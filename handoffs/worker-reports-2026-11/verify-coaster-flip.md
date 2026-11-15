# verify-coaster-flip — 🔍 Verifier (Sonnet 5.5), 2026-11-15
SHA verified: b2de123 (03177a7 Coaster Flip code + b2de123 docs). Clean detached worktree, import exit 0, empty APPDATA per suite, one Godot at a time.
VERIFY b2de123: PASS 21/21 suites (smoke_doors_sit/hud/loop/stairs/start/tap/version, test_avatar/coaster_flip/debug_tools/feel/lounge/menu/minigames/needs/nightlife/seats/string_keys/tonight/touch/walk). No reruns, no flakes seen.
Web build: exit 0, 54.3 MB.
Push: fast-forward fea81ec..b2de123 (2 commits); `git ls-remote origin main` = b2de123efce9f58108692d41f931e2c533938ac8.
Suite list at b2de123 matches PROJECT.md Tests (21). Working tree has an extra untracked test_neon_moth.gd (builder's, not in this SHA, not verified/pushed).
Done-when: 21/21 pass; web build pass; origin/main = b2de123 pass.
Not verified: Coaster Flip feel/play on a real phone; visuals (diff only: coaster_flip.gd/.tscn, rules.gd, venue_session.gd, strings.csv; suite covers logic).
Waited for an Ooze Godot run (test_seats, then a shots run) to finish before starting.
Logs: scratchpad verify-b2de123 (temp, not kept).

## Addendum: verify-neon-moth (a1a43b8)
VERIFY a1a43b8: PASS 22/22 suites (incl. test_neon_moth), web build exit 0 (54.3 MB). First import crashed with the known exit 3221225477; rerun once, then clean. Pushed adc8c01..a1a43b8 (8ff310c Neon Moth + a1a43b8 docs); ls-remote origin main = a1a43b86f39d568f2bd69c89114c278714e41d2f. Suite list matches PROJECT.md (22). Not verified: real-device feel. Waited for the builder's Godot import first.
