# 🏗️ Venue entrance round: role note (2026-11-20, state now)

Worker: map-builder (Opus 5.5), load id 2026-11-20-map-builder-black-cabin-251106, briefed by orchestrator
local_5352afaa. Branch `wk/venue-entrance`, worktree `C:/Users/itisf/bc-wt/venue-entrance`. Report:
`handoffs/worker-reports-2026-11/venue-entrance.md`. Hub card `venue-entrance-review` (order 410).

## State now and next step: read this first
- Successor (map-builder, load id 2026-11-20-map-builder-black-cabin-b7c402) built Daniele's corrections 1-6 (see the
  HANDOVER list at the end) on `wk/venue-entrance`, rebased on origin/main; not pushed (the Verifier pushes). The review
  file `blender/BlackCabin-entrance-review.blend` (10 cameras, near walls shown, two-tone walls) was reopened on his
  screen 2026-11-20. Hub card `venue-entrance-review` carries the round-2 pictures (photo | game pairs).
- Next: his answer on the card / chat. Same places to edit: `game/tools/build_venue.gd` (`_entrance_room`,
  `_memory_corner`, `_curtain_corner`, `_sticker_door_lounge`, `_merch_shop`), then `tools/blender/bc_review.py` +
  `bc_entrance_review.py` for the review file.
- Merge script for layout.json own lines (round 2): the successor's report lists the name regex; the method is
  export to a copy, take only own names (others' drift in the export: Mic0, PedalboardGtr, CurtainBack*, Backdrop*,
  ElectricPiano, PatronsBoardMonth, Bay4, ReindeerHead, Band_Guitar/Keys — never merge those).
- Round 3 (Daniele 18:05-18:20: table centred in front of the street door, stray props in the Blender corridor, darker,
  grey floor, the red curtain = buffer entrance) is built too: lights cut to 42 (MerchLight, ArcadeGlow, StickerDoorLight,
  BoothLight, LongTableLightB gone; corridor/red lamp/eagle lamp/red panels lower), CurtainBufferLounge pair, review
  file: KIT lineup and FONT labels hidden, textured floors grey (TEXTURED_BASE), exposure -1. Card v3.
- Open questions (for Daniele, not blocking): (a) QR codes LoungeTable0/1 (`docs/venue/qr/codes.json`,
  `supabase/seed/venue_tables.sql`) now name tables that are gone from the game: reassign one to CornerTable or retire
  them (presence role); (b) the arcade on its stand by the Sticker door is dressing only (the game machine stays
  GameCabinet by the stairs): should it be playable?; (c) the high counter was shortened to 1.1 m to fit the arcade.

## Owner words (all 2026-11-20, chat)
- "new round of venue picture this time we improve entrance entrance corridor and if needed lounge have a look, a thing
  the eagle on the table at the entrance should be the one greeting you and sending the entrance message as a chat
  bubble instead of as a popup also modify the scene layout and decor to fit it, create any new prop you need also theres
  the pic of the door with the stickers"
- "open in my blender how it would look before pushing live when you done with props and scene"
- "also make sure walls color and floor of entrance and corridor are same as in the reality also lounge"
- Three photos in chat: the L's corner from the eagle side, the corner towards the eagle entrance (a door with an exit
  light between the eagle room and the marble stretch), the Sticker door. Same shots as photos 15, 01, 06 in the folder.

## What is where
- Photos: `docs/venue/photos/2026-11-20-entrance-round/01..15`. Layout facts: the lobby strip (x 0-2.15, z 5.05-14.9)
  = eagle room (north, street door west, table on the north wall) | door (z 8.4) | marble stretch + red lamp | concrete
  | poster booth in the SW corner where the corridor ends; corridor east to the brick end wall and the Sticker door.
- New kit: entrance_table, eagle_greeter (group "entrance_greeter"), brass_lamp, pdpa_sign, fire_extinguisher,
  red_floor_lamp, poster_bc / poster_foil, booth_table, charging_kiosk; sticker_door redone (front -y = corridor).
- Mural: `tools/venue_mural.py` → `game/assets/venue/corridor_mural.png`, a quad on the lounge wall's corridor face with
  the lounge wall's cut_rooms (hidden with that wall in lounge views, standing in corridor views).
- Walls: `_two_tone_mat` (the north-wall shader, generalised): `lobby_plaster` (PLASTER_TOP / PLASTER_DAMP below 0.9 m)
  for the lobby and corridor, `lounge_wainscot` (LOUNGE_TOP over a dark wainscot, red LED line at 0.9 m) for the lounge.
- Bubble: `game/scenes/ui/eagle_bubble.gd`; `venue_session.gd` `_greet()` emits `door_greeting(line)` (no action card);
  `main.gd` shows it once nothing blocks (`_door_line`), `greet_at_door()` for tests/captures. Strings
  `venue.eagle.name|welcome|welcome_anon` in `strings_venue.csv` (TH machine drafts).

