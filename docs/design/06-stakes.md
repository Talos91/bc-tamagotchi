# Black Cabin Tamagotchi — Stakes: Last Call

Status: draft v1 (2026-10-28). Reads: `DECISIONS.md` (neglect is fatal,
2026-10-28), `01-high-concept.md`, `02-gdd.md` §2, §3, §5, §7, §8, §10, §14,
`03-cast.md`, `04-coins.md`, `game/scripts/rules.gd`. Overrules GDD §2.5 "At 0:
nothing breaks". All numbers are starting values for `rules.gd` (§6).

---

## 1. Pillar and fiction

**Pillar 2, new wording: "Cozy, with real stakes."** Needs drain over days,
not hours. A week of normal life never costs anything. Three weeks with no
nights out, or a need left empty for two weeks, and your character packs up
and leaves Bangkok for good. Their memories stay with you.

**The fiction: they left Bangkok.** In a 21+ bar game, the honest way a
regular disappears is that they stop coming out, then move away. Nobody gets
sick. The ending is final: no revive, no coins, no paid restore, ever.

| Moment | EN | TH (draft for a native writer) |
|---|---|---|
| Name of the system (UI, settings) | **Last Call** | **Last Call** (kept in English, like the bar's own name) |
| Warning chip in the Flat | "Thinking of leaving · 3 days" | "คิดจะย้ายออก · อีก 3 วัน" |
| The ending (title card) | "**[Name] has left Bangkok.**" | "**[ชื่อ] ย้ายออกจากกรุงเทพฯ แล้ว**" |
| The letter on the table (by personality) | Night Owl: "Took a day job in Chiang Mai. Early nights now." · Music Nerd: "Went home to play in my brother's band." · Social Butterfly: "Moved in with family up north." · Easy Sipper: "Took the early flight. Tell Nam thanks for every first one." All end: "Left you my tab with Nam. — [Name]" | Native writer; same beats. |

**Copy rules.** The GDD ban stays ("abandoned / neglected / forgot") and
extends to "die / dead / death / kill / starve / sick". Warnings describe the
character ("is packing"), never the player ("you failed to…").

---

## 2. Mandatory care

### 2.1 The two rules

| Rule | Minimum | Clock | If broken |
|---|---|---|---|
| **A. Night Out** | One **qualifying visit** in any 7 real days | `since_night_out`: real time since the last qualifying visit ended | Decline starts at day 7 (§3) |
| **B. Every need touched** | No meter may stay **Empty** (below 10) for long | `empty_days`: per meter, continuous real time below 10. Resets when the meter reaches 10+. | Decline starts when a meter goes Empty; Gone after 14 days Empty |

**Qualifying visit (a "Night Out"):** at least 5 real minutes in the venue
(idle time excluded) **and** at least 2 refill actions from GDD §2.3. A tap in
and out doesn't count. A visit in progress also stops the clocks from reaching
Gone.

**One number drives the decline:**
`stake_days = max(since_night_out, longest_empty_days + 7)`.
A meter going Empty counts like a week away; each further Empty day adds a day.

**What that asks of a player, in practice:**

| Player | Stays at |
|---|---|
| 3 visits a week, GDD §2.3 sample visit | Fine, always |
| 1 sample visit a week | Fine after each visit, then Staying In for the last ~3 days before the next (meters dip below 10); never Fading. Welcome Back (Vibe < 25) fires most weeks. |
| 3 visits a week, never earns any Nightlife (no dancing, pinball, Lounge, full sets) | From creation (75): Nightlife Empty ~day 10.3 → Fading ~15.3 → Gone ~24.3, with venue warnings every visit (§3.2) |
| Nobody opens the app after creation (meters at 75) | Gone on day 21 |

Meter times assume `SOFT_FLOOR_FACTOR = 0.3` (DECISIONS; code still has 0.5,
§6). From 100, time to Empty: Drinks 8.1 d, Music 10.3 d, Friends 11.4 d,
Nightlife 12.7 d.

### 2.2 The clock

| Item | Rule |
|---|---|
| Elapsed time | Real UTC time, computed on load like the meters (no background process) |
| Day and week boundaries | Bangkok time (UTC+7), DECISIONS (f) |
| Notification quiet hours | Device-local after 22:00 (they protect the player's sleep; open question 3) |
| Trusted time | Server time when online. Gone needs trusted time (§7). |

### 2.3 A real visit to the real bar

Checking in at the real Black Cabin (staff-verified code or venue QR,
`04-coins` §7.5) **counts as a Night Out** and lifts every meter to at least
30. It is presence, not a purchase, so `04-coins` §7.1 (real spending never
refunds needs) holds. Once per Bangkok day; first time drops a "Was There"
polaroid. Post-FP.

### 2.4 Trips (Out of Town, extended)

| Rule | Value |
|---|---|
| **Out of Town** freezes all four meters **and both stake clocks** | up to 14 days per trip (existing) |
| Cooldown | 30 days from return (existing) |
| **Long Trip** (home for the holidays, Songkran, a work posting) | once per rolling 365 days, up to 35 days |
| Total trip days | max 70 per rolling 365 days |
| When it can start | Only at **Fine** or **Staying In**. Not from Fading or Packing: it's for planned time away, not an escape hatch. |
| Ending | Ends early on the first venue visit; ends automatically at the limit, and the clocks resume where they froze |
| On return | Welcome Back (GDD §2.5) on the first visit |
| Look | Suitcase by the door, postcards from the trip on the Memory Wall |

Server outages and declared maintenance freeze all stake clocks for everyone.

---

## 3. The decline

### 3.1 Stages

| Stage | `stake_days` | Character | The Flat | Notification (2 per week max) |
|---|---|---|---|---|
| **Fine** | 0–7 | As Vibe (GDD §2.2) | Normal | — |
| **Staying In** | 7–12 | Homebody look whatever the Vibe: pyjamas, all low-meter tells | Curtains drawn, record player off | Day 7: "[Name]'s been staying in. Nam asked after you." (budget) |
| **Fading** | 12–17 | Sits on the bed facing the window; 30% desaturation | Lamps dim one step; postcards pile up by the door | Day 12: "[Name] hasn't been out in a while." (budget) |
| **Packing** | 17–21 | Travel clothes; folds things into the suitcase | Open suitcase on the bed; one Memory Wall pin comes down each day; chip "Thinking of leaving · N days" | Day 17: "[Name] is packing." (budget) · **Day 19, Last Call:** "[Name] leaves Bangkok in 2 days. One night out changes their mind." (**exception**, see below) |
| **Gone** | 21+ | — | Empty flat, morning light, keys and the letter on the table | None. The player sees it when they next open the app. |

Stage notifications go out once per decline, 5 days apart, inside the
2-a-week budget. **Exception:** the Last Call warning is outside the budget,
once per decline, because it is the only message that prevents a permanent
loss. If it would land in quiet hours it goes out earlier, at 19:00 local.
With notifications off, the Flat chip and postcards are the warnings
(character creation says so). The Flat shows days, never a live countdown;
meters still never notify at 0.

### 3.2 What staff and regulars say

| Stage | Delivered by | Lines (EN; TH by native writer) |
|---|---|---|
| Staying In | Postcard from the regular with the most hearts | Ploy: "Third table's empty without you." |
| Fading | Postcard from Nam | "Your stool's still warm. Sort of." |
| Packing | Postcards from Nam and a second regular | Big: "Band's on Friday. Just saying." · Dougie: "Don't make me come round there." |
| **Rescued** (first visit from Staying In or later) | Nam at the bar (Welcome Back line), then a regular | Nam (from Packing): "Don't you dare. Sit. This one's on me." · Mali: "We kept your name on the board." |
| Rule B warning, in the venue (any visit while a meter is Empty) | The regular who feeds that meter (`03-cast` §3.1) | Jules: "You haven't touched the pinball in weeks." · Tong: "Front row's lonely." · Hiro: "Water again?" · Mali: "Sit with us." |
| Gone | Nam's postcard in the album | "They said thanks for every first one." |

**Rescue** is any qualifying visit before Gone. It resets `since_night_out` to
0 and triggers Welcome Back (×2 gains, 15 minutes). Rescue from Packing also
drops a one-time "Close Call" polaroid and puts the wall pins back up. Recovery
costs nothing more. The stakes are the ending, not a slow punishment.

---

## 4. What survives

| Thing | After Gone |
|---|---|
| **Memory Album** | **Kept**, all of it. The old character's memories become a chapter with their name and dates ("[Name] · Mar–Oct 2026"). Read-only. |
| Memory Wall | Reset. The first pin on the new wall is the farewell polaroid (the letter on the table). Frames owned are kept. |
| **Coins** | **Kept** ("Left you my tab with Nam"). `04-coins` §1: coins are never lost. |
| Wardrobe | **Kept**: every owned item stays on the rail and in the wardrobe. |
| Real-world vouchers, raffle entries | **Kept**. They belong to the verified account, not the character. |
| The Flat | Kept: same flat, new tenant ("It was going cheap"). Wall colour and swaps stay. |
| Character (name, look, personality) | **Lost** |
| Meters, Tab, Regular Rank, chalkboard rank | **Lost**. The new character starts as a Newcomer. |
| Hearts with regulars | **Lost**. Reset to 0. Story beats already seen stay in the album. |
| Minigame bests, stamp card | **Lost** (per character) |

**Do regulars remember?** The old character, yes; the new one is a stranger
at 0 hearts. A regular who had 2+ hearts says one line, once. Tong: "Someone
used to sit right there. You'd have liked them."

**Memorial in the venue:**

| Where | What |
|---|---|
| Collectibles shelf behind the bar | The old character's usual drink as a coaster with their name. Up to 3 on the shelf; older ones move into the album. |
| Regulars chalkboard | Their name stays, with a small paper-plane doodle |
| Nam | Tap the coaster: "[Name]. Always had the [drink]." |

**What the new character inherits:** wallet, wardrobe, frames, the Flat, the
album, the farewell polaroid. **Not inherited:** the starting wallet (20
coins), first-visit-ever coins, coins for memories already in the album, and
heart coins (`COIN_HEART`) for any heart at or below the account's best with
that regular.

---

## 5. GDD amendments

### 5.1 §2.5, rewritten

> **2.5 Full, empty and Last Call**
>
> **At 100:** unchanged (sparkle; overflow to Tab 1:1).
>
> **Below 10 (Empty):** the meter's tell is at full strength, the regular who
> feeds it mentions it each visit, and the meter's Empty clock runs. A
> character who stays away 7+ days, or leaves a meter Empty, starts to
> decline: Staying In, Fading, Packing. At 21 days they leave Bangkok for good;
> memories, coins and wardrobe stay with the player (06-stakes).
>
> **Welcome Back:** the first visit after Vibe has been below 25, after 7+
> days away, or rescuing a character from any decline stage: the bartender
> says hello by name, the first drink is free, all gains doubled for 15 minutes
> (diminishing returns still apply), 10 coins (04-coins). Rescuing from Packing
> also drops the Close Call polaroid. Copy may never say "abandoned /
> neglected / forgot / die / dead".

### 5.2 One-line amendments

| Where | Amendment |
|---|---|
| 01 Pillar 2 | "**Cozy, with real stakes.** Needs drain over days; a normal week costs nothing; three weeks without a night out and your character leaves Bangkok for good, memories kept." |
| 01 "Tamagotchi" row and hook | "Neglect makes your character a homebody, then makes them leave Bangkok (06-stakes)." |
| §2.1 Soft floor | "Below 30, decay ×0.3. The floor slows emptying; it does not stop it. Below 10 a meter is Empty (06-stakes §2)." |
| §2.1 Out of Town | "Freezes decay and the Last Call clocks for up to 14 days, once per 30 days; plus one Long Trip of up to 35 days a year; only from Fine or Staying In (06-stakes §2.4)." |
| §2.2 Homebody | "Also the look for the Staying In stage, whatever the Vibe." |
| §2.6 | "Last Call stage messages use the 2-a-week budget; the one Last Call warning (48 h before leaving) is outside it and moves earlier rather than into quiet hours." |
| §10.1 | "Rank never goes down while the character lives; a new character starts at Newcomer." |
| §10.2 | "The Last Call clock is the one hard deadline. It is never shown as a streak count." |
| §14 In | "Last Call stages, Gone and new-character flow, driven by the debug clock, with a debug 'jump to day N'." |
| §14 Out | "Last Call notification, real-bar check-in, Long Trip." |

---

## 6. Numbers for `rules.gd`

| Constant | Value | Note |
|---|---|---|
| `SOFT_FLOOR_FACTOR` | **0.3** | Code still 0.5; DECISIONS changed it. Every time in §2.1 depends on it. |
| `EMPTY_BELOW` | 10.0 | |
| `EMPTY_OFFSET_DAYS` | 7.0 | `stake_days = max(since_night_out, longest_empty + 7)` |
| `STAGE_THRESHOLDS` | `[["gone", 21.0], ["packing", 17.0], ["fading", 12.0], ["staying_in", 7.0], ["fine", 0.0]]` | Same shape as `VIBE_THRESHOLDS` |
| `NIGHT_OUT_MIN_MINUTES` / `NIGHT_OUT_MIN_ACTIONS` | 5.0 / 2 | Idle time excluded |
| `LAST_CALL_NOTIFY_HOURS_BEFORE` | 48.0 | Outside `NOTIFY_MAX_PER_WEEK` |
| `LAST_CALL_QUIET_FALLBACK_HOUR` | 19 | Local |
| `OUT_OF_TOWN_MAX_DAYS` / `OUT_OF_TOWN_COOLDOWN_DAYS` | 14.0 / 30.0 | Existing; now also freeze the stake clocks |
| `LONG_TRIP_MAX_DAYS` / `LONG_TRIPS_PER_YEAR` | 35.0 / 1 | |
| `TRIP_DAYS_PER_YEAR` | 70.0 | Rolling 365 days |
| `TRIP_ALLOWED_STAGES` | `["fine", "staying_in"]` | |
| `REAL_CHECKIN_METER_FLOOR` / `REAL_CHECKIN_PER_DAY` | 30.0 / 1 | Post-FP |
| `MEMORIAL_SHELF_MAX` | 3 | |
| `CLOCK_BACKWARD_TOLERANCE_MINUTES` | 10.0 | §7 |
| `UNTRUSTED_MAX_STAGE` | `"packing"` | Gone needs trusted time |
| `MOVE_ON_COOLDOWN_DAYS` | 30.0 | Voluntary restart, §7 |

### 6.1 Tests for the needs session

1. `stage_for(stake_days)` returns each stage at each boundary (6.99, 7.0, 11.99, 12.0, 16.99, 17.0, 20.99, 21.0).
2. `stake_days` is the max of the two clocks; an Empty meter alone gives Staying In at once.
3. A new character with no visits (meters 75) is Gone at exactly 21.0 days.
4. A visit under 5 minutes or with under 2 actions doesn't reset `since_night_out`.
5. A qualifying visit resets `since_night_out` but not `empty_days` unless the meter reaches 10.
6. A meter reaching 10 resets its Empty clock; dropping below 10 again restarts from 0.
7. 8 simulated weeks of the 3-visit sample player: always Fine.
8. 8 weeks of 1 sample visit per week: never past Staying In.
9. 3 visits a week with zero Nightlife gains, from a new character: Nightlife Empty at ~10.3 d, Gone at ~24.3 d (with the floor at 0.3).
10. Out of Town freezes meters and both clocks; it can't start in Fading or Packing; it auto-ends at 14 days; cooldown, Long Trip and 70-day yearly cap enforced.
11. A visit in progress blocks Gone; Gone is applied after the visit only if it doesn't qualify.
12. Gone is final: later saves, visits or clock changes never change the stage. `gone_at` is the threshold time, not the time the app was opened.
13. A backward clock jump beyond tolerance gives 0 elapsed (no un-decay, no un-decline).
14. Without trusted time, the stage caps at Packing.
15. Rescue from Staying In or later triggers Welcome Back; rescue from Packing drops Close Call once.
16. New character: coins and wardrobe carried, rank/hearts/Tab 0, album kept, no starting wallet, no heart coins at or below the account's best.
17. The Last Call notification is scheduled at Gone −48 h, once per decline, outside the budget, moved to 19:00 if in quiet hours; it's rescheduled on every save.

---

## 7. Abuse and edge cases

| Case | Rule |
|---|---|
| **Clock forward** (to fast-forward decay) | Only hurts the player. Gone needs server time, so a wrong device clock can't finalise a loss; offline, the stage caps at Packing. |
| **Clock backward** (to freeze) | Elapsed time is never negative; jumps back beyond 10 minutes count as 0 and are logged. Server reconciles on next sync. |
| **App uninstalled** | The clocks keep running. On reinstall the server account restores the living character or the letter. FP (local save): uninstall loses everything. |
| **Restoring an old save file** to undo Gone | FP: possible, accepted. With backend: the `gone_at` flag is server-side and wins. |
| **Multiple characters** | One living character per account. Multiple accounts can't share real rewards (verified phone, `04-coins` §7.3). |
| **Deliberate reset to farm gifts** | Nothing to farm: starting wallet once per account, no repeat memory coins, heart coins only above the account's best, voucher account age counts from the account. Gone takes 21 days anyway. |
| **Wanting a fresh start** | A voluntary **Move On** in settings, with two confirmations: same letter, same rules as Gone. Once per 30 days. |
| **Hospital, emergency, no phone** | Support can apply a retroactive trip once per year (open question 4). |
| **Notifications off** | In-app warnings only; creation and the Flat say so. |
| **Game outage** | All clocks freeze for the outage window. |
| **Player mid-visit at the threshold** | Can't go Gone while a visit is in progress. |

---

## 8. Open questions for the orchestrator

1. **Timeline:** 21 days to Gone and 14 Empty days, or tougher (14 / 10)? 21 suits a once-a-week player; shorter is more Tamagotchi.
2. **Rule B (every need touched):** keep it, or have only the Night Out clock count? It's what makes the "each need" mandatory, but it can end a character for a player who visits often.
3. **Quiet hours:** device-local (proposed) or Bangkok, given DECISIONS (f) "Bangkok wins everywhere"?
4. **Support-applied retroactive trip** for emergencies: allow (once a year), or is no exception the point?
5. **Coins and wardrobe surviving:** confirm. It follows `04-coins` §1 but makes the loss lighter. The alternative keeps coins and drops wardrobe.
6. **Real-bar check-in as a Night Out:** confirm, and does it need a backend from launch or only post-FP?
7. **Last Call by email or LINE** when push is off or the app is uninstalled? It would need consent at sign-up.
8. **The letter's reasons:** fixed per personality (proposed) or written by the player at creation as their "someday" plan?
9. **`SOFT_FLOOR_FACTOR` 0.3:** the code still has 0.5. This chapter's timings assume 0.3; the needs session should change it along with the stakes code.
