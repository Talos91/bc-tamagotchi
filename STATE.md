# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-01)

## LIVE
- No release yet (no build/publish path). `main` = design docs, needs system, four minigames, kit v4 (90 objects), characters v2, VENUE V4 rebuilt to the real floor map (228eb2e, daf76b6; plan `docs/art/plan-v4.md`, 21.7 × 15 m main room), first playable loop re-wired to it; six headless suites green (orchestrator re-ran on daf76b6).
- `layout.json` unfrozen until Daniele accepts v4. Play it: `docs/tech/02-playtest-guide.md` (spawn is now the west lobby).

## IN FLIGHT (shared checkout, branch main only)
- Venue notes round on main (676a6a8, a08065e): doors, seating, stair, alcove camera, Prae leftovers; seven suites pass (incl. new smoke_doors_sit). venue-notes session idle, kept for venue follow-ups. Stair confirmed by Daniele 2026-11-02.
- B8 start screen on main (0dc0b68, cf0555f). Round 2 running in 🎬 start-screen (local_d2ed3aae): sign from direction 23, no title, eased camera sequence, exit shot.
- 🏗️ venue-notes (local_545c7c14): spawn out of exit zone, Entrance zone label, red neon edge, Prae no surname, every seat sittable, bar_chat +3 Friends (provisional). Then REFREEZE layout.json (Daniele accepted v4).

## WORKERS ALIVE (max 3)
- 🎛️ orchestrator fdaed712-5416-430d-b3a7-7174cf46699f (Opus 5.5); 🏗️ venue-notes (spawn + label fix); 🎬 start-screen idle, kept for follow-ups.

## WAITING ON OWNER
- All Questions-tab items answered 2026-11-02 (see DECISIONS). Outstanding: entrance/street photos (next visit), band consent (Daniele asking Black Cabin).
## (older) (answer on the Questions tab: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW#questions)
- Confirm the stair reading on the venue-notes capture; accept venue v4 after this round (then refreeze layout.json); real entrance-corridor photos later.
- Orientation; Black Cabin opening hours; brand typeface; staff turnover; resident band + consent packs; stakes numbers; coin sign-off; chat policy; real drinks menu.

## NEXT THREE JOBS
1. Verify venue-notes round → refreeze layout.json (PROJECT never-list), regenerate the changelog. Verify start-screen round 2.
2. B8 start screen DONE pending Daniele's calls on the Questions tab (camera, sign, title, exit shot); was: outside street facade at night with lit Black Cabin neon, still first-person camera on the street door, tap to enter → door opens → camera follows the character in → door closes → pull back to game camera → play. Reuses venue-notes' door code; title/menu UI and save load stay as now.
3. Performance pass (42 lights, phone measurement before any phone build), then figure lighting/proportion pass and character creator.
- Later: everything in `docs/design/BACKLOG.md` (ideas, real-life bridge, online, debt). Shared board: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW

## POINTERS
- Worker rules `PROJECT.md`; history `LOG.md`; owner decisions `docs/design/DECISIONS.md` ("Still open"); waves `ORCHESTRATION.md`; changelog `docs/CHANGELOG.md` (`python tools/changelog.py`).
- Handoffs `handoffs/` (orchestrator, zone-wiring). Method: vault `wiki/concepts/claude-orchestration-method.md`, profiles `wiki/agents/`.

## QUEUED (start when a worker slot frees)
- 🎲 stakes + economy design (Opus): stakes chapter from Daniele's base proposal (total deletion, friend revival e.g. zombie stage act, fatal = not going to Black Cabin, others minor annoyances), one-page coin summary, Flat-as-rented-room unlock note.
- Orientation toggle: portrait first + landscape button top-right (give to start-screen session or a UI worker).
- 🍸 real-menu (local_b0e3443e) running: menu.json from docs/venue/menu, replaces six invented drinks; needs orchestrator go-ahead before editing game/scripts/zones/.
