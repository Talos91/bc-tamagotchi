# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-09 ~17:40 UTC+7, first rewrite of 🎛️ local_7f958171)

## LIVE (origin/main eef9b04; every code SHA on it verified 17/17 in a clean worktree, APPDATA empty per suite)
- Venue v4 to the real floor map, doors, seats, stair, start screen with the real sign, Lato + Kristi, portrait first + landscape toggle, real menu (121 drinks, 34 dishes), Prae owner, Tt regular #4, nightlife actions + WASTED, per-area camera with seven area buttons, lounge revamp + follow-up (accepted, **layout.json frozen**), look D (6cd9735 + 6df5288; acceptance pending), menu follow-ups (accepted), stakes v3 docs (review pending), camera feel 2 (406d2fd + c97abde; acceptance pending), web build on Vercel (docs/tech/03-web-build.md), polish batch 11-04 (movement nav fixes, camera-relative stick; string tables + debug panel; iPhone audio-worklet 404 fix + failure banner).
- 17 suites (run from `game/`, list in PROJECT.md Tests). Version 0.2.0 open (`docs/tech/versioning.md`). Play: `docs/tech/02-playtest-guide.md`. Live build: https://bc-tamagotchi.vercel.app at 8889dce (11-04; Daniele redeploys with `python tools/build_web.py --deploy --out %LOCALAPPDATA%\bc-web`).

## IN FLIGHT
- Orchestrator: **local_7f958171** (Fable 5.1, from 2026-11-09 ~17:15; successor of local_ddbbfc1d, load id 2026-11-09-orchestrator-black-cabin-4e4cbd). **Context ~8 %** at this rewrite. Effort shows "medium" in the session metadata; the handover asked high (Daniele sets it in the picker). Old orchestrator's "not in the files" answer: asked 17:25, pending; Master check-in sent 17:30.
- **No worker running.** 🏗️ venue-fixes local_0ea22856 parked for Daniele's venue changes from the real place (message it, no new venue worker). Idle, done, to archive from the newest end: housekeeping-loader local_d94fc4ff, web-labels-debug local_50480d64; old orchestrator local_ddbbfc1d after its answer (Daniele archives).
- Proposed this turn (cards; Daniele starts): 🎨 character-creator design (item 22, Opus, profile voxel-art; design doc + review card first, build after his yes).
- Method state: vault server `talos-vault`; workers start with `load_agent(<role>, "black-cabin", ...)`, close with `capture(kind="report", replies_to=<load id>)`; briefs end with the §4 self-handover line; Verifier = `godot-verify-push` skill on Sonnet; orchestrator pushes only docs by SHA after a separate `git log origin/main..HEAD` check. No `### Social features` entry in PROJECT.md yet (needed before the item-24 worker loads; Housekeeping adds it).

## WAITING ON OWNER (Questions tab: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW#questions)
- **Live build 8889dce, no feedback yet:** phone pass numbers (load s, fps, model, first vs second entry) gate the performance pass (item 16); iPhone retest (banner names the failure); debug panel. Card web-build-review.
- Cards open: needs-stakes-review (+4), look-followups-review (+3 incl. layout-export), touch-anywhere-review, venue-fixes-review (+2), web-labels-debug-review, iphone-load-review, movement-polish-review, cast-tonight-review, look-d-accept (0.2.0 close waits on it), camera-feel-2-accept, camera-closer-still, camera-patrons-in-front.
- Menu spelling list for the bar: `docs/venue/menu/errata-for-black-cabin.md` (link it in chat). Facts pending: cocktail page, entrance/street photos, band and staff consent, Prae's lines, November poster, real merch list. Venue changes from the real place: his list → venue-fixes session.

## PROMISED, NOT DONE
- Live manual (Claude Doc) §15 stale since venue v4; hub tabs Stakes rules / Game bible not yet viewed by Daniele. Needs build left out: Retire settings screen, audio duck, postcards beyond the home text. Camera rig: exit sign and sconces lag when the north wall sinks. Web: ♥ glyph missing in the web font; Thai names unverified in web.
- Memory upload at the TV corner (D5); memory-corner props placeholders; raised couch places not walkable; Thai strings machine drafts; stale card "🎲 Real-world bridge chapter" (task_b873ccbd) to dismiss; export include filter `*.json`, `*.csv`.
- Method v1.1 review by Daniele ~2026-11-16: LOG carries a "context %" per day.

## NEXT JOBS
0. 🛠️ **Performance pass** (item 16, Sonnet): waits for Daniele's phone numbers. Scope when they arrive: shader warm-up behind the start screen, light budget (42 lights, Compatibility renderer), door swing + camera pull-back split, first vs second entry measured in the web build.
1. 🎨 **Character creator** (item 22, Opus, voxel-art profile): design first from `docs/design/02-gdd.md` §7 (creator lite in the launch scope line 583: 3 bodies, 6 skins, 4 hairs, 3 outfits, 4 personalities) and `03-cast.md`; kit in `game/assets/chars/` (`tools/blender/bc_chars.py`, presets, manifest); merch items wait on it. Card proposed.
2. 🌐 **Presence multiplayer design** (item 24, Opus, social-features profile): after the creator spec; presence events via real check-ins + table QR, notifications, no live movement; replaces GDD wave 4 live-sync; small backend (Supabase, Daniele's account).
3. Look-D acceptance → close 0.2.0 (changelog, live manual §15). 🧹 Housekeeping: Social features entry in PROJECT.md, hub tabs, manual §15, archive idle sessions.
4. Later: memory-corner props, real-life bridge, `docs/design/BACKLOG.md`.

## POINTERS
- Rules `PROJECT.md`; history `LOG.md`; decisions `docs/design/DECISIONS.md`; changelog `docs/CHANGELOG.md` (`python tools/changelog.py`); orchestrator gotchas `handoffs/orchestrator-2026-11-02.md` (verify recipe lines 7–9, push rule line 31, hub schema 12–17); owner words `handoffs/owner-feedback-2026-11-02.md`, `-11-04.md`; hub source `docs/design/backlog-board.html` (Housekeeping only); profiles vault `wiki/agents/general/` + `game-dev/`; previous stint recap vault `raw/claude-exports/2026-11-09-black-cabin-orchestrator-stint-ddbbfc1d.md`.
