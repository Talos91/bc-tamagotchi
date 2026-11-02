# 🛠️ needs-stakes-build — report (2026-11-02/03)

## EVIDENCE
- **Commit dd4e03c** on local main (code, tests, captures, role note). Not pushed. Report in the commit after it.
- **Suites** (APPDATA empty per suite, headless, from `game/`): `test_needs` 228 checks 0 failed; `test_menu` 3670 / 0; `test_minigames` 1498 / 0; `smoke_loop` PASS; `test_nightlife` 107 / 0; `smoke_tap` PASS; `smoke_start` PASS. (`smoke_start` failed once while a windowed capture ran at the same time; passes alone. `smoke_loop` re-run after the Ty rename.) Not run: smoke_stairs, smoke_hud, smoke_doors_sit, smoke_version, test_seats, test_feel, test_lounge (verifier's full run).
- **Cards** on the Questions tab: `needs-stakes-review` (pictures + files), and interpretations `needs-stakes-night-boundary`, `needs-stakes-death-in-visit`, `needs-stakes-rescue-welcome`, `needs-stakes-retire-ui`.
- **Captures:** `docs/art/screens/needs-stakes/` (1 HUD at Last Call, 2 MISS card, 3 home at Last Call, 4 home ghost, 5 farewell; portrait and landscape; window clamps to 1080×1421 on this screen). Script `game/tests/capture_needs_stakes.gd`.
- **Role note:** `handoffs/needs-stakes-build-2026-11-02.md`.
- **Name:** `cast.tt.name` = "Ty" (Daniele via orchestrator); `smoke_loop` tag check updated. The raw "TT.name" label in the web build comes from the export not including the CSV (web-build paths, not touched).

## What was built (06-stakes §10, O1–O4)
Stake clock with Out of Town excluded, exact death at 21.0 days (never inside a visit), ghost freeze, deletion at day 35, `check_in()` as the only revival (90-day limit, floor 40, Welcome Back, lives, zombie visit), annoyances with ×0.85 drag, minigame miss (0.25; 0.4 first round while Rusty), 3 tries per visit, `minigame_played`, Retire and account-keeping deletion, save keys (old saves load at Fine). O1: `real_visit_required` only bites after `has_checked_in`. O2: no stand-in revival. O3: `memory_shared(night)` counts only for a checked-in night. UI: HUD chips, Last Call chip, home stake box, farewell card, ghost rows, debug panel entries, Thirsty walk ×0.75.
Adjacent: bundles price-only and list-only (`was` no longer exposed); Pour Perfect marks the poured drink as tried (no conflict with the design).

## Interpretations (cards)
Night = 06:00 to 06:00 Bangkok; a death held off by a visit starts the ghost window at the visit's end; Welcome Back on rescue fires when the counting action lands.

## Open / not done
- Retire has no settings screen (card); Earworm −9 dB is `Needs.music_duck_db()`, no audio bus yet.
- Notifications and postcards beyond the home text, the stitched-scar and "Back From the Dead" sticker, Going bonus: not built (need push, wardrobe, calendar).
- `strings_venue.csv` Thai lines are machine drafts, marked in their context column.
- Layout.json untouched.
