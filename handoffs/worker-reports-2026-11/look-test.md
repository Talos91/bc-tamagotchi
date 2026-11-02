# 🎨 look-test: black / burgundy walls, red light (2026-11-02)

Worker: 🎨 look-test (Opus), started by the orchestrator local_9bb3d41c. Brief: Daniele after playing 50a0623, "in real
life the walls are black and lighting is red, we should do the same i think, if not pitch black but a shade of dark
burgundy or such, before implementing lets test". A test only: no game file changed.

**Recommendation: variant D ("as in the venue").** Card pictures are listed below.

## Daniele messaged this session during the test (acted on)
> "a thing i noticed form real black cabin walls oppositot the bar on main room are light gray top half and blackinsh
> bottom half with a neon strip in the middle, all other walls are blackish, lounge all walls are blackish, floor is not
> tiled but like a cement looking floor"

Acted on it: D was a burgundy-black idea of mine. It is now "as in the venue": blackish walls everywhere (lounge too),
and the main room's north wall (opposite the bar) is light grey on top and blackish below, with a red neon line between.
**B, C and D all get a cement floor** in place of today's tiles, so B and C still differ from D only in walls and light.

## Commits
- see `git log -- game/tests/capture_look_test.gd`. One commit holds the tool, the compose script, the captures, this
  report and the role note. Not pushed.

## Files
- `game/tests/capture_look_test.gd`: the capture tool. It loads `main.tscn` as built, re-colours materials, re-tints
  and re-energises the venue's own 42 lights and sets the environment, all at runtime. Each view is framed once, the
  tree is paused (crowd and camera hold still), and every variant renders on the same frame. It needs a windowed run
  (headless renders nothing); it ran fine from this checkout:
  `Godot --path game --script res://tests/capture_look_test.gd -- --tag=portrait` (and `--tag=landscape`, main-room
  views only). Options: `--only=floor,bar`, `--variants=A,D`, `--out=DIR`. It prints frame and player-area luma.
- `game/tools/look_test_compose.py`: makes the strips and photo sheets (`python game/tools/look_test_compose.py`).
- `docs/art/screens/look-test/`:
  - captures `<A|B|C|D>-<floor|bar|stage|lounge|corridor|smoking>.png` (portrait 1080×1920, HUD on)
  - landscape captures `<A|B|C|D>-landscape-<floor|bar|stage>.png` (1920×1080)
  - strips `strip-<view>.jpg` (A | B | C | D) and `strip-landscape-<view>.jpg` (2×2)
  - photo sheets `sheet-photos-bar.jpg` (D at the bar beside photos 09 and 16) and `sheet-photos-floor.jpg` (D on the
    floor, landscape, beside photos 07 and 11)

## Pictures for the Questions-tab card (pick a variant)
1. `docs/art/screens/look-test/strip-floor.jpg`: the main room, A | B | C | D
2. `docs/art/screens/look-test/strip-bar.jpg`: the bar
3. `docs/art/screens/look-test/strip-stage.jpg`: the stage; D's grey-top north wall and neon line show either side of it
4. `docs/art/screens/look-test/strip-lounge.jpg`: the lounge
5. `docs/art/screens/look-test/sheet-photos-floor.jpg`: D next to real photos 07 and 11

Suggested card: "Which look for the venue?" Options: A today / B black walls + red light / C burgundy walls + red
light / **D as in the venue (rec)**: blackish walls, grey-top north wall with a neon line, cement floor, red light,
warm candles.

## Variants and their values
Same for B, C and D: the kit's amber bar soffits and shelves that `venue_looks.gd` leaves amber (`SoffitPeach_emissive`,
`ShelfAmber_emissive` → ff1a12, `CubbyGlow_emissive` → 6a0806). The cement floor: the `Floor` and `Concrete` materials
take a 256² seamless noise texture (0.70–1.0, world-triplanar as today) times albedo **#4a4848**. Environment:
ambient **(0.45, 0.34, 0.34) × 1.5** (today 0.56, 0.44, 0.44 × 1.1), `adjustment_contrast` **1.06** (today 1.18),
`tonemap_exposure` **1.3** (today 1.2), `glow_intensity` **0.30** (today 0.22). Saturation 1.15, fog, tonemapper and
glow levels unchanged.

