# 🎮 Area camera: role note (2026-11-02, state now)

Worker: gameplay (Opus), briefed by the orchestrator local_78d0c67d after Daniele's Questions-tab answers of
2026-11-01 20:37–22:14 (DECISIONS row "Questions tab, answered 2026-11-01"): "why you decided to remove the focus
camera? actually those are fundamental as for quick navigation mobile you just press the area button your character
walks there and scene focus there also make sure smoking room is now correctly visible", and "version label: make it
bigger". Builds on the feel pass (45a6dbf, `handoffs/feel-pass-2026-11-02.md`). Commit: see the end of this note.

## What changed

1. **A view per area again** (`camera_rig.gd`, zone data in `build_venue.gd`). Floor looks east (the feel pass's wide
   clamp, so the corner tables stay in frame), bar south, toilets corridor south, stage north, smoking room south, as
   before 45a6dbf (95c710b's yaws; stage clamp reaches the front row now, so the player is no longer at the screen's
   bottom edge). The feel pass's good parts stay: critically damped follow, velocity lead, walls sinking to a 0.4 m
   stub, movement, facing, seats, the `fx_offset / fx_tilt / fx_fov_scale` hook (unchanged).
   - **No wild swings.** `zone` (where the player is: HUD title, band earshot, arrival bonus) and `view` (the framing
     used) are separate. Inside one room (`ROOMS`: floor, bar, stage, toilets, smoking = "main") a new area takes over
     only after `ZONE_DWELL` 0.3 s, so brushing an edge or cutting a corner never turns the view; across a door it
     changes at once, as before. Yaw, pitch and distance settle 95 % in `swing_time` 1.0 s plus
     `SWING_PER_HALF_TURN` 0.4 s for a 180° turn (stage ↔ bar is one even 1.4 s orbit, peak ~230°/s). Spring times
     are now "95 % settled" (`SETTLE_95`); the feel pass's 0.6 s spring took ~1.4 s to 95 %, so door turns are a little
     quicker than before.
   - The bar's area starts 1.2 m east of the counter's west end, so the south-west corner by the west opening keeps
     the floor's view (its tall tables stay in frame; feel-pass check).
2. **Area buttons** (`needs_hud.gd` `AREAS`, `main.gd` `walk_to_area`). The four walk-hint chips (Bar, Stage, Prae's
   table, Pinball) became seven area buttons: Lounge (→ pinball), Buffer (→ a tall table), Floor (→ Table2, the middle round table of the row of five; Prae
   no longer has a fixed table after the cast pass 92c0a27),
   Stage, Bar, Toilets, Smoking. A tap: `CameraRig.focus_on(area)` turns the view to that area at once (anywhere in
   the area's room; from another room at the threshold into it), the look point follows the player unclamped so they
   stay on screen the whole walk, the walk ends inside the area (each target is a zone whose approach is inside the
   area's camera rect; `main.ARRIVE_SLACK` still opens its sheet), `release_focus()` adopts the area at once on
   arrival (no dwell, no turn away and back) and the camera settles on the area's clamp. The sheet opens on arrival,
   as the old chips did. A stick or tap cancels the walk and the focus. The button of the area you are in is dimmed
   (the column never shifts); the lowest need's area keeps the colour edge. 96 × 42 dp, 6 dp apart: seven fit between
   the top bar and the prompt in portrait. Not given a button: the entrance (Leave covers it) and the old-corridor
   alcove (nothing to do there). `walk_to_kind` stays (smoke_tap's regular's-table check). The old `venue.hint.*` strings are now unused. Strings `venue.area.*` (EN +
   machine Thai) in `strings_venue.csv`.
3. **Smoking room visible.** Before: from the main room the view looked east and the room was off frame behind the
   south-east wall; inside, the clamp was a point, the open red door's leaf stood in front of the camera (its cutaway
   box was the shut door's, computed once) and the wine fridge with the light box hid the player in the north-east
   corner. Now: the smoking view takes over in front of the door (its rect reaches north to the raised strip and west
   to the bar's east end), looks south at pitch −40 through the main room's south-east wall and red door (zone meta
   `see_through`: pieces standing on that strip are cut while that view is on), clamps over the whole narrow room;
   swing doors are tested with their box as they stand each frame; pieces without a stub (kit pieces, doors) hide at
   once instead of after 0.09 s; the wine fridge and the light box are cutaway pieces (hidden only on the sight line).
4. **Version label bigger** (`version_info.gd`): 13 dp (was 9), SMOKE at 85 % (was ASH at 70 %).

## Zone-data edits in `build_venue.gd` (for the lounge-revamp worker)

Only `_camera_zones()` rows bar, stage, toilets, smoking (and its comment), plus two lines in `_main_room()` that wrap
`WineFridge` and `LightboxBC` in `_cut(..., Vector3.ZERO)`. Nothing in the lounge or corridor. `venue.tscn`
regenerated (the diff is mostly random `unique_id`s). `layout.json` untouched.

## Tests

- `test_feel.gd`: the "main room never turns" check is replaced by: floor → stage → bar → toilets each settles on its
  own yaw, no spin faster than 260°/s, no camera step over 0.3 m per frame; a step into the bar and back within the
  dwell keeps the floor view. New: every area button from the middle of the main room (walk ends inside the area, its
  sheet opens, player on screen every frame, no jumps, settled on the area's yaw/pitch/distance with the look point in
  its clamp); the smoking room from three main-room spots (smoking view, player and all four tables in sight) and five
  inside spots (player in sight, no standing wall between), and three walks through the red door (never behind a wall
  or the leaf). 84 checks.
- All 13 suites PASS (smoke_stairs, smoke_tap, smoke_hud, test_needs, test_minigames, smoke_loop, smoke_doors_sit,
  smoke_start, test_menu, smoke_version, test_nightlife, test_seats, test_feel) on f3f3bc8 (after the cast pass) plus
  these files, in an isolated copy (`git archive HEAD game tools docs/venue`, venue rebuilt, imported) with APPDATA
  pointed at an empty folder per suite. test_menu reads `docs/venue/menu/` from outside `game/`, so an isolated copy
  needs that folder too.

## Captures (`docs/art/screens/area-camera/`)

`<portrait|landscape>-area-<id>.png` (each button pressed from the middle of the main room, sheet closed, settled),
`-smoking-out-{west,door,ne}.png`, `-smoking-in-{middle,nw,ne,sw,se}.png`, `-version.png` (the label, 3×). Before |
after: `twoup-portrait-smoking-{out-door,out-ne,out-west,in-nw,in-ne,in-middle}.jpg` (before = 20c6ad3 at 540×960).
Best for a Questions-tab card: `twoup-portrait-smoking-out-door.jpg`, `twoup-portrait-smoking-in-nw.jpg`,
`portrait-area-stage.png`, `portrait-area-bar.png`, `portrait-version.png`. Landscape: the toilets view shows the void
past the venue's west edge on the right half (portrait is fine); mobile is portrait first, left as is. Script `game/tests/capture_areas.gd`.

## Open / for later

- The lounge camera still looks west; the lounge revamp may want its own areas (merch, memory corner, leaderboard):
  add rows to `_camera_zones()`, a room entry in `CameraRig.ROOMS` if they share a room, and a row in `AREAS`.
- Thai labels of the area buttons are machine drafts.
- In front of the red door (the smoking view's strip of main room) the HUD title already reads "Smoking Room" and the
  band is out of earshot there (it was floor); small, left as is.
- Open questions for the Questions tab: see the report.
