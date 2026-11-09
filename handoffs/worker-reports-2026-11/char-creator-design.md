# Worker report — 🎨 character creator, phase 1 design (2026-11-09)

Session local_ea874820 (Opus) · load id 2026-11-09-voxel-art-black-cabin-bca013 · not pushed (orchestrator pushes docs by SHA)

## Evidence
- Commit **083e0c8**: `docs/design/07-character-creator.md`, `docs/art/screens/char-creator/mock-01-body-skin.png`,
  `mock-02-hair.png`, `mock-03-vibe-name.png`, `tools/mock/char_creator_mock.gd`. Report and role note in the commit after it.
- Mocks: Godot 4.6.1 windowed capture (Compatibility, RTX 5080) of a static mock scene built from
  `parts/parts_<body>.glb` with `BCChars.show_parts` / `recolour`; 1080×1920 each, saved with err=0. They show the lite
  counts (3 bodies, 6 skins, 4 hair styles); not the final UI.
- Hub card **`char-creator-design-review`** (items, version 1, kind design, multi): Q1–Q11 as options with rec, 3 images
  (`/_blob/ac78e3af…`, `/_blob/0ad78a1f…`, `/_blob/25b108b8…`), 4 files.
- No suites run: no game code changed. No `rules.gd`, `save.gd`, `layout.json`, script or version edits.

## Findings (measured)
- Player today = preset `patron_06` (broad, square head, shaggy, beard, moss tee); the look colours in `player.gd` only
  feed the box fallback. Same model as a crowd patron.
- `needs.set_personality()` has no caller (every save has personality ""); `profile.display_name` is never written.
- Kit covers creator lite with zero new modelling: 4 bodies, 8 skins, 4 heads, 5/5/5 face parts, 17 hairs, 10 hair
  colours, 15 tops / 5 bottoms / 3 shoes. Parts libraries are 1.37 MB each (README says 0.85).
- In the mock the three lite bodies look almost the same at thumbnail size; `tall` is the one distinct silhouette.

## Design in one paragraph
Four tabs on one portrait screen (Body · Hair · Outfit · You), live 3D preview with drag-to-turn and "Surprise me",
under 60 s with defaults. Avatar record `profile.avatar` (ids and swatch names, own `v`, `worn` = wardrobe hook);
personality stays in `needs.personality`, name in `profile.display_name`; no save VERSION bump. Old saves keep the
patron_06 look until a one-time card. Runtime: `PatronFigure.set_look({"avatar": record})` → library + show_parts +
recolour, then a lean node for phones. Wardrobe needs generator work later (hat hair trims, outer-layer split, voxel
merch prints).

## Owner calls (on the card)
Q1 bodies (rec 4 incl. tall) · Q2 skins (rec 8) · Q3 hair (rec 8×8) · Q4 face (rec 4 heads + 3 sets) · Q5 outfits
(rec 3 looks × 6 top colours) · Q6 personality change (rec free) · Q7 old saves (rec one-time card) · Q8 Edit look
(rec start screen + menu) · Q9 name rules · Q10 no gender field · Q11 greeters Jules/Tong/Tt/Nam.

## Not verified
Real phone, web build memory and load, Thai strings, landscape layout (described only, no mock).

## Profile feedback
voxel-art profile fits; its "regenerate the set / review .blend" steps do not apply to a design-only phase.
