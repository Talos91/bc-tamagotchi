# 🎲 stakes-fold — report (2026-11-02)

Worker: 🎲 stakes-fold (Opus, docs only), started by the orchestrator
(local_9bb3d41c). **Commit 625f83f** (design docs), this report and the role
note in the commit after it. Not pushed. No game code, no version bump, no
changelog. Daniele did not message this session.

## What changed, per file

| File | Change |
|---|---|
| `docs/design/06-stakes.md` | **v3**, rewritten around the answers. §1 goal and v2→v3 table; §2 needs (four meters + visit and calendar habits; the memory at the bar is part of the fatal need; `minigame_played`); §3 what counts (real visit [server], in-game stand-in, `REAL_VISIT_REQUIRED` switch, Out of Town the only pause); §4 timer and warnings (21 days, stages 10 / 15 / 18 with the reason); §5 ghost window 14 days, revival only by a real-bar check-in once per 90 days, zombie return; §6 total deletion; §7 stronger annoyances (drag ×0.85 per annoyance, frictions) and minigame misses + tries; §8 attachment; §9 the Flat; **§10 build spec** (states, timers, warnings, annoyances, minigames, UI, constants, save fields, server items, build order, 18 tests); §11 edge cases; §12 amendments applied; §13 answers table + open calls O1–O4 |
| `docs/design/04-coins.md` | Status **v2, signed off** (C1); the hub's Coins tab is the live copy and wins when a row is edited; drink bands as decided (C2); Flat row with Monday rent, pauses, grace, storage, re-rent; wardrobe sold at the **coin merch shop in the lounge** (tiers 30/60/80/120; item list is the lounge-merch-items card); **real-life merch shop later, never coins**; a miss earns no coins; annoyances never cost coins; Flat constants; §10.1 now records the GDD amendments as applied |
| `docs/design/04-coins-summary.md` | Marked signed off, Coins-tab note, merch shop, Flat details, real-life shop row, check-in wording (keeps the character alive, revives a ghost) |
| `docs/design/02-gdd.md` | Revision line; §1.1 home; §2.1 Out of Town (visit clock, no Long Trip, not from Restless) and Empty; §2.2 Homebody look from Restless; §2.3 miss line + `minigame_played` row; §2.5 "nothing breaks at 0" replaced by annoyances + the stakes in one paragraph; Welcome Back on rescue and revival; §2.6 three stake messages outside the budget; §3 home view; §4 staircase (real events floor, Flat behind the rope later); §6.1 events on Bangkok time; §7.2 merch shop; §7.3 the Flat; §9 misses and 3 tries per visit; §10.1/10.2 deletion and the visit clock; §11 merch shop, upstairs; §13 platform decided (mobile only); §14 first-playable scope; §15 answered |
| `docs/design/01-high-concept.md` | Status line; pitch adds the one rule; platform decided (mobile only); pillar 2 rewritten; Sims and Tamagotchi rows; the hook paragraph states the stakes and the Flat |

## Conflicts resolved

1. **S5 vs S8** — settled as S13: only a real visit (QR check-in or a memory
   taken at the bar) resets the 21-day clock; S5's "any one refill action" is
   the in-game stand-in until the server exists. One flag
   (`REAL_VISIT_REQUIRED`) switches; at the switch every living character's
   clock restarts so nobody dies of the change.
2. **"Two habits" vs Daniele's S8 note** — the habits are the **visit**
   (fatal; a memory at the bar counts as one) and the **calendar** (minor).
   v2's separate memory habit and its "Faded pins" annoyance are dropped;
   in-game memory drops stay the collection layer.
3. **S9 "stronger (coin or gain penalty)" vs C1 "no fines for neglect"** —
   C1 signed off the coins page as written, so the stronger bite is in gains
   and play, never coins: a ×0.85 drag on other meters per active annoyance,
   firmer frictions, minigame misses and 3 tries.
