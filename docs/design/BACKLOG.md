# BACKLOG — every idea once, with status and track (living list)

Source of truth for everything Daniele wants. Mirrored by hand on the hub Backlog tab
(https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW); the file wins if they differ. Items are added, never
silently deleted: when one ships mark it live with version and SHA; when one is dropped say why. `STATE.md` holds
only the next jobs. Refreshed 2026-11-15 (Housekeeping) from this file's 11-02 version, owner items 1–33
(`handoffs/owner-feedback-2026-11-02.md`, `-11-04.md`, `-11-09.md`), DECISIONS up to 2026-11-11, `08-presence.md`,
`07-character-creator.md`, LOG and STATE.

**Effort:** S = one worker, a day; M = one worker, a wave; L = several waves or a new system.
**Status:** idea · designed · built-awaiting-acceptance (card id) · live (version, SHA) · parked.
**Track:** **T1** no server, can ship in 0.3.0 · **T2** needs the Supabase backend (accounts, check-ins, presence;
waits on card `presence-supabase-setup`) · **T3** needs a business decision (payments, legal, bar systems).
"Live" = in the build Daniele deployed (v0.2.2, bd50d36, 2026-11-11); "acceptance" cards are on the hub Questions tab.

## 0.3.0 now (2026-11-15; Daniele: "Yes, go")

