# 🧩 tonight-lineup — role note (2026-11-20)

UI worker, Opus 5.5, load id 2026-11-20-ui-black-cabin-05f1f2. Branch `wk/tonight-lineup` in `C:/Users/itisf/bc-wt/tonight-lineup` (off origin/main edc4599). Not pushed.

## State now
- Built: "Who's playing tonight" act cards + Calendar tab in the Tonight sheet (`game/scenes/tonight_sheet.gd`), weekly lineup loader + set slots + now-on-stage in `game/scripts/tonight_events.gd`, 23 strings at the end of `game/i18n/strings_tonight.csv` (EN + TH machine draft).
- Data: `docs/venue/events/2026-11.json` (9 November events), `docs/venue/events/lineup-2026-11-16.json` (16–22 Nov, 21 acts), copies in `game/data/events/`. 18 photo crops in `game/assets/events/` (320 px JPEG) via `tools/crop_lineup.py` + `docs/venue/events/2026-11-week-16-22/crops.json`.
- Suites: new `test_lineup` (242 checks); `test_tonight` moved off "November has no data" (now 2027-01 is the missing month; upcoming rows 3 → 6).
- Captures: `docs/art/screens/tonight-lineup/` (13 shots × portrait 540x960 + landscape 960x540, hidden desktop, `tests/capture_lineup.gd`).
- Live chip (Daniele's add-on, 2026-11-20): `game/scripts/ui/stage_chip.gd` replaces the HUD's "LIVE · song n of 4" pill (node still named `Live`) with the act on stage now (`TE.stage_now/stage_line/stage_sub`); the stage sheet line uses the same text. House band songs still run for the Music meter; `band_text()` + `venue.band.*` strings kept dormant. DECISIONS rows 2026-11-20 added.
- Hub cards: `tonight-lineup-review` (407), `band-photos-consent` (408), `bar-open-mondays` (409).

## Next
- Orchestrator: verify + cherry-pick; add `test_lineup` to the PROJECT.md Tests list.
- Weekly: Housekeeping follows the recipe at the end of `docs/venue/events/README.md`.
- If Daniele answers `bar-open-mondays` = open 7 nights: `CLOSED_WEEKDAY` in `tonight_events.gd` (-1 = none), the hours string `tonight.hours`, the stakes check-in window, and the test_tonight Monday cases.
- If `band-photos-consent` = no photos: delete `photo` fields (or the jpgs); cards fall back to neon initials, test_lineup's photo count check needs updating.

## Gotchas
- `needs_hud.gd` and `venue_session.gd` got small edits (chip, stage line, one preload): venue-entrance also edits `venue_session.gd`, expect a trivial cherry-pick conflict.
- Lineup files are found by the week's **Monday** date; acts' times before noon count as after midnight.
- `test_lineup` pins week 16–22 Nov; it checks the game copies equal the docs files byte for byte.
- Glyphs ‹ › ◆ are not in the web font: ASCII `<` `>` and drawn swatches are used.
- The Godot exe on Drive crashes on import: use `C:/Users/itisf/godot-local/`.
