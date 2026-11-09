# Black Cabin Tamagotchi — Stakes

Status: **v3 (2026-11-02), Daniele's answers folded in.** v2 put fifteen
calls on the Questions tab; all are answered (DECISIONS 2026-11-02: "Stakes,
Flat and drink coins", "Questions tab, answered 2026-11-01 20:37–22:14" for
S13 and C1, "Lounge revamp answers" for the merch shop). Where an answer
differed from v2's recommendation, the answer is the rule here; the record of
which is which is §13. Reads: `DECISIONS.md`, `01-high-concept.md`,
`02-gdd.md` §2, §7.3, §9, §10, `04-coins.md`, `04-coins-summary.md`,
`game/scripts/rules.gd`, `game/scripts/needs.gd`. Also holds **the Flat**
(§9), because renting the room changes where the character lives and what
death takes away.

**§10 is the build spec** for the needs worker. Numbers Daniele set are
marked "Daniele"; every other number is a starting value, tunable without a
design change. Anything that needs the backend (Supabase) is marked
**[server]**: until it exists, the game runs on the stand-ins named next to
it.

---

## 1. Goal, tone, one paragraph

**Players grow attached to their character, so losing them must mean
something.** One need is fatal: **go to Black Cabin**, the real one. A
character whose player hasn't been to the bar in **21 days** dies and becomes
a ghost; a check-in at the real bar within the next **14 days** brings them
back; at **day 35** they are deleted with everything they had, and the next
game starts from scratch. Every other need (a drink, music, a chat, a
minigame, a look at the event calendar) only brings **annoyances**: stronger
than a joke, cleared within the same visit by doing the thing. Daniele:
*"This is not an everyday job; keep it light but give people a reason to
open it."*

Until the server can see real visits, an in-game visit stands in for one
(§3), so the first playable keeps the same clock with in-game play behind it.

**Tone: playful ghost and zombie** (S6). The fiction is a 21+ bar wink: the
character "dies of boredom", haunts the club as a voxel ghost, and comes back
from a check-in as a zombie for a night. Copy describes the character
("[Name] is getting restless"), never the player ("you neglected").

| v2 (proposed) | v3 (decided) |
|---|---|
| Fatal after 14 days without an in-game visit of 3 minutes | Fatal after **21 days** without a **real visit** (QR check-in or a memory taken at the bar); any in-game refill stands in until the server exists |
| Ghost window 7 days, deleted at 21 | Ghost window **14 days**, deleted at **35** |
| A regular at 2+ hearts stages a zombie act on stage | **Only a check-in at the real bar** revives; no NPC revival |
| Memory and calendar both minor habits | A memory taken at the bar is part of the fatal need; the calendar is the one minor habit |
| Cosmetic annoyances with tiny friction | **Stronger** annoyances that cost gains; minigames can be **missed** and have **limited tries** |

---

## 2. The needs and where they live

Daniele's list, mapped onto what is built (S8, S13): **four meters + two
habits**. The meters stay as built in `rules.gd`; the habits are timestamps,
not meters, so the HUD doesn't change. Daniele on S8: *"memory at black cabin
and … check in in black cabin (using black cabin qr codes we ll put on
tables) are one of the needs and are the needs that if not fulfilled is
death; checking calendar is one of the minor needs"*.

| Need (Daniele) | Lives in | Filled by | If neglected |
|---|---|---|---|
| **Go to Black Cabin** | **Visit habit** `last_counted_visit` | A real visit: a QR check-in at a table, **or a memory taken at the bar** [server]. Until then, any in-game refill (§3) | **Fatal** (§4–§6) |
| Drink | Drinks meter | `order_drink`, `pour_perfect`, `try_new_drink` | Thirsty (§7) |
| Listen to music | Music meter | `listen_song`, `finish_set`, `front_row_rhythm`, `applaud`, `headline_set` | Earworm |
| Have a chat | Friends meter | `candle_talk`, `sit_with`, `bar_chat`, `social_verb`, `quiz_night`, `light_one_up` | Phone face |
| Play a minigame | Nightlife meter | `pinball`, `dance_off`, `dance_30s`, `enter_lounge`, `last_song`, **new `minigame_played`** | Rusty |
| Check the event calendar | **Calendar habit** `last_calendar_at` | Opening the events calendar (BACKLOG D1; real data in `docs/venue/events/`) | Out of the loop |

**Minigames also feed Nightlife** (S8): the new action `minigame_played` (+3
Nightlife on finishing any minigame without a miss, capped +9 per visit) makes
Pour Perfect, Front Row Rhythm and Candle Talk count as "play a minigame"
without a fifth meter.

**The memory need is the real one.** "Do a memory" means a photo taken at the
real Black Cabin and shared at the lounge TV corner (BACKLOG D5, DECISIONS
"Memories at the lounge TV"); it counts as a real visit. In-game memory drops
(polaroids, coasters) stay the collection layer (GDD §8) and are no longer a
need of their own; v2's "Faded pins" annoyance is dropped.

