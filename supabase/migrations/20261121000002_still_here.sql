-- "Still at Black Cabin?" (Daniele 2026-11-21: "add a you still at bc prompt after 1 hour that sends a notification
-- if not open within 30 min it auto check out if open and press yes stay").
-- One hour after the check-in (or after the last Yes) the check-in is due a confirm: bc_tonight says still_due, the
-- game shows the prompt (Yes, I'm here / Leave), and the `still-here` Edge Function sends one Web Push to phones that
-- allowed it. Yes (bc_still_here) restarts the hour. No answer within 30 more minutes: checked out. The deadline is
-- read in every query (bc_still_expired), so it holds without a scheduler; pg_cron, when there, also writes left_at
-- every 5 minutes and calls the push function (end of this file).
-- Times are in bc_settings (still_after_min, still_grace_min). A re-scan restarts the clock (trigger below).
-- Also: bc_tonight now answers me_checked_in false and my_table '' after Leave (20261121000001 left them set).

alter table public.bc_settings add column if not exists still_after_min int not null default 60;
alter table public.bc_settings add column if not exists still_grace_min int not null default 30;
alter table public.checkins add column if not exists confirmed_at timestamptz;     -- last "Yes, I'm here"
alter table public.checkins add column if not exists still_pushed_at timestamptz;  -- this hour's push went out

-- Everyone checked in when this lands gets a fresh hour (otherwise check-ins older than 90 minutes would vanish at once).
update public.checkins set confirmed_at = now() where night >= public.bc_night() - 1 and left_at is null;

create or replace function public.bc_still_base(c public.checkins) returns timestamptz
language sql stable set search_path = '' as $$
  select greatest(c.at, coalesce(c.confirmed_at, c.at))
$$;

create or replace function public.bc_still_due(c public.checkins) returns boolean
language sql stable set search_path = '' as $$
  select c.left_at is null and now() >= public.bc_still_base(c)
         + make_interval(mins => (select still_after_min from public.bc_settings where id = 1))
$$;

create or replace function public.bc_still_expired(c public.checkins) returns boolean
language sql stable set search_path = '' as $$
  select now() >= public.bc_still_base(c) + make_interval(mins => (select still_after_min + still_grace_min
                                                                   from public.bc_settings where id = 1))
$$;

-- A re-scan (bc_check_in moves `at`) is an answer too: back in, and the hour starts again.
create or replace function private.bc_checkins_rescan() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.at is distinct from old.at then
    new.left_at := null;
    new.confirmed_at := null;
    new.still_pushed_at := null;
  end if;
  return new;
end $$;

-- "Yes, I'm here": the hour starts again. Too late (or after Leave): {ok:false, reason:"left"}; scan again.
create or replace function public.bc_still_here() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  c public.checkins;
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  select * into c from public.checkins where player_id = uid and night = public.bc_night() for update;
  if c.id is null or c.left_at is not null or public.bc_still_expired(c) then
    return jsonb_build_object('ok', false, 'reason', 'left');
  end if;
  update public.checkins set confirmed_at = now(), still_pushed_at = null where id = c.id;
  return jsonb_build_object('ok', true, 'next_at', extract(epoch from now() + make_interval(mins =>
    (select still_after_min from public.bc_settings where id = 1))));
end $$;

-- Writes left_at for the check-ins whose answer window closed (pg_cron; the queries do not depend on it).
create or replace function public.bc_still_sweep() returns int
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  update public.checkins c set left_at = public.bc_still_base(c) + make_interval(mins =>
      (select still_after_min + still_grace_min from public.bc_settings where id = 1))
  where c.night >= public.bc_night() - 1 and c.left_at is null and public.bc_still_expired(c);
  get diagnostics n = row_count;
  return n;
end $$;

-- For the `still-here` Edge Function (service role): check-ins due a confirm whose push has not gone out this hour,
-- on phones with a push subscription; each gets a push_log row and is marked pushed.
create or replace function public.bc_svc_still_targets() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  res jsonb := '[]'::jsonb;
  r record;
  lid bigint;
begin
  for r in
    select c.id, c.player_id, c.night from public.checkins c
    where c.night = public.bc_night() and c.left_at is null and c.still_pushed_at is null
      and public.bc_still_due(c) and not public.bc_still_expired(c)
      and exists (select 1 from public.push_subscriptions s where s.player_id = c.player_id)
    for update skip locked
  loop
    insert into public.push_log (event_id, from_id, to_id, night, detail)
    values (null, null, r.player_id, r.night, 'still') returning id into lid;
    update public.checkins set still_pushed_at = now() where id = r.id;
    res := res || jsonb_build_object('to', r.player_id, 'log_id', lid);
  end loop;
  return res;
end $$;

-- Tonight's list without players who left or did not answer in time.
create or replace function public.bc_presences(viewer uuid, n date) returns setof jsonb
language sql stable security definer set search_path = '' as $$
  with me as (
    select exists (select 1 from public.checkins where player_id = viewer and night = n and left_at is null
                   and not public.bc_still_expired(checkins)) as here
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
      and c.left_at is null
      and not public.bc_still_expired(c)
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

-- bc_tonight: still_due / still_deadline for the prompt; Leave and a missed answer read as not checked in.
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
  s_after int := (select still_after_min from public.bc_settings where id = 1);
  s_grace int := (select still_grace_min from public.bc_settings where id = 1);
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  select * into mine from public.checkins where player_id = uid and night = n;
  if mine.id is not null and (mine.left_at is not null or public.bc_still_expired(mine)) then
    mine := null;                                  -- pressed Leave, or did not answer "Still here?" in time
  end if;
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
    'presences', pres, 'last_night', last, 'server_time', extract(epoch from now()),
    'still_due', mine.id is not null and open and public.bc_still_due(mine),
    'still_deadline', case when mine.id is null then null
                      else extract(epoch from public.bc_still_base(mine) + make_interval(mins => s_after + s_grace)) end);
end $$;

revoke execute on function public.bc_still_base(public.checkins), public.bc_still_due(public.checkins),
  public.bc_still_expired(public.checkins), public.bc_still_sweep(), public.bc_svc_still_targets()
  from public, anon, authenticated;
grant execute on function public.bc_still_sweep(), public.bc_svc_still_targets() to service_role;
revoke execute on function public.bc_still_here() from public, anon;
grant execute on function public.bc_still_here(), public.bc_tonight() to authenticated;
revoke execute on function public.bc_presences(uuid, date) from public, anon, authenticated;

-- Every 5 minutes, when pg_cron (and pg_net for the push) are available. The push call reads the service key from
-- Vault under the name 'bc_service_role_key' (Dashboard > Vault); without it only the sweep runs, and phones get the
-- prompt at their next open.
do $$
begin
  create extension if not exists pg_cron;
  perform cron.schedule('bc-still-sweep', '*/5 * * * *', 'select public.bc_still_sweep()');
  begin
    create extension if not exists pg_net;
    perform cron.schedule('bc-still-push', '*/5 * * * *', $job$
      select net.http_post(
        url := 'https://czrbsjalcjekcslylwbt.supabase.co/functions/v1/still-here',
        headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization',
          'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'bc_service_role_key')),
        body := '{}'::jsonb)
      where exists (select 1 from vault.decrypted_secrets where name = 'bc_service_role_key')
    $job$);
  exception when others then
    raise notice 'pg_net / vault not available: the still-here push is not scheduled (%).', sqlerrm;
  end;
exception when others then
  raise notice 'pg_cron not available: still-here works in queries; no sweep or push schedule (%).', sqlerrm;
end $$;
