# Black Cabin Tamagotchi — Cast Bible

Status: draft v1 (session 2A, 2026-10-27). Read `DECISIONS.md`, `01-high-concept.md`
and `02-gdd.md` §5–§7 first. This file owns names, personalities, schedules,
dialogue voice and the asks to Black Cabin. The GDD owns the numbers; where a
number appears here it repeats the GDD or is marked **proposal**.

★ = ships in the first playable (GDD §14): **Nam (bartender), Tong, Ploy, Jules**,
plus the house band.

Zone names follow the GDD, with the greybox node in brackets: Entrance Lounge
(`Lounge`), Bar (`Bar`), Stage & Front Row (`Stage`), Candle Floor (`Tables`),
Long Table (`CommunalTable`), Velvet Banquette (no node yet), Dance Floor (the
spot under the disco ball). All times are Bangkok time (DECISIONS).

---

## 1. Cast philosophy

### 1.1 What NPCs are for

The room is the star and the player's own character is the Tamagotchi. NPCs are
neither. They are **the reason the room feels like somewhere**. Each one does
one of three jobs:

| Job | Who | What it means in play |
|---|---|---|
| **Hosts** | Staff | They run the room. Every refill passes through them or their space: the drink, the stage, the door. They never need you; they're glad you came. |
| **Regulars** | 8 NPCs | They are the "I have a local" fantasy. They remember you, save you a seat, and give the Friends meter a face. Each one also points at one other need, so talking to them nudges you around the room. |
| **Performers** | House band + 6 acts | They make the Music meter and the weekly calendar. They are the live-ops content unit (GDD §6.3). |

Rules for every cast member:

1. **Nobody needs rescuing.** No regular has a crisis the player must fix. Stories
   are small and true-to-a-bar: a bass never played, a sketch never shown, a
   record from 1979.
2. **Nobody is a quest giver.** Regulars suggest ("the band's on in two"), they
   never assign.
3. **No rejection, no guilt** (GDD §5.1, §2.5). A regular never refuses to talk.
   Absence lines are warm ("Your seat's been cold"), never "you forgot us".
4. **One signature item, one spot, one voice.** Art bible §7: no two regulars
   share a head silhouette; each has a fixed signature item players can't buy.
5. **Real people are slots, not inventions.** Staff and performers are written so
   the real Black Cabin person can drop in with a photo, a nickname and a story.

### 1.2 Keeping a quiet room alive

The headcount rule (GDD §5.2) guarantees 12–20 bodies. The cast makes those
bodies feel like a night, not a crowd sim:

| Quiet-room behaviour | Who | Trigger |
|---|---|---|
| Ambient work loops: polishing glasses, restocking the shelf, cutting limes | Nam, Fern | Always, when not serving |
| Soundcheck between sets: taps a mic, plays one bar of a riff, adjusts a stand | Golf, house band | During the 2-minute break |
| **Regular-to-regular moments**: a 10–20 s scripted beat between two regulars present at once (Dougie and Lung Nop argue whether vinyl is "warm" or "honest"; Bow drags Jules to dance; Mali recruits Hiro for the quiz; Lung Nop tells Tong the bass holds the floor up) | Any pair present | Once per pair per visit, when the player is in the same zone |
| Zone drift: a regular walks to their second zone once per visit (bar run, smoke-break walk to the Entrance Lounge, front row for a favourite song) | All regulars | Random, 1× per visit |
| Door check-ins: Big waves new arrivals in, so the room visibly fills on event nights | Big | Each time an anonymous patron spawns |
| Callouts: a regular shouts the next thing ("Last song!", "Quiz in five!") | Whoever is in the zone | Schedule events |

The room should never look like it is waiting for the player. Things are
already happening when they walk in.

### 1.3 Presence rules with other players (P2 Echoes, P3 Live)

Restated from GDD §5.2 for the cast:

| Rule | Detail |
|---|---|
| Headcount | 12 bodies on a quiet Monday, 20 on a Headline Night. |
| Replacement order | Real players and echoes replace **anonymous patrons first, never regulars or staff**. |
| Seats | Each regular has a reserved seat. Players can sit at a regular's table but never in the regular's seat. At 2+ hearts the regular saves **you** the next seat. |
| Hearts are per player | Two players can both be at 3 hearts with Ploy. Her story beats play privately in each player's UI. |
| Candle Talk in P3 | Candle Talk is a UI-side minigame, so one regular can be in Candle Talk with several players at once. Other players just see the regular in a "chatting" animation. |
| Verbs | Regulars use the same social-verb interface as players (wave, cheers, sit with, dance with). A regular can cheers a player; a player can cheers a regular. |
| Behaviour toward players | Regulars never react to players' rudeness or spam. They have no negative states. |
| Staff priority | The bartender serves each player through their own UI, with no visible queue. On screen, Nam always looks like they're serving *you*. |

