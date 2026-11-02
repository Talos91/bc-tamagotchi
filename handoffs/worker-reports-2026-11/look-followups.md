# 🎨 look-followups: Daniele's six look-D follow-ups + owner feedback 3, 9, 10 (2026-11-02/03)

## EVIDENCE
- Commits on local main (not pushed): `84c58e5` (the six follow-ups), then `86b40ab` (owner feedback items 3, 9, 10), then this report.
- Suites, empty APPDATA per suite, shared tree:
  - On 84c58e5's venue: **6/6 PASS** (test_lounge, test_feel, test_seats, smoke_doors_sit, smoke_start, smoke_tap).
  - After items 3/9/10: test_lounge, test_feel and smoke_start re-run: **3/3 PASS** on `86b40ab`.
- Venue: 42 lights, 1 shadowed. Navmesh 561 → 555 polygons, because the closed-room boxes are smaller (item 10).
  `git diff game/assets/kit/layout.json` is empty.
- Hub cards (Questions tab): `look-followups-review` (v2, 12 pictures + files), `look-followups-player-light`,
  `look-followups-layout-export`, `look-followups-month-list`.
- Captures: `docs/art/screens/look-followups/` holds `before/` (82ef3e6, isolated copy), `after/` and the two-ups
  `twoup-*.jpg`. Portrait 1080×1920 shots: floor, stage, bar, dark, dark-aisle, corridor-west, lobby, board, north-west,
  cashier, library, band-door. Landscape 1920×1080 shots: floor, stage, bar, board, cashier, library, band-door.
  `crop-board-*`, `crop-stage-*`, `chars/keys-blender-review-*.png`.
- Review scenes: `blender/BlackCabinKit.blend` (with `electric_piano`), `blender/BlackCabinChars_band_keys.blend`.
- Role note: `handoffs/look-followups-2026-11-02.md`. Values: `docs/art/palette-look-d.md` § Follow-ups.

## What was built
1. **Darker still:** ambient 0.7 → 0.5, exposure 1.15 → 1.0, key 0.15 → 0.12. Frame luma is 10–14 % lower
   (floor 0.132 → 0.116, dark 0.094 → 0.081, landscape floor 0.130 → 0.112).
   **Player readable:** `venue.gd` `PLAYER_LIFT` 0.15 makes the player's materials emit their own albedo. It adds no
   Light3D, so the budget of 42 holds. Player-box luma: dark spot 0.018 → 0.037, dark aisle 0.038 → 0.072,
   corridor west 0.032 → 0.094, floor 0.163 → 0.168.
2. **Corridor west end:** still unlit. A dim, slightly red-white neon line (ffbcae, emission 0.8) runs 0.1 m up
   the south wall from the street wall to x 6.5.
3. **LEDs all red:** this was already done at load. The piano's LED is NeonRed, and the library strip is now red
   (item 9). The sconces already sit on the neon line (disc bottom at 1.9 m), so they are unchanged.
4. **Curtain symmetric** (also owner note 12): the backdrop is centred on the drums, with 2 × 0.825 m panels on
   each side out to the stage ends.
5. **Electric piano player** (also owner note 1):
   - Kit `electric_piano`, plus the preset `band_keys` "Guest keyboardist" (the guitarist's look, no guitar) with
     animation `play_keys`.
   - Spot `Band_Keys`; mapped in `venue_patrons.gd` `BAND`.
   - Mic0 and PedalboardGtr removed; the guitar stays on its stand.
6. **Two posters:** `PatronsBoardMonth` (0.7 scale, north of the first, tops level). Subtitles come from
   `venue.board.all_time` / `venue.board.this_month` in `strings_venue.csv` (EN + TH draft). Placeholder month
   order: `Patrons.MONTH`.
- **Owner 3:** Bay4 was `back_bar_art` (the pixel-guitar painting bay). Every bay is `back_bar_shelf` now.
- **Owner 9:** removed the 3 `ShelfBacklight_*` emissive panels behind the shelf tiles (they showed pink through the
  gaps). `ShelfNeon` changed from pink ff2a5a to NEON_RED.
- **Owner 10:** the closed-room boxes reached the wall line and z-fought with the wall's room face (the Backstage
  box against the north wall at the band door). All closed rooms are now inset by 0.21 m.

## Judgement calls (cards)
- The player-only lift (patrons not lifted) → `look-followups-player-light`.
- `layout.json` is not re-exported (frozen), so it now lags the stage dressing, Bay4 and the second board →
  `look-followups-layout-export`.
- The month list is a placeholder, and the board's tap sheet still shows one ranking (`venue_session.gd` belonged
  to the needs worker) → `look-followups-month-list`.

## Not done / gaps
- Swatches are not baked into `bc_kit.py`: `CabinDark` is also the staff wardrobe swatch in `bc_chars.py`, so
  baking it needs a venue-only swatch (a kit job).
- Band door: when the north wall sinks for the camera, its wall-mounted kit (the exit sign, Sconce_269) can stay up.
  That comes from the camera rig's cut rules (`camera_rig.gd`, not my file); the z-fighting itself is fixed.
- Not checked on a real phone. The web build Daniele played predates 84c58e5.
- I did not write a LOG.md line (the orchestrator owns LOG).
