# STATE — Black Cabin Tamagotchi (rewritten, never appended; as of 2026-10-28)

## LIVE
- Nothing released: no build or publish path yet. `main` holds design docs through coins and stakes, needs system, four minigames, kit v3, characters v2 (accepted), accepted room (parity iteration 18, 6dc9f5d), venue generator.
- Room accepted; characters v2 accepted as base (ae9decf). Layout frozen at `game/assets/kit/layout.json`.

## IN FLIGHT (shared checkout, branch main only)
- Zone wiring: zones, HUD, result card, walk-out, Welcome Back, `smoke_loop`; files uncommitted in the tree, not yet on main.
- Apply decisions: GDD §2 6–10 days, §9 tuning, Rhythm gain +12–18, cast and manual fixes; uncommitted.
- Method setup (this adoption): PROJECT/STATE/LOG/handoffs + vault profiles.

## WORKERS ALIVE (max 3)
- 🎛️ orchestrator fdaed712-5416-430d-b3a7-7174cf46699f
- 🎮 zone-wiring local_694335d4-c7d3-4d7d-a7eb-00de863d4a37 (Opus)
- 🎲 apply-decisions local_17e445ab-606c-450a-b9d1-02d1cbacbe90 (Sonnet)
- 🧹 method-setup local_d1485b13-e58a-4135-9cdc-07faab66c6b3 (Sonnet, ends with this commit)

## WAITING ON OWNER
- Orientation (portrait vs landscape); Black Cabin opening hours; brand typeface; staff turnover policy.
- Resident band + consent packs; stakes numbers; coin sign-off; chat policy.

## NEXT THREE JOBS
1. Performance pass: 42 lights, ~1,850 draw calls, 24 ms GPU desktop; measure on a phone before any phone build.
2. Figure lighting and proportion pass (warm key/rim on figures, heads 27–34 % of height).
3. Character creator + the Flat (minimal home screen).
- Then: lounge camera blocked by curtain wall, performances, memories album, native Thai pass, real-world bridge chapter, web export test.

## POINTERS
- Rules for workers: `PROJECT.md`; history: `LOG.md`; owner decisions: `docs/design/DECISIONS.md`; waves: `ORCHESTRATION.md`.
- Handoffs: `handoffs/orchestrator-2026-10-28.md`. Changelog: `docs/CHANGELOG.md`.
- Method: vault `wiki/concepts/claude-orchestration-method.md`; profiles `wiki/agents/` (G:\My Drive\VAULTS\Talos Vault).
