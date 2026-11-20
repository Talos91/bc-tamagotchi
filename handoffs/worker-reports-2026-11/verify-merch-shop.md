# verify-merch-shop (verify-queue-1120)
- SHA b74364f (wk/merch-shop) on origin/main a62c836: fast-forward yes
- VERIFY b74364f: PASS 37/37 suites (empty APPDATA per suite), import exit 0, web build exit 0 (61.4 MB)
- Pushed a62c836..b74364f (6 commits); ls-remote main = b74364ff... match
- Deploy run 44767664754: success (2m3s). blackcabin.app serves build hash bc-cb824a3c (was 356c6c7b before). My local build hash was c3492b57; the hash differs per build, so it is not comparable.
- Migrations in the commit (already applied live by the worker, NOT run by me): supabase/migrations/20261120000002_player_profile_merch.sql, supabase/seed/merch_items.sql
- Not verified: real device, feel, the Supabase live state, merch flow against the live server.
- Logs: scratchpad verify-b74364f
