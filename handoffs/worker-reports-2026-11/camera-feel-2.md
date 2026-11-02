# 🎮 camera-feel-2: worker report (2026-11-02)

**Commits cdb2dce, e04b8e9, d5825cb, 406d2fd** (main, not pushed; this report and the role note are one more commit
on top). **Suites on 406d2fd: 14/14 PASS** (clean `git archive`, imported, venue rebuilt = committed scene apart from
unique_ids, APPDATA empty per suite). Hub cards: camera-feel-2-accept, camera-closer-still, camera-patrons-in-front. Ready to verify: yes (406d2fd; the docs commit on top changes only handoffs and captures).

Brief: Daniele's camera answer (DECISIONS "Camera, what feels clunky", 07:26): trails behind when walking; walls or
furniture still in the way; too far, too close or too steep. Only those three (turn speed, surprise turns and
tap-to-walk not ticked, left alone), plus test_feel's wall-clock timing. Daniele did not message this session.

## History of the four commits
- cdb2dce: the pass. Its own 14-suite run: 12/14; smoke_loop (the Lounge entry bonus landed one tick late: the rig
  now steps on physics ticks, the area was set after the session's first check) and test_lounge 7 (headless windows
  are 1920 x 1920 = the landscape branch: the raised-strip tables above the frame, a buffer curtain beside the nearer
  camera).
- e04b8e9: `snap()` frames the player at once (also when the zones are collected), test_lounge runs at the game's
  portrait size 1080 x 1920, floor view -36/5.6 (cdb2dce had -40/5.2: from mid-floor the raised strip left the frame
  in landscape), test_feel checks the raised strip in frame from mid-floor in portrait and landscape.
- d5825cb: corridor look clamp starts at x 4.6 (was 3.5): in portrait the nearer corridor camera stood just behind
  the lobby's street wall and a tap from the corridor's west end hit the wall's collider (test_lounge "tap on
  portrait:3"); test_lounge's curtain check adapted (below). Its 14-suite run: 13/14, test_feel failed its new
  landscape check (raised strip 14 px above a real 16:9 landscape frame).
- 406d2fd: `landscape_dist_scale` 1.3 -> 1.5 (landscape shows less height, vfov 42; the raised strip is in frame from
  mid-floor again); test_feel snaps again after resizing the window.

## 1. Trails behind
- Before (14cda24): follow spring 0.3 s, lead 0.4 s of velocity built by a 0.6 s spring. At walking speed (3.6 m/s)
  the look point trailed up to 0.70 m behind the player (bar walk), 0.7-0.9 m in the lobby, corridor, memory and
  smoking walks (sight-line probe; larger figures elsewhere are clamps at room edges).
- After: `follow_time` 0.12 s, `lead_time` 0.25 s, lead spring `LEAD_SETTLE` 0.25 s, `LEAD_MAX` 1.2 m. Walking the
  floor the look point trails by at most **0.17 m** and stays within **0.50 m** of the player (test bounds 0.35 /
  0.9); on average it is slightly ahead. Back on the player 0.62 s after a stop.
