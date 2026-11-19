# Role note: 🎮 rivals-hooks (2026-11-19)

Load id 2026-11-19-rules-powers-black-cabin-3876d8. Worktree `C:/Users/itisf/bc-wt/rivals-hooks`, branch `wk/rivals-hooks`
(not pushed; the Verifier pushes the SHA). Hub card `rivals-hooks-review`.

## State now
`neon_pinball.gd`, `pour_perfect.gd`, `soi_dash.gd` use `mg_rivals.gd` like Neon Moth / Coaster Flip: `Rivals.tonight` in
`_on_start` (rival, ghost), a corner HUD (to beat / name + points / you N), a "Past X!" pop when live points pass the
regular, `Rivals.record` once in `_result_extra` -> `{"rival", "board"}`. Payouts unchanged. Each game has `rivals_store`
(tests) and `live_points()`.
- Pinball: no ghost (physics, nothing to replay). Passing is checked after each advance.
- Pour: ghost = `{levels: [3 fills]}` drawn as faint cyan ticks on the glass; passing checked when a layer locks.
- Soi Dash: ghost = `{seed, relaxed, step 0.25, lanes: [...]}` (~160 ints), shown only on the same seed and timing mode.
- 2 strings: `mg.pour_perfect.ghost`, `mg.soi_dash.ghost` (EN 40 chars max; TH machine drafts).
- Tests: `test_minigames` new `[rivals]` block (Store class, pinball + pour), `test_soi_dash` `test_rivals` (+ guard >= 120 checks).
- Capture: `tests/capture_rivals_hooks.gd`, 18 PNG in `docs/art/screens/rivals-hooks/`.

## Gotchas
- Pour capture bot must wait >= 0.8 s (SETTLE) after a release before the next press, else the press is ignored.
- Two backgrounded runner scripts raced on APPDATA and logs; start ONE and wait.
- `hd.ps1` is not in map-shots-tools; copied from another worker's scratchpad (any `*/scratchpad/hd.ps1`).

## Next
Verifier: verify and push the tip; then remove the worktree. Daniele: answer the card.
