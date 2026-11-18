# q2-venue-pause role note (2026-11-18)

State now: done in branch wk/q2-venue-pause. `main.gd` `_cover_venue()` (called by `_sync_block`) sets viewport `disable_3d` and Venue `process_mode` DISABLED while the minigame frame is open. Suite `test_venue_pause`. Numbers in `worker-reports-2026-11/q2-venue-pause.md`.
Next: Verifier pushes the SHA; Daniele may check feel on a phone (frame rate/battery).
Gotchas: video MB does not change (resources stay resident). Headless test: the player drifts in y (falls) so the suite compares xz only. Hidden-desktop probe: runs from `C:/Users/itisf/ooze-wt/quota-drill-tools/hd.ps1` (map-shots-tools no longer has it).
