-- Gameplay telemetry: ready-to-run queries for the morning after (Daniele 2026-11-20: "tmr we look at the results
-- and adjust"). Table public.play_events (supabase/migrations/20261120000001_play_events.sql), filled by
-- game/scripts/play_telemetry.gd. Run in the Supabase SQL editor of project czrbsjalcjekcslylwbt (bc-tamagotchi-presence),
-- or through the Supabase connector's execute_sql. Each block is one query; change the window in `since` (default:
-- the last 24 hours). Test rows: player_name 'curl-test' and device 'curl' / 'windows' are excluded below.
--
-- Event shapes (column `data`):
--   mg_start       {difficulty}
--   mg_end         {score 0..100, duration_s, reason, misses, best, difficulty, tier, reached{level, gates, lives_left, ...}}
--                  reason: lost | quit (pause menu Leave) | closed (round never finished: app or tab closed) |
--                          timer | sign_end (Neon Moth reached the sign) | arrived (Soi Dash) | complete
--   venue_session  {length_s, games, reason: left | closed}


-- 0. Sanity: what arrived, per kind and build.
with since as (select now() - interval '24 hours' as t)
select kind, build, count(*) as rows, count(distinct player_id) as players, min(at) as first, max(at) as last
from public.play_events, since
where at > since.t and coalesce(device, '') not in ('curl', 'windows') and coalesce(player_name, '') <> 'curl-test'
group by kind, build order by kind, build;


-- 1. Per game: plays, finished rounds, median / p90 score and duration, personal bests.
with since as (select now() - interval '24 hours' as t),
ev as (select * from public.play_events, since
       where at > since.t and coalesce(device, '') not in ('curl', 'windows') and coalesce(player_name, '') <> 'curl-test')
select s.game,
  s.starts,
  count(e.*) as ends,
  s.starts - count(e.*) as never_ended,
  percentile_cont(0.5) within group (order by (e.data->>'score')::numeric) as score_median,
  percentile_cont(0.9) within group (order by (e.data->>'score')::numeric) as score_p90,
  round(avg((e.data->>'score')::numeric), 1) as score_mean,
  percentile_cont(0.5) within group (order by (e.data->>'duration_s')::numeric) as duration_median_s,
  percentile_cont(0.9) within group (order by (e.data->>'duration_s')::numeric) as duration_p90_s,
  count(*) filter (where (e.data->>'best')::boolean) as new_bests,
  count(distinct e.player_id) as players
from (select game, count(*) as starts from ev where kind = 'mg_start' group by game) s
left join ev e on e.kind = 'mg_end' and e.game = s.game
group by s.game, s.starts
order by s.starts desc;


-- 2. How rounds end, per game: lost / quit / closed / timer / sign_end / arrived / complete (count and share).
with since as (select now() - interval '24 hours' as t)
select game, data->>'reason' as reason, count(*) as rounds,
  round(100.0 * count(*) / sum(count(*)) over (partition by game), 1) as pct_of_game,
  percentile_cont(0.5) within group (order by (data->>'score')::numeric) as score_median,
  percentile_cont(0.5) within group (order by (data->>'duration_s')::numeric) as duration_median_s
from public.play_events, since
where kind = 'mg_end' and at > since.t and coalesce(device, '') not in ('curl', 'windows') and coalesce(player_name, '') <> 'curl-test'
group by game, data->>'reason'
order by game, rounds desc;


-- 3. Where people quit or lose: seconds into the round and how far they got (the `reached` numbers), per game.
--    Bucketed in 10 s steps; `reached_example` shows one typical reached{} of the bucket.
with since as (select now() - interval '24 hours' as t)
select game, data->>'reason' as reason,
  (floor((data->>'duration_s')::numeric / 10) * 10)::int as from_s,
  count(*) as rounds,
  round(avg((data->>'misses')::numeric), 1) as misses_mean,
  round(avg((data->'reached'->>'gates')::numeric), 1) as gates_mean,
  round(avg((data->'reached'->>'level')::numeric), 1) as level_mean,
  (array_agg(data->'reached' order by at desc))[1] as reached_example
