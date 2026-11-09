# Role note: 🛠️ perf-iphone (2026-11-10)

## State now
- Owner item 29 (iPhone "WebGL context lost" at the start screen). Commits c5bdef8 (start screen hides the 12 venue groups the street camera cannot see: 6,858 → 1,414 draws), 86878a5 (context-loss banner with GPU/heap tally, last scene, Reload), 277611d (look captures), plus report and this note. Not pushed; awaits the Verifier. 19/19 suites PASS (my run).
- Hub card perf-iphone-review: MSAA off / pixel ratio 2 / 3D 0.75 on phones; rec = retest first.
- Report: handoffs/worker-reports-2026-11/perf-iphone.md (numbers table).

## Next step
- After the redeploy and retest: if the banner shows, read its numbers (textures, render buffers, canvas, scene). If Daniele picks MSAA off: `rendering/anti_aliasing/quality/msaa_3d.web=0` in project.godot. Pixel ratio 2: in SHELL_GUARD, before the engine script, redefine `window.devicePixelRatio` as `Math.min(2, real)` on touch devices (Godot's canvas policy 2 reads it via GodotDisplayScreen.getPixelRatio).
- Item 16 (entrance lag): merge static kit meshes per room in build_venue.gd (no look change); measure with `game/tools/perf_probe.gd -- --skip-intro`.

## Gotchas
- Measure: `Godot --path game --resolution 750x1624 -s tools/perf_probe.gd` (windowed; `--cull-test`, `--cull-final <dir>`, `--variants <dir> full`). Web: insert tools/web_probe.js before the shell guard in a copied index.html; `?dpr=3`, `bcProbe()`.
- Max window height on this PC ~1421 px; use 792x1408 for portrait captures.
- Shared tree may hold another worker's half-done scripts: measure and test in a `git archive HEAD game docs/venue/menu` export under %LOCALAPPDATA%\bc-perf\src (import first).
- Port 8823 was used for the local server; check `netstat` first.
