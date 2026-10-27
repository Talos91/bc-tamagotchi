# Black Cabin Tamagotchi: Game Manual

Status: v1, 2026-10-28. A digest of the repo's design, art, UI and tech documents, written for Daniele. Where this
manual and a source file disagree, the source wins, and `docs/design/DECISIONS.md` wins over everything.

- **OPEN:** not decided yet (all collected again in section 15).
- **SUPERSEDED:** an older doc says one thing; the decisions log changed it. The new rule follows.
- **FP** = first playable, the smallest build meant to prove the loop is fun. Numbers come from the docs and from
  `game/scripts/rules.gd`, the one file holding the game's tunable numbers.

---

## 1. What this game is

**Pitch.** A cozy voxel game (the world is built from small visible cubes, like 3D pixels) about a character who
needs a night out. Four needs, **Music, Friends, Drinks, Nightlife**, run down in real time over about a week. You
refill them by taking the character to Black Cabin, the Bangkok live-music bar, rebuilt block by block. A visit
takes about ten minutes; three a week keep the character glowing.

**Fantasy.** "I have a local": the bartender remembers your order, the band is always about to start, a familiar
face waves you over.

**The Tamagotchi hook, precisely.**

| Element | Rule |
|---|---|
| Meters | Four, each 0 to 100 |
| Drain | Continuous, real time; empty in roughly 6 to 9 days from full |
| Refill | Only by doing bar things at Black Cabin; no feed buttons |
| Typical visit | ~10 minutes, ~30 points per meter (GDD sample: 115 points) |
| Rhythm | 3 visits a week keeps the character happy |
| Neglect | SUPERSEDED: the high concept said "neglect has no lasting cost". DECISIONS 2026-10-28: neglect is fatal. 21 days without a night out, or 14 days with a need left empty, and the character leaves Bangkok for good; memories, coins and wardrobe stay (section 5) |

**Pillars (as amended).**

| # | Pillar | Meaning |
|---|---|---|
| 1 | Going out is the care | Every refill is a nightlife action in the venue |
| 2 | Cozy, with real stakes | SUPERSEDED: was "Cozy, never punishing". A normal week costs nothing; long neglect ends the character |
| 3 | The room is the star | One authored real place; changes through events and lighting, never through players decorating ("Coins: yes. Decor: no.") |

**Audience.** 20 to 35 year olds who like cozy and collection games and going out, in short phone sessions; also
Black Cabin's real crowd. Not for players who want competition or optimisation. Rated **21+**; alcohol is in.

**Platform and orientation.**

| Item | Status |
|---|---|
| Owner | Commissioned by Black Cabin: real name, logo, venue, and real staff and performers with consent |
| Engine | Godot 4.6.1, Compatibility renderer, Web export as a first-class target |
| Devices | Phone first; desktop is a secondary export of the same project |
| Orientation | OPEN. Portrait was set as primary, then reopened. Until decided, venue, camera and HUD must run at 1080×1920 and 1920×1080, and screenshot sets include both |
| Players | Single-player FP; multiplayer later, and the save format must not block it |
| Languages | English and Thai at launch |
| Clock | Real time; Bangkok (UTC+7) for days, weeks and events |

Source files: `docs/design/01-high-concept.md`, `docs/design/00-brief.md`, `docs/design/DECISIONS.md`.

---

## 2. Decisions log

All of `DECISIONS.md`, oldest first. Rows (a) to (p) are the orchestrator's calls after wave 2, reversible by
Daniele.

