# 🌐 merch-shop — role note (2026-11-20)

Worker merch-shop-1120 (Opus 5.5, social-features profile, load id 2026-11-20-social-features-black-cabin-3c3d32),
started by orchestrator local_14422c6c. Worktree `C:/Users/itisf/bc-wt/merch-shop` on `wk/merch-shop`. Never push.
Brief: Daniele 2026-11-20 merch note (verbatim in `docs/design/14-merch-shop.md`). Ships only when ready and verified;
nothing waits on it.

## State now
- Done: consistent players (server profile + player code + restore + auto re-link), inventory on the server,
  40-piece catalogue (10 × head / eyes / top / acc), shop at the merch stand, wardrobe at the photo booth.
- Version-wipe check: no version wipes a character (save path stable, migrate keeps keys, normalize keeps unknown
  keys). Real causes: new web address, storage eviction, lost anonymous session (table in 14-merch-shop.md §1).
- Server: migration `supabase/migrations/20261120000002_player_profile_merch.sql` + `supabase/seed/merch_items.sql`
  APPLIED live 2026-11-20 (proof in supabase/README.md). A server without it answers "no function" once per launch and the client stays local.
- Tests: `test_merch_profile` (85 checks) + all suites headless, empty APPDATA (see the worker report).
- Hub: `merch-shop-review` (8 renders) and questions `merch-server-apply`, `merch-prices`, `merch-free-cap`,
  `merch-cut`, `merch-keep-on-reset`.

## Files
New: `game/scripts/merch/{merch,player_profile,merch_shop,merch_server_mock,merch_strings}.gd`, `game/data/merch.json`
(generated), `tools/merch_catalog.py` (source of the catalogue and the seed), `game/i18n/strings_merch.csv`,
`game/tests/test_merch_profile.gd`, `game/tests/capture_merch.gd`, renders `docs/art/screens/merch-shop/`.
Hooks in shared files (small): `main.gd` (merch stand → shop; booth "Merch" button; merch_shop in `_blocked`),
`venue_patron_figure.gd` (Merch.adjust on resolve, Merch.dress after `_apply_avatar`), `needs.gd` (complete_deletion
keeps `ext.merch`), `presence_mock.gd` (`extensions` dict), `project.godot` (PlayerProfile autoload, strings_merch
translations), `test_string_keys.gd` (table list).

## Gotchas
- creator-fix (wk/creator-fix) rewrites `venue_patron_figure.gd` with `show_avatar()` (the creator preview toggles
  visibility instead of rebuilding). After it lands, `show_avatar` must call `Merch.dress(_model, rec)` at its end,
  or the booth preview will not show merch (in-venue figures are fine: they go through `_build_preset`). Same for the
  hat hair: v2 libraries have `hair_<id>_hat`, which `Merch.adjust` already uses when present.
- The catalogue's x is the viewer's right; merch.gd mirrors onto the kit (+x = character's right). Hats are lifted
  one row by the generator (brim on T + 2 like the kit's hats).
- Material names `merch__*` never match `Chars.recolour` slots.
- Old creator: "Surprise me" makes a fresh record and drops worn merch (by design: a new look).
- Capture: `hd.ps1` hidden desktop (copied from `C:/Users/itisf/bc-wt/pi-tools/hd.ps1`), `--resolution 1600x900`.

## Next steps
1. Server applied 2026-11-20. Next server check: from the live build, a pick shows up in `inventory`.
   `execute_sql`), then `test_presence_net -- --live` style check by hand: sign up, bc_profile_save, bc_claim_item.
2. After creator-fix lands: the `show_avatar` hook above; optionally a "Merch" row inside the creator's Outfit tab
   instead of the overlay button.
3. Prices / caps / cuts per the answers.
