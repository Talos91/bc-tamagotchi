# 🎮 rivals-hooks: report (2026-11-19)

Load id 2026-11-19-rules-powers-black-cabin-3876d8. Branch `wk/rivals-hooks` (local, not pushed). Card `rivals-hooks-review`.

## Evidence
- Suites headless, empty APPDATA, own worktree after import: all 26 pass except `test_feel` (known buffer walk, Tag_mali,
  pre-existing). `test_minigames` 2219 checks 0 failed; `test_soi_dash` 139/0; `test_neon_moth` 104/0; `test_coaster_flip` 147/0;
  `test_shake_serve` 82/0; `test_mg_fx` 122/0; `test_string_keys` pass.
- Captures on the hidden desktop (hd.ps1, no focus taken): `docs/art/screens/rivals-hooks/` (18 PNG, portrait + landscape).
- Files: the three game scripts, `i18n/strings.csv` (+2 rows), `test_soi_dash.gd`, `test_minigames.gd`, `capture_rivals_hooks.gd`.

## What changed
Regular to beat in the corner, pass pop, board line on the result for all three; Pour ghost lines, Soi Dash ghost runner;
Pinball has no ghost (physics, no run to replay). Payouts unchanged.

## Open
Pinball/Pour/Soi regulars use the default SKILL table (no `set_skill`); Daniele may want a harder pinball board. TH strings are machine drafts.
