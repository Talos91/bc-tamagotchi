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

## Fix (owner items 26-27) DONE by the successor (Opus, load id 2026-11-09-voxel-art-black-cabin-f23bdf)
- 26 cause 1 (9cb6bc9): Done / Into the bar refuses a bad or empty name; at 375x812 the field and reason were below the
  fold of the You tab, and ‹ only stepped back. Now: × top right in every mode leaves; ‹ steps back (new, step 2+); the
  reason shows in `_status` above the button; the name field is the You tab's first row; Next/Done drop the keyboard.
- 26 cause 2 (8368a40): the Web preset has `html/experimental_virtual_keyboard=false` and no input element, so a phone
  never got a keyboard. On a touch web build the name field opens `window.prompt` (JavaScriptBridge), deferred out of
  the LineEdit focus handling (else it re-grabs focus and the test hangs). `use_prompt` / `prompt_name` are test hooks.
- 27 (56aca5c): new kit hairs `long_straight`, `pigtails`, `double_bun` (front-readable); hairs re-picked; look
  `dress` (bottom_follows_top in avatar.gd) replaces `night_out`, which stays hidden for old saves.
- test_avatar: `exits` + `phone name` sections with real touches (`Input.parse_input_event`). Captures
  `docs/art/screens/char-creator/fix/` (`tests/capture_char_creator_fix.gd`). Card char-creator-fix-review.
- Not checked: a real phone (iOS Safari showing window.prompt from the game loop is the open risk).

## Next step
Daniele checks the fix on his phone after the redeploy and answers card `char-creator-fix-review`. Later: wardrobe (doc §8), personality idles, Tong/Jules placed so
their greeting fires, server-side name check with presence (item 24).

## Gotchas
- The headless dummy renderer prints "Parameter material is null (material_get_instance_shader_parameters)" while
  materials are duplicated; harmless, not a failure.
- A method named `_set` on a Control clashes with `Object._set`: the creator uses `_pick`.
- `bc_kit.py --only` does not write `manifest.json`: a new kit object needs a full run.
- Tests that start a fresh character with `intro = true` now get the creator on the first tap; give the character a
  look first (`needs.set_avatar(...)`) if a test wants the walk-in.
- Browser pane hidden = background tab: frames pause and synthetic taps get lost; wait 1.5 s+ between taps, dispatch
  TouchEvents on the canvas (the pane's own clicks are mouse events without a mousemove). Stub window.prompt to test.
- Avatar.data() is cached and mutable: a scratch script can add looks to preview them without touching avatar.json.
