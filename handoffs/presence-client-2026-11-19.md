# Role note: 🌐 presence-client (social-features), 2026-11-19

Branch `wk/presence-client` (worktree `C:/Users/itisf/bc-wt/presence-client`), from origin/main 40ceef1. Load id
2026-11-19-social-features-black-cabin-9d6cb9. Hub card `presence-client-review`.

## State now
- Presence wave 1 client (08-presence §3.1, §5.1, §6; owner item 40) works against **Fake presences**; nothing is on
  unless asked: `-- --fake-presences`, `?presence=fake` in the web address, or `PresenceClient.use_fake()`. Off = the
  game exactly as before (test_presence_client "off" proves it).
- Code: `game/scripts/presence_ui/` — `presence_client.gd` (the hub: source choice, fetch/sort/cap, verb limits,
  inbox, check-in, local night state in `needs.ext["presence"]`), `fake_presence.gd` (answers in 08b shapes),
  `presence_badge.gd` (live icon + floor ring + verb bubbles), `presence_taps.gd` (tap on a presence → card),
  `presence_card.gd`, `presence_inbox.gd`, `checkin_flow.gd`. Hooks: `venue_patrons.gd` (presence step before the
  anonymous fill, late walk-ins, poll, removal, `vacate()` never moves a presence), `start_screen.gd` (Inbox · N button,
  QR check-in before walking in). 70 strings `ui.presence.*` in `strings_ui.csv` (EN + TH).
- Suite `game/tests/test_presence_client.gd` (69 checks). Captures `docs/art/screens/presence-client/` via
  `game/tests/capture_presence_client.gd` (hidden desktop only).

## Backend wiring (next step)
- The backend contract is `docs/design/08b-presence-api.md` on `wk/presence-backend` (autoload `Presence`). The
  client already speaks its shapes (modes everyone/here/nobody, reasons, `table_id` "" + `zone` for P3, phrase ids
  `p01..`, drink `{drink_id, band}`, inbox `from` dict, `need_mode`, server calls `Needs.check_in()` itself).
- `PresenceClient._pick()` uses the autoload when `/root/Presence` exists and `is_active()` (real URL or its mock).
  `RealSource` wraps the awaited calls. **Not run yet against the real autoload** (it is not on this branch): after
  both branches merge, run test_presence_client once with `Presence.use_mock(true)` + `mock_fake_presences(12)` instead
  of the fake, and a real-device check of the QR URL `https://blackcabin.app/?t=<code>`.
- Polling: the venue polls itself every 120 s through `fetch_tonight`; the autoload's own `start_polling()` /
  `tonight_changed` are not used (one poller is enough). `inbox_changed` is not used either.

## Open (owner or later jobs)
- "Send a drink": no coins exist yet, so it is free and `band` is 0 (P10 wants the coin price). The received drink
  is only listed in the inbox: no drink inventory exists.
- Phrase lines: 12 drafts (GDD §5.3 gave three examples and asks 24); the backend has ids p01–p24. Owner to supply.
- Not built: "+N more here tonight" past the cap, the door's offline dot, Last night on the lounge board, the push
  opt-in card (08b §4), Settings → Presence (change mode, delete my data), tablemate toast in the venue (N1 is shown
  on the check-in result only), table cheers / polaroid / friend link (P11).
- Cheers does not check "a drink in hand" (§5.1).
- PRESENCE_CAP 40 avatars are not perf-tested on a phone (each avatar is unmerged parts, ~10 meshes).

## Gotchas
- An autoload named `Presence` exists on the backend branch: never name a script const `Presence` (shadowing);
  the client uses `PresenceClient`.
- Badge height comes from the figure's measured rest-pose top (`presence_badge.gd standing_top`): avatar libraries
  are taller than the presets.
- The tap catcher sits on the root after the game scene so it hears touches before the Player; it takes both press
  and release (the Player's own tap tracking never starts).
- Fake table codes must be 10 characters (08b CODE_RE): `TESTTABLE2` → Table2, `TESTTABLE1` → Table1.
