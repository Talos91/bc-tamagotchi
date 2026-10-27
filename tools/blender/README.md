# Blender kit pipeline

## Tooling on Daniele's PC (checked 2026-10-27)

| Tool | Found |
|---|---|
| Blender | **5.2.2 LTS** at `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` (not on PATH) |
| Blender MCP add-on | `blender_mcp.py` installed in `%APPDATA%\Blender Foundation\Blender\5.2\scripts\addons\` (the bridge Ooze Syndicate used). No Blender MCP tools were connected to the session that wrote this, so the kit was built headless; the script also runs inside Blender through the bridge (`exec(open(...).read())`, the Ooze pattern) |
| Godot | 4.6.1 from `H:\My Drive\PROJECTS\Ooze Syndicate\Tools\Godot\Godot_v4.6.1-stable_win64.exe` (not on PATH) |

Approach copied from Ooze Syndicate's `Models/2.0/build_kit_2_0.py`: one script, a palette dict that becomes
materials, one builder, every run rebuilds the whole kit from scratch. Ooze used bmesh primitives with bevels;
this kit uses a voxel grid instead (art bible section 2: no bevels, no smoothing).

## Run

From the repo root (about 5 s for the whole kit):

```
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python tools/blender/bc_kit.py
```

`-- --only round_table,bar_stool` rebuilds just those objects (and leaves `manifest.json` and the .blend alone);
`-- --no-blend` skips the review file; `-- --out <dir>` writes the GLBs and manifest somewhere else (tests, no .blend).

**Open in Blender:** `blender/BlackCabinKit.blend` (repo root), written by every full run. It has one collection
per zone with a text label under each object, a dark world, warm lights, a camera framing the whole grid, and the
viewport set to Material Preview with scene lights and world.
Then refresh the Godot showcase and its still, from `game/`:

```
godot --headless --path . --import
godot --headless --path . --script res://assets/kit/build_showcase.gd
godot --path . --script res://assets/kit/capture_showcase.gd
```

The capture needs a GPU window (not `--headless`); it writes `docs/art/kit-showcase.png` and prints how one
material came through the importer (vertex colour, seam texture, emission energy, cull mode).

## What `bc_kit.py` does

- **Voxel grid.** `Vox` is a sparse dict of integer cells -> material key, with `box`, `cyl` (stepped pixel
  circles, square below diameter 5), `sphere`. One voxel = **0.05 m** (`VOX`), the art bible scale.
- **Meshing (v2).** Only exposed faces, merged greedily: per plane, coplanar faces of the same material become
  maximal rectangles. Floor-anchored objects drop their bottom faces. This cut the 35 v1 objects from 114,822
  to 12,532 triangles (-89%) and 9.6 MB to 1.1 MB without changing the look, because jitter and seam now live
  in the texture (below), not in the vertices.
- **Palette.** `PALETTE` holds the bible's section 3 *Game* hexes with roughness, metallic and emissive strength.
  A key ending in `_emissive` makes an emissive material with that name; Godot imports it with
  `emission_enabled` and `emission_energy_multiplier` from `KHR_materials_emissive_strength`.
- **Surface finish (v2).** One 256 px texture, `bc_seam`, tiles 16 x 16 voxels at 16 px per voxel: each cell has
  its own value jitter of -2..+2 steps (3.5% each) and a 1 px dark seam on its border. UVs are in voxel units on
  the object's voxel grid, offset per plane by a hash, so a merged rectangle still shows one jittered, seamed
  cube per voxel and neighbouring planes do not repeat the same pattern. White tile (`ColumnWhite`) uses
  `bc_seam2`: jitter and seams on a 2 x 2 grid (bible section 5). The texture stores jitter / 1.07 and the
  material's base colour factor is the swatch x 1.07, so the mean colour is unchanged. No vertex colours any
  more (v1 used `COLOR_0`), so Godot imports `vertex_color_use_as_albedo = false`; that is expected.
  Emissive materials have no texture and no jitter.
- **Export.** One GLB per object at `game/assets/kit/<zone>/<object>.glb`, Y-up, origin at the centre of the
  footprint on the floor (`anchor: floor`) or at the top mount point (`anchor: ceiling`: disco ball, beam,
  ceiling panel, track light). Front faces **+Z in Godot** (-Y in Blender). Backface culling on.
- **Manifest.** `game/assets/kit/manifest.json`: name, zone, size class, anchor, `res://` path, footprint and
  height in metres, size in voxels, emissive yes/no, material list, voxel count, `tris` (merged) and
  `tris_unmerged` (one quad per voxel face, the v1 count). Optional, only where they apply: `mount: "wall"`
  (origin still at the bottom centre, back face against the wall at -Z in Godot) with `mount_height_m` (a
  suggested height for the origin), `variant_of` (the object it swaps with), `note`.

