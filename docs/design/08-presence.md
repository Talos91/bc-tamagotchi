# 08 — Presence: real check-ins in everyone's bar (owner item 24)

Status: **design v1, 2026-11-09** (🌐 presence-design worker, design only: no game code, no backend created). Owner
calls are in §12 and on the hub card `presence-design-review`; nothing here is built until Daniele answers.

Owner direction (item 24, `handoffs/owner-feedback-2026-11-04.md`, 2026-11-04): live movement of real customers on each
other's phones makes no sense. Instead **simulated presence**: everyone who checks in at Black Cabin in real life
enters the bar of every player; their avatar can be seen and interacted with, and the other player is notified. Then
the ability to enter the other player's world and do things together. The case that matters most: **both check in at
the same table via the table's QR code.**

Sources kept as they are: GDD §2.6 (notifications, 2 a week, quiet after 22:00), §5.2 (headcount 12–20, players replace
anonymous patrons first, never regulars), §5.3 (social verbs, phrase wheel only), §13 ("one social-verb interface shared
by NPCs, echoes and players"); `06-stakes.md` §3 (a QR check-in is one per bar night, Tue–Sun 19:00–02:00 Bangkok, an
after-midnight check-in belongs to the night it started on), §10.8 (what the server provides), O1–O3 as answered
(DECISIONS 2026-11-02: real visits required only after a character's first check-in; no revival before the server;
a memory counts only on a checked-in night); `07-character-creator.md` §4 (the avatar record `profile.avatar`, ids
and swatch names only, small enough to send as-is); `03-cast.md` §1.2–1.3 (Big waves arrivals in at the door;
regulars' seats reserved); `save.gd` (additive keys only); `needs.gd` `check_in()` (already exists: the server will
call it; the debug "Fake check-in" runs it today); `venue_patrons.gd` (80 seated anonymous patrons, hosts first).

Pictures (1080×1920, composed mocks, not the final UI): `docs/art/screens/presence/presence-01-venue-mock.png` (a
checked-in player's view of the Candle Floor with tonight's presences, a tablemate and the verb sheet) and
`presence-02-flow.png` (check-in → presence → who sees what → together layer).

---

## 1. What changes (one paragraph)

There is **no state sync**. Nobody's position, needs or actions stream to anyone. The only shared facts are small
**events** written to a server when something happens: *Mai checked in at table 7 tonight*, *Mai waved at Ploy*,
*Mai and Ploy shared table 7*. Each phone reads tonight's events when it enters the venue (and every two minutes while
inside) and **stages** them with the crowd system it already has: checked-in players sit in the room as avatars in
place of anonymous patrons. This replaces the GDD's P2 *Echoes* and P3 *Live rooms* and the ORCHESTRATION wave-4
"relay + headless host" plan (§11). A live, real-time layer is deferred to a later wave and only for the together
layer (§5.3), never for the room.

## 2. The presence model

### 2.1 A check-in is an event

| Field | Value |
|---|---|
| `checkin_id` | server id |
| `player_id` | the account id (anonymous auth, §7.2) |
| `night` | the bar night (Bangkok; 19:00–02:00, after midnight belongs to the night before: same rule as `needs.night_key`) |
| `table_id` | the venue table the QR code belongs to (§3.1), e.g. `Table0`, `WestTable0`, `BufferTall3` (the ids in `layout.json`) |
| `at` | server time of the scan |
| `avatar` | a **snapshot** of `profile.avatar` (07 §4.2) + `display_name` taken at check-in, so tonight's look is fixed even if the player edits later |
| `visibility` | the player's presence setting at that moment (§2.3) |

One counted check-in per player per night (the stakes rule). A second scan the same night at **another table** moves the
presence to that table (it is the same visit); a scan at the same table refreshes `at` (used by the tablemate window,
§3.2). The client already knows what to do with a check-in: the server's answer triggers `needs.check_in()` (clock
reset, revival in the ghost window), unchanged.

### 2.2 Who sees whom, and for how long

