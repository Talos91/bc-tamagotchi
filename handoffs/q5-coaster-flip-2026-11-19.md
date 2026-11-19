# Role note: 🎮 Q5 Coaster Flip (2026-11-19)

Job Q5 of the minigame quality pass (`docs/design/11-minigame-quality.md` §1.2, §2.3, §3, §4.1, §6). Load id
2026-11-19-rules-powers-black-cabin-5d7b68. Worktree `C:/Users/itisf/bc-wt/q5-coaster-flip`, branch
`wk/q5-coaster-flip` (never pushed; the Verifier pushes the SHA). Hub card `q5-coaster-flip-review`.

## State now
- `coaster_flip.gd` reworked for clarity (Daniele 2026-11-18: "very unclear"): straight vertical flip from the
  stack into the ring above it; a swipe coach (animated finger + arrow) over the stack for the first two flips; the
  ring says CATCH HERE until the first catch; a **closing ring** shrinks onto the catch ring and meets it exactly at
  the top of the arc (the timing cue); a tap where a swipe is wanted pops "Swipe up!"; every drop says why ("Too
  early!" / "Too late!" + a coach line); a thin clock bar; drops left as coaster icons.
- Voxel sprites from `game/assets/minigames/coaster_flip/` (coaster spin 8 frames, ring lit/dim + additive glow,
  table top + leg, backdrop), the table's regular (config.regular) behind the table (cheers on catches), tonight's
  rival head in the HUD. Only those two regular sheets load (README memory rule). Flat drawing is a fallback only.
- §2.3 beats via `mg_fx`: swipe squash + puff + motion trail; ring pulse when it lights; catch hit-stop, +1, sparks,
  combo, confetti every 5; stack lands with a squash (clack); drop: coasters scatter (own sim), shake, red edge,
  combo break, early/late pop; passing the rival: their head cheers + "Past X!".
- §3 ramp: as built + from catch 6 the ring drifts (±90 px sideways, 110 up / 70 down) before each flip; flight time
  follows the ring height (`flight_for(rise)`, free fall), so the top of the arc comes earlier or later.
- §4.1 via `mg_rivals.gd` exactly as Neon Moth (tonight(), record(), rival + board in result extra). Ghost = your
  best stack tonight drawn faint at the left of the table (`{stack}`). Old `TO_BEAT` table removed; result extra
  keeps `regular` (hearts for the table's regular, unchanged).
- Catch rule: 0.3.1 one-glow-per-flight kept, and extended to relaxed: `catch_window()` = in the ring AND within a
  quarter turn of the apex (relaxed at run 9 used to light 3x a flight). Normal play unchanged.
- Payouts and score formula unchanged (Friends 8-12, cap 20).

## Gotchas
- Dictionary `:=` inference fails: type the vars. Lambdas copy locals (capture uses `result.merge`).
- The suite guards `checks >= 100` (a compile error otherwise prints PASS with 0 checks).
- Calibration bots aim at the apex with Gaussian jitter: sharp σ20 ms 1.00, average σ60 ms 0.80, sloppy σ110 ms
  0.42; relaxed 1.00 / 0.96 / 0.63.

## Next
- Verifier: verify and push the tip; remove this worktree.
- Daniele on the card: is it clear now; rival = tonight's next rung (as Neon Moth) vs the regular at your table.
