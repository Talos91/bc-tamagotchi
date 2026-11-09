# 🎨 Character creator — role note (2026-11-09)

Session local_ea874820 (Opus), voxel-art profile, load id 2026-11-09-voxel-art-black-cabin-bca013 (vault server down
at phase 2 start: same load id kept). Phase 1 (design) 083e0c8; phase 2 (build) this note's commit.

## State now
- Built per `docs/design/07-character-creator.md` §10 and DECISIONS 2026-11-09 (all as recommended; Q8 = photo booth).
  - Record: `game/scripts/avatar.gd` + `game/data/avatar.json` (options, legacy look = patron_06 with beard, name rules,
    greeters). `needs.gd`: `has_avatar / avatar / is_new_character / set_avatar` (calls `set_personality`, writes
    `display_name`). `save.gd`: comment only, VERSION unchanged.
  - Figure: `PatronFigure.set_look({"avatar": rec})` loads one parts library, prunes and recolours it before it enters
    the tree (venue.gd's lift sees only kept meshes). `Player.set_avatar()`; `main.gd` applies the saved look.
  - Screen: `game/scripts/ui/character_creator.gd` (portrait / landscape rebuild on resize; hair cards are UPDATE_ONCE
    3D renders; strings `ui.avatar.*` in `strings_ui.csv`).
  - Entries: start screen (new character → creator on first tap; old save → one-time card; Edit look button), photo
    booth (zone `booth` → `main.open_creator()`; prompt `venue.prompt.booth`).
  - Booth: `photo_booth` in `tools/blender/bc_kit.py` (full kit run, deterministic: only manifest + new glb changed),
    `_photo_booth()` in `game/tools/build_venue.gd` at (9.2, 0, 0.55) on the lounge north wall, one entry merged into
    `layout.json` by hand (no export), venue.tscn regenerated (structurally only PhotoBooth + its collider added).
  - Greeter: `VenueSession._greet()` on visit start; Nam and Tt are in the room, Tong and Jules are not placed yet.
  - Suite `test_avatar` (eighteenth); captures `game/tests/capture_char_creator.gd`.

## Next step
Daniele reviews the card `char-creator-build-review`. Later: wardrobe (doc §8), personality idles, Tong/Jules placed so
their greeting fires, server-side name check with presence (item 24).

## Gotchas
- The headless dummy renderer prints "Parameter material is null (material_get_instance_shader_parameters)" while
  materials are duplicated; harmless, not a failure.
- A method named `_set` on a Control clashes with `Object._set`: the creator uses `_pick`.
- `bc_kit.py --only` does not write `manifest.json`: a new kit object needs a full run.
- Tests that start a fresh character with `intro = true` now get the creator on the first tap; give the character a
  look first (`needs.set_avatar(...)`) if a test wants the walk-in.
