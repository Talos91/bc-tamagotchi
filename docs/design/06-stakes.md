# Black Cabin Tamagotchi — Stakes

Status: draft v2 (2026-11-02), rewritten from Daniele's base proposal
(DECISIONS 2026-11-02 "Stakes"). Replaces draft v1 ("Last Call", 2026-10-28)
entirely. Reads: `DECISIONS.md`, `01-high-concept.md`, `02-gdd.md` §2, §7.3,
§10, `04-coins.md`, `04-coins-summary.md`, `game/scripts/rules.gd`,
`game/scripts/needs.gd`. Also holds **the Flat** (§9), because renting the
room changes where the character lives, where the game starts and what death
takes away; the rent numbers are echoed in `04-coins-summary.md`.

**Every number here is provisional, for Daniele to tune.** Open calls are
listed in §13 with their IDs (S1…S12); the orchestrator puts them on the
Questions tab.

---

## 1. Goal, tone, one paragraph

**Players grow attached to their character, so losing them must mean
something.** Only one thing is mandatory: **go to Black Cabin**. Skip it for
two weeks and your character dies. For one more week a friend can bring them
back (a zombie act on stage). After that they are deleted: the character,
their coins, wardrobe, memories, achievements and leaderboard rows. The next
game starts from scratch. Everything else a character needs (a drink, music,
a chat, a memory, a minigame, a look at the event calendar) only brings
**minor annoyances** when neglected: visible, a little funny, cleared within
the same visit by doing the thing. Daniele: *"This is not an everyday job;
keep it light but give people a reason to open it."* A once-a-week player
should never be in danger and should rarely be annoyed.

**Tone: playful ghost story, not tragedy.** Daniele's own example is a zombie
act, so the fiction is a wink, 21+ bar humour: the character "dies" of
boredom, haunts their usual spot as a voxel ghost, and can be raised by
friends on stage. This drops v1's "left Bangkok" fiction and its ban on the
words "die / dead" (call S6). Copy still never blames the player: warnings
describe the character ("[Name] is getting restless"), never "you neglected".

| v1 (2026-10-28) | v2 (this chapter) |
|---|---|
| Two fatal rules: no Night Out in 7 days *and* any meter Empty 14 days | One fatal rule: no visit in 14 days |
| Gone at 21 days, no revive ever | Dies at 14, friend revival window 7 days, deleted at 21 |
| Album, coins, wardrobe, Flat survive | Total: everything in-game goes (§6) |
| Meters could kill | Meters only annoy (§7) |
| Long Trip, retroactive support trip | Dropped; Out of Town as built is the only pause |

---

## 2. The seven needs and where they live

Daniele's list, mapped onto what is built. The four meters in `rules.gd` stay;
two light **habits** (timestamps, not meters) are added; the visit clock is
the only thing that kills (call S8).

| Need (Daniele) | Lives in | Filled by (as built, `rules.gd` ACTIONS) | If neglected |
|---|---|---|---|
| **Go to Black Cabin** | **Visit clock** `days_since_visit` (new) | A counting visit (§3) | **Fatal** (§4–§6) |
| Drink | Drinks meter | `order_drink`, `pour_perfect`, `try_new_drink` | Thirsty (§7) |
| Listen to music | Music meter | `listen_song`, `finish_set`, `front_row_rhythm`, `applaud`, `headline_set` | Earworm |
| Have a chat | Friends meter | `candle_talk`, `sit_with`, `bar_chat`, `social_verb`, `quiz_night` | Phone face |
| Play a minigame | Nightlife meter (now also "play") | `pinball`, `dance_off`, `dance_30s`, `enter_lounge`, `last_song`, **new `minigame_played`** | Rusty |
| Do a memory | **Memory habit** `last_memory_at` (new) | Any new memory drop in a visit; a photo shared at the lounge TV corner (BACKLOG D5) | Faded pins |
| Check the event calendar | **Calendar habit** `last_calendar_at` (new) | Opening the events calendar (BACKLOG D1, real data in `docs/venue/events/`), from home or the venue | Out of the loop |

