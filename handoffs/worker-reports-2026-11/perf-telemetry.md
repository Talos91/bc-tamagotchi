# Report: perf-telemetry (🛠️ Opus 5.5, 2026-11-19, owner item 41)

Owner words (Daniele 2026-11-19): "we need telemetry a friend tried to play and game was lagging like crazy we need to optimize majorly". Load id 2026-11-19-ui-black-cabin-116cc9.

## EVIDENCE
- Branch `wk/perf-telemetry` (worktree `C:/Users/itisf/bc-wt/perf-telemetry`), rebased on origin/main 2bfe88c (Q1+Q2 in), tip = the commit that adds this report (code 687cc0b). Not pushed, no version bump.
- Suites: **24/25 PASS** on the rebased tip (687cc0b code), headless, each suite with its own empty APPDATA, after a fresh import: smoke_stairs, smoke_tap, smoke_hud, test_needs, test_minigames, smoke_loop, smoke_doors_sit, smoke_start, test_menu, smoke_version, test_nightlife, test_seats, test_lounge, test_touch, test_string_keys, test_walk, test_debug_tools, test_avatar, test_tonight, test_coaster_flip, test_neon_moth, test_soi_dash, test_shake_serve, test_perf_telemetry (39 ok); **test_feel 1 FAIL, pre-existing** (below).
- `test_feel` "buffer walk: hidden by Zones/Tag_mali 8 ticks" fails on clean origin/main too (checked in a clean worktree of 4313aed and with my batching switched off): tonight's cast tag, date-dependent, not this work. The other 15 test_feel failures this pass caused (shadow-only proxies counted as walls) are fixed in the test: shadow-only meshes are never drawn.
- Web build: `python tools/build_web.py --out %LOCALAPPDATA%/bc-web-perf` built bc-a0699061 (57.8 MB, pck 19.7 MB), not deployed. Loaded in the built-in browser (hidden pane, `?perf=1&phone=1`): reached `start:title`, no console errors; the report's device-hints JS returns UA / GPU / pixel ratio / cores / memory class. The overlay itself was not seen on screen (hidden pane draws no frames).
- Hub cards: **perf-telemetry-review** (3 pictures + 6 files; options incl. auto quality on/off) and **telemetry-beacon** (design question: server copy of the report, what is kept).
- New suite `test_perf_telemetry` (39 checks): add to PROJECT.md Tests (orchestrator).

## Method
Desktop RTX 5080 laptop, OpenGL Compatibility, hidden desktop (hd.ps1), window 720x1560, 3D rendered at 480x1040, MSAA off (phone graphics), `--fixed-fps 30`, seed 41, vsync off: `tools/perf_views.gd` puts the player in each of the 21 camera areas, settles 90 frames, times 120. Before = same build with `--nobatch` (VenueBatch off). Render CPU/GPU ms = `viewport_get_measured_render_time_*`. **Not measured on a phone** (device unknown): draw calls are the number that carries to a phone browser, where every WebGL call costs CPU.

## Ranking (before; ablations, each alone)
| cost | evidence |
|---|---|
| 1. patrons (~70 skinned figures, 10 parts / 15 surfaces each, ~1,050 skinned draws) | hidden: Corridor GPU 24.1 -> 4.0 ms, Curtains 16.5 -> 2.1, Floor 7.2 -> 0.9; animation paused barely helps (skinning per surface per frame) |
| 2. key-light shadow map (2048, 30 m) re-draws ~1,075 casters | shadow off: Lobby draws 2,665 -> 392, Buffer 2,555 -> 414, Corridor 4,587 -> 2,804 |
| 3. static venue meshes in long views (4,093 surfaces, 891 materials) | Corridor / Curtains still ~2,200 main-pass draws after 1-2 |
| small: 42 lights | omni/spot all off: draws unchanged (lit in the base pass), GPU -0.5 to -5 ms only where patrons are seen |
| small: GDScript per frame (tealight flicker, crowd walk, doors), textures (cut 11-10) | not visible in render CPU; textures already shared |

