# Report: 🎲 minigame-next — design (B3) and build round — 2026-11-15

## Evidence
- Design: a02298f (10-minigame-next.md + concept pictures), eca06be (note/report v1). Card minigame-next-pick.
- Build (Daniele 2026-11-15 "buiuld them all why not" + owner item 35), local commits, never pushed:
  | Game | SHA | Suites at commit | Card | New suite |
  |---|---|---|---|---|
  | A Coaster Flip | 03177a7 | 21/21 | minigame-coaster-flip-review | test_coaster_flip |
  | D Neon Moth | 8ff310c | 22/22 | minigame-neon-moth-review | test_neon_moth |
  | C Soi Dash | 1354f66 | 23/23 (+ test_soi_dash, test_minigames after a draw-only tweak) | minigame-soi-dash-review | test_soi_dash |
  | B Shake & Serve | ff37dfd | 24/24 | minigame-shake-serve-review | test_shake_serve |
- Suites run headless from `game/` with APPDATA set to an empty temp folder, in the shared tree (which also holds other sessions' uncommitted work, e.g. test_tonight). Captures 540x960 in a windowed Godot on `--screen 1`; not checked on a phone.

## What changed outside the new files
- `rules.gd`: ACTIONS coaster_flip (friends [8,12], cap 20), neon_moth and soi_dash (nightlife [10,20]), shake_serve_friends (friends 5); MINIGAME_TRY_POOL {shake_serve: pour_perfect}.
- `needs.gd`: tries counted per pool. `result_card.gd`: applies `extra.bonus_action`. `venue_session.gd`: registry + rows (tall, cabinet pick, bar). `minigame_lab.gd`: entries, smaller rows. `strings.csv` + one `strings_venue.csv` line.

## Open for Daniele (on the cards)
- Coaster Flip tuning / +2 cheers; Neon Moth payout and a cabinet Nightlife cap; Soi Dash look; Shake & Serve free drink. Cocktail page still pending.

## Notes
- Bible lines (for the release worker): GDD §9 gains Coaster Flip (tall table), Neon Moth and Soi Dash (game cabinet), Shake & Serve built (shares Pour Perfect's tries). Changelog: "Four new minigames: Coaster Flip, Neon Moth, Soi Dash, Shake & Serve."
- Lab overflows with 8 games (dev tool). Profile feedback: rules-powers says "own worktree"; this project uses the shared checkout (PROJECT wins).