**Why Nightlife carries "play a minigame":** its sources are already pinball,
dance-off and dancing. One new action, `minigame_played` (+3 Nightlife on
finishing any minigame, capped +9 per visit), makes Pour Perfect, Front Row
Rhythm and Candle Talk count too, so "play a minigame" is honest without a
fifth meter or a HUD change.

---

## 3. The visit: what counts

**A visit counts** once the character has spent **3 real minutes inside the
club in one visit**. Inside the club = any zone past the Sticker door (old
corridor, lounge, buffer, main room, smoking room, stair), or arriving
downstairs from the Flat (§9). Minigame time counts; time with the app in
the background does not; the existing 10-minute idle rule (`VISIT_IDLE_SECONDS`)
still ends a visit. No action is required: walking in and sitting with the
band is enough. Standing at the street door is not a visit (call S5).

| Rule | Value |
|---|---|
| Counting threshold | 3 active minutes past the Sticker door (`VISIT_COUNT_MINUTES`) |
| Effect | `last_counted_visit` = the moment it qualifies; `days_since_visit` = 0 |
| A visit in progress | Blocks death; if the clock passes 14 days mid-visit, the visit qualifies first |
| Real bar check-in (post-backend) | A staff-verified check-in at the real Black Cabin counts as a visit, once per Bangkok day (BACKLOG D4, `04-coins` §7) |
| Clock | Real time, computed on load like the meters (no background process); day boundaries in Bangkok time (DECISIONS (f)) |
| Out of Town (built: 14 days, once per 30 days) | Also freezes the visit clock. Can't start once the character is Restless (day 7+): it's for planned time away, not an escape hatch |
| Server outage (post-backend) | Freezes the visit clock for everyone |

Two weeks plus Out of Town means a player can be away up to 28 days without
losing anyone, once a month. v1's Long Trip and support-applied trips are
dropped to keep it light (call S10).

---

## 4. Warnings and the fatal timer

Clock: `days_since_visit` (Out of Town days excluded). Death at **14.0 days**
(call S1).

| Day | Stage | Character | Home (Flat, or the front door if no Flat) | Notification |
|---|---|---|---|---|
| 0–7 | **Fine** | As Vibe (GDD §2.2) | Normal | — |
| 7 | **Restless** | Homebody look whatever the Vibe; paces | Curtains drawn; a regular's postcard ("Third table's empty without you." — Ploy) | "[Name] is getting restless. The band's on tonight." (in the 2-a-week budget) |
| 10 | **Fading** | Greyed 30 %, slumped on the bed / the kerb | Lamps dim; postcards pile by the door; chip "Fading · 4 days" | "[Name] hasn't been out in 10 days." (budget) |
| 12 | **Last Call** | Translucent at the edges | Chip "Last Call · 2 days"; Nam's postcard: "Don't make me come round there." | **"[Name] has 2 days left. One night out saves them."** (outside the budget, once per decline) |
| 14 | **Dead → Ghost** | A voxel ghost of the character, same outfit, floating | Ghost in the home view; a tombstone sticker on the club door | **"[Name] died of boredom. A friend can still bring them back: 7 days."** (outside the budget) |
| 19 | Ghost | Ghost flickers | Chip "2 days to bring [Name] back" | "2 days left to bring [Name] back." (budget) |
| 21 | **Deleted** | — | Start from scratch (§6) | None; the player sees the farewell card next time they open the app |

- Days are shown, never a live countdown. Only two notifications sit outside
  the 2-a-week budget (Last Call and the death notice), each once per decline.
  If one would fall in quiet hours (after 22:00 local, GDD §2.6) it goes out
  at 19:00 local the same day instead.
- With notifications off, the home chip and postcards are the warnings;
  character creation says so in one line.