4. **GDD §9 "no fail screen" and §2.3 "never zero"** — overruled by Daniele's
   S9 note; a round below 0.25 is a miss. A missed Candle Talk keeps "no
   rejection": it costs a try, not a heart or the day's talk.
5. **Warnings on a 21-day clock** — v2's 7/10/12 became 10/15/18: a weekly
   player and a fortnightly bar regular never see worse than Restless; Last
   Call leaves three days, which always hold two nights the bar is open.
6. **Revival before the server** — S3 allows only a real-bar check-in, so no
   revival ships until the server; a debug "Fake check-in" runs the same path
   for tests (open call O2).
7. **GDD vs DECISIONS elsewhere in the touched sections** — events on Bangkok
   time (DECISIONS (f)), mobile only, §15 answered.

## Build list for the needs worker (06-stakes §10.9 step 1; no server, no coins)

**`game/scripts/rules.gd`**
- New constants (06-stakes §10.6): `FATAL_DAYS` 21.0, `GHOST_WINDOW_DAYS`
  14.0, `STAKE_STAGES` `[["last_call", 18.0], ["fading", 15.0],
  ["restless", 10.0], ["fine", 0.0]]`, `GHOST_REMINDER_DAYS` [28.0, 33.0],
  `REVIVE_COOLDOWN_DAYS` 90.0, `REVIVE_METER_FLOOR` 40.0,
  `REAL_VISIT_REQUIRED` false, `STAKE_NOTIFY_OUTSIDE_BUDGET`
  ["last_call", "dead", "ghost_33"], `ANNOY_EMPTY_BELOW` 10.0,
  `ANNOY_DRAG_MULT` 0.85, `THIRSTY_WALK_MULT` 0.75, `EARWORM_DUCK_DB` −9.0,
  `RUSTY_FUMBLE_SECONDS` 2.0, `CALENDAR_HABIT_DAYS` 7.0,
  `CALENDAR_HABIT_ENABLED` false, `MINIGAME_MISS_BELOW` 0.25,
  `RUSTY_MISS_BELOW` 0.4, `MINIGAME_TRIES_PER_VISIT` 3, `GOING_BONUS_MUSIC`
  10.0, `RETIRE_COOLDOWN_DAYS` 7.0.
- `ACTIONS["minigame_played"]` = `{"gains": {"nightlife": 3.0},
  "cap_per_visit": 9.0}`.
