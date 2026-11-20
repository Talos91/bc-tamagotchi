-- Gameplay telemetry (Daniele 2026-11-20: "implement telemetry for people playing seeing when they lose and such
-- tonight then tmr we look at the results and adjust"). Minigame starts and ends and venue visits, batched by the
-- client (game/scripts/play_telemetry.gd) and sent through Presence. Same terms as perf_reports (Daniele 11-19:
-- "auto", not anonymous): the player's name, build SHA and a coarse device class, nothing else personal. Kept 90
-- days. Read with docs/tech/telemetry-queries.sql (service role / SQL editor only; players read only their own rows).

create table public.play_events (
  id bigint generated always as identity primary key,
  player_id uuid references auth.users (id) on delete cascade,
  at timestamptz not null default now(),          -- when the server stored it
  client_at timestamptz,                          -- when it happened on the phone (queued events arrive later)
  kind text not null check (kind in ('mg_start', 'mg_end', 'venue_session')),
  game text check (char_length(game) <= 40),
  player_name text check (char_length(player_name) <= 40),
  build text check (char_length(build) <= 40),
  device text check (char_length(device) <= 60),
  data jsonb not null default '{}'::jsonb check (pg_column_size(data) < 4096)
);
comment on column public.play_events.data is 'mg_start: difficulty. mg_end: score, duration_s, reason, misses, best, difficulty, reached{...}. venue_session: length_s, games, reason';
create index on public.play_events (at);
create index on public.play_events (kind, game, at);
create index on public.play_events (player_id, at);
alter table public.play_events enable row level security;
create policy own_play on public.play_events for select to authenticated using (player_id = auth.uid());
revoke insert, update, delete, truncate on public.play_events from anon, authenticated;

-- Insert a batch (an array of {kind, game, client_at, player_name, build, device, data}) as the signed-in player.
-- At most 50 per call and 3000 a day per player; rows with a bad kind are skipped, not fatal.
create or replace function public.bc_play_events(p_events jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); e jsonb; n int := 0; ca timestamptz;
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  if jsonb_typeof(p_events) <> 'array' or jsonb_array_length(p_events) > 50 then
    return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'events must be an array of at most 50');
  end if;
  if (select count(*) from public.play_events where player_id = uid and at > now() - interval '1 day') >= 3000 then
    return jsonb_build_object('ok', false, 'reason', 'limit');
  end if;
  for e in select * from jsonb_array_elements(p_events) loop
    if jsonb_typeof(e) <> 'object' or coalesce(e->>'kind', '') not in ('mg_start', 'mg_end', 'venue_session') then
      continue;
    end if;
    begin
      ca := to_timestamp((e->>'client_at')::double precision);
    exception when others then
      ca := null;
    end;
    insert into public.play_events (player_id, client_at, kind, game, player_name, build, device, data)
    values (uid, ca, e->>'kind', left(e->>'game', 40), left(e->>'player_name', 40), left(e->>'build', 40),
      left(e->>'device', 60), case when jsonb_typeof(e->'data') = 'object' and pg_column_size(e->'data') < 4096
        then e->'data' else '{}'::jsonb end);
    n := n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'stored', n);
end $$;
revoke execute on function public.bc_play_events(jsonb) from public, anon;
grant execute on function public.bc_play_events(jsonb) to authenticated;

-- Retention: play events (90 days) join the daily cleanup.
create or replace function public.bc_retention() returns void
language sql security definer set search_path = '' as $$
  delete from public.checkin_attempts where at < now() - interval '1 day';
  delete from public.checkins where night < public.bc_night() - 90;
  delete from public.tablemates where night < public.bc_night() - 90;
  delete from public.events where read_at < now() - interval '30 days' or at < now() - interval '90 days';
  delete from public.push_log where at < now() - interval '30 days';
  delete from public.reports where at < now() - interval '1 year';
  delete from public.perf_reports where at < now() - interval '90 days';
  delete from public.play_events where at < now() - interval '90 days';
$$;
revoke execute on function public.bc_retention() from public, anon, authenticated;
