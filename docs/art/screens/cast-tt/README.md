# Cast pass: Tt, Prae with long hair (2026-11-02)

Daniele's answers on the Questions tab (DECISIONS row "Questions tab, answered 2026-11-01 20:37–22:14 UTC"):
Prae (id `mali`, an owner) has **straight long hair**, is in **every other night** at one of three spots and is
silent for now; a new regular **Tt** takes over her old regular duties (quiz captain at the Long Table, Candle Talk);
Khun Joy is retired. Cast bible: `docs/design/03-cast.md` §2.3 and §3.

Every picture comes in portrait (1080×1920, phone first) and landscape (1920×1080).

| File | What it shows |
|---|---|
| `tt-blender-review-{portrait,landscape}.png` | Blender review card for Tt (`blender/BlackCabinChars_tt.blend`): front and three-quarter (landscape adds side and back). Tall body, light-wash jeans jacket over a black tee, white pants, dark silver Korean two-block hair |
| `prae-blender-review-{portrait,landscape}.png` | Blender review card for Prae with the straight long hair (`blender/BlackCabinChars_mali.blend`) |
| `1-tt-game-*.png` | The game camera in the lounge, the player at the Long Table: Tt seated on the banquette under his "Tt ♥" tag |
| `2-tt-long-table-*.png` | Free camera on the Long Table: Tt, the regulars' table, his tag |
| `3-tt-close-*.png` | Free camera, close on Tt |
| `4-prae-game-*.png` | The game camera in the main room beside Prae at her spot (night pinned to 0: WestTable0, top-left); her tag reads "Prae", no heart |
| `5-prae-front-*.png`, `6-prae-three-quarter-*.png` | Free camera on Prae with her long hair |

Regenerate: `blender --background --factory-startup --python tools/blender/bc_chars.py -- --focus tt --out docs/art/screens/cast-tt`
(and `--focus mali`), then from `game/`:
`godot --path . --resolution 800x1422 --script res://tests/capture_cast_tt.gd -- --tag=portrait --capture-size=1080x1920`
and `godot --path . --resolution 1920x1080 --script res://tests/capture_cast_tt.gd -- --tag=landscape --capture-size=1920x1080`.
Portrait frames are rendered at 800×1422 (a 1080×1920 window is clipped to the screen) and scaled to 1080×1920.
The game-camera shots were taken on the camera of HEAD 20c6ad3 (one east-looking main-room view); the area-camera
work in flight changes those views, not the figures.
