# 🖼️ creator-fix — role note (2026-11-20)

Worker chain under orchestrator local_5352afaa; **from 2026-11-20 evening the orchestrator is local_14422c6c-6819-4921-bfc9-af16d4185b7b: report there, not to local_5352afaa.** First session: Opus 5.5, ui profile, load id
2026-11-20-ui-black-cabin-b3ce6e (the successor loads its own and reports with both ids). Worktree
`C:/Users/itisf/bc-wt/creator-fix` on `wk/creator-fix`, based on origin/main 649a06a. Never push.

Owner list (Daniele 2026-11-20, verbatim): "character creation is superunresponsve, hairs often clips the head and looks
like bald spots, also too little variety expecially in clothing, the who can reach out tonight selector doesn t work
and the only way is to click skip, the unused corridor (the blocked one) in the lounge has the end wall invisible and
you can see trough both ways".

## STATE NOW (successor, 2026-11-20 evening): ALL ITEMS 1-10 FIXED, plus Daniele's cabinet move
Successor session (Opus 5.5, ui, load id 2026-11-20-ui-black-cabin-807c4f). Branch rebased on origin/main 9502c68.
Hub card `creator-fix-1120-review` (8 before/after sheets, files list). Report `handoffs/worker-reports-2026-11/creator-fix.md`.
- **Item 7** (invisible player after any minigame): `main._cover_venue` disabled the Venue, which takes its colliders
  out of physics, while the player kept running gravity: it fell ~20 m per game. Now the player pauses with the venue.
  Suite `test_mg_return` (all 8 games, real leave path; before: y -20 -> -722 m, after: 0.000 m).
- **Item 6** (no touch scrolling): Godot 4.6 drag-scrolls only from emulated mouse that reaches the ScrollContainer, and
  all our rows/cards/buttons are MOUSE_FILTER_STOP. New autoload `TouchScroll` (`scripts/ui/touch_scroll.gd`) scrolls
  the topmost ScrollContainer under a finger from ScreenDrag, flings, keeps a drag from pressing what it started on.
  Suite `test_touch_scroll` (Tonight, calendar, menu, creator; 12 fails without the autoload).
- **Items 8-10** (build_venue.gd): ArcadeOnStand removed (layout.json: that entry only; DECISIONS row); memory CRT
  120 -> 60 deg (layout.json still says 120: flagged in the report); street door lintel at the kit's 2.15 m.
  test_lounge checks all three.
- **Daniele, direct, mid-session** ("since you are at it remove the table here and put the game cabinet there", picture of
  the high counter under the wall records): HighCounter + CounterStool0/1 + seats removed, GameCabinet x 10.3 -> 11.55,
  records raised to 2.0 m, counter camera spot folded into the cabinet's. layout.json own lines; DECISIONS row;
  test_lounge/test_feel/smoke_doors_sit/smoke_tap updated. No QR code pointed at HighCounter.
- **Items 1, 3**: creator restyles in place, rebuilds a tab only when its rows change; preview keeps the body's parts
  library (`PatronFigure.show_avatar`, cached materials); hair thumbnails cached, one offscreen viewport. Per-piece
  Outfit tab (Top, Top colour, Pattern colour, Bottom + colour, Shoes, Hat, Glasses), 38 strings (TH drafts).
  `tools/creator_taps.gd` medians (call / until drawn, desktop): hair 322/368 -> 2.5/16.5 ms, outfit 50/56 -> 8.4/16.4,
  body 19/22 -> 2.3/16.5. test_avatar +22 checks.
- **Item 4** captures done (`docs/art/screens/creator-fix/checkin/`): before, Check in drops back to the consent card.
- Gotcha: a suite run that overlaps windowed captures can fail test_lounge on walk timeouts (CPU load); rerun alone.
- Not verified: real phone (touch scroll and creator speed on a phone browser), web build.

## Earlier state (first session, tip eb1b8c0)
- **Item 4 FIXED (4ec4666).** Cause: `PresenceClient.set_mode` wrote only `needs.profile` while `mode()` read the real
  autoload, so the live check-in went out with no mode → server `need_mode` → consent card again; only "Not now" got
  past. Fix in `presence_client.gd` (set_mode hands it to the autoload, mode() falls back to the profile),
  `checkin_flow.gd` (no loop after a choice; Check in runs deferred, it freed its own button mid-press).
  Check: `test_presence_client` section "real checkin (item 4)", real touches against the autoload in mock mode; with
  the old client it fails `need_mode` (verified). Suite PASS.
- **Item 5 FIXED (4ec4666).** The alcove (STUB, "Old Corridor") ended at the main room's west wall, which sinks when it
  faces the camera (lounge curtains view, main floor view). `build_venue.gd` adds StubEnd / StubEndBack (lounge two-tone
  / main black), cut_sight_only + cut_rooms of the main-room zones. venue.tscn regenerated (only those two nodes new;
  the rest is unique_id churn as usual). layout.json untouched. Evidence: `docs/art/screens/creator-fix/alcove/`
  (before-/after- portrait + landscape; `look-from-lounge` and `look-from-main` show it best), capture
  `game/tests/capture_alcove.gd`.