- `static func stake_stage(days)` in the shape of `vibe_state()`.
- **Fix the stale comment on `START_VALUE`** (line 15: "06-stakes §2 assumes
  it ("meters 75", Gone at 21.0 days)"): point it at GDD §2.1 only.
- Flat constants wait for the wallet (step 2).

**`game/scripts/needs.gd`**
- Stake clock: `last_counted_visit`, `days_since_visit()` excluding Out of
  Town time; stage derived in `sync()`/`_refresh()`; signals for stage changes
  (for the home chip and postcards).
- Stand-in: any accepted `apply_action` counts the visit at that moment.
- `can_start_out_of_town()` false from Restless on.
- Ghost: enter only between visits at 21.0; freeze decay; `apply_action`
  refused with `reason: "ghost"`; `begin_visit()` allowed, counts nothing;
  deletion at `dead_at` + 14.0.
- `check_in()` entry point (real visit; revives a ghost if outside the 90-day
  cooldown; meters floored at 40, Welcome Back, `lives` +1, zombie flag);
  called by the debug panel now, the server later.
- Annoyances: on/off per §10.3, cleared-for-this-visit set, the drag in the
  gain multiplier (other meters only), exposed for UI and walk speed.
- Minigame tries per id per visit; `minigame_played` after non-miss rounds.
- Welcome Back also on rescue (counting visit from Restless) and revival.
- Deletion and Retire: split `new_game()` so `profile.player_id` and settings
  survive; everything else goes. Retire once per 7 days.

**`game/scripts/save.gd`** — no version bump; document the new `needs` keys
in the schema comment. Keys and old-save defaults: 06-stakes §10.7
(`last_counted_visit` defaults to `last_visit_end` or load time — nobody dies
on upgrade).

**`game/scripts/minigames/`** — `minigame_base.gd`: miss tier below 0.25
(0.4 on the first round while Rusty), `tier_for()` returns a miss; the comment
"Never a fail tier" goes. `result_card.gd`: MISS word and line, no gain line;
"That's plenty for tonight" after the third try. `minigame_frame.gd`: no
`apply_action` on a miss; Pour Perfect miss serves no drink (no tipsiness).
Candle Talk miss keeps the regular's daily talk.

**UI** — home (start screen / Flat stand-in): stage look, stage chip,
postcards, annoyance icons; venue HUD: annoyance icon by its meter, Last Call
chip only; ghost look and "You're a ghost" prompts; zombie arrival, sticker,
"Lives: 2"; farewell card (save/share) then creation; settings: Retire;
player walk speed ×0.75 while Thirsty (`player.gd`); music bus duck while
Earworm; debug panel: jump to day N, Fake check-in, Open calendar. Strings in
`game/i18n/` (English + Thai drafts).

**Tests** (06-stakes §10.10, 1–17 now; 18 with the wallet): stage edges at
9.99/10/14.99/15/17.99/18/20.99/21; ghost at 21.0, deleted at 35.0;
stand-in counts on an accepted action only; no death mid-visit; Out of Town
freeze and Restless block; meters at 0 never kill; 12 weeks of one sample
visit = always Fine, only Thirsty; ghost refuses actions and freezes decay;
revival via Fake check-in and the 90-day refusal; deletion keeps `player_id`
and settings, Retire cooldown; annoyances on/off and drag ×0.7225 with two;
miss at 0.24 vs good at 0.25, Rusty 0.4; fourth try refused, new visit
resets, missed Candle Talk keeps the daily talk; `minigame_played` cap 9;
old save loads at Fine; backward clock never un-kills; sample visit still 0
coins and no misses. Probably a new suite `test_stakes`, plus updates to
`test_needs` and `test_minigames` (the no-fail-tier assertions).

## Open calls (for the Questions tab)

- **O1 Players who can't reach the bar.** Once real visits are required, a
  player outside Bangkok dies every 35 days whatever they do. ★Real visits
  required from a character's first QR check-in / for everyone / never (real
  visits only add bonuses). Settles: "Real visits are required [for everyone
  / from a character's first check-in / never]."
- **O2 Revival before the server.** ★The ghost window just runs out (debug
  check-in for tests) / the in-game stand-in revives too. Settles: "Before the
  server, a ghost [can't be revived / is revived by an in-game visit]."
- **O3 How a memory proves it was taken at the bar** (bridge chapter). ★Only
  photos shared on a checked-in night count / location + opening hours /
  staff approve. Settles: "A memory counts as a real visit when […]."
- **O4 Tuning:** drag ×0.85 per annoyance, miss line 0.25 (0.4 Rusty), 3 tries
  per minigame per visit, warnings at 10/15/18. Settles: "Stakes numbers
  confirmed as in 06-stakes v3 §10.6 [with changes]."

## Follow-ups noticed (not mine to fix)

- `docs/MANUAL.md` §5 ("Stakes: mandatory care and Last Call") and its
  glossary still describe v1 (Packing stage, Long Trip, "leaving Bangkok");
  the live manual doc too. Housekeeping / the manual refresh.
- `DECISIONS.md` "Still open": "Death rules in detail" and "The Flat as a
  rented second-floor room" are answered by 06-stakes v3 (orchestrator's
  file); the S13 row could note O1–O4 as the remaining stakes questions.
- `docs/design/BACKLOG.md` D5 says a TV-corner photo "counts as the monthly
  refill of one need"; under v3 it counts as a real visit.
- GDD §8 still says 24 coasters (the real menu has 121 drinks): menu domain.
