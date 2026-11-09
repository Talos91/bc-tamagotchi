# 🎮 Camera areas: role note (2026-11-10, state now)

Worker: UI (Opus), session started by the orchestrator local_7f958171, load id 2026-11-10-ui-black-cabin-66bced.
Spec: owner items 30–32 in `handoffs/owner-feedback-2026-11-09.md` (Daniele's words). Builds on camera feel 2
(`camera-feel-2-2026-11-02.md`: tight follow, nothing hides the player; both kept). Report:
`handoffs/worker-reports-2026-11/camera-areas.md`. Hub card `camera-areas-review`. Nothing pushed (Verifier pushes).

## Commits (main, local)
3ac4e99 item 30 · 74db99e item 31 · c4df060 item 32 · 42ff467 item 31 follow-up (door view yaw 165 → 150, after
captures, two-ups) · 074440a (a heading spot is also taken standing still, facing its way: on the web build a
walk that ended at the corridor's end never showed its view) · then this note and the report.

## What exists now
- **Spots** (`game/scripts/camera_rig.gd`, header "Spots"): camera-zone markers with meta `spot=true` are views
  inside an area, never areas. `zone` (HUD title, area buttons, earshot, the enter_lounge bonus) is unchanged;
  `spot` names the view in use and `view` follows it. Taken after `ZONE_DWELL` 0.3 s, held `HYSTERESIS` 0.6 m past
  the rect, eased by the swing; at once when `zone` just changed (a door) or on a snap. Metas: `area` (the area it
  belongs to), `item` (also taken at once on a tap-walk ending inside it: `Player.walk_target()`; the clamp is free
  until the player arrives), `heading` (Vector2: taken only while walking that way, dot > 0.3; held until dot < −0.3),
  `solid_beyond` (entrance rule: a facing wall wholly beyond the player stays up). Area-button `focus_on` clears spots.
- **Zone rows** (`game/tools/build_venue.gd` `_camera_zones()`; marker names are `capitalize()`d, so
  `corridor_end` is `"corridor end"` in `rig.spot`):
  - item 30: booth, couch, pinball, cabinet, counter at 3.6 m (pitch −34/−36); merch, memory, patrons areas 5.0/4.8 → 3.8 m.
  - item 31: `corridor_end` (corridor, heading east, x > 11.6, yaw −35, looks NE through the corridor's own cut
    south wall; lounge wall + Sticker door stand); `door` (lounge, x 12.9+, z 10.4+, yaw 150, dist 5.0: taken at once
    through the door, looks back at the door, the high counter and the game machine).
  - item 32: `curtains` (lounge side of the buffer opening, heading east, yaw −90). Buffer keeps its own north view
    (the "flip"), the main room its east view (the "flip back").
- **Taps through cut walls** (`game/scripts/player.gd` `tap_at`): a hit on the collider of a cutaway piece that is
  hidden or sunk is skipped (up to 4 hits), so the corridor-end camera (behind the corridor's south wall) keeps
  tap-to-walk. Applies everywhere a wall is cut.
- `venue.tscn` regenerated (zone markers only; 42 lights; layout.json untouched).

## Tests
`game/tests/test_feel.gd`: FRAMING for merch/memory/patrons; the area-button check accepts an item spot of the area
(Lounge button → pinball close-up); new `camera_areas()` (5 items: view on tap, settle distance, ease back out,
camera step ≤ 0.3 m, turn ≤ 260°/s), `camera_areas_31()` (corridor end, tap through the cut wall, crossing at
once, camera on the lounge side, door + machine on screen, player in sight, occlusion walk, westward exit never
takes the end view), `camera_areas_32()` (curtains east, buffer then floor, westward never takes curtains,
swaying on the line holds the view). Capture script `game/tests/capture_camera_areas.gd` (`--tag`, `--prefix`,
`--only=items|door|curtains`), two-ups composed by a scratch script (PIL, 540×960 / 960×540 halves).

## Gotchas
- Only one Godot at a time: gate every launch on `tasklist | grep -i godot` (the perf worker runs Godot too).
- The 180° lounge → curtains turn peaks at ~225°/s (limit 260); the swing rule is unchanged.
- Spot names with `_` become spaces in `rig.spot`/`rig.view` (Marker3D names are capitalized).

## Open (owner calls on the card)
- The Sticker door reads dark from both sides (black leaf on a black wall, no light near it): an emissive sign or
  strip over it would make "see the door clearly" literal; look change, not built.
- Buffer view direction: kept north (90° turns either side) rather than a true 180° flip.
- Not verified on a real phone; web build (074440a) checked at 375×812 in the desktop app's browser pane: corridor
  end and pinball close-up seen; the lounge-side door view not reached in web (tapping the Sticker door from the
  corridor does not walk through it; the Lounge button's focus shows the lounge view instead).
- Web driving tip: in the hidden pane, touch emulation lost the creator's taps; desktop size + plain clicks worked
  (stub `window.prompt` for the name), then switch to the mobile preset in game.
