# Report: perf-iphone (🛠️ Opus, 2026-11-10, owner item 29, part of item 16)

## EVIDENCE
- Commits on local main, not pushed, not deployed, no version bump: **c5bdef8** start-screen cut + smoke_start checks + cull captures; **86878a5** context-loss banner (tools/build_web.py, main.gd `_mark_scene`, docs/tech/03-web-build.md, game/tools/perf_probe.gd, tools/web_probe.js); **277611d** look-option captures; plus this report and the role note.
- Load id 2026-11-10-perf-web-black-cabin-ae5ee3 (draft profile `perf-web` via request_agent; no fitting profile existed).
- Hub card **perf-iphone-review** (7 pictures + files), kind now: MSAA off / pixel ratio 2 / 3D 0.75 on phones, rec = retest first.
- Suites 19/19 PASS, my run, headless, each with an empty APPDATA, in a `git archive` export of 86878a5 (shared tree had another worker's half-edited camera_rig.gd, which does not parse):
  smoke_stairs, smoke_tap, smoke_hud, test_needs, test_minigames, smoke_loop, smoke_doors_sit, smoke_start (+3 new checks), test_menu*, smoke_version, test_nightlife, test_seats, test_feel, test_lounge, test_touch, test_string_keys, test_walk, test_debug_tools, test_avatar: PASS. *test_menu first failed only because the export lacked `docs/venue/menu/menu.json` (it reads ../docs); PASS after adding it.
- Not done: no real iPhone; the web numbers come from Chrome in the built-in pane with devicePixelRatio forced to 3. The pane was hidden, so per-frame numbers come from Godot's own monitors (perf_probe.gd, windowed, desktop GPU).

## Main number
The start screen drew **6,858 draw calls a frame** (17 fps on a desktop GPU at 750x1624; inside the venue 522–4,585) because the street camera had the whole venue in its frustum behind the closed door, with all 44 lights visible. On an iPhone at pixel ratio 3 the WebGL context also holds **~245 MB** (textures 148 + MSAA render buffers 68 + buffers 28), 146 MB of it full-screen buffers that scale with the pixel ratio. Probable cause of the loss: that frame load plus memory on a phone GPU; not proven on a device.

## Numbers (before → after)
| what | before | after | how |
|---|---|---|---|
| start screen draw calls / objects | 6,858 / 6,890 | 1,414 / 1,446 | perf_probe, 750x1624 |
| start screen fps (desktop GPU) | 17 | 60 | same |
| visible lights on the start screen | 44 | 12 | same |
| start picture vs before | — | identical (diff = only the pulsing prompt, as the 2-frame noise control) | start-cull-diff*.jpg |
| WebGL textures at dpr 3 | 274, 148.2 MB | unchanged | web_probe, 1125x2436 canvas |
| MSAA render buffers at dpr 3 | 68.0 MB | unchanged (owner card) | same |
| vertex/index buffers | 28.5 MB | unchanged | same |
| total GPU at dpr 2 | 160 MB | — | same, measured |
| wasm heap / JS heap | 115 MB / 30–60 MB | unchanged | same |
| shader programs linked by the title | 121 | 121 (now compiled behind the title for the hidden groups: 3 warm frames) | same |
| inside: Corridor / Floor / Toilets draws | 4,585 / 1,767 / 584 | unchanged | perf_probe --skip-intro |
Owner options (Godot VRAM monitor at 792x1408): MSAA off −17 MB, 3D 0.75 −14 MB; at dpr 3 in WebGL: MSAA off ≈ −68 MB (est.), pixel ratio 2 −85 MB (measured), both ≈ −111 MB (est.).

## Checked and left
- Texture compression: no compressed uploads at all (all textures RGB8/RGBA8 or render targets), so iOS's missing S3TC changes nothing; biggest non-screen textures: shadow map 2048² 8 MB (look), a 2048x1024 RGB8 6 MB, 1200x1120 3.8 MB.
- Character parts glbs already load per body on demand (venue_patron_figure.gd:83): nothing to cut.
- Wasm tee during load: the engine has no flag; left.
- Banner: tested with WEBGL_lose_context in a local build: no alert, banner + Reload (docs/art/screens/perf-iphone/context-lost-banner-375x812.jpg).

## Next (proposed)
1. Daniele redeploys; friend retests; the banner now names memory and screen if it fails.
2. Owner call on the card (MSAA off / pixel ratio 2 on phones): `msaa_3d.web` override + a pixel-ratio cap in the shell.
3. Draw calls inside (item 16, no look change): merge static voxel kit meshes per room in build_venue.gd (the venue is ~2,000+ separate objects; Corridor view 4,585 draws, 21 fps desktop); the door entrance still brings the full venue back.
4. Exit shot / WASTED shot look at the street too: same hiding could apply.

## Gotchas
- Windows clamps a Godot window to the monitor: 1080x1920 came out 1080x1421; use 792x1408.
- A hidden built-in browser pane renders almost no frames: take frame counts from perf_probe.gd.
