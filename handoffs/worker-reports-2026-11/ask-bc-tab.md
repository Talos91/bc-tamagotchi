# 🧹 ask-bc-tab — report (2026-11-03, Sonnet)

## EVIDENCE
- Commit `93db64f` (local, not pushed): ask-black-cabin.md, backlog-board.html, build_hub_tabs.py, screenshot, role note.
- Hub republished to the SAME url https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW: service Version 16 (id 1793720092-9ce8), page footer "v15". No new artifact.
- Screenshot `docs/art/screens/hub/ask-black-cabin-v15.png` (375×812): tab bar shows "Ask Black Cabin", panel renders, checkboxes and file names wrap cleanly.
- CAVEAT: the browser pane is not signed in to claude.ai (it shows "Sign in"), so the screenshot is of the identical local `backlog-board.html` (the file just published), page width forced to 375, not of the live URL. The live page renders the same HTML; Daniele should open `#ask` once on the phone.

## Files
- `docs/design/ask-black-cabin.md` (59 lines): 1 Menu (errata #7–#11, three bundle "was" prices, six fixed misprints, Thai names, cocktail page), 2 Facts (November poster, merch, hours, door line, weekly calendar, Prae's full name, bridge), 3 People (consents staff/band/performers/Prae/Ty, Prae's lines, performer names and instruments, photos with instruments, songs, band tee, soundcheck clip, bartender pack), 4 Photos (street front, door, corridor, day version, buffer window, toilet corridor, TV corner, stage), 5 Show them (live URL; look D, Ty and Prae, touch control).
- `docs/design/build_hub_tabs.py`: key `ask` added. `backlog-board.html`: nav button, panel, `tabs` map in the page script (it was not generic), footer v15.

## Could not source / calls for the orchestrator
- Ty "if he is a real person": nothing in the docs says he is; I worded it conditionally. Drop the item if Ty is invented.
- Opening hours come only from public listings (STATE.md); item says "confirm".
- "Prae's family name": DECISIONS 2026-11-02 lists "Prae's full name" as still open; kept.
- The first publish was refused because the live version had not been read; fixed by reading, then republishing.
- Local main has uncommitted/untracked files of other sessions; I did not pull (pull --rebase refused). Push is yours.
