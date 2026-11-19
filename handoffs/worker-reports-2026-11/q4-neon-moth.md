# Worker report: 🎮 Q4 Neon Moth (2026-11-19)

Load id 2026-11-19-rules-powers-black-cabin-95f676. Branch `wk/q4-neon-moth` in `C:/Users/itisf/bc-wt/q4-neon-moth`,
rebased on origin/main 50cf6e7; tip = the commit that adds this report (SHA in the final message). Not pushed.
Hub card `q4-neon-moth-review` (9 pictures + files).

## Evidence
- Suites, headless, empty APPDATA, rebased tip, after `--import`: 25 of 26 PASS. `test_feel` FAIL 1: the known
  pre-existing buffer-walk line (`hidden by Zones/Tag_mali: 8`), not touched. `test_neon_moth` 104 checks, 0 failed;
  `test_minigames` PASS (after shortening the TH `mg.result.board` to 26 clusters); `test_string_keys` PASS.
- Captures (hidden desktop via hd.ps1, foreground probe: godot-owned 0): `docs/art/screens/q4-neon-moth/`,
  portrait 1080×1920 + landscape 1920×1080: 1-intro, 2-play, 3-singe, 4-sign-ahead, 5-sign-reached, 6-result
  (result shows "You beat Jules (90)" and "#1 of 5 tonight"). Script `game/tests/capture_q4_neon_moth.gd`.
- Difficulty calibration (8 nights, bot with reaction delay + tap jitter): sharp 0.98, average 0.61 (tiers good 5,
  great 1, perfect 2), sloppy 0.30; relaxed 0.92 / 0.79 / 0.46. Pinned in `test_average_and_relaxed`.

## What changed (own files)
- `game/scripts/minigames/neon_moth.gd`: voxel sprites (sprites.json), glow layer (additive), §2.3 beats via mg_fx,
  §3 ramp (20 gates, 390->290 spacing, 200->250 px/s, gap 340->262 then 250 x3, step 200->320, bobbing gaps from
  gate 7, relaxed +60 / 225 cap), rival HUD, ghost record and draw, landscape draws the whole play area.
- New `game/scripts/minigames/mg_rivals.gd`: the shared offline competition API (doc block at the top; summary in
  `handoffs/q4-neon-moth-2026-11-19.md`).
- `game/scripts/minigames/result_card.gd`: small documented hook, the `board` competition line.
- `game/i18n/strings.csv`: 6 keys (`mg.rivals.you|to_beat|you_now|passed|ghost`, `mg.result.board`), TH drafts.
- `game/tests/test_neon_moth.gd`: ramp, average/relaxed, art + juice, rivals API, rivals in game, check-count guard.

## Bible / changelog lines (for the release worker)
- Bible (Neon Moth): 20 gates, 2-3 on screen, speed and tightness ramp through the flight, bobbing gaps in the second
  half; tonight's regular to beat in play, your best flight tonight as a ghost, board place on the result.
- Changelog: "Neon Moth: voxel look, faster flight with more gates on screen, tonight's regulars to beat, your ghost
  moth, and your place on tonight's board."

## Open / for Daniele (on the card)
- Accept the template before Q5-Q9 copy it. Perfect now needs 17 of 20 gates + sign (score formula unchanged).
- Not checked on a real phone. TH strings are machine drafts.
- Follow-ups: other suites can also exit "PASS" when their game script fails to compile (no check-count guard);
  Coaster Flip's own `TO_BEAT` vs `Rivals.to_beat` is Q5's call; `capture_q1_juice.gd` still uses `gap_y` (works).
- Profile note: `rules-powers` fit; the brief's "load_agent first" and exit ritual worked as written.
