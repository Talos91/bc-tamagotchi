# Ty name fix — role note 2026-11-03
Tech worker (Sonnet), started by orchestrator local_ddbbfc1d. Report: `handoffs/worker-reports-2026-11/ty-name-fix.md`.

- Symptom: the gold name tag over Ty's table (seen through the street wall on the start screen, and in play) read `cast.tt.name` in the web export.
- Reproduced in a local web export of 4826ba6+ (docs/art/screens/ty-name-fix/before-*). Desktop headless suites never showed it.
- Fix (mechanism chosen): `game/project.godot` now registers `strings.en/th.translation` next to the venue ones, so cast names resolve from the engine's imported translation and do not depend on the runtime CSV read in `scripts/minigames/strings.gd` (which fails or is stale in the web export; exact reason not isolated). Also `venue_session.gd::_name` now calls `Cast.name_of` instead of a bare `TranslationServer.translate`.
- Tests: `smoke_start` checks no Label/Label3D text contains `cast.`, Ty's table prompt names him, strings.en/th are registered, and `translate("cast.tt.name") == "Ty"` with no S.t call; `smoke_loop` checks the same at Ty's table. Honest caveat: only the registration/translate checks fail on the old project.godot; the label scans pass on old code headless (S.t installs the CSV there). The web screenshots are the real proof.
- Open: the ♥ after Ty's name does not render in the web build (font glyph?); ui/menu/nightlife strings still use the runtime CSV read and may have the same web issue (not verified).
