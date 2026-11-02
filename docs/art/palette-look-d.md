# Venue palette: look D "as in the venue" (2026-11-02)

Daniele picked look D of the look test (DECISIONS "Venue look: D, with a voxel floor"). Built by 🎨 look-build in
`game/tools/build_venue.gd` (venue materials, lights, environment) and `game/scenes/venue/venue_looks.gd` (kit
swatches recoloured at load). Values come from the look test (`handoffs/worker-reports-2026-11/look-test.md`); this
note supersedes the venue rows of `art-bible.md` §3 where they differ. Captures: `docs/art/screens/look-build/`.
Second pass the same day (Daniele, through the orchestrator): the walls take the floor's voxel finish, the light is
darker ("half way between real and what we got now"), and the reindeer over the cashier faces the room, pale.

## Surfaces

| Swatch | Was | Look D | Where |
|---|---|---|---|
| `WALL_BLACK` (main_wall, lounge_wall) | 23150f / 4a0c10 | **0e0b0b**, voxel grain | main room, buffer, vestibule, lounge walls, the reindeer panel |
| North wall top / bottom / neon | 23150f | **8c8a8a / 100c0c / ff1a12**, voxel grain | main room north wall (opposite the bar): grey above 1.9 m, blackish below, an 8 cm red neon line (emission 3, lights nothing) at 1.9 m; shader `NORTH_SHADER`, one box per segment |
| lobby_wall / smoke_wall / smoke_plaster | 2a2426 / 1e1c20 / 6e6e6a | 0e0b0c / 0e0c0e / 6e6e6a, voxel grain | lobby and corridor; smoking room west wall; its pale plaster (photos 20, 21) |
| frame_wood (pilasters) | 2a1810 | 120c0a, voxel grain | main room framing |
| upper_brick (4–6 m filler) | 2e221e | 130e0d | stays dark: grey there reads as a banner over the HUD |
| `CABIN_DARK` (ceilings) / ceiling_edge | 1c0d0c / 120a0a | 080606 / 070505 | |
| `BEAM_BLACK` | 160a0c | 0a0708 | lounge beams, street lamp post |
| closed_room | 0e0a0a | 070606 | boxes behind closed doors |
| kit CabinDark / CeilingPlum (venue only, at load) | 1c0d0c / 2a0e12 | 0c0909 / 0c0809 | kit pieces in the venue; characters keep theirs. `bc_kit.py` is unchanged |
| kit ShelfAmber, SoffitPeach / CubbyGlow (venue, at load) | ff8a30, e8814a / e8642a | **ff1a12 / 6a0806** | every kit LED in the venue: bar soffits, counter and cashier strips, back-bar bays and art, stage backdrop lights and lanterns, amber PAR lens, step lights, collectibles shelf, wine fridge (kit emission energy kept) |

## Floor: voxel cement (`CEMENT` 4a4848)

Daniele on the test's smooth cement: "looks like a texture that hasn't loaded, make it match the rest of the map
style". Built as `_cement_mat()` in `build_venue.gd`, used by both floor materials ("Floor" in rooms, "Concrete" in
the lobby, corridor, buffer, stub, vestibule, smoking room, staff room and sills); the raised strip keeps its planks.

