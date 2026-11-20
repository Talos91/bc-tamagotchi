# 🧩 tonight-lineup — report (2026-11-20)

UI worker, Opus 5.5, load id 2026-11-20-ui-black-cabin-05f1f2. Branch `wk/tonight-lineup`, one commit on origin/main (SHA in the orchestrator message). Not pushed.

## Evidence
- Suites, headless, local exe `C:/Users/itisf/godot-local/`, one empty APPDATA per suite, final tree: **31/31 PASS** (the 30 in PROJECT.md + new `test_lineup`, 242 checks). `test_tonight` 185 checks.
- Captures, hidden desktop (hd.ps1; foreground owners: claude only, godot-owned=0): `docs/art/screens/tonight-lineup/`, 13 shots × portrait 540x960 + landscape 960x540 (`tests/capture_lineup.gd`): HUD chip on stage / between sets / closed Monday; lineup night Wed 18; special night Thu 19; closed Mon 23; week without data Tue 24; calendar Fri 20 + Thu 19 tapped; Thai.
- Hub cards: `tonight-lineup-review` (review, 11 pictures + files), `band-photos-consent` (question, recommended: yes, ask the bar to confirm), `bar-open-mondays` (question; posters list Monday acts and Mon 9 event, game says Tue–Sun).

## What changed
- Data: `docs/venue/events/2026-11.json` (9 events), `docs/venue/events/lineup-2026-11-16.json` (7 days, 21 acts; Thu 19 John Mayer Night program), copies in `game/data/events/`. Poster quirks in `notes` (MONTHERFUNKY vs MOTHERFUNKY, Kiki 19.00 vs 19.30, 23.15PM, text under Instagram icons).
- Photos: 18 square crops, 320 px JPEG ~15 KB each, `game/assets/events/<slug>.jpg`, from `tools/crop_lineup.py` + `docs/venue/events/2026-11-week-16-22/crops.json`.
- Logic `game/scripts/tonight_events.gd`: `lineup(date)` (file `lineup-<monday>.json`, found by name), `act_slots`, `now_on_stage`, `stage_now/stage_line/stage_sub`, `act_photo`, text helpers; `tonight()` gains `acts`, `lineup_known`, `now_act` (backward compatible).
- UI `game/scenes/tonight_sheet.gd`: tabs Tonight | Calendar; act cards (photo or neon initial, name, genre/role, set time, description; act on now lit + "Now on stage"); Mon–Sun month grid (gold = special event, LED bar = lineup in), tap a day → events + acts, < > months.
- **Live chip (Daniele's add-on):** `game/scripts/ui/stage_chip.gd` replaces "LIVE · song n of 4" in `needs_hud.gd` (node still `Live`); the stage sheet line (`venue_session.gd header_for`) uses the same text. House band songs still drive the Music meter and Front Row Rhythm; `band_text()` and `venue.band.*` strings kept dormant (cheap). DECISIONS: two 2026-11-20 rows quoting Daniele.
- Strings: 23 keys appended at the end of `game/i18n/strings_tonight.csv` (EN + TH machine draft). `strings_venue.csv` untouched.
- Docs: format + weekly update recipe at the end of `docs/venue/events/README.md`; pointer in `docs/design/09-tonight-events.md`.

## Not verified / open
- No real phone; web build not run (no ‹ › ◆ glyphs used, ASCII and drawn swatches instead).
- Monday stays closed in the game (Monday acts show only in the Calendar) until `bar-open-mondays` is answered.
- Photos are real people: shipping them waits on `band-photos-consent` (orchestrator's call).
- `test_lineup` needs adding to the PROJECT.md Tests list (orchestrator).
- Cherry-pick: `venue_session.gd` is also edited by venue-entrance (my change: one preload + one line in `header_for`).

## Incident
- At ~17:2x I ran `taskkill //IM Godot_v4.6.1-stable_win64_console.exe` to stop my own leftover suite run; it killed 3 Godot processes, possibly another session's. Lesson: kill by PID only.

## Profile feedback
- The UI profile could name the hidden-desktop script path (`C:/Users/itisf/ooze-wt/quota-drill-tools/hd.ps1`) and say "kill Godot by PID only".