| | A today | B black + red | C burgundy + red | D as in the venue (rec) |
|---|---|---|---|---|
| main_wall | 23150f | 0e0b0b | 4a0c16 | 0e0b0b; **north wall** two-tone: top 8c8a8a, bottom 100c0c, red neon line ff1a12 (emission 3, 8 cm) at 1.9 m |
| lounge_wall | 4a0c10 | 0e0b0b | 520d18 | 0e0b0b |
| lobby_wall / smoke_wall | 2a2426 / 1e1c20 | 0e0b0c / 0e0c0e | 3c0a12 / 300a10 | as B |
| frame_wood (pilasters) | 2a1810 | 120c0a | 300a10 | as B |
| Upper Brick (texture ×) | 2e221e base | ×(0.42, 0.40, 0.42) | ×(1.5, 0.45, 0.6) | as B (the 4–6 m filler stays dark: grey there read as a banner over the HUD) |
| ceiling / ceiling_edge / beam_black | 1c0d0c / 120a0a / 160a0c | 080606 / 070505 / 0a0708 | 1c070b / 18060a / 22080c | as B |
| kit CabinDark / CeilingPlum | 1d0e0d / 2c0f13 | 0c0909 / 0c0809 | 26090e / 26080d | as B |
| floor | tiles 57525c | cement 4a4848 | cement | cement |
| key light (directional) | ffcfa8 0.32 | ff6a55 0.32 | as B | ff8a70 0.288 |
| table lamps (11 LAMP_GOLD omnis) | ffb860 1.8–2.2 | ff2a18 ×0.6 | as B | ffa050 ×0.75 (candle pools) |
| bar counter + cashier (3) | ffb860 1.0 / ffd0a0 1.2 | ff2a18 ×0.8 | as B | ffa050 ×0.9 |
| red lights (neon, panels, back bar, PARs red, tree, neon edge; 13) | as built | ×1.15 | as B | ×1.3 |
| amber PAR (ParSpot3) | ff7a30 | ff2a18 | as B | ff2a18 |
| house lights (lobby, corridor, staff room, lightbox, disco glint) | warm white | ff2a18 ×0.9 | as B | ff2a18 ×0.9 |
| toilet-corridor picture light | ffd8a8 | ff2a18 | as B | kept warm (photo 10) |
| smoking room (street spill, bulb), streetlight, pinball, blue PAR, tealights | kept | kept | kept | kept (photo 13: the smoking room is cool, not red) |

### What I had to adjust, and why
- **First try (red ambient (0.46, 0.20, 0.20) × 0.9, lamps fully red):** the floor flooded solid red and the player
  became a black silhouette (player-area luma 0.046 at the bar, against 0.22 in A). Red light on a green shirt is black.
- **The fix that works:** keep the ambient only slightly red but stronger (× 1.5); lower the contrast boost (1.18 crushed
  the darks to black); darken the floor albedo (the cement). Near-black walls stay dark under any ambient, because their
  albedo is ~0.05. The figures (bright albedo) lift out of the dark room. That separation is what keeps the player
  readable.
- Red lamps at ×0.6: at ×1.0 the tables' pools merged into one red field.
- **Readability numbers** (frame luma / luma of a box around the player, which includes floor; portrait):
  floor A 0.19/0.29, B 0.14/0.19, D 0.17/0.23; bar A 0.20/0.20, B 0.15/0.12, D 0.18/0.16; lounge A 0.16/0.27,
  B 0.11/0.16, D 0.14/0.21; corridor A 0.08/0.24, B 0.05/0.11, D 0.06/0.13. In B and C the player reads as a red-lit
  figure. In D they keep their shirt colour (see strip-bar, strip-lounge).

### What it shows (worth knowing before the build)
- **Wall colour barely changes the game's frame.** The cameras look down, and the cutaway sinks walls on the sight line,
  so walls fill little of the picture. B and C look almost the same except in the corridor and at the frame edges. The
  look comes from light and floor: the red light, the dark cement and the red LED soffits change every view. The north
  wall's grey top (D) shows only in views that face it (stage, the floor view's top left).
- The kit's bar soffits were still amber over the red back bar; they go red in B, C and D (photo 09).
- D against the photos (`sheet-photos-floor.jpg`, `sheet-photos-bar.jpg`): dark floor, red washes, warm candle pools,
  red back bar. D is closer to photos 07 and 09 than A is. The game camera stays far brighter than the photos on
  purpose (phone readability).

