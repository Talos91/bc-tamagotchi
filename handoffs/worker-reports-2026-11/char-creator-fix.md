# 🎨 Character creator fix (owner items 26-27), 2026-11-09

Session: successor of local_ea874820 (Opus), load id 2026-11-09-voxel-art-black-cabin-f23bdf.

## Evidence
- Commits (main, not pushed by me): 9cb6bc9 (26, part 1; verified + pushed by the orchestrator), 8368a40 (26, part 2),
  56aca5c (27). Role note + this report: the commit after 56aca5c.
- Cause of 26 (two): (1) Done / "Into the bar" refuses an empty or bad name, but at 375x812 the name field and the
  reason sat below the fold of the You tab: the tap looked dead; ‹ only stepped back a tab (up to 4 taps to leave).
  (2) The Web export preset has `html/experimental_virtual_keyboard=false` and the build has no input element, so on a
  phone the name field never got a keyboard: a new character could never type a name; × led back to the street,
  whose next tap reopens the creator. Reproduced on a local web build at 375x812 with synthetic TouchEvents.
- Fix: × top right in every mode leaves; reason above the button; name field first; on a touch web build the name
  field opens the browser's prompt (JavaScriptBridge). 27: kit hairs `long_straight`, `pigtails`, `double_bun`
  (bc_chars.py, full kit run, presets unchanged); hairs long_straight, crop, pigtails, quiff, bob, curly, double_bun,
  buzz; looks easy, dress (new), smart; night_out hidden for old saves. Q10 stands.

| Suite run | Result |
|---|---|
| Working tree with all three commits' content, empty APPDATA per suite, 19 suites | 19/19 PASS (smoke_start, test_string_keys, test_avatar re-run after the prompt change: PASS) |
| git-archive export of 9cb6bc9, fresh import: smoke_start, test_avatar, test_string_keys | 3/3 PASS |
| git-archive export of 8368a40, fresh import: same three | 3/3 PASS |

- Web 375x812 (local build, synthetic touch; window.prompt stubbed): reason shows above the button; × leaves; prompt
  asked once, field filled, "Into the bar" went on to the walk-in; the new hair row renders.
- Captures: `docs/art/screens/char-creator/fix/` portrait + landscape 01-08 (hair long/pigtails/buns, looks
  easy/dress/smart, name refused, walk-in), web-375x812-01..04. Review blend `blender/BlackCabinChars.blend`.
- Hub card: char-creator-fix-review (10 pictures + files).

## Not verified / notes
- No real phone. Open risk: whether iOS Safari shows window.prompt called from the game loop (not a touch handler).
  The alternative is enabling the experimental virtual keyboard in the export preset (owner/tech call).
- In the hidden browser pane, about one tap in four was lost (background tab, paused frames); headless 18/18 with
  press and release in one frame. Not seen as a game bug.
- The pre-alpha Debug button overlaps the bottom-left corner of the creator's main button (minor, not touched).
- `HairBlack` reads grey under the preview lights (palette, not touched). No LOG.md line (orchestrator's file).
- Profile gap: the voxel-art profile has no step for "check the view the player actually sees" (front-only creator).
