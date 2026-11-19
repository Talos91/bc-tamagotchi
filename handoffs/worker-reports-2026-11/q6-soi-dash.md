# 🎮 q6-soi-dash: report (2026-11-19)

Load id 2026-11-19-rules-powers-black-cabin-ca857b. Branch `wk/q6-soi-dash` (local, not pushed), rebased on origin/main 247a19d.

## Evidence
- Suites headless, empty APPDATA, worktree after import: 25 of 26 pass; `test_feel` fails only the known buffer walk
  (Tag_mali, pre-existing). `test_soi_dash` 123/0 (new: ramp, movers, sprites + budget, relaxed, beats, sprite
  bounds), `test_minigames` 2128/0, `test_mg_fx` 122/0, `test_string_keys` pass.
- Captures (hidden desktop via hd.ps1, foreground never Godot): `docs/art/screens/q6-soi-dash/` (6 portrait 1080x1920 +
  6 landscape 1920x1080), script `game/tests/capture_q6_soi_dash.gd`. Sprite sheet `docs/art/screens/minigame-sprites/soi_dash.png`.
- Hub card `q6-soi-dash-review` (7 images, files list).
- Note: one full-suite run overlapped another session's Godot for its first suite (my wait check fired late); the
  final run started on a free machine.

## What changed
`soi_dash.gd`: sprites (road tile strips, lane dashes, kerbs, shophouses + additive glow, backdrop parallax, door);
kinds TUK, STRAY, LIZARD added; §2.3 beats (dash streak, hop dust + squash, note +1 / flare / NOTES combo, bump
shake + edge + clock flash + "−2 s", door swing + flare + confetti); §3 ramp (gap 1.9→1.2, pairs + tuk from 10 s, dogs
15 s, lizards 20 s, tighter last third); relaxed (+0.4 gap, same rows, movers settle 0.5 earlier, tuk rush 1.3).
Result extra adds `best_combo`, `relaxed`. Payouts and tiers unchanged. Strings: how_to updated, +2 rows
(`mg.soi_dash.combo`, `mg.soi_dash.bump`, TH machine draft). Generator: `soi_dog_trot`, `tuk_tuk_front`; packer README merge.

## Bible / changelog lines
- Bible: "Soi Dash street life: tuk-tuks drive at you (dodge), stray dogs trot and monitor lizards crawl across (hop);
  a mover is in its lane ~1 s before you reach it; warm-up 10 s, then rows tighten 1.9→1.2."
- Changelog: "Soi Dash: voxel street, tuk-tuks, stray dogs, monitor lizards, food carts; juice on every action; difficulty ramp."

## Open
Competition hook (TODO in `_result_extra`, Q4 mg_rivals). Runner = default avatar (own avatar needs a live 3D render;
option on the card). Not checked on a phone. Texture budget 3.94/4 MB.
