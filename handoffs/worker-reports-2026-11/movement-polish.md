# 🎮 Movement polish: worker report (2026-11-04)

## EVIDENCE
- **Rollback 2026-11-04 (Daniele played the live build: fixed axis "very hard to manoeuvre"): commit 80fc8a4.** Default
  `Player.control_frame` is **CAMERA** again (camera-relative, latched for one press, as before ac8d0ac); the hold-through-
  the-swing variant was not built, so plain camera-relative. Every navigation and stuck fix kept. test_touch section 7
  now checks: default CAMERA; a held drag keeps its world way through two swings (latch); a fresh drag after the swing
  walks screen-up of the new camera; fixed frames still ignore the camera. Suites (empty APPDATA, headless, from game/):
  test_touch PASS, test_walk PASS (0/315 tap, 0/92 stick wedges), smoke_tap PASS, smoke_loop PASS, test_feel PASS.
  Card movement-axis-choice note: "rolled back by Daniele 11-04". The axis section below is history.
- Code commit **ac8d0ac** (local main, not pushed; on top of c11c419/c3cbe5b/2364605 web-labels). Role note + this report: next commit.
- Suites, run one at a time from `game/` with APPDATA on an empty folder, headless, shared tree at ac8d0ac's content:
  test_touch PASS, test_walk PASS, smoke_tap PASS, smoke_loop PASS, test_feel PASS, test_seats PASS, smoke_doors_sit PASS,
  smoke_start PASS (8/8). test_walk also PASS with `-- --seed=7` (0/315 tap, 1/92 = 1.1 % stick wedge on the raised strip).
- **New suite `test_walk`** (game/tests/test_walk.gd, ~35 s): orchestrator, please add it to PROJECT.md Tests.
- Numbers, same test (final version), before = HEAD player.gd + venue.tscn, after = ac8d0ac:
  | | before | after |
  |---|---|---|
  | tap-walks to seat approaches failing (> 0.3 m short or stalled) | 6 / 315 (all 6 at the buffer's tall tables) | 0 / 315 |
  | per group: lounge 36, long table 15, bar stools 27, buffer 24, main room 213 | buffer 6 fail | all 0 |
  | stick held at a seat 3–6 m away, wedged (0.5 s no motion, short way round exists) | 23 / 96 (24.0 %) | 0 / 92 (0 %) |
  | tap-walk end distance, mean / max | 0.03 / 0.04 m (stalls not counted) | 0.03 / 0.04 m |
  Stick pushes that stop at a real wall (the way round > 1.5 x straight + 1 m, e.g. the stage's front row): 5 before, 4 after (correct).
- Fixed axis: test_touch section 7 — drag up held from the lobby (camera yaw 0) through the main floor (-90) and the bar
  (180): world heading unchanged (dot > 0.97); a fresh drag after the swing: same; fixed frames ignore `rig.yaw`, CAMERA follows it.
- Hub cards (Questions tab, items): **movement-polish-review** (order 344, now; sheets portrait + landscape, files) and
  **movement-axis-choice** (order 345, design; three strips). Assets /_blob/bca1380c…, 72ccff88…, 3861bbda…, 5e078402…, 27082739….
- Captures `docs/art/screens/movement-polish/`: before-/after-/option-main-room-{1-lounge,2-buffer-held,3-same-drag-again}-
  {portrait 1080x1920, landscape 1920x1080}.jpg, strip-*.jpg, sheet-{portrait,landscape}.jpg. Rendered at 540x960 / 960x540
  and scaled 2x (the window clamps at 1421 high on this screen).
- `game/assets/kit/layout.json` unchanged (git diff empty).

## Causes found (item 18)
1. Navmesh edges inside the capsule: Recast simplifies outlines by `edge_max_error` cells (default 1.3 = 0.13 m) so edges
   sat ~0.27 m from chairs, the capsule is 0.35 m. Now 0.4 cells (navmesh 561 → 2023 polygons).
2. Tap-walk oscillation: navmesh paths carry runs of identical corners; zero-length segments filled the four-segment
   pursuit window, so the figure swung to and fro forever (the 6 buffer stalls). Paths cleaned, window >= 2 m, stall net.
3. Stick wedges: the capsule walked into pockets between stools / chairs and tables (off the navmesh, a dead end). The stick
   now stays on the navmesh on flat floor (slides along its edge) and walks round a table in its way along a navmesh path
   while the stick keeps its direction; never through a door (it once went round through the red door), free on
   stairs/ramps (the second stair flight has no navmesh) and off the mesh (seats). No furniture moved.

## Axis choice (item 17) — my call and why
- Built: **VENUE_NORTH** (screen-up = -z). "Fixed to the first camera" is identical today: the first camera after the start
  screen is the lobby's, yaw 0 = north. So the real alternative is **MAIN_ROOM** (screen-up = east); both captured.
- The catch, measured on random navmesh points (6000 probes, seed 7) by area: the area cameras face all four ways, so any fixed axis is ~90° off
  the screen on average; drag-up is within 45° of screen-up on 20 % of the floor (north) vs 29 % (main-room east). North is
  reversed at the bar/toilets/smoking room, sideways in the main room and lounge; main-room east is reversed in the lounge.
- I recommend north: it is the axis the game opens on (lobby, start screen), matches the stage/buffer/merch/memory views,
  and is what the brief named; main-room east wins on raw floor share but reverses the whole lounge. Honest risk: on a phone
  a fixed axis may feel worse than the old stick; the card offers "follow the camera but hold through the swing" as an out.
- Switch: `static var control_frame := ControlFrame.VENUE_NORTH` in `game/scripts/player.gd`.

## Not verified
- Real phone (touch feel, iPhone). Web build not rebuilt by me. Captures are windowed desktop renders.
- STATE/LOG not touched (orchestrator's files).

## Files
game/scripts/player.gd, game/tools/build_venue.gd, game/scenes/venue/venue.tscn (rebuilt), game/tests/test_walk.gd (+uid),
game/tests/test_touch.gd, game/tests/capture_movement.gd, game/tools/movement_compose.py, docs/art/screens/movement-polish/,
handoffs/movement-polish-2026-11-04.md, this report.
