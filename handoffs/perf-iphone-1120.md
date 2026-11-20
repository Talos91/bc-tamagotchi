# Role note: 🖼️ perf-iphone-1120 (2026-11-20, mobile optimisation round, iPhone first)

Orchestrator now: **local_14422c6c-6819-4921-bfc9-af16d4185b7b** (handover from local_5352afaa). Load id of the first
worker: 2026-11-20-ui-black-cabin-152930 (capture replies_to). Self-handover at 41 % context, 2026-11-20 evening.

## State now
- Branch `wk/perf-iphone` in `C:/Users/itisf/bc-wt/perf-iphone`, base 4e9dbc8 (venue entrance; on origin/main now, with docs-only
  commits after it). Tip **48492a9** (WIP, clean point) + this note. Not rebased yet, not pushed (the Verifier pushes).
- **HOLD (orchestrator 11-20):** no final numbers and no report until the orchestrator sends "main has everything" (overflow-seats,
  play-telemetry, creator-fix 10 items land first). Then: `git rebase origin/main`, re-measure on that build (new clothing and
  venue props included), fix what they added, then report. At a clean point before that: commit and stay idle, no report.
- Done in 48492a9 (all verified as said):
  1. Static merge on (`venue_batch.gd` `merge_static`): chunks keep <= 8 lights by the engine's light boxes, same pixels
     (0-0.2 %, carpet speckle), draws -17..-53 % per view (Corridor 3,244 -> 1,533). Runs in a `MergeWorker` node, 6 ms/frame.
     GPU buffers +7.7 MB (compressed vertices). More shadow proxies.
  2. Battery saver (`scripts/frame_pacer.gd`, autoload FramePacer): touch phones on the web draw 30 fps in the venue, 15 after
     20 s without a touch, uncapped in minigames; `?saver=0/1`; Debug > Performance > Battery saver; line in the perf report.
     Headless Chrome, start screen, phone=1: draw calls/s 73,923 (off) -> 21,648 (default on); frames drawn 60 -> 17.6/s.
  3. Full-screen button (`scenes/ui/fullscreen_button.gd`, HUD title row): Fullscreen API + portrait lock; iPhone: hint
     "Add to Home Screen for full screen: Share → Add to Home Screen" under the title for 6 s. Strings in strings_ui.csv (reimport!).
     DECISIONS row 2026-11-20 added (his words).
  4. Install + update (`tools/build_web.py` pwa_patch, preset display=1 + iOS meta): manifest was `display: browser` ->
     Chrome `manifest-display-not-supported` (that is why "cannot be installed"); now 0 installability errors. Service worker:
     skipWaiting, clients.claim, network-first page, and on replacing an older build's cache it reloads open pages once (not
     awaited: awaiting deadlocked). Headless Chrome test `C:/Users/itisf/bc-wt/pi-tools/sw_test.mjs`: from Godot's old worker
     (like Daniele's phone) deploy A runs after one reopen, deploy B at once; push manager intact.
  5. Telemetry: Supabase read (connector on, then off again): `perf_reports` 0 rows ever; `play_events` 2 rows in 6 h, both
     the play-telemetry worker's tests (dirty build, curl). Daniele's phone sent nothing (live build has no hook). No model data.
- Hub card `perf-iphone-1120-review` (order 411, version 1): merge pictures only; needs an update with the full-screen
  button captures (portrait + landscape), the battery-saver question and the install/update notes.
- Suites: 31/31 pass on the pre-48492a9 tree except what was then fixed (test_feel via chunk parts, string keys after
  reimport, exit segfaults from static caches -> fixed). Full 32-suite run on 48492a9 was started in the background:
  results `C:/Users/itisf/bc-wt/pi-suites/summary.txt` (one log per suite there). Check it first.

## Successor progress (session local_f76df517 era, load id 2026-11-20-ui-black-cabin-b09079; 2026-11-20 21:40)
- 32/32 suites PASS rc=0 on 48492a9 (`pi-suites/summary.txt`, test_walk "fail" words are table headers).
- a76c65b: `FullscreenButton.force_show` (capture-only static) + `tests/capture_fullscreen.gd`; captures 720x1280 /
  1280x720 on the hidden desktop (1080x1920 gets clamped to 1080x1421 there): `pi-out/fs/`, sheets
  `docs/art/screens/perf-iphone-1120/fullscreen-{portrait,landscape}.jpg`. In portrait the hint covers the pet tag
  ("Ty ♥") for its 6 s; left as is.
- Hub: `perf-iphone-1120-review` was already ANSWERED "ok" by Daniele 13:53 (version 2), so the battery-saver question
  went on a NEW card `perf-iphone-1120-saver` (order 412, version 1; options on (rec) / venue-only 30 / off) with the
  two full-screen pictures and the install/update notes. Orchestrator copies answers to DECISIONS.
- Now: waiting for "main has everything" from local_14422c6c (step 4). Queue before us: merch-shop, minigame-ramp (0.4.2),
  presence hotfix (0.4.3). No Godot until that message (it also means Godot is free). Daniele (via orchestrator): push
  everything live tonight, no questions back.
- Orchestrator 11-20: after rebase (keep every autoload line in project.godot; trial merge: DECISIONS.md + strings_ui.csv
  conflict, both additive), suites with empty APPDATA, re-measure, then a SEPARATE final commit bumping
  `game/project.godot` version to **0.4.4** (orchestrator's order; overrides the profile's "never bump"). Send the SHA;
  Verifier verify-queue-1120 pushes.

## Next steps (successor)
1. Read `pi-suites/summary.txt`; every line must end PASS with rc=0 (32 suites incl. test_battery_saver). Fix any failure.
2. Captures of the full-screen button: on desktop it is hidden (not web). Add a capture-only switch (e.g. a static
   `force_show` in fullscreen_button.gd set by a `tests/capture_fullscreen.gd`), shoot portrait 1080x1920 + landscape on the
   hidden desktop (`C:/Users/itisf/bc-wt/pi-tools/hd.ps1`, never a visible window), plus the iPhone hint shown.
3. Update the hub card (ArtifactData update with if_version 1; pictures via Artifact asset upload, copy files to the
   scratchpad first): add the button pictures, and ONE question: keep the battery saver on by default for phones
   (30 fps venue / 15 idle; rec: yes). Look trade-offs stay listed as "later, only if the friend's phone still struggles".
4. Wait for "main has everything" from local_14422c6c. Then rebase on origin/main, re-import, re-run
   `pi-tools/views.ps1` (before = a clean worktree of the new origin/main without this branch, after = rebased tip),
   `probe.ps1`, the web build (`bc-perf2/build.py`) + `saver_test.mjs` + `sw_test.mjs`; fix what the new work adds;
   rewrite the report's tables; 32 suites; LOG.md line; exit ritual (report file, capture, final message to local_14422c6c).

## Gotchas
- Lights: the engine pairs omni/spot lights by box (`Light3D.get_aabb()`), max 8 per object: chunks must stay <= 8.
- Never hold textures/materials in static vars (freed after the renderer at exit -> segfault rc 139 in smoke_hud etc.).
  No pending coroutines at quit either (leak + crash): use a child node for sliced work.
- A broken venue_batch.gd parse error does NOT fail most suites (they still print PASS): test_battery_saver guards it.
- Same-frame captures: fresh APPDATA per run, no ablations in the same run; delete `game/build_info.json` after local builds.
- CSV string changes need `--import` before tests see them.
- Bash heredocs here eat backslashes: write Python fix scripts with the Write tool into the scratchpad and run them.
- The built-in browser pane cannot register service workers ("unknown error"): use headless Chrome via node + CDP
  (`pi-tools/sw_test.mjs`, `saver_test.mjs`; kill only chrome.exe whose command line has `bc-sw-`).
- `git worktree add` on the Drive mount can leave `index.lock` instead of `index`: with no git running, rename it.
- QR codes / table codes / presence check-in tables: do NOT touch (Daniele testing tonight).
- Scrolling on phones belongs to creator-fix-1120, not here.
