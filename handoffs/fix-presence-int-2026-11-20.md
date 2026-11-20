# 🛠️ fix-presence-int — role note (2026-11-20)

Branch `wk/fix-presence-int` in `C:/Users/itisf/bc-wt/fix-presence-int`, on a929206 (v0.4.0 RC, local main; not
pushed). Fix commit 7e66e6d. Load id 2026-11-20-social-features-black-cabin-788a9c. Report:
`handoffs/worker-reports-2026-11/fix-presence-int.md`.

## State now
- Done: 30/30 suites pass headless with an empty APPDATA, zero SCRIPT ERROR; web build exit 0 (not deployed).
- On-switch (08b §1.1): web build on by default (`?presence=off|fake` turns it off); headless, editor and desktop
  inert unless `-- --live` / `-- --presence-live`, `Presence.go_live()` or `Presence.use_mock(true)`.
- `PresenceClient.fire()` drops replies whose callback object was freed (counter `PresenceClient.dropped`).
- Venue hook (`venue_patrons.gd`, presence parts only): tap catcher made before the async answer; react timer binds a
  weakref instead of capturing the figure.

## Next
- Verifier: verify the fix SHA and push with a929206.
- Real-device check of a live web build: presence on, check-in from `https://blackcabin.app/?t=<code>` (domain still
  NXDOMAIN per presence-backend note), `?presence=off` turns it off.

## Gotchas
- Mock and cached `tonight` answer synchronously: to test the async path set `Presence.mock_delay_s` and clear
  `_tonight_at`.
- "Lambda capture at index 0 was freed" (plain ERROR, not SCRIPT ERROR) = a lambda capturing a Node that died before
  a timer fired; bind a weakref instead.
- Web export needs the real APPDATA (export templates live there); run suites with the empty one.
- In the real (async) source, venue presences always walk in through the door; the first seating is never instant.
