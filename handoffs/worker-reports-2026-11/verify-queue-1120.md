# verify-queue-1120: night queue 2026-11-20/21 (verifier verify-queue-1120)
All pushed with godot-verify-push (clean worktree of the exact SHA, import, every suite headless with empty APPDATA, web build, FF check, push of that SHA only). Godot 4.6.1 console. No code edited. No Supabase SQL run by me.

| SHA | job | suites | web | push (from -> to) | deploy run | live hash | live version |
|---|---|---|---|---|---|---|---|
| b74364f | merch shop | 37/37 | ok | a62c836 -> b74364f | 44767664754 ok | bc-cb824a3c | n/a |
| 65801ea | checkin hotfix | 37/37 (import crash 1x, retry ok) | ok | b74364f -> 65801ea | 44771144046 ok | bc-e2b08414 | n/a |
| 291a00f | checkin hotfix 2 | 37/37 (import crash 1x, retry ok) | ok | d98628e -> 291a00f | 44776543496 ok | bc-2096233d | 0.4.1 in .pck |
| 90e3da2 | minigame ramp | run1 36/37 (test_avatar), re-run 37/37 | ok | 291a00f -> 90e3da2 | 44782182543 ok | bc-ba723286 | 0.4.2 |
| 3e17417 | presence hotfix 3 | 37/37 (import crash 1x exit 3221226356, retry ok) | ok | 90e3da2 -> 3e17417 | 44785637711 ok | bc-5134184b | 0.4.3 |
| 0b5fa04 | still-here 0.4.4 | 37/37 | ok | 3e17417 -> 0b5fa04 (held until "push 0.4.4") | 44788105249 ok | bc-4ddc20f0 | 0.4.4 |
| 08236bd | perf-iphone | 38/38 | ok | 0b5fa04 -> 08236bd | 44793193753 ok | bc-29d71ecf | 0.4.5 |
| 8b86f99 | presence hotfix 4 | 38/38 | ok | 08236bd -> 8b86f99 | 44795794571 ok | bc-57f2a887 | 0.4.6 |

Live version = the string in the live .pck (curl); never seen rendered in-game.

## Notes
- test_avatar is flaky: failed in the 90e3da2 run 1, and solo on main 291a00f too; solo on 90e3da2 it failed twice and passed once. Passed in every other run. Needs an owner.
- perf_telemetry.gd "Parse error" in the import log (during 291a00f) is the end of a "Failed to compile depended scripts" cascade on the cold first import; file unchanged by that commit, so on main too; suites pass.
- Import crashes 3221225477 / 3221226356 on a first attempt happen; one retry passed each time. Other Godot processes (not mine) sometimes ran during checks; left alone.
- Migrations seen in diffs, NOT run by me: 20261120000002_player_profile_merch.sql + seed/merch_items.sql (b74364f), 20261121000002_still_here.sql (0b5fa04), 20261121000003_restore_brings_tonight.sql (8b86f99).
- Not verified anywhere: real device/phone, feel, live Supabase flows, the --live test.
- Logs: scratchpad verify-<sha>[-r2] folders of this session.
