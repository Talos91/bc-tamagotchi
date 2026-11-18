# Role note: 🎲 design-quality (minigame quality pass, owner item 38), 2026-11-18

Session local_c382941d (Opus 5.5). Load id 2026-11-18-rules-powers-black-cabin-f19e92. Design only, no game code.

## State now
- Plan: `docs/design/11-minigame-quality.md` (commit 80a1038): look options A/B/C (rec B voxel sprites from the
  Blender kit), iPhone budget (<= 6 MB GPU per open game, no full-screen shaders, CPUParticles2D), shared juice kit,
  per-game ramps, offline competition (louder best, seeded regular to beat, ghost run, lounge board, optional streak),
  T2 list, scorecard, build jobs Q1-Q11.
- Mock-ups: `docs/art/screens/minigame-quality/` (drawings from existing captures via `make_mocks.py`; no Godot run).
- Hub: card `minigame-quality-plan` (order 370) + questions `minigame-quality-sound`, `-sound-style`, `-art`,
  `-order`, `-compete` (multi), `-practice` (orders 371-376). All unanswered at 2026-11-18.

## Next step
- Orchestrator reads the answers, copies them to DECISIONS.md, then briefs Q1 (juice kit) and Q2 (venue pause)
  after 0.3.1 is verified; Q3/Q4 (Neon Moth look + feel) after the art and sound answers.

## Gotchas
- Haptics: every game guards `Input.vibrate_handheld` with `OS.has_feature("mobile")`, which (per Godot feature tags)
  is not set on web exports, so vibration never fires live. Not checked on a phone. iOS WebKit has no Vibration API.
  `minigame_frame.gd` line 96 uses the same test for the keyboard.
- Coaster Flip and Soi Dash files belong to fix-031 until 0.3.1 is verified.
- "Tonight's regular to beat" must read as the cast, never as real players (offline has no other players).
