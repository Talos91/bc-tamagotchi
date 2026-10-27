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

From the repo root (about 10 s for the whole kit):

```
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python tools/blender/bc_kit.py
```

`-- --only round_table,bar_stool` rebuilds just those objects (and leaves `manifest.json` and the .blend alone);
`-- --no-blend` skips the review file.

**Open in Blender:** `blender/BlackCabinKit.blend` (repo root), written by every full run. It has one collection
per zone with a text label under each object, a dark world, warm lights, a camera framing the whole grid, and the
viewport set to Material Preview with scene lights and world. In Blender the materials also multiply in the
per-voxel jitter; that node is added after export, so the GLBs never carry it.
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
- **Meshing.** Only exposed faces, one quad per voxel face (so each face can carry its own jitter and seam).
  Floor-anchored objects drop their bottom faces.
- **Palette.** `PALETTE` holds the bible's section 3 *Game* hexes with roughness, metallic and emissive strength.
  A key ending in `_emissive` makes an emissive material with that name; Godot imports it with
  `emission_enabled` and `emission_energy_multiplier` from `KHR_materials_emissive_strength`.
- **Surface finish.** Per-voxel value jitter of -2..+2 steps (3.5% each) goes into vertex colour `COLOR_0`,
  hashed from object name + cell, so runs are deterministic. White tile jitters per 2x2 block. Non-emissive
  materials carry a 16 px seam texture (dark 1 px border) on per-face UVs: the thin dark seam between voxels.
  Godot's importer turns on `vertex_color_use_as_albedo` automatically (verified by `capture_showcase.gd`).
- **Export.** One GLB per object at `game/assets/kit/<zone>/<object>.glb`, Y-up, origin at the centre of the
  footprint on the floor (`anchor: floor`) or at the top mount point (`anchor: ceiling`: disco ball, beam,
  ceiling panel, track light). Front faces **+Z in Godot** (-Y in Blender). Backface culling on.
- **Manifest.** `game/assets/kit/manifest.json`: name, zone, size class, anchor, `res://` path, footprint and
  height in metres, size in voxels, emissive yes/no, material list, voxel and triangle counts.

Zones follow the bible's section 6 headings: `bar`, `tables`, `stage`, `lounge`, `circulation`
(Stairs and circulation). Heights follow the greybox (`game/tools/build_venue.gd`): walls 3.5 m, stage 0.5 m
(platform 9 voxels + carpet tile 1), stairs 12 steps of 0.2 m x 0.3 m, 1.6 m wide, bar counter 1.1 m.

## Deviations from the bible (need sign-off)

- **Derived swatches** not in the bible's palette: three bottle tints with caps, `MirrorGrey` (disco ball tiles),
  `PlantDark`/`PlantMid` (bible asks for 2-3 greens, gives one), `LampGoldOff` (unlit lamp glass), `White`
  emissive (lit disco tiles).
- **Table lamp** shade is 5x5 (two layers), 3x3, 1x1 instead of 4x4, 3x3, 2x2: even and odd tiers cannot share
  a centre, and the bible's own rule says odd diameters when there is a central post.
- **Room height**: the bible says 80 voxels (4 m), the greybox uses 3.5 m; columns and curtains follow the
  greybox (70 voxels). One of the two should change.
- Size classes are the bible's labels; some objects exceed the class's voxel limit (guitar 23 tall vs S = 14,
  exit sign 6 wide vs XS = 4) because the real-world size wins.
- Added beyond the task list because the bible inventory has them and they are cheap: `napkin_cup`,
  `ceiling_panel` (red emissive panel between lounge beams).

On import Godot extracts the embedded seam texture beside each GLB (`*_bc_seam.png`); those files are
regenerated and ignored by `game/assets/kit/.gitignore`.

## Godot note: glow needs HDR 2D in Compatibility

With the Compatibility renderer, `WorldEnvironment` glow lifts the whole frame (background `#1C0D0C` renders
as `#92403A`) unless the viewport has `use_hdr_2d = true`. `capture_showcase.gd` sets it on its SubViewport.
The game itself should set `rendering/viewport/hdr_2d=true` in `project.godot` (owned by the tech session),
or every glow-enabled scene will look washed out.
