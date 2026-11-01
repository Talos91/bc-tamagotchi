# Parity pass vs renders 05/06 (commits 156d0bc, 526fecf)

- Main room is now x 10..28, z -0.5..14 (18 x 14.5 m; constants MAIN_X1 / MAIN_Z0 / MAIN_Z1 in build_venue.gd).
  Stage x 18..28, z -0.5..3.3, 0.6 m high; ramp x 20.5..22.5 is 1.4 m long (navmesh climb limit).
  No banquette in the main room any more (renders show none): seating zones are Tables, Bar, CommunalTable, Lounge.
- Crowd: 43 figures (36 seated, band of 4 on Band_* spots, server with tray, bartender), all drawn at scale 0.8
  (FIG_SCALE in venue_patrons.gd). game/tests/smoke_tap.gd now expects 30-50 figures and 4 seated zones.
- Camera zone "bar" now covers z 7.4..14 (it used to start at 7.1 in the old 10 m room).
- New kit objects: back_bar_art, beer_glass, backdrop_lantern, amp_stack. New char presets: server, patron_13..24.
  New hair: shaggy, wavy, afro. New accessories: beard, hat_fedora, vest, tray, beer_left.
- Parity captures: game/tools/capture_parity.gd (disables the camera rig and applies its own cutaway),
  game/tools/parity_compose.py <n>. Results in docs/art/screens/parity/, table in docs/art/parity-measurements.md.
