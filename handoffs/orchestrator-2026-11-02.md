# 🎛️ Orchestrator — state 2026-11-02 (new version)

Session local_78d0c67d (Opus, high effort, detached, top level). It replaced local_d1485b13 / fdaed712 after a closed
handover. Read `PROJECT.md`, then `STATE.md`, then this note.

## Old orchestrator's handover answers (things not in the other files)
- **Clean-worktree verify:** `git worktree add` with an absolute path (a relative one once landed inside the repo);
  `Godot --headless --path game --import` first; `git worktree remove` fails with "Filename too long" in the scratchpad,
  so `rm -rf` the folder and then `git worktree prune`. Push by SHA only (`git push origin <sha>:main`).
- **Shared index:** a worker's commit once swept already-staged files into itself (0dc0b68). Stage right before
  committing; wait on `.git/index.lock`.
- **Hub db (`items`):** fields order, kind (now|design|facts), ref, date, title, context (paragraphs split on blank
  lines), options [{key,text,rec}], multi, images [{url,alt}], answer, note, answered_at. Writes to existing docs need
  `if_version`; Daniele edits cards live, so expect version mismatches and re-read. Screenshots: `Artifact` publish
  with the hub url, `asset: true`, `file_paths`; put the returned `/_blob/<id>` url in `images`. The page source is
  `docs/design/backlog-board.html` (capabilities db + user + assets); `Artifact read` it once before republishing.
- **How Daniele works:** sometimes messages workers directly, and they act and report it. Answers come both on the tab
  and in chat; a chat answer with an image becomes a direction file in the repo, and the tab card is marked answered
  with a note. Explain game-dev jargon, use emoji session titles and they/them, keep status messages short.
  Cross-project rules arrive through the Ooze orchestrator (local_ee0811d3). A ctx-guard hook nags at 40 % context.
- **App limits:** `start_session` "user_asked" is refused on turns started by events or cross-session messages, so
  propose own_initiative cards; Daniele starts them. Workers often cannot archive themselves (it needs Daniele's OK in
  their session), so the orchestrator archives them after verification.
- **Vault:** recaps only at releases (no release yet).

## Lessons this version
- A worker staging a whole file sweeps up another session's uncommitted hunks in it (4bf4d9e took nightlife's toilet-zone hunk of `venue_zones.gd`). Briefs say: check `git status` first and ask before editing a file another session has touched.
- With uncommitted edits from parallel workers in the shared tree, suites can fail there (smoke_loop "walked to stage" with feel-pass edits); only the clean-worktree run counts.

- **Push only what you verified, also for doc commits (local_9bb3d41c, 2026-11-02):** a worker's unverified commit (50a0623) sat on local main under the orchestrator's STATE commit, so `git push origin HEAD:main` sent it out before the verify (it then passed 14/14). Before any push, run `git log --oneline origin/main..HEAD` and push only when every commit listed is verified or the orchestrator's own docs.

## This version so far
- Six answers given after the close are folded into DECISIONS ("Questions tab, third batch"); "Still open" pruned.
- Workers: see STATE.md IN FLIGHT.
