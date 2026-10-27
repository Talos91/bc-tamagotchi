# Black Cabin Tamagotchi: Godot project

Godot **4.6.1**, Compatibility renderer (`gl_compatibility`, also for mobile, so web and low-end phones match).
Engine rationale: `docs/tech/01-engine-decision.md`.

## Open and run

- Godot 4.6.x is not on PATH on Daniele's PC. Ooze Syndicate's copy works:
  `H:\My Drive\PROJECTS\Ooze Syndicate\Tools\Godot\Godot_v4.6.1-stable_win64.exe`.
- Editor: start Godot, Import, pick `game/project.godot`, press F5. Main scene is `scenes/main.tscn`.
- Controls: tap / click the floor to walk there; WASD / arrows or the on-screen joystick (bottom-left) move
  relative to the camera.
- CLI: `godot --path game` runs it. First time, run `godot --headless --path game --import` once.

## Venue

`scenes/venue/venue.tscn` is **generated** from the voxel kit (`assets/kit/manifest.json`): edit
`tools/build_venue.gd`, then from `game/` run `godot --headless --path . --import` once and
`godot --headless --path . --script res://tools/build_venue.gd`. Hand-edits are overwritten. Kit objects are
instanced from their `.glb`; furniture gets box colliders; the navmesh is baked into the scene (`scripts/venue.gd`
re-bakes if it is empty). Units are metres, x east, z south, room height 4 m.

| Node | Where | What |
|---|---|---|
| `WorldEnvironment` | | Dark warm ambient, filmic tonemap, glow (threshold 1.0, only emissives bloom), light depth fog |
| `Lounge` | x 0..10, z 0..10 | Neon sign on the plant wall (north), velvet banquette, long table with lamps, two white columns, CRT, arcade cabinet, collectibles shelf with high counter, beam grid with red ceiling panels |
| `Stairs` | west wall | Kit stair run rising north to a landing at 2.4 m, hidden ramp collider |
| `Curtain` | x 10, door z 4.8..7.2 | Partition with red curtain panels on the lounge side, valance, exit sign |
| `MainRoom` | x 10..30, z 0..10 | Floor, walls, amber cove strip, track lights, disco ball |
| `Bar` | south wall | 10 back-bar shelves, 10 counter units, 8 stools, soffit panels, 4 amber shelf lights |
| `Tables` | middle | 6 round tables in two staggered rows (lamp or tealights each), chairs, drum stools; the z 5.5 aisle stays clear from curtain to stage |
| `CommunalTable` | north wall | Two long tables, chairs both sides |
| `Banquette` | north wall, x 18..22 | Velvet banquette (boxes until the kit has a `banquette`) with two small tables |
| `Stage` | x 24..30, z 1..9, 0.5 m high | Kit risers, carpet tiles, steps over a hidden ramp, slatted backdrop, curtains, drum kit, amps, guitar, mics, wedges, truss with PARs, haze sheets |
| `CameraZones` | | One Marker3D per zone with the camera framing (see below) |
| `Navigation` | | NavigationRegion3D, agent radius 0.4 m, baked from the static colliders |

Entering through the curtain you face the stage with the bar on your right and the communal table on your left,
as in `docs/art/direction/01`. Ceiling slab, beams, panels, soffit and the track lights over the bar are on render
layer 2.

## Camera and controls

`player.tscn` is the entry point: a `CharacterBody3D` (capsule placeholder) with a `NavigationAgent3D` and a
`CameraRig` (`scripts/camera_rig.gd`, top-level so it ignores the player transform).

- **Diorama camera.** Fixed-angle elevated three-quarter view that follows the player inside the current zone.
  Zones (`Venue/CameraZones/*`, metas `rect`, `clamp`, `yaw`, `pitch`, `dist`, `look_y`): lounge (looks north at
  the sign), bar (looks south at the back bar), floor (looks east from the curtain toward the stage), stage (looks
  east, closer and lower). Changing zone eases position, yaw, pitch and distance (`smoothing`). Portrait keeps a
  52° horizontal FOV; landscape keeps a 42° vertical FOV and pulls back ×1.3. The camera never draws layer 2
  (ceiling), hides walls in group `cutaway` whose `cut_normal` faces it, and hides group `occluder` props (the
  disco ball) while they sit between it and the player.
- **Tap / click to move.** A short tap on the floor raycasts from the camera and walks the navmesh
  (`Player.tap_at`, `Player.walk_to`). WASD / arrows and the on-screen joystick move relative to the camera and
  cancel a tap-walk.

## Light budget

26 dynamic lights, **2 shadow-casting** (the stage red washes). `max_renderable_lights=48` in `project.godot`;
Compatibility shades at most 8 lights per mesh, so the floor is 2 m tiles. Lamp and tealight lights fade out
beyond 22 m from the camera.

| Zone | Lights |
|---|---|
| Lounge | neon red, 2 red ceiling-panel omnis, 3 table lamps, arcade cyan, shelf amber (8) |
| Bar | 4 amber shelf omnis (4) |
| Tables / communal / banquette | 6 round tables, 2 communal lamps, 2 banquette tealights (10; tealights flicker ±8% at 1–2 Hz) |
| Stage | 2 red spot washes (shadows), blue PAR spot, backdrop red omni (4) |

Measured on an RTX 5080 laptop (`tools/capture_venue.gd`): GPU 0.3–1.2 ms and 180–1100 draw calls per frame
depending on the zone; the floor view is the heaviest (kit objects carry 2–9 material surfaces each).

## Screenshots

`tools/capture_venue.gd` runs main.tscn in a real window and writes the gameplay view of each zone plus eye-level
views placed like the direction renders to `docs/art/screens/2026-10-27-integration/`:

```
godot --path . --resolution 540x960 --script res://tools/capture_venue.gd -- --tag=portrait
godot --path . --resolution 1280x720 --script res://tools/capture_venue.gd -- --tag=landscape
```

## Tests

Headless, exit code 0 = pass, from `game/`:

```
godot --headless --path . --script res://tests/smoke_stairs.gd   # joystick walk lounge -> curtain -> aisle -> stage
godot --headless --path . --script res://tests/smoke_tap.gd      # tap-to-move to four goals, all four camera zones
godot --headless --path . --script res://tests/smoke_hud.gd
godot --headless --path . --script res://tests/test_needs.gd
```

## Folder conventions

| Path | Holds |
|---|---|
| `scenes/` | `.tscn` files: `main.tscn`, `venue/`, `player/`; add one folder per feature (`npc/`, `ui/`, `minigames/`) |
| `scripts/` | `.gd` shared by scenes; scene-specific scripts may sit beside their `.tscn` |
| `assets/kit/` | Voxel venue kit and character parts (glTF from the Blender MCP pipeline) |
| `assets/ui/` | UI textures, fonts, icons |
| `tools/` | Editor/CLI generator scripts (run with `--script`) |
| `tests/` | Headless test scripts (`--script res://tests/...`, exit code 0 = pass) |

`.godot/` and `*.import` are git-ignored at the repo root. Commit `.uid` files and generated `.tscn`.
