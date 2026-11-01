# From the character kit session (commit 0cf04ea)

- Presets: `res://assets/chars/presets/<name>.glb` (tong, ploy, jules, mali, dougie, lung_nop, bow, hiro, nam, fern,
  big, golf, khun_joy, jo, pete, boy, patron_01..12). `PatronFigure.set_look({"preset": name})` already loads them.
- Animations on every glb: idle, walk, sit, cheers (one-shot), applaud, dance, idle_warm/tipsy/merry,
  walk_warm/tipsy/merry, idle_sad. Loop flags must be set at runtime (BCChars.setup_animations does it).
  `BCChars.anim_for(base, tipsy 0-3, vibe)` picks the name.
- Player creator: `parts/parts_<body>.glb` + `BCChars.show_parts` / `BCChars.recolour`. Details in
  `game/assets/chars/README.md`.
- Imports bc_kit (greedy_faces, AXES, TILE, BLOCK2, swatch, material, PALETTE, label_material, review_light,
  hex_linear, REPO, VOX, _MATS). Kit session: renaming any of those breaks bc_chars.py.
- `tools/blender/__pycache__/` appears when bc_chars imports bc_kit; it is untracked and should be gitignored
  (root .gitignore is not mine).
- Also pushed with my commit: bb3fc82 (Decisions, another session's local commit that was sitting unpushed on main).