- **Item 2 FIXED (eb1b8c0).** Only `curly` (random tufts over the scalp) and `buzz` (floating plate, bare back/sides)
  were bare. `bc_chars.py` fixed, libraries + 4 presets (big, patron_09/15/16) regenerated, deterministic otherwise.
  Check: `test_avatar` "hair cover" (ray casts on the meshes, 128 body×head×hair; failed before, passes now).
  Sheets: `docs/art/screens/creator-fix/hair/{before,after}-hair-<body>-<front|back|top>[-diag].png`
  (`capture_hair_grid.gd`; -diag = skin magenta, hair green).
- **Item 3 PART 1 (eb1b8c0).** Kit: tops tee_stripe, shirt_check, shirt_aloha (pattern slot `top_print`), tank; bottoms
  skirt_long, jeans_ripped; hat_cap; swatches Fuchsia, Lilac, Cobalt, Coral, Mint; `hair_<style>_hat` (hair cut at
  the brim) for every hair. `avatar.json`: tops (14), printed_tops, bottoms (6), shoes, top_colours (18),
  print_colours, bottom_colours, hats (5), glasses (2), top_info / shoe_info trims, worn_items. `avatar.gd` record
  **v2**: top, bottom, shoes, top_colour, print_colour, bottom_colour, worn {hat, glasses}; keeps `look` (=
  look_for(top)) so pre-v2 clients draw the nearest look; v1 records migrate in normalize() and draw exactly as before
  (legacy test passes). resolve() picks `hair_<id>_hat` when a hat is worn. test_avatar PASS.
- The creator still shows the OLD Outfit tab (look chips + top colour); `_pick("look")` was patched to reset the pieces.

## Item 6 (added by the orchestrator 2026-11-20, Daniele: "also can't scroll the tonight session")
The Tonight panel (lineup cards / monthly calendar, from 2ce7624) does not scroll on his phone. Suspects: the
ScrollContainer gets no touch drag (cards with mouse_filter STOP swallow it; ScrollContainer only drag-scrolls from
emulated mouse when its children PASS/IGNORE), or a touch-anywhere / joystick / presence_taps layer eats the drag.
Fix it, add a check with real touch drags (InputEventScreenTouch + ScreenDrag through Input, mapped through
`root.get_final_transform()`), before/after captures on the same hub card, same exit ritual. Not investigated yet.

Orchestrator follow-up: Daniele, "on my phone i cannot scroll". Treat item 6 as touch scrolling broken in EVERY
scrollable panel on a real phone (Tonight, calendar, menus, lists). Look for one global cause: the
`pointing/emulate_mouse_from_touch` / `emulate_touch_from_mouse` settings, a full-screen input layer (the touch-anywhere
stick, `touch_joystick.gd`, presence_taps) consuming InputEventScreenDrag, the ScrollContainer `scroll_deadzone`, or the
web canvas's CSS `touch-action`. Fix it once, globally; test with simulated ScreenDrag events in a suite.

## Items 7-10 (orchestrator, Daniele 2026-11-20). DO ITEM 7 FIRST: it is the worst bug live
7. "after playing a match of clap game my character became invisible when i went back to the bar", then "the
   character becoming invisible happens with all games". The bug is in the shared minigame open/close path (venue
   pause/resume Q2 `test_venue_pause`, the mg frame, the camera/cutaway restore, player visibility), not in one game.
   Add a check: the player is visible after each of the 8 minigames returns.
8. "there's 2 arcade machines, keep only the big one". Remove the smaller arcade machine through `build_venue.gd`
   (the lounge has `ArcadeCabinet`/`Pinball` and `GameCabinet`, plus the `ArcadeOnStand` near the Sticker door: check
   which ones he means from a capture). layout.json may lose that one entry only. Add a DECISIONS.md row quoting him.
9. "the screen for share a memory is facing the wall instead of the player". Turn the memory-corner screen
   (`_memory_corner` in build_venue.gd) so it faces the room.
10. "entrance door doesn't fit the full door frame and has the top open". Make the street door fill its frame (the
   door height and frame fit in build_venue.gd; the kit piece in `tools/blender/bc_kit.py` only if needed).
Regenerate the venue once for 8-10. Every item gets before/after captures on card `creator-fix-1120-review`; same
exit ritual. Suggested order: 7, 6, 8-10 (one venue regeneration), then items 1 and 3 (creator UI).

## Next steps the first session left (all done by the successor, see STATE NOW)
1. **Before captures of the creator (items 1, 3) and the check-in card (item 4)** from the OLD code: `git worktree add
   C:/Users/itisf/bc-wt/creator-fix-before 649a06a` (import it), run the existing `capture_char_creator_fix.gd` and a
   check-in-card shot there (portrait 540x960 + landscape 960x540, hidden desktop). Remove that worktree after.