| Viewer | Sees |
|---|---|
| **Any player, anywhere** (in the bar or at home), during the bar night | Every visible presence of **tonight**, seated in their venue (§6), up to the cap. Daniele's "enters the bar of every player". |
| **A player checked in tonight** (physically in the bar) | The same, plus **which real table** each one is at: avatars sit at the matching in-game table (§6.2). |
| **Tablemates** (§3) | Each other first, always on screen together, plus the together layer. |
| **After closing (02:00)** | Avatars leave the room. Tonight's check-ins become **"Last night at Black Cabin"**: a list of names and portraits on the lounge board until the next opening (19:00), no avatars. ★ (call P2) |

Presence lasts **from the scan until closing** (★ P2). There is no "leaving" signal: the bar has no exit scan and the
game must not track anyone. A player who leaves early still shows until 02:00; that is accepted.

**Cap:** the venue now seats 80 anonymous patrons (`venue_patrons.gd seated_count`). Presences replace anonymous
patrons one for one, never regulars, staff or the band, so the room never empties or overfills. Shown at most
`PRESENCE_CAP` = 40 avatars; past that, the door shows "+N more here tonight" and a tap lists them. Order of priority:
tablemates → friends (§5.2) → players you interacted with → the most recent arrivals.

### 2.3 Privacy defaults (what the player decides)

At the **first** check-in, before anything is written, one card asks how the player shows up (★ P1):

- **Everyone** — your avatar and name are in every player's bar tonight.
- **Only people here tonight** — only players checked in tonight see you.
- **Nobody** — the check-in still counts for your character (stakes, Top patrons), you are not shown to anyone.

No option is preselected; the choice is remembered and changed from the in-game menu (Settings → Presence) at any
time; a change applies from the next check-in, and "Nobody" also hides tonight's presence at once.

What another player ever sees about you: **display name, the avatar snapshot, the in-game table** (real table only to
people checked in tonight, ★ P3), and **"first time here" / "regular"** (5+ nights in 90 days). Never: real name,
phone, location beyond the venue, times, how many nights, needs, coins, death or ghost state.

## 3. The table QR: co-presence proof

### 3.1 The code on the table

Each table gets a printed QR code (a table tent or a sticker) holding a URL:
`https://bc-tamagotchi.vercel.app/c/<code>` where `<code>` is a random 10-character token per table (not the table
number, so codes cannot be guessed). The phone's camera app opens it; the web build reads the code from the page
address at start (`JavaScriptBridge`, `window.location`) and asks the server to check in. No in-game camera, no
camera permission. A player who has never opened the game lands on the start screen first; the check-in waits until
the creator and name are done (07 §4.3), then runs.

The server accepts a code when: it is active, the bar is open (Tue–Sun 19:00–02:00 Bangkok), the player has not been
rate-limited (§7.3). A photographed code still works from home; the defences are the one-per-night rule, opening
hours, the night's audit trail and the ability to **reprint one table's code** (deactivate, new token) in a minute.
★ P9 asks whether that is enough for wave 1.

### 3.2 Tablemates

Two players are **tablemates** for the night when their check-ins (or a re-scan) at the **same table** fall within
`TABLEMATE_WINDOW` = 45 minutes of each other. Up to 8 per table (every pair). It is the strongest signal the game can
get that two people are really together, and the together layer (§5) unlocks from it.

What it unlocks, the same night:

