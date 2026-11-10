# perf-door report (owner item 16, Daniele 2026-11-11), session load id 2026-11-11-map-builder-black-cabin-d7ba6d

## EVIDENCE
- Commits on local main (not pushed): **da2b6cf** probe modes, **cbedd67** the fix + probe + captures (tip before docs). Report/role note commit follows.
- Suites: **19/19 PASS** from `game/`, headless, empty APPDATA, shared tree at the cbedd67 code (smoke_stairs … test_avatar).
- Card: **perf-door-review** on the Questions tab (2 pictures + 4 files).
- Measured: desktop RTX 5080 laptop, OpenGL Compatibility, window 640x1386, MSAA off (phone graphics), vsync off, `tools/perf_probe.gd --door 2 --phone` (`--old` = before). **Not measured on a phone.** Two Ooze fog_playground windows were open during all timings (Daniele's exception, 2026-11-11).

| stretch (entry 1 / entry 2) | before draws mean / max | after draws mean / max | before GPU ms mean / max | after GPU ms mean / max |
|---|---|---|---|---|
| walk, door open → pull | 6,440 / 6,665 · 6,433 / 6,667 | 1,352 / 1,579 · 1,343 / 1,577 | 29.5 / 37.4 · 30.7 / 38.1 | 6.0 / 9.4 · 6.0 / 9.9 |
| pull-back | 2,972 / 6,016 · 2,991 / 6,014 | 1,978 / 2,855 · 1,982 / 2,857 | 6.2 / 36.3 · 6.6 / 36.3 | 3.1 / 8.3 · 3.1 / 7.9 |
| play (first 45 frames) | 2,538 | 2,538 | 1.6 | 1.6 |

Visible lights at the door 44 → 12. Wall time per frame at the door 43–44 ms → 12–13 ms mean. A first-run baseline also showed a 250 ms frame when the door opened (the groups coming back); none in the after runs. First vs second entry: same numbers both ways (shaders already warmed behind the title, c5bdef8).

## What it was
- `--door-cull groups` (fixed 30 fps, each venue group hidden alone at every 2nd frame, any changed pixel = seen; portrait 19.5:9, 16:9, landscape): only **Lobby, Lounge, Stairs** are seen from the door to the end of the pull; the other 10 groups change 1–5 px only after the camera has risen above the ceiling, as the mesh-less Navigation node does (toggle artifact).
- The draw calls were not the GPU cost: with those 10 groups hidden, draws fell to ~2,260 but GPU stayed ~26 ms; the Lounge off: 25 ms; ceiling layer off: 22 ms. **Patrons off: 1.3 ms.** The ~70 animated figures (crowd, band, staff) are the cost while the entrance camera looks along the venue.

## What changed (`game/scripts/start_screen.gd`)
- `HIDDEN_THROUGH_DOOR`: the 10 unseen groups stay hidden from the door until the pull-back camera passes CEILING_Y (then all come back; also on skip / finish / exit).
- `_cull_figures()`: through the entrance a patron is drawn only while it stands on the floor plan (+1 m) of Lobby / Lounge / Stairs, checked every frame (wanderers show as they step in); ~55 of 73 off; all back at play. `--door-cull figs` (all on, each figure hidden alone, two portrait runs + landscape): every figure changes exactly 1 px at the same late-pull moment, in sight or not = the toggle artifact; none is otherwise seen.
- Proof of no look change: `--door-shots` captures every 3rd frame from door open to play twice in the same paused frame (as drawn now / with everything hidden shown again): worst 2 px portrait 792x1408, 4 px landscape 1408x792, over 60 frames; **0 px** at the five saved moments. `docs/art/screens/perf-door/` (before-/after-*.png, landscape/, compare-before-after-portrait.jpg, -landscape.jpg).

## Left, and why
- Daniele's idea (2026-11-11, in chat): load only the entrance and corridor, the Lounge once the player has control. Measured: the Lounge costs ~1 ms here (GPU 25 ms with it off while patrons on), and it is seen through the doorway (up to 260k px), so hiding it would be a pop-in look change for little gain. Not done; offered as an option on the card.
- (b) per-room mesh merge in build_venue.gd: not needed for the entrance after this; still the route for play views (Corridor 4,585 draws). The patrons are the bigger cost there too: next perf job could cull patrons by room for play views (camera zone sight), measured the same way.
- (d) light budget: no change needed (lights are cut with their groups).
- Windows framebuffer quirk: `root.get_texture().get_size()` reported smaller numbers than the window (581x1033 for 792x1408) but the saved PNGs are full 792x1408; window sizes above are the requested ones.

## Profile note
- `load_agent("perf-web", ...)` resolved to the Researcher profile (no perf-web profile); used the map-builder fallback as briefed. A perf profile would fit this job better.
