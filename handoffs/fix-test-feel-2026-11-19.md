# fix-test-feel role note (2026-11-19)
State: done. test_feel buffer-walk failure was date-driven, not code: Cast.night() follows the clock; Prae (mali) is in on even nights and rotates WestTable0 / Table0 / BufferTall3 by (n/2)%3. Night 20776 (2026-11-19) = BufferTall3, so her Zones/Tag_mali sign (Label3D, no_depth_test) covers the player 8 of 147 ticks at the end of the buffer walk. 2026-11-18 was odd (Prae out), hence the pass on cafe83f.
Fix: game/tests/test_feel.gd pins Cast.night_override = 0 (like smoke_loop).
Gotcha / open: on her buffer-table nights the sign really can overlap the player in game; look change not made (owner decides). Any other suite that walks near the three Prae tables is date-sensitive unless it pins the night.
