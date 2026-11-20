# Black Cabin events (real calendars)

Monthly posters from Black Cabin (@blackcabinbar), supplied by Daniele, with a JSON transcription per month. Feeds BACKLOG D1 (upcoming events), D2 (Tonight tab), the "check the event calendar" need in the stakes proposal, and the performances schedule. Format: `YYYY-MM.json` next to the poster image. Kinds of night seen so far: tribute nights ("Coldplay & Oasis Night", "Charlie Puth Night", "Damien Rice Night"), concerts by named Thai acts (Moderndog, Noi Pru), "The Cabin Jam" with a listed lineup, "Cabin's Visitor" guest sets, anniversary and Halloween parties. Showtimes 20:00–23:45.

## Month file `YYYY-MM.json` (special events)
`{source, month, notes?: [..], events: [{date, day, title, subtitle?, time, time_kind: showtime|onwards, lineup?: [names], note?}]}`. Titles as printed (Title Case), one entry per poster line; two events on one date are two entries. `subtitle` = the second poster line (guest bartender and bar). Poster quirks go in `notes`, never silently fixed. November 2026 (`2026-11.json`) is from `2026-11-week-16-22/0-november-calendar.jpg`.

## Weekly lineup `lineup-<monday YYYY-MM-DD>.json` ("Who's playing tonight", 2026-11-20)
From the bar's weekly "This week on stage" Instagram posters (one per day, three acts each). The file is named by the **Monday** of the Mon–Sun week; the game finds it by name, no list to update.

```
{source, week: "<monday>", notes?: [..],
 days: [{date, day, title?, poster, acts: [
   {slug, name, genre?, role?: opening|cover|closing, start: "HH:MM", end?: "HH:MM", till_late?: true,
    description?, photo?: "<slug>.jpg"}]}]}
```
- Times as on the poster (`21.15` → `"21:15"`); times before noon are after midnight (same evening). `TILL LATE` → `till_late: true` (runs to 02:00). No end → until the next act starts (the last act: 02:00).
- `genre` and `description` from the poster, all caps turned into sentence case, words unchanged. Special nights with a program (Thu 19 John Mayer Night: OPENING BY / COVER BY / CLOSING BY) use `role` and no photo; the game shows the name's initial in neon.
- `photo` is a square crop of the act's picture in `game/assets/events/` (320 px JPEG, ~15 KB), made by `tools/crop_lineup.py` from a `crops.json` next to the posters.
- The bar is closed on Mondays in the game (`tonight_events.gd`), so a Monday lineup shows in the Calendar only, not as tonight's cards (open question `bar-open-mondays`).

## Weekly update recipe (Housekeeping, data only, no code)
When Daniele sends next week's posters (cover + one per day, + the month calendar when a new month starts):
1. Save them in `docs/venue/events/<YYYY-MM>-week-<DD>-<DD>/` named `1-week-cover.jpg`, `2-monday.jpg` … `8-sunday.jpg` (special-night posters keep their own name, e.g. `5-thu19-john-mayer-night.jpg`).
2. Transcribe `docs/venue/events/lineup-<monday>.json` (copy the previous week's file as the template). Exact spellings; unreadable words → ask, never guess; quirks → `notes`.
3. Photos: copy the last week's `crops.json` into the new folder, set each act's `slug`, `poster` and `box` (the photo's pixel rectangle on the poster: the three photos sit at about x 53–507, y 198–541 / 569–911 / 940–1282 on a 1079 px wide poster; `focus_x` 0..1 moves the square left/right; `fit: "contain"` for two-photo collages) and run `python tools/crop_lineup.py docs/venue/events/<week folder>/crops.json`. Look at the crops before committing.
4. Copy the JSON into the game: `cp docs/venue/events/lineup-<monday>.json game/data/events/` (and `<YYYY-MM>.json` for a new month).
5. Run `test_lineup` and `test_tonight` (headless, empty APPDATA). `test_lineup` pins the 16–22 Nov week; it keeps passing as weeks are added.
6. Commit posters + JSON + crops in one commit; the verified push deploys it (auto-deploy pipeline).
New act photos are real people from the bar's public posters: hub card `band-photos-consent` must be answered yes before they ship publicly.
