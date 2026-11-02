# Report: ty-name-fix (tech worker, Sonnet)
EVIDENCE
- Commits: see `git log -- handoffs/ty-name-fix-2026-11-03.md` (code commit "Ty name fix", then notes). Not pushed.
- Cause: web export shows `cast.tt.name` (reproduced, before-*.jpg). `strings.csv` was only loaded by a runtime CSV read (S.install); `project.godot` registered only strings_venue. The web build does not get the names through that read. `venue_session.gd:305` also bypassed S.t.
- Fix: registered `strings.en/th.translation` in project.godot (engine-native, works in web) AND routed `venue_session._name` via `Cast.name_of`.
- Suites (headless, empty APPDATA): smoke_start PASS, smoke_loop PASS, test_nightlife 107/0, test_menu 3670/0, smoke_hud PASS.
- Web: `build_web.py --out` scratchpad (before bc-6adb4fd7, after bc-7eb7eb7f), served locally, 375x812: after shows "Ty" on start screen and in play.
- Hub card: `ty-name-fix-review` (Questions tab), 3 images, files.
- Paths: game/project.godot, game/scripts/zones/venue_session.gd, game/tests/smoke_start.gd, game/tests/smoke_loop.gd, docs/art/screens/ty-name-fix/*.jpg, handoffs/ty-name-fix-2026-11-03.md

CAVEATS
- Label-scan checks pass headless on the old code too; only the project.godot registration and the cold `translate("cast.tt.name")` checks fail before the fix.
- Heart "♥" after Ty's name is not visible in the web build (separate, unfixed).
- ui/menu/nightlife CSV loaders use the same runtime read; unverified in web. Suggest a check or registering their translations too.
- Web server quirk locally: audio worklet files 404 under python http.server (not related).
- Other sessions' uncommitted edits in the tree (venue_patrons, venue.tscn, smoke_doors_sit, capture_venue_fixes, build_venue) were not touched or committed.
