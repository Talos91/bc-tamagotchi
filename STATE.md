# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-02 ~08:45 UTC)

## LIVE (origin/main 14cda24; every code SHA verified 14/14 in a clean worktree, APPDATA empty per suite)
- Venue v4 to the real floor map, doors, seats, stair, start screen with the real sign, Lato + Kristi, portrait first + landscape toggle, real menu (121 drinks, 34 dishes), Prae owner, Tt regular #4, nightlife actions + WASTED, per-area camera with seven area buttons, lounge revamp (coin merch shop, memory corner, game machine by the stair foot, Top patrons board, ten corridor portraits with patron messages, curtain from the main room, lane to Raised3; accepted, **layout.json frozen**), **look D** (6cd9735 + 6df5288: voxel cement floor and grained walls, blackish, grey-top north wall with a red neon line, red neon + candle pools, a third darker than before, reindeer head over the cashier; acceptance pending), **menu follow-ups** (6c7d9e4: Try something new rotates six real drinks per night, any order marks tried, Coke row, Bundles tab, errata list `docs/venue/menu/errata-for-black-cabin.md`; accepted 08:09), **stakes v3 docs** (625f83f: `06-stakes.md` v3 with §10 build spec, `04-coins.md` v2 signed off, GDD + high concept match; review pending).
- 14 suites (run from `game/`): smoke_stairs, smoke_tap, smoke_hud, test_needs, test_minigames, smoke_loop, smoke_doors_sit, smoke_start, test_menu, smoke_version, test_nightlife, test_seats, test_feel, test_lounge. Version 0.2.0 open (`docs/tech/versioning.md`). Play: `docs/tech/02-playtest-guide.md`.

## IN FLIGHT
- Orchestrator: local_9bb3d41c (Fable 5.1, high; detached; **context 45 %** at this rewrite, handover in progress). Rule since 08:00: `git log origin/main..HEAD`, read it, push in a separate call; never past an unverified worker commit. Review rule since 08:20 (PROJECT.md): every review is a hub card with pictures and `files` paths; the orchestrator links the hub in chat when asking.
- **Handover decided 2026-11-02 ~09:00 (context past 40 %):** no new workers from local_9bb3d41c; it finishes the two below (verify, push, cards), then Daniele starts the successor from `C:/Users/itisf/.claude/handoffs/1ab97086-9b4b-48fb-afb8-c28766300c88.md`. Workers running (2 of 3, started by Daniele from cards):
  - 🎮 **camera-feel-2** (Opus, local_e7daa046) **STOPPED by the usage limit** (resets 18:40 Bangkok): commits cdb2dce (tight follow, occlusion fixes, nearer/steeper per-area views; 12/14 in its isolated run) + e04b8e9 (WIP fix: snap() immediate, test_lounge portrait, floor view -36/5.6), **not verified, not pushed, hub cards not written** (pictures uploaded, blob ids in the report). Open: test_lounge "both main-side curtains in view" fails at the nearer floor camera: move the test spots east, accept one curtain, or keep the floor view farther. Next: a 🎮 worker resumes from `handoffs/camera-feel-2-2026-11-02.md`, then a 🔍 Verifier.
  - 🧹 **housekeeping** (Sonnet, local_a768e570): `docs/MANUAL.md` §5 (stakes v1 → v3) and §15 refresh, GDD §8 coaster count, untracked `before-*.png` and `.uid` leftovers, Kanit font files if unreferenced, hub Backlog mirror check. Docs and assets only.
- Finished today, verified, pushed: lounge-revamp 50a0623, lounge-followup e5d38a6, look-test 8067c7a, look-build 6cd9735 + 6df5288, menu-followups 6c7d9e4, stakes-fold 625f83f. Role notes `handoffs/<job>-2026-11-02.md`, reports `handoffs/worker-reports-2026-11/`. menu-followups session archived by Daniele.
- Queued: 🛠️ **needs/stakes build** (Sonnet or Opus) from `06-stakes.md` §10 + the build list in `handoffs/worker-reports-2026-11/stakes-fold.md`, **after Daniele accepts stakes-v3-review** (and O1–O4 if they change numbers); 🎨 look follow-ups once the three look cards are answered (corridor light, sconces, amber LEDs; optional: bake swatches into `bc_kit.py`); 🎨 kit pass for memory-corner props; 0.2.0 close after look-D acceptance (changelog, live manual §15).

## WAITING ON OWNER (Questions tab: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW#questions)
- **Look D:** look-d-accept, look-corridor-light, look-sconces-neon, look-amber-leds.
- **Stakes:** stakes-v3-review, stakes-o1-far-players, stakes-o2-revival-before-server, stakes-o3-memory-proof, stakes-o4-tuning.
- **Menu:** menu-errata-unsure, menu-bundle-was, menu-bundle-coins.
- **Lounge:** lounge-east-tables (the one open layout question), lounge-merch-items, lounge-board-wording.
- Coins tab: no edits yet. Facts pending: cocktail page, entrance/street photos, band and staff consent, Prae's lines, November poster, real merch list.

## PROMISED, NOT DONE
- Live manual (Claude Doc) §15 stale since venue v4; `docs/MANUAL.md` §5 still stakes v1 (housekeeping running).
- Memory upload at the TV corner (D5, counts as a real visit under v3); memory-corner props placeholders; portraits read edge-on in play.
- Raised couch places not walkable: Raised0 S0, Raised2 S1, Raised4 S0/S1.
- Thai strings are machine drafts everywhere new.
- Pour Perfect does not mark a drink as tried (not asked; decide with the needs build).
- Stale card "🎲 Real-world bridge chapter" (task_b873ccbd): dismiss, re-propose later.
- Export include filter `*.json`, `*.csv` once an export preset exists.

## NEXT THREE JOBS
0. 🛠️ **Web build on Vercel (Sonnet or Opus; Daniele's ask 2026-11-02, BACKLOG A8):** export templates for 4.6.1, Web export preset in `game/export_presets.cfg` (Compatibility, single-threaded, include `*.json,*.csv`, PWA on), `tools/build_web.py` that exports and stamps with `tools/version.py`, a `web/` output folder with a `vercel.json` (static, cache headers), Vercel project `bc-tamagotchi` (Daniele's Vercel account; the orchestrator has Vercel MCP tools), test on a phone browser: load time, frame rate (42 lights), touch, portrait HUD, save survives reload; then the performance pass with the phone numbers. A `*.vercel.app` URL first; custom domain later.
1. 🛠️ Needs/stakes build (on stakes-v3-review acceptance).
2. Look follow-ups + look-D acceptance, then close 0.2.0.
3. Performance pass (42 lights, phone measurement), then character creator, then the real-life bridge.
- Later: `docs/design/BACKLOG.md`.

## POINTERS
- Rules `PROJECT.md`; history `LOG.md`; decisions `docs/design/DECISIONS.md`; changelog `docs/CHANGELOG.md` (`python tools/changelog.py`); orchestrator gotchas `handoffs/orchestrator-2026-11-02.md`; hub source `docs/design/backlog-board.html`; verify script (scratchpad) = clean worktree of the SHA, import, 14 suites with empty APPDATA each.
