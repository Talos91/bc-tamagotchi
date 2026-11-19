# Role note: 🎮 Q7 Shake & Serve (2026-11-19)

Job Q7 of the minigame quality pass (`docs/design/11-minigame-quality.md` §1.2, §2.3, §3, §4.1, §6). Load id
2026-11-19-rules-powers-black-cabin-bd8297. Worktree `C:/Users/itisf/bc-wt/q7-shake-serve`, branch `wk/q7-shake-serve`
(never pushed; the Verifier pushes the SHA). Hub card `q7-shake-serve-review`.

## State now
- `shake_serve.gd` draws from the look B sprites (`game/assets/minigames/shake_serve/`, sprites.json read at start;
  flat drawing only as a fallback), on a 720×1280 field fitted to the play area (backdrop covers the rest).
- Bottle mixing: a right bottle lifts off the shelf, flies to the shaker, tips and pours a coloured stream (0.45 s);
  its ghost stays on the shelf. Recipe chips show the mix with small bottle sprites. Each pour pops the real bottle
  name (spirits: Pour Perfect's featured menu bottle per family); shelf labels use the short family name.
- Levels rise through the run, one per order (Daniele: "difficulty levels (more ingredients)"):
  1 Easy pour 2 bottles, 4 nods 0.60 s · 2 House mix 3 bottles, 4 nods 0.55 s · 3 Nam's special 4 bottles, shelf
  restocked in a nightly seeded order, 6 nods 0.50 s. Relaxed: beat window 0.33 s, recipe shown +1 s.
- 19 mixes (5 / 8 / 6). Score formula, tiers, action, bonus and try pool unchanged; order score now averages any
  number of nods.
- Animation: Nam bobs, nods on each beat (frame 1), smiles on a right bottle / good serve, frowns on a wrong bottle
  (new frames 2, 3 from the generator); shaker swings frames 0-1-2-3-2-1 after a tap; glass slides down the bar.
- §2.3 beats via `mg_fx`: pour = squash/flash/spark/real-bottle-name pop/tick; wrong = shelf rattle, red edge, small shake,
  "Wrong bottle", double haptic; on-beat shake = splash sparks, ring flare, CLEAN combo, "On the nod"; serve = "+pts",
  sparks, confetti + hit-stop on perfect; level change = banner, flare, "Shelf restocked!" on level 3.
- §4.1 via `mg_rivals.gd` like Neon Moth: regular to beat top right, "Past X!" pop, result rival + board lines.
  No ghost (not a race; Rivals.record gets `{}`).
- `test_shake_serve` 198 checks (guard: fails below 120). `tests/capture_q7_shake_serve.gd` + 16 captures in
  `docs/art/screens/q7-shake-serve/`.

## Gotchas
- `SPIRITS + MIXERS` is a folded constant: returning it from `shelf()` shared one array, so a test's `sort()` or the
  restock shuffle changed the shelf for everyone. `shelf()` now builds a fresh array. Compare arrays with `str()`.
- Juice must not be skipped off-tree: in `SceneTree._initialize` nodes are not inside the tree yet, but `fx()` works.
- Partial sprite regen: private TEMP, `-- --game shake_serve --no-backdrops --no-blend`; then the packer drops
  `backdrop.png` (no backdrop in the manifest): restore it from git and re-add its sprites.json entry; the README
  writer from main (Q6's `_report_from_disk`) keeps other games. The review .blend does not show Nam's new frames.
- `hd.ps1` copied from another session's scratchpad to `C:/Users/itisf/bc-wt/q7-tmp/`.

## Next
Verifier: verify and push the tip; remove the worktree. Daniele on the card: levels and pace.
