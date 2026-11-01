# 🎭 Prae as owner: role note (2026-11-02, state now)

Worker: cast (Opus), session local_b5fbe4b1, briefed by the orchestrator local_78d0c67d after Daniele's playtest of
33dc5b9: "prae is a female with black hair dressed with leather black jacket and blue jeans and no heart in her name
(she is one of the owner and my friend)". She is a real person. Internal id stays `mali`.

## What landed (one commit on main, not pushed)
- **Look** (`tools/blender/bc_chars.py`): preset `mali` is now display "Prae", role `owner`, slot `OWNER_PRAE`:
  regular body (v2 proportions), soft head, wavy black hair, new top style `leather` (black leather biker jacket open
  over a white tee, lapels in a lit `LeatherSheen`, silver zip and side buckle, glossy material), `JeansBlue` jeans,
  black boots, no accessories. Cardigan chalk dust, bob, reading glasses and the iced-tea mug are gone from her.
  New swatches LeatherBlack, LeatherSheen, Silver, JeansBlue; `GLOSS` table for roughness/metallic per swatch.
  Khun Joy's role is `owner` too (its `OWNER` slot), so she lost the tray/pour clips (owners carry no trays).
  Full run with `--no-review`: 42 presets, 3 libraries (they now carry `top_leather`), manifest,
  `blender/BlackCabinChars.blend`, `docs/art/chars-showcase.png`. `blender/BlackCabin.blend` (room review) untouched.
- **Review card**: new `--focus <name>` mode writes `blender/BlackCabinChars_mali.blend` (lit, labelled, four views)
  and `docs/art/screens/prae/prae-blender-review-{landscape,portrait}.png`; `prae-alt-long-hair-*` is the
  straight-long-hair alternative.
- **Owner role in code**: `game/scripts/cast.gd` reads each preset's role from the character manifest
  (`Cast.role`, `Cast.befriends`, `Cast.is_owner`; unknown ids count as regulars). Only regulars are befriended.
  `venue_zones.gd`: `tag_text(id)`, the tag over her table reads "Prae", no ♥ (regulars keep "Name  ♥").
  `result_card.gd`: hearts kept and drawn for regulars only; a Candle Talk with an owner refills Friends, keeps no
  hearts, shows no hearts row. `venue_patrons.gd`: `_place_host` stands Prae (`Host_mali`) at Table2's south-west
  corner facing the room, idle (she was never in the room before, only a floating tag).
- **Tests**: test_minigames (owner role, tag text, no hearts kept, no heart glyphs on her card; the hearts test now
  uses Tong), smoke_loop (tag "Prae" without ♥, Host_mali present, no hearts after her talk).
- **Cast bible** `docs/design/03-cast.md` v1.1: new §2.3 Owners: Prae (role in code, where, when, what she does,
  no invented lines); `OWNER_PRAE` row in the staff table; regular #4 is "(open)" everywhere her old duties lived.
- **Captures** `docs/art/screens/prae/` (README there): in-game view, front, three-quarter, name tag, each portrait
  1080x1920 (rendered 800x1422 and scaled: a full-height window is clipped) and landscape 1920x1080.
  Script `game/tests/capture_prae.gd`.

## Verification
All ten suites pass headless in a clean worktree of HEAD (fb2702f) plus only these changes: smoke_stairs, smoke_tap,
smoke_hud, test_needs (106), test_minigames (836), smoke_loop, smoke_doors_sit, smoke_start, test_menu (2736),
smoke_version. In the shared tree smoke_loop fails "walked to stage" because of other sessions' uncommitted edits
(feel-pass: player.gd, camera_rig.gd, ...); HEAD alone passes it, and HEAD plus these changes passes it.

## Calls for Daniele (Questions tab; pictures in docs/art/screens/prae/)
1. **Look (now):** Is this Prae? (a, rec) Yes, wavy black hair as shown; (b) straight long hair
   (`prae-alt-long-hair-*`); (c) change something (note: hair length, tee colour, build, glasses...).
   Pictures: `prae-blender-review-portrait.png`, `2-prae-front-portrait.png`, `prae-alt-long-hair-portrait.png`.
2. **Her old regular duties (design):** quiz captain at the Long Table, Tuesday anchor, "Second Is First" memory,
   Candle Talk lines, regular-to-regular moments. (a, rec) A new fictional regular #4 takes the whole package (the old
   cardigan-bob-glasses design can be reused; Daniele names them); the Candle Talk table goes to them and Prae stays a
   pure owner. (b) Hiro takes quiz captain and Tuesday (his nights are already Tue Thu Sat, Long Table on Tue); the
   rest retires; seven regulars. (c) Slot #4 stays empty; the quiz becomes a house event; seven regulars.
3. **Khun Joy, the fictional owner (design):** (a, rec) retire Khun Joy, Prae holds the owner slot (house toast,
   anniversary, rank-up visit only if she agrees); (b) keep Khun Joy as a second owner; (c) another real owner
   replaces Khun Joy if one agrees.
4. **Facts, ask Prae:** her usual nights and spot, and whether she gives 2-3 real catchphrases and one story
   (consent pack §2.1). Until then she stands at Table2 every night and has no lines of her own.

## Open / follow-ups
- Interim: her table still offers Candle Talk with the old quiz-captain lines (`npc.mali.talk.*`, `mali.json`); they
  belong to slot #4 and move or go once call 2 is answered. String comments for `cast.mali.name` and
  `venue.hint.table` now say owner; the player-facing text is unchanged.
- A walk loop for her (table, bar end, lounge) is a proposal in §2.3, not built.
- The versioning work left `version_info.gd.uid`, `capture_version.gd.uid`, `smoke_version.gd.uid` untracked.
