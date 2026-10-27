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
5. End with a short report: what was produced, what was decided, what is
   still open for the orchestrator.

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

### Wave 3 — depends on wave 2

Multiplayer presence and persistence (reuse Ooze Syndicate's server model),
first two minigames, performance/event system, character customization,
memory collection. Split per feature, one session each.

## Decisions the orchestrator still owes

- Engine confirmation after 1C's write-up.
- Single-player-first or multiplayer-first for the first playable.
- Target platform (phone portrait, like a Tamagotchi, vs desktop).

## Log

- 2026-10-27 — Project created. Repo `Talos91/bc-tamagotchi` was empty.
  Brief and 12 venue photos imported. Waves defined.
