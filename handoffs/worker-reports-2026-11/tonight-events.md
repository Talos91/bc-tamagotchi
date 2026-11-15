# Worker report — 🌐 Tonight + upcoming events (backlog D1/D2), 2026-11-15

Load id 2026-11-15-social-features-black-cabin-182dca · model Opus 5.5 · orchestrator local_060ea4b4.

## EVIDENCE
- **Tip 1311e91** on local main (base a885b04 = origin/main at commit time; not pushed — Verifier pushes). Report/role-note commit follows on top.
- **Suites**, shared tree, empty APPDATA per suite: 19/20 PASS; `test_string_keys` FAILED there only on 35 `mg.*` keys from the minigame worker's *uncommitted* files (coaster_flip / neon_moth / soi_dash; none is a tonight key). **Clean worktree of 1311e91** (import, empty APPDATA): `test_string_keys` PASS (520 csv rows, 0 failures), `test_tonight` PASS. After the last sheet edit: `test_tonight` + `smoke_hud` PASS again.
- **New suite `test_tonight`** (165 checks) → orchestrator: add to PROJECT.md Tests (twentieth suite). Run: `Godot --headless --path game -s tests/test_tonight.gd`.
- **Hub cards**: `tonight-review` (design: placement, 7 pictures + files) and `tonight-november-data` (facts: the November 2026 poster).
- **Captures** `docs/art/screens/tonight/`: 0-hud-button, 1-cabin-jam, 2-regular-night, 3-closed-monday, 4-no-data-november, 5-cabin-jam-th, each `-portrait` (1080×1920) and `-landscape` (1920×1080); windowed Godot on the side screen (`--screen 1`), from `game/tests/capture_tonight.gd`.
- Design: `docs/design/09-tonight-events.md`. Role note: `handoffs/tonight-events-2026-11-15.md`.

## What was built
- HUD **Tonight** button (top right, left of the orientation toggle) → bottom sheet: date + state (*Open now · until 02:00* / *Doors open at 19:00* / *Closed on Mondays · back Tue at 19:00*), tonight's card (title, Showtime/From time, lineup), Coming up (≤ 6, this month + next), hours footer. Walking blocked while open.
- Clock: phone clock → Bangkok UTC+7; evening 19:00–02:00; before 02:00 = previous evening; Monday evening (Mon 02:00 → Tue 02:00) closed.
- Data: `game/data/events/2026-10.json` (copy of `docs/venue/events/2026-10.json`), looked up by file name; a missing month shows "…calendar isn't in the game yet", never invented. Today (15 Nov) the live game would show that: only October exists.

## Paths touched outside the brief's own paths (one-liners, said so)
`game/scenes/ui/needs_hud.gd` (signal, button, retitle), `game/scripts/main.gd` (open_tonight, `_blocked`), `game/project.godot` (2 translations registered: needed for the web export), `game/tests/test_string_keys.gd` (TABLES), `game/data/events/` (new), `game/tests/capture_tonight.gd` (new).

## Not verified / open
- No phone or web-build check (headless + desktop windowed only). Thai strings are machine drafts (B22). Special openings/closures not modelled.
- Owner calls: placement (card tonight-review, rec: HUD button as built), November data (card tonight-november-data).
- Profile note: the social-features profile's two-client/reconnect evidence does not apply to an offline feature; nothing else missing.
