# Black Cabin Tamagotchi — Art Bible

Status: v1, 2026-10-27. Owner: session 1B. Grounded in the 12 photos in
`docs/reference/venue-photos/` (cited by filename, `IMG_` prefix dropped:
`5843` = `IMG_5843.jpg`). Every later visual sheet follows this document;
nothing here is negotiable without updating it first.

## 0. Reference audit (read before anything else)

The photos do not match the brief one-to-one. This bible follows the photos
where they exist and marks everything else **[brief-only]**.

- **Seen in the photos:** concrete floor (5845, 5846), near-black ceiling
  (5846), floor-to-ceiling rust-red velvet curtains (5852, 5853, 5856), round
  and square wooden tables (5845, 5846), black marble pedestal tables (5849,
  5851), rust-red channel-tufted velvet banquette (5849, 5851), studded
  leather pouffes (5843, 5844), fluted-glass cordless lamps with brass domes
  on every table (all photos), cut-glass tealights (5852, 5853), a candelabra
  with taper candles (5852, 5853), Tolix-style metal chairs (5852–5855),
  bentwood spindle chairs (5849, 5851), orange cove LED strips (5845, 5852,
  5853), disc-reflector floor lamps (5843, 5844, 5845, 5855), an olive tree on
  stage (5843, 5844, 5854), drum kit, sparkle-grille amp, music stands, mic
  stands, wedge monitor (5843, 5844), curio/bottle shelving wall (5849, 5851,
  5855), a backlit orange "BLACK CABIN" lightbox sign (5845), framed prints
  (5847, 5851, 5852), a TOILET/exit sign and a wall sconce (5856).
- **Not visible in any photo [brief-only]:** red neon "BLACK CABIN" sign over
  a plant wall, CRT TV, pinball cabinet, globe lamps, staircase, a bar counter
  seen from the front, red stage wash. A dark sphere on a stand in 5855 may be
  the unlit disco ball (unconfirmed).
- **The light is amber first, red second.** Measured, the room is lit by
  orange-amber (5854 curtain wash `#C75203`, 5852 cove `#C46D1D`); red comes
  from velvet and cove spill (5845 strip `#6A1300`). Red stage wash is kept
  as the late-night show state (section 4), not the default.

## 1. Visual thesis

Black Cabin is a dark, warm diorama of chunky cube voxels in which almost
everything sits in near-black shadow and only small pools of light (a fluted
lamp on each table, tealights, an amber cove strip, a curtain catching the
glow) pull objects and people out of the dark. The voxels make it cozy,
readable and collectible like a toy, while the lighting carries the mood of the
real room: intimate, low, red-velvet-and-amber, a place you go to at night to be
near people and music. We sell the venue by its light, not its geometry, so
the geometry stays simple and the light does the work.

## 2. Voxel rules

**Scale.** One voxel = 6.25 cm (1/16 m) in world space, everywhere. One
resolution for the whole game: no half-voxels, no mixed-scale detail, no
smoothing. Thin things (mic stands, lamp stems, chair rods) are one voxel
wide, never thinner.

**Grid references.**

| Thing | Voxels (W × D × H) | Note |
|---|---|---|
| Character, standing | 10 × 8 × 24 | ~1.5 m, chibi |
| Round café table | Ø12 × H12 | 5845, 5846 |
| Pouffe | Ø8 × H7 | 5843 |
| Chair seat height | H7 | matches pouffe so characters sit at one height |
| Table lamp | 4 × 4 × 7 | 5847: reads larger than real on purpose |
| Room height | 64 | curtains run full height (5853) |
| Architecture module | 16 × 16 | walls, floor, curtain bays snap to this |

**Character proportions.** Head 10 × 10 × 9 voxels on a 14-voxel body: head
≈ 40% of height, ratio head:total ≈ 1:2.5. Arms 2 × 2, legs 3 × 3, no
fingers, no knees. Faces are pixel decals on the front face of the head cube
(2-voxel eyes, 1–2 voxel mouth), not sculpted.

**Round things.** Circles are stepped pixel-circles on the grid, always
symmetrical, always odd diameter when they have a central post (table pedestals,
lamp stems). Below Ø5 a circle becomes a square. Spheres (disco ball, globe
lamps): Ø7–9 voxel stepped spheres. Disco ball facets are per-voxel value
variation plus sparkle particles, never extra geometry. Bottles: 2 × 2 or
3 × 3 columns with a 1 × 1 neck; label = one off-color voxel band. Curtain folds:
alternating 1-voxel depth steps on a 2-voxel rhythm (5853), never curves.

