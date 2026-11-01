# Prae as an owner (2026-11-02)

**Superseded look:** Daniele chose the straight long hair (`prae-alt-long-hair-*`) on 2026-11-02; the current
pictures are in `../cast-tt/`. Her table moved too: she is in every other night at one of three spots (03-cast §2.3).
The review card here (`prae-blender-review-*`) still shows the wavy hair; `blender/BlackCabinChars_mali.blend` is now
the long-hair one.

Daniele's playtest of 33dc5b9: Prae is female, with black hair, a black leather jacket and blue jeans, and **no heart
in her name**. She is one of Black Cabin's owners and Daniele's friend. Internal id stays `mali`.

| File | What it shows |
|---|---|
| `prae-blender-review-{landscape,portrait}.png` | Blender review card: front, three-quarter, side, back (portrait: front and three-quarter). `blender/BlackCabinChars_mali.blend` |
| `prae-alt-long-hair-{landscape,portrait}.png` | The same with straight long hair instead of wavy, for comparison |
| `1-prae-game-*.png` | The game camera in the main room: Prae stands at her table (below right of the tag); the tag reads "Prae", no heart |
| `2-prae-front-*.png` | Free camera, eye level, front |
| `3-prae-three-quarter-*.png` | Free camera, three-quarter |
| `4-prae-label-*.png` | The name tag over her table with her in front |

Look: `bc_chars.py` preset `mali`, role `owner`: regular body, soft head, wavy black hair (`HairBlack`), new top
`leather` (black leather biker jacket `LeatherBlack` with lit lapels `LeatherSheen`, a silver zip and side buckle,
open over a white tee), `JeansBlue` jeans, black boots, no accessories. The cardigan, bob and reading glasses are gone.

Regenerate: `blender --background --factory-startup --python tools/blender/bc_chars.py -- --focus mali` (card),
then from `game/`:
`godot --path . --resolution 800x1422 --script res://tests/capture_prae.gd -- --tag=portrait --capture-size=1080x1920`
and `godot --path . --resolution 1920x1080 --script res://tests/capture_prae.gd -- --tag=landscape --capture-size=1920x1080`.
Portrait frames are rendered at 800x1422 (a 1080x1920 window is clipped to the screen) and scaled to 1080x1920.
