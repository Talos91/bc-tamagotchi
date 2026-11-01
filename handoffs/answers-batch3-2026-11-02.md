# 🖼️ Answers batch 3 in the game: Kristi lettering, dimmed prices, Pour Perfect 12 (state 2026-11-02)

Daniele's answers (DECISIONS.md, "Questions tab, third batch"): Kristi script on the corridor end-wall neon and the
memory-corner light box; THB prices shown, dimmed; Pour Perfect a rotation of 12 drinks, one per drink family.
`layout.json` untouched (the sign and the box are build_venue.gd details, not kit placements); `rules.gd` untouched;
`smoke_start.gd` untouched (another worker's).

## 1. Kristi lettering
- **Corridor end-wall neon** (photo 24): new generator `tools/venue_neon.py` draws `game/assets/venue/corridor_neon.png`
  (1200 × 1120, black = nothing) from the bundled `Kristi-Regular.ttf`: "Black" over a tube line and "— Cabin —" in
  pale pink-white tubes with a red-pink glow, "Now Open" in a green-white arrow outline pointing left (north, to the
  Sticker door). Same recipe as the street sign (`tools/street_sign.py`): tinted tube, white-hot centre (the stroke
  eroded), two blurred halos. Kristi's strokes are already tube-thin, so the glyph itself is the tube.
- `game/tools/build_venue.gd`: `_corridor_end` now places one additive, HDR-bright quad (`_neon_quad`, 1.2 × 1.12 m,
  same material setup as `street_front.gd`'s sign) on the existing dark panel; the old Label3D wordmarks and the 3D
  line/arrow tubes are gone. Still in the "cutaway" group with the corridor's cut rule. No new light (42).
- **Memory-corner light box** (photo 25): "Black / Cabin" in Kristi, printed in dark ink on the lit box as in the
  photo (it is a printed light box there, not neon); was white glowing default-font capitals.
- Words are in title case ("Black", "Cabin", "Now Open"), as the interface's Kristi titles (`UI.title_case`): script
  capitals read badly.
- `scenes/venue/venue.tscn` regenerated (`--import`, then `--script res://tools/build_venue.gd`).

## 2. Prices
- Already in the game since the real-menu worker (option (a) of their call, which Daniele chose): every drink and
  dish row shows its THB price as printed ("390", "520 / glass", "1,890 / bottle", "5 + 1 free · 590") right-aligned
  in the secondary colour (SMOKE `#C4ADA2`, the item name is CREAM), with the footer "Prices in THB as printed at
  Black Cabin". Now pinned: `menu_list.gd` `PRICE_COLOR := UI.SMOKE`, price label named `Price`, and `test_menu`
  checks every drinks and kitchen row shows `BarMenu.price_text()` in that colour, dimmer than the names.

## 3. Pour Perfect: 12 families
- `tools/menu_build.py` `POUR_FAMILIES` (written to `game/data/menu.json` as `pour_families`; `pour_featured` is now
  derived from it). The twelve families cover every pourable menu category exactly once (the five whisky lists are one
  family), in rotation order with their drink:
  1 beer Heineken Draught · 2 house shooter House Shooter · 3 sparkling Moët & Chandon Brut · 4 white wine Pete's Pure
  Sauvignon Blanc · 5 red wine The Wily Fox Shiraz · 6 whisky Monkey Shoulder · 7 gin Roku · 8 tequila & mezcal
  Don Julio Blanco · 9 vodka Absolut · 10 rum Phraya Rum 8Y · 11 brandy & cognac Hennessy VS · 12 liqueur Jagermeister.
  Changed from the old 12: Guinness and Jameson out (a second beer, a second whisky); Moët and Absolut in.
- **Rotation: per bar night, then per pour.** `BarMenu.night_of(t)` counts nights on Bangkok time (UTC+7) turning
  over at 06:00, so 19:00–02:00 is one night and every player sees the same drink of the night. `pour_pick(n, merry,
  night)` = family `(night + n) % 12`: tonight opens on one family, each further pour in the visit moves on one, and
  tomorrow opens on the next family. Before, `pours_this_visit` reset every visit, so every visit opened on Heineken.
  Merry still pours a Coke. `venue_session.gd` passes `BarMenu.night_of(needs.real_now())` (the one-line change).
- New helpers `BarMenu.pour_families()`, `family_of(id)`, `night_of(t)`.
- `test_menu` `_check_pour_families`: 12 families, 12 featured; ids and categories unique; each drink on the menu and
  in its own family; every pourable drink in exactly one family, nothing else in any; any 12 pours in a row from six
  sample nights cover all 12 families; tomorrow opens on the next family; the 06:00 Bangkok turnover.

## Tests (headless, from game/, shared tree)
All nine pass (2026-11-02, before the row-height fix; test_menu re-run after it: 2736 checks, 0 failed): smoke_stairs,
smoke_tap, smoke_hud, test_needs (106), test_minigames (828), smoke_loop, smoke_doors_sit, test_menu (2734),
smoke_start (PASS once, camera speed max 7.9 m/s; run against the smoke-start worker's uncommitted copy of the test).

## Captures `docs/art/screens/answers-3/` (portrait 1080×1920, landscape 1920×1080)
- `1-corridor-sign-*` (game camera looking east), `1-corridor-sign-close-*` (eye level).
- `2-memory-corner-*` (eye level, as photo 25), `2-memory-box-close-*`.
- `3-menu-drinks-*`, `3-menu-wine-*` (by-the-bottle prices, long names wrapping), `3-menu-kitchen-*`.
- `4-pour-perfect-hennessy_vs-*` (tonight's drink, in game).
- Fixed on the way: drink rows did not grow when a long name wrapped (rows drew over each other, visible in the wine
  list); `menu_list.gd` now grows each row with its content; `test_menu` checks every row fits its text.
- Re-take: `godot --path . --resolution 1080x1920 --script res://tests/capture_answers3.gd -- --capture-size=1080x1920
  --tag=portrait` (and `1920x1080`, `--tag=landscape`) from `game/`, then `python tools/answers3_sheet.py`.

## Open / for whoever is next
- Ordering from the menu still does not mark a drink as tried; bundles still not shown (real-menu follow-ups).
- The memory-corner box and its stool are still placeholders for the later kit pass (Daniele: model them properly).
- **Not done:** a 12-tile Pour Perfect rotation sheet. Pour scenes instanced on their own stayed on "Nam slides you a
  glass" (they need whatever start call the minigame frame makes); the attempt and its composer were removed. The
  list of twelve is in this note and in `menu.json`.
- No call for Daniele; lettering, prices and the rotation follow his answers. The box lettering is dark ink, as photo 25.
