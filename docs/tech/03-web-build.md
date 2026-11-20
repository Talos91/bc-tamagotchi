# Web build (phone browser)

Job 0 (BACKLOG A8): the game in a phone browser from a Vercel URL.

## One command
```
python tools/build_web.py            # stamp, import, export, hash, vercel.json  -> web/
python tools/build_web.py --deploy   # same, then `vercel link` + `vercel deploy --prod` (project bc-tamagotchi)
```
`web/` is gitignored output. `--out <dir>` builds somewhere else (the vercel link/deploy then run in that folder). **Recommended on this PC**, a folder outside Google Drive so sync never holds files:
```
python tools/build_web.py --deploy --out %LOCALAPPDATA%\bc-web
```
(PowerShell: `--out $env:LOCALAPPDATA\bc-web`.) On Windows the script calls `npx.cmd` (PowerShell blocks `npx.ps1`); log in once with `npx.cmd vercel login`. A clean state (no `web/`, no `game/.godot`) builds in about 2 minutes (first import dominates).

## What it does
1. `tools/version.py` stamps `game/build_info.json` (the in-game `v0.2.0 · sha`; commit first, or the label says `dirty`).
2. `Godot --headless --import`, then `--export-release "Web"` into `web/index.html`.
3. Renames `index.{wasm,pck,js}` to `bc-<hash8>.*` (hash of the three) and patches `index.html` and the service worker, so those files are cached for a year while `index.html`, the service worker and the manifest are `no-cache`.
4. Writes `web/vercel.json` (static site, the cache headers above).

## Preset (`game/export_presets.cfg`, tracked; was gitignored until 2026-11-02)
Web, single-threaded (`variant/thread_support=false`: no SharedArrayBuffer, no COOP/COEP headers needed), no GDExtension, PWA on (standalone, portrait), include filter `*.json,*.csv` (menu data, `build_info.json`), exclude `tests/*,tools/*`. Renderer is the project's Compatibility (GL ES3 / WebGL2). Portrait comes from `display/window/handheld/orientation` and the PWA manifest.

## Templates
Godot 4.6.1 web templates live in `%APPDATA%\Godot\export_templates\4.6.1.stable\` (`web_nothreads_*`, `web_dlink_nothreads_*`, `version.txt`). On 2026-11-02 they were copied from `H:/My Drive/PROJECTS/Ooze Syndicate/Tools/Godot/Web/`; only Web is installed (no desktop/mobile templates). To redo on another machine: Godot > Editor > Manage Export Templates, or the `Godot_v4.6.1-stable_export_templates.tpz` from the godot GitHub release (1.25 GB).

## Deploy
**Automatic since 2026-11-20:** a push to main that touches the game deploys itself (GitHub Actions); see `docs/tech/04-deploy.md`. By hand (fallback): needs a Vercel login on this machine: `npx vercel login` once (Daniele's account), then `--deploy`. `vercel deploy --temporary` (no login) was tried 2026-11-02 and the anonymous `*.tmp.now` URL answers 403 to everything, so it is not a route.

## Size
pck 15.7 MB, wasm 37.7 MB, js 0.3 MB; Vercel serves them brotli-compressed.

## Testing locally
`python -m http.server 8791 --directory <out dir>` (do not start it with `web/` as its working folder: it keeps the folder locked), open `http://localhost:8791/index.html`. A hidden browser pane throttles `requestAnimationFrame` to about 1 fps, so frame rates only count on a visible browser or a real phone.

## Download watch and resume (item 28, 2026-11-09)
The engine reads the 37.7 MB wasm and the pck as one stream and never catches an error in the middle of it, so one dropped connection (iPhone, Chrome for iOS: "Startup failed: Load failed" at ~45 %) killed the start with no retry. The shell guard in `build_web.py` wraps `fetch()` for `bc-<hash>.wasm/.pck` only: it resumes a broken stream from the received byte with a `Range` request (Vercel answers ranges with plain bytes, so offsets match) and the banner ends with "Last download: <file> HTTP <status> <encoding>, <MB> received, resumed Nx". Test a cut yourself: serve the build with a server that closes the first wasm response at ~24 MB; the log shows a second GET and the game still reaches "Tap to enter". Pick a port with `netstat -ano | findstr :<port>` first: another session's server on the same port silently serves a different build.

