# 15 — Minigame ramp: endless, harder, a clear loss (draft for Daniele's OK)

Owner words (Daniele, 2026-11-20): "all game should get more hard the more you play with clear loss condition for
example the clap game should have double taps and 2 taps at the same time and after a few lost taps a loss (3 taps
missed)" · "since are all records game no need to end them at black cabin sing but make them become increasingly
harder and faster (but humanly possible not impossible) so become real competition".

## Rules for all eight
- **No fixed end.** No sign, no song end, no 3 orders, no 10-catch run, no clock. A round ends only on its loss
  rule (or Leave in the pause menu). Every loss rule is **3 strikes**, shown in play.
- **The record is uncapped.** Points keep counting; about **100 = what a perfect old round scored**, so old bests
  still mean something. The best, tonight's board and the rivals use these points.
- **Rewards do not change.** The need gain still reads the first 100 points (min(1, points/100)), so a long run is a
  record, not a way to farm the meters. Miss below 25 points as before.
- **Harder by level**, each level faster or denser, up to a **cap** (the top level) that stays humanly playable.
  A "LEVEL n" pop and a tick when it goes up; the level shows in the status line.
- **Relaxed timing** keeps its extra slack at every level.
- **Telemetry**: every end sends `end_reason` (lost / quit / closed), `level`, `speed`, `misses` to play_events.

## The table

| Game | Starts at | Gets harder by | Cap (top level) | Loss | Points | Why the cap is playable |
|---|---|---|---|---|---|---|
| **Neon Moth** | 200 px/s, gates 390 apart, gap 340 | every gate: +4 px/s, gates 4 px closer, gap 3 px smaller; more gates bob | gate 30: 320 px/s, gates 260 apart (one every 0.8 s), gap 230 (5.7 moths tall), 70 % bob | 3 singes (as now) | 5 a gate (20 gates = 100) | one flap lifts ~110 px; the gap moves at most 280 px gate to gate = 3 flaps in 0.8 s |
| **Coaster Flip** | spin 1.2 turns/s, flight 1.3 s | every catch: spin +0.12, flat need +0.02 (as now); after catch 10 the flight shortens and the ring drifts wider | catch 10 timing (today's hardest) + catch 25: flight 0.9 s | 3 drops (as now); a drop keeps the level, the stack starts again | 10 a catch | the catch window stays today's catch-10 window (~90 ms with the 50 ms tap grace); only the tempo rises |
| **Shake & Serve** | orders 1-3 as now (2, 3, 4 bottles) | from order 4: shelf restocked every order, recipe look 2.0 → 1.5 s, pick time 12 → 7 s, nods 6 → 8, nod gap 0.50 → 0.38 s | order 9 | an order under 50 % = Nam sends it back; 3 sent back | 33 an order × its score | 0.38 s nods = 158 a minute, slower than a fast clap; 1.5 s still reads 4 chips |
| **Soi Dash** | 1.0 street/s, rows 1.9 apart, no clock | +0.01 speed a second; rows close to 1.2 (as now); tuk-tuks 10 s, dogs 15 s, lizards 20 s, two-lane rows more often | 60 s: 1.6 street/s (a row every 0.75 s, 2.5 s seen ahead) | 3 bumps | 2 a street unit + 1 a note (the old street ≈ 110) | a hop (0.6 s) still clears one row before the next; 2.5 s of preview |
| **Neon Pinball** | as now, 3 balls | level +1 each time BLACK CABIN is spelled (letters reset) and every 60 s: gravity +100, ball save −1 s, word bonus × level | level 6: gravity 2100 (+40 %), ball save 4 s | 3 balls (as now), no 3-minute cap | pinball score / 30 (3000 = 100, as now) | the flippers swing in 0.05 s; a 40 % steeper table is still slower than a real one |
| **Pour Perfect** | glass 1 as now (3 layers) | glass after glass; new lines each glass; pour speed +0.008 a glass, flow wobble 35 → 55 % | glass 10: 0.15 glass/s | a layer more than 0.10 off its line, a spill over the rim, or 8 s without pouring = a spoiled layer; 3 spoiled | 33 a layer × its score | at the fastest flow the ±0.10 band lasts 0.85 s, the perfect band 0.17 s |
| **Front Row Rhythm** | 96 BPM, one lane at a time | +4 BPM every 8 bars; bar 9 two lanes at once, bar 17 double taps (same lane, half a beat apart), bar 25 runs swapping lanes; notes fall faster (1.7 → 1.2 s) | 152 BPM (after ~4 min) | **3 missed taps** | perfect 2, good 1 | eighths at 152 BPM = 5 taps a second over two thumbs; hit windows unchanged (±70 / ±140 ms) |
| **Candle Talk** | turns 1-5 as now | past turn 5 the talk goes on: the regular's lines come round again in a new card order, with a reply timer 8 s → 4 s | turn 14: 4 s to answer | an off card or a timeout = the candle gutters; 3 gutters = candle out | 20 best card, 10 half | 4 s reads a one-line question and 3 short cards |

## Open for Daniele (one card each on the Questions tab)
1. The table above (the ramp, caps and loss rules).
2. Tonight's regulars: their numbers were made for a 0-100 round. Recommendation: scale them ×1.5 so the board stays a
   contest (Hiro ~130, Lung Nop ~50); or leave them as they are.
3. Candle Talk: endless repeats each regular's 6 lines. Recommendation: endless as above (it is a record game too);
   or keep it a 5-turn talk (it feeds hearts, daily once).