- **Rescue** = any counting visit before day 14. It resets the clock, triggers
  Welcome Back (GDD §2.5, already built), and from Last Call drops a one-time
  "Close Call" polaroid. Nothing else is owed.

**What it asks in practice** (simulated with the built decay, soft floor 0.3
and the GDD §2.3 sample visit; method in the design handoff):

| Player | Danger | Annoyances on arrival (§7) |
|---|---|---|
| 2–3 visits a week | Never | None |
| 1 visit a week | Never past Fine | Thirsty only (the free first drink clears it in seconds) |
| 1 visit every 10–13 days | Restless/Fading warnings, never dead | All four meter annoyances, most visits |
| Opens the app after creation, never visits | Dead day 14, deleted day 21 | — |

---

## 5. Death, the revival window, revival

### 5.1 The window

At day 14 the character dies and becomes a **ghost** for **7 days** (call
S2). Meters, coins and everything else freeze where they were. The ghost
can't refill needs, earn or spend. The Flat's rent is paused (§9).

### 5.2 Single-player now: the regulars do the zombie act

Multiplayer is wave 4 and not started, so until then **the regulars are the
friends** (call S3):

1. **Who can do it:** any NPC regular at **2+ hearts** at the moment of death
   (FP hearts are 0–3, DECISIONS (n)). If none, nobody comes: the window still
   runs, but in single-player the ghost fades at day 21. Friendships are the
   insurance; that is the attachment payoff.
2. **What the player does:** open the app during the window. The home view
   shows the ghost and the regular's note ("Tonight. Front row. Bring
   yourself."). Tap → the ghost drifts in through the door (no meters, no
   bar). The stage is set for **"Night of the Living [Name]"**: the regular
   and the House Lights play a zombie shuffle; the player plays one round of
   the Front Row Rhythm engine on that song (60 s, one thumb). Any finished
   round revives; as everywhere, low skill earns the minimum, never a fail.
3. **Limit:** once per **90 days** per character, counted from the last
   revival (call S4). Within 90 days the regular says "Not twice in one
   season, darling" and the window runs out normally.

### 5.3 Multiplayer later: a real friend

| Rule | Value |
|---|---|
| Who | Any player on your friends list (wave 4) |
| What | In their own game, during your window, they put on the zombie act for you at the stage (same 60 s round); you're revived the next time you open the app |
| Their reward | A "Raised [Name]" polaroid and a door sticker. No coins (keeps it from being farmed) |
| Limit | One revival per character per 30 days, any route; the NPC route stays at 90 days |
| Real bar (post-backend) | A staff-verified check-in at the real Black Cabin during the window revives too ("Come to the bar and we'll bring you back"); same 30-day limit |

### 5.4 Coming back

The revived character returns **as a zombie for the rest of that visit**
(green-grey tint, stiff-arm walk, a groan on idle; cosmetic only), then is
normal. Each meter is lifted to at least 40, the visit clock is 0, Welcome
Back fires. They keep everything. A "Back From the Dead" sticker goes on the
club door and a stitched-scar accessory unlocks in the wardrobe (optional to
wear). The character card shows "Lives: 2". Revival is a story the player
tells, not a punishment.

---

## 6. Deletion: total

At day 21 (or immediately on a voluntary Retire, §11) the character is
deleted. Daniele: "the character is deleted from the game, including
leaderboard positions and achievements; a new game starts from scratch."

| Goes | Stays (call S7) |
|---|---|
| Character: name, look, personality, age, lives | The account: sign-in, settings, notification consent |
| Meters, Tab, Regular Rank, chalkboard name | Real-world vouchers **already claimed** stay valid until they expire (they are a promise Black Cabin made to a person); an unredeemed voucher that expires does **not** refund coins, since there is no wallet to refund to |
| Coins, wardrobe, frames, the Flat lease (§9) | A **farewell card** the player can save or share before it goes (the last Memory Wall photo, name, "Nights out: 23 · 3 Oct – 6 Nov"); the game keeps no copy |
| Hearts with regulars (they start as strangers) | Anti-abuse flags at account level, invisible: account age for real rewards, the monthly real-reward limits (`04-coins` §7.3) |
| Memories, album, Memory Wall, photos shared at the TV corner | |
| Achievements (the door stickers, BACKLOG B4), minigame bests, stamp card | |
| Leaderboard rows (server-side delete, BACKLOG B6) | |