- No jitter, no jumps: the look point = tight follow of the player + a framing offset (clamp and look height) on its
  own spring (0.2 s at a room edge, the swing's time after a view change). Without that split the tight follow
  jumped 0.56-0.68 m in one tick when a door or area changed the clamp. The rig steps in `_physics_process`, in
  lockstep with the player, with a fixed delta. Largest tick-to-tick change of the camera's step: 0.008 m at
  start/stop and on the stairs. Dwell 0.3 s, swings and per-area views unchanged.

## 2. Walls or furniture in the way
Tool: a sight-line probe, now the `occlusion` section of test_feel: tap-walks through every area; every other tick the
segment from the camera to the player's chest (0.8 m) and head (1.25 m) against every visible mesh's own box.
Found on 14cda24 and fixed (now hidden only while they cover the player, `cut_sight_only`):
- `Buffer/ValanceE`, `ValanceW` and `BufferPar`: walking floor -> buffer -> lounge (Buffer and Lounge buttons),
  33 and 48 occluded samples.
- `TreeRightOfStage`: on the raised strip, 15 samples (`twoup-portrait-occl-raised-tree.jpg`).
- `Bar/Bay0` (all nine back-bar bays now): toilets view by the vestibule, 90 + 39 samples, also standing still
  (`twoup-portrait-occl-toilets-backbar.jpg`).
- `Lounge/TrackLight0/1`: appeared with the nearer lounge camera, 6 samples.
After: **16 routes, 0 occluded ticks** (lobby, corridor, lounge, merch, memory, patrons, buffer, lounge <-> floor both
ways, alcove, floor, raised strip, stage, bar, toilets, smoking).
Already fine: shelves, wine fridge, light box, columns, reindeer panel, posters (cutaway since the feel pass / look
build), swing doors (tested as they stand), stubs 0.4 m = 10 % of the 4 m rooms (Daniele's rule; checked).
Not counted: other characters. Passing patrons stood between the camera and the player in 18-37 samples of the floor
walk (question card).

## 3. Too far / too close / too steep
At 450 x 800 the character was ~60-75 px tall and the top third of most frames showed upper walls (portrait's
vertical field of view is ~81°, so a -32° pitch looks above the horizon). Pitch / distance:

| area | before | after | character (px of 800) |
|---|---|---|---|
| floor | -32 / 8.5 | -36 / 5.6 | 67 -> 86 |
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

(before = probe averages over the walks; after = standing in each area, test_feel.) Clamps: bar x to 36.0 (walking
to the red door the player left the frame before the smoking view took over), buffer 1.8 m wide (was 0.3), stage
x 28.4-33.4, smoking Rect2(38.2, 12.8, 2.6, 3.6), corridor from x 4.6. The smoking view stays a little farther (5.4)
so its four tables show from the main room in front of the red door (area-camera check kept). Landscape: same values
x 1.5 (was 1.3); from mid-floor the raised strip is in frame in both orientations (new check).

## 4. Deterministic timing
test_feel's turn-speed check used `Time.get_ticks_usec()`; it and the camera-step checks now read the rig once per
physics tick (fixed delta). Movement times were already counted in ticks.

## Tests changed
- `test_feel.gd`: 133 checks (new: follow 4, stairs shake 1, raised strip from mid-floor 2, framing 26, occlusion 16).
- `test_lounge.gd` (lounge worker's file, adapted to the camera): runs portrait 1080 x 1920 (the headless window is
  square, i.e. the landscape branch); the curtain check now asks both main-side curtains to stand (never cut) from all
  three main-room spots, both in frame in front of the opening (21.6, 5.3), and the one on the player's side in frame
  at the two off-centre spots: there the nearer camera has the other just outside the frame (measured at floor
  distances 5.2-6.5, never both). Flagged on the acceptance card.

## Captures (`docs/art/screens/camera-feel-2/`, portrait 1080 x 1920; after = d5825cb, landscape after = 406d2fd)
- `twoup-portrait-area-<area>.jpg` (13 areas, before = 14cda24 | after), `portrait-area-<area>.png`, `areas-sheet.jpg`.
- `walk-strip.jpg`: walk across the main room at 0.25 / 0.7 / 1.3 / 2.2 s and stopped, before row over after row;
  `portrait-walk-1..5.png`.
- `twoup-portrait-occl-{raised-tree,toilets-backbar,buffer-valance}.jpg`, `portrait-occl-*.png`.
- Landscape: `twoup-landscape-area-{floor,bar,stage,lounge}.jpg`, `landscape-area-*.png`.
- Scripts: `game/tests/capture_camera2.gd`, `game/tools/camera2_compose.py`. Before PNGs not committed.

## Open questions (hub cards)
- `camera-feel-2-accept` (order 40, kind now): accept? Six pictures (floor, walk strip, raised-strip tree, toilets
  back bar, lounge, landscape floor) and the folder + this report as files. Mentions the curtain side effect.
- `camera-closer-still` (order 41, design): as it is (rec) / one step closer / halfway back; picture: all 13 views.
- `camera-patrons-in-front` (order 42, design): passing customers can cover the character; leave them solid (rec) /
  fade them while they cover you.

## Notes
- `docs/tech/02-playtest-guide.md` camera lines still give the feel pass's spring numbers (doc; left for the
  orchestrator / housekeeping).
- Five superseded card pictures from the first upload stay in the hub's asset store (unreferenced): 94db5637...,
  2c47c263..., cbb7063a..., a25cd923..., 1cc01461..., 6496540a...
- Still not done from the brief: nothing; layout untouched (navmesh 561 polygons, as before).
