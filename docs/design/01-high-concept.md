# Black Cabin Tamagotchi — High Concept

Status: draft v1 (session 1A, 2026-10-27); revised 2026-11-02 for the stakes
(`06-stakes.md` v3), the Flat and mobile only. Feeds: `02-gdd.md`, art bible,
cast bible, UI.

## Elevator pitch

A cozy voxel game about a character who needs a night out. Your character's
four needs (**Music, Friends, Drinks, Nightlife**) run down in real time over
about a week. You refill them by taking your character to Black Cabin, a
candlelit live-music bar in Bangkok recreated block by block: you order at the
amber-lit bar, catch the house band's set from the front row, sit with the
regulars at the long table, and play pinball in the neon lounge. A visit takes
about ten minutes. Three visits a week keep your character glowing; one rule
keeps them alive: go to the real Black Cabin at least every three weeks.

## The fantasy

"I have a local." Somewhere you can always walk into, where the bartender
remembers your order, the band is always about to start, and a familiar face
waves you over. It's the feeling of a good bar on a good night, without the
hangover, the bill or the trip across town.

## Target player

- **Primary:** 20–35-year-olds who like cozy and collection games (Animal
  Crossing, Neko Atsume, Unpacking, Tamagotchi nostalgia) and like going out,
  or miss it. They play in short bursts on a phone: on the train, before bed,
  on a slow evening at home.
- **Secondary:** Black Cabin's real audience (Bangkok live-music crowd, expats,
  tourists who visited) who want a piece of the place in their pocket.
- **Not for:** players who want competition, combat, or optimisation pressure.

## Platform (decided)

**Mobile only, portrait first with a landscape toggle** (DECISIONS
2026-11-02: "the game is mobile only"). The reasoning below was the original
recommendation and still holds; the desktop build it mentions is a
development tool, not a product.

- The Tamagotchi loop is a check-in loop: short sessions, a few times a week,
  driven by a gentle notification ("Your character is humming to themselves.
  The band's on at 9."). That is a phone habit, not a desktop one.
- A bar interior is tall and deep, not wide. Portrait frames a diorama-style
  view of one zone at a time (stage, bar, lounge) well.
- Tap-to-move and one-thumb minigames suit portrait. Every minigame in the GDD
  is designed for one thumb.
- Godot exports the same project to Android, iOS and desktop, so desktop costs
  little. It's useful for development, streamers and players who prefer it.
- **Consequence for the build:** the camera should be a fixed-angle,
  diorama-style follow camera with tap/click-to-move. A free-orbit
  third-person controller, like a desktop action game, is the wrong default.
  The greybox controller from 1C is fine for walking the space but should not
  be treated as the final control scheme.

## Three design pillars

1. **Going out is the care.** Every refill happens by *doing nightlife things*
   in the venue: listening, drinking, talking, dancing. There are no feeding
   buttons and no menus that fill meters. If an action doesn't feel like
   something you'd do at Black Cabin, it doesn't refill anything.
2. **Cozy, with real stakes.** Needs drain over days and a normal week costs
   nothing; a neglected need is an annoyance you clear in one visit. One thing
   is fatal: skip the real Black Cabin for three weeks and your character dies
   of boredom; a check-in at the bar within two weeks brings them back; after
   that they are gone for good, with everything they had (06-stakes).
3. **The room is the star.** One fixed, authored, real place, faithful to the
   real Black Cabin (velvet curtains, ribbed glass table lamps, candles, the
   orange "BLACK CABIN" sign, the drum kit by the olive tree). It grows through
   what happens in it (performers, events, regulars, decorations, minigames),
   not through players building it.

## How it differs

| Game | What it does | What Black Cabin does instead |
|---|---|---|
| **Animal Crossing** | You own and build an island; daily chores on a real-time calendar. | You own nothing but your look and your memories. You *visit* a place someone else runs. The pull is your character's needs, not a to-do list. |
| **Habbo Hotel** | User-built rooms; chat is the content. | One authored venue with scheduled live content (sets, quiz nights, headline nights). Social play runs through verbs (cheers, sit with, dance with, buy a round), not free chat. NPC regulars keep the room alive when it's quiet. |
| **The Sims** | Needs drain in minutes; constant micromanagement; failure states. | Needs drain over a real week; one 10-minute visit fixes a lot; one failure state, and it is staying away from the bar. |
| **Tamagotchi** | You care for a creature that can get sick or die. | You care for *yourself-as-avatar*, and the care is going out, to the real bar. Neglect makes your character a homebody, then a ghost; a check-in at Black Cabin can still raise them (06-stakes). |

## The "Tamagotchi" hook, stated precisely

Your character has four needs (Music, Friends, Drinks, Nightlife), each a
0–100 meter that drains continuously in real time and empties in roughly 6–10
days. The only way to refill them is to take your character to Black Cabin and
do the things people do there. A typical 10-minute visit restores about 30
points to each meter, so **three visits a week keeps a character happy**.
Let a meter run empty and your character gets an annoyance (Thirsty,
Earworm, Phone face, Rusty) that drags the whole night until you see to it.
The one fatal need is **going to Black Cabin**: a QR check-in at a table or a
memory taken at the real bar (until the server exists, any visit in the game
stands in). Twenty-one days without one and the character dies; fourteen more
and they are deleted with everything they had, unless a check-in at the bar
brings them back first (once per 90 days). Your character lives in a rented
room upstairs once you can afford it (100 coins, then 20 a week).
