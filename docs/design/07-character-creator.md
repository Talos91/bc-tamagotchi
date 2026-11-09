# 07 — Character creator (creator lite, version 0.3)

Status: **design v1, 2026-11-09** (🎨 character-creator worker, phase 1: design only, no game code). Owner item 22
(`handoffs/owner-feedback-2026-11-04.md`: "next feature after the polish: the character creator"). Owner calls are
in §9 and on the hub card `char-creator-design-review`; nothing here is built until Daniele answers.

Sources kept as they are: GDD §7.1 (creation) and §7.2 (wardrobe), the launch scope in GDD §14 ("Character creator
lite: 3 body types, 6 skin tones, 4 hair styles, 3 outfits, 4 personalities"), `rules.gd` (`PERSONALITIES`,
`PERSONALITY_DECAY_MULT` 0.9), `save.gd` (additive keys, no rename), the cast bible (regulars' signature items are
never sold to players), DECISIONS 2026-11-02 (merch shop = in-game coin items that wait on this creator; mobile only,
portrait first with the landscape toggle; Lato for UI, Kristi for titles), `game/assets/chars/README.md` (kit v2).

Mock pictures (Godot capture of a static mock built from the real parts libraries, 1080×1920, not the final UI):
`docs/art/screens/char-creator/mock-01-body-skin.png`, `mock-02-hair.png`, `mock-03-vibe-name.png`; the mock tool is
`tools/mock/char_creator_mock.gd` (review only, not game code). The mocks show the lite counts (3 bodies, 6 skins,
4 hair styles) and no face row; the counts proposed in §2 are owner calls Q1–Q4.

---

## 1. What is true today (measured 2026-11-09)

- **The player is a crowd patron.** `player.gd` sets `look = {"preset": "patron_06", ...}`: a `broad` body, square
  head, shaggy hair, beard, moss tee, charcoal jeans, boots, Skin5. The colour keys in that dict only feed the box
  fallback, so the player is drawn exactly like `patron_06`, who can also be in the crowd.
- **Personality exists in the rules but nothing sets it.** `rules.gd` maps `night_owl → nightlife`,
  `music_nerd → music`, `social_butterfly → friends`, `easy_sipper → drinks`; `needs.gd` stores
  `needs.personality` and `set_personality()` has no caller. Every save today has `personality: ""` (no modifier).
- **The name exists but nothing sets it.** `profile.display_name` is saved and read (welcome card, farewell card,
  ghost chip with `venue.stake.name_fallback`), but no screen writes it.
- **The kit already has everything creator lite needs.** Four rigged parts libraries
  (`parts/parts_<petite|regular|broad|tall>.glb`, 1.37 MB each on disk, 94 parts, every animation),
  `BCChars.show_parts()` and `BCChars.recolour()` for runtime assembly, swatches in `manifest.json`.

| Slot | In the kit now | Creator lite (GDD §14) | GDD §7.1 full launch |
|---|---|---|---|
| Body | 4: petite, regular, broad, tall | 3 | 3 heights × 3 builds |
| Skin | 8 swatches Skin1–8 (light to deep) | 6 | 12 |
| Head shape | 4: square, round, soft, heart | — | (face row) |
| Eyes / brows / mouth | 5 / 5 (incl. none) / 5 | — | 8 / 6 / 6 |
| Hair style | 17 | 4 | 16 |
| Hair colour | 10 swatches | — | 16 |
| Tops / bottoms / shoes | 15 / 5 / 3 | 3 outfits | 6 looks, mixable |
| Wardrobe swatches | 32 | — | — |
| Personality | 4 in `rules.gd` | 4 | 4 |

So **phase 2 models nothing new for creator lite**: every option is a part id plus a swatch. New generator work is
only needed for the wardrobe (§8).

## 2. Scope for 0.3 (proposal; counts are owner calls Q1–Q5)

