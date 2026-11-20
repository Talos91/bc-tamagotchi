# Verify overflow seating: BLOCKED at import (2026-11-20)
- f4abb26 requested; origin/main had moved to 72f669d (STATE.md only). Cherry-picked a12b3c1 + f4abb26 onto it clean: 0cfb7c7 + 8d51b2b (verified SHA would be 8d51b2b). Fast-forward: yes. Not pushed.
- QR/layout freeze: `git diff 082979b 8d51b2b -- docs/venue/qr game/assets/kit/layout.json` empty (pass).
- Suites on tip: 32 (31 + test_overflow_seats) present.
- Import FAILED twice in a clean worktree: exit 3221225477, retry exit 3221225501; log tail: "FATAL: Index p_index = -1 out of bounds (size() = 26)" at strings_venue.csv reimport (cowdata.h:193). No suite ran: 0/0.
- Logs: scratchpad verify-8d51b2b and verify-8d51b2b-r2 (_import.log).
- Not verified: everything past import. No push, no deploy.
- Suspect: Godot crash on CSV translation import (strings_venue.csv), maybe a worker-concurrent run or a fresh-worktree import problem; may also be an existing main problem. Not tested on 72f669d alone.