| Date | Decision | Applies to |
|---|---|---|
| 10-27 | Commissioned by Black Cabin: real name, logo, likeness, real staff and performers where they agree | Cast, art, brand |
| 10-27 | Age rating 21+ | All content |
| 10-27 | Alcohol and intoxication are in (GDD's "no intoxication effects" overruled) | Cast §5, bar menu |
| 10-27 | Music: commissioned originals and licensed tracks from real performers | Performers |
| 10-27 | Real-time event clock, no compressed time outside debug; Bangkok time by default | Needs, events |
| 10-27 | English and Thai at launch, string table from day one | UI, i18n |
| 10-27 | Phone portrait primary, desktop secondary; diorama follow camera, tap-to-move, one-thumb minigames | Camera, HUD (orientation later reopened) |
| 10-27 | Single-player FP per GDD §14; multiplayer later | Scope, save |
| 10-27 | Visual target = the `docs/art/direction/` renders | Art bible, kit |
| 10-27 | (a) `SOFT_FLOOR_FACTOR` 0.5 → 0.3 | `rules.gd` (not changed yet) |
| 10-27 | (b) Welcome Back ×2 replaces, never stacks with, the daily ×0.75 | Needs (code stacks them) |
| 10-27 | (c) Neon Pinball runs on the arcade cabinet's screen | Minigame |
| 10-27 | (d) Screen Cyan is the Nightlife meter colour, UI only | UI |
| 10-27 | (e) Meter numbers hidden by default | HUD |
| 10-27 | (f) Bangkok time everywhere, including the event schedule | Events, notifications |
| 10-27 | (g) String table at `game/i18n/strings.csv`, owned by gameplay sessions | i18n |
| 10-27 | (h) The Flat stays as the minimal home screen | UI |
| 10-27 | (i) Velvet Banquette added to the main room and the kit | Venue, kit |
| 10-27 | (j) Room height 4 m / 80 voxels | Venue, kit |
| 10-27 | (k) Candle Talk +5 lean bonus approved | Needs (not coded) |
| 10-27 | (l) Tipsiness: one state per 30 real minutes, water drops one, Merry caps; others later see walk and idle only | Cast, characters |
| 10-27 | (m) Anonymous patrons: 12 bodies from a kit | Characters |
| 10-27 | (n) Hearts 0 to 3 for the FP | Regulars |
| 10-27 | (o) ครับ/ค่ะ/จ้า particle choice in character creation | Creator |
| 10-27 | (p) `rendering/viewport/hdr_2d=true` in `project.godot` | Tech (done) |
| 10-27 | The player's character is the Tamagotchi; the GDD stands. The overall-look mockup is interface style only; its Mood/Energy/Tidiness and Serve/Clean/Decor are not the design | UI, art |
| 10-27 | Orientation open again; build for both | Camera, HUD |
| 10-27 | Coins yes, decor no; earn/spend needs a chapter | `04-coins.md` (draft) |
| 10-27 | App is a bridge to the real bar: discounts, merch, drinks, table booking, real calendar, song requests, MAYBE order to table; needs a chapter, staff-verifiable redemption, Supabase backend | Section 10 |
| 10-27 | Neglect must have stakes; pillar 2 softened | Section 5 |
| 10-28 | Neglect is fatal: gone for good, memories stay, new character; GDD §2.5 overruled; timeline needs a chapter | `06-stakes.md` (draft) |

Source files: `docs/design/DECISIONS.md`.

---

## 3. The core loop

**A visit (8 to 15 minutes).** Check in at the Flat (the character's small home screen: mood, meters, postcards,
lineup) → tap the door → the lowest meter "breathes" on the HUD and regulars hint where to go → do bar things
(drink, listen, sit, dance, minigames) → memories drop → leave any time; the walk-out summary totals the night.
Gains are kept the moment they are earned.

**A week.**

| Day | Offer |
|---|---|
| Mon | Week Recap, new lineup, featured drink, fresh stamp card |
| Tue | Quiz Night (bonus Friends) |
| Wed | Open Mic (bonus Music) |
| Thu | Jazz & Candles (bonus Music, Friends) |
| Fri, Sat | Headline Night, disco ball on (bonus Music, Nightlife) |
| Sun | Slow Sunday, double memory chance at the banquette |

SUPERSEDED: GDD §6.1 runs events 19:00 to 24:00 on the player's local clock. DECISIONS (f): Bangkok time.

**Sessions.**

| Session | Length | Target | Contents |
|---|---|---|---|
| Check-in | 10 to 30 s | 1 a day | Flat only, no venue load |
| Quick drink | 3 to 5 min | 1 to 2 a week | Bar and one song |
| Night out | 8 to 15 min | 2 to 3 a week | Full loop |
| Event night | 15 to 25 min | 1 a week | Quiz or Headline end to end |

About 35 minutes a week. Backgrounding the app means the character leaves, with no loss.

Source files: `docs/design/02-gdd.md` §1, §3, §6.

---

## 4. Needs and Vibe

Each meter is saved as value plus timestamp and recomputed from elapsed real time on load.

| Meter | Decay per real hour | Full to empty (no floor) | Low-meter tell |
|---|---|---|---|
| Music | 0.55 | ~7.6 days | Hums, headphones at home |
| Friends | 0.50 | ~8.3 days | Checks phone, looks at the door |
| Drinks | 0.70 | ~6.0 days | Stares into an empty glass |
| Nightlife | 0.45 | ~9.3 days | Yawns, pyjamas by 9 pm |

Drinks is fastest on purpose. A week costs about 370 points in all.

| Rule | Value |
|---|---|
| New character | 75 (`START_VALUE`). OPEN: creator wireframe says 70 |
| Soft floor | Below 30, decay × `SOFT_FLOOR_FACTOR`. SUPERSEDED: GDD and code 0.5; DECISIONS (a) **0.3**. Code still 0.5 |
| Personality | One meter decays ×0.9 (Night Owl, Music Nerd, Social Butterfly, Easy Sipper) |
| Out of Town | Freezes decay up to 14 days, once per 30 days (extended in section 5) |
| Debug clock | 1 real minute = 1 game hour, debug builds only |

With the 0.3 floor, 100 to Empty (below 10): Drinks 8.1 d, Music 10.3 d, Friends 11.4 d, Nightlife 12.7 d.

**Vibe** is the average of the four, shown as a word and a candle: 80 to 100 **Glowing** (rim light, +25% memory
chance, Spotlight eligible), 50 to 79 **Good**, 25 to 49 **Meh** (a "missing it" line each visit), 0 to 24
**Homebody** (pyjamas; next visit triggers Welcome Back).

**Refill table** (base gains; score-scaled = low at a poor score, high at a perfect one, never zero).

| Action | Zone | Gain | Limit / note | FP |
|---|---|---|---|---|
| Order a drink | Bar | Drinks +15 | First each visit free; then coins | Yes |
| Pour Perfect / Shake & Serve | Bar | Drinks +20 to 30 | Always free | PP yes |
| Try a new drink | Bar | Drinks +5 | Drops a coaster | Yes |
| Listen to a song | Stage, Candle Floor | Music +5 | Passive | Yes |
| Full set (4 songs) | Stage | Music +5, Nightlife +5 | | Yes |
| Front Row Rhythm | Stage | Music +8 to 12 per song | | Yes |
| Applaud / request | Stage | Music +2 | Cap +6 a visit | Applaud |
| Headline set (70%+) | Stage | Music +40, Nightlife +20 | Fri/Sat | |
| Candle Talk | Candle Floor, Banquette | Friends +10 to 20 | Once per regular per day; +5 lean bonus (approved, not coded) | Yes |
| Sit 60 s with someone | Any table | Friends +8 | Once per character per day | Yes |
| Receive a social verb | Any | Friends +2 | Cap +10 a visit | |
| Quiz / Name That Tune | Long Table | Music +5, Friends +10 to 15 | | |
| Dance 30 s | Dance floor | Nightlife +3 | Cap +15 a visit | Emote |
| Dance-off | Dance floor | Nightlife +12 to 20 | | |
| Pinball | Lounge | Nightlife +10 to 20 | | Yes |
| First time in the Lounge | Lounge | Nightlife +5 | Once a visit | Yes |
| Stay to the last song | Any | Nightlife +10 | Headline nights | |

GDD sample visit: Music +25, Friends +23, Drinks +40, Nightlife +26; costs 0 coins.

**Diminishing returns.** Per meter per visit: first 40 points full, 41 to 80 at 50%, beyond 80 at 25%. Per Bangkok
day: 1st visit ×1.0, 2nd ×0.75, 3rd+ ×0.5. A visit ends on leaving or after 10 minutes idle. At 100, gains become
**Tab** (progression points) 1:1. No hard caps.

**Welcome Back.** First visit after Vibe below 25, after 7+ days away, or rescuing a declining character: greeting
by name, first drink free, gains ×2 for 15 minutes (diminishing returns still apply), 10 coins. DECISIONS (b) says
×2 replaces the daily ×0.75; `needs.gd` currently multiplies both. Copy never says "abandoned / neglected / forgot /
die / dead".

**Notifications** (out of the FP). Opt-in, default on, max 2 a week. Lowest meter crossing 40: one character line.
Friday 18:00: tonight's headliner (OPEN: GDD says local time, DECISIONS says Bangkok everywhere). Never about a
meter at 0; never after 22:00 local. Last Call has one exception (section 5).

Source files: `docs/design/02-gdd.md` §2, `game/scripts/rules.gd`, `game/scripts/needs.gd`,
`docs/design/06-stakes.md` §5.

---

## 5. Stakes: mandatory care and Last Call

`06-stakes.md` is draft v1 (2026-10-28) implementing "Neglect is fatal". Its numbers await sign-off; none are in
code.

**Fiction.** Nobody gets sick. The character stops going out, then **leaves Bangkok**. The system is called **Last
Call** (English in both languages). Final: no revive, no coins, no paid restore. Flat chip: "Thinking of leaving · 3
days". Title card: "[Name] has left Bangkok." A letter by personality (Night Owl: "Took a day job in Chiang Mai.
Early nights now."), ending "Left you my tab with Nam." Banned words extend to die, dead, death, kill, starve, sick.

**The two mandatory rules.**

| Rule | Minimum | If broken |
|---|---|---|
| A. Night Out | One qualifying visit in any 7 real days | Decline starts at day 7 |
| B. Every need touched | No meter Empty (below 10) for long; per-meter clock resets at 10+ | Decline starts on going Empty; Gone after 14 Empty days |

Qualifying visit: 5+ real minutes (idle excluded) and 2+ refill actions. A visit in progress blocks Gone.
Driver: `stake_days = max(since_night_out, longest_empty_days + 7)`.

**Decline timeline.**

| Stage | `stake_days` | Character / Flat | Notification |
|---|---|---|---|
| Fine | 0 to 7 | As Vibe | None |
| Staying In | 7 to 12 | Homebody look; curtains drawn | Day 7 (inside the 2-a-week budget) |
| Fading | 12 to 17 | Faces the window, 30% desaturated; lamps dim | Day 12 (budget) |
| Packing | 17 to 21 | Packs a suitcase; one wall pin down a day | Day 17 (budget); **Day 19 Last Call warning outside the budget**, moved to 19:00 if in quiet hours |
| Gone | 21+ | Empty flat, keys and the letter | None |

| Player | Outcome |
|---|---|
| 3 sample visits a week | Always Fine |
| 1 sample visit a week | Staying In for ~3 days before each visit, never Fading |
| 3 visits a week, zero Nightlife | Nightlife Empty ~day 10.3, Fading ~15.3, Gone ~24.3 |
| Never returns after creation | Gone on day 21 |

**Rescue** = any qualifying visit before Gone: resets the clock, triggers Welcome Back; from Packing also a "Close
Call" polaroid and the wall pins go back up. Staff and regulars send warm postcards at each stage.

**What survives Gone.**

| Kept | Lost |
|---|---|
| Memory Album (read-only chapter with the old name and dates) | Name, look, personality |
| Coins, wardrobe, frames, the Flat | Meters, Tab, Regular Rank |
| Real-world vouchers and raffle entries (account-level) | Hearts (seen story beats stay in the album) |
| | Minigame bests, stamp card, Memory Wall (reset with a farewell polaroid) |

In the venue, the old character's drink appears as a named coaster on the collectibles shelf (max 3) and their name
stays on the chalkboard. A new character gets no second 20-coin starting wallet or repeat memory and heart coins.

**Holiday mode.**

| Rule | Value |
|---|---|
| Out of Town | Freezes meters and both stake clocks; up to 14 days; 30-day cooldown |
| Long Trip | Once per rolling 365 days, up to 35 days |
| Yearly cap | 70 trip days |
| Allowed from | Fine or Staying In only |
| Real-bar check-in | Staff-verified visit to the real bar counts as a Night Out, lifts meters to 30, once a Bangkok day (post-FP) |

**Edge cases.** Clock forward: Gone needs trusted server time; offline the stage caps at Packing. Clock back: jumps
over 10 minutes count as 0. Uninstall: clocks keep running; FP local saves are lost. Fresh start: voluntary **Move
On**, two confirmations, once per 30 days. Server outage: all clocks freeze. The chapter specifies 17 tests and
constants such as `EMPTY_BELOW 10`, `NIGHT_OUT_MIN_MINUTES 5`, `LAST_CALL_NOTIFY_HOURS_BEFORE 48`,
`LONG_TRIP_MAX_DAYS 35`, `TRIP_DAYS_PER_YEAR 70`.

OPEN (06-stakes §8): 21/14 days or 14/10; keep Rule B; quiet hours device-local or Bangkok; emergency retroactive
trip; coins and wardrobe surviving; real-bar check-in and its backend timing; Last Call by email or LINE; letter
reasons fixed or player-written; code floor to 0.3.

Source files: `docs/design/06-stakes.md`, `docs/design/DECISIONS.md`.

---

## 6. The venue

Layout, from the three direction renders (the only layout source): **entrance lounge → curtain → main room**.
Entering the main room through the curtain: stage on the left, bar along the right, round tables and the communal
table at the back. SUPERSEDED: the first integration pass followed the mockup and is being re-laid.

| GDD zone | Real room / render | Offers | Need | FP |
|---|---|---|---|---|
| Entrance | Orange sign doorway (photos); in the build the lounge is the arrival room | Notice board, guestbook | None | Yes |
| The Bar | Backlit amber shelves (R01, R03) | Bartender, drinks, Pour Perfect, coasters | Drinks | Yes |
| Stage & Front Row | Red-carpet corner stage, slatted backdrop | Sets, Front Row Rhythm, Open Mic | Music | Yes |
| Candle Floor | Round tables, lamps, drum-stools | Sit, Candle Talk, listening | Friends, Music | Yes |
| Velvet Banquette | Red tufted banquette (photos; DECISIONS (i)) | Quiet Candle Talk, story beats | Friends | Dressing |
| Long Table | Communal tables, north wall | Quiz Night, group games | Friends | Dressing |
| Dance Floor | Under the disco ball | Dancing, Dance-off | Nightlife | Emote |
| The Lounge | Red neon on a plant wall, beams, arcade cabinet, CRT (R02) | Pinball, CRT, hangout | Nightlife | Yes |
| Staircase | Stairs up from the lounge (R02) | "Coming soon: upstairs" | None | Walkable |

The layout never moves; lighting, performers, regulars, seasonal dressing and the featured drink change.

**As built** (`game/scenes/venue/venue.tscn`, generated from the kit, metres):

| Node | Extent | Contents |
|---|---|---|
| Lounge | x 0 to 10 | Neon sign, plant wall, 4 banquette modules, long table, columns, CRT, arcade cabinet, collectibles shelf, red ceiling panels |
| Stairs | West wall | 12 steps to a 2.4 m landing |
| Curtain | x 10 | Curtain partition, exit sign |
| MainRoom | x 10 to 30 | Floor, walls, track lights, disco ball |
| Bar | South wall | 10 shelves, 10 counter units, 8 stools |
| Tables | Middle | 6 round tables, 18 chairs, 6 drum-stools; clear aisle to the stage |
| CommunalTable / Banquette | North wall | 2 long tables, 12 chairs / 4 banquette modules, 2 tables |
| Stage | x 24 to 30, 0.5 m high | Drum kit, amps, guitar, 3 mics, truss with red/amber/blue PARs, stage tree, PA |

`layout.json` lists 335 kit instances and 65 person spawns. Room height 4 m; 26 dynamic lights, 2 with shadows.

**Kit objects by zone (52).**

| Zone | Objects |
|---|---|
| bar (10) | bar_counter, back_bar_shelf, bottle_amber/green/clear, bar_stool, soffit_segment, painting_a/b/c |
| tables (8) | round_table, communal_table, cafe_chair, drum_stool, table_lamp_lit/unlit, tealight_lantern, napkin_cup |
| stage (17) | stage_platform, stage_carpet_tile, stage_steps, slatted_backdrop, curtain_panel, drum_kit, guitar_on_stand, amp, mic_stand, monitor_wedge, disco_ball, truss_segment, par_light_red/amber/blue, stage_tree, pa_speaker |
| lounge (12) | neon_sign, plant_wall_tile, white_column, beam_segment, ceiling_panel, arcade_cabinet, collectibles_shelf, crt_monitor, banquette_straight/corner, ac_unit, wall_lamp |
| circulation (5) | stair_run, exit_sign, track_light, floor_tile_a/b |

Source files: `docs/design/02-gdd.md` §4, `docs/art/direction/README.md`, `game/README.md`,
`game/assets/kit/manifest.json`, `game/assets/kit/layout.json`.

---

## 7. Cast

NPC rules: nobody needs rescuing, no quests, no rejection or guilt, one signature item and spot each. Real people
are **slots**: a working name the real person replaces if they consent. The room always shows 12 to 20 bodies.

**Staff.**

| Slot | Working name | Role | FP |
|---|---|---|---|
| `BAR_1` | Nam (น้ำ) | Head bartender; orders, Pour Perfect, Welcome Back, water at Merry | Yes |
| `BAR_2` | Fern | Second bartender, Fri/Sat from 20:00 | |
| `DOOR` | Big | Door host, announces the lineup | Post-FP |
| `SOUND` | Golf | Sound engineer, soundchecks, disco ball | Ambient |
| `OWNER` | Khun Joy | Rare; house toast | |

Black Cabin must supply, per consenting person: signed consent, photos (front, side, back, face), nickname in Thai
and English, signature drink, one true story, 2 to 3 real catchphrases, one habit. Owner adds founding story,
anniversary date and toast.

**Regulars.** On a usual night present 90% of the time, else 25%. Early = 18:00 to 23:00, Late = 21:00 to close.

| Regular | Who | Nights | Home zone | Need | FP |
|---|---|---|---|---|---|
| Tong | Music nerd who never plays | Wed Thu Fri, Late | Front-row poufs | Music | Yes |
| Ploy | Architect who sketches the room | Mon Tue Thu Sun, Early | Candle Floor | Friends | Yes |
| Jules | French pinball champion | Thu Fri Sat, Late | Lounge, arcade cabinet | Nightlife | Yes |
| Mali | Quiz captain | Tue Thu Sat, Early | Long Table | Friends | |
| Dougie | Scottish retired roadie | Mon Wed Fri Sun, Early | Bar end stool | Drinks | |
| Lung Nop | Retired FM radio DJ | Thu Sun, Early | Banquette | Music | |
| Bow | Flight attendant | Fri Sat + 1 random, Late | Dance Floor | Nightlife | |
| Hiro | Highball perfectionist | Tue Thu Sat, Late | Bar middle stool | Drinks | |

The three FP regulars cover every day. Hearts 0 to 3 in the FP; each heart plays a story beat; at 2 hearts they wave
and save a seat; at 3 they give a memory. OPEN: hearts 4 to 5 at launch.

**Performers.**

| Act | Genre | When | FP |
|---|---|---|---|
| The House Lights (Jo, Pete, Boy) | Soul-pop covers | 4-song sets every ~8 minutes, every night | Yes |
| The Thursday Club | Jazz trio | Thursday | |
| Monsoon Funk Unit / Plaa Thong / Soi Dog Blues | Funk / Thai dream indie / blues | Headline Fri/Sat, rotating | |
| Fah | Singer-songwriter | Slow Sunday | |
| DJ Moo Krob | Thai funk and disco vinyl | Fri/Sat 23:00 to close, lounge | |

One performer unit: 2 to 4 voxel members, 6 to 10 songs of 60 to 90 s with beat maps, banter, a memory, a band tee.
Most urgent ask: if Black Cabin has a resident band, the House Lights should be them.

**Tipsiness** (alcoholic drinks only, per visit; one state drops every 30 real minutes; water drops one at once).

| State | Drinks | Look | Gameplay |
|---|---|---|---|
| 0 Clear | 0 | Normal | None |
| 1 Warm | 1 to 2 | Bounce, sway, light blush | Dancing ×1.1 (proposal) |
| 2 Tipsy | 3 to 4 | Loose weave, leans on the bar | Candle Talk "Loose Lips" card |
| 3 Merry | 5+ | Slow, sings along | Nam serves water and mocktails only; taxi home |

No state lowers a reward. Never shown: vomiting, falling, fights, driving, pressure to drink, hangovers.

Source files: `docs/design/03-cast.md`, `docs/design/02-gdd.md` §5, §6.

---

## 8. Minigames

Shared rules: one thumb, 10 to 180 s, no fail screen, local best shown, always optional. The result card shows a
three-word tier (good, great, perfect; great from score 0.6, perfect from 0.85).

| # | Minigame | Zone | Need | Duration | FP |
|---|---|---|---|---|---|
| 1 | Pour Perfect | Bar | Drinks +20 to 30 | 20 to 30 s | Yes |
| 2 | Shake & Serve | Bar | Drinks +20 to 30, Friends +5 | 45 to 60 s | |
| 3 | Front Row Rhythm | Stage | Music +8 to 12 per song | 60 to 90 s | Yes |
| 4 | Open Mic | Stage | Music +15, Nightlife +10 | 90 s | |
| 5 | Candle Talk | Candle Floor | Friends +10 to 20, hearts | 60 to 90 s | Yes |
| 6 | Name That Tune | Long Table | Friends +10 to 15, Music +5 | 2 min | |
| 7 | Coaster Flip | Long Table | Friends +8 to 12 | 30 s | |
| 8 | Toast Chain | Any table | Friends +3 each (max 12) | 10 s | |
| 9 | Dance-off | Dance Floor | Nightlife +12 to 20 | 60 s | |
| 10 | Neon Pinball | Lounge | Nightlife +10 to 20 | 1 to 3 min | Yes |
| 11 | CRT Channel Surf | Lounge | Nightlife +5, Music +5 | 30 s | |
| 12 | Setlist Shuffle | Stage | Music +10 | 60 to 90 s | |

**Pour Perfect.** Controls: hold anywhere to pour, release on the line. Build: 3 layers with targets at 30%, 58% and
82% of the glass; 30 s limit; overfill foams and costs at most 0.3 of the score. OPEN: plays in 17 to 20 s versus
the GDD's 20 to 30.

**Front Row Rhythm.** Controls: tap the left or right half on the beat. Build: 4 beat-map songs rotating by day,
4-beat count-in, perfect window 0.07 s, good 0.14 s, one song per round. The GDD's three difficulties are not built,
and there is no live set yet for it to raise Crowd Vibe. OPEN: +8 to 12 per song "feels small".

**Candle Talk.** Controls: tap one of three topic cards. Build: 5 turns; best card lights the candle fully, a near
card half; story lines appear only once the candle is at 2+; hearts 0 to 3 saved; it reports a "lean" flag but
`rules.gd` has no lean action. OPEN: only Mali's script exists, though the FP regulars are Tong, Ploy and Jules.

**Neon Pinball.** SUPERSEDED: GDD "pinball table"; DECISIONS (c) puts it on the arcade cabinet's screen. Controls:
hold a half for its flipper, swipe up (or tap) to launch, swipe sideways to nudge (with tilt). Build: 3 balls, 10 s
ball save, 180 s cap; BLACK CABIN letters 250 points each, word bonus 1,500. OPEN: 3,000 points = full score is "a
guess".

All four run inside a shared frame and result card that calls `Needs.apply_action` once, and in a **minigame lab**
scene. Screenshots: `docs/art/screens/2026-10-27-minigames/` (lab, each game, result card, Thai lab). They are not
yet reachable from the venue.

Source files: `docs/design/02-gdd.md` §9, `docs/ui/wireframes.md` §7, `game/scripts/minigames/`,
`ORCHESTRATION.md` wave 3b.

---

## 9. Coins

`04-coins.md` is draft v1 (2026-10-28); it replaces the GDD's "Cabin Tokens" (SUPERSEDED). DECISIONS still lists the
economy as open. Nothing is coded.

**Role.** "The tab you run at your local": coins buy choice and, through the bridge, a small real thank-you. They
never gate a refill, never buy freezes, multipliers, hearts or memories, never decorate the venue, are never lost
(no expiry, cap or neglect penalty), never create time pressure, never make alcohol cheaper than non-alcohol, never
look like baht and never move between players.

**Earning** (per-visit sources take the daily ×1.0 / ×0.75 / ×0.5).

| Source | Coins | Limit | FP |
|---|---|---|---|
| First visit of the Bangkok day | 10 | Once a day | Yes |
| Minigame good / great / perfect | 2 / 3 / 5 | First 4 a visit, then 1 | Yes |
| Applaud a set | 1 | 2 sets a visit | Yes |
| Encore | 3 | Each | |
| New memory | 2 | 3 a visit | Yes |
| Heart gained | 10 | Each | Yes |
| Welcome Back gift | 10 | Each | Yes |
| Week Recap | 5 per day visited | Max 25 | Yes |
| Stamp card | 5 per stamp | Max 20 | |
| Starting wallet | 20 | Once per account | Yes |

Ceilings: **60 per Bangkok day, 250 per week** ("That's plenty for tonight").

| Weekly budget | Earns | Spends | Saves |
|---|---|---|---|
| 3-visit player | ~115 | ~35 | ~80 |
| 7-visit player | ~240 | | ~170 |

**Spending.** First drink of every visit is free (any drink); water and Pour Perfect always free. Every paid drink
is Drinks +15 through the same diminishing returns.

| Item | Price |
|---|---|
| Pour drinks (lager, Thai iced tea, coffee, soft drinks) | 4 |
| Mixed (highball, cocktails and their mocktails) | 6 |
| Signature (staff and regular signatures, featured drink) | 9 |
| Tip jar (Crowd Vibe +10, double request vote) | 3 |
| Buy a round (table +10 Drinks each, you Friends +5, once a visit) | 3 per person |
| Wardrobe small / mid / statement | 30 / 60 / 120 |
| Performer tee | 80 |
| Frames: plain / wood / brass / velvet / neon / poster | 0 / 20 / 35 / 35 / 50 / 50 |

**Zero-coin rule:** an empty wallet can still fill every meter to 100.

**Wallet UI.** Chip top right on the Flat, beside the Album button in the venue, hidden during sets and minigames.
Unaffordable rows say "Not tonight". No coin toasts or showers; one soft clink; the walk-out says "Coins +24".

**Real-world link.** Voucher 150 (1 a week), real drink 300 (1 a month), raffle entry 50 (3 per draw), song slot
100 (1 a month). Booking, calendar and table ordering never use coins. Details in section 10.

**Monetization stance** (recommendation, not a decision): coins are never sold for real money (21+ alcohol risk,
it would cheapen the bridge, and Black Cabin commissioned the game). If premium is needed, direct-price cosmetics
only. No loot boxes or gacha.

**FP cut:** wallet, FP earning sources, paid second drinks, tip jar, 3 frames (20 / 35 / 50) as the save-up goal.

**Constants:** `COIN_START 20`, `COIN_FIRST_VISIT_OF_DAY 10`, `COIN_MINIGAME_TIER [2,3,5]`,
`COIN_MINIGAME_FULL_PER_VISIT 4`, `COIN_HEART 10`, `COIN_WELCOME_BACK 10`, `COIN_CAP_DAY 60`, `COIN_CAP_WEEK 250`,
`DRINK_PRICE {0,4,6,9}`, `TIP_PRICE 3`, `ROUND_PRICE_PER_PERSON 3`, `WARDROBE_PRICE {30,60,80,120}`,
`REAL_PRICE {voucher 150, drink 300, raffle 50, song 100}`, `REAL_VOUCHER_DAYS 30`, `REAL_CODE_MINUTES 10`.

Source files: `docs/design/04-coins.md`, `docs/design/02-gdd.md` §12.

---

## 10. Real-world bridge

Confirmed by DECISIONS (2026-10-27):

| Feature | Coins side (04-coins §7) |
|---|---|
| Discounts | Voucher, 150 coins, 1 a week |
| Win merch | Monthly raffle, 50 per entry, 3 entries |
| Win drinks | 300 coins, 1 a month; needs a Thai legal check on alcohol prizes |
| Book tables | Free service, never coins |
| Real event calendar | Free service |
| Request songs | 100 coins, 1 a month, must be checked in at the bar |
| MAYBE order to the table | Real money only; a voucher may apply |

Redemption outline: claim in the app (voucher lasts 30 days; unused coins return) → "Use now" shows a rotating QR
and a 4-character code valid 10 minutes → staff scan or type it, "Mark used" → one redemption per account per
Bangkok day. Anti-abuse: server ledger only, verified phone, single-use codes. Backend: **Supabase**. Black Cabin
owns the catalogue, monthly budget, staff training and legal check. 06-stakes adds a real-bar check-in that counts
as a Night Out.

OPEN: the bridge **design chapter is pending** (redemption flow, staff verification, what bookings and song requests
need from Black Cabin's systems).

Source files: `docs/design/DECISIONS.md`, `docs/design/04-coins.md` §7, `docs/design/06-stakes.md` §2.3.

---

## 11. Memories, wardrobe, the Flat, progression and live-ops

**Memories.**

| Type | Earned by | Launch count |
|---|---|---|
| Polaroid | Authored moments and random candids | ~40 triggers |
| Ticket stub | Sets, events, encores | 1 per performer + events |
| Coaster | First taste of each drink | 24 |
| Setlist | Hearing a whole catalogue | 1 per performer |
| Postcard | Heart milestones, absences | ~3 per regular |

Authored triggers always drop first time; candids 10% per moment (+25% when Glowing), max 3 a visit. Nothing is
missable. Shown in the **Memory Album** and on the Flat's **Memory Wall** (12 pins; 6 in the FP). Monday **Week
Recap** card, shareable. FP: ~15 memories. Not built yet.

**Character creation and wardrobe.** Launch: 3 heights × 3 builds, 12 skin tones, 8 eyes / 6 brows / 6 mouths, 16
hair styles × 16 colours, 6 starter looks, ~60 items, 3 outfit presets, 4 personalities, Thai particle choice. FP: 3
bodies, 6 skin tones, 4 hair styles, 3 outfits. OPEN: skin tones (GDD 12, art bible and kit 8). SUPERSEDED: GDD
"the shop" is now a merch rail by the Entrance (coins).

**The Flat.** One small voxel room (bed, record player, door): check-in screen and Memory Wall; wall colour and 4
furniture swaps. OPEN: DECISIONS (h) keeps it, yet "Still open" lists "keep minimal or cut".

**Progression.**

| System | Rule |
|---|---|
| Tab | Every meter point gained, plus overflow |
| Regular Rank | Newcomer → Familiar Face → Regular → Local → Part of the Furniture (~2, 4, 8, 16 weeks); greetings, seat style, cosmetics, chalkboard name |
| Hearts | Per regular, 0 to 5 (FP 0 to 3) |
| Stamp card | 4 stamps: each meter to 80+ once a week |
| Minigame bests | Bronze, silver, gold |

Rank never drops while the character lives. No resetting streaks, energy timers or expiring rewards.

**Live-ops** (content added on a schedule after launch).

| Cadence | Adds |
|---|---|
| Weekly | Lineup, featured drink, stamp reward, 10 quiz questions |
| Monthly | 1 performer, 1 regular or story chapter, 8 to 12 cosmetics, 5 polaroids |
| Every 2 months | 1 minigame |
| Quarterly | Expansion: Upstairs, then rooftop, then back-alley stage |
| Seasonal | Halloween, Loy Krathong, New Year, Valentine's, Songkran, Black Cabin anniversary |

Source files: `docs/design/02-gdd.md` §7, §8, §10, §11, §14, `docs/design/04-coins.md`, `docs/design/06-stakes.md`
§4.

---

## 12. Art direction

**Visual thesis.** A crisp voxel diorama of a night-time music bar where saturated **red** light (stage carpet,
glowing slatted backdrop, velvet curtains, neon) fills the room and small **amber** cubes (lamps, tealights,
backlit bottles) mark every seat. Cubes stay cubic, with per-voxel colour jitter and glossy surfaces, like a toy
model; darks are warm red-browns, never black. (Art bible v1 read the photos amber-first; v2 follows the renders.)

**Direction files** (`docs/art/direction/`):

| File | Shows |
|---|---|
| `01-main-room-from-entrance.webp` (R01) | Main room toward the stage; tables left, bar right, curtains, disco ball |
| `02-entrance-lounge.webp` (R02) | Lounge: neon on the plant wall, beams, arcade cabinet, stairs; curtain to the main room |
| `03-main-room-from-bar.webp` (R03) | From the bar end: tables, drum-stools, red stage |
| `04-overall-look-mockup.webp` | Interface style only (dark HUD, glyphs, need bubbles); map and HUD functions are not the design |

**Voxel rules.** 1 voxel = 5 cm, one resolution, no smoothing or bevels; room 80 voxels high on a 20 × 20 module;
nothing thinner than 1 voxel; round things are stepped pixel circles (below 5 voxels, squares); ±2 steps colour
jitter and a dark seam per voxel; tables, bar and floor glossy, fabrics matte. Never voxel: glow, haze, shadows,
particles, UI.

**Palette (game values).**

| Name | Hex | Name | Hex |
|---|---|---|---|
| Cabin Dark | `#1C0D0C` | Neon Red | `#FF2A14` |
| Beam Black | `#160A0C` | Neon Halo | `#F06A2A` |
| Ceiling Plum | `#2A0E12` | Drum Red | `#9A2A1A` |
| Stool Black | `#221110` | Lamp Gold | `#FFDD78` |
| Floor Grey | `#3A2C30` | Tealight | `#F7DB71` |
| Floor Lit | `#7A5248` | Shelf Amber | `#FF8A30` |
| Column White | `#E4DDE6` | Soffit Peach | `#E8814A` |
| Velvet Shadow | `#3E0408` | Cymbal Gold | `#E8A030` |
| Velvet Red | `#8C0610` | Table Wood Lit / Wood Mid | `#B5582C` / `#6E3522` |
| Carpet Red | `#9A0A12` | Wood Dark / Bar Front | `#3F1A10` / `#5E1C10` |
| Slat Red | `#D0161C` | Exit Cyan / Screen Cyan | `#2AE6F5` / `#18D0FA` |
| Panel Red | `#B80A10` | Stage Blue / Plant Green | `#20A8F0` / `#2E3A1A` |

Ratios: base 45 to 55%, red 25 to 35%, warm 15 to 20%, cool 3% or less. OPEN: the kit re-derived the wood values
(`#946446`, `#5E3E2A`, `#36241A`, `#4E2A1C`) and needs sign-off.

**Lighting model.** (1) Red stage and neon: the room colour, reflected in the glossy floor. (2) Amber bar: the warm
horizon of backlit shelves and soffits. (3) Table lamps and tealights: the heartbeat, a warm pool on every table;
tealights flicker ±8% at 1 to 2 Hz. Medium bloom, light haze over the stage, mild vignette. Time states: Day (work
lights), Evening (the renders), Late night (amber −30%, more red, disco sparkles).

**Character style.** Chibi voxel, 30 voxels (1.5 m) tall, head 12 × 12 × 11, no fingers, pixel-decal faces. Must
not rely on red to read; warm rim light on everyone. The head silhouette is the identity; no two regulars share
one. Staff wear Cabin Dark with Cymbal Gold trim.

**Style anchor**, attached verbatim to every image prompt (quoted exactly, so it keeps its original dash):

```
STYLE ANCHOR — BLACK CABIN
Detailed voxel diorama of an intimate live-music bar at night, every surface built from small visible cubes with thin dark seams and slight per-cube color variation, no smoothing. Saturated red light dominates: red carpeted stage, glowing red slatted backdrop, red velvet curtains, red neon. Warm amber accents: glowing cube table lamps and tealight cubes on wooden tables, backlit amber bottle shelves behind the bar. Glossy grey tiled floor reflecting red and amber. Dark warm ceiling with black beams and small track spotlights, a voxel mirror disco ball. Tiny cyan exit signs as the only cool color. Medium bloom on light sources, light haze. Wide interior view, elevated eye level, sharp focus, cozy and theatrical.
```

Anti-references: Minecraft textures, bright pastel cozy rooms, pink-and-cyan cyberpunk.

**Renders and screenshots.** `docs/art/review-overview.png` (the combined Blender review), `kit-showcase.png`,
`chars-showcase.png`, `chars-showcase-godot.png`; `docs/art/screens/2026-10-27-integration/` (portrait and
landscape of bar, entrance, floor, lounge, stage, hud, eye-level R01 to R03, `portrait-gameplay-sheet.png`,
`compare-renders-vs-game.png`); `docs/art/screens/2026-10-27-minigames/`.

Source files: `docs/art/art-bible.md`, `docs/art/direction/README.md`.

---

## 13. Interface

**UI thesis.** "The room is the light; the UI is the table it sits on." Dark warm panels, cream text, one accent at
a time; UI never glows brighter than a tealight, never covers the character's zone, and shrinks during a set. UI is
smooth, the world is voxel. No bounce or elastic motion.

**Fonts.** Display: **Kanit** 600/700. Text: **IBM Plex Sans Thai Looped** 400/500/600. Fallback Noto Sans Thai
Looped → Noto Sans → Noto Color Emoji. Free OFL licences, Latin and Thai. Not in the repo yet. OPEN: Black Cabin
brand typeface. The neon wordmark is a logo asset, never typeset.

**Meter component.** Fixed order Music, Friends, Drinks, Nightlife.

| Need | Glyph | Colour |
|---|---|---|
| Music | Eighth note | Slat Red `#D0161C` |
| Friends | Two heads | Lamp Gold `#FFDD78` |
| Drinks | Coupe glass | Shelf Amber `#FF8A30` |
| Nightlife | Moon with a spark | Screen Cyan `#18D0FA` |

Full meter (Flat, recap, walk-out): 40 dp glyph and an 8 dp bar. Compact (HUD): four 36 dp rings. No numbers unless
Settings > Show numbers. Low (25 to 39): 70% opacity, and only the single lowest meter breathes (2.4 s). Very low
and Empty stay calm: never red, never shaking. Vibe shows as a word and a candle.

**Screens (wireframes).**

| # | Screen | # | Screen |
|---|---|---|---|
| 1 | The Flat (check-in) | 6 | Performance in progress |
| 2 | Character creator (lite) | 7a to 7d | The four FP minigames |
| 3 | Venue HUD | 8 | Memory drop toast |
| 4 | Zone interaction sheet | 9 / 9b | Memory album / wall of six |
| 4b | Walk-out summary | 10 | Week Recap card (9:16 shareable) |
| 5 | Candle Talk dialogue | 11 | Settings |

The zone sheet lists things you'd do there, not meter buttons. Design frame 390 × 844 dp ("dp" is a screen unit that
keeps the same physical size across phones); tap targets 48 dp minimum; top of screen for reading, bottom 40% for
doing. Landscape re-flows the same screens: a 420 dp left column, side panels, minigames in a centred 9:16 area.
OPEN: wireframes call the bartender "Noi"; the cast names `BAR_1` Nam.

**Thai rules.**

| Rule | Value |
|---|---|
| Line height | ~1.6 to 1.65× font size (Latin 1.3 to 1.4×); +2 dp padding; never clip Thai |
| Breaking | Godot TextServerAdvanced dictionary breaking; zero-width spaces allowed |
| Style | No tracking, fake bold or italics; minimum 13 dp, dialogue 15 dp |
| Writing | A native Bangkok writer writes Thai from context, never literal translation |
| Strings | `strings.csv` columns `key,en,th,context,max`; named placeholders; Buddhist Era years in Thai |
| Brand | BLACK CABIN always in Latin capitals |
| Voice | Warm, short, no guilt words in either language |

Proposed (OPEN): minigame names stay English with a Thai subtitle; `docs/ui/glossary.csv` not created.

Source files: `docs/ui/style-guide.md`, `docs/ui/wireframes.md`, `docs/ui/strings-guidelines.md`.

---

## 14. Tech and pipeline

**Engine.** Godot 4.6.1, Compatibility renderer (simplest, OpenGL-based; runs on web and low-end phones), Web export
first-class. Chosen because Ooze Syndicate already proves the pipeline: web export, WebSocket relay, headless room
host, Supabase accounts, headless tests, Blender kit. The web-native alternative wins only on first-load size (Ooze's
web build is ~90 MB; target under 25 MB). Godot is not on PATH; use
`H:\My Drive\PROJECTS\Ooze Syndicate\Tools\Godot\Godot_v4.6.1-stable_win64.exe`.

**Project layout.**

| Path | Holds |
|---|---|
| `game/project.godot` | 1080×1920 base, stretch expand, `hdr_2d=true`, `Needs` autoload |
| `game/scripts/` | `rules.gd`, `needs.gd`, `save.gd`, camera, player, venue, `minigames/` |
| `game/scenes/` | `main.tscn`, `venue/`, `player/`, `minigames/`, `ui/` |
| `game/assets/kit/`, `game/assets/chars/` | Voxel GLBs, manifests, `layout.json` |
| `game/tools/`, `game/tests/` | Venue generator, capture, layout export; headless tests |
| `tools/blender/` | `bc_kit.py`, `bc_chars.py`, `bc_review.py` |

**Kit pipeline.** `bc_kit.py` (headless Blender 5.2.2) builds each object from a voxel grid, merges faces greedily
(v1's 35 objects fell from 114,822 to 12,532 triangles), applies one jitter-and-seam texture and exports a GLB per
object plus `manifest.json`. `game/tools/build_venue.gd` then generates `venue.tscn` (hand edits are overwritten)
and `export_layout.gd` writes `layout.json`.

**Character pipeline.** `bc_chars.py` builds chibi characters on an 8-bone rig: 28 presets (8 regulars, 5 staff, 3
House Lights, 12 patrons), 75 parts per body, 13 animations (idle, walk, sit, cheers, applaud, dance, Warm/Tipsy/
Merry variants, idle_sad). `PatronFigure.set_look({"preset": "nam"})` swaps a placeholder for a preset.

**Review .blend files.** `blender/BlackCabin.blend` is the one to open: VENUE, KIT and CHARACTERS collections with a
camera each; it renders `docs/art/review-overview.png`. `BlackCabinKit.blend` and `BlackCabinChars.blend` are the
per-pipeline files. Rule: every generator saves a review `.blend`; after a kit or character change, rerun
`bc_review.py`.

**Tests** ("headless" = the engine runs without a window; exit code 0 = pass), from `game/`:

```
godot --headless --path . --script res://tests/test_needs.gd
godot --headless --path . --script res://tests/test_minigames.gd
godot --headless --path . --script res://tests/smoke_hud.gd
godot --headless --path . --script res://tests/smoke_tap.gd
godot --headless --path . --script res://tests/smoke_stairs.gd
```

Run on 2026-10-28 for this manual: all five pass (92 needs checks, 818 minigame checks; tap-to-move reaches all four
camera zones; joystick walk reaches the stage).

**Session and wave model.** One orchestrator plans, briefs, reviews and merges, writing no content. Workers do one
deliverable each on a `bc/<slug>` branch, open a PR to `main` and report back.

| Wave | Contents | Status |
|---|---|---|
| 1 | Concept + GDD, art bible, engine + greybox | Done |
| 2 | Cast, UI guide + wireframes, venue kit, needs prototype | Done |
| 3a | Venue integration, kit v2, character kit, minigames | Done; venue layout being corrected to renders 01 to 03 |
| 3b | Zone wiring, creator + Flat, performance system, memories; FP assembly; real-device test | Not started |
| 4 | Multiplayer on Ooze's relay + Supabase | After the FP is fun |

| Emoji | Area | Emoji | Area |
|---|---|---|---|
| 🎛️ | Orchestrator | 🖼️ | UI |
| 🎲 | Game design | 🧱 | Venue kit |
| 🎨 | Art | 🎮 | Gameplay in-engine |
| 🛠️ | Tech | 🌐 | Multiplayer |
| 🎭 | Cast and characters | | |

Source files: `docs/tech/01-engine-decision.md`, `game/README.md`, `tools/blender/README.md`,
`game/assets/chars/README.md`, `ORCHESTRATION.md`.

---

## 15. Status and open questions

**Built and tested on `main` (head `e5785ae`).**

| Area | Commits | What runs |
|---|---|---|
| Needs | `184e394` | Decay, floor (0.5), personality, diminishing returns, daily multiplier, Welcome Back, Tab, Out of Town, save/load, debug clock and HUD |
| Minigames | `f749960` | Four FP games, frame, result card, lab, string loader |
| Venue | `f26a150`, `76ba8aa`, `71f68b2` | Kit-built room, lighting, diorama camera (4 zones), tap-to-move, crowd (9 seated, Nam, 3 wanderers), both orientations captured |
| Kit, characters | `9ee9148`, `9b0141b`, `0cf04ea` | 52 objects; 28 presets, 13 animations |
| Review file | `e5785ae` | `blender/BlackCabin.blend` |

**Designed only:** Last Call (`403a2c1`), coins (`ac0be50`), bridge, memories, the Flat, creator, zone wiring
(minigames unreachable from the venue), performances and schedule, regular behaviour, events, notifications,
wardrobe, fonts, Thai native pass, backend, multiplayer. The GDD amendments in `04-coins.md` §10.1 and `06-stakes.md`
§5 are not yet applied to `02-gdd.md`.

**Code versus decisions:** floor 0.5 not 0.3; Welcome Back stacks with the daily ×0.75; no lean-bonus action; fonts
missing.

**Every OPEN item.**

1. Orientation: landscape or portrait primary.
2. Black Cabin's opening hours and what the game shows at 14:00.
3. Staff turnover if a real person leaves.
4. Brand typeface.
5. Last Call: 21/14 or 14/10 days; Rule B; quiet-hours time zone; emergency trip; coins and wardrobe surviving;
   real-bar check-in; email/LINE warning; letter reasons.
6. Coin economy sign-off, including "never sold for real money".
7. Real-world bridge chapter (redemption, staff verification, booking and song requests, order-to-table, legal).
8. Multiplayer chat policy.
9. The Flat: kept by (h), still listed open.
10. Hearts 4 to 5 at launch.
11. Starting meters 75 or 70.
12. Bartender "Noi" (wireframes) versus Nam (cast).
13. Candle Talk content only for Mali; FP needs Tong, Ploy, Jules; Mali's Thai is machine-drafted.
14. Minigame tuning: Pour Perfect length, pinball mapping, Rhythm gains, difficulty picker.
15. Skin tone count: 12, 8 or 6.
16. Kit deviations from the art bible (wood values, banquette channels, lamp tiers, size classes).
17. Headline notification time zone.
18. Notification budget of 2 a week, never confirmed.
19. English minigame names with Thai subtitles; glossary file.
20. Web export size baseline not recorded.
21. Music licensing and beat maps per performer.
22. Premium cosmetics or no monetization beyond the commission.

**Asks for Black Cabin.**

| Priority | Ask |
|---|---|
| 1 | Who agrees to appear, with signed consent |
| 2 | Resident band: names, photos with instruments, 4+ songs with licence status, real set |
| 3 | Head bartender pack: photos, nickname TH/EN, signature drink, story, catchphrases |
| 4 | Door, sound, owner packs (owner adds founding story, anniversary, toast) |
| 5 | Up to six acts and the night they really play |
| 6 | Opening hours and the real weekly calendar |
| 7 | Bridge: reward catalogue, monthly budget, staff verification, legal advice |

Source files: `docs/design/DECISIONS.md`, `docs/design/03-cast.md` §7, `docs/design/04-coins.md`,
`docs/design/06-stakes.md` §8, `ORCHESTRATION.md`.

---

## 16. Glossary

| Term | Meaning |
|---|---|
| Art bible | The visual rulebook: voxel scale, palette, lighting, characters |
| Autoload | A Godot script loaded once at start and reachable everywhere (here `Needs`) |
| Beat map | A file of note timings for a rhythm game |
| Bloom | A soft halo around bright lights |
| Compatibility renderer | Godot's simplest renderer; runs on web and low-end phones |
| Diminishing returns | Extra points in one visit count for less |
| Diorama camera | A fixed-angle elevated camera framing one zone like a model in a box, following the character |
| dp | A screen unit that keeps the same physical size across phones |
| Emissive | A material that glows by itself |
| FP | First playable |
| GDD | Game Design Document, the main design spec |
| GLB | The 3D file format exported from Blender and imported into Godot |
| Greybox | A rough block-out of a level for testing space before real art |
| Headless test | A test that runs the engine without a window |
| Kit | The library of reusable 3D objects the venue is built from |
| Last Call | The neglect system ending with the character leaving Bangkok |
| Live-ops | Content and events added on a schedule after launch |
| Navmesh | The walkable-area map used for path-finding |
| PAR light | A stage spotlight can |
| Preset | A ready-made character assembled from kit parts |
| R01 to R03 | Daniele's three direction renders |
| String table | The CSV holding all on-screen text in English and Thai |
| Supabase | Hosted database and accounts service; the planned backend |
| Style anchor | A fixed text block added to every image prompt to keep the look consistent |
| Tab | Progression points from every meter point gained |
| Tap-to-move | Tap the floor and the character walks there |
| Vibe | The average of the four meters, shown as a word and a candle |
| Voxel | A cube-shaped 3D pixel, here 5 cm |
| Wave | A batch of worker sessions run in parallel |
| Welcome Back | The return bonus: free drink, ×2 gains for 15 minutes, 10 coins |

Source files: all of the above.