---

## 2. Staff

Staff wear Cabin Dark with Cymbal Gold trim (art bible §7). Each slot below has a
**working name** so writing and art can start. The real person's name, look and
lines replace it 1:1 if they agree to appear. If someone declines, the working
name ships as a fictional character.

| Slot | Working name | Role in play | Zone / when | Signature item (placeholder) | Working catchphrases | FP |
|---|---|---|---|---|---|---|
| `BAR_1` | **Nam** (น้ำ) | Head bartender. Takes orders, hosts Pour Perfect and Shake & Serve, gives the Welcome Back, says the rank greetings, offers water at Merry (§5). | Bar, every night | Apron and bar towel over the shoulder | "Same again?" / "อันนี้พี่เลี้ยง" ("This one's on me") / "Back where you belong." | ★ |
| `BAR_2` | **Fern** (เฟิร์น) | Second bartender on Fri/Sat. Runs the featured drink and Shake & Serve orders on busy nights. | Bar, Fri–Sat from 20:00 | Cocktail shaker, always mid-shake | "Something sour, something orange?" / "Trust me on this one." | |
| `DOOR` | **Big** (บิ๊ก) | Door host. First face of every visit: greets, points at the notice board and the guestbook, announces tonight's lineup. | Entrance Lounge, by the curtain | Clicker counter and a torch | "Band's on in two. Go, go." / "You again? Good." | Post-FP (FP uses a static board) |
| `SOUND` | **Golf** (กอล์ฟ) | Sound engineer. Runs soundchecks in the quiet room, hosts Setlist Shuffle, curates CRT Channel Surf clips, and lights the disco ball. | Stage-side desk | Headphones around the neck, gaffer tape on the belt | "Check, check… perfect." / "Too loud? No such thing." | Ambient only |
| `OWNER` | **Khun Joy** (คุณจอย) | Owner figure. Rare: Headline Nights, the anniversary, and the rank-up to "Part of the Furniture". Raises the house toast. | Walks the room; ends at the bar | Their own glass, the only one with a gold rim | "Welcome to my living room." | |

### 2.1 What to ask Black Cabin, per staff slot

Send the same request to each person who agrees to appear:

