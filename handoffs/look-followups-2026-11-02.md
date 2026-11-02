# 🎨 look-followups: role note (2026-11-02)

Done and closed: no worker of this role is running. Report: `handoffs/worker-reports-2026-11/look-followups.md`.

## What exists
- Daniele's six look-D follow-ups (DECISIONS row "Questions tab, answered 07:35–08:19") are built into the
  generators; `venue.tscn` regenerated (42 lights, 1 shadowed, navmesh 561, `layout.json` untouched).
- **Darker still:** `build_venue.gd` `_environment()` ambient 0.5, exposure 1.0, key 0.12.
  **Player lift:** `game/scripts/venue.gd` `PLAYER_LIFT` 0.15. Every material under the player (a `Player` sibling of
  the venue) gets a copy that emits its own albedo. It is re-applied when the figure is rebuilt (`node_added`) and
  costs no Light3D (smoke_start budget 42). Patrons are not lifted.
- **Corridor west end:** `LowNeonS` / `LowNeonW` in `_lobby_and_corridor()`, emissive boxes `CORRIDOR_LOW_NEON`
  ffbcae at 0.8, 0.1 m up, from the street wall to `LOW_NEON_X1` 6.5. They are cut with their wall. No light.
- **LEDs:** unchanged (red at load, `venue_looks.gd`). The sconces (`Sconce_212/269`, kit `wall_lamp` at 1.9 m) sit
  on the north-wall neon line: the disc's bottom is the origin.
- **Curtain:** `_stage()` puts three backdrop panels centred on `STAGE` centre 30.75 and two curtain panels each
  side at 0.825 m (`cw`). Names: CurtainBack0/1 west, 5/6 east, Backdrop2–4.
- **Keyboard player:** kit `electric_piano` (`bc_kit.py`, stage zone; keys 0.6 m, which is figure hip height at FIG_SCALE
  0.75). Placed at (28.98, 0, 2.51), rotated 195°, in front of spot `Band_Keys` (pose `band_keys`, where Band_Guitar was).
  Mic0 and PedalboardGtr removed. Preset `band_keys` "Guest keyboardist" (`bc_chars.py`, guitarist's look, no guitar),
  animation `play_keys` (`KEYS_ANIMS`, only for `KEYS_PLAYERS`; the part libraries carry it too). Mapping in
  `venue_patrons.gd` `BAND`. Review: `blender/BlackCabinChars_band_keys.blend`, kit review `blender/BlackCabinKit.blend`.
- **Two posters:** `_patrons_board()` keeps `PatronsBoard` (all time) and adds `PatronsBoardMonth` (the kit board at 0.7,
  z 8.28, top level with the first). `_board_names()` letters a subtitle key (`venue.board.all_time` /
  `venue.board.this_month` in `strings_venue.csv`; Label3D translates it) and ten names. Placeholder month order
  `Patrons.MONTH` / `month()` in `scripts/zones/patrons.gd`.
- Captures: `game/tests/capture_look_followups.gd` (views floor, stage, bar, dark, dark-aisle, corridor-west, lobby,
  board, north-west; `--sweep` finds the darkest walkable patches). Before (82ef3e6, isolated copy) / after /
  two-ups / crops in `docs/art/screens/look-followups/`.

## Gotchas
- `layout.json` is not re-exported (frozen). It now lags the stage dressing and the second board (card
  look-followups-layout-export).
- Swatches not baked into `bc_kit.py`: `CabinDark` is also the staff wardrobe swatch in `bc_chars.py` (`STAFF_TOP`).
  Baking it would turn staff tops black on the next character run. Use a venue-only swatch if this is ever done.
- Both generators are deterministic: a full kit run changed only the piano, the manifest and the review .blend; a full
  character run (`--no-blend --no-review`) changed only band_keys, the manifest and the four part libraries.
- The tap sheet of the board still lists one ranking (`venue_session.gd`, the needs worker's file on 2026-11-02).
- `strings_venue.csv` was being edited by the needs worker too: stage only your own lines (the blob was built from
  HEAD plus the two board lines).

## Next
- Daniele answers look-followups-review and the three judgement cards; then look-D close → 0.2.0 close.
