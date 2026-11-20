# verify-d9384d0-qr (verifier)
- VERIFY d9384d0: PASS 34/34 suites (33 expected + test_qr_codes counted; no unlisted failures), import exit 0, empty APPDATA per suite, clean worktree, Godot 4.6.1 console. Logs: scratchpad verify2-d9384d0 (session scratchpad).
- First attempt: IMPORT FAILED exit 3221225477 (other workers' Godots running at the same time); rerun once with own TEMP -> passed.
- Consistency: codes.json = SQL insert rows (code, table_id, label, zone all equal) = SQL deactivate list = 39; 31 distinct table_ids; table-map.svg numbers 1-39 and key list match codes.json. (SVG shows numbers/keys, not tokens.)
- Pushed: 9502c68..d9384d0 (script, fast-forward), then 296783a (orchestrator ask; diff d9384d0..296783a = handoffs/qr-remake-2026-11-20.md only) 9502c68..296783a. ls-remote main = 296783ae14bd.
- Deploy: Web deploy run 44757195082 (d9384d0) success, 2m0s; 296783a is docs-only, no deploy by path filter. blackcabin.app serves bc-05a828f5.pck, HTTP 200.
- Not verified: real phone scan of printed codes; the served build's content beyond HTTP 200 (hash not mapped to commit); Supabase seed NOT run (Daniele's step).
