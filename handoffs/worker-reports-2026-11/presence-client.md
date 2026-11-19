# Worker report: 🌐 presence-client, 2026-11-19

## Evidence
- Branch `wk/presence-client`, rebased on origin/main 54b1e94; code commit 4c0a01e (this report and the note on top).
- Suites, headless, each with its own empty APPDATA, on the rebased tip 4c0a01e: **28 of 28 pass** (the 27 of
  PROJECT.md Tests + test_presence_client; 0 SCRIPT ERROR). First full run (before rebase, base 40ceef1): 27 of 28 pass; **test_feel fails 1 check** ("buffer walk: the player
  in clear sight 139 of 147 ticks (hidden by Zones/Tag_mali)") **and fails the same way on a clean worktree of
  40ceef1** (pre-existing, date-dependent: tonight's cast tag; not this branch).
- New suite `game/tests/test_presence_client.gd`: 69 checks pass — off by default (crowd unchanged), spawn (10 of 12
  fake people, 2 are mode "here"), live icon + ring on each and on no NPC, headcount holds, chairs out of group seat,
  vacate() never moves them, P3 (no table reaches a viewer not checked in); late check-in walks in from the street
  door and sits; hidden presence leaves at the next poll; a real tap through the input pipeline opens the card and
  does not walk the player; wave sent (source got it, "Sent", bubbles), 1 per pair, drink, phrases 3 per pair,
  Hide; inbox (2 items, a new one arrives, Got it marks read, Friends +2 queued for the visit); QR check-in (consent
  first, nothing preselected, Check in off until a choice, checked in at Table2, tablemates, needs.check_in ran,
  Into the bar walks in, code used once, then the "here" people show and sit at their real tables); offline venue
  (anonymous room, no error) and offline check-in (error, Not now walks in).
- Captures (hidden desktop, hd.ps1, Godot never foreground), portrait 1080x1920 + landscape 1920x1080:
  `docs/art/screens/presence-client/` 1-badge, 1b-badge-closeup, 2-card, 3a-wave-sent, 3b-phrase-wheel,
  4a-start-inbox-button, 4b-inbox, 5-checkin-consent, 5b-consent-chosen, 6-checkin-done (20 PNG).
- Hub card `presence-client-review` (6 pictures + files).

## What was built
- `game/scripts/presence_ui/`: presence_client.gd (source choice: `Presence` autoload when active, else Fake
  presences when asked by `--fake-presences` / `?presence=fake`, else off), fake_presence.gd (08b answer shapes),
  presence_badge.gd (cyan pulsing live icon placed from the measured head height, floor ring, gold for tablemates,
  verb bubbles), presence_taps.gd, presence_card.gd (avatar portrait, tags, nights together, Wave / Cheers / Send a
  drink / Say… with 12 fixed lines, Hide / Report with fixed reasons), presence_inbox.gd, checkin_flow.gd.
- `venue_patrons.gd`: presence step before the anonymous fill, late walk-ins, 120 s poll, fade-out removal.
- `start_screen.gd`: "Inbox · N" button; QR check-in (after the creator for a new character) before walking in.
- 70 `ui.presence.*` strings, English + Thai, in strings_ui.csv.

## Not verified / open
- Not run against the real `Presence` autoload (backend branch not merged here); the adapter follows 08b v1.1.
  After the merge: run the suite once on `Presence.use_mock(true)` and check the QR URL on a real phone.
- Owner: phrase lines (12 drafts; backend has p01–p24), coins for Send a drink (none exist; sent free, band 0),
  drink inventory for received drinks. Not built: +N more past the cap, offline dot, Last night board, push opt-in
  card, Settings → Presence, N1 toast inside the venue, table cheers / polaroid / friend link (P11).
- 40 avatars (the cap) not perf-tested on a phone.
- Profile note: the generic `social-features` profile fit; nothing to change.
