# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-02 ~16:50 UTC)

## LIVE (origin/main 2db20c8; every code SHA on it verified 14/14 in a clean worktree, APPDATA empty per suite)
- Venue v4 to the real floor map, doors, seats, stair, start screen with the real sign, Lato + Kristi, portrait first + landscape toggle, real menu (121 drinks, 34 dishes), Prae owner, Tt regular #4, nightlife actions + WASTED, per-area camera with seven area buttons, lounge revamp + follow-up (accepted, **layout.json frozen**), look D (6cd9735 + 6df5288; acceptance pending), menu follow-ups (6c7d9e4; accepted), stakes v3 docs (625f83f; review pending), housekeeping 38fc2fa (MANUAL §5/§15, GDD §8, Kanit removed), **camera feel 2** (406d2fd + start-screen fix c97abde: tight follow, nothing hides the player, nearer per-area views, landscape distance x1.5, corridor clamp; acceptance pending on three cards).
- 14 suites (run from `game/`): smoke_stairs, smoke_tap, smoke_hud, test_needs, test_minigames, smoke_loop, smoke_doors_sit, smoke_start, test_menu, smoke_version, test_nightlife, test_seats, test_feel, test_lounge. Version 0.2.0 open (`docs/tech/versioning.md`). Play: `docs/tech/02-playtest-guide.md`.

## IN FLIGHT
- Orchestrator: **local_ddbbfc1d** (Fable 5.1; effort medium at start, Daniele asked to set high; **context ~13 %** at this rewrite; 8 % 13:20, 11 % 14:10). Handoff `C:/Users/itisf/.claude/handoffs/1ab97086-9b4b-48fb-afb8-c28766300c88.md`. Connectors off. Never verifies, pushes code, publishes or deploys itself.
- 🛠️ web-build (Sonnet, archived) DONE and pushed: tooling verified by 🔍 verify-web-build (82ef3e6 14/14 in a clean worktree; build exit 0, 53.9 MB) and the script fixes 5728821 (clean step with retries, raw regexes, npx.cmd, `--out`) pushed as tooling/docs. **Deploy waits on Daniele:** `npx.cmd vercel login` once, then `python tools/build_web.py --deploy --out %LOCALAPPDATA%c-web` from the repo root; best from a clean state (after the needs build is verified), since the export takes the shared tree with other workers' uncommitted code. Phone numbers after the URL exists. Finding `cast.tt.name` given to needs-stakes.
- 🛠️ **needs-stakes-build** (Sonnet, local_a2f9ddd4) and 🎨 **look-followups** (Opus, local_c3d3ee21) running, resumed after the 16:10 PC crash (their uncommitted edits were intact). PC crash cause likely the load: four Godot processes + two exports at once; keep three workers and stagger builds and suite runs.
- 🧹 housekeeping-2 (Sonnet, local_cc42185f) DONE and pushed: 5f2bbf4, 95f2f27, c05cc05, 24489b1 (docs only, no game paths: pushed without suites). Report `handoffs/worker-reports-2026-11/housekeeping-2.md`. Session to archive on Daniele's side.
- Today earlier: verify-camera-2 FAIL → camera-start-fix c97abde → verify-camera-3 PASS afd2e58 (reports in `handoffs/worker-reports-2026-11/`). Sessions to archive: camera-feel-2 local_e7daa046.
- Context ~16 % at this rewrite.

## WAITING ON OWNER (Questions tab: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW#questions)
- **Web build:** `npx.cmd vercel login`, then `python tools/build_web.py --deploy --out %LOCALAPPDATA%c-web`; then a phone pass (load s, fps, tap walk, HUD, save survives reload). Card web-build-review.
- **Camera:** camera-feel-2-accept, camera-closer-still, camera-patrons-in-front (playtest of origin ≥ afd2e58).
- **Menu:** the unverifiable-spelling list for the bar is `docs/venue/menu/errata-for-black-cabin.md` (Daniele asked to be sent it; link it in chat).
- Coins tab: no edits yet. Facts pending: cocktail page, entrance/street photos, band and staff consent, Prae's lines, November poster, real merch list.
- Answered 2026-11-02 (DECISIONS row 07:35–08:19): look D accepted darker still, corridor dim white-red neon line, all red, sconces on the neon line, symmetric stage curtain, left singer → electric-piano band member; stakes v3 accepted, O1 first check-in gates real visits, O2 no revival before the server, O3 memory = photo on a checked-in night, O4 tuning as written; menu follow-ups accepted, bundles price-only and list-only; lounge east tables stay west, two Top-patrons posters (all time, this month), merch placeholders until the character creator.

## PROMISED, NOT DONE
- Hub tabs Daniele asked for (stakes-v3-review note): stakes rules + a maintained game bible (next 🧹 job). Live manual (Claude Doc) §15 stale since venue v4. Menu: bundles price-only/list-only not yet in code. Missing string `cast.tt.name` (web-build finding).
- Memory upload at the TV corner (D5); memory-corner props placeholders; portraits read edge-on in play; raised couch places not walkable (Raised0 S0, Raised2 S1, Raised4 S0/S1); Thai strings machine drafts; Pour Perfect does not mark a drink tried (decide with the needs build); stale card "🎲 Real-world bridge chapter" (task_b873ccbd) to dismiss; export include filter `*.json`, `*.csv` once a preset exists.
- Method v1.1 review by Daniele ~2026-11-16: LOG carries a "context %" per day.

## NEXT JOBS
0. 🛠️ Web build: tooling live, deploy waits on Daniele (above); then the phone pass → performance pass.
1. 🛠️ **Needs/stakes build** (Sonnet; card proposed): `06-stakes.md` §10 + build list in `handoffs/worker-reports-2026-11/stakes-fold.md`, with O1–O4 as answered; include the menu bundle price-only/list-only change and Pour Perfect marking a drink tried (decide in the brief: yes).
2. 🎨 **Look follow-ups** (Opus; card proposed): darker still with the player readable, corridor west-end neon line, sconces on the line, symmetric stage curtain, left singer → electric-piano player, two Top-patrons posters; bake look-D swatches into `bc_kit.py` if cheap. Then look-D close → 0.2.0 close (changelog, live manual §15).
3. 🧹 Housekeeping: hub tabs for stakes rules + game bible; live manual §15.
4. Memory-corner kit props; performance pass (phone numbers from the web build); character creator; real-life bridge. Later: `docs/design/BACKLOG.md`.

## POINTERS
- Rules `PROJECT.md`; history `LOG.md`; decisions `docs/design/DECISIONS.md`; changelog `docs/CHANGELOG.md` (`python tools/changelog.py`); orchestrator gotchas `handoffs/orchestrator-2026-11-02.md` (verify recipe lines 7–9, push rule line 31, hub schema 12–17); hub source `docs/design/backlog-board.html` (Housekeeping only); profiles `G:\My Drive\VAULTS\Talos Vault\wiki\agents\general\` + `game-dev\`.
