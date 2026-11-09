# Report: housekeeping-designs (🧹 Sonnet, 2026-11-09)

## EVIDENCE
- Commit **e81c162** on main (local, not pushed); own paths only; `git diff --stat` before commit: 7 files, small insertions.
- Load id 2026-11-09-housekeeping-black-cabin-8112c8. Vault up (load_agent worked).
- Hub not republished (version unchanged): no change to `stakes-rules.md` / `game-bible.md`.
- Nothing under `game/` opened or edited. No tests run (docs only).

## Files
- `docs/design/02-gdd.md`: §5.2 amendment note (P2 Presence, P3 Together; headcount rule kept); §13 note (Ooze server only for live table games); §7.1 note with the accepted creator counts, no gender field, names 2–16 Latin + Thai, photo booth in the lounge as Edit look; name line; §14 launch-scope bullet replaced with accepted counts.
- `ORCHESTRATION.md`: wave 4 amendment (presence events on Supabase, relay only for live table games, baseline).
- `docs/design/03-cast.md` §1.3 and `06-stakes.md` §10.8: dated amendments pointing to 08-presence.md.
- `docs/tech/01-engine-decision.md`: note that the 20–50-avatar live room is no longer planned.
- `docs/design/07-character-creator.md`: status line + Answer column for Q1–Q11 (Q8 marked as changed: photo booth).
- `docs/design/08-presence.md`: status line, §11 Applied column, §12 Answer column P1–P11 (P5 = (b), others (a)); marked baseline.

## Checks
- Every Q/P row has an Answer cell (counted by eye in the diff: 11 + 11, six Applied rows).
- Answers match the two 2026-11-09 DECISIONS rows (d510065).
- Still open: nothing closed by these answers.

## Not done / notes
- Housekeeping did not push; orchestrator pushes e81c162 plus the two notes by SHA.
- Profile feedback: the loader profile is fine; PROJECT.md should say `git pull --rebase origin main` (bare pull fails).
