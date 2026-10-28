# Orchestration — how this project is run

One orchestrator session (Fable) plans, briefs, reviews and merges. It does
not write game content or code itself. Worker sessions on cheaper models do
the work, one session per deliverable, each on its own branch.

## Ground rules for every worker session

1. Read `docs/design/00-brief.md` and look at `docs/reference/venue-photos/`
   before producing anything.
2. One deliverable per session. Write it to the path named in the brief.
   Do not touch files owned by another session.
3. Follow the pipeline order: nothing visual before the art bible, nothing
   in-engine before the GDD core loop is written.
4. Commit on your own branch (`bc/<slug>`), push, and open a PR against
   `main`. The orchestrator reviews and merges.
5. Blender rule (as in Ooze Syndicate): every generator script ends by saving
   a review `.blend` into `blender/` at the repo root (`BlackCabinKit.blend`,
   `BlackCabinChars.blend`, ...), with the objects laid out on a labelled grid,
   lit, and a camera framing them, so Daniele can open the file and see what
   was made. Commit the `.blend` with the script.
6. End with a short report: what was produced, what was decided, what is
   still open for the orchestrator.

## Session naming

Every session title starts with an emoji so it can be told apart at a glance:

| Emoji | Area |
|-------|------|
| 🎛️ | Orchestrator |
| 🎲 | Game design (concept, GDD, systems, minigames) |
| 🎨 | Art (art bible, sheets, kit visuals) |
| 🛠️ | Tech (engine, skeleton, build, networking) |
| 🎭 | Cast and characters |
| 🖼️ | UI style guide and wireframes |
| 🧱 | Venue kit (Blender MCP, assets) |
| 🎮 | Gameplay features and minigames in-engine |
| 🌐 | Multiplayer and persistence |

## Waves

### Wave 1 — foundations (run in parallel, documents only)

