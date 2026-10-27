# Black Cabin Tamagotchi — UI Style Guide

Status: v1, 2026-10-27. Owner: session 2B. Reads: `DECISIONS.md`,
`02-gdd.md`, `art/art-bible.md`. Supersedes art bible §9 sheet 8 (UI kit).
Layouts per screen live in `wireframes.md`; text rules in
`strings-guidelines.md`.

## 1. UI thesis

**The room is the light; the UI is the table it sits on.** The interface is
dark, warm and quiet: low panels in the room's own near-black, cream text, and
one colour of accent at a time, so the red stage and the amber lamps stay the
brightest things on screen. UI never glows harder than a tealight, never
covers the zone the character is standing in, and gets out of the way the
moment the player is watching a set.

Three consequences:

1. **Panels are dark, not glassy.** No frosted blur, no bright white cards.
   UI surfaces are Cabin Dark at high opacity with a 1 px warm edge. The scene
   behind them is darkened, never blurred, so the room stays recognisable.
2. **Accent is spent sparingly.** At most one red element (the primary action)
   and one lit amber element (the thing to look at) per screen. Everything
   else is cream on dark.
3. **UI is smooth, the world is voxel.** Per art bible §2, meters, bubbles,
   nameplates and icons are never voxelised. Flat shapes, rounded corners,
   no bevels. The contrast between soft UI and crisp cubes is what keeps them
   from blurring together.

## 2. Palette

UI colours are taken from the art bible game values; three new neutrals
(Candle Cream, Smoke, Ash) are derived from Lamp Gold and Cabin Dark for text.
Tokens are the names used in the Godot theme (`ui_theme.tres`).

| Token | Hex | Source | Use |
|---|---|---|---|
| `bg.base` | `#1C0D0C` | Cabin Dark | Full-screen backgrounds, panels (92% opacity over the scene) |
| `bg.deep` | `#160A0C` | Beam Black | Sheets, modal backdrops, minigame frames |
| `bg.raised` | `#2E1614` | Cabin Dark +1 step | Cards, list rows, input fields |
| `bg.plum` | `#2A0E12` | Ceiling Plum | Selected row, pressed state |
| `line` | `#4A2A24` | Wood Dark, lifted | 1 px panel edges, dividers |
| `text.primary` | `#F6EBDD` | Candle Cream (new) | Body and headings |
| `text.secondary` | `#C4ADA2` | Smoke (new) | Captions, metadata, inactive tabs |
| `text.tertiary` | `#A8907F` | Ash (new) | Timestamps, hints. Minimum for any text |
| `accent.red` | `#8C0610` | Velvet Red | Primary button fill |
| `accent.red.hi` | `#D0161C` | Slat Red | Primary button hover/pressed, focus ring, Music meter |
| `accent.neon` | `#FF2A14` | Neon Red | Brand moments only: logo, "LIVE" tag, minigame title. Never a text background |
| `accent.amber` | `#FF8A30` | Shelf Amber | Drinks meter, highlights, "new" dots |
| `accent.gold` | `#FFDD78` | Lamp Gold | Friends meter, Vibe candle, rewards, secondary button text |
| `accent.cyan` | `#18D0FA` | Screen Cyan | Nightlife meter only |

### Contrast (WCAG 2.x, checked)

| Foreground | Background | Ratio | Verdict |
|---|---|---|---|
| Candle Cream | Cabin Dark `#1C0D0C` | 16.0 | AAA, all text |
| Candle Cream | raised `#2E1614` | 14.4 | AAA |
| Candle Cream | panel over Slat Red light (88% Cabin Dark) `#310E0D` | 14.9 | AAA; panels survive the red stage |
| Smoke | Cabin Dark | 8.9 | AAA |
| Smoke | raised | 7.9 | AAA |
| Ash | Cabin Dark / raised | 6.3 / 5.6 | AA, all sizes |
| Lamp Gold | Cabin Dark | 14.3 | AAA |
| Shelf Amber | Cabin Dark | 8.0 | AAA |
| Screen Cyan | Cabin Dark | 10.3 | AAA |
| Slat Red | Cabin Dark | 3.4 | **Non-text only** (meter fills, focus rings ≥ 3:1) |
| Neon Red | Cabin Dark | 5.0 | AA text, but reserved for brand words |
| Candle Cream | Velvet Red `#8C0610` | 8.3 | AAA; primary button label |
| Candle Cream | Slat Red `#D0161C` | 4.7 | AA; pressed button label |
| Candle Cream | Neon Red `#FF2A14` | 3.2 | **Fail** for body; never put text on Neon Red |
| Cabin Dark | Lamp Gold / Shelf Amber | 14.3 / 8.0 | AAA; dark text on gold/amber chips is fine |