### Cost
- **No lights added:** still 42 lights and 1 shadow map; only colours and energies change. D adds one ShaderMaterial
  (north wall, 5 pieces) and one 256² texture (cement). Glow intensity 0.22 → 0.30 changes no pass (glow is already on).
  I measured no GPU time: this is a desktop capture, and the performance pass is still to come.

## Build plan (the next job, once Daniele picks; values above, D shown)
`game/tools/build_venue.gd` and `venue.tscn` belong to 🏗️ lounge-followup right now: start this build after it
finishes, then regenerate `venue.tscn` with the generator.
1. **`game/tools/build_venue.gd`**
   - Material colours: `_mat("main_wall")` ×4 call sites, `lounge_wall` (×2, incl. `UpperFloorLip`), `lobby_wall`,
     `smoke_wall`, `frame_wood`, `closed_room`, `ceiling_edge`; constants `CABIN_DARK` (ceiling) → 080606,
     `BEAM_BLACK` → 0a0708 (also used by the street lamp post); `_bond_mat("upper_brick", …)` base → 130e0d.
   - Floor: `_floor_mat()` and `_concrete_mat()` → a cement material (seamless FastNoiseLite image, 0.70–1.0, albedo
     4a4848, same triplanar setup and roughness). `_plank_mat()` (raised strip) unchanged.
   - North wall: give `MainRoom/WallNorth_*` a two-tone material. Either use the test's shader (world-height split at
     1.9 m with an emissive 8 cm line), which keeps one box per segment so the camera rig's sinking stubs still work,
     or a tall box plus an emissive strip box. The second only works if the rig's stub rule (full-height box) is
     respected. I recommend the shader: it is `NORTH_SHADER` in the tool.
   - Lights (`_omni`/`_spot` calls): `LAMP_GOLD` table lamps → ffa050 at ×0.75; `CounterLightW/E`, `CashierLight` →
     ffa050 ×0.9; the red group ×1.3; `ParSpot3` → ff2a18; `LobbyLight`, `CorridorLight`, `StaffRoomLight`,
     `LightboxGlow`, `DiscoGlint` → ff2a18 ×0.9.
   - `_environment()`: ambient (0.45, 0.34, 0.34) × 1.5, `adjustment_contrast` 1.06, `tonemap_exposure` 1.3,
     `glow_intensity` 0.30; key light ff8a70 × 0.288.
2. **`game/scenes/venue/venue_looks.gd`**: turn `SoffitPeach_emissive` / `ShelfAmber_emissive` / `CubbyGlow_emissive`
   red on every bar instance, not only the `look_red_bar` bays (the test did it by material name; check what else
   uses those swatches first).
3. **`tools/blender/bc_kit.py`** (kit palette, optional but keeps kit and venue in step): `CabinDark` → 0c0909,
   `BeamBlack` → 0a0708, `CeilingPlum` → 0c0809; regenerate the GLBs and review blends (a kit job).
4. Art bible / palette note in `docs/art/` for the new swatches; recapture the parity and area shots; run the suites
   (no behaviour changes expected; `smoke_*` and `test_feel` cover the venue load).

## Open questions (for the Questions tab, with pictures)
1. **Which variant?** (card above; pictures 1–5.)
2. **"Walls opposite the bar"**: I read this as the main room's whole north wall (the stage wall; the stage backdrop
   and curtains stay in front of it). Is that right? Is the grey top about half the wall (I used 1.9 m of a 4 m room),
   and is the neon strip red? Picture: `docs/art/screens/look-test/D-stage.png`.
3. **Table lamps**: warm candle pools (D) or red like the room (B/C)? Pictures: `strip-floor.jpg`, `strip-lounge.jpg`.
4. The smoking room keeps its cool street light (photo 13) and the toilet corridor its warm picture light (photo 10)
   in every variant. Keep that? Picture: `strip-smoking.jpg`.

## Not done / notes
- No suites were run (no behaviour change). The capture shows `v0.2.0 · 466e017 · dirty` because the shared tree had
  other sessions' untracked files.
- The tool keys on material names and light node names from `build_venue.gd`. If lounge-followup renames any, the tool
  prints fewer materials or lights in its first line (today: 42 lights, 17 materials, 2 floor materials, 5 north wall
  pieces).