Zones follow the bible's section 6 headings: `bar`, `tables`, `stage`, `lounge`, `circulation`
(Stairs and circulation). Room height is 4 m / 80 voxels (`ROOM_H`, DECISIONS 2026-10-27 (j)): column and
curtain bay are floor to ceiling. Stage 0.5 m (platform 9 voxels + carpet tile 1), stairs 12 steps of
0.2 m x 0.3 m, 1.6 m wide, bar counter 1.1 m.

## Kit v2 (2026-10-27)

Added (17): `banquette_straight` (1 m module) and `banquette_corner` (inside corner; the run on its -y side is
a straight module rotated -90 deg about the vertical), `stage_steps` (two carpeted treads up to the 0.5 m stage),
`truss_segment` (2 m black box truss, ceiling) with `par_light_red` / `_amber` / `_blue` (ceiling, hang under
the truss), `stage_tree` (the olive tree, 5843), `pa_speaker` (with a hanging yoke), `ac_unit`, `wall_lamp`
(red disc, 5843-5845) and `painting_a/b/c` (wall), `soffit_segment` (bar light soffit, ceiling),
`floor_tile_a/b` (1 m concrete, seamless, two mottling variants).

Fixed: wood un-lit (browner, less saturated, see the palette comment); plant wall as leaf clusters on vines
with gaps, top-lit in three greens, wrapping at the tile edge; drum kit with bigger shells, hoops, lugs, bells,
tripod feet and a ringed kick head inside the v1 box; guitar 3 voxels thick with neck, frets and hardware
inside the v1 box; disco ball tiles in three mirror values with red and amber reflections clustered by side
(mirror metallic 0.7 -> 0.3, it read black without a reflection probe).

Changed for existing objects (integration must adjust): `white_column` and `curtain_panel` are 80 voxels tall
(4 m), were 70. All other names, origins and footprints are as in v1.

## Deviations from the bible (need sign-off)

- **Derived swatches** not in the bible's palette: three bottle tints with caps, `MirrorGrey`/`MirrorLight`/
  `MirrorDark` (disco ball tiles), `PlantDark`/`PlantMid` (bible asks for 2-3 greens, gives one), `LampGoldOff`
  (unlit lamp glass), `White` emissive (lit disco tiles), `PlasticWhite` (AC unit), `OliveLeaf`/`OliveDark`/
  `BarkGrey` (stage tree), `FloorPale`/`FloorDeep` (concrete mottling).
- **Wood swatches** differ from the bible's Game column (v2 re-derivation); the bible's section 3 should take
  the new values: Table Wood Lit `#946446`, Wood Mid `#5E3E2A`, Wood Dark `#36241A`, Bar Front `#4E2A1C`.
- **Banquette channels** are 3-voxel tubes with 1-voxel grooves (a 4-voxel rhythm, so 1 m modules tile); the
  bible says 2-voxel channels.
- **Table lamp** shade is 5x5 (two layers), 3x3, 1x1 instead of 4x4, 3x3, 2x2: even and odd tiers cannot share
  a centre, and the bible's own rule says odd diameters when there is a central post.
- Size classes are the bible's labels; some objects exceed the class's voxel limit (guitar 23 tall vs S = 14,
  exit sign 6 wide vs XS = 4) because the real-world size wins.
- Added beyond the task list because the bible inventory has them and they are cheap: `napkin_cup`,
  `ceiling_panel` (red emissive panel between lounge beams).

On import Godot extracts the embedded texture beside each GLB (`*_bc_seam.png`, `*_bc_seam2.png`); those files are
regenerated and ignored by `game/assets/kit/.gitignore`.

## Godot note: glow needs HDR 2D in Compatibility

With the Compatibility renderer, `WorldEnvironment` glow lifts the whole frame (background `#1C0D0C` renders
as `#92403A`) unless the viewport has `use_hdr_2d = true`. `capture_showcase.gd` sets it on its SubViewport.
The game itself should set `rendering/viewport/hdr_2d=true` in `project.godot` (owned by the tech session),
or every glow-enabled scene will look washed out.
