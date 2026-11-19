# Role note: 🎮 Q9 Front Row Rhythm + Candle Talk (2026-11-19)

Job Q9 of the minigame quality pass (`docs/design/11-minigame-quality.md` §1.2, §2.3, §3, §4.1, §6). Load id
2026-11-19-rules-powers-black-cabin-2b5b6c. Worktree `C:/Users/itisf/bc-wt/q9-rhythm-candle`, branch
`wk/q9-rhythm-candle` (never pushed; the Verifier pushes the SHA). Hub card `q9-rhythm-candle-review`.
Daniele 2026-11-18: look B voxel sprites, NO sound for now, no practice rounds.

## State now
- `front_row_rhythm.gd`: draws from `game/assets/minigames/front_row_rhythm/` (backdrop, target pads, pucks with
  additive glow, band_jo + band_pete on the beat, clap hands under each pad); flat drawing stays as the fallback when
  art is missing. §2.3 through `mg_fx`: tap squashes the clap, perfect = white flash on the puck + flare + sparks +
  "Perfect" pop + combo, good = small pop + combo, miss = puck dims (frame 2, falls on) and the combo shatters.
  NO shake, NO hit-stop (either breaks the rhythm). §3: no change, the beat maps are the ramp, relaxed stays x1.5.
- `candle_talk.gd`: backdrop, candle, 6-frame flame (flicker 8 fps, gutter frames on a miss) with additive glow, this
  regular's sprite only (listen / smile, squashed on the smile), card.png as a nine-patch on the real topic buttons.
  Choosing a card sends a copy of the card flying (0.4 s, arc) from its button to the flame; on landing: best = flare
  + sparks + smile for the reaction, near = amber flare + embers, miss = flame gutters 0.9 s. NO shake. §3: none, it is
  a chat. Flame size follows the candle light (eased).
- Both use `mg_rivals.gd` exactly as Neon Moth: `Rivals.tonight` in `_on_start`, `Rivals.record` in `_result_extra`
  (no ghost: `{}`), a "to beat / name pts / you N" block in play, "Past <name>!" pop when passed. `rivals_store` var
  for tests. 0 new strings (reused `mg.rivals.*`, `mg.front_row_rhythm.hit_*`, `mg.fx.clean`).
- `test_minigames`: `test_q9_sprites_fx_rivals` (art loads, fx beats, no shake, rival/board in the result).
  `game/tests/capture_q9_rhythm_candle.gd` makes the captures in `docs/art/screens/q9-rhythm-candle/`.

## Gotchas
- `is_inside_tree()` is false for a node added to `root` inside a SceneTree script's `_initialize`; do not guard
  `fx()` beats with it (the tests then see no pops).
- Candle: the card buttons are the real controls (accessible, tap targets unchanged); the flying card is a drawn copy,
  its start rect is read from the button before `_fill_cards(false)` frees them.
- Candle cards box is 84 dp tall now (was 120) so the card nine-patch keeps its aspect; hint moved with it.
- Rhythm HUD (rival block) sits top right under the frame's status line at y 120-194 px; check it on a phone.

## Next
Verifier: verify and push the branch tip; remove the worktree. Daniele on the card: look of both games, the rival
block position, whether the candle regular should sit in front of the flame.
