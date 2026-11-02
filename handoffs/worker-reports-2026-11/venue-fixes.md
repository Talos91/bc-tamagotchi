# 🏗️ venue-fixes: owner feedback 4, 5, 6, 7, 8, 11 + smoke_loop / test_minigames fixes (2026-11-03)

## EVIDENCE: follow-up, owner item 15 (2026-11-03)
- Commit `3492232` on local main (not pushed), after `e4d7e76`/`bf0875a`; then this report + role note.
- Suites, shared tree, empty APPDATA per suite: **5/5 PASS**: smoke_doors_sit, test_seats, test_feel,
  test_nightlife, smoke_start.
- Hatch staff errands only through the bar door, at y 0.45 throughout (no step); the north staff door stays shut.
  Walled area (`StaffRoom*`, `StaffDoorBar`, `BarDoor`, `Pass*`) out of the camera cutaway; `StaffRoomNorth` split
  from `WallSouthEast`. No layout.json change. Card `venue-fixes-review` v2 (item 15 text + picture).
- Captures `docs/art/screens/venue-fixes/before-15/`, `after-15/` (staff-from-smoking, -floor, -bar; portrait +
  landscape), `twoup-15-walled-area-solid.png`. Item 15 had no saved picture; worked from the note.

## EVIDENCE (first round)
- Commit on local main (not pushed): `e4d7e76` (code, venue, layout lines, tests, captures); then this report + role note.
  Base 86b40ab (look-followups) clean at the gate; built on top of b8f6d50/d32407a (touch-anywhere).
- Suites, shared tree, empty APPDATA per suite, all on the final venue: **9/9 PASS**: smoke_loop, test_minigames,
  smoke_doors_sit, test_seats, smoke_tap, smoke_stairs, test_lounge, test_feel, smoke_start. (smoke_doors_sit ran
  again alone after its sit helper fix; the other eight in one batch.) test_touch not run (orchestrator: not needed).
- Orchestrator fixes: **smoke_loop** LongTable walk: `build_venue.gd` collider `NavTopBlock` over the long table (its
  top had a navmesh island; the zone approach = table centre snapped onto it; the walk ended at 1.99 m vs a 1.95 m
  zone). Now the approach snaps to floor (5.4, 5.0), 1.5 m in. Table not moved. **test_minigames** line 404 expects Ty.
- Venue: 42 lights, 1 shadowed; navmesh 553 polygons; layout 736 kit instances (generator output).
- Hub cards (Questions tab): `venue-fixes-review` (7 pictures + files), `venue-fixes-bar-height` (0.45 m, rec),
  `venue-fixes-bar-door` (staff-only, rec).
- Captures `docs/art/screens/venue-fixes/`: `before/` (86b40ab venue) and `after/`, portrait 1080×1920 + landscape
  1920×1080: bar, bar-east, bar-door-top, bar-side, buffer, buffer-west, buffer-east, buffer-from-main, buffer-top,
  toilets, alcove, alcove-top (+ portrait-only before for buffer-east-in, buffer-west-in, toilets-top; after both).
  Two-ups `twoup-{4-bar-door,5-bar-height,6-buffer-curtain,7-toilet-door,8-buffer-east-curtains,11-alcove-rope}.png`.
- No kit change, so no review `.blend`. Role note: `handoffs/venue-fixes-2026-11-02.md` (every layout.json line).

## What was built (details in the role note)
4. `BarDoor`: staff_door in the walled bar area's west wall, z 13.4–14.4, staff-only (blocker); the hatch staff's
   errands alternate between it (to behind the counter) and the north door.
5. `BAR_FLOOR_H` 0.45: `BarDuckboard` behind the counter, `StaffRoomDeck` in the walled area; bartender lift 0.45,
   hatch staff and staff spawn at 0.45; the hatch staff steps down at the north door. Figures are 1.16 m tall.
6. Buffer curtains and PAR stand: also cut in the buffer view when nearer the camera than the player
   (`camera_rig.gd`: cut_sight_only pieces with cut_rooms). Main-room and lounge views unchanged.
7. The men's door existed but was hidden by the back bar's west bays in the toilets view (now cut there, same rule)
   and black on black (now a lit M plaque; F too).
8. Main-room side of the buffer: second curtain panel at -90, folds into the buffer (kit panel is one-sided).
11. `_velvet_rope()` (stair rope refactored, unchanged) across the alcove mouth + `AlcoveStop` blocker.

## Judgement calls (cards)
- Bar floor height 0.45 m (0.3 showed only heads; 0.6 offered).
- Bar door staff-only: the player still never goes behind the counter.

## For the orchestrator
- `layout.json`: only my lines are committed. `export_layout.gd` output now also differs by the look-followups pieces
  (stage, piano, second poster, Band_Keys spawn, Bay4, reindeer); that waits on the open card
  `look-followups-layout-export`. Whoever exports next must keep that in mind.
- NavTopBlock side effect: a tap whose ray crosses above the long table (0.75–2.45 m) resolves to the table zone.
- The 4 cm zone margin behind the smoke_loop failure is `venue_zones.gd` SEAT_MARGIN 0.35 (not mine; untouched).
- The alcove camera zone is now unreachable in play; test_feel still teleports there (passes).
- Version stamp in captures reads 545eae3 (stale `version_info`, not re-stamped; orchestrator stamps builds).
