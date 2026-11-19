# 🎮 q8-pinball-pour: report (2026-11-19)

Load id 2026-11-19-rules-powers-black-cabin-c2115a. Branch `wk/q8-pinball-pour` (local, not pushed).

## Evidence
- Suites headless, empty APPDATA, worktree after import: 25 of 26 pass; `test_feel` fails only the known buffer walk
  (Tag_mali, pre-existing). `test_minigames` 2072 checks 0 failed; `test_mg_fx` 122/0; `test_neon_moth` 41/0.
- Captures (hidden desktop, 1080x1920 and 1920x1080): `docs/art/screens/q8-pinball-pour/` (12 PNG).
- Files: `neon_pinball.gd`, `pour_perfect.gd`, `i18n/strings.csv` (+1 row), capture script. Tests untouched.

## What changed
Pour: pint, tap, stream, rising foam, backdrop; PERFECT pop + line flash + confetti + hit-stop; spill foam + sparks;
relaxed = band x1.5, flow -20 %. Pinball: playfield, bumpers, flippers, ball, letters + additive glow; bumper hit-stop
and pop; letter pops; ball trail; drain shake; relaxed = ball save 15 s, tilt +1. Payouts unchanged.

## Open
Competition hook (mg_rivals) left for the rivals worker. No tests added for relaxed values.
