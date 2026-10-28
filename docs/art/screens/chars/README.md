# Characters vs renders 05/06

Work of the 🎨 Characters session (wave 3-parity, P1). Generator: `tools/blender/bc_chars.py`; game side:
`game/scripts/venue_patron_figure.gd`, `game/scripts/venue_patrons.gd`; kit docs: `game/assets/chars/README.md`.

## 1. Measurements (read off the render figures at the render cameras)

Pixel heights are on the 1672 x 941 (05) and 1446 x 1087 (06) direction renders. The cameras look down at about
25-35 degrees, the same as the game's R05/R06 cameras, so the ratios already include the foreshortening the game
camera adds.

| Figure | Height px | Head + hair | Torso (shoulder to crotch) | Legs | Head width vs shoulders (arms incl.) |
|---|---|---|---|---|---|
| 05 server (standing, tray) | 178 | 29 % | 36 % | 35 % | 0.9 |
| 05 front guitarist (standing) | 158 | 33 % | 29 % | 38 % | 0.8 |
| 06 blonde guitarist (standing) | 170 | 34 % | 30 % | 36 % | 1.0 (hair) |
| 05 / 06 seated patrons | - | head top 1.6-1.8 x the table-top height above the seat | table top at chest | thighs level, shins down | - |

Read-offs that drive the kit:
- A standing figure is about 30 render voxels (the server's hair voxels are about 6 px on a 178 px figure).
- Head + hair is a third of the height and as wide as the shoulders with the arms; hair overhangs by 1-2 voxels
  and rises 2-3 in clumps; the back of the head is clumpy hair, not a flat panel.
- Faces: 1 x 2 dark eyes about halfway down the head, brows and beards in relief, moustaches common; mouths
  rarely visible from above.
- Arms are about 2.5 voxels thick; a hanging hand reaches the hips.
- Clothes are layered: white shirts with collars and rolled sleeves, open dark jackets with lapels, the server's
  black vest and belt, red sleeveless dresses, fedoras; drinks are amber pints and mugs with white foam.
- Seated patrons sit with level thighs, forearms flat on the table and a glass in hand; the table top is at chest
  height. The server holds the tray beside the head on a level forearm. The band: drummer seated with sticks,
  guitarists with the guitar on the belly and the neck up to their left, a bassist in a fedora.

## Kit proportions chosen (voxels of 5 cm, drawn at FIG_SCALE 0.75 in the venue)

Iterated against the sheet: a 9-row head measured 37-40 % of the figure and an 8-row head 34-43 % against the 05
server's 27-29 %, so the final head is 8 x 7 x 7, narrower than the shoulders with the arms, as in the renders.

| | regular | petite | broad |
|---|---|---|---|
| Legs (thigh / shin / shoe) | 11 (6 / 3 / 2) | 10 (5 / 3 / 2) | 11 |
| Pelvis + chest | 2 + 9 | 2 + 8 | 2 + 10 |
| Head (W x D x H) | 8 x 7 x 7 | same | same |
| Hair | +1 to +2 (afro, curly more) | | |
| Total, drawn | 30-31 vox, 1.13-1.16 m | 28-30 | 31-33 |
| Head + hair share | 27-30 % (about a third with the tufted sides seen from above) | | |
| Torso W x D, arms | 8 x 5, arms 3 x 3 (upper 4, forearm 4, hand 2) | 8 x 5 | 10 x 6 |

## Pose plan

| Pose | Who | Where |
|---|---|---|
| `sit_drink` | patrons | cafe chairs at tables, communal table, bar stools (table and bar tops are both 0.30 m above their seats, so one pose fits) |
| `sit_talk` | patrons | same, leaning in, free hand talking, glass stays on the table |
| `sit_hold` | patrons | drum-stool poufs, lounge chairs: glass at the chest, sips |
| `sit_applaud` | patrons | the poufs facing the stage |
| `sit` | anyone | relaxed, hands on the thighs |
| `stand_drink`, `cheers` | patrons | standing with a glass |
| `idle_tray`, `walk_tray` | server | the floor |
| `pour` | bartender (Nam) | behind the bar, bottle over a glass |
| `play_guitar`, `play_bass`, `sing`, `play_drums` | guest guitarist, Pete, Jo, Boy | the four stage spots |
| `idle`, `walk`, `dance`, `applaud`, `idle_warm/tipsy/merry`, `walk_warm/tipsy/merry`, `idle_sad` | everyone | kept from kit v1, now with elbows and knees |

## Results

| File | What |
|---|---|
| `chars-03-sheet.png` | **review sheet**: seven render figures next to the kit figure in the same role at the same pixel height (server, two guitarists, bassist, drummer, seated patrons with glasses), then the band and table regions of 05/06 next to the game at the same camera |
| `chars-03-R05-game.png`, `chars-03-R06-game.png` | the venue at the R05 / R06 parity cameras with the v2 crowd (87 figures) |
| `chars-01-*`, `chars-02-*` | earlier captures of the same session (9-row and 8-row heads) |

Still open after sheet 03:
- Figures read darker than in the renders: the renders light every figure with a warm key and rim; the room's
  lighting belongs to the room-polish session.
- From R05 many seated patrons show their backs (four chairs round each table, as in the layout); the renders
  favour faces. A crowd-only fix would be to fill the chairs that face the camera first.
- The 05 "tables and server" region does not line up with the game layout (the render has a table where the game
  has the aisle), so that pair compares density, not the same figures.
- The render bassist plays an upright bass; the cast bible gives Pete a yellow electric bass, which the kit keeps.
  05/06 show a four-piece and the House Lights are a trio: the fourth spot is an anonymous guest guitarist
  (`band_guitar`), to be confirmed.
- Hair is voxel-exact blocks with clumps; the renders' hair is softer and more sculpted.
