# LOG — Black Cabin Tamagotchi

Append-only. One dated line per event, newest last. Never edit earlier lines.

- 2026-10-27 — Project created; repo Talos91/bc-tamagotchi empty; brief and 12 venue photos imported (1fe85b9).
- 2026-10-27 — Wave 1 done: GDD and high concept (89bdc15), art bible v2 (b2c8145, 9f1a080), engine decision Godot 4.6 + greybox (65e0133).
- 2026-10-27 — Wave 2 done: cast bible (4b5baa2), UI style guide (8a3a59e), 35-object venue kit (9ee9148), needs prototype with tests (184e394); orchestrator review bf2ea66 split wave 3 into 3a/3b.
- 2026-10-27 — Decisions: commissioned by Black Cabin, 21+, alcohol in, EN+TH, phone portrait primary (later reopened), coins yes / decor no, real-world bridge (5386b79, cbff3d2, b02fc6d, bb3fc82).
- 2026-10-27 — Wave 3a done: kit v2 (9b0141b), minigames (f749960), venue integration (f26a150); changelog and wave 3b inputs from minigames report (6252315).
- 2026-10-28 — Decisions: neglect is fatal (bb3594b); venue layout from renders 01–03 only (d6107e0); quality bar renders 05/06 (4003717); coins and stakes chapters (ac0be50, 403a2c1).
- 2026-10-28 — Wave 3-parity started: parity pass on renders 05/06, iterations 1–10 (526fecf, ef72644, a2d77ad, 146d334); plan confirmed, lounge turned (31660d6).
- 2026-10-28 — Session archived: 🎨 visual parity pass (local_ae62f504), split into two sessions.
- 2026-10-28 — Sessions started: 🎨 chars-parity (local_0ae05ffd) and 🎨 room-polish (local_6b78b408) on disjoint paths.
- 2026-10-28 — Room polish iterations 11–17 landed (ad8bf98); room accepted at 17 pending 18 (4c38ee6); wave 3b mechanical (Sonnet, wave3b-mech) started.
- 2026-10-28 — Session started: 🎮 zone-wiring (local_694335d4), zones from layout.json, HUD, result card, walk-out, smoke_loop.
- 2026-10-28 — Wave 3b mechanical done: fonts + theme (73886af), rules fixes (db7871e), GDD amendments (f82a5c1), Nam fix (60d934d), tuning proposals (3a4d81c).
- 2026-10-28 — Room accepted at parity iteration 18 (6dc9f5d); session archived: 🎨 room-polish. Debt: 42 lights / 24 ms GPU, lounge camera, figure lighting.
- 2026-10-28 — Characters v2 delivered (85d08e7 … ae9decf, 42 presets); Daniele accepted it as base and five calls (f7510f0); session archived: 🎨 chars-parity.
- 2026-10-28 — Session started: 🎲 apply-decisions (local_17e445ab), GDD §2/§9, Rhythm gain, cast, manual.
- 2026-10-28 — Method adopted (Daniele: "i accept all for now we will tweak later"); session started: 🧹 method-setup (local_d1485b13).
- 2026-10-28 — Setup done: PROJECT.md, STATE.md, LOG.md, handoffs/, Method section in ORCHESTRATION.md; vault profiles voxel-art and social-features added.
- 2026-11-01 — zone-wiring done: first playable loop on main (068949a, cfa7c72, 5fbe25b, 42cec51), smoke_loop added; 11 provisional calls logged in DECISIONS; archived.
- 2026-11-01 — apply-decisions done: GDD §2/§9, Rhythm +12–18 (b891f3b), cast, high concept, manual, ORCHESTRATION 3b list; archived.
- 2026-11-01 — method-setup done: PROJECT/STATE/LOG/handoffs (ae5e543), vault profiles voxel-art + social-features; archived.
- 2026-11-01 — orchestrator re-ran all six suites, pushed main, rewrote STATE; waiting on Daniele's first hand playtest.
- 2026-11-01 — Daniele played the alpha ("good alpha"); gate = baseline map fix, inputs pending; BACKLOG.md + shared backlog artifact created with all ideas and open questions.
- 2026-11-01 — Daniele supplied the real floor map and nine photos; filed as direction 08–16 (116aa23); orchestrator asking scale/route questions before briefing A1.
- 2026-11-01 — Daniele answered the layout questions (direction 17–22, README); layout unfrozen; sessions started: 🧱 kit-real-room (local_33603a64), 🏗️ venue-rebuild.
- 2026-11-01 — 🏗️ venue-rebuild: plan v4 written (docs/art/plan-v4.md, game/tools/plan_v4.py, plan_view.py --planned → docs/art/screens/plan/plan-v4.png); uniform scale from the map's depth (main room 21.7 × 15 m), 30 m width flagged for Daniele; build starts.
- 2026-11-01 — venue-rebuild plan v4 approved (78c55ef): uniform scale, main room 21.7 × 15 m (owner's 30 m was rough; one constant to switch); minimal edits to main.tscn, smoke tests, venue_patrons approved.
- 2026-11-01 — kit v4 additions done (🧱): 30 baseline-map objects exported (f9380b5), review blends + contact sheet docs/art/screens/kit/kit-v4-additions.png (0fc2320); handoff handoffs/kit-additions-2026-11-01.md. pull --rebase refused (other sessions' unstaged files), commits local.
