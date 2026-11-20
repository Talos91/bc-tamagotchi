# Role note: 🖼️ perf-iphone-1120 (2026-11-20, mobile optimisation round, iPhone first)

## State now
- Branch `wk/perf-iphone` in `C:/Users/itisf/bc-wt/perf-iphone` on top of the venue entrance build (4e9dbc8; rebased on origin/main once the Verifier pushed it). Not pushed: the Verifier pushes. Report `handoffs/worker-reports-2026-11/perf-iphone-1120.md`; card `perf-iphone-1120-review` (order 411).
- Shipped, no look change: static merge on (`venue_batch.gd` `merge_static`, light-exact chunks, sliced at load), more shadow proxies. Draws -17 to -53 % per view (Corridor 3,244 -> 1,533); GPU buffers +7.7 MB.
- Test script for the friend: `docs/tech/iphone-test-script.md`.

## Next step
- Daniele answers the card; the friend runs the script on the next deploy and sends the perf report.
- If the iPhone still struggles: the look trade-offs listed in the report (shadow map 1024 on phones, pixel ratio 1.5, mural size, MSDF fonts) go to Daniele one card each, with captures.
- No-look-change follow-ups: custom wasm template (fewer engine modules), minigame art in a second pck, wiring the telemetry client hook so `perf_reports` gets rows.

## Gotchas
- The engine pairs omni/spot lights by box (`Light3D.get_aabb()`, a cube of the range), max 8 per object: any merge must keep each chunk at <= 8 paired lights or lighting shifts.
- Same-frame captures need a fresh APPDATA per run (a saved avatar changes the player's look) and no ablations in the same run (they shift the crowd's timing). `pi-tools/views.ps1`, `probe.ps1`, `cmp.py`, `sheet.py` in `C:/Users/itisf/bc-wt/pi-tools/`.
- A local build stamps `game/build_info.json` (gitignored): delete it before captures or the version label differs.
- `git worktree add` on the Drive mount can leave `.git/worktrees/<name>/index.lock` instead of `index`: status then shows everything deleted. With no git process running, rename the lock.
- The hidden browser pane renders ~1 fps and its phone size resets when the pane width changes: use it for memory and load times only.
