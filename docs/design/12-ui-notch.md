# 12 — UI up a notch: clearer need icons, a Black Cabin interface (owner item 39)

Owner words (Daniele, 2026-11-18, chat): "also icons of needs are weird put more obvious one and the interface is too
general make it more interesting staying on theme, its time to go up a notch".

Design only: no game code changed. Two picks for Daniele on the Questions tab: **ui-notch-icons** (which need icons)
and **ui-notch-direction** (which interface look). The two are independent: any icon set works with any direction.
Mock-ups are PIL drawings over real in-game captures (`docs/art/screens/ui-notch/`, generators in `tools/`), not
game captures; no Godot was run for this job.

## 1. Audit: what reads as "generic" today (from the code and existing captures)

Read from `game/scripts/minigames/need_glyph.gd`, `mg_ui.gd`, `game/scenes/ui/meter_ring.gd`, `needs_hud.gd`,
`zone_sheet.gd`, `game/scripts/menu/`, `result_card.gd` on `wk/q1-juice` (2644bc3, read only), and the captures in
`docs/art/screens/tonight/`, `menu-followups/`, `area-camera/`, `q1-juice/` (branch).

| Where | Today | Why it reads weak or generic |
|---|---|---|
| Need meters (HUD) | 4 rings 44 dp, a 22 dp line glyph inside (`meter_ring.gd`, `need_glyph.gd`) | The glyph is half the ring and drawn with 2-unit lines: thin at phone size. **Friends** (two ring heads + an arc) reads as goggles or a face mask. **Nightlife** (crescent moon + spark) reads as *sleep / energy*, the opposite of a night out, and looks like a letter "C". **Music** in Slat Red disappears on the red room. No label anywhere, so the icon must carry the whole meaning. Ring fill is hard to compare at a glance. |
| Every panel and button | One shape: `UI.box()` dark-brown rounded rect with a thin line (Leave, Tonight, area buttons, sheet rows, result card, action card) | The look of a generic app settings screen. Nothing on screen comes from the venue: no neon, no lit shelves, no LED strips, no curtains, no posters. |
| Type | Lato for everything; Kristi (brand script) for zone names and the result title | Lato is clean but neutral. Kristi is handwriting; the venue's own signs are **neon tube capitals** (street sign `direction/23`, corridor sign `24`). |
| Area column | 7 identical pills "Lounge ›" … "Smoking ›" down the right edge | Reads as a list in a settings menu, and covers a third of the portrait screen. |
| Bar sheet / menus | Same coupe glyph on every row, brown rows | No hierarchy between "order", "menu" and the GAME row; nothing says "bar". |
| Tonight sheet | Brown card list | The real Black Cabin speaks in **posters** (`docs/venue/events/2026-10-upcoming-events.jpg`); the game's list does not. |
| Result card (Q1, being verified) | Stamp slam, count-up, NEW BEST ribbon, competition lines | The motion is good and stays. The card itself is the same brown box as everything else. |
| Start screen | Not re-captured for this job | Same panel and button family; covered by step U6 of the build order. |

What the venue gives us instead (photos `reference-real-bc/`, read only, and `docs/art/direction/09`, `18`, `23`,
`24`): red **LED strips** under the bar, the steps and the shelves; **backlit bottle cubbies** behind the bar; **neon
tube lettering** (BLACK CABIN, NOW OPEN arrow); red **velvet curtains**; candle lamps; green exit signs; brick; live
band posters and set lists.

## 2. Need icons (card ui-notch-icons) — picture `icons-options.png`

The four needs (`rules.gd` `METERS`): **Music, Friends, Drinks, Nightlife**. Same four objects in every set, chosen to
be read in under a second without a label:

| Need | New object | Why |
|---|---|---|
| Music | two beamed eighth notes (♫) | The universal "music" sign; thicker than one note |
| Friends | two people, front one overlapping | The universal "people / friends" sign; replaces the goggles shape |
| Drinks | cocktail glass with an olive | Kept from today (it already reads), filled and bolder |
| Nightlife | **disco ball with a sparkle** | "Party / night out" at a glance; the venue has a real disco ball over the floor (renders 05/06). Replaces the moon |

