# Report: iphone-load-2 (🛠️ Sonnet, 2026-11-09, item 28)

## EVIDENCE
- Code SHA: e43a9ec (local main, not pushed, not deployed; `git pull --rebase` not run: shared tree has other workers' uncommitted files). Paths: tools/build_web.py, docs/tech/03-web-build.md, docs/art/screens/iphone-load/iphone2-resume-375x812.jpg.
- Live site curl (build bc-ec7d29fd): every file in the index answers 200 with the right type, no 404, no COOP/COEP/CORP, no content-encoding length problem.
  | file | CT | length (identity) | enc br wire | Cache-Control |
  | .js | application/javascript | 315759 | br | immutable 1y |
  | .wasm | application/wasm | 37685705 | br, 8.87 MB complete download in 0.5 s | immutable 1y |
  | .pck | application/octet-stream | 16008420 | br | immutable 1y |
  | audio.worklet.js / audio.position.worklet.js | application/javascript | 7298 / 2973 | br | immutable |
  | index.service.worker.js, manifest | js / json | 5860 / 339 | no-cache |
  | png icons | image/png | 21443 / 5702 / 11952 | max-age 86400 |
  Range request on the wasm (even with Accept-Encoding br): 206, plain bytes, identical to the identity file.
- Cause line: engine loader (`getTrackedResponse` in the engine js): `reader.read()` errors in the stream's `start` promise are not caught, so there is no retry and the rejection ("TypeError: Load failed" in WebKit) reaches our `unhandledrejection` hook = "Startup failed: Load failed". 45 % of the bar = ~24 of 53.7 MB, i.e. inside the wasm. So: a network drop mid-stream; which event dropped it (iPhone network, memory, the Instagram in-app handoff) is NOT proven; no iPhone here.
- Fix: shell guard wraps fetch() for bc-*.wasm/.pck only; on a broken stream it resumes with `Range: bytes=<received>-` (up to 8 times, backoff) and records file/status/encoding/MB; banner ends with "Last download: ...".
- Test: local build bc-b4fd83a2 (54.2 MB), server that cuts the first wasm response at 24,051,712 bytes: log "CUT at 24051712" then a second GET of the wasm, game reached "Tap to enter" at 375x812 (screenshot above), no banner. Console: only the service-worker registration error that also appears with a stock `python -m http.server` and was noted on 11-04 (index.html never registers a SW; it is pane noise) plus the injected cut's ERR_CONTENT_LENGTH_MISMATCH. Not tested: a real iPhone, a cut in the pck, the banner text on screen (code path read, not triggered).
- Hub card: `iphone-load-2-review`. No game/ files touched, no suites run.

## Hypotheses
1 files/headers: clear. 2 stale SW: none exists (no register call; the 11-04 note "SW registers fine" was wrong). 3 memory: engine clones the wasm response (tee) and reads eagerly, so ~2x37 MB transient; not changed, still a candidate if resume does not help. 4 CriOS vs Safari: same WebKit fetch; no evidence either way.

## Gotchas
- Port 8791 was already served by another session's server (a different build); check `netstat -ano | findstr :<port>`.
- Daniele must redeploy; then retest on the iPhone and send the banner screenshot if it still fails.
