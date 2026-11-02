# Venue palette: look D "as in the venue" (2026-11-02)

Daniele picked look D of the look test (DECISIONS "Venue look: D, with a voxel floor"). Built by 🎨 look-build in
`game/tools/build_venue.gd` (venue materials, lights, environment) and `game/scenes/venue/venue_looks.gd` (kit
swatches recoloured at load). Values come from the look test (`handoffs/worker-reports-2026-11/look-test.md`); this
note supersedes the venue rows of `art-bible.md` §3 where they differ. Captures: `docs/art/screens/look-build/`.

## Surfaces

| Swatch | Was | Look D | Where |
|---|---|---|---|
| `WALL_BLACK` (main_wall, lounge_wall) | 23150f / 4a0c10 | **0e0b0b** | main room, buffer, vestibule, lounge walls |
| North wall top / bottom / neon | 23150f | **8c8a8a / 100c0c / ff1a12** | main room north wall (opposite the bar): grey above 1.9 m, blackish below, an 8 cm red neon line (emission 3, lights nothing) at 1.9 m; shader `NORTH_SHADER`, one box per segment |
| lobby_wall / smoke_wall | 2a2426 / 1e1c20 | 0e0b0c / 0e0c0e | lobby and corridor; smoking room west wall (its pale plaster 6e6e6a stays, photos 20, 21) |
| frame_wood (pilasters) | 2a1810 | 120c0a | main room framing |
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

## Light (42 lights, 1 shadow map: unchanged count)

| Group | Was | Look D |
|---|---|---|
| Key light (directional) | ffcfa8 × 0.32 | ff8a70 × 0.288 |
| Table lamps (11) | ffb860 1.8–2.2 | `CANDLE` ffa050, × 0.75 (1.35–1.65) |
| Counter W/E, cashier | ffb860 1.0, ffd0a0 1.2 | ffa050 0.9, 1.08 |
| Red lights (neon, red panels, buffer PAR, red PARs, tree, neon edge, back bar; 12, the test report said 13) | as built | × 1.3 |
| Amber PAR (ParSpot3) | ff7a30 3.4 | `HOUSE_RED` ff2a18 3.4 |
| House: lobby, corridor, staff room, light box, disco glint | warm whites | ff2a18 × 0.9 |
| Kept | | tealights, blue PAR, toilet-corridor picture light (warm, photo 10), smoking room street spill and bulb (cool, photo 13), streetlight, pinball |

## Environment

Ambient (0.45, 0.34, 0.34) × 1.5 (was (0.56, 0.44, 0.44) × 1.1), `adjustment_contrast` 1.06 (was 1.18),
`tonemap_exposure` 1.3 (was 1.2), `glow_intensity` 0.30 (was 0.22). Saturation, fog, tonemapper and glow levels
unchanged. Why: a red ambient or strong red lamps turn the player into a black silhouette (red on a green shirt);
a near-neutral strong ambient over near-black walls keeps figures in their own colours.
