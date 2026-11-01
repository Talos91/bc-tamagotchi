# 🛠️ smoke_start "no cut" flake — state 2026-11-02

`game/tests/smoke_start.gd`, the "no cut" check in the entry loop. Test-only change; `scripts/start_screen.gd`,
`scripts/exit_shot.gd` and the camera are untouched, and there is no cut in the camera.

## Cause
The old check divided the camera's displacement between two samples by the wall-clock time between them
(`Time.get_ticks_usec`, ignored when under 4 ms). The two do not line up. Order inside one Godot frame: the
SceneTree script's `_process(delta)`, then `process_frame` (the `await` in the test resumes here), then the nodes
(the start screen moves the camera by `delta`). A sample therefore sees the camera as the PREVIOUS frame left it,
moved by the previous frame's delta, while the wall time covers the current frame. After one long frame and one
short one the quotient spikes (12.4 to 14.6 m/s seen); the camera never moved faster than about 8 m/s.

## Fix
- `smoke_start.gd` is now a `_process(delta)` override that keeps `frame_delta`; the entry loop pairs each camera
  step with the delta of the frame that made it (`moved_by`, one sample behind) and checks
  `step / that delta < 12 m/s`. A hitch makes both the step and the delta long, so the quotient stays put.
- The check line also prints the biggest single step (`max_step`) so a failure shows the size of a jump.
- Real speed: peak about 8 m/s, biggest step about 0.055 m per frame at 60 fps.

## Evidence the check still catches a cut
Temporary local copies (removed, not committed), one 100-frame-in injection each:
- A node with `process_priority` 1000 moved the start camera 1 m in one frame, after the start screen had placed
  it: FAIL, "136.2 m/s (biggest step 1.01 m)".
- `OS.delay_msec(250)` three times in the loop (frame hitches): PASS, 7.9 m/s with a 0.53 m step.
- Before the fix, the unmodified test failed once at 12.4 m/s on the first run of this session (no injection).

A wall-time window (displacement over at least 0.1 s) was tried as a second measure and dropped: it read 9.8 m/s
under the 250 ms hitches (closer to the limit than the per-frame figure, so it would flake again), and it added
nothing the per-frame check does not catch.

## Runs
smoke_start headless, 10 in a row after the fix; logs in the session scratchpad
`C:\Users\itisf\AppData\Local\Temp\claude\H--My-Drive-PROJECTS-Black-Cabin-Tamagotchi\89f53cd0-a2ca-4b86-af7f-b43f290b4ede\scratchpad\`
(`smoke_start_run1.log` to `smoke_start_run10.log`, `run10_summary.log`): 10 of 10 PASS, camera peak 7.9 m/s in every
run (run 3 had a natural hitch, 0.23 m step, and still read 7.9). Other suites, once each, all PASS: smoke_stairs,
smoke_tap, smoke_hud, test_needs, smoke_loop, smoke_doors_sit, test_menu, test_minigames (828 checks). They ran in
the shared tree with other sessions' uncommitted edits (menu, venue), not in a clean worktree.

## Loose end
`game/tests/smoke_loop.gd.uid` is untracked; every other test in `game/tests/` has its `.uid` tracked, so it should
be committed by the zone-wiring session's owner (not by this job). `tools/blender/__pycache__/` should be ignored
or left alone, not committed.
