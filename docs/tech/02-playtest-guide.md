# Playtest guide: the first playable loop

Status: 2026-10-28, wave 3b zone wiring. One page on how to play a visit end to end.

## Run it

- **Editor:** open `game/project.godot` in Godot 4.6.1
  (`H:/My Drive/PROJECTS/Ooze Syndicate/Tools/Godot/Godot_v4.6.1-stable_win64.exe`), press **F5**.
  `scenes/main.tscn` is the main scene.
- **Command line:** `Godot_v4.6.1-stable_win64.exe --path game` (portrait 1080×1920, shrunk to fit the screen).
  For landscape add `--resolution 1920x1080`, or press **F7** in game to swap.
- You arrive in the Lounge by the street door, and the visit starts at once.

## Controls

| Do | Mouse / keyboard | Touch |
|---|---|---|
| Walk | WASD or arrows; click the floor | joystick bottom left; tap the floor |
| Go to a zone | click the bar, stage, a table or the cabinet; or a chip on the right edge (Bar, Stage, Mali's table, Pinball) | same, tap |
| Open what's here | click the prompt pill at the bottom, or **E** / Space / Enter | tap the pill |
| Close a sheet | Esc, or click the room above it | tap the room |
| Leave | **Leave** (top left), or the street door | same |

The top row shows the four needs as rings (Music, Friends, Drinks, Nightlife). The lowest one breathes, and its
zone's chip gets the same colour edge. Gains rise from the rings as "+N".

## What to try

| Where | Rows | Refills |
|---|---|---|
| **Bar** (Nam) | Order a drink (first one's on the house) · Pour it yourself (**Pour Perfect**) · Try something new (+5 bonus, 6 drinks) · Thai iced tea · Water | Drinks |
| **Stage** front | Find a spot · Play along (**Front Row Rhythm**, the song playing now) · Applaud (between songs only, capped) | Music |
| Anywhere on the Candle Floor or at the stage (not the bar or Lounge) | every song you hear most of (60 s songs) is +5 Music; 4 songs also earn the set bonus (+5 Music, +5 Nightlife) | Music |
| **Mali's table** (gold "Mali ♥" tag) | **Candle Talk** (once a day) · Sit with Mali (stand still 60 s, once a day) | Friends |
| Other Candle Floor tables | Sit here a while (60 s, once per table per day) | Friends |
| **Lounge** | first time in each visit: +5 | Nightlife |
| **Pinball cabinet** (Lounge) | **Neon Pinball** | Nightlife |
| **Street door** | Head home: the walk-out summary | — |

- Drink 3–5 alcoholic drinks and watch the chip next to the rings go Warm → Tipsy → Merry; the walk changes, and
  once Merry, Nam pours only water or mocktails. Water drops one state.
- Repeat an action: diminishing returns (§2.4) make each one land a little less; at zero the card says "That's
  plenty for tonight".
- Leave, read the totals, tap BACK TO THE FLAT, then GO OUT: that's the day's 2nd visit (×0.75).
- **F4** (a week away) shows the Welcome Back dialogue and the gold x2 chip for 15 minutes.

## Debug keys (debug builds)

| Key | Does |
|---|---|
| F1 | needs debug panel: exact meter values, every action, clock controls |
| F2 | game clock +1 day (decay applies) |
| F3 | debug clock ×60 (1 real minute = 1 game hour), again for ×1 |
| F4 | as if away 7 days: ends the visit quietly, starts a new one with Welcome Back |
| F5 | reset the save and restart the scene |
| F6 | skip to the end of the current song or break |
| F7 | swap portrait / landscape window |
| F8 | English / Thai |

## Reset the save

Press **F5** in game, or delete
`%APPDATA%\Godot\app_userdata\Black Cabin Tamagotchi\save.json` with the game closed.

## Tests and screenshots

From `game/`: `Godot --headless --path . --script res://tests/smoke_loop.gd` (the whole visit), plus
`smoke_stairs`, `smoke_tap`, `smoke_hud`, `test_needs`, `test_minigames`.
Screenshots: `Godot --path . -- --capture=<png> --capture-size=1080x1920 --capture-at=bar [--capture-sheet]`;
the current ones are in `docs/art/screens/loop/`.

## Not in yet

The Flat (a stand-in screen only), coins (drinks are free), memories, the dance spot, other regulars, Nam's chat, a
real performance schedule (the band loops one set of 4 songs), headline nights.
