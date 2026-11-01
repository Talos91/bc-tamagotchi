# Art direction (from Daniele, 2026-10-27)

Three voxel renders that set the visual target. The art bible must match
these, not the other way round.

- `01-main-room-from-entrance.webp` — main room looking toward the stage:
  long communal table and round candlelit tables on the left, bar with
  backlit bottle shelves on the right, red curtain wall and slatted red
  backdrop behind the stage, drum kit, mics, disco ball, track lights.
- `02-entrance-lounge.webp` — the entrance room: red neon "BLACK CABIN"
  sign on a plant wall, red-lit black ceiling beams, white columns, long
  table with candle lamps, vending/arcade cabinet, shelf of objects, stairs
  up on the left. **The red curtain on the right is the way into the main
  room.**
- `03-main-room-from-bar.webp` — main room from the bar end: bar on the
  left, round tables and black drum-stools in the middle, red carpeted stage
  on the right with drums, guitar, mics, amps; red curtains behind.

Layout: entrance lounge → curtain → main room. The main room sits on the
right-hand side of the main bar. **Standing in the main room where you enter
through the curtain: the stage is on the left, the bar runs along the right,
the round tables and the communal table fill the back.** Renders 01–03 are
accurate to the real place and are the ONLY layout source. Render 04 is never
used for layout (Daniele, 2026-10-28: "those [01–03] were accurate of how the
place actually looks").

- `04-overall-look-mockup.webp` (added later on 2026-10-27) — Daniele's
  direction for the overall game look: isometric whole-room view, chibi voxel
  patrons with hair and faces, a live band, need bubbles over heads, a dark
  HUD with glyph icons. **The map is not correct; it is a look reference
  only.** Its HUD (Mood / Energy / Tidiness, coins, Serve / Chat / Music /
  Clean / Decor) is a mockup, not the agreed design; see DECISIONS.md.

## Quality bar (2026-10-28)

- `05-main-room-iso-from-entrance.webp` and `06-main-room-iso-from-bar.webp`
  are two near-accurate isometric voxel renders of the real main room, with
  patrons, band and staff. Daniele: "our game should look and feel exactly
  like this … we not settling for anything less than something looking like
  this." They are the acceptance target for the venue, kit, lighting and
  characters. The current build is "clunky, less detailed and doesn't respect
  proportion nor layout" by comparison. Every visual session compares its
  output side by side with these at matched camera angles before reporting.
- What they show: stage on the left with red carpet, slatted glowing backdrop,
  curtains, truss PARs, drums, guitars, amps, tree; drum-stool poufs in rows in
  front of the stage; round tables with candle lamps and seated patrons in the
  middle; a long communal table with many lamps at the front-left; the bar on
  the right with a bartender, backlit bottle cubbies, stools; a disco ball;
  cyan exit signs; dense, warm, glossy floor; characters with hair, clothes,
  glasses in hand, a server carrying a tray.

## Real-place photo (2026-10-28)

- `07-main-room-photo-from-bar-end.webp` — a real photograph of the main
  room taken from the bar end, looking toward the stage. Daniele's two
  layout corrections from it, after parity iteration 8:
  1. **The entrance lounge faces the wrong way.** Rotate the lounge 90°
     to the left so the curtain into the main room is on the opposite side
     of the lounge from the stairs (as render 02 shows: stairs left,
     curtain right).
  2. **The stage does not reach the end wall.** The stage ends before the
     end of the room. The whole end wall is a line of tables, and between
     that line and the stage there are more drum stools with short tables.
  Graphic target unchanged: as close as possible to 05/06. Iteration 8 was
  judged "too empty and not crisp".

## Real floor map and room photos (2026-11-01) — the baseline-map source

Daniele drew `08-floor-map-real.png` after the alpha and supplied photos 09–16. This map supersedes photo 07's two
corrections and the frozen `layout.json`: the baseline-map fix (BACKLOG A1) rebuilds the venue from it. Not to scale
until Daniele confirms a measurement.

Legend, in Daniele's words:
- Green rooms are not in the game, or at most visible but never walkable: they are NPC spawns (backstage = band,
  kitchen = staff, "BAR walled area" = staff, old toilets unused).
- Light blue squares = tall tables with two tall stools each (four in the buffer zone, two at the main room's west
  opening).
- Black squares, rectangles and circles = normal tables, four chairs each.
- Gold circles = tiny tables, two tiny stools each (row of six below the stage, three right of it).
- The tables on the right (east) of the main room sit on a raised area, with a wall-long couch on the east wall and
  chairs on the other side; shelves on the wall above the couch; mirrored ceiling panels (photo 11).
- The stage is at floor level, delimited by carpets, against the north wall with backstage behind it (staff door).
- Green circles = counter stools at the bar; the cashier area bumps out of the bar counter; a mounted reindeer head
  hangs over the cashier (photo 16).
- Entrance (spawn) is the lobby at the far west; an entrance corridor runs along the south of the lounge to the
  Sticker door (the achievements door); stairs in the lounge's south-west corner. Curtains close both ends of the
  buffer zone and the kitchen corridor.

Photos: 09 bar from the west end (red-lit back bar, pillars, cashier bump, ribbed-glass bar top); 10 the corridor to
the toilets with the kitchen curtain (concrete, picture light, vinyl on the wall); 11 the raised east side: couch,
round tables, shelf wall, mirror ceiling, bare tree in the far corner; 12 the smoke-room door and the south-east
corner (Black Cabin light box, wine fridge, curtain); 13 the smoking room (glass wall to the street, wooden tables,
ashtrays, EXIT signs); 14 the buffer zone's south side (mirror wall, red curtains, two tall tables, PAR on a stand);
15 the buffer zone's north side (full-height window wall); 16 the reindeer head over the cashier, red back bar.

### Answers from Daniele (2026-11-01) — binding for the rebuild

- Scale: no measured plan. Main room is roughly **30 × 15 m**; scale the whole map from that.
- Player route (`17-floor-map-player-route.webp`, red line): spawn in the west entrance lobby → entrance corridor
  along the south of the lounge → **Sticker door** → north up the old toilet corridor into the lounge's east end /
  buffer zone → through the curtains into the main room → the bar → the smoke-room door. Keep that corridor dimly lit
  for now; real photos later.
- Lounge: keep the current furniture (plant wall, neon, banquette, long table). The real lounge changes often and has
  no bookable tables, so we are free there. Add a **game machine** (Black Cabin–themed flappy-bird style game) next to
  the stairs near the sticker door, and put the **pinball on the west wall**.
- Raised area (`18`): about **15 cm**, a neon strip under its edge; only the yellow strip with the couch and round
  tables is raised. The south-east corner by the smoke-room door is at floor level.
- Tree (`19`): a bare tree to the **right of the stage**, between stage and raised area, next to the tiny tables.
- Curtains are open all night (lounge–buffer, buffer–main, kitchen corridor).
- Smoking room (`20`, `21`): the **red door** opens to the main venue, the dark door is an emergency exit. Windows look
  outside; it is **night** outside (a day version maybe later).
- Buffer zone (`22`): the north wall is a window that looks outside; put a tree outside it.
- Columns: none in the main room; only the two in the lounge where the map shows them. The pillars at the back bar are
  part of the bar joinery.