---

## 3. The visit: what counts

**The rule (S13):** only a **real visit** resets the fatal clock. Daniele:
*"since to check in you need to visit black cabin 1 and 3 are same"*.

| Real visit [server] | Counts when |
|---|---|
| **QR check-in** | The player scans a Black Cabin table QR code while the bar is open (Tue–Sun 19:00–02:00 Bangkok); the server verifies the code and the night. One per bar night; a check-in after midnight belongs to the night it started on |
| **Memory taken at the bar** | A photo shared at the lounge TV corner that the server accepts as taken at Black Cabin that night (how it tells is the real-world bridge chapter's call, §13 open call O3) |

The same check-ins rank the **Top patrons** board (monthly, DECISIONS
"Lounge revamp answers") and revive a ghost (§5).

**The stand-in, until the server exists (S5):** any one **refill action** in
the game counts: a drink, a chat, a song, a minigame finished without a miss,
any action `apply_action` accepts. It counts the moment it lands; there is no
minimum time. Standing at the street door and walking around don't count.

| Rule | Value |
|---|---|
| Effect | `last_counted_visit` = the moment it counts; the stake stage drops to Fine |
| A visit in progress | Can't die mid-visit: if the clock reaches 21 days during a visit, death waits until the visit ends (the first refill will have reset it anyway) |
| Clock | Real time, computed on load like the meters (no background process); day boundaries in Bangkok time (DECISIONS (f)) |
| **Switching to real visits** [server] | One flag, `REAL_VISIT_REQUIRED`, false now. When the server ships it turns on: in-game actions stop resetting the clock, and every living character's clock restarts at the switch so no one dies of the change; a one-time card explains the new rule |
| Out of Town (built: 14 days, once per 30) | Freezes the visit clock too. Can't start once Restless (day 10+): it is for planned time away, not an escape hatch (S10) |
| Server outage [server] | Freezes the visit clock for everyone |

**The only pause is Out of Town, as built** (S10). With it a player can be
away up to 35 days once a month without losing anyone.

---

## 4. Warnings and the fatal timer

Clock: `days_since_visit` = real days since `last_counted_visit`, Out of Town
days excluded. **Death at 21.0 days** (S1, Daniele's).

| Day | Stage | Character | Home (the Flat, or the street-door start screen while the Flat is minimal) | Notification |
|---|---|---|---|---|
| 0–10 | **Fine** | As Vibe (GDD §2.2) | Normal | — |
| 10 | **Restless** | Homebody look whatever the Vibe; paces | Chip "Restless"; a regular's postcard ("Third table's empty without you." — Ploy) | "[Name] is getting restless. The band's on tonight." (in the 2-a-week budget) |
| 15 | **Fading** | Greyed 30 %, slumped on the kerb (on the bed, in the Flat) | Chip "Fading · 6 days"; lamps dim; postcards pile by the door | "[Name] hasn't been out in two weeks." (budget) |
| 18 | **Last Call** | Translucent at the edges | Chip "Last Call · 3 days"; Nam's postcard: "Don't make me come round there." | **"[Name] has 3 days left. One night at Black Cabin saves them."** (outside the budget) |
| 21 | **Dead → Ghost** | A voxel ghost of the character, same outfit, floating | Ghost at the door; a tombstone sticker on the club door | **"[Name] died of boredom. Check in at Black Cabin within 14 days to bring them back."** (outside the budget) |
| 28 | Ghost | Ghost flickers | Chip "Ghost · 7 days to bring [Name] back" | "A week left to bring [Name] back." (budget) |
| 33 | Ghost | Ghost barely there | Chip "Ghost · 2 days" | **"2 days left to bring [Name] back."** (outside the budget) |
| 35 | **Deleted** | — | The farewell card, then a new game (§6) | None; the player sees the farewell card the next time they open the app |

**Why 10 / 15 / 18** (v2 had 7 / 10 / 12 on a 14-day timer): Restless at 10
means a weekly player, and a bar regular who comes every second week (day
14), never sees worse than Restless; Fading at 15 marks "over two weeks";
Last Call at 18 leaves three days, and any three days hold at least two
nights the real bar is open (closed Mondays), which matters once a real visit
is required.

- Days are shown, never a live countdown. Three notifications sit outside the
  2-a-week budget (Last Call, the death notice, the last 2 ghost days), each
  once per decline. One that would fall in quiet hours (after 22:00 local,
  GDD §2.6) goes out at 19:00 local the same day instead.
- With notifications off (and until push notifications exist), the home chip
  and postcards are the warnings; character creation says so in one line.
- **Rescue** = any counting visit before day 21. It resets the clock, triggers
  Welcome Back (GDD §2.5, built), and from Last Call drops a one-time "Close
  Call" polaroid. Nothing else is owed.

**What it asks in practice** (built decay, soft floor 0.3, GDD §2.3 sample
visit; with the in-game stand-in):

| Player | Danger | Annoyances on arrival (§7) |
|---|---|---|
| 2–3 visits a week | Never | None |
| 1 visit a week | Never past Fine | Thirsty only (the free first drink clears it in seconds) |
| 1 visit every 10–20 days | Restless to Last Call warnings, never dead | All four meter annoyances, most visits |
| Opens the app after creation, never plays | Dead day 21, deleted day 35 | — |

---

## 5. Death, the ghost window, revival

### 5.1 The ghost window

At day 21 the character dies and becomes a **ghost for 14 days** (S2,
Daniele's). Meters, coins and everything else freeze where they were. The
ghost can drift into the club (walk, sit, watch the band) but nothing it does
counts: every action prompt reads "You're a ghost", nothing refills, nothing
earns, no visit counts. The Flat's rent pauses (§9).

### 5.2 Revival: a check-in at the real bar

**Only a check-in at the real Black Cabin revives** (S3, Daniele's) [server].
There is no NPC zombie act. A QR check-in during the ghost window revives the
character; a memory taken at the bar does not (it needs a living character to
share it).

| Rule | Value |
|---|---|
| How | A QR check-in at the real bar during the 14-day window; the app shows "Come to the bar and we'll bring you back" on the ghost's chip |
| Limit | **Once per 90 days** per character, counted from the last revival (S4, Daniele's). A check-in inside 90 days still counts for Top patrons, but the window runs out: "Not twice in one season, darling." — Nam |
| Before the server exists | No revival path ships; the window runs out. A debug "Fake check-in" runs the same code so it can be tested (open call O2 asks whether the in-game stand-in should revive too) |
| Multiplayer later (wave 4) | Daniele's base proposal ("a friend needs to do something and they come back to life") may add a friend's zombie act on stage; it shares the 90-day limit. Designed with wave 4 |

### 5.3 Coming back

The next time the player opens the app, the revived character walks in
through the club door **as a zombie for that visit** (green-grey tint,
stiff-arm walk, a groan on idle; cosmetic only), then is normal. Each meter is
lifted to at least 40, the visit clock is 0, Welcome Back fires. They keep
everything. A "Back From the Dead" sticker goes on the club door and a
stitched-scar accessory unlocks in the wardrobe (optional to wear). The
character card shows "Lives: 2". Revival is a story the player tells, not a
punishment.

---

## 6. Deletion: total

At day 35 (or at once on a voluntary Retire, §11) the character is deleted.
Daniele: *"the character is deleted from the game, including leaderboard
positions and achievements; a new game starts from scratch."* **Nothing in
the game survives** (S7).

| Goes | Stays |
|---|---|
| Character: name, look, personality, lives, "since" date | The account: sign-in, settings, notification consent |
| Meters, Tab, Regular Rank, chalkboard name | Real-world vouchers **already claimed** stay valid until they expire (a promise Black Cabin made to a person). One that expires unused does **not** refund coins: there is no wallet to refund to |
| Coins, wardrobe, frames, the Flat lease and storage (§9) | A **farewell card** the player can save or share before it goes (last memory photo, name, "Nights out: 23 · 3 Oct – 6 Dec", lives); the game keeps no copy |
| Hearts with regulars (they start as strangers) | Anti-abuse records at account level, invisible: account age for real rewards, monthly real-reward limits (`04-coins` §7.3) |
| Memories, album, Memory Wall, photos shared at the TV corner | |
| Achievements (door stickers, BACKLOG B4), minigame bests, stamp card | |
| Leaderboard and Top patrons rows (server-side delete, BACKLOG B6) | |

This overrules DECISIONS 2026-10-28 ("its memories stay in the album").
`04-coins` §1 reads "never lost while the character lives". A new game is
fully new: starting wallet, first-visit gifts and creation, as for a
first-time player. Deliberate death can't be farmed: it takes 35 days and
leaves nothing behind.

---

## 7. Annoyances

**Stronger** (S9). Daniele: *"stronger but also lets try to balance it to make
it both a real need and to make it harder, like we can make failing at
minigame a thing and limit time a minigame can be retried"*. Two parts: each
neglected need drags the whole night down until it is seen to (§7.1), and
minigames can be missed, with a limited number of tries (§7.2). **Coins are
never touched:** the coin sign-off (C1) keeps "no fines for absence or
neglect", so the bite is in gains and play, not the wallet.

### 7.1 The five annoyances

Meter annoyances start when the meter is **Empty (below 10)**, the GDD's word
for it; the calendar one by days. Each shows on arrival and on the home view,
and is cleared **in the same visit** by doing the thing.

**The drag:** while any annoyance is on, gains to every *other* meter are
×0.85 for each one (two on: ×0.72; four: ×0.52). It applies with the daily or
Welcome Back multiplier, before diminishing returns. A meter's own annoyance
never lowers its own refill: the refill is the cure.

| Need | Trigger | Annoyance | Friction on top of the drag | Cleared by |
|---|---|---|---|---|
| Drink | Drinks < 10 | **Thirsty:** stares into an empty glass; at home the fridge door hangs open | Walks 25 % slower in the venue | Any drink (water counts) |
| Music | Music < 10 | **Earworm:** hums one off-key loop | The club's music is ducked −9 dB under the hum | Hearing one song |
| Chat | Friends < 10 | **Phone face:** scrolls their phone on idle | Regulars don't wave you over or save a seat; the first chat prompt asks "Put the phone away?" (one extra tap) | Any chat (Candle Talk, sitting at a table, bar chat, a cigarette in the smoking room) |
| Minigame | Nightlife < 10 | **Rusty:** drops the shaker, misses the plunger | The first minigame of the visit opens with a 2-second fumble and a higher miss line (§7.2) | Finishing any minigame, even a miss |
| Calendar | Calendar not opened for 7 days | **Out of the loop:** the Tonight board shows "?"; a regular mentions an event you missed ("You missed Moderndog!") | The drag only | Opening the calendar |

**The reason to open the app** (Daniele's ask) is the calendar: a 10-second
look from home shows tonight's real event, and tapping **Going** on a night
gives a small bonus if you then play that night (+10 Music on arrival and an
"I was there" ticket stub; with the server, a check-in at the real bar that
night). No coins for opening the app, no streaks (GDD §10.2).

Times to Empty with the built decay (soft floor 0.3): Drinks 8.1 days from
100, Music ~10, Friends ~11, Nightlife ~13; from the start value 75 about two
days less. Hence §4: weekly players meet only Thirsty, and the free first
drink clears it before the drag costs anything.

### 7.2 Minigames: misses and tries

This overrules GDD §9's "no fail screen, any finish gives the minimum".

| Rule | Value |
|---|---|
| **Miss** | A finished or abandoned round scoring below **0.25** is a miss: no need gain, no coins, no `minigame_played`, no best. The result card shows MISS and a playful line ("Most of it's on the floor." — Nam). A missed Pour Perfect serves no drink and adds no tipsiness |
| Rusty | While Rusty, the first minigame of the visit misses below **0.4** |
| **Tries** | **3 rounds per minigame per visit**, misses included. After the third the cabinet, bar or stage says "That's plenty for tonight" (the existing caption). AGAIN also hides, as built, when the next round would earn nothing |
| Candle Talk | A missed talk doesn't use up the regular's once-a-day talk and never costs a heart (GDD §5.1 "no rejection" stands): it costs a try |
| Tiers | Miss < 0.25 ≤ good < 0.6 ≤ great < 0.85 ≤ perfect (`minigame_base.gd` keeps 0.6 / 0.85) |

The zero-coin rule still holds: every meter can still be filled to 100 with no
coins, and the GDD §2.3 sample visit has no misses.

---

## 8. Why players get attached

| Lever | Detail |
|---|---|
| Age | The character card shows "At Black Cabin since 3 Oct · 23 nights out · Lives 1" |
| Door stickers (BACKLOG B4) | Achievements live on the club's entry door; seen on every arrival and exit; all gone on deletion |
| The usual | After 3 orders of the same drink, Nam starts it when you sit at the bar ("The usual?") |
| Regulars remember | Hearts, postcards, names, the seat they save you |
| Top patrons | Real check-ins put the character on the lounge board and, in the top 10, on the corridor wall with their own message (BACKLOG B7) |
| Home | The Flat (§9): your room, your wall, your clothes on the rail |
| Lives and scars | Revival leaves a mark (§5.3): a character who came back is a better story |

---

## 9. The Flat: a rented room upstairs

(Here rather than in `04-coins.md` because it changes where the character
lives and what death takes; `04-coins` carries the prices.)

**Now:** the Flat stays minimal (DECISIONS 2026-11-02): the home is today's
stand-in (walk-out card, GO OUT; the street-door start screen on launch).
**Later, as an unlock:** with coins you **rent a room on the second floor**,
an instanced area, and the game then starts there.

**Upstairs is real** (F1): Black Cabin's second floor is a real events floor.
Daniele: fine to keep the Flat there for now; it may move later. So the Flat
is its own scene with one entry point (the rope), and moving it later changes
only that entry.

| Item | Value |
|---|---|
| Unlock | Coins only; offered once the wallet first reaches the move-in fee (a note under the door: "Room going upstairs. Ask Nam.") |
| Move-in | **100 coins**, once, non-refundable (S11, Daniele's) |
| Rent | **20 coins a week**, taken **every Monday 00:00 Bangkok** with the Week Recap (S11) |
| Pay ahead | Up to 4 weeks |
| Paused | While **Out of Town** and while the character is a **ghost** (§5): those Mondays charge nothing |
| What you get | The room (GDD §7.3): bed, record player, window onto the street, the **Memory Wall** (12 pins), the wardrobe rail at home, the **event calendar** on the wall. Wall colour and 4 furniture swaps; no building. The game starts here |
| What it never gives | Slower decay, extra gains, protection from the visit clock. Coins never buy relief from needs (`04-coins` §1) |

**If rent lapses** (S12, Daniele's): coins never go negative, so a Monday with
too few coins starts **7 days' grace**: a note under the door ("Rent's late.
— the landlady"), the room still works. Still unpaid when the grace ends: the
character **moves out**, the game starts at the street door again, frames and
pins go **to storage** (kept, not lost), the rope closes. **Re-renting within
30 days is free** of the move-in fee (the week's rent is still due); after 30
days the move-in is paid again. Storage waits as long as the character lives.
A lapse never touches the visit clock or the character.

**Where it meets the club** (layout frozen; no change to `layout.json`): the
lounge stair (south-wall flight from the game cabinet, landing, west-wall
flight north) ends at the velvet rope (`build_venue.gd` `STAIR_STOP_Z` 10.05)
under the dark bulkhead of the closed upper floor.

| Moment | What happens |
|---|---|
| Non-tenant at the rope | As now: rope closed, prompt "Rooms upstairs · tenants only" |
| Tenant at the rope | Nam's helper unhooks the rope; the character climbs into the bulkhead; fade; the Flat scene loads |
| Launching the game as a tenant | Opens in the Flat (the check-in view, GDD §1.1), not at the street door |
| Going out | Tap the Flat door → fade → the character appears on the upper flight and walks down into the lounge |
| Leaving the club | Walking up past the rope ends the visit and goes home; the street door also works and lands at home with the exit shot |
| Instanced | Each tenant has their own room behind the same rope. Multiplayer later: invite-only visits; others see you climb the stair and disappear |

**On death:** rent pauses through the ghost window; a revived character goes
home to the same room; on deletion the lease and storage end with everything
else.

---

## 10. Build spec

For the needs worker. **Stays as built:** the four meters, `START_VALUE` 75,
`DECAY_PER_HOUR`, soft floor (30, ×0.3), personality ×0.9, Vibe thresholds,
diminishing returns, daily multiplier, Welcome Back (×2 replacing the daily
multiplier, 15 min), Out of Town 14 / 30 days, every existing action and
value, the nightlife rules (drunk, WASTED), notification budget 2 a week and
quiet hours after 22:00.

### 10.1 States and timers

`stake_stage` is derived from the clock on every `sync()`, never stored as
truth (the save keeps it only to notice a change on load).

| Stage | From `days_since_visit` | Leaves when |
|---|---|---|
| `fine` | 0 | — |
| `restless` | 10.0 | A counting visit (→ `fine`) |
| `fading` | 15.0 | A counting visit |
| `last_call` | 18.0 | A counting visit (→ `fine`, Close Call polaroid) |
| `ghost` | 21.0 (sets `dead_at`) | A revival (→ `fine`) or `dead_at` + 14.0 days (→ deleted) |
| deleted | `dead_at` + 14.0 (day 35) | Farewell card, then `new_game()` keeping account fields |

- `days_since_visit` = (clock − `last_counted_visit` − Out of Town seconds in
  between) / 86400; never negative.
- Out of Town can't start at `restless` or later; it pauses the clock as it
  pauses decay (the same `out_of_town_until` window).
- A visit in progress holds the stage at `last_call` at most; `ghost` is only
  entered between visits.
- A revival sets `last_counted_visit` = now, `last_revival_at` = now,
  `lives` += 1, `dead_at` = 0, floors each meter at 40, starts Welcome Back
  and flags the next visit as the zombie visit. Refused if `last_revival_at`
  is within 90 days.
- Ghost: decay and the wallet freeze at `dead_at`; `apply_action` returns
  `{ok: false, reason: "ghost"}`; `begin_visit()` works (the ghost can walk in)
  but nothing counts.

### 10.2 Warnings

| Stage reached | In-app (built now) | Push (when notifications exist) |
|---|---|---|
| `restless` | Chip + Ploy's postcard | In budget |
| `fading` | Chip with days left, dim lamps | In budget |
| `last_call` | Chip with days left + Nam's postcard | **Outside** budget |
| `ghost` | Ghost at the door, tombstone sticker, chip with days left | **Outside** budget |
| ghost day 28 | Chip | In budget |
| ghost day 33 | Chip | **Outside** budget |
| deleted | Farewell card on next launch | — |

Each fires once per decline: a counting visit re-arms them. A push that would
land after 22:00 local goes at 19:00 local that day.

### 10.3 Annoyances

| Id | On when | Off when (same visit) | Effect |
|---|---|---|---|
| `thirsty` | Drinks < 10 | Any drink action (water included) | Venue walk speed ×0.75 |
| `earworm` | Music < 10 | `listen_song` (or any Music gain) | Club music bus −9 dB, hum loop |
| `phone_face` | Friends < 10 | Any Friends gain | No wave or saved seat; one extra confirm tap on the first chat |
| `rusty` | Nightlife < 10 | Finishing any minigame (a miss counts) | 2 s fumble + miss line 0.4 on the first minigame |
| `out_of_loop` | `last_calendar_at` older than 7 days | Opening the calendar | Tonight board "?" |

- All five add to the **drag**: gains to other meters ×0.85 per active
  annoyance (never on the annoyance's own meter).
- Meter annoyances are checked on load, on visit start and on every action;
  once cleared they stay off for the rest of the visit even if the meter dips
  again.
- `out_of_loop` is off until the events calendar (BACKLOG D1) exists
  (`CALENDAR_HABIT_ENABLED` false); turning it on sets `last_calendar_at` =
  now for every save so nobody starts annoyed.

### 10.4 Minigames

`minigame_base.gd` gains a miss tier below 0.25 (0.4 for the first round while
Rusty). The result card shows MISS; `apply_action` is not called on a miss.
Tries are counted per minigame id per visit (3), misses included; at 3 the
minigame's prompt is replaced by "That's plenty for tonight". `minigame_played`
is applied after any non-miss round.

### 10.5 What the UI shows

| Where | What |
|---|---|
| Start screen / Flat stand-in (home) | The character in their stage look; the stage chip from Restless on ("Restless", "Fading · 6 days", "Last Call · 3 days", "Ghost · 9 days to bring [Name] back"); postcards; active annoyance icons |
| Venue HUD | The meters as built; one small icon per active annoyance next to its meter (the calendar one by the clock); no stage chip in the venue except Last Call |
| Result card | MISS tier word and line; "That's plenty for tonight" after the third try |
| Ghost | Ghost character, tombstone sticker on the club door, prompts read "You're a ghost"; the chip names the revival rule ("Check in at Black Cabin to bring [Name] back") |
| Revival | The zombie arrival on the next launch, "Back From the Dead" sticker, scar accessory unlocked, "Lives: 2" |
| Deletion | The farewell card (save / share / done), then character creation |
| Settings | **Retire [Name]** (two confirmations, farewell card, immediate deletion, no ghost window; once per 7 days); one line "Warnings show here if notifications are off" |
| Debug panel | "Jump to day N" on the stake clock, "Fake check-in" (counts as a real visit; revives a ghost), "Open calendar" (until D1) |

Strings go through `game/i18n/` as everywhere (English + Thai machine
drafts).

### 10.6 Constants (`rules.gd`)

| Constant | Value |
|---|---|
| `FATAL_DAYS` | 21.0 (Daniele) |
| `GHOST_WINDOW_DAYS` | 14.0 (Daniele) |
| `STAKE_STAGES` | `[["last_call", 18.0], ["fading", 15.0], ["restless", 10.0], ["fine", 0.0]]` (same shape as `VIBE_THRESHOLDS`) |
| `GHOST_REMINDER_DAYS` | `[28.0, 33.0]` (days since the last visit) |
| `REVIVE_COOLDOWN_DAYS` | 90.0 (Daniele) |
| `REVIVE_METER_FLOOR` | 40.0 |
| `REAL_VISIT_REQUIRED` | false (true when the server ships, §3) |
| `STAKE_NOTIFY_OUTSIDE_BUDGET` | `["last_call", "dead", "ghost_33"]`, fallback hour 19 local |
| `ANNOY_EMPTY_BELOW` | 10.0 |
| `ANNOY_DRAG_MULT` | 0.85 (per active annoyance, on other meters' gains) |
| `THIRSTY_WALK_MULT` / `EARWORM_DUCK_DB` / `RUSTY_FUMBLE_SECONDS` | 0.75 / −9.0 / 2.0 |
| `CALENDAR_HABIT_DAYS` / `CALENDAR_HABIT_ENABLED` | 7.0 / false |
| `MINIGAME_MISS_BELOW` / `RUSTY_MISS_BELOW` | 0.25 / 0.4 |
| `MINIGAME_TRIES_PER_VISIT` | 3 |
| `GOING_BONUS_MUSIC` | 10.0 (on arrival, the night you marked Going) |
| `ACTIONS["minigame_played"]` | `{"gains": {"nightlife": 3.0}, "cap_per_visit": 9.0}` |
| `RETIRE_COOLDOWN_DAYS` | 7.0 |
| `FLAT_MOVE_IN` / `FLAT_RENT_WEEK` / `FLAT_PREPAY_WEEKS` | 100 / 20 / 4 (Daniele; built with the wallet, §10.9) |
| `FLAT_GRACE_DAYS` / `FLAT_REJOIN_FREE_DAYS` | 7.0 / 30.0 (Daniele) |

Fix the stale comment on `START_VALUE` (it still cites v1, "Gone at 21.0
days"): it should point to GDD §2.1 only; nothing in the stakes depends on the
start value.

### 10.7 Save fields

Additive keys in the `needs` block (`needs.gd` `to_dict` / `from_dict`), so
old saves load; no `save.gd` version bump (its rule: bump only for a
migration).

| Key | Type | Default for an old save |
|---|---|---|
| `last_counted_visit` | unix float | `last_visit_end`, or the load time if 0 (nobody dies on upgrade) |
| `created_at` | unix float | the earliest `visits` start, else the load time |
| `nights_out` | int | count of `visits` entries |
| `stake_stage` | string | derived |
| `dead_at` / `last_revival_at` | unix float | 0 |
| `lives` | int | 1 |
| `zombie_next_visit` | bool | false |
| `annoy_cleared` | dict id → true (this visit; cleared on `begin_visit`) | {} |
| `minigame_tries` | dict id → int (this visit) | {} |
| `last_calendar_at` | unix float | the load time |
| `going` | list of Bangkok dates | [] |
| `last_retire_at` | unix float | 0 |
| `stake_notified` | list of stage ids fired this decline | [] |

Later, with the wallet: `coins`, `coin_ledger` (`04-coins` §10), `flat`
(`{rented, paid_until, grace_until, moved_out_at, storage}`).

**Deletion** calls `new_game()` but keeps the account: today `new_game()`
also clears `profile`; split it so `player_id` and settings survive while
`display_name` and every `needs`, `visits` and `ext` field go.

### 10.8 What the server provides later [server]

> **Amended 2026-11-09:** the first row's check-in verification is `check_in(code)` in `08-presence.md` §3 and §7 (one static code per table, one check-in per bar night; baseline, DECISIONS 2026-11-09).

| Item | Stand-in until then |
|---|---|
| Table QR codes and check-in verification per bar night | Any in-game refill (§3); debug "Fake check-in" |
| Memory upload at the TV corner, checked as taken at the bar | None (in-game memories don't count) |
| Revival by check-in during the ghost window | None ships; debug "Fake check-in" (open call O2) |
| Server time for death and deletion; the server's `dead_at` wins over a restored save | Local clock; offline the stage caps at Last Call once the server exists |
| Leaderboard and Top patrons rows deleted with the character | Placeholder names on the board |
| Push notifications | In-app chip and postcards |
| `REAL_VISIT_REQUIRED` switch with the one-time clock restart | — |

### 10.9 Build order

1. **Now (needs worker, no server, no coins):** §10.1 to §10.7 except the
   Flat; debug panel entries.
2. **With the coin wallet** (`04-coins` §9 first-playable cut): the Flat's
   rent, grace, storage and re-rent, behind the Flat scene.
3. **With the events calendar (D1):** turn on `out_of_loop`, Going.
4. **With the server:** everything in §10.8.

### 10.10 Tests

1. `stake_stage(days)` at 9.99, 10.0, 14.99, 15.0, 17.99, 18.0, 20.99, 21.0.
2. A new character with no counting visit is a ghost at exactly 21.0 days and deleted at 35.0.
3. Stand-in: one accepted refill action resets the clock at that moment; walking in, standing at the street door or a missed minigame doesn't.
4. A visit in progress at 21.0 days doesn't die mid-visit; ending it without a counting action makes it a ghost.
5. Out of Town freezes the stake clock; it can't start at day 10 or later.
6. Meters at 0 for 30 days with a counting visit every 20 days: never dead.
7. 12 simulated weeks of one GDD §2.3 sample visit a week: stage always Fine; only Thirsty on arrival.
8. Ghost: `apply_action` refused, decay frozen, `begin_visit` allowed and counts nothing.
9. Revival (debug Fake check-in) in the window: meters floored at 40, clock 0, Welcome Back on, `lives` 2, zombie flag set; a second one within 90 days is refused and the window runs out.
10. Deletion keeps `player_id` and settings and wipes everything else (meters, Tab, visits, hearts, bests, ext, display name); Retire does the same at once and is refused within 7 days of the last.
11. Each annoyance turns on at its trigger and off on the named action in the same visit; with two on, a third meter's gain is ×0.7225; a meter's own refill is never dragged.
12. Miss: a score of 0.24 gives no gain, no coins, no `minigame_played`, no drink for Pour Perfect, and uses a try; 0.25 is good. While Rusty, the first round misses below 0.4.
13. Tries: a fourth round of the same minigame in one visit is refused; a new visit resets the count; a missed Candle Talk leaves the regular's daily talk available.
14. `minigame_played` adds +3 Nightlife per non-miss round, capped +9 per visit.
15. An old save without the new keys loads at Fine with the clock starting at its last visit end (or the load time), and no annoyance from the calendar.
16. A backward device clock never un-decays, un-kills or un-deletes (elapsed is never negative, as `sync()` does today).
17. The GDD §2.3 sample visit still costs 0 coins and has no misses (zero-coin rule).
18. Later, with the wallet: rent is charged Monday 00:00 Bangkok; skipped while Out of Town or a ghost; a short wallet starts 7 days' grace, then moved out with storage kept; re-renting within 30 days skips the move-in; coins never go negative.

---

## 11. Edge cases

| Case | Rule |
|---|---|
| Clock set forward | Only hurts the player. With the server, death and deletion need server time; offline, the stage caps at Last Call |
| Clock set backward | Elapsed is never negative (built in `sync()`) |
| Restoring an old save to undo death | First playable (local save): possible, accepted. With the server, its `dead_at` wins |
| Uninstall | Local save: everything is lost. With accounts: the clock keeps running server-side |
| Wanting a fresh start | **Retire [Name]** in settings (§10.5) |
| WASTED lockout | Can't kill: WASTED follows drinks, so the visit has already counted and the clock is at 0 |
| Notifications off | In-app warnings only; creation and the home chip say so |
| Death during a minigame or set | Can't happen: a visit in progress holds the stage at Last Call |
| One character per account | Yes; the next one starts after deletion |

---

## 12. Amendments applied to other docs (2026-11-02)

| Doc | What changed |
|---|---|
| `01-high-concept.md` | Pillar 2, the Tamagotchi rows and the hook state the v3 rule; platform reads mobile only |
| `02-gdd.md` | §2.1 Out of Town and Empty; §2.3 minimum line; §2.5 replaced by the stakes summary; §2.6 three stake messages outside the budget; §6.1 Bangkok time; §7.2 merch shop; §7.3 the Flat; §9 misses and tries; §10 visit clock; §14 first-playable scope; §15 answered |
| `04-coins.md`, `04-coins-summary.md` | Signed off (C1): drink bands, Flat prices, the coin merch shop in the lounge |
| `DECISIONS.md` | The orchestrator's: "Death rules in detail" and "The Flat" in Still open are answered by this chapter |

---

## 13. Answers and open calls

| ID | Call | v2 recommended | **Decided** | Where |
|---|---|---|---|---|
| S1 | Fatal timer | 14 days | **21 days** | §4 |
| S2 | Revival window | 7 days | **14 days** (deleted at 35) | §5.1 |
| S3 | Revival before multiplayer | Regulars at 2+ hearts | **Only a check-in at the real bar** [server] | §5.2 |
| S4 | Revival limit | Once per 90 days | Once per 90 days | §5.2 |
| S5 | What counts as a visit | 3 minutes past the Sticker door | **Any one refill action**, now the stand-in (S13) | §3 |
| S6 | Tone | Playful ghost and zombie | Playful ghost and zombie | §1 |
| S7 | What survives deletion | Nothing in-game; claimed vouchers; farewell card | As recommended | §6 |
| S8 | The needs | Four meters + two habits; minigames feed Nightlife | As recommended, **with the real check-in and the memory at the bar as the fatal need, the calendar as the minor habit** | §2 |
| S9 | Annoyances | Cosmetic + tiny friction | **Stronger**, with minigame misses and limited tries | §7 |
| S10 | Pauses | Out of Town only | Out of Town only | §3 |
| S11 | Flat price | 100 + 20 a week | 100 + 20 a week | §9 |
| S12 | Rent lapse | 7-day grace, storage, free re-rent within 30 days | As recommended | §9 |
| S13 | S5 vs S8 conflict | — | **Only a real visit resets the timer; an in-game refill stands in until the server exists** | §3 |
| C1 | Coins sign-off | Sign off | Signed off as written; a Coins tab on the hub | `04-coins` |
| C2 | Drink prices | Bands from THB | Bands from THB | `04-coins` §3.1 |
| F1 | What's upstairs | — | A real events floor; the Flat stays there for now, may move | §9 |

**Open calls** (for the orchestrator; none blocks §10.9 step 1):

- **O1 Players who can't reach the bar.** Once `REAL_VISIT_REQUIRED` is on,
  a player outside Bangkok dies every 35 days whatever they do in the game.
  Options: ★the real-visit rule starts with a character's first QR check-in
  (until then the in-game stand-in keeps them alive) / everyone needs real
  visits (the app is for the bar's own crowd) / the stand-in stays for good
  and a real visit only adds bonuses. Would settle as DECISIONS: "Real visits
  are required [for everyone / from a character's first check-in / never]."
- **O2 Revival before the server.** No route revives a ghost until check-ins
  exist. Options: ★the ghost window just runs out (as decided; debug
  check-in for testing) / the in-game stand-in also revives (the ghost walks
  into the club and is served by Nam). Would settle: "Before the server, a
  ghost [can't be revived / is revived by an in-game visit]."
- **O3 How a memory proves it was taken at the bar.** For the real-world
  bridge chapter: ★only photos shared during a checked-in night count /
  location and opening hours / staff approve. Would settle: "A memory counts
  as a real visit when [it is shared on a checked-in night / …]."
- **O4 Tuning to confirm on the Questions tab:** drag ×0.85 per annoyance,
  miss line 0.25 (0.4 Rusty), 3 tries per minigame per visit, warnings at
  10 / 15 / 18. Would settle: "Stakes numbers confirmed as in 06-stakes v3
  §10.6 [with changes]."
