# hk-backlog-refresh (Housekeeping, 2026-11-15; load id 2026-11-15-housekeeping-black-cabin-d93f40)

EVIDENCE
- File: `docs/design/BACKLOG.md` rewritten (commit SHA in LOG / git log; message "BACKLOG: full refresh 2026-11-15").
- Rows: 48 ideas. Status: live 14, built-awaiting-acceptance 5, built (placeholder, real later) 3, designed 5, parked 2, idea 19.
- Track: T1 32, T2 10, T3 6.
- Folded in: A4–A12 (were only on the hub), owner items 13–33 (B14–B22; items 13–15 into A11/A12, 16/29/33 B17/B18, 20/28 B17, 22 B2, 23 B12, 26–27 B2, 30–32 B15, 21 B14), presence item 24 = B16. B2 live, item 16 entrance closed (DECISIONS 2026-11-11). "0.3.0 now" section added; dated Log line added.
- Not touched: code, rules, tests, DECISIONS, game/, docs/design/09-*, 10-*.

HUB
- The hub Backlog tab (`docs/design/backlog-board.html`, #p-backlog) is hand-written HTML. `build_hub_tabs.py` only splices stakes-rules, game-bible and ask-black-cabin; nothing builds the backlog from BACKLOG.md. So not regenerated or republished; no tab invented. The hub still shows the 11-03 v15 statuses (stale vs the file). Decision for orchestrator: have Housekeeping hand-edit #p-backlog (rows + 0.3.0 section + track column) and republish, or add a BACKLOG.md splice to the script.

UNSOURCED / GUESSES
- Track of B4 (T1), C5 (T1), B20 (T1; notifications part needs T2), D7 (T3, Grab sponsor) are my judgment.
- Status of cards after 11-11 taken from STATE (not re-checked on the hub).

PROFILE NOTE: housekeeping profile has no step for "hub tab is not generated"; PROJECT.md should say which tabs the script builds.
