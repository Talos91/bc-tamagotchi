# Report: perf-iphone-2 (🛠️ Opus, 2026-11-10, owner item 33)

## EVIDENCE
- Commits on local main, not pushed, not deployed, no version bump: **547ac82** seam textures shared (`game/scripts/seam_share.gd`, hooks in main.gd + venue_patron_figure.gd, smoke_start +2 checks); **7ae23b6** `rendering/gl_compatibility/item_buffer_size=4096`; **3c8d4bc** phone graphics (`game/scripts/phone_graphics.gd`, shell in tools/build_web.py, creator preview, street sign 1024 under the cap, tools/web_probe.js, docs/tech/03-web-build.md §GPU memory on phones, smoke_start +1 check); plus captures, this report, role note.
- Load id 2026-11-10-researcher-black-cabin-3e694d (`load_agent("perf-web")` returned the researcher profile; perf-web is still only a draft).
- Suites **19/19 PASS**, my run, headless, each with its own empty APPDATA, in a `git archive` export of 3c8d4bc (imported twice): smoke_stairs, smoke_tap, smoke_hud, test_needs, test_minigames, smoke_loop, smoke_doors_sit, smoke_start (+3 checks), test_menu, smoke_version, test_nightlife, test_seats, test_feel, test_lounge, test_touch, test_string_keys, test_walk, test_debug_tools, test_avatar.
- Hub card **perf-iphone-review** rewritten for item 33 (v2; 2 new pictures + files): keep cap + MSAA off, rec; 3D 0.75 optional.
- Measured in Chrome (built-in pane) on local web builds at 375x812 CSS with devicePixelRatio forced to 3 (canvas 1125x2436), `?ios=1` (no S3TC); the probe counts LA8 font atlases at 4 B. **Not on an iPhone.** Check: the "before" build at start:walk read 282 textures / 161.5 MB and 68 MB render buffers; scaled to the friend's 1170x1995 canvas that is ~149 MB / ~58 MB, his banner said 149.6 / 57.9.

## MB per category (venue, after the door pull-back; MB as WebGL allocations)
| category | before 4a22dd5 | no-look cuts (547ac82+7ae23b6), phone off | + phone graphics, all 3 parts |
|---|---|---|---|
| screen render targets (2× RGBA16F, 2× depth, RGBA8 back buffer, glow, shadow 8) | 88.1 | 88.1 | 36.2 |
| seam textures (137 → 2, 256² RGB8+mips) | 34.3 | 0.5 | 0.5 |
| font atlases (LA8 at 4 B) | 22–34 | same | 13–19 |
| street sign / corridor neon / portraits ×10 | 6.0 / 3.9 / 3.7 | same | 1.5 / 3.9 / 3.7 |
| **textures total** | **167.5** (284) | **134.0** (150) | **61.0** lobby, 66.0 lounge |
| MSAA render buffers | 68.0 | 68.0 | 2.3 |
| GL buffers (canvas item buffers 2 MB → 0.5 MB each) | 44.9 | 61 → **14** | 14.2 |
| **WebGL total** | **280.4** (lobby), 312 creator | ~216 lobby (seam run 263 − 47 buffers), ~249 creator | **77.4** lobby, **82.5** lounge, 88.8 creator |
Phone parts measured one by one (before the buffer cut, lobby): ratio cap only 150.9 (tex 69.7); cap + MSAA off 108.7 (tex 69.7); all three 92.9 at the pull (tex 62.0). With the buffer cut, cap + MSAA off is ~86 lobby, ~90 lounge (tex ~68 / ~73), **estimated from the parts, not measured**.

**Default shipped: cap + MSAA off** (Daniele: "only as many as the budget needs"): the total is well under 120 MB, but textures stay above 60 MB in the venue (font atlases and the screen targets). 3D at 0.75 takes ~7 MB more off and gets textures to 61–66 MB; it is one word in PHONE_PARTS (`tools/build_web.py`) or `?pg=dpr,msaa,scale` to try. The 60 MB texture target is not met by any set in the lounge.

## Biggest textures, before (venue lobby, by size class; RT = render target)
1–2 RT 1125x2436 RGBA16F ×2 41.8 (3D colour, 2D HDR) · 3 seams ×137 34.3 (the 164 `*_bc_seam[2].png`) · 4–5 RT 1125x2436 depth24 ×2 20.9 · 6 fonts 512² ×18 18.0 · 7 fonts 1024² ×3–4 12–16 (Lato ×3, Kristi) · 8 RT 1125x2436 RGBA8 10.5 (Emscripten back buffer) · 9 RT shadow 2048² 8.0 · 10 street_sign.png 2048x1024 6.0 · 11 RT glow 562x1218 5.2 · 12 corridor_neon.png 1200x1120 3.9 · 13 portraits 320x400 ×10 3.7 · 14 RT glow 281x609 1.3 · 15 patron swatch 320x320 0.4 · 16 160x160 ×4 0.3 · 17 347x240 0.3 · 18 RT 140x304 0.3 · 19 256x1 RGBA32F ×74 0.3 (light/shader data) · 20 800x6 0.02.

## Checked and left
- ETC2/ASTC: `import_etc2_astc=true` already; every texture is Lossless (mode 0) so nothing is VRAM-compressed on any platform; switching to VRAM would change the look (block artefacts on 1 px seams) and the dedupe made it moot.
- Mipmaps: only the seams have them (they are minified); others have none.
- Venue instanced once: textures 282 → 283 → 284 across walk / pull / lobby; no second venue.
- Character parts libraries already load one body at a time (perf-iphone).
- **The pull-back frame: 7,300–8,400 draw calls** (all venue groups on again, 44 lights). Memory at the pull was *below* the creator's peak (279 vs 312 MB, before), and the friend got through the creator, so the frame itself may be what the phone gives up on. Next job if the retest still fails: item 16 mesh merge per room, or keep the culled groups hidden until the pull ends.

## Captures (portrait, `docs/art/screens/perf-iphone-2/`)
`before-`, `after-`, `phone-` × `01-start`, `02-creator`, `03-bar`, `04-lounge` (1080x1920, windowed Godot, `game/tests/capture_perf_iphone2.gd`, settled, no walk); `compare-before-after-phone.jpg`, `zoom-bar-after-vs-phone.jpg`. **No visible change from the two invisible cuts:** before vs after mean diff 0.17 / 0.68 / 0.44 / 0.75, a rerun of the same build 0.00 / 0.67 / 0.33 / 0.67 (patrons, flicker); the start screen's only differing box is the version label (793–1058, 1859–1886). Phone column: MSAA off is real, the ratio cap is approximated by a 2/3 rescale; mean diff 0.8–1.9, 1–2.4 % of pixels (softer edges). The in-browser pass could not capture the venue: the built-in pane was hidden and renders no frames then.
