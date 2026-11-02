# 🎮 camera-start-fix: smoke_start "no cut" after camera-feel-2 (2026-11-02)

Fix SHA c97abde (local main, unpushed). One line in `game/scripts/start_screen.gd` (`_start_pull`).

## Cause (b, a real glitch, not a measurement artefact)
At the start of the pull-back `_start_pull` called `p.rig.snap()` and then `p.rig.set_process(true)`. Since camera-feel-2
`CameraRig.snap()` runs `_physics_process(0.0)`, which returns while `is_processing()` is false, so the snap did nothing.
The pull-back's first frame therefore lerped toward the rig camera at (0,0,0); the next frame (after the first physics
tick had positioned the rig) toward (1.2, 6.04, 12.9). The height term (about 2.2 u times b.y) jumped by ~0.06 m in one
frame: 0.0976 m step against 0.04 m neighbours (14.1 m/s on a 7 ms headless frame; the old _process rig positioned itself
in time). Not (a): the measurement pairs each step with its process delta, and the spike sits in a single process frame
with no physics-tick pairing problem (log: `f=567 step 0.0166, f=568 step 0.0976, f=569 step 0.0402`, PULL log shows
`b=(0,0,0)` on f=566 and the real b from f=567).
Why it looked flaky/deterministic: it depends on how many process frames fall between the phase change and the first
tick; headless runs at ~145 fps vs 60 Hz physics (verifier: 14.1, 13.4; one of my first runs unfixed read 6.7).

## Fix
`p.rig.set_process(true)` before `p.rig.snap()`. Camera feel (follow_time, lead, per-area views, x1.5 landscape) untouched.
Test unchanged; limit still 12.0.

## Evidence
- smoke_start x3 after the fix: PASS, "camera speed at most 6.7 m/s (biggest step 0.05 m)" each time.
- Injection (local, removed): a 1 m x-jump of the start camera in one frame, 100 frames into the entry loop: FAIL,
  "145.4 m/s (biggest step 1.00 m)".
- test_feel, test_lounge, smoke_tap, smoke_hud: PASS.

## Re-run
From `game/`, `APPDATA` on an empty folder:
`Godot --headless --path . -s tests/smoke_start.gd` (see PROJECT.md for the exe).

## Open
- The other 9 suites were not re-run by me (they do not touch start_screen.gd); verifier re-runs all 14 on the SHA.
- `git pull --rebase` was refused (unstaged changes from other sessions in the shared tree); nothing pulled, nothing pushed.
