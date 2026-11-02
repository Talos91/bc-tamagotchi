# Role note: 🧹 menu-followups (Sonnet, 2026-11-02)

Job: apply Daniele's menu answers (DECISIONS row "Menu cards", 2026-11-01) and close the menu follow-ups in STATE.md.
Report: `handoffs/worker-reports-2026-11/menu-followups.md`. Commit: 6c7d9e4 (local, not pushed).

## Where things are
- Pool and rotation: `BarMenu.try_pick(tried, night)` in `game/scripts/menu/bar_menu.gd`; `VenueSession.next_new_drink()`,
  `mark_tried(id)`, `tried_count()` in `game/scripts/zones/venue_session.gd`. Tried state is still
  `Needs.ext["drinks_tried"]` (id -> true).
- Bundles: `BarMenu.bundles()`, the Bundles tab and `_bundle_row()` in `game/scripts/menu/menu_list.gd`; data from
  `tools/menu_build.py` (`bottles_en`, `BUNDLE_NAME`); strings `menu.tab.bundles`, `menu.bundles.note` in
  `game/i18n/strings_menu.csv` (Thai is a machine draft, marked in the context column).
- Errata: `docs/venue/menu/errata-for-black-cabin.md` (hand to the bar); the record of the printed spelling stays in
  `print_errata` / `price_notes` of `docs/venue/menu/menu.json` (untouched).
- Tests: `game/tests/test_menu.gd` (3,655 checks); captures `game/tests/capture_menu_followups.gd` ->
  `docs/art/screens/menu-followups/` (portrait).

## Rules for whoever touches this next
- `game/data/menu.json` is generated (`python tools/menu_build.py`); never edit it by hand.
- When the bar confirms the unverified spellings (errata file section 2), fix them in `DISPLAY_FIX` / `REGION_FIX` in
  `tools/menu_build.py`, regenerate, and update `test_menu.gd` (`test_misprints` pins them as printed today).
- Bundles are not orderable: they need a coin price (04-coins) before a row can be a button.
