# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-02, new version opened by the new orchestrator)

## LIVE (main, pushed, verified in a clean worktree)
- No release build yet. `main` = venue v4 to the real floor map (accepted, **layout.json frozen**), doors you walk through, real sitting at every seat, stair, TV memory corner (upload stub), corridor neon, cutaway rule (walls solid until you pass the door), front-door start screen with the real sign and exit shot, brand fonts Lato + Kristi (Thai fallback IBM Plex Sans Thai Looped), portrait-first with a landscape toggle, the real Black Cabin menu (121 drinks, 34 dishes) at the bar and in Pour Perfect.
- Suites (run from `game/`): smoke_stairs, smoke_tap, smoke_hud, test_needs (106), test_minigames (828), smoke_loop, smoke_doors_sit, smoke_start, test_menu (2373).
- Play: `docs/tech/02-playtest-guide.md`. Venue facts: `docs/venue/menu/`, `docs/venue/events/` (Oct 2026), opening hours Tue–Sun 19:00–02:00.

## IN FLIGHT
- New orchestrator: session local_78d0c67d (detached, top level). Handover checked: origin/main 51603f0, no workers were running; the old orchestrator's answers to "what is not in the files" are in `handoffs/orchestrator-2026-11-02.md`.
- Workers running (started 2026-11-02): 🛠️ smoke-start-flake (Sonnet, local_7e81e277: `game/tests/smoke_start.gd`, plus committing `smoke_loop.gd.uid` and ignoring `__pycache__/`); 🎲 stakes-design (Opus, local_13d0486b: docs only, `06-stakes.md`, `04-coins-summary.md`, the Flat); 🖼️ answers-batch3 (Opus, local_084d7fb8: Kristi lettering on the corridor neon and memory box, dimmed THB prices, Pour Perfect rotation of 12).

## WAITING ON OWNER (Questions tab: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW#questions)
- Open cards: cocktail page, misprints, "Try something new", soft-drink row, Thai brand names. (Address, lettering, corridor camera, memory-corner props, menu prices, Pour Perfect list were answered after the close; DECISIONS row "Questions tab, third batch".)
- Photos of the street front, street door and entrance corridor (next visit); band consent (Daniele asking Black Cabin).

## PROMISED, NOT DONE
- **Failing test, fix first (in flight):** `smoke_start`'s "no cut" check (camera speed < 12 m/s per frame, `game/tests/smoke_start.gd:113`) reads 13–14.6 m/s; cb8fb07 went 1 pass / 1 fail, ccc6417 (real menu) 4/4 fail clean and 2/2 in the shared tree, so diagnose the menu's startup load before calling it a flake.
- Live manual (Claude Doc https://claude.ai/artifact/6p6YVjvtt3EhjY599Bs8rQ) §15 not refreshed last version: venue v4, doors/seats, start screen, menu and fonts are missing.
- November event poster for `docs/venue/events/` (ask Daniele).
- The old orchestrator's stale card "🎲 Real-world bridge chapter" (task_b873ccbd) predates the real menu and events; Daniele can dismiss it, and the bridge job is re-proposed fresh when its turn comes.
- 🎲 Stakes chapter from Daniele's base proposal (DECISIONS 2026-11-02): total deletion, friend revival (e.g. zombie act on stage), only "go to Black Cabin" fatal, other needs minor annoyances; plus the one-page coin summary Daniele asked for; plus the Flat as a rented second-floor room unlock.
- Memory upload at the TV corner (BACKLOG D5); regulars' photos on the corridor wall (B7).
- Menu follow-ups: ordering from the menu does not mark a drink as tried; bundles in data but not shown; export include filter needs `*.json`, `*.csv` once an export preset exists.
- Memory-corner kit props (placeholders now); street front and door from real photos.
- Remove the unused Kanit font files.

## NEXT THREE JOBS
1. 🎲 Stakes + coins + Flat design (Opus, docs only), then answers from the tab folded in.
2. Performance pass (42 lights; phone measurement before any phone build), then figure lighting and proportions.
3. Character creator; then the real-life bridge (events list from `docs/venue/events/`, Tonight tab, booking scaffold).
- Later: everything in `docs/design/BACKLOG.md`.

## POINTERS
- Rules `PROJECT.md` (incl. 2026-11-02 working rules); history `LOG.md`; owner decisions `docs/design/DECISIONS.md`; changelog `docs/CHANGELOG.md` (`python tools/changelog.py`); role notes `handoffs/`; worker reports `handoffs/worker-reports-2026-11/`; hub https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW.
