# Verify overflow seating: PASS and pushed (2026-11-20)
- VERIFY 8d51b2b: PASS 32/32 suites (incl. test_overflow_seats), import exit 0, web build exit 0 (60.9 MB).
- f4abb26 rebased: origin/main had moved to 72f669d (STATE.md only); cherry-picked a12b3c1 + f4abb26 as 0cfb7c7 + 8d51b2b. Verified and pushed 8d51b2b (not f4abb26).
- Push: 72f669d..8d51b2b, ls-remote main = 8d51b2b (match).
- Deploy: web-deploy run 44748728133 completed success (2m11s). blackcabin.app serves bc-9e53268b (hash read from page; not matched to the commit hash).
- QR/layout freeze: git diff 082979b 8d51b2b -- docs/venue/qr game/assets/kit/layout.json empty (pass).
- Earlier attempts: two imports crashed (3221225477, 3221225501, strings_venue.csv reimport) while other workers ran Godot. Control: bare 72f669d imported fine (exit 0, others running). Third run, with Godot otherwise quiet and own empty TEMP/TMP: clean. Concurrency was the cause.
- Not verified: real device, feel, the in-game seating on a phone; Vercel preview (bypass not set up).
