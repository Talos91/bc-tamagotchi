# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-11-20 ~20:50, final rewrite of orchestrator local_5352afaa before handover; context 67 % of 500k measured = past 40 %)

## LIVE
- https://blackcabin.app (bought 11-20; www → apex; also bc-tamagotchi.vercel.app) = **4e9dbc8** (venue entrance round + tonight lineup 2ce7624 + v0.4.0 presence). **Auto deploy live**: a push to main touching game/ builds on GitHub Actions → Vercel preview → prod (docs/tech/04-deploy.md). Supabase czrbsjalcjekcslylwbt.
- Phones may show an old build (PWA service worker): close every tab and reopen (fix in perf-iphone).

## IN FLIGHT (order: overflow → play-telemetry → creator-fix 2 → perf-iphone LAST)
- 🔍 verify-f4abb26-overflow local_0aa239c0: overflow seats, cherry-pick 8d51b2b on 72f669d, verifying with Godot quiet. Worker overflow-seats-1120 local_f0b1504b held until pushed.
- 🎮 play-telemetry-1120 local_295e6368 (4th worker, Daniele's word): play_events table + mg start/end/loss; Daniele wants it live tonight, queries for tomorrow's tuning (docs/tech/telemetry-queries.sql).
- 🖼️ creator-fix 2 (successor of local_768f5184, started by Daniele): item 7 invisible player after EVERY minigame FIRST, then 6 global touch scroll, 8 remove small arcade, 9 memory screen faces room, 10 entrance door gap, creator UI responsiveness (1) + new clothes in the creator (3). Done already at f0aa27b/e55b39b: 4 reach-out selector, 5 alcove wall, 2 hair cover, wardrobe kit + avatar v2. Role note handoffs/creator-fix-2026-11-20.md.
- 🛠️ perf-iphone-1120 local_d6113b6d: perf + phone overheating (Daniele's telemetry), fullscreen button (iPhone = Add to Home Screen hint), SW update takeover, PWA install fails on Daniele's phone. **Lands LAST: message it "main has everything" when the three above are live**; then it rebases, re-measures, reports.
- QUEUED: minigame endless ramp + loss conditions → `handoffs/queued-minigame-ramp-2026-11-20.md` (start when a slot frees; ramp table needs Daniele's OK).
- Local docs NOT pushed: 1af7567 (PROJECT Tests 32), fec3963, 94bf978, this rewrite + handoff → push after the overflow verifier pushes (FF check).

## TREE (method 3b)
- Predecessor tree local_96f4e96d: done/archived. This stint local_5352afaa: 7 workers/verifiers archived (hk-cards, deploy-pipeline, verify-deploy, venue-entrance ×2, verify-venue, tonight-lineup, verify-lineup); open: the five above. Recap: vault raw/agent-notes/2026-11-20-black-cabin-orchestrator-stint-session-local-5352afaa-2026-1.md. Handoff handoffs/ORCHESTRATOR-HANDOVER-2026-11-20b.md.
- Orchestrator now local_14422c6c (from 20:45). The five open sessions (verify-overflow, overflow-seats, play-telemetry, creator-fix 2, perf-iphone) were DETACHED at handover = top level: close each myself (role note, report, archive) when done; archiving local_5352afaa does not take them along (Master 11-20).
- **Orchestrator: Opus 5.5 medium; orchestrators never Sonnet (Daniele 11-20). Fable workers only for an architecture plan or a bug Opus failed twice; Daniele's OK each time, logged.**
- Hard walls: never push past unverified code; Verifier always its own session; code workers in own worktree C:/Users/itisf/bc-wt/<job>; ≤ 3 workers (4th only by Daniele's word); ctx measured vs 500k (40 % = 200k, any compaction = past 40 %).
- Godot: ALWAYS C:/Users/itisf/godot-local/Godot_v4.6.1-stable_win64_console.exe (Drive exe crashes; skill default is Drive → pass --godot). Concurrent imports crash on strings_venue.csv → verifiers wait for quiet Godot + own TEMP. Kill by PID only.
- Peer/event-started turns cannot start sessions → verifier cards Daniele clicks. Archiving a worker detaches its nested successor.

## WAITING ON OWNER (hub #questions)
- **QR FREEZE (Daniele 11-20): don't change docs/venue/qr or table codes — friend test tonight.** Table map docs/venue/qr/table-map.svg.
- Open: redirect vercel.app → blackcabin.app (resets saves; keep both meanwhile); band-photos-consent; bar-open-mondays (posters list Monday); LoungeTable0/1 QR name removed tables; cards 403–406 (phrase lines, send-drink coins, drink inventory, Prae's sign); reviews tonight-lineup-review, overflow-seats-review, creator-fix-1120-review (coming). Answered: venue-entrance-review v4 (QR tables, arcade, counter) — not yet built.
- Hub has no archive field: the 160 answered cards stay; old card list in git history.

## POINTERS
Rules PROJECT.md (Tests: 32 suites incl. test_lineup, test_overflow_seats); history LOG.md; decisions docs/design/DECISIONS.md; deploy docs/tech/04-deploy.md; events docs/venue/events/README.md (weekly lineup = data only); ideas docs/design/BACKLOG.md (stale since 11-15: refresh via Housekeeping); hub https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW.
