# 🎮 Nightlife actions: role note (2026-11-02, state now)

Worker: gameplay (Opus), briefed by the orchestrator local_78d0c67d. Spec: Daniele's playtest of 33dc5b9
(`docs/design/DECISIONS.md`, row "Playtest of 33dc5b9"), BACKLOG B12. Four features: Light one up, the secret Check
the plumbing, the drunk debuff, WASTED with a 12 h lockout.

## What landed
- **Rules** (`game/scripts/rules.gd`, new block "Nightlife", every number not Daniele's marked provisional):
  `DRUNK_FROM 3`, `DRUNK_FULL 10`, `WASTED_AFTER 10`, `DRUNK_SOBER_MINUTES 20` (prov.), `WATER_SOBER_DRINKS 2` (prov.),
  `DRUNK_WARN_FROM 8` (prov.), `WASTED_LOCKOUT_HOURS 12`, `WASTED_METER_VALUE 0` (prov.), `WASTED_LINES 10`,
  `SMOKE_SECONDS 8`, `PLUMBING_DRINKS_TO 0`; new action `light_one_up` = +3 Friends, capped +6 per visit (prov.).
  No existing number changed.
- **Logic** `game/scripts/zones/nightlife.gd` (static, UI-free): `drunk_level(drinks)` (0 below 3; 3 → 0.125,
  4 → 0.25, 7 → 0.625, 10 → 1.0), `is_wasted` (11+), `get_wasted` (four meters to 0, visit ended with reason
  "wasted", lockout saved, a line picked that is never the previous one), `locked` / `seconds_left` /
  `last_line`, `check_plumbing`. State in `Needs.ext["nightlife"]` = {lockout_until, wasted, line}; the lockout runs
  on the game clock (`Needs.clock`), which is saved and keeps moving while the app is closed, so it survives a
  restart and the debug clock skips it (F2 +1 day, F3 x60).
- **Needs** (`needs.gd`): one helper, `force_meter(meter, value, fresh)`.
- **Drink count** (`zones/tipsiness.gd`): the per-visit count no longer stops at Merry (5). One drink wears off per
  `DRUNK_SOBER_MINUTES` of game clock (was one state per 30 real minutes); water takes `WATER_SOBER_DRINKS` off (was
  one state); looks unchanged (Clear/Warm/Tipsy/Merry anim sets).
- **Session** (`zones/venue_session.gd`): Nam no longer refuses alcohol at Merry (needed to reach 10); from 8 drinks
  the Order row's line is her warning ("Water's free, you know."). The menu list no longer greys alcohol at Merry
  (`main.gd` passes false; `data/menu.json` and `tools/menu_build.py` `merry_blocked` false for alcohol). Pour Perfect
  counts as alcohol only when what Nam pours is alcoholic (while Merry she still swaps in a Coke). Smoking room: row
  **Light one up** (8 s cigarette in the stand_drink pose, a white voxel stick with a glowing tip and CPU smoke
  particles built on the player at runtime; walking off puts it out with no gain; HUD line "Smoking · Ns"), then the
  generic sit. Toilets: one row, **Check the plumbing**. 11th alcoholic drink: `wasted(line)` signal.
- **Toilets zone** (`zones/venue_zones.gd`, kind `toilet`): the Vestibule kit at floor level (curtain, doors) grown
  0.1 m, approach `Wander_Toilets`. The roofed vestibule left behind the bar's west end; no build_venue change. Its
  prompt "Psst… tap to check the plumbing" is the only hint; no other zone, sheet, chip or label mentions it.
  NB: this hunk went into the Prae worker's commit 4bf4d9e (they staged the whole file); the rest landed in mine.
- **Drunk overlay** (`scripts/ui/drunk_overlay.gd`): CanvasLayer 0 right after `Post` (the vignette), under the HUD.
  Canvas shader on the screen texture: slow roll and drift, breathing zoom, a ghost copy sliding sideways (double
  vision), a 9-tap blur, warm tint, darker edges; strength = `drunk_level`, eased 0.35/s. `camera_rig.gd` untouched
  (its uncommitted fx hook from feel-pass is not used).
- **WASTED** (`scripts/wasted_shot.gd`, extends `street_shot.gd` like the exit shot): character doubled over puking
  (green voxel chunks), keels over backwards, a temporary Camera3D eases from the diorama view to a close-up
  (cull mask copied from the rig, so no ceiling), dark at 90 %, then `scenes/ui/wasted_screen.gd`: **WASTED** in red
  Kristi (capitals as Daniele wrote it, LabelTitle with a red glow), one of ten lines in Lato, "Out cold for 12 hours.
  Every need is back to empty.", **Try again** disabled with an h:mm:ss countdown. About 3.6 s; a tap skips to the
  screen. Opened during a lockout, `main.gd` goes straight to the screen (same line as when it happened). Try again:
  as the game, reloads main (start screen); in tests, back in at the spawn.
- **Strings** `game/i18n/strings_nightlife.csv` (EN + Thai draft), read at runtime by
  `scripts/zones/nightlife_strings.gd` (no project setting). The ten lines: index 0–9 in the CSV.
- **Tests** `game/tests/test_nightlife.gd` (new); `test_menu.gd`: two checks changed from "Merry refuses alcohol"
  to "Merry still serves alcohol". Captures `game/tests/capture_nightlife.gd`.

## Verification
All eleven suites pass headless in a clean export of 4bf4d9e (d47b27d adds only docs and .uid files) plus only my files
(git archive, then `--import`): smoke_stairs, smoke_tap, smoke_hud, test_needs (106), test_minigames (836), smoke_loop,
smoke_doors_sit, smoke_start, test_menu (2736), smoke_version, **test_nightlife (107)**. In the shared tree
smoke_loop fails "walked to stage" because of feel-pass's uncommitted player/camera edits (the Prae worker saw the
same); it passes in the clean tree with my changes.
test_nightlife covers: drunk levels 0 / 3 / 4 / 7 / 10, not WASTED at 10, WASTED at 11; wear-off and water; the
plumbing reset (meter to 0, next drink +15 in full) and that it is offered and hinted only in the toilets; Light
one up (prop, smoke particles, HUD line, gain only once finished); WASTED in the venue (all four meters to 0, visit
ended, no walk-out card, own camera, screen with the line, button disabled with countdown, pressing it locked does
nothing, debug clock past 12 h enables it, Try again starts a sober visit on their feet); the lockout through a save
and a 6 h close (6 h left, same line, meters saved), the x60 debug clock and F2 (+1 day); the boot during a lockout
going straight to the screen; every string in EN and TH, ten different lines, no drink-driving or harm words.

