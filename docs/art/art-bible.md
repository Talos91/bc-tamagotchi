# Black Cabin Tamagotchi — Art Bible

Status: v2, 2026-10-27. Owner: session 1B. Every later visual sheet follows
this document; nothing here is negotiable without updating it first.

## Direction renders (the visual target)

Daniele's three voxel renders in `docs/art/direction/` are the authority. Where
they disagree with the real-venue photos, the renders win.

| File | View |
|---|---|
| `01-main-room-from-entrance.webp` | Main room toward the stage: long communal table and round tables left, bar right, red curtains and glowing slatted backdrop behind the stage, disco ball, track lights |
| `02-entrance-lounge.webp` | Entrance lounge: red neon "BLACK CABIN" on a plant wall, black beams with red-lit ceiling panels, white columns, long table, arcade/vending cabinet, collectibles shelf, stairs up; the red curtain on the right leads to the main room |
| `03-main-room-from-bar.webp` | Main room from the bar end: bar left, round tables and black drum-stools centre, red-carpeted stage right with drums, guitars, mics, amps |

Layout: entrance lounge → curtain → main room; the main room sits to the right
of the main bar. Renders are cited as R01, R02, R03. The 12 photos in
`docs/reference/venue-photos/` (cited as `5843` = `IMG_5843.jpg`) remain the
"real place" reference for objects and materials the renders do not show
closely. The renders contain no characters; character rules (section 7) are
scaled to the render furniture.

## 0. Reference audit

The renders resolve every item v1 flagged as brief-only:

| Brief item | Status |
|---|---|
| Red neon sign over plant wall | Shown, R02 |
| Bar with backlit bottle shelves | Shown, R01, R03 |
| Disco ball | Shown, R01, R03 |
| Staircase | Shown, R02 (left, with lit step edges) |
| CRT TV | Shown as a small blue-screen monitor on a cabinet, R02 |
| Pinball cabinet | Replaced by an upright arcade/vending cabinet with a blue screen, R02 |
| Globe lamps | Not shown; a glass globe sits on the collectibles shelf, R02. Dropped as a lamp type |
| Red stage wash | Shown as the default look, R01, R03 |
| Track lights | Shown on every ceiling, R01–R03 |

**v1 was wrong about the light.** The photos read amber-first; the renders
are **red-first**: the stage carpet, slatted backdrop, curtains, lounge ceiling
panels and neon are all saturated red, and amber is the second light (bar
shelves, table lamps, coves). This bible now follows the renders.

## 1. Visual thesis

Black Cabin is a crisp voxel diorama of a night-time music bar in which
saturated red light (stage carpet, glowing slatted backdrop, velvet curtains,
neon) fills the room and small amber cubes (table lamps, tealights, backlit
bottles) mark every place to sit. The cubes stay visibly cubic, with per-voxel
color jitter and glossy surfaces that catch reflections, so the place reads as
a collectible toy model, but the lighting gives it the real venue's mood: warm,
low, intimate, a little theatrical. Darks are deep warm red-browns rather than
black voids, so the whole room stays legible while the light still does the
storytelling.

## 2. Voxel rules

**Scale.** One voxel = 5 cm (1/20 m) world-space, measured from the renders
(round table top ≈ 14 voxels across, R03). One resolution for the whole venue:
no half-voxels, no smoothing, no bevels beyond a dark seam between voxels.
Thin parts (mic stands, lamp stems, chair legs, stair rails) are one voxel
wide, never thinner.

**Measured from the renders.**

| Object | Voxels (W × D × H) | Source |
|---|---|---|
| Round table | Ø14 top, H15, 4 square legs | R03 foreground |
| Long communal table | 14 × 60+, H15 | R01 |
| Café chair | 8 × 8, seat H9, back H18 | R01, R03 |
| Bar stool with back | 8 × 8, seat H16, back H24 | R01 |
| Drum-stool (audience pouffe) | Ø9, H9, recessed 1-voxel ring on top | R03 |
| Table lamp | base 3 × 3 × 1, stem 1 × 1 × 5, shade 3 stepped tiers (4×4, 3×3, 2×2), H10 | R01 |
| Tealight lantern | 2 × 2 × 3, fully emissive | R01, R03 |
| Napkin cup | 2 × 2 × 3, off-white | R03 |
| Bottle | 1 × 1 × 3–4, cap voxel one step lighter | R03 bar |
| Disco ball | Ø14 stepped sphere on a 2 × 2 drop rod | R03 |
| Bass drum | Ø10, kick head 1 voxel thick | R03 |
| Room height | 80 | R01 |
| Architecture module | 20 × 20 | walls, floor, curtain bays snap to this |

