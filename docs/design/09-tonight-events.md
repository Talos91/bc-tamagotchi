# 09 — Tonight and upcoming events (backlog D1 + D2)

Status: built offline for 0.3.0 (2026-11-15, social-features worker). Owner calls marked **(Daniele)** are on the hub card `tonight-review`.

## What it is
The real Black Cabin calendar inside the game, with no server: a **Tonight** sheet that says what is on at the bar tonight (event, time, lineup) and lists what is **coming up**. It is the in-game bridge to "go to the real bar tonight" and the source the stakes chapter's "check the event calendar" need can later read.

## Where it opens
- A small **Tonight** button on the venue HUD, top right, on the zone-name row just left of the orientation toggle (`game/scenes/ui/needs_hud.gd`, signal `tonight_pressed`; `game/scripts/main.gd` `open_tonight()`). Walking is blocked while the sheet is open, like the menu list.
- The sheet is a bottom sheet in the menu list's look (`game/scenes/tonight_sheet.gd`); it closes on Close, a tap above it, or Esc.
- Placement options **(Daniele)**: A HUD button top right (built, rec) · B a line on the start screen ("Tonight: The Cabin Jam") that opens the same sheet · C a row in the stage zone's sheet ("What's on tonight").

## What it shows
1. Header "TONIGHT AT BLACK CABIN", then the evening's date and the bar's state: *Open now · until 02:00* / *Doors open at 19:00* / *Closed on Mondays · back Tue at 19:00* (red).
2. Tonight's card: the event title (large), *Showtime 22:45* or *From 21:15* (the poster's SHOWTIME / ONWARDS), and the lineup when the poster lists one (The Cabin Jam). Gold-edged when there is an event.
3. **Coming up**: up to 6 events after tonight, in tonight's month and the next: date (*Sun 25 Oct*), title, lineup, time.
4. Footer: *Open Tue–Sun, 19:00–02:00*.

## The clock (Bangkok, UTC+7, no daylight saving)
- "Tonight" is an **evening**, 19:00 to 02:00. Before 02:00 it is still the previous evening (01:30 on Thursday shows Wednesday's Cabin Jam).
- 02:00–19:00 on an opening day: tonight is the coming evening, state *Doors open at 19:00*.
- **Monday is closed**: the Monday evening runs Mon 02:00 → Tue 02:00. Monday 01:00 is still Sunday's open evening.
- The game uses the phone's clock converted to UTC+7, so a player abroad still sees Bangkok's tonight.

## Empty and closed states (nothing is ever invented)
| Case | Tonight's card | Coming up |
|---|---|---|
| Event tonight | title, time, lineup | next events |
| Month known, no event | "No special event tonight: a regular night at the bar." | next events |
| Monday | "The bar is closed tonight." | next events |
| Month without a JSON | "November 2026's calendar isn't in the game yet." | "November 2026: calendar not in yet." per missing month |

Today (15 Nov 2026) the game shows the last row: only October is transcribed. The November poster is a **facts** question on the card.

## Data and adding a new month
- Source of record: `docs/venue/events/<yyyy-mm>.json` next to the poster (format in that folder's README: `date`, `day`, `title`, `time`, `time_kind` showtime|onwards, optional `lineup`, `note`).
- In the game: a copy at `game/data/events/<yyyy-mm>.json` (bundled: the export include filter has `*.json`). The game looks for the file by name, so no list to update.
- **To add a month**: Daniele sends the poster → a worker saves it as `docs/venue/events/<yyyy-mm>-upcoming-events.jpg`, transcribes `<yyyy-mm>.json` (asks, never guesses, unreadable titles), copies the JSON to `game/data/events/`, runs `test_tonight`, commits; the next PATCH deploy carries it. Titles are shown as printed on the poster (English) in both languages.
- Later (not built): fetch the month from the server when presence/Supabase exists, with the bundled copy as fallback.

## Code and tests
- Logic: `game/scripts/tonight_events.gd` (evening mapping, month loading, upcoming, text helpers; `now_override` pins the clock for tests and captures).
- Strings: `game/i18n/strings_tonight.csv` (EN + TH machine drafts, for staff to check), registered in `project.godot` and listed in `test_string_keys`.
- Suite: `game/tests/test_tonight.gd` (165 checks): Bangkok conversion, after-midnight, closed Monday, month and year edges, known/unknown months, upcoming cap, strings and dynamic keys, the sheet in EN/TH portrait/landscape with no raw keys, and the HUD button opening and closing it from `main.tscn`.

## What can go wrong
- A phone with a wrong clock shows the wrong evening (accepted: no server time offline).
- Special openings or closures (holiday Mondays, private events) are not modelled: the poster JSON would need a `closed` / `open` flag **(Daniele: if the bar ever opens on a Monday)**.
- Thai strings are machine drafts; Thai dates use the Gregorian year.
