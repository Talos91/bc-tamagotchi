# 🏗️ Venue fixes: role note (2026-11-03, state now)

Worker: venue (Opus), session local_0ea22856, briefed by the orchestrator local_ddbbfc1d. Owner words:
`handoffs/owner-feedback-2026-11-02.md` items 4, 5, 6, 7, 8, 11 (authorised layout changes). Built on 86b40ab (look-followups).
Report: `handoffs/worker-reports-2026-11/venue-fixes.md`. Captures: `docs/art/screens/venue-fixes/{before,after}/`.

## What changed (all in `game/tools/build_venue.gd` unless named)
4. **Door between the bar and the walled bar area:** `BAR_DOOR` (z 13.4–14.4) in the staff room's west wall (x 35.75),
   swing door `BarDoor`, kit `staff_door` like the north one, front to the bar (-90), staff-only (`staff_door_user`,
   blocker in the opening: the player never gets behind the counter, `BarFloorBlock`). The hatch staff's errands go
   through it to behind the counter and back (`scripts/venue_patrons.gd` `BAR_DOOR_X/Z`; item 15 below).
5. **Raised bar and walled bar area:** `BAR_FLOOR_H` 0.45: `BarDuckboard` (planks, counter back to the back-bar fronts,
   no collider: it is behind `BarFloorBlock`) and `StaffRoomDeck` (inset to the walls' inner faces, the closed-room
   no-shared-face rule); `StaffShelf` stands on it; spots `Staff_Hatch` and `Spawn_StaffArea` at y 0.45.
   `venue_patrons.gd` `BARTENDER_LIFT` 0.3 → 0.45 (figures are 1.16 m: about 0.5 m shows over the 1.1 m counter, head
   and shoulders as photo 09; at 0.3 only the head did). Judgement card: `venue-fixes-bar-height`.
6. **Buffer curtain in the view:** the curtains and the PAR stand keep `cut_sight_only` and now carry
   `cut_rooms ["buffer"]`; `scripts/camera_rig.gd`: such a piece is also cut, in its own rooms' views only, when it
   is wholly nearer the camera than the player and in view (the south pair filled the buffer view's foreground).
   From the main room and the lounge they stay up as Daniele asked (Questions tab 2026-11-01).
7. **Male toilet door:** the door was there but the back bar's west bays hid it from the toilets view and it was black
   on black. The bays carry `cut_rooms ["toilets"]` (same camera rule: cut when nearer than the player in that view),
   and each toilet door has a lit plaque with M / F over it (`_toilet_plaque`, a Label3D: no string key).
8. **Buffer east curtains:** the kit `curtain_panel` has folds on one face and a flat dark back; at 90 the main-room
   side showed its back into the buffer. A second panel hangs back to back on that side at -90 (`Curtain_*In`).
11. **Unused corridor barrier:** the stair's velvet rope is now `_velvet_rope()` (stair unchanged, same node names);
   `Alcove` rope across the old-corridor alcove 0.35 m inside its mouth plus collider `AlcoveStop` (navmesh stops).
   The alcove camera zone stays but is unreachable in play (`test_feel` still teleports there).

## Follow-up: owner feedback item 15 (live build 4826ba6, 2026-11-03)
- **No stepping:** the hatch staff's errand is now only the bar door, behind the counter on the raised floor
  (`venue_patrons.gd`: `_bar_errand` and the north-door route and its y-snap are gone, `STAFF_DOOR_X/Z` removed). The
  north staff door into the main room stays shut (it still swings for `staff_door_user`, nobody goes there now).
- **Solid walled area:** its north wall is its own piece `StaffRoomNorth` (hatch + staff door; `WallSouthEast` now runs
  from `STAFF_ROOM_X1` 38.25 only), and `_main_room` takes every `StaffRoom*`, `StaffDoorBar`, `BarDoor`, `Pass*` node
  out of the cutaway (`_uncut`). The smoking view's see-through strip and the nearer-than-player rule no longer open it.
  No layout.json change (walls are not kit; `export_layout.gd` output was not committed, see below).
- Tests: `smoke_doors_sit` checks the errand stays at y 0.45 inside the walled area / behind the bar with the north door
  shut, and that no walled-area piece is in the cutaway. Captures `before-15/`, `after-15/` (staff-from-smoking,
  -floor, -bar; portrait + landscape), two-up `twoup-15-walled-area-solid.png`.

## Orchestrator additions (verify of 24ff659 failed 12/14)
- **smoke_loop "walked to table:LongTable":** the long table's top grew a navmesh island; the seat-group zone's
  approach is the table centre, so the walk snapped onto the island and ended at the table's north tip (3.93, 3.01),
  1.99 m from the centre, outside the 1.95 m zone circle. Before 86b40ab's closed-room inset the same end landed a few
  cm inside (the inset re-cut the navmesh). Fix in `build_venue.gd`: collider `NavTopBlock` over the table top (0.75–
  2.45 m) leaves no headroom, so no island; the approach now snaps to the floor east of the chairs (5.4, 5.0), 1.5 m in.
  The table does not move. Side effect: a tap whose ray crosses above the long table resolves to the table zone, as a
  tap on the table does. The fragile part (a 4 cm margin, `venue_zones.gd` SEAT_MARGIN) is not mine; left as is.
- **test_minigames:** the cast check expected "Tt"; Ty since dd4e03c (`tests/test_minigames.gd`, that line only).

## layout.json (frozen file; every change recorded here)
- + `Curtain_198_34In`, `Curtain_198_71In` (curtain_panel, x 19.8, z 3.4 / 7.2, rot -90): item 8.
- + `BarDoorLeaf` (staff_door, 35.85, 0.45, 13.9, rot -90): item 4.
- spawns `Staff_Hatch` and `Spawn_StaffArea` y 0 → 0.45: item 5.
- Only these were written in (merged onto the committed file by hand). A full re-export would also bring in the
  look-followups stage/lounge/bar pieces (+ `PatronsBoardMonth`, `ElectricPiano`, `CurtainBack6`, spawn `Band_Keys`,
  moved backdrop and curtains, `Bay4`, `ReindeerHead`, − `Mic0`, − `PedalboardGtr`); that waits on the open card
  `look-followups-layout-export`, so `export_layout.gd` output is NOT what is committed until it is answered.

## Tests and captures
`smoke_doors_sit` new section "bar area and alcove" (bar door built, raised floors, bartender/hatch height, the errand
through the bar door opens and closes it, the north errand steps down, navmesh and player stop at the alcove rope).
`test_lounge` curtain section: six panels, the inner pair at -90, from the buffer the south panels cut and the north
stand. Captures: `game/tests/capture_venue_fixes.gd` (`--tag=portrait|landscape`, `--out`, `--only`; views with
`cam` use a fixed overview camera, the rest the game's own). No kit change, so no review `.blend`.

## Re-running
From game/: `--script res://tools/build_venue.gd`, then `--script res://tools/export_layout.gd`; captures windowed
`--path . --resolution 540x960 --script res://tests/capture_venue_fixes.gd -- --tag=portrait` (960x540 landscape).
