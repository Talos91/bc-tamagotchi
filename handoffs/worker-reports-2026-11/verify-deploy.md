# verify-deploy: 56b249b (auto web deploy pipeline): PASS, PUSHED
Verifier 2026-11-20, load id 2026-11-20-verifier-black-cabin-60ad8f.
- SHA 56b249b2e099c76f680c60a76dcf346409718ab7 (4e6d342 code + 56b249b docs). VERIFY 56b249b: PASS 30/30 suites (import exit 0, empty APPDATA per suite; slowest test_feel 286 s).
- Pushed f1f122b..56b249b; ls-remote main = 56b249b2e099c76f680c60a76dcf346409718ab7 (match). Only that SHA; local main is ahead with other docs commits, not pushed.
- Web build: exit 0, 58.2 MB (wasm 37.7 MB, pck 20.0 MB, js 0.3 MB), hash tag bc-698aa521.
- `tools/web_smoke.py --local` against that folder: 16 files, OK (exit 0).
- Workflow YAML parses (yaml.safe_load); only secret = VERCEL_TOKEN; no token values in the diff (names and docs only).
- build_web.py diff = 1 docstring line; script parses. Manual `--deploy` not executed (would deploy).
- Not verified: real GitHub Actions run, Vercel preview/prod smoke (not triggered per brief; Daniele adds the secret first), real device.
- Incident: the first two attempts crashed at import (exit 3221225477), and so did the control on main (3221225501), while running Godot from the Google Drive path. Copying both exes (console + GUI) to C:/Users/itisf/godot-local/ fixed it; run the skill with --godot C:/Users/itisf/godot-local/Godot_v4.6.1-stable_win64_console.exe. Skill/PROJECT.md default path should point at a local copy.
- A Git Bash commit segfaulted once and left a stale .git/index.lock (removed; no git process was running).
