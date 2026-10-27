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

```
godot --headless --path . --script res://tools/build_venue.gd
```

Units are metres. Main room x 0..18, z 0..8: bar on the z=0 wall, round tables at z=4.5, stage platform and
red curtain wall at the east end. Lounge up the stairs at y=2.4 (x 0..12, z 8..15) with the long table, CRT,
cabinet, plant wall and the red neon sign. Emissive boxes mark the neon sign, amber bar shelf lights,
candles, stage wash and CRT; a few OmniLights back them up. Everything is CSG, a placeholder for the voxel kit.
The stair ramp and fill boxes are hidden collision; the visible steps are decoration.

Smoke test (walks the player up the stairs; prints `SMOKE PASS`):

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
