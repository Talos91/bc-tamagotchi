# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-01)

## LIVE
- No release yet (no build/publish path). `main` = design docs, needs system, four minigames, kit v3, characters v2 (accepted), room accepted at parity 18, FIRST PLAYABLE LOOP: zones, HUD, result card, Welcome Back, walk-out, Flat stand-in; six headless suites.
- Layout frozen at `game/assets/kit/layout.json`. Play it: `docs/tech/02-playtest-guide.md`.

## IN FLIGHT (shared checkout, branch main only)
- Nothing. Alpha verdict in: "good alpha". Gate = baseline map fix; waiting on Daniele's new photos + plan.

## WORKERS ALIVE (max 3)
- 🎛️ orchestrator fdaed712-5416-430d-b3a7-7174cf46699f only. zone-wiring, apply-decisions, method-setup finished and archived.

## WAITING ON OWNER
- Answers to the orchestrator's baseline-map questions (scale, lounge furniture, player route, raised height); playtest notes (A3). Floor map + photos are in `docs/art/direction/08–16`.
- Orientation; Black Cabin opening hours; brand typeface; staff turnover; resident band + consent packs; stakes numbers; coin sign-off; chat policy; real drinks menu.

## NEXT THREE JOBS
1. Baseline map fix from the new photos + plan (unfreeze layout.json, re-run parity) + bar-counter navmesh (BACKLOG A1, A2).
2. Performance pass: 42 lights, ~1,850 draw calls, 24 ms GPU desktop; phone measurement before any phone build.
3. Figure lighting and proportion pass (warm key/rim, heads 27–34 %); then character creator + the Flat.
- Later: everything in `docs/design/BACKLOG.md` (ideas, real-life bridge, online, debt). Shared board: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW

## POINTERS
- Worker rules `PROJECT.md`; history `LOG.md`; owner decisions `docs/design/DECISIONS.md` ("Still open"); waves `ORCHESTRATION.md`; changelog `docs/CHANGELOG.md` (`python tools/changelog.py`).
- Handoffs `handoffs/` (orchestrator, zone-wiring). Method: vault `wiki/concepts/claude-orchestration-method.md`, profiles `wiki/agents/`.
