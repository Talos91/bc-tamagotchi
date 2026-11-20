# 🖼️ creator-fix — worker report (2026-11-20)

Branch `wk/creator-fix` (worktree `C:/Users/itisf/bc-wt/creator-fix`), rebased on origin/main 9502c68, not pushed.
Two sessions (ui profile, Opus 5.5): load ids 2026-11-20-ui-black-cabin-b3ce6e (first) and
2026-11-20-ui-black-cabin-807c4f (successor). Hub card `creator-fix-1120-review` (8 before/after sheets).

## Evidence
- Suites, empty APPDATA, headless, on the rebased tip: **35/35 pass** (the 33 listed in PROJECT.md + new
  `test_mg_return` and `test_touch_scroll`). smoke_loop failed (7) on the first full run and was fixed (item 7 below);
  re-run alone with test_mg_return and test_venue_pause after the fix: pass.
- Captures (hidden desktop, portrait 540x960 + landscape 960x540, before = temporary worktree of 649a06a):
  `docs/art/screens/creator-fix/{mg-return,scroll,venue-items,creator,checkin,hair,alcove}/`, sheets in `sheets/`.
- Creator ms per tap, `tools/creator_taps.gd`, desktop window, median of 11-12 taps (call / until the frame is drawn):
  hair 322 / 368 -> 2.5 / 16.5; outfit 50 / 56 -> 8.4 / 16.4; body 19 / 22 -> 2.3 / 16.5 (16.5 = one frame at 60 Hz).

## Owner items (Daniele 2026-11-20)
| # | Status | Fix | Check |
|---|---|---|---|
| 1 creator unresponsive | FIXED | restyle in place, tab rebuilt only when its rows change; preview keeps the body's parts library (`PatronFigure.show_avatar`, cached materials); hair thumbnails cached, one offscreen viewport, one per frame | numbers above; test_avatar "a colour tap restyles in place" |
| 2 hair bald spots | FIXED (first session) | bc_chars.py curly / buzz | test_avatar "hair cover" |
| 3 clothing variety | FIXED | per-piece Outfit tab: Top 14, Top colour 18, Pattern colour, Bottom 6 + colour, Shoes 3, Hat None+5, Glasses None+2; record v2; 38 strings (TH machine drafts) | test_avatar +22 checks; sheet item3-outfits |
| 4 check-in selector | FIXED (first session) | presence_client set_mode -> autoload | test_presence_client "real checkin"; captures checkin/ |
| 5 alcove end wall | FIXED (first session) | StubEnd / StubEndBack | captures alcove/ |
| 6 no touch scrolling | FIXED | autoload `TouchScroll` (`scripts/ui/touch_scroll.gd`): Godot 4.6 drag-scrolls only from emulated mouse reaching the ScrollContainer, and our rows/cards are MOUSE_FILTER_STOP; now any ScrollContainer under a finger scrolls from ScreenDrag, flings, and a drag never presses what it started on | test_touch_scroll (12 fails without it) |
| 7 invisible after games | FIXED | the cover disabled the Venue (colliders leave physics) while the player kept gravity: ~20 m fall per game. The player's physics step now pauses with the venue | test_mg_return, all 8 games (before: y -20 ... -722) |
| 8 two arcades | FIXED | ArcadeOnStand removed; layout.json: that entry only; DECISIONS row | test_lounge |
| 9 memory screen | FIXED | CRT 120 -> 60 deg, faces its stools | test_lounge |
| 10 street door top | FIXED | opening lintel at the door kit's 2.15 m (was 2.3) | test_lounge |
| + Daniele direct: "remove the table here and put the game cabinet there" | DONE | HighCounter + 2 stools + seats removed, GameCabinet x 10.3 -> 11.55, wall records to 2.0 m, counter camera spot merged; layout.json own lines; DECISIONS row; 4 suites updated | test_lounge, test_feel, smoke_doors_sit, smoke_tap, test_seats |

## Open / flags
- layout.json still records the CRT at 120° (item 9 turned it in build_venue.gd only, the brief allowed one layout entry).
  An export also shows older drift not mine (stage curtains/backdrops, Mic0, PedalboardGtr, ReindeerHead,
  PatronsBoardMonth, ElectricPiano, Band_Guitar/Keys spawns): a map-builder export pass should settle it.
- Not verified on a real phone or the web build: touch scrolling and creator speed are desktop + simulated-touch only.
- Shared files touched: main.gd (_cover_venue), project.godot (one autoload line, merged next to PlayTelemetry),
  venue_patron_figure.gd (show_avatar + _slot_mat), test_lounge/test_feel/smoke_doors_sit/smoke_tap (cabinet move).
- Gotcha: suites run while windowed captures run can fail test_lounge walk timeouts; run alone.
- `game/tests/_scratch/` holds probes, never committed. Temporary worktree creator-fix-before removed.
