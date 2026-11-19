-- Black Cabin presence v1 (docs/design/08-presence.md §7, contract 08b-presence-api.md).
-- Every table has RLS on; clients never write tables directly: they call the bc_* functions (security definer).
-- Times: a bar night is the Bangkok day that starts at 06:00 (same as needs.gd night_key); the bar is open
-- Tue–Sun 19:00–02:00 Bangkok (06-stakes §3).

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------- settings (one row, server only)
create table public.bc_settings (
  id int primary key default 1 check (id = 1),
  ignore_hours boolean not null default false,      -- test switch: check-ins outside opening hours
  push_max_per_night int not null default 3,         -- pushes a receiver gets per night (card presence-push-caps)
  push_per_sender int not null default 1,            -- pushes per sender -> receiver pair per night
  push_from_hour int not null default 19,            -- Bangkok hour window for pushes [from, until)
  push_until_hour int not null default 2,
  tablemate_window_min int not null default 45,
  verbs_per_night int not null default 40
);
insert into public.bc_settings default values;

-- ---------------------------------------------------------------- tables
create table public.venue_tables (
  code text primary key check (code ~ '^[A-Za-z0-9]{10}$'),
  table_id text not null,
  label text not null,
  zone text not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index on public.venue_tables (table_id);

create table public.profiles (
  player_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 24),
  avatar jsonb not null default '{}'::jsonb check (pg_column_size(avatar) < 4096),
  presence_mode text not null default '' check (presence_mode in ('', 'everyone', 'here', 'nobody')),
  name_hidden boolean not null default false,        -- 3 reports in 30 days: shown as "Guest ####" until reviewed
  banned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.checkins (
  id bigint generated always as identity primary key,
  player_id uuid not null references public.profiles (player_id) on delete cascade,
  night date not null,
  table_id text not null,
  code text not null,
  first_at timestamptz not null default now(),
  at timestamptz not null default now(),
  display_name text not null,
  avatar jsonb not null,
  visibility text not null check (visibility in ('everyone', 'here', 'nobody')),
  unique (player_id, night)
);
create index on public.checkins (night, table_id);

create table public.checkin_attempts (
  player_id uuid not null references public.profiles (player_id) on delete cascade,
  at timestamptz not null default now()
);
create index on public.checkin_attempts (player_id, at);

create table public.tablemates (
  night date not null,
  table_id text not null,
  a uuid not null references public.profiles (player_id) on delete cascade,
  b uuid not null references public.profiles (player_id) on delete cascade,
  at timestamptz not null default now(),
  primary key (night, a, b),
  check (a < b)
);

create table public.events (
  id bigint generated always as identity primary key,
  from_id uuid not null references public.profiles (player_id) on delete cascade,
  to_id uuid not null references public.profiles (player_id) on delete cascade,
  kind text not null check (kind in ('wave', 'cheers', 'drink', 'phrase', 'table_cheers')),
  payload jsonb not null default '{}'::jsonb check (pg_column_size(payload) < 512),
  night date not null,
  at timestamptz not null default now(),
  read_at timestamptz
);
create index on public.events (to_id, read_at);
create index on public.events (from_id, night);

create table public.friends (
  a uuid not null references public.profiles (player_id) on delete cascade,
  b uuid not null references public.profiles (player_id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'ok')),
  asked_by uuid not null,
  notify_a boolean not null default false,
  notify_b boolean not null default false,
  at timestamptz not null default now(),
  primary key (a, b),
  check (a < b)
);

create table public.blocks (
  blocker uuid not null references public.profiles (player_id) on delete cascade,
  blocked uuid not null references public.profiles (player_id) on delete cascade,
  at timestamptz not null default now(),
  primary key (blocker, blocked)
);

create table public.reports (
  id bigint generated always as identity primary key,
  reporter uuid not null references public.profiles (player_id) on delete cascade,
  target uuid not null references public.profiles (player_id) on delete cascade,
  reason text not null check (reason in ('name', 'harassment', 'other')),
  night date not null,
  at timestamptz not null default now(),
  status text not null default 'open' check (status in ('open', 'kept', 'dismissed', 'banned'))
);

