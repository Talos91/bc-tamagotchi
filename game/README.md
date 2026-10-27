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
| `MainRoom` | x 10..30, z 0..10 | Floor, walls, amber cove strips, track lights, disco ball, paintings, wall lamps, exit signs, entrance plant |
| `Bar` | right-hand (south) wall | 11 back-bar shelves, 11 counter units, 9 stools, bottles and tealights on the counter, soffit, paintings, 4 amber shelf lights |
| `Tables` | middle and back | 10 round tables (lamp or tealights each), chairs, 6 drum stools in front of the stage; a clear aisle runs from the curtain to the stage steps |
| `CommunalTable` | left (north) wall, before the stage | Two long tables, chairs both sides |
| `Banquette` | entrance wall north of the curtain | Kit `banquette_straight` ×4 facing the room, two small tables |
| `Stage` | left (north) wall at the far end, x 20..30, z 0..4, 0.5 m high | Kit risers, carpet tiles, kit steps over a hidden ramp, curtains behind, drum kit, amps, guitar, mics, wedges, truss with PARs, stage tree, PA speakers, haze; slatted backdrop on the far (east) wall |
| `Patrons` | | Simulated crowd (`scripts/venue_patrons.gd`) and `Spots/`, the seats, staff and wander points named by zone |
| `CameraZones` | | One Marker3D per zone with the camera framing (see below) |
| `Navigation` | | NavigationRegion3D, agent radius 0.4 m, baked from the static colliders |

Laid out from the three direction renders only (`04-overall-look-mockup` is style, not layout). Entering through
the curtain (R01): the stage is on your left along the far half of the wall, the bar runs along your right, the
communal table is on the left before the stage, round tables fill the middle and the back in front of the slatted
backdrop. R03 is the reverse view from the stage end. Ceiling slab, beams, panels, soffit and the track lights over the bar are on render
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

## People

Every person is a `PatronFigure` (`scenes/venue/patron_figure.tscn`, `scripts/venue_patron_figure.gd`):
`set_look(dict)` builds it, `play("idle" | "walk" | "sit")` poses it. With `{"preset": "patron_05"}` it
instances `assets/chars/presets/patron_05.glb` (rigged, animated, from the character session) when that file is
imported; otherwise, or with no preset, it builds a chibi box placeholder from the colours in the dict (head cube
40% of the height, 1.2–1.4 m). Idles breathe and glance around (head bone turn on presets). Swapping in other
characters is a change to this one scene; the venue only calls `set_look` and `play`.

- **Player:** `player.tscn` carries a `Body/Figure` with `Player.look` (preset `patron_06`) and a warm ring on the
  floor so it reads in a crowd.
- **Crowd:** `Venue/Patrons` (`scripts/venue_patrons.gd`, seeded) seats 9 patrons, at least one in each seating
  zone (round tables, bar stools, banquette, communal table, lounge), puts the bartender (`nam`) behind the bar
  pacing its length, and sends 3 wanderers between the `Wander_*` spots along navmesh paths. Spots are
  `Venue/Patrons/Spots/<Zone>_<Seat>` Marker3Ds (metas `zone`, `pose`, `seat_h`; seat at 0.45 m, bar stools
  0.8 m), written by `tools/build_venue.gd`. Figures have no collision.

## Light budget

30 dynamic lights, **2 shadow-casting** (the stage red washes). `max_renderable_lights=48` in `project.godot`;
Compatibility shades at most 8 lights per mesh, so the floor is 2 m tiles. Lamp and tealight lights fade out
beyond 22 m from the camera.

| Zone | Lights |
|---|---|
| Lounge | neon red, 2 red ceiling-panel omnis, 3 table lamps, arcade cyan, shelf amber (8) |
| Bar | 4 amber shelf omnis (4) |
| Tables / communal / banquette | 10 round tables, 2 communal lamps, 2 banquette tables (14; tealights flicker ±8% at 1–2 Hz) |
| Stage | 2 red spot washes (shadows), blue PAR spot, backdrop red omni (4) |

Measured on an RTX 5080 laptop (`tools/capture_venue.gd`): GPU 0.9–5.4 ms and 250–1500 draw calls per frame with the crowd
depending on the zone; the floor view is the heaviest (kit objects carry 2–9 material surfaces each).

## Screenshots

`tools/capture_venue.gd` runs main.tscn in a real window and writes the gameplay view of each zone plus eye-level
views placed like the direction renders, plus a `hud` shot with the UI on, to
`docs/art/screens/2026-10-27-integration/`. Orientation is undecided, so capture both (half of 1080×1920 and
1920×1080); `stretch/aspect=expand` lets the same scene fill either:

```
godot --path . --resolution 540x960 --script res://tools/capture_venue.gd -- --tag=portrait
godot --path . --resolution 960x540 --script res://tools/capture_venue.gd -- --tag=landscape
```

## Layout export

`assets/kit/layout.json` lists every kit instance in the venue (`object`, `zone`, `name`, `position`, `rotation_y`,
`scale`) and every person spawn (`preset_slot` PLAYER / BAR_1 / PATRON / PATRON_WANDER, `spot`, `zone`, `pose`,
`seat_h`, `position`, `rotation_y`), Godot axes in metres, for the combined Blender review file. Regenerate after
`build_venue.gd`:

```
godot --headless --path . --script res://tools/export_layout.gd
```

## Tests

Headless, exit code 0 = pass, from `game/`:

```
godot --headless --path . --script res://tests/smoke_stairs.gd   # joystick walk lounge -> curtain -> aisle -> stage
godot --headless --path . --script res://tests/smoke_tap.gd      # tap-to-move, all four camera zones, crowd spawned
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