## Captures `docs/art/screens/nightlife/` (portrait 1080×1920, landscape 1920×1080)
Script `game/tests/capture_nightlife.gd` (portrait rendered 800x1422 and scaled, as the Prae captures), run on the
clean tree. Files `<name>-{portrait,landscape}.png`:
- `1-smoking` (game view, HUD "Smoking · 58s"), `1-smoking-close` (drink in one hand, lit cigarette and smoke in the other)
- `2-plumbing-prompt` (the toilets: character out of view, pill "Psst… tap to check the plumbing"), `2-plumbing-sheet`
- `3-drunk-4`, `4-drunk-7`, `5-drunk-10` (HUD stays sharp; chip Tipsy/Merry)
- `6-wasted-puke`, `6-wasted-down` (close-up, out cold on the bar floor)
- `7-wasted-screen` (line 3: "Nam says you sang the whole set. The band says it was a different set."),
  `7-wasted-screen-th` (Thai)

## Calls for Daniele (sent to the orchestrator for the Questions tab)
Pictures for the cards are the captures above (portrait and landscape of each).
1. **Sobering rate** (cards: `3-drunk-4`, `4-drunk-7`, `5-drunk-10`). Drinks count per visit; how fast do they wear
   off? (a, **rec**) one drink per 20 game minutes, a glass of water takes two off: a fast round still gets you
   WASTED, a slow evening with water never does; (b) one per 10 minutes, water two; (c) one per 60 minutes (about a
   real liver: nothing wears off within a visit, only water and leaving help); (d) no wear-off at all, only water
   and leaving.
2. **What "Light one up" does to the needs** (cards: `1-smoking`, `1-smoking-close`). (a, **rec**) +3 Friends, two
   cigarettes count per visit (the smoking room is where you talk to strangers); (b) +3 Nightlife, two per visit;
   (c) nothing, it is just for the look and the moment; (d) +2 Friends and +2 Nightlife, once per visit.
3. **"All minor needs unfulfilled" after WASTED** (cards: `7-wasted-screen`). (a, **rec**) all four meters (Drinks,
   Music, Friends, Nightlife) to 0, as built; the next visit then gets Welcome Back x2 automatically (Vibe fell
   under 25); (b) all four to 9, just "Empty" (the stakes annoyances fire, but the climb back is shorter); (c) only
   Drinks and Nightlife to 0; (d) as (a), plus the calendar habit marked as missed once the calendar exists.
4. **Check the plumbing, exactly** (cards: `2-plumbing-prompt`, `2-plumbing-sheet`). (a, **rec**) the Drinks meter
   to 0 and this visit's Drinks diminishing returns reset, so the next drinks count in full ("ready to drink all
   over"), as built; (b) only the diminishing-returns reset, the meter stays where it is (a pure bonus); (c) as (a)
   and it also takes one drink off the drunk count.
5. **WASTED title** (card: `7-wasted-screen`, `7-wasted-screen-th`): kept in capitals in Kristi as Daniele wrote it,
   although the Kristi call (title case for zone names) recommends title case for the script. (a, **rec**) keep
   "WASTED" in capitals; (b) "Wasted" in title case like the zone names; (c) capitals in Lato Black, Kristi only for
   the line. Information, no call: Nam no longer refuses alcohol at Merry (she warns from 8), otherwise 10 drinks
   could never be reached.

## Open / follow-ups
- Drunk is only visual (no wobbly walk): movement lives in `player.gd`, owned by feel-pass. A follow-up could add
  a small steering wobble there, or use the rig's fx hook once it is committed.
- Thai lines are drafts for a native read.
- `menu_list.gd` still has its `merry` parameter (now always false); remove when someone next owns it.
- 06-stakes §7 annoyances (Thirsty at Drinks < 10) will fire right after Check the plumbing and after WASTED once
  they are built; that is intended ("ready to drink all over"), but worth a look when the stakes build lands.
