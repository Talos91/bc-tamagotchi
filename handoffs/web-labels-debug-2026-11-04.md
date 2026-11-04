# Web labels + pre-alpha debug panel — role note 2026-11-04
Tech worker (Sonnet), started by orchestrator local_ddbbfc1d. Report: `handoffs/worker-reports-2026-11/web-labels-debug.md`.

## Task A: raw keys in the web build
- Cause: only `strings` and `strings_venue` were registered in `project.godot`. `strings_ui`, `strings_nightlife`, `strings_menu` (and `strings` before 65b7de7) were read from the raw `.csv` at runtime. The web export ships the imported `.translation` resources instead of the raw CSV, so `FileAccess.open` found nothing and every key stayed a dotted key.
- Mechanism chosen: register all five tables' `.en/.th.translation` in `project.godot` (`internationalization/locale/translations`). The engine loads them on every platform; no CSV is needed at runtime. The loaders (`minigames/strings.gd`, `zones/nightlife_strings.gd`, `ui/ui_strings.gd`; `venue_strings.gd` and `bar_menu.gd` already had it) now skip the CSV read when the probe key already translates; the CSV fallback stays for a fresh checkout before the first import. Raw CSVs are not shipped to web (no export filter change).
- New table = register its `.en/.th.translation` in `project.godot`; `tests/test_string_keys.gd` fails if you forget.
- Test `game/tests/test_string_keys.gd`: no loader runs; every CSV row and every literal `.t("…")` / `tr("…")` key in `scripts/` and `scenes/` must resolve from the registered translations alone. On the old `project.godot` it fails (111 failing keys); now 0. Keys built at runtime from variables are not covered.

## Task B: pre-alpha debug panel
- `Rules.PRE_ALPHA` (`scripts/rules.gd`, true) shows a small "Debug" button bottom-left on every screen (own CanvasLayer 100, so it also sits over the start and WASTED screens). Set it to false for the first public build.
- Panel (`scripts/ui/debug_panel.gd`, added by `main.gd`): clear WASTED lockout, force WASTED, clock +1 h / +12 h / +1 night, make ghost, fake check-in (revives; lifts the 90-day cooldown), reset save (two taps). Logic in `scripts/debug_tools.gd`. `needs_debug` (F1) was not reused: it is debug-build only, hidden behind F1, and its panel does not show on the WASTED screen.
- Test `game/tests/test_debug_tools.gd` (touch path emulated: topmost control under the touch is the button, then pressed).
- Open: Daniele's old locked save on the phone needs one tap on Debug → Clear lockout (or Reset save) after the next deploy.
