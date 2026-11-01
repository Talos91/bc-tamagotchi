PROJECT: Black Cabin Tamagotchi — root H:\My Drive\PROJECTS\Black Cabin Tamagotchi

If the folder you are in is not this root, stop and tell the orchestrator.

## Basics
- What it is: a voxel-art Tamagotchi-style game commissioned by the real Black Cabin bar (Bangkok): the player's character lives a needs loop (four meters, real-time decay) in a voxel replica of the venue, with minigames, coins and, later, a bridge to the real venue. Mode: single-player first playable, desktop first, phone portrait later; multiplayer (wave 4) is not started. Legacy / never to build from: direction render 04 (style reference only) and the first greybox integration.
- Owner: Daniele (they/them). Start pages to read: `docs/design/DECISIONS.md` (binding, newest rows at the bottom), `ORCHESTRATION.md`, `docs/MANUAL.md`, `docs/art/direction/README.md`. Design package: `docs/design/` (`00-brief.md`, `01-high-concept.md`, `02-gdd.md`, `03-cast.md`, `04-coins`, `06-stakes`); open-questions file: the "Still open" list at the bottom of `docs/design/DECISIONS.md`.
- Working memory: `STATE.md` (read first), `LOG.md`, this file, `handoffs/`, all at the repo root. Write UTF-8 text. Git on this Google Drive mount is slow: wait on `.git/index.lock`, never delete it while a git process runs.
- Decisions page: `docs/design/DECISIONS.md`, section "Still open" is the owner's decisions page; the orchestrator copies each answer into the table above it as a dated row and removes it from "Still open". The owner decides rules, balance, art acceptance, money and venue facts.
- Models: Opus for design and art, Sonnet for mechanical work. At most three workers at a time.
- Session titles start with an emoji: 🎛️ orchestrator, 🎲 design, 🎨 art, 🛠️ tech, 🎭 cast, 🖼️ UI, 🧱 kit, 🏗️ venue, 🎮 gameplay, 🌐 multiplayer, 🧹 housekeeping.

## Repo, clones, numbers
- Repo: github.com/Talos91/bc-tamagotchi. Branch: `main` only; never push to any other branch. Product code lives in `game/` (Godot project); tools in `tools/`; Blender review files in `blender/`.
- Checkout: single shared checkout at the root above; workers do not use worktrees. Commit straight to `main` with only your own paths staged (`git add <paths>`, never `git add -A`), after `git pull --rebase`. Never stash, reset or switch branches; other sessions have uncommitted work in the same tree.
- Numbers and rules: `game/scripts/rules.gd` (decay, floors, actions), `game/scripts/needs.gd`, `game/scripts/save.gd`; minigames in `game/scripts/minigames/`; strings in `game/i18n/strings.csv` and `game/i18n/strings_venue.csv`; layout of record `game/assets/kit/layout.json` (unfrozen 2026-11-01 for the baseline-map rebuild; owned by the 🏗️ venue-rebuild session; refreezes when Daniele accepts).
- Engine: Godot 4.6.1 at `H:/My Drive/PROJECTS/Ooze Syndicate/Tools/Godot/Godot_v4.6.1-stable_win64.exe` (Compatibility renderer, `rendering/viewport/hdr_2d=true` required). Blender 5.2.2 at `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`.
- House rules: where DECISIONS.md and the GDD disagree, DECISIONS.md wins until the GDD is updated; every Blender generator saves a lit, labelled review `.blend` into `blender/`; every screenshot set includes portrait (1080×1920) and landscape (1920×1080) until orientation is decided; claim only what was verified.

## Tests
- Headless suites, run from `game/`: `smoke_stairs`, `smoke_tap`, `smoke_hud`, `test_needs`, `test_minigames`, `smoke_loop` (new, owned by the zone-wiring session). Files are `game/tests/<name>.gd`, run as `Godot --headless --path game -s tests/<name>.gd` using the Godot exe above.
- Full-suite rule: run all six once per assembled wave before the orchestrator regenerates the changelog; role suites (needs, minigames, loop) run on every change to their paths.
- Windowed runs: omit `--headless`; screenshots go next to the renders they are compared with. Known slow: `test_minigames` (hundreds of checks).

## Release path
- None yet: no build, export or publish path exists. First playable is desktop; phone later (web export untested).
- Docs updated together after a wave: `ORCHESTRATION.md` wave status, `docs/MANUAL.md` section 15, `STATE.md`, `LOG.md`, and `docs/CHANGELOG.md` via `python tools/changelog.py` (orchestrator only).

## Never
- Never edit another session's paths.
- Never move anything in `game/assets/kit/layout.json` unless you are the 🏗️ venue-rebuild session (2026-11-01 wave); it refreezes when Daniele accepts the rebuilt room.
- Never use direction render 04 for layout. Layout source is the real floor map `docs/art/direction/08` + route `17` with photos 09–22 and the README answers; renders 05–06 remain the look target.
- Never commit raw venue photos over 2000 px.
- Never push to any branch but `main`.
- Never report "done" without evidence (tip, test log, artefact path, note) and a LOG.md line.

## Sites and links
- Repo: https://github.com/Talos91/bc-tamagotchi
- Live manual doc (Claude Docs): https://claude.ai/artifact/6p6YVjvtt3EhjY599Bs8rQ (doc id 2f111106-392b-4ea9-80ff-61f75267f99d); refresh its section 15 when waves land.
- Vault page: `G:\My Drive\VAULTS\Talos Vault\wiki\projects\black-cabin.md`. Orchestration method: `wiki/concepts/claude-orchestration-method.md`; generic profiles: `wiki/agents/`.

## Per-role notes
### Orchestrator
- Session fdaed712-5416-430d-b3a7-7174cf46699f. Briefs, verifies, writes STATE.md and LOG.md, owns DECISIONS.md "Still open", regenerates the changelog. Builds nothing.
### Game design / gameplay (🎲 🎮)
- Design docs `docs/design/`; code under `game/scripts/`, `game/scenes/`; see Tests above.
### Voxel art (🎨 🧱 🎭)
- Generators: `tools/blender/bc_kit.py` (venue kit), `tools/blender/bc_chars.py` (characters), `tools/blender/bc_review.py` (review scene). Venue generator `game/tools/build_venue.gd`; parity capture `game/tools/capture_parity.gd` + `game/tools/parity_compose.py`. Outputs: `game/assets/kit/`, `game/assets/chars/`, `blender/`, captures in `docs/art/screens/`. Acceptance target: direction renders 05 and 06.
### Housekeeping (🧹)
- Docs, changelog inputs, handoffs archive; never touches code, rules or tests.

## Conflicts noted
- `docs/design/DECISIONS.md` vs `02-gdd.md`: DECISIONS wins until the GDD is amended.
- Renders 05 and 06 disagree on framing: 05 is the layout source.
- 2026-10-28: `ORCHESTRATION.md` Waves/Log sections predate the method; the Method section at its top now governs process, and STATE.md/LOG.md replace its Log.
