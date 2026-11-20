# Report: perf-iphone-1120 (🖼️ UI worker, Opus 5.5, 2026-11-20/21; mobile optimisation round, iPhone first)

Owner words (Daniele 2026-11-20, via the orchestrator): an optimisation round for mobile, especially iPhones, on top of the
venue update; "my whole phone overheat", the app "cannot be installed", the phone keeps showing an old build, and "add a
full screen button in the interface to force full screen (vertical)". Load ids 2026-11-20-ui-black-cabin-152930 (first
worker) and 2026-11-20-ui-black-cabin-b09079 (successor).

## EVIDENCE
- Branch `wk/perf-iphone` (worktree `C:/Users/itisf/bc-wt/perf-iphone`), rebased on origin/main **0b5fa04** (v0.4.4:
  overflow, telemetry, QR remake, creator-fix 2, merch shop, check-in hotfixes, endless minigames, presence fixes,
  still-here prompt). Code commit 3e6127e (was 48492a9 before the rebase), captures 080c3ea, then this report and the
  separate version commit **0.4.5** (orchestrator's order). Not pushed (verify-queue-1120 pushes).
- Rebase: two additive conflicts (DECISIONS.md rows, strings_ui.csv rows), both sides kept. project.godot: main's six
  autoloads all kept + FramePacer.
- Suites on the rebased tree, each with its own empty APPDATA: **38/38 PASS, rc=0** (the 36 of PROJECT.md +
  `test_battery_saver` (new, this job) + `test_merch_profile` (on main, missing from PROJECT.md's list)). Logs
  `C:/Users/itisf/bc-wt/pi-suites/` (`summary.txt`). Before the rebase: 32/32 PASS on 48492a9. smoke_version re-run
  after the bump (see the version commit).
- Hub cards: **perf-iphone-1120-review** (order 411, merge pictures) — answered "ok" by Daniele 2026-11-20 13:53 (not yet
  in DECISIONS: orchestrator). **perf-iphone-1120-saver** (order 412, new): full-screen button pictures + ONE question,
  battery saver on by default for phones (30 venue / 15 idle; rec: yes).
- Captures: `docs/art/screens/perf-iphone-1120/` (card sheets, incl. `fullscreen-{portrait,landscape}.jpg`); full-screen
  raw shots `C:/Users/itisf/bc-wt/pi-out/fs/`; 20 views before/after on 0b5fa04, PNG: `pi-out/b44-p`/`a45-p`,
  `b44-l`/`a45-l` (logs `views-b44-*.log`, `views-a45-*.log`, `probe-pb44.log`, `probe-pa45.log`, `saver45.log`,
  `sw45b.log`, `sw45fresh.log`).
- iPhone test script: `docs/tech/iphone-test-script.md` (8 steps). Docs: `docs/tech/03-web-build.md` § Static merge and
  the iPhone round.
- Telemetry: Supabase read 2026-11-20 (connector on, then off): `perf_reports` 0 rows ever; `play_events` 2 rows, both a
  worker's tests. Daniele's phone sent nothing (the live build then had no hook). No real-phone data.

## Method
Before = clean worktree of origin/main 0b5fa04 (`C:/Users/itisf/bc-wt/perf-iphone-base`), after = this branch rebased on
it. Godot 4.6.1 console (godot-local), Compatibility renderer, RTX laptop.
- Per view: `tools/perf_views.gd --fixed-fps 30 -- --win 720x1560 --phone` (portrait; 3D 480x1040, MSAA off) and
  `--win 1560x720` (landscape), on the private hidden desktop (hd.ps1), fresh APPDATA per run, same frame before/after;
  pixel diff = share of pixels whose grey difference > 8.
- Memory in the venue: `tools/perf_probe.gd -- --skip-intro` at 750x1624 (Godot monitors).
- Web: local export of this branch (`pi-tools/build45.py`, godot-local exe), served locally, headless Chrome over CDP:
  `saver_test.mjs` (draw calls/s, phone emulated) and `sw_test.mjs` (service-worker update path, installability).

## Before / after (on 0b5fa04, v0.4.4)
| | before (main 0b5fa04) | after (this branch) | how |
|---|---|---|---|
| Draws, Corridor (portrait) | 3,216 | 1,524 (-53 %) | perf_views |
| Draws, Curtains | 3,176 | 1,433 (-55 %) | |
| Draws, Corridor End | 2,131 | 1,103 | |
| Draws, Floor | 1,792 | 1,047 | |
| Draws, Lobby / Bar / Stage | 1,463 / 918 / 1,120 | 900 / 504 / 770 | |
| Draws, all 20 views portrait | 524-3,216 (sum 25,162) | 426-1,524 (sum 14,747, -41 %); every view -16 to -55 % | |
| Draws, all 20 views landscape | 569-2,124 (sum 20,839) | 415-1,097 (sum 12,679, -39 %); every view -22 to -53 % | |
| Render CPU ms, Corridor / Curtains (desktop) | 9.5 / 8.6 | 7.9 / 7.4 | noisy, suites ran alongside |
| GPU ms, Corridor / Curtains (desktop) | 8.3 / 7.5 | 6.6 / 6.4 | |
| Pixels changed, same frame | - | 0-0.1 % in 35 of 40 shots; Stage 0.9 / 0.8 % (carpet speckle, as on the first card); landscape Floor 0.8 %, Merch 0.2 %; landscape Bar 3.8 % = the mirror ball at a different turn (its merged copy is parented under DiscoBall in code, so it still turns) | cmp.py |
| GPU memory in the venue (vram) | 89.8 MB | 97.5 MB (+7.7, mesh buffers 18.0 -> 25.8) | perf_probe |
| Web, start screen, phone emulated: draw calls/s | 73,860 (`?saver=0`) | 20,558 (default) ; frames drawn 60 -> 16.6/s | saver_test |
| Web .pck / .wasm (this branch) | - | 23.29 / 37.69 MB (pck grew from 22.75 with main's new assets; this branch adds scripts only) | local export |
| Install check (Chrome, fresh profile) | live: `manifest-display-not-supported` | 0 errors | sw_test |
| Update path | live: old build kept (Godot's cache-first worker) | from Godot's old worker: the new build loads at the next open; the build after it takes over within 22 s on its own | sw_test |

## What changed
1. Static merge on (`game/scripts/venue_batch.gd` `merge_static`): chunks keep <= 8 lights by the engine's own light
   boxes, same pixels, sliced over frames in a `MergeWorker` node (6 ms/frame). Shadow proxies extended.
2. Battery saver (`game/scripts/frame_pacer.gd`, autoload FramePacer): touch phones on the web draw 30 fps in the venue,
   15 after 20 s without a touch, uncapped in minigames; `?saver=0/1`; Debug > Performance > Battery saver.
3. Full-screen button (`game/scenes/ui/fullscreen_button.gd`, HUD title row): Fullscreen API + portrait lock; iPhone:
   "Add to Home Screen for full screen" hint for 6 s. Capture-only `force_show` + `tests/capture_fullscreen.gd`.
4. Install + update (`tools/build_web.py` pwa_patch, preset display standalone + iOS meta): installable; service worker
   skipWaiting, clients.claim, network-first page, one reload when it replaces an older build's cache.
5. `test_battery_saver` (new suite) guards 2 and 3 and a venue_batch parse error.

## Left, and why
- Look trade-offs, not decided (only if the friend's phone still struggles): shadow map 2048 -> 1024 on phones (-6 MB),
  iPhone pixel ratio cap 2 -> 1.5, corridor mural 2048x640 -> 1024x320, MSDF fonts.
- Bigger jobs, no look change, follow-ups: custom web export template without unused modules (wasm 37.7 -> est. 25 MB),
  minigame art in a second pck, ETC2/ASTC texture compression (needs `.import` settings in git: owner/tech decision).
- In portrait the iPhone hint covers the pet tag for its 6 s (left as is).
- PROJECT.md's suite list lacks `test_merch_profile` and `test_battery_saver` (orchestrator adds suites).
- Not verified: a real iPhone or Android phone; the battery saver's effect on heat; the web build in a visible browser;
  in a Chrome profile that had the old build, the install check still reported the old manifest error during the test
  (fresh profile: 0 errors); iPhone Safari's Add to Home Screen.

## Incidents
- Drive-mount worktree index left as `index.lock` after `git worktree add`; renamed (no git running).
- A first import of the base worktree crashed while another session ran Godot; the retry passed.
- `bc-perf2/build.py` calls the Ooze Godot path and fails with an empty APPDATA (no export templates): wrapped in
  `pi-tools/build45.py` with the godot-local exe and the normal APPDATA.
- The first worker hit 41 % context and handed over; the successor finished from the role note.

## Profile note
- Loaded as `ui`; the fifth perf job on the ui profile. A `perf` / tech-art profile (measure, ablate, same-frame captures,
  web probe, headless Chrome) would fit; suggest `request_agent` at the next organize pass.
