# 🛠️ Chat stuck: role note (2026-11-02, state now)

Worker: tech (Sonnet), briefed by the orchestrator local_78d0c67d after Daniele played v0.2.0 · 967eab0: "game works,
chat seems stuck". Bug hunt on "have a chat" (Candle Talk at Prae's table and the Friends rows).

## What I found
- **The talk itself does not hang.** In clean worktrees of 967eab0, driven through `main.tscn` with real mouse events
  (`Viewport.push_input`, in a 450x800 window and headless): talk row → frame → five cards → closing line → result
  card → DONE → frame gone, `_blocked()` false, `player.input_enabled` true. Sober, 4 drinks and 9 drinks (drunk
  overlay up): all fine. Every Friends row (Sit here a while at all 40 table/tall zones, Take a stool) seats the player and pays
  after the minute, sober and drunk. The drunk overlay's rect ignores the mouse. Prae being an owner (4bf4d9e) changes
  only the hearts row.
- **Getting to the talk does hang, for 22 of 45 zones, including Prae's table.** Tapping a table, or the "Prae's
  table" chip, walks the player to the zone's `approach` point (the table centre). The table's furniture is a hole in
  the navmesh and the agent stops 0.3 m short of its target (`target_desired_distance`), so the feet end 0.0–0.2 m
  outside the zone circle (Table2: 1.34 m from the centre, radius 1.15). `main._process` then dropped `pending_zone`
  (the walk ended outside the zone), so no sheet opened, and a second tap did nothing either (the walk is already
  "finished"). The player had to steer into the circle by hand. From the spawn, Prae's table fails this way every
  time; a walk from another side often lands inside, which is why the suites (they teleport onto the approach point
  or walk from the stage) never saw it.
- **Not new:** identical at 51603f0 (Table2 from the spawn stops at 28.99, 7.57 in both). 4bf4d9e / 2bde243 did not
  cause it. They only add Prae's figure and the toilet zone.

## Fix (one commit)
- `main.gd` `_process`: when a walk to `pending_zone` ends, the sheet opens if the feet are within `ARRIVE_SLACK`
  (0.5 m) of the zone. `venue_zones.gd`: `gap(zone, point)`, metres outside a footprint. Not touched: `player.gd`
  (feel-pass's), `camera_rig.gd`, `build_venue.gd`, `venue.tscn`, `smoke_doors_sit.gd`.
- Robustness found on the way: a Candle Talk with a cast member that has no `candle_talk/<id>.json` (every regular
  but Prae) died in `_on_start` on `data["lines"]` and left an empty frame; it now falls back to Prae's set
  (`candle_talk.gd` `FALLBACK`). The name over the bubble and on the hearts row comes from `Cast.name_of(id)` (the
  `cast.<id>.name` string, else the preset's display name), not the raw key. Only Prae has a name string today.
- Tests: `test_minigames` `test_chat_cast` (Prae and the seven regulars through the real frame: start, five turns,
  result card, DONE, control back, hearts only for regulars); `smoke_tap` taps six tables/stools from the west entrance
  and the Prae chip and asserts the sheet opens.

## Verification
All eleven suites pass headless in a clean worktree of 967eab0 (game/ identical to HEAD 22d52f4) plus only my seven
files: smoke_stairs, smoke_tap (new tap checks), smoke_hud, test_needs, test_minigames (933 checks, 97 new), smoke_loop,
smoke_doors_sit, smoke_start, test_menu, smoke_version, test_nightlife. The same tap walk from the west entrance
before the fix: 22 of 45 zones end without a sheet (Prae's Table2 included).

## Gotcha for every verifier: the suites read the real save
`smoke_tap` (and any run that does not call `new_game()` / switch autosave off) loads `user://save.json`
(`%APPDATA%/Godot/app_userdata/Black Cabin Tamagotchi`). That file currently holds an active **WASTED lockout**
(`ext.nightlife.lockout_until` 2026-11-02 16:31 local, meters all 0, written 04:40, so it came from the 967eab0 playtest
or a debug run): `main` boots straight into the WASTED screen, the player is blocked, and `smoke_tap` sees no movement
and hangs. I ran the suites with `APPDATA` pointed at an empty folder (`export APPDATA=<dir>` before Godot) to get a
clean save. Daniele's own next launch of the game on this machine will also open on the WASTED screen with a disabled
Try again until 16:31 (F2 skips a day in debug builds): if "chat seems stuck" came with the game opening on a dark
screen, that is why. Worth deleting or moving that save before the next playtest launch (orchestrator's call).

## Open / follow-ups
- **Raised3 (the third couch table of the raised strip) is unreachable by tap from the main room:** its approach point
  resolves to a navmesh spot beside Raised4 (gap 1.3 m), so no sheet opens. Raised3 and Raised4 are only 1.25 m apart
  with 1.09 m zones. Needs an approach point (layout/venue side, `build_venue.gd` / `venue_zones.gd`).
- Only Prae has Candle Talk lines; the seven regulars need their own `candle_talk/<id>.json` and `cast.<id>.name`
  strings (design/cast). Until then the fallback shares Prae's interim quiz-captain lines.
- If Daniele meant a different "chat" (e.g. the Claude session, or the multiplayer phrase wheel, not started), this note
  does not cover it: nothing in the game hangs inside the talk.
