# Role note: 🎮 minigame-ramp (rules-powers), 2026-11-20

Daniele 2026-11-20: "all game should get more hard the more you play with clear loss condition ... (3 taps missed)";
"no need to end them at black cabin sign but make them become increasingly harder and faster (but humanly possible
not impossible)". Table approved: "ok yes go" (~22:30, card minigame-ramp-review). Side cards minigame-ramp-rivals
(regulars x1.5) and minigame-ramp-candle (Candle Talk endless) unanswered; recommended options taken per Daniele's
"don t ask for permission". Worker session minigame-ramp-1120, branch wk/minigame-ramp (worktree
C:/Users/itisf/bc-wt/minigame-ramp), load id 2026-11-20-rules-powers-black-cabin-bb5773.

## State now
- Design + table: `docs/design/15-minigame-ramp.md`.
- Base contract `minigame_base.gd`: STRIKES 3, RECORD_FULL 100, `ramp_level`, `end_reason`, `record_points()`,
  `score_of()`, `lose()`, `level_up(n)`; finish() emits points = max(points_for(score), record_points()).
- `mg_rivals.gd` SCALE 1.5 (regulars 5..150). Set to 1.0 if Daniele answers "keep" on minigame-ramp-rivals.
- All 8 games endless with their suites updated (built by 4 helper subagents, reviewed here). Captures:
  `game/tests/capture_ramp.gd` -> `docs/art/screens/minigame-ramp/` (hidden desktop).
- Telemetry: extra carries level / speed / misses; end_reason "lost" from lose(); play_telemetry reads extra.misses.

## Rules added beyond the table (flag to Daniele)
- Pinball: the ball self-launches after 8 s in the lane; ball save once per ball; a ball resting in the lane returns
  to the plunger free (otherwise an idle player never loses).
- Pour Perfect: a spoiled layer resets the fill to its line (no 3 strikes from one spill); relaxed also widens the
  spoil band and the idle wait x1.5; overfill penalty gone (a spill is a strike now).
- Coaster Flip: no idle loss (a player who never flicks only leaves via the pause menu). Candle Talk: no timer in
  turns 1-5 (as the table). Coaster draws at most 30 coasters in the stack.

## Gotchas
- Old capture scripts are stale (not suites): capture_q4 (reached_sign, sign_x: runtime errors), q6 (no door/clock),
  q7 (never ends: needs abandon()), q8 (pour spill loop hangs), q9 (rhythm/candle never end), capture_rivals_hooks
  (pour round never ends). Use capture_ramp.gd for the endless look.
- Unused now, kept for test_strings: mg.*.status keys of the 8 games.

## Done (2026-11-20 night)
- Suites 37/37 headless with empty APPDATA; captures on the hidden desktop; card minigame-ramp-review has the 8
  pictures. Report: handoffs/worker-reports-2026-11/minigame-ramp.md. Tip = the 0.4.2 version bump commit.
