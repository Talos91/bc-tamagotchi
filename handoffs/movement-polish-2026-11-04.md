# 🎮 Movement polish: role note (2026-11-04, state now)

Worker: gameplay (Opus), session started by the orchestrator local_ddbbfc1d. Owner words: `handoffs/owner-feedback-2026-11-04.md`
items 17 (stick follows the camera, wants a fixed axis) and 18 (stuck between tables). Report:
`handoffs/worker-reports-2026-11/movement-polish.md`. Captures: `docs/art/screens/movement-polish/`.

## What exists now (`game/scripts/player.gd`)
- **Control frame** `Player.control_frame` (static var, THE one-line switch, its default): `VENUE_NORTH` (built: screen-up =
  -z, the venue's north), `FIRST_CAMERA` (yaw of the camera at the first stick use, the lobby's = north today, so
  identical now), `MAIN_ROOM` (screen-up = east, the main room's view), `CAMERA` (the old stick: camera-relative, latched
  for one press). `control_yaw()`, `input_to_world()`, `world_to_input()` all go through it; keys use it too.
- **Why it is a call for Daniele:** the area cameras face all four ways (lounge 90, main floor -90, bar/toilets/smoking 180,
  lobby/buffer/stage/merch/memory 0). Any fixed axis disagrees with the screen somewhere: measured over the walkable floor
  (navmesh samples, per area share), every fixed yaw is ~90° off on average and within 45° of the screen on only 20 %
  (north) to 29 % (main-room east) of the floor; north is reversed in the bar, toilets and smoking room, main-room east is
  reversed in the lounge. Cards: `movement-polish-review`, `movement-axis-choice`.
- **Tap-walks:** paths cleaned of repeated corners (`_clean`; a run of identical points filled the four-segment pursuit
  window and the figure swung to and fro forever by the buffer's tall tables). Pursuit search spans >= 2 m of path
  (`_pursue`). Stall net `_check_stall`: no 5 cm of progress in `STALL_TIME` 0.5 s → re-plan; within `ARRIVE_NEAR` 0.3 m →
  arrived; after `STALL_REPLANS` 2 → give up (never "walking" on the spot).
- **Stick on the walkable area** (`_steer_stick`): on flat floor a step that would leave the navmesh (0.4 m clear of every
  collider) slides along its edge, so the 0.35 m capsule never wedges between two stools or into a pocket by a table.
  Head-on into an edge, or physically blocked `DETOUR_BLOCKED` 0.1 s: navmesh path to a point 1.5 / 2.5 / 3.5 m ahead in
  the stick's direction, followed while the stick holds within 35°, max 1.5 s; refused if longer than 1.5 x straight +
  0.5 m or if it passes a swing door within 0.8 m (`_through_door`: pushing at the staff room's wall once detoured through
  the red door). Free as before where the floor ahead is not level (stairs, ramps: the lounge stair's second flight has
  no navmesh) or off the navmesh (seats, test spots).
- **Navmesh** (`game/tools/build_venue.gd` `_navigation`): `edge_max_error` 0.4 cells (was the default 1.3 = 0.13 m: edges
  crept to ~0.27 m from chairs, inside the capsule). Polygons 561 → 2023. `venue.tscn` rebuilt (layout untouched; the diff
  is mostly unique ids). Tried and dropped: `region_min_size` 8 (drops the small navmesh islands in the pockets between
  tiny tables and stools); not needed once the stick stays on the mesh it walks on, so the default stays.

## Tests
- New `game/tests/test_walk.gd` (PROJECT.md Tests: orchestrator adds it): 315 tap-walks from random navmesh starts (same
  room, 1.5–9 m, seed 1104) to every seat's approach point (lounge tables, long table, bar stools, buffer tall tables,
  main room); fail > 0.3 m short or stall. Then 90-odd stick pushes held straight at a seat 3–6 m away for 2 s; a wedge =
  no motion 0.5 s while a short way round exists from where it stands (path <= 1.5 x straight + 1 m); fails over 2 %.
  Player stepped by hand (120 steps per physics frame), runs in ~35 s. `-- --list`, `-- --seed=N`, `-- --max=N`.
- `test_touch.gd` section 7 `fixed_axis`: drag up held in the lobby (yaw 0), player moved to the main floor (-90) and the
  bar (180) with the finger down: same world heading; a fresh drag after the swing: same; every fixed frame ignores
  `rig.yaw`, CAMERA follows it.

## Tools
`game/tests/capture_movement.gd` (windowed, `--resolution 540x960` / `960x540`, args `<out> <portrait|landscape>
<camera|north|first_camera|main_room>`; writes the shots + a JSON of finger and figure screen motion) and
`game/tools/movement_compose.py <shots dir>` (2x to 1080x1920 / 1920x1080, yellow finger / cyan walk arrows, strips and
sheets). The window cannot open at 1080x1920 on this screen (clamped to 1421 high), hence the 2x.

## Open
- Axis choice (card). If Daniele wants screen-relative after all, `CAMERA` + a latch that holds through the swing is the
  likely answer; the nav and stick fixes stay whatever the frame.
- Not verified on a real phone.
