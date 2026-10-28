# 🎮 Zone wiring + first-playable assembly — state 2026-10-28

## Done (on main)

- `068949a` zones from `layout.json` (`game/scripts/zones/`), visit session, house band loop, tipsiness, `i18n/strings_venue.csv` (110 keys EN+TH) registered in `project.godot`.
- `cfa7c72` needs HUD, zone prompt, zone sheet, action card, Welcome Back, walk-out + Flat stand-in (`game/scenes/ui/`), `main.gd` / `main.tscn` wiring, debug keys F1–F8, `--capture` mode.
- `5fbe25b` `game/tests/smoke_loop.gd`: Welcome Back, every zone, all four minigames, a song, a sit, leave with totals, GO OUT. PASS.
- `42cec51` `docs/tech/02-playtest-guide.md`, `docs/art/screens/loop/hud-portrait-bar.png` (1080×1920), `hud-landscape-stage.png` (1920×1080).

Suites: smoke_loop, smoke_stairs, smoke_tap, smoke_hud, test_needs, test_minigames all PASS at `fcf99d5`.

## Calls made where the GDD / brief left it open (log in DECISIONS)

1. **Tipsiness is not in `rules.gd`** (the brief said it was). Built in `scripts/zones/tipsiness.gd` per 03-cast §5.1: per visit, not
   saved; 1–2 Warm, 3–4 Tipsy, 5+ Merry; −1 state per 30 real minutes; water −1 at once. Pour Perfect and Try something new count as
   alcoholic; Thai iced tea and water do not (both are a plain `order_drink`, +15). Merry: alcoholic rows disabled, Pour Perfect still
   plays and counts as a mocktail. Walk-out shows "Taxi home tonight." if Merry.
2. **No coins yet:** every drink is free; "First one's on the house" is only a label on the first order of a visit.
3. **Leaving is the street door** (exit_sign `ExitSignStreet`, lounge north wall), not the curtain: the curtain is the lounge ↔ main
   room passage. Leave on the HUD does the same.
4. **`enter_lounge` fires on arrival:** the street door opens into the Lounge, so every visit starts with +5 Nightlife.
5. **Mali sits at `Table2`** (only regular with Candle Talk content). Candle Talk and "Sit with Mali" only there; every other Candle
   Floor round table offers "Sit here a while", `sit_with` keyed per table (anonymous patrons), once per table per day.
6. **Sit = 60 s standing still at the table** (stand_drink pose); moving cancels. No seat is claimed from the patrons.
7. **House band stand-in:** 4 × 60 s songs + 12 s breaks, looping on real time (not the debug clock). A song counts as heard at ≥60%
   of it within earshot = camera zones Stage + Candle Floor (not Bar, Lounge). `finish_set` every 4 songs heard in a visit. Applause
   only in the breaks (cap 6 from rules). FRR plays the song currently on.
8. **Try something new menu:** six invented drinks (Lychee Fizz, Thai Tea Sour, Mekhong Mule, Butterfly Pea Gin, Pandan Colada,
   Smoky Old Fashioned), tried list in `Needs.ext.drinks_tried`. Needs Black Cabin's real menu.
9. **Visit lifecycle:** a visit begins when main.tscn loads (arrival). BACK TO THE FLAT → Flat stand-in (meters, Vibe) → GO OUT
   starts the next visit (counts for the daily multiplier). A 10-minute idle end is silent; the next action starts a new visit
   (Needs' existing behaviour), which also counts as a visit of the day.
10. **Welcome Back** greets `profile.display_name`, else "Hey you". `Needs.first_drink_free` is not consumed (no coins).
11. **Thai strings are machine drafts**; native pass needed, like Mali's lines.

## Open / for other sessions

- **Venue (room):** the navmesh strip between the first table row and the bar stools is an island, so the player cannot reach the
  counter; the bar trigger extends 3.4 m out and is used from the aisle. Joining that strip would let the player stand at the bar.
- Not built: Who's-here chips, album button, 6 s idle context hint, meter detail sheet, dance spot (`dance_30s`), Nam chat, memories.
- Tipsy walk variants play at a fixed speed (PatronFigure scales only `walk`); a small foot-slide when Warm+.
