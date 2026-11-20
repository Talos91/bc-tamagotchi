# Verify 2ce7624 (tonight lineup + calendar + on-stage chip) — PASS, pushed

- SHA: 2ce7624d81934b066442bbb64162a83645d51907 (origin/main was 62c31af, fast-forward, no docs-only drift)
- VERIFY 2ce7624: PASS 31/31 suites (incl. new test_lineup 4.5s, test_tonight, test_string_keys); empty APPDATA per suite; headless; local exe C:/Users/itisf/godot-local/Godot_v4.6.1-stable_win64_console.exe
- Web build: exit 0, 59.8 MB
- Push: PUSHED 62c31af..2ce7624; ls-remote main = 2ce7624d81934b066442bbb64162a83645d51907 (match)
- Actions: `gh run list --limit 1` -> Web deploy, in_progress at 10:42Z (run 44721480487); final status not rechecked
- Suite folder vs PROJECT.md: 31 on disk = 31 listed, no mismatch
- Incident: first import run crashed (exit 3221225477 at strings_venue.csv reimport, local exe, while another Godot was running). Rerun once, import exit 0. Likely concurrency/flaky CSV import; not a code fault. Logs in scratchpad verify-2ce7624 / verify-2ce7624b.
- Done-when: judged from suites + diff stat only (I did not have the brief text): lineup logic/calendar data/chip covered by test_lineup pass.
- Not verified: real device, visual feel of cards/calendar/chip, final Actions result.