| Step | Slot | Proposed for 0.3 | Why |
|---|---|---|---|
| Body | Build | **4**: petite, regular, broad, **tall** (Q1) | In the mock the three lite bodies read almost the same at thumbnail size (mock-01); `tall` (Tt's body) is the one with a clearly different silhouette and costs nothing. |
| Body | Skin | **8** (Q2) | Skin7 and Skin8 already exist; cutting to 6 would drop only the two deepest tones. GDD's 12 = add 4 in-betweens later. |
| Body | Face | **4 head shapes + 3 face sets** (Q4) | Head shape is the main silhouette cue from the high camera (cast bible: regulars differ by head silhouette). Face sets are eyes+brows+mouth trios: *Easy* (dot, flat, smile), *Bright* (wide, arched, grin), *Soft* (lashes, flat, small). |
| Hair | Style | **8** (Q3): crop, quiff, bob, long, curly, bun, side_part, buzz | All exist; the cost is eight thumbnails. Leaves `two_block` (Tt), `afro`, `ponytail`, `spiky`, etc. for wardrobe drops later. |
| Hair | Colour | **8**: Black, Dark brown, Brown, Auburn, Bleach, Grey, Rose, Silver | Swatches exist; recolour also colours the brows. |
| Outfit | Look | **3 starter looks**, each with **6 colourways for the top** (Q5) | Lite says 3 outfits; a colour pick makes two players on the same look differ. Looks in §2.1. |
| You | Personality | **4** (as built in `rules.gd`) | §3. |
| You | Name | free text, filtered (Q9) | §5.4. |

Not in 0.3: hats, glasses, facial hair, held items, outer layers (all wardrobe, §8); body height slider; GDD's 12
skins / 16 hair colours / 6 looks (they are additive later, no format change). No gender field: every part is
available on every body (Q10).

### 2.1 Three starter looks (proposal)

| Look | Top | Bottom | Shoes | Fixed colours | Top colourways |
|---|---|---|---|---|---|
| **Easy** | `tee` | `jeans` | `sneakers` | Denim jeans, Cream sneakers | Cream, Mustard, Rust, Teal, Charcoal, ShirtWhite |
| **Night out** | `leather` (open over a tee) | `jeans` | `boots` | JeansBlue, StoolBlack boots | LeatherBlack, Jacket, Leather, DressRed, Olive, Denim (jacket colour; inner tee Cream) |
| **Smart** | `shirt` | `trousers` | `loafers` | Charcoal trousers, StoolBlack loafers | ShirtWhite, Sky, Sand, Stone, VelvetRed, Moss |

All three avoid the overlap pairs the kit README warns about (jacket hem over a belt is fine in `leather`; no
hat, no glasses). Each look is one row in a data file, so changing a look is data, not code.

## 3. Personality (needs effects)

Kept exactly as `rules.gd` and GDD §7.1 have it; the creator only calls `needs.set_personality(id)`.

| Id | Card name | Effect (rules.gd) | Greeted first by (proposal) | Line on the card |
|---|---|---|---|---|
| `night_owl` | Night Owl | Nightlife decays ×0.9 | **Jules** (Nightlife regular, pinball) | "Nightlife fades 10% slower" |
| `music_nerd` | Music Nerd | Music decays ×0.9 | **Tong** (Music, front row) | "Music fades 10% slower" |
| `social_butterfly` | Social Butterfly | Friends decays ×0.9 | **Tt** (quiz captain, adopts everyone) | "Friends fades 10% slower" |
| `easy_sipper` | Easy Sipper | Drinks decays ×0.9 | **Nam** (bartender, in every night) | "Drinks fades 10% slower" |

- "Which regular greets you first" (GDD §7.1): on arrival, if that character is in tonight, their greeting line plays
  before the others'. Nam is picked for Easy Sipper because Dougie and Hiro are not in the first-playable roster and
  Nam is in every night. The greeting order is a small hook in phase 2; no new lines are needed (existing greetings).
- "Sets idle animations" (GDD §7.1): **deferred**. The kit has no personality idles, and the existing variants
  (`idle_warm`, `idle_tipsy`...) already mean tipsiness; reusing them would mislead. Later clip candidates: Night Owl
  taps a foot, Music Nerd nods to the beat, Social Butterfly waves, Easy Sipper swirls a glass.
- Changing personality later is free (GDD §7.1: "all changeable later at no cost"; Q6). The switch goes through
  `set_personality()`, which calls `sync()` first, so decay so far is charged at the old rate. The worst-case gain from
  switching to whichever meter is lowest is 10 % of one meter's decay: small.
- Existing saves have `personality: ""`, which keeps working (no modifier) until the player picks one (§4.3).

## 4. The avatar record

### 4.1 Where it lives

`save.json → profile.avatar` (a new key under the existing `profile`, beside `display_name`). Reasons: `profile` is
already "reserved for accounts / multiplayer", and presence multiplayer (item 24), the corridor portraits and the top
patrons boards all need the look without the needs state. **Personality stays in `needs.personality`** (the rules
own it; no copy). **The name stays in `profile.display_name`.** No `VERSION` bump: it is an added key (save.gd rule).

### 4.2 Shape

```json
"profile": {
  "player_id": "",
  "display_name": "Mai",
  "avatar": {
    "v": 1,
    "body": "regular",
    "head": "round",
    "face": "easy",
    "skin": "Skin3",
    "hair": "bob",
    "hair_colour": "HairBlack",
    "look": "night_out",
    "top_colour": "LeatherBlack",
    "worn": {},
    "created_at": 1762689600.0,
    "edited_at": 1762689600.0
  }
}
```

- Values are **ids and swatch names, never hexes**: a palette tweak in `bc_chars.py` reaches every save, and the record
  is small enough to send to a server as-is (item 24).
- `face` names a face set (§2); the set → eyes/brows/mouth ids table lives in the data file, so new sets are data.
- `look` + `top_colour` resolve to top/bottom/shoes ids and their colours through the looks table (§2.1).
- `worn` is empty in 0.3; it is the wardrobe hook (§8): `{slot: item_id}` overrides what `look` gives.
- `v` is the record's own version, so the avatar can migrate without touching the save `VERSION`.
- Unknown ids fall back per slot to the default below (a removed part never breaks a save).

### 4.3 Defaults and migration

| Save | What happens |
|---|---|
| New game (no save, or after the farewell card / Retire, which already clear the profile) | The creator opens after "Tap to enter", before the walk-in. The record starts from a random roll ("Surprise me") so two new players rarely match. |
| Existing save, no `avatar` key | Loads with the **legacy default**, which reproduces today's player exactly (`patron_06`: broad, square, shaggy, Skin5, HairDarkBrown, moss tee, charcoal jeans, boots, beard), so nobody's character changes behind their back. On the next start screen a one-time card offers "Make your character" / "Keep this look" (Q7). Either answer writes the record, so the card shows once. |
| Existing save, empty `display_name` | The creator's last step asks for the name; "Keep this look" still asks for the name alone. |
| `personality` empty | Same one-time card; it stays empty (no modifier) if skipped, and can be set later from Edit look. |

The legacy default is the only place the beard appears in 0.3; it stays as a hidden `worn` item so the migrated
character keeps it, and the wardrobe offers it later.

## 5. The creator screen (phone, portrait first)

Pictures: mock-01 (Body), mock-02 (Hair), mock-03 (You). Layout for 1080×1920; the landscape toggle puts the preview
on the left half and the panel on the right.

### 5.1 Layout

- **Top bar** (0–160 px): back chevron, the title in Kristi ("Who are you tonight?"), "Step n of 4" in Lato.
- **Preview** (160–1010 px): the character on a small lit disc, red fill and a warm key as in the venue, playing
  `idle` and turning with a drag. Two pills over it: "drag to turn" and "Surprise me" (random roll of every slot).
- **Panel** (1010–1920 px, the thumb half): four tabs **Body · Hair · Outfit · You**; the options of the current tab;
  a full-width red button "Next: …" (last step: "Into the bar"). All touch targets ≥ 96 px.
- Choices update the preview at once. Option cards show the real parts (mini 3D thumbnails, as in the mocks),
  not icons.

### 5.2 Steps and timing (target under 60 s; GDD limit 2 minutes)

| Step | Rows | Taps if the player takes the defaults |
|---|---|---|
| 1 Body | Build (4 cards), Skin (8 swatches), Face: head shape (4) and face set (3) | 1 (Next) |
| 2 Hair | Style (8 cards in two rows), Colour (8 swatches) | 1 |
| 3 Outfit | Look (3 cards), Top colour (6 swatches) | 1 |
| 4 You | Vibe (4 personality cards, effect and greeter shown), Name field | name + 1 |

Everything has a preselected value except the name, so a player can be in the bar in four taps and a name. Tabs can
be tapped in any order; Back never loses a choice. Before "Into the bar" nothing is saved; leaving the creator on a new
game returns to the start screen.

### 5.3 Editing later (free)

"Edit look" opens the same screen with the current record, the tab bar fully unlocked and the button reading
"Done". Proposed entry point: a small button on the start screen under "Tap to enter" and in the in-game menu (Q8).
Later, a diegetic spot (the toilet mirror) can open it too. Editing never costs coins and never touches meters,
except a personality change (§3).

### 5.4 Name

- 2–16 characters after trimming; Latin and Thai letters, digits, space, `.`, `-`, `'`; no emoji (the web font has
  no colour emoji; the ♥ glyph is already missing there), no line breaks, no leading/trailing spaces, no run of more
  than two spaces.
- Blocked: the cast's names (Nam, Fern, Big, Golf, Prae, Tong, Ploy, Jules, Tt, Dougie, Lung Nop, Bow, Hiro, Jo,
  Pete, Boy) so name tags never confuse a player with an NPC; a local word list (English and Thai, kept in a data
  file under `game/data/`) checked case-insensitively and with spaces and look-alike characters folded.