from public.play_events, since
where kind = 'mg_end' and data->>'reason' in ('quit', 'lost', 'closed')
  and at > since.t and coalesce(device, '') not in ('curl', 'windows') and coalesce(player_name, '') <> 'curl-test'
group by game, data->>'reason', from_s
order by game, reason, from_s;


-- 4. Misses at the end, per game and reason (how hard does it feel).
with since as (select now() - interval '24 hours' as t)
select game, data->>'reason' as reason,
  percentile_cont(0.5) within group (order by (data->>'misses')::numeric) as misses_median,
  percentile_cont(0.9) within group (order by (data->>'misses')::numeric) as misses_p90,
  count(*) as rounds
from public.play_events, since
where kind = 'mg_end' and at > since.t and coalesce(device, '') not in ('curl', 'windows') and coalesce(player_name, '') <> 'curl-test'
group by game, data->>'reason'
order by game, rounds desc;


-- 5. By player: rounds, games tried, median score, how often they lost or quit, best scores per game.
with since as (select now() - interval '24 hours' as t),
e as (select * from public.play_events, since
      where kind = 'mg_end' and at > since.t and coalesce(device, '') not in ('curl', 'windows') and coalesce(player_name, '') <> 'curl-test')
select coalesce(nullif(player_name, ''), left(player_id::text, 8)) as player,
  max(device) as device,
  count(*) as rounds,
  count(distinct game) as games_tried,
  percentile_cont(0.5) within group (order by (data->>'score')::numeric) as score_median,
  count(*) filter (where data->>'reason' = 'lost') as lost,
  count(*) filter (where data->>'reason' in ('quit', 'closed')) as quit_or_closed,
  jsonb_object_agg_strict(game, best) as best_by_game
from (select e.*, max((data->>'score')::int) over (partition by player_id, game) as best from e) x
group by player, player_id
order by rounds desc;


-- 6. Per player and game: every round in order (the detail behind a surprising number).
with since as (select now() - interval '24 hours' as t)
select coalesce(nullif(player_name, ''), left(player_id::text, 8)) as player, game, client_at,
  (data->>'score')::int as score, (data->>'duration_s')::numeric as secs, data->>'reason' as reason,
  (data->>'misses')::int as misses, (data->>'best')::boolean as best, data->'difficulty' as difficulty, data->'reached' as reached
from public.play_events, since
where kind = 'mg_end' and at > since.t and coalesce(device, '') not in ('curl', 'windows') and coalesce(player_name, '') <> 'curl-test'
order by player, game, client_at;


-- 7. Venue visits: length and minigames played per visit, per player.
with since as (select now() - interval '24 hours' as t)
select coalesce(nullif(player_name, ''), left(player_id::text, 8)) as player, count(*) as visits,
  round(avg((data->>'length_s')::numeric) / 60, 1) as minutes_mean,
  round(max((data->>'length_s')::numeric) / 60, 1) as minutes_max,
  sum((data->>'games')::int) as games_played,
  count(*) filter (where data->>'reason' = 'closed') as closed_mid_visit
from public.play_events, since
where kind = 'venue_session' and at > since.t and coalesce(device, '') not in ('curl', 'windows') and coalesce(player_name, '') <> 'curl-test'
group by player order by visits desc;


-- 8. Devices: rounds and median score per device class (does a slow phone lose more?).
with since as (select now() - interval '24 hours' as t)
select device, count(*) as rounds, count(distinct player_id) as players,
  percentile_cont(0.5) within group (order by (data->>'score')::numeric) as score_median
from public.play_events, since
where kind = 'mg_end' and at > since.t and coalesce(device, '') not in ('curl', 'windows') and coalesce(player_name, '') <> 'curl-test'
group by device order by rounds desc;
