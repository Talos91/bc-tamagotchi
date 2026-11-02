# 🏗️ Lounge follow-up: role note (2026-11-02, state now)

Worker: venue (Sonnet), briefed by the orchestrator local_9bb3d41c. Owner words: DECISIONS row "Lounge revamp answers
(Questions tab, 2026-11-02 …)". Builds on the lounge revamp (`handoffs/lounge-revamp-2026-11-02.md`, report
`handoffs/worker-reports-2026-11/lounge-followup.md` for this job). `layout.json` stays open for the lounge, the corridor
walls and the east tables until Daniele answers the acceptance card.

## What changed
1. **Game machine back by the stair foot** (`game/tools/build_venue.gd`): `CABINET_X` 10.3, `GameCabinet` at (10.3, 12.65)
   turned 180 as before 50a0623; the confirmed stair is untouched, so its bottom step faces the machine again. The top left
   keeps only the memory corner. To make room: `LEDGE_X` (high counter, stools, records) is now x 11.1–12.8 on the south
   wall between the machine and the Sticker door (stools at 11.55 and 12.5, z 12.0); `RedDiscLamp` back to x 10.2 and
   `LoungePainting` to 8.2 on the north wall. Camera zone `memory` now covers the corner alone (rect to x 8.0, clamp
   x 4.2–6.6). Merch shop, board, portraits, stair, curtain: unchanged.
2. **Raised3 lane:** `EAST_X` 37.6: both east tables (diamond `EastTable` and rectangle `RectTableE`, with chairs, lamps,
   seats, `EastLight`) stand 0.6 m west of the map. The rectangle alone did not do it: the diamond's chairs sealed the
   strip's north lane (z 5.0–6.8), which Raised3's couch places need. `venue_zones.gd` `APPROACH_AT` is empty (the
   workaround for Raised3 is gone); Raised3's zone approach is its centre like the others.
3. **Merch sheet** (`venue_session.gd` `MERCH_ITEMS` = id + price; strings `venue.merch.*`, `venue.sheet.merch.*`): six
   in-game cosmetic items, coin prices from `docs/design/04-coins.md` §3.2 wardrobe tiers: cap 30, enamel pin 30, tote 30,
   Black Cabin tee 60, performer tee 80, jacket 120; each row reads "{price} coins · coming soon" and is disabled. The item
   names are placeholders (the tiers are the plan). No real-life merch shop (Daniele adds that in the lounge later).
4. **Top patrons:** greeting "This month's check-ins at the bar, most first. Names and counts are placeholders."; row sub
   "{n} check-ins this month". Ranking data in `scripts/zones/patrons.gd` is unchanged (placeholders).
5. **Portrait messages:** row title "A message from {name}", body in the patron's own voice ("Thanks for the nights at Black
   Cabin! Come say hi at the bar. (Placeholder: {name} will write this.)"), sheet greeting "One of Black Cabin's top patrons.
   Their message, in their own words."
Thai is machine draft for every changed string (marked "TH machine draft" in the context column).

## Tests and tools
`game/tests/test_lounge.gd`: machine by the stair foot (position, facing, no overlap, counter and stools east of it), the
merch / patrons / portrait sheet texts, both east tables 0.6 m west, Raised3's chair and two couch places walked to and sat in
from the main room, Raised3 by tap and the Sit row, the rectangle's four seats. `game/tests/capture_lounge_followup.gd`
(captures), `game/tools/lounge_followup_twoup.py` (before | after two-ups; before = 50a0623).

## Re-running
From game/: `godot --headless --path . --import`, `--script res://tools/build_venue.gd`, `--script res://tools/export_layout.gd`
(strings need an import to reach the translations). Captures: `godot --path . --resolution 1080x1920 --script
res://tests/capture_lounge_followup.gd -- --tag=portrait` (and 1920x1080 / `--tag=landscape`; `--only=a,b`, `--prefix=before-`,
`--out=DIR`), then `python game/tools/lounge_followup_twoup.py portrait|landscape` from the repo root.

## Open / for later
See the report. The Top patrons board on the wall still says "Top patrons" (no "this month"; only the sheet does); real
patron names, counts, messages and the coin system do not exist yet.
