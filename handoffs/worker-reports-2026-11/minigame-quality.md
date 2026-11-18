# Report: 🎲 design-quality (owner item 38), 2026-11-18

## Evidence
- Commit 80a1038 (local, not pushed): `docs/design/11-minigame-quality.md` + `docs/art/screens/minigame-quality/`
  (neon-moth-today-vs-target.jpg, result-today-vs-target.jpg, art-options-a-b-c.jpg, neon-moth-target-clean.png,
  make_mocks.py). Report/role-note commit follows this file.
- Hub cards (items): minigame-quality-plan (370), minigame-quality-sound (371), minigame-quality-sound-style (372),
  minigame-quality-art (373), minigame-quality-order (374), minigame-quality-compete (375, multi),
  minigame-quality-practice (376). Pictures uploaded: /_blob/1992bd17..., /_blob/4afe0818..., /_blob/29ec7e4e...
- Load id 2026-11-18-rules-powers-black-cabin-f19e92.

## Recommendations
- Art B (voxel sprites rendered from the Blender kit, glow sprites, blurred venue backdrop); sound: effects only,
  mixed style (arcade on the cabinet, real-bar foley elsewhere); order: juice kit Q1 + venue pause Q2, then Neon Moth
  (Q3 look, Q4 feel/ramp/compete) as the template for Daniele to accept, then Coaster Flip, Soi Dash, Shake & Serve,
  pinball + Pour Perfect, Rhythm + Candle Talk; competition: louder best, seeded regular to beat, ghost, lounge board;
  no practice rounds.

## Not checked
- No Godot run, no game code read beyond the minigame scripts; mock-ups are drawings, not captures.
- Haptics finding (`OS.has_feature("mobile")` false on web) from Godot's feature-tag rules, not tested on a phone.
- Memory numbers are estimates from texture sizes plus LOG's emulated figures; no phone measurement.
- Compatibility-renderer 2D glow on iOS not tested (plan avoids it).
- Scorecard scores are judged from code and v0.3.0 captures, not from play.
- No LOG.md line written (LOG is the orchestrator's file).

## Profile note
- Loaded as rules-powers (a build profile); a design-only job fits a "design" profile better if one exists.