| Unlock | What happens |
|---|---|
| **"Mai is at your table"** | Instant in-app toast to both (they have the game open: they just scanned), with both avatars |
| **Seated together** | In both games, and in everyone else's, the two avatars share the table |
| **Table cheers** | One button for both: clink animation, both Friends +8 (the GDD's 60 s "sit with" value), once per night per pair |
| **Table polaroid** | A memory both keep: the two (up to 8) avatars at that table, the date, Black Cabin's frame. It counts as the memory at the bar for both (O3: taken on a checked-in night) |
| **Friend link** | "Add Mai as a friend" (both must accept). Friends see each other's check-ins first and may opt in to a notification (§4) |
| **Nights together** | A counter per pair ("3 nights at the same table"); at 3, 10 and 25 a polaroid frame for both |

## 4. Notifications (opt-in)

| # | What | When | Channel | Budget |
|---|---|---|---|---|
| N1 | "Mai is at your table" | At the tablemate match | In-app toast (both are in the app) | Outside the budget |
| N2 | Waves, cheers and drinks you received | Gathered; shown at your next open (inbox on the start screen, like postcards) | In-app only | None |
| N3 | "Ploy just checked in at Black Cabin" | A **friend** you marked "tell me" checks in | Push, opt-in per friend | ★ P6: at most 1 a night, 19:00–23:00 |
| N4 | "12 people are at Black Cabin tonight" | Friday 20:30 if 8+ are checked in | Push | Inside the GDD's 2 a week (replaces the Friday 18:00 headline line that week) |

Push is **off** until the player turns it on from a one-time card after their first tablemate or friend (the moment
it is obviously useful), not at install. Never a push about someone you blocked or who hides from you; never one that
says where a non-friend is. GDD's "never after 22:00" collides with a bar that opens at 19:00 and fills at 22:00; P6
asks for the friend-check-in exception.

Web build: Web Push works on Android Chrome; on iPhone only once the game is **installed to the home screen** (iOS 16.4+)
— the export is already a PWA. It needs a service-worker push handler added to the exported worker, VAPID keys
(secret, §7.5) and a sender (a Supabase Edge Function). If push is unavailable, N3/N4 fall back to the start-screen
inbox.

## 5. The together layer

### 5.1 Social verbs on a presence (wave 1)

Tap an avatar → its card (name, avatar, "regular" badge, your nights together) with the verbs. The other player is
**not live**: a verb is an event they receive at their next open (N2); the sender sees the animation now.

| Verb | Sender now | Receiver at next open | Limit |
|---|---|---|---|
| Wave | Wave animation, Friends +2 (existing "receive a social verb" row, cap +10 per visit) | "Mai waved at you" + Friends +2 | 1 per pair per night |
| Cheers | Needs a drink in hand; clink | +2 Friends both | 1 per pair per night |
| Send a drink | Coins at the drink's band price (C2: 4/6/9), from the real menu | A free drink in their inventory, "from Mai" | 1 per pair per night; ★ P10 |
| Phrase | One of the 24 preset lines + emoji (GDD §5.3), shown as a bubble | In the inbox | 3 per pair per night |
| Hide / Report | — | — | §7.4 |

The same interface serves NPC regulars (GDD §13): a regular can be waved at the same way, with the effect immediate.

### 5.2 Wave 1 scope (★ P11)

In: presences in the room (§6), the verbs above, tablemates (§3.2: toast, table cheers, table polaroid, friend link,
nights together), the inbox, N1–N4, Last night on the lounge board, Top patrons from real check-ins (already decided).

### 5.3 Deferred

| Later | What | Why later |
|---|---|---|
| **Visit their Flat** (wave 2) | "Enter the other player's world": the Flat upstairs (06-stakes §9) is the player's own instanced room. A friend can walk around it (read-only), see their Memory Wall, leave a sticker. Asynchronous: no server room, just their Flat's public snapshot | The Flat is minimal today; needs Flat customisation first |
| **Live table game** (wave 3) | Tablemates who are both in the app start a short live game together (quiz, a pinball duel) through a 2–8 player room on the Ooze relay pattern | The only place real-time is worth its cost; needs the relay hosted for Black Cabin |
| **Real-world reward** | e.g. "first night at the same table: one free shot", shown to staff | Money and staff flow: the real-world bridge chapter (DECISIONS Still open) |

## 6. Presence avatars in the venue

### 6.1 Spawning

A new step in `venue_patrons.gd` `_ready()`, after `_place_hosts()` and before the anonymous fill (build phase, not now):

1. `Presence.tonight()` returns the cached list (fetched at venue entry; §8).
2. Sort by the priority in §2.2, keep `PRESENCE_CAP`.
3. Seat each (§6.2) with `_spawn()` using the avatar snapshot resolved through the creator's runtime assembly
   (07 §6) instead of a random preset and palette; name the node `Presence_<player_id>`; add to group `presence`.
4. Lower `seated_count` by the number placed so the headcount holds.

New arrivals while the player is inside (the 2-minute poll) **walk in from the street door** to their seat, and
Big waves them in (03-cast §1.2), so the room visibly fills. A presence that turns hidden fades out where it sits.

### 6.2 Seat choice

| Viewer | Seat |
|---|---|
| Checked in tonight | The presence's **real table** (`table_id` = the in-game table of the same name): a free chair there, else the nearest free chair in the zone. Tablemates sit next to each other. |
| Not checked in tonight | A free chair in a zone weighted by the real table's zone (so the Candle Floor still fills when the real one does), never the exact table (★ P3) |
| Anyone | Never a regular's reserved seat, never the player's own seat. Unlike an anonymous patron, a presence is never made to get up for the player (`vacate()` skips group `presence`) |

### 6.3 Idle behaviour

Seated poses as for patrons (`sit_drink`, `sit_talk`, `sit_hold`), plus: when the viewer enters the zone, a friend
or tablemate waves once; when the band plays, front-row presences applaud with the crowd. Once per visit a presence
may "drift" to the bar and back (the regulars' zone drift). No other movement: they are not live.

### 6.4 Telling real people from NPCs

A thin white ring under the chair (the colour of the player's own ring, dimmer) and the name over the head when the
camera is close or on tap. Tablemates get a warm gold ring. Anonymous patrons and regulars have no ring. Mock:
`presence-01-venue-mock.png`.

## 7. The minimal backend (Supabase, on Daniele's account; not created)

### 7.1 Shape

Supabase is enough: Postgres with row-level security, anonymous auth, two or three database functions and one Edge
Function for push. No relay, no headless Godot, no realtime channel (polling every 2 min is cheaper and works through
every network).

| Table | Columns (main) | Who reads / writes |
|---|---|---|
| `profiles` | `player_id` (pk = auth uid), `display_name`, `avatar` jsonb, `presence_mode`, `name_ok_at`, `banned` | Own row read/write; others only through `tonight` |
| `venue_tables` | `code` (pk, random token), `table_id`, `label`, `active` | Server only |
| `checkins` | `id`, `player_id`, `night`, `table_id`, `at`, `avatar` jsonb snapshot, `visibility`; unique (`player_id`, `night`) | Written only by `check_in()`; own rows readable |
| `tonight` (view) | visible check-ins of the current night, minus blocks, with name + avatar + table (table only if the reader checked in tonight) | Any signed-in player |
| `tablemates` | `night`, `table_id`, `a`, `b`, `at` | Written by `check_in()`; the two players read |
| `events` | `id`, `from`, `to`, `kind` (wave, cheers, drink, phrase, table_cheers), `payload`, `night`, `at`, `read_at` | Written by `send_verb()`; recipient reads and marks read |
| `friends` | `a`, `b`, `status` (pending, ok), `notify_a`, `notify_b` | The two players |
| `blocks` | `blocker`, `blocked` | Own rows |
| `reports` | `id`, `reporter`, `target`, `reason` (fixed list), `night`, `at`, `status` | Insert own; Daniele/staff read in the dashboard |
| `push_subscriptions` | `player_id`, `endpoint`, `keys`, `created_at` | Own rows; Edge Function reads |

Functions: `check_in(code)` (validates code, hours, rate limit, one per night; writes the check-in, finds tablemates,
returns `{night, table_id, revived?, tablemates[]}`), `send_verb(to, kind, payload)` (checks block, limits, coins
are spent client-side and the server only records), `delete_me()` (§7.6). Edge Function `notify` (N3, N4).

### 7.2 Auth

Anonymous sign-in at the first check-in (no email, no password); the id lives in the browser's storage beside the save.
Risk: iPhone Safari wipes a website's storage after 7 days unused unless it is installed to the home screen; the
player would lose their account, and the local save with it (same storage). ★ P5: an optional "keep my account"
email link (magic link) from the menu.

### 7.3 Rate limits

| What | Limit |
|---|---|
| Anonymous sign-ins | Supabase's per-IP limit (default 30 an hour); the bar's Wi-Fi shares one IP, so raise it for the bar's network on busy nights or keep 4G |
| `check_in()` | 5 attempts per 10 minutes per player; 1 counted per night; codes only during opening hours |
| Verbs | As §5.1, plus 40 per player per night in total |
| Display name | Changed at most once a day; filtered (07 Q9) before it reaches `profiles` |
| Reads of `tonight` | Client polls every 2 minutes, never faster; cached for the night |

### 7.4 Abuse and moderation

- **No free text anywhere.** The only words a player writes are their display name; verbs and phrases are fixed
  lists. Avatars are built from fixed parts. That removes most moderation work.
- **Hide** (one tap on the card): that player disappears from your bar and can't send you verbs; they are not told.
- **Report** (fixed reasons: offensive name, harassment, other): hides them for you at once and writes a row.
  3 reports from different players in 30 days → the name is replaced with "Guest ####" until reviewed; a review can
  ban (`banned`: no presence, no verbs; the single-player game still works).
- Review: Daniele (or someone he names) in the Supabase dashboard's table view, weekly; a hub tab later if volume asks.
- Every filter hit, report and ban is a row (the audit trail the profile asks for).

### 7.5 Secrets

The Supabase URL and anon key are public by design (row-level security on every table). The service-role key, the
VAPID private key and the SQL migration's seed codes never go in the repo: Edge Function secrets in the Supabase
dashboard. The table-code list goes to Daniele as a printable sheet, not committed.

### 7.6 Data kept about real people (★ P4)

| Data | Kept |
|---|---|
| `checkins` rows | 90 days (the revival cooldown and the "regular" badge need no more), then folded into per-player monthly counts for Top patrons |
| `events` | 30 days after read |
| `tablemates` | 90 days; the "nights together" counter is kept as a number per friend pair |
| `reports` | 1 year |
| `profiles` | Until the player deletes or the character is deleted (06-stakes §6, BACKLOG B6: server rows go with it) |

A "Delete my data" button (Settings → Presence) runs `delete_me()`: every row of the player goes, the local game stays.

### 7.7 What Daniele must create (when the build is approved, not now)

1. A Supabase project on his account, region **Singapore** (ap-southeast-1), free tier (★ P8).
2. Turn on anonymous sign-ins (Authentication → Providers).
3. Run the migration SQL the build worker writes (`supabase/migrations/`, reviewed first).
4. Set the Edge Function secrets (VAPID keys) from a sheet the worker gives him.
5. Give the build worker the project URL and anon key (both public).
6. Print one QR per table from the code sheet: `layout.json` has about 20 table ids (Table0–4, WestTable0–1,
   RectTableE/W, EastTable, LongTable, LoungeTable0–1, BufferTall0–3, OpeningTall0–1, …); the real count and the bar
   stools (one code for the bar, or none) are confirmed with Black Cabin.

### 7.8 What staff see (★ P7)

Recommended for wave 1: **counts only** — tonight's check-ins per table and per hour, and the month's Top patrons,
in a read-only page (a hub tab or a Supabase saved query). No live list of names at tables: it would show staff who is
sitting where and who is "a regular", which the players did not agree to.

## 8. Offline and web-build constraints

- **Single-player never waits on the network.** Venue entry asks for `tonight` with a 4-second timeout; on failure
  the room fills with anonymous patrons as today and a small "offline" dot shows on the door board.
- `tonight` is cached for the night; the 2-minute poll runs only while the venue is open on screen.
- **A check-in needs the server** (it is the stakes proof). Offline scan: "No signal — scan again when you're
  connected"; nothing is queued (a queued check-in could not prove the night).
- Verbs sent offline are queued locally and sent on reconnect if the night has not ended; otherwise dropped with a note.
- Godot's `HTTPRequest` works in the web export (it uses the browser's fetch); Supabase allows any origin for its REST API.
  No WebSockets, no threads, no cross-origin isolation: the export stays single-threaded as today.
- The code in the URL (`/c/<code>`) needs one Vercel rewrite to `index.html`; the game reads and clears it.
- Save stays local (`user://save.json` in the browser's storage). The server holds only the social rows in §7.1, never
  the needs or the stakes state, except the check-in itself. `profile.player_id` (already reserved in `save.gd`) takes
  the auth id: an added value, no `VERSION` bump.
- Rules constants proposed for `rules.gd` at build time: `PRESENCE_CAP` 40, `TABLEMATE_WINDOW_MIN` 45,
  `PRESENCE_POLL_S` 120, `PRESENCE_TIMEOUT_S` 4, `VERBS_PER_NIGHT` 40, and the flag `PRESENCE_ON` (false until the
  backend exists; the debug panel gets "Fake presences" with 12 generated avatars to test the room offline).

## 9. Tests for the build (from the profile)

Scripted two-client cases against a local Supabase (`supabase start`) or a test project: two anonymous players scan
the same table 10 minutes apart → tablemates on both; 50 minutes apart → not; one hides → gone from the other's
`tonight` and verbs refused; check-in at 02:30 → refused; second check-in at another table → moved; offline venue
entry → anonymous room, no error; reconnect → queued wave delivered; `delete_me()` → no rows left. Headless suite
`test_presence` with the "Fake presences" list for seating, cap, headcount and the never-vacated rule.

## 10. Build order (after the answers)

1. Character creator phase 2 (the avatar record must exist and render).
2. Presence client offline: "Fake presences", seating, rings, cards, verbs to a local inbox (`PRESENCE_ON` false).
3. Backend (Daniele creates the project; worker writes migrations and functions; two-client tests).
4. QR check-in through the URL; `REAL_VISIT_REQUIRED` switch (06-stakes §3) on the same release.
5. Push (N3, N4) last.

## 11. What this replaces (amendments to apply after the answers)

| Doc | Change |
|---|---|
| `02-gdd.md` §5.2 | P2 *Echoes* and P3 *Live rooms* → **P2 Presence** (this chapter), **P3 Together** (Flat visits, live table games). Headcount rule kept. |
| `02-gdd.md` §13 | "P3 reuses Ooze Syndicate's server" → only for live table games (§5.3) |
| `ORCHESTRATION.md` wave 4 | "Presence and persistence reusing Ooze's relay + headless host" → "Presence events on Supabase (08-presence); relay only for live table games later" |
| `03-cast.md` §1.3 | "P2 Echoes, P3 Live" → "presences"; Candle Talk row stays for P3 |
| `06-stakes.md` §10.8 | Check-in verification = `check_in(code)` here |
| `docs/tech/01-engine-decision.md` | Note: the 20–50-avatar live room is no longer planned |

## 12. Owner calls (one question each; on the hub card `presence-design-review`)

| # | Question | Options | Recommendation |
|---|---|---|---|
| P1 | **Consent:** how does a player show up after checking in? | (a) **asked once at the first check-in: Everyone / Only people here tonight / Nobody, nothing preselected**; (b) Everyone by default, changeable in settings; (c) Nobody by default, opt in | **(a)** |
| P2 | How long does a presence stay in everyone's bar? | (a) **from the scan until closing (02:00), then a "Last night" list on the lounge board until 19:00**; (b) 3 hours after the scan; (c) until closing, nothing after | **(a)** |
| P3 | **Data shown:** who sees the real table someone sits at? | (a) **only players checked in tonight; others see them in the same zone, not the table**; (b) everyone; (c) nobody, seats are random | **(a)**: someone at home can't tell where a person is sitting right now |
| P4 | **Data kept** about real people | (a) **check-ins 90 days, then monthly counts only; events 30 days; delete-my-data button**; (b) everything 13 months; (c) everything until the player deletes | **(a)** |
| P5 | Accounts | (a) anonymous only; (b) **anonymous, plus an optional "keep my account" email link**; (c) required email or Google sign-in at the first check-in | **(b)**: no sign-up wall at the table, a way back for those who want it |
| P6 | Friend check-in pushes vs "never after 22:00" | (a) **allowed 19:00–23:00, at most 1 a night, opt-in per friend, outside the 2-a-week budget**; (b) inside the budget and the 22:00 rule; (c) no social pushes, in-app only | **(a)** |
| P7 | **What staff see** | (a) **counts only: check-ins per table and hour, Top patrons**; (b) a live list of names per table; (c) nothing | **(a)** |
| P8 | **Money:** backend cost and who pays | (a) **Supabase free tier on Daniele's account until the bar launch, then decide Pro (US$25 a month) with Black Cabin**; (b) Pro from day one; (c) Black Cabin's own account | **(a)**: free tier covers 50,000 monthly users and 500 MB |
| P9 | QR codes and cheating | (a) **one static code per table + one per night + opening hours + reprint a table's code if abused**; (b) the same plus a "word of the night" staff write on a board; (c) a changing QR on a staff tablet | **(a)** for wave 1; (b) if the audit shows home check-ins |
| P10 | **Money (in-game):** "Send a drink" with coins | (a) **yes, at the drink's coin price, 1 per pair per night**; (b) verbs only, no coins between players | **(a)** |
| P11 | The together layer in the first presence wave | (a) **tablemates: toast, table cheers, shared polaroid, friend link, nights together**; (b) (a) plus Flat visits now; (c) presence and verbs only | **(a)**; Flat visits wave 2, live table games wave 3 |
