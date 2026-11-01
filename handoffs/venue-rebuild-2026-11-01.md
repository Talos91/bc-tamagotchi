# 🏗️ Venue rebuild to the real floor map — state 2026-11-01

## Done (on main)

- `78c55ef` plan v4: `docs/art/plan-v4.md`, data `game/tools/plan_v4.py`, diagram `docs/art/screens/plan/plan-v4.png`
  (`python game/tools/plan_view.py <png> --planned`; without the flag it draws `layout.json`, → `plan-v4-built.png`).
- `228eb2e` + the evidence commit after it: `game/tools/build_venue.gd` rewritten for plan v4 with Daniele's corrections,
  `layout.json` regenerated (706 kit instances, 142 spawns), zones, navmesh, strings, tests, captures.
- Scale: one factor from the map, main room 21.7 × 15 m (Daniele: keep). `S` in `plan_v4.py` is the one place to change;
  `build_venue.gd` constants are transcribed from it by hand (no code link), so change both.

- `daf76b6` corrections: order hatch beside the staff door, smoke door, camera zones, seat facings, captures, two-ups.
- `68d9ff5` + `4cb4bf3` fix round: red back bar and dull shelves recoloured at load (`game/scenes/venue/venue_looks.gd`,
  groups `look_red_bar`, `look_shelf_dull`), cool smoking room, staff figure behind the hatch; camera sight-line
  cutaway (`camera_rig.gd`: any `cutaway` piece crossing camera → player feet/chest/head hides; closed rooms and the
  stair bulkhead have cut_normal ZERO); held-input latch (`player.gd` `_move_yaw`, tests use `p.world_to_input`);
  Mali → **Prae** / แพร in display strings (id stays `mali`).
- Playtest notes round (venue-notes session, this file's last update): walk-through doors, real seats, the turned
  stair, Prae leftovers, alcove camera; see "Doors, seats, stair" below.

## Doors, seats, stair (Daniele's v4 playtest notes)
- **Doors** (`build_venue.gd` `_swing_door`, runtime `game/scenes/venue/venue_doors.gd`): a hinge pivot (group
  `swing_door`, metas `center`, `users`) holds the kit door as its leaf (`<Name>Leaf`; frame and leaf are one kit
  mesh, so the whole piece swings; openings are 1.2 m, the 1 m kit leaf is stretched ×1.2). No leaf collider, so the
  navmesh runs through. Opens within 1.2 m of anyone in group `door_user` (player, wanderers, a patron who gives up a
  seat), swings away from them in 0.25 s, closes 0.6 s after they leave. Walk-through: StreetDoor (lobby west wall,
  kit `staff_door` as a dark wooden leaf; no photo of the real one), StickerDoor, RedDoor. StaffDoorBar opens only
  for `staff_door_user` (the hatch staff walks out through it and back, `venue_patrons.gd` `_run_errand`) and has a
  blocker collider in its opening. Emergency, toilet, old-toilet, backstage and kitchen doors stay static and solid.
  A 1.6 m step of night street outside the street door (invisible kerbs); the exit zone and the lobby camera reach it.
- **Seats**: every `sit` spot has metas `table` (its table's kit name, "Bar" for counter stools) and `couch`, and
  is in group `seat`. `VenueSession.find_seat(zone)` picks the player's seat (theirs, else the nearest free one, else
  the nearest taken one whose patron `vacate()`s and wanders off); `Player.sit_at(seat)` walks there and, within
  1 m (or where the walk ends, within 1.6 m), snaps onto the spot facing its yaw, figure lowered like the patrons
  (`seat_h - SEAT_H * FIG_SCALE`), pose `sit_drink` (`sit_hold` on couches and the lounge counter). Stick / key input
  or any walk stands them up where they were. The minute counts only while seated; rules unchanged (`sit_with`).
  Bar: new row "Take a stool" (seat only, no need effect). Raised-strip seats: `seat_h` fixed to 0.45 above the
  strip (was 0.6, so patrons sat 15 cm high there).
- **Stair**: first flight along the lounge south wall, foot at x 8.05 facing the game machine (moved to x 10.3), up
  west to a 1.6 m landing in the SW corner; second flight turns right (north) along the west wall to 4.0 m under a
  dark bulkhead (the floor above, cut away on the sight line). Solid convex wedges carry walking and the navmesh;
  rail colliders on the open sides; a velvet rope and a blocker at z 10.05 (y ≈ 2.47) stop the player. Constants
  `STAIR_*` in `build_venue.gd` (not in `plan_v4.py`).
- **Camera**: zone `alcove` (old corridor off the lounge) looks south over the old toilets' closed box; lobby zone
  widened to x −2 for the street step.
- Test `game/tests/smoke_doors_sit.gd`: navmesh through the three doors, each swings open while walked through and
  closes, staff door stays shut and solid, seated at Prae's table / a raised couch / a tall stool / a bar stool (spot,
  facing, height, pose), the minute refills Friends, stick stands up, stair to the landing and up to the rope,
  cabinet reachable. `smoke_loop` now waits for the player to be seated before the minute.

