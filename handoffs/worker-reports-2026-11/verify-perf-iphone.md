# Verify 86878a5 (item 29: start-screen cull + web context-loss banner)
VERIFY 86878a5e3abdfe34739d01e64d022ac2ce18c520: PASS 19/19 suites (import exit 0, empty APPDATA per suite, one Godot at a time). Verifier: Sonnet, load 2026-11-10-verifier-black-cabin-a3ebcb.
- Pushed: 149d170..86878a5 (c5bdef8 + 86878a5, fast-forward). `git ls-remote origin main` = 86878a5e3abdfe34739d01e64d022ac2ce18c520. 3ac4e99 and later local commits NOT pushed.
- Web build: `tools/build_web.py --out <scratch>/web` exit 0, 54.2 MB; built index.html contains "context" (5 hits, banner in shell).
- Diff 86878a5 vs 149d170: no change to game/assets/kit/layout.json, game/scripts/rules.gd, game/project.godot (version 0.2.0 untouched). 13 files: main.gd, start_screen.gd, smoke_start.gd (+6), perf_probe.gd, build_web.py, web_probe.js, docs/tech/03-web-build.md, screens.
- Suites: 19 in game/tests/ incl. test_debug_tools; slowest test_feel 227 s.
- Logs: C:\Users\itisf\AppData\Local\Temp\claude\367d8cda9bb5f12e\ca6c64dc-2d6f-422f-8c1e-b410b359b0cd\scratchpad\verify-86878a5
- Not verified: real iPhone (does the friend's device still lose WebGL context), the banner firing on real context loss, draw-call count (6,858 -> 1,414) on device, look of start screen by eye.
- Note: waited ~85 min for Godot to be free (camera-areas runs); no profile problems.
