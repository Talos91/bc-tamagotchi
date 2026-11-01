# Versioning

Daniele playtests builds and names the build in their feedback, so every build says which one it is.

## The scheme
- **One source of truth:** `application/config/version` in `game/project.godot`, semantic `MAJOR.MINOR.PATCH`.
- **MINOR** is bumped by the orchestrator when it closes a version (0.1.0 closed 2026-11-02, 0.2.0 is in progress). **PATCH** is for a hotfix to a closed version. **MAJOR** stays 0 until Daniele calls a release. Workers never bump it.
- **Build stamp:** the version number says which release, the stamp says which commit. `python tools/version.py` writes `game/build_info.json` (gitignored) with `sha` (short commit), `dirty` (uncommitted changes under `game/`, tracked or not) and `date` (UTC). `python tools/version.py --print` shows it without writing.
- **In the game:** a small dim label, bottom right, on the start screen and on the HUD in play: `v0.2.0 · 33dc5b9`, plus ` · dirty` for a stamp taken from a dirty tree. Without `build_info.json` it shows `v0.2.0` only. The string is built in one place, `game/scripts/version_info.gd` (`VersionInfo.text()`); never format it anywhere else.

## Stamping a build for a playtest
```
python tools/version.py        # from the repo root, right before handing the build over
```
Run it after the last commit you want in the build; a `dirty` label means the build is not exactly that commit, so commit first when Daniele will quote the label. A future export must include the file (add `*.json` to the export include filter, as `STATE.md` already notes for the menu data); without it the build shows the version only.

## Cutting a version (orchestrator)
1. Close the version: all workers finished and archived, suites green, STATE/LOG written.
2. In `tools/changelog.py` append `('<closed version>', '<last commit sha>')` to `RELEASES` (the last commit of the closed version, inclusive).
3. Bump `application/config/version` in `game/project.godot` to the next MINOR (a hotfix on a closed version: PATCH).
4. `python tools/changelog.py`: `docs/CHANGELOG.md` regroups under version headings, everything after the last `RELEASES` entry sits under the version now in `project.godot` as "(in progress)".
5. Commit, then `python tools/version.py` for the build you hand to Daniele; optionally tag the closing commit `v<version>` locally.

## Test
`game/tests/smoke_version.gd` (headless): the version is `MAJOR.MINOR.PATCH`, `VersionInfo` composes `v<version>[ · sha[ · dirty]]`, and the label exists, is visible, shows the ProjectSettings version and sits bottom right inside the viewport on the start screen and the HUD, in portrait and landscape. Run from `game/`: `Godot --headless --path . --script res://tests/smoke_version.gd`.
