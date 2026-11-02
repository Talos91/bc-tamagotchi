# 🏗️ Lounge revamp: worker report (2026-11-02)

Worker: venue/art (Opus), briefed by the orchestrator local_9bb3d41c. Role note: `handoffs/lounge-revamp-2026-11-02.md`
(what changed, files, how to re-run). Daniele did not message this session directly.

## Commits (main, not pushed)
- `50a0623` the revamp: code, kit, venue.tscn, layout.json, portraits, strings, test_lounge, test_feel tweak, captures,
  two-ups, playtest guide.
- the next commit: this report and the role note.

## Suites
**All 14 PASS** in an isolated copy (`git archive 50a0623 game tools docs/venue` on local disk, imported, venue rebuilt
(navmesh 554 polygons, 42 lights), imported again, `APPDATA` pointed at an empty folder per suite): smoke_stairs,
smoke_tap, smoke_hud, test_needs, test_minigames, smoke_loop, smoke_doors_sit, smoke_start, test_menu, smoke_version,
test_nightlife, test_seats, test_feel, test_lounge. Note: test_feel's first isolated run failed two wall-clock checks
on the main-room walk (fastest turn 370°/s vs 260, largest step 0.32 m vs 0.3; that walk is untouched by this job); two
reruns in the same copy pass (168°/s, 0.19 m), as did the shared-tree run (171°/s, 0.19 m). The metric divides by real
time between headless frames, so a stalled frame inflates it: flaky, worth a look by whoever owns test_feel.

New suite `game/tests/test_lounge.gd` (76 checks): layout (merch top right, game machine top left by the memory
corner's TV, board under the second flight, ten framed portraits with pictures, stair unchanged), the merch / Top
patrons / ten portrait sheets (contents and opened as real sheets), screen taps on the merch counter, the board and a
portrait open their sheets, walking the corridor passes all ten portraits with their prompt, every raised-strip
table (Raised3 too) opens from a tap in the main room, the four buffer curtains hide only on the sight line and both
main-side ones stand on screen from three main-room spots, the merch / memory / patrons / lounge views, walking into
the merch corner turns the view, all seven area buttons walk there and open their sheet, the Lounge button from the
merch corner opens the pinball. Please add it to the PROJECT.md suite list.
`test_feel.gd`: one check changed (its "lounge, north-east" corner now expects MerchStand and CollectiblesShelf, since
the high counter moved to the south wall).

## Captures (`docs/art/screens/lounge-revamp/`, portrait 1080×1920 and landscape 1920×1080)
`<portrait|landscape>-{lounge, merch, merch-sheet, memory, patrons, patrons-sheet, stair-foot, corridor-west,
portrait-0-sheet, corridor-east, portrait-6-sheet, portrait-wall, curtain-main-west, curtain-main-strip,
curtain-buffer, area-lounge}.png`; `twoup-<orientation>-<shot>.jpg` before (db5e398) | after for lounge, merch,
memory, patrons, stair-foot, corridor-west/east, portrait-wall, curtain-main-west/strip, curtain-buffer;
`kit-lounge-additions.png` (Blender contact sheet of the five new props). `portrait-wall` is a review camera inside
the corridor, not the game's view. These render at true 1080×1920 (half-size window, full-size viewport); the
1421-px captures elsewhere had the HUD shrunk to 0.74.

**Best for a Questions-tab acceptance card:** `twoup-portrait-lounge.jpg`, `portrait-merch.png`,
`portrait-memory.png`, `portrait-portrait-6-sheet.png`, `twoup-portrait-curtain-main-west.jpg`.

## layout.json entries moved (lounge and corridor walls only; nothing else changed)
Removed: RegularPictureS0-3, CorridorLamp4, CorridorLamp10 (Lobby). Added: Portrait0-9, PortraitLamp0-9, CorridorLamp3,
CorridorLamp9 (Lobby); MerchRack, MerchStand, MerchPlant, PatronsBoard, GigPoster0-1, LoungeVinyl0-2, StairPlant
(Lounge). Moved: GameCabinet (10.3, 12.65) → (8.0, 0.4), turned 180 → 0; CounterStool0/1 (13.15|14.05, 1.85) →
(10.35|11.3, 12.0), turned 180 → 0; RedDiscLamp x 10.2 → 10.7; LoungePainting x 8.2 → 9.6. Spawns Lounge_Stool0/1 moved
with their stools. Refreeze on Daniele's acceptance.

## Questions for Daniele (orchestrator: please put them on the Questions tab with these pictures)
1. **Game machine vs the stair (design).** Your revamp puts the game machine top left with the memory corner; the
   confirmed stair had its bottom step facing the machine. I kept the stair. Options: (a, rec) keep as built: machine
   top left, the stair's foot now faces the high counter and two posters; (b) put the machine back by the stair foot
   (top left keeps only the memory corner); (c) turn the stair so its foot faces the machine's new place (re-opens the
   confirmed stair). Pictures: `portrait-memory.png`, `twoup-portrait-stair-foot.jpg`.
2. **Merch (facts + money).** The stand and sheet list six placeholders (tee, cap, tote, sticker pack, enamel pin, gig
   poster), none for sale, no prices. What does Black Cabin sell, at what prices, and is it paid in coins, real money,
   or bought at the bar? Options: (a, rec) Black Cabin sends its real merch list and prices; the sheet shows them with
   "buy at the bar" until a payment bridge exists; (b) in-game coin items (cosmetic merch for the character); (c) both.
   Pictures: `portrait-merch.png`, `portrait-merch-sheet.png`.
3. **What ranks the Top patrons (design).** Placeholder: ten invented nicknames with invented "check-ins" counts.
   Options: (a, rec) real check-ins at the bar (the QR codes), counted per month; (b) all-time check-ins; (c) in-game
   visits or coins. Also: may real customers' names (or nicknames) appear, with their consent? Pictures:
   `portrait-patrons.png`, `portrait-patrons-sheet.png`.
4. **Owner messages on the portraits (content).** Each shows "{name}, thank you for all the nights at Black Cabin. See
   you at the bar. (Placeholder message.)". Who writes the real ones (you, Prae, the owners), one per patron or one
   for all? Picture: `portrait-portrait-6-sheet.png`.
5. **Raised3's seats are boxed in (layout, main room).** Raised3's sheet now opens by tap (the walk ends on the strip
   past Raised4), but its chair and couch places cannot be walked to: the east rectangular table's chairs stand west
   of it and Raised4's chair south, all in the frozen main-room layout. Options: (a, rec) move the east rectangular
   table group about 0.6 m west to open a lane (unfreezes those entries); (b) leave it (Raised3 opens, you cannot sit
   there). No capture yet; one can be made on request.
6. **Lounge corners as area buttons (design, low).** The merch, memory-corner and board corners have their own camera
   views, but no buttons: the seven buttons already fill the column in portrait. Options: (a, rec) leave seven
   (Lounge still goes to the pinball); (b) the Lounge button opens a small menu of the lounge's corners.

## Left undone / known
- Thai strings are machine drafts (marked in the context column); placeholder names, counts, items and messages are
  invented and say so.
- In play the corridor camera looks along the wall, so the portraits read edge-on; their sheet shows them full size
  (a wider corridor view would need the lounge's south wall cut from the corridor, which the cutaway rule forbids).
- Memory-corner props are still placeholders (unchanged); no new light added (42).
- The two white rectangles at the top edge of some lounge/buffer shots predate this job (also in area-camera shots).
- Not pushed, version not bumped, changelog not touched (orchestrator's).
