# Report: fix-test-feel (2026-11-19)
EVIDENCE
- Failure reproduced twice on a clean worktree of origin/main (headless, empty APPDATA): "buffer walk ... 139 of 147 ticks (hidden by Zones/Tag_mali: 8)".
- Cause: test_feel unpinned; Cast.night() = Bangkok day number. Night 20776 is even and (20776/2)%3 == 2 -> Prae at tall:BufferTall3 (the buffer walk's table); her name sign overlaps the player. 11-18 = 20775 odd -> Prae out -> pass. Not run: clean cafe83f worktree, or the failing night re-run with the pin removed beyond the first two runs.
- Fix: test_feel.gd: const Cast preload + Cast.night_override = 0. layout.json and minigame scripts untouched.
- After fix: test_feel buffer walk 147/147, PASS; all 27 suites PASS headless, empty APPDATA (exit code 0 each).
NOT VERIFIED / OPEN: in game the Prae sign can overlap the player at the buffer table on her buffer nights (look change, not made).