- The message on a refusal is friendly and specific ("That's Nam's name. Pick another?" / "Let's keep it friendly").
- When names become visible to other players (item 24, top patrons, corridor portraits), the server re-checks; the
  local filter is only the first gate.
- Changeable any time, free, from Edit look.

## 6. Runtime assembly (phase 2 notes)

1. `PatronFigure.set_look()` gets a third form: `{"avatar": record}` (beside `{"preset": ...}` and the box colours).
2. It instances `parts/parts_<body>.glb`, calls `BCChars.setup_animations()`, resolves the record through the data
   file to part ids (`head_*`, `hair_*`, `eyes_*`, `brows_*`, `mouth_*`, `top_*`, `bottom_*`, `shoes_*`, `hands`,
   plus `worn` items) and calls `BCChars.show_parts()`, then `BCChars.recolour()` per slot with the swatch hexes from
   `manifest.json` (`skin` also colours bare arms, legs and hands; `hair` also the brows).
3. Blush and expressions keep working: `blush` shows at Warm and above; low Vibe swaps `brows_worried` +
   `mouth_flat` and restores the face set's own ids after.
4. Everything else (FIG_SCALE 0.75, SEAT_H, drink props per pose, head turn, walk speeds) is unchanged: the libraries
   share the presets' scale, pivot and rig.
