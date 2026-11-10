# verify-perf-iphone-2 (🔍 Verifier, Sonnet, load id 2026-11-10-verifier-black-cabin-c28b91)

EVIDENCE
- VERIFY cac24e5: PASS 19/19 suites (clean worktree, empty APPDATA per suite), web build exit 0 (54.3 MB). Pushed 1c79f46..cac24e5; ls-remote main = cac24e5907aad29b85989197312fb99adba2e97a.
- VERIFY 4620eb5 (version 0.2.1): PASS 19/19 on rerun, smoke_version PASS, web build exit 0. Pushed cac24e5..4620eb5; ls-remote main = 4620eb5d6e0655661b1beca51b216b7c175b385e. This push also carried 0933571 (docs only).
- First 4620eb5 run: 18/19, test_seats exit 1, 0 SCRIPT ERROR, log cut after "the seated player faces the seat's way in the world", no FAIL line. Same suite passed on cac24e5 and on the one rerun (full suite set rerun once). Looks like a flake; cause not found. Watch test_seats.
- Logs: %TEMP%\claude\...\scratchpad\verify-cac24e5, verify-4620eb5 (failed run), verify-4620eb5-rerun.

DONE-WHEN
- Diff cac24e5 vs 1c79f46: layout.json and rules.gd untouched; project.godot only +gl_compatibility/item_buffer_size=4096, version 0.2.0: PASS.
- Diff 4620eb5 vs cac24e5: project.godot version 0.2.0 -> 0.2.1 only, plus LOG.md and STATE.md: PASS.
- Fast-forward from 1c79f46 (then cac24e5): PASS.

NOT VERIFIED: real iPhone / device GPU memory (headless and emulation only). PROJECT.md lists 19 suites, folder holds 19: match.
