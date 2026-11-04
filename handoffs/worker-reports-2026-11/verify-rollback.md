# 🔍 verify-rollback (2026-11-04): PASS 17/17, 8889dce pushed

EVIDENCE
- SHA verified: 8889dce (local main tip, clean detached worktree in scratchpad, `--import` exit 0, fresh empty APPDATA per suite, one Godot at a time, no reruns needed).
- Commits in origin/main..HEAD (5): 8889dce LOG, 840b2da report trim, 5b7c592 report+role note, 80fc8a4 movement rollback (code: player.gd, test_touch.gd), 0c365dc owner feedback docs. Base was c7f8cc8.
- 17/17 PASS, all exit 0, 0 SCRIPT ERROR: smoke_stairs, smoke_tap, smoke_hud, test_needs, test_minigames, smoke_loop, smoke_doors_sit, smoke_start, test_menu, smoke_version, test_nightlife, test_seats, test_feel, test_lounge, test_touch, test_string_keys, test_walk.
- Pushed: `c7f8cc8..8889dce 8889dce -> main`; `git ls-remote origin main` = 8889dce2931196929f16b1121d0b639da7847e65.
- Logs: side-session-notes/local_ddbbfc1d-.../verify-rollback-logs/ (one log per suite + results.txt).
- Worktree removed (rm -rf) and pruned; only the shared checkout remains.
- Not verified: web build, real device, the feel of the camera-relative stick (suites only).
