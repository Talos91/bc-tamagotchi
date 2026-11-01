# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-01)

## LIVE
- No release yet (no build/publish path). `main` = design docs, needs system, four minigames, kit v4 (90 objects), characters v2, VENUE V4 rebuilt to the real floor map (228eb2e, daf76b6; plan `docs/art/plan-v4.md`, 21.7 × 15 m main room), first playable loop re-wired to it; six headless suites green (orchestrator re-ran on daf76b6).
- `layout.json` unfrozen until Daniele accepts v4. Play it: `docs/tech/02-playtest-guide.md` (spawn is now the west lobby).

## IN FLIGHT (shared checkout, branch main only)
- Nothing running. Venue v4 + fix round on main (68d9ff5, 4cb4bf3): red back bar, cool smoking room, camera cutaway, held-input latch, Mali → Prae. Venue session retired at its context limit; resume prompt in its handoff `C:/Users/itisf/.claude/handoffs/f0b20610-ad70-427d-a81a-2ba2c6d97e04.md`.

## WORKERS ALIVE (max 3)
- 🎛️ orchestrator fdaed712-5416-430d-b3a7-7174cf46699f only (now on Opus 5.5). Workers run on Opus 5.5 or Sonnet; never Fable without Daniele's OK.

## WAITING ON OWNER
- Playtest verdict on venue v4 (game open on Daniele's PC) → accept and refreeze layout.json, or a notes list for the next venue session; real entrance-corridor photos later.
- Orientation; Black Cabin opening hours; brand typeface; staff turnover; resident band + consent packs; stakes numbers; coin sign-off; chat policy; real drinks menu.

## NEXT THREE JOBS
1. Venue v4 notes round (fresh Opus venue session from the handoff prompt): Daniele's notes, repo handoff update, Prae rename in 03-cast/02-gdd/06-stakes/playtest guide + chars manifest display + chars_showcase, neon-edge check, old-corridor camera zone. Then refreeze layout.json and regenerate the changelog.
2. Performance pass: 42 lights, ~1,850 draw calls, 24 ms GPU desktop; phone measurement before any phone build.
3. Figure lighting and proportion pass (warm key/rim, heads 27–34 %); then character creator + the Flat.
- Later: everything in `docs/design/BACKLOG.md` (ideas, real-life bridge, online, debt). Shared board: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW

## POINTERS
- Worker rules `PROJECT.md`; history `LOG.md`; owner decisions `docs/design/DECISIONS.md` ("Still open"); waves `ORCHESTRATION.md`; changelog `docs/CHANGELOG.md` (`python tools/changelog.py`).
- Handoffs `handoffs/` (orchestrator, zone-wiring). Method: vault `wiki/concepts/claude-orchestration-method.md`, profiles `wiki/agents/`.