Rules: body text is Cream or Smoke only. Ash is the floor; nothing dimmer
carries words. Red is a fill or an edge, not a text colour, except Neon Red
in the brand wordmark. Never encode meaning in red vs amber alone (common
colour-blindness confuses them): every coloured element also has a glyph or a
fixed position.

## 3. Typography

Two families, both open-licence (OFL), both with full Latin and Thai, so a
heading never switches face when the language changes.

| Role | Face | Weights | Why |
|---|---|---|---|
| **Display** (brand voice) | **Kanit** | SemiBold 600, Bold 700 | Loopless, slightly condensed Thai and Latin; the voice of Bangkok gig posters and bar menus. Tight, confident, reads like a chalkboard lineup |
| **Text** | **IBM Plex Sans Thai Looped** (Latin set included) | Regular 400, Medium 500, SemiBold 600 | Looped Thai is the most legible at small phone sizes and for older readers; Plex's Latin is calm and pairs cleanly with Kanit |

The neon **BLACK CABIN** wordmark is a logo asset (pixel letterforms, art
bible §5), never typeset. Use Kanit for everything else that shouts.

### Scale (phone, at 1x = 1 dp)

| Style | Face | Size / Latin line-height | Thai line-height | Use |
|---|---|---|---|---|
| `display.xl` | Kanit 700 | 32 / 36 | 32 / 48 | Week Recap title, minigame result |
| `display.l` | Kanit 600 | 24 / 28 | 24 / 38 | Screen titles, zone name on entry |
| `display.s` | Kanit 600, +4% tracking (Latin only) | 14 / 18 | 14 / 22 | Labels: LIVE, NEXT SET, meter names |
| `body.l` | Plex 500 | 17 / 24 | 17 / 28 | Dialogue bubbles, card text |
| `body` | Plex 400 | 15 / 21 | 15 / 25 | Default |
| `caption` | Plex 400 | 13 / 18 | 13 / 21 | Metadata, hints. Minimum size |

### Thai rules

- **Line-height:** Thai lines are set at roughly 1.6–1.65x the font size (vs
  1.3–1.4x Latin) to leave room for stacked upper vowels and tone marks
  (e.g. ที่, ปี้) and lower vowels (ู, ุ). Implement as a per-locale theme
  override, not per label.
- **Vertical padding:** containers add 2 dp top and bottom in Thai so marks
  are never clipped. Never set `clip_text` on a label that can hold Thai.
- **Line breaking:** Thai has no spaces between words. Use Godot's
  TextServerAdvanced (ICU dictionary breaking). Never break inside a word;
  content writers may insert U+200B zero-width spaces at safe break points in
  long strings.
- **No tracking, no fake bold, no italics** on Thai. Kanit's Latin letter
  spacing applies to Latin only.
- **Minimum size:** 13 dp for Thai (same as Latin caption), but no Thai body
  smaller than 15 dp in dialogue or Candle Talk cards.
- **Uppercase** styling (`display.s`) only transforms Latin; Thai has no case
  and keeps the same string.

### Fallback chain

`Kanit` → `IBM Plex Sans Thai Looped` → `Noto Sans Thai Looped` →
`Noto Sans` → `Noto Color Emoji`. Fonts are bundled with the build, never
loaded from the OS (Web export cannot rely on system Thai fonts). Subset for
the web export: Latin-1 + Thai block (U+0E00–0E7F) + the punctuation and
symbols used in the string table.

## 4. Needs meter component

The four meters are the game's main readout. Fixed order everywhere, left to
right or top to bottom: **Music, Friends, Drinks, Nightlife**. Order, glyph
and colour all say the same thing, so any one is enough.

| Need | Glyph | Fill colour | Room source |
|---|---|---|---|
| Music | single eighth note | Slat Red `#D0161C` | the stage |
| Friends | two overlapping heads | Lamp Gold `#FFDD78` | the table lamps |
| Drinks | coupe glass | Shelf Amber `#FF8A30` | the back bar |
| Nightlife | crescent moon with one spark | Screen Cyan `#18D0FA` | the arcade screen, the one cool light |

### Two sizes

- **Full meter** (Flat, week recap, walk-out summary): glyph in a 40 dp
  circle, label in `display.s`, horizontal bar 8 dp tall with 4 dp radius,
  track `bg.raised`. Bar width fills the column.
- **Compact meter** (venue HUD): a 36 dp ring (3 dp stroke) around the glyph,
  four in a row. The ring fills clockwise from 12 o'clock. No labels; the
  glyph is the label. Tap the row to expand to full meters in a sheet.