## Before / after (draw calls; render CPU / GPU ms; same probe, same views)
| view | draws before | draws after | CPU before -> after | GPU before -> after |
|---|---|---|---|---|
| Corridor | 4,602 | 2,926 | 17.5 -> 5.1 | 16.2 -> 4.4 |
| Curtains | 4,908 | 2,894 | 20.4 -> 5.4 | 19.0 -> 4.8 |
| Corridor End | 3,501 | 1,804 | 10.9 -> 3.8 | 9.7 -> 2.5 |
| Floor | 2,497 | 1,551 | 7.4 -> 3.0 | 7.6 -> 2.5 |
| Lobby | 2,664 | 1,048 | 3.2 -> 1.7 | 2.7 -> 1.0 |
| Buffer | 2,557 | 1,051 | 3.4 -> 2.1 | 3.4 -> 1.3 |
| Merch | 2,249 | 892 | 2.3 -> 2.0 | 0.8 -> 0.7 |
| Memory | 2,062 | 687 | 2.3 -> 2.0 | 1.5 -> 0.9 |
| Booth | 2,052 | 742 | 2.3 -> 1.5 | 0.9 -> 0.7 |
| Stage | 1,829 | 893 | 2.6 -> 1.9 | 2.8 -> 1.0 |
| Lounge | 1,816 | 817 | 2.6 -> 1.9 | 3.2 -> 1.2 |
| Couch | 1,331 | 623 | 2.3 -> 1.7 | 2.8 -> 1.1 |
| Pinball | 1,194 | 578 | 2.3 -> 1.6 | 2.0 -> 0.9 |
| Bar | 1,139 | 703 | 2.3 -> 1.7 | 2.8 -> 1.2 |
| Alcove / Patrons / Cabinet / Counter / Door / Toilets / Smoking | 844 / 370 / 391 / 442 / 484 / 611 / 458 | 437 / 294 / 289 / 326 / 383 / 430 / 308 | ~1.6-1.9 -> 1.4-1.8 | ~0.7-1.7 -> 0.7-1.1 |
Crowd surfaces 1,222 -> 232. Shadow casters: ~1,075 separate -> 25 shadow-only proxies + 277 casting alone (185 cut-away / door pieces of one mesh, ceiling, transparent).

**Look:** captures of all 21 views, before and after, same frame: only a 10x10 px HUD corner differs (it differs between any two runs). `docs/art/screens/perf-telemetry/compare-before-after.jpg`, `before-/after-corridor|bar.jpg`.

## What changed
- `game/scripts/venue_batch.gd` (new): `merge_figure` (patron parts under one skeleton -> one skinned surface; colour, roughness, metallic per vertex; PLAIN_SHADER = StandardMaterial3D's own code for these defaults); `shadow_proxies` (static casters -> shadow-only meshes per venue group, and per cut-away / occluder piece as its child, so a cut wall's shadow still goes with it); `merge_static` exists, **off** (see below).
- Hooks: `venue.gd` (_ready, deferred), `venue_patron_figure.gd` (`look.merge`), `venue_patrons.gd` (`"merge": true` for the crowd; the player is never merged: venue.gd lifts its materials).
- Telemetry: `game/scripts/perf_telemetry.gd` (autoload PerfTelemetry), `perf_quality.gd`, Debug > Performance row in `scripts/ui/debug_panel.gd`, `?perf=1`. Docs `docs/tech/03-web-build.md` §Telemetry.
- Tools: `game/tools/perf_views.gd`, `perf_scan.gd`. Test: `game/tests/test_perf_telemetry.gd`; `test_feel.gd` skips shadow-only meshes.

## Left, and why
- `merge_static` (static meshes per 4 m cell, max 8 lights per chunk): Corridor 2,926 -> 2,275, Curtains 2,894 -> 2,211 draws, but 2.7 % of Corridor pixels change (wall lighting) and stage-floor speckles (coplanar faces in one draw). Off (`MERGE_STATIC`). Next if a phone still lags in the long views: find why the chunk lighting differs, or distance-cull small props there.
- Auto quality is ON (lighter = 3D 0.75, lowest = no key shadow), only after 6 s under 24 fps in the venue; Daniele chooses on the card.
- Not done: a real phone; the server beacon (card telemetry-beacon); landscape captures (the views probe runs portrait only).

## Profile note
- Loaded as `ui` (brief); a perf/tech profile would fit better (third perf job on the ui/researcher/map-builder fallbacks).