**Detail budget per class.**

| Class | Max size | Max colors | Examples |
|---|---|---|---|
| XS tabletop | 4 vox | 2 + 1 emissive | tealight, napkin cup, glass, mic head |
| S furniture | 12 vox | 4 + 1 emissive | lamp, pouffe, chair, bottle, stand |
| M fixture | 32 vox | 8 + 2 emissive | table, drum kit, amp, candelabra, CRT |
| L feature | 64 vox | 12 + 3 emissive | banquette run, shelf wall, stage, sign |
| Architecture | 16-vox tiles | 3 per tile | curtain bay, concrete floor, wall |

No surface texture inside a voxel. Variation comes from per-voxel value shifts
of ±1 step within a swatch, never noise.

**Never voxelized:** lights and glow, bloom, fog and haze, shadows, particles
(candle flicker, disco sparkles, music notes, steam, dust motes in light),
UI, nameplates, speech bubbles, needs meters, sign lettering at UI scale.
These are rendered smooth on top of the voxel world; the contrast is the
point.

## 3. Palette

Sampled = median of a region in the named photo. Game = the value artists
use. Photo values are underexposed, so game values lift the darks slightly
for readability and push emissives to full. Full rationale lives here; there is
no separate palette file.

**Base (near-blacks, concrete)**

| Name | Sampled | Game | Source |
|---|---|---|---|
| Cabin Black | `#020202` | `#0B0908` | ceiling, 5846 |
| Curtain Shadow | `#190E08` | `#1C1009` | 5846 |
| Lacquer | `#110C09` | `#16100B` | marble top, 5849; leather, 5843 |
| Concrete Dark | `#0B0704` | `#2A231A` | floor shadow, 5846 |
| Concrete Lit | `#645539` | `#6B5C40` | floor, 5845 |
| Olive Wall | `#443B1E` | `#4A4026` | back corridor, 5856 |

**Accent (reds)**

| Name | Sampled | Game | Source |
|---|---|---|---|
| Velvet Deep | `#390D02` | `#3D1007` | banquette shadow, 5849 |
| Velvet Red | `#922B05` | `#8E2410` | lit curtain peak, 5853 |
| Cove Red | `#6A1300` | `#A3200A` emissive | floor strip, 5845 |
| Sign Rust | `#8C2A0F` | `#C2410F` emissive | lightbox, 5845 |
| Neon Red | n/a | `#FF3B24` emissive | [brief-only] neon sign, show wash |

**Warm (amber, candle, wood, brass)**

| Name | Sampled | Game | Source |
|---|---|---|---|
| Amber Wash | `#C75203` | `#D15A0A` | curtain under wash, 5854 |
| Cove Amber | `#BF6212` | `#E07A1E` emissive | wall cove, 5852 |
| Drum Gold | `#CD7A04` | `#D88A12` | stage glow, 5844 |
| Candle Core | `#ECC779` | `#FFD98A` emissive | tealight, 5852 |
| Bulb Cream | `#FFDCA1` | `#FFE6B8` emissive | disc lamp, 5845 |
| Brass | `#7B5B1E` | `#9A7A34` | lamp base, 5849 |
| Walnut | `#593B19` | `#5E3F1C` | table top, 5844, 5852 |

**Cool contrasts (rare)**

| Name | Sampled | Game | Source |
|---|---|---|---|
| Pedal Blue | `#5A68DF` | `#5A68DF` emissive | floor LEDs, 5844, 5845 |
| Sconce White | `#F9F9FE` | `#E8ECF5` emissive | corridor sconce, 5856 |
| Lamp Violet | `#454E6F` | `#6A6F9A` | cool-cast lamp, 5856 |
| Exit Green | n/a | `#2FBF71` emissive | exit sign present, unlit, 5856 |
| Screen Glow | n/a | `#7FD6C2` emissive | [brief-only] CRT |

**Ratios (share of screen pixels in a typical frame):** base 60–70%, warm
15–25%, red 10–15%, cool ≤3%. The darkest 40% of any frame sits at or below
Curtain Shadow. Emissives are the only values above 80% brightness. Pure white
and pure black are never used on geometry. Cool colors only appear as point
sources (an LED, a sign, a screen), never as fill or ambient light.

## 4. Lighting model

The venue is defined by light, not geometry. Ambient light is near zero;
every readable object is lit by a nearby source.