No numbers by default. Settings > Show numbers adds the value (0–100) beside
each full meter for players who want it.

### States

| State | Value | Look |
|---|---|---|
| **Full** | 100 | Bar complete, one small gold spark on the glyph; overflow gains show "+Tab" instead of "+N" |
| **Healthy** | 40–99 | Plain fill at full colour |
| **Low** | 25–39 | Fill drops to 70% opacity; glyph gets a soft 4 dp halo in its own colour that breathes (2.4 s cycle). This is the "lowest meter glows" hint from GDD §1.1; only the single lowest meter breathes |
| **Very low** | 1–24 | Fill at 50% opacity, glyph still breathes. Never turns red, never shakes, no warning icon |
| **Empty** | 0 | Track only, glyph at Smoke. Still calm: an empty meter is a mood, not an error |
| **Gaining** | on refill | Fill sweeps to the new value (400 ms), a "+N" chip in the need's colour rises 16 dp and fades (900 ms) |
| **Decayed since last visit** | on check-in | Meters start at the last-seen value and ease down to the current value once (600 ms), so the week is visible without a ticking bar. Decay is never animated live |
| **Frozen** | Out of Town on | Bars desaturate to Smoke, suitcase glyph on the Vibe line |

Low states never use red as an alarm: red already means "the stage", and
the GDD forbids guilt. Dimmer = needs a night out.

### Vibe summary

Vibe (average of the four) is shown as a word and a candle, never a number.
The candle glyph's flame grows with the state:

| Vibe | Word | Candle |
|---|---|---|
| 80–100 | Glowing | Tall flame, gold halo, character gets the rim light |
| 50–79 | Good | Normal flame |
| 25–49 | Meh | Small flame |
| 0–24 | Homebody | Unlit wick with a thread of smoke |

