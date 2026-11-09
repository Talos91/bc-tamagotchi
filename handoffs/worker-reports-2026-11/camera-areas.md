# 🎮 camera-areas: worker report (2026-11-10, owner items 30–32)

Worker UI (Opus), load id 2026-11-10-ui-black-cabin-66bced, briefed by 🎛️ local_7f958171. Not pushed.

## Evidence
- Commits on local main: **3ac4e99** (item 30) · **74db99e** (item 31) · **c4df060** (item 32) · **42ff467** (item 31
  follow-up: door view yaw 150, after captures, two-ups) · **074440a** (heading spot also taken when the player
  stands still facing that way; found on the web build) · then this report + role note.
- Suites (Godot 4.6.1 headless, from `game/`, empty APPDATA per suite):

| Run | Suites | Result |
|---|---|---|
| c4df060 tree | all 19 | 19/19 PASS (test_needs 228, test_minigames 1498, test_menu 3670, test_nightlife 113 checks, 0 failed) |
| 42ff467 tree | test_feel, test_lounge, test_walk, smoke_start | 4/4 PASS |
| 074440a tree | test_feel, test_lounge, test_walk, smoke_start | 4/4 PASS |
| 74db99e tree | + smoke_tap (tap ray changed) | PASS |

- test_feel adds: 5 item spots (view on the tap, settled at 3.6 m, eased back out, step ≤ 0.3 m, turn ≤ 260°/s),
  corridor end (door shown, lounge wall standing, tap through the cut south wall), crossing (door view at once,
  camera on the lounge side z 7.9, door + game machine on screen, player in sight; occlusion walk 122/122 ticks),
  west exit never takes the corridor-end view, curtains (yaw −98° on arrival, east), buffer then floor (−90°),
  westward never takes curtains, swaying across the buffer line holds the view. Peak turn 225°/s (lounge → curtains,
  180°).
- Captures `docs/art/screens/camera-areas/`: `before-` / `after-` × portrait 1080×1920 / landscape 1920×1080 × 14
  spots (8 items, corridor-end, door-swing, door-in, curtains, buffer, main), `twoup-*.jpg`, web
  `web-375x812-corridor-end.jpg`, `web-375x812-item-pinball-half.jpg`.
- Web: `python tools/build_web.py --out <scratch>` exit 0 (54.2 MB, 074440a), served on 8798, desktop app browser
  pane (hidden pane, ~30 fps), 375×812: corridor-end view and pinball close-up seen. Not captured in web: the
  lounge-side door view (a tap on the Sticker door from the corridor snaps to the corridor side; reached only via
  the Lounge button, whose focus shows the lounge view). Not on a real phone.
- Hub cards: **camera-areas-review** (10 pictures + files), **camera-areas-door-dark** (owner call),
  **camera-areas-buffer-view** (owner call).

## What changed
Camera "spots" in `camera_rig.gd`: views inside an area that never change `zone` (HUD title, area buttons, earshot,
enter_lounge bonus). Metas `area`, `item` (tap-walk takes it at once), `heading` (approach direction only),
`solid_beyond` (corridor end: facing walls beyond the player stay up). Zone rows in `build_venue.gd`; venue.tscn
regenerated (markers only, 42 lights, layout.json untouched). `player.gd`: `walk_target()`; taps skip colliders of
cut walls. Role note `handoffs/camera-areas-2026-11-10.md`.

## Calls for Daniele
1. camera-areas-review: accept or name a spot.
2. camera-areas-door-dark: the Sticker door reads dark from both sides; emissive sign/strip (no light) recommended.
3. camera-areas-buffer-view: quarter-turn kept in the buffer (a half-turn would face back at the lounge).

## Gaps / for later
- An area-button walk keeps `focus` until arrival even after a tap elsewhere (main.gd releases it only when the walk
  ends), so spots wait until then; the facing rule in 074440a covers the corridor end. Small; main.gd not touched.
- Tapping the Sticker door from the corridor does not walk through it (nav snaps to the corridor side); the stick or
  the Lounge button does. Pre-existing.
- Two Godot overlaps: my first before-capture run started while the perf worker's Godot ran (gate added after).
- Profile note: the `ui` profile has no step for web-build input in a hidden pane; desktop-size clicks work, touch
  emulation lost creator taps.
