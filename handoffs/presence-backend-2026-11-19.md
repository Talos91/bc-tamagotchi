# 🌐 presence-backend — role note (2026-11-19)

Branch `wk/presence-backend` in `C:/Users/itisf/bc-wt/presence-backend` (not pushed). Load id 2026-11-19-social-features-black-cabin-6868dc.

## State now
- DONE in branch: API contract `docs/design/08b-presence-api.md` (v1.1); migrations `supabase/migrations/2026111900000{1,2}*.sql`
  (schema, RLS, bc_* RPCs, perf_reports, retention cron); Edge Function `supabase/functions/verb/index.ts` (verb + Web Push,
  VAPID keys generated in-function into private.vapid); autoload `Presence` (`game/scripts/presence/`: presence.gd,
  presence_api.gd, presence_mock.gd, presence_config.gd with EMPTY URL/key = presence off); push SW `tools/push-sw.js` +
  `tools/build_web.py` hook (importScripts at top of index.service.worker.js, no-cache header); QR sheet `docs/venue/qr/`
  (codes.json, qr-sheet.png/pdf, png/, make_qr.py) + `supabase/seed/venue_tables.sql`; suite `game/tests/test_presence_net.gd`
  (offline 101/101; `-- --live` runs the two-client test against the real project).
- BLOCKED: Supabase create_project refused — org Talos91 at free 2-active-project limit (ethos, ooze-syndicate). Card
  `presence-supabase-limit`. Cost quoted $0.
- blackcabin.app attached to Vercel project bc-tamagotchi (prj_N4jIo9OBOI6Rd2TNFFQAJkyMFzc6, team talos-projects00) but
  misconfigured: not in the team's domain list, NS = .app registry. Card `blackcabin-domain-dns`. Vercel connector turned off.
- Open cards: presence-supabase-limit, presence-push-caps, presence-qr-tables, blackcabin-domain-dns.

## Next steps once a slot is free
1. create_project bc-tamagotchi-presence, ap-southeast-1 (get_cost -> confirm_cost 0 -> create with confirm id).
2. Turn on anonymous sign-ins (Auth settings; connector may not expose it -> ask Daniele, or test signup and see).
3. apply_migration x2, execute_sql supabase/seed/venue_tables.sql, deploy_edge_function `verb` with verify_jwt=false.
4. Put URL + anon (publishable) key into presence_config.gd (public by design). Then `ON` becomes true.
5. Run `-s tests/test_presence_net.gd -- --live` (bar must be open or `update bc_settings set ignore_hours=true`, then false).
6. Push test: local page on localhost with tools/push-sw.js registered, subscribe via the edge public_key, save via bc_save_push,
   send a verb from a second client; desktop Chrome (Claude in Chrome) as proxy; Android = NOT DONE unless a device exists.
7. get_advisors (security) and fix warnings; all PROJECT.md suites headless with empty APPDATA; rebase; exit ritual.

## Gotchas
- GDScript min()/max() reject Strings (use _lo/_hi). `tools/web/` is gitignored (web/ pattern) -> push-sw.js lives in tools/.
- Presence constants live in presence.gd (not rules.gd) to avoid collisions with presence-client.
- The URL is `/?t=<code>` (no Vercel rewrite), host blackcabin.app (Daniele 2026-11-19).
