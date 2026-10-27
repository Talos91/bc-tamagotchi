# Black Cabin Tamagotchi — Portrait Wireframes

Status: v1, 2026-10-27. Owner: session 2B. Components, colours, type and
motion are defined in `style-guide.md`; string keys and length budgets in
`strings-guidelines.md`. Scope follows GDD §14 (first playable) unless a
screen says "later".

## Conventions

- Frames are 36 characters wide, drawn at the 390 x 844 dp portrait frame
  (roughly 11 dp per column, 25 dp per row). Proportions are indicative;
  dp values in the tables are binding.
- `~~~` rows are the unsafe areas (notch / status bar on top, home indicator
  at the bottom). The 3D scene renders under them; UI does not.
- `[ LABEL ]` is a button, `(x)` an icon button, `[###---]` a meter bar,
  `(M)(F)(D)(N)` the compact meter rings for Music, Friends, Drinks,
  Nightlife. `*` marks the breathing lowest meter.
- Every tap target is at least 48 x 48 dp. Top third of the screen is for
  reading; the bottom 40% is for doing.
- **Needs** line per screen: which meters the screen shows (reads) or can
  change (refills).

---

## 1. The Flat (check-in)

The home screen and the 10–30 s check-in (GDD §3). No venue load.

```text
+------------------------------------+
|~~~~~~~~~~~~ status bar ~~~~~~~~~~~~|
| (gear)                  TUE 20:52  |
|   .----- the Flat (voxel) ------.  |
|   | [] [] []   memory wall (6)  |  |
|   | [] [] []                    |  |
|   |                record player|  |
|   |       (character, idle)     |  |
|   |            o_         door  |  |
|   |  bed      /|            |   |  |
|   '-----------------------------'  |
|  (candle) Vibe: Meh      (suitcase)|
|------------------------------------|
| (note)  MUSIC      [#####------]   |
| (heads) FRIENDS    [######-----]   |
| (coupe) DRINKS     [##---------] * |
| (moon)  NIGHTLIFE  [#######----]   |
|------------------------------------|
| TONIGHT  House band  . next set 6m |
| .--------------------------------. |
| | (postcard) Mali: "The long     | |
| | table missed you."         (>) | |
| '--------------------------------' |
| [          GO OUT  (door)        ] |
|~~~~~~~~~~ home indicator ~~~~~~~~~~|
+------------------------------------+
```

| Element | Spec | Tap |
|---|---|---|
| Settings | icon button, top-left | 48 dp → Settings (§11) |
| Clock | `caption`, Bangkok time, day + hh:mm | none |
| Flat diorama | ~40% of height; character idles per lowest need's tell (GDD §2.1) | tap character: plays a mood line; tap a wall frame: opens Album on that memory |
| Vibe line | candle glyph + word | tap: meter detail sheet |
| Out of Town | suitcase icon | 48 dp → confirm dialog |
| Full meters | 4 rows, 44 dp each | whole block: meter detail sheet (what refills each need, where in the venue) |
| Tonight strip | `display.s` label + next set countdown (house set every ~8 min) | none in first playable |
| Postcard | card, one at a time, newest first | 56 dp row → postcard full view |
| GO OUT | primary, 56 dp, full width minus margins | → fade through Cabin Dark → venue Entrance (§3) |

**States**

- *First launch:* no meters yet → Character creator (§2) first.
- *Returning:* meters animate from last-seen to current value (600 ms, see
  style guide §4), then the lowest one starts breathing.
- *Welcome Back* (Vibe < 25 or 7+ days away): character in pyjamas, postcards
  stacked (up to 2), GO OUT label reads "Head back in", a gold chip under it:
  "First drink's on the house". No guilt copy.
- *Homebody:* candle unlit, character in pyjamas; otherwise identical.
- *Out of Town:* meters greyed, suitcase filled, GO OUT still works (going
  out ends Out of Town after a confirm).
- *All meters full:* Vibe Glowing, rim light on character, Tonight strip
  says what's on rather than nudging.

**Needs:** reads all four + Vibe. Refills none.

---

## 2. Character creator (lite)

Under 2 minutes; everything changeable later. First-playable options per GDD
§14: 3 bodies, 6 skin tones, 4 hair styles, 3 outfits, 4 personalities.

