# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-02 ~14:10 UTC)

## LIVE (origin/main 9556fc1; every code SHA on it verified 14/14 in a clean worktree, APPDATA empty per suite)
- Venue v4 to the real floor map, doors, seats, stair, start screen with the real sign, Lato + Kristi, portrait first + landscape toggle, real menu (121 drinks, 34 dishes), Prae owner, Tt regular #4, nightlife actions + WASTED, per-area camera with seven area buttons, lounge revamp + follow-up (accepted, **layout.json frozen**), look D (6cd9735 + 6df5288; acceptance pending), menu follow-ups (6c7d9e4; accepted), stakes v3 docs (625f83f; review pending), housekeeping 38fc2fa (MANUAL §5/§15, GDD §8, Kanit removed), **camera feel 2** (406d2fd + start-screen fix c97abde: tight follow, nothing hides the player, nearer per-area views, landscape distance x1.5, corridor clamp; acceptance pending on three cards).
- 14 suites (run from `game/`): smoke_stairs, smoke_tap, smoke_hud, test_needs, test_minigames, smoke_loop, smoke_doors_sit, smoke_start, test_menu, smoke_version, test_nightlife, test_seats, test_feel, test_lounge. Version 0.2.0 open (`docs/tech/versioning.md`). Play: `docs/tech/02-playtest-guide.md`.

## IN FLIGHT
- Orchestrator: **local_ddbbfc1d** (Fable 5.1; effort medium at start, Daniele asked to set high; **context ~11 %** at this rewrite; ~8 % at 13:20). Took over 13:10 UTC from local_9bb3d41c (handoff `C:/Users/itisf/.claude/handoffs/1ab97086-9b4b-48fb-afb8-c28766300c88.md`). Connectors all off. Never verifies, pushes code, publishes or deploys itself.
- No worker running. Today after the takeover: 🔍 verify-camera-2 FAILED 2b01291 (smoke_start 14.1 m/s); 🎮 camera-start-fix (c97abde: `rig.set_process(true)` before `rig.snap()` in `start_screen.gd`, injected-cut proof kept); 🔍 verify-camera-3 PASSED afd2e58 14/14 in a clean worktree and pushed (origin 9556fc1). Reports in `handoffs/worker-reports-2026-11/` (verify-camera-2, camera-start-fix, verify-camera-3); role notes `handoffs/camera-start-fix-2026-11-02.md`. Sessions to archive on Daniele's side: camera-feel-2 local_e7daa046, verify-camera-3 local_4fdca45a.
- Cards waiting for Daniele to start: 🛠️ Web build on Vercel (task_c3c14eb5, Sonnet) and 🧹 Housekeeping (task_d85a5ed6, Sonnet). Different paths; may run together. Not verified by anyone: windowed/phone camera feel (Daniele's playtest on the three camera cards).
## WAITING ON OWNER (Questions tab: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW#questions)
- **Camera:** camera-feel-2-accept, camera-closer-still, camera-patrons-in-front.
- **Look D:** look-d-accept, look-corridor-light, look-sconces-neon, look-amber-leds.
- **Stakes:** stakes-v3-review, stakes-o1-far-players, stakes-o2-revival-before-server, stakes-o3-memory-proof, stakes-o4-tuning.
- **Menu:** menu-errata-unsure, menu-bundle-was, menu-bundle-coins. **Lounge:** lounge-east-tables, lounge-merch-items, lounge-board-wording.
- Coins tab: no edits yet. Facts pending: cocktail page, entrance/street photos, band and staff consent, Prae's lines, November poster, real merch list.

## PROMISED, NOT DONE
- Hub page v12 lacks BACKLOG A8 and the camera cards' status (Housekeeping). Live manual (Claude Doc) §15 stale since venue v4.
- Standardisation (Master's note): profiles in vault `wiki/agents/general/`; PROJECT.md Working rules + Context budget and ORCHESTRATOR-HANDOVER.md become one pointer line to `wiki/concepts/claude-orchestration-method.md` plus Black Cabin deltas.
- Memory upload at the TV corner (D5); memory-corner props placeholders; portraits read edge-on in play; raised couch places not walkable (Raised0 S0, Raised2 S1, Raised4 S0/S1); Thai strings machine drafts; Pour Perfect does not mark a drink tried (decide with the needs build); stale card "🎲 Real-world bridge chapter" (task_b873ccbd) to dismiss; export include filter `*.json`, `*.csv` once a preset exists.
- Method v1.1 review by Daniele ~2026-11-16: LOG carries a "context %" per day.

## NEXT JOBS
0. 🛠️ **Web build on Vercel** (Sonnet or Opus; BACKLOG A8, DECISIONS 2026-11-02): export templates for 4.6.1, Web preset in `game/export_presets.cfg` (Compatibility, single-threaded, include `*.json,*.csv`, PWA on), `tools/build_web.py` exporting + stamping via `tools/version.py`, `web/` output with `vercel.json` (static, cache headers), Vercel project `bc-tamagotchi` on Daniele's account, phone check (load time, frame rate with 42 lights, touch, portrait HUD, save survives reload). Worker owns the preset, script, project and the phone check; the orchestrator receives the URL and evidence only. A `*.vercel.app` URL first.
1. 🧹 Housekeeping: standardisation pass, hub Backlog tab (A8, camera status), DECISIONS rows for new answers.
2. 🛠️ Needs/stakes build from `06-stakes.md` §10 + the build list in `handoffs/worker-reports-2026-11/stakes-fold.md`, after stakes-v3-review (and O1–O4 if numbers change).
3. Look follow-ups once the three look cards are answered; memory-corner kit props; look-D acceptance → close 0.2.0 (changelog, live manual §15).
4. Performance pass (phone numbers), character creator, real-life bridge. Later: `docs/design/BACKLOG.md`.

## POINTERS
- Rules `PROJECT.md`; history `LOG.md`; decisions `docs/design/DECISIONS.md`; changelog `docs/CHANGELOG.md` (`python tools/changelog.py`); orchestrator gotchas `handoffs/orchestrator-2026-11-02.md` (verify recipe lines 7–9, push rule line 31, hub schema 12–17); hub source `docs/design/backlog-board.html` (Housekeeping only); profiles `G:\My Drive\VAULTS\Talos Vault\wiki\agents\general\` + `game-dev\`.