This overrules DECISIONS 2026-10-28 ("its memories stay in the album") and
`04-coins` §1 ("coins are never lost"); `04-coins` is amended to "never lost
while the character lives". A new game is fully new: starting wallet,
first-visit gifts and creation, as for a first-time player. Deliberate death
can't be farmed: it takes 21 days and leaves nothing behind.

---

## 7. Minor annoyances

Each one is triggered on arrival or on the home view, is visible and a little
funny, is cleared **in the same visit** by doing the thing, and never blocks a
need, lowers a gain or costs coins (call S9). Meter annoyances start when the
meter is **Empty (below 10)**, the GDD's existing word for it; habit
annoyances by days.

| Need | Trigger | Annoyance | Cleared by |
|---|---|---|---|
| Drink | Drinks < 10 | **Thirsty:** walks 20 % slower in the venue; at home the fridge door hangs open | Any drink (water counts) |
| Music | Music < 10 | **Earworm:** hums one off-key loop; the club's music is ducked under the hum (−6 dB) | Hearing one song |
| Chat | Friends < 10 | **Phone face:** scrolls their phone on idle; regulars don't wave you over; the first chat prompt asks "Put the phone away?" (one extra tap) | Any chat (Candle Talk, sitting at a table, bar chat) |
| Minigame | Nightlife < 10 | **Rusty:** the first minigame opens with a 2-second fumble (drops the shaker, misses the plunger); score unaffected | Finishing any minigame |
| Memory | No new memory for 14 days | **Faded pins:** one photo on the Memory Wall (no Flat: the album cover) bleaches blank each week | Any new memory, or a photo shared at the TV corner; every blank pin returns |
| Calendar | Calendar not opened for 7 days | **Out of the loop:** the venue's Tonight board shows "?"; a regular mentions an event you missed ("You missed Moderndog!") | Opening the calendar |

