# Role note: 🎲 minigame-next (B3, 0.3.0) — 2026-11-15

## State now
- Design (a02298f) and build round done: four new minigames, each its own local commit (not pushed) and card.
  - A Coaster Flip 03177a7 — tall tables, Friends [8,12] cap 20 — card minigame-coaster-flip-review — suite test_coaster_flip
  - D Neon Moth 8ff310c — lounge game cabinet, Nightlife [10,20] — card minigame-neon-moth-review — suite test_neon_moth
  - C Soi Dash 1354f66 — game cabinet (pick with Neon Moth), Nightlife [10,20] — card minigame-soi-dash-review — suite test_soi_dash
  - B Shake & Serve ff37dfd — bar, pour_perfect Drinks [20,30] + shake_serve_friends +5 at great — card minigame-shake-serve-review — suite test_shake_serve
- 24/24 suites at ff37dfd in the shared tree (empty APPDATA; includes the tonight worker's uncommitted test_tonight).
- Design card minigame-next-pick is superseded by Daniele's "build them all" (DECISIONS 2026-11-15).

## Where things are
- Games `game/scripts/minigames/{coaster_flip,neon_moth,soi_dash,shake_serve}.gd`, scenes `game/scenes/minigames/<id>/`.
- Registry: `venue_session.gd` GAMES / ROW_GAMES and rows for zones `tall`, `cabinet`, `bar`; lab `minigame_lab.gd` GAMES.
- Rules: `rules.gd` ACTIONS (coaster_flip, neon_moth, soi_dash, shake_serve_friends) and MINIGAME_TRY_POOL; `needs.gd` try pool; `result_card.gd` generic `extra.bonus_action`.
- Strings: `game/i18n/strings.csv` (mg.<id>.*); one venue line changed (venue.sheet.cabinet.greet). Thai = machine drafts.
- Captures: `game/tests/capture_minigame_next.gd -- <id>` → `docs/art/screens/minigame-next/build-*`.

## Next
- Daniele's answers on the four cards (tuning, cap, cheers bonus, free drink). Cocktail page → replace the house mixes in shake_serve RECIPES.
- PROJECT.md Tests: add the four suites (orchestrator).

## Gotchas
- test_string_keys walks every script: keep unbuilt games' files out of the tree until their commit.
- The minigame lab overflows a 540x960 window with 8 games (dev tool; needs a ScrollContainer).
- One Godot at a time: my runner waits while any Godot process exists; another session's suite runs can hold it 10+ min.
- Coaster Flip's +2 cheers for beating the regular was left out (needs a hook outside the game).
