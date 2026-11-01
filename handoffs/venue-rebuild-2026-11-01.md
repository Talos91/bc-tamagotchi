# 🏗️ Venue rebuild to the real floor map — state 2026-11-01

## Done (on main)

- `78c55ef` plan v4: `docs/art/plan-v4.md`, data `game/tools/plan_v4.py`, diagram `docs/art/screens/plan/plan-v4.png`
  (`python game/tools/plan_view.py <png> --planned`; without the flag it draws `layout.json`, → `plan-v4-built.png`).
- `228eb2e` + the evidence commit after it: `game/tools/build_venue.gd` rewritten for plan v4 with Daniele's corrections,
  `layout.json` regenerated (706 kit instances, 142 spawns), zones, navmesh, strings, tests, captures.
- Scale: one factor from the map, main room 21.7 × 15 m (Daniele: keep). `S` in `plan_v4.py` is the one place to change;
  `build_venue.gd` constants are transcribed from it by hand (no code link), so change both.

## Rooms and kit
- Every kit v4 object is instanced by manifest name through `_ph()` (box fallback if a name is missing; none is now).
  Doors sit in gaps `_wall_x/_wall_z` leave; door rotation puts the kit's room side (+z) toward the walkable room.
- Closed rooms (backstage, kitchen, toilets, old toilets) are dark boxes behind closed doors. The bar staff room is a
  real room (walls, floor without collider, light, shelf) behind the staff door and the half wall for orders.
- NPC spawn markers: `Spawn_Backstage`, `Spawn_Kitchen`, `Spawn_StaffArea` (pose `spawn`, exported as `NPC_SPAWN`).
  Nothing spawns from them yet; `venue_patrons.gd` ignores `spawn` and `stand` poses.

## Zones (`game/scripts/zones/venue_zones.gd`)
- bar, stage (from carpet tiles; the stage is floor level), table (round tables of Tables/Raised/Lounge, Mali = Table2),
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
- Look: the back bar glows amber (kit `back_bar_shelf` emissive); photos 09/16 are red. Needs a red variant from the
  kit session or a material override. The smoking room is lit warm; photo 20 is cool teal.
- Staff figures behind the half wall and band/staff walking out of their spawns need `venue_patrons.gd` work.
- The old-corridor alcove has no camera zone of its own (keeps the lounge framing).
- Real photos of the L corridor; framed pictures of regulars to replace the placeholders.
- `layout.json` refreezes when Daniele accepts the room.