| Ask | Format | Used for |
|---|---|---|
| **Consent** to appear: name, likeness, optional voice | Signed one-pager | Legal; without it the working name ships |
| **Photo** | Full body front, side and back in the usual work outfit, plus a face close-up, in plain light | Voxel model; head silhouette; signature item |
| **Nickname** | How guests call them, spelled in Thai and in English, plus the honorific they want (P', Khun, none) | Name tags, dialogue, string table |
| **Signature drink** | Name, recipe, glass and garnish | One of the 24 coasters; their Shake & Serve order |
| **One story** | A true night at Black Cabin in 3–5 sentences | Becomes their 3-heart postcard or a CRT clip |
| **Catchphrases** | 2–3 things they actually say on shift, in their own language | Greeting lines; Thai-first strings |
| **Habit** | One thing they always do (cut limes, tap the bar twice, fix a lamp) | Ambient idle loop |

Extra asks for specific slots:
- `OWNER`: the founding story, the anniversary date (GDD §11) and the house toast.
- `SOUND`: a 30-second phone clip of a real soundcheck, for the CRT and the break SFX.
- `DOOR`: the real door policy line, so ours sounds like theirs.

### 2.2 Nam's line set (first playable)

| Moment | EN | TH (Thai-first; this is a draft for a native writer) |
|---|---|---|
| First visit ever | "First time? First one's on the house. It's always on the house, the first one." | "มาครั้งแรกเหรอ แก้วแรกพี่เลี้ยงนะ แก้วแรกเลี้ยงเสมอ" |
| Rank: Familiar Face | "I know that face." | "หน้าคุ้น ๆ นะ" |
| Rank: Regular | "Your usual?" | "เหมือนเดิมไหม" |
| Rank: Local | "Sit, I'll bring it over." | "นั่งเลย เดี๋ยวพี่เอาไปให้" |
| Rank: Part of the Furniture | "Honestly, you could work here." | "มาบ่อยขนาดนี้ มาทำงานที่นี่เลยไหม" |
| Welcome Back | "There you are. Back where you belong. This one's on me." | "มาแล้ว ๆ กลับมาที่เดิมนะ แก้วนี้พี่เลี้ยง" |
| Merry state (§5) | "Water's on me too. House rule." | "น้ำเปล่าพี่ก็เลี้ยง กฎของร้าน" |

---

## 3. Regulars

Eight regulars, matching the GDD launch count. Five are Thai, three are expats
(French, Scottish, Japanese), which matches the real Bangkok live-music crowd. Thai
regulars go by their nickname (*chue len*), as Thai people do. Their formal names
appear only in the album credits and the localization table (§6).

### 3.1 Roster

| # | Name | Archetype | Age | Why they come | Home zone (2nd zone) | Usual nights | Window | Feeds | Usual drink | Signature item / head silhouette | FP |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **Tong** (ต้อง) | Music nerd who never plays | 24–28 | To watch hands. He studies every bassist. | Stage front-row poufs (Bar) | Wed Thu Fri | Late | Music | Leo beer, one, nursed | Gig bag on his back / bucket hat | ★ |
| 2 | **Ploy** (พลอย) | Architect who sketches the room | 28–34 | The light. Third table from the curtain. | Candle Floor, by the orange wall lamp (Banquette) | Mon Tue Thu Sun | Early | Friends | Glass of red | Sketchbook / high bun with a pencil through it | ★ |
| 3 | **Jules** | Night-owl pinball champion | 30–36 | Came for three months, six years ago | Entrance Lounge, pinball cabinet (Dance Floor) | Thu Fri Sat | Late | Nightlife | Gin and tonic, lots of lime | Oversized bomber / bleached quiff | ★ |
| 4 | **Mali** (มะลิ) | Quiz captain, adopts everyone | 36–42 | Somewhere she doesn't need a form to make friends | Long Table (Candle Floor) | Tue Thu Sat | Early | Friends | Thai iced tea (no alcohol) | Chalk-dusted cardigan / short bob with reading glasses pushed up | |
| 5 | **Dougie** | Retired touring roadie | 60–68 | "Best room I've stood in." | Bar, end stool (Stage edge) | Mon Wed Fri Sun | Early | Drinks | Lager, always | Flat cap / grey sideburns | |
| 6 | **Lung Nop** (ลุงนพ) | Retired FM radio DJ, jazz and *luk krung* | 64–70 | Thursday jazz, Sunday slow songs | Velvet Banquette (Front Row on Thu) | Thu Sun | Early | Music | Whisky soda, small | Vinyl record under the arm / round tinted glasses, white side-part | |
| 7 | **Bow** (โบว์) | Flight attendant on a crazy roster | 26–30 | To dance off the jet lag | Dance Floor (Bar) | Fri Sat + 1 random weekday | Late | Nightlife | Mojito, then water | Wheelie cabin bag / big ribbon in a high ponytail | |
| 8 | **Hiro** | Salaryman and highball perfectionist | 34–40 | In Tokyo he drank alone. Here, never. | Bar, middle stool (Long Table on Tue) | Tue Thu Sat | Late | Drinks | Highball | Pocket notebook / neat side-part, loosened tie | |

**Window:** Early = 18:00–23:00, Late = 21:00 to close. On a usual night a
regular is present 90% of the time, otherwise 25% (GDD §5.1).

**Feeds (proposal):** Candle Talk always gives Friends +10–20 (GDD §2.3). A
*good* Candle Talk (candle fully lit) also gives **+5 to the regular's Feeds
meter**: Tong talks you into the front row, Hiro gets you to try something. This
spreads regulars across all four needs. It lives in `needs_config` as
`candle_talk_lean_bonus`.

### 3.2 Weekly schedule (home zone; † = second-zone drift likely)

| | Mon | Tue | Wed | Thu (Jazz) | Fri (Headline) | Sat (Headline) | Sun (Slow) |
|---|---|---|---|---|---|---|---|
| Tong ★ | | | Front Row | Front Row | Front Row | | |
| Ploy ★ | Candle Floor | Candle Floor | | Candle Floor | | | Banquette† |
| Jules ★ | | | | Lounge | Lounge | Lounge → Dance† | |
| Mali | | Long Table (Quiz) | | Long Table | | Long Table | |
| Dougie | Bar | | Bar | | Bar | | Bar |
| Lung Nop | | | | Front Row† | | | Banquette |
| Bow | | (random) | (random) | (random) | Dance Floor | Dance Floor | |
| Hiro | | Bar → Long Table† | | Bar | | Bar | |
| **Usuals present** | 2 | 3 | 2 | 6 | 4 | 4 | 3 |

**First-playable check:** with only Tong, Ploy and Jules, every day has at least
one usual (Ploy covers Mon/Tue/Sun, Tong covers Wed, all three are in on Thu).
Ploy's Tue night exists for this reason. Mali is the Tuesday anchor when she
ships.

### 3.3 Heart arcs (hearts 1–3)

The GDD runs to 5 hearts; the first playable stops at 3. Every heart plays a short
banquette story beat. At 2 hearts the GDD's "notices you" rules apply (wave,
saved seat, mentions your last memory). The 3-heart reward is the regular's
memory (§3.4). Hearts 4–5 come with the live-ops story chapters.