- Commits: `4452080` Prae leftovers (cast, GDD, stakes, chars manifest, showcase), `676a6a8` doors / seats / stair /
  alcove / test, then captures + docs. Captures `docs/art/screens/v4/<orientation>-{door-sticker,door-red,sit-table,
  sit-couch,sit-bar}[-close].png`, `-stair-top`, `-stair-eye`, `-neon-edge`, `-alcove`, `-alcove-walk`.
- Numbers this round: 42 lights, 1 shadow map. Floor view 1080×1920: 3,042 draw calls (HEAD before: 3,032); GPU
  7.9–8.2 ms new vs 7.4–8.3 ms for the previous venue measured back to back the same hour (the 6.3 ms of the last
  round did not reproduce on this laptop today; no measurable difference between the two scenes).
- Neon edge under the raised strip: a thin glowing line along the riser, reads warm amber more than red in
  `landscape-neon-edge.png`.

## Rooms and kit
- Every kit v4 object is instanced by manifest name through `_ph()` (box fallback if a name is missing; none is now).
  Doors sit in gaps `_wall_x/_wall_z` leave; door rotation puts the kit's room side (+z) toward the walkable room.
- Closed rooms (backstage, kitchen, toilets, old toilets) are dark boxes behind closed doors. The bar staff room is a
  real room (walls, floor without collider, light, shelf) behind the staff door and the half wall for orders.
- NPC spawn markers: `Spawn_Backstage`, `Spawn_Kitchen`, `Spawn_StaffArea` (pose `spawn`, exported as `NPC_SPAWN`).
  Nothing spawns from them yet; `venue_patrons.gd` ignores `spawn` and `stand` poses.

## Zones (`game/scripts/zones/venue_zones.gd`)
- bar, stage (from carpet tiles; the stage is floor level), table (round tables of Tables/Raised/Lounge, Prae, id mali = Table2),
  arcade (pinball on the lounge west wall; zone = floor in front of it), exit (street door, lobby west wall).
- Stubs with the generic "Sit here a while" row: `cabinet` (game_cabinet_bc), `tall` (every tall table), `smoking`.
  Strings EN+TH (machine-draft Thai) in `strings_venue.csv`: zone names lobby/corridor/buffer/toilets/smoking,
  prompts and sheet headers for the stubs. HUD walk-hint chips are unchanged (bar, stage, table, arcade).
- The +5 lounge arrival bonus now also lands in the lobby/corridor camera zones (`venue_session.gd`), keeping the
  provisional call "lands on arrival" now that the street door opens into the lobby.
- The bar counter strip is reachable (the open floor in front of the stools); approach 1.6 m from the counter line.

## Edits outside the venue paths (approved by the orchestrator)
- `game/scenes/main.tscn`: player transform → lobby (1.2, 0.1, 7.2) facing east.
- `game/scripts/venue_patrons.gd`: `SEAT_ZONES` → Tables, Bar, Lounge, Buffer, Raised, Smoking.
- `game/tests/smoke_stairs.gd`: route lobby → corridor → Sticker door → buffer → main → raised strip (+15 cm).
- `game/tests/smoke_tap.gd`: goals floor, bar, stage, smoking, lounge; seated zones ≥ 4 (was == 4).
- Also mine: `game/tools/measure_shadows.gd` floor-view position, `capture_venue.gd` shots, `capture_plan.gd` framings,
  `photo_twoup.py` (new), `export_layout.gd` slots.

## Numbers (this desktop, not a phone)
- 42 lights, 1 shadow map. Floor view 1080×1920 (`measure_shadows.gd`): 3,046 draw calls, 6.2 ms GPU, 96 fps; iteration 18
  was 3,026 / 24.0 ms / 32 fps. Draw calls +0.7 %, GPU time about a quarter. Heaviest gameplay view is still the floor.
- Seat yaw convention: 0 faces +z (south). Daniele spotted couch patrons facing the wall; couch, raised chairs, tiny-table
  stools and smoking chairs were all turned and are fixed.

## Open / for later
- Band and kitchen staff walking out of their spawns (only the hatch staff uses a door so far).
- Tiny tables (drum stools) are not zones, so the player cannot sit there yet; the long table and the lounge
  counter neither.
- Real photos of the L corridor; framed pictures of regulars to replace the placeholders.
- `layout.json` refreezes when Daniele accepts the room.
