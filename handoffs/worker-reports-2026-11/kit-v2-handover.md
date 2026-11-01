# Kit v2 hand-over (for room assembly / integration)

Manifest: `game/assets/kit/manifest.json`, 52 objects (35 v1 + 17 new). Read it; nothing is hardcoded.

**Changed on existing objects**
- `white_column` and `curtain_panel`: height 3.5 m -> 4.0 m (80 voxels, DECISIONS (j)). Footprint and origin
  (bottom centre) unchanged.
- No vertex colours any more: per-voxel jitter + seam are in the base-colour texture. Godot imports
  `vertex_color_use_as_albedo = false` (expected). If any scene overrides kit materials, keep the albedo texture.
- Everything else: same names, origins, footprints.

**New manifest fields** (optional): `tris_unmerged`; `mount: "wall"` + `mount_height_m` (origin is still the
bottom centre; back face against the wall = Godot -Z); `variant_of`; `note`.

**New objects**
- lounge: `banquette_straight` (1 x 0.6 m, tiles along X, back at Godot -Z), `banquette_corner` (0.6 x 0.6,
  backs at -Z and +X; the run on its +Z side (front) is a straight module with `rotate_y(-PI/2)`),
  `ac_unit` (wall, 2.9 m), `wall_lamp` (wall, 1.8 m)
- stage: `stage_steps` (1 x 0.6 m, top tread 0.35 m, put against the stage front), `truss_segment` (2 m, ceiling),
  `par_light_red/_amber/_blue` (ceiling; hang one at truss origin minus truss height_m), `stage_tree`,
  `pa_speaker` (floor or hung by its yoke)
- bar: `soffit_segment` (ceiling, tiles along X), `painting_a/b/c` (wall)
- circulation: `floor_tile_a/b` (1 m concrete, 1 voxel thick, seamless; mix a/b, rotate freely)
