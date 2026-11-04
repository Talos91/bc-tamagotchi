# Report: web labels + pre-alpha debug panel (tech worker, 2026-11-04)

## EVIDENCE
- Code commit: c11c419 (local main, not pushed). Captures + role note + this report in the follow-up commit.
- Cause: `project.godot` registered only `strings` and `strings_venue` translations. `strings_ui`, `strings_nightlife`, `strings_menu` were read from the raw CSV at runtime; the web export ships imported `.translation` files instead of the CSV, so the read found nothing and raw dotted keys showed.
- Fix: all five tables' `.en/.th.translation` registered in `project.godot`; loaders (`strings.gd`, `nightlife_strings.gd`, `ui_strings.gd`) skip the CSV read when a probe key already translates (CSV fallback kept for a fresh checkout). No CSV shipped to web.
- Key check `game/tests/test_string_keys.gd`: no loader runs; every CSV row (404) and every literal `.t("")`/`tr("")` key in scripts/scenes (147) must resolve from registered translations. Fails on the old project.godot (111 failing keys), passes now. Dynamically built keys are not covered.
- Suites (clean APPDATA per suite, headless, from `game/`): test_needs, test_menu, test_minigames, test_nightlife, smoke_hud, smoke_start, smoke_tap, test_string_keys, test_debug_tools: all PASS (exit 0).
- Web proof: `python tools/build_web.py --out <scratchpad>/web` (built bc-18337240, 54 MB), served on 127.0.0.1:8931, 375x812: start screen, needs HUD, bar menu, minigame result card, debug panel, WASTED after Clear lockout. No dotted key in any. Folder `docs/art/screens/web-labels/` (7 jpg).
- Debug panel: `Rules.PRE_ALPHA` (true) → "Debug" button bottom-left, own CanvasLayer 100 (over start and WASTED screens). Clear lockout, Force WASTED, +1 h / +12 h / +1 night, Make ghost, Fake check-in (revives, lifts 90-day cooldown), Reset save (two taps). Files: `scripts/debug_tools.gd`, `scripts/ui/debug_panel.gd`, wiring in `main.gd`. Test `tests/test_debug_tools.gd`. Verified live in the web build: Force WASTED then Clear lockout enabled Try again.
- Hub card: `web-labels-debug-review` (6 pictures + files).
- Role note: `handoffs/web-labels-debug-2026-11-04.md`.

## Calls for the orchestrator
- Add `test_string_keys` and `test_debug_tools` to the suite list in PROJECT.md (seventeen).
- Before the first public build set `Rules.PRE_ALPHA := false`.
- Daniele's locked phone save: after deploy, Debug → Clear lockout.
- Not done: Thai names/♥ glyph in web unchecked; software-rendered browser, so no fps numbers. `needs_debug` (F1) left untouched.
- The movement/iPhone workers' paths were not touched.
