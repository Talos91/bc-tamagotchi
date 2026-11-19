# Role note: 🎮 Q8 Neon Pinball + Pour Perfect (2026-11-19)

Job Q8 of the minigame quality pass. Load id 2026-11-19-rules-powers-black-cabin-c2115a. Worktree
`C:/Users/itisf/bc-wt/q8-pinball-pour`, branch `wk/q8-pinball-pour` (never pushed; the Verifier pushes the SHA).
Hub card `q8-pinball-pour-review`.

## State now
- Built: both games draw from the look B sprites (lazy `load`, flat draw kept as fallback), every section 2.3 beat
  through `mg_fx`, the section 3 "relaxed" additions, capture script `game/tests/capture_q8_pinball_pour.gd`, one
  string (`mg.pour_perfect.spill`). Suites: all pass headless except the known `test_feel` buffer walk (Tag_mali).
- Not in this job: competition. TODO hook: both `_result_extra()` should later carry `{"rival": {...}}` from `mg_rivals.gd`.
- Ramps (section 3 normal column) not done: only the relaxed additions were asked.

## Gotchas
- Pour geometry comes from `_geo()` (sprite inner box from README points); beats and `_draw` both use it.
- Pinball `_layout()` sets `_scale/_origin`; beats call it because they fire inside physics, before any draw.
- Glow halos sit on a child `Glow` control with an additive material (`_draw_glow`).
- hit-stop is real-clock only: `advance(dt)` in tests ignores it.
- `hd.ps1` was not at `map-shots-tools/`; copied from another session's scratchpad.

## Next
Verifier: verify and push the tip; remove the worktree.
