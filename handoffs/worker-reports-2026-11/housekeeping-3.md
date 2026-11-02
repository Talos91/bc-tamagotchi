# 🧹 housekeeping-3 — report (2026-11-03, Sonnet)

## EVIDENCE
- Docs commit: see `git log -1 --format=%h -- docs/design/stakes-rules.md` (message "Housekeeping: DECISIONS row for the 14 owner items…"); not pushed. Role note + this report in the commit after it.
- Hub: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW republished at the same url; footer **v14** (service version 15); tabs Backlog, Questions, Coins, **Stakes rules**, **Game bible**. Not opened in a browser (private artifact, no session); structure checked from the file.
- DECISIONS: one new row "2026-11-02/03 Owner feedback from the web build…" (14 items with SHAs 84c58e5, dd4e03c, 86b40ab, e4d7e76, b8f6d50; orchestrator decisions: export_presets.cfg tracked 8a46bd3, layout.json opened for items 4, 5, 7, 11 only, test_touch fifteenth suite d32407a). "Still open" rewritten (9 bullets): camera cards + sconce/sign lag, look follow-ups + layout-export filter, needs-build leftovers (Retire screen, audio duck, postcards, Going bonus, notifications, scar), bridge design, hub tabs (now built), cocktail page + errata, street photos, web redeploy + phone pass, Black Cabin asks.
- Hub Backlog rows: A7 built (406d2fd, c97abde), awaiting acceptance; A8 built, deploy by Daniele; new A9 look follow-ups (84c58e5, 86b40ab), A10 needs/stakes (dd4e03c), A11 touch anywhere (b8f6d50), A12 venue fixes (e4d7e76), all "built, card open". Debt list gets the needs-build leftovers line.
- **Card-id check (db `items`, 111 docs): none missing.** Present: look-followups-review, -player-light, -layout-export, -month-list; needs-stakes-review, -night-boundary, -death-in-visit, -rescue-welcome, -retire-ui; touch-anywhere-review; venue-fixes-review, -bar-height, -bar-door. (Also present: camera-feel-2-accept, camera-closer-still, camera-patrons-in-front, web-build-review.)
- "🎲 Real-world bridge chapter" (task_b873ccbd) is a session-proposal card from the old orchestrator, not in the hub db or Backlog tab: nothing to remove; STATE can drop it from PROMISED.
- Worktrees: `verify-36da262` and `verify-38fc2fa` folders removed, `git worktree prune`; `git worktree list` now shows only the main checkout.

## Files
- `docs/design/stakes-rules.md` (80 lines): player-facing rules from 06-stakes v3 §1–§9 + O1–O3, numbers checked against rules.gd.
- `docs/design/game-bible.md`: links every design, venue, art, UI, tech doc with a one-line summary; "Live numbers" table generated from `rules.gd`.
- `docs/design/build_hub_tabs.py`: regenerates the table and splices both pages into the hub source.
- `docs/design/backlog-board.html`, `docs/design/DECISIONS.md`, `handoffs/housekeeping-2026-11-02.md`.

## Could not source / calls for the orchestrator
- Not done (outside the brief): live manual (Claude Doc) §15, still stale since venue v4.
- The two new tabs are generated text; after docs change, rerun `build_hub_tabs.py` and republish.
- Not verified in a browser: the new tabs' look on a phone.
