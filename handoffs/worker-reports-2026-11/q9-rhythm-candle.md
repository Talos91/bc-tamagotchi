# Report: 🎮 Q9 Front Row Rhythm + Candle Talk (2026-11-19)

Load id 2026-11-19-rules-powers-black-cabin-2b5b6c. Branch `wk/q9-rhythm-candle` (worktree `C:/Users/itisf/bc-wt/q9-rhythm-candle`). Hub card `q9-rhythm-candle-review`.

## Evidence
- Suites, headless, empty APPDATA, in the worktree: all 27 in PROJECT Tests pass except `test_feel` (1 failure: buffer walk, Tag_mali hides the player 8 of 147 ticks; pre-existing, not touched). `test_minigames` 2127 checks, 0 failed (non-zero count; includes the new `test_q9_sprites_fx_rivals`).
- Captures on the private hidden desktop (`hd.ps1`, probe: no Godot window ever foreground), portrait 1080x1920 + landscape 1920x1080, both games, results with the regular: `docs/art/screens/q9-rhythm-candle/` (23 PNGs). Not checked on a phone.

## What changed (my files only)
- `front_row_rhythm.gd`: look B sprites (flat drawing kept as fallback), §2.3 beats via `mg_fx` (clap squash, white flash + flare + sparks + combo on perfect, small pop on good, puck dims on a miss, no shake, no hit-stop), `mg_rivals` (tonight / record, HUD block, "Past X!" pop). §3: no ramp (beat maps are the ramp). Payouts unchanged.
- `candle_talk.gd`: look B sprites (only the talking regular loaded), card sprite as a nine-patch on the real buttons (box 84 dp tall), flying card, flame flare / smile / gutter, no shake, `mg_rivals`. §3: none.
- `test_minigames.gd`: one new function. New `tests/capture_q9_rhythm_candle.gd`.
- No new strings. `mg_fx.gd`, `mg_rivals.gd`, `result_card.gd`, PROJECT.md untouched.

## Design-bible line / changelog line (for the release worker)
- Bible: Front Row Rhythm and Candle Talk draw from the look B voxel sprites; every tap, perfect, miss and card answers through the juice kit (no shake in either); both show tonight's regular to beat and a board line.
- Changelog: Front Row Rhythm and Candle Talk get voxel art, feedback and tonight's regulars to beat.

## Open / for Daniele (on the card)
Rival block placement; regular in front of the flame; no ghost for these two (not a replay game).

## Notes for orchestrator / profile
- `hd.ps1` still missing from `map-shots-tools/` (copied from another session's scratchpad). The Artifact asset upload refuses files outside the session's folders: copy captures to the scratchpad first.
- `is_inside_tree()` is false in a SceneTree script's `_initialize`; do not guard fx beats with it.
