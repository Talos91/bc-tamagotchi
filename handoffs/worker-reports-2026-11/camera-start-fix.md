# 🎮 camera-start-fix report (2026-11-02)

EVIDENCE
- SHA: c97abde on local main (unpushed; commit touches only game/scripts/start_screen.gd). Verifier pushes.
- Cause: (b), a real one-frame jump at the start of the pull-back, not a measurement artefact.
- smoke_start x3 (empty APPDATA, headless): PASS ×3, peak 6.7 m/s, biggest step 0.05 m (was 14.1 m/s, 0.10 m).
- Injection (temporary, removed): 1 m jump of the start camera in one frame: FAIL, 145.4 m/s (biggest step 1.00 m).
- test_feel PASS (0 failures), test_lounge PASS, smoke_tap PASS, smoke_hud PASS.
- Notes: handoffs/camera-start-fix-2026-11-02.md. No hub card (camera feel unchanged; limit 12.0 unchanged; test unchanged).

Diagnosis: per-frame log (step, process delta, physics frame) showed one spike (0.0976 m vs 0.04 m neighbours) on the
first pull frames, no two-tick pairing. Logging inside `_pull` showed the rig camera position b = (0,0,0) on the first
pull frame and the real (1.2, 6.04, 12.9) from the next. `_start_pull` called `rig.snap()` before `rig.set_process(true)`;
since camera-feel-2 snap() runs `_physics_process(0.0)`, which returns while the rig is off, so snap did nothing and the
pull's height term jumped when the first physics tick positioned the rig.
Fix: one line, `set_process(true)` before `snap()`.

Open: other 9 suites not run by me (untouched paths); `git pull --rebase` refused (other sessions' unstaged changes), nothing pulled.