| Regular | ♥1 | ♥2 | ♥3 |
|---|---|---|---|
| Tong ★ | Uses your name. Shows you the bass in the bag, borrowed from his brother five years ago and never given back. | Saves you a front-row pouf. Makes you watch his signature on the Open Mic list. He crosses it out. | Golf lets him play one song during a break. You're the only one clapping, then everyone is. **Memory.** |
| Ploy ★ | Asks if she can draw you. Says no to showing you. | Shows you the bar she designs in her sketchbook and will never build. "It's this one, but with my lamp." | Gives you the sketch of you, framed. **Memory.** |
| Jules ★ | Challenges you to beat his pinball initials. | Teaches you the nudge trick, and admits he never sleeps before 3. | You both spell BLACK CABIN on one table; he insists on sharing the high score. **Memory.** |
| Mali | Chalks your name on the quiz team board. | Lets you pick the team name for one week ("Second Is First" wins). | Team tee cosmetic, plus the scoreboard polaroid. **Memory.** |
| Dougie | Recommends a drink you haven't tried. Its coaster glows on the menu. | Tells you the broken-wrist blues band story at the banquette. | Gives you his 1994 tour laminate. **Memory.** |
| Lung Nop | Gives you a "song of the week" on your next visit. | Brings records in and tells you about his last broadcast, the night the station went off air. | Hands you a mixtape labelled "For Lan". **Memory.** |
| Bow | Teaches you her move, which becomes a dance emote. | Sends a postcard from wherever she's flying this week. | Gives you a wing pin (accessory cosmetic). **Memory.** |
| Hiro | Reads you a tasting note from his notebook. | Orders for you: "Trust me." This unlocks an off-menu drink. | Tears out the Black Cabin page and gives it to you. **Memory.** |

### 3.4 Memories given

| Regular | Memory | Type | Caption |
|---|---|---|---|
| Tong | "Tong's First Song" | Polaroid | "Wednesday, the break. One song. Front row of one." |
| Ploy | "Ploy's Sketch of You" | Polaroid (drawn); also unlocks a wall frame | "Third table from the curtain. Best light." |
| Jules | "Co-Signed High Score" | Polaroid under red neon | "1:12 am. Shared initials. He insisted." |
| Mali | "Second Is First" | Polaroid of the chalk scoreboard | "Tuesday. Came second. Celebrated anyway." |
| Dougie | "All Access '94" | Ticket stub (laminate) | "Forty years of amps. One good stool." |
| Lung Nop | "For Lan" | Postcard with a cassette | "Side A: Thursday. Side B: Sunday." |
| Bow | "Disco Ball, Ground Control" | Polaroid | "Landed at 6. Dancing by 10." |
| Hiro | "Page 42" | Coaster with a recipe | "Ice. Whisky. Patience." |

### 3.5 Candle Talk lines

Each set is the regular's **opening lines** in Candle Talk: one plays per turn
and the player answers with a topic card. Voice notes come first and bind every
future line.

**Tong ★.** *Fast and nerdy, self-deprecating, talks gear. Never mean about other musicians.*
1. "Watch Boy's left hand on the hi-hat. Nobody watches the hi-hat. Tragic."
2. "I've had a bass in this bag for two years. It's been on stage zero times. Very well travelled though."
3. "Wednesday's open mic. I'm signing up. I say this every Wednesday."
4. "That chord just now? Borrowed from the minor key. Don't tell anyone, they'll want it back."
5. "Back there you hear the room. Front row, you hear the amp breathe."
6. "You were clapping on two and four tonight. I noticed. Respect."

**Ploy ★.** *Dry and observant, short sentences, warm underneath. Describes the room like a building.*
1. "Third table from the curtain. Best light in the room. I measured. Professionally."
2. "I draw everyone who sits here. Don't worry, I'm kinder with a pencil."
3. "Monday is for people who survived Monday. Cheers to us."
4. "The man at the bar has read that menu for ten minutes. He's going to order a beer."
5. "Bangkok is concrete and traffic, then you walk through a curtain and it's 1962."
6. "You look less tired than last week. I'd know. I drew you."

**Jules ★.** *Theatrical, playful, a little French in the rhythm, competitive but generous.*
1. "The pinball has a soul. A cruel soul. I respect it."
2. "My initials are on that machine. Yours could be underneath. Ambition is healthy."
3. "Nobody goes home before the last song. It is the law. Thai law, I think. Maybe French."
4. "I came to Bangkok for three months. That was six years ago. The lounge is why."
5. "Bow says I dance like a fan with one blade missing. She is correct. I dance anyway."
6. "Spell BLACK CABIN and the neon gets brighter. I've done it four times. I am unbearable about it."

