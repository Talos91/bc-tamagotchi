# 🛠️ needs/stakes build — role note (2026-11-02)

Session: tech worker (Sonnet) started by the orchestrator local_ddbbfc1d. Report: `handoffs/worker-reports-2026-11/needs-stakes-build.md`.

## What it is
`docs/design/06-stakes.md` §10 built with the answers O1–O4 (DECISIONS row "Questions tab, answered 07:35–08:19").

## Where things live now
- `game/scripts/rules.gd`: the §10.6 constants, `stake_stage()`, `ACTIONS["minigame_played"]`.
- `game/scripts/needs.gd`: the fatal clock (`last_counted_visit`, `stake_paused`, `days_since_visit()`), death inside `advance_game` (exact at 21.0 days, never inside a visit), ghost freeze, `check_in()` (the only revival; the debug "Fake check-in" calls it), `memory_shared()` (O3), `real_visit_required` + `has_checked_in` (O1), annoyances + drag in `apply_action`, minigame tries/miss line, `retire()`, `complete_deletion()`.
- `game/scripts/minigames/`: `minigame_base.gd` (tier -1 = miss, `miss_below`, `fumble`), `result_card.gd` (tries, miss, `minigame_played`), `minigame_frame.gd` (sets miss line and fumble from Needs).
- UI: `needs_hud.gd` (annoyance chips, Last Call chip), `start_screen.gd` (home stake box), `scripts/ui/farewell_card.gd` + `main.gd show_farewell()`, `needs_debug.gd` (+5 d, Fake check-in, Open calendar, Retire), `player.gd` (Thirsty walk ×0.75), `venue_session.gd` (ghost rows, tries, Pour Perfect marks tried).
- Menu: `bar_menu.gd bundles()` no longer exposes `was`; bundle rows are list-only (already were).
- Tests: `test_needs.gd` (stakes 1–16, O1–O3), `test_minigames.gd` (miss tier, extra action), `test_menu.gd` (bundles, Pour tried). Captures: `tests/capture_needs_stakes.gd` → `docs/art/screens/needs-stakes/`.

## Gotchas
- Tests that set meters to 0 now meet annoyances (drag ×0.85 each); use 10+ for pure-gain checks.
- `note_minigame_round()` starts the visit (begin_visit clears the tries).
- New CSV keys need `Godot --headless --path game --import` locally; untracked `.translation` files regenerate.
- No audio bus exists: Earworm's −9 dB is `Needs.music_duck_db()`, unread yet. There is no settings screen: Retire is `Needs.retire()` + the debug panel.
- Screenshots in a small screen come out 1080×1421 (window clamped); content is the real layout.
