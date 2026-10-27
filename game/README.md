# Black Cabin Tamagotchi: Godot project

Godot **4.6.1**, Compatibility renderer (`gl_compatibility`, also for mobile, so web and low-end phones match).
Engine rationale: `docs/tech/01-engine-decision.md`.

## Open and run

- Godot 4.6.x is not on PATH on Daniele's PC. Ooze Syndicate's copy works:
  `H:\My Drive\PROJECTS\Ooze Syndicate\Tools\Godot\Godot_v4.6.1-stable_win64.exe`.
- Editor: start Godot, Import, pick `game/project.godot`, press F5. Main scene is `scenes/main.tscn`.
- Controls: WASD / arrows to move, right-mouse drag (or one-finger drag) to look, wheel to zoom, on-screen
  joystick (bottom-left; mouse works too) for touch.
- CLI: `godot --path game` runs it. First time, run `godot --headless --path game --import` once.

## Greybox venue

`scenes/venue/venue.tscn` is **generated**: edit `tools/build_venue.gd`, then from `game/`:

Units are metres. Entrance Lounge x 0..8, z 0..8: neon sign on the plant wall (north), long table, white
columns, cabinet, stairs up on the west side to a landing. The red `Curtain` on the lounge's east wall (to the
right when facing the sign) is a passable opening into the main room x 8..26: `Bar` along the north wall,
`Tables` (rounds) in the middle, `CommunalTable` along the south wall, `Stage` at the far end with a ramp.
Top-level node names are by zone (Lounge, Stairs, Curtain, MainRoom, Bar, Tables, CommunalTable, Stage).
Emissive boxes mark the neon sign, amber shelf lights, candles and stage wash. Everything is CSG, a
placeholder for the voxel kit. The stair ramp and fill boxes are hidden collision.

Smoke test (walks the player from the lounge through the curtain onto the stage; prints `SMOKE PASS`):

```
godot --headless --path . --script res://tests/smoke_stairs.gd
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
