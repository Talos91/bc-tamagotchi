# Handoff: 🎸 Black Cabin orchestrator local_96f4e96d → successor (2026-11-20)

**Successor runs on Sonnet 5.5, effort medium (Sonnet trial, Daniele 11-18 via the Master).** Title starts with 🎸.

Reading order:
1. `load_agent("orchestrator", "black-cabin", "new orchestrator after handover from local_96f4e96d")`; `get_session self` (detach if nested); every connector off unless a running worker needs it.
2. Stint recap: vault `raw/agent-notes/2026-11-20-black-cabin-orchestrator-stint-session-local-96f4e96d-2026-1.md` (get_page).
3. `PROJECT.md` (whole), `STATE.md` (whole), `tail -15 LOG.md`; `changes_since("2026-11-20")`, `agent_log(project="black-cabin", days=3)`.
4. SendMessage 🔍 verify-040 (local_8702f6fa-9d41-414a-b862-7923e210ebe5) your session id: it is re-verifying v0.4.0 at 773025e and reports done/blocked to you.
5. Ask local_96f4e96d once what is not in the files; then the ≤ 10-line check-in to the 👑 Master (local_9a0f2f8a-6c3d-491b-b07b-225080f02f59), including the TREE block.
6. On verify-040 done: confirm `git ls-remote origin main` = 773025e, give Daniele the redeploy command, archive verify-040, `git pull --rebase` and push docs.

State at writing: origin/main 54b1e94; local main 773025e = v0.4.0 candidate + docs above it. Never push past unverified code. Daniele archives local_96f4e96d after its one answer.
