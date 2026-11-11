# verify-perf-door (Verifier, Sonnet 5.5, load id 2026-11-11-verifier-black-cabin-1f64cf)

## EVIDENCE
- SHA **166918da1d1be48ace6a35f9c00cc8b86e826f2b**. `VERIFY 166918d: PASS 19/19 suites` (clean worktree, import exit 0, fresh empty APPDATA per suite, one Godot at a time; no test_seats flake, no reruns).
- Web build exit 0, 54.3 MB.
- Fast-forward from 49cbc2e: yes. Pushed 49cbc2e..166918d (da2b6cf, 49e851f, cbedd67, 166918d); `git ls-remote origin main` = 166918da1d1be48ace6a35f9c00cc8b86e826f2b.
- Logs: scratchpad `verify-166918d\` (%TEMP%\claude\...\scratchpad), results.json inside.
- Suite folder = 19 files = PROJECT.md list; no mismatch.
- Godot note: an Ooze `fog_playground` window (pid 108028, started 11:34) was open during the run (Daniele's exception); no Ooze test run was active.

## Done when
- Code diff is only `game/scripts/start_screen.gd` + `game/tools/perf_probe.gd` (+ captures/docs): pass.
- Suites 19/19, web build: pass.
- Door draws 6,440 → 1,350 and "no look change" (0 px at five moments): **not verified by me**, taken from the worker's report; I did not rerun perf_probe or compare images.

## Not verified
Real device / phone feel, perf numbers, pixel identity.
