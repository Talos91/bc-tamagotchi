# 🎨 Character creator — role note (2026-11-09)

Session local_ea874820 (Opus), voxel-art profile, load id 2026-11-09-voxel-art-black-cabin-bca013. Phase 1 (design) done.

## State now
- Design v1: `docs/design/07-character-creator.md` (commit 083e0c8). Mocks: `docs/art/screens/char-creator/mock-0{1,2,3}-*.png`
  (1080×1920), built by `tools/mock/char_creator_mock.gd` (review only; run with a GPU window:
  `Godot --path game --resolution 270x480 --script "<abs>/tools/mock/char_creator_mock.gd" -- "<abs out dir>"`).
- Hub card `char-creator-design-review` (Questions tab, multi-select): Q1–Q11 with recommendations, 3 pictures, files.
- No game code, `rules.gd`, `save.gd`, `layout.json` or version touched.

## Next step (phase 2, new brief after Daniele's answer)
Order in doc §10: data file `game/data/avatar.json` + `profile.avatar` record + legacy migration + `test_avatar` →
`PatronFigure` avatar form + lean node → creator screen (portrait + landscape, EN/TH) + Edit look + one-time card →
greeter order → captures and card.

## Gotchas
- The player is drawn as `patron_06` today (broad, beard): the legacy default must reproduce it exactly, beard included.
- `needs.set_personality()` has no caller; `profile.display_name` is never written. Both are wired by the creator.
- Parts libraries are 1.37 MB each (the README says 0.85): load one body at a time on the web build.
- Library hats do not trim hair (presets trim at build time): hats need generator work before the wardrobe.
- GDScript in the mock: typed `var x: T = [...][i]`, and `look_at_from_position` before the node is in the tree.
