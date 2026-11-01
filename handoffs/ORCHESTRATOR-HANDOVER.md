# Orchestrator handover checklist (Black Cabin; adopted from the Ooze checklist, Daniele 2026-11-02)

**Rule (Daniele, 2026-11-02): no new orchestrator until all the work is closed.** That means every worker has finished, or closed with its role note; everything is documented; nothing is running; and the version is closed. Only then does the new orchestrator start from the files and spawn its own fresh sessions. The generic version is in the vault (`wiki/concepts/claude-orchestration-method.md` §5) and in Ooze's `05 Handoff/archetypes/ORCHESTRATOR-HANDOVER.md`.

## Old orchestrator, before handing over (at ~40 % context, or when Daniele asks)
1. Once the handover is decided, start no new worker.
2. Idle workers: each refreshes its role note in `handoffs/`, reports, then archives itself. Check that each note exists before moving on.
3. Running workers: let each finish, or reach a clean stop where everything is committed, verified and pushed and nothing is half-wired. Each then writes its role note, reports and archives itself. Wait until `list_sessions {"linked": true}` shows none of your workers running.
4. Close the version: verify every worker SHA in a clean `git worktree` (import, all suites), push it, refreeze `layout.json` if it is due, and regenerate `docs/CHANGELOG.md` (`python tools/changelog.py`).
5. Put everything in files:
   - Rewrite STATE.md: what is live, what is in flight (none), what waits on Daniele, PROMISED NOT DONE, and the next jobs.
   - Add a LOG.md line.
   - Make sure every Questions-tab answer is a DECISIONS row.
   - Update the hub's Backlog tab status.
6. Copy the session's side-session notes folder into `handoffs/worker-reports-<yyyy-mm>/`.
7. Write the session handoff file: reading order and first prompt only, pointing to files. Nothing may live only in it.
8. Start the new orchestrator on Opus or Fable with effort high or above, passing both explicitly. Then detach it at once (`detach_session`) so it sits at top level, and file it in the Black Cabin sidebar group. No worker is carried over.
9. Answer the new orchestrator's "what is not in the files?" check, then stop. Daniele archives the old orchestrator.

## New orchestrator, first turn
1. `get_session "self"`: if it has a parent and is not detached, `detach_session "self"`.
2. Read PROJECT.md, then STATE.md, then the last DECISIONS rows, then the Questions tab. No worker should be running; if one is, log it as an error of the handover.
3. Ask the old orchestrator what is not in the files, and fold the answer into STATE.md.
4. Verify every claim (git ls-remote, files, suites) before relying on it.
5. Do new work only through fresh workers it starts itself. Never reuse a detached session; a role note seeds the fresh worker.
