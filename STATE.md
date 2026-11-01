# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-01)

## LIVE
- No release yet (no build/publish path). `main` = design docs, needs system, four minigames, kit v4 (90 objects), characters v2, VENUE V4 rebuilt to the real floor map (228eb2e, daf76b6; plan `docs/art/plan-v4.md`, 21.7 × 15 m main room), first playable loop re-wired to it; six headless suites green (orchestrator re-ran on daf76b6).
- `layout.json` unfrozen until Daniele accepts v4. Play it: `docs/tech/02-playtest-guide.md` (spawn is now the west lobby).

## IN FLIGHT (shared checkout, branch main only)
- WAVE 4 fix round: 🏗️ venue-rebuild (local_21de4de2) on red back bar, dark cool smoking room, duller shelves, staff figure at the hatch, neon edge check; then re-captures.

## WORKERS ALIVE (max 3)
- 🎛️ orchestrator fdaed712-5416-430d-b3a7-7174cf46699f; 🏗️ venue-rebuild. kit-real-room archived.

## WAITING ON OWNER
- Acceptance of venue v4 after the fix round (then refreeze layout.json); real photos of the entrance corridor later; playtest notes (A3).
- Orientation; Black Cabin opening hours; brand typeface; staff turnover; resident band + consent packs; stakes numbers; coin sign-off; chat policy; real drinks menu.

## NEXT THREE JOBS
1. Wave 4 fix round → show Daniele → acceptance → refreeze layout.json, regenerate changelog (BACKLOG A1, A2 done: bar strip reachable).
2. Performance pass: 42 lights, ~1,850 draw calls, 24 ms GPU desktop; phone measurement before any phone build.
3. Figure lighting and proportion pass (warm key/rim, heads 27–34 %); then character creator + the Flat.
- Later: everything in `docs/design/BACKLOG.md` (ideas, real-life bridge, online, debt). Shared board: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW

## POINTERS
- Worker rules `PROJECT.md`; history `LOG.md`; owner decisions `docs/design/DECISIONS.md` ("Still open"); waves `ORCHESTRATION.md`; changelog `docs/CHANGELOG.md` (`python tools/changelog.py`).
- Handoffs `handoffs/` (orchestrator, zone-wiring). Method: vault `wiki/concepts/claude-orchestration-method.md`, profiles `wiki/agents/`.
