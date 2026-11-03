# 🔍 verify-ty-walled (2026-11-03): PASS 15/15, efc4ea4 pushed

EVIDENCE
- SHA verified: efc4ea4 (clean detached worktree, `--import` exit 0, fresh empty APPDATA per suite, one Godot at a time, no reruns).
- Pushed: `a88a329..efc4ea4 efc4ea4 -> main`; `git ls-remote origin main` = efc4ea47b8afaf8f93f301efd985c48fa47573cd. 9 commits (origin/main..efc4ea4): efc4ea4 bc5440e 3492232 6a504ef 09fc6a9 65b7de7 b40d873 72cf9c1 2b89962.
- 15/15 PASS (all exit 0): smoke_stairs, smoke_tap, smoke_hud, test_needs, test_minigames, smoke_loop, smoke_doors_sit, smoke_start, test_menu, smoke_version, test_nightlife, test_seats, test_feel, test_lounge, test_touch.
- Web build: `python tools/build_web.py --out <scratch>` exit 0, index.html 5693 bytes, folder 54.0 MB (bc-72429ecb); not deployed.
- "Ty" check: served my build on port 8791, browser pane at 375x812, start screen shows "Ty" over the poster by the door; stamp reads v0.2.0 · efc4ea4 · dirty. No `cast.tt.name`.
- Trap: port 8765 already runs someone else's `http.server` (PID 57568, since 02:50) serving a stale build (bc-6adb4fd7, b40d873) that does show raw `cast.tt.name`. My first screenshot hit it; I re-served on 8791 and rechecked. Left 57568 running; it is not mine.
- Logs: side-session-notes/local_ddbbfc1d-.../verify-ty-walled-logs/. Worktree, build and my servers removed, pruned.
- Not verified: windowed/phone feel, the TH name in the web build, the 3492232 camera/walled-bar behaviour beyond the suites (no visual check).
