# Kit v4 additions (🧱 kit session, 2026-11-01) — for the venue-rebuild session

All 30 names from the brief are exported and in `game/assets/kit/manifest.json` (90 objects now); no renames.
Full state and footprints: `handoffs/kit-additions-2026-11-01.md`. Sheet: `docs/art/screens/kit/kit-v4-additions.png`.

Things that matter when placing them:
- New GLB folders `buffer/`, `raised/`, `smoke/` (zone names); read the `path` from the manifest, nothing is hardcoded.
- Doors (`red_door`, `emergency_door` 1.75 m wide, `sticker_door`, `staff_door`) are frame + leaf, 0.15 m deep,
  room side at Godot +Z, handle at -X. Leave a gap in the wall for them; the EXIT sign is part of `emergency_door`
  (total height 2.4 m).
- `raised_edge_neon` is only the 1 m riser face (0.2 m deep, 0.15 m high) with the neon under it; the platform top
  is yours. Its front (neon side) is Godot +Z.
- `couch_long` back at Godot -Z, tiles along X; `shelf_wall_tile` is a wall object (origin bottom centre,
  `mount_height_m` 1.1) and tiles along X and up.
- `cashier_counter` 1.1 × 0.65 m: its -Z (Blender +y) side joins `bar_counter`; stone top and glass rail stand
  1 voxel proud on the other three sides, so leave 0.05 m to the neighbouring counter segments' fronts or let it overlap.
- `lightbox_bc` (0.65 m high incl. skull) stands on `wine_fridge` (1.0 m): lift it by the fridge's `height_m`.
- `tall_stool` is 0.35 m across: two per tall table, as the legend says. `tiny_table` takes two `drum_stool`.
- `outdoor_tree_bare` is 3.1 m, 3.1k tris: one or two instances outside the glass, not more.
- `pinball_machine` long axis is depth (1.45 m), player at +Z; `game_cabinet_bc` player at +Z.
- Existing GLBs are byte-identical (deterministic run), so nothing already placed changes.
- `git pull --rebase` refused in the shared checkout (your unstaged `game/tools/plan_view.py` and untracked files), so
  my three commits (f9380b5, 0fc2320, + LOG/handoff) are local on `main` until the orchestrator pushes.
