# 🌐 presence-backend — worker report (2026-11-19)

## Evidence
- Branch `wk/presence-backend`, tip = the SHA in the final message (rebased on origin/main 54b1e94). Not pushed.
- Supabase project `bc-tamagotchi-presence` (ref czrbsjalcjekcslylwbt, ap-southeast-1, free, $0 quoted):
  https://czrbsjalcjekcslylwbt.supabase.co. `ethos` paused (Daniele "Pause Ethos"). Anonymous sign-ins on (Daniele).
- Migrations applied: `supabase/migrations/20261119000001_presence_v1.sql`, `..._000002_perf_reports.sql`; seed 20 codes;
  pg_cron job bc-retention; Edge Function `verb` v1 ACTIVE (verify_jwt off, CORS), VAPID public key served.
- Security advisors: only expected notices (13 SECURITY DEFINER RPCs callable by `authenticated` = the design; 5
  tables RLS-on with no policy = deny-all on purpose). bc_presences, bc_svc_* and bc_retention not callable by clients.
- Secrets: none in git (URL + anon key are public by design; service role and VAPID private key only in Supabase).
- Tests:
  - `test_presence_net` offline (mock, two-plus clients): 101 checks, 0 failures (check-in, one per night, hours incl.
    after-midnight/Monday, tablemates 45 min, P1 here/nobody, P3 table vs zone, rate limit, verbs + limits, inbox +
    mark_read, hide, push budget, offline queue + reconnect + night-ended drop, report -> Guest name, delete_me, polling
    diff, fake presences, Needs.check_in hook, perf reports).
  - `test_presence_net -- --live` two anonymous players against the real project: 14 checks, 0 failures (check-in
    767 ms, tablemate match, tonight with table, wave via Edge Function, limit, phrase, inbox, mark_read, hide + silent
    drop, VAPID key, perf report, delete_me). DB afterwards: 0 profiles / checkins / events / users.
  - All suites headless with empty APPDATA on the pre-rebase tip: 27/28 pass; test_feel fails only its known
    "buffer walk ... Tag_mali" line (pre-existing, on other cards). Post-rebase (on 54b1e94): **28/28 pass**, test_presence_net included.
- Push: two pushes accepted by FCM (push_log 201); third answered 410 (registration dropped) -> status gone,
  subscription deleted. **Delivery to a device NOT DONE:** throwaway Chrome profiles (headless and windowed on the
  hidden desktop) never kept a GCM registration (gcm-internals: UNKNOWN_ERROR); no Android device here; the in-app
  browser cannot register service workers. Kit: `supabase/tests/push-receiver/`.
- QR: `docs/venue/qr/qr-sheet.pdf|png`, `png/<table>.png`, `codes.json`, `make_qr.py` (20 codes, https://blackcabin.app/?t=<code>).
- Domain: blackcabin.app attached to Vercel project bc-tamagotchi (no deploy) but **does not resolve** (Google DNS:
  non-existent domain; not in the Vercel team's domain list). Vercel connector turned off after.
- Hub cards: presence-backend-review (new), presence-push-caps, presence-qr-tables, blackcabin-domain-dns;
  answered: presence-supabase-limit, presence-anon-signins.

## What was built
- Contract `docs/design/08b-presence-api.md` (v1.1, written first; `/?t=<code>` instead of 08's `/c/<code>`).
- `game/scripts/presence/`: presence.gd (autoload `Presence`), presence_api.gd (HTTP), presence_mock.gd (in-memory
  server with the same rules), presence_config.gd. Registered in project.godot.
- Web push: `tools/push-sw.js` + `tools/build_web.py` puts importScripts('push-sw.js') at the top of the exported
  service worker and copies the file (no-cache).
- Perf telemetry backend (card telemetry-beacon "auto"): perf_reports, bc_perf_report, 90 days; `Presence.perf_report()`.

## Not done / open
- Device push delivery (above). Presence UI (presence-client's job). Friend link RPCs, N3/N4 pushes. Live check of the
  web build itself (no deploy; Daniele redeploys).
- Owner calls: push caps (default 1/sender, 3/night, 19–02), QR table list + public codes, blackcabin.app DNS.
- Profile note: the social-features profile could say "a fresh Supabase project has anonymous sign-ins off; the
  connector cannot flip it" and "free plan = 2 active projects per owner".
