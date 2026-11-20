# 🌐 merch-shop-1120 — worker report (2026-11-20)

## Evidence
- Branch `wk/merch-shop`, tip: see the final line of this file (rebased on origin/main b607586, creator-fix 2).
- Suites: all headless, empty APPDATA, own TEMP: see "Suites" below. New suite `test_merch_profile` (85 checks).
- Renders (hidden desktop, `tests/capture_merch.gd`): `docs/art/screens/merch-shop/` (sheet-<cat>[-back].png,
  shop / shop-tees / wardrobe / restore -portrait.png).
- Hub: review `merch-shop-review` (8 pictures + files); questions `merch-server-apply`, `merch-prices`,
  `merch-free-cap`, `merch-cut`, `merch-keep-on-reset`.
- Design chapter `docs/design/14-merch-shop.md`; role note `handoffs/merch-shop-2026-11-20.md`.

## What was built
1. Consistent players. Check first: no version update wipes a character (save path stable, save.gd migrate keeps
   every key, avatar normalize keeps unknown keys and migrates v1 → v2). Real causes found: a new web address,
   browser storage eviction, a lost anonymous session. Now: `PlayerProfile` autoload mirrors the character to
   `profiles` (stable player id = the anonymous account, avatar, personality, created/updated/avatar_at, build),
   a 10-character player code restores it anywhere (rate limited), a changed account re-links by itself, a lost save
   gets its character back; `navigator.storage.persist()` asked on web. Local save stays the truth and the fallback.
2. Inventory on the server: `inventory (player_id, item_id, acquired_at, source free_pick|purchase|grant,
   price_paid)`, catalogue `merch_items` with `price_coins` / `price_thb` (NULL), `bc_settings.shop_free`. RLS: own
   rows only; writes only through security-definer functions. No money logic.
3. Catalogue: 40 pieces (10 hats & masks, 10 eyewear, 10 tees, 10 extras), runtime voxels on the kit's head and
   spine bones (5 cm voxels, kit palette style, glow pieces unshaded), masks hide the head, hats use the kit's
   cut-at-the-brim hair. Shop at the lounge merch stand (try on, pick free, wear, player code, restore); wardrobe
   at the photo booth ("Merch" over the creator), wearing updates the creator's record and preview.

## Hooks in shared files (small)
`main.gd`, `venue_patron_figure.gd` (adjust/dress in set_look and show_avatar), `needs.gd` (reset keeps ext.merch),
`presence_mock.gd` (extensions), `project.godot` (autoload + strings_merch), `test_string_keys.gd` (table),
`test_lounge.gd` (the stand opens the shop now), `supabase/README.md` (apply step).

## Not done / not verified
- Live Supabase: APPLIED (migration player_profile_merch + 40-row seed) on Daniele's relayed word; proof query + rolled-back run as a real account (see supabase/README.md). Not yet exercised from the live game build.
- No real phone, no web build check. Other players seeing merch: by code path (check-in sends the avatar record,
  figures dress from it), not tested with two clients.
- Hats still show some hair on the main-branch library before creator-fix's `_hat` hair; with b607586 the cut hair
  is used.

## Profile note
The social-features profile fit. Missing: the brief's "Supabase migrations need the owner's connector OK" step could
name the hub card pattern (one card per live apply).
