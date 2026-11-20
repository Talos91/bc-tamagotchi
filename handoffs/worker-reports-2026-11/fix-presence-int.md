# Report: 🛠️ fix-presence-int (2026-11-20)

## Evidence
- Fix commit 7e66e6d on a929206 (branch wk/fix-presence-int, worktree C:/Users/itisf/bc-wt/fix-presence-int); version unchanged.
- Suites: 30/30 PASS headless, empty APPDATA, fresh import, 0 SCRIPT ERROR lines (logs:
  C:/Users/itisf/AppData/Local/Temp/claude/367d8cda9bb5f12e/d108372e-7ae2-48b1-8b75-5b99b5233443/scratchpad/logs, summary all.txt).
- Web build: `python tools/build_web.py --out <scratchpad>/web` exit 0, 56 MB, not deployed.

## Cause
The client (built against its own fake) picked the real `Presence` autoload whenever it existed and had a URL, so every
headless run made real Supabase calls; a reply landing after its venue was freed called a lambda on a freed object
(presence_client.gd fetch_tonight → SCRIPT ERROR, test_avatar crash 3221225477), and "off by default" failed.

## Fix
- presence.gd: `live_wanted()` / `go_live()`: web build on by default (`?presence=off|fake` off); elsewhere inert unless
  `--live` / `--presence-live` / mock. `_exit_tree` stops polling, pending calls answer offline. `mock_delay_s` for tests.
- presence_client.gd: every async reply goes through `fire()`, dropped when the asker is freed.
- venue_patrons.gd (presence hook only): tap catcher created before the async answer (with the real source it was never
  made: presences could not be tapped); react timer binds a weakref (5 "Lambda capture freed" errors).
- test_presence_client: new "real" section (autoload inert by default; mock mode: 12 presences walk in, taps up, wave,
  freed venue poll + freed node replies dropped). test_presence_net: --live calls go_live().
- 08b v1.2 §1.1 states the rule.

## Not verified
- Live network path not run (`test_presence_net -- --live`); no phone or browser run of the web build.
