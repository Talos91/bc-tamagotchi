# Worker report: 🌐 overflow-seats, 2026-11-20

## Evidence
- Commit: see LOG.md / the final message (branch `wk/overflow-seats`, rebased on origin/main, not pushed).
- Suites: all 33 headless suites (32 existing + new `test_overflow_seats`) run with empty APPDATA in the worktree:
  result in the final message. `test_overflow_seats`: 61 checks, 0 FAILS.
- Hub card `overflow-seats-review` (order 411, 10 pictures, files list). Captures `docs/art/screens/overflow-seats/`
  (450x800 portrait, hidden desktop via CreateDesktop, foreground probe: no Godot window on Daniele's desktop).
- Design `docs/design/08-presence.md` §6.2.1; DECISIONS row 2026-11-20 quoting Daniele; LOG line.

## 1. What happened before (headless probe, viewer checked in, fake presences)
No overlap, no hidden avatar, no error, nobody standing: `_pick_seat` took a free chair at the table, else a random
free chair in the zone. Late check-ins (the 2-minute poll) almost never got their table: the anonymous crowd holds
its chairs and `_bump_patron` only ran when no chair was free anywhere. Measured: 9 at Table3 → 2 at Table3, 7 spread
over WestTable0/1, RectTableW/E, Tiny1; 12 at Bar → 2 on bar stools; 6 at BufferTall1 → 1 there. Also: QR codes
LoungeTable0/1 have no in-game seats any more (the entrance round removed those tables), so they sit by Lounge zone.

## 2. What was built
- `game/scripts/presence_ui/overflow_seats.gd` (new): per-table overflow slots, computed lazily once; chair markers
  with the kit glb (cafe_chair / tall_stool / drum_stool / bar_stool) spawned at runtime under Patrons; released with
  a shrink. Caps: 8 per table (round tables reach it: 4 on the diagonals), Bar 18 (9 between and just past the
  stools), tall tables 1-2 extra (room-limited); then 4 standing (Bar 6, behind the stools), then the zone.
- `venue_patrons.gd` (tight): `_pick_seat` → `_table_overflow` (bump an anonymous patron at the table, else overflow)
  before the zone fallback; `remove_presence` releases overflow and `_settle`s the table (the worst-placed person
  moves to the best free spot, so extra chairs vanish as the table drops back); standing people do not sit-applaud.
- `fake_presence.gd` arrive(): zone from PresenceMock.TABLES (Bar came out as "Tables").
- Nothing in layout.json / venue.tscn; docs/venue/qr/ and codes untouched (QR freeze).

## 3. Phone portrait
Captures at 450x800: Table3 4 vs 9, Bar 12 (two halves + game camera), BufferTall1 6. No clipping into walls or
tables seen; the area column covers the right third unless slid aside (shots slide it, as the player can). From
the bar side a full Table3 stands between camera and player (same as card camera-patrons-in-front, bigger crowd).

## Not verified
Real phone, live Supabase with many real check-ins, perf on iPhone (slot computation ~25 ms per table on desktop,
once per table per visit, only when a table overflows).

## Open for the owner
- The card (ok / fewer: no standing / changes). LoungeTable0/1 codes → which in-game table (after the QR freeze).

## Profile feedback
Social-features profile fine; it could mention the hidden-desktop capture recipe and the Drive-mount worktree
index.lock gotcha (git worktree add left `index.lock` instead of `index`).
