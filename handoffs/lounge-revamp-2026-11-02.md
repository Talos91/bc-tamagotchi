# 🏗️ Lounge revamp: role note (2026-11-02, state now)

Worker: venue/art (Opus), briefed by the orchestrator local_9bb3d41c. Owner words: DECISIONS rows "Lounge revamp and
corridor portraits" (2026-11-02) and "Questions tab, answered 2026-11-01 20:37–22:14" (the curtain). BACKLOG B7, B9,
B10, B11. `layout.json` was unfrozen for the lounge and the corridor walls only; it refreezes when Daniele accepts.
Commits: see the end of this note. Report: `handoffs/worker-reports-2026-11/lounge-revamp.md`.

## What changed

1. **Lounge (B9)**, `game/tools/build_venue.gd` `_lounge`, `_merch_shop`, `_lounge_dressing`, `_patrons_board`:
   - **Merch shop top right:** the collectibles shelf stays; new kit `merch_rack` (rail with three tees) beside it and
     `merch_stand` (lit red MERCH counter with folded tees, caps, tote, stickers) in front at `MERCH` (13.6, 1.55),
     customers on its south side. A snake plant (`potted_plant`) in the corner.
   - **Game machine top left:** `GameCabinet` moved from the south wall by the stair foot (10.3, 12.65, facing the
     bottom step) to the north wall beside the memory corner (`CABINET_X` 8.0, z 0.4, facing south). The painting and
     the red disc lamp on that wall shifted east (9.6, 10.7). **The stair is unchanged**; its bottom step no longer
     faces the machine: asked as a question (report).
   - **Top patrons board under the stairs (left):** new kit `patrons_board` on the face of the plinth under the second
     flight (x 4.03, z 9.55, facing east), title in Kristi and the ten names lettered on it (Label3D).
   - **High counter + two stools** (seat group `HighCounter`, spawns `Lounge_Stool0/1`) moved from the top right to the
     south wall east of the stair foot (`LEDGE_X` 9.9–11.8), stools facing the wall.
   - **Decorations:** two gig posters climbing the wall over the first flight, three vinyl records over the high
     counter (`LoungeVinyl0-2`; `Vinyl0-2` clashed with the main room's names in layout.json), two snake plants.
     No new light (42).
   - The two white columns are cutaway pieces now (cut_normal ZERO: they hide only when in front of the player).
2. **Top patrons (B10):** `game/scripts/zones/patrons.gd` holds the ten placeholders (nickname, patron preset, invented
   check-in count; rank 1 first). Zone `patrons` (`venue_zones.gd`); its sheet lists them as info lines in a scroll list.
3. **Merch (B11):** zone `merch` in front of the counter; sheet with six placeholder items (tee, cap, tote, sticker
   pack, enamel pin, gig poster), each disabled "Coming soon · price to be confirmed". No prices, no payment rule.
4. **Corridor portraits (B7):** `_portraits`: ten `portrait_frame` kit frames on the corridor's south wall
   (`PORTRAIT_X0` 3.0, step 1.2), each holding a textured quad of a top patron's head and shoulders rendered in the
   game's voxel style (`game/tools/render_portraits.gd` → `game/assets/venue/portraits/<preset>.png`), a brass
   `picture_light` above and the rank + name in Kristi under it. The four old corridor pictures are gone (the two in the
   lobby stay); the two corridor wall lamps moved up to 2.6 m between portraits. A tap-only collider (`TAP_LAYER`,
   physics layer 10, excluded from the navmesh bake by `geometry_collision_mask = 1`) on each frame takes screen
   taps. Zones `portrait:<rank>` (radius 0.55, centred 0.55 m off the wall): walking past shows the prompt, a tap opens
   the sheet with the picture (zone_sheet `picture`) and the owner's placeholder message.
5. **Curtain:** the buffer's four open curtain panels carry meta `cut_sight_only` (cut_normal ZERO): `camera_rig.gd`
   cuts them only when they stand on the sight line to the player. Before, the floor view (looking east, camera in the
   buffer when you stand by the west opening) cut them as "facing the camera" and "nearer than the player", so from
   the main room the opening had no curtain. Two-ups `twoup-*-curtain-main-*.jpg`.
6. **Raised3:** its centre is boxed in (the east rectangular table's chairs west of it, Raised4's chair south; the strip
   between the chairs is a navmesh pocket). `venue_zones.gd` `APPROACH_AT` gives it the nearest reachable spot (39.6,
   9.2) with a matching `slack` that `main.gd` adds to `ARRIVE_SLACK`. A tap from the main room now opens its sheet. Its
   own seats stay out of reach (main-room layout is frozen): question in the report.
7. **Camera / areas:** three lounge views in `_camera_zones()` listed before `lounge`: `merch` (north, top right),
   `memory` (north, top left: memory corner + game machine), `patrons` (yaw 130, from the north-east past the column).
   `lounge` has meta `base`: `camera_rig.gd` `_zone_for` lets any area inside it take over even within its hysteresis
   (before, a sub-area inside a bigger rect could never win). `CameraRig.ROOMS` maps the three to `lounge` (dwell, no
   wild swings). No new area buttons: seven already fill the column in portrait; the Lounge button still walks to the
   pinball. HUD titles `venue.zone.merch` / `.patrons`; the lounge arrival bonus also lands in the three.
8. **Sheets** (`scenes/ui/zone_sheet.gd`): optional picture under the header, rows with `info: true` are plain text
   lines (wrapped), six or more rows scroll within half the screen.

## Files
build_venue.gd, venue.tscn (regenerated), layout.json (exported), camera_rig.gd, main.gd, venue_zones.gd,
venue_session.gd, zone_sheet.gd, patrons.gd (new), strings_venue.csv (+22 rows, Thai machine drafts marked in the
context column), bc_kit.py (+5 objects, letters M E R H in FONT), manifest + 5 GLBs, blender/BlackCabinKit.blend,
render_portraits.gd + 10 PNGs, capture_lounge.gd, lounge_twoup.py, test_lounge.gd (new suite), test_feel.gd (the
lounge north-east corner check now looks for the merch stand and the shelf), playtest guide.

## layout.json entries moved (lounge and corridor walls only)
Removed: RegularPictureS0-3, CorridorLamp4, CorridorLamp10 (Lobby). Added: Portrait0-9, PortraitLamp0-9, CorridorLamp3,
CorridorLamp9 (Lobby); MerchRack, MerchStand, MerchPlant, PatronsBoard, GigPoster0-1, LoungeVinyl0-2, StairPlant
(Lounge). Moved: GameCabinet (10.3, 12.65) → (8.0, 0.4) turned 180 → 0; CounterStool0/1 (13.15|14.05, 1.85) →
(10.35|11.3, 12.0) turned 180 → 0; RedDiscLamp x 10.2 → 10.7; LoungePainting x 8.2 → 9.6. Spawns Lounge_Stool0/1 moved
with the stools. Nothing outside Lounge / Lobby changed.

## Re-running
From game/: `godot --headless --path . --import`, then `--script res://tools/build_venue.gd`, then
`--script res://tools/export_layout.gd`. Portraits (GPU window): `godot --path . --script res://tools/render_portraits.gd`.
Kit: `blender --background --factory-startup --python tools/blender/bc_kit.py` (repo root). Contact sheet:
`bc_kit_sheet.py -- --out docs/art/screens/lounge-revamp/kit-lounge-additions.png --names merch_stand,merch_rack,patrons_board,portrait_frame,potted_plant`.
Captures: `godot --path . --script res://tests/capture_lounge.gd -- --tag=portrait|landscape` (renders at full size in
a half-size window: true 1080×1920; the older 1421-px captures in other folders have the HUD shrunk to 0.74).

## Open / for later
- Questions for Daniele: see the report (game machine vs the stair foot; merch contents/prices/payment; what ranks
  patrons; owner messages; Raised3's seats).
- Thai strings are machine drafts. Placeholder names, counts and the owner message are invented and say so.
- The corridor's own view looks along the wall, so the portraits read edge-on in play; their sheet shows them full
  size. A wider corridor view would need the lounge's south wall cut from the corridor, which the cutaway rule forbids.
- Memory-corner kit props are still placeholders (unchanged).

## Commit

50a0623 (main, not pushed): code, kit, venue.tscn, layout.json, portraits, strings, tests, captures, playtest guide. This note and the report in the commit after it.
