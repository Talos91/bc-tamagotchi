# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-02 ~08:15 UTC)

## LIVE (origin/main ed400d9, every code SHA verified 14/14 in a clean worktree)
- Venue v4 to the real floor map, doors, seats, stair, start screen with the real sign, Lato + Kristi, portrait first + landscape toggle, real menu (121 drinks, 34 dishes), Prae owner, Tt regular #4, nightlife actions + WASTED, per-area camera with seven area buttons, **lounge revamp** (merch coin shop top right, memory corner top left, game machine by the stair foot, Top patrons board under the stairs, ten corridor portraits with patron messages, curtain seen from the main room, lane to Raised3; 50a0623 + e5d38a6, accepted, **layout.json frozen**), **look D first pass** (6cd9735: blackish walls, grey-top north wall with neon line, voxel cement floor, red light).
- 14 suites (run from `game/`): smoke_stairs, smoke_tap, smoke_hud, test_needs, test_minigames, smoke_loop, smoke_doors_sit, smoke_start, test_menu, smoke_version, test_nightlife, test_seats, test_feel, test_lounge. Version 0.2.0 open (`docs/tech/versioning.md`). Play: `docs/tech/02-playtest-guide.md`. Venue facts: `docs/venue/`.

## IN FLIGHT
- Orchestrator: local_9bb3d41c (high; **Fable 5.1 since ~08:00 UTC**, Opus before; detached, top level). Daniele's audit of the Opus hours (08:05): all SHAs verified and pushed, notes complete, Coins tab unedited; one gap, the camera-clunky answer, now a DECISIONS row. Two push slips (commits pushed before verify, both passed later): rule in `handoffs/orchestrator-2026-11-02.md`: `git log origin/main..HEAD`, read it, then push in a separate call.
- Workers (3 of 3):
  - 🎨 **look-build** (Opus, local_255ee1ab): after 6cd9735, Daniele's additions: walls in the floor's voxel finish, lighting halfway between today and the real bar (red neon + dim candle pools), stray frame at the bar removed, reindeer head over the cashier (photo 16). Owns `build_venue.gd`, `venue.tscn`, `venue_looks.gd`, `bc_kit.py`. Report `handoffs/worker-reports-2026-11/look-build.md`.
  - 🧹 **menu-followups** (Sonnet, local_0a254a5f): misprints corrected in game + errata list for Black Cabin, Try something new = six real drinks one per family, bar soft row = Coke, ordering marks a drink tried, bundles shown. Owns `game/data/menu.json`, `game/scripts/menu/`, `strings_menu.csv`, `test_menu.gd`, `docs/venue/menu/`.
  - 🎲 **stakes-fold** (Opus, local_9977e523): folds the 15 stakes/coins/Flat answers into `06-stakes.md` v3, `04-coins.md` / `-summary.md`, GDD + high concept §12 amendments; docs only; ends with the build list for the needs worker.
- Done this version, verified, pushed, archived: lounge-revamp (50a0623), lounge-followup (e5d38a6), look-test (8067c7a, tool only). Role notes `handoffs/<job>-2026-11-02.md`, reports `handoffs/worker-reports-2026-11/`.
- Queued: 🎮 camera feel 2 (Opus; DECISIONS "Camera, what feels clunky": trails behind, walls/furniture in the way, too far/steep) **after look-build**; 🛠️ needs build of `06-stakes.md` §10 after stakes-fold (also the stale `START_VALUE` comment in `rules.gd`); 🎨 kit pass for memory-corner props; 🧹 housekeeping (untracked `before-*.png` in `docs/art/screens/lounge-revamp/`, capture `.uid` files, Kanit font files; test_feel wall-clock flake).

## WAITING ON OWNER (Questions tab)
- Open cards: lounge-east-tables (both east tables moved, not only the rectangle; the one open layout question), lounge-merch-items, lounge-board-wording. Look-D acceptance card comes after look-build.
- Coins tab: no edits yet (all rows v1). When rows get `edited_at`, copy into `04-coins.md` and the rules.
- Facts pending: cocktail page (separate printed menu), entrance/street photos (next visit), band and staff consent, Prae's lines, November event poster, real merch list (for the later real-life shop).

## PROMISED, NOT DONE
- Live manual §15 (Claude Doc) stale since venue v4.
- Memory upload at the TV corner (D5); memory-corner props still placeholders; corridor portraits read edge-on in play (sheet shows them full size).
- Raised couch places not walkable: Raised0 S0, Raised2 S1, Raised4 S0/S1 (tables still open by tap).
- Thai strings are machine drafts everywhere new (Black Cabin staff to check).
- Stale card "🎲 Real-world bridge chapter" (task_b873ccbd) predates the real menu; dismiss, re-propose later.
- Export include filter needs `*.json`, `*.csv` once an export preset exists.

## NEXT THREE JOBS
1. 🎮 Camera feel 2 (after look-build), then look-D acceptance + 0.2.0 close (changelog, manual §15).
2. 🛠️ Needs/stakes build from `06-stakes.md` v3 (after stakes-fold).
3. Performance pass (42 lights, phone measurement), then character creator, then the real-life bridge.
- Later: `docs/design/BACKLOG.md`.

## POINTERS
- Rules `PROJECT.md`; history `LOG.md`; decisions `docs/design/DECISIONS.md`; changelog `docs/CHANGELOG.md` (`python tools/changelog.py`); orchestrator gotchas `handoffs/orchestrator-2026-11-02.md`; hub https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW (Backlog, Questions = db `items`, Coins = db `coins`; source `docs/design/backlog-board.html`).
