# 🌐 presence-backend — role note (2026-11-19)

Branch `wk/presence-backend` in `C:/Users/itisf/bc-wt/presence-backend` (rebased on origin/main 54b1e94, not pushed).
Load id 2026-11-19-social-features-black-cabin-6868dc. Report: `handoffs/worker-reports-2026-11/presence-backend.md`.

## State now
- **Supabase project LIVE:** `bc-tamagotchi-presence`, ref `czrbsjalcjekcslylwbt`, Singapore, free tier, org Talos91
  (`ethos` paused for it, Daniele "Pause Ethos"; restorable). Anonymous sign-ins ON (Daniele flipped it).
  Both migrations applied, 20 table codes seeded (`supabase/seed/venue_tables.sql`), pg_cron `bc-retention` daily
  21:17 UTC, Edge Function `verb` v1 (verify_jwt off), VAPID keys in `private.vapid` (made by the function).
  URL + public anon key in `game/scripts/presence/presence_config.gd` -> `Presence.ON` is true in this branch.
  The database is empty (test players deleted).
- **Client:** autoload `Presence` (contract `docs/design/08b-presence-api.md` v1.1). No UI calls it yet: presence-client
  builds the avatars / badge / verb sheet / consent and push cards against it.
- **Tests:** `test_presence_net` offline 101/101; `-- --live` two-client 14/14 against the real project (needs the bar
  open, or `update bc_settings set ignore_hours = true` then back to false).
- **Push:** server path proven (FCM 201 with our VAPID; 410 -> subscription deleted). Delivery to a device NOT DONE:
  throwaway Chrome profiles never keep a GCM registration. Test kit `supabase/tests/push-receiver/`.
- **Domain:** blackcabin.app attached to Vercel project bc-tamagotchi but NXDOMAIN (not registered / purchase not
  done). QR codes already point at it. Card `blackcabin-domain-dns`.
- Cards: presence-backend-review, presence-push-caps, presence-qr-tables, blackcabin-domain-dns (presence-supabase-limit,
  presence-anon-signins answered).

## Next (for whoever continues)
1. Real-device push check: deploy a build with this branch, open on an Android phone (Chrome), enable push from the
   presence-client opt-in card, have a friend wave. Or open `supabase/tests/push-receiver/` in a real Chrome profile.
2. When Daniele answers presence-push-caps: one `update public.bc_settings set ...` (no build).
3. presence-qr-tables: table list changes -> edit TABLES in `docs/venue/qr/make_qr.py`, rerun, run the seed SQL.
4. Friend links (P11) have a table but no RPCs yet; N3/N4 pushes (friend check-in, Friday headline) not built.

## Gotchas
- Godot JSON numbers are floats: cast ids to int before sending to bigint params (mark_read bug found live).
- GDScript min()/max() reject Strings (use _lo/_hi). `tools/web/` is gitignored (web/ pattern) -> push-sw.js lives in tools/.
- Presence constants live in presence.gd (not rules.gd) to avoid collisions with presence-client.
- The in-app browser pane cannot register service workers; Supabase dashboard there needs Daniele's sign-in.
- Supabase free plan: 2 active projects per owner (now bc-tamagotchi-presence + ooze-syndicate).
