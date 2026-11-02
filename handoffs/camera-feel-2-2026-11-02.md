# 🎮 Camera feel 2: role note (2026-11-02, state now)

Done and closed: no worker of this role is running. Worker: gameplay (Opus), briefed by the orchestrator
local_9bb3d41c after Daniele's camera answer (DECISIONS "Camera, what feels clunky", Questions tab 07:26: trails
behind when walking; walls or furniture still in the way; too far, too close or too steep; not ticked: turn speed,
surprise turns, tap-to-walk). Builds on the feel pass (`handoffs/feel-pass-2026-11-02.md`) and the area camera
(`handoffs/area-camera-2026-11-02.md`). Report: `handoffs/worker-reports-2026-11/camera-feel-2.md`. Code commit cdb2dce.

## What exists now (`game/scripts/camera_rig.gd`)
- **Follow:** `follow_time` 0.12 s (was 0.3), `lead_time` 0.25 s (was 0.4), lead spring `LEAD_SETTLE` 0.25 s (was a
  literal 0.6), `LEAD_MAX` 1.2 m (was 1.6). The look point is `_follow` (tight spring on the player's feet + lead) plus
  `_frame` (clamp correction and look height) on its own spring: `CLAMP_SETTLE` 0.2 s at a room's edge, the swing's
  time right after a view change, blending back over the swing. That split is what keeps a tight follow from jumping
  when a door or a new area changes the clamp. `_look` is still the sum (tests and occluders read it).
- **Physics step:** the rig works in `_physics_process` (lockstep with the player, which moves only on physics ticks;
  with a tight follow at the display rate the figure would shake on screen) and so with a fixed delta. `set_process()`
  is still the on/off switch (street_shot.gd and start_screen.gd call it): `_physics_process` returns while
  `is_processing()` is false; `_ready` turns processing on.
- Dwell 0.3 s, swings, focus_on / release_focus, the cutaway rules and `STUB_H` 0.4 m (10 % of the 4 m rooms) are
  unchanged.

## Zone data (`game/tools/build_venue.gd` `_camera_zones()`), pitch / distance, before -> after
floor -32/8.5 -> -40/5.2 · bar -32/7.0 -> -40/5.2 · stage -28/7.5 -> -34/5.2 · toilets -34/6.0 -> -42/4.8 ·
smoking -40/6.5 -> -46/5.4 · buffer -32/7.0 -> -40/4.6 · lounge -34/8.0 -> -40/5.0 · merch, memory -34/6.5 -> -38/5.0 ·
patrons -30/5.2 -> -34/4.8 · alcove -48/5.5 -> -50/4.2 · corridor -34/6.0 -> -36/5.0 · lobby -36/6.5 -> -40/5.0.
Clamps: bar x to 36.0 (was 34.0: the player walking east to the red door left the frame before the smoking view took
over), buffer Rect2(16.8, 4.2, 1.8, 2.2) (was 0.3 m wide), stage x 28.4-33.4, smoking Rect2(38.2, 12.8, 2.6, 3.6).
Landscape keeps `landscape_dist_scale` 1.3.

## Sight-line cuts added (all `cut_sight_only`: hidden only while they cover the player)
Buffer `ValanceW` / `ValanceE` and `BufferPar`, `TreeRightOfStage`, the nine back-bar bays `Bay0..8` (the west ones
stood in the toilets view), lounge `TrackLight0/1`. `venue.tscn` rebuilt (layout untouched, navmesh 561 polygons).

## Tests (`game/tests/test_feel.gd`, 131 checks)
New sections follow (trail <= 0.35 m, within 0.9 m, back on the player <= 0.8 s, step-change <= 0.012 m per tick at
start/stop, <= 0.024 on the stairs), framing (every area's pitch/distance; the character >= 80 px of 800 standing in
each area, smoking >= 72), occlusion (16 tap-walk routes; every other tick no visible mesh, by its own box, on the
camera -> chest or head line; characters not counted). Turn speed and camera steps are per physics tick now.

## Tools
`game/tests/capture_camera2.gd` (windowed: `--tag=portrait|landscape --prefix=before- --out=DIR --only=areas|walk|occl`),
`game/tools/camera2_compose.py SHOTS_DIR` (two-ups, walk strip, areas sheet into `docs/art/screens/camera-feel-2/`).
The sight-line probe used for the before numbers is the `occlusion` section of test_feel (the scratch version also
logged screen offset and character size per area; numbers in the report).

## Gotchas
- A Godot `--import` of a fresh archive can segfault part-way (exit message only); run it twice or fonts are missing.
- Headless process frames run far faster than physics; anything timed by the camera must be read on physics frames.
- Passing patrons can still stand between the camera and the player (not furniture; open question on the hub).