**Source 1: candle and table lamp (the heartbeat).** Every table has a
fluted-glass lamp on a brass dome plus one or two cut-glass tealights (5847,
5852). Voxel treatment: the lamp shade and tealight cup are emissive voxels
(Candle Core), with a small warm point light (radius ~2 m, Candle Core
color) pooling on the tabletop, and a 1–2 Hz brightness flicker of ±8% on
tealights only. The pool on the table and the underlit faces of whoever sits
there are the main subject of every shot.

**Source 2: amber shelf and cove light (the room tone).** Orange cove strips
along the base of the curtains and walls (5845, 5852, 5853) and the curio shelf
wall (5855) give the room its horizon of warm light. Voxel treatment: a 1-voxel
emissive line (Cove Amber or Cove Red) plus a long, low area light grazing up
the curtain so the folds read as amber stripes (5854). Shelf cubbies get one
emissive back-panel voxel row each so bottles silhouette against it.

**Source 3: red neon and stage wash (the event light).** The "BLACK CABIN"
sign (5845, orange lightbox; red neon in the lounge [brief-only]) and the stage.
Voxel treatment: sign lettering as 1-voxel emissive tubes in Neon Red or Sign
Rust, with strong bloom; stage wash as a coloured spot light, never baked.

**Post stack:** bloom on emissives only (threshold high, so concrete never
glows); light volumetric haze, densest near the stage; a strong vignette
(corners at ~35% brightness); slight warm grade (lift shadows towards Curtain
Shadow, not grey); optional tilt-shift depth of field for screenshots and
key art. In Godot this maps to emissive StandardMaterial3D, WorldEnvironment
glow, volumetric fog and a vignette post shader; 1C decides the engine.

**Time states.**

| State | When | Look |
|---|---|---|
| Day | venue "closed", prep | House work-lights on, cool-neutral, concrete and curtains read at mid value, lamps off. Used for decorating and menus. The only state where the room is legible end to end. |
| Evening | doors open, quiet sets | Default. Table lamps and tealights on, cove amber, stage in Drum Gold (5844, 5854). |
| Late night | headline show | House drops further, stage wash shifts to Neon Red, haze up, disco sparkle on, coves turn Cove Red, cool pedal LEDs on stage become visible. |

## 5. Materials

| Material | Where | Voxel treatment |
|---|---|---|
| Velvet | curtains, banquette (5849, 5853) | Velvet Deep base, Velvet Red on fold crests; folds are 1-voxel steps; banquette channels are 2-voxel ribs. Matte, high roughness, picks up colored light strongly. |
| Concrete | floor (5845, 5846) | 16-vox tiles, two values (Concrete Dark/Lit) in large soft patches, occasional 1-voxel crack line. Slight sheen to catch lamp pools. |
| Wood | tables, chairs (5845, 5852) | Walnut, 2-step value variation along the grain direction only. Semi-gloss top faces so lamps reflect (5852). |
| Leather | pouffes (5843) | Lacquer base, one highlight row on the top edge, studs as a 1-voxel ring of Brass every other voxel. |
| Glass | lamp shades, tealight cups, bottles | Emissive when lit; fluted shades are vertical stripes alternating two values (5847). Bottles are translucent amber, never clear. |
| Metal | brass (lamp domes, napkin cups), black steel (Tolix chairs, stands) | Brass: metallic, low roughness, 3 values. Black steel: Lacquer with one highlight edge. |
| Marble | pedestal tables (5849) | Lacquer base with 1-voxel lighter veins, very glossy. |
| Neon tube | sign [brief-only] | 1-voxel emissive line, unlit backing panel in Cabin Black. |
| Plant wall / olive | lounge [brief-only], stage olive (5843) | Clusters of 1-voxel leaves in two dark olive values on 1-voxel branches; reads as silhouette against amber, never as bright green. |

## 6. Object kit inventory

Size classes from section 2. **P** = photo-grounded, **B** = brief-only.

**Bar and shelves**
- Shelf wall with cubbies, bottles, curios, books (L, P 5849/5855)
- Bar counter with backlit bottle shelf (L, B)
- Bottles: tall, short, squat; amber, green, clear-tinted (S, P 5849)
- Bar stool (S, B), glassware set (XS, B)

**Tables zone**
- Round café table, hairpin legs (M, P 5843/5844)
- Round wooden table, 4 legs (M, P 5845/5846)
- Square table, X-braced (M, P 5856)
- Black marble pedestal table (M, P 5849/5851)
- Long communal table (M→L, P 5852/5854)
- Leather pouffe (S, P 5843), wooden chair (S, P 5846), Tolix chair (S, P 5852), spindle chair (S, P 5849)
- Velvet banquette, modular 16-vox runs (L, P 5849/5851)
- Fluted lamp (S, P all), cut-glass tealight (XS, P 5852), brass napkin cup (XS, P 5847), candelabra (M, P 5852/5853)

