# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-04 ~10:30 UTC+7)

## LIVE (origin/main 3ef71dc; every code SHA on it verified 14/14 in a clean worktree, APPDATA empty per suite)
- Venue v4 to the real floor map, doors, seats, stair, start screen with the real sign, Lato + Kristi, portrait first + landscape toggle, real menu (121 drinks, 34 dishes), Prae owner, Tt regular #4, nightlife actions + WASTED, per-area camera with seven area buttons, lounge revamp + follow-up (accepted, **layout.json frozen**), look D (6cd9735 + 6df5288; acceptance pending), menu follow-ups (6c7d9e4; accepted), stakes v3 docs (625f83f; review pending), housekeeping 38fc2fa (MANUAL §5/§15, GDD §8, Kanit removed), **camera feel 2** (406d2fd + start-screen fix c97abde: tight follow, nothing hides the player, nearer per-area views, landscape distance x1.5, corridor clamp; acceptance pending on three cards).
- 15 suites (run from `game/`): smoke_stairs, smoke_tap, smoke_hud, test_needs, test_minigames, smoke_loop, smoke_doors_sit, smoke_start, test_menu, smoke_version, test_nightlife, test_seats, test_feel, test_lounge, test_touch (added 2026-11-03 with touch-anywhere b8f6d50). Version 0.2.0 open (`docs/tech/versioning.md`). Play: `docs/tech/02-playtest-guide.md`.

## IN FLIGHT
- Orchestrator: **local_ddbbfc1d** (Fable 5.1; effort medium, Daniele asked to set high; **context ~34 %** at this rewrite; 11-02: 8 → 19 %; 11-03: 23 → 31 %; 11-04: 34 %). Handoff `C:/Users/itisf/.claude/handoffs/1ab97086-9b4b-48fb-afb8-c28766300c88.md`. Connectors off. Never verifies, pushes code, publishes or deploys itself.
- **Daniele 11-04: the game was a huge success at Black Cabin on 11-03; polish the base game before any new feature** (`handoffs/owner-feedback-2026-11-04.md`, items 17–23). Three workers started 10:20 +7:
  - 🎮 **movement-polish** (Opus, local_600d506b): stick on a fixed world axis (not camera-relative), character no longer stuck between tables (nav settings, not furniture), new suite `test_walk` (to list in PROJECT.md on report), card movement-polish-review + axis-choice card.
  - 🛠️ **web-labels-debug** (Sonnet, local_50480d64): the five runtime CSV loaders resolve in the web export (raw `name.x.y` keys), key-coverage check, web screenshots; pre-alpha debug panel on touch (clear WASTED lockout, force WASTED, clock jumps, ghost/revival flow, reset save) behind a `PRE_ALPHA` flag; card web-labels-debug-review.
  - 🛠️ **iphone-load** (Sonnet, local_a0ce7579): why Safari on iPhone does not load the build (WebGL2, wasm memory, headers, PWA, shell), fixes in preset/shell/vercel.json, loading-screen failure message, iPhone checklist; card iphone-load-review.
- 🏗️ venue-fixes (local_0ea22856) parked by Daniele's wish: venue changes from the real place are coming.
- After the three: one 🔍 verifier (16 suites if test_walk lands), Daniele redeploys, then the performance pass (item 16) and the **character creator** (item 22, next feature).

## WAITING ON OWNER (Questions tab: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW#questions)
- **Web build:** live at https://bc-tamagotchi.vercel.app; phone pass (load s, fps, tap walk, HUD, save survives reload). Card web-build-review.
- **Camera:** camera-feel-2-accept, camera-closer-still, camera-patrons-in-front (playtest of origin ≥ afd2e58).
- **Menu:** the unverifiable-spelling list for the bar is `docs/venue/menu/errata-for-black-cabin.md` (Daniele asked to be sent it; link it in chat).
- Coins tab: no edits yet. Facts pending: cocktail page, entrance/street photos, band and staff consent, Prae's lines, November poster, real merch list.
- Answered 2026-11-02 (DECISIONS row 07:35–08:19): look D accepted darker still, corridor dim white-red neon line, all red, sconces on the neon line, symmetric stage curtain, left singer → electric-piano band member; stakes v3 accepted, O1 first check-in gates real visits, O2 no revival before the server, O3 memory = photo on a checked-in night, O4 tuning as written; menu follow-ups accepted, bundles price-only and list-only; lounge east tables stay west, two Top-patrons posters (all time, this month), merch placeholders until the character creator.

## PROMISED, NOT DONE
- Live manual (Claude Doc) §15 stale since venue v4. Hub tabs Stakes rules / Game bible not yet viewed in a browser by anyone. Needs build left out (worker's call): Retire settings screen, audio duck, postcards beyond the home text. Camera rig: exit sign and sconce lag a moment when the north wall sinks (cut rule in camera_rig.gd). Web: ♥ glyph missing in the web font; ui/menu/nightlife runtime CSV loaders unverified in web; Thai names unverified.
- Memory upload at the TV corner (D5); memory-corner props placeholders; portraits read edge-on in play; raised couch places not walkable (Raised0 S0, Raised2 S1, Raised4 S0/S1); Thai strings machine drafts; Pour Perfect does not mark a drink tried (decide with the needs build); stale card "🎲 Real-world bridge chapter" (task_b873ccbd) to dismiss; export include filter `*.json`, `*.csv` once a preset exists.
- Method v1.1 review by Daniele ~2026-11-16: LOG carries a "context %" per day.

## NEXT JOBS
0. Polish batch running (movement, labels + debug panel, iPhone). Then 🛠️ performance pass (item 16: entrance lag; shader warm-up, light budget, first vs second entry).
0b. 🎭 **Character creator** (Opus): next feature after the polish (item 22); design first from `docs/design/02-gdd.md` and `03-cast.md` (merch items wait on it).
1. 🛠️ **Needs/stakes build** (Sonnet; card proposed): `06-stakes.md` §10 + build list in `handoffs/worker-reports-2026-11/stakes-fold.md`, with O1–O4 as answered; include the menu bundle price-only/list-only change and Pour Perfect marking a drink tried (decide in the brief: yes).
2. 🎨 **Look follow-ups** (Opus; card proposed): darker still with the player readable, corridor west-end neon line, sconces on the line, symmetric stage curtain, left singer → electric-piano player, two Top-patrons posters; bake look-D swatches into `bc_kit.py` if cheap. Then look-D close → 0.2.0 close (changelog, live manual §15).
3. 🧹 Housekeeping: hub tabs for stakes rules + game bible; live manual §15.
4. Memory-corner kit props; performance pass (phone numbers from the web build); character creator; real-life bridge. Later: `docs/design/BACKLOG.md`.

## POINTERS
- Rules `PROJECT.md`; history `LOG.md`; decisions `docs/design/DECISIONS.md`; changelog `docs/CHANGELOG.md` (`python tools/changelog.py`); orchestrator gotchas `handoffs/orchestrator-2026-11-02.md` (verify recipe lines 7–9, push rule line 31, hub schema 12–17); hub source `docs/design/backlog-board.html` (Housekeeping only); profiles `G:\My Drive\VAULTS\Talos Vault\wiki\agents\general\` + `game-dev\`.