Colour: Music moves from Slat Red to **neon pink `#FF4081`** so it stays visible on the red room; Friends gold,
Drinks amber, Nightlife cyan stay. (Colour is part of the pick; say no to keep red.)

| Option | Look | Phone size | On theme | Cost |
|---|---|---|---|---|
| **I1 Bold chips ★ rec** | Filled silhouette in dark ink on a solid colour disc | Best: reads at 24 dp, high contrast on red and black | Medium (clean, poster-like) | S: redraw `need_glyph.gd` |
| I2 Neon tubes | The same objects as glowing neon tube outlines, like the bar's signs | Weaker under ~32 dp (thin lines, glow blurs) | High | S–M: glow as a pre-blurred sprite per glyph |
| I3 Voxel | Blocky 20×20 pixel icons with top light and side shade, framed | Good at 36 dp, rough under 28 dp; Friends gets busy | High with the voxel world and minigame sprites (look B) | M: 4 small sprites (or the pixel grids drawn in code) |

**Recommendation: I1.** The complaint is "weird, put more obvious ones": legibility first. I1 wins at every size, the
colour disc carries the need even in peripheral vision, and it sits well inside any of the three directions (D2 mock
uses it). Neon (I2) can still appear as decoration (zone titles, big result moments) without carrying the meters.

Also proposed with any set: meters get **bigger (52–60 dp tiles instead of 44 dp rings)** and a fill that reads as a
level (bar or rising liquid), plus a one-word label in the full-meter sheet. The lowest meter keeps its breathing.

## 3. Interface directions (card ui-notch-direction) — pictures `directions-overview.png` + per direction

Each direction is shown as: portrait HUD with the bar sheet open (`*-portrait-hud.png`), portrait result card
(`*-portrait-result.png`), landscape HUD with the Tonight panel (`*-landscape.png`). Layout is the same in all three
(Leave · four meters · Tonight on top; zone title + LIVE; area column; sheet), so only the look is being picked.

### D1 Neon Sign — `d1-neon-*.png`
- **Idea:** every frame is a neon tube on a black wall: buttons and panels outlined in glowing tubes (red, gold for
  Tonight, cyan for GAME), area buttons shaped like the corridor's **NOW OPEN arrow sign**.
- Type: **Tilt Neon** (OFL) for titles, buttons and numbers; Lato for body text.
- Meters: tile with a neon icon (I2) and a neon tube level bar.
- Result: "Neon reached" glows; NEW BEST is a gold neon plaque.
- Pros: the most "Black Cabin sign" look, very bold. Cons: a lot of glow on screen at once (busy, can tire), outlined
  text over bright scenes is the weakest for legibility; glow needs pre-blurred sprites or StyleBox shadows on phones.

### D2 Back-bar ★ rec — `d2-backbar-*.png`
- **Idea:** the UI is built from the bar itself: **dark wood panels with a thin brass line and a red LED strip glowing
  under each panel** (the strips under the real bar and steps), and **backlit bottle cubbies** for icons.
- Meters: **a shelf of four lit cubbies**; each cubby fills with its colour like a glass filling up (the level is the
  meter), icon on top (I1 silhouette). The lowest cubby glows at its edge.
- Sheets: each option has its own backlit cubby; GAME is a brass tag. Primary buttons are velvet red with a gold rim.
- Type: zone names and sheet titles as a **neon sign** (Tilt Neon, red glow, one per screen); Lato for everything else.
  Kristi stays for nothing or the start screen only.
