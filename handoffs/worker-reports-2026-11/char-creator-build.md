# Worker report — 🎨 character creator, phase 2 build (2026-11-09)

Session local_ea874820 (Opus) · load id 2026-11-09-voxel-art-black-cabin-bca013 (vault was down at start; same id) · not pushed

## Evidence
- Commits: **64280d1** (build + captures) and the follow-up commit with this report (web glyph fix, web screenshots,
  role note, LOG line). Build verified on 64280d1 + the glyph fix; the Verifier reruns in a clean worktree.
- Suites from `game/`, each with an empty APPDATA (my run, shared tree; not the verify):

| Suite | Result | Suite | Result |
|---|---|---|---|
| smoke_stairs | PASS | test_nightlife | PASS |
| smoke_tap | PASS | test_seats | PASS |
| smoke_hud | PASS | test_feel | PASS |
| test_needs | PASS | test_lounge | PASS |
| test_minigames | PASS | test_touch | PASS |
| smoke_loop | PASS | test_string_keys | PASS |
| smoke_doors_sit | PASS | test_walk | PASS |
| smoke_start | PASS (after the fix below; 19 fails before) | test_avatar (NEW, 18th) | PASS (re-run after the glyph fix: PASS) |
| test_menu | PASS | smoke_version | PASS |

- **smoke_start changed** (2 lines): its fresh characters now get a look first, because a new character's first tap
  opens the creator (by design). PROJECT.md Tests needs `test_avatar` added (orchestrator).
- Captures: `docs/art/screens/char-creator/build/` — `portrait-01..12-*.png` (1080×1920), `landscape-01..12-*.png`
  (1920×1080): 4 creator steps, name refused, walk-in, old-save card, Edit look, booth in the lounge, booth prompt,
  booth creator, booth close-up. Tool `game/tests/capture_char_creator.gd`.
- Web build: `python tools/build_web.py --out <scratch>` (no deploy), 54.2 MB (wasm 37.7, pck 16.0), served on
  127.0.0.1:8931, opened at 375×812 in the app's browser with a cleared save: start screen → tap → creator → Hair tab
  (thumbnails render). Localhost downloads finish 0.36 s after navigation (meaningless for a phone); the creator was up
  within the 3 s wait after the tap, Hair within 2 s; JS heap 31 MB. Screenshots `web-375x812-00/01/02-*.jpg`.
  Console: the service worker fails to register on the plain local server (not an error from the game); WebGL "zero size
  framebuffer" warnings while the pane was laid out. Glyphs ⟲ ⚄ showed as boxes in the web font: removed.
- Hub cards: **`char-creator-build-review`** (9 pictures, 4 files), **`char-creator-booth-spot`** (owner call: booth
  position and look).

## What was built (doc 07 §10, DECISIONS 2026-11-09)
- `game/scripts/avatar.gd` + `game/data/avatar.json`: record in `profile.avatar` (ids + swatch names), options per the
  answers, legacy look = old player (patron_06 + beard, colours checked by test), name filter, greeters.
- `needs.gd` avatar API (set_avatar calls `set_personality`, writes `display_name`); `save.gd` comment only; no VERSION bump.
- `PatronFigure` avatar form: one parts library (lazy, per body), pruned + recoloured before entering the tree.
- `scripts/ui/character_creator.gd` (portrait + landscape), EN/TH `ui.avatar.*`, `venue.prompt.booth`.
- Start screen: creator on a new character's first tap; one-time card; Edit look. Booth: zone `booth` → creator.
- Photo booth: `bc_kit.py` `photo_booth` (full deterministic run: only manifest + new glb changed), `build_venue.gd`
  `_photo_booth()` at (9.2, 0, 0.55), one hand-merged `layout.json` entry, venue.tscn regenerated (only PhotoBooth +
  collider added structurally; 42 lights unchanged). Navmesh: booth front on the mesh (test_avatar), test_walk /
  test_lounge / test_seats PASS.
- Greeter: `VenueSession._greet()` on arrival (Nam, Tt; Tong and Jules are not placed, so no line for them yet).

## Not done / not verified
- Real phone; first-open time on a phone network. Personality idles; wardrobe (§8). Hair thumbnails rebuild on every
  choice (8 small renders): fine on desktop and in the browser here, watch on weak phones.
- No rules.gd, PRE_ALPHA or version change.
