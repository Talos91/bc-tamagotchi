# Worker report: 🎮 minigame-ramp (rules-powers), 2026-11-20

Load id 2026-11-20-rules-powers-black-cabin-bb5773. Branch wk/minigame-ramp (worktree C:/Users/itisf/bc-wt/minigame-ramp).

## Evidence
- Tip: see the final message (the last commit only bumps application/config/version to 0.4.2).
- Suites, headless, Godot 4.6.1 console exe, empty APPDATA per suite, after one import (the first import crashed
  3221225477 with no other Godot running; the retry passed): 37 of 37 suite files in game/tests pass (36 in PROJECT
  Tests + test_merch_profile). test_minigames 2582 checks 0 failed; test_neon_moth 184/0; test_coaster_flip 191/0;
  test_shake_serve, test_soi_dash, test_play_telemetry, test_mg_fx, smoke_loop, test_mg_return, test_string_keys pass
  after the last code change (re-run).
- Captures: game/tests/capture_ramp.gd on a private hidden desktop (CreateDesktop; foreground probe godot-owned=0),
  8 PNGs in docs/art/screens/minigame-ramp/, on card minigame-ramp-review (answer "ok", Daniele "ok yes go").
- Cards: minigame-ramp-review (answered ok), minigame-ramp-rivals and minigame-ramp-candle (unanswered; recommended
  options built per Daniele "don t ask for permission").

## What changed
- All 8 minigames endless per docs/design/15-minigame-ramp.md: ramp to a humanly playable cap, 3-strike loss,
  uncapped record points (~100 = a perfect old round); the need gain reads only the first 100 points.
- Base contract (minigame_base.gd): STRIKES, RECORD_FULL, ramp_level, end_reason, record_points(), score_of(), lose(),
  level_up(). mg_rivals SCALE 1.5. Telemetry: extra.level / speed / misses, end_reason "lost".
- Rules beyond the table (built, flag to Daniele): Pinball self-launch after 8 s in the lane, ball save once per ball,
  a ball resting 3 s with no flipper held rolls off (found by the suite: a ball cradled at the right flipper pivot
  never drained); Pour Perfect: a spoiled layer resets the fill to its line, relaxed widens the spoil band and the idle
  wait x1.5, a spill is a strike (the old foam penalty is gone); Front Row Rhythm: a chord passed by = 2 strikes,
  two-finger touch input added (the old input read mouse only, so chords were unplayable on phones).
- Strings: mg.ramp.* + 5 game keys (TH machine drafts), 8 how_to texts rewritten.

## Design-bible line
Every minigame is a record race: no fixed end, it speeds up level by level to a playable cap, and the third strike
ends it; the record has no ceiling, the meters read only the first 100 points.

## Changelog line
Minigames never stop at the sign any more: they get faster and harder until your third miss. Beat your record.

## DECISIONS rows (draft, for the orchestrator)
| 2026-11-20 | Minigames endless: ramp per docs/design/15-minigame-ramp.md, caps as listed, 3 strikes in all 8, uncapped record, need gain reads the first 100 points | Daniele: "ok yes go" (card minigame-ramp-review) |
| 2026-11-20 | Tonight's regulars score x1.5 (mg_rivals SCALE) so the board stays a contest | recommended option, card minigame-ramp-rivals unanswered; Daniele "don t ask for permission" |
| 2026-11-20 | Candle Talk endless too (lines come round again, reply timer 8 -> 4 s, 3 gutters); hearts and the daily reward read the first 5 turns | recommended option, card minigame-ramp-candle unanswered; same |

## Open
- Old capture scripts are stale (q4 errors on reached_sign; q6/q7/q8/q9/rivals_hooks expect a fixed end). Not suites.
- Coaster Flip has no idle loss (never flicking only leaves via pause). Candle Talk has no timer in turns 1-5.
- Not checked on a real phone; two-finger chords in Rhythm verified only by code, not by a device.

## Profile feedback
rules-powers profile fine. Worth adding: when a fixed end or time cap goes, look for idle stalls (a resting ball, a
player who never acts) because the cap was what ended them.