**The reason to open the app** (Daniele's ask) is the calendar: a 10-second
check-in from home shows tonight's real event, and tapping **Going** on a
night gives a small bonus if you then visit the game that night (+10 Music on
arrival and an "I was there" ticket stub; at the real bar, later, a check-in
on that night). No coins for opening the app, no streaks (GDD §10.2).

Times to Empty with the built decay (soft floor 0.3): Drinks 8.1 days from
100, Music ~10, Friends ~11, Nightlife ~13; from the start value 75 about two
days less. Hence the table in §4: weekly players meet only Thirsty.

---

## 8. Why players get attached

Death only works if there is something to lose. What builds it, all from
systems already planned:

| Lever | Detail |
|---|---|
| Age | The character card shows "At Black Cabin since 3 Oct · 23 nights out · Lives 1" |
| Door stickers (BACKLOG B4) | Achievements live on the club's entry door; seen on every arrival and exit; all gone on deletion |
| The usual | After 3 orders of the same drink, Nam starts it when you sit at the bar ("The usual?") |
| Regulars remember | Hearts, postcards, names; the regular who would revive you is the one you talk to |
| Home | The Flat (§9): your room, your wall, your clothes on the rail |
| Lives and scars | Revival leaves a mark (§5.4): a character who came back is a better story |

---

## 9. The Flat: a rented room upstairs

(Here rather than in `04-coins.md` because it changes where the character
lives and what death takes; `04-coins-summary.md` carries the rent line.)

**Now:** the Flat stays minimal (DECISIONS 2026-11-02): the home is today's
stand-in (walk-out card, GO OUT; the front-door start screen on launch).
**Later, as an unlock:** with in-game coins you **rent a room on the second
floor**, an instanced area, and the game then starts there.

| Item | Value (provisional, call S11) |
|---|---|
| Unlock | Coins only; offered once the wallet first reaches the move-in fee (a note under the door: "Room going upstairs. Ask Nam.") |
| Move-in fee | **100 coins**, once (non-refundable "key money"); about 1–2 weeks of a 3-visit player's savings, about a month for a once-a-week player |
| Rent | **20 coins a week**, taken automatically on Monday 00:00 Bangkok with the Week Recap. A once-a-week player can just hold it (they save ~25 a week); a 3-visit player keeps ~60 a week after rent (`04-coins-summary.md`) |
| Pay ahead | Up to 4 weeks prepaid |
| Paused | While Out of Town, and while the character is a ghost (§5) |
| What you get | The room (GDD §7.3): bed, record player, window onto the street, the **Memory Wall** (12 pins), the wardrobe rail at home, the **event calendar** on the wall. Wall colour and 4 furniture swaps as GDD §7.3; no building. The game starts here; the character sleeps here between visits |
| What it never gives | Slower decay, extra gains, protection from the visit clock. Coins never buy relief from needs (`04-coins` §1) |

**Where it meets the club** (layout frozen; no change to `layout.json`):
the stair in the lounge (south-wall flight from the game cabinet, landing,
west-wall flight north) ends at the velvet rope (`build_venue.gd`
`STAIR_STOP_Z` 10.05) under the dark bulkhead of the closed upper floor
(captures `docs/art/screens/v4/portrait-stair-top.png`, `…-stair-eye.png`).

| Moment | What happens |
|---|---|
| Non-tenant at the rope | As now: rope closed, prompt "Rooms upstairs · tenants only" |
| Tenant at the rope | Nam's helper unhooks the rope; the character climbs into the bulkhead; fade; the Flat scene loads (its own scene, not in `layout.json`) |
| Launching the game as a tenant | Opens in the Flat (the check-in view, GDD §1.1), not at the street door |
| Going out | Tap the Flat door → fade → the character appears on the upper flight just below the rope and walks down into the lounge; that is the arrival (the visit clock counts from here, §3) |
| Leaving the club | Walking up past the rope ends the visit and goes home; the street door also works and lands at home with the exit shot |
| Instanced | Each tenant has their own room behind the same rope. Multiplayer later: invite-only visits; other players see you climb the stair and disappear |

**If rent lapses:** coins never go negative, so a Monday with too few coins
starts a **7-day grace**: a note under the door ("Rent's late. — the
landlady"), the room still works. If still unpaid at the end of the grace,
the character moves out: the game starts at the street door again, frames
and the wall's pins go into storage (kept, not lost), the rope closes again.
Re-renting within 30 days skips the move-in fee; after that it is paid again
(call S12). A lapse never touches the visit clock or the character.

**On death:** rent pauses through the ghost window; a revived character goes
home to the same room; on deletion the lease ends with everything else.

---

## 10. Mapping onto `rules.gd` and `needs.gd`

**Stays as built:** the four meters, `START_VALUE` 75, `DECAY_PER_HOUR`,
soft floor (30, ×0.3), personality ×0.9, Vibe thresholds, diminishing
returns, daily multiplier, Welcome Back (×2 replacing the daily multiplier,
15 min), Out of Town 14 / 30 days, every existing action and value, the
notification budget of 2 a week and quiet hours after 22:00.

**Changes:**

| Where | Change |
|---|---|
| Meters | No longer fatal in any way (v1 Rule B is never built). Below 10 they trigger an annoyance (§7) |
| Out of Town | Also freezes the visit clock; can't start from Restless onward |
| Welcome Back | Also fires on a rescue (any counting visit from Restless onward) and on revival |
| `rules.gd` comment on `START_VALUE` | Says "Gone at 21.0 days"; now "dead at 14.0, deleted at 21.0 with no visit" |
| GDD §2.5 / §2.1 / §2.6 / §10 text | Still describe v1 (Last Call clocks, Long Trip, "Fine or Staying In"); amendments in §12 |

**New constants (provisional):**

| Constant | Value |
|---|---|
| `VISIT_COUNT_MINUTES` | 3.0 (active, past the Sticker door) |
| `FATAL_DAYS` | 14.0 |
| `STAKE_STAGES` | `[["last_call", 12.0], ["fading", 10.0], ["restless", 7.0], ["fine", 0.0]]` (same shape as `VIBE_THRESHOLDS`) |
| `REVIVAL_WINDOW_DAYS` | 7.0 |
| `REVIVE_NPC_MIN_HEARTS` / `REVIVE_NPC_COOLDOWN_DAYS` | 2 / 90.0 |
| `REVIVE_FRIEND_COOLDOWN_DAYS` | 30.0 (wave 4) |
| `REVIVE_METER_FLOOR` | 40.0 |
| `STAKE_NOTIFY_OUTSIDE_BUDGET` | `["last_call", "dead"]`, fallback hour 19 local |
| `ANNOY_EMPTY_BELOW` | 10.0 |
| `THIRSTY_WALK_MULT` / `EARWORM_DUCK_DB` / `RUSTY_FUMBLE_SECONDS` | 0.8 / −6.0 / 2.0 |
| `MEMORY_HABIT_DAYS` / `CALENDAR_HABIT_DAYS` | 14.0 / 7.0 |
| `GOING_BONUS_MUSIC` | 10.0 (on arrival, the night you marked Going) |
| `ACTIONS["minigame_played"]` | `{"gains": {"nightlife": 3.0}, "cap_per_visit": 9.0}` |
| `FLAT_MOVE_IN` / `FLAT_RENT_WEEK` / `FLAT_PREPAY_WEEKS` | 100 / 20 / 4 |
| `FLAT_GRACE_DAYS` / `FLAT_REJOIN_FREE_DAYS` | 7.0 / 30.0 |
| `RETIRE_COOLDOWN_DAYS` | 7.0 (§11) |

**New save fields** (`needs.gd` / `save.gd`, additive so old saves load):
`last_counted_visit`, `stake_stage`, `dead_at`, `last_revival_at`, `lives`,
`last_memory_at`, `last_calendar_at`, `going` (list of event dates),
`flat` (`{rented, paid_until, grace_until, storage}`).

### 10.1 Tests for the needs worker

1. `stake_stage(days)` at 6.99, 7.0, 9.99, 10.0, 11.99, 12.0, 13.99, 14.0.
2. A new character with no visits is dead at exactly 14.0 days and deleted at 21.0.
3. A visit under 3 active minutes, or only at the street door, doesn't reset the clock; one at 3:00 does, at the moment it qualifies.
4. A visit in progress at 14.0 days blocks death; it dies only if the visit ends without qualifying.
5. Out of Town freezes the visit clock; it can't start at day 7+.
6. Meters at 0 for 30 days with a visit every 13 days: never dead.
7. 12 simulated weeks of one GDD §2.3 sample visit a week: stage always Fine; only Thirsty on arrival.
8. Revival: needs a regular at 2+ hearts at death; works once per 90 days; meters floored at 40; Welcome Back fires; `lives` +1.
9. Deletion wipes every character field (coins, wardrobe, album, hearts, bests, flat) and keeps account settings and claimed vouchers.
10. Each annoyance turns on at its trigger and clears on the named action in the same visit; none changes a gain.
11. `minigame_played` adds +3 Nightlife per finished minigame, capped +9 per visit.
12. Rent: charged Monday 00:00 Bangkok; paused while Out of Town or a ghost; short wallet → 7-day grace → moved out with storage kept; re-rent within 30 days free of the move-in fee; coins never negative.
13. A backward device clock never un-decays or un-kills (elapsed is never negative, as `sync()` does today).

---

## 11. Edge cases

| Case | Rule |
|---|---|
| Clock set forward | Only hurts the player. With a backend, death and deletion need server time; offline, the stage caps at Last Call |
| Clock set backward | Elapsed is never negative (built in `sync()`) |
| Restoring an old save to undo death | First playable (local save): possible, accepted. With the backend, the server's `dead_at` wins |
| Uninstall | Local save: everything is lost. With accounts: the clock keeps running server-side |
| Wanting a fresh start | **Retire [Name]** in settings: two confirmations, the farewell card, immediate deletion, no ghost window. Once per 7 days |
| Notifications off | In-app warnings only; creation and the home chip say so |
| Death during a minigame or set | Can't happen: a visit in progress blocks it |
| One character per account | Yes; the next one starts after deletion |

---

## 12. Amendments to other docs (for a housekeeping pass; not applied here)

| Doc | Amendment |
|---|---|
| `01` Pillar 2 and the Tamagotchi rows | "Cozy, with real stakes: skip Black Cabin for two weeks and your character dies; a friend has a week to bring them back, then they're gone for good, with everything they had." |
| `02` §2.1 Out of Town | "Freezes decay and the visit clock for up to 14 days, once per 30 days; can't start from Restless (06-stakes §3)." Drop Long Trip. |
| `02` §2.1 Soft floor | "…Below 10 a meter is Empty and its annoyance shows (06-stakes §7)." |
| `02` §2.5 | Replace "Last Call" text with §4–§7 here in four lines; keep Welcome Back, add "also on rescue and revival". |
| `02` §2.6 | "Two stake messages (Last Call, death notice) sit outside the budget." |
| `02` §7.3 The Flat | "Minimal home now; later a rented room upstairs (06-stakes §9)." |
| `02` §10.1, §10.2 | "Rank never goes down while the character lives; deletion resets everything." "The visit clock is the one hard deadline; never shown as a streak." |
| `02` §14 | In: stake stages, ghost, NPC revival, deletion, annoyances, debug "jump to day N". Out: friend revival, real-bar check-in, Flat rent. |
| `DECISIONS.md` | The orchestrator records the answers to §13. |

---

## 13. Calls for Daniele

Sent to the orchestrator for the Questions tab; full wording, options and
recommendation in the design handoff (`handoffs/stakes-design-2026-11-02.md`).

| ID | Call | Section |
|---|---|---|
| S1 | Fatal timer: 10 / **14** / 21 days without a visit | §4 |
| S2 | Revival window: 3 / **7** / 14 days | §5.1 |
| S3 | Single-player revival before multiplayer: **regulars at 2+ hearts** / none until multiplayer / real-bar check-in only | §5.2 |
| S4 | Revival limit: **once per 90 days** / once per life / no limit | §5.2–5.3 |
| S5 | What counts as a visit: **3 minutes past the Sticker door** / any one refill action / just opening the game at the door | §3 |
| S6 | Tone: **playful ghost and zombie** / v1 "left Bangkok" / plain game over | §1 |
| S7 | What survives deletion: **nothing in-game; claimed vouchers and a farewell card** / absolutely nothing / the album too | §6 |
| S8 | Seven needs: **four meters + two habits, minigames feed Nightlife** / six meters / four meters, memory and calendar only nudges | §2 |
| S9 | Annoyances: **cosmetic + tiny friction** / cosmetic only / stronger (coin or gain penalty) | §7 |
| S10 | Pauses: **Out of Town as built only** / also v1's yearly Long Trip / no pause at all | §3 |
| S11 | Flat price: 60 + 15 a week / **100 + 20 a week** / 200 + 40 a week | §9 |
| S12 | Rent lapse: **7-day grace, then moved out, storage kept** / moved out at once / prepaid only, can't lapse | §9 |
