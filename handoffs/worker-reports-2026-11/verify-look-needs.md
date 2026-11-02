# 🔍 verify-look-needs (2026-11-03): FAIL 12/14 at 24ff659, nothing pushed

EVIDENCE
- SHA verified: 24ff659. Clean worktree, `--import` first, fresh empty APPDATA per suite. origin/main stays fd91bee (`git ls-remote origin main`).
- Commits (origin/main..24ff659, 11): 24ff659 7638093 86b40ab abd40a9 dd4e03c 079a06d 5c43cd8 84c58e5 a8fed1e 6debe4a 68df465.
- PASS (12): smoke_stairs, smoke_tap, smoke_hud, test_needs, smoke_doors_sit, smoke_start, test_menu, smoke_version, test_nightlife, test_seats, test_feel, test_lounge.
- FAIL (2), both rerun once, same result:
  - test_minigames: 1498 checks, 1 failed: "Tt's name and heart tag (Ty  ♥)". `game/tests/test_minigames.gd:404` (unchanged in 24ff659) still expects "Tt"; the build renamed the regular to "Ty" (dd4e03c). Test not updated; the needs worker's 1498/0 claim does not hold at this SHA.
  - smoke_loop: FAIL (11). "walked to table:LongTable (at (3.93, 0.0, 3.01))" and "at Tt's table, the Long Table ()" fail, so the Candle Talk / sit / friends checks after it fail (10 follow-ons), plus "walk-out total for friends > 0". The name-tag check passes (Ty ♥). Probably the walk to the Long Table: venue changes (look-followups 86b40ab, closed rooms/table positions) or the Tt id/name rename; not diagnosed (no edits by the verifier).
- Not pushed, by rule. Logs (first run, rerun, all suites): side-session-notes/local_ddbbfc1d-.../verify-look-needs-logs/.
- EVIDENCE blocks of needs-stakes-build.md and look-followups.md: files they name exist at 24ff659 (captures, role notes, capture script, .blend files, palette doc). Hub card ids are stated, not checkable from the repo.
- Worktree removed (rm -rf, prune). Not verified: windowed/phone feel.
