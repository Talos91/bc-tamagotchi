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

## Fix brief in flight (orchestrator, 2026-11-09, Daniele's phone test of c495a35; items 26-27 in
## `handoffs/owner-feedback-2026-11-09.md`) — handed to the successor at 40 % context, nothing started yet
26. On the phone, Done and the exit (× / ‹) do not leave the creator. Suspects, in order: `_finish()` refuses the
    name silently when the You tab's error label is not visible (mode edit/name, `tab < 3` path: `_name_err` is null
    until the You tab is built -> a refused default name may crash or show nothing); the LineEdit keeping focus /
    the on-screen keyboard eating the tap; buttons only answering mouse (they are `UI.button`, check
    `emulate_mouse_from_touch`); the panel's Next button off-screen under the browser bar (safe area); on the start
    screen `street_shot._input` swallowing touches while `_modal` is freed but still valid (queue_free). Reproduce:
    `python tools/build_web.py --out <scratch>`, `python -m http.server <fresh port, never 8765>`, browser pane
    375x812 (mobile preset = touch emulation), clear IndexedDB `/userfs` for a new character. Fix, then add to
    `test_avatar`: Done with the default name and with an empty name leaves the creator (or shows the reason), and
    the ×/‹ exit leaves it, from the start screen and from the booth.
27. "no female hair, all characters look male": re-pick the 8 hair styles in `game/data/avatar.json` so at least 3
    read clearly feminine (kit has `long`, `bob`, `bun`, `ponytail`, `chignon`, `wavy`, `curly`); re-cut the 3
    starter looks (kit tops include `blouse`, `dress`; bottoms `skirt`, `dress`): e.g. one look with blouse + skirt
    or the dress. Q10 stands (no gender field). Update `test_avatar` counts if needed; `capture_char_creator.gd`.
Done when: 19/19 suites PASS (the orchestrator counts 19 now: check PROJECT.md Tests), web screenshot at 375x812 of
Done leaving the creator + the new hair row, portrait captures of the 3 looks + hair picker under
`docs/art/screens/char-creator/fix/`, hub card `char-creator-fix-review` (pictures + files), report
`handoffs/worker-reports-2026-11/char-creator-fix.md` (<= 40 lines, EVIDENCE first: SHA, cause of 26, suite table),
this note refreshed, vault capture replies_to the load id, final message to the orchestrator local_7f958171 (first
400 chars: SHA, cause of 26, suites, card id); idle, never archive yourself, do not push. One Godot at a time on
this PC.

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
