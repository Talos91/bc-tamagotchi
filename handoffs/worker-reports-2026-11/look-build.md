# 🎨 look-build: look D in the venue, voxel floor and walls, darker light, reindeer (2026-11-02)

Worker: 🎨 look-build (Opus, local_255ee1ab), started by the orchestrator local_9bb3d41c. Brief: build look D of the
look test (DECISIONS "Venue look: D, with a voxel floor"), floor first: Daniele on the test's cement, "looks like a
texture that hasn't loaded, make it match the rest of the map style". Mid-job the orchestrator relayed three more
notes from Daniele (DECISIONS f1c7dfe): walls like the floor, darker light, the bar's stray frame and missing reindeer.
All are in.

**Ready to verify: 6df5288** (on top of 6cd9735, which the orchestrator already pushed and verified at 14/14), plus the
report commit after it. Suites: **14/14 PASS** in an isolated copy of 6df5288. Not pushed. Version and changelog untouched. Daniele did not message this
session.

## Commits
- `6cd9735` Look build: look D in the venue with a voxel cement floor (pushed by the orchestrator; 14/14 in my
  isolated run too).
- `6df5288` Look build pass 2: voxel walls, darker light, reindeer facing the room.
- the next commit: this report and the role note `handoffs/look-build-2026-11-02.md`.

Order kept: the floor was prototyped in my own tool while 🏗️ lounge-followup owned the venue; I touched
`build_venue.gd` only after its report (72fa0bd) was committed and those files were clean (HEAD 54b96c3).

## 1. The floor: voxel cement, and why it matches the kit
Prototyped in `game/tests/capture_look_build.gd` (look D applied at runtime as the test did, three floors compared;
`docs/art/screens/look-build/floor-proto-strip.jpg`: A today | D as tested | E voxel cement | F E + step shade | G
E with 0.2 m cells). **F is built** (`_cement_mat()` on the shared generator `_voxel_tex()` in `build_venue.gd`):
- **Flat square cells of 0.1 m** = two kit voxels (the kit is 5 cm voxels; the old tile floor's blocks were 0.2 m),
  one flat colour each, nearest-filtered, world-triplanar: the idiom of the old running-bond floor and the upper
  brick (`_bond_mat`), which bake per-block value jitter into a small texture, and of the kit, whose surfaces are
  per-voxel value steps (`bc_kit.py`: jitter of ±2 steps per voxel).
- **Stepped values, no smooth noise:** five greys around **#4a4848**, one step 0.022, with the bond texture's warm
  shift. Value noise is sampled *once per cell* and snapped to a step, so patches (0.5–1.5 m) have stair-stepped,
  cell-edged outlines; 9 % of cells are single-cell aggregate flecks.
- **Step shade:** 1 px on a cell's north and west edges where the value steps (darker where the neighbour is
  lighter): the cells read as voxels of slightly different height. Without it (E) the floor read flatter; G's
  0.2 m cells were nearly invisible at the game's distance.
