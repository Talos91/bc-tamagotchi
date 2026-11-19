-- Perf telemetry beacon (hub card telemetry-beacon, Daniele 2026-11-19: "auto"; "no need to be anonymous all my
-- friends know is tracked right now"). One report per visit, sent automatically by the client at the end of a visit
-- (client hook later). Kept 90 days. Contract: docs/design/08b-presence-api.md §3.7.

create table public.perf_reports (
  id bigint generated always as identity primary key,
  player_id uuid references auth.users (id) on delete cascade,
  at timestamptz not null default now(),
  version text not null check (char_length(version) <= 40),
  device jsonb not null default '{}'::jsonb check (pg_column_size(device) < 4096),
  numbers jsonb not null default '{}'::jsonb check (pg_column_size(numbers) < 16384)
);
comment on column public.perf_reports.device is 'user agent, GPU, pixel ratio, screen/canvas, cores, memory class, phone parts';
comment on column public.perf_reports.numbers is 'fps p50/p5 overall and per area, spikes, draws, video MB, load times, quality changes';
create index on public.perf_reports (at);
create index on public.perf_reports (player_id, at);
alter table public.perf_reports enable row level security;
create policy own_perf on public.perf_reports for select to authenticated using (player_id = auth.uid());
revoke insert, update, delete, truncate on public.perf_reports from anon, authenticated;

-- Insert one report as the signed-in player; at most 30 a day per player.
create or replace function public.bc_perf_report(p_version text, p_device jsonb, p_numbers jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); rid bigint;
begin
  if uid is null then return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'no auth'); end if;
  if jsonb_typeof(coalesce(p_device, '{}')) <> 'object' or jsonb_typeof(coalesce(p_numbers, '{}')) <> 'object' then
    return jsonb_build_object('ok', false, 'reason', 'server', 'detail', 'device and numbers must be objects');
  end if;
  if (select count(*) from public.perf_reports where player_id = uid and at > now() - interval '1 day') >= 30 then
    return jsonb_build_object('ok', false, 'reason', 'limit');
  end if;
  insert into public.perf_reports (player_id, version, device, numbers)
  values (uid, left(coalesce(p_version, ''), 40), coalesce(p_device, '{}'), coalesce(p_numbers, '{}'))
  returning id into rid;
  return jsonb_build_object('ok', true, 'id', rid);
end $$;
revoke execute on function public.bc_perf_report(text, jsonb, jsonb) from public, anon;
grant execute on function public.bc_perf_report(text, jsonb, jsonb) to authenticated;

-- Retention: add perf reports (90 days) to the daily cleanup.
create or replace function public.bc_retention() returns void
language sql security definer set search_path = '' as $$
  delete from public.checkin_attempts where at < now() - interval '1 day';
  delete from public.checkins where night < public.bc_night() - 90;
  delete from public.tablemates where night < public.bc_night() - 90;
  delete from public.events where read_at < now() - interval '30 days' or at < now() - interval '90 days';
  delete from public.push_log where at < now() - interval '30 days';
  delete from public.reports where at < now() - interval '1 year';
  delete from public.perf_reports where at < now() - interval '90 days';
$$;
revoke execute on function public.bc_retention() from public, anon, authenticated;

-- Daily at 04:17 Bangkok (21:17 UTC), when pg_cron is available.
do $$
begin
  create extension if not exists pg_cron;
  perform cron.schedule('bc-retention', '17 21 * * *', 'select public.bc_retention()');
exception when others then
  raise notice 'pg_cron not available: run select public.bc_retention() by hand (%).', sqlerrm;
end $$;
