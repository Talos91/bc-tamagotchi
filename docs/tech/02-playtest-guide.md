# Playtest guide: the first playable loop

Status: 2026-11-02, venue v4 with walk-through doors, real seats, the turned stair and the front-door start screen. One page on how to play a
visit end to end.

## Run it

- **Editor:** open `game/project.godot` in Godot 4.6.1
  (`H:/My Drive/PROJECTS/Ooze Syndicate/Tools/Godot/Godot_v4.6.1-stable_win64.exe`), press **F5**.
  `scenes/main.tscn` is the main scene.
- **Command line:** `Godot_v4.6.1-stable_win64.exe --path game` (portrait 1080×1920, shrunk to fit the screen).
  For landscape add `--resolution 1920x1080`, or press **F7** in game to swap.
- **Start screen.** The game opens on the street at night, looking across the soi at the club's door under the
  lit BLACK CABIN neon, with the title and "Tap to enter". Tap, click, Enter or Space: your character steps out from
  under the camera and walks in, the door swings open for them, the camera follows over their shoulder through the
  doorway, then pulls back and up into the game camera as the door swings shut; the HUD fades in. About 5 s; tap
  again to skip to the end. Nothing counts until you are inside (no visit, no band, no HUD); the save loads first.
  Skip it altogether with `-- --skip-intro` on the command line, or **Esc** on the start screen (debug builds).
- You arrive in the entrance lobby, just inside the street door (west end of the L corridor), and the visit starts
  then. The corridor runs east along the lounge to the Sticker door; through it is the lounge, then the buffer
  zone and the main room.
- **Doors.** The street door, the Sticker door and the red door to the smoking room swing open when you (or a
  patron) come within about a metre, and close behind you. The emergency exit, toilet, kitchen and staff doors stay
  shut; the bar staff sometimes step out through the staff door by the order hatch.
- **Stairs.** In the lounge's south-west corner: the first flight runs along the Sticker-door wall from beside the
  game machine up to a landing, the second turns right and climbs along the west wall into the floor above. You
  can climb to the velvet rope; upstairs is closed for now.

## Controls

| Do | Mouse / keyboard | Touch |
|---|---|---|
| Walk | WASD or arrows; click the floor | joystick bottom left; tap the floor |
| Go to a zone | click the bar, stage, a table or the cabinet; or a chip on the right edge (Bar, Stage, Prae's table, Pinball) | same, tap |
| Open what's here | click the prompt pill at the bottom, or **E** / Space / Enter | tap the pill |
| Close a sheet | Esc, or click the room above it | tap the room |
| Leave | **Leave** (top left), or the street door (its sheet opens inside it or on the step outside) | same |
| Stand up | any move key or the joystick, or click / tap somewhere to walk | same |

The top row shows the four needs as rings (Music, Friends, Drinks, Nightlife). The lowest one breathes, and its
zone's chip gets the same colour edge. Gains rise from the rings as "+N".

## What to try

| Where | Rows | Refills |
|---|---|---|
| **Bar** (Nam) | Order a drink (first one's on the house) · Pour it yourself (**Pour Perfect**) · Try something new (+5 bonus, 6 drinks) · Thai iced tea · Water | Drinks |
| **Stage** front | Find a spot · Play along (**Front Row Rhythm**, the song playing now) · Applaud (between songs only, capped) | Music |
| Anywhere on the Candle Floor or at the stage (not the bar or Lounge) | every song you hear most of (60 s songs) is +5 Music; 4 songs also earn the set bonus (+5 Music, +5 Nightlife) | Music |
| **Prae's table** (gold "Prae ♥" tag) | **Candle Talk** (once a day) · Sit with Prae (60 s seated, once a day) | Friends |
| Every other table: Candle Floor round, rectangular and tiny tables, raised strip, lounge tables, long table and counter, tall tables, smoking-room tables | Sit here a while (60 s seated, once per table per day) | Friends |
| **Bar** | Take a stool: a minute at the counter chatting (+3, provisional; order from the stool) | Friends |
| **Lounge** | first time in each visit: +5 | Nightlife |
| **Pinball cabinet** (Lounge) | **Neon Pinball** | Nightlife |
| **Street door** | Head home: the walk-out summary | — |

- **Sitting.** "Sit" walks you to a free chair at that table (a couch place on the raised strip, a stool at a tall
  table or the bar) and sits you down facing the table; if every seat is taken, a patron gets up to make room. The
  minute starts once you are seated and the HUD counts it down; you stay seated after it until you move. The game
  machine has no seat: there "Sit here a while" still means standing still a minute.
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
| F8 | English / Thai (also on the start screen) |
| Esc | on the start screen: straight in, no walk (F5 restarts with the start screen) |

## Reset the save

Press **F5** in game, or delete
`%APPDATA%\Godot\app_userdata\Black Cabin Tamagotchi\save.json` with the game closed.

## Tests and screenshots

From `game/`: `Godot --headless --path . --script res://tests/smoke_loop.gd` (the whole visit), plus
`smoke_stairs`, `smoke_tap`, `smoke_hud`, `test_needs`, `test_minigames`, `smoke_doors_sit` (doors, seats, stair) and
`smoke_start` (start screen and entry). Suites that load `main.tscn` themselves start straight in the venue; only
running the game (main scene) shows the start screen.
Screenshots: `Godot --path . -- --capture=<png> --capture-size=1080x1920 --capture-at=bar [--capture-sheet]`;
the current ones are in `docs/art/screens/loop/` (screenshot mode skips the start screen). Start screen and entry:
`Godot --path . --resolution 540x960 --script res://tests/capture_start.gd -- --tag=portrait` (and `960x540`,
`--tag=landscape`) → `docs/art/screens/start/`.

## Not in yet

The Flat (a stand-in screen only), coins (drinks are free), memories, the dance spot, other regulars, Nam's chat, a
real performance schedule (the band loops one set of 4 songs), headline nights.
