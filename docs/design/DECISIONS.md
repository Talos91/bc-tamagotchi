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

## Still open

- Chat policy for multiplayer (phrase wheel vs free text, now that the game is 21+).
- The Flat home screen: keep minimal or cut.
