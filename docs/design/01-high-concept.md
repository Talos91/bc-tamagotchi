# Black Cabin Tamagotchi — High Concept

Status: draft v1 (session 1A, 2026-10-27). Feeds: `02-gdd.md`, art bible, cast bible, UI.

## Elevator pitch

A cozy voxel game about a character who needs a night out. Your character's
four needs (**Music, Friends, Drinks, Nightlife**) run down in real time over
about a week. You refill them by taking your character to Black Cabin, a
candlelit live-music bar in Bangkok recreated block by block: you order at the
amber-lit bar, catch the house band's set from the front row, sit with the
regulars at the long table, and play pinball in the neon lounge. A visit takes
about ten minutes. Three visits a week keep your character glowing.

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

## Platform recommendation (orchestrator decides)

**Phone, portrait, as the primary platform. Desktop as a secondary build of the
same game.**

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
2. **Cozy, never punishing.** Needs drain over days, not hours. Empty meters
   change how your character looks and acts, and never cost items, progress
   or friends. Coming back after a month is welcomed, not penalised.
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
| **The Sims** | Needs drain in minutes; constant micromanagement; failure states. | Needs drain over a real week; one 10-minute visit fixes a lot; no failure state. |
| **Tamagotchi** | You care for a creature that can get sick or die. | You care for *yourself-as-avatar*, and the care is going out. Neglect makes your character a homebody, never sick. |

## The "Tamagotchi" hook, stated precisely

Your character has four needs (Music, Friends, Drinks, Nightlife), each a
0–100 meter that drains continuously in real time and empties in roughly 6–9
days. The only way to refill them is to take your character to Black Cabin and
do the things people do there. A typical 10-minute visit restores about 30
points to each meter, so **three visits a week keeps a character happy**.
Neglect has no lasting cost: an empty meter only changes your character's mood,
look and idle behaviour until the next night out.
