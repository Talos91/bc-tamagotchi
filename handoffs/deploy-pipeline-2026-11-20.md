# Role note: 🛠️ deploy-pipeline (webapp worker), 2026-11-20
State: automatic deploy implemented (4e6d342, not pushed); blackcabin.app LIVE since 11-20 17:10 (bought by Daniele, cert via `vercel certs issue`).
- Pipeline: `.github/workflows/web-deploy.yml` (push to main touching game/** or the build tools -> Godot 4.6.1 Linux
  headless export -> local smoke -> Vercel preview + smoke -> `--prod` + smoke). Doc `docs/tech/04-deploy.md`.
- Tested on this PC: build of origin/main 14228c7 (bc-c3d7bf46, 58.2 MB), local smoke 16/16 PASS, preview deploy
  https://bc-tamagotchi-cgziktdw8-talos-projects00.vercel.app READY with all 17 files (Vercel API file list).
  NOT tested: the GitHub runner (Linux Godot install, first run) and the preview smoke behind Vercel Authentication.
- blackcabin.app: bought by Daniele 11-20 16:29; certificate needed `vercel certs issue` (see 04-deploy.md).
## Next
1. Daniele: VERCEL_TOKEN secret (+ optional Protection Bypass for Automation) (04-deploy.md).
2. Verifier pushes 4e6d342(+docs); Daniele or anyone with repo access: Actions > Web deploy > Run workflow; read the summary.
3. If the Linux run fails: the step name tells where (Godot download / unzip names / export). Fix in the workflow only.
4. Redirect of bc-tamagotchi.vercel.app waits on Daniele
   (a redirect resets saves and presence logins: per-site browser storage).
## Gotchas
- Vercel CLI 66 prints JSON on stdout when it thinks an agent runs it; the workflow greps the first *.vercel.app URL.
- `vercel curl` breaks on Windows paths with spaces (npx under Git Bash); web_smoke.py reads the bypass via the API.
- Deployment URLs (also production ones) are behind Vercel Authentication (`all_except_custom_domains`); the
  bc-tamagotchi.vercel.app alias and custom domains are public.
- A local Godot import writes ~27 `.uid` files under game/ that are not in git: never commit them with tooling.
