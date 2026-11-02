# Owner feedback, 2026-11-02 ~17:00 UTC (Daniele, web build in a phone browser; pictures in `docs/art/screens/owner-feedback-2026-11-02/feedback-1..8.png`)

Daniele's words, numbered by the orchestrator. Owner decisions: items 4, 5, 7, 11 change the venue structure and are authorised (layout.json stays frozen for everything else). Housekeeping folds this list into DECISIONS.md as one dated row.

1. Electric piano not added to the band on the stage. → 🎨 look-followups (brief item 5).
2. Ty is called "TT.name" instead of Ty (missing string `cast.tt.name`; the name is Ty). → 🛠️ needs-stakes-build.
3. Right of the reindeer head there is what looks like a guitar instead of the scaffolding shelving like the rest of the bar. → 🎨 look-followups.
4. The bar is missing a door between the bar and the walled bar area (where NPCs spawn). → 🏗️ venue-fixes.
5. The walled bar area and the bar are at ground level, not raised, so the NPCs are too short against the counter and the bar window in the walled area. → 🏗️ venue-fixes.
6. The curtain in the buffer room blocks the view. → 🏗️ venue-fixes (camera occluder or transparency, with the gameplay rig's rules).
7. The male toilet is missing a door. → 🏗️ venue-fixes.
8. The "curtains" on the right side of the buffer rooms are a solid wall, not curtains. → 🏗️ venue-fixes.
9. The library behind the couch has pinkish artefacts (feedback-3.png). → 🎨 look-followups.
10. Clipping or shadow error at the band door (feedback-7/8.png). → 🎨 look-followups.
11. Add a barrier in the unused corridor so people cannot go in (the same barrier used upstairs). → 🏗️ venue-fixes.
12. The stage background is not symmetric. → 🎨 look-followups (brief item 4).

Pictures: 1 bar floor / song HUD; 2 the bar with the reindeer frame and shelves; 3 library artefacts; 4 candle floor corridor wall; 5 player on the dark floor (look D darkness check); 6 stage with the band; 7–8 band door shadows.

13. (added ~17:30 UTC) Navigation: the joystick is fixed at the bottom right; instead, wherever a person touches, a swipe in a direction moves the character, so the control is anywhere the finger lands and no joystick needs to be visible. → 🎮 touch-anywhere control (after needs-stakes commits player.gd).