create table public.push_subscriptions (
  id bigint generated always as identity primary key,
  player_id uuid not null references public.profiles (player_id) on delete cascade,
  endpoint text not null unique check (endpoint ~ '^https://' and char_length(endpoint) < 1024),
  p256dh text not null check (char_length(p256dh) < 200),
  auth text not null check (char_length(auth) < 100),
  created_at timestamptz not null default now()
);

create table public.push_log (
  id bigint generated always as identity primary key,
  event_id bigint references public.events (id) on delete set null,
  from_id uuid,
  to_id uuid not null,
  night date not null,
  at timestamptz not null default now(),
  status text not null default 'pending',            -- pending | sent | failed | gone
  detail text
);
create index on public.push_log (to_id, night);

-- VAPID keys live here, generated by the push Edge Function on its first run; never exposed to clients.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create table private.vapid (
  id int primary key default 1 check (id = 1),
  public_key text not null,      -- base64url, uncompressed P-256 point (applicationServerKey)
  private_jwk jsonb not null,
  subject text not null default 'https://blackcabin.app',
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- RLS: on everywhere, reads of own rows only
alter table public.bc_settings enable row level security;
alter table public.venue_tables enable row level security;
alter table public.profiles enable row level security;
alter table public.checkins enable row level security;
alter table public.checkin_attempts enable row level security;
alter table public.tablemates enable row level security;
alter table public.events enable row level security;
alter table public.friends enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.push_log enable row level security;

create policy own_profile on public.profiles for select to authenticated using (player_id = auth.uid());
create policy own_checkins on public.checkins for select to authenticated using (player_id = auth.uid());
create policy own_tablemates on public.tablemates for select to authenticated using (auth.uid() in (a, b));
create policy own_events on public.events for select to authenticated using (to_id = auth.uid() or from_id = auth.uid());
create policy own_friends on public.friends for select to authenticated using (auth.uid() in (a, b));
create policy own_blocks on public.blocks for select to authenticated using (blocker = auth.uid());
create policy own_push on public.push_subscriptions for select to authenticated using (player_id = auth.uid());

revoke insert, update, delete, truncate on all tables in schema public from anon, authenticated;

-- ---------------------------------------------------------------- helpers
create or replace function public.bc_night(t timestamptz default now()) returns date
language sql stable set search_path = '' as $$
  select ((t at time zone 'Asia/Bangkok') - interval '6 hours')::date
$$;

create or replace function public.bc_local_hour(t timestamptz default now()) returns int
language sql stable set search_path = '' as $$
  select extract(hour from (t at time zone 'Asia/Bangkok'))::int
$$;

-- Tue–Sun 19:00–02:00 Bangkok; the night of a Monday is closed.
create or replace function public.bc_is_open(t timestamptz default now()) returns boolean
language sql stable set search_path = '' as $$
  select (select ignore_hours from public.bc_settings where id = 1)
      or (extract(isodow from public.bc_night(t)) <> 1
          and (public.bc_local_hour(t) >= 19 or public.bc_local_hour(t) < 2))
$$;

create or replace function public.bc_blocked_between(x uuid, y uuid) returns boolean
language sql stable set search_path = '' as $$
  select exists (select 1 from public.blocks
                 where (blocker = x and blocked = y) or (blocker = y and blocked = x))
$$;

create or replace function public.bc_shown_name(p public.profiles) returns text
language sql immutable set search_path = '' as $$
  select case when p.name_hidden then 'Guest ' || lpad((abs(hashtext(p.player_id::text)) % 10000)::text, 4, '0')
              else p.display_name end
$$;

-- The presences a viewer may see for one night, as jsonb rows (08 §2.2, P1, P3).
create or replace function public.bc_presences(viewer uuid, n date) returns setof jsonb
language sql stable security definer set search_path = '' as $$
  with me as (
    select exists (select 1 from public.checkins where player_id = viewer and night = n) as here
  ), rows as (
    select c.*, p as prof,
           exists (select 1 from public.tablemates t where t.night = n and t.a = least(viewer, c.player_id)
                   and t.b = greatest(viewer, c.player_id)) as tm,
           exists (select 1 from public.friends f where f.status = 'ok' and f.a = least(viewer, c.player_id)
                   and f.b = greatest(viewer, c.player_id)) as fr,
           exists (select 1 from public.events e where e.night = n and ((e.from_id = viewer and e.to_id = c.player_id)
                   or (e.to_id = viewer and e.from_id = c.player_id))) as met,
           (select count(distinct night) from public.checkins c2 where c2.player_id = c.player_id
              and c2.night > n - 90) as nights90,
           (select count(*) from public.checkins c3 where c3.player_id = c.player_id) as nights_all
    from public.checkins c
    join public.profiles p on p.player_id = c.player_id
    where c.night = n
      and (c.player_id = viewer or (
            not p.banned
            and (c.visibility = 'everyone' or (c.visibility = 'here' and (select here from me)))
            and not public.bc_blocked_between(viewer, c.player_id)))
  )
  select jsonb_build_object(
    'player_id', r.player_id,
    'display_name', case when r.player_id = viewer then r.display_name else public.bc_shown_name(r.prof) end,
    'avatar', r.avatar,
    'table_id', case when (select here from me) then r.table_id else '' end,
    'zone', coalesce((select v.zone from public.venue_tables v where v.table_id = r.table_id limit 1), 'Tables'),
    'at', extract(epoch from r.at),
    'tablemate', r.tm, 'friend', r.fr, 'regular', r.nights90 >= 5, 'first_time', r.nights_all <= 1,
    'me', r.player_id = viewer)
  from rows r
  order by (r.player_id = viewer) desc, r.tm desc, r.fr desc, r.met desc, r.at desc
$$;

-- ---------------------------------------------------------------- client RPCs
create or replace function public.bc_set_profile(p_display_name text default null, p_avatar jsonb default null,
                                                 p_mode text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  if p_mode is not null and p_mode not in ('', 'everyone', 'here', 'nobody') then
    return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'bad mode');
  end if;
  insert into public.profiles (player_id) values (uid) on conflict do nothing;
  update public.profiles set
    display_name = coalesce(left(regexp_replace(p_display_name, '[[:cntrl:]]', '', 'g'), 24), display_name),
    avatar = case when p_avatar is not null and jsonb_typeof(p_avatar) = 'object' then p_avatar else avatar end,
    presence_mode = coalesce(p_mode, presence_mode),
    updated_at = now()
  where player_id = uid;
  if p_mode = 'nobody' then   -- "Nobody" also hides tonight at once (08 §2.3)
    update public.checkins set visibility = 'nobody' where player_id = uid and night = public.bc_night();
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.bc_check_in(p_code text, p_display_name text, p_avatar jsonb, p_mode text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  vt public.venue_tables;
  prof public.profiles;
  cur public.checkins;
  n date := public.bc_night();
  win int := (select tablemate_window_min from public.bc_settings where id = 1);
  first boolean := false;
  moved boolean := false;
  mates jsonb;
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  if coalesce(p_mode, '') not in ('everyone', 'here', 'nobody') then
    return jsonb_build_object('ok', false, 'reason', 'need_mode');
  end if;
  perform public.bc_set_profile(p_display_name, p_avatar, p_mode);
  select * into prof from public.profiles where player_id = uid;
  if prof.banned then return jsonb_build_object('ok', false, 'reason', 'banned'); end if;
  if (select count(*) from public.checkin_attempts where player_id = uid and at > now() - interval '10 minutes') >= 5 then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;
  insert into public.checkin_attempts (player_id) values (uid);
  select * into vt from public.venue_tables where code = p_code and active;
  if vt.code is null then return jsonb_build_object('ok', false, 'reason', 'bad_code'); end if;
  if not public.bc_is_open() then return jsonb_build_object('ok', false, 'reason', 'closed'); end if;

  select * into cur from public.checkins where player_id = uid and night = n for update;
  if cur.id is null then
    first := true;
    insert into public.checkins (player_id, night, table_id, code, display_name, avatar, visibility)
    values (uid, n, vt.table_id, vt.code, prof.display_name, prof.avatar, p_mode);
  else
    moved := cur.table_id <> vt.table_id;
    update public.checkins set table_id = vt.table_id, code = vt.code, at = now(),
      display_name = prof.display_name, avatar = prof.avatar, visibility = p_mode
    where id = cur.id;
  end if;

  -- Tablemates: visible players whose (last) scan at this table is within the window (08 §3.2).
  if p_mode <> 'nobody' then
    insert into public.tablemates (night, table_id, a, b)
    select n, vt.table_id, least(uid, c.player_id), greatest(uid, c.player_id)
    from public.checkins c join public.profiles p on p.player_id = c.player_id
    where c.night = n and c.table_id = vt.table_id and c.player_id <> uid and c.visibility <> 'nobody'
      and not p.banned and c.at > now() - make_interval(mins => win)
      and not public.bc_blocked_between(uid, c.player_id)
    on conflict do nothing;
  end if;

  select coalesce(jsonb_agg(x), '[]'::jsonb) into mates
  from public.bc_presences(uid, n) x
  where (x->>'tablemate')::boolean and x->>'table_id' = vt.table_id;

  return jsonb_build_object('ok', true, 'night', n, 'night_key', n - date '1970-01-01',
    'table_id', vt.table_id, 'label', vt.label, 'first_of_night', first, 'moved', moved, 'tablemates', mates);
end $$;

create or replace function public.bc_tonight() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  n date := public.bc_night();
  open boolean := public.bc_is_open();
  ln date;
  pres jsonb := '[]'::jsonb;
  last jsonb := '[]'::jsonb;
  mine public.checkins;
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  select * into mine from public.checkins where player_id = uid and night = n;
  if open then
    select coalesce(jsonb_agg(x), '[]'::jsonb) into pres from public.bc_presences(uid, n) x;
  else
    ln := case when public.bc_local_hour() < 6 then n else n - 1 end;
    select coalesce(jsonb_agg(jsonb_build_object('player_id', x->'player_id', 'display_name', x->'display_name',
             'avatar', x->'avatar')), '[]'::jsonb)
      into last from public.bc_presences(uid, ln) x where not (x->>'me')::boolean;
  end if;
  return jsonb_build_object('ok', true, 'night', n, 'open', open, 'me_checked_in', mine.id is not null and open,
    'my_table', case when open then coalesce(mine.table_id, '') else '' end,
    'presences', pres, 'last_night', last, 'server_time', extract(epoch from now()));
end $$;

-- Records a verb; called by the `verb` Edge Function with the sender's JWT (so auth.uid() is the sender), which then
-- sends the push when `push` is true. Coins for a drink are spent client-side (P10).
create or replace function public.bc_send_verb(p_to uuid, p_kind text, p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  n date := public.bc_night();
  s public.bc_settings;
  me public.profiles;
  rc public.checkins;
  sender_here boolean;
  per_pair int;
  pl jsonb := '{}'::jsonb;
  eid bigint;
  do_push boolean := false;
  h int := public.bc_local_hour();
  log_id bigint;
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  select * into s from public.bc_settings where id = 1;
  if p_to = uid then return jsonb_build_object('ok', false, 'reason', 'self'); end if;
  if p_kind not in ('wave', 'cheers', 'drink', 'phrase') then
    return jsonb_build_object('ok', false, 'reason', 'bad_kind');
  end if;
  select * into me from public.profiles where player_id = uid;
  if me.player_id is null then
    insert into public.profiles (player_id) values (uid) returning * into me;
  end if;
  if me.banned then return jsonb_build_object('ok', false, 'reason', 'banned'); end if;
  if not public.bc_is_open() then return jsonb_build_object('ok', false, 'reason', 'not_tonight'); end if;
  select * into rc from public.checkins where player_id = p_to and night = n;
  sender_here := exists (select 1 from public.checkins where player_id = uid and night = n);
  -- The receiver must be someone the sender can see tonight; otherwise answer as if they were not here.
  if rc.id is null or rc.visibility = 'nobody' or (rc.visibility = 'here' and not sender_here)
     or exists (select 1 from public.profiles where player_id = p_to and banned)
     or exists (select 1 from public.blocks where blocker = uid and blocked = p_to) then
    return jsonb_build_object('ok', false, 'reason', 'not_tonight');
  end if;
  -- Hidden by the receiver: accepted and dropped, so the sender is never told (08 §7.4).
  if exists (select 1 from public.blocks where blocker = p_to and blocked = uid) then
    return jsonb_build_object('ok', true, 'event_id', 0, 'push', false);
  end if;
  per_pair := case p_kind when 'phrase' then 3 else 1 end;
  if (select count(*) from public.events where from_id = uid and to_id = p_to and night = n and kind = p_kind) >= per_pair
     or (select count(*) from public.events where from_id = uid and night = n) >= s.verbs_per_night then
    return jsonb_build_object('ok', false, 'reason', 'limit');
  end if;
  if p_kind = 'phrase' then
    if coalesce(p_payload->>'phrase', '') !~ '^p(0[1-9]|1[0-9]|2[0-4])$' then
      return jsonb_build_object('ok', false, 'reason', 'bad_kind', 'detail', 'phrase');
    end if;
    pl := jsonb_build_object('phrase', p_payload->>'phrase', 'emoji', left(coalesce(p_payload->>'emoji', ''), 8));
  elsif p_kind = 'drink' then
    if coalesce(p_payload->>'band', '') not in ('4', '6', '9')
       or coalesce(p_payload->>'drink_id', '') !~ '^[a-z0-9_]{1,40}$' then
      return jsonb_build_object('ok', false, 'reason', 'bad_kind', 'detail', 'drink');
    end if;
    pl := jsonb_build_object('drink_id', p_payload->>'drink_id', 'band', (p_payload->>'band')::int);
  end if;
  insert into public.events (from_id, to_id, kind, payload, night) values (uid, p_to, p_kind, pl, n)
  returning id into eid;

  -- Push budget (card presence-push-caps; defaults in bc_settings).
  if exists (select 1 from public.push_subscriptions where player_id = p_to)
     and (case when s.push_from_hour <= s.push_until_hour then h >= s.push_from_hour and h < s.push_until_hour
               else h >= s.push_from_hour or h < s.push_until_hour end)
     and (select count(*) from public.push_log where to_id = p_to and night = n and status in ('pending', 'sent'))
         < s.push_max_per_night
     and (select count(*) from public.push_log where to_id = p_to and from_id = uid and night = n
            and status in ('pending', 'sent')) < s.push_per_sender then
    insert into public.push_log (event_id, from_id, to_id, night) values (eid, uid, p_to, n) returning id into log_id;
    do_push := true;
  end if;
  return jsonb_build_object('ok', true, 'event_id', eid, 'push', do_push, 'push_log_id', log_id,
                            'from_name', public.bc_shown_name(me));
end $$;

create or replace function public.bc_inbox() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('ok', true, 'events', coalesce(jsonb_agg(jsonb_build_object(
      'id', e.id, 'kind', e.kind, 'payload', e.payload, 'night', e.night, 'at', extract(epoch from e.at),
      'from', jsonb_build_object('player_id', p.player_id, 'display_name', public.bc_shown_name(p), 'avatar', p.avatar))
      order by e.at), '[]'::jsonb))
  from (select * from public.events where to_id = auth.uid() and read_at is null order by at desc limit 100) e
  join public.profiles p on p.player_id = e.from_id
  where not exists (select 1 from public.blocks b where b.blocker = auth.uid() and b.blocked = e.from_id)
$$;

create or replace function public.bc_mark_read(p_ids bigint[]) returns jsonb
language sql security definer set search_path = '' as $$
  with u as (update public.events set read_at = now() where to_id = auth.uid() and id = any (p_ids) and read_at is null
             returning 1)
  select jsonb_build_object('ok', true, 'marked', (select count(*) from u))
$$;

create or replace function public.bc_hide(p_player uuid) returns jsonb
language sql security definer set search_path = '' as $$
  insert into public.blocks (blocker, blocked) select auth.uid(), p_player
  where auth.uid() is not null and p_player <> auth.uid()
    and exists (select 1 from public.profiles where player_id = p_player)
  on conflict do nothing;
  select jsonb_build_object('ok', true)
$$;

create or replace function public.bc_report(p_player uuid, p_reason text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null or p_player = uid or p_reason not in ('name', 'harassment', 'other') then
    return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'bad report');
  end if;
  if not exists (select 1 from public.profiles where player_id = p_player) then
    return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no such player');
  end if;
  insert into public.profiles (player_id) values (uid) on conflict do nothing;
  perform public.bc_hide(p_player);
  if not exists (select 1 from public.reports where reporter = uid and target = p_player and at > now() - interval '1 day') then
    insert into public.reports (reporter, target, reason, night) values (uid, p_player, p_reason, public.bc_night());
  end if;
  if (select count(distinct reporter) from public.reports where target = p_player and at > now() - interval '30 days') >= 3 then
    update public.profiles set name_hidden = true where player_id = p_player;
  end if;
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.bc_save_push(p_endpoint text, p_p256dh text, p_auth text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  insert into public.profiles (player_id) values (uid) on conflict do nothing;
  insert into public.push_subscriptions (player_id, endpoint, p256dh, auth) values (uid, p_endpoint, p_p256dh, p_auth)
  on conflict (endpoint) do update set player_id = excluded.player_id, p256dh = excluded.p256dh, auth = excluded.auth;
  -- at most 3 devices per player: drop the oldest
  delete from public.push_subscriptions where player_id = uid and id not in
    (select id from public.push_subscriptions where player_id = uid order by created_at desc, id desc limit 3);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.bc_delete_push(p_endpoint text default null) returns jsonb
language sql security definer set search_path = '' as $$
  delete from public.push_subscriptions where player_id = auth.uid() and (p_endpoint is null or endpoint = p_endpoint);
  select jsonb_build_object('ok', true)
$$;

create or replace function public.bc_push_public_key() returns text
language sql stable security definer set search_path = '' as $$
  select public_key from private.vapid where id = 1
$$;

create or replace function public.bc_delete_me() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  delete from public.push_log where to_id = uid or from_id = uid;
  delete from public.reports where reporter = uid;   -- reports about the player stay for review (1 year)
  delete from public.profiles where player_id = uid;  -- cascades to every other row of the player
  begin
    delete from auth.users where id = uid;
  exception when others then null;                    -- the account row is anonymous; profile rows are gone anyway
  end;
  return jsonb_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------- service-only functions (Edge Function `verb`)
create or replace function public.bc_svc_vapid() returns jsonb
language sql stable security definer set search_path = '' as $$
  select to_jsonb(v) from private.vapid v where id = 1
$$;

create or replace function public.bc_svc_vapid_set(p_public text, p_private jsonb) returns jsonb
language sql security definer set search_path = '' as $$
  insert into private.vapid (id, public_key, private_jwk) values (1, p_public, p_private) on conflict (id) do nothing;
  select to_jsonb(v) from private.vapid v where id = 1
$$;

create or replace function public.bc_svc_push_targets(p_to uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('endpoint', endpoint, 'p256dh', p256dh, 'auth', auth)), '[]'::jsonb)
  from public.push_subscriptions where player_id = p_to
$$;

create or replace function public.bc_svc_push_result(p_log_id bigint, p_status text, p_detail text,
                                                     p_gone_endpoints text[] default '{}') returns void
language sql security definer set search_path = '' as $$
  update public.push_log set status = p_status, detail = left(p_detail, 500) where id = p_log_id;
  delete from public.push_subscriptions where endpoint = any (p_gone_endpoints);
$$;

-- Retention (P4): check-ins and tablemates 90 days, read events 30 days, push log 30 days, reports 1 year,
-- attempts 1 day. Run daily by pg_cron when available (see 20261119000002).
create or replace function public.bc_retention() returns void
language sql security definer set search_path = '' as $$
  delete from public.checkin_attempts where at < now() - interval '1 day';
  delete from public.checkins where night < public.bc_night() - 90;
  delete from public.tablemates where night < public.bc_night() - 90;
  delete from public.events where read_at < now() - interval '30 days' or at < now() - interval '90 days';
  delete from public.push_log where at < now() - interval '30 days';
  delete from public.reports where at < now() - interval '1 year';
$$;

-- ---------------------------------------------------------------- grants
revoke execute on all functions in schema public from public, anon;
grant execute on function public.bc_set_profile(text, jsonb, text), public.bc_check_in(text, text, jsonb, text),
  public.bc_tonight(), public.bc_send_verb(uuid, text, jsonb), public.bc_inbox(), public.bc_mark_read(bigint[]),
  public.bc_hide(uuid), public.bc_report(uuid, text), public.bc_save_push(text, text, text),
  public.bc_delete_push(text), public.bc_push_public_key(), public.bc_delete_me(), public.bc_night(timestamptz)
  to authenticated;
revoke execute on function public.bc_svc_vapid(), public.bc_svc_vapid_set(text, jsonb),
  public.bc_svc_push_targets(uuid), public.bc_svc_push_result(bigint, text, text, text[]), public.bc_retention(),
  public.bc_presences(uuid, date) from authenticated;
grant execute on function public.bc_svc_vapid(), public.bc_svc_vapid_set(text, jsonb),
  public.bc_svc_push_targets(uuid), public.bc_svc_push_result(bigint, text, text, text[]), public.bc_retention()
  to service_role;