**Mali.** *Bossy-warm team captain, lists and plans, calls the player "nong".*
1. "Sit, sit. Long table is for everyone. That's the point of a long table."
2. "Tuesday quiz, seven o'clock, my team. You know one thing about eighties music? You're in."
3. "I do HR all day. Here nobody needs a form to be my friend."
4. "Have you eaten? Eat before the third drink, nong. I'm serious."
5. "Lung Nop knows every jazz record ever made and still loses the music round. Beautiful."
6. "We came second last week. Second is just first with homework."

**Dougie.** *Gruff Glaswegian storyteller, calls everyone "pal", lager loyalist who pushes you to try things.*
1. "Forty years carrying amps round the world, and this is the best room I've stood in. Don't tell Glasgow."
2. "Try the one with the smoke on it. I won't, I'm a lager man. But you should."
3. "Golf's got that desk running sweeter than any tour I did. Don't tell him either."
4. "Nam pours my order before I sit down. That's not service, pal. That's friendship."
5. "Every bar's got a stool that's yours. Find yours. That one's mine."
6. "Saw a band in '89 play a whole set with a broken wrist. Worst set I ever heard. Best night."

**Lung Nop.** *Slow, polite, paternal radio voice; calls the player "lan" (หลาน, niece/nephew, gender-neutral).*
1. "Listen to the bass. He is not playing notes, lan. He is holding the floor up."
2. "On the radio we had one rule: never talk over the intro. Let the song walk in by itself."
3. "Thursday is jazz. Sunday is slow songs. The other nights I rest my ears."
4. "My wife and I danced to this one in 1979. She danced better. She still does."
5. "Young people say vinyl is warm. It is not warm. It is honest."
6. "You came. Good. A song is better with one more person listening."

**Bow.** *Bubbly and quick, airline jokes, ends lines with "na".*
1. "Landed from Osaka three hours ago. My body thinks it's breakfast. Let's dance."
2. "Disco ball on? Then I'm on."
3. "Jules dances like a broken fan. I love him. Don't tell him, na."
4. "Please fasten your seatbelts. The headliner is about to start."
5. "Next week is Dubai, Paris, Dubai. So tonight counts double, na."
6. "If you see me sitting down, check my pulse."

**Hiro.** *Precise, quiet, deadpan; treats drinks like craft and friendship like a surprise.*
1. "A highball is three things: ice, whisky, patience. Most bars skip the patience."
2. "Nam's lime cut is correct. I checked. I always check."
3. "In Tokyo I drank alone. Here, somehow, never."
4. "I keep notes on every drink. Page forty-two is all Black Cabin."
5. "You ordered something new. Brave. Tell me everything."
6. "My boss thinks I'm at a networking event. Technically, I am networking."

---

## 4. Performers

### 4.1 Lineup and calendar

| Act | Genre | Lineup | When | Feeds | Real-performer slot |
|---|---|---|---|---|---|
| **The House Lights** ★ | Soul-pop covers and warm originals | **Jo** (Filipina, vocals and acoustic guitar), **Pete** (Thai, bass), **Boy** (Thai, drums at the kit by the olive tree) | Continuous house sets every night; backs Open Mic on Wed | Music (+Nightlife on a full set) | `PERF_HOUSE`: Black Cabin's real resident band, if there is one |
| **The Thursday Club** | Jazz trio | **Aom** (piano), **Jack** (Australian, upright bass), **Note** (drums with brushes) | Thu, Jazz & Candles | Music + Friends | `PERF_JAZZ` |
| **Monsoon Funk Unit** | Funk and soul, horns | 6-piece led by **May** (vocals); guitar, bass, drums, sax, trumpet | Headline Fri/Sat, rotating | Music + Nightlife | `PERF_HEAD_A` |
| **Plaa Thong** (ปลาทอง, "goldfish") | Thai-language dream indie | 4-piece led by **Nok** (vocals and guitar); synth, bass, drums | Headline Fri/Sat, rotating | Music + Nightlife | `PERF_HEAD_B`: ideally a real Thai indie act |
| **Soi Dog Blues** | Delta and Chicago blues | Duo: **P'Daeng** (Thai, 50s, slide guitar and vocals) and **Mick** (Australian, harmonica, stomp box) | Headline Fri/Sat, rotating; guest set on Sun | Music + Friends | `PERF_HEAD_C` |
| **Fah** (ฟ้า) | Singer-songwriter, Thai and English | Solo: voice, nylon guitar, loop pedal | Sun, Slow Sunday | Music + Friends | `PERF_SUN` |
| **DJ Moo Krob** (หมูกรอบ, "crispy pork") | Vinyl: Thai funk, city pop, disco | Solo, in the lounge | Fri/Sat 23:00 to close, after the headline; the after-party | Nightlife | `PERF_DJ` |

