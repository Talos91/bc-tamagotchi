PROJECT: Black Cabin Tamagotchi — root H:\My Drive\PROJECTS\Black Cabin Tamagotchi

If the folder you are in is not this root, stop and tell the orchestrator.

## Basics
- What it is: a voxel-art Tamagotchi-style game commissioned by the real Black Cabin bar (Bangkok): the player's character lives a needs loop (four meters, real-time decay) in a voxel replica of the venue, with minigames, coins and, later, a bridge to the real venue. Mode: **mobile only** (phone, portrait first; Daniele 2026-11-02), single-player first playable; multiplayer (wave 4) is not started. Legacy / never to build from: direction render 04 (style reference only) and the first greybox integration.
- Owner: Daniele (they/them). Start pages to read: `docs/design/DECISIONS.md` (binding, newest rows at the bottom), `ORCHESTRATION.md`, `docs/MANUAL.md`, `docs/art/direction/README.md`. Design package: `docs/design/` (`00-brief.md`, `01-high-concept.md`, `02-gdd.md`, `03-cast.md`, `04-coins`, `06-stakes`); open-questions file: the "Still open" list at the bottom of `docs/design/DECISIONS.md`.
- Working memory: `STATE.md` (read first), `LOG.md`, this file, `handoffs/`, all at the repo root. Write UTF-8 text. Git on this Google Drive mount is slow: wait on `.git/index.lock`, never delete it while a git process runs. Automatic git maintenance is off for this repo (`gc.auto 0`, `maintenance.auto false`, 2026-11-02): a background repack while Drive synced left 33 object folders locked until Google Drive was restarted. Never run `git gc` or `git maintenance` here.
- Questions to the owner: the **Questions tab** of the Black Cabin Backlog artifact (https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW#questions; database collection `items`, one doc per question with kind now/design/facts, options with one `rec`, `answer`, `note`). Workers never ask Daniele directly: they report calls to the orchestrator, who adds them to the tab, reads answers back, copies each into `docs/design/DECISIONS.md` as a dated row and removes it from "Still open". The owner decides rules, balance, art acceptance, money and venue facts.
- Models: Opus for design and art, Sonnet for mechanical work. At most three workers at a time.
- Session titles start with an emoji: 🎛️ orchestrator, 🎲 design, 🎨 art, 🛠️ tech, 🎭 cast, 🖼️ UI, 🧱 kit, 🏗️ venue, 🎮 gameplay, 🌐 multiplayer, 🧹 housekeeping.

## Working rules from Daniele (2026-11-02, vault method §5)
- **One hub artifact:** every page made for Black Cabin is a tab or a database row of the Black Cabin Backlog (https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW). Never publish a new standalone artifact ("so we don't have 40 sparse artifacts"). The existing manual stays a Claude Doc.
- **Questions carry pictures:** any question for Daniele that needs a visual includes one or more screenshots (on its Questions-tab card), so he never has to launch the game to answer.
- **Workers archive themselves, only after reporting (mandatory, Daniele 2026-11-02):** before a worker archives itself it must, in this order, (1) commit its code and captures, (2) write or refresh its role note `handoffs/<job>-<date>.md` (state now, files, how to re-run, open items), (3) commit its report `handoffs/worker-reports-<yyyy-mm>/<job>.md`, (4) make sure its hub review card exists when there is anything to review, (5) send its final message to the orchestrator (first 400 characters: commit SHA, suites result, card ids). A worker that would archive without all five stops and reports instead. Idle workers close the same way after refreshing their notes; their next job goes to a fresh worker started by the orchestrator. The orchestrator starts every worker itself and checks the five at verify time; if Daniele archives a worker early, the orchestrator verifies what is on disk and writes the missing card or note itself.
- **Models:** the orchestrator runs on Fable or Opus at high effort or above; workers run on whatever model the job needs (Opus for design and art, Sonnet for mechanical work). A Fable worker needs Daniele's written OK.
- **Review cards carry pictures and file paths (Daniele 2026-11-02):** anything Daniele is asked to review goes on the hub's Questions tab as a card with its pictures **and** a `files` list (`[{path, label}]`, Windows paths to the folder or file, shown with a Copy button) so the folder can be opened for a file review. Each worker makes sure its review material is on a card before it reports: it names the card pictures and the folder in its report, and may write the card itself (hub db `items`, schema in `handoffs/orchestrator-2026-11-02.md`; pictures via `Artifact` asset upload to the hub url). The orchestrator checks the card exists at verify time and, whenever it asks Daniele to review, links the hub in chat (https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW#questions) and the files as clickable paths.
- **Handover:** no new orchestrator until all the work is closed (every worker finished, role note written, archived; version closed; everything in files). Follow `handoffs/ORCHESTRATOR-HANDOVER.md`, the copy of vault `wiki/concepts/orchestrator-handover.md`. Every worker brief ends with "update your role note, commit your report, send it, then archive yourself". Promised-but-not-done items and worker reports live in project files, never only in a session.

## Repo, clones, numbers
- Repo: github.com/Talos91/bc-tamagotchi. Branch: `main` only; never push to any other branch. Product code lives in `game/` (Godot project); tools in `tools/`; Blender review files in `blender/`.
- Checkout: single shared checkout at the root above; workers do not use worktrees. Commit straight to `main` with only your own paths staged (`git add <paths>`, never `git add -A`), after `git pull --rebase`. Never stash, reset or switch branches; other sessions have uncommitted work in the same tree.
- Numbers and rules: `game/scripts/rules.gd` (decay, floors, actions), `game/scripts/needs.gd`, `game/scripts/save.gd`; minigames in `game/scripts/minigames/`; strings in `game/i18n/strings.csv` and `game/i18n/strings_venue.csv`; layout of record `game/assets/kit/layout.json` (frozen again 2026-11-02 after Daniele accepted the lounge revamp + follow-up, e5d38a6; only exception still open: the Questions-tab card lounge-east-tables, which may move the east rectangular table back alone).
- Engine: Godot 4.6.1 at `H:/My Drive/PROJECTS/Ooze Syndicate/Tools/Godot/Godot_v4.6.1-stable_win64.exe` (Compatibility renderer, `rendering/viewport/hdr_2d=true` required). Blender 5.2.2 at `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`.
- House rules: where DECISIONS.md and the GDD disagree, DECISIONS.md wins until the GDD is updated; every Blender generator saves a lit, labelled review `.blend` into `blender/`; every screenshot set includes portrait (1080×1920) and landscape (1920×1080) until orientation is decided; claim only what was verified.

## Tests
- Headless suites, run from `game/`: `smoke_stairs`, `smoke_tap`, `smoke_hud`, `test_needs`, `test_minigames`, `smoke_loop`, `smoke_doors_sit`, `smoke_start`, `test_menu`, `smoke_version`, `test_nightlife`, `test_seats`, `test_feel`, `test_lounge` (fourteen as of 2026-11-02; new suites add themselves here through the orchestrator). Files are `game/tests/<name>.gd`, run as `Godot --headless --path game -s tests/<name>.gd` using the Godot exe above.
- Orchestrator verification runs in a clean `git worktree` of the exact SHA (import first), never the shared tree, then pushes that SHA only. Run suites with `APPDATA` pointed at an empty folder: the real `user://save.json` may hold a WASTED lockout (smoke_tap hangs on it).
- Full-suite rule: run all suites once per assembled wave before the orchestrator regenerates the changelog; role suites (needs, minigames, loop) run on every change to their paths.
- **Playtest launches for Daniele** open in a phone-sized portrait window, never full desktop: `Godot --path game --resolution 450x800` (from a clean worktree of the pushed SHA, stamped with `python tools/version.py`). Daniele 2026-11-02: "the game is mobile only".
- Windowed runs: omit `--headless`; screenshots go next to the renders they are compared with. Known slow: `test_minigames` (hundreds of checks).

## Release path
- Versioning (2026-11-02, `docs/tech/versioning.md`): the version lives in `application/config/version` in `game/project.godot` (0.1.0 closed 2026-11-02; 0.2.0 in progress). The orchestrator bumps MINOR when it closes a version and PATCH for a hotfix; workers never bump it. The game shows `v<version> · <sha>` bottom right (`game/scripts/version_info.gd`). Stamp a build with `python tools/version.py` before handing it to Daniele; add the closed version to `RELEASES` in `tools/changelog.py` when cutting one.
- No build, export or publish path exists yet. The game is mobile only (Daniele 2026-11-02); no phone export exists yet (web export untested).
- Docs updated together after a wave: `ORCHESTRATION.md` wave status, `docs/MANUAL.md` section 15, `STATE.md`, `LOG.md`, and `docs/CHANGELOG.md` via `python tools/changelog.py` (orchestrator only).

## Never
- Never edit another session's paths.
- Never move anything in `game/assets/kit/layout.json` (frozen; venue v4 and the lounge revamp accepted by Daniele 2026-11-02). Only an owner decision unfreezes it.
- Never use direction render 04 for layout. Layout source is the real floor map `docs/art/direction/08` + route `17` with photos 09–25 and the README answers; renders 05–06 remain the look target.
- Never commit raw venue photos over 2000 px.
- Never push to any branch but `main`.
- Never report "done" without evidence (tip, test log, artefact path, note) and a LOG.md line.

## Sites and links
- Repo: https://github.com/Talos91/bc-tamagotchi
- Live manual doc (Claude Docs): https://claude.ai/artifact/6p6YVjvtt3EhjY599Bs8rQ (doc id 2f111106-392b-4ea9-80ff-61f75267f99d); refresh its section 15 when waves land.
- Vault page: `G:\My Drive\VAULTS\Talos Vault\wiki\projects\black-cabin.md`. Orchestration method: `wiki/concepts/claude-orchestration-method.md`; generic profiles: `wiki/agents/`.

## Per-role notes
### Orchestrator
- Session local_9bb3d41c (from 2026-11-02; before: local_78d0c67d, fdaed712). Briefs, verifies, writes STATE.md and LOG.md, owns DECISIONS.md "Still open", regenerates the changelog. Builds nothing.
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
