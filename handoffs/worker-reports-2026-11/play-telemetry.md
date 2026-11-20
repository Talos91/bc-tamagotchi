# Report: 🎮 play-telemetry-1120 (rules-powers), 2026-11-20

Load id 2026-11-20-rules-powers-black-cabin-ea17ea. Branch wk/play-telemetry (worktree C:/Users/itisf/bc-wt/play-telemetry), not pushed.
Daniele 11-20: "implement telemetry for people playing seeing when they lose and such tonight then tmr we look at the results and adjust".

## Evidence
- Commits: see the final SHA in the orchestrator message (rebased on origin/main).
- Suites: 32/32 headless with empty APPDATA (31 existing + new `test_play_telemetry`, 32 checks; smoke_start was red once
  on the new footer label and is fixed by excluding it like VersionLabel).
- Supabase (czrbsjalcjekcslylwbt): migration `play_events` applied through the connector: table `public.play_events`, RPC
  `bc_play_events(jsonb)` (authenticated only, ≤ 50 per call, 3000 a day per player), RLS own-row select, direct
  insert revoked, 90-day retention added to bc_retention (live definition checked before replacing). Advisors: only
  the same SECURITY DEFINER / anonymous-sign-in warnings perf_reports already has.
- curl (anon sign-up + RPC): `{"ok": true, "stored": 1}` (the bogus-kind row skipped); direct POST to /rest/v1/play_events
  → 42501 permission denied; RPC without sign-in → 42501. Row id 1 (player curl-test).
- Local web build (tools/build_web.py → C:/Users/itisf/bc-wt/pt-web, served on localhost:8765, built-in browser pane):
  created a player "Telemetry", walked in, reloaded mid-visit → row id 2 `venue_session` {games 0, length_s 23,
  reason closed}, build "v0.4.0 · 885d4f6 · dirty", device "web dpr1 mem32". A minigame round was NOT played in the
  browser (no shortcut to a game; walking a hidden pane is slow); mg_start / mg_end are proven by the suite through the
  real minigame frame and by a headless `--live` run (row id 3, device windows).
- Query file `docs/tech/telemetry-queries.sql`: 8 queries; 1 (per game median/p90), 3 (where people quit/lose) and 5
  (by player) run on the live table.

## What was built
- `game/scripts/play_telemetry.gd` (autoload PlayTelemetry): mg_start {difficulty}; mg_end {score 0..100, duration_s,
  reason lost/quit/closed/timer/sign_end/arrived/complete, misses, best, difficulty, tier, reached{…}}; venue_session
  {length_s, games, reason left/closed}. Every row: player name, build, device class ("ios dpr3 mem4"). Queue on disk
  (user://play_telemetry.json, ≤ 400), sent every 15 s and after each round; offline keeps it; limit/bad data drops
  the batch; inert unless Presence is active.
- Hook: `minigame_frame.gd` 4 lines (watch() at round start, Leave = "quit"). Presence: `play_events()` + mock handler.
- Notice: start screen bottom-centre, "Perf and game results are sent with your name" (`ui.start.telemetry`, TH machine draft).

## Lines for the release worker
- Changelog: "Gameplay telemetry: minigame starts, results and how rounds end, and visit length, are sent with your
  name to tune difficulty (start-screen notice)."
- PROJECT.md Tests: add `test_play_telemetry` (2026-11-20: gameplay telemetry queue, frame hook, offline mock).

## Open
- Thai notice line is a machine draft. Note: there was no existing in-game telemetry notice to extend (perf sends nothing
  automatically yet; its client hook is still pending); this line covers both.
- The ramp job: set `end_reason` / `difficulty` / `level` on games and they flow into the rows (role note).
- Profile note: the rules-powers profile fit; nothing missing.