2. **Item 3 UI**: Outfit tab rows Top (chips), Top colour, Pattern colour (printed tops only), Bottom (hidden for the
   dress), Bottom colour, Shoes, Hat (None + 5), Glasses (None + 2). `_pick`: top dress ⇒ bottom dress, leaving the
   dress ⇒ skirt; `record.look = Avatar.look_for(top)`; hat/glasses go in `record.worn[slot]` (None erases). Strings
   `ui.avatar.row.{top,print,bottom,bottom_colour,shoes,hat,glasses}`, `ui.avatar.none`, item names
   `ui.avatar.{top,bottom,shoes,hat,glasses}.<id>` in `game/i18n/strings_ui.csv` (TH machine drafts; test_string_keys).
   Update test_avatar `_data` counts (it still checks 3 looks with 6 colours each; keep those for the hidden-look
   compat) and add: v1 record → v2 draws the same ids/colours; Surprise me sets hats sometimes; a hat swaps the hair id.
3. **Item 1 responsiveness** (`character_creator.gd`): today every tap does `set_look` (instantiate the whole parts
   library ~120 meshes, free the rest) AND `_show_tab()` (rebuild the tab; on the Hair tab 8 SubViewports each
   instantiating the library again = 9 library builds per tap). Plan: (a) restyle the tapped row in place, rebuild the
   tab only when its rows change; (b) preview figure keeps the full library for its body and toggles visibility +
   `Chars.recolour` (add a keep-all/`show_avatar(rec)` path to `venue_patron_figure.gd`, rebuild only on body change);
   (c) hair cards: render thumbnails once per (body, head, skin, hair colour, face) into cached ImageTextures with one
   offscreen viewport, one per frame; colour change re-renders, never re-instantiates. Measure before/after (ms per tap
   on the web build, or Time.get_ticks_usec around _pick on desktop) and put the numbers in the report.
4. After captures (creator portrait/landscape per tab + outfit variety sheet; check-in card), all 31 suites with empty
   APPDATA, hub card `creator-fix-1120-review` (pictures + files list; schema in `handoffs/orchestrator-2026-11-02.md`
   lines 12-17), LOG.md line, report `handoffs/worker-reports-2026-11/creator-fix.md`, `git rebase origin/main`,
   capture(kind=report, replies_to both load ids), final message to the orchestrator.

## Gotchas
- Godot `C:/Users/itisf/godot-local/Godot_v4.6.1-stable_win64_console.exe`; first import segfaulted (139), the retry
  worked. APPDATA for my runs: `C:/Users/itisf/bc-wt/cf-appdata` (imports), `cf-ad-t` (tests).
- Windowed runs: `C:/Users/itisf/bc-wt/cf-tools/shot.ps1 -Script <capture>.gd -Res 540x960 -Extra "<args>"` (hidden
  desktop via `C:/Users/itisf/ooze-wt/quota-drill-tools/hd.ps1`).
- Blender: `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python
  tools/blender/bc_chars.py -- --no-review` from the worktree (~3 min), then re-import.
- Headless tests: touches must be mapped through `root.get_final_transform()` when a test does not set root.size
  (test_presence_client `_touch`).
- `game/tests/_scratch/` holds my probes (probe_alcove, probe_curtains, mesh_probe, hair_only): never commit.
- Shared files touched: `test_presence_client.gd` (one call + two functions at the end of `_real`), `build_venue.gd`
  (alcove block only), `venue.tscn`. The overflow-seats worker works in presence + venue_patrons: expect a rebase merge
  there; perf-iphone in perf/graphics + HUD.
- QR FREEZE: never touch docs/venue/qr/ or table codes.

## ORCHESTRATOR ADDENDUM (2026-11-20): items 6–10, sent by message, NOT in the notes above. Do them too.
- **Item 7 — PRIORITY 1, worst live bug.** Daniele: "after playing a match of clap game my character became invisible when i went back to the bar" + "the character becoming invisible happens with all games". The cause is in the shared minigame open/close path (venue pause/resume Q2, mg frame, camera/cut restore). Fix it, plus a check over all 8 games that the player is visible after returning.
- **Item 6.** "on my phone i cannot scroll" (Tonight panel and every scrollable panel): look for one global cause (touch-anywhere layer eating ScreenDrag, emulate_mouse_from_touch, ScrollContainer deadzone, canvas CSS touch-action). Fix it once, with a check using simulated ScreenDrag.
- **Item 8.** "there's 2 arcade machines, keep only the big one". Remove the small one via the venue generator; only that one layout.json entry may go; DECISIONS row.
- **Item 9.** "the screen for share a memory is facing the wall instead of the player". Turn it to face the room.
- **Item 10.** "entrance door doesn't fit the full door frame and has the top open". Fix the door height/frame fit.
Before/after captures for each go on card creator-fix-1120-review. QR freeze: don't touch docs/venue/qr/.