**Stage**
- Stage platform with rug (L, P 5843/5855)
- Drum kit (M, P 5844), sparkle-grille amp (S, P 5843), guitar amp stack (M, P 5844)
- Mic stand boom/straight (S, P 5844), condenser mic (XS, P 5844), music stand (S, P 5844)
- Wedge monitor (S, P 5843), PA speaker (M, P 5856)
- Olive tree in planter (M, P 5843/5854)
- Disc floor lamp (S, P 5845), disco ball (S, B/possibly 5855)

**Lounge**
- "BLACK CABIN" lightbox sign (M, P 5845); red neon version over plant wall (L, B)
- Plant wall module (L, B), CRT TV (S, B), pinball cabinet (M, B), globe lamps (S, B)
- Framed prints, B&W photo, painting (S, P 5847/5851/5852)

**Stairs and circulation**
- Staircase, black steel and concrete (L, B)
- Curtain bay module (Architecture, P), cove light strip (Architecture, P 5852)
- TOILET/exit sign (S, P 5856), wall sconce (S, P 5856), black ceiling with track lights (Architecture, B; ceiling P 5846)

## 7. Character style

**Read at a glance in the dark.** Every character carries one warm rim light
from the nearest lamp and a faint fill so the head is never lost. Main outfit
colors sit at mid value (40–70% brightness); an all-black outfit must have one
trim in a warm or brass swatch. Faces always face-lit enough that both eyes
read at phone size.

**Silhouette rules.** The head cube is the identity: hair and headwear may
extend it by up to 4 voxels in any direction, and that extension is the main
silhouette signal. Bodies stay a simple 6–8 voxel block; distinct body
silhouettes come from one accessory (instrument case on the back, long coat,
tote bag, scarf). No two NPC regulars share a head silhouette.

**Players vs NPC regulars.** Players get a smooth (non-voxel) nameplate and
can wear anything in the catalogue. Regulars have a fixed signature item that
players cannot buy (the drummer's sticks in a back pocket, the bartender's
apron and towel), a fixed seat or spot, and slightly higher-saturation colors so
they stand out in a crowd. Staff wear Cabin Black with Brass trim.

**Customization slots.** Skin tone (8 swatches, warm-biased), face (eye set,
mouth set, optional blush/freckle decal), hair (style + color), headwear, top,
outerwear, bottom, shoes, held item (drink, instrument, phone), back item.
Outfit colors pick from a 24-swatch wardrobe palette derived from section 3
plus mid-value neutrals; no neon garments except as event rewards.

**Needs read through pose and props, not voxels.** Slumped idle when Nightlife
is low, drink in hand when Drinks is refilled; meters themselves are UI.

## 8. Style anchor

Attach this block verbatim to every image prompt, after the sheet's prompt
body. Do not edit it per sheet; change it only by updating this document.

```
STYLE ANCHOR — BLACK CABIN
Cozy voxel diorama of an intimate Bangkok live-music bar at night. Chunky uniform cube voxels, crisp visible cube edges, one voxel size, no smoothing, no surface textures. Chibi voxel characters with large cube heads (about 40% of body height), simple pixel-dot eyes, clear silhouettes. The room is mostly near-black; light comes only from small warm sources: fluted-glass table lamps on brass bases, tealights in cut glass, amber cove strips, rust-red velvet curtains catching the glow. Palette: near-black, warm grey concrete, deep rust-red velvet, amber, candle gold, brass, rare tiny points of cool blue. Soft bloom on light sources, light haze, dark vignette. Elevated three-quarter view, miniature tilt-shift feel. Warm, quiet, intimate.
```

**Negative list (attach as negative prompt or "avoid:" line):**

```
smooth or rounded surfaces, mixed voxel sizes, Minecraft-style block textures, pixel-art textures on cubes, realistic human proportions, photorealism, daylight, bright evenly lit room, white walls, pastel or kawaii candy colors, cyberpunk pink-and-blue neon, purple lighting, green ambient light, harsh flat lighting, lens flare streaks, chromatic aberration, text, logos, watermark, signature, cluttered crowd filling the frame
```

## 9. Sheet plan