**Character proportions.** Character height 30 voxels (≈1.5 m, so a seated
character's head clears the table lamp). Head 12 × 12 × 11 on an 18-voxel body:
head ≈ 40% of height, head:total ≈ 1:2.5. Arms 3 × 3, legs 4 × 4, no fingers,
no knees. Faces are pixel decals on the front of the head cube (2-voxel eyes,
1–2 voxel mouth).

**Round things.** Stepped pixel-circles, always symmetrical, odd diameter when
there is a central post. Round tables read as stepped octagons with a 1-voxel
lip (R03). Drum shells are stepped cylinders with a 1-voxel gold hardware ring
top and bottom; cymbals are 1-voxel-thick stepped discs in gold (R03). The disco
ball is a stepped sphere where every surface voxel is a separate mirror tile:
mid-grey base, with individual tiles lit white, amber or red by reflection
(R03). Below Ø5 a circle becomes a square.

**Surface finish (from the renders).** Each voxel carries random value jitter
of ±2 steps within its swatch; floors and wood show it most (R01). Every voxel
edge has a thin darker seam, so cubes count even on flat surfaces. Tabletops,
the bar top and the floor are glossy and show soft reflections of lamps and red
light (R01, R03). Velvet, carpet, plants and pouffes are matte. No painted
texture inside a voxel.

**Detail budget per class.**

| Class | Max size | Max colors | Examples |
|---|---|---|---|
| XS tabletop | 4 vox | 2 + 1 emissive | tealight, napkin cup, bottle, mic |
| S furniture | 14 vox | 4 + 1 emissive | lamp, chair, drum-stool, guitar |
| M fixture | 40 vox | 8 + 2 emissive | table, drum kit, amp, arcade cabinet |
| L feature | 80 vox | 12 + 3 emissive | bar run, slatted backdrop, stage, plant wall |
| Architecture | 20-vox tiles | 3 per tile | floor, curtain bay, column, beam |

**Never voxelized:** light volumes and glow, bloom, haze, shadows, particles
(candle flicker, disco sparkles, music notes, dust in beams), UI, nameplates,
speech bubbles, needs meters. These render smooth over the voxel world.

## 3. Palette

Sampled = median of a region in the named render. Game = the value artists
paint with (emissives pushed to full, darks kept warm). Photo = the matching
real-place value from v1, secondary reference only.

**Base (darks, floor, structure)**

| Name | Sampled | Game | Source | Photo |
|---|---|---|---|---|
| Cabin Dark | `#1E0E0D` | `#1C0D0C` | ceiling, R01 | `#020202` |
| Beam Black | `#160A0C` | `#160A0C` | lounge beams, R02 | — |
| Ceiling Plum | `#2A0B11` | `#2A0E12` | ceiling, R03 | — |
| Stool Black | `#1B0908` | `#221110` | drum-stools, R01 | `#110C09` |
| Floor Grey | `#311D26` | `#3A2C30` | floor in shade, R03 | `#2A231A` |
| Floor Lit | `#6B3D33` | `#7A5248` | floor near lamps, R01 | `#645539` |
| Column White | `#956072` | `#E4DDE6` | lounge columns (tinted by red), R02 | — |

**Accent (reds)**

| Name | Sampled | Game | Source | Photo |
|---|---|---|---|---|
| Velvet Shadow | `#430105` | `#3E0408` | curtain folds, R01 | `#390D02` |
| Velvet Red | `#820108` | `#8C0610` | banquette, R02 | `#922B05` |
| Carpet Red | `#860000` | `#9A0A12` | stage carpet, R01, R03 | — |
| Slat Red | `#CA131A` | `#D0161C` emissive | slatted backdrop, R01 | — |
| Panel Red | `#AD080E` | `#B80A10` emissive | lounge ceiling panels, R02 | — |
| Neon Red | `#FF190E` | `#FF2A14` emissive | neon core, R02 | — |
| Neon Halo | `#EB6B29` | `#F06A2A` bloom | neon edge, R02 | `#8C2A0F` |
| Drum Red | `#842719` | `#9A2A1A` | drum shells, R03 | — |

**Warm (amber, candle, wood)**

| Name | Sampled | Game | Source | Photo |
|---|---|---|---|---|
| Lamp Gold | `#FFDD78` | `#FFDD78` emissive | lamp shade, R01 | `#ECC779` |
| Tealight | `#F7DB71` | `#F7DB71` emissive | lantern, R01 | `#ECC779` |
| Shelf Amber | `#FE7E2A` | `#FF8A30` emissive | backlit bottles, R03 | `#C46D1D` |
| Soffit Peach | `#E0723E` | `#E8814A` emissive | bar light panels, R01 | — |
| Cymbal Gold | `#F66F1D` | `#E8A030` | cymbals, R03 | `#7B5B1E` |
| Table Wood Lit | `#B54C24` | `#B5582C` | tabletop under lamp, R03 | `#593B19` |
| Wood Mid | `#753121` | `#6E3522` | long table, R01 | `#5E3F1C` |
| Wood Dark | `#3C1006` | `#3F1A10` | chairs, R01 | — |
| Bar Front | `#5C1309` | `#5E1C10` | bar panels, R03 | — |

**Cool contrasts (points only)**

| Name | Sampled | Game | Source |
|---|---|---|---|
| Exit Cyan | `#29E8F8` | `#2AE6F5` emissive | exit signs, R01 |
| Screen Cyan | `#0FD5FD` | `#18D0FA` emissive | arcade cabinet, R02 |
| Stage Blue | `#00BFED` | `#20A8F0` emissive | stage PAR, R03 |
| Plant Green | `#1A1A0E` | `#2E3A1A` | plant wall in shade, R02 |

**Ratios (share of screen pixels):** base 45–55%, red 25–35%, warm 15–20%,
cool ≤3%. Luminance targets, measured on the renders: 10th percentile ≈ 10/255,
median ≈ 30–37/255, 90th percentile ≈ 90–105/255. Darks are warm red-browns,
never pure black. Emissives are the only values above ~85% brightness. Cool
colors appear only as small sources (exit signs, screens, a stage PAR), never
as fill light. Green appears only as dark plant foliage.

## 4. Lighting model

The venue is defined by light, not geometry. Ambient light is low and red;
every readable object is lit by a nearby source.

**Source 1: red stage and neon (the room color).** The slatted backdrop is
1-voxel vertical slats with 1-voxel gaps in front of a Slat Red emissive
panel, with two rows of small amber "window" lights across its upper third
(R01). The stage carpet is Carpet Red and also lit by red spots, so it glows
(R03). Red cube PARs hang on the truss (R01, R03). In the lounge, the panels
between the black beams are emissive Panel Red (R02) and the neon is 1-voxel
Neon Red tubes with a Neon Halo bloom. Red spills onto the glossy floor in long
reflections (R02).

**Source 2: amber bar (the warm horizon).** Back-bar cubbies are Shelf Amber
emissive panels with 1 × 1 bottles silhouetted in front (R03). A row of Soffit
Peach light panels runs above the bar and a 1-voxel amber strip runs under the
counter lip (R01). Thin amber cove strips run along wall bases in the main room
(R03, right wall).

**Source 3: table lamps and tealights (the heartbeat).** Every table carries a
stepped-shade lamp and one or two 2 × 2 × 3 lantern cubes, all emissive Lamp
Gold/Tealight, each with a small warm point light that pools on the glossy top
(R01). Tealights flicker ±8% at 1–2 Hz; lamps are steady.

**Bloom and post.** Bloom is medium: a soft halo about 1–2 voxels wide around
emissives, strong enough that lamp shades blur at their edges, never strong
enough to wash a surface. Light haze, thickest over the stage. Mild vignette
(corners ~70% brightness, gentler than v1). Grade warm; shadows lift towards
Cabin Dark, not grey. Shallow depth of field only for screenshots and key art.
Godot mapping: emissive StandardMaterial3D, WorldEnvironment glow,
screen-space reflections or reflection probes for the glossy floor, volumetric
fog; 1C decides the engine.

**Time states.**

| State | When | Look |
|---|---|---|
| Day | venue closed, prep | Work-lights on, neutral; red backdrop and neon off; floor and columns read as true grey and white. For decorating and menus. |
| Evening | doors open | The renders. Red backdrop, red carpet, neon on; lamps, tealights, bar shelves on. |
| Late night | headline show | House amber drops 30%, red spots and haze up, disco ball turns and throws red/white sparkle particles across curtains and floor, blue PARs pulse on beat. |

## 5. Materials

| Material | Where | Voxel treatment |
|---|---|---|
| Velvet | curtains, banquette (R01–R03; 5853) | Velvet Shadow base, Velvet Red crests; curtain folds are 1-voxel depth steps on a 2-voxel rhythm; banquette has vertical 2-voxel channels (R02). Matte. |
| Carpet | stage (R03) | Carpet Red with ±2 jitter, matte, stepped edge to the stage riser. |
| Floor tile | all floors (R01–R03) | 1-voxel square grey tiles with dark seams and value jitter, glossy, takes long colored reflections. |
| Wood | tables, chairs, bar front | Table Wood / Wood Mid / Wood Dark, jitter along the grain direction; glossy tops, matte legs. |
| White tile | lounge columns, stair wall, wall beside stage (R02, R03) | Column White with visible tile seams on a 2-voxel grid; tints strongly with nearby light. |
| Black structure | beams, stage risers, amps, speakers (R02, R03) | Beam Black / Stool Black, one lighter highlight edge per form. |
| Glass and bottles | lamps, lanterns, bottles | Emissive when lit. Bottles are 1 × 1 columns in amber, green and clear-tint, lit from behind. |
| Mirror | disco ball | Per-voxel tiles, mid-grey base, individually lit by reflection. |
| Brass and gold | lamp bases, cymbals, drum hardware | Cymbal Gold, metallic, 3 values. |
| Neon tube | sign (R02) | 1-voxel Neon Red core, Neon Halo bloom, letters in a chunky pixel font. |
| Plants | plant wall, stage tree, planters (R01, R02) | Clustered 1-voxel leaves in 2–3 dark greens on 1-voxel branches; silhouettes against red light, never bright green. |

## 6. Object kit inventory

Size classes from section 2. Source render(s) in brackets.

**Bar (main room)**
- Bar counter run with wood front panels and under-lip amber strip (L, R01/R03)
- Back-bar of backlit cubbies with bottles (L, R01/R03)
- Light soffit panel row above the bar (L, R01)
- Tall bar stool with back (S, R01)
- Bottles, three heights and three tints (XS, R03)
- Pixel-art paintings in red frames (M, R01/R03)

**Tables zone (main room)**
- Round table, 4 legs (M, R01/R03)
- Long communal table with chairs both sides (L, R01)
- Café chair (S, R01/R03)
- Drum-stool: black cylindrical audience pouffe (S, R01/R03)
- Table lamp (S), tealight lantern (XS), napkin cup (XS) (R01/R03)

**Stage**
- Stage riser with steps and red carpet (L, R01/R03)
- Slatted red backdrop with window lights (L, R01)
- Red velvet curtain bays (Architecture, R01/R03)
- Drum kit: red shells, white kick head, gold cymbals and hardware (M, R03)
- Electric guitar, red, on stand; bass/guitar, yellow (S, R03)
- Guitar amp, bass amp, speaker cabinets (S–M, R01/R03)
- Wedge monitors (S, R03)
- Mic stands with red mic heads (S, R03)
- Stage tree in planter (M, R01)
- Truss with red and blue cube PAR lights (L, R01/R03)
- Disco ball on drop rod (S, R01/R03)

**Entrance lounge**
- Red neon "BLACK CABIN" sign (M, R02)
- Plant wall framing the sign (L, R02)
- Red velvet banquette under the sign (L, R02)
- Long table with stepped-shade lamps and woven-back chairs (L, R02)
- White square columns (Architecture, R02)
- Black beam grid with red emissive ceiling panels (Architecture, R02)
- Arcade/vending cabinet with blue screen (M, R02)
- Small CRT-style monitor on a low cabinet, with a lit poster box beside it (S, R02)
- Collectibles shelf: figurines, busts, glass globe, mini disco ball, boxes, small plants (L, R02)
- Long counter/high table with stools in front of the shelf (L, R02)
- Red disc wall lamp (S, R02; also 5845 disc lamps)
- Floor cube lanterns and planters with voxel bushes (S, R02)
- Wall-mounted AC units (S, R02)

**Stairs and circulation**
- Staircase with black steel stringer, rail and amber step lights (L, R02)
- Entrance curtain to the main room (Architecture, R02)
- Exit signs, cyan (XS, R01/R03); small red signs (XS, R01)
- Wall lantern sconce (S, R01)
- Track light rails with spot heads (Architecture, R01–R03)
- Hanging speakers and projector box (S, R01/R03)

## 7. Character style

**Read at a glance in red light.** The renders are dominated by red, so
characters must not depend on red to read. Every character gets a warm rim
light from the nearest lamp. Main outfit colors sit at mid value; red outfits
need a contrasting trim (cream, gold, black) or they vanish against the carpet
and curtains. Both eyes must read at phone size.

**Silhouette rules.** The head cube is the identity: hair and headwear may
extend it by up to 5 voxels, and that extension is the main silhouette signal.
Bodies stay a simple 8–10 voxel block; secondary silhouette comes from one
accessory (guitar case, long coat, tote, scarf). No two NPC regulars share a
head silhouette.

**Players vs NPC regulars.** Players get a smooth (non-voxel) nameplate and can
wear anything in the catalogue. Regulars have a fixed signature item players
cannot buy (the drummer's sticks, the bartender's apron and towel), a fixed
spot, and slightly higher saturation. Staff wear Cabin Dark with Cymbal Gold
trim.

**Customization slots.** Skin tone (8 swatches, warm-biased), face (eye set,
mouth set, optional blush/freckle decal), hair (style + color), headwear, top,
outerwear, bottom, shoes, held item (drink, instrument, phone), back item.
Outfit colors come from a 24-swatch wardrobe palette built from section 3 plus
mid-value neutrals and a few greens and blues for contrast; neon garments only
as event rewards.

**Needs read through pose and props.** Slumped idle when Nightlife is low,
drink in hand when Drinks is refilled; meters are UI.

## 8. Style anchor

Attach verbatim to every image prompt, after the sheet's prompt body. When the
image model accepts reference images, also attach R01 and R03 (or R02 for
lounge sheets). Test: a new render must sit next to the three direction renders
without looking out of place.

```
STYLE ANCHOR — BLACK CABIN
Detailed voxel diorama of an intimate live-music bar at night, every surface built from small visible cubes with thin dark seams and slight per-cube color variation, no smoothing. Saturated red light dominates: red carpeted stage, glowing red slatted backdrop, red velvet curtains, red neon. Warm amber accents: glowing cube table lamps and tealight cubes on wooden tables, backlit amber bottle shelves behind the bar. Glossy grey tiled floor reflecting red and amber. Dark warm ceiling with black beams and small track spotlights, a voxel mirror disco ball. Tiny cyan exit signs as the only cool color. Medium bloom on light sources, light haze. Wide interior view, elevated eye level, sharp focus, cozy and theatrical.
```

**Negative list (negative prompt or "avoid:" line):**

```
smooth or rounded surfaces, low-poly, mixed voxel sizes, Minecraft grass or stone textures, painted textures on cubes, photorealism, realistic people, daylight, evenly lit room, pure black void, pastel or kawaii colors, pink-and-cyan cyberpunk grading, purple fill light, green ambient light, blown-out bloom, lens flare streaks, chromatic aberration, fisheye distortion, text other than BLACK CABIN, logos, watermark, signature
```

## 9. Sheet plan

Generate in order; each sheet must pass review before the next. Every prompt
= body + style anchor + negative list (+ R01/R03 as image references where
supported). Reviewer checks the palette ratios and luminance targets (section
3) and the voxel measurements (section 2).

1. **Style anchor sheet.** Body: "One round wooden voxel table on a glossy grey
   tile floor with a stepped-shade cube lamp, two tealight cubes and a napkin
   cup, two café chairs and one black drum-stool, a red velvet curtain behind,
   red stage light spilling from the right. Isolated vignette, square format."
   Purpose: confirm the anchor reproduces R03's furniture at the same scale.
2. **Venue mood triptych.** Body: "Three panels of the same voxel bar main room
   from the R01 angle (stage and slatted red backdrop at the back, long table
   left, bar right). Panel 1 daytime prep with neutral work lights, backdrop
   and neon off; panel 2 evening exactly as in the reference; panel 3
   late-night show with heavier red spots, haze and disco-ball sparkles."
3. **Prop kit A: bar and tables.** Body: "Voxel prop sheet on a dark plum grid
   background, items evenly spaced in rows, same scale, three-quarter view:
   round table, long table section, café chair, bar stool with back, black
   drum-stool, table lamp, tealight cube, napkin cup, bottles in three heights
   and tints, back-bar cubby section with bottles, bar counter section, framed
   pixel-art painting."
4. **Prop kit B: stage.** Same layout body, items: stage riser with steps and
   red carpet, slatted backdrop section, curtain bay, drum kit, red electric
   guitar on stand, yellow bass, guitar amp, bass amp, speaker cabinet, wedge
   monitor, mic stand with red mic, red PAR light, blue PAR light, truss
   section, disco ball, stage tree.
5. **Prop kit C: lounge and circulation.** Same layout body, items: BLACK CABIN
   neon sign on plant wall section, red banquette section, white column,
   beam-and-red-panel ceiling section, arcade cabinet, small monitor on
   cabinet, collectibles shelf, floor cube lantern, planter, red disc wall
   lamp, AC unit, staircase section, exit sign, track light rail.
6. **Character lineup.** Body: "Lineup of eight chibi voxel characters, about
   twice the height of a café table, standing on the red stage carpet, front
   view, warm rim light: a drummer, a bartender with apron, a shy regular in a
   hoodie, a couple in going-out clothes, a singer, an office worker after
   work, an older jazz fan in a hat. Varied hair and headwear silhouettes,
   mid-value clothing that contrasts with red." Names from 2A when available.
7. **Turnaround.** Body: "Turnaround of one chibi voxel player avatar: front,
   three-quarter, side, back, three-quarter back, on a dark plum grid, neutral
   pose, plus a row of swappable parts: three hairstyles, two hats, three tops,
   two bottoms, shoes, held drink."
8. **UI kit.** Body: "Game UI kit for a cozy voxel bar game: four round need
   meters (music note, two friends, cocktail glass, crescent moon) in red and
   amber, buttons, speech bubble, nameplate, memory polaroid card, inventory
   slots; smooth flat shapes with soft glow on dark plum translucent panels.
   UI elements are smooth, not voxel." 2B's style guide supersedes this sheet.
9. **Key art.** Body: "Wide key art of the voxel venue during a late-night
   show: band of chibi voxel characters on the red carpeted stage, crowd at
   lamp-lit round tables and drum-stools, bartender in front of the backlit
   shelves, disco ball throwing sparkles, haze in the red beams. 16:9."

## 10. Anti-references

1. **Minecraft / textured block worlds.** Our cubes have per-voxel color jitter
   and dark seams, but never painted textures (grass, stone, planks). Textures
   add noise that fights the lighting and turns red-lit scenes to mud.
2. **Pastel cozy (Animal Crossing, bright kawaii café sims).** Evenly lit
   pastel rooms erase the night, the red and the pools of lamp light that make
   the place worth visiting. Cozy here means warm and close, not bright.
3. **Cyberpunk neon (pink-and-cyan, synthwave, Blade Runner).** The renders
   use one dominant red plus amber, with cyan only in tiny exit signs and
   screens. Magenta-cyan grading reads as a club, not a cabin, and breaks the
   ratios in section 3.
