# 🏗️ Lounge follow-up: worker report (2026-11-02)

Worker: venue (Sonnet), briefed by the orchestrator local_9bb3d41c. Role note: `handoffs/lounge-followup-2026-11-02.md`.
Daniele did not message this session directly. Not pushed, version not bumped, changelog not touched.

## Commits (main, not pushed)
- `e5d38a6` the follow-up: `build_venue.gd`, `venue.tscn` (regenerated), `layout.json` (exported), strings, `venue_session.gd`,
  `venue_zones.gd`, `test_lounge.gd`, capture script, two-up script, playtest guide, captures.
- the next commit: this report and the role note.

## Suites
**All 14 PASS** on `e5d38a6` in an isolated copy (`git archive e5d38a6 game tools docs/venue` on local disk, imported, venue
rebuilt (navmesh 561 polygons, 42 lights), imported again, `APPDATA` an empty folder per suite): smoke_stairs, smoke_tap,
smoke_hud, test_needs (106), test_minigames (1468), smoke_loop, smoke_doors_sit, smoke_start, test_menu (2736), smoke_version,
test_nightlife (107), test_seats, test_feel, test_lounge (106 checks). test_feel passed on its first run, so no rerun.
`test_lounge.gd` now checks: the machine at (10.3, 12.65) facing the room with the stair's foot facing it, nothing overlapping
it, the counter and stools east of it, the merch rows (six items, prices 30/30/30/60/80/120 in the "{price} coins · coming
soon" reason), the merch / Top patrons / portrait sheet texts (this month; a message from the patron, nothing from "the
owner"), both east tables 0.6 m west, Raised3's chair and both couch places walked to and sat in from the main room, tap +
Sit row at Raised3, the rectangle's four seats, plus the unchanged tap/camera/area-button/curtain checks.

## What was done (Daniele's answers)
1. **Game machine** back at (10.3, 12.65) turned 180; the bottom step faces it again; the top left keeps only the memory
   corner. High counter + two stools + records now x 11.1–12.8 on the south wall east of it (stools 11.55 / 12.5), lamp and
   painting back at their old north-wall places, `memory` camera view recentred on the corner.
2. **Raised3 lane:** moved **both** east tables 0.6 m west (diamond `EastTable` and rectangle `RectTableE`, x 38.2 → 37.6).
   See the call below: moving only the rectangle made Raised3's *chair* reachable but not its couch places.
3. **Merch** = six in-game cosmetic coin items from the wardrobe tiers of `04-coins.md` §3.2, each "coming soon". The item names
   are placeholders (cap, pin, tote, tee, performer tee, jacket); prices are the plan's tiers, not placeholders.
4. **Top patrons** sheet: this month's check-ins at the bar, "{n} check-ins this month"; names and counts stay placeholders.
5. **Portrait messages** are written by the patron: "A message from {name}", first-person placeholder text.
Thai is machine draft for all changed strings (marked in the context column).

## Captures (`docs/art/screens/lounge-followup/`, portrait 1080×1920 and landscape 1920×1080)
`<tag>-{lounge, stair-foot, machine, cabinet-sheet, memory, merch, merch-sheet, patrons, patrons-sheet, corridor-east,
portrait-6-sheet, raised-east, raised-top, raised3-seated, raised3-seated-close}.png` (`raised-top` and `raised3-seated-close`
are review cameras, not the game's view); `twoup-<tag>-{lounge, stair-foot, memory, merch-sheet, patrons-sheet,
portrait-6-sheet, raised-east, raised-top}.jpg`, before (`50a0623`) | after.

**Best for the acceptance card:** `twoup-portrait-stair-foot.jpg` (machine back by the stair foot),
`portrait-merch-sheet.png` (coin shop), `twoup-landscape-raised-top.jpg` (the lane to Raised3, seen from above),
`portrait-raised3-seated-close.png` (seated at Raised3). Also `twoup-portrait-portrait-6-sheet.jpg` (patron's message).

## layout.json entries moved (lounge and the east tables only)
Moved: `GameCabinet` (8.0, 0.4) turned 0 → (10.3, 12.65) turned 180; `CounterStool0/1` (10.35|11.3, 12.0) → (11.55|12.5, 12.0)
and their spawns `Lounge_Stool0/1`; `LoungeVinyl0-2` x +1.2; `RedDiscLamp` x 10.7 → 10.2; `LoungePainting` x 9.6 → 8.2 (the
`HighCounter` box is built, not exported, and moved x +1.2 too). Main room: `EastTable` and `RectTableE` x 38.2 → 37.6 with their
chairs (`EastTableChair0-3`, `RectTableEChairW0/W1/E0/E1`), glasses, lamp, menu card, napkins, tealights and spawns
(`Tables_EastTable_C0-3`, `Tables_RectTableE_W0/W1/E0/E1`); the `EastLight` omni (not exported) x 38.2 → 37.6. Nothing else in the main room changed. Refreeze on Daniele's acceptance.

## Calls for Daniele (orchestrator: please put on the Questions tab with these pictures)
1. **I moved the east diamond table too (not only the rectangular one).** The brief said "the east rectangular table group";
   moving only that opened Raised3's chair, but its couch places stayed out of reach because the diamond table's chairs seal the
   strip's north lane (z 5.0–6.8). Both tables now stand in one column at x 37.6. Options: (a, rec) keep both moved; (b) move only
   the rectangle and accept that Raised3's couch places stay unreachable (one constant, `EAST_X` in `build_venue.gd`, plus the
   diamond's line). Pictures: `twoup-landscape-raised-top.jpg`, `portrait-raised3-seated-close.png`.
2. **Merch item list.** The six items are placeholders matched to the coin plan's tiers (30 / 60 / 80 / 120). What does the
   character wardrobe really contain, and should the shop rows show the wardrobe piece on the character? (Needs the character
   creator / wardrobe.) Picture: `portrait-merch-sheet.png`.
3. **Board wording (low).** The lettered board on the wall still says "Top patrons"; only the sheet says "this month". Add
   "this month" under the board title? Picture: `portrait-lounge.png`.

## Left undone / known
- Thai strings are machine drafts; names, counts, messages and the coins themselves do not exist yet (rows are disabled).
- Several Raised couch places beyond Raised3's (Raised0 S0, Raised2 S1, Raised4 S0/S1) are still not walkable to by the walk
  rule; they were not in this brief and the Raised table zones sit on the chair, so tapping a table always works. Not changed.
- The real-life merch shop in the lounge was not built, as asked.
- Before-pictures not named in the two-ups were not retaken; the before set for lounge, stair-foot, memory, sheets is the
  committed 50a0623 capture set in `lounge-revamp/`; `raised-*` before shots were taken from a copy of 50a0623 (not committed,
  carried by the two-ups).
