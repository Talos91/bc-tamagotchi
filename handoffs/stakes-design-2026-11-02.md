# 🎲 Stakes design — role note (state now, 2026-11-02)

Worker: 🎲 stakes-design (Opus, docs only), started by the orchestrator
(local_78d0c67d). Done; archived after reporting.

## What exists now
- `docs/design/06-stakes.md` **draft v2**: fully rewritten from Daniele's base
  proposal (DECISIONS 2026-11-02 "Stakes"). One fatal rule (no counting visit
  in 14 days → dies → 7-day ghost window → deleted at 21), NPC zombie-act
  revival for single-player (a regular at 2+ hearts, once per 90 days),
  friend and real-bar revival for later, total deletion, six minor
  annoyances, attachment levers, **the Flat (§9)**, mapping onto
  `rules.gd`/`needs.gd` with new constants, save fields and 13 tests, edge
  cases, amendments for other docs, calls S1–S12.
- `docs/design/04-coins-summary.md` (new): the one-page coin summary for
  Daniele's sign-off.
- `docs/design/04-coins.md`: amended only where the summary changes it (§1
  coins deleted with a dead character, §3.1 drink bands from the real menu's
  THB, §3.2 Flat rent row, typical-spend line, §5 last line, §10 constants).
- The Flat lives in `06-stakes.md` §9 (where the character lives, where the
  game starts, what death takes); rent numbers echoed in the summary and §10
  of `04-coins.md`.

## Not done (on purpose)
- `02-gdd.md` and `01-high-concept.md` still describe v1 (Last Call clocks,
  Long Trip, "left Bangkok"). The amendment list is `06-stakes.md` §12; a
  housekeeping or design pass applies it **after** Daniele answers S1–S12.
- No code: `rules.gd`/`needs.gd` untouched. The needs worker builds from
  `06-stakes.md` §10 once the calls are answered.
- `rules.gd` comment on `START_VALUE` still cites v1 ("Gone at 21.0 days").
- DECISIONS.md untouched (orchestrator's file).

## Calls for Daniele (for the Questions tab, kind "design" unless noted)

Each: question · context · options (★ = recommended) · doc section.

- **S1 Fatal timer.** How many days without a visit before the character dies? · Daniele: "not an everyday job"; 14 lets a once-a-week player miss a week safely. · 10 days / ★14 days / 21 days · 06-stakes §4
- **S2 Revival window.** After death, how long can a friend bring them back before deletion? · 7 makes deletion land at day 21, like v1's timeline. · 3 days / ★7 days / 14 days · §5.1
- **S3 Revival before multiplayer.** Who can revive in single-player? · Multiplayer isn't built; regulars at 2+ hearts make friendships the insurance. · ★A regular at 2+ hearts stages the zombie act, you play one rhythm round / No revival until multiplayer / Only a real-bar check-in (needs backend) · §5.2
- **S4 Revival limit.** How often can a character be revived? · Without a limit death stops meaning anything. · ★Once per 90 days (friends later: once per 30) / Once per life / No limit · §5.2–5.3
- **S5 What counts as a visit.** What saves the character from the timer? · Light, but standing at the door shouldn't count. · ★3 active minutes past the Sticker door / Any one refill action / Opening the game at the street door · §3
- **S6 Tone of death.** How does the game talk about it? · Daniele's zombie example suggests a wink. · ★Playful ghost and zombie ("died of boredom") / v1's "left Bangkok", no death words / Plain "game over" · §1
- **S7 What survives deletion.** Daniele said total; these are the only edges. · Claimed vouchers are a promise to a real person. · ★Nothing in-game; claimed real-world vouchers stay valid; a farewell card to save / Absolutely nothing / The memory album too (as DECISIONS 2026-10-28 said) · §6
- **S8 The seven needs.** How do they sit on the four meters? · Keeps rules.gd and the HUD as built. · ★Four meters + two habits (memory, calendar); minigames also feed Nightlife / Six meters / Four meters; memory and calendar are nudges with no annoyance · §2
- **S9 Annoyance strength.** How much should neglecting a minor need bite? · Weekly players should only ever see Thirsty. · ★Cosmetic + tiny friction (slower walk, ducked music, an extra tap, a 2 s fumble) / Cosmetic only / Stronger (smaller gains or coin penalty) · §7
- **S10 Pauses.** What can stop the timer? · Two weeks + Out of Town = 28 days away once a month. · ★Out of Town as built only / Also v1's yearly 35-day Long Trip / No pause at all · §3
- **S11 Flat price.** What does the room upstairs cost? · Weekly players should be able to hold it; it's also the main coin sink. · 60 + 15 a week / ★100 move-in + 20 a week / 200 + 40 a week · §9 (picture: `docs/art/screens/v4/portrait-stair-top.png`, `portrait-stair-eye.png`)
- **S12 Rent lapse.** What if the wallet can't pay? · Coins never go negative. · ★7-day grace, then moved out; frames in storage; re-rent free within 30 days / Moved out at once / Prepaid only, can't lapse · §9 (same pictures)
- **C1 Coins sign-off.** Sign off the one-page summary? · Daniele asked for it before signing coins off. · ★Sign off as written / Sign off with changes (note) / Not yet · `04-coins-summary.md`
- **C2 Drink prices.** How are paid drinks priced in coins? · The real menu replaced the invented drinks; THB stays shown, dimmed. · ★Banded from the real THB price (≤250 → 4, ≤500 → 6, more → 9; bottles not for coins) / One price for every drink / Proportional to THB · `04-coins.md` §3.1
- **F1 (kind "facts") What's really upstairs at Black Cabin?** · The Flat fiction puts rented rooms behind the velvet rope. · Staff/storage, the fiction is fine / A real second room or bar, so the Flat should go elsewhere / Don't know, keep the fiction · §9 (pictures as S11)

## Numbers check
Simulated with the built decay (rates from `rules.gd`, soft floor 30 ×0.3,
start 75) and the GDD §2.3 sample visit, 12 weeks after a 4-week warm-up:
with the Empty threshold 10, players at 2–3 visits a week never arrive with
an annoyance; 1 a week only Thirsty; 1 every 13 days all four. At threshold
20 a weekly player would see all four every visit, hence 10. Script (scratch,
not committed): decay with the floor, `tier()` diminishing returns, Welcome
Back ×2 when away 7+ days or Vibe < 25.

## Next for whoever picks this up
1. Orchestrator: cards S1–S12, C1, C2, F1 on the Questions tab; answers to DECISIONS.
2. Fold answers into `06-stakes.md` / `04-coins*.md`, then apply §12 amendments to the GDD and high concept.
3. Needs worker: implement §10 (constants, save fields, tests 1–13) behind the debug clock.
