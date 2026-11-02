# Report: touch-anywhere control + slide-away area buttons (🎮 Sonnet, 2026-11-03)

## EVIDENCE
- Code SHA: **b8f6d50** (local main, not pushed). Note `handoffs/touch-anywhere-2026-11-02.md`.
- Suites (headless, empty APPDATA, tree = dd4e03c + my paths): smoke_tap PASS, smoke_hud PASS, test_feel PASS (0 failures), smoke_start PASS, **test_touch PASS (22 checks, new)**.
  **smoke_loop FAIL (11) and test_minigames FAIL (1 of 1498): not mine.** Both fail identically in a clean worktree of HEAD without my changes (smoke_loop checked there; test_minigames fails on the check `S.t("cast.tt.name") == "Tt"` while strings.csv says "Ty" since dd4e03c). smoke_loop: the walk to the Long Table (approach 3.9, 5.0) ends at (3.93, 3.01), so the zone never matches; the player stops 2 m short, cause unknown (layout/patron/nav, not input). The needs worker's report said both passed, probably run before the Ty rename or the look-D follow-ups merged.
- Hub card: **touch-anywhere-review** (Questions tab, ref A9, order 340), 4 pictures + files.
- Captures: `docs/art/screens/touch-anywhere/` (1-hud-no-stick, 2-debug-ring-only, 3-areas-hidden, 4-areas-back; portrait and landscape). No stick graphic in any HUD capture.
- Real window input (capture_touch.gd, both orientations): drag on play area gives stick 0.8, release gives 0, a drag starting on an area button gives 0.

## What changed
- `touch_joystick.gd`: full-screen, below the Hud, PASS filter; drag past 24 px = stick, tap falls through to tap-to-walk; optional faint ring behind `TouchJoystick.debug_ring`.
- `main.tscn`: Joystick node now full-rect and before Hud. `main.gd`, `player.gd`: comments only.
- `needs_hud.gd`: tab on the right edge slides the area column off and back; static state for the session (item 14).

## Calls for the orchestrator
1. Add `test_touch` to PROJECT.md "Tests" (fifteenth suite).
2. Fix the two stale suites (Ty rename in test_minigames; smoke_loop Long Table walk) before the verifier's full run; smoke_loop needs a look at why the walk stops short.
3. Real-phone feel (stick radius 90 canvas px, drag threshold 24) not tried.
4. Portrait captures are 1080x1421 (screen-clamped window).
5. I briefly reverted and restored my own five files in the shared tree to test a baseline (restored byte-identical, committed); no other session's files touched.
