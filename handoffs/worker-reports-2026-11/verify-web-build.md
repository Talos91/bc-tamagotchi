# 🔍 verify-web-build (2026-11-02): PASS 14/14, 82ef3e6 pushed, web build OK

EVIDENCE
- SHA verified: 82ef3e6 (local tip). Clean worktree, `--import` first, fresh empty APPDATA per suite. The first run died with a PC crash; the whole run was redone from scratch (no rerun of a failing suite was needed).
- Pushed with it (origin/main..82ef3e6): 8a46bd3 cf02ffe 82ef3e6. `git ls-remote origin main` = 82ef3e6 (`3d393e7..82ef3e6`).
- 14/14 PASS: smoke_stairs, smoke_tap, smoke_hud, test_needs (106), test_minigames (1468), smoke_loop, smoke_doors_sit, smoke_start, test_menu (3655), smoke_version, test_nightlife (107), test_seats, test_feel, test_lounge.
- `python tools/build_web.py` (no --deploy): exit 0, `web/index.html` present, "built web/ (bc-2a901f0c, 53.9 MB)": wasm 37.7 MB, pck 15.7 MB, js 0.3 MB, `du` 52M.
- Worktree rm -rf'd and pruned. Logs: side-session-notes/local_ddbbfc1d-.../verify-web-build-logs/.
- Not verified: the exported build running in a browser or on a phone; deploy (waits on Vercel login).