Six non-house acts at launch cover six months of the "one new performer a month"
cadence (GDD §11) if they are released one at a time. More likely they launch
together, with real Black Cabin acts arriving monthly after that.

### 4.2 Stage presence and set structure

Each act fills the GDD §6.2–6.3 content unit: 6–10 songs (60–90 s each), 3
banter lines per song, a crowd-work moment, a request pool, an encore, a
Spotlight part, a signature memory and a band tee.

| Act | Stage presence (animation brief) | Set shape | Crowd-work moment | Encore song | Spotlight part | Memory / tee |
|---|---|---|---|---|---|---|
| House Lights ★ | Jo talks to the room like friends at a table; Pete barely moves and grins; Boy spins a stick on the last hit | **4 songs:** groove opener → mid-tempo singalong → the slow one → upbeat closer; then a 2-min break with soundcheck idles | Jo points the mic at the front row on the singalong chorus | Not in the FP (encore comes with events) | Tambourine | Ticket stub "House Lights, Night One" / cream tee with a lamp logo |
| Thursday Club | Seated, eyes closed, nodding at each other's solos; Aom lifts a hand at the end of a phrase | **8 songs:** standard → standard → ballad → piano solo feature → bass feature → up-tempo → ballad → *luk krung* jazz arrangement | Jack asks "Anyone here on their first Thursday?" and the front row raises glasses | The *luk krung* tune again, slower | Finger snaps on 2 and 4 | Setlist "Thursday Club" / black tee with a gold candle |
| Monsoon Funk | Horns step forward for hits; May works the whole stage; full-band jump on the last chord | **10 songs:** build 1–3, peak 4–6, breather 7, peak 8–10 | Call-and-response ("Say Mon!" "Soon!") | Ten-minute medley (cut to 90 s) | Cowbell | Polaroid "Horns Up" / orange tee, rain-cloud logo |
| Plaa Thong | Shoegaze stillness, then Nok kicks a pedal and the lights bloom; synth player sways | **10 songs:** dreamy 1–4, single 5, slow 6–7, big 8–10 | Nok asks the room to put phones down and hold up lamps (the candle lamps glow brighter) | The hit single, acoustic | Backing "oo"s | Ticket stub / pale blue tee, goldfish line art |
| Soi Dog Blues | P'Daeng sits on a stool, Mick stomps and wanders into the front row | **8 songs:** shuffle, slow blues, boogie, story song (spoken intro), harp feature, slow blues, boogie, gospel closer | Mick plays a harp solo standing at a front-row table | Gospel closer, a cappella chorus | Stomp box | Polaroid "Front Row Harp" / brown tee, dog with sunglasses |
| Fah | One light; she loops her own voice into a choir; quiet thank-yous | **6 songs**, all slow; one Thai, one English, alternating | She asks for a hum, then loops the room's hum into the song | A lullaby in Thai | Humming | Postcard "Sunday, Slow" / soft grey tee, cloud logo |
| DJ Moo Krob | Headphones on one ear, digs crates, fist-pumps when a record lands | **Continuous mix** in 6 × 90 s tracks; no breaks | Holds up a record sleeve; the lounge cheers | None (DJ) | None; Dance-off host instead | Coaster "Crispy Pork Special" / tee with a crackling pig |

