# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-01)

## LIVE
- No release yet (no build/publish path). `main` = design docs, needs system, four minigames, kit v3, characters v2 (accepted), room accepted at parity 18, FIRST PLAYABLE LOOP: zones, HUD, result card, Welcome Back, walk-out, Flat stand-in; six headless suites.
- Layout frozen at `game/assets/kit/layout.json`. Play it: `docs/tech/02-playtest-guide.md`.

## IN FLIGHT (shared checkout, branch main only)
- WAVE 4 baseline map: 🧱 kit done (90 objects, pushed). 🏗️ venue-rebuild (local_21de4de2) building from plan v4 (`docs/art/plan-v4.md`, 21.7 × 15 m confirmed) with three owner corrections relayed (walled staff room + half wall, no toilet-corridor wall, L corridor).

## WORKERS ALIVE (max 3)
- 🎛️ orchestrator fdaed712-5416-430d-b3a7-7174cf46699f; 🏗️ venue-rebuild. kit-real-room archived.

## WAITING ON OWNER
- Acceptance of the rebuilt room when renders land; real photos of the entrance corridor later; playtest notes (A3).
- Orientation; Black Cabin opening hours; brand typeface; staff turnover; resident band + consent packs; stakes numbers; coin sign-off; chat policy; real drinks menu.

## NEXT THREE JOBS
1. Wave 4 baseline map (running): verify plan-v4, renders, six suites; refreeze layout.json on acceptance (BACKLOG A1, A2).
2. Performance pass: 42 lights, ~1,850 draw calls, 24 ms GPU desktop; phone measurement before any phone build.
3. Figure lighting and proportion pass (warm key/rim, heads 27–34 %); then character creator + the Flat.
- Later: everything in `docs/design/BACKLOG.md` (ideas, real-life bridge, online, debt). Shared board: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW

## POINTERS
- Worker rules `PROJECT.md`; history `LOG.md`; owner decisions `docs/design/DECISIONS.md` ("Still open"); waves `ORCHESTRATION.md`; changelog `docs/CHANGELOG.md` (`python tools/changelog.py`).
- Handoffs `handoffs/` (orchestrator, zone-wiring). Method: vault `wiki/concepts/claude-orchestration-method.md`, profiles `wiki/agents/`.
