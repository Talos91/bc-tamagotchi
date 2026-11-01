# Orchestrator handover checklist (Black Cabin)

Done by the outgoing orchestrator before the new one starts; the new one ticks it on arrival.

1. STATE.md rewritten (<40 lines): live, in flight, workers alive with session ids, waiting on owner, next three jobs, queue.
2. LOG.md has a line for every event since the last handover.
3. DECISIONS.md holds every owner answer as a dated row; the Questions tab has no answered card that is missing from it.
4. Every pushed SHA was verified in a clean git worktree; any local unpushed commits are listed in STATE with their status.
5. Running workers listed with their briefs' paths and what they report next; idle workers archived after refreshing their notes.
6. Promised-not-done items are in STATE or BACKLOG, not only in the session.
7. The orchestrator's session handoff file is refreshed and its first prompt names STATE.md and this checklist.
8. New orchestrator: detach to top level, re-file running workers in the sidebar group, read PROJECT.md → STATE.md → DECISIONS (last rows) → Questions tab.
