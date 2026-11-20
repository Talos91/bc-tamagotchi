extends SceneTree
## Headless tests for Neon Moth (docs/design/10-minigame-next.md §D): the lounge per night (generated ahead in chunks),
## points, a scripted flyer, singes, the action, strings and the venue registry. Q4 (11-minigame-quality §2.3, §4.1):
## the voxel sprites, the juice beats, and mg_rivals (regulars to beat, tonight's best, ghost run, board). Endless ramp
## (docs/design/15-minigame-ramp.md; Daniele 2026-11-20): no sign; the ramp per gate up to its cap at gate 30, level
## 1..7, 5 points a gate, the third singe loses.
##   godot --headless --path . --script res://tests/test_neon_moth.gd
## Exit code 0 = all pass.

const Rules = preload("res://scripts/rules.gd")
const Base = preload("res://scripts/minigames/minigame_base.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Game = preload("res://scripts/minigames/neon_moth.gd")
const Session = preload("res://scripts/zones/venue_session.gd")
const Rivals = preload("res://scripts/minigames/mg_rivals.gd")
const Card = preload("res://scripts/minigames/result_card.gd")

const STEP := 1.0 / 120.0
const LONG_STEP := 1.0 / 60.0        ## long average-player runs (collisions still well inside a gate: 5 px a step)


## Stands in for Needs: mg_rivals only reads and writes `ext`.
class Store:
	extends RefCounted
	var ext := {}


var failures := 0
var checks := 0
var _result: Dictionary = {}
var store := Store.new()


func _initialize() -> void:
	test_layout()
	test_points()
	test_ramp_numbers()
	test_good_flyer()
	test_idle_and_singes()
	test_tap_input()
	test_action_strings_registry()
	test_on_screen()
	test_average_and_relaxed()
	test_art_and_juice()
	test_rivals_api()
	test_rivals_in_game()
	# a game script that fails to compile makes every test error out before any check runs: never call that a pass
	check(checks >= 100, "the suite ran its checks (%d)" % checks)
	print("")
	print("%d checks, %d failed" % [checks, failures])
	print("NEON MOTH TESTS ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("  FAIL: ", msg)


func spawn(config := {"seed": 20261115}) -> Control:
	var g: Control = Game.new()
	g.size = Vector2(1080, 1400)
	g.config = config
	g.rivals_store = store
	root.add_child(g)
	_result = {}
	g.finished.connect(func(r: Dictionary) -> void: _result = r)
	g.start()
	return g


func test_layout() -> void:
	print("[layout] same lounge per night, a new one tomorrow, fair steps, generated ahead in chunks")
	var a := Game.layout(42, 60)
	check(a.size() == 60 and Game.layout(42).size() == Game.GATES, "layout(seed, n) gives n gates (default the old 20)")
	check(a == Game.layout(42, 60), "the same seed gives the same gaps")
	check(a != Game.layout(43, 60), "another night gives other gaps")
	check(Game.layout(42, 20) == a.slice(0, 20), "the first gates do not depend on how far the course is generated")
	var ok := true
	var c: Dictionary = Game.course(42, 60)
	for i in a.size():
		var amp := Game.MOVE_AMP if c["phase"][i] >= 0.0 else 0.0
		if a[i] - amp < Game.GAP_MIN_Y - 0.01 or a[i] + amp > Game.GAP_MAX_Y + 0.01:
			ok = false
		if i > 0 and absf(a[i] - a[i - 1]) > Game.step_at(i) + 0.01:
			ok = false
		if i > 0 and absf(float(c["x"][i]) - float(c["x"][i - 1]) - Game.spacing_at(i - 1)) > 0.01:
			ok = false
	check(ok, "gaps stay in range, never jump more than the ramp's step, gates spaced by the ramp")
	var bkk_midnight := 1_800_000_000.0 - fmod(1_800_000_000.0 + Game.BKK_OFFSET, 86400.0)
	check(Game.night_seed(bkk_midnight - 1.0) + 1 == Game.night_seed(bkk_midnight), "the seed turns over at Bangkok midnight")
	# in play: a chunk ahead at the start, more as the moth flies, the same gates as course()
	var g := spawn()
	check(g.gap_y.size() >= Game.CHUNK and g.gap_y.size() <= 2 * Game.CHUNK, "the start generates one chunk or two (%d), not the whole night" % g.gap_y.size())
	check(g.passed.size() == g.gap_y.size() and g.hit.size() == g.gap_y.size() and g.gate_off.size() == g.gap_y.size(), "per-gate arrays grow together")
	fly_bot(g, 60.0)
	var n: int = g.gap_y.size()
	check(n > Game.CHUNK, "the course grew ahead of the moth (%d gates)" % n)
	var same: Dictionary = Game.course(20261115, n)
	check(g.gap_y == same["centre"] and g.gate_off == same["x"] and g.move_phase == same["phase"], "the chunks in play are course(seed, n)")
	check(Game.START_X + g.gate_off[n - 1] - g.scroll < Game.AHEAD_PX + Game.CHUNK * Game.SPACING_START, "never generated far beyond what is needed")
	g.queue_free()


func test_points() -> void:
	print("[points] 5 a clean gate, uncapped record; the need score reads the first 100")
	check(Game.points_at(0) == 0 and Game.points_at(1) == 5 and Game.points_at(20) == 100, "5 a gate, 20 gates = 100 (the old perfect flight)")
	check(Game.points_at(47) == 235, "the record is uncapped (47 gates = 235)")
	var g := spawn()
	for gates in [0, 4, 5, 13, 20, 21, 60]:
		g.gates_passed = gates
		var pts: int = g.record_points()
		check(pts == 5 * gates and g.live_points() == pts, "%d gates: %d points" % [gates, pts])
		check(is_equal_approx(g.current_score(), minf(1.0, float(pts) / 100.0)), "%d gates: score = min(1, points / 100) (%.2f)" % [gates, g.current_score()])
	check(Base.tier_for(Game.score_of(Game.points_at(4))) == Base.TIER_MISS, "4 gates (20 points) is a miss")
	check(Base.tier_for(Game.score_of(Game.points_at(5))) == 0, "5 gates (25 points) is good")
	check(Base.tier_for(Game.score_of(Game.points_at(18))) == 2, "18 gates (90 points) is perfect")
	g.queue_free()


func test_ramp_numbers() -> void:
	print("[ramp] every gate faster, closer, tighter, more bobbing, up to the cap at gate 30; relaxed keeps its slack")
	check(is_equal_approx(Game.speed_at(0), 200.0) and is_equal_approx(Game.speed_at(1), 204.0) and is_equal_approx(Game.speed_at(30), 320.0), "speed 200 + 4 a gate, 320 at gate 30")
	check(is_equal_approx(Game.spacing_at(0), 390.0) and is_equal_approx(Game.spacing_at(1), 386.0) and is_equal_approx(Game.spacing_at(33), 260.0), "spacing 390 - 4 a gate, 260 from gate 33")
	check(is_equal_approx(Game.gap_at(0), 340.0) and is_equal_approx(Game.gap_at(1), 337.0) and is_equal_approx(Game.gap_at(37), 230.0), "gap 340 - 3 a gate, 230 from gate 37")
	check(is_equal_approx(Game.step_at(0), 200.0) and is_equal_approx(Game.step_at(20), 280.0), "a gap moves at most 200 + 4 a gate, 280 from gate 20")
	check(is_equal_approx(Game.move_chance_at(Game.MOVE_FROM - 1), 0.0) and is_equal_approx(Game.move_chance_at(Game.MOVE_FROM), 0.45) and is_equal_approx(Game.move_chance_at(30), 0.70), "bobbing from gate 7: 0.45 -> 0.70 at gate 30")
	var rising := true
	for i in range(1, 30):
		if not (Game.speed_at(i) > Game.speed_at(i - 1) and Game.gap_at(i) < Game.gap_at(i - 1) and Game.spacing_at(i) < Game.spacing_at(i - 1)):
			rising = false
	check(rising, "gates 1..29: every gate faster, tighter and closer than the one before")
	var capped := true
	for i in [37, 40, 75, 200, 1000]:
		if not (is_equal_approx(Game.speed_at(i), Game.SPEED_CAP) and is_equal_approx(Game.spacing_at(i), Game.SPACING_MIN) and is_equal_approx(Game.step_at(i), Game.STEP_CAP)
				and is_equal_approx(Game.move_chance_at(i), Game.MOVE_CHANCE_CAP) and is_equal_approx(Game.gap_at(i), Game.GAP_MIN)):
			capped = false
	check(capped, "past the cap nothing rises any more")
	check(Game.SPEED_CAP == 320.0 and Game.SPACING_MIN == 260.0 and Game.GAP_MIN == 230.0 and Game.STEP_CAP == 280.0 and Game.MOVE_CHANCE_CAP == 0.70, "the cap matches the table (320 px/s, 260 apart, gap 230, step 280, 70 % bob)")
	check(Game.SPACING_MIN / Game.SPEED_CAP > 0.79, "at the cap a gate comes every 0.8 s (%.2f s)" % (Game.SPACING_MIN / Game.SPEED_CAP))
	var lift := Game.FLAP_SPEED * Game.FLAP_SPEED / (2.0 * Game.GRAVITY)
	check(lift > 100.0 and Game.STEP_CAP <= 3.0 * lift, "the biggest gap step is 3 flaps or less (one lifts %.0f px)" % lift)
	check(is_equal_approx(Game.gap_at(50, true), Game.GAP_MIN + 60.0) and is_equal_approx(Game.gap_at(5, true), Game.gap_at(5) + 60.0), "relaxed: +60 px every gap, also at the cap")
	check(is_equal_approx(Game.speed_at(100, true), 280.0) and is_equal_approx(Game.speed_at(0, true), 200.0) and Game.speed_at(100, true) < Game.speed_at(100), "relaxed: the scroll stops at 280")
	# level: 1 + gates cleared / 5, capped at 7 (gate 30)
	check(Game.level_for(0) == 1 and Game.level_for(4) == 1 and Game.level_for(5) == 2 and Game.level_for(29) == 6, "a level every 5 gates")
	check(Game.level_for(30) == 7 and Game.level_for(31) == 7 and Game.level_for(500) == 7 and Game.LEVEL_CAP == 7, "level 7 at gate 30 and no higher")
	# bobbing in the generated lounges
	var early := 0
	var late := 0
	var late_n := 0
	for sd in range(1, 31):
		var c: Dictionary = Game.course(sd, 50)
		for i in 50:
			if c["phase"][i] >= 0.0:
				if i < Game.MOVE_FROM:
					early += 1
				elif i >= 30:
					late += 1
			if i >= 30:
				late_n += 1
	check(early == 0, "only gates from 7 on bob")
	var share := float(late) / float(late_n)
	check(share > 0.58 and share < 0.82, "about 70 %% of the gates past the cap bob (%.0f %%)" % (100.0 * share))


## A simple flyer: flutter whenever it sinks below the next gap's centre (where it is now: gaps bob) plus `slop`.
## react: seconds of delay before it sees where the gap is; jitter: up to this many seconds late on each tap (seeded).
## Sharp (react 0, slop 60) it clears 27-70 gates (mean ~41) on any lounge, past the cap at gate 30 on most nights
## (calibrated 2026-11-20 on a port of the rules over 60 lounges); react 0.2 / slop 70 / jitter 0.1 plays like an
## average player (~15-20 gates, ~75-100 points; relaxed ~20-25).
func fly_bot(g: Control, max_secs := 150.0, react := 0.0, slop := 60.0, jitter := 0.0, dt := STEP) -> void:
	var t := 0.0
	var seen: Array = []  # [time, target] samples for the delay
	var rng := RandomNumberGenerator.new()
	rng.seed = g.seed_used * 7 + 1
	var pending := -1.0
	while not g.done and t < max_secs:
		var n: int = g.next_gate()
		var target: float = g.gap_center(n)
		if react > 0.0:
			seen.append([t, target])
			while seen.size() > 1 and seen[1][0] <= t - react:
				seen.pop_front()
			target = seen[0][1]
		if pending < 0.0 and g.state != Game.State.INTRO and g.y > target + slop and g.vy >= 0.0:
			pending = t + (rng.randf_range(0.0, jitter) if jitter > 0.0 else 0.0)
		if pending >= 0.0 and t >= pending:
			g.flap()
			pending = -1.0
		g.advance(dt)
		t += dt


func test_good_flyer() -> void:
	print("[play] a sharp bot flies well past the old 20-gate flight, up to the cap; only the third singe ends it")
	var at_cap := 0
	var seeds := [20261115, 1, 7, 99, 2026]
	for sd in seeds:
		var g := spawn({"seed": sd})
		fly_bot(g)
		check(g.done and g.singes_left == 0 and g.end_reason == "lost", "seed %d: the flight ends only on the third singe" % sd)
		check(g.gates_passed > Game.GATES, "seed %d: past the old 20-gate flight (%d gates)" % [sd, g.gates_passed])
		check(int(_result.get("points", 0)) > 100 and int(_result.get("points", 0)) == g.record_points(), "seed %d: the record goes past 100 (%d)" % [sd, int(_result.get("points", 0))])
		check(is_equal_approx(float(_result.get("score", 0.0)), 1.0) and int(_result.get("tier", -9)) == 2, "seed %d: the need score stops at 1.0" % sd)
		var ex: Dictionary = _result.get("extra", {})
		check(int(ex.get("level", 0)) == g.ramp_level and g.ramp_level == Game.level_for(g.gates_cleared), "seed %d: level %d sent with the result" % [sd, g.ramp_level])
		check(int(ex.get("misses", -1)) == 3 and float(ex.get("speed", 0.0)) >= Game.SPEED_START, "seed %d: misses 3 and the speed sent" % sd)
		check(not ex.has("sign"), "seed %d: no sign any more" % sd)
		if g.ramp_level == Game.LEVEL_CAP:
			at_cap += 1
			check(is_equal_approx(g.speed(), Game.SPEED_CAP), "seed %d: at the top level the scroll is at its cap" % sd)
		if sd == 20261115:
			check(_result.get("action_id", "") == "neon_moth" and int(ex.get("seed", 0)) == 20261115, "result names the action and the seed")
		g.queue_free()
	check(at_cap >= 2, "the sharp bot reaches level 7 (gate 30+) on most lounges (%d of %d)" % [at_cap, seeds.size()])


func test_idle_and_singes() -> void:
	print("[play] never tapping singes three times and loses on exactly the third")
	var g := spawn()
	var t := 0.0
	var wings := Game.SINGES
	var early_end := false
	while not g.done and t < 60.0:
		g.advance(STEP)
		t += STEP
		if g.singes_left < wings:
			wings = g.singes_left
			if wings > 0 and g.done:
				early_end = true
	check(not early_end, "one or two singes never end the flight")
	check(g.done and g.singes_left == 0 and g.end_reason == "lost", "the third singe loses (end_reason %s)" % g.end_reason)
	check(t < 15.0, "it ends quickly (%.1f s)" % t)
	check(bool(_result.get("miss", false)) and int(_result.get("points", -1)) <= 10, "an idle flight is a miss with almost no points: a blink may drift through a gate (%s points, %d gates)" % [str(_result.get("points")), g.gates_passed])
	var ex: Dictionary = _result.get("extra", {})
	check(int(ex.get("level", 0)) == 1 and int(ex.get("misses", 0)) == 3, "result extra: level 1, misses 3")
	g.queue_free()
	var r := spawn({"seed": 5})
	r.relaxed = true
	check(r.gap_size() > Game.GAP, "relaxed timing widens the gaps")
	r.queue_free()
	var k := spawn()
	fly_bot(k, 12.0)
	var before: int = k.gates_passed
	k.abandon()
	check(int(_result.get("extra", {}).get("gates", -1)) == before and int(_result.get("points", -1)) == Game.points_at(before), "leaving keeps the gates and points so far")
	check(k.end_reason == "", "leaving is not a loss")
	k.queue_free()


func test_tap_input() -> void:
	print("[input] a tap flutters")
	var g := spawn()
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	g._gui_input(e)
	check(g.state == Game.State.FLYING and g.vy < 0.0, "the first tap starts the flight with a flutter")
	g.queue_free()


func test_action_strings_registry() -> void:
	print("[needs + strings + registry]")
	var def: Dictionary = Rules.ACTIONS.get("neon_moth", {})
	check(def.get("gains", {}).get("nightlife", []) == [10.0, 20.0], "Nightlife [10, 20]")
	check(not def.has("cap_per_visit"), "no cap, like pinball")
	var keys := {}
	for r in S.rows():
		keys[r["key"]] = r
	for suffix in ["title", "subtitle", "how_to", "tier_1", "tier_2", "tier_3", "hint", "row", "row_sub"]:
		var k: String = "mg.neon_moth." + suffix
		check(keys.has(k) and keys[k]["en"] != "" and keys[k]["th"] != "", "string " + k)
	for k in ["mg.rivals.you", "mg.rivals.to_beat", "mg.rivals.you_now", "mg.rivals.passed", "mg.rivals.ghost", "mg.result.board",
			"mg.ramp.level", "mg.ramp.status", "mg.ramp.strike", "mg.ramp.last"]:
		check(keys.has(k) and keys[k]["en"] != "" and keys[k]["th"] != "", "string " + k)
	check(Session.GAMES.has("neon_moth") and ResourceLoader.exists(Session.GAMES["neon_moth"]), "venue registry has the scene")
	check(Session.ROW_GAMES.get("moth", "") == "neon_moth", "the cabinet row counts its tries")
	var g := spawn()
	check(g.last_status == S.t("mg.ramp.status", {"level": 1, "points": 0, "lives": 3}), "status line: level, points, lives (%s)" % g.last_status)
	g.queue_free()


func test_on_screen() -> void:
	print("[ramp in play] several gates on screen, the scroll speeds up, the level climbs")
	var h := spawn()
	var v0: float = h.speed()
	var t := 0.0
	var most := 0
	var frames := 0
	var several := 0
	var levels: Array[int] = [1]
	while not h.done and t < 40.0:
		var n: int = h.next_gate()
		if h.state != Game.State.INTRO and h.y > h.gap_center(n) + 60.0 and h.vy >= 0.0:
			h.flap()
		h.advance(STEP)
		t += STEP
		if h.ramp_level != levels[levels.size() - 1]:
			levels.append(h.ramp_level)
		if h.state == Game.State.FLYING and h.gates_cleared >= 1:
			frames += 1
			most = maxi(most, h.gates_on_screen())
			if h.gates_on_screen() >= 2:
				several += 1
	check(is_equal_approx(v0, 200.0), "the flight starts at 200 px/s")
	check(h.speed() > v0 + 40.0, "the scroll speeds up (%.0f -> %.0f)" % [v0, h.speed()])
	check(most >= 3, "up to 3 gates on screen (%d)" % most)
	check(frames > 0 and float(several) / frames > 0.85, "2+ gates on screen nearly all flight (%.0f %%)" % (100.0 * several / maxi(frames, 1)))
	var steps_ok := levels.size() >= 3
	for i in range(1, levels.size()):
		if levels[i] != levels[i - 1] + 1:
			steps_ok = false
	check(steps_ok, "the level climbs one at a time (%s)" % str(levels))
	check(h.last_status.contains(str(h.ramp_level)), "the status line shows the level (%s)" % h.last_status)
	h.queue_free()


func test_average_and_relaxed() -> void:
	print("[ramp] an average player scores a fair record; relaxed never scores below normal")
	var normal_sum := 0
	var relaxed_sum := 0
	var tiers := {}
	for sd in [3, 11, 20261119, 424242, 77, 5, 8, 13]:
		var g := spawn({"seed": sd})
		fly_bot(g, 240.0, 0.2, 70.0, 0.1, LONG_STEP)
		check(g.done, "seed %d: the average flight ends on its third singe" % sd)
		normal_sum += g.record_points()
		var tier := Base.tier_for(g.current_score())
		tiers[tier] = int(tiers.get(tier, 0)) + 1
		g.queue_free()
		var r := spawn({"seed": sd})
		r.relaxed = true
		fly_bot(r, 240.0, 0.2, 70.0, 0.1, LONG_STEP)
		relaxed_sum += r.record_points()
		r.queue_free()
	print("    average bot tiers ", tiers, " normal %.0f relaxed %.0f points" % [normal_sum / 8.0, relaxed_sum / 8.0])
	check(normal_sum / 8.0 > 40.0 and normal_sum / 8.0 < 160.0, "an average player's mean record is fair (%.0f points)" % (normal_sum / 8.0))
	check(int(tiers.get(Base.TIER_MISS, 0)) <= 2, "an average run rarely misses")
	check(relaxed_sum >= normal_sum, "relaxed scores at least normal for the same player (%d vs %d)" % [relaxed_sum, normal_sum])


func test_art_and_juice() -> void:
	print("[art + juice] voxel sprites drawn; every §2.3 beat answers; LEVEL and strike pops")
	var g := spawn()
	check(g.has_art(), "all Neon Moth sprites load (import first)")
	var f = g.fx()
	f.auto_step = false
	g.flap()
	check(f.squash_scale("moth") != Vector2.ONE, "tap: wing snap (squash)")
	check(f.particles_alive() > 0, "tap: ember puff")
	g.queue_free()
	var h := spawn()
	var hf = h.fx()
	hf.auto_step = false
	var t := 0.0
	var popped := false
	while not h.done and h.gates_passed < 4 and t < 30.0:
		var n: int = h.next_gate()
		if h.state != Game.State.INTRO and h.y > h.gap_center(n) + 30.0 and h.vy >= 0.0:
			h.flap()
		h.advance(STEP)
		t += STEP
		if h.gates_passed >= 1 and hf.pops_alive() > 0:
			popped = true
	check(popped, "gate passed: +5 pop")
	check(hf.combo >= 3, "clean gates build the combo (%d)" % hf.combo)
	# singe: drive the moth into the floor
	var wings: int = h.singes_left
	var pops0: int = hf.pops_alive()
	h.blink = 0.0
	h.vy = Game.MAX_FALL
	h.y = Game.FIELD.y - Game.MOTH_R - 1.0
	h.advance(STEP)
	check(h.singes_left == wings - 1, "a bump singes a wing")
	check(hf.pops_alive() > pops0, "singe: a strike pop (lives left)")
	check(hf.edge_amount() > 0.0, "singe: red edge")
	check(hf.combo == 0, "singe: the combo breaks")
	check(hf.squash_scale("wing%d" % h.singes_left) != Vector2.ONE, "singe: the wing icon breaks (squash)")
	check(not h.done, "a singe with wings left goes on")
	h.queue_free()
	# level up: the fifth gate cleared raises level 2 with a pop
	var k := spawn()
	var kf = k.fx()
	kf.auto_step = false
	t = 0.0
	while not k.done and k.gates_cleared < Game.LEVEL_GATES and t < 40.0:
		var n2: int = k.next_gate()
		if k.state != Game.State.INTRO and k.y > k.gap_center(n2) + 60.0 and k.vy >= 0.0:
			k.flap()
		var lv: int = k.ramp_level
		var p0: int = kf.pops_alive()
		k.advance(STEP)
		t += STEP
		if k.ramp_level > lv:
			check(kf.pops_alive() > p0, "level up: a LEVEL pop")
	check(k.ramp_level == 2, "5 gates cleared: level 2 (%d)" % k.ramp_level)
	k.queue_free()


func test_rivals_api() -> void:
	print("[rivals] seeded regulars, board, the next rung, tonight's best and ghost")
	var s2 := Store.new()
	var n := 20000
	check(Rivals.regular_points("neon_moth", "hiro", n) == Rivals.regular_points("neon_moth", "hiro", n), "a regular's score is fixed for the night")
	var diff := false
	for k in 5:
		if Rivals.regular_points("neon_moth", "hiro", n + k + 1) != Rivals.regular_points("neon_moth", "hiro", n):
			diff = true
	check(diff, "and changes from night to night")
	var hiro := 0.0
	var nop := 0.0
	for k in 40:
		hiro += Rivals.regular_points("neon_moth", "hiro", n + k)
		nop += Rivals.regular_points("neon_moth", "lung_nop", n + k)
	check(hiro > nop + 20.0 * 40.0, "Hiro plays far better than Lung Nop on average")
	var line := Rivals.lineup("neon_moth", n)
	var uniq := {}
	for r in line:
		uniq[r] = true
	check(line.size() == Rivals.PLAYERS_A_NIGHT and uniq.size() == line.size(), "4 different regulars a night")
	check(Rivals.lineup("neon_moth", n) == line, "same lineup all night")
	var b := Rivals.board("neon_moth", 50, n)
	var sorted_ok := true
	for i in range(1, b.size()):
		if int(b[i]["points"]) > int(b[i - 1]["points"]):
			sorted_ok = false
	check(b.size() == 5 and sorted_ok, "board: 4 regulars + you, best first")
	var regs := Rivals.board("neon_moth", -1, n)
	var low := int(regs[regs.size() - 1]["points"])
	var top := int(regs[0]["points"])
	check(int(Rivals.to_beat("neon_moth", 0, n)["points"]) == low, "no best yet: the lowest regular is the one to beat")
	check(int(Rivals.to_beat("neon_moth", top + 1, n)["points"]) == top, "above everyone: the top regular stays the mark")
	var mid := int(regs[1]["points"])
	var tb := Rivals.to_beat("neon_moth", mid - 1, n)
	check(int(tb["points"]) >= mid - 1 and int(tb["points"]) <= mid and str(tb["name"]) != "", "the next rung above your best, with a name")
	check(Rivals.tonight("neon_moth", s2, n)["best"] == 0, "no best tonight yet")
	var r1 := Rivals.record("neon_moth", 40, {"seed": 1, "ys": [1, 2]}, s2, n)
	check(r1["new_best"] and r1["best"] == 40, "first run is tonight's best")
	var r2 := Rivals.record("neon_moth", 30, {"seed": 1, "ys": [9]}, s2, n)
	check(not r2["new_best"] and r2["best"] == 40, "a weaker run keeps the best")
	check(Rivals.tonight("neon_moth", s2, n)["ghost"].get("ys", []) == [1, 2], "the ghost is the best run's")
	check(int(r2["board_line"]["rank"]) >= int(r1["board_line"]["rank"]), "the board line places this run")
	check(Rivals.tonight("neon_moth", s2, n + 1)["best"] == 0 and Rivals.tonight("neon_moth", s2, n + 1)["ghost"].is_empty(), "a new night starts clean")
	check(Rivals.tonight("coaster_flip", s2, n)["best"] == 0, "each game keeps its own night")
	check(JSON.parse_string(JSON.stringify(s2.ext)) is Dictionary, "the record survives the JSON save")
	var lines := Card.competition_lines({"points": 60, "extra": {"board": {"rank": 2, "count": 5}}}, {})
	var has_board := false
	for l in lines:
		if l["id"] == "board" and "2" in str(l["text"]) and "5" in str(l["text"]):
			has_board = true
	check(has_board, "result card shows the board line")


func test_rivals_in_game() -> void:
	print("[rivals in game] the regular to beat, the result lines, the ghost next try, the ghost stays small")
	store = Store.new()
	var g := spawn()
	check(not g.rival.is_empty() and g.rival.has("points") and str(g.rival.get("name", "")) != "", "a regular to beat in play")
	check(g.ghost.is_empty(), "no ghost before the first flight tonight")
	fly_bot(g)
	var ex: Dictionary = _result.get("extra", {})
	check(ex.get("rival") is Dictionary and ex["rival"].has("points"), "result carries the rival")
	check(ex.get("board") is Dictionary and int(ex["board"].get("rank", 0)) >= 1, "result carries the board place")
	check(g.rival_passed == (g.live_points() > int(g.rival["points"])), "passing the regular is flagged in play")
	var points: int = int(_result.get("points", 0))
	check(points == g.record_points(), "the record sent is the uncapped points (%d)" % points)
	g.queue_free()
	var h := spawn()
	var ys: Array = h.ghost.get("ys", [])
	check(ys.size() > 100, "the next try flies with tonight's best as a ghost (%d samples)" % ys.size())
	check(ys.size() <= Game.GHOST_MAX, "the ghost stays within its cap")
	h.flap()
	for i in 240:
		h.advance(STEP)
	check(not is_nan(h.ghost_y_at(h.scroll)), "the ghost has a height mid-flight")
	check(int(Rivals.tonight("neon_moth", store)["best"]) == points, "tonight's best is that flight")
	h.queue_free()
	var other := spawn({"seed": 99})
	check(other.ghost.is_empty(), "a ghost from another lounge layout is not shown")
	other.queue_free()
	# a very long flight: the recorded ghost stops at GHOST_MAX samples (the save stays small)
	var k := spawn()
	k.flap()
	k.blink = 1000.0                   # no singes while the flight jumps far down the lounge
	k.scroll = Game.GHOST_STEP * float(Game.GHOST_MAX + 500)
	k.advance(STEP)
	check(k.ghost_ys.size() == Game.GHOST_MAX, "ghost capped at %d samples (%d)" % [Game.GHOST_MAX, k.ghost_ys.size()])
	check(k.ghost_data()["ys"].size() == Game.GHOST_MAX, "ghost data capped too")
	check(not k.done and k.gap_y.size() > Game.GHOST_MAX * Game.GHOST_STEP / Game.SPACING_START, "the lounge kept generating ahead (%d gates)" % k.gap_y.size())
	k.abandon()
	k.queue_free()
