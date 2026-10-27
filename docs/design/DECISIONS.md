# Decisions log

Settled by Daniele unless noted. Newest at the bottom. Every worker session
reads this before the GDD; where the two disagree, this file wins until the
GDD is updated.

| Date | Decision |
|------|----------|
| 2026-10-27 | **Commissioned by Black Cabin.** The game is an official Black Cabin product: use the real name, logo, brand, venue likeness, and (where they agree) real staff and performers. |
| 2026-10-27 | **Age rating 21+.** No age restrictions to design around. |
| 2026-10-27 | **Alcohol and intoxication are in.** Drinks are real drinks; intoxication effects are allowed as gameplay and character behaviour. The GDD's "no intoxication effects" proposal is overruled. |
| 2026-10-27 | **Music: both.** Commissioned original tracks and licensed tracks from real performers. |
| 2026-10-27 | **Event clock runs in real time.** Needs decay and the event schedule follow the real clock; no compressed game-time outside debug builds. Time zone for events: Bangkok time by default (it is the real venue), unless Daniele says player-local. |
| 2026-10-27 | **Languages at launch: English and Thai.** All UI text and content goes through a string table from day one. |
| 2026-10-27 | **Platform: phone portrait is primary; desktop/landscape is a secondary export of the same project.** Camera is a fixed-angle diorama follow camera with tap-to-move; minigames are one-thumb. The direction renders stay the look target; portrait frames one zone at a time. |
| 2026-10-27 | **Single-player first playable; multiplayer later.** The first playable follows GDD §14 (no multiplayer, no shop). Save format and systems must not block adding presence later. |
| 2026-10-27 | **Visual target = `docs/art/direction/` renders.** The three voxel renders are the authority; the art bible is being revised to match them. |
| 2026-10-27 | **Orchestrator calls after wave 2** (reversible by Daniele): (a) `SOFT_FLOOR_FACTOR` goes from 0.5 to 0.3 so the 6–9 day empty window in GDD §2 holds; (b) Welcome Back ×2 replaces, never stacks with, the daily ×0.75; (c) Neon Pinball runs on the arcade cabinet's screen (the renders show a cabinet, not a pinball table); (d) Screen Cyan is approved as the Nightlife meter colour in UI only; (e) meter numbers hidden by default; (f) Bangkok time wins everywhere, including event schedule; (g) the string table lives at `game/i18n/strings.csv`, owned by gameplay sessions; (h) the Flat stays as the minimal home screen; (i) the Velvet Banquette is added to the main room (it is in the real venue photos) and to the kit; (j) room height is 4 m / 80 voxels per the art bible, greybox adjusts; (k) Candle Talk +5 lean bonus approved; (l) tipsiness: one state per 30 real minutes, water drops one, Merry caps; other players later see walk and idle only; (m) anonymous patrons: 12 bodies from a kit; (n) hearts 0–3 for the first playable; (o) the ครับ/ค่ะ/จ้า particle choice goes into character creation; (p) `rendering/viewport/hdr_2d=true` is required in `project.godot` (glow washes out the Compatibility renderer otherwise). |
| 2026-10-27 | **The player's character is the Tamagotchi; the GDD stands.** The overall-look mockup (`docs/art/direction/04-overall-look-mockup.webp`) is a reference for interface *style* (dark HUD, glyph icons, need bubbles over heads, isometric room view), not for functionality. Its Mood/Energy/Tidiness meters and Serve/Clean/Decor actions are not the design. |
| 2026-10-27 | **Orientation is open again.** Daniele's first idea was landscape; portrait was the GDD's recommendation. Decision deferred. Until then build so both work: the venue, camera and HUD must run at 1080×1920 and at 1920×1080; every screenshot set includes both. |
| 2026-10-27 | **Coins: yes. Decor: no.** A virtual currency is in; players never decorate or build the venue (pillar 3, the room is authored). What coins are earned from and spent on (drinks, wardrobe, memories, tips to performers) needs a GDD chapter before any implementation. |
| 2026-10-27 | **The app is a bridge to the real Black Cabin.** Confirmed real-world features: give discounts; win merch; win drinks; book tables; show the real event calendar; request songs; MAYBE order to the table from the app. These need a GDD chapter, a redemption flow the real staff can verify, and a backend (Supabase, as Ooze Syndicate uses). Coins and real-world rewards must be designed together. |
| 2026-10-27 | **Neglect must have stakes.** Daniele: since it is a Tamagotchi, some interactions must be mandatory or the character "dies" (or the game's equivalent). GDD §2.5 currently says nothing breaks at 0. The exact consequence is open (see Still open); pillar 2 "cozy, never punishing" is softened to "cozy, with real stakes". |
| 2026-10-28 | **Neglect is fatal.** If the character is neglected long enough it is gone for good; its memories stay in the album; the player creates a new character. Pillar 2 becomes "cozy, with real stakes". GDD §2.5 ("nothing breaks at 0") is overruled; the exact timeline, warnings, mandatory weekly interactions and what survives need a GDD chapter before implementation. |
| 2026-10-28 | **Venue layout comes from direction renders 01–03 only.** Stage left, bar right, tables at the back when entering the main room through the curtain. The overall-look mockup (04) is never a layout source. The first integration pass followed 04 and is being redone. |

## Still open

- Black Cabin's real opening hours (drives what the game shows at 14:00: open all day with staff only, or "Doors at 18:00" with the Flat only).
- Staff turnover policy if a real person leaves (proposal: goodbye postcard, then the slot's working name).
- Brand typeface: does Black Cabin have one, or do we keep Kanit + IBM Plex Sans Thai Looped.
- The asks to Black Cabin listed at the end of `03-cast.md` (consent, house band, staff packs).

- Death rules: how long at zero, warnings, which interactions are mandatory per week, what survives (needs a GDD chapter).
- Real-world bridge design: redemption flow, staff-side verification, what a booking or song request needs from Black Cabin's systems.
- Orientation: landscape vs portrait primary (see above).
- Coin economy design (earn/spend, no decor).
- Chat policy for multiplayer (phrase wheel vs free text, now that the game is 21+).
- The Flat home screen: keep minimal or cut.