```text
+------------------------------------+
|~~~~~~~~~~~~ status bar ~~~~~~~~~~~~|
| (<)      MAKE YOUR CHARACTER       |
|   .-----------------------------.  |
|   |                             |  |
|   |     (character preview)     |  |
|   |      on red stage carpet    |  |
|   |     drag to turn  <  >      |  |
|   |                             |  |
|   '-----------------------------'  |
| BODY  SKIN  HAIR  OUTFIT  VIBE     |
| ====                               |
| .------. .------. .------.         |
| | short| | mid  | | tall |         |
| '------' '------' '------'         |
| .------. .------. .------.         |
| | slim | | avg  | | broad|         |
| '------' '------' '------'         |
|                                    |
| Name  [ Type a name...         ]   |
| [            DONE              ]   |
|~~~~~~~~~~ home indicator ~~~~~~~~~~|
+------------------------------------+
```

Personality tab (labelled VIBE in the tab bar; full title "Personality"):

```text
+------------------------------------+
| BODY  SKIN  HAIR  OUTFIT  VIBE     |
|                           ====     |
| .--------------------------------. |
| | (moon)  NIGHT OWL              | |
| | Nightlife fades slower.        | |
| '--------------------------------' |
| .--------------------------------. |
| | (note)  MUSIC NERD         (v) | |
| | Music fades slower.            | |
| '--------------------------------' |
| .--------------------------------. |
| | (heads) SOCIAL BUTTERFLY       | |
| '--------------------------------' |
| .--------------------------------. |
| | (coupe) EASY SIPPER            | |
| '--------------------------------' |
+------------------------------------+
```

| Element | Spec | Tap |
|---|---|---|
| Preview | top 40%, rotates by drag; plays an idle tied to the chosen personality | drag to rotate |
| Tabs | 5 tabs, `display.s`, 48 dp tall, underline on active | switch tab |
| Option tiles | 3 per row, 96 x 72 dp; swatches 48 dp circles, 6 per row | select; selected = Plum fill + gold edge |
| Personality cards | full width, 72 dp, glyph + name + one line | select one |
| Name | text field, 48 dp, 16 grapheme max, filtered | opens keyboard; sheet scrolls so field stays above it |
| DONE | primary; disabled until a name exists ("Pick a name first") | → Flat, first check-in with all meters at 70 |

**States:** first-run (no back arrow; DONE says "Let's go"); edit from
Settings (back arrow, DONE says "Save"); name rejected by filter (inline
caption in Ash under the field).

**Needs:** sets the personality modifier (one need decays 10% slower). Shows
the need glyph on each personality card.

---

## 3. Venue HUD

The main in-venue view. Fixed-angle diorama follow camera frames one zone;
tap the floor to walk, tap a person or object to open its sheet.

```text
+------------------------------------+
|~~~~~~~~~~~~ status bar ~~~~~~~~~~~~|
| (<home)  (M)(F)(D*)(N)    (album)  |
| THE BAR             next set 2:10  |
| Here: (o)(o)(o) +2                 |
|                                    |
|   .. diorama: one zone framed ..   |
|      back bar, amber shelves       |
|      ====== bar counter ======     |
|         (Noi)   [stool]            |
|                                    |
|              (you)                 |
|                                    |
|   round table      round table     |
|                                    |
|(< Lounge)                (Stage >) |
|                                    |
|        .--------------------.      |
|        | Tap the bar to     |      |
|        | order a drink      |      |
|        '--------------------'      |
|~~~~~~~~~~ home indicator ~~~~~~~~~~|
+------------------------------------+
```

| Element | Spec | Tap |
|---|---|---|
| Home | icon button, door glyph | → Walk-out summary (§4b) |
| Compact meters | 4 rings, 36 dp each, 44 dp hit areas, centred | tap row → meter detail sheet (which zone refills what) |
| Album | icon button, polaroid glyph; gold dot when a memory dropped this visit | → Album (§9) |
| Zone name | `display.l` on entry (fades to `display.s` after 2 s) | none |
| Next set | `caption`, countdown; becomes red `LIVE` tag during a set | tap → walk to Stage |
| Who's here | up to 3 head chips 32 dp + "+N"; regulars first, gold ring = 2+ hearts | tap → list sheet; tap a person → walks there and opens their sheet |
| Walk hints | edge chips at the screen sides toward neighbouring zones, 48 dp tall | tap → character walks; camera eases to next framing |
| World taps | bartender, stage, tables, people, arcade cabinet, dance spot | open the zone interaction sheet (§4) |
| Context hint | one line, bottom third, appears after 6 s idle, never during a set | tap → performs the hinted action |