## Gotchas
- Player spawn is x 1.12 (main.tscn): the eagle table now stands at x 1.53-2.13 and the exit zone ends at x 0.96.
- High counter stools 0.8 m apart: at 0.6 the HighCounter seat zone shrank past the navmesh and smoke_doors_sit failed.
- bc_review puts west/south-facing cutaway walls in "VENUE ceiling and near walls" (excluded for the overview); the
  entrance review re-includes it and excludes the KIT lineup (it stands inside the lounge).
- The eagle-room door must be DOOR_W (1.2 m): at 0.96 m the navmesh (agent radius 0.4) closed it and smoke_tap failed.
- Its wall pieces carry `cut_sight_only`: from the south (lobby camera looks north) the wall stands; it is cut only
  when it hides the player. The cut normal BACK alone would hide it in every lobby view.
- The bubble's `avoid` is `hud.prompt.pill` (the prompt Control itself is full screen). Portrait: the bubble overlaps
  the top area buttons for its 6 s; it ignores the mouse so they stay usable.
- layout.json is still merged by hand (card look-followups-layout-export open): export to a copy, take only own names.
  Own entries: Booth*, Eagle*, ExitSignBooth, ExitSignEagleRoom, FireExtinguisher, PdpaSignLobby, RedFloorLamp,
  ChargingKiosk; removed RegularPictureW0/1.
- Never `taskkill /IM Godot...`: it kills other sessions' Godot too (I did once, 17:25; see report).

## Re-running
From game/: `--import`, `--script res://tools/build_venue.gd`; captures on the hidden desktop (`hd.ps1`):
`--path . --script res://tests/capture_entrance.gd -- --tag=portrait|landscape --out=res://../docs/art/screens/venue-entrance/after`.
Kit: `blender --background --factory-startup --python tools/blender/bc_kit.py`. Review: `bc_review.py -- --no-render`,
then `bc_entrance_review.py`; open with `blender blender/BlackCabin-entrance-review.blend --python
tools/blender/bc_entrance_review.py -- --view`.

## HANDOVER at 44 % context (2026-11-20 ~17:45): Daniele's corrections, NOT yet built (successor does them)
Daniele, chat, verbatim: "some error so you enter form main door (like now in our game and the eagle lobby is waht you
see pic 1 2 and 5 / pic 2 i attached is if you stay left to the eagle and look right you see the door to the corridor /
you pass the door and you see the corner of the L (pic 3) / pic 4 is from the corner you look back / pic 6 is from end
of the corridor (where theres the black cabin neon and the sticker door on the left of it) and look back towards the L
corner / pic 7 and 8 are the murales on the left wall of the corridor (opposed to our patrons frames) / pic 9 is the
share a memory corner in real life / pic 10 is the view from inside the lounge of the corridor door (the sticker door)
/ pic 11 is where now we have our merch stand, i want this part to remade like this remove the 2 tables from lounge and
move the merch booth at the center of the room so players can walk around it"
and: "also the blender has many invisible walls not sure if they invisible or errors".
His pics map to folder photos: 1=12, 2=13, 3=15, 4=01, 5=14, 6=05, 7=03, 8=04, 9=09, 10=07, 11=08.
To do:
1. Eagle room: you enter by the street door (as now) into the eagle room (photos 12, 13, 14). From LEFT of the eagle
   looking RIGHT you see the door to the corridor (13): the door is beside the table, not across the room. Re-place the
   table and/or the door in `_entrance_room` so photo 13 reads; keep the door DOOR_W (1.2 m) or smoke_tap fails.
2. Mural stays on the corridor's north wall (opposite the portraits): already right.
3. Memory corner (`_memory_corner`) to look like photo 09: CRT on a counter with a plant, the BLACK CABIN sign on a
   stand, two low stools, the orange disc lamp, the kiosk on its right, posters on the wall.
4. Lounge side of the Sticker door (photo 07): merch rack (tee, shelf, lamp, frames over it) on its left, the arcade
   cabinet on a stand with a mirror on its right, exit sign over the door.
5. Merch corner (photo 08, where the merch stand is now, NE): remake like the photo (table with chairs and a lamp,
   curtains, the BLACK CABIN frame, shelves on the left); REMOVE the two round lounge tables (LoungeTable0/1, their
   seats and LoungeTablesLight) and MOVE the merch stand (MerchStand, zone "merch") to the centre of the room, walkable
   all round. layout.json: own lines only (+ / − these names). Check test_lounge, test_seats, smoke_loop (seat counts!).
6. Blender "invisible walls": bc_review.py builds tscn greybox materials from StandardMaterial colours; the walls now
   use ShaderMaterial (`_two_tone_mat`), so they come out invisible/odd. Fix bc_review's material parse for shader
   materials (use top_col) and regenerate both review files; reopen for Daniele (he asked to see it in Blender before
   anything goes live).
Then: captures again, all 30 suites, card venue-entrance-review updated (pictures + note of the changes), report,
capture(report), final message. Suites at handover: a run was in progress (/c/Users/itisf/bc-wt/ve-suites/summary.txt).
