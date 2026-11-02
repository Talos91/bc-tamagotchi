# 🎨 look-build: role note (2026-11-02)

Done and closed: no worker of this role is running. Report: `handoffs/worker-reports-2026-11/look-build.md`.

## What exists
- Look D "as in the venue" is built into the venue: `game/tools/build_venue.gd` (wall, ceiling, beam and floor
  materials, the north wall shader, the 42 lights' colours and energies, the environment) and
  `game/scenes/venue/venue_looks.gd` (kit amber LEDs red, kit CabinDark/CeilingPlum blackish, at load, venue only).
  `venue.tscn` regenerated. Values and reasons: `docs/art/palette-look-d.md`.
- Voxel cement floor and voxel walls: `_voxel_tex()` in `build_venue.gd` makes the finish (0.1 m cells, five stepped
  values, flecks, 1 px step shade, no grout); `_cement_mat()` (4a4848, 8 m repeat, "Floor" and "Concrete") and
  `_wall_mat()` (grey grain × wall colour, 4 m repeat, every wall material; the north wall shader samples it).
- Darker light (Daniele: halfway between the photos and look D as tested): ambient 0.7, exposure 1.15, key 0.15, the
  red neon and the candle pools carry the room, the corridor light is warm.
- The reindeer head faces the room on a dark panel between two pillars behind the cashier (photo 16); kit swatch
  FurPale for its pale head (`tools/blender/bc_kit.py`, `reindeer_head.glb`, review `blender/BlackCabinKit.blend`).
- `game/tests/capture_look_build.gd`: windowed capture of the game's views with the HUD on (floor, bar, stage, lounge,
  corridor, corridor-mid, smoking, toilets, cashier; landscape floor, bar, stage). Variant A = as built (before|after
  shots). Variants D–G (floor prototype) apply look D on top of what is built: only meaningful on 54b96c3 or earlier;
  K1–KI are the darker-light trials, relative to 6cd9735.
- `game/tools/look_build_compose.py floor|after`: floor strips and before|after two-ups into
  `docs/art/screens/look-build/`.

## Gotchas
- The north wall is one ShaderMaterial (`north_wall`) on the `MainRoom/WallNorth_*` boxes; the camera rig's stubs
  share it, so they show the blackish bottom. Keep one full-height box per segment.
- The cement and wall grain textures are embedded in `venue.tscn` (320² and 160² RGB with mipmaps): the scene grew
  from 3.2 to 4.7 MB.
- Kit wall mounts: back face at -Z in Godot, so a wall piece on the south (bar) wall needs 180°. The reindeer stood
  at 0° from when it was placed, showing only its frame.
- Darker than ambient ~0.65 the player turns into a silhouette between the candle pools; the corridor's west end
  has no light of its own (an open question in the report).
- `venue_looks.gd` recolours by material name prefix on every MeshInstance3D under the venue except `Patrons`.
  A kit piece that should keep an amber LED needs a group exception there.
- Wall albedo barely shows in the game cameras (they look down, the cutaway sinks walls). Light, floor and contrast
  make the look; keep the ambient near neutral or the player turns into a silhouette.
- Run Godot with `APPDATA` pointed at an empty folder; the shader-cache `err != OK` lines are harmless.

## Next
- Daniele accepts (or not) on the Questions tab with the card pictures listed in the report.
- Optional kit job: bake the look D swatches into `tools/blender/bc_kit.py` (CabinDark 0c0909, BeamBlack 0a0708,
  CeilingPlum 0c0809, the amber LEDs red) and drop the runtime recolour from `venue_looks.gd`.
- Open calls in the report: darkness level, corridor light position, north-wall sconces, amber LEDs.
