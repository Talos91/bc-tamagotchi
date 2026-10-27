# Black Cabin Tamagotchi — Game Design Document

Status: draft v1 (session 1A, 2026-10-27). Read `01-high-concept.md` first.
All numbers are starting values for tuning and live in one data file
(`needs_config`) so they can be changed without code changes.

---

## 1. Core loop

### 1.1 A visit (8–15 minutes)

1. **Check in** (home screen, 10–30 s). See your character in their flat:
   mood, the four meters, postcards from regulars, tonight's lineup.
2. **Go out.** Tap the door. Your character arrives at the Black Cabin entrance
   under the orange sign. The notice board shows what's on in this visit.
3. **Pick what you need.** The lowest meter glows on the HUD. The board and
   the regulars hint at where to go ("Mali's at the long table, the band's on
   in 2 minutes").
4. **Do bar things.** Order a drink, catch a song or a set, sit with a
   regular, dance, play a minigame. Each action refills one or two meters (§2.3).
5. **Collect.** Notable moments drop a memory (polaroid, ticket stub,
   coaster) into your pocket (§8).
6. **Head home.** Leave any time. The walk-out screen totals what you gained,
   then you're back at the flat with the new memories on the wall.

Leaving mid-set costs nothing; gains are kept the moment they're earned.

### 1.2 A week

| Day | What the game offers |
|---|---|
| Monday | Week Recap card for last week; new weekly lineup posted; new featured drink; fresh weekly stamp card. |
| Tue | **Quiz Night** at the long table (bonus Friends). |
| Wed | **Open Mic** (player performances, bonus Music). |
| Thu | **Jazz & Candles** (slow set, bonus Music + Friends). |
| Fri–Sat | **Headline Night**: the week's featured performer plays a full set, disco ball on (bonus Music + Nightlife). |
| Sun | **Slow Sunday**: acoustic sets, double memory chance at the banquette. |

The intended rhythm is **3 visits a week**, with one landing on an event night.
A player who visits every day is never blocked, but returns diminish (§2.4),
and the extra time goes into memories, friendships and minigame scores.

---

## 2. Needs system

### 2.1 The four meters

Each meter is a float 0–100. Saved as `{value, last_updated_utc}` and
recomputed on load from elapsed real time, so no background process is needed.

| Meter | Fantasy | Decay / real hour | Full → empty | Low-meter tell (character) |
|---|---|---|---|---|
| **Music** | Live sound, being in a crowd for a song | 0.55 | ~7.6 days | Hums to themselves, taps on things, wears headphones at home |
| **Friends** | Being recognised, talking, company | 0.50 | ~8.3 days | Checks phone, sighs, looks at the door |
| **Drinks** | The ritual of ordering and sipping (alcoholic or not) | 0.70 | ~6.0 days | Stares into an empty glass, fridge door open |
| **Nightlife** | Staying out, dancing, the late-night buzz | 0.45 | ~9.3 days | Yawns, in pyjamas by 9 pm |

Decay per full week: Music −92, Friends −84, Drinks −118 (bottoms out on
day 6), Nightlife −76. **Drinks is deliberately the fastest**, so it's the
small, frequent reason to drop in.

**Soft floor:** below 30, decay is halved. A character who isn't visited for
two weeks reaches about 10–20 on most meters, not 0. Only a long absence
empties them.

**Out of Town toggle:** freezes all decay for up to 14 days, once per 30 days.
Shown as a suitcase in the flat.

**Personality modifier:** set at character creation (§7). Lowers one meter's
decay by 10%.

### 2.2 Overall mood ("Vibe")

Vibe is the average of the four meters. It drives the character's visible
state.

| Vibe | State | Effect |
|---|---|---|
| 80–100 | **Glowing** | Warm rim light on the character, happy idles, +25% memory drop chance, can be picked for the Spotlight at headline nights |
| 50–79 | **Good** | Normal |
| 25–49 | **Meh** | Muted idles, one "missing it" line from a regular each visit |
| 0–24 | **Homebody** | Character stays in pyjamas at the flat; the first visit after this triggers the **Welcome Back** (below) |

### 2.3 Refill actions

Values are base gains before diminishing returns. "Score-scaled" means
minimum at a poor score, maximum at a perfect one. Low skill always earns the
minimum, never zero.

| Action | Zone | Music | Friends | Drinks | Nightlife | Notes |
|---|---|---|---|---|---|---|
| Order a drink (no minigame) | Bar | | | +15 | | First drink each visit is "on the house" (free) |
| Pour Perfect / Shake & Serve minigame | Bar | | | +20–30 | | Score-scaled; replaces a plain order |
| Try a drink you've never had | Bar | | | +5 bonus | | Also drops a Coaster memory |
| Listen to one song (within earshot of the stage) | Stage / Candle Floor | +5 | | | | Passive; character sits or stands |
| Finish a full set (4 songs) | Stage | +5 bonus | | | +5 | |
| Front Row Rhythm (per song) | Stage | +8–12 | | | | Score-scaled |
| Applaud / request a song | Stage | +2 | | | | Capped at +6 per visit |
| Headline Night set (attend 70%+ of it) | Stage | +40 | | | +20 | Fri/Sat only |
| Candle Talk with a regular | Candle Floor / Banquette | | +10–20 | | | Score-scaled; once per regular per day |
| Sit at a table with another character for 60 s | Any table | | +8 | | | Once per character per day |
| Receive a social verb (wave, cheers, high five) | Any | | +2 | | | Capped at +10 per visit |
| Quiz Night / Name That Tune | Long Table | +5 | +10–15 | | | Score-scaled |
| Dance under the disco ball (per 30 s) | Dance floor | | | | +3 | Capped at +15 per visit outside minigame |
| Dance-off minigame | Dance floor | | | | +12–20 | Score-scaled |
| Pinball (one game) | Lounge | | | | +10–20 | Score-scaled |
| First time entering the Lounge each visit | Lounge | | | | +5 | |
| Stay until "last song" of a headline night | Any | | | | +10 | |

**Sample 10-minute visit:** free drink (+15 D), Pour Perfect (+25 D), three
songs from the front row (+15 M) plus one Front Row Rhythm round (+10 M),
Candle Talk with a regular (+15 F), sit with someone (+8 F), Lounge entry and a
pinball game (+5, +15 N), one minute of dancing (+6 N). Totals: M +25,
F +23, D +40, N +26. About 115 points against a weekly decay of ~370, so three
such visits cover a week.

### 2.4 Diminishing returns (instead of caps)

Per meter, per visit:
- The first **40** points gained count in full.
- Points 41–80 count at **50%**.
- Beyond 80, **25%**.

Separately, a **daily** multiplier: the 1st visit of a real day earns ×1.0,
the 2nd ×0.75, the 3rd and later ×0.5. A "visit" starts when the character
walks in and ends when they leave or have been idle for 10 minutes.

No hard caps, so the player is never told "you can't do that". Grinding just
stops being efficient.

### 2.5 Full and empty

**At 100:** the meter shows a small "topped up" sparkle. Further gains for that
meter turn into **Tab** (progression XP, §10) at 1:1, so play is never wasted.

**At 0:** nothing breaks. The character's tell for that meter (table in §2.1)
is at full strength. All four at 0 is just a very homebody character.

**Welcome Back:** the first visit after Vibe has been below 25, or after 7+
days away: the bartender says hello by name, the first drink is free, and all
gains are doubled for 15 minutes (diminishing returns still apply). Two
regulars send warm postcards during the absence ("Haven't seen you at the long
table lately"). Never guilt: copy may not say "abandoned / neglected / forgot".

### 2.6 Notifications (opt-in, default ON, max 2 per week)

- When the lowest meter crosses 40: one-line character status ("Your character
  is humming to themselves").
- Friday 18:00 local: the headline act for tonight.
- Never notify about a meter hitting 0. Never notify after 22:00 local.

---

## 3. Session structure

| Session type | Length | Frequency target | Contents |
|---|---|---|---|
| **Check-in** | 10–30 s | 1/day | Flat view, meters, postcards, lineup. No venue load. |
| **Quick drink** | 3–5 min | 1–2/week | Bar + one song. Tops up Drinks and some Music. |
| **Night out** | 8–15 min | 2–3/week | The full loop in §1.1. |
| **Event night** | 15–25 min | 1/week | Quiz Night or Headline Night end to end. |

Target average: **~35 minutes per week** across 3–4 sessions. A session can be
abandoned at any moment with no loss (the app being backgrounded = the
character leaves).

---

## 4. The venue

The venue is one fixed space faithful to the reference photos, split into
zones the camera frames one at a time (portrait diorama view; the character
walks between zones, and the camera eases between framings). The art bible
owns exact layout and scale; this section owns what each zone *does*.

| # | Zone | Real-room source | Offers | Main meters |
|---|---|---|---|---|
| 1 | **Entrance** | Doorway with the orange backlit "BLACK CABIN" sign, dark concrete corridor, toilet sign | Arrival, notice board (tonight's lineup, events, weekly stamp card), guestbook | — |
| 2 | **The Bar** | Backlit bar with amber-lit bottle shelves | Bartender NPC, drink menu, Pour Perfect, Shake & Serve, featured drink, coaster collection | Drinks |
| 3 | **Stage & Front Row** | Corner stage: drum kit, sparkly amp, mic stands, music stands, olive tree, red/amber wash, round high tables with tufted black leather poufs | Live sets, Front Row Rhythm, song requests, Open Mic, applause | Music |
| 4 | **Candle Floor** | Main room: round dark-wood tables, ribbed glass brass table lamps, tea lights, wooden chairs, floor-to-ceiling velvet curtains, round orange wall lamp, orange under-glow strip along the wall | Sit with regulars and players, Candle Talk, passive listening | Friends, Music |
| 5 | **Velvet Banquette** | Red channel-tufted velvet banquette under display shelving, black marble round tables, framed prints | Quiet one-on-one corner: Candle Talk with bonus memory chance, regulars' "story" scenes | Friends |
| 6 | **The Long Table** | Long dark tables with black metal bistro chairs, candelabra on the sideboard by the curtain | Group seating (8), Quiz Night, Name That Tune, Coaster Flip, Toast Chain | Friends |
| 7 | **Dance Floor** | Open floor in front of the stage on Headline Nights; mirror disco ball | Dancing, Dance-off; disco ball turns on Fri/Sat and during events | Nightlife |
| 8 | **The Lounge** | Second space: black-painted concrete beams, red neon "BLACK CABIN" sign over the plant wall, long communal table, globe lamps, vintage CRT TV, pinball-style cabinet | Pinball, CRT Channel Surf, late-night hangout | Nightlife |
| 9 | **The Staircase** | Staircase up from the lounge | Roped off at launch ("Coming soon: upstairs"). The first expansion zone (§11). | — |

**Venue state changes, not layout changes:** the room's layout never moves.
What changes is lighting (house lights vs. show lights vs. disco), who's on
stage, which regulars are in, seasonal decorations (dressing on fixed
anchor points: curtain rail, bar top, table centres, lounge wall), and the
featured drink on the bar.

**Note for the art bible:** the photos clearly show zones 1, 3, 4, 5, 6. The
bar counter, disco ball, CRT, pinball and red neon come from the brief only
(§15 Q6).

---

## 5. Regulars and other players

### 5.1 NPC regulars

Launch cast: **8 regulars + 1 bartender + 1 house band (3 members)**. The cast
bible (2A) owns names and personalities. Systems rules:

- **Schedule:** each regular has 2–4 "usual nights" and a preferred zone
  (e.g. a jazz fan at the front row on Thursdays, a quiz shark at the long
  table on Tuesdays). On a usual night they are present 90% of the time;
  otherwise 25%.
- **Friendship:** 0–5 hearts. +1 heart per 3 Candle Talks (or equivalent
  shared activities). Each heart unlocks one story beat (a short scene at the
  banquette), a postcard type, and at 3 and 5 hearts a cosmetic or memory.
- **They notice you:** at 2+ hearts a regular waves when you enter, saves you
  a seat, and mentions your last memory together.
- **No rejection:** a regular never refuses to talk. A bad Candle Talk earns
  fewer hearts, never negative ones.

### 5.2 Other players

Phased (see the recommendation in §13):

| Phase | What other players are | Presence |
|---|---|---|
| **P1 — Solo** (first playable) | Absent. The room is filled by regulars and anonymous background patrons. | NPC fill to a target headcount |
| **P2 — Echoes** (async) | Other players' characters appear as *echoes*: real avatars replaying a short loop of where they sat and what they did in the last 24 h. You can cheers an echo; they get the Friends +2 and a notification next check-in. Guestbook notes at the entrance. | Up to 6 echoes per zone |
| **P3 — Live rooms** (real time) | Real players in the same room instance. | Instance cap 24 players; NPCs fill to headcount |

**Headcount rule (all phases):** the venue always shows **12–20 bodies**
depending on time and event (quiet Monday 12, Headline Night 20). Real players
and echoes replace anonymous patrons first, never regulars. The room never
feels empty and never feels packed.

### 5.3 Social verbs

Selected from a radial menu on another character. No free-text chat by
default.

| Verb | Effect |
|---|---|
| Wave | Recipient Friends +2 |
| Cheers (both must be holding a drink) | Both Friends +2, clink animation |
| Sit with | Join their table; triggers the 60 s Friends +8 |
| High five | Both Friends +2 |
| Buy a round | Spend tokens; everyone at the table gets a drink (Drinks +10 each) and you get Friends +5 |
| Dance with | Paired dance animation, both Nightlife ×1.5 for 30 s |
| Swap polaroids | Trade a duplicate polaroid memory |
| Phrase wheel | 24 preset lines ("This song!", "Same again?", "Last one?") + emoji |

Free-text chat (P3 only) is opt-in, 18+ verified, with a filter. This is an
open question (§15).

---

## 6. Performances and events

### 6.1 Schedule

- **House sets:** the house band plays a 4-song set, then a 2-minute break,
  continuously (about every 8 minutes). Something is always starting soon.
- **Event nights:** per §1.2, on the player's local clock, 19:00–24:00 local.
  Outside that window the event's content is available as "the after-party"
  (reduced bonus), so players in odd time zones or on night shifts aren't
  locked out.
- **Headline Night:** a featured performer replaces the house band for one
  10-song set that loops 19:00–24:00 local Fri and Sat.

### 6.2 How a performance works

A set is a list of **songs**, each a 60–90 s audio track plus an animation set
for each performer (instrument loop, between-song banter line, crowd-work
moment).

- **Crowd Vibe:** a hidden 0–100 value for the set. Rises with applause,
  Front Row Rhythm scores, song requests honoured, and the number of characters
  in the stage zone. Falls slowly when no one interacts.
- **Between songs:** a 5 s window to **applaud** (tap) or **request** (pick 1
  of 3 songs from the performer's catalogue; the most-picked plays next).
- **Encore:** if Crowd Vibe ≥ 70 at the end of a set, the performer plays one
  extra song and everyone present gets an Encore ticket-stub memory.
- **Spotlight** (Headline Night only): one Glowing character in the front row
  is invited on stage for the last song (tambourine or backing vocals: a short
  Front Row Rhythm variant) and gets a unique polaroid.

### 6.3 Performer content unit

One performer = 1 voxel character set (2–4 members), 6–10 songs, 3 banter
lines per song, 1 signature memory, 1 cosmetic (band tee). This is the main
live-ops content unit (§11).

---

## 7. Character creation and customization

### 7.1 Creation (under 2 minutes, all changeable later at no cost)

| Slot | Launch options |
|---|---|
| Body | 3 heights × 3 builds |
| Skin tone | 12 |
| Face | 8 eye shapes, 6 brows, 6 mouths |
| Hair | 16 styles × 16 colours |
| Starter outfit | 6 full looks (mixable after creation) |
| **Personality** | **Night Owl** (Nightlife decay −10%), **Music Nerd** (Music), **Social Butterfly** (Friends), **Easy Sipper** (Drinks). Also sets idle animations and which regular greets you first. |

Name: free text, filtered.

### 7.2 Wardrobe

Slots: hat, top, outer layer, bottom, shoes, accessory (glasses, earrings),
held item (only cosmetic: e.g. a tote bag, a vinyl record). Launch: **~60
items**. New items come from memories, regulars' hearts, performer merch, the
weekly stamp card and the shop (§12). Outfits can be saved as 3 presets.

### 7.3 The Flat

One small voxel room (bed, record player, door) used as the check-in screen,
showing the character's mood and the **Memory Wall** (§8). Wall colour and 4
furniture swaps only: a frame, not a building game.

---

## 8. Memories

Memories are the collection layer: the record of nights out.

| Type | Earned by | Count at launch |
|---|---|---|
| **Polaroid** | Notable moments: auto-captured voxel snapshot with a caption ("Thursday, front row, the House Lights") | ~40 authored triggers + random "candid" drops |
| **Ticket stub** | Completing a set or event; Encore stubs; Headline stubs | 1 per performer + events |
| **Coaster** | First time trying each drink | 24 drinks |
| **Setlist** | Hearing every song in a performer's catalogue | 1 per performer |
| **Postcard** | From regulars at heart milestones and during absences | ~3 per regular |

- **Drop rules:** authored triggers always drop the first time. Candid
  polaroids: 10% chance per eligible moment (a song finish, a cheers, a minigame
  best), +25% when Glowing, max 3 candids per visit.
- **No missable content:** seasonal memories return every year. Nothing is sold
  or timed out forever.
- **Display:** the **Memory Album** (paged by month, filter by type, shows
  date + who was there) and the **Memory Wall** in the flat (pin up to 12; the
  first thing you see on check-in).
- **Week Recap** (Mondays): one card summarising last week (visits, songs
  heard, best memory, regulars seen) saved into the album. It's shareable as an
  image.
- Completing a set (e.g. all 24 coasters) awards a cosmetic and a wall frame.

---

## 9. Minigames

All minigames: one thumb, portrait, 10–180 s, no fail screen (any finish
gives the minimum reward), local best score shown, optional and never
required for refills. The table is the summary; designs follow.

| # | Minigame | Zone | Need | Duration | Players | First playable? |
|---|---|---|---|---|---|---|
| 1 | Pour Perfect | Bar | Drinks | 20–30 s | 1 | **Yes** |
| 2 | Shake & Serve | Bar | Drinks | 45–60 s | 1 | |
| 3 | Front Row Rhythm | Stage | Music | 60–90 s (1 song) | 1+ | **Yes** |
| 4 | Open Mic | Stage | Music + Nightlife | 90 s | 1 | |
| 5 | Candle Talk | Candle Floor / Banquette | Friends | 60–90 s | 1 + NPC | **Yes** |
| 6 | Name That Tune | Long Table | Friends + Music | 2 min | 1–8 | |
| 7 | Coaster Flip | Long Table / Bar | Friends | 30 s | 1–4 | |
| 8 | Toast Chain | Any table | Friends | 10 s | 2–8 | |
| 9 | Dance-off | Dance Floor | Nightlife | 60 s | 1–2 | |
| 10 | Neon Pinball | Lounge | Nightlife | 1–3 min | 1 | **Yes** |
| 11 | CRT Channel Surf | Lounge | Nightlife + Music | 30 s | 1 | |
| 12 | Setlist Shuffle | Stage (backstage) | Music | 60–90 s | 1 | |

**1. Pour Perfect.** The bartender slides you a ribbed glass (like the table
lamps); you pour 2–3 layers, each to a target line. Score = closeness to the
lines; overflow just foams. *Controls:* hold to pour, release. *Feeds:*
Drinks +20–30.

**2. Shake & Serve.** A regular orders by vibe ("something sour, something
orange"). Tap ingredients from the backlit shelf in order, shake on a 4-beat
count cued by the bartender's nods, strain. Recipes found go in a recipe book.
*Controls:* tap; tap on beat. *Feeds:* Drinks +20–30, Friends +5.

**3. Front Row Rhythm.** During any live song, two clap lanes (left / right
hand) scroll to the song's beat map. Hits raise Crowd Vibe for everyone;
misses only lose the bonus. Three difficulties. *Controls:* tap left / right
half of the screen. *Feeds:* Music +8–12 per song.

**4. Open Mic.** Wednesdays: the player takes the stage, picks an instrument
(voice, guitar, keys, drums) and 1 of 6 songs, and plays a three-lane chart.
The house band backs you, so a weak run still sounds fine; the crowd reacts
live. *Controls:* tap 3 lanes, hold sustains. *Feeds:* Music +15,
Nightlife +10, stage polaroid.

**5. Candle Talk.** The core friendship game. Five turns: the regular says
something, you play one of three topic cards (music, drinks, gossip, Bangkok,
their story thread). Matches brighten the candle. Cards come from memories
(seeing a band gives a card about it), so collecting feeds conversation.
*Controls:* tap a card. *Feeds:* Friends +10–20, hearts.

**6. Name That Tune.** Quiz Night at the long table: 10 rounds of a 5 s clip
and 4 answers. Questions favour the game's own performers (rewarding
attention to sets), then general trivia. Shared scoreboard chalked on the
table. *Controls:* tap. *Feeds:* Friends +10–15, Music +5.

**7. Coaster Flip.** The bar trick: flick a coaster off the table edge and
catch it, growing the stack each success. Table-mates take turns; the tallest
stack wins. *Controls:* swipe up, tap to catch. *Feeds:* Friends +8–12.

**8. Toast Chain.** Anyone at a table raises a glass; others have 3 s to tap
"cheers". More clinks, bigger toast and sound. Regulars join when solo.
*Controls:* one tap. *Feeds:* Friends +3 per participant (max +12).

**9. Dance-off.** Fri/Sat under the disco ball, whose light marks the next
pose. Swipe the pose direction on the beat, head-to-head with a regular, echo
or player; both sides earn rewards. *Controls:* 4-way swipe. *Feeds:*
Nightlife +12–20.

**10. Neon Pinball.** The lounge cabinet: a short table themed on the venue
(bottle-shelf bumpers, curtain ramp, drum-kit spinner), 3 balls, generous
ball save. Spelling "BLACK CABIN" lights the lounge neon for everyone for the
rest of the visit. *Controls:* tap left / right flippers, swipe to launch.
*Feeds:* Nightlife +10–20.

**11. CRT Channel Surf.** Turn the old TV's dial; static hides short clips
(performer videos, venue history, rehearsals). Lock a clear signal before it
drifts. Each new clip is a memory. *Controls:* drag dial, tap to lock.
*Feeds:* Nightlife +5, Music +5.

**12. Setlist Shuffle.** Help the house band order 5 song cards (energy and
tempo icons) to fit a mood curve: warm start, peak, wind down. A better fit
raises the next set's starting Crowd Vibe and encore chance. *Controls:* drag
and drop. *Feeds:* Music +10.

---

## 10. Progression and retention

### 10.1 Systems

| System | What grows | Reward |
|---|---|---|
| **Tab (XP)** | Every meter point gained (and overflow at 100) adds to your Tab | Regular Rank |
| **Regular Rank** | Newcomer → Familiar Face → Regular → Local → Part of the Furniture (5 ranks, ~2, 4, 8, 16 weeks at 3 visits/week) | Each rank: a reserved seat style, a bartender greeting, cosmetics, new phrase-wheel lines, a name on the "regulars" chalkboard at the bar |
| **Hearts** | Per-regular friendship (§5.1) | Story beats, postcards, cosmetics |
| **Collections** | Memories (§8) | Cosmetics, wall frames |
| **Weekly stamp card** | 4 stamps: get each meter to 80+ at least once that week | Weekly cosmetic or token reward; a "Good Week" stamp in the album |
| **Minigame bests** | Personal bests and per-minigame mastery (bronze/silver/gold) | Titles, cosmetic variants |

Rank never goes down. Nothing decays except the four meters.

### 10.2 Retention levers (and what we don't use)

Used: needs (gentle return pull), weekly lineup and events, regulars'
schedules, monthly new performers, the Week Recap.
Not used: login streaks that reset, energy timers, expiring rewards, FOMO
limited-forever items.

---

## 11. Live-ops cadence

| Cadence | Adds |
|---|---|
| **Weekly** | Lineup (which performer headlines), featured drink (+1 coaster), weekly stamp-card reward, 10 new quiz questions |
| **Monthly** | 1 new performer (content unit §6.3), 1 new regular *or* a new story chapter for an existing one, 8–12 cosmetics, 1 monthly memory set (5 polaroids) |
| **Every 2 months** | 1 new minigame (from the backlog in §9 or new) |
| **Quarterly** | 1 venue expansion or major state change. Order: **Upstairs** (via the staircase, a second small bar room), then a rooftop, then a back-alley stage. Each opens with a launch event week. |
| **Seasonal (yearly, returning)** | Halloween (late Oct), **Loy Krathong** (Nov: krathong decorations, candle-floating memory), New Year countdown, Valentine's slow-dance night, **Songkran** (April: water-themed decorations, no water physics), Black Cabin anniversary (date from the venue) |

Real-world tie-in candidates (need venue agreement): real Black Cabin
performers as in-game guests, an in-game set mirroring the real lineup on the
same night, a QR code at the real bar that unlocks a coaster.

---

## 12. Monetization stance (recommendation only)

**Recommendation: free to download, cosmetics-only, no pay-to-refill.**

- **Never sell meter refills, decay freezes or multipliers.** Selling relief
  from needs turns pillar 2 into anxiety monetization.
- Sell: outfits, flat furniture, wall frames, special drink *glassware*
  (cosmetic only), emote packs.
- Optional monthly **Night Pass**: a cosmetic track earned by playing, with a
  free lane. No gameplay advantages.
- Soft currency **Cabin Tokens** is earned by playing (stamp cards, ranks,
  minigame firsts) and buys drinks beyond the free first one, song requests on
  Headline Night, "buy a round". Tuned so a 3-visits-a-week player ends
  every week with more tokens than they started with.
- No loot boxes, no gacha.
- Alternative worth weighing: the game as a **brand piece for the venue**
  (paid by or co-owned with Black Cabin, monetization secondary). This changes
  priorities more than any pricing choice and needs a decision (§15).

---

## 13. Recommendations on the open decisions

**Platform:** phone portrait primary, desktop secondary (reasoning in
`01-high-concept.md`). Build implication: fixed-angle diorama camera with
tap/click-to-move. Treat the 1C third-person controller as greybox tooling.

**Single-player-first vs multiplayer-first:** **single-player-first.**
- The first playable must answer "does the loop make you want to come back
  in two days?" That needs no server.
- A small early population means empty real-time rooms, the worst first
  impression for a bar. NPC fill is needed anyway (§5.2).
- Moderation and server cost should wait until the loop is worth protecting.
- Build multiplayer-ready anyway: timestamp-based meters, one social-verb
  interface shared by NPCs, echoes and players, serialisable character data.
  P2 then becomes a backend feature and P3 reuses Ooze Syndicate's server.

---

## 14. First playable (scope cut)

**Goal:** prove the loop: a tester plays 5 visits across a real week (or a
compressed debug clock) and wants to return.

**In:**
- Flat check-in screen (static room, character, four meters, Vibe state)
- Character creator lite: 3 body types, 6 skin tones, 4 hair styles, 3
  outfits, 4 personalities
- Venue zones: Entrance, Bar, Stage & Front Row, Candle Floor, Lounge
  (Banquette and Long Table as set dressing; dance floor = a spot under the
  disco ball with a dance emote)
- Needs system: full decay model (§2.1), refill table rows that apply to
  included content, diminishing returns, Welcome Back, save/load, debug clock
  (1 real minute = 1 game hour)
- House band: 1 set of 4 songs on loop, applaud between songs
- 3 regulars + bartender with schedules and Candle Talk, hearts 0–3
- Minigames: **Pour Perfect, Front Row Rhythm, Candle Talk, Neon Pinball**
  (one per meter)
- Memories: ~15 (polaroids, 6 coasters, 1 ticket stub), album + wall of 6
- Week Recap card

**Out:** multiplayer of any kind, shop and tokens, events and headline nights,
wardrobe beyond creation, notifications, other minigames, the Flat
customisation, upstairs.

**Exit criteria:** meters, decay and refills read clearly without a tutorial
longer than 60 s; a 10-minute visit lands near the §2.3 sample totals; testers
can name a regular.

---

## 15. Open questions for the orchestrator

1. **Platform** and **single vs multiplayer**: recommendations in §13; need
   a decision before 2B (UI wireframes) and 2D (needs prototype) lock layouts
   and save formats.
2. **Alcohol and age rating** (12+ to 17+ depending on depiction). Proposal:
   menu mixes cocktails, beer, mocktails, Thai iced tea, coffee; never any
   intoxication effects. Confirm the target rating.
3. **Relationship with the real Black Cabin:** rights to name, logo and
   likeness; can real staff or performers appear; brand piece or independent
   product? (Affects §11, §12.)
4. **Music sourcing.** Original commissioned tracks, licensed tracks from
   Black Cabin's real performers, or both? Each performer needs 6–10 songs plus
   beat maps.
5. **Event clock.** Player-local time (proposed) vs. Bangkok time for event
   nights. Local is friendlier; Bangkok time is more "real" and matters if P3
   rooms are global.
6. **Venue survey.** The 12 photos don't show the bar counter, lounge, disco
   ball, CRT, pinball or stairs. Request more photos or a floor plan with
   dimensions.
7. **Chat policy for P3:** phrase wheel only, or opt-in 18+ free text?
8. **Languages at launch:** English only, or English + Thai?
9. **Notification budget:** max 2 per week is proposed; confirm.
10. **The Flat:** keep it as a minimal home screen (proposed) or cut it for a
    2D menu to save art budget?
