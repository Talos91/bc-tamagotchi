# Role note — 🌐 Tonight + upcoming events (backlog D1/D2), 2026-11-15

Worker: social-features, load id 2026-11-15-social-features-black-cabin-182dca. Orchestrator local_060ea4b4.

## State now
- Built offline on local main (not pushed; the Verifier pushes): HUD **Tonight** button (top right, left of the orientation toggle) → bottom sheet with tonight's date + bar state, tonight's card (event/time/lineup or regular/closed/no-data), Coming up (≤ 6, this month + next), hours footer.
- Design: `docs/design/09-tonight-events.md`. Captures: `docs/art/screens/tonight/` (portrait 1080×1920 + landscape). Hub card `tonight-review`.
- Data bundled: `game/data/events/2026-10.json` (copy of `docs/venue/events/2026-10.json`). **November 2026 missing** → the game today shows "November 2026's calendar isn't in the game yet." Facts question on the card.

## Files
- `game/scripts/tonight_events.gd` (logic + strings fallback), `game/scenes/tonight_sheet.gd` (UI), `game/i18n/strings_tonight.csv`, `game/data/events/`, `game/tests/test_tonight.gd` (suite, 165 checks), `game/tests/capture_tonight.gd` (screens).
- Hooks outside own paths (one-liners): `game/scenes/ui/needs_hud.gd` (signal + button + retitle), `game/scripts/main.gd` (`open_tonight`, `_blocked`), `game/project.godot` (2 translations registered), `game/tests/test_string_keys.gd` (TABLES + strings_tonight).

## Next steps
- When Daniele sends the November poster: save jpg + transcribe `docs/venue/events/2026-11.json`, copy to `game/data/events/`, run test_tonight (its "2026-11 has no data" checks then need moving to a month still missing, e.g. pin 2027-01).
- Owner calls on the card: placement (HUD button / start-screen line / stage sheet), November data.

## Gotchas
- Clock is UTC+7 from the phone clock; `TonightEvents.now_override` pins it (tests, captures). Evening = 19:00–02:00; Monday evening = Mon 02:00 → Tue 02:00.
- In landscape the stretched viewport is wider than 1920 (canvas_items/expand): use `get_visible_rect()` in checks.
- "tonight." appears in real English ("closed tonight."): raw-key checks use the regex `tonight\.[a-z0-9_]`.
