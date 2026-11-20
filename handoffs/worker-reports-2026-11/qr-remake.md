# Worker report — 🌐 qr-remake-1120 (2026-11-20)

- Branch wk/qr-remake, tip = the commit adding this file (on origin/main 9502c68). Not pushed.
- Suites, headless, empty APPDATA per suite: all 33 PASS on 5b12e0b's content over a046df5 (31 + test_overflow_seats
  + new test_qr_codes); after rebasing over play-telemetry: test_qr_codes, test_overflow_seats, test_presence_net,
  test_presence_client, test_play_telemetry, smoke_start, smoke_tap, test_seats PASS (9502c68 adds docs only).
- Counts: codes.json 39 codes / 31 tables = table-map.svg 39 = qr-sheet.pdf 39 cards (2 pages + map) = seed SQL 39
  rows (+ retire all others) = presence_mock.TABLES 31 tables (fake_presence 12, subset). test_qr_codes: 614 checks.
  Buffer 6, Main room tables 19, Raised 5, Bar stools 9. No Lounge, no Smoking. 0 of the 20 old tokens reused.
- Choice: one code per table (its chairs/stools share it); one code per bar stool (all -> table Bar).
- Live: tokens resolve server-side; live build 4e9dbc8 already has seats for all 31 tables. Codes switch on when
  supabase/seed/venue_tables.sql runs (old codes off at the same moment) — NOT applied (needs Daniele: SQL editor or
  connector OK). Hub card qr-remake-review.
- Not verified: a real phone scan (needs the SQL applied).
