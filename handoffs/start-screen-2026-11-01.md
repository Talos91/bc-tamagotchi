# 🎬 Start screen: the club's front door (BACKLOG B8) — state 2026-11-02

Daniele's words: "when you start the game the menu should be a still camera as if first person of you staring on the
entrance of the club from outside with a camera on the door on which a Black Cabin neon lit sign is; you tap to
enter, door opens, your character walks in with camera following his point of view and then once in, door closes,
camera zooms out to current one and game starts."

## What is built (on main)
- **Street front** `game/scenes/street/street_front.gd` (script only, built in code at runtime; no `.tscn`). Placed
  from the venue's `StreetDoor` meta `center`, so it follows the door if the venue session moves it. Black-painted
  two-floor front with a parapet; the door cut out of it with dark jambs and a sill; a black sign board above the
  door carrying the **kit `neon_sign`** (BLACK over CABIN, red voxel tubes, the lounge's sign at ×1.5, emission ×3
  so it blooms); a small lit menu box beside the door; upper floor: one dark window, one lit behind a red blind,
  a wall AC unit, a drainpipe. Neighbours: a taller grey shophouse north with a roller shutter and lit windows,
  a low shop south with a shutter. Ground: pavement (around build_venue.gd's own 1.6 m `StreetStep`, not over it),
  kerb, a 2.4 m soi with lane marks, the far kerb and a strip of opposite pavement up to build_venue.gd's
  `StreetFacade` box across the street. Dressing: concrete utility pole with a sodium streetlight on an arm, the
  Bangkok cable bundle sagging along the street, a transformer; a potted palm by the door; a parked cream
  step-through scooter. Sky = the venue environment's NIGHT_SKY colour (no stars, no moon).
  **Two lights** (`NeonWash` red omni, `Streetlight` sodium omni): 44 on the start screen (max_renderable 48),
  42 once inside (the street and both lights are hidden when the pull-back starts; node `Main/Street` stays,
  hidden). No colliders: nothing there is walked on except the venue's own step.
- **Start screen and entry** `game/scripts/start_screen.gd`, started from `game/scripts/main.gd`:
  - Title: still camera at eye height (1.6 m) on the opposite pavement, ~4.8 m from the facade, pitched up
    (portrait 62° horizontal FOV, +13°: facade to the cables and the dark sky; landscape 54° vertical, +9°: door,
    sign, upper windows). Title "BLACK CABIN" (Kanit Bold, LabelDisplayXL, cream with a red glow) near the top,
    "Tap to enter" (Kanit SemiBold, gold, slow pulse) near the bottom, soft dark gradients behind both. Strings
    `venue.start.title`, `venue.start.tap` in `game/i18n/strings_venue.csv` (EN + machine-draft TH
    "แตะเพื่อเข้าร้าน"; the title stays Latin in Thai). F8 swaps the language on the title.
  - Tap / click / Enter / Space / E: the title fades; the character (hidden until now, under the camera) walks
    6.6 m from behind the camera to the lobby spawn in 3.3 s (about 2.4 m/s, eased in and out; physics off, position driven, walk
    animation from the figure); the street door opens by its own proximity rule (venue_doors.gd, unchanged); the
    camera follows 1.3 m behind and 0.3 m right (over the shoulder), at 1.75 m, tilting from looking up at the sign
    to slightly down, closing to 0.6 m behind and centred once through the door. Then a 1.7 s pull-back: up first,
    then back, always looking at the character, ending exactly on the diorama rig's lobby camera (FOV and aspect
    blended, ceiling dropped above 3.6 m). The street is hidden as the pull starts (the camera faces into the
    lobby). The door swings shut during the pull (its own 0.6 s hold + 0.8 s close). Then `main.start_play()`:
    HUD and joystick fade in over 0.5 s, the session resumes, `session.arrive()` starts the visit (Welcome Back if
    due) exactly as before. Tap to the end of the visit start: 5.0 s (+0.5 s fade).
  - Any tap after the first: skip; the player lands at the spawn, the door is forced shut (hold cleared), the rig
    camera takes over, the visit starts.
  - While it runs: no visit (`Needs.begin_visit` not called), HUD and joystick hidden, `VenueSession` process
    disabled (house band and sit minute frozen), `_blocked()` true so E/Space/Enter and sheets do nothing, the rig
    does not process until the pull-back (so its cutaway never hides the lobby's west wall while we stand outside).
    The save is loaded by the Needs autoload before any of this.
- **When it shows** (`main.gd`): only when main.tscn is the running scene (`get_tree().current_scene == self`), not
  in `--capture=` screenshot mode, not with `-- --skip-intro`. Tests and tools that instance main.tscn themselves
  (all six old suites, smoke_doors_sit, capture_venue, measure_shadows, capture_parity, export_layout) start straight
  in the venue as before, no edits to them. A test can force it with `main.intro = true` before `add_child`.
  Debug builds: Esc on the start screen goes straight in. F5 (reset save) reloads the scene, so the start screen
  shows again.

## Tests and captures
- `game/tests/smoke_start.gd`: title (street built with 2 lights, neon present, start camera current and aimed at
  the door, EN/TH strings, no visit after 20 frames, HUD/joystick hidden, session suspended, player hidden), entry
  (ends in 4–6.5 s, camera followed through the doorway at head height, pull-back phase seen, door opened ≥0.9, visit
  started, rig camera current, lobby zone, street hidden, HUD alpha 1, door shut, lights inside ≤ venue's own and
  ≤ 42, player at spawn and walking again, session processing), skip (second tap, door shut and stays shut, HUD,
  lights), off (no start screen without `intro`, visit starts at once).
- `game/tests/capture_start.gd` (windowed): `docs/art/screens/start/{portrait,landscape}-{1-title,2-door,3-pull,4-play}.png`
  at half size (540×960 / 960×540, as capture_venue.gd; a full 1080×1920 window is clipped to this laptop's screen).
  2-door = 2.2 s after the tap, 3-pull = 4.1 s.

## Not measured / not done
- Frame time of the start screen view not measured (light count only). Desktop, not a phone.
- Leaving (walk-out) is unchanged. Showing the street on leave would be small: `Main/Street` is still in the tree,
  hidden; `street.set_on(true)` + a camera out on the step. Follow-up, not built.
- The first gameplay frame shows the prompt "Tap to head home": the lobby spawn sits inside the exit zone. That was
  already so before this change (checked with the start screen off); a venue/zone question.

## Calls for Daniele
1. The facade: black-painted two-floor shophouse front, neighbours grey (taller) and brown (low, shutter), a narrow
   soi. All stand-ins until a photo of the real front exists.
2. The sign: the lounge's kit neon (BLACK over CABIN, red voxel tubes) on a black board above the door. Real sign's
   shape, colour, placement (flat over the door, projecting blade, lightbox)?
3. The door from outside: the kit `staff_door` leaf (dark, reads red under the neon), as inside.
4. Dressing: streetlight on a utility pole with the cable bundle, potted palm, cream scooter, menu box. Keep / swap?
5. Title text: "BLACK CABIN" (duplicates the neon on screen; a game name instead?) and "Tap to enter" /
   "แตะเพื่อเข้าร้าน" (machine-draft Thai). Shown in the current language only.
6. Camera: across the street on the opposite pavement (slightly further than "on the pavement" so the door, sign and
   sky fit in portrait); over-the-shoulder follow rather than true first person (true first person showed only the
   back of the head and the lobby wall).
7. Timing: ~5 s, walk 3.3 s; any tap skips. F5 shows the start screen again.
