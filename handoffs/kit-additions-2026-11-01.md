# Kit v4 additions (🧱 kit session, 2026-11-01) — state

Commits on `main`: f9380b5 (generator, 30 GLBs, manifest), 0fc2320 (review blends, contact sheet).
Contact sheet: `docs/art/screens/kit/kit-v4-additions.png`. Review files: `blender/BlackCabinKit.blend` (opened headless
after the run: 90 meshes, 90 labels, 8 zone collections, all 30 new names present), `blender/BlackCabin.blend`
(regenerated with `bc_review.py -- --no-render`; the still `docs/art/review-overview.png` was not rewritten).

## What exists now
`game/assets/kit/manifest.json` lists 90 objects (60 before). Every object below has a GLB, a footprint and a height.
Pivot: bottom centre of the footprint; front (room side) = Godot +Z / Blender -Y, as for the rest of the kit.

| zone (= folder) | objects |
|---|---|
| `buffer` | `tall_table_square` 0.6×0.6×1.05, `tall_table_round` (variant), `tall_stool` 0.35×0.35×0.75, `window_wall_panel` 1.0×0.1×4.0, `mirror_wall_panel` 1.0×0.1×2.5, `par_on_stand` 0.65×0.6×2.05, `outdoor_tree_bare` 2.15×1.15×3.1 |
| `raised` | `couch_long` 1.0×0.7×0.95 (tiles along X, back at -Z, Neon Red strip under the seat), `shelf_wall_tile` 1.0×0.3×1.0 (wall, mount 1.1 m, tiles X and Y), `raised_edge_neon` 1.0×0.2×0.15 (the riser face; the platform top is the venue generator's) |
| `tables` | `tiny_table` 0.5×0.5×0.7 (stools: `drum_stool`) |
| `bar` | `cashier_counter` 1.1×0.65×1.5 (its +Z… i.e. Blender +y back joins `bar_counter`; customers on the other three sides), `reindeer_head` 0.8×0.65×1.6 (wall, mount 1.5 m), `wine_fridge` 0.5×0.55×1.0, `lightbox_bc` 0.7×0.15×0.65 (sits on the fridge) |
| `lounge` | `game_cabinet_bc` 0.7×0.75×1.8, `pinball_machine` 0.7×1.45×1.65 (long axis = depth, player at the front) |
| `circulation` | `red_door` 1.0×0.15×2.15, `emergency_door` 1.75×0.2×2.4 (EXIT sign included), `sticker_door` 1.0×0.15×2.15, `staff_door` 1.0×0.15×2.15, `wall_picture_framed` 0.5×0.1×0.7 (wall 1.4 m), `wall_picture_framed_b` 0.7×0.1×0.5 (variant, wall 1.5 m), `picture_light` 0.4×0.2×0.1 (wall 2.0 m), `vinyl_record_wall` 0.4×0.1×0.6 (wall 1.3 m) |
| `smoke` | `smoke_table_square` 0.8×0.7×0.75, `smoke_table_round` 0.7×0.7×0.5 (variant), `wishbone_chair` 0.45×0.45×0.8, `ashtray` 0.15×0.15×0.1, `air_purifier` 0.3×0.3×0.7 |

Doors carry `note: "stands in a wall opening; room side -y"`: they are frame + leaf, 0.15 m deep, to be dropped into a
gap the venue generator leaves in the wall; hinge side +X, handle at -X.

## Calls I made (reversible, flag to Daniele if wrong)
- `lightbox_bc` shows "BC" in the kit's 5×7 pixel font, black on the lit red face, with the small skull on top. The full
  "BLACK CABIN" does not fit a 0.7 m box at 5 cm voxels (it would need ~1.5 m, as the lounge `neon_sign` does).
- `game_cabinet_bc` marquee is a pixel skull on Panel Red (no text); the screen is sky, two green pipes, a yellow bird.
- Hairpin legs are two 1-voxel steel rods per corner (8 per table); `SteelDark` was lightened to #6A6A72 so they do not
  read as black under the room light.
- `outdoor_tree_bare` is 3.1 m and 3.1k tris (the `line()` branches do not merge well). It is meant to stand outside the
  glass, one or two instances; do not scatter it.
- 17 new palette swatches (marked "v4" in `PALETTE`: StoneDark, GlassNight, GlassRib, FurBrown/FurLight/HornDark,
  TeakPale, WeaveCream, SteelDark, DoorRed, ScreenSky/Green/Yellow, BackglassBlue, PaperWhite, PrintGrey) are not in
  the art bible yet; same status as the "derived" ones.
- New zones `buffer`, `raised`, `smoke` only affect the manifest `zone`, the GLB folder and the review grid; the venue
  generator keys objects by name.

## Not done / debt
- No Godot import or showcase refresh was run (`build_showcase.gd` / `capture_showcase.gd`); the venue session's
  `build_venue.gd` run will import the new GLBs. Nothing under `game/scripts`, `layout.json` or `build_venue.gd` was touched.
- `git pull --rebase` refused because of other sessions' unstaged files in the shared checkout (see LOG); commits are
  local on `main` until the orchestrator pushes.
- `tools/blender/__pycache__/` is still untracked (root `.gitignore` is not mine).
