# Role note: 🛠️ perf-telemetry (2026-11-19, owner item 41)

## State now
- Branch `wk/perf-telemetry` in `C:/Users/itisf/bc-wt/perf-telemetry`, not pushed (the Verifier pushes). Report `handoffs/worker-reports-2026-11/perf-telemetry.md` (numbers, method, SHA). Cards `perf-telemetry-review` (review + auto-quality choice) and `telemetry-beacon` (server question) on the Questions tab.
- Shipped in the branch, no look change: merged patrons (1 surface each, PLAIN_SHADER mirrors StandardMaterial3D) and shadow-only proxies (`game/scripts/venue_batch.gd`). Telemetry overlay + Copy perf report (`perf_telemetry.gd`, Debug > Performance, `?perf=1`). Auto quality ON (`perf_quality.gd`, Daniele to confirm on the card).
- Left off: `merge_static` (per 4 m cell static merge): −8 to −22 % draws in corridor views but shifts some wall lighting (`MERGE_STATIC := false`).

## Next step
- Daniele answers both cards; the friend sends a perf report (Debug > Performance > Copy perf report) from the next deploy.
- If the corridor views still lag on a phone: the ~2,200 static draws there. Options: fix `merge_static`'s lighting shift (per-object light lists: probably a chunk lit by lights its parts never were, or > 8 lights), or cull far static props by distance in the long views.

## Gotchas
- Primitive meshes (BoxMesh, QuadMesh) have no `surface_get_format` / `surface_get_primitive_type` / `get_blend_shape_count`: check `is ArrayMesh` or derive the format from the arrays (`_fmt_of`).
- BaseMaterial3D's generated shader is not reachable from GDScript; PLAIN_SHADER is a hand copy for default materials only (`_plain_textured`). Proof: same-frame captures (`perf_views.gd --fixed-fps 30`, seed 41) before/after differ only in a 10x10 HUD corner.
- On the hidden desktop the window sometimes falls back to vsync mid-run (wall locks at 16.67 ms): rank by draws and render CPU/GPU ms, not wall.
- `hd.ps1` lives in another session's scratchpad (`C:/Users/itisf/AppData/Local/Temp/claude/4d417711ef75e3e3/7ecd422d-.../scratchpad/hd.ps1`); copy it, it captures no stdout (use `--log-file`).
