# 🎮 camera-feel-2: worker report (2026-11-02)

**Commits cdb2dce + the follow-up fix commit (see git log), main, not pushed. NOT READY TO VERIFY** (usage limit
reached mid-fix). Suites on cdb2dce (isolated archive, APPDATA empty each): 12/14 PASS; smoke_loop failed (zone set
one tick late; fixed in the follow-up: snap() frames at once) and test_lounge failed 7 (headless window is square =
landscape framing; raised tables above the frame, main-side curtains beside the nearer camera). Follow-up commit:
snap() immediate, test_lounge runs portrait 1080x1920, floor view -36/5.6 (was -40/5.2 in cdb2dce; the raised strip
is in frame from mid-floor in portrait and landscape), test_feel landscape raised-strip check. **Still failing
(measured, not yet rerun as suites):** test_lounge "both main-side curtains stand in view" at (22.4, 6.2) and
(21.4, 4.2): one of the two curtains is beside/behind the nearer floor camera at any distance 5.2-6.5. Needs a call:
move those test spots east / accept one curtain, or keep the floor view farther. Full 14-suite rerun not done.
Hub cards NOT written (pictures uploaded: /_blob/94db5637348d1ee36ddb3038c61a5cde floor two-up,
/_blob/2c47c263819809518596ff693e295fcd walk strip, /_blob/cbb7063a3f7df9bdeb32c787b0564b85 raised tree,
/_blob/837b5b6f3922a2ae36fff3112365e6e6 toilets back bar, /_blob/604d6b7a9ae151dd78629158a5c8fc48 lounge,
/_blob/a25cd923e67b28afd38084af9791bcc3 areas sheet, /_blob/1cc01461f4094ff563aabd93a8cb3dd6 landscape floor).
Floor numbers in the table below are cdb2dce's (-40/5.2, 87 px); now -36/5.6 (~86 px); captures are of cdb2dce.

Brief: Daniele's camera answer (DECISIONS "Camera, what feels clunky", 07:26): trails behind when walking; walls or
furniture still in the way; too far, too close or too steep. Only those three (turn speed, surprise turns and
tap-to-walk not ticked, left alone), plus test_feel's wall-clock timing.

## 1. Trails behind
- Before (14cda24): follow spring 0.3 s, lead 0.4 s of velocity built by a 0.6 s spring. At walking speed (3.6 m/s)
  the look point trailed up to 0.70 m behind the player on the bar walk and 0.7-0.9 m in the lobby, corridor, memory
  and smoking walks (sight-line probe, every frame; larger figures elsewhere are clamps at room edges).
- After: `follow_time` 0.12 s, `lead_time` 0.25 s, lead spring 0.25 s, `LEAD_MAX` 1.2 m. Walking the floor the look
  point trails by at most **0.17 m** and stays within **0.50 m** of the player (test: bounds 0.35 / 0.9); on average
  it is now slightly ahead. Back on the player 0.62 s after a stop.
