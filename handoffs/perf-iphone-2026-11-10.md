# Role note: 🛠️ perf-iphone (2026-11-10; perf-iphone-2 from ~15:00)

## State now
- Item 29 (start screen) done by perf-iphone: c5bdef8 cull, 86878a5 banner (pushed).
- **Item 33 (iPhone loses graphics entering the venue)**, perf-iphone-2 local_f074f47d: three commits on local main, not pushed: **547ac82** seam textures shared (137 → 2 textures, −34 MB, no look change), **7ae23b6** `item_buffer_size=4096` (GL buffers 59 → 14 MB after the creator, no look change), **3c8d4bc** phone graphics on touch phones per DECISIONS 2026-11-10 (pixel ratio cap 2 + MSAA off; 3D 0.75 available, not default). Report `handoffs/worker-reports-2026-11/perf-iphone-2.md`; captures `docs/art/screens/perf-iphone-2/`; card perf-iphone-review.
- Measured only in Chrome (built-in pane, 375x812, devicePixelRatio forced to 3, `?ios=1`); never on an iPhone. The emulation reproduced the friend's banner numbers (282 textures ~150 MB scaled to his canvas).

## Next step
- Verifier on 3c8d4bc, Daniele redeploys, the friend retests (banner now says "phone graphics on (...)").
- If it still fails at start:pull with memory low: the frame itself is the suspect. The door pull-back draws **~7,300–8,400 draw calls a frame** (all venue groups back on, 44 lights); merge static kit meshes per room in build_venue.gd (item 16), or keep the culled groups hidden until the pull ends.
- Not cut, left: font atlases (~13–34 MB as counted, LA8 counted at 4 B), 2048² shadow map 8 MB (look), corridor neon 1200x1120 3.9 MB, ten 320x400 portraits 3.7 MB.

## Gotchas
- `*.import` is gitignored: import settings never reach a clean checkout (the Verifier's). Change textures at run time or in the source files, never in .import.
- The built-in pane renders no frames while hidden; a pane width change leaves Godot's layout wrong until reload. Read the canvas (`toDataURL`, preserveDrawingBuffer is on) rather than the pane screenshot.
- The emulated pane has no coarse pointer: add `?phone=1` (or `?phone=0`) when measuring; `?pg=dpr,msaa,scale` picks parts.
- Measuring kit lives in `%LOCALAPPDATA%\bc-perf2\` (build.py: build a `git archive` copy + inject tools/web_probe.js; recv.py: canvas PNG receiver on :8825; server on :8824).
- Windowed captures: `tests/capture_perf_iphone2.gd` (`--phone` = MSAA off for real, ratio cap approximated by 2/3 rescale).
