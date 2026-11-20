-- Consistent players + merch inventory (Daniele 2026-11-20: "setup the server to consistent stuff and knowing what
-- player has what ... from tonite we have consistent players (so between version they don t need to recreate the
-- charcter except if they do reset)"; "10 special pieces per category and for now can be picked for free later will
-- need to buy"). Design: docs/design/14-merch-shop.md.
--
-- profiles (presence v1) gains the rest of the character: personality, when it was made, the build that last wrote
-- it, and a player code (restore_code) that brings the character back on a phone that lost its local save (new web
-- address, cleared or evicted browser storage, a lost anonymous session).
-- merch_items is the catalogue (rows from supabase/seed/merch_items.sql); prices exist as columns, NULL for now:
-- no money logic here, money is Daniele's call. inventory is who owns what (source free_pick now, purchase later).
-- RLS: players read only their own profile and inventory rows; every write goes through the bc_* functions below.

-- ---------------------------------------------------------------- profiles: the whole character
alter table public.profiles
  add column if not exists personality text not null default '' check (char_length(personality) <= 24),
  add column if not exists character_created_at timestamptz,      -- when the player made the character (client clock)
  add column if not exists avatar_at timestamptz,                 -- last time the character itself was saved here
  add column if not exists build text not null default '' check (char_length(build) <= 40),
  add column if not exists restore_code text unique check (restore_code ~ '^[A-HJ-NP-Z2-9]{10}$'),
  add column if not exists restored_from uuid;

-- ---------------------------------------------------------------- catalogue
create table if not exists public.merch_items (
  item_id text primary key check (item_id ~ '^[a-z0-9_]{2,40}$'),
  category text not null check (category in ('head', 'eyes', 'top', 'acc')),
  name text not null check (char_length(name) <= 60),
  sort int not null default 0,
  price_coins int check (price_coins >= 0),          -- in-game coins, later (NULL = no price set)
  price_thb numeric(10, 2) check (price_thb >= 0),   -- real money, later, if ever (Daniele's call)
  free_pick boolean not null default true,           -- may be picked for free while bc_settings.shop_free is on
  active boolean not null default true,              -- false = no longer offered; owners keep it
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- inventory
create table if not exists public.inventory (
  player_id uuid not null references public.profiles (player_id) on delete cascade,
  item_id text not null references public.merch_items (item_id),
  acquired_at timestamptz not null default now(),
  source text not null check (source in ('free_pick', 'purchase', 'grant')),
  price_paid numeric(10, 2) check (price_paid >= 0), -- NULL for free picks
  primary key (player_id, item_id)
);
create index if not exists inventory_item on public.inventory (item_id);

create table if not exists public.restore_attempts (
  player_id uuid not null references auth.users (id) on delete cascade,
  at timestamptz not null default now()
);
create index if not exists restore_attempts_player on public.restore_attempts (player_id, at);

alter table public.bc_settings add column if not exists shop_free boolean not null default true;

alter table public.merch_items enable row level security;
alter table public.inventory enable row level security;
alter table public.restore_attempts enable row level security;
drop policy if exists merch_read on public.merch_items;
create policy merch_read on public.merch_items for select to anon, authenticated using (active);
drop policy if exists own_inventory on public.inventory;
create policy own_inventory on public.inventory for select to authenticated using (player_id = auth.uid());
revoke insert, update, delete, truncate on public.merch_items, public.inventory, public.restore_attempts
  from anon, authenticated;

-- ---------------------------------------------------------------- helpers
-- A fresh player code: 10 characters, no look-alikes (no I, O, 0, 1).
create or replace function public.bc_new_restore_code() returns text
language plpgsql security definer set search_path = '' as $$
declare a text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; c text; i int;
begin
  loop
    c := '';
    for i in 1..10 loop
      c := c || substr(a, 1 + (get_byte(extensions.gen_random_bytes(1), 0) % 32), 1);
    end loop;
    exit when not exists (select 1 from public.profiles where restore_code = c);
  end loop;
  return c;
end $$;
revoke execute on function public.bc_new_restore_code() from public, anon, authenticated;

-- The caller's character as the client stores it: profile fields, code, owned items.
create or replace function public.bc_profile_json(uid uuid) returns jsonb
language sql security definer set search_path = '' stable as $$
  select jsonb_build_object(
    'ok', true,
    'player_id', p.player_id,
    'display_name', p.display_name,
    'avatar', p.avatar,
    'personality', p.personality,
    'character_created_at', extract(epoch from p.character_created_at),
    'avatar_at', extract(epoch from p.avatar_at),
    'restore_code', p.restore_code,
    'inventory', coalesce((select jsonb_agg(jsonb_build_object('item_id', i.item_id, 'source', i.source,
        'acquired_at', extract(epoch from i.acquired_at)) order by i.acquired_at)
      from public.inventory i where i.player_id = p.player_id), '[]'::jsonb))
  from public.profiles p where p.player_id = uid
$$;
revoke execute on function public.bc_profile_json(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------- player functions
-- Save the character (name, avatar record, personality, created-at, build) and get back the code and inventory.
-- p_avatar null keeps the server's; a newer avatar on the server (p_avatar_at older than avatar_at) is kept too,
-- so an old phone cannot overwrite a newer look.
create or replace function public.bc_profile_save(p_display_name text default null, p_avatar jsonb default null,
    p_personality text default null, p_created_at double precision default null,
    p_avatar_at double precision default null, p_build text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); cur public.profiles; newer boolean;
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  if p_avatar is not null and (jsonb_typeof(p_avatar) <> 'object' or pg_column_size(p_avatar) >= 4096) then
    return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'bad avatar');
  end if;
  insert into public.profiles (player_id) values (uid) on conflict do nothing;
  select * into cur from public.profiles where player_id = uid for update;
  newer := cur.avatar_at is null or p_avatar_at is null or to_timestamp(p_avatar_at) >= cur.avatar_at;
  update public.profiles set
    display_name = case when newer then coalesce(left(regexp_replace(p_display_name, '[[:cntrl:]]', '', 'g'), 24),
      display_name) else display_name end,
    avatar = case when newer and p_avatar is not null then p_avatar else avatar end,
    personality = case when newer then coalesce(left(p_personality, 24), personality) else personality end,
    character_created_at = coalesce(character_created_at,
      case when p_created_at > 0 then to_timestamp(p_created_at) end),
    avatar_at = case when newer and p_avatar is not null
      then coalesce(to_timestamp(p_avatar_at), now()) else avatar_at end,
    build = coalesce(left(p_build, 40), build),
    restore_code = coalesce(restore_code, public.bc_new_restore_code()),
    updated_at = now()
  where player_id = uid;
  return public.bc_profile_json(uid);
end $$;

create or replace function public.bc_profile_get() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); r jsonb;
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  r := public.bc_profile_json(uid);
  return coalesce(r, jsonb_build_object('ok', true, 'player_id', uid, 'inventory', '[]'::jsonb));
end $$;

-- Pick a piece for free (the shop, 2026-11-20). Owning twice is fine (answers new = false).
create or replace function public.bc_claim_item(p_item text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); it public.merch_items; free_on boolean; n int;
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  select * into it from public.merch_items where item_id = p_item and active;
  if not found then return jsonb_build_object('ok', false, 'reason', 'unknown_item'); end if;
  select shop_free into free_on from public.bc_settings where id = 1;
  if not (coalesce(free_on, false) and it.free_pick) then
    return jsonb_build_object('ok', false, 'reason', 'not_free');
  end if;
  insert into public.profiles (player_id) values (uid) on conflict do nothing;
  insert into public.inventory (player_id, item_id, source) values (uid, p_item, 'free_pick') on conflict do nothing;
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'item_id', p_item, 'new', n > 0, 'source', 'free_pick',
    'acquired_at', (select extract(epoch from acquired_at) from public.inventory where player_id = uid and item_id = p_item));
end $$;

-- Bring a character back with its player code: the code's character (name, look, personality, created-at) and its
-- items move to the caller's account; the code moves along (one live holder). 10 tries an hour.
create or replace function public.bc_profile_restore(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); src public.profiles; code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  if (select count(*) from public.restore_attempts where player_id = uid and at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  insert into public.restore_attempts (player_id) values (uid);
  select * into src from public.profiles where restore_code = code;
  if not found then return jsonb_build_object('ok', false, 'reason', 'bad_code'); end if;
  if src.player_id = uid then return public.bc_profile_json(uid); end if;
  if src.banned then return jsonb_build_object('ok', false, 'reason', 'bad_code'); end if;
  insert into public.profiles (player_id) values (uid) on conflict do nothing;
  update public.profiles set restore_code = null where player_id = src.player_id;
  update public.profiles set display_name = src.display_name, avatar = src.avatar, personality = src.personality,
    character_created_at = coalesce(src.character_created_at, src.created_at), avatar_at = src.avatar_at,
    restore_code = code, restored_from = src.player_id, updated_at = now()
  where player_id = uid;
  insert into public.inventory (player_id, item_id, acquired_at, source, price_paid)
    select uid, item_id, acquired_at, source, price_paid from public.inventory where player_id = src.player_id
    on conflict do nothing;
  delete from public.inventory where player_id = src.player_id;
  return public.bc_profile_json(uid);
end $$;

revoke execute on function public.bc_profile_save(text, jsonb, text, double precision, double precision, text) from public, anon;
grant execute on function public.bc_profile_save(text, jsonb, text, double precision, double precision, text) to authenticated;
revoke execute on function public.bc_profile_get() from public, anon;
grant execute on function public.bc_profile_get() to authenticated;
revoke execute on function public.bc_claim_item(text) from public, anon;
grant execute on function public.bc_claim_item(text) to authenticated;
revoke execute on function public.bc_profile_restore(text) from public, anon;
grant execute on function public.bc_profile_restore(text) to authenticated;
