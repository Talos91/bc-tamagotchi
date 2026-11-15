# Report: 🎲 design-minigame — next minigame (B3), design only — 2026-11-15

## Evidence
- Commit **a02298f** (local main, not pushed): `docs/design/10-minigame-next.md` + 7 pictures in `docs/art/screens/minigame-next/`.
- Hub card **`minigame-next-pick`** (Backlog items, version 1, order 360): 3 options, rec = A, 3 images (/_blob/631b1ca3…, 608a2fe4…, edc7b506…), files list (doc, pictures, this report).
- Load id 2026-11-15-rules-powers-black-cabin-c33dc1 (profile rules-powers; no game-designer profile exists, rules-powers carries the project's minigame entry).
- No code, no tests run (design only); no Godot launched. Mocks are PIL drawings in the style-guide palette, venue halves are existing captures annotated.

## Concepts
- **A. Coaster Flip ★** — tall tables (zone `tall`, stub today); swipe up / tap to catch; Friends +8–12, cap 20/visit; S.
- **B. Shake & Serve** — bar; tap bottles + tap on beat; Drinks +20–30 (existing `pour_perfect` action) +5 Friends at great; shares bar's 3 tries; free drink (money call); M; needs the cocktail page.
- **C. Soi Dash** — lounge game cabinet (zone `cabinet`, stub, "Tap to try the Black Cabin game"); lane swipes; Nightlife +10–20; M.
- All pay standard 2/3/5 coins (04-coins); misses and 3 tries per 06-stakes §7.2; all fit `minigame_base.gd` unchanged.

## Open calls for Daniele (on the card / in the doc)
- The pick. A: Friends cap 20/visit vs daily-once per table; stack-to-beat per regular vs own best. B: free drink extension of "Pour Perfect free, always".

## Notes
- `git pull --rebase` refused (other sessions' unstaged files); committed own paths only, no stash. Local main was ahead 3 of origin at commit time.
- Profile feedback: no generic "game designer" profile; rules-powers fits implement-a-mechanic, its "branch off in your own worktree" step conflicts with this project's single shared checkout rule (PROJECT wins).
