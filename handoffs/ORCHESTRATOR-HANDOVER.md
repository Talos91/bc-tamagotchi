# Orchestrator handover checklist (Black Cabin)

**The checklist is `G:\My Drive\VAULTS\Talos Vault\wiki\concepts\orchestrator-handover.md`** (rule, old-orchestrator steps, new-orchestrator first turn, Master check-in); method `wiki\concepts\claude-orchestration-method.md`, orchestrator profile `wikigents\general\orchestrator.md`. This file keeps no copy of them, only the Black Cabin deltas:
- **Rule (Daniele, 2026-11-02):** no new orchestrator until all the work is closed: every worker finished or closed with its role note, everything in files, nothing running, the version closed.
- **Worker archive order** is in PROJECT.md "Method and Black Cabin deltas"; the context budget is method §6 plus the connector list there.
- **Close the version here:** verify every worker SHA in a clean `git worktree` (import, all fourteen suites, empty APPDATA), push that SHA, refreeze `game/assets/kit/layout.json` if it is due, regenerate `docs/CHANGELOG.md` (`python tools/changelog.py`).
- **Files to bring up to date:** STATE.md (live, in flight = none, waits on Daniele, PROMISED NOT DONE, next jobs), a LOG.md line, every Questions-tab answer as a `docs/design/DECISIONS.md` row, the hub's Backlog tab status.
- **Copy** the session's side-session notes folder into `handoffs/worker-reports-<yyyy-mm>/`.
- **Handoff file:** reading order and first prompt only, pointing to files; nothing lives only in it.
- **Start the new orchestrator** on Opus or Fable, effort high or above, both passed explicitly; detach it at once (`detach_session`) and file it in the Black Cabin sidebar group; no worker is carried over. Answer its "what is not in the files?" check, then stop; Daniele archives the old orchestrator.
- **New orchestrator, first turn:** `get_session "self"` and detach if it has a parent; read PROJECT.md, STATE.md, the last DECISIONS rows, the Questions tab; check in with 👑 Orchestrator Master (`local_bccbb1e7-7474-49e5-9574-c2acd7ce6641`); verify every claim (git ls-remote, files, suites); start the next version only with fresh workers it spawns itself, each seeded from its role note, with an explicit model.

