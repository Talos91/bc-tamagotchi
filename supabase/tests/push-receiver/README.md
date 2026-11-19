# Push receiver test (2026-11-19)

A browser page that plays "the friend's phone": signs in anonymously, subscribes to Web Push with the `verb`
function's VAPID key, saves the subscription and checks in at Table 3. A second player (curl or the Godot live test)
then waves at it; the service worker posts "PUSH RECEIVED" to the page.

    copy ../../../tools/push-sw.js here, then: python -m http.server 8793 --directory .
    open http://localhost:8793/index.html (a real Chrome profile or an Android phone on the same host via tunnel)
    node push_cdp.mjs <cdp port> subscribe | wait      (drive a Chrome started with --remote-debugging-port)
    node gcm_cdp.mjs <cdp port>                        (chrome://gcm-internals: connection + receive log)

Result 2026-11-19: FCM accepted the pushes (201, VAPID valid); a throwaway temp-profile Chrome (headless, and
windowed on the hidden desktop) never received them: its GCM registration failed (UNKNOWN_ERROR) and FCM answered
410 on the next send, which the function handled (status gone, subscription deleted). Device delivery needs a real
browser profile or a phone.
