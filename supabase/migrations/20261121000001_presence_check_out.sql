-- Leave = check out (Daniele 2026-11-20: "I left but I was still in jack game when I check, when you press leave
-- should auto check out"; 2026-11-21: "any player logging in tonight should see all of us until night is over or we
-- press leave"). A check-in now ends only at the night boundary (bc_night) or when the player presses Leave in the
-- game (bc_check_out): no heartbeat, no expiry, a locked phone or a closed tab stays checked in.
-- The row is kept (tonight's first_of_night, tablemates and the verb history stay right); left_at hides it.
-- A re-scan the same night (bc_check_in updates `at`) clears left_at through the trigger.

alter table public.checkins add column if not exists left_at timestamptz;

create or replace function private.bc_checkins_rescan() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.at is distinct from old.at then
    new.left_at := null;
  end if;
  return new;
end $$;

drop trigger if exists checkins_rescan on public.checkins;
create trigger checkins_rescan before update on public.checkins
  for each row execute function private.bc_checkins_rescan();

create or replace function public.bc_check_out() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  n int;
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  update public.checkins set left_at = now()
  where player_id = uid and night = public.bc_night() and left_at is null;
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'was_in', n > 0);
end $$;

-- Tonight's list without the players who left (and a viewer who left is no longer "here").
create or replace function public.bc_presences(viewer uuid, n date) returns setof jsonb
language sql stable security definer set search_path = '' as $$
  with me as (
    select exists (select 1 from public.checkins where player_id = viewer and night = n and left_at is null) as here
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

revoke execute on function public.bc_check_out() from public, anon;
grant execute on function public.bc_check_out() to authenticated;
revoke execute on function public.bc_presences(uuid, date) from public, anon, authenticated;