5. **Phone memory:** a library is 1.37 MB with all 94 parts and every clip. For the venue, phase 2 copies the chosen
   meshes into a lean node (mesh + skin + skeleton path) and frees the library; the creator preview may keep the
   library while open. Thumbnails: up to 8 small SubViewports on the open tab only (the mock renders 3–4 at once).
   Generator trims worth doing with phase 2: drop the staff and band clips (tray, pour, guitar, bass, drums, sing)
   and the staff/band props from the player libraries.
6. Changing body type swaps the library and re-applies the same record (README step 6).
7. The same record draws the player everywhere: venue, start screen, welcome and farewell cards, ghost, corridor
   portraits and top patrons later, and other players' avatars in presence multiplayer (item 24).
8. The data file (proposal `game/data/avatar.json`): bodies, head shapes, face sets, hair styles, swatch lists, looks
   and colourways, name rules. The creator and the assembler read only this file plus `manifest.json`.

Tests for phase 2 (proposal; added through the orchestrator): a headless `test_avatar` suite — every option
combination in the data file resolves to part ids that exist in all four libraries; record round-trip through
`save.gd`; legacy migration reproduces `patron_06`'s ids and colours; name filter cases (cast names, Thai, limits).

## 7. Accessibility and feel

- Swatches carry a name for screen readers and a selected ring; colour is never the only cue (the selected card also
  gets the red frame and bold label).
- Strings go to `game/i18n/strings.csv` with Thai drafts for staff review (DECISIONS: staff check the Thai).
- No timers, no pressure; "Surprise me" for players who do not want to choose.

## 8. Wardrobe and merch (GDD §7.2), where they hook in later

- **Slots** (GDD §7.2): hat, top, outer layer, bottom, shoes, accessory (glasses, earrings), held item. In the record:
  `avatar.worn = {slot: item_id}`; an item overrides what the look gives for that slot.