The Vibe line sits above the meters on the Flat ("Vibe: Good") and is
omitted from the venue HUD (the character's own look carries it there).

## 5. Components

### Buttons

| Type | Fill | Label | Use |
|---|---|---|---|
| **Primary** | Velvet Red, 1 px Slat Red top edge | Candle Cream, Kanit 600 17 | One per screen: GO OUT, Order, Start |
| **Secondary** | `bg.raised`, 1 px `line` edge | Lamp Gold, Kanit 600 15 | Alternatives: Maybe later, Album |
| **Ghost** | none | Smoke, Plex 500 15 | Close, Skip, Back |
| **Icon** | 44 dp circle, `bg.base` 80% | glyph in Cream | Settings, close, album |

Heights: primary 56 dp, secondary 48 dp, minimum tap target 48 x 48 dp for
everything (hit area may extend beyond the drawn shape). Corner radius 14 dp;
icon buttons fully round. Pressed: fill steps one value (Velvet → Slat Red),
scale 0.97 for 80 ms. Disabled: 40% opacity plus a caption saying why ("Back
after this song").

### Cards

`bg.raised`, radius 16 dp, 16 dp padding, 1 px `line` edge. A card may carry
one lit element (a gold "new" dot, an amber reward chip). Memory cards
(polaroid, stub, coaster) are the exception: they are physical objects drawn
as flat illustrations with a cream border and a slight rotation (±2°),
because they are keepsakes, not UI.

### Sheets

The zone interaction sheet, meter detail and settings slide up from the
bottom, `bg.deep` at 96%, top radius 20 dp, a 36 x 4 dp grab handle. A sheet
never covers more than 60% of the screen in the venue, so the character and
the zone stay visible above it. Drag down or tap the scene to dismiss.

### Toasts

Single line, top of the screen under the safe area, `bg.base` 92%, radius
12 dp, leading glyph, max 2.8 s on screen, one at a time, queued. Used for:
need gains summary, memory dropped ("New coaster: Thai Iced Tea"), regular
arrived. Never used for errors that need action; those are dialogs.

### Dialogue bubbles (Candle Talk and regulars)

- Speaker bubble: `bg.base` 94%, radius 18 dp, tail pointing to the
  speaker's head in world space, max width 80% of screen, `body.l` text.
  Speaker name above in `display.s` Lamp Gold.
- Bubbles anchor to the character but clamp inside the safe area; if the
  speaker is off-screen, the bubble docks to the screen edge with an arrow.
- Player reply bubbles are not drawn; the player speaks through **topic
  cards** (see `wireframes.md`, Candle Talk). The chosen card flies into the
  bubble's place.
- Text reveals by line, not by letter (Thai combining marks break
  per-character typewriter effects). Tap to show all.
- The candle meter (Candle Talk's score) is a warm glow behind the bubble
  that brightens with each match.

Nameplates: smooth pill, Lamp Gold on `bg.base` 80%, heart count for
regulars; none over the player's own character.

## 6. Iconography

Icons live in a voxel world but are **not voxels**.

- Flat, single-colour glyphs on a 24 dp grid, 2 dp stroke, rounded caps and
  joins, 2 dp corner radius. Drawn as SVG and imported as MSDF or at 3x.
- Filled variants only for selected or active states.
- Default colour Candle Cream; need glyphs take their need colour; no
  gradients, no drop shadows, no glow except the low-meter halo.
- Subjects come from the room: note, heads, coupe, moon, candle, door,
  suitcase, polaroid, ticket stub, coaster, disco ball, gear. Draw them as
  pictograms of the real objects, simplified, with no cube faces.
- No emoji in UI chrome. Emoji are allowed only in the phrase wheel (later
  phases).

## 7. Motion

The room moves (tealights flicker, the disco ball turns). The UI is calmer
than the room.

| What | Duration | Curve |
|---|---|---|
| Button press | 80 ms down, 120 ms up | ease-out |
| Sheet in / out | 280 ms / 200 ms | ease-out cubic / ease-in |
| Screen fade (Flat ↔ venue) | 500 ms through Cabin Dark | linear |
| Meter fill on gain | 400 ms | ease-out |
| "+N" chip rise and fade | 900 ms | ease-out |
| Decay replay on check-in | 600 ms, staggered 80 ms per meter | ease-in-out |
| Toast in / hold / out | 200 / 2400 / 200 ms | ease-out |
| Low-meter breathe | 2400 ms loop, opacity 60–100% | sine |
| Card select | 150 ms, lift 4 dp | ease-out |

Rules:

- **No bounce, no overshoot, no elastic, no wobble.** Nothing springs.
- Animate opacity and position; avoid scale over 1.05.
- Only one looping UI animation on screen at a time (the breathing low meter
  or the LIVE tag pulse, not both; LIVE wins during a set).
- Beat-synced UI (Front Row Rhythm lanes) is the only motion tied to music.
- **Reduce motion** setting: replaces all movement with 150 ms cross-fades,
  stops breathing loops (static halo instead), and stops the disco-ball
  screen sparkles.

## 8. Layout, safe areas and phones

- **Design frame:** 390 x 844 dp portrait (a common modern phone). Must work
  down to 360 x 740 dp and up to 430 x 932 dp. Godot stretch mode
  `canvas_items`, aspect `expand`, base width 390.
- **Grid:** 16 dp side margins, 8 dp spacing unit.
- **Safe areas:** read `DisplayServer.get_display_safe_area()` at start and on
  resize. All UI anchors to the safe rect; the 3D scene renders full-bleed
  behind the notch and home indicator. Top strip (HUD) sits 8 dp below the
  safe top; bottom actions sit 12 dp above the safe bottom (home indicator).
  Never place a tap target in the top 24 dp of the safe area on phones with a
  dynamic-island cutout; use that band for passive text only.
- **Thumb zone:** primary actions live in the bottom 40% of the screen. Top of
  screen is for reading (meters, zone name, time); bottom is for doing.
- **Web export on phones:** worst case 360 x 640 dp; sheets scroll.

## 9. Desktop and landscape (secondary)

Same screens, same components, re-flowed. No separate desktop UI.

- **Frame:** 1280 x 720 minimum, scales to 1920 x 1080.
- **Column:** portrait content becomes a 420 dp column docked left, with the
  3D view filling the rest. The venue HUD's top strip becomes a left rail
  (meters stacked vertically, zone name and who-is-here under them); sheets
  open as right-side panels 400 dp wide instead of from the bottom.
- **Flat and full-screen menus** (creator, album, recap, settings) centre a
  480 dp phone-proportion panel on a darkened scene; the album shows two pages
  side by side.
- **Minigames** keep a portrait play area (9:16) centred, with scene art
  filling the sides. One-thumb controls map to: left / right half → `A` / `D`
  or arrow keys; tap → click or `Space`; hold → hold mouse or `Space`.
- **Input:** hover raises one fill step; 2 dp Slat Red focus ring for
  keyboard; `Esc` closes the top sheet; click-to-move. UI scale 90–125%.

## 10. Accessibility

Text ≥ 4.5:1 checked over each zone's brightest red framing; never colour
alone; text size 100/115/130% (layouts hold at 130% Thai); reduce motion;
"dim flashes" for the disco state; minigame "relaxed timing" (+50% hit
windows). No fail screens (GDD §9).
