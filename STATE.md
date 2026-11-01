# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-02, new version opened by the new orchestrator)

## LIVE (main, pushed, verified in a clean worktree)
- No release build yet. `main` = venue v4 to the real floor map (accepted, **layout.json frozen**), doors you walk through, real sitting at every seat, stair, TV memory corner (upload stub), corridor neon, cutaway rule (walls solid until you pass the door), front-door start screen with the real sign and exit shot, brand fonts Lato + Kristi (Thai fallback IBM Plex Sans Thai Looped), portrait-first with a landscape toggle, the real Black Cabin menu (121 drinks, 34 dishes) at the bar and in Pour Perfect.
- Suites (run from `game/`): smoke_stairs, smoke_tap, smoke_hud, test_needs (106), test_minigames (828), smoke_loop, smoke_doors_sit, smoke_start (fixed b571c18: the no-cut check uses the engine delta; camera peak 7.9 m/s), test_menu (2373).
- Play: `docs/tech/02-playtest-guide.md`. Venue facts: `docs/venue/menu/`, `docs/venue/events/` (Oct 2026), opening hours Tue–Sun 19:00–02:00.

## IN FLIGHT
- New orchestrator: session local_78d0c67d (detached, top level). Handover checked: origin/main 51603f0, no workers were running; the old orchestrator's answers to "what is not in the files" are in `handoffs/orchestrator-2026-11-02.md`.
- Workers running: 🛠️ versioning (Sonnet, local_5a83e04a: af393ac committed, finishing captures + note); 🎮 feel-pass (Opus, local_5c0bdf0a: camera, transparent walls but the bottom 10 %, fluid movement, facing bug, seat orientation); 🎭 prae-owner (Opus, local_b5fbe4b1: Prae as owner, black hair, leather jacket, jeans, no hearts).
- Awaiting verification: de17eba (answers-batch3: Kristi neon + memory box, prices pinned, Pour Perfect 12 families per bar night) and af393ac (versioning 0.2.0).
- Queued, in order (max three workers): (1) when versioning closes, 🎮 nightlife actions (BACKLOG B12): "Light one up" in the smoking room, secret "Check the plumbing" in the toilet, drunk debuff 3–10 drinks, WASTED screen (DECISIONS playtest row).
  (2) when feel-pass closes (both edit `build_venue.gd` / the venue scene), 🏗️ lounge revamp + corridor portraits (BACKLOG B7, B9–B11; DECISIONS "Lounge revamp" row; `layout.json` unfrozen for the lounge and corridor walls only, refreeze on Daniele's acceptance).

## WAITING ON OWNER (Questions tab: https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW#questions)
- **Stakes answered** (DECISIONS row of 2026-11-02, 14 of 15; several differ from the recommendations: 21-day timer, 14-day ghost, real-bar revival only, any refill resets, stronger annoyances). Still open: **C1 coin sign-off** (`docs/design/04-coins-summary.md`) and **S13** (game visit vs real visit as the fatal need). Then a design worker folds the answers into `06-stakes.md`. Original cards: S1–S10 stakes, S11–S12 Flat rent, C1 coin sign-off, C2 drink pricing, F1 what is really upstairs. Source: `handoffs/stakes-design-2026-11-02.md`. After the answers: fold into `06-stakes.md` / `04-coins*.md`, apply the §12 amendments to the GDD and high concept, then a needs worker builds `06-stakes.md` §10 (also fix the stale `START_VALUE` comment in `rules.gd`).
- Open menu cards: cocktail page, misprints, "Try something new", soft-drink row, Thai brand names. (Address, lettering, corridor camera, memory-corner props, menu prices, Pour Perfect list were answered after the close; DECISIONS row "Questions tab, third batch".)
- Photos of the street front, street door and entrance corridor (next visit); band consent (Daniele asking Black Cabin).

## PROMISED, NOT DONE
- Live manual (Claude Doc https://claude.ai/artifact/6p6YVjvtt3EhjY599Bs8rQ) §15 not refreshed last version: venue v4, doors/seats, start screen, menu and fonts are missing.
- November event poster for `docs/venue/events/` (ask Daniele).
- The old orchestrator's stale card "🎲 Real-world bridge chapter" (task_b873ccbd) predates the real menu and events; Daniele can dismiss it, and the bridge job is re-proposed fresh when its turn comes.
- 🎲 Stakes chapter from Daniele's base proposal (DECISIONS 2026-11-02): total deletion, friend revival (e.g. zombie act on stage), only "go to Black Cabin" fatal, other needs minor annoyances; plus the one-page coin summary Daniele asked for; plus the Flat as a rented second-floor room unlock.
- Memory upload at the TV corner (BACKLOG D5); regulars' photos on the corridor wall (B7).
- Menu follow-ups: ordering from the menu does not mark a drink as tried; bundles in data but not shown; export include filter needs `*.json`, `*.csv` once an export preset exists.
- Memory-corner kit props (placeholders now); street front and door from real photos.
- Remove the unused Kanit font files.

## NEXT THREE JOBS
1. 🎲 Stakes + coins + Flat design: docs DONE (f62a858, `06-stakes.md` v2, `04-coins-summary.md`); waiting on the 15 Questions-tab cards, then the build.
2. Performance pass (42 lights; phone measurement before any phone build), then figure lighting and proportions.
3. Character creator; then the real-life bridge (events list from `docs/venue/events/`, Tonight tab, booking scaffold).
- Later: everything in `docs/design/BACKLOG.md`.

## POINTERS
- Rules `PROJECT.md` (incl. 2026-11-02 working rules); history `LOG.md`; owner decisions `docs/design/DECISIONS.md`; changelog `docs/CHANGELOG.md` (`python tools/changelog.py`); role notes `handoffs/`; worker reports `handoffs/worker-reports-2026-11/`; hub https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW.
