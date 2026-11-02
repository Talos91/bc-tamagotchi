# Touch-anywhere control + slide-away area buttons (2026-11-03, 🎮 gameplay worker, Sonnet)

Owner feedback items 13 and 14 (`handoffs/owner-feedback-2026-11-02.md`). Code commit b8f6d50.

## How input works now
- `game/scripts/touch_joystick.gd` (class `TouchJoystick`, node `UI/Joystick`) is a full-screen Control, `MOUSE_FILTER_PASS`, placed in `main.tscn` BELOW the Hud node. The HUD's buttons and cards stop their own touches, so only touches on empty play area reach it. It never calls `accept_event()`, so a tap still falls through to `Player._unhandled_input` (tap-to-walk unchanged).
- A touch becomes the stick centre where it lands; after `DRAG_START` (24 px = `Player.TAP_MAX_MOVE`) it is a drag and `value` = offset / `RADIUS` (90 canvas px), same curve as the old stick. Release, or the layer being hidden mid-drag, zeroes `value`.
- `Player._input_vector` unchanged: `joystick.value` still read, `input_enabled` still gates. `main._sync_block` hides the layer while a sheet, minigame, menu or the start screen owns input.
- No graphic. `TouchJoystick.debug_ring = true` draws a faint ring and knob while a finger is down (capture 2 only).
- Coordinates: real input is in window pixels, the HUD in canvas units (stretch `canvas_items`/expand, landscape scale 0.5625). Captures convert with `root.get_final_transform()`.

## Area buttons (item 14)
`needs_hud.gd`: a tab `AreasToggle` on the right edge, centre. Pressing it slides the `Areas` column off to the right (0.2 s), pressing again brings it back. `NeedsHud.areas_hidden` is static: kept for the session, starts shown. `set_areas_shown(bool, animate)`, `areas_shown()`.

## Tests
`game/tests/test_touch.gd` (new, 22 checks; PROJECT.md "Tests" to add it via the orchestrator): drag moves, drag clamps, release stops, tap walks, tap with jitter walks, touch on HUD ignored, blocked input, hidden layer, hide mid-drag, area buttons hide/show/persist. A headless viewport does not route GUI input, so the test dispatches by hand (topmost control under the touch). The real path is verified by `game/tests/capture_touch.gd` in a window with `Input.parse_input_event`.
Captures: `docs/art/screens/touch-anywhere/` (1 HUD, 2 debug ring, 3 areas hidden, 4 areas back; portrait and landscape).

## Not verified
Real phone. Portrait captures are 1080x1421 (window clamped by the screen), not 1080x1920.