Generate in this order; each sheet must pass review before the next. Every
prompt = body below + style anchor + negative list. Reviewer checks palette
ratios (section 3) and voxel budget (section 2) on every sheet.

1. **Style anchor sheet.** Subject: a single round café table vignette.
   Body: "A single round walnut café table on a concrete floor, a fluted glass
   lamp and a cut-glass tealight on it, two leather pouffes, one chibi voxel
   character seated holding a drink, a rust-red velvet curtain behind with an
   amber cove strip at its base. Isolated vignette on near-black background,
   square format." Purpose: lock the look; this image becomes the visual
   reference attached to every later sheet.
2. **Venue mood triptych.** Subject: the same main-room angle in Day,
   Evening and Late night. Body: "Three panels side by side of the same voxel
   live-music bar main room from the same elevated three-quarter angle: stage
   with drum kit and olive tree at left, round tables with glowing lamps in the
   middle, velvet curtains at back. Panel 1 prep time with neutral work lights
   and lamps off; panel 2 evening with table lamps and amber coves; panel 3
   late-night show with red stage wash, haze and disco sparkles."
3. **Prop kit A: tables zone.** Body: "Prop sheet on a dark grey grid
   background, items evenly spaced in rows with no overlap, all at the same
   scale, three-quarter view: round café table with hairpin legs, round wooden
   table, square X-braced table, black marble pedestal table, long communal
   table, leather studded pouffe, wooden café chair, black metal Tolix chair,
   bentwood spindle chair, velvet tufted banquette segment, fluted glass lamp,
   cut-glass tealight, brass napkin cup, candelabra with taper candles."
4. **Prop kit B: stage.** Same layout body, items: stage platform with rug,
   drum kit, sparkle-grille combo amp, guitar amp stack, boom mic stand,
   straight mic stand, condenser mic, music stand, wedge monitor, PA speaker,
   olive tree in planter, disc-reflector floor lamp, mirror disco ball.
5. **Prop kit C: bar and lounge.** Same layout body, items: shelf wall with
   cubbies and bottles, bar counter with backlit bottles, bar stool, assorted
   bottles, glassware, "BLACK CABIN" lightbox sign, red neon sign, plant wall
   module, CRT TV, pinball cabinet, globe lamps, staircase section, exit sign.
   Hold the brief-only items until Daniele confirms them (section 0).
6. **Character lineup.** Body: "Lineup of eight chibi voxel characters
   standing in a row on a dark stage floor, front view, same height, each lit
   by a warm rim light: a drummer, a bartender with apron, a shy regular in a
   hoodie, a couple in going-out clothes, a singer, an office worker after
   work, an older jazz fan in a hat. Varied hair and headwear silhouettes,
   mid-value clothing colors." Cast names come from 2A when available.
7. **Turnaround.** Body: "Character turnaround sheet of one chibi voxel
   player avatar, front, three-quarter, side, back, three-quarter back, on a
   dark grey grid, neutral pose, plus a separate row of swappable parts:
   three hairstyles, two hats, three tops, two bottoms, shoes, held drink."
8. **UI kit.** Body: "Game UI kit sheet for a cozy voxel bar game: four
   round need meters (music note, two friends, cocktail glass, crescent moon)
   in amber and rust red, buttons, a speech bubble, a nameplate, a memory
   polaroid card, inventory slots; smooth flat shapes with soft glow on near-
   black translucent panels." UI is the one sheet where voxels are not used;
   keep the anchor but add "UI elements are smooth, not voxel" to the body.
   2B's style guide supersedes this sheet once written.
9. **Key art.** Body: "Wide key art of the full voxel venue during a late-
   night show: band on stage under red wash, crowd of chibi characters at
   lamp-lit tables, bartender behind the glowing shelf wall, the BLACK CABIN
   sign glowing, haze in the light beams, disco sparkles across the curtains.
   Cinematic, inviting, 16:9."

## 10. Anti-references

1. **Minecraft / textured block worlds.** Per-face textures add noise that
   fights the lighting; in a dark room it turns to mud. Our voxels are flat
   color and let light carry the detail.
2. **Pastel cozy (Animal Crossing, bright kawaii café sims).** Evenly lit
   pastel rooms erase what makes the place worth visiting: the dark, the
   intimacy, the pools of light. Cozy here means warm and close, not bright.
3. **Cyberpunk neon bar (pink-and-blue, Blade Runner, synthwave).** Black
   Cabin's neon is a single warm red sign in a room of amber and velvet. Cool
   magenta-cyan grading reads as a club, not a cabin, and breaks the palette
   ratios in section 3.