**States**

- *Arrival:* Entrance framing, notice board bubble "What's on tonight" for
  3 s; zone name in large type.
- *Idle:* HUD at full opacity; context hint after 6 s.
- *Walking:* HUD drops to 60% opacity; nothing else changes.
- *Set in progress:* see §6 (HUD compresses further).
- *Sheet open:* HUD hidden except meters (they animate gains live).
- *Welcome Back active:* gold "x2" chip beside the meters with remaining
  minutes.
- *Lowest meter breathing:* the matching zone's walk hint gets the same
  colour edge (e.g. Drinks low → "< Bar" chip has an amber edge).

**Needs:** reads all four (compact); refills happen in sheets and
minigames, and passively (listening within earshot raises Music; the "+N"
chip rises from the ring).

---

## 4. Zone interaction sheet

Opens from a world tap. It is a list of *things you'd do here*, not meter
buttons (pillar 1): each row makes the character do it in the world, and the
sheet closes. Rows show the need glyph so the player learns where to go, but
no numbers.

```text
+------------------------------------+
|~~~~~~~~~~~~ status bar ~~~~~~~~~~~~|
| (<home)  (M)(F)(D*)(N)    (album)  |
|                                    |
|   .. scene stays visible ..        |
|      (Noi behind the bar)          |
|              (you)                 |
|                                    |
|.----------------------------------.|
||              ----                ||
|| THE BAR . Noi                    ||
|| "Evening! What are we having?"   ||
||----------------------------------||
|| (coupe) Order a drink            ||
||         First one's on the house ||
||----------------------------------||
|| (coupe) Pour it yourself    GAME ||
||         Pour Perfect . best 82   ||
||----------------------------------||
|| (coupe) Try something new        ||
||         New coaster  (gold dot)  ||
||----------------------------------||
|| (heads) Chat with Noi            ||
|'----------------------------------'|
|~~~~~~~~~~ home indicator ~~~~~~~~~~|
+------------------------------------+
```

Rows per zone (first playable):

| Zone / target | Rows | Needs |
|---|---|---|
| Bar (bartender) | Order a drink · Pour it yourself (Pour Perfect) · Try something new · Chat (Candle Talk with bartender) | Drinks (+ Friends via chat) |
| Stage | Find a spot near the front · Play along (Front Row Rhythm) · Applaud (between songs only) · Request (later) | Music, Nightlife on full set |
| Candle Floor table | Sit here · Sit with *Mali* (if a regular is seated) | Friends, Music (passive listening) |
| A regular | Candle Talk · Sit with · Wave | Friends |
| Dance spot (under the disco ball) | Dance | Nightlife |
| Lounge arcade cabinet | Play Neon Pinball | Nightlife |

| Element | Spec | Tap |
|---|---|---|
| Sheet | `bg.deep` 96%, max 60% of height, grab handle | drag down / tap scene to close |
| Header | zone + person in `display.s` gold, greeting line `body.l` | none |
| Action row | 64 dp tall, glyph 24 dp in need colour, title `body.l`, sub-line `caption` | performs action |
| GAME tag | right-aligned `display.s` chip for minigame rows, shows local best | — |

