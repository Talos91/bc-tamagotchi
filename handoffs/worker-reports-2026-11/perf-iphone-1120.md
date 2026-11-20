# Report: perf-iphone-1120 (🖼️ UI worker, Opus 5.5, 2026-11-20; mobile optimisation round, iPhone first)

Owner words (Daniele 2026-11-20, via the orchestrator): an optimisation round for mobile, especially iPhones, on top of the venue update. Load id 2026-11-20-ui-black-cabin-152930.

## EVIDENCE
- Branch `wk/perf-iphone` (worktree `C:/Users/itisf/bc-wt/perf-iphone`), base 4e9dbc8 (venue entrance round 4). Tip: see the commit that adds this report. Not pushed, no version bump.
- Suites: SUITES_LINE
- Hub card **perf-iphone-1120-review** (order 411): 3 pictures (portrait, landscape, carpet zoom) + 3 files; one question (ship it / something looks different).
- Captures: `docs/art/screens/perf-iphone-1120/` (card sheets); all 21 views before/after, portrait and landscape, PNG: `C:/Users/itisf/bc-wt/pi-out/` (`b-p`/`a3-p`, `b-l`/`a-l`; logs `views-*.log`, `probe-pb.log`/`probe-pa3.log`).
- iPhone test script: `docs/tech/iphone-test-script.md` (8 steps). Docs: `docs/tech/03-web-build.md` § Static merge and the iPhone round.
- Supabase perf rows: **not read**. The Supabase connector is off and needs Daniele's OK; and `perf_reports` can only hold rows once the client hook is wired (`Presence.perf_report()` is called nowhere yet, STATE "telemetry client hook"), and RLS lets a player read only their own rows. So there is no phone data yet.

## Method
Before = clean worktree of 4e9dbc8 (`C:/Users/itisf/bc-wt/perf-iphone-base`), after = this branch. Godot 4.6.1 console exe from godot-local, Compatibility renderer, RTX laptop.
- Per view: `tools/perf_views.gd --fixed-fps 30 -- --win 720x1560 --phone` (portrait; 3D 480x1040, MSAA off) and `--win 1560x720` (landscape), on the private hidden desktop (hd.ps1), one fresh APPDATA per run, same frame for before and after; pixel diff = share of pixels whose grey difference > 8.
- Memory in the venue: `tools/perf_probe.gd -- --skip-intro` at 750x1624 (Godot monitors). Start screen in the web build: `tools/web_probe.js` (bcPeak) in the built-in browser, 375x812, `?phone=1&dpr=3` (cap 2 on), local server, hidden pane.
- Download: live https://blackcabin.app (2ce7624) with curl, raw and brotli. Load: local builds, page open -> `start:title`, 3 runs each.

## Ranked costs (before, 4e9dbc8)
| # | cost | evidence |
|---|---|---|
| 1 | Static venue meshes drawn one by one (1,430 mesh instances, 3,329 surfaces; ~2,400 draws in Corridor) | ablations: Corridor 3,247 draws, shadow off 2,474, patrons off 3,068 |
| 2 | Key-light shadow pass (~770-860 draws: 277 casters left alone, each surface a draw) | shadow off: Lobby 1,452 -> 588, Corridor 3,247 -> 2,474 |
| 3 | Download: pck 22.7 MB raw / 17.8 MB brotli (barely compresses), wasm 37.7 / 8.9 MB | curl on blackcabin.app |
| 4 | GPU memory at the start screen ~94 MB: render targets 43.6 (two full-screen RGBA16F 18.6, two depth 9.3, shadow map 8), font atlases 10 (ten 512x512), corridor mural 2048x640 5, corridor neon 3.9, portraits 3.7 | `bcGroups()` |
| 5 | Patrons (~73 merged figures, ~180 draws; skinning GPU) | patrons off: Corridor -179 draws, GPU -3.6 ms (desktop) |
| 6 | 42 lights: no extra draws (lit in the base pass), GPU -0 to -5 % on desktop with all omni/spot off; per-pixel cost on a phone GPU not measurable here | ablation `omni` |
| 7 | Start: title ~6-9 s after page open on a local server (wasm compile + pck + scene), no network | bcSceneT, 3 runs |
Minigames: not measured separately; the 3D venue pauses behind a minigame frame (Q2, test_venue_pause).

