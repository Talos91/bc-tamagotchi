# 🎨 art-mg-sprites — report (2026-11-18)

Load id 2026-11-18-voxel-art-black-cabin-7a328a. Owner item 38, look B (`docs/design/11-minigame-quality.md` §1).

## Evidence
- Commit **48f0f74** (local, not pushed): generator `tools/blender/bc_minigame_sprites.py`, packer
  `tools/blender/bc_minigame_pack.py`, 116 files: `game/assets/minigames/<game>/` (PNG strips, half-size `_glow`
  strips, `backdrop.png`, `sprites.json`, Godot `.import` files), `game/assets/minigames/README.md` (wiring notes),
  contact sheets `docs/art/screens/minigame-sprites/<game>.png` + `review-blend.png`, review scene
  `blender/BlackCabinMinigames.blend`, role note `handoffs/art-mg-sprites-2026-11-18.md`.
- Suites: **24/24 pass** headless in a clean worktree of 48f0f74 (import first), APPDATA empty per suite, exit 0 and no FAIL line each. Nothing changed for them (no script touched), as expected.
- Hub card **minigame-sprites-review** (order 378, 9 pictures + 4 file paths): accept the look / change.
- No `game/scripts/minigames/*.gd` touched; nothing loads the sprites yet, so the game is unchanged.
- Largest committed image 1600 px wide (contact sheets); all ≤ 2000 px (checked by script).

## Texture memory with the game open (RGBA8, lossless, no mipmaps; budget 4 MB)
| Game | Loaded | Files on disk |
|---|---|---|
| Neon Moth | 1.82 MB | 1.82 MB |
| Coaster Flip | 3.07 MB (one regular's head) | 3.61 MB |
| Soi Dash | 3.56 MB | 3.56 MB |
| Shake & Serve | 2.51 MB | 2.51 MB |
| Pour Perfect | 2.86 MB | 2.86 MB |
| Front Row Rhythm | 2.25 MB | 2.25 MB |
| Candle Talk | 2.40 MB (one regular's bust) | 5.76 MB |
| Neon Pinball | 1.64 MB | 1.64 MB |
Measured from the files (w × h × 4), not on a phone.

## What was built (per game, details in the README)
Neon Moth: moth (flap 4, singe 2), wing pip, bulb drop lit/off, cord tile, batten, speaker cabs (2), kit neon sign,
lounge backdrop. Coaster Flip: coaster spin 8, ring lit/dim, table top, leg, 8 regulars' heads (calm/cheer), room.
Soi Dash: runner (run 4, hop 2, default avatar), motorbike, tuk-tuk, food cart, soi dog (2), monitor lizard (2), kerb,
note, 3 shopfronts, road tile (seamless 128), lane dash, Black Cabin front door closed/open, night soi backdrop.
Shake & Serve: 12 shelf bottles/mixers, shaker 4, highball/rocks/coupe empty/full, Nam nod 2, bar top, bar shelf.
Pour Perfect: pint in two layers (back, front; inner box points), tap (spout point), stream tile, foam 3, bar top.
Front Row Rhythm: clap 3, puck 3, hit pad 2, Jo and Pete playing (2 each), stage. Candle Talk: candle (wick point),
flame 6 (flicker + gutter), 8 regulars' busts (listen/smile), topic card 2, candle table.
Neon Pinball: bumper 2, flipper (pivot anchor), ball, letters B L A C K I N off/lit, playfield 360×600.

## Gaps and not verified
- Not seen in the game or on a phone: wiring is the builders' job; sizes are aimed at a 780 px play width.
- Backdrops come from `blender/BlackCabin.blend`, which is older than `layout.json` (bar at x 12–24, no Buffer tall
  tables); Coaster Flip therefore shows the main-room tables. Rerun `bc_review.py`, then this generator, to refresh.
- Runner is a default avatar, not the player's; the player's own look needs a runtime render (builder decision).
- Brief said 8 bottles; the shelf has 12 ids, all rendered. Band: Jo and Pete only (Boy is in the stage backdrop).
- Shared juice art (sparks, confetti, stamps, number font) left to job Q1 as the plan says.
- Profile note: the voxel-art profile's "capture in the engine at every device size" step does not fit an art-only
  sprite job whose wiring comes later; captures belong to the builder jobs.
