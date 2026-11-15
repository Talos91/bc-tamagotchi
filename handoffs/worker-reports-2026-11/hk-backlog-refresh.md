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

## Addendum: hub Backlog tab now generated (2026-11-15)
- `docs/design/build_hub_tabs.py` now also splices #p-backlog (markers BEGIN/END:backlog in backlog-board.html) from BACKLOG.md: same pills/table look, new Track column, "0.3.0 now" section, E (questions pointer) skipped. Never hand-edit #p-backlog.
- DRIFT FOUND: the live hub (v16, 10 Nov) had two Backlog sections, G "User psychology" and H "Monetization", that were never in the repo or BACKLOG.md. Kept verbatim in new `docs/design/backlog-gh.html` (static fragment the script appends after the generated block). They are NOT in BACKLOG.md: fold them in or accept the fragment (orchestrator/Daniele call).
- Republished the same artifact (v20, https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW), capabilities carried forward (assets, db, user); title kept "Black Cabin Hub". Questions/Coins db untouched (page JS and db not edited).
- Other tabs vs live v16: Questions, Coins, Stakes, Ask, JS identical; Game bible gains one row (`PRE_ALPHA` = true) because the script regenerates the rules table from rules.gd; footer line updated.
- Rows on the tab: 48 (A–D) + G/H as before.

## Addendum 2: G and H folded in (2026-11-15)
- G (User psychology: persona table + G1–G12) and H (Monetization H1–H9 + guard rails) are now sections of BACKLOG.md, content unchanged in meaning. G rows ideas with my track guess (T1 mostly; G3, G6, G8, G11 T2); H rows all T3, ideas / "suggested next" (H9), no decision implied (per orchestrator). G12 stays "suggested next".
- `backlog-gh.html` and its append in `build_hub_tabs.py` removed: BACKLOG.md is the only source. The script now also handles non-6-column tables (persona table) and sections A–H.
- Hub republished, same URL, version 21, capabilities kept; G and H still on the tab (generated: 2 section headings, rows present). Row total on the tab: 48 + 21 (G 12, H 9).
- Exit ritual: role note `handoffs/hk-backlog-refresh-2026-11-15.md` updated; capture sent earlier (addenda here, not re-captured).