- **No seam on every cell** (the kit's voxels have one): a seam grid on a floor reads as tiles, and Daniele said
  "not tiled". **Matte** (roughness 0.85; the tiles were 0.34 and threw red sheen pools).
- One seamless 8 m texture (a 4 m repeat showed in the 21.7 m room) shared by "Floor" and "Concrete" (lobby,
  corridor, buffer, stub, vestibule, smoking room, staff room, sills). The raised strip keeps its planks; they do not
  clash (`twoup-landscape-floor.jpg`).
- First-pass comparisons, test's smooth cement | voxel cement under look D as tested:
  `floor-twoup-{floor,bar,lounge,corridor}.jpg`.

## 2. Walls like the floor ("floor coming tgt walls aswell")
My reading matches the orchestrator's: the walls take the same voxel finish. `_wall_mat()` = the floor's generator
at a grey grain (base 0.8, steps 0.07, 4 m repeat) times each wall's colour, with `albedo_color` set so the mean
stays the look-D swatch. It covers main_wall, lounge_wall, lobby_wall, smoke_wall, the smoking room's pale plaster,
frame_wood (pilasters) and the new reindeer panel; the north wall shader samples the same grain on both tones.
The steps are ~9 % of the value (the cement's are ~8 %), so they show even on near-black.
**Floor and walls stay separate surfaces:** the walls are about 5× darker than the cement in sRGB value, so the floor
reads as a lit warm plane and the walls as a dark grained frame. The grain shows best where a wall is lit: the north
wall's grey top (`twoup-landscape-stage.jpg`, `twoup-stage.jpg`), the smoking room's plaster (`twoup-smoking.jpg`),
the reindeer panel (`twoup-cashier.jpg`); on the blackish walls in the dark it is subtle by design.

## 3. Darker light, halfway between the photos and D as tested
Same 42 lights and 1 shadow map, tint and energy only (values in `docs/art/palette-look-d.md`):
- **Ambient 1.5 → 0.7** (colour unchanged, near neutral), **exposure 1.3 → 1.15**, **key 0.288 → 0.15**.
- **The red neon carries the room:** the 12 red lights × 1.3 again (lounge neon 3.38 → 4.4, back bar 2.08 → 2.7,
  red PARs 4.42 → 5.75, …). **Candle pools:** table lamps 1.35–1.65 → 1.45–1.75, tealights 1.4/1.6 → 1.8/2.1.
  Counters and cashier 0.9/1.08 → 0.72/0.86; staff room, light box, disco glint down to 0.5/0.5/0.32.
- Readability holds: lobby light 1.0 (spawn); the **corridor light turned warm** (ffa050, 2.05; red light on the
  player's green shirt reads black in the dark corridor); picture light and smoking room lights × 1.3.
- How I chose: trials K1–KI on the built venue (`capture_look_build.gd`). Below ambient ~0.65 the player turns into
  a silhouette between the candle pools; exposure or contrast changes darken the player as much as the room.

Luma (frame / box around the player), portrait unless marked:

| View | Before (main 54b96c3) | D as tested (6cd9735) | Built now (6df5288) |
|---|---|---|---|
| floor | 0.212 / 0.326 | 0.172 / 0.249 | **0.135 / 0.197** |
| bar | 0.222 / 0.224 | 0.175 / 0.166 | **0.133 / 0.107** |
| stage | 0.144 / 0.210 | 0.130 / 0.184 | **0.101 / 0.145** |
| lounge | 0.184 / 0.320 | 0.142 / 0.217 | **0.099 / 0.135** |
| corridor (west end, x 4.2) | 0.097 / 0.268 | 0.066 / 0.152 | **0.047 / 0.085** |
| corridor-mid (x 9) | 0.090 / 0.252 | – | **0.075 / 0.109** |
| smoking | 0.159 / 0.255 | 0.122 / 0.158 | **0.080 / 0.098** |
| toilets | 0.109 / 0.143 | 0.109 / 0.119 | **0.083 / 0.094** |
| cashier | 0.198 / 0.197 | – | **0.120 / 0.111** |
| landscape floor / bar / stage | 0.166/0.230, 0.190/0.137, 0.153/0.163 | 0.162/0.212, 0.175/0.130, 0.170/0.160 | **0.123/0.166, 0.132/0.109, 0.136/0.142** |

The frame is about a fifth darker than D as tested and a third darker than before. The player stays a readable
figure in its own colours in the main room, bar and lounge (the look test's B, "a red-lit figure", was 0.12 at
the bar). **Weak spot: the corridor's west end** (0.085), where no light reaches; see open question 3.

## 4. Bar: the stray frame and the reindeer
**One bug, not two.** The kit already had `reindeer_head` (kudu head with tiara in a gilt frame, from the kit-additions
job). The venue placed it at rotation 0, so its head pointed into the back bar and only the gilt frame showed,
floating in front of the bottles between two bays: Daniele's "frame seemingly hanging randomly" and "no reindeer".
Fixed against photo 16:
- `build_venue.gd`: the head faces the room (180°) at 1.75 m, its frame flat on a new **1.4 m dark wall panel between
  two dark pillars** that breaks the back bar right behind the cashier, as in the photo (the red LED strips stop
  behind the panel). No layout item moved (cashier, bays and counter as in `layout.json`); no light added
  (CashierLight lights it).
- `tools/blender/bc_kit.py`: new swatch **FurPale** d6caba; head, neck, chest and ears pale cream as in the photo
  (they were mid browns and read as a dark blob in the red light); muzzle FurLight. Full kit run: only
  `reindeer_head.glb` and its manifest entry changed (the generator is deterministic); lit, labelled review scene
  saved to `blender/BlackCabinKit.blend`.
- Pictures: `twoup-cashier.jpg` (before: frame over the bottles; after: the head on its panel), `twoup-bar.jpg`.

## Other values (first pass, unchanged by the second)
Walls/ceilings: `WALL_BLACK` 0e0b0b (main and lounge walls), lobby 0e0b0c, smoke 0e0c0e, frame_wood 120c0a, upper
brick 130e0d, ceilings 080606, ceiling edge 070505, beams 0a0708, closed rooms 070606. North wall: grey 8c8a8a
above 1.9 m, 100c0c below, 8 cm neon ff1a12 (emission 3) at 1.9 m, `NORTH_SHADER`, one box per segment (the camera
rig's stubs share it). Contrast 1.06, glow 0.30, key colour ff8a70, lamp colour `CANDLE` ffa050, house red ff2a18,
amber PAR red. `venue_looks.gd`: every kit ShelfAmber/SoffitPeach → ff1a12 and CubbyGlow → 6a0806 (kit emission
energy kept), CabinDark → 0c0909, CeilingPlum → 0c0809, at load, characters under `Patrons` skipped: what the look
test did by material name. Swatch users: bar soffits, counter and cashier strips, back-bar bays and art, stage
backdrop lights and lanterns, amber PAR lens, step lights, collectibles shelf, wine fridge; CabinDark/CeilingPlum:
amps, soffits, shelves, the patrons board, the sticker door, a framed picture, the wine fridge, two paintings.
`venue.tscn` regenerated (navmesh 561, 42 lights, 1 shadowed); 3.2 → 4.7 MB (cement 320² and wall grain 160²
textures, with mipmaps, embedded).

## Suites
**All 14 PASS on 6df5288** in an isolated copy (`git archive 6df5288 game tools docs/venue` on local disk, imported,
venue rebuilt (navmesh 561 polygons, 42 lights, 1 shadowed), imported again, `APPDATA` an empty folder per suite):
smoke_stairs, smoke_tap, smoke_hud, test_needs, test_minigames, smoke_loop, smoke_doors_sit, smoke_start, test_menu,
smoke_version, test_nightlife, test_seats, test_feel, test_lounge. test_feel passed on the first run (no rerun
needed). The same isolated run on 6cd9735 (first pass) was also 14/14. No suite was changed.

## Captures (`docs/art/screens/look-build/`, the game's views, HUD on)
- `before/A-<view>.png` (54b96c3, captured in an isolated copy) and `after/A-<view>.png` (6df5288's tree): portrait
  1080×1920 floor, bar, stage, lounge, corridor, corridor-mid, smoking, toilets, cashier; landscape 1920×1080 floor,
  bar, stage. Two-ups before | after: `twoup-<view>.jpg`, `twoup-landscape-<view>.jpg`.
- Floor design: `floor-proto-strip.jpg`, `floor-twoup-<view>.jpg`, `floor/{D,F}-<view>.png` (first pass, under the
  look-D-as-tested light).
- Re-run: from `game/`, `godot --path . --script res://tests/capture_look_build.gd -- --tag=portrait --variants=A
  --out=<dir>` (and `--tag=landscape`), then `python game/tools/look_build_compose.py after`.
- The after shots show `v0.2.0 · 466e017 · dirty`: the shared tree's version stamp is stale (I do not stamp).

**Best for the acceptance card:**
1. `docs/art/screens/look-build/twoup-floor.jpg`: the main room before | after (voxel floor, darker, candle pools)
2. `docs/art/screens/look-build/twoup-cashier.jpg`: the reindeer over the cashier (photo 16)
3. `docs/art/screens/look-build/twoup-landscape-stage.jpg`: the grey-top north wall with its neon line and the wall
   grain
4. `docs/art/screens/look-build/twoup-lounge.jpg`: the lounge, darker, the neon carrying the light
5. `docs/art/screens/look-build/twoup-bar.jpg`: the bar, red soffits and back bar

Suggested card: "Look D is in: voxel floor and walls, darker, the reindeer over the cashier. Accept?" Options: accept
(rec) / darker still / lighter / the floor or walls need work.

## Open questions (for the Questions tab, with pictures)
1. **Accept the build?** Pictures 1–5.
2. **Dark enough?** I aimed at halfway (frame luma about a fifth under D as tested). Darker still costs player
   readability between the pools unless lights move. Pictures: `twoup-floor.jpg`, `twoup-lounge.jpg`.
3. **The corridor's west end is the darkest spot** (player luma 0.085; no light reaches x < 6). A fix needs a light
   moved or added (CorridorLight from x 9 to ~6, or a dim one at the lobby end): OK to move it? Picture:
   `twoup-corridor.jpg` (and `twoup-corridor-mid.jpg`, which is fine).
4. **Two sconces on the north wall sit on the neon line** (kit `wall_lamp` at 1.9 m, x 21.2 and 26.9). Keep, or lower
   them? Picture: `twoup-landscape-stage.jpg` (left of the stage).
5. **All of the kit's amber LEDs are red** (as in the test): the stage backdrop's dots and lanterns, step lights, the
   collectibles shelf and the wine fridge too. Keep, or bring some back to amber? Picture: `twoup-stage.jpg`.
6. (Tech, no picture) Bake look D's swatches into `bc_kit.py` and drop `venue_looks.gd`'s runtime recolour? Tidier,
   not visible.

## Not done / notes
- No GPU timing (desktop only; the performance pass is still to come). Cost: one ShaderMaterial (north wall, 5
  pieces), two embedded textures (cement 320², wall grain 160²; the old floor had two 160²).
- `capture_look_build.gd` variants D–G (floor prototype) apply look D on top of what is built: meaningful only on
  54b96c3 or earlier; K1–KI are relative to 6cd9735's lights. On today's main only A means anything.