**Banter voice rules:** House Lights are warm and inclusive ("This one's for
whoever's on their second drink"). Thursday Club stays understated. Monsoon is
loud. Plaa Thong speaks Thai first and switches to English shyly. Soi Dog Blues
tells stories. Fah is quiet. Moo Krob never talks; he only shouts track names.

### 4.3 What to ask Black Cabin, per performer slot

Everything in §2.1 (consent, photos of each member with their instrument, names
and nicknames, one story), plus:
- Song list: 6–10 tracks with licence status (commissioned, licensed or originals they own), and stems if possible for beat maps.
- A live photo or video on the Black Cabin stage, for stage presence and positions.
- The set they actually play: opener, closer, the song the crowd asks for.
- Merch or logo for the in-game band tee.
- Their usual Black Cabin night, so the in-game calendar can mirror the real one (GDD §11 tie-in).

---

## 5. Intoxication and drinks as character

Intoxication is in (DECISIONS). It's played as **mood**, the way a good bar
night looks from across the room. It is never shown as harm.

### 5.1 The four states

Counted per visit from alcoholic drinks only. Non-alcoholic drinks (Thai iced
tea, coffee, mocktails, water) **refill Drinks exactly as much** and never add
tipsiness. Each state drops by one every 30 real minutes (**proposal**). A glass
of water drops one state immediately. The count resets between visits.

| State | Drinks this visit | Walk | Idle | Dialogue tone | Gameplay |
|---|---|---|---|---|---|
| **0 · Clear** | 0 | Normal | Normal mood idles | Normal | None |
| **1 · Warm** | 1–2 | A small bounce in the step | Sways to the music; cheek-blush decal at 30% | Friendlier; the phrase wheel shows "Cheers!" first | Dancing Nightlife ×1.1 (**proposal**) |
| **2 · Tipsy** | 3–4 | A loose half-step weave on turns, never a stumble | Leans on the table or bar, laughs at nothing, taps along | More candid. Candle Talk adds a "Loose Lips" gossip card. | Loose Lips card: an extra match option, so it's slightly easier |
| **3 · Merry** | 5+ | Slower, humming, arms swinging | Sits more, chin on hand, sings along at the stage | Sentimental ("I love this place") | Nam serves only water and mocktails until the state drops. The walk-out screen shows a taxi home. |

**No state ever lowers a reward.** Minigame timing windows and scores are
unchanged. Tipsiness changes how the night looks, not how well you play.

### 5.2 Never shown

Vomiting, falling over, passing out, injury, fights or aggression, unwanted
touching or flirting that changes with drink, driving, pressure to drink or
drinking games that punish refusal, mocking slurred text, blackouts, hangover
penalties the next day, drinking to fix sadness, and drinking alone in the Flat.
A Homebody character never holds a drink at home.

### 5.3 How regulars react

| Regular | To a Tipsy/Merry player | Their own night arc |
|---|---|---|
| Nam ★ | Merry: "Water's on me too. House rule." Slides a glass over. | Never drinks on shift |
| Tong ★ | "You're singing louder than Jo. I support this." | Stays at Warm: one beer, nursed |
| Ploy ★ | "Hold still, this is a good face. I'm drawing it." | Warm by 21:00, stays there |
| Jules ★ | "Pinball is harder now. More fun. Allez." | Merry by 01:00 on Sat; dances worse, happier |
| Mali | "Have you eaten? I'm ordering fries. Don't argue." | Clear all night; Thai iced tea only |
| Dougie | "Pace yourself, pal. It's a marathon, not a sprint." | Warm from the first lager, never past it |
| Lung Nop | Just smiles and turns his chair to the stage. | Warm after one whisky soda; goes home at 23:00 |
| Bow | Grabs you for a dance. | Tipsy on Fri, Clear if she flies the next day ("Flying tomorrow, water tonight, na") |
| Hiro | Pours you water with full ceremony: "Hydration is also a craft." | Tipsy by midnight; his notes get poetic |

NPC states use the same four animation sets as players, so art builds them once.

---

## 6. Localization

### 6.1 Thai-first lines

These lines are **written in Thai by a native writer first**, then adapted into
English. They are never translated from the English drafts above.

| Line group | Why |
|---|---|
| All Thai regulars' Candle Talk (Tong, Ploy, Mali, Lung Nop, Bow) | Their voice lives in particles and register: Bow's "na" (นะ), Lung Nop's polite radio Thai, Mali's big-sister "nong" |
| All staff lines and real staff catchphrases | Black Cabin staff speak Thai on shift; their real words are the source |
| Plaa Thong and Fah's banter and lyrics | Thai-language acts |
| Seasonal content (Loy Krathong, Songkran) | Cultural accuracy |
| Quiz questions about Thai music | Wordplay |
| Honorifics in every line | P' (พี่), Nong (น้อง), Khun (คุณ), Lung (ลุง) must follow real age gaps; the English keeps them as name prefixes ("P'Daeng", "Lung Nop") |

**Player politeness particle:** Thai speech marks the speaker's gender (ครับ/ค่ะ).
Proposal: character creation asks which particle the player's character uses
(ครับ / ค่ะ / neutral จ้า), and the phrase wheel and player-side Candle Talk cards
use it.

### 6.2 Naming table

| Character | EN display | TH display | Full name (EN) | Full name (TH) | Note |
|---|---|---|---|---|---|
| Bartender ★ | Nam | น้ำ | — | — | Working name for `BAR_1` |
| Bartender 2 | Fern | เฟิร์น | — | — | `BAR_2` |
| Door | Big | บิ๊ก | — | — | `DOOR` |
| Sound engineer | Golf | กอล์ฟ | — | — | `SOUND` |
| Owner | Khun Joy | คุณจอย | — | — | `OWNER` |
| Tong ★ | Tong | ต้อง | Thanakorn Wongsawat | ธนกร วงศ์สวัสดิ์ | |
| Ploy ★ | Ploy | พลอย | Ploypailin Chaiyaporn | พลอยไพลิน ชัยพร | |
| Jules ★ | Jules | จูลส์ | Jules Moreau | จูลส์ โมโร | |
| Mali | Mali | มะลิ | Malinee Srisuk | มาลินี ศรีสุข | |
| Dougie | Dougie | ดักกี้ | Douglas McLeod | ดักลาส แมคลาวด์ | |
| Lung Nop | Lung Nop | ลุงนพ | Noppadol Rattanakul | นพดล รัตนกุล | "Lung" = uncle |
| Bow | Bow | โบว์ | Benjawan Kaewmanee | เบญจวรรณ แก้วมณี | |
| Hiro | Hiro | ฮิโระ | Hiroshi Mori | ฮิโรชิ โมริ | |
| Lung Nop's wife (mentioned) | Pa Dao | ป้าดาว | — | — | Possible anniversary cameo |
| House Lights ★ | The House Lights | เดอะ เฮาส์ ไลท์ส | — | — | Band |
| — vocals | Jo | โจ | Joanna Reyes | โจแอนนา เรเยส | Filipina |
| — bass | Pete | พีท | — | — | |
| — drums | Boy | บอย | — | — | |
| Jazz trio | The Thursday Club | เดอะ เธิร์สเดย์ คลับ | — | — | |
| — piano | Aom | อ้อม | — | — | |
| — upright bass | Jack | แจ็ค | — | — | Australian |
| — drums | Note | โน้ต | — | — | |
| Funk band | Monsoon Funk Unit | มอนซูน ฟังก์ ยูนิต | — | — | |
| — vocals | May | เมย์ | — | — | |
| Thai indie | Plaa Thong | ปลาทอง | — | — | Thai name kept in EN |
| — vocals | Nok | นก | — | — | |
| Blues duo | Soi Dog Blues | ซอยด็อก บลูส์ | — | — | |
| — slide guitar | P'Daeng | พี่แดง | — | — | |
| — harmonica | Mick | มิก | — | — | Australian |
| Singer-songwriter | Fah | ฟ้า | — | — | |
| DJ | DJ Moo Krob | ดีเจหมูกรอบ | — | — | |

---

## 7. Open questions for the orchestrator

1. **Candle Talk lean bonus** (§3.1): approve +5 to the regular's Feeds meter on
   a good Candle Talk? It adds a `needs_config` key and slightly raises the §2.3
   sample totals.
2. **Venue hours and daytime.** The real clock means players will open the game
   at 14:00. Is the bar "open" all day in-game (staff and one or two regulars
   only), or does it show "Doors at 18:00" with the Flat only? Black Cabin's real
   hours are needed.
3. **Tipsiness numbers** (§5.1): one state per 30 real minutes, water drops one
   state, Merry caps alcohol. Confirm. Should other players see your tipsiness in
   P2/P3? Proposal: yes for walk and idle, never as a label.
4. **GDD sample text** says "Thursday, front row, Mali's band". In this cast Mali
   is the quiz captain. Change the GDD example to "the House Lights".
5. **The Velvet Banquette** is in the photos but not in the direction renders or
   greybox. Lung Nop lives there, and so do all heart story beats. Add a
   banquette anchor to the main room, or move story beats to the Candle Floor?
6. **Staff turnover.** If a real staff member leaves Black Cabin, do they stay in
   the game, retire with a goodbye scene, or get swapped silently? Proposal: a
   goodbye postcard, then the slot's working name.
7. **The house band as a real band.** If Black Cabin has a resident band, the
   House Lights should *be* them from day one, since they ship in the first
   playable. That's the most urgent ask.
8. **Player particle** (§6.1): add a ครับ/ค่ะ/จ้า choice to character creation (2B owns the creation UI, 2D the data).
9. **Anonymous patrons:** how many unique voxel patrons does the art budget
   allow? Proposal: 12 bodies from a kit (3 bodies × 4 heads, palette swaps), so
   no patron looks like a regular.
10. **Hearts 4–5** content waits for live-ops chapters. Confirm the first
    playable's 0–3 range is final for the launch build too, or whether launch
    needs 5.

### Summary: what we need from Black Cabin

| Priority | Ask |
|---|---|
| 1 | Who agrees to appear (staff and performers), with signed consent |
| 2 | Resident or house band: names, photos with instruments, 4+ songs with licence status, their real set |
| 3 | Head bartender: photo (front, side, back), nickname in TH and EN, signature drink recipe, one story, 2–3 real catchphrases |
| 4 | Door, sound engineer, owner: same pack as the bartender. Owner also gives the founding story, anniversary date and house toast. |
| 5 | Up to six regular acts: the §4.3 pack, plus which night they really play |
| 6 | Opening hours and the real weekly calendar |
