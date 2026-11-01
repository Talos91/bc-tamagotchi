# 🖼️ Brand fonts and orientation toggle — state 2026-11-02

Daniele's decisions (DECISIONS.md, 2026-11-02): Lato for all interface text, bold as on blackcabin.bar; Kristi for
stylish titles only; IBM Plex Sans Thai Looped stays as the Thai fallback. Portrait first, landscape through a simple
toggle button at the top right of the interface.

## Fonts
- Bundled in `game/assets/fonts/`: `Lato-Regular.ttf`, `Lato-Bold.ttf`, `Lato-Black.ttf`, `Kristi-Regular.ttf`
  (Google Fonts repo `ofl/lato`, `ofl/kristi`, unmodified), licences `OFL-Lato.txt`, `OFL-Kristi.txt`.
  Lato-Regular is bundled but unused (Daniele: "all bold").
- `game/ui/bc_theme.tres`: default font, Button, LabelBody/BodyL/Caption = Lato Bold; LabelDisplayS/L/XL = Lato
  Black; new **LabelTitle** = Kristi. Every variation falls back to IBM Plex Sans Thai Looped SemiBold, so Thai
  renders everywhere. Kanit is no longer referenced; its files stay in `assets/fonts/` until the orchestrator
  removes them (also `OFL-Kanit.txt`).
- Kristi is used through `UI.title(text, size_dp)` in `game/scripts/minigames/mg_ui.gd`, at three places only: the
  HUD zone name (`scenes/ui/needs_hud.gd`), the result card heading (`scripts/minigames/result_card.gd`) and the
  Welcome Back heading (`scenes/ui/welcome_back.gd`). Kristi's x-height is small, so outside Thai the size is ×1.4
  (`UI.SCRIPT_SCALE`); Thai, which falls back to Plex, keeps the plain size. Capitals in a script read badly, so
  an all-caps string is shown in title case (`UI.title_case`: "THE LOUNGE" → "The Lounge"); the strings files are
  unchanged.
- `UI.draw_text` (canvas-drawn minigame text) now uses the project theme's default font (Lato Bold) instead of the
  engine fallback font.
- Line heights: Lato's line is 1.2 em against Kanit's 1.5 and Plex's 1.65, so English lines got shorter; Thai lines
  keep Plex's height. Checked in the captures at 1080×1920 and 1920×1080 layouts (EN, TH): nothing clips or wraps
  badly.

## Orientation toggle
- `game/scripts/ui/orientation.gd`: `current()` (from the root viewport's shape), `toggle(needs)`, `apply()`,
  `restore(needs)`. Same mechanism as main.gd's F7: swap the window's width and height (canvas_items / expand
  re-lays the UI). On a phone build it sets the screen orientation instead; headless it resizes the root viewport.
- Saved in `Needs.ext["ui"]["orientation"]` ("portrait" / "landscape"); written at once when autosave is on.
  No saved value = portrait (the project window). `restore()` runs in the HUD's `setup()` at boot, before the start
  screen, and is skipped when the command line sizes the window (`--resolution`, `--capture*`) or headless.
- `game/scenes/ui/orientation_toggle.gd`: a 44 dp round button with a drawn phone outline in the orientation it
  switches to and a gold turn arrow; tooltip and accessible name "Landscape" / "Portrait" (TH แนวนอน / แนวตั้ง)
  from the new `game/i18n/strings_ui.csv` (read at runtime by `game/scripts/ui/ui_strings.gd`).
- Placement (`needs_hud.gd`): right end of the zone-name row, directly under the top bar's right end, so it never
  meets Leave or the rings. The top bar was 16 dp wider than a 390 dp portrait screen (the x2/tipsy chip column
  hung off the right edge); its outer row now has no separation (the rings keep 8 dp between them in their own
  row), so the bar and the toggle both fit. The zone name trims with an ellipsis rather than pushing the toggle off
  screen. The toggle lives in the HUD, so it is hidden whenever the HUD is: start screen, exit shot, minigames,
  walk-out card. `start_screen.gd` is untouched.

## Tests
- `smoke_hud` gains `_check_orientation`: toggle visible on the HUD; in portrait and landscape, English and Thai,
  it sits inside the screen, in the top-right quarter, at least 40 dp, overlapping neither Leave nor any ring; a
  press flips the orientation and records it in the save; the Thai tooltip; hidden while a start screen runs.
  The Thai check now covers LabelTitle too.
- All eight suites pass on the shared tree (2026-11-02): smoke_stairs, smoke_tap, smoke_hud, test_needs (106),
  test_minigames (828), smoke_loop, smoke_doors_sit, smoke_start.

## Captures `docs/art/screens/ui/` (`game/tests/capture_ui.gd`, half of 1080×1920 / 1920×1080, same layout)
- `hud-{portrait,landscape}-{en,th}.png`, `result-…`, `welcome-…`, `toggle-{portrait,landscape}.png` (toggle ringed).
- Rerun: `Godot --path . --resolution 540x960 --script res://tests/capture_ui.gd -- --tag=portrait` (and `960x540`,
  `--tag=landscape`) from `game/`.

## Open
- **F7 does not save.** main.gd's F7 still swaps the window itself (main.gd had another session's uncommitted edit,
  so I left it alone). One-line follow-up for whoever owns main.gd next: `KEY_F7: Orientation.toggle(needs)` with
  `const Orientation = preload("res://scripts/ui/orientation.gd")`; the toggle's icon already follows F7.
- The orientation lives in the game save, so the F5 debug reset (and, later, total character deletion from the
  stakes proposal) puts it back to portrait. If settings must survive a death, move `ext.ui` to a separate settings
  file then.
- Call for Daniele (title case in Kristi), below.
- Seen in passing, not mine: the band caption "LIVE · song 1 of 4" (red on the red-lit bar) is hard to read in the
  portrait HUD (`hud-portrait-en.png`); the error `get_meta('cut_rooms')` from camera_rig.gd floods the log while
  venue-notes' uncommitted camera edit is in the tree.

## Call for Daniele
**Kristi titles: title case or capitals?** Screenshot: `docs/art/screens/ui/hud-portrait-en.png` (zone name
"The Bar"), `welcome-portrait-en.png` ("Welcome Back"), `result-portrait-en.png` ("Perfect pour").
- A. Title case in Kristi, as now ("The Lounge"). **Recommended**: a script in capitals is hard to read and loses the
  handwritten look.
- B. Capitals in Kristi ("THE LOUNGE"), as the strings are written.
- C. Kristi for Welcome Back and the result card only; zone names back to capitals in Lato Black (they change every
  few seconds while walking, and need to be read at a glance).
