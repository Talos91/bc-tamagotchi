# housekeeping-loader (Sonnet, 2026-11-09) - PROJECT.md aligned with the vault loader and method section 4

## EVIDENCE
- Commit d41522d (local, not pushed): PROJECT.md, handoffs/ORCHESTRATOR-HANDOVER.md. Role note + this report in the follow-up commit.
- Load ids: housekeeping 2026-11-09-housekeeping-black-cabin-e6e253; loader checks verifier 2026-11-09-verifier-black-cabin-28ea71 and voxel-art 2026-11-09-voxel-art-black-cabin-4e1a8e: both returned section 3 with the renamed project entry.
- (b) `grep "^### " PROJECT.md`: Orchestrator, Verifier, Housekeeping, Researcher, Voxel art, UI, Rules / Powers; no non-ASCII symbol in any heading (python check: empty list).
- (c) `grep -niE "detach|archive yourself|archives itself|archiving itself"` over both files: 0 hits.
- Vault capture "Black Cabin STATE pointer refresh 2026-11-09" written (id in the capture report).

## Changes
- Basics: line for `load_agent(<role>, "black-cabin", "<purpose>")` and the `capture(kind="report", ...)` close.
- Per-role notes: headings renamed; new Verifier, Researcher, UI, Rules / Powers; "Game design / gameplay" split; Orchestrator gets session-start steps (`changes_since`, `agent_log`), own handover at ~40 % or ~30 % near the limit, inherited worker finishes only its current task. Emoji kept only in the session-title rule.
- "Archive order" became "Exit ritual order": worker stays idle, never archives its own session; orchestrator archives. Handover bullet carries the section 4 self-handover line (successor nested, predecessor idle).
- Working rules / ORCHESTRATOR-HANDOVER.md: already a pointer plus deltas (11-02), confirmed; trimmed leftovers: "fourteen" -> "seventeen" suites, worker self-handover paragraph added, orchestrator start / first-turn bullets now defer to checklist steps 0, 1, 8 instead of saying "detach" (vault checklist step 8 still says detach for the orchestrator itself).
- Fixed BEL characters that had corrupted the `wikigents\` paths in both files.

## Not done / flags
- STATE.md says 15 suites verified 14/14 while PROJECT.md Tests lists seventeen; not mine to reconcile.
- PROJECT.md line 32 untouched. Nothing pushed.
