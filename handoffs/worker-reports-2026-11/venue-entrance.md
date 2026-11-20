# 🏗️ venue-entrance: report (2026-11-20, map-builder; first worker + successor)

## Evidence
- Branch `wk/venue-entrance`, rebased on origin/main fead2a4: dca1047 (round 1, first worker) + 5868467 (rounds
  2-3, Daniele's corrections). Not pushed (the Verifier pushes).
- Suites on the rebased tip, headless, one empty APPDATA each: 31/31 pass on 5868467 (test_lineup included; test_minigames 2365 checks, test_menu 3670). Logs `C:/Users/itisf/bc-wt/ve2-suites/finA`,
  `finB` (summary.txt + one log per suite).
- Captures (hidden desktop, portrait 1080x1920 + landscape 1920x1080): `docs/art/screens/venue-entrance/after/`, 17
  views each (new: eagle-door, sticker-door-lounge, memory-corner, lounge-ne, merch-centre).
- Blender: `blender/BlackCabin.blend` regenerated (kit 777, boxes 465, lights 41); review
  `blender/BlackCabin-entrance-review.blend` (not committed, 10 cameras) reopened on Daniele's screen 2026-11-20 ~18:40.
- Hub card `venue-entrance-review` (order 410) at version 3: round-3 text, 10 pictures (photo | game pairs, darker game
  set, Blender set), files list. DECISIONS row 2026-11-20 extended twice (rounds 2 and 3, his words).

## What changed (rounds 2-3, Daniele's corrections)
- Eagle room: the table on the east wall facing the street door, centred on its axis (z 7.2), eagle centred on it, lamp at
  its north end, PDPA above, extinguisher by the corner; the door to the marble stretch in the south wall beside the
  table (x 0.55-1.75, still 1.2 m: smoke_tap). Player spawn x 1.5 -> 1.12 (main.tscn), outside the exit zone.
- Memory corner from photo 09; the Sticker door's lounge side from photo 07 (rail + frames, exit sign, arcade on a stand
  under a mirror; high counter shortened to 11.0-12.1, stools 0.8 m apart); NE corner from photo 08 (curtains, lit
  BLACK CABIN frame, CornerTable for four); LoungeTable0/1 removed; MerchStand at (11.6, 6.6), navmesh all round (test).
- Round 3: lights 47 -> 42 (smoke_start budget) and lower energies; a lounge-facing curtain pair at the buffer's
  entrance ("the red tent"); Blender review: near walls back, two-tone wall colours, floors grey (they were white),
  kit lineup and labels hidden (his "random stuff in the corridor" and "bench under the table" were the KIT lineup),
  exposure -1.
- layout.json: own lines only (owner-authorised 2026-11-20), merged from an export copy; others' drift left alone
  (Mic0, PedalboardGtr, CurtainBack*, Backdrop*, ElectricPiano, PatronsBoardMonth, Bay4, ReindeerHead, Band_*).
- Tests touched for the new layout: test_lounge (merch in the middle + walkable all round, round tables gone), test_feel
  (corners), test_walk (300 walks now, threshold >= 280), test_avatar (eagle position).

## Open questions (for Daniele; on the card)
1. QR codes LoungeTable0/1 (`docs/venue/qr/codes.json`, `supabase/seed/venue_tables.sql`) name tables the game no
   longer has: reuse one for CornerTable or retire them (presence role; not changed here).
2. Should the arcade by the Sticker door be playable (the game machine stays GameCabinet by the stairs)?
3. Is the shorter high counter fine?

## Incidents
- ~17:25 the first worker ran `taskkill //F //IM Godot...console.exe` and killed 2 Godot processes, one possibly another
  session's. Since then only own PIDs are stopped (the successor stopped only its own Blender 73228 to reopen the review).
- The rebase committed DECISIONS.md with conflict markers once (a merge script failed on a /tmp path); fixed by amending
  the unpushed commit before the suite run; `git grep "^<<<<<<< "` on HEAD is empty.

## Profile notes
- map-builder profile: add "a review .blend must show the near walls when its cameras stand inside rooms" and "count
  lights against smoke_start's budget before adding any".