- Flat square cells of **0.1 m** (two kit voxels; the old tile floor's blocks were 0.2 m), each one of five stepped
  greys around 4a4848, one step = 0.022 albedo (warm shift as in the kit's bond texture: g × 0.95, b × 0.9).
- The steps follow cell edges: value noise sampled once per cell and snapped to a step gives patches of roughly
  0.5–1.5 m; 9 % of cells are single-cell flecks a step up or down (aggregate).
- A 1 px **step shade** on a cell's north and west edges where the grey changes (darker where the neighbour is
  lighter, lighter where it is darker): the cells read as voxels of slightly different height, the way the kit's
  surfaces read through their voxel edges.
- No grout lines (cement is poured, not tiled). Matte: roughness 0.85, specular 0.25 (tiles were 0.34 and glossy).
- One seamless 320 px image (1 px = 2.5 cm) repeats every **8 m**, world-triplanar, nearest-filtered with mipmaps.
- Why no seam on every cell, as kit voxels have: a grid of seams on a floor reads as tiles, and Daniele said the
  floor is "not tiled". The step shade gives the voxel edge only where the value steps.

## Walls: the same voxel finish (`_wall_mat()`)

Daniele: "floor coming tgt walls aswell". Every wall material (and the north wall shader) is a grey grain times its
colour: the floor's generator (`_voxel_tex()`: 0.1 m cells, five stepped values, 9 % flecks, step shade) at base
grey 0.8 with steps of 0.07 (about 9 % of the value, so the cells show on near-black; the cement's 0.022 is 8 %),
a 4 m seamless repeat (160 px), seed 9151. `albedo_color` is set so grain × colour averages the swatch above in
linear light. The walls stay about 5× darker than the cement in sRGB value (15× in linear albedo), so floor and walls never merge: the floor is a
lit warm grey-brown plane, the walls a dark grained frame around it.

## Light (42 lights, 1 shadow map: unchanged count; darker pass)

| Group | Before (main) | Look D as tested | Built (darker) |
|---|---|---|---|
| Key light (directional) | ffcfa8 0.32 | ff8a70 0.288 | ff8a70 **0.15** |
| Table lamps (11) | ffb860 1.8–2.2 | `CANDLE` ffa050 1.35–1.65 | ffa050 **1.45–1.75** |
| Tealights (buffer, tiny tables) | f7db71 1.4, 1.6 | kept | **1.8, 2.1** |
| Counter W/E, cashier | ffb860 1.0, ffd0a0 1.2 | ffa050 0.9, 1.08 | ffa050 **0.72, 0.86** |
| Red lights (neon, red panels, buffer PAR, red PARs, tree, neon edge, back bar; 12; the test report said 13) | as built | × 1.3 | **× 1.69** (e.g. lounge neon 2.6 → 4.4, back bar 1.6 → 2.7) |
| Amber PAR (ParSpot3) | ff7a30 3.4 | `HOUSE_RED` ff2a18 3.4 | ff2a18 3.4 |
| Staff room, light box, disco glint | warm whites 0.9, 0.9, 0.6 | ff2a18 × 0.9 | ff2a18 **0.5, 0.5, 0.32** |
| Lobby light | ffc890 0.9 | ff2a18 0.81 | ff2a18 **1.0** (spawn) |
| Corridor light | ff9a60 0.8 | ff2a18 0.72 | **`CANDLE` ffa050 2.05** (red on the player's green read black in the dark corridor) |
| Picture light (toilet corridor), smoking room spill / bulb | 1.1, 1.2 / 0.7 | kept | **1.43, 1.56 / 0.91** |
| Kept | | | blue PAR, streetlight, pinball |

## Environment

| | Before (main) | Look D as tested | Built (darker) |
|---|---|---|---|
| Ambient | (0.56, 0.44, 0.44) × 1.1 | (0.45, 0.34, 0.34) × 1.5 | (0.45, 0.34, 0.34) × **0.7** |
| `tonemap_exposure` | 1.2 | 1.3 | **1.15** |
| `adjustment_contrast` | 1.18 | 1.06 | 1.06 |
| `glow_intensity` | 0.22 | 0.30 | 0.30 |

Saturation, fog, tonemapper and glow levels unchanged. Why: a red ambient or strong red lamps turn the player into
a black silhouette (red on a green shirt); a near-neutral ambient over near-black walls keeps figures in their own
colours. The darker pass halves the ambient and the key, and lets the red neon and the candle pools carry the light;
below ambient ~0.65 the player turns into a silhouette between the pools (trials K1–KI in
`game/tests/capture_look_build.gd`). Readability numbers: `handoffs/worker-reports-2026-11/look-build.md`.

## Reindeer head (kit `reindeer_head`, photo 16)

New swatch `FurPale` d6caba for the head, neck, chest and ears (were FurBrown 6e5a48 / FurLight 9a8470; the muzzle
is FurLight now). In the venue it hangs at 1.75 m on a 1.4 m dark panel between two dark pillars that break the back
bar behind the cashier, facing the room (it faced the wall before, so only its gilt frame showed).
