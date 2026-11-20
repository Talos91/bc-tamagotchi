# Deploy (automatic) and the blackcabin.app domain
2026-11-20, deploy-pipeline worker. The live site no longer needs anyone to run a command: a push to `main` that
touches the game builds the web export on GitHub and puts it on Vercel.

## How it works
`.github/workflows/web-deploy.yml` (GitHub Actions, public repo = free minutes):
1. **Trigger:** push to `main` touching `game/**`, `tools/build_web.py`, `tools/version.py`, `tools/push-sw.js`,
   `tools/web_smoke.py` or the workflow. Docs-only pushes do not deploy. Manual run: Actions > Web deploy > Run
   workflow (tick or untick "production").
2. **Build:** Godot 4.6.1 Linux headless + the web templates (downloaded once, cached), then the same
   `python tools/build_web.py --out <tmp>` as on the PC. The ~20 MB .pck is built on the runner and never committed.
3. **Smoke (local):** `tools/web_smoke.py <url> <folder> --local` against the folder served by `http.server`:
   every file answers with its size, index.html carries the build's `bc-<hash>`, worklets hashed, push-sw.js
   imported by the service worker. Fails the run before anything is uploaded.
4. **Preview:** `vercel deploy` (no `--prod`) -> a `bc-tamagotchi-<id>-talos-projects00.vercel.app` URL in the run
   summary. Smoke against it (adds the Vercel checks: no-cache index, immutable hashed files, Range -> 206).
   Previews sit behind Vercel Authentication; the check reads the project's "Protection Bypass for Automation"
   secret through the API with the same token. Without that secret the run warns "Preview not checked" and goes on.
5. **Production:** `vercel deploy --prod`, then the same smoke against https://bc-tamagotchi.vercel.app (and
   https://blackcabin.app once it resolves).
- **Hold production** (preview only, for a risky batch): repo Settings > Secrets and variables > Actions >
  Variables > `WEB_DEPLOY_PROD` = `off`. Delete it to go back to automatic.
- `vercel.json` is written by `build_web.py` (cache headers). No COOP/COEP headers: the export is single-threaded
  (`variant/thread_support=false`), so none are needed. Audio worklets and `push-sw.js` are checked by the smoke.
- Fallback by hand (unchanged): `python tools/build_web.py --deploy --out $env:LOCALAPPDATA\bc-web`.

## Daniele's steps (once)
1. **Vercel token:** https://vercel.com/account/settings/tokens > Create Token > name `github-bc-tamagotchi`, scope
   *Talos' projects*, expiry 1 year > Create > copy it. (If Vercel asks for 2FA first, it gives the link to set it up.)
2. **GitHub secret:** https://github.com/Talos91/bc-tamagotchi/settings/secrets/actions > New repository secret >
   Name `VERCEL_TOKEN` > paste > Add secret. Never paste the token anywhere else (chat, files).
3. **Preview check (optional, recommended):** https://vercel.com/talos-projects00/bc-tamagotchi/settings/deployment-protection
   > Protection Bypass for Automation > Add (no name needed) > Save. Nothing else to copy: the workflow reads it.
4. **First run:** after the Verifier pushes this, GitHub > Actions > Web deploy > Run workflow. Green = live.

## blackcabin.app
- **Live since 2026-11-20 ~17:10 +7.** Diagnosis that morning: the domain had only been *added* to Vercel (Registrar
  Third Party, registry NXDOMAIN), never bought. Daniele bought it in Vercel at 16:29 (Registrar Vercel, expires
  2027-11-20, $15/yr renewal, nameservers ns1/ns2.vercel-dns.com). DNS answered within ~1 minute.
- **Gotcha:** 30+ minutes later HTTPS still failed (TLS handshake, no certificate) while plain HTTP answered 200;
  every .app name is HTTPS-only in browsers, so the site was unreachable. `vercel domains verify blackcabin.app` said
  configured correctly; `npx.cmd vercel certs issue blackcabin.app www.blackcabin.app` issued the certificate in 14 s.
- Checked by curl: `https://blackcabin.app/?t=Uqmj4YnQVc` 200, same build as bc-tamagotchi.vercel.app, hashed files
  Range 206 + immutable, index and push-sw.js no-cache, service worker imports push-sw.js; www.blackcabin.app 307 to
  the apex. The workflow's production step smoke-tests blackcabin.app on every deploy from now on.
- **Canonical URL:** blackcabin.app (the QR codes in `docs/venue/qr/` point at it). **bc-tamagotchi.vercel.app is
  not redirected:** the game save and the presence login live in the browser per site, so a redirect would start
  every current player over. Both serve the same build until Daniele decides (hub question).

## QR test
The server takes check-ins only while the bar is open (Tue-Sun 19:00-02:00 Bangkok, `bc_is_open`), unless
`ignore_hours` is on (Supabase SQL editor: `update public.bc_settings set ignore_hours = true;`, `false` after).
1. Phone camera on `docs/venue/qr/png/Bar.png` (or the sheet `qr-sheet.pdf`): it opens `blackcabin.app/?t=Uqmj4YnQVc`.
2. The game loads; finish the character if new; enter the venue: the "you are in" check-in moment shows (table Bar).
3. The address bar drops `?t=` (reload does not check in again).
4. A second phone scans `Table3.png`: each sees the other in the bar with the live badge.
5. Any failure: screenshot + the time; the banner text says which step.