| # | Session | Deliverable | Model |
|---|---------|-------------|-------|
| 1A | Game design | `docs/design/01-high-concept.md`, `docs/design/02-gdd.md`: pillars, core loop, the needs system (four meters, weekly decay, refill actions), session structure, progression, memories, minigame list with one-paragraph designs, live-ops cadence | Opus |
| 1B | Art bible | `docs/art/art-bible.md`: voxel style rules (voxel scale, proportions, palette from the photos, lighting model for red neon + candle + amber bar), material list, the fixed **style anchor** prompt block, and the list of sheets to generate next | Opus |
| 1C | Tech decision + skeleton | `docs/tech/01-engine-decision.md` (Godot 4.6 as the default, given Ooze Syndicate's pipeline and Blender MCP kit; state the case for a web client as the alternative) and, once decided, `game/` with an empty project, a greybox of the venue at the right footprint, a third-person character controller, and a running scene | Sonnet |

Wave 1 has no file overlap, so all three start together.

### Wave 2 — depends on wave 1

| # | Session | Needs | Deliverable |
|---|---------|-------|-------------|
| 2A | Cast bible | 1A + 1B | `docs/design/03-cast.md`: regulars, staff, performers, archetypes, how NPCs and other players' characters coexist |
| 2B | UI style guide + wireframes | 1A + 1B | `docs/ui/style-guide.md`, wireframes for the needs HUD, character creator, venue map, memory album |
| 2C | Venue kit | 1B + 1C | Blender MCP script that generates the voxel venue kit (bar, round tables, stools, curtains, stage, disco ball, neon sign, CRT, pinball) and imports into `game/` |
| 2D | Needs system prototype | 1A + 1C | The four meters, decay, refill actions, save/load, in `game/` |

### Wave 3a — build the room for real (parallel, disjoint paths)

| # | Session | Owns | Deliverable |
|---|---------|------|-------------|
| 3A | 🛠️ Integration | `game/scenes/venue`, `game/scenes/main.tscn`, `game/scripts/camera*`, `game/scripts/player*`, `game/project.godot` | Replace the greybox with kit objects laid out per the renders; HDR 2D on; lamp/tealight point lights, floor reflections, haze; the portrait diorama follow camera with tap-to-move; room at 4 m; open it in a real window and commit screenshots next to the renders |
| 3B | 🧱 Kit v2 | `tools/blender/bc_kit.py`, `game/assets/kit` | Banquette, stage steps, truss + PAR lights, stage tree, speakers, AC, wall lamps, paintings, soffit; browner wood; real plant-wall leaves; voxel floor tile; face merging to shrink the kit |
| 3C | 🎨 Character kit | `tools/blender/bc_chars.py`, `game/assets/chars` | Chibi voxel avatar kit per art bible §7 and cast bible: 3 bodies × 4 heads, hair, outfits, skin palette; the 8 regulars and staff as presets; idle/walk/tipsy animation set; showcase scene |
| 3D | 🎮 Minigames | `game/scenes/minigames`, `game/scripts/minigames` | Pour Perfect, Front Row Rhythm, Candle Talk, Neon Pinball as standalone portrait scenes with the shared frame and result card from the wireframes, each calling `Needs.apply_action` |

### Wave 3-parity — reach the quality bar (renders 05/06)

| # | Session | Owns | Deliverable |
|---|---------|------|-------------|
| P0 | 🎨 Visual parity pass (done, archived) | all visual paths | Measurements, kit v3, venue re-laid to 05/06 and photo 07, lounge turned, iterations 0–10 in `docs/art/screens/parity/`, plan sheet |
| P1 | 🎨 Characters | `tools/blender/bc_chars.py`, `game/assets/chars/`, `game/scripts/venue_patron*`, `blender/BlackCabinChars.blend`, `docs/art/screens/chars/` | Head and body proportions, faces visible from the game camera, seated / glass-holding / tray / band poses, clothing detail, matched against the figures in 05/06 |
| P2 | 🎨 Room polish | `tools/blender/bc_kit.py`, `game/assets/kit/`, `game/scenes/venue/`, `game/tools/`, WorldEnvironment lighting, `blender/BlackCabin.blend`, `docs/art/screens/parity/`, `docs/art/parity-measurements.md` | Stage as dark platform under a red wash, lighting balance, crisp edges and contact shadows, material contrast; iterations 11+ |

Layout is frozen at `game/assets/kit/layout.json` (146d334, plan confirmed by Daniele). Neither session edits the other's paths; characters may run `capture_parity.gd` but not edit it.

### Wave 3b — depends on 3a and 3-parity

Inputs carried over from 3a reports (add to the relevant 3b brief):
- Fonts: Kanit and IBM Plex Sans Thai Looped are not in the repo; add them
  under `game/assets/fonts/` and a theme, or Thai breaks on mobile/web export.
- `rules.gd` needs a Candle Talk lean-bonus action (+5 per DECISIONS); the
  result card already flags `extra.lean`.
- Pour Perfect runs 17–20 s vs the GDD's 20–30 s; pinball score mapping
  (3000 pts = 1.0) is a guess; Rhythm's +8–12 Music per 60 s song feels small.
- Thai lines for Mali are machine drafts; a native pass is required.
- CSV import in the editor must be set to "Keep" (extra columns read as locales).
- Memory drops are not built anywhere yet.

🎮 Zone wiring (bar, stage, lounge triggers → Needs; visit begin/end; walk-out
totals; Welcome Back dialogue; `game/i18n/strings.csv` with EN/TH), 🎭
Character creator + the Flat screen, 🎵 Performance system (house band set,
applause, schedule on Bangkok time), 🖼️ Memories album. Then a first-playable
assembly pass and a real-device test.

### Wave 4 — multiplayer

Presence and persistence reusing Ooze Syndicate's relay + headless host +
Supabase accounts. Not before the first playable is fun on a phone.

## Decisions the orchestrator still owes

- Engine confirmation after 1C's write-up.
- Single-player-first or multiplayer-first for the first playable.
- Target platform (phone portrait, like a Tamagotchi, vs desktop).

## Log

- 2026-10-27 — Wave 1 (design, art bible v2, engine + greybox) and wave 2
  (cast, UI, 35-object kit, needs prototype with passing tests) done. Routine
  calls logged in `docs/design/DECISIONS.md`. Wave 3 split into 3a/3b.

- 2026-10-27 — Project created. Repo `Talos91/bc-tamagotchi` was empty.
  Brief and 12 venue photos imported. Waves defined.
