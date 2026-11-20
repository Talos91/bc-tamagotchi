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

## blackcabin.app (diagnosis 2026-11-20)
- **The domain was never bought.** Vercel lists it under talos-projects00 attached to project bc-tamagotchi, but as
  *Registrar: Third Party*, no expiry, no renewal price (`vercel domains inspect blackcabin.app`): it was *added*,
  not purchased. The .app registry has no record of it (Google Registry RDAP 404; its own nameserver answers
  NXDOMAIN), and `vercel domains check blackcabin.app` says **available, $9.99 first year, $15 renewal**.
- **Fix = buy it (Daniele, money):** https://vercel.com/talos-projects00/~/domains > Buy > `blackcabin.app` >
  confirm $9.99. Or in PowerShell: `npx.cmd vercel domains buy blackcabin.app` (asks to confirm the price).
  If Vercel refuses because the name is already in the team, first remove it at bc-tamagotchi > Settings >
  Domains > blackcabin.app > Remove, then buy, then Add it back to bc-tamagotchi. Bought through Vercel, the
  nameservers and DNS are Vercel's: nothing to type. Resolves in minutes (.app is HTTPS-only; Vercel issues the cert).
- **Check:** `nslookup blackcabin.app 8.8.8.8` gives an address; `curl -I https://blackcabin.app` answers 200.
- **Canonical URL:** once it resolves, make blackcabin.app the project's primary domain (Settings > Domains). The
  QR codes (`docs/venue/qr/`) already point at it. **Not redirected yet:** the game save and the presence login
  live in the browser per site, so a redirect from bc-tamagotchi.vercel.app would start every current player
  over on blackcabin.app. Both URLs serve the same build until Daniele decides (hub question).

## QR test (once blackcabin.app resolves; before: replace the host by bc-tamagotchi.vercel.app)
The server takes check-ins only while the bar is open (Tue-Sun 19:00-02:00 Bangkok, `bc_is_open`), unless
`ignore_hours` is on (Supabase SQL editor: `update public.bc_settings set ignore_hours = true;`, `false` after).
1. Phone camera on `docs/venue/qr/png/Bar.png` (or the sheet `qr-sheet.pdf`): it opens `blackcabin.app/?t=Uqmj4YnQVc`.
2. The game loads; finish the character if new; enter the venue: the "you are in" check-in moment shows (table Bar).
3. The address bar drops `?t=` (reload does not check in again).
4. A second phone scans `Table3.png`: each sees the other in the bar with the live badge.
5. Any failure: screenshot + the time; the banner text says which step.
