# 🌐 Presence design — worker report (2026-11-09)

## Evidence
- Commit **a6ca189** (local, not pushed): `docs/design/08-presence.md` (new, 12 sections),
  `docs/art/screens/presence/presence-01-venue-mock.png`, `presence-02-flow.png` (both 1080×1920).
- Commit of this report + role note `handoffs/presence-2026-11-09.md`: see the orchestrator message (SHA).
- Hub card **presence-design-review** (Questions tab, kind design, multi-select, P1–P11, 2 pictures, 3 files).
- No suites run: design only, no game code, no `rules.gd` / `save.gd` / `layout.json` / version / Supabase touched.
- **Vault: `load_agent` and `capture` not run** — the `talos-vault` MCP server failed to connect (CONNECTION_CLOSED)
  for this whole session. No load id. Profile read from the vault file by hand. The orchestrator (or a later session)
  should capture this report to the vault.

## What the design says
- Presence = events, not sync. A table-QR scan (`bc-tamagotchi.vercel.app/c/<code>`, opening hours, one per night)
  writes a check-in with an avatar snapshot; every phone polls tonight's list every 2 min and seats those avatars in
  place of anonymous patrons until 02:00 (cap 40, "+N more" at the door). Offline = today's crowd.
- Tablemates: same table within 45 min → instant toast, table cheers, shared polaroid (counts as the O3 memory),
  friend link, nights-together counter.
- Verbs on a presence (wave, cheers, send a drink, phrase) are async events read at next open; no free text anywhere.
- Notifications: in-app for tablemates and verbs; push opt-in only (friend check-in, Friday crowd line).
- Backend: Supabase (Singapore, free tier), anonymous auth, RLS, `check_in()` / `send_verb()` / `delete_me()`,
  one Edge Function for web push; rate limits, hide/report, 3-report name reset, retention table (§7).
- Replaces GDD §5.2 P2/P3 and ORCHESTRATION wave 4 (amendment list §11, not applied).
- Deferred: Flat visits (wave 2), live table games on the relay (wave 3), real-world rewards (bridge chapter).

## Owner calls (P1–P11, card presence-design-review)
P1 consent mode at first check-in · P2 presence until closing · P3 who sees the real table · P4 data retention ·
P5 accounts (anonymous + optional email) · P6 friend pushes vs the 22:00 rule · P7 what staff see · P8 backend
money · P9 QR anti-cheat · P10 send a drink with coins · P11 wave-1 together scope.

## Not verified
- No backend exists; limits and Supabase free-tier figures are from Supabase's published plans as I know them,
  not checked live. Web Push on iPhone (installed PWA only) not tested on this export.
- Mock 01 is a composed overlay on the camera-feel-2 floor capture, not a game render; rings and tags are hand-placed.
