# Versioning — tech worker role note (2026-11-02, state now)

Done: version 0.2.0 in `game/project.godot`; `game/scripts/version_info.gd` is the only place that builds "v0.2.0 · sha[ · dirty]"; label bottom right (9 dp, ASH at 70 %) on the start screen (`start_screen.gd`) and the HUD (`needs_hud.gd`); `tools/version.py` writes the gitignored `game/build_info.json`; `tools/changelog.py` groups by version via `RELEASES` (0.1.0 = through 51603f0); `docs/tech/versioning.md`; `game/tests/smoke_version.gd` (tenth suite); `smoke_start` ignores `VersionLabel`. Commits: af393ac (code, docs, tests), then the captures commit. Captures: `docs/art/screens/version/` (portrait/landscape x start/hud, half-size windows as capture_start).

Suites (shared tree, headless): smoke_stairs, smoke_tap, smoke_hud, test_needs, smoke_loop, smoke_doors_sit, test_menu, test_minigames, smoke_version PASS; smoke_start PASS after the VersionLabel exclusion (first run failed on exactly that).

Not done / watch: in landscape the label is small (UI scales with height: about 14 px at 1920x1080); raise the size if Daniele cannot read it. The stamp must be re-run after the last commit (`python tools/version.py`); an export must include `build_info.json`. Not pushed.
