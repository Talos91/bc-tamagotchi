# web-build report (tech worker, 2026-11-02)

## EVIDENCE
- Code commit: 8a46bd3 (local main, not pushed): game/export_presets.cfg, tools/build_web.py, docs/tech/03-web-build.md, .gitignore, docs/art/screens/web-build/. Role note + this report in the next commit.
- Suites from game/ with empty APPDATA: smoke_start PASS, smoke_version PASS, smoke_hud PASS (no game files changed).
- (a) `python tools/build_web.py` from clean: DONE. web/ = bc-f553da15.{js,pck,wasm} + index.html, service worker, manifest, icons, vercel.json; 53 MB (pck 15.7, wasm 37.7).
- (b) URL: NONE. Deploy blocked: no Vercel login on this machine (`vercel whoami`: logged out); `vercel deploy --temporary` made https://zippy-copper-5su4f2z.tmp.now but it is 403 for every request (curl and browser). Vercel connector is "pending" (needs sign-in), not tried.
- (c) Phone numbers: NOT measured. In-app browser pane was hidden, so rAF ran at about 1.2 fps whatever the page (also on an empty page); not a game figure. Verified: loads locally at 375x812 and 812x375 (WebGL2 on RTX 5080), start screen, tap to enter, camera pull-back runs; local load: wasm/pck served in under 0.3 s on localhost. Not verified: fps with 42 lights, tap-to-walk, HUD in play, save across reload.
- (d) Hub card: web-build-review (Questions tab, kind now, 3 pictures + files list). Pictures/folder: docs/art/screens/web-build/ (portrait-start, portrait-entering, landscape).
- (e) Commits hold only my paths.

## What is needed to finish
1. Daniele (or a session with the Vercel connector signed in): `npx vercel login`, then `python tools/build_web.py --deploy` (script runs `vercel link --project bc-tamagotchi` then prod deploy). Not exercised yet; the vercel link/deploy flags are untested.
2. A real phone pass: load seconds, fps with 42 lights, tap walk, portrait HUD, save across reload (IndexedDB).
3. Finding: raw label `cast.tt.name` shows on the start screen and in play (missing string).
4. Decision for the orchestrator: `game/export_presets.cfg` is now tracked (was gitignored); it holds no secrets.

## Notes
- Templates: %APPDATA%\Godot\export_templates\4.6.1.stable\ (web only), copied from Ooze Syndicate/Tools/Godot/Web/ (not downloaded).
- Port 8765 on this machine is Ooze Hub; local test uses 8791.
- Detail and re-run: handoffs/web-build-2026-11-02.md, docs/tech/03-web-build.md.
