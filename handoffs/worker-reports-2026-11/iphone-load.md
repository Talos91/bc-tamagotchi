# Report: iphone-load (🛠️ Sonnet, 2026-11-04)

## EVIDENCE
- Code SHA: ebed591 (local main, not pushed, not deployed). Paths: tools/build_web.py, docs/art/screens/iphone-load/start-375x812.jpg, handoffs/iphone-load-2026-11-04.md, this report.
- Suites (game/, empty APPDATA, shared tree with other workers' uncommitted edits): smoke_start PASS, smoke_version PASS, smoke_hud PASS. The change touches only tools/build_web.py (no game code).
- Hub card: `iphone-load-review` (picture, 10-line iPhone checklist, files list).
- Local build: `python tools/build_web.py --out <scratchpad>/web`, served on 8793, loaded at 375x812: start screen "Tap to enter", no banner, no 404, no worklet error.
  Console showed only a service-worker registration error on localhost (pane/python server; the live site registers fine); the guard treats it as non-fatal.

## Findings (full list in the role note)
- ★ Most likely: audio worklets 404 on the live site (`bc-<hash>.audio.worklet.js` requested, files were still `index.audio.*.js`; AbortError "Unable to load a worklet's module"). Our build script bug. Fixed: worklets renamed with the rest, patched in index.html and the service worker cache list. Not proven to be the iOS cause.
- Second: memory (wasm 37.7 + pck 15.9 MB in RAM, Safari silently reloads over ~300 MB per forum reports). Needs a device reading; the new guard detects the silent reload.
- Ruled out / fine: COOP/COEP (not set, single thread), extensions flag false (right), br compression, no-cache on shell, PWA registration, audio tap (start screen has a tap).
- WebGL2 requires iOS 15+; now checked before the download.

## Fix details
SHELL_GUARD injected before the engine script: red banner with the failure in words (no WebGL2, no WebAssembly, storage blocked, file failed, startup error, context lost, 25 s still loading, silent reload = probable out of memory) plus a BC-DIAG user-agent line. Worklet and service worker rejections only logged.

## Costs if Safari needs lighter
Texture halving on phones ~40-80 MB RAM, ~1 day (performance pass, item 16); smaller wasm needs a custom template (days, risk). Not before a device reading.

## Open calls for the orchestrator
1. Verifier: push ebed591 and deploy; then Daniele tests (checklist on the card). Note `git pull --rebase` was blocked here by others' unstaged files, so the commit sits on the old base.
2. Unverified: that the worklet 404 is what stops iOS. If the iPhone still fails, the banner text names the next suspect.
