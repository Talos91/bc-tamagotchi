# Housekeeping report (🧹 Sonnet, 2026-11-02)

Commits on `main` (not pushed): `a05338b` docs, `90dbe12` .uid files, `f0f894f` Kanit removal (check `git log` after the rebase for final SHAs).

## Changed
- `docs/MANUAL.md` §5 rewritten to stakes v3 (21-day visit clock, stages 10/15/18, ghost 14 days, deletion day 35, revival by a real check-in once per 90 days, drag + misses with 3 tries, Out of Town the only pause, Flat rent 100 + 20/week), with a designed-vs-built table (only Out of Town and the 0.3 floor are built). Retitled "Stakes: mandatory care and the ghost window". Glossary: Last Call redefined, added Ghost window and Out of Town. Also fixed, outside the literal brief but same fact: §2 "Neglect" row (leaves Bangkok), §4 pointer to the Last Call exception, §9 coaster row (121), §12 Fonts line (Lato + Kristi, Kanit gone).
- `docs/MANUAL.md` §15 rewritten for 14cda24: live, 14 suites, known debt, designed only, Questions-tab pointer, facts wanted. Old "Still open (DECISIONS)" and "asks" tables removed (Questions tab and BACKLOG carry them).
- `docs/design/02-gdd.md` §8 Coaster row: "24 drinks" → real menu (121 drinks, 34 dishes), coasters = tried drinks. The sentence "all 24 coasters" two paragraphs below is untouched (brief said nothing else): needs the same fix.
- The live Claude Doc manual is not refreshed (orchestrator).

## Removed
- 22 untracked `docs/art/screens/lounge-revamp/before-*.png` (each has a committed `twoup-*.jpg`; none kept).
- `game/assets/fonts/Kanit-{Regular,SemiBold,Bold}.ttf` (+ `.import`, untracked) and `OFL-Kanit.txt`. Grep: only the Godot editor cache mentioned Kanit.
- NOT touched: 4 untracked `docs/art/screens/lounge-followup/before-*.png` (brief named only lounge-revamp; all four have a committed `twoup-*.jpg`, safe to delete).

## Committed .uid
capture_areas, capture_cast_tt, capture_feel, capture_look_build, capture_nightlife, test_feel (all scripts tracked).

## Suites after Kanit removal
Isolated copy (`git archive f0f894f game tools docs/venue`, import, APPDATA empty): **smoke_hud PASS, smoke_start PASS**, no errors. Fonts stay removed.

## Hub mirror (BACKLOG.md vs backlog-board.html), board is stale
- A1: md "built, awaiting acceptance" / html "done, accepted, layout frozen" (html newer; md should update).
- A2: md "done (228eb2e)" / html "done" (cosmetic). A3: md "in progress" / html "done".
- B2 md "planned (STATE job 3)"; B8 md "next, after A3" / html "done"; B9 md "landed, follow-up running, acceptance pending" / html "done, accepted, layout frozen"; B12 md "queued" / html "done".
- B10, B11, B7, B13: html lacks the 50a0623 / 6cd9735 details; B11 html "coin shop sheet in progress" is stale.
- Ids only in the board: A4, A5, A6, A7 (not in BACKLOG.md).
- Item wording differs on A3, B1, B2, B7, B8, B9, B11, B13, C3, D2 to D5 (D5 html lacks the v3 "counts as a real visit").
Several of these are BACKLOG.md being the stale side (A1, A3, B8, B9, B12 look finished): orchestrator to decide which file wins.

## For Daniele
Nothing needed. (GDD "all 24 coasters" line; the four lounge-followup before-pngs.)
