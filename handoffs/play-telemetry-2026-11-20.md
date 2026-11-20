# Role note: 🎮 play-telemetry (rules-powers), 2026-11-20

Daniele 2026-11-20: "implement telemetry for people playing seeing when they lose and such tonight then tmr we look at
the results and adjust". Worker session play-telemetry-1120, branch wk/play-telemetry (worktree
C:/Users/itisf/bc-wt/play-telemetry), load id 2026-11-20-rules-powers-black-cabin-ea17ea.

## State now
- Supabase table `public.play_events` + RPC `bc_play_events(jsonb)` LIVE on czrbsjalcjekcslylwbt (applied through
  the connector, migration name `play_events`; file `supabase/migrations/20261120000001_play_events.sql`). RLS on,
  players read only their own rows, no direct insert, batch ≤ 50, 3000 a day per player, 90-day retention in
  bc_retention. Test row id 1 (player_name curl-test, device curl) — the query file excludes it.
- Client: `game/scripts/play_telemetry.gd` (autoload PlayTelemetry, after Presence). Hook: one `watch(game, best)`
  call in `minigame_frame.gd::_start_game` + `set_meta("end_reason", "quit")` in `_leave`. Notice line on the start
  screen bottom-left (`ui.start.telemetry`, TH machine draft).
- Queries for tomorrow: `docs/tech/telemetry-queries.sql` (8 blocks; window = last 24 h).
- Suite `test_play_telemetry` (32 checks); add it to PROJECT.md Tests (the orchestrator does).

## For the minigame ramp job (next)
- To report a loss reason, set a property `end_reason` (String) on the game or `set_meta("end_reason", ...)`
  before `finish()`. Values the queries expect: lost, quit, closed, timer, sign_end, arrived, complete.
- `difficulty` (property or config key) is sent with mg_start / mg_end; `level` and `speed` properties and
  `misses` are picked up into mg_end automatically. Lives: singes_left / drops_left / balls_left / lives_left.

## Gotchas
- Inert unless Presence is active (web build; `?presence=off` turns both off). Desktop/headless send nothing.
- A tab closed mid-visit is reported as venue_session reason "closed" on the next start (queue + open visit kept in
  user://play_telemetry.json). A round never finished = mg_start without mg_end (query 1 `never_ended`).
- Turn the Supabase connector off after use (other sessions flip the default).
