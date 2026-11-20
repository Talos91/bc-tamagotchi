# Role note: 🌐 overflow-seats (social features), 2026-11-20

Branch `wk/overflow-seats` (worktree `C:/Users/itisf/bc-wt/overflow-seats`), based on 4e9dbc8 (venue entrance round).
Brief: Daniele 2026-11-20, "we will be more than 4 people at a table so we need to factor how that look i suggest
factoring optional seating appearing only when you pass the 4 people". QR freeze respected (docs/venue/qr/ untouched).

## State now
- DONE, committed, not pushed. Suite `test_overflow_seats` (new, 33rd file in game/tests; PROJECT.md Tests list to be
  updated by the orchestrator). Hub card `overflow-seats-review` (10 pictures, files list).
- Code: `game/scripts/presence_ui/overflow_seats.gd` (new: slot geometry + markers/chairs), `game/scripts/venue_patrons.gd`
  (+ `_table_overflow`, `_overflow_pose`, `_settle`, `overflow_at`; `_pick_seat` calls overflow before the zone fallback;
  `remove_presence` releases the overflow marker and settles the table; `react` skips standing people),
  `game/scripts/presence_ui/fake_presence.gd` (arrive(): zone from PresenceMock.TABLES for tables the fake list lacks, e.g. Bar).
- Docs: `docs/design/08-presence.md` §6.2 + §6.2.1, DECISIONS row 2026-11-20, captures `docs/art/screens/overflow-seats/`
  (script `game/tests/capture_overflow_seats.gd`, hidden desktop only).

## How it works (short)
- Order for a checked-in viewer (table_id known): table's own free chair → bump an anonymous patron on one → overflow
  seat (cap 8 per table, Bar 18) → standing spot (4, Bar 6) → zone (old behaviour). Viewer not checked in: unchanged (P3).
- Slots per table computed once, lazily (~25 ms per table on desktop; first overflow at a table only). Round/square
  tables: circle at chair reach + 0.12; long tables: footprint grown by the chairs' distance; rows (Bar, HighCounter,
  Tiny*): along the row, 0.7 m past the ends, BAR_GAP 0.45.
- Clearance: room colliders (BoxShape3D OBBs, own table excluded for chairs), every sit spot (gap), other tables'
  zones (reach + SEAT_MARGIN 0.35 + 0.1), lane spots (wander/spawn/stand/hatch, 0.6 m), baked navmesh within 0.6 m.
- Markers live under Patrons (not Spots), not in group "seat" (player never takes them); chair = kit glb child, pops in.

## Gotchas
- `git worktree add` on the Drive mount left `index.lock` without `index` (rename failed): every file showed as staged
  deletion. Fix: rename `.git/worktrees/<name>/index.lock` → `index` (own worktree only).
- Hidden-desktop launches sometimes exit 0xC0000142 (3221225794) at once while other Godot runs start; retry.
- Captures: close-ups hide CanvasLayers and the player; `NeedsHud.areas_hidden = true` slides the area column aside.
- LoungeTable0/1 QR codes point at tables removed by the entrance round: those check-ins sit by Lounge zone. Not fixed
  (QR freeze); listed on the card as a later question.

## Next
- Verifier: clean worktree of the SHA, all suites. Daniele: the card. Possible follow-ups: camera-patrons-in-front with
  big tables; map LoungeTable0/1 codes to an in-game table after the friend test.
