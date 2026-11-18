# 11 — Minigame quality bar (owner item 38): look, feel, difficulty, competition

Design only, 2026-11-18 (🎲 design-quality, load id 2026-11-18-rules-powers-black-cabin-f19e92).
Daniele 2026-11-18: "should we start to improve the quality of the games? like better graphic more competitive etc?",
then "Yes, plan it". **Nothing here is built or decided.** Sound and art direction are Daniele's calls: this page
gives options with a recommendation; he answers on the hub card `minigame-quality-plan` and its question cards
(https://claude.ai/artifact/BbpBxVWVVXMjz7TgJ7aFBW#questions). Rules, balance and money stay as signed off
(04-coins, 06-stakes §7.2): nothing below changes a payout, a cap or the 3 tries per visit unless a question says so.

Pictures (mock-up drawings made in Python from existing captures, **not game captures**; no code was changed and no
Godot was run): `docs/art/screens/minigame-quality/`
- `neon-moth-today-vs-target.jpg` — today's v0.3.0 Neon Moth frame next to the target frame, six numbered ideas.
- `result-today-vs-target.jpg` — today's result card next to the target result moment.
- `art-options-a-b-c.jpg` — the three art directions on the same moth and gate.
- `make_mocks.py` — the script that draws them (rerun it to change a mock).

## 0. Where we are (read from the code, 2026-11-18)

Eight minigames, all `Control` scenes on `minigame_base.gd`, opened in `minigame_frame.gd`, ending on the shared
`result_card.gd`. All eight draw themselves with flat 2D calls (`draw_rect`, `draw_circle`, polygons) in the
style-guide palette (`mg_ui.gd`). What they share today:

| | Have | Missing |
|---|---|---|
| Look | Palette, Lato / Kristi fonts, a fitted play field | Sprites, glow, particles, any link to the voxel venue; backgrounds are flat fills |
| Feel | Status line, a few colour flashes (pinball bumpers, Coaster Flip ring) | Screen shake, hit pops, combo readouts, a result *moment*; **haptics never fire on the web build** (see §2.4) |
| Sound | Front Row Rhythm's generated tick | Everything else: the game has no sound effects and no audio files at all |
| Difficulty | Coaster Flip ramps (spin speeds up, flat window narrows); Shake & Serve and Coaster Flip honour relaxed timing | Neon Moth, Soi Dash, Pour Perfect, pinball run flat (no ramp); relaxed timing missing in Pour Perfect, Soi Dash, Neon Pinball |
| Competition | Personal best per game (`Needs.ext["minigame_best"]`, shown on the sheet and result); Coaster Flip's regular "stack to beat"; nightly seed in Neon Moth and Soi Dash | A target to chase tonight, a reason to come back tomorrow, anyone else's score |

The games, with what Daniele said: **Neon Moth** "is fun" (the template). **Coaster Flip** "seems bugged" and **Soi
Dash** "goes outside of the screen": worker fix-031 is fixing those for 0.3.1, so this plan touches neither file until
0.3.1 is verified. Shake & Serve, Pour Perfect, Front Row Rhythm, Candle Talk and Neon Pinball: no feedback yet.

## 1. Look: from flat 2D to the venue's voxel / neon look

### 1.1 Three directions (Daniele's call; picture `art-options-a-b-c.jpg`)

| | A. Polished flat neon | B. Voxel sprites ★ rec | C. Real 3D in the venue |
|---|---|---|---|
| What | Keep the draw code; add glow, gradients, particles, better silhouettes | Each game's objects (moth, bulbs, speakers, coasters, bottles, bikes) built as voxel models in the Blender kit style, **rendered once to small sprite sheets**, drawn in 2D with glow and particles on top | The minigame plays inside a 3D scene with the venue camera |
| Looks like the venue | Somewhat (palette) | Yes: same voxels and materials as the room you walked in from | Fully |
| Cost per game | S (½ session) | M (1 session: Blender generator + sheet + swap the draw calls) | L (2–3 sessions) and new tests |
| Phone GPU | +0–1 MB | +1–4 MB per open game (§1.3) | +20–60 MB and the iPhone already lost graphics at ~208 MB (owner item 33) |
| Risk | Low; can still look "app-like" | Low; one generator script, reruns cleanly | High: renderer, memory, camera, every test |

**Recommendation: B for every game, built on A's juice layer.** A alone stays below the quality bar of renders 05/06
that the venue is held to; C fights the iPhone memory budget the perf workers just won back. B reuses the kit
pipeline (`tools/blender/bc_kit.py` style, Blender 5.2.2), so the moth on the cabinet and the BLACK CABIN neon in the
lounge are the same voxels. The mock `neon-moth-today-vs-target.jpg` shows B (pixel blocks stand in for renders).

### 1.2 What B means per game (the sprites to render)

| Game | Sprites (each a small sheet, 2–6 frames) | Background |
|---|---|---|
| Neon Moth | moth (flap 4 frames, singe 2), bulb string segment, speaker cabinet, the BLACK CABIN neon (the kit's own) | the lounge, blurred and darkened, slow parallax (one 540×960 image) |
| Coaster Flip | coaster (spin 8 frames), stack, tall table top, the regular's head (from `chars`) | Buffer / main-room opening, blurred |
| Soi Dash | runner (from the player's avatar parts: run 4, hop 2), bike, food cart, soi dog, kerb, note, shop fronts strip | night soi strip, 2-layer parallax |
| Shake & Serve | 12 bottles (from the bar kit), shaker (shake 4), glass, Nam's head | the backlit bar shelf, blurred |
| Pour Perfect | glass, tap/bottle, foam | bar top close-up |
| Front Row Rhythm | clap hands, beat pucks, band silhouettes | the stage, blurred, light pulses on the beat |
| Candle Talk | candle (flame 4), the regular (from `chars`), topic cards | candle table close-up |
| Neon Pinball | bumpers, flippers, ball, BLACK CABIN letters | cabinet playfield art, one image |

Shared (built once in job Q1): glow sprite (soft additive circle), spark / ember / confetti squares, the tier stamps,
number font for pops.

### 1.3 Memory and speed budget (iPhone)

From LOG / owner item 33: the iPhone lost graphics entering the venue at **textures 149.6 MB + render buffers
57.9 MB** at pixel ratio 3; perf-iphone-2 brought the venue entry to **~86 MB WebGL** (emulated, not measured on an
iPhone) with ratio cap 2 and MSAA off on touch phones. A minigame opens **on top of** the loaded venue, so it adds to
that number. Budget:

- **≤ 6 MB of GPU memory per open minigame**, loaded when it opens and freed when it closes. A 1024×1024 RGBA
  sheet is 4 MB uncompressed (+33 % with mipmaps; 2D sheets need none); most games fit one 512×512 (1 MB) sheet plus
  one background (540×960 ≈ 2 MB, or a 270×480 one scaled up and blurred, 0.5 MB).
- **No full-screen post-process shaders** on phones (each extra buffer at 1170×1995 is ~9 MB, and the Compatibility
  renderer's 2D glow is untested on iOS here). Glow = pre-blurred additive sprites; flashes = a full-screen
  `ColorRect` with alpha. Cheap and renderer-independent.
- **Particles: `CPUParticles2D`** (Compatibility-safe), ≤ 200 alive at once per game.
- **Pause the venue's 3D drawing while a minigame covers the screen** (the frame is opaque): likely a frame-rate and
  battery win on phones. It touches `main.gd`, so it is its own small job (Q2) with a before/after draw-call count.
- Each art job reports: sheet sizes, GPU MB with the game open (the context-loss banner's tally gives it), draw calls,
  and a phone check if Daniele can do one (else "desktop emulation only").

## 2. Feel ("juice"): every action answers

### 2.1 The rule

Every player input gets **an answer within the same frame**: something moves, flashes, pops or sounds. Every
success is **bigger** than every routine input; every failure is **clear but short** (≤ 0.5 s, never blocks the next
input). The result is a **moment**, not a dialog.

### 2.2 The shared juice kit (job Q1, one file `mg_fx.gd`, used by every game)

| Effect | Spec (starting values, tunable) |
|---|---|
| Hit pop | "+1", "+50", "CLEAN" text rises 40 px and fades in 0.5 s, scale 1.3 → 1.0 |
| Combo counter | "CLEAN ×6" under the action; grows on each step, shatters into sparks on a break |
| Hit flash | object tints white 60 ms; failure tints the screen edge red 120 ms |
| Screen shake | trauma model: 0.3 on a bump, 0.6 on a lost life, decays in 0.25 s, max 10 px; **off with the "reduce motion" switch** (new setting, default on = shake allowed) |
| Hit-stop | 50 ms freeze on a big hit (catch, perfect beat) |
| Squash & stretch | on taps (moth flap, coaster catch, shaker) |
| Particles | sparks on success, embers on singe, confetti on perfect |
| Result moment | tier stamp slams in (rotate + overshoot) with a short shake and haptic; score counts up 0.6 s; NEW BEST ribbon; then the competition lines (§4) |
| Haptics | light tick on success, double on failure, strong on perfect (§2.4) |
| Sound | per game set (§2.5), only if Daniele says yes |

Picture: `result-today-vs-target.jpg` (the result moment).

### 2.3 Per-game feedback beats (what each game must answer)

| Game | Inputs and the answer each gets |
|---|---|
| Neon Moth | tap → wing snap + ember puff; gate passed → "+1" + gold flash in the gap; 3 gates clean → combo; singe → shake 0.3, ember burst, red edge, wing icon breaks; sign reached → neon flares, confetti |
| Coaster Flip | swipe → stack whoosh, motion blur frames; ring "flat" → ring pulse; catch → hit-stop, stack grows with a clack, "+1"; drop → coasters scatter (particles), shake 0.3; beat the regular → their head reacts + line |
| Soi Dash | swipe → lane dash streak; hop → dust puff; note → chime pop, combo of notes without a bump; bump → shake + clock flashes "−2 s"; door → doors swing, neon flares |
| Shake & Serve | bottle tap → bottle lifts and pours a splash; wrong bottle → shelf rattle; nod → Nam's nod + beat ring; on-beat shake → splash particles + tick; serve → glass slides, ice clink |
| Pour Perfect | hold → stream + rising foam; release on the line → line flashes, "PERFECT" pop; overfill → foam spill particles |
| Front Row Rhythm | tap → hand clap squash; perfect → white flash on the puck + combo; miss → puck dims (no shake: it breaks rhythm) |
| Candle Talk | card play → card flies to the candle; best card → flame flares, regular smiles; miss → flame gutters (no shake: it is a chat) |
| Neon Pinball | already the most alive; add hit-stop on bumpers, letter light-up pops, ball trail, shake on drain |

### 2.4 Haptics on the web build (finding)

Every game guards its vibration with `OS.has_feature("mobile")`. On the **web** export that feature is, by Godot's
feature-tag rules, not set (phones report `web` plus `web_android` / `web_ios`), so **the four
`Input.vibrate_handheld` calls never fire on the live build**. Not checked on a phone; to be confirmed in job Q1.
- **Android Chrome:** `Input.vibrate_handheld` → the browser Vibration API works. Fix: test `OS.has_feature("web_android")`
  or `"mobile"`.
- **iPhone (Safari and Chrome on iOS, both WebKit):** no Vibration API, so **no haptics on iPhone** from a web build.
  The visual and sound beats carry the feel there. (A native iOS export later would get real haptics.)
- `minigame_frame.gd` line 96 uses the same `"mobile"` test for the on-screen keyboard: worth a look in the same job.

### 2.5 Sound (Daniele's call: yes / no, then a style)

Today the game makes no sound except one generated tick. Options:
- **No sound** (visual + haptics only): zero size, zero licensing; the minigames stay mute.
- **Sound effects only ★ rec**: about 6–10 short sounds per game (~60 in all, ogg, ~400 KB total), one mute switch in
  settings, default on. Web audio starts after the first tap, which every minigame has anyway. Sources: made for us
  (generated or recorded), or CC0 libraries; nothing ripped from games.
- **Effects + a music loop per game**: biggest feel gain, but +2–5 MB, licensing, and it competes with the Black Cabin
  song (owner item 34). Better after the song question is settled.

Style (if yes):
- **Real-bar foley**: glass clinks, coaster clacks, the shaker, amp hum, crowd murmur.
- **Arcade chip sounds**: bleeps and arpeggios, like a cabinet.
- **Mixed ★ rec**: the cabinet games (Neon Moth, Soi Dash, pinball) sound like an arcade; the bar and table games
  (Coaster Flip, Shake & Serve, Pour Perfect, Candle Talk, Front Row Rhythm) sound like the real room. It tells you
  where you are: on a machine, or in the bar.

## 3. Difficulty: a ramp through each run, relaxed timing kept

The rule: **the first 10 s are a warm-up anyone survives; the middle teaches; the last third tests.** Relaxed timing
(the accessibility switch, +50 % windows today) widens every window and slows every ramp; it never removes a ramp.
Numbers are starting values for the build job, tuned by playing.

| Game | Ramp across the run (normal) | Relaxed |
|---|---|---|
| Neon Moth | gap 340 → 250 px over 15 gates; scroll 200 → 250 px/s; gap step 200 → 320 px; last 3 gates "tight" | gap +60 px all flight; scroll capped at 225 |
| Coaster Flip | as built (spin +0.12 turns/s per catch, flat window narrows); add: from catch 6 the ring drifts | as built (−0.15 on the flat need) |
| Soi Dash | row gap 1.9 → 1.2 units; two-lane rows only after 10 s; dogs only after 15 s | row gap +0.4; telegraph rows 0.5 s earlier (after fix-031) |
| Shake & Serve | order 1: 2 bottles; 2: 3 bottles; 3: 3 bottles + a decoy; nods 0.60 → 0.50 s apart | as built (0.33 s window) |
| Pour Perfect | layer 1 slow flow, layer 3 fastest wobble; perfect band shrinks 0.03 → 0.015 | **add** relaxed: perfect band ×1.5, flow −20 % |
| Front Row Rhythm | already in the beat maps; add a "hard" chart per song later | as built (×1.5) |
| Candle Talk | no ramp: it is a chat, not a skill test | n/a |
| Neon Pinball | ball speed cap +10 % per ball; ball save 10 → 5 s on ball 3 | **add** relaxed: ball save 15 s, tilt limit +1 |

Every ramp change keeps the score tiers where they are (miss < 0.25, great 0.6, perfect 0.85) and is checked with the
game's suite driven through `advance(dt)`: a scripted "average" run must still land in good/great, a perfect run must
still be possible, and relaxed must score ≥ normal for the same inputs.

## 4. Competition

### 4.1 Offline now (no server; works in today's single-player build)

| Feature | What | Cost | Rec |
|---|---|---|---|
| **Personal best, louder** | exists; add the NEW BEST ribbon and "+12 over your best" on the result; best per game on the sheet | S (in Q1) | ★ yes |
| **Tonight's regular to beat** | each night (Bangkok date seed) a regular "plays" each cabinet / table game: a seeded score from their skill (Tt good, Hiro great, Lung Nop bad...), shown on the sheet and the result ("Tt 92 · 8 short"). Generalises Coaster Flip's stack to beat. Clearly the cast, never presented as real players | S per game | ★ yes |
| **The lounge "Top patrons" board** | the board already in the lounge shows tonight's cabinet scores: the regulars' seeded scores plus yours, ranked | M (venue board text) | ★ yes, after Q3 |
| **Ghost run** | your best run tonight flies / runs beside you (semi-transparent). The deterministic games (Neon Moth, Soi Dash, Coaster Flip) replay their own recorded taps through `advance(dt)`: a few hundred bytes a game | S–M per game | ★ yes for Neon Moth, Soi Dash |
| **Night streak** | Bangkok nights in a row with a good-or-better round in any minigame; shown on the result; a small badge at 3 / 7. **No coins** (04-coins unchanged) | S | optional: it nudges daily play inside a game whose real goal is going to the bar |
| **Practice rounds** | after the 3 tries a visit, more rounds with **no gain, no coins, no best** (score shown, ghost kept) | S | Daniele's rule call (06-stakes §7.2 says 3 tries a visit, misses included); rec **no** for now: the tries are a stake |

### 4.2 Later, with T2 (Supabase; waits on card presence-supabase-setup)

- Real nightly leaderboards per game per seed ("everyone flew the same lounge tonight"), top 10 + your rank.
- Friends: scores of players you checked in with at the real bar.
- Weekly cabinet champion shown on the in-game board and, if Black Cabin wants it, a small real-world thank-you
  (a T3 business call, not a coin rule).
- Real ghosts (the night's top run). Anti-cheat: server replays the recorded inputs through the same deterministic
  game code before accepting a score (another reason to keep every game on `advance(dt)` with a seed).
The offline features above are built so T2 only swaps the data source: the regulars' seeded rows sit next to real
rows on the same board.

## 5. Per-game scorecard

Scores 1–5 (today → target), judged from the code and the v0.3.0 captures, not from play on a phone.

| Game | Look | Feel | Ramp | Compete | Biggest gap | Effort to target | Order |
|---|---|---|---|---|---|---|---|
| **Neon Moth** (template) | 2 → 4 | 2 → 5 | 1 → 4 | 2 → 4 | flat shapes, no ramp, no answer to a tap | M (Q3 + Q4) | **1** |
| Coaster Flip | 2 → 4 | 2 → 4 | 3 → 4 | 3 → 4 | bugs first (fix-031), then the catch moment | M | 2 (after 0.3.1) |
| Soi Dash | 2 → 4 | 2 → 4 | 1 → 4 | 2 → 4 | off-screen (fix-031), flat density | M | 3 (after 0.3.1) |
| Shake & Serve | 2 → 4 | 2 → 4 | 2 → 4 | 1 → 3 | no tactile shake, recipe screen plain | M | 4 |
| Neon Pinball | 3 → 4 | 3 → 4 | 2 → 3 | 2 → 4 | already lively; art + ghostless board | S–M | 5 |
| Pour Perfect | 2 → 4 | 2 → 4 | 2 → 3 | 2 → 3 | no relaxed, plain glass | S–M | 6 |
| Front Row Rhythm | 2 → 4 | 3 → 4 | 3 → 4 | 2 → 3 | stage art, needs sound most of all | M | 7 |
| Candle Talk | 2 → 4 | 2 → 3 | n/a | n/a | art of the regular and the candle; not a score race | S | 8 |

Why this order: Neon Moth first because Daniele likes it and it is the cleanest code (a template others copy);
Coaster Flip and Soi Dash next because they are new and visible, but only once fix-031's 0.3.1 is verified; then the
rest by how much a player sees them.

## 6. Build order: small jobs (each ≤ one worker session)

Every job: own files only, its suite(s) green headless, captures portrait 1080×1920 + landscape on the hidden desktop
only (PROJECT Tests, 2026-11-15) or marked NOT DONE, one review card. One Godot at a time.

| Job | What | Files | Waits on | Size |
|---|---|---|---|---|
| **Q1 juice kit** | `mg_fx.gd` (pop, combo, flash, shake with reduce-motion switch, hit-stop, particles, glow sprite), haptics fix for web (§2.4), result moment in `result_card.gd` (stamp, count-up, NEW BEST) | new `mg_fx.gd`, `result_card.gd`, `mg_ui.gd`, `minigame_base.gd` (one helper), strings | 0.3.1 verified (fix-031 may touch the frame) | M |
| **Q2 venue pause** | stop drawing the 3D venue while a minigame covers it; before/after draw calls and GPU MB | `main.gd`, `minigame_frame.gd` | 0.3.1 | S |
| **Q3 Neon Moth look** | Blender generator for the moth, bulb string, speaker; sprite sheet; blurred lounge background; the kit's neon as the goal | `tools/blender/bc_minigame_sprites.py` (new), `game/assets/minigames/neon_moth/`, `neon_moth.gd` draw code | art direction answer (B), Q1 | M |
| **Q4 Neon Moth feel + ramp + compete** | §2.3 beats via `mg_fx`, §3 ramp, regular to beat, ghost run, sound if yes | `neon_moth.gd`, new `mg_rivals.gd` (seeded regulars), `test_neon_moth` | Q1, Q3, sound + competition answers | M |
| Q5 Coaster Flip | Q3 + Q4 pattern | `coaster_flip.gd`, assets, suite | 0.3.1 verified, Q4 accepted by Daniele | M |
| Q6 Soi Dash | same; runner from the avatar parts | `soi_dash.gd`, assets, suite | 0.3.1 verified, Q4 accepted | M (maybe L with the avatar runner) |
| Q7 Shake & Serve | same | `shake_serve.gd`, assets, suite | Q4 accepted | M |
| Q8 Pinball + Pour Perfect | art + relaxed for both | two scripts, suites | Q4 accepted | M |
| Q9 Rhythm + Candle Talk | art; rhythm sound pass | two scripts | Q4 accepted, sound answer | M |
| Q10 lounge board | Top patrons board shows tonight's cabinet scores | venue board script | Q4 | S |
| Q11 sound set | the effects (if yes), mute switch | `game/assets/audio/`, settings | sound answers | S–M |

Q1 and Q2 can run side by side (different files); everything after Q4 waits for Daniele to accept the Neon Moth
template on a card, so the other games copy something he approved. T2 leaderboards are a separate track after the
Supabase card.

## 7. Questions for Daniele (one card each on the Questions tab)

1. **Sound: yes or no?** No sound / effects only ★ / effects + music loops.
2. **Sound style** (if yes): real-bar foley / arcade chip / mixed by place ★.
3. **Art direction:** A polished flat neon / B voxel sprites from the Blender kit ★ / C real 3D in the venue.
4. **Order:** Neon Moth first, then Coaster Flip, Soi Dash, Shake & Serve, the old four ★ / fix the old four first /
   another order.
5. **Competition offline (pick any):** louder personal best ★, tonight's regular to beat ★, ghost run ★, the lounge
   board ★, night streak (optional).
6. **Practice rounds after the 3 tries** (no gain, no coins, no best): no, keep the tries a stake ★ / yes.

## Files

- This doc: `docs/design/11-minigame-quality.md`
- Mock-ups: `docs/art/screens/minigame-quality/` (`neon-moth-today-vs-target.jpg`, `result-today-vs-target.jpg`,
  `art-options-a-b-c.jpg`, `neon-moth-target-clean.png`, `make_mocks.py`)
- Games: `game/scripts/minigames/` (eight games, `minigame_base.gd`, `minigame_frame.gd`, `result_card.gd`, `mg_ui.gd`)
- Binding: `docs/design/04-coins-summary.md` (minigame coins 2 / 3 / 5), `docs/design/06-stakes.md` §7.2 (3 tries),
  `docs/design/10-minigame-next.md` (the four new games as built), DECISIONS.md
- Perf numbers: `handoffs/owner-feedback-2026-11-09.md` item 33, LOG.md 2026-11-10 (perf-iphone-2)
