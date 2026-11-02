# Web build (phone browser)

Job 0 (BACKLOG A8): the game in a phone browser from a Vercel URL.

## One command
```
python tools/build_web.py            # stamp, import, export, hash, vercel.json  -> web/
python tools/build_web.py --deploy   # same, then `vercel link` + `vercel deploy --prod` (project bc-tamagotchi)
```
`web/` is gitignored output. A clean state (no `web/`, no `game/.godot`) builds in about 2 minutes (first import dominates).

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
Needs a Vercel login on this machine: `npx vercel login` once (Daniele's account), then `--deploy`. `vercel deploy --temporary` (no login) was tried 2026-11-02 and the anonymous `*.tmp.now` URL answers 403 to everything, so it is not a route.

## Size
pck 15.7 MB, wasm 37.7 MB, js 0.3 MB; Vercel serves them brotli-compressed.

## Testing locally
`python -m http.server 8791` inside `web/`, open `http://localhost:8791/index.html`. A hidden browser pane throttles `requestAnimationFrame` to about 1 fps, so frame rates only count on a visible browser or a real phone.
