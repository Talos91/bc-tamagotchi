# 🎬 Start screen and exit shot (BACKLOG B8) — state 2026-11-02, round 2

Daniele's words (2026-11-01): "when you start the game the menu should be a still camera as if first person of you
staring on the entrance of the club from outside with a camera on the door on which a Black Cabin neon lit sign is;
you tap to enter, door opens, your character walks in with camera following his point of view and then once in, door
closes, camera zooms out to current one and game starts." Round 2 answers (2026-11-02, DECISIONS.md): the sign is
the photo (direction 23); no title; camera "start first (when you see the door) tapping and camera ease to over the
shoulder, character open the door enters and while the door is closing camera ease to game view, interface appear
and its playable"; add an exit shot.

## Commits
- Round 1: `0dc0b68` (code, test), `cf0555f` (captures, docs). Round 2: see LOG.md (sign, sequence, exit shot).

## Street front `game/scenes/street/street_front.gd`
- Script only, built in code at runtime from the venue's `StreetDoor` meta `center` (follows the door if the venue
  session moves it); one node `Main/Street`, hidden with its lights while the player is inside.
- **Sign (direction 23):** `game/assets/street/street_sign.png` (2048×1024), drawn by `tools/street_sign.py`:
  BLACK over a smaller centred CABIN in a high-contrast serif built from rectangles, polygons and ellipses (no font
  file, nothing to license); the glyph masks' edges become the tubes (dilate minus erode), so every stroke reads as
  a double line; pale pink-white core, deep red glow (two blurs). In the scene: one 3.6 × 1.8 m quad, unshaded,
  additive (black adds nothing), albedo ×2.4 so the environment glow blooms it, 0.34 m out from the facade over the
  door. Behind it **foliage lit red from behind**: 520 voxel leaf clumps in an oval (4.3 × 2.1 m), three merged
  meshes (glowing deep red at the back and middle, mid red, near-black in front and at the edges; emissive ones
  have a black albedo and no specular so the streetlight doesn't tint them). Regenerate the texture with
  `python tools/street_sign.py`, then let Godot import it (`--import` or the editor). A missing import falls back to
  reading the PNG directly.
- The rest as round 1: black two-floor front, door jambs and sill, lit menu box, upper windows (one lit), AC unit
  (moved north of the sign), drainpipe, taller grey neighbour north, low shuttered shop south, pavement round the
  venue's own StreetStep, kerbs, a 2.4 m soi, the opposite pavement; utility pole with sodium streetlight and cables,
  potted palm, cream scooter. **Two lights** (`NeonWash`, `Streetlight`): 44 with the street on, 42 inside.
- `view_transform(portrait)`, `view_pitch`, `view_fov`: the still camera of both shots (opposite pavement, eye
  1.6 m; portrait 62° horizontal FOV pitched +14°, landscape 54° vertical pitched +10°).

## Start screen `game/scripts/start_screen.gd` (shared base `game/scripts/street_shot.gd`)
- Title: the still view, only "Tap to enter" (`venue.start.tap`, EN + machine-draft TH, Kanit SemiBold gold, slow
  pulse) over a soft dark band at the bottom. No title (removed `venue.start.title`).
- Tap / click / Enter / Space / E:
  1. prompt fades; the character steps out from under the camera (visible from now) and walks to 0.75 m in front of
     the facade (1.9 s); the camera eases over 1.2 s from the still view to over the right shoulder (1.3 m behind,
     0.3 m right, 1.75 m up, pitched down), following with a damped x so nothing jerks;
  2. they stop 0.3 s while the door swings open (venue_doors.gd's proximity rule, unchanged), then walk through to
     main's spawn (1.2 s), the camera closing to 0.6 m behind and centring;
  3. when the door starts to swing shut (venue_doors.gd: 0.6 s after they leave its 1.2 m reach), the camera eases
     over 1.6 s up first, then back, always looking at the character, ending exactly on the diorama rig's lobby
     camera; the street goes dark once the door is shut;
  4. `main.start_play()`: HUD and joystick fade in (0.5 s), the session resumes, `session.arrive()` starts the visit
     (Welcome Back if due) exactly as without a start screen. Tap to visit start ≈ 5.3–5.5 s.
- Second tap: skip (door forced shut, street dark, diorama camera, visit starts). Debug Esc: same from the title.
- While it runs: no visit, HUD/joystick hidden, `VenueSession` process disabled (band, sit minute), `_blocked()`
  true, rig not processing until the pull-back.

## Exit shot `game/scripts/exit_shot.gd`
- `main._on_visit_finished`: when the visit ended because the player **left** (Leave button or the street door's
  Head home; not idle, not the F4 debug week) and street shots are on, the exit shot plays first, then
  `main.end_exit_shot(summary)` opens the walk-out card exactly as before (totals, rules, card unchanged).
- 0.25 s dip to black; under it the street lights on, the still view (landscape: pitched +4°, 60° FOV so the
  character on the pavement is in frame), the character just inside the shut door facing out; dip back. They walk
  out (1.7 s) to 1.5 m in front of the facade, a step to the side; the door opens for them and shuts 1.4 s after
  they pass its reach; 0.4 s more, then: street dark, character back at the spawn with the diorama camera behind the
  card, card. ≈ 3.2 s. A tap skips straight to the card. GO OUT starts the next visit at the spawn, as before.

## When the shots run (`main.gd`)
- `street_shots` is on only when main.tscn is the running scene (`current_scene == self`), not in `--capture=`
  screenshot mode, not with `-- --skip-intro`. Tests and tools that instance main.tscn start in the venue and leave
  straight to the card unless they set `main.intro = true` first. F5 reloads, so the start screen shows again.

## Tests and captures
- `game/tests/smoke_start.gd`: title (street lit, sign + foliage, still camera aimed at the door, only the prompt on
  screen, EN/TH, no visit, HUD hidden, session suspended), entry (over the shoulder before the door opens, door opens,
  through the doorway at head height, pull-back starts while the door closes, no cut: camera speed < 12 m/s, ends
  4–6.5 s, visit, rig camera, lobby zone, street dark, HUD, door shut, lights 42, spawn, walking), exit (shot before
  the card, street lit with 44 lights, its camera, no HUD, door opens, character out on the pavement, door shut before
  the card, then the card, street dark, lights 42, rig camera), exit skip (GO OUT → next visit, leave, tap → card,
  door shut), entry skip, off (no shots without `intro`; leaving opens the card at once).
- `game/tests/capture_start.gd` (windowed, half size 540×960 / 960×540): `docs/art/screens/start/<orientation>-`
  `1-title, 2-shoulder, 3-door, 4-pull, 5-play, 6-exit-out, 7-exit-shut`. Round-1 frame names removed.

## Not measured / not done
- Frame time of the street views not measured (light count only). Desktop, not a phone.
- The real street door model (staff-door stand-in kept, Daniele 2026-11-02) and a real photo of the front.

## Calls for Daniele (options, recommendation first)
1. **Sign proportions:** the letters are my own serif drawing after the photo, not the real sign's font. (a) keep
   (recommended until a straight-on, higher-resolution photo of the sign exists); (b) match a named typeface if
   Daniele knows it; (c) trace the real sign from a better photo.
2. **Exit shot on idle endings:** today only a chosen leave plays it. (a) only on leaving (recommended: an idle
   timeout is not the character walking out); (b) on every visit end.
3. **GO OUT after the exit shot:** today straight back inside at the spawn, no entry shot. (a) keep (recommended:
   the Flat stand-in is temporary); (b) replay the entry from the street each time.