- **Items** live in a catalogue (proposal `game/data/wardrobe.json`): `{id, slot, part, colours, source, price}`;
  `source` is one of memory, heart, performer merch, stamp card, lounge merch shop (coins, `04-coins.md` §3.2).
  Owned items: `ext.wardrobe.owned`; 3 saved outfit presets: `ext.wardrobe.presets`.
- **Generator work the wardrobe needs** (none of it is needed for 0.3):
  - hats over a library hair: presets trim the hair under the brim at build time, but a library cannot, so each hat
    needs trimmed hair variants (`hair_<style>__brim`) or a per-hat hair mask: the biggest piece of new kit work;
  - an `outer` slot (the `jacket`, `leather`, `bomber`, `denim_jacket` tops are today built as one top with the inner
    tee): split into inner top + outer layer so they mix;
  - merch prints (Black Cabin logo tee, band tees per performer, GDD §6.3): a voxel print block on the chest in
    `bc_chars.py` (pixel art in voxels, same as the eyes), not a texture, so it matches the kit;
  - earrings and more held items; regulars' signature items (gig bag, sketchbook, flat cap, tinted glasses...) are
    **never** offered (cast bible).
- **Lounge merch shop:** the placeholders stay until the catalogue exists; the shop then lists catalogue items with
  `source: shop` and their coin price.

## 9. Owner calls (one question each; on the hub card `char-creator-design-review`)

| # | Question | Options | Recommendation |
|---|---|---|---|
| Q1 | How many body types in 0.3? | (a) 3 as the lite scope: petite, regular, broad; (b) **4, adding tall**; (c) GDD's 3 heights × 3 builds (new generator work) | **(b)**: tall exists and is the only clearly different silhouette (mock-01 shows the three lite bodies look alike) |
| Q2 | How many skin tones? | (a) 6 as the lite scope; (b) **all 8 that exist**; (c) 12 now (generate 4 in-betweens) | **(b)**: no cost; 6 would drop the two deepest tones |
| Q3 | How many hair styles (with 8 colours)? | (a) 4 as the lite scope; (b) **8**; (c) all 17 | **(b)**: all exist; keeps some for wardrobe drops later |
| Q4 | A face choice in 0.3? | (a) one fixed face; (b) **4 head shapes + 3 face sets**; (c) eyes, brows, mouth separately | **(b)**: head shape is the silhouette cue; sets keep it to two rows |
| Q5 | Outfits | (a) 3 fixed looks; (b) **3 looks, each with 6 top colours**; (c) free top/bottom/shoes now | **(b)** |
| Q6 | Changing personality later | (a) **free, any time (GDD)**; (b) once a week; (c) only at creation | **(a)**: the gain from switching is at most 10 % of one meter's decay |
| Q7 | Existing saves | (a) **keep today's look; one-time card "Make your character / Keep this look"**; (b) force the creator once; (c) keep it silently, Edit look only | **(a)** |
| Q8 | Where "Edit look" lives | (a) **start screen + in-game menu**; (b) only the toilet mirror in the venue; (c) both now | **(a)** now; the mirror later as a fun extra |
| Q9 | Name rules | (a) **2–16 letters, Latin + Thai, cast names blocked, local word filter, server check later**; (b) the same plus emoji; (c) no filter until the server | **(a)** |
| Q10 | Gender | (a) **no gender field; every part on every body**; (b) a gender choice that filters parts | **(a)** |
| Q11 | Greeters per personality | (a) **Jules, Tong, Tt, Nam** (§3); (b) another pairing (say which) | **(a)** |

## 10. Phase 2 (build) outline, for the next brief

1. Data file + record + migration (`save.gd` comment, `needs.gd` profile) with `test_avatar`.
2. Assembler (`PatronFigure` avatar form; player uses it; lean node).
3. Creator screen (portrait + landscape), strings EN/TH, name filter, "Edit look" entry points, one-time card.
4. Greeter order hook.
5. Captures at 1080×1920 and 1920×1080, review card. Generator trims (clips/props) if memory needs it.

Risks: phone memory and first-open time on the web build (four libraries if the preview loads every body: load
lazily, one body at a time); thumbnails rendering cost on weak phones (render once to textures and cache).