**States:** row disabled with reason ("Between songs", "Already talked today
— try tomorrow"); first drink free (sub-line); new-item gold dot; Welcome
Back ("x2" chip in header); regular absent (row hidden, not greyed).

---

## 4b. Walk-out summary

Shown when the player taps Home or the app returns after the visit ended.

```text
+------------------------------------+
| HEADING HOME                       |
| Tuesday . 11 min                   |
| (note)  MUSIC     [######-----] +25|
| (heads) FRIENDS   [#######----] +23|
| (coupe) DRINKS    [#######----] +40|
| (moon)  NIGHTLIFE [########---] +26|
| New tonight                        |
| [polaroid] [coaster] [stub]        |
| [           BACK TO THE FLAT     ] |
+------------------------------------+
```

Bars sweep from start-of-visit to end value. Gains shown here are the only
numbers outside "Show numbers" mode. **Needs:** reads all four.

---

## 5. Candle Talk dialogue (conversation entry)

Talking to a regular starts in the world with speech bubbles; it becomes
the Candle Talk minigame (§7c) when the player picks *Talk*.

```text
+------------------------------------+
|~~~~~~~~~~~~ status bar ~~~~~~~~~~~~|
| (<home)  (M)(F*)(D)(N)    (album)  |
|                                    |
|       MALI  (heart)(heart)( )      |
|   .----------------------------.   |
|   | Back again! The band's     |   |
|   | doing that slow one        |   |
|   | tonight. Sit?              |   |
|   '-------------v--------------'   |
|             (Mali)                 |
|         [lamp] table [tealight]    |
|             (you)                  |
|                                    |
|                                    |
| .--------------------------------. |
| | (candle)  Talk                 | |
| '--------------------------------' |
| .--------------.  .---------------.|
| | (chair) Sit  |  | (wave) Wave   ||
| '--------------'  '---------------'|
|~~~~~~~~~~ home indicator ~~~~~~~~~~|
+------------------------------------+
```

| Element | Spec | Tap |
|---|---|---|
| Name + hearts | `display.s` gold, hearts 0–3 (first playable) | tap → regular's profile (later) |
| Bubble | style guide §5; line-by-line reveal | tap: show rest / next line |
| Talk | 64 dp, full width | → Candle Talk (§7c) |
| Sit / Wave | 56 dp, half width each | performs verb, closes |

**States:** greeting by heart level (0: polite, 2+: waves and saves a seat);
already talked today (Talk disabled: "Mali's heading home soon — tomorrow?");
heart milestone (after §7c: heart fills with a gold sweep, postcard toast);
Meh Vibe ("missing it" line, GDD §2.2).

**Needs:** Friends (Talk +10–20 via §7c, Sit +8 after 60 s, Wave +2 to them).

---

## 6. Performance in progress

The set is the show: the UI shrinks to almost nothing.

```text
+------------------------------------+
|~~~~~~~~~~~~ status bar ~~~~~~~~~~~~|
| (<home)  (M)(F)(D)(N)        (LIVE)|
| House band . song 2 of 4           |
| [=======-----------------]  1:12   |
|                                    |
|     .. stage framed, red wash ..   |
|      [drums]  (singer)  [amp]      |
|       |mic|    (bass)              |
|     ~~~~~~ red carpet ~~~~~~       |
|                                    |
|   (o)  (o)   (you)   (o)  (o)      |
|          front row crowd           |
|                                    |
|                                    |
| .--------------------------------. |
| | (note) Play along          GAME| |
| '--------------------------------' |
|~~~~~~~~~~ home indicator ~~~~~~~~~~|
+------------------------------------+
```

Between songs (5 s window):

```text
+------------------------------------+
| House band . next: song 3          |
| [######################]  0:04     |
|                                    |
|       (stage, crowd cheering)      |
|                                    |
| .--------------------------------. |
| |                                | |
| |       ( clap )  APPLAUD        | |
| |                                | |
| '--------------------------------' |
+------------------------------------+
```

| Element | Spec | Tap |
|---|---|---|
| Meters | compact, 70% opacity; gains still animate | → meter sheet |
| LIVE tag | Neon Red text on `bg.base`, pulses 2.4 s (the only loop on screen) | none |
| Song line + progress | `caption`, 4 dp bar in Slat Red | none |
| Play along | 56 dp; hidden during the last 15 s of a song | → Front Row Rhythm (§7b) from the next song |
| APPLAUD | 120 dp tall block, bottom third; each tap = clap sound + crowd ripple; counts up to the per-visit cap silently | tap |

**States:** listening (default); between songs (applaud block); encore
(gold "ENCORE" tag replaces LIVE; ticket stub toast at the end); set over
→ break, HUD returns to §3 with "next set 2:00"; player leaves earshot (song
line fades, no penalty).

**Needs:** Music (+5 per song passively, +2 per applaud, +5 full-set bonus),
Nightlife (+5 on full set).

---

## 7. Minigame frames

Shared frame for all minigames: top bar with title, need glyph and a pause
button; play area; thumb zone. No fail screen: every finish shows a result
card.

```text
+------------------------------------+
|~~~~~~~~~~~~ status bar ~~~~~~~~~~~~|
| (pause)  POUR PERFECT   (coupe)    |
| best 82 . layer 2 of 3             |
|------------------------------------|
|                                    |
|            play area               |
|                                    |
|------------------------------------|
|            thumb zone              |
|~~~~~~~~~~ home indicator ~~~~~~~~~~|
+------------------------------------+
```

Result card (all minigames):

```text
+------------------------------------+
| .--------------------------------. |
| |  NICE POUR                     | |
| |  88   new best!                | |
| |  (coupe) DRINKS [######---]+28 | |
| |  [coaster] New: Lychee Fizz    | |
| |                                | |
| |  [ AGAIN ]     [   DONE    ]   | |
| '--------------------------------' |
+------------------------------------+
```

| Element | Spec | Tap |
|---|---|---|
| Pause | 48 dp icon; opens Resume / How to play / Leave (keeps the minimum reward) | — |
| Title | `display.l`, Kanit; Neon Red allowed here (brand moment) | — |
| Result card | score word tier (e.g. "NICE POUR"), number, best, need gain, memory drop | AGAIN (secondary), DONE (primary) → back to venue |

Score tiers, not grades: three words per minigame (good / great /
perfect-tier), never a fail word. AGAIN is hidden when the next attempt would
earn nothing (diminishing returns), replaced by the caption "That's plenty
for tonight".

### 7a. Pour Perfect (Bar · Drinks)

```text
+------------------------------------+
| (pause)  POUR PERFECT   (coupe)    |
| best 82 . layer 2 of 3             |
|------------------------------------|
|          (Noi, watching)           |
|                                    |
|            |          |            |
|       -- 3 |----------| target     |
|            |          |            |
|       -- 2 |~~~~~~~~~~| target     |
|            |##########| layer 1    |
|            |##########|            |
|            '----------'            |
|           ribbed glass             |
|------------------------------------|
|                                    |
|       HOLD ANYWHERE TO POUR        |
|                                    |
|~~~~~~~~~~ home indicator ~~~~~~~~~~|
+------------------------------------+
```

Controls: hold anywhere in the lower 45% to pour, release to stop; the next
layer starts after 600 ms. Target lines are 2 dp Lamp Gold with a 12 dp
tolerance band; overflow foams (no fail). States: pouring, settled, layer
score flash ("close!" / "spot on"), result. **Needs:** Drinks +20–30.

### 7b. Front Row Rhythm (Stage · Music)

```text
+------------------------------------+
| (pause) FRONT ROW RHYTHM (note)    |
| song 2 of 4 . crowd [#####---]     |
|------------------------------------|
|      LEFT       |       RIGHT      |
|                 |                  |
|        o        |                  |
|                 |        o         |
|        o        |                  |
|                 |        o         |
|                 |                  |
|   ======(  )====|====(  )======    |
|         hit line                   |
|------------------------------------|
|   tap left half | tap right half   |
|                 |                  |
|~~~~~~~~~~ home indicator ~~~~~~~~~~|
+------------------------------------+
```

Controls: tap the left or right half of the screen; each half is a full
195 x 400 dp target. Notes scroll down to a hit line at 70% height (above the
thumb). Hit = clap and crowd ripple; miss = soft mute, no sound penalty.
The stage stays visible at 40% brightness behind the lanes. Difficulty
picker (3) before the first song; "relaxed timing" from Settings widens
windows. States: waiting for downbeat (4-beat count-in), playing, song end →
result card, or "Keep playing" into the next song. **Needs:** Music +8–12 per
song (also raises the set's Crowd Vibe).

### 7c. Candle Talk (Candle Floor / Banquette · Friends)

```text
+------------------------------------+
| (pause)   CANDLE TALK  (heads)     |
| Mali . turn 3 of 5                 |
|------------------------------------|
|   .----------------------------.   |
|   | Did you catch the drummer  |   |
|   | last Thursday?             |   |
|   '-------------v--------------'   |
|              (Mali)                |
|                                    |
|            .( candle )..           |
|           glow: 3 of 5             |
|                                    |
|------------------------------------|
| .--------..----------..---------.  |
| | (note) || (coupe)  || (map)   |  |
| | That   || Same as  || Bangkok |  |
| | set!   || always   || rain    |  |
| '--------''----------''---------'  |
|~~~~~~~~~~ home indicator ~~~~~~~~~~|
+------------------------------------+
```

Controls: tap one of three topic cards (each 112 x 120 dp); the card flies
into a reply position, the regular reacts, the candle brightens on a match
(warm halo grows) or flickers on a miss (never goes out). Cards earned from
memories show the memory thumbnail in the corner. States: regular speaking
(cards disabled until the line finishes, tap to skip), choosing, reaction,
result (hearts gained, possible heart-milestone postcard). **Needs:**
Friends +10–20, hearts.

### 7d. Neon Pinball (Lounge · Nightlife)

```text
+------------------------------------+
| (pause)  NEON PINBALL    (moon)    |
| B L A C K  C A B I N   balls (o)(o)|
|------------------------------------|
|  .------------------------------.  |
|  | (bumper) (bumper) (bumper)   |  |
|  |   bottle-shelf bumpers       |  |
|  |                  /curtain    |  |
|  |   (spinner)     / ramp       |  |
|  |    drum kit    /             |  |
|  |         o                    |  |
|  |   \                     /    |  |
|  |    \___           ___/    |L||  |
|  |        \__  __/           |A||  |
|  '------------------------------'  |
|------------------------------------|
|  LEFT FLIPPER  | RIGHT FLIPPER     |
|                |     swipe up ^    |
|~~~~~~~~~~ home indicator ~~~~~~~~~~|
+------------------------------------+
```

Controls: tap left / right half for flippers; swipe up on the right third to
launch. The table fills the play area at 9:16; the lounge's red neon
silhouettes behind it. Letters of BLACK CABIN light as they are spelled
(Neon Red, brand moment); completing it lights the lounge neon in the world
for the rest of the visit. Generous ball save (first 10 s). States: launch,
in play, ball saved (toast), ball lost (no sound sting, next ball), game
over → result card. **Needs:** Nightlife +10–20.

---

## 8. Memory drop (toast)

Not a screen, but the most common reward moment.

```text
+------------------------------------+
|~~~~~~~~~~~~ status bar ~~~~~~~~~~~~|
| .--------------------------------. |
| | [polaroid] New polaroid        | |
| |  "Thursday, front row"     (>) | |
| '--------------------------------' |
+------------------------------------+
```

Toast style (style guide §5), 2.8 s, tap → opens that memory in the Album.
The Album icon in the HUD gets a gold dot until opened. **Needs:** none.

---

## 9. Memory album

```text
+------------------------------------+
|~~~~~~~~~~~~ status bar ~~~~~~~~~~~~|
| (<)          MEMORIES        12/15 |
| ALL  POLAROIDS  STUBS  COASTERS    |
| ===                                |
| (<)        October 2026        (>) |
| .--------..--------..--------.     |
| |[photo] ||[photo] ||(coaster)|    |
| | Thu    || Tue    ||  new . |     |
| '--------''--------''--------'     |
| .--------..--------..--------.     |
| |[photo] || (stub) ||(coaster)|    |
| | Sun    || Sat    ||        |     |
| '--------''--------''--------'     |
| .--------..--------..--------.     |
| |   ?    ||   ?    ||   ?    |     |
| '--------''--------''--------'     |
|                                    |
| [      EDIT WALL (6)             ] |
|~~~~~~~~~~ home indicator ~~~~~~~~~~|
+------------------------------------+
```

Memory detail (tap a tile):

```text
+------------------------------------+
| (<)                       (pin)    |
|   .----------------------------.   |
|   |                            |   |
|   |   voxel snapshot (polaroid)|   |
|   |                            |   |
|   |----------------------------|   |
|   | Thursday, front row,       |   |
|   | the house band             |   |
|   '----------------------------'   |
| Tue 27 Oct 2026 . 21:14            |
| Who was there: (Mali)(Noi)         |
| [      PIN TO WALL               ] |
+------------------------------------+
```

| Element | Spec | Tap |
|---|---|---|
| Filter tabs | `display.s`, 48 dp | filter |
| Month pager | arrows 48 dp; swipe left/right | page |
| Tiles | 3 columns, ~108 x 128 dp, ±2° rotation, polaroids cream-bordered | → detail |
| Undiscovered | "?" tile in `bg.raised`, no hint text in first playable | none |
| Counter | found / total, `caption` | none |
| Pin | toggle; if wall full → wall editor with "replace which?" | — |

**States:** empty album (one line: "Your first night out will start this.");
new memory (gold dot on tile); wall full.

### 9b. Wall of six (on the Flat)

```text
+------------------------------------+
| (<)          YOUR WALL             |
|   .--------..--------..--------.   |
|   |[photo] ||(coaster)|| (stub) |  |
|   '--------''--------''--------'   |
|   .--------..--------..--------.   |
|   |[photo] ||  ( + ) || ( + )  |   |
|   '--------''--------''--------'   |
| Tap a frame to swap. Hold to move. |
| [            DONE                ] |
+------------------------------------+
```

The same six slots appear on the Flat's wall in the voxel room. Editing is a
2D overlay; frames are 108 x 108 dp. Empty slot `( + )` opens the album in
pick mode. 12 slots later (GDD §8). **Needs:** none.

---

## 10. Week Recap card

Mondays, on the first check-in of the week; saved to the album. Designed as
a 9:16 shareable image (1080 x 1920 export) with the UI chrome outside it.

```text
+------------------------------------+
|~~~~~~~~~~~~ status bar ~~~~~~~~~~~~|
| (x)                       (share)  |
| .--------------------------------. |
| |  (neon) BLACK CABIN            | |
| |  YOUR WEEK                     | |
| |  19 - 25 Oct                   | |
| |                                | |
| |  [   best memory polaroid    ] | |
| |  [                           ] | |
| |                                | |
| |   3 nights out . 14 songs      | |
| |   2 drinks you'd never had     | |
| |   Regulars: (Mali)(Noi)(Ton)   | |
| |                                | |
| |  (M)(F)(D)(N)  GOOD WEEK       | |
| |  Vibe: Glowing                 | |
| '--------------------------------' |
| [            NICE               ]  |
|~~~~~~~~~~ home indicator ~~~~~~~~~~|
+------------------------------------+
```

| Element | Spec | Tap |
|---|---|---|
| Card | `bg.deep`, wordmark asset, `display.xl` title, stats in `body.l` | swipe to see last weeks (later) |
| Best memory | the week's highest-ranked polaroid | → memory detail |
| Stamps | four rings show whether each need reached 80+ this week; GOOD WEEK if all four | none |
| Share | OS share sheet with the rendered image (Web: download) | — |
| NICE | primary → Flat | — |

**States:** quiet week (0–1 visits): warm copy, "A quiet week. Your stool's
still there." — never guilt, no empty stats; first week
(partial week note); no polaroid (shows a coaster or the Flat). **Needs:**
reads all four (week summary). Refills none.

---

## 11. Settings

```text
+------------------------------------+
|~~~~~~~~~~~~ status bar ~~~~~~~~~~~~|
| (<)          SETTINGS              |
| LANGUAGE                           |
| .---------------..---------------. |
| |  English  (v) ||     ไทย       | |
| '---------------''---------------' |
| SOUND                              |
| Music       [==========-----]      |
| Effects     [=============--]      |
| DISPLAY                            |
| Show meter numbers           [ o]  |
| Text size        100  115  130     |
| Reduce motion                [ o]  |
| Dim flashes                  [ o]  |
| PLAY                               |
| Relaxed timing               [ o]  |
| Out of Town                   (>)  |
| Edit character                (>)  |
| Credits . Privacy             (>)  |
|~~~~~~~~~~ home indicator ~~~~~~~~~~|
+------------------------------------+
```

| Element | Spec | Tap |
|---|---|---|
| Language | segmented control, 56 dp; each option written in its own language ("English", "ไทย") and never translated | switches live, no restart; layout re-flows; persists |
| Sliders | 48 dp tall hit area | drag |
| Toggles | 52 x 32 dp switch, 48 dp row | toggle |
| Text size | 3-option segmented | live preview |
| Rows with (>) | 56 dp | sub-screens |

**States:** Notifications row hidden in first playable (GDD §14), shown later
under PLAY; Debug clock row only in debug builds; Thai selected → all
sections re-render with Thai line-height (style guide §3). **Needs:** none
(Out of Town freezes all four).

---

## Screen index

| # | Screen | Needs |
|---|---|---|
| 1 | The Flat | reads all four + Vibe |
| 2 | Character creator | sets personality modifier |
| 3 | Venue HUD | reads all four; passive Music |
| 4 | Zone interaction sheet | whichever the zone offers |
| 4b | Walk-out summary | reads all four |
| 5 | Candle Talk dialogue | Friends |
| 6 | Performance in progress | Music, Nightlife |
| 7a | Pour Perfect | Drinks |
| 7b | Front Row Rhythm | Music |
| 7c | Candle Talk | Friends |
| 7d | Neon Pinball | Nightlife |
| 8 | Memory drop toast | — |
| 9 | Memory album / 9b wall of six | — |
| 10 | Week Recap | reads all four |
| 11 | Settings | Out of Town freezes all |
