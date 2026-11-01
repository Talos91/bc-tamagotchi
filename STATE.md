# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-01)

## LIVE
- No release yet (no build/publish path). `main` = design docs, needs system, four minigames, kit v4 (90 objects), characters v2, VENUE V4 rebuilt to the real floor map (228eb2e, daf76b6; plan `docs/art/plan-v4.md`, 21.7 × 15 m main room), first playable loop re-wired to it; six headless suites green (orchestrator re-ran on daf76b6).
- `layout.json` unfrozen until Daniele accepts v4. Play it: `docs/tech/02-playtest-guide.md` (spawn is now the west lobby).

## IN FLIGHT (shared checkout, branch main only)
- Venue notes round on main (676a6a8, a08065e): doors, seating, stair, alcove camera, Prae leftovers; seven suites pass (incl. new smoke_doors_sit). venue-notes session idle, kept for venue follow-ups. Stair confirmed by Daniele 2026-11-02.
- 🎬 start-screen (local_d2ed3aae, Opus 5.5): B8 front-door start sequence in its own scene (`game/scenes/street/`, `start_screen.gd`); must not touch venue files.

## WORKERS ALIVE (max 3)
- 🎛️ orchestrator fdaed712-5416-430d-b3a7-7174cf46699f (Opus 5.5); 🎬 start-screen (local_d2ed3aae); 🏗️ venue-notes idle.

## WAITING ON OWNER
- Confirm the stair reading on the venue-notes capture; accept venue v4 after this round (then refreeze layout.json); real entrance-corridor photos later.
- Orientation; Black Cabin opening hours; brand typeface; staff turnover; resident band + consent packs; stakes numbers; coin sign-off; chat policy; real drinks menu.

## NEXT THREE JOBS
1. Daniele: remaining calls (street door model, Prae's full name, bar-stool row, neon colour) and venue v4 acceptance → refreeze layout.json, regenerate the changelog. Venue tweaks go to venue-notes (local_545c7c14).
2. B8 front-door start screen (running, 🎬 start-screen): outside street facade at night with lit Black Cabin neon, still first-person camera on the street door, tap to enter → door opens → camera follows the character in → door closes → pull back to game camera → play. Reuses venue-notes' door code; title/menu UI and save load stay as now.
3. Performance pass (42 lights, phone measurement before any phone build), then figure lighting/proportion pass and character creator.
- Later: everything in `docs/design/BACKLOG.md` (ideas, real-life bridge, online, debt). Shared board: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW

## POINTERS
- Worker rules `PROJECT.md`; history `LOG.md`; owner decisions `docs/design/DECISIONS.md` ("Still open"); waves `ORCHESTRATION.md`; changelog `docs/CHANGELOG.md` (`python tools/changelog.py`).
- Handoffs `handoffs/` (orchestrator, zone-wiring). Method: vault `wiki/concepts/claude-orchestration-method.md`, profiles `wiki/agents/`.
