# Role note: 🎲 design-minigame (B3, 0.3.0) — 2026-11-15

## State now
- Design only, done: `docs/design/10-minigame-next.md` (a02298f, local main, not pushed). Pictures `docs/art/screens/minigame-next/`.
- Hub card `minigame-next-pick` (items, order 360, kind design): A Coaster Flip (rec) / B Shake & Serve / C Soi Dash. Waiting on Daniele.
- Nothing built; no rules.gd, BACKLOG, DECISIONS or version edits.

## Next step (build round, after Daniele's pick)
- A Coaster Flip: `game/scripts/minigames/coaster_flip.gd` on `minigame_base.gd`; `ACTIONS["coaster_flip"]` friends [8,12] cap 20/visit (pending his answer to the two open calls in §A); a row for zone kind `tall` in `venue_session.gd` `rows_for` + `ROW_GAMES`; strings EN/TH; `test_minigames` cases; role suites test_needs, test_minigames, smoke_loop, test_menu, test_nightlife.
- B needs the cocktail page (or the classics fallback) and a shared bar try counter; C needs a seeded street per Bangkok date.

## Gotchas
- `git pull --rebase` refuses while other sessions have unstaged files in the shared tree: commit own paths without pulling, never stash.
- Pictures regenerate from a PIL script (scratchpad, not kept); venue captures used: camera-feel-2 portrait-area-buffer/bar (1080x1421), camera-areas after-portrait-item-cabinet.
- Zones `tall` and `cabinet` are stubs in `venue_zones.gd` (generic sit sheet): homes for new games with no layout change (layout.json frozen).
