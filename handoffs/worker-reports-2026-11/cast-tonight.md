# Report: cast-tonight (🎭, Sonnet)
EVIDENCE
- Commit 66ae12d (local main, not pushed): cast.gd (`night_at`), test_nightlife.gd (`test_cast_tonight`), tests/capture_cast_tonight.gd, docs/art/screens/cast-tonight/.
- Finding: night n is the Bangkok calendar night (floor((unix+1h)/86400), turning 06:00 Bangkok), global for every save and phone clock/time zone; never a visit count. Tue 2026-11-03 19:00 to Wed 06:00 = night 20760 (even). Prae is IN (parity rule), at WestTable0 (n/2 %3 = 0). Ty is in every night (Long Table, no absence rule). Fresh save and visited save alike. No override needed, none added. Prae will be out tomorrow (20761).
- Suites (headless, empty APPDATA): test_nightlife 113/0 (new section "[cast]" with 0/1/3 visits, odd night after), test_needs 228/0, smoke_loop PASS, smoke_start PASS, test_seats PASS.
- Capture 450x800: 1-ty-phone.png (Ty with tag), 2-prae-phone.png (Prae at the table, no tag visible in frame).
- Hub card: cast-tonight-review (Questions tab, 2 pictures + files).
OPEN
- No redeploy needed for tonight: the refactor changes no behaviour; the live build already puts both in tonight by the same rule.
- The commit used CRLF warnings only. Unrelated untracked files left alone.
