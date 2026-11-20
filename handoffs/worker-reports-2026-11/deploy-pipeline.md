# Report: deploy-pipeline (2026-11-20, Opus 5.5, session local_aaa4946a, load 2026-11-20-webapp-black-cabin-0fe490)
## Evidence
- Commit 4e6d342 on wk/deploy-pipeline (rebased on origin/main): workflow, tools/web_smoke.py, docs/tech/04-deploy.md.
- Domain: `vercel domains inspect blackcabin.app` -> Registrar Third Party, Expiration -, attached to bc-tamagotchi;
  `nslookup blackcabin.app 8.8.8.8` -> Non-existent domain; registry nameserver ns-tld1.charlestonroadregistry.com
  -> NXDOMAIN; https://pubapi.registry.google/rdap/domain/blackcabin.app -> 404; `vercel domains check` -> available;
  `vercel domains price` -> $9.99 purchase, $15 renewal. Cause: added to Vercel, never purchased.
- Build: `python tools/build_web.py --out <scratch>` on 14228c7 -> bc-c3d7bf46, 58.2 MB, exit 0.
- Smoke local: `tools/web_smoke.py http://127.0.0.1:8797 <out> --local` -> 16 files OK.
- Preview: `vercel@66.5.0 deploy` with VERCEL_ORG_ID/PROJECT_ID env -> https://bc-tamagotchi-cgziktdw8-talos-projects00.vercel.app
  READY (dpl_CmBbWEUtcMR1g9ZCi7yjkrsSVvE2), 17/17 files present (API /v6/deployments/<id>/files). Behind Vercel
  Authentication (302); the project has no automation-bypass secret, so the preview smoke was not run.
- Live fallback: https://bc-tamagotchi.vercel.app/?t=Uqmj4YnQVc -> 200, build bc-4d7feca5, pck/wasm/worklet/push-sw
  Range 206, service worker imports push-sw.js. Check-in reads `?t=` from any origin (presence.gd:163).
- Linux readiness: 1118 res:// references, 0 case mismatches. Godot 4.6.1 Linux zip (71.8 MB) and templates tpz
  (1.25 GB) URLs answer 200. Workflow YAML parses (js-yaml).
## Not verified
- The GitHub Actions run itself (cannot push; no Linux here). First run = Daniele's "Run workflow" after the push.
- Real phone QR scan; blackcabin.app (not registered).
## Daniele's steps (click paths in docs/tech/04-deploy.md)
1. Buy blackcabin.app ($9.99). 2. Vercel token -> GitHub secret VERCEL_TOKEN. 3. Optional: Protection Bypass for
Automation. 4. Actions > Web deploy > Run workflow. 5. Decide: redirect vercel.app -> blackcabin.app (resets saves) or keep both.
## Profile feedback
- No `tech`/`release`-web role exists; `webapp` fit loosely (no CRM here). PROJECT.md has no `### Webapp` entry.
- Connector: Vercel CLI login on the PC did everything; the Vercel connector was enabled but not needed.
## Update 2026-11-20 ~17:10 +7: blackcabin.app live
- Daniele bought it (Vercel, 16:29). DNS resolved in ~60 s (64.29.17.65 / 216.198.79.65). No certificate after 30 min
  (TLS handshake failed, HTTP 200): `vercel certs issue blackcabin.app www.blackcabin.app` fixed it in 14 s.
- curl: https://blackcabin.app/?t=Uqmj4YnQVc 200 (bc-4d7feca5 = vercel.app build), pck/wasm/js/worklets 206
  immutable, push-sw.js + index no-cache, SW imports push-sw.js, www 307 -> apex. Real-phone QR scan still Daniele's.
