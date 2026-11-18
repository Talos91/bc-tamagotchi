# q2-venue-pause: report (2026-11-18)

**Change:** `game/scripts/main.gd` `_cover_venue()`, called from `_sync_block()`: while `frame` (the minigame frame) is
valid, `get_viewport().disable_3d = true` and `$Venue.process_mode = DISABLED` (patron walks, tealight flicker, disco
ball stop). Player, camera rig, Session, Needs and the HUD keep running, so needs decay (real time), positions, camera
and music/timers are unchanged; on close (`frame = null` then `_sync_block`) both are switched back. `minigame_frame.gd`
untouched (fix-031 phone detection intact); Q1 files untouched. New suite `game/tests/test_venue_pause.gd` (in PROJECT.md Tests).

**Measured** (Godot 4.6.1 Compatibility, windowed 450x800 on the private hidden desktop, RTX 5080 laptop GPU, coaster_flip
open, 90 frames in, `RenderingServer.get_rendering_info` in the frame; probe script not committed):

| | draw calls | objects | primitives | video MB |
|---|---|---|---|---|
| before, venue only | 2005 | 2088 | 129313 | 44.4 |
| before, minigame open | 1961 | 2055 | 124184 | 44.9 |
| **after, minigame open** | **40** | **134** | **2166** | 44.9 |
| after, venue restored | 1990 | 2073 | 128485 | 45.0 |

Draw calls -98 %, objects -94 %. **Video memory does not drop** (textures/meshes stay resident; that is the point: no reload on
close). The win is GPU time/battery, not GPU MB. Desktop numbers, not an iPhone: fps is 60 either way on this GPU.

**Evidence:** `test_venue_pause` PASS headless; full suite results in the hub card / final message.
**Not verified:** a real iPhone (frame rate, battery); web build.