## Before / after
| | before (4e9dbc8) | after | how |
|---|---|---|---|
| Draws, Corridor (portrait) | 3,244 | 1,533 | perf_views |
| Draws, Curtains | 3,167 | 1,426 | |
| Draws, Corridor End | 2,152 | 1,109 | |
| Draws, Floor | 1,790 | 1,045 | |
| Draws, Lobby / Bar / Stage | 1,453 / 939 / 1,112 | 890 / 525 / 762 | |
| Draws, all 21 views | 522-3,244 | 425-1,533 (-17 to -53 %) | |
| Draws, landscape Corridor / Floor / Bar | 1,716 / 2,036 / 1,292 | 1,016 / 1,087 / 618 | |
| Render CPU ms, Corridor (desktop) | 12.8 | 5.7-8.9 | noisy between runs |
| Pixels changed, same frame | - | 0-0.2 % (Stage 1.0 % portrait incl. version label; carpet speckle) | |
| GPU buffers in the venue | 18.2 MB | 25.9 MB (+7.7) | perf_probe |
| GPU total in the venue (vram) | 95.7 MB | 103.3 MB | perf_probe |
| Start screen GPU (web, cap 2) | 93.6 MB | 97.1 MB | bcPeak |
| .pck / .wasm | 22.75 / 37.69 MB | 22.75 / 37.69 MB | local export |
| Page open -> title (local) | 6.1 / 8.0 / 9.2 s | 7.7 / 8.4 / 7.6 s | same within noise |
| Merge work at load | - | 0.48 s native, sliced 6 ms/frame over ~41 frames | |

## What changed
- `game/scripts/venue_batch.gd`: `merge_static` on, rewritten: light pairing by the engine's own light boxes (`Light3D.get_aabb()`), greedy chunks per 8 m cell kept at <= 8 lights, a chunk made only when it draws fewer surfaces (also one mesh of many surfaces, e.g. the 60 shelf tiles of 17 surfaces), identical materials share a surface, untextured plain colours join via a 1x1 white texture, glass surfaces kept in a `_Rest` child, retired casters stay shadow-only, vertices compressed, material checks cached, packed-array maths (1.25 s -> 0.44 s native), sliced over frames. `shadow_proxies`: a single caster with several surfaces gets a proxy too.
- `game/scripts/venue.gd`: calls the sliced merge. `game/tools/perf_merge.gd` (new): what is merged and what is left, per group.
- Docs: `docs/tech/03-web-build.md`, `docs/tech/iphone-test-script.md`; captures `docs/art/screens/perf-iphone-1120/`.

## Left, and why (questions only if the friend's phone still struggles; on the card, recommendation: none now)
- Look trade-offs, not decided: shadow map 2048 -> 1024 on phones (-6 MB), iPhone pixel ratio cap 2 -> 1.5 (-44 % pixels, softer), corridor mural 2048x640 -> 1024x320 (-3.75 MB), MSDF fonts (one atlas instead of ten, slightly different text edges).
- Bigger jobs, no look change, proposed as follow-ups: a custom web export template without unused engine modules (wasm 37.7 MB -> est. 25 MB, needs an emscripten build); minigame art in a second pck fetched on first play (-~3.5 MB from the first download); texture compression (ETC2/ASTC) for phones would need `.import` settings in git (they are gitignored on purpose), so it is an owner/tech decision.
- `merge_static` keeps the originals' meshes alive (scene cache), so the merged copies cost +7.7 MB; freeing them saved only 1.7 MB and was dropped.
- Not verified: a real iPhone, the web build in a visible browser (the pane was hidden: no frame rates), landscape web numbers.

## Incidents
- My worktree's index stayed as `index.lock` after `git worktree add` (Drive mount), so `git status` showed every file deleted; renamed the finished lock to `index` (no git process running), status clean after.
- The first import of the base worktree crashed (FATAL index -1 in a CSV import) while another session ran Godot; the retry passed.

## Profile note
- Loaded as `ui`; this is the fourth perf job on the ui profile. A `perf` / tech-art profile (measure, ablate, same-frame captures, web probe) would fit; suggest `request_agent` at the next organize pass.