## Context loss and the GPU tally (item 29, 2026-11-10)
An iPhone lost the WebGL context at the start screen and the engine only showed its own `alert("WebGL context lost, please reload the page")`. The shell guard now:
- counts what the engine uploads to WebGL2 (textures, render buffers) and keeps the wasm memory, cheaply (upload calls only);
- catches `webglcontextlost` on `window` in the capture phase (before the engine's canvas listener, so its alert never shows) and opens the red banner "Black Cabin lost its graphics" with textures (count, MB), render buffers, canvas size and pixel ratio, wasm and JS heap, the last scene and seconds since the page opened, plus a **Reload** button (any banner has it);
- the last scene comes from `main.gd` `_mark_scene()` (web only, sent when it changes): `start:title`, `start:title:creator`, `start:walk`, `creator`, `minigame`, `menu`, `leaving`, `farewell`, `venue:<area>`.
Test it in a local build: in the console, `document.querySelector('canvas').getContext('webgl2').getExtension('WEBGL_lose_context').loseContext()`.

## Measuring (perf-iphone, 2026-11-10)
- Per-frame numbers from the engine: `Godot --path game --resolution 750x1624 -s tools/perf_probe.gd` (start screen) or `... -- --skip-intro` (one line per camera area). Windowed only; prints draw calls, objects, primitives, VRAM, lights.
- WebGL totals in the browser: copy a build, insert `tools/web_probe.js` in a `<script>` before the shell guard, open it with `?dpr=3` (fakes an iPhone pixel ratio) and read `bcProbe()` in the console. A hidden browser pane renders almost no frames, so take frame counts from `perf_probe.gd`, memory from `bcProbe()`.
- Start screen: the venue groups the street camera cannot see are hidden after three warm-up frames (`start_screen.gd` `UNSEEN_FROM_STREET`): 6858 -> 1414 draw calls.

## GPU memory on phones (item 33, perf-iphone-2, 2026-11-10)
An iPhone at pixel ratio 3 lost the WebGL context entering the venue with ~250 MB in use. Three cuts (numbers in `handoffs/worker-reports-2026-11/perf-iphone-2.md`):
- **Seam textures shared** (`game/scripts/seam_share.gd`, no look change): the 164 extracted `<glb>_bc_seam[2].png` hold 2 images; every material now uses one texture per kind (137 → 2 textures, −34 MB). `*.import` is gitignored, so this runs at load (main `_ready`, figure `_build_preset`), not as an import script. smoke_start fails if the seam files ever stop being 2 images.
- **Canvas item buffers** (`rendering/gl_compatibility/item_buffer_size=4096`, no look change): the renderer adds buffers as needed and never frees them; 25 × 2 MB after the creator became 11 × 0.5 MB.
- **Phone graphics** (DECISIONS 2026-11-10, on for touch phones by default; desktop browsers unchanged): the shell caps `devicePixelRatio` at 2 and sets `window.bcPhone`; `game/scripts/phone_graphics.gd` turns MSAA off (game view and creator preview) and, if the `scale` part is on, renders 3D at 0.75. With the cap the street sign goes up at 1024×512. Parts in `PHONE_PARTS` in `tools/build_web.py` (default `dpr`, `msaa`). Page URL switches for testing: `?phone=0` / `?phone=1`, `?pg=dpr,msaa,scale`. The context-loss banner says which parts were on.
- Measuring: `tools/web_probe.js` now marks render targets (`RT`) and has `bcGroups()` (textures by size and format) and `bcPeak` (peak per `bcScene`). The emulated pane reports no coarse pointer: add `?phone=1`.

## Telemetry and the draw-call pass (item 41, perf-telemetry, 2026-11-19)
- **Perf report for testers** (`game/scripts/perf_telemetry.gd`, autoload `PerfTelemetry`): Debug > Performance > *Perf overlay* (live fps p50 / p5 of the last 120 frames, draws, quality) and *Copy perf report* (clipboard text: version, user agent, GPU, pixel ratio, screen / canvas, cores, memory class, phone parts, quality and its changes, load times from page open, fps p50 / p5 overall and per screen / venue area, spikes > 50 / > 100 ms, draws / objects / primitives, video MB). `?perf=1` opens the overlay at start. Nothing is sent; a server beacon waits for hub card `telemetry-beacon`.
- **Auto quality** (`game/scripts/perf_quality.gd`): full / lighter (3D 0.75) / lowest (also no key-light shadow); in the venue, a 6 s window with a median under 24 fps steps down one level, never up; a hand pick (overlay *Quality*) turns auto off. `PerfTelemetry.AUTO` switches it off.
- **Batching at load** (`game/scripts/venue_batch.gd`, same pixels): each patron's 10 skinned parts become one surface (`merge_figure`, from `venue_patron_figure.gd` when the look has `merge`); the venue's static shadow casters become shadow-only proxies per group and per cut-away piece (`shadow_proxies`, from `venue.gd`). `merge_static` (per-cell static merge) exists but is off (`MERGE_STATIC`): it shifts some corridor wall lighting.
- **Measuring:** `Godot --path game --fixed-fps 30 -s tools/perf_views.gd -- --win 720x1560 --phone --shots <dir> [--nobatch] [--ablate base,patrons,anim,shadow,omni,msaa] [--quality 0..2] [--areas A,B]` on the hidden desktop: one line per camera area (wall, render CPU / GPU ms, draws, objects, primitives) and a PNG per area; `--nobatch` is the before. `tools/perf_scan.gd` (headless) counts meshes, surfaces, materials, casters per venue group; `-- --figure <preset>` shows one preset's parts and its merge.
