# 🔍 verify-camera-2 (2026-11-02): FAIL, nothing pushed

EVIDENCE
- SHA verified: 2b01291630e8a545bb7b08cc56ddd5f82722b308 (clean worktree, `--import` first, APPDATA empty per suite).
- 13/14 PASS: smoke_stairs, smoke_tap, smoke_hud, test_needs, test_minigames, smoke_loop, smoke_doors_sit, test_menu, smoke_version, test_nightlife, test_seats, test_feel, test_lounge.
- **FAIL: smoke_start**, reran once, same result (deterministic, not a flake):
  `SMOKE START FAIL (1): ["no cut: camera speed at most 14.1 m/s (biggest step 0.10 m)"]` (rerun: step 0.11 m).
  Check is `max_speed < 12.0` at game/tests/smoke_start.gd:127 (diorama camera must not cut while the door closes). The camera-feel-2 follow (tight follow / snap) likely made the start-screen camera step faster. The worker's "14/14" did not hold in a clean worktree.
- Push: none. `git ls-remote origin main` = 5b657d09e66dfb35fab7e644048e2120099865f4 (unchanged). Not pushing this report either (it would carry the 7 unverified commits).
- Worktree removed (rm -rf) and pruned. Logs: scratchpad notes folder `side-session-notes/local_ddbbfc1d-.../smoke_start.log`, `smoke_start_rerun.log`.
- EVIDENCE claims of camera-feel-2.md: files exist (report, role note handoffs/camera-feel-2-2026-11-02.md); card ids camera-feel-2-accept, camera-closer-still, camera-patrons-in-front are stated (hub not opened by me); "14/14 on 406d2fd" is NOT confirmed (smoke_start fails on 2b01291, whose code equals 406d2fd).
- Not verified: windowed/phone feel; whether smoke_start failed before camera-feel-2 (not tested on 5b657d0).
- Next: a fix worker for smoke_start (camera speed on the start-screen diorama), then re-verify.
