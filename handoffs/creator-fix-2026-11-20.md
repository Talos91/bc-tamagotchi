# 🖼️ creator-fix — role note (2026-11-20)

Worker chain under orchestrator local_5352afaa. First session: Opus 5.5, ui profile, load id
2026-11-20-ui-black-cabin-b3ce6e (the successor loads its own and reports with both ids). Worktree
`C:/Users/itisf/bc-wt/creator-fix` on `wk/creator-fix`, based on origin/main 649a06a. Never push.

Owner list (Daniele 2026-11-20, verbatim): "character creation is superunresponsve, hairs often clips the head and looks
like bald spots, also too little variety expecially in clothing, the who can reach out tonight selector doesn t work
and the only way is to click skip, the unused corridor (the blocked one) in the lounge has the end wall invisible and
you can see trough both ways".

## State now (tip eb1b8c0)
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

## Next steps (successor)
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
