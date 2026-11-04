# 🛠️ iphone-load — role note 2026-11-04 (owner item 20)

Worker: Sonnet tech worker. Fixes in `tools/build_web.py` (commit ebed591, local, not pushed, not deployed).

## Findings (one line per hypothesis; ★ = most likely cause)
1. ★ **Audio worklets 404 on the live site, a bug of ours.** Godot 4.6 loads `<executable>.audio.worklet.js` and `.audio.position.worklet.js`. `build_web.py` renamed the executable to `bc-<hash>` but left the files as `index.audio.*.js`, so both requests 404 and the console shows `AbortError: Unable to load a worklet's module` (seen on https://bc-tamagotchi.vercel.app, 4 errors). Chrome carries on without sound; Safari's WebAudio start is stricter, so a rejected init is the best fit for "does not load" that Android does not show. **Fixed**: the worklets are renamed with the rest and patched into `index.html` and the service worker's cache list. Not proven to be the iOS cause (no iPhone here).
2. **Memory (likely second cause).** wasm 37.7 MB + pck 15.7 MB, both fully in RAM, plus the decoded textures and the 3D scene; forum reports (Godot 4.3 on iOS 18 "WebGL context lost", 4.4.1 random reloads) put the safe ceiling near 300 MB on iPhones, and Safari reloads the tab silently when it goes over. Cannot be measured without a device. Mitigation without a device: the new shell guard leaves a `bc-started` marker so a silent reload shows "the browser probably ran out of memory". Real fixes if confirmed: lower texture sizes, drop shadows/lights on phones, fewer venue meshes at start (performance pass, item 16).
3. **WebGL2.** iOS 15+ has it; older iPhones (iOS ≤ 14) have none and Godot cannot run. Now checked before the 50 MB download and reported in words.
4. **COOP/COEP.** Not set (headers checked: only Cache-Control, HSTS, content-encoding br); preset is single-threaded, `ensure_cross_origin_isolation_headers=false`. Nothing to fix; turning it on would break nothing in Safari but is not needed and hides third-party content.
5. **Service worker / PWA.** Registers fine on the live site, `no-cache` on index/SW/manifest. Precache list contained the worklets under their old names (they existed then, so no break). A failed SW registration never blocks the engine; the guard ignores it. Home-screen (standalone) mode on iOS has its own, smaller memory/cache quota: test from Safari first.
6. **Content types / compression.** `index.html` and SW: br; wasm/pck: br (8.9 MB and 11.3 MB on the wire). `.wasm` content-type was not re-fetched (Chrome streamed it with `WebAssembly.instantiateStreaming`, which requires `application/wasm`, so it is right). Safari handles br over https.
7. **Audio needs a tap.** The start screen has "Tap to enter"; Godot's web audio resumes on the first gesture. No change.
8. **Extensions support flag.** `variant/extensions_support=false`, correct (true would use the dlink build, bigger and slower on Safari).
9. **Known iOS 17/18 regressions.** Reports of WebGL context loss on iOS 18 and crashes fixed "in 4.5" betas (memory-leak fix for WebKit); we are on 4.6.1, so already past those. Unverified on our build.
10. **Storage blocked** (private tabs): Godot save uses IndexedDB; the guard probes `localStorage` and says so.
11. **Console noise on desktop:** WebGL "Framebuffer is incomplete: Attachment has zero size" spam during start-up (hidden pane); harmless, not an iOS blocker.

## What changed in the shell (`SHELL_GUARD` in `build_web.py`, injected before the engine script)
A dark-red banner over the page says why the game did not start: no WebGL2, no WebAssembly, storage blocked, a game file failed to load, startup error, graphics context lost, 25 s still loading, or "previous start did not finish" (probable out-of-memory reload). Tap hides it. It ends with `BC-DIAG <user agent>` so a screenshot carries the iOS version and model family. Worklet and service-worker rejections are only logged.

## Cost if Safari needs a lighter build
Estimates, not measured: halving texture resolution on phones saves ~40–80 MB RAM, about a day of the performance pass; wasm cannot shrink without a custom template (strip modules: days, risk). Not recommended before a device reading.

## Test on an iPhone (checklist for Daniele)
1. Update nothing yet: open https://bc-tamagotchi.vercel.app (after the Verifier deploys this fix) in **Safari**, a normal tab (not private), on Wi-Fi.
2. Note the iPhone model and Settings > General > About > iOS version.
3. Wait up to 60 s on the first load (50 MB). A red banner = screenshot it (it names the failure and carries `BC-DIAG`).
4. No banner and the start screen shows "Tap to enter": screenshot it, tap, screenshot the venue.
5. If the page reloads by itself or goes blank: reopen it; the banner now says "ran out of memory". Screenshot it, close other tabs, try again once.
6. Try Chrome on the iPhone too (same WebKit; tells us if it is Safari-only).
7. Mac route: iPhone Settings > Safari > Advanced > Web Inspector on; plug into a Mac, Safari > Develop > [iPhone] > the page > Console; screenshot red lines.
8. Low Power Mode off for the test.
9. Send the screenshots to the orchestrator with model and iOS.
10. Do not use the home-screen icon for this test.

## Files
`tools/build_web.py`, `docs/art/screens/iphone-load/start-375x812.jpg`, this note, `handoffs/worker-reports-2026-11/iphone-load.md`.
