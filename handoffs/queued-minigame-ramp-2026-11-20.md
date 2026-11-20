# Queued job: minigame endless ramp + loss conditions (start when a worker slot frees)

Owner words (Daniele, 2026-11-20, verbatim):
"all game should get more hard the more you play with clear loss condition for example the clap game should have double taps and 2 taps at the same time and after a few lost taps a loss (3 taps missed)"
"since are all records game no need to end them at black cabin sing but make them become increasingly harder and faster (but humanly possible not impossible) so become real competition"

Role: rules-powers (🎮), Opus. Worktree `wk/minigame-ramp` from origin/main. Godot local exe only.
Scope: all 8 minigames in `game/scripts/minigames/` (Coaster Flip, Shake & Serve, Soi Dash, Neon Moth, Neon Pinball, Pour Perfect, Front Row Rhythm = the clap game, Candle Talk).
1. Remove the fixed end at the Black Cabin sign: every game runs until a clear loss condition, score = record for the rivals boards.
2. Difficulty ramps with time/score, faster and denser, capped at a humanly possible ceiling (state each game's cap and why it is playable).
3. Clear loss conditions per game, e.g. Front Row Rhythm: double taps, two simultaneous taps (two lanes), 3 missed taps = loss.
4. Balance numbers in rules or per-game constants; DECISIONS rows; hub card `minigame-ramp-review` with captures; suites test_minigames + per-game suites + all 31.
Rules/balance are Daniele's: give the per-game ramp table on the card for his OK before shipping.