- No jitter: the look point = tight follow of the player + a framing offset on its own spring (0.2 s at a room edge,
  the swing's time after a view change). Without that split the tight follow jumped 0.56-0.68 m in one tick when a
  door or area changed the clamp (caught by test_feel's no-jump checks). The rig now steps in `_physics_process`, in
  lockstep with the player (which only moves on physics ticks), with a fixed delta. Largest tick-to-tick change of the
  camera's step: 0.008 m at start/stop, 0.008 m on the stairs. Dwell 0.3 s and the per-area views are unchanged.

## 2. Walls or furniture in the way
Tool: a sight-line probe (now the `occlusion` section of test_feel): tap-walks in every area, each tick the segment
from the camera to the player's chest (0.8 m) and head (1.25 m) against every visible mesh's own box.
Found on 14cda24 and fixed (all now hidden only while they cover the player, `cut_sight_only`):
- `Buffer/ValanceE`, `ValanceW` (curtain valances over the buffer openings) and `BufferPar` (PAR on its stand):
  walking floor -> buffer -> lounge (the Buffer and Lounge buttons): 33 and 48 occluded samples.
- `TreeRightOfStage`: on the raised strip, 15 samples. Picture `twoup-portrait-occl-raised-tree.jpg`.
- `Bar/Bay0` (back-bar bay; all nine bays now): in the toilets view by the vestibule, 90 + 39 samples (also at rest).
  Picture `twoup-portrait-occl-toilets-backbar.jpg`.
- `Lounge/TrackLight0/1`: appeared with the nearer lounge camera, 6 samples.
After: **16 routes, 0 occluded ticks** (lobby, corridor, lounge, merch, memory, patrons, buffer, lounge <-> floor both
ways, alcove, floor, raised strip, stage, bar, toilets, smoking).
Checked and fine already: shelves, wine fridge, light box, columns, reindeer panel and posters (cutaway since the feel
pass / look build), swing doors (tested as they stand each frame), stubs at 0.4 m (= 10 % of the 4 m rooms, Daniele's
rule; test "cut walls stand as 0.4 m stubs" still passes). Not counted: other characters. Passing patrons stood
between the camera and the player for 18-37 samples on the floor walk (question card).

## 3. Too far / too close / too steep
At 450 x 800 the character was ~60-75 px tall and the top third of most frames showed upper walls (portrait's
vertical field of view is ~81°, so a -32° pitch looks above the horizon). New values, pitch / distance:

| area | before | after | character (px of 800) |
|---|---|---|---|
| floor | -32 / 8.5 | -40 / 5.2 | 67 -> 87 |
| bar | -32 / 7.0 | -40 / 5.2 | 71 -> 85 |
| stage | -28 / 7.5 | -34 / 5.2 | 68 -> 88 |
| toilets | -34 / 6.0 | -42 / 4.8 | 78 -> 84 |
| smoking | -40 / 6.5 | -46 / 5.4 | 68 -> 74 |
| buffer | -32 / 7.0 | -40 / 4.6 | 70 -> 88 |
| lounge | -34 / 8.0 | -40 / 5.0 | 62 -> 82 |
| merch / memory | -34 / 6.5 | -38 / 5.0 | 73 -> 89 |
| patrons | -30 / 5.2 | -34 / 4.8 | 103 -> 100 |
| alcove | -48 / 5.5 | -50 / 4.2 | 70 -> 85 |
| corridor | -34 / 6.0 | -36 / 5.0 | 80 -> 92 |
| lobby | -36 / 6.5 | -40 / 5.0 | 71 -> 84 |

(before = probe averages over the walks; after = test_feel standing in each area.) Clamps: bar x to 36.0 (the walk
to the red door left the frame before the smoking view took over), buffer 1.8 m wide (was 0.3), stage x 28.4-33.4,
smoking Rect2(38.2, 12.8, 2.6, 3.6). The smoking view stays a little farther (5.4) so its four tables show from the
main room in front of the red door (test kept). Landscape: same values x 1.3 (unchanged scale); captured for floor,
bar, stage, lounge.

## 4. Deterministic timing
test_feel's turn-speed check used `Time.get_ticks_usec()`; it and the camera-step checks now read the rig once per
physics tick (fixed delta), so load cannot change them. Movement times were already counted in ticks.

## Tests
`test_feel.gd`: 131 checks (new: follow 4, stairs shake 1, framing 26, occlusion 16). See the status at the top.

## Captures (`docs/art/screens/camera-feel-2/`, portrait 1080 x 1920)
- `twoup-portrait-area-<area>.jpg` (13 areas, before = 14cda24 | after), `portrait-area-<area>.png` (after),
  `areas-sheet.jpg` (all areas after).
- `walk-strip.jpg`: walk across the main room at 0.25 / 0.7 / 1.3 / 2.2 s and stopped, before row over after row;
  `portrait-walk-1..5.png`.
- `twoup-portrait-occl-{raised-tree,toilets-backbar,buffer-valance}.jpg`, `portrait-occl-*.png`.
- Landscape: `twoup-landscape-area-{floor,bar,stage,lounge}.jpg`, `landscape-area-*.png`.
- Scripts: `game/tests/capture_camera2.gd`, `game/tools/camera2_compose.py`. Before PNGs are not committed.

## Open questions (hub cards)
Not written yet. Planned: acceptance card (order 40) with the seven pictures above and the folder; question 'closer still?' (order 41, areas sheet); question 'fade other characters on the sight line?' (order 42).

## Not done / notes
- Did not touch turn speed, dwell, tap-to-walk, layout. `docs/tech/02-playtest-guide.md` camera lines still describe
  the feel pass's spring numbers (doc, left to housekeeping/orchestrator).
- Daniele did not message this session.
