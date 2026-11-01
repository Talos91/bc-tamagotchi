# BACKLOG — ideas, requests and questions (living list)

Source of truth for everything we want but have not scheduled. Mirrored to the
shared "Black Cabin Backlog" artifact for Daniele; the file wins if they differ.
Items are added, never silently deleted: when one ships, mark it done with the
commit; when one is dropped, say why. `STATE.md` holds only the next three jobs.

Effort: S = one worker, a day; M = one worker, a wave; L = several waves or a
new system. Needs: what has to exist outside the game before the item can ship.

## A. Fix first — the gate (Daniele 2026-11-01)

Verdict on the first playable: "fun, fucked up but fine, good alpha".
"We need to fix the baseline map of the club, everything else comes after, as
it is a community game so at least the base needs to be fixed." New photos and
a layout plan are coming from Daniele; until then the layout stays frozen.

| # | Item | Effort | Needs | Status |
|---|------|--------|-------|--------|
| A1 | Baseline map of the club rebuilt to the real floor map (venue v4) | M | Daniele's acceptance | built, awaiting acceptance |
| A2 | Bar-counter strip connected to the walkable floor (known navmesh gap) | S | — | done (228eb2e) |
| A3 | Playtest fixes: walk-through doors, real sitting on tap-to-sit, stairs reoriented (2026-11-01 notes) | M | — | in progress |

## B. The playable world

| # | Item | Effort | Needs | Status |
|---|------|--------|-------|--------|
| B1 | More interactive places (beyond bar, stage, tables, pinball) | M | map fixed (A1) | idea |
| B2 | Character creation (creator UI on the accepted v2 presets) | M | — | planned (STATE job 3) |
| B3 | More minigames (today: Pour Perfect, Rhythm, pinball, Candle Talk) | M each | — | idea |
| B7 | Framed photos of regular customers on the entrance corridor walls (could tie to achievements or the photo feature) | S | map v4 | idea |
| B8 | Start screen as the club's front door: still first-person view from outside facing the street door under a lit Black Cabin neon sign; tap to enter, door opens, camera follows the character's view inside, door closes, camera pulls back to the game view, play starts (Daniele 2026-11-01) | M | walking doors (A3), street facade | next, after A3 |
| B4 | Achievements as stickers on the club's entry door; shown when you leave and in the Flat before you go out | M | — | idea |
| B5 | Voxel quality push: more cubes per object without killing a phone (pairs with the performance pass) | L | phone measurement first | idea |
| B6 | Leaderboard per minigame, weekly and monthly | M | online backend, accounts | idea |

## C. Online and community

| # | Item | Effort | Needs | Status |
|---|------|--------|-------|--------|
| C1 | Chat with other players in the club | L | online backend, accounts, chat policy (phrase wheel vs free text, 21+) | idea |
| C2 | Cheer button during a set; the band sees a live cheer count | M | online backend, band-side view | idea |
| C3 | Crew quests: small weekly goals for a friend group ("try the featured cocktail", "catch two new bands"); sponsors can brand them | L | online, friends, sponsor deals | idea |
| C4 | Referral reward for bringing a first-time visitor who checks in | M | online, check-in proof | idea |
| C5 | Seasonal cosmetics for holidays and themed nights that expire | M | content calendar | idea |

## D. Real-life bridge (needs Black Cabin data or systems)

| # | Item | Effort | Needs | Status |
|---|------|--------|-------|--------|
| D1 | Upcoming events list | S–M | real October 2026 calendar in `docs/venue/events/` (monthly posters + JSON) | idea |
| D2 | "Tonight" tab with the band lineup | S | tonight's lineup source | idea |
| D3 | Table booking: scaffold only, not wired to a real system | M | later: Black Cabin's booking flow | idea |
| D4 | Band info and band pages: follower count, past set lists, "bands you've seen" passport filled by check-ins | L | band data, check-ins | idea |
| D5 | Post a picture taken at the club, shared at the lounge's TV memory corner (direction 25); counts as the monthly refill of one need and goes into the memories album | M | photo upload, moderation, consent for faces | idea |
| D6 | Tip a band through the app | L | payments provider, legal, band payout | idea |
| D7 | Ride-home button at last call (Grab link; Grab could sponsor) | S | Grab deep link | idea |
| D8 | Guest list and tickets for special nights: RSVP and a QR that works at the door | L | door-side scanner app, ticketing | idea |
| D9 | Dashboard for the bar: attendance per band, busiest hours, redemptions | L | online backend, check-ins | idea |

## E. Questions Daniele still has to answer

- Black Cabin's real opening hours (what the game shows at 14:00).
- Orientation: portrait or landscape primary (both work today; F7 swaps).
- Brand typeface, or keep Kanit + IBM Plex Sans Thai Looped.
- Staff turnover policy when a real person leaves.
- Resident band, consent and staff packs (asks at the end of `03-cast.md`).
- Death rules: how long at zero, warnings, what survives.
- Coin economy sign-off (`04-coins.md`).
- Chat policy for multiplayer (phrase wheel vs free text).
- The Flat home screen: keep minimal or cut.
- Black Cabin's real drinks menu (six placeholder drinks today).
- Real photos of the entrance corridor; day version of the outside (later).

## F. Accepted debt (not features)

- Performance: 42 lights, ~1,850 draw calls, 24 ms GPU on desktop; phone measurement before any phone build.
- Lounge camera partly blocked by the curtain wall.
- Figure lighting and head proportions (heads 37–43 % vs 27–34 % in the renders).
- Native Thai pass; Thai line-height override; web export check.
- Coins, the Flat, memories album, performances schedule not built.

## Log

- 2026-11-01 — Created from Daniele's alpha verdict and the todo list relayed from the Ooze project.
- 2026-11-01 — B8 start-screen idea added; A1 built, A2 done, A3 in progress.