- Tonight: date blocks like bar tabs; tonight's event lit with the LED strip.
- Pros: unique to *this* bar (nobody else's UI looks like its back-bar), calm enough for a game you open daily,
  readable (solid fills, Lato body), one neon accent per screen keeps neon special. Cons: more texture work than D1
  (gradients, LED line); the wood must stay dark or the screen turns brown again.

### D3 Gig Poster — `d3-poster-*.png`
- **Idea:** the live-music side: printed gig posters, ticket stubs and the band's set list. Off-black poster paper
  with grain, cream ticket stubs with notches and perforations, red rubber stamps.
- Type: **Bebas Neue** (OFL) condensed capitals for titles and buttons; Lato for body.
- Meters: cream ticket stubs with an ink icon and a printed level bar. Area column becomes **SET LIST 01–07**.
- Result: a ticket, stamped NEW BEST and NEON REACHED. Tonight: a poster "TONIGHT AT BLACK CABIN".
- Pros: strongest personality, great for Tonight/events and results, stamps fit Q1's slam. Cons: cream paper is the
  brightest thing on a dark venue screen (pulls the eye off the room); capitals-only titles are harder in Thai
  (Bebas has no Thai: Thai falls back to IBM Plex Sans Thai Looped, so Thai titles change look).

**Recommendation: D2 Back-bar**, with I1 icons. It is the most "this bar" of the three, stays readable at phone size,
keeps neon for the moments that matter (zone sign, result title) and fits the voxel venue's warm, dark lighting
(renders 05/06). D3's poster language is worth reusing **inside** D2 for the Tonight panel only if Daniele likes it
(a mix option on the card).

Fonts (all free to ship): Tilt Neon (SIL OFL 1.1, Google Fonts), Bebas Neue (OFL), Lato and Kristi (OFL, already in
`game/assets/fonts/` with their OFL texts). None of the new display fonts has Thai; the existing fallback chain
(`bc_theme.tres` → IBM Plex Sans Thai Looped) covers Thai, as it does for Kristi today.

Performance (iPhone budget, `11-minigame-quality.md` §1.3): no full-screen shaders. Glows = `StyleBoxFlat`
`shadow_size`/`shadow_color` (works in Compatibility) or one shared pre-blurred 9-patch texture; LED strips = a thin
`ColorRect` + a soft glow 9-patch; cubby fills = `StyleBoxFlat` with a gradient texture. Estimate: under 1 MB GPU
memory for the whole skin.

## 4. Build order after Daniele's picks (small jobs, own files each)

| Job | What | Files (own) | Checks |
|---|---|---|---|
| U1 icons | Redraw the four needs in the picked set; meter ring → meter tile (bigger, level fill, label in the full sheet); music colour | `game/scripts/minigames/need_glyph.gd`, `game/scenes/ui/meter_ring.gd`, `NEED_COLORS` in `mg_ui.gd` | `smoke_hud`, `test_minigames`; captures portrait + landscape |
| U2 skin kit | The direction's builders: panel, button (primary/secondary/ghost), LED strip, cubby, neon title; add the display font + OFL text; theme variations | new `game/scripts/ui/bc_skin.gd`, `game/assets/fonts/`, `bc_theme.tres` | `test_string_keys`, a skin contact sheet |
| U3 HUD | Top bar (Leave, meter shelf, Tonight), zone title as the neon sign, LIVE chip, area column restyled | `game/scenes/ui/needs_hud.gd`, `orientation_toggle.gd` | `smoke_hud`, `test_touch`, `test_feel` |
| U4 sheets | Zone sheet, action card, bar menu, Tonight sheet in the skin | `zone_sheet.gd`, `action_card.gd`, `game/scripts/menu/*`, the Tonight sheet script | `test_menu`, `test_tonight` |
| U5 minigame frame + result card | After Q1 is verified and on main (it owns `result_card.gd` now) | `result_card.gd`, `minigame_frame.gd` | `test_minigames`, `test_mg_fx` |
| U6 the rest | Start screen, Welcome Back, walk-out, wasted, farewell, character creator buttons | `start_screen.gd`, `welcome_back.gd`, `walk_out.gd`, `wasted_screen.gd`, `farewell_card.gd` | `smoke_start`, `test_avatar` |

U1 can start as soon as the icon card is answered (it does not wait for the direction). U2 waits on the direction
card; U3–U6 wait on U2 and can run in parallel (different files). Each job: before/after captures portrait 1080×1920
and landscape, headless or hidden desktop only, its card on the Questions tab.

## 5. Not done / not verified
- No Godot run: the mock-ups are drawings over earlier captures (backdrops: `area-camera/portrait-area-bar.png`,
  `camera-areas/after-landscape-main.png`, Q1's `portrait-neon-moth-gate.png`); real look and glow cost are checked
  in U1/U2 on the hidden desktop.
- Start screen, character creator and Welcome Back were not mocked (same skin applies; U6).
- Tonight mock uses October poster events (`docs/venue/events/2026-10.json`) as sample data.
