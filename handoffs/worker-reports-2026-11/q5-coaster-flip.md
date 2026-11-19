# Worker report: 🎮 Q5 Coaster Flip (2026-11-19)

Load id 2026-11-19-rules-powers-black-cabin-5d7b68. Branch `wk/q5-coaster-flip` in `C:/Users/itisf/bc-wt/q5-coaster-flip`,
rebased on origin/main 247a19d (contains 14f989a; only STATE/LOG changed since); tip = the commit that adds this
report (SHA in the final message). Not pushed. Hub cards `q5-coaster-flip-review` (10 pictures + files) and
`q5-coaster-flip-rival` (one design question).

## Evidence
- Suites, headless, empty APPDATA (`C:/Users/itisf/bc-wt/q5-appdata`), after `--import`: 26 of 27 PASS, 0 SCRIPT
  ERROR in any log. `test_feel` FAIL 1: the known pre-existing buffer-walk line (`hidden by Zones/Tag_mali: 8`), not
  touched. `test_coaster_flip` 147 checks, 0 failed (now fails below 100 checks). After the rebase and the last tweak:
  test_coaster_flip, test_string_keys, test_minigames, test_needs, smoke_loop PASS again.
- Captures (hidden desktop via hd.ps1, foreground probe godot-owned 0): `docs/art/screens/q5-coaster-flip/`,
  portrait 1080×1920 + landscape 1920×1080: 1-first-seconds, 2-rising, 3-rings-meet, 4-catch, 5-drop-early,
  6-drift, 7-result (result: "You beat Tong (59)", "#2 of 5 tonight", hearts with Jules). Script
  `game/tests/capture_q5_coaster_flip.gd`.
- Calibration (8 nights, bot aiming at the apex with Gaussian jitter): sharp σ20 ms 1.00, average σ60 ms 0.80,
  sloppy σ110 ms 0.42; relaxed 1.00 / 0.96 / 0.63. Pinned in `test_average_and_relaxed` (ordering + relaxed ≥ normal).

## What changed (own files only)
- `game/scripts/minigames/coaster_flip.gd`: clarity (swipe coach, CATCH HERE, closing-ring timing cue, nudge,
  early/late on every drop, clock bar), voxel sprites + glow layer, §2.3 beats via mg_fx, §3 drift from catch 6,
  §4.1 via mg_rivals (rival, ghost stack, board line). `catch_window()` keeps one glow per flight in relaxed too
  (it lit 3x at run 9). Old `TO_BEAT` removed; result extra keeps `regular` for hearts. Payouts unchanged.
- `game/tests/test_coaster_flip.gd`: clarity, drift ramp, players/relaxed, art + juice, rivals in game, guard.
- `game/i18n/strings.csv`: 8 new `mg.coaster_flip.*` keys (goal, zone, nudge, early, late, early_hint, late_hint,
  ghost), 3 rewritten (how_to, hint_flick, hint_catch); TH machine drafts. `to_beat`, `house`, `beat`,
  `dropped` are now unused (left in place).
- No change to mg_fx.gd, mg_rivals.gd, result_card.gd, other games or PROJECT.md. No API change needed.

## Bible / changelog lines (for the release worker)
- Bible (Coaster Flip): swipe up to flip the stack into the ring; a closing ring meets the catch ring at the top of
  the arc, tap then; misses say too early / too late; from catch 6 the ring drifts; tonight's regular to beat,
  your best stack tonight as a ghost, board place on the result.
- Changelog: "Coaster Flip: clearer (shows when to tap and why you missed), voxel look, tonight's regulars to beat."

## Open / for Daniele (on the cards)
- Is it clear now (review card). Who to beat at a hosted table (rival card; built: tonight's next rung).
- Not checked on a real phone. TH strings machine drafts. Landscape draws the 600×1000 field centred (as Neon Moth).
- The regular's head sits behind the table's candle block (table_top sprite); cosmetic.
- Profile note: `rules-powers` fit.