1. **Backlog refresh** — this file (Housekeeping, done with this commit).
2. **D1 + D2 Tonight + events** — worker running (T1: real October calendar in `docs/venue/events/`; no live feed yet).
3. **New minigame** — design worker running (B3); build only after Daniele's yes on the design.
4. **Venue list** — Daniele's real-place changes go to the parked venue worker (local_9543f6b2) → B14.
5. **T2 waits** on card `presence-supabase-setup` (a Supabase project on Daniele's account): then presence wave 1
   (P1), accounts, check-ins, real top-patrons, leaderboards, chat.
6. Still gating the close of 0.2.x: acceptance cards (look-d-accept and the camera, creator, perf ones in STATE).

## A. Fix first — the gate (Daniele 2026-11-01)

| # | Item | Effort | Needs | Status | Track |
|---|------|--------|-------|--------|-------|
| A1 | Baseline map of the club rebuilt to the real floor map (venue v4), layout frozen | M | — | live (v0.2.x); accepted 11-02 | T1 |
| A2 | Bar-counter strip connected to the walkable floor | S | — | live (228eb2e) | T1 |
| A3 | Playtest fixes: walk-through doors, real sitting, stairs reoriented, memory corner, corridor sign | M | — | live (v0.2.x) | T1 |
| A4 | Real Black Cabin menu (121 drinks, 34 dishes) at the bar and in Pour Perfect; Lato + Kristi; portrait first + landscape toggle | M | — | live (v0.2.x); menu follow-ups accepted | T1 |
| A5 | Smoother camera, see-through walls (bottom 10 %), fluid movement, facing bug, seats; Prae as owner; area views and buttons | M | — | live (v0.2.x) | T1 |
| A6 | Version number in the game, changelog by version | S | — | live (v0.2.0 → v0.2.2, `docs/tech/versioning.md`) | T1 |
| A7 | Camera feel round 2: tighter follow, walls and furniture out of the way, distance/angle (owner 11-02) | M | — | built-awaiting-acceptance (cards camera-feel-2-accept, camera-closer-still, camera-patrons-in-front; 406d2fd, c97abde) | T1 |
| A8 | Web build on Vercel, playable on phones from a link | M | — | live (v0.2.2, https://bc-tamagotchi.vercel.app; `docs/tech/03-web-build.md`) | T1 |
| A9 | Look-D follow-ups (owner items 1, 3, 9, 10, 12: piano player, shelving, library artefacts, band-door shadow, symmetric stage curtain) | M | — | built-awaiting-acceptance (cards look-followups-review, look-followups-layout-export; 84c58e5, 86b40ab) | T1 |
| A10 | Needs and stakes build: stake clock, ghost, annoyances, Retire, farewell card; Ty named (item 2) | M | — | built-awaiting-acceptance (card needs-stakes-review +4; dd4e03c) | T1 |
| A11 | Touch anywhere instead of the fixed joystick; area buttons slide away and back (items 13, 14) | S | — | live (v0.2.x); card touch-anywhere-review open | T1 |
| A12 | Venue fixes: bar door, raised bar and walled area, curtains, toilet door, barrier in unused corridor (items 4–8, 11, 15) | M | — | built-awaiting-acceptance (card venue-fixes-review +2; e4d7e76) | T1 |

## B. The playable world

| # | Item | Effort | Needs | Status | Track |
|---|------|--------|-------|--------|-------|
| B1 | More interactive places beyond bar, stage, tables, pinball | M | map fixed (A1 done) | idea | T1 |
| B2 | Character creator (4 bodies, 8 skins, 8 hair × 8 colours, 3 looks; photo booth in the lounge; items 22, 26, 27) | M | — | live (v0.2.1, c495a35 + fixes); card char-creator-build-review open | T1 |
| B3 | More minigames (today: Pour Perfect, Rhythm, pinball, Candle Talk); a new one now in design | M each | — | designed in progress (design worker running, 0.3.0) | T1 |
| B4 | Achievements as stickers on the club's entry door; shown when you leave and in the Flat | M | the Flat (not built) | idea | T1 |
| B5 | Voxel quality push: more cubes per object without killing a phone | L | phone measurement (items 16, 29, 33) | idea | T1 |
| B6 | Leaderboard per minigame, weekly and monthly | M | accounts, backend | idea | T2 |
| B7 | Entrance corridor portraits of the top 10 customers; open one to read the patron's message | S now, M later | patrons' messages once accounts exist | built (50a0623): ten placeholder portraits and messages; real content later | T2 |
| B8 | Start screen as the club's front door (street, neon sign, tap to enter, door, pull-back) | M | — | live (0dc0b68, v0.2.x); door pull-back smooth on phone (item 16, 166918d, v0.2.2) | T1 |
| B9 | Lounge revamp: merch shop, memory corner, game machine, top-patrons board, decorations | M | — | live (50a0623 + follow-up, v0.2.x); accepted, layout frozen | T1 |
| B10 | Top-patrons board: ranking = real QR check-ins per month | S now, M later | check-ins | built (50a0623): placeholder names; real data later | T2 |
| B11 | Merch shop in the lounge: in-game coin cosmetics now; a real-life merch shop later | M | real merch list from Black Cabin; coins economy (`04-coins.md`) | built (50a0623): stand in; coin cosmetics sheet pending. Real-life merch shop | T3 |
| B12 | Nightlife actions: Light one up, Check the plumbing, drunk debuff, WASTED + 12 h lockout; debug bypass (item 23) | M | — | live (2bde243, v0.2.x) | T1 |
| B13 | Venue look D: blackish walls, voxel cement floor, red neon, dim candles | M | — | built-awaiting-acceptance (card look-d-accept; 6cd9735 + 6df5288; closes 0.2.x) | T1 |
| B14 | Venue changes from Daniele's real-place list (street front, entrance and cocktail photos pending) | M | his list; real photos | parked (venue worker local_9543f6b2 waits for the list) | T1 |
| B15 | Per-area camera: zoom on photo booth and main lounge items, corridor-end framing and wall crossing, curtains facing (items 30–32) | M | — | live (v0.2.1, camera-areas); cards camera-areas-review, -door-dark, -buffer-view open | T1 |
| B16 | Presence P1: real check-ins appear as avatars in everyone's bar, notifications, same-table QR together layer (item 24; `08-presence.md`, all 11 answers as baseline 11-09) | L | Supabase project (card presence-supabase-setup), accounts, check-ins, consent (P1) | designed (v1, a6ca189); wave-1 build waits on T2 | T2 |
| B17 | iPhone works: download, context loss, entry crash (items 20, 28, 29, 33) | M | friend's iPhone confirmation on v0.2.2 | live (v0.2.2); fix chain 11-09…11-11; iPhone still to be confirmed (card iphone-v021-friend) | T1 |
| B18 | Item 16 deeper cut: mesh merge if the door/entry still stutters (~8,000 draw calls) | M | phone numbers | parked (only if lag returns; entrance closed 11-11) | T1 |
| B19 | Camera gaps: area-button focus held after a tap; Sticker door not tappable from the corridor | S | — | idea (STATE job 4) | T1 |
| B20 | Retire settings screen, audio duck, postcards beyond home text, Going bonus, notifications, stitched-scar sticker (needs build left out) | M | audio bus; notifications need T2 | idea (card needs-stakes-retire-ui) | T1 |
| B21 | The Flat, coins and the memories album (not built; stakes v3 docs `06-stakes.md`, `04-coins.md`) | L | stakes-v3 review | designed (docs only; card needs-stakes-review) | T1 |
| B22 | Thai pass: native-speaker review of machine-drafted strings; Thai names in the web font; ♥ glyph | S | native Thai speaker | idea | T1 |

## C. Online and community (all need the Supabase backend)

| # | Item | Effort | Needs | Status | Track |
|---|------|--------|-------|--------|-------|
| C1 | Chat with other players in the club | L | accounts, chat policy (phrase wheel vs free text, 21+) | idea (presence uses the phrase wheel only) | T2 |
| C2 | Cheer button during a set; the band sees a live cheer count | M | backend, band-side view | idea | T2 |
| C3 | Crew quests: weekly goals for a friend group; sponsors can brand them | L | friends, backend; sponsor deals (business) | idea | T3 |
| C4 | Referral reward for bringing a first-time visitor who checks in | M | check-in proof | idea | T2 |
| C5 | Seasonal cosmetics for holidays and themed nights that expire | M | content calendar | idea | T1 |

## D. Real-life bridge

| # | Item | Effort | Needs | Status | Track |
|---|------|--------|-------|--------|-------|
| D1 | Upcoming events list | S–M | calendar in `docs/venue/events/` (October filed; November poster pending) | designed in progress (worker running, 0.3.0) | T1 |
| D2 | "Tonight" tab with the band lineup | S | tonight's lineup source (the events JSON for now) | designed in progress (worker running, 0.3.0) | T1 |
| D3 | Table booking, scaffold only | M | Black Cabin's booking flow | idea | T3 |
| D4 | Band pages: followers, past set lists, "bands you've seen" passport from check-ins | L | band data, check-ins; band consent | idea | T2 |
| D5 | Post a picture from the club at the lounge TV memory corner; counts as a real visit | M | photo upload and storage, moderation, consent for faces | idea | T2 |
| D6 | Tip a band through the app | L | payments provider, legal, band payout | idea | T3 |
| D7 | Ride-home button at last call (Grab link; Grab could sponsor) | S | Grab deep link, sponsor | idea | T3 |
| D8 | Guest list and tickets for special nights: RSVP and a door QR | L | door-side scanner, ticketing | idea | T3 |
| D9 | Dashboard for the bar: attendance per band, busiest hours, redemptions | L | backend, check-ins | idea | T2 |

## E. Questions Daniele still has to answer

Live on the Questions tab of the hub (https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW#questions); the binding
list is "Still open" in `DECISIONS.md`. Gating now: `presence-supabase-setup`, `iphone-v021-friend`, `look-d-accept`.

## F. Accepted debt (not features)

- Performance: 42 lights; the phone measurement gates any further cut (B5, B18). Web build uses lower phone graphics (pixel ratio cap 2, MSAA off).
- Pre-alpha debug panel behind `PRE_ALPHA` in `rules.gd`: off before anything public.
- Camera rig: exit sign and sconces lag when the north wall sinks; lounge camera partly blocked by the curtain wall.
- Figure lighting and head proportions (heads 37–43 % vs 27–34 % in the renders).
- Live manual §15 stale since venue v4.

## Log

- 2026-11-01 — Created from Daniele's alpha verdict and the todo list relayed from the Ooze project.
- 2026-11-02 — Playtest rounds: B7–B13 added, statuses updated (see git history for the detail).
- 2026-11-15 — Full refresh (Housekeeping): every idea one row with status and track (T1/T2/T3); A4–A12 pulled from the hub; owner items 13–33 and presence (item 24) folded in (B14–B22); B2 creator live (v0.2.1), item 16 door entrance closed (DECISIONS 2026-11-11, v0.2.2); "0.3.0 now" section added. Dropped nothing; A-items 1–6, 8, 11 marked live.
