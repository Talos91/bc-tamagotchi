# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-21 ~02:30 Bangkok, orchestrator local_14422c6c; context 370k = 74 % of 500k measured — Daniele: "no handover")

## LIVE
- https://blackcabin.app = **v0.4.6 · 8b86f99** (bc-57f2a887). Auto deploy on push to main. Supabase czrbsjalcjekcslylwbt.
- Landed 11-20/21 night (each verified + deployed): overflow seats 8d51b2b · play telemetry 53096f4 · QR remake 296783a (39 codes/31 tables, new tokens, seed live) · creator-fix 2 b607586 · merch shop + PlayerProfile b74364f (40 items, migration+seed live) · check-in hotfix 1 65801ea (gzip, did NOT fix) · hotfix 2 291a00f v0.4.1 (4 s HTTP timeout during 7.8 s boot block = real cause) · minigame endless ramp 90e3da2 v0.4.2 · presence hotfix 3 3e17417 v0.4.3 (same-table seating, in-bar verb banner, Leave = check-out; migration 000001 live) · still-here prompt 0b5fa04 v0.4.4 (migration 000002 + edge fn still-here + crons live) · perf-iphone 08236bd v0.4.5 · presence hotfix 4 8b86f99 v0.4.6 (session mirrored to localStorage; restore brings tonight; migration 000003 live).
- Confirmed by Daniele at the bar: check-in works on 0.4.1. NOT yet seen on a phone: seating, banners, Leave, still-here, perf, 0.4.6 session keep.

## OPEN / NEXT
- Daniele: add Vault secret `bc_service_role_key` (Supabase Dashboard → Vault) so still-here push notifications send; until then in-game prompt only.
- Daniele had 2 anon users tonight (old ac0eecf4 checked in, new 1e8e6f68); fix = enter old player code in merch shop (restore moves check-in + 7 unread verbs) or re-scan QR.
- test_avatar is flaky (fails on main too) → small fix job.
- Queued next week: handoffs/queued-next-week-2026-11-21.md (Black Cabin loading screen; Android APK/AAB + iOS via cloud Mac/TestFlight).
- Hub cards open: merch-prices, merch-free-cap, merch-cut, merch-keep-on-reset, perf-iphone-1120-saver, minigame-ramp rivals/candle (built on rec), DECISIONS rows for tonight's answers still to write (Housekeeping).
- Worktrees under C:/Users/itisf/bc-wt/ (play-telemetry, qr-remake, creator-fix, merch-shop, minigame-ramp, perf-iphone, checkin-hotfix*, presence-hotfix-3/4) → Housekeeping cleanup after Daniele's OK.

## TREE
- Open (NOT archived — Daniele 11-21: no archiving until he says so): verify-queue-1120 local_4e5c969d, minigame-ramp-1120 local_b65235c8, merch-shop-1120 local_2ab6c32e (out of context), perf successor local_b366ab41, old perf local_d6113b6d. Archived earlier tonight (before that rule): 10 sessions, see LOG.
- Rules tonight: every code push bumps PATCH (Daniele); no permission prompts until all live (Daniele); Godot runs serialized (concurrent imports crash 3221225477/…356); Remote Control turns can't start sessions → subagents / idle workers used.
- Shared .git/index got corrupt twice (Drive) → rebuilt with read-tree HEAD.

## POINTERS
PROJECT.md (Tests 38) · LOG.md · docs/design/DECISIONS.md · docs/tech/04-deploy.md · docs/tech/telemetry-queries.sql · hub https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW
