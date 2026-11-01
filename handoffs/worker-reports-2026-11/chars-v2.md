# Characters v2 (wave 3-parity P1), commits 85d08e7, f5ae8a8, 94c6413, ae9decf

- Review: docs/art/screens/chars/chars-03-sheet.png; captures chars-03-R05-game.png / chars-03-R06-game.png;
  measurements, pose plan and open items in docs/art/screens/chars/README.md.
- Rig now 12 bones: forearm_L/R, shin_L/R added. Head 8x7x7, figures drawn at PatronFigure.FIG_SCALE 0.75
  (PatronFigure scales its own Model now; venue_patrons no longer scales the node, player gets it too).
- Seated root offset unchanged in form: root = seat_h - SEAT_H * FIG_SCALE.
- New clips: sit_drink, sit_talk, sit_hold, sit_applaud, stand_drink, idle_tray, walk_tray, pour, play_guitar,
  play_bass, sing, play_drums. Staff/band clips only on those presets (manifest presets[].animations).
- look["anims"] remaps clip names per figure ({"sit": "sit_drink"}, server {"walk": "walk_tray"}); state stays
  "sit" so smoke_tap's seated-zone check still works.
- Drinks are meshes drink_beer / drink_mug / glass_gold / beer_left / bottle, shown only in drinking clips.
- New preset band_guitar (anonymous guest on the 4th stage spot; House Lights are a trio): needs Daniele's OK.
- Bartender lifted 0.3 m (BARTENDER_LIFT in venue_patrons.gd) to read chest-up over the 1.1 m bar.
- bc_chars.py runs with -- --no-review here so blender/BlackCabin.blend (room-polish) is not rewritten; that
  combined review file still shows v1 characters until bc_review.py is re-run.
- Export: linear keys every 3 frames, force_sampling off -> no scale channels; 42 presets + 3 libs = 14 MB.
