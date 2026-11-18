# Worker report: 🖼️ q1-juice (2026-11-18)

## Evidence
- Branch `wk/q1-juice` in `C:/Users/itisf/bc-wt/q1-juice`, rebased on origin/main 4313aed; code commit 4a01959,
  tip = the commit that adds this report (SHA in the final message to the orchestrator).
- Suites, headless, each with `APPDATA` pointed at an empty folder, Godot 4.6.1 console: **25/25 PASS**
  (smoke_doors_sit, smoke_hud, smoke_loop, smoke_stairs, smoke_start, smoke_tap, smoke_version, test_avatar,
  test_coaster_flip, test_debug_tools, test_feel, test_lounge, test_menu, test_mg_fx, test_minigames, test_needs,
  test_neon_moth, test_nightlife, test_seats, test_shake_serve, test_soi_dash, test_string_keys, test_tonight,
  test_touch, test_walk). After a last result-card fix: test_mg_fx, test_minigames, test_needs, test_shake_serve,
  test_string_keys, test_neon_moth re-run, all PASS. New suite `test_mg_fx`: 122 checks.
- Captures on a private hidden desktop (`hd.ps1`, CreateDesktop; probe: foreground never Godot), rendered in
  SubViewports of exact size: `docs/art/screens/q1-juice/` — portrait 1080×1920 and landscape 1920×1080: result
  moment perfect at 3 times (stamp / count / rest), great, miss, Neon Moth gate and singe. Script
  `game/tests/capture_q1_juice.gd`.
- Hub card `q1-juice-review` (Questions tab, order 379): 9 pictures + files list.

## What changed
- New `game/scripts/minigames/mg_fx.gd`: hit pop (rise 40 px, 1.3→1.0, 0.5 s), combo counter (grows, shatters
  into sparks), hit flash 60 ms + red edge 120 ms, trauma shake (0.3 / 0.6, 0.25 s, max 10 px) with reduce
  motion (`Needs.ext.ui.reduce_motion`, default off = shake allowed), hit-stop 50 ms, squash & stretch,
  CPUParticles2D bursts (spark / ember / confetti, ≤ 200 alive, untextured squares), glow texture + additive
  material + flares. All values are named constants.
- `minigame_base.gd`: `fx()`, `hit_stop()`, `vibrate(ms)`, `haptic(kind)`, `vibrate_supported_by()`.
- Web haptics (§2.4): vibration now fires on native phones and `web_android`; `web_ios` never (no Vibration API).
  The five `Input.vibrate_handheld` sites (coaster_flip, neon_moth, pour_perfect, shake_serve, soi_dash) call
  `vibrate()`.
- `result_card.gd`: stamp slam (2.4→1, tilt −16°→−4°, landing dip, card shake, haptic by tier, sparks / confetti),
  count-up 0.6 s, NEW BEST ribbon, competition lines (`+N over your best`; tonight's regular via
  `extra.rival`), glow behind great/perfect stamps; `animate = false` opens at rest; `outcome.prev_best`.
- Neon Moth: proof wiring only (gate, singe, sign).
- Strings (`game/i18n/strings.csv`, TH machine drafts): mg.fx.clean, mg.fx.perfect, mg.fx.combo,
  mg.result.over_best, mg.result.rival_beat / rival_level / rival_short, mg.settings.reduce_motion.
- PROJECT.md Tests: `test_mg_fx` added (twenty-five suites).

## Not verified
- No real phone: the Android browser buzz and the feel on a phone are untested; iPhone has no web vibration API.
- No web build was made.

## Follow-ups (for the orchestrator)
- Reduce-motion switch on a settings menu (owner of the menu scripts); the setting and string exist.
- `minigame_frame.gd` (~line 96, safe area) and `ui/orientation.gd` still use `OS.has_feature("mobile")`,
  false on the web build: for Q2 / the UI owner to check.
- Card paths point at the worktree; after the push they live at the same relative paths in the shared checkout.

## Profile feedback
- The `ui` profile fit. Missing: how to upload hub pictures from a worktree (asset upload refuses paths outside the
  session's folders; copy them to the scratchpad first).
