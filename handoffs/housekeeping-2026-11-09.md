# Housekeeping role note, 2026-11-09 (design answers folded in)

Load id 2026-11-09-housekeeping-black-cabin-8112c8. Sonnet. Docs only; nothing under `game/` touched.

## State now
- Creator (07) and presence (08) answers are in every doc that 08 §11 lists, plus the GDD creator counts and the lounge photo booth as the in-game Edit-look entry. Commit e81c162 (not pushed; the orchestrator pushes by SHA).
- 07 §9 and 08 §12 carry an Answer column (date, choice). 08 §11 carries an Applied column. 08 is marked a baseline (Daniele: "all of these are just baseline and we might change").
- Hub untouched: `stakes-rules.md` and `game-bible.md` do not mention creator or presence, so no tab change, no republish.
- DECISIONS "Still open": no item closed. The real-world bridge item stays (08 covers staff counts and QR only in part); the stale card "Real-world bridge chapter" waits for the orchestrator.

## Next step
None for Housekeeping. If Daniele changes a baseline answer, edit the Answer cell in 08 §12 and the amendment note in the doc it touches.

## Gotchas
- The `.md` files use mixed line endings (CRLF in the GDD, cast, stakes, 08); edit with a script that preserves them, `git diff --stat` stays small.
- `git pull --rebase` needs `origin main` here (a bare pull said "multiple branches").
- Beyond the brief's four docs, `docs/tech/01-engine-decision.md` also got the 08 §11 note (it is listed there).
- `game-bible.md` was not read in full; only grepped for creator and presence.
