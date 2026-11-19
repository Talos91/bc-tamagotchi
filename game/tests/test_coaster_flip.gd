extends SceneTree
## Headless tests for Coaster Flip (docs/design/10-minigame-next.md §A): rules, scoring tiers, scripted players,
## the swipe gesture, the action's gains and cap, strings and the venue registry. Q5 (11-minigame-quality): clarity
## cues (coach, closing ring, early/late), voxel art, every §2.3 beat via mg_fx, the §3 drift ramp, mg_rivals.
##   godot --headless --path . --script res://tests/test_coaster_flip.gd
## Exit code 0 = all pass.

const Rules = preload("res://scripts/rules.gd")
const NeedsScript = preload("res://scripts/needs.gd")
const Base = preload("res://scripts/minigames/minigame_base.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Game = preload("res://scripts/minigames/coaster_flip.gd")
const Session = preload("res://scripts/zones/venue_session.gd")
const Rivals = preload("res://scripts/minigames/mg_rivals.gd")

const T0 := 1_800_000_000.0
const STEP := 1.0 / 120.0

## Stands in for Needs: mg_rivals only reads and writes `ext`.
class Store:
	extends RefCounted
	var ext := {}


var failures := 0
var checks := 0
var _result: Dictionary = {}
var store := Store.new()


func _initialize() -> void:
	test_rules()
	test_perfect_player()
	test_clumsy_player()
	test_no_catch_and_time_limit()
	test_swipe_and_regular()
	test_human_player()
	test_action()
	test_strings_and_registry()
	test_clarity()
	test_ramp_drift()
	test_average_and_relaxed()
	test_art_and_juice()
	test_rivals_in_game()
	# a game script that fails to compile makes every test error out before any check runs: never call that a pass
	check(checks >= 100, "the suite ran its checks (%d)" % checks)
	print("")
	print("%d checks, %d failed" % [checks, failures])
	print("COASTER FLIP TESTS ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("  FAIL: ", msg)


func spawn(config := {}) -> Control:
	var g: Control = Game.new()
	g.size = Vector2(1080, 1400)
	g.config = config
	g.rivals_store = store
	root.add_child(g)
	_result = {}
	g.finished.connect(func(r: Dictionary) -> void: _result = r)
	g.start()
	return g


func run_for(g: Control, secs: float) -> void:
	var t := 0.0
	while t < secs and not g.done:
		g.advance(STEP)
		t += STEP


## Advances until the coasters are flat inside the catch window (or the flight ends).
func wait_flat(g: Control) -> void:
	var guard := 0
	while g.state == Game.State.FLIGHT and guard < 1000:
		if g.catchable() and g.alignment() >= Game.flat_needed(g.run) + 0.02:
			return
		g.advance(STEP)
		guard += 1


func test_rules() -> void:
	print("[rules] spin, flat threshold, score tiers")
	check(Game.spin_rate(5) > Game.spin_rate(0), "each catch spins faster")
	check(Game.flat_needed(5) > Game.flat_needed(0), "each catch needs flatter coasters")
	check(Game.flat_needed(50) <= Game.FLAT_MAX, "the threshold is capped")
	check(Game.flat_needed(3, true) < Game.flat_needed(3), "relaxed timing widens the catch")
	check(is_equal_approx(Game.flatness(0, Game.FLIGHT_SECONDS * 0.5), 1.0), "flat at the top of the arc, in the ring")
	check(Base.tier_for(Game.score_for(2, [1.0, 1.0])) == Base.TIER_MISS, "a best run of 2 is a miss")
	check(Base.tier_for(Game.score_for(3, [0.8, 0.8, 0.8])) == 0, "a run of 3 is good")
	check(Base.tier_for(Game.score_for(7, [0.9, 0.9, 0.9, 0.9, 0.9, 0.9, 0.9])) == 1, "a run of 7 is great")
	var tens: Array = []
	for i in 10:
		tens.append(0.8)
	check(Base.tier_for(Game.score_for(10, tens)) == 2, "a run of 10 is perfect")
	check(Game.score_for(0, []) == 0.0, "nothing caught scores 0")


func test_perfect_player() -> void:
	print("[play] a bot that taps on every flat moment")
	var g := spawn()
	run_for(g, Game.INTRO_SECONDS + 0.05)
	check(g.state == Game.State.READY, "ready after the intro")
	var guard := 0
	while not g.done and guard < 40:
		g.flick()
		check(g.state == Game.State.FLIGHT, "flick sends the stack up")
		wait_flat(g)
		g.tap()
		run_for(g, Game.RESULT_SECONDS + 0.02)
		guard += 1
	check(g.done, "the round ends")
	check(g.best_run == Game.FULL_RUN, "ten catches in a row (%d)" % g.best_run)
	check(g.drops_left == Game.DROPS, "no drops")
	check(int(_result.get("tier", -9)) == 2, "perfect tier (%s)" % str(_result.get("score")))
	check(_result.get("game_id", "") == "coaster_flip" and _result.get("action_id", "") == "coaster_flip", "result names the game and action")
	check(int(_result.get("extra", {}).get("best_run", 0)) == Game.FULL_RUN, "result extra carries the best run")
	g.queue_free()


func test_clumsy_player() -> void:
	print("[play] tapping at the flick, before the catch window, drops every time")
	var g := spawn()
	run_for(g, Game.INTRO_SECONDS + 0.05)
	for i in Game.DROPS:
		g.flick()
		g.tap()
		check(g.state == Game.State.DROPPED, "early tap drops (%d)" % i)
		run_for(g, Game.RESULT_SECONDS + 0.02)
	check(g.done, "three drops end the round")
	check(bool(_result.get("miss", false)), "nothing caught is a miss")
	g.queue_free()


func test_no_catch_and_time_limit() -> void:
	print("[play] no tap drops at the end of the flight; idling ends at the time limit")
	var g := spawn()
	run_for(g, Game.INTRO_SECONDS + 0.05)
	g.flick()
	run_for(g, Game.FLIGHT_SECONDS + 0.05)
	check(g.drops_left == Game.DROPS - 1, "an uncaught flip is a drop")
	g.queue_free()
	var h := spawn()
	run_for(h, Game.TIME_LIMIT + Game.INTRO_SECONDS + 1.0)
	check(h.done, "the round ends at the time limit")
	check(is_equal_approx(float(_result.get("score", 1.0)), 0.0), "idle scores 0")
	h.queue_free()
	# a mid-run leave keeps the best run so far
	var k := spawn()
	run_for(k, Game.INTRO_SECONDS + 0.05)
	for i in 4:
		k.flick()
		wait_flat(k)
		k.tap()
		run_for(k, Game.RESULT_SECONDS + 0.02)
	check(k.best_run == 4, "four caught")
	k.abandon()
	check(int(_result.get("tier", -9)) == 0, "leaving after 4 keeps a good round")
	k.queue_free()


func test_swipe_and_regular() -> void:
	print("[input] swipe up flicks, a tap in the air catches; the table's regular stays on the result")
	store = Store.new()
	var g := spawn({"regular": "tt"})
	check(g.regular == "tt", "the table's regular is Tt")
	run_for(g, Game.INTRO_SECONDS + 0.05)
	_mouse(g, true, Vector2(500, 1100))
	_mouse(g, false, Vector2(500, 1100))
	check(g.state == Game.State.READY, "a tap on the table does not flick")
	check(g._nudge > 0.0, "a tap instead of a swipe is answered (swipe-up nudge)")
	_mouse(g, true, Vector2(500, 1100))
	_mouse(g, false, Vector2(500, 1000))
	check(g.state == Game.State.FLIGHT, "a swipe up flicks")
	wait_flat(g)
	_mouse(g, true, Vector2(500, 600))
	check(g.state == Game.State.CAUGHT and g.run == 1, "touch-down in the air catches")
	_mouse(g, false, Vector2(500, 600))
	run_for(g, Game.RESULT_SECONDS + 0.02)
	# the flick fires during the drag, as soon as the finger is SWIPE_PX up (no wait for the lift)
	_mouse(g, true, Vector2(500, 1100))
	var m := InputEventMouseMotion.new()
	m.position = Vector2(500, 1100 - Game.SWIPE_PX - 1.0)
	g._gui_input(m)
	check(g.state == Game.State.FLIGHT, "the drag itself flicks once far enough up")
	_mouse(g, false, Vector2(500, 900))
	check(g.state == Game.State.FLIGHT, "the lift after a drag-flick does nothing more")
	g.abandon()
	check(str(_result.get("extra", {}).get("regular", "")) == "tt", "result extra keeps the table's regular (hearts)")
	g.queue_free()
	# a swipe during the intro starts at once
	var h := spawn({"regular": "nobody_here"})
	_mouse(h, true, Vector2(500, 1100))
	_mouse(h, false, Vector2(500, 900))
	check(h.state == Game.State.FLIGHT, "a swipe in the intro flicks at once")
	check(h.loaded_regulars() <= 1, "an unknown host loads no table sprite")
	h.queue_free()


func _mouse(g: Control, pressed: bool, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	g._gui_input(e)


func test_action() -> void:
	print("[needs] coaster_flip feeds Friends 8-12, at most 20 a visit")
	var def: Dictionary = Rules.ACTIONS.get("coaster_flip", {})
	check(def.get("gains", {}).get("friends", []) == [8.0, 12.0], "Friends [8, 12]")
	check(float(def.get("cap_per_visit", 0.0)) == 20.0, "cap 20 per visit")
	var n: Node = NeedsScript.new()
	n.autosave = false
	n.time_override = T0
	n.save_path = "user://test_coaster_flip_save.json"
	n.new_game()
	root.add_child(n)
	for m in n.meters:
		n.meters[m] = 20.0
	var r1: Dictionary = n.apply_action("coaster_flip", 1.0)
	check(float(r1.get("gains", {}).get("friends", 0.0)) > 0.0, "a perfect round gains Friends")
	var r2: Dictionary = n.apply_action("coaster_flip", 1.0)
	check(bool(r2.get("ok", false)), "a second round still counts (the 8 left under the cap)")
	var r3: Dictionary = n.apply_action("coaster_flip", 1.0)
	check(not bool(r3.get("ok", true)) and r3.get("reason", "") == "cap_reached", "a third round hits the cap")
	check(is_equal_approx(float(n.visit_action_totals.get("coaster_flip", 0.0)), 20.0), "20 base points used this visit")
	n.queue_free()


func test_strings_and_registry() -> void:
	print("[strings + registry]")
	var keys := {}
	for r in S.rows():
		keys[r["key"]] = r
	for suffix in ["title", "subtitle", "how_to", "tier_1", "tier_2", "tier_3", "status", "hint_flick", "hint_catch", "row", "row_with", "row_sub"]:
		var k: String = "mg.coaster_flip." + suffix
		check(keys.has(k) and keys[k]["en"] != "" and keys[k]["th"] != "", "string " + k)
	check(Session.GAMES.has("coaster_flip") and ResourceLoader.exists(Session.GAMES["coaster_flip"]), "venue registry has the scene")
	check(Session.ROW_GAMES.get("coaster", "") == "coaster_flip", "the tall-table row counts its tries")
	var inst: Node = load(Session.GAMES["coaster_flip"]).instantiate()
	check(inst.get("game_id") == "coaster_flip", "the scene runs the game script")
	inst.free()


## Item 37 (0.3.1): a person, not a frame-perfect bot. The ring must light once per flight, only with the stack in it,
## and a player who taps a human reaction time after it lights, or aims at the top of the arc, must catch. Before the
## fix the ring flickered 3-5 times a flight for 50-190 ms and a 200 ms reaction never caught.
func test_human_player() -> void:
	print("[human] one glow per flight, in the ring; reacting or aiming at the top catches")
	for run in [0, 3, 6, 9]:
		var onsets: Array[float] = []
		var prev := false
		var t := 0.0
		while t < Game.FLIGHT_SECONDS:
			var lit := Game.in_ring(t) and Game.flatness(run, t) >= Game.flat_needed(run)
			if lit and not prev:
				onsets.append(t)
			prev = lit
			t += 1.0 / 240.0
		check(onsets.size() == 1, "run %d: the ring lights once per flight (%d)" % [run, onsets.size()])
	# Reacting to the glow: tap 150 ms after it lights, early stacks
	for run in [0, 2]:
		var g := spawn()
		run_for(g, Game.INTRO_SECONDS + 0.05)
		for i in run:
			g.flick()
			wait_flat(g)
			g.tap()
			run_for(g, Game.RESULT_SECONDS + 0.02)
		g.flick()
		while g.state == Game.State.FLIGHT and not (g.catchable() and g.alignment() >= Game.flat_needed(g.run)):
			g.advance(STEP)
		run_for(g, 0.15)
		g.tap()
		check(g.state == Game.State.CAUGHT and g.run == run + 1, "run %d: a tap 150 ms after the ring lights catches" % run)
		g.queue_free()
	# Aiming at the top of the arc, 30 ms late: a full run of 10
	var h := spawn()
	run_for(h, Game.INTRO_SECONDS + 0.05)
	for i in Game.FULL_RUN:
		h.flick()
		run_for(h, h.apex_time() + 0.03)
		h.tap()
		run_for(h, Game.RESULT_SECONDS + 0.02)
	check(h.best_run == Game.FULL_RUN, "aiming at the top of the arc catches all ten (best %d)" % h.best_run)
	h.queue_free()
	# A tap at the flick, low by the table, drops it
	var k := spawn()
	run_for(k, Game.INTRO_SECONDS + 0.05)
	k.flick()
	run_for(k, 0.05)
	k.tap()
	check(k.state == Game.State.DROPPED, "a tap by the table, outside the ring, drops the stack")
	k.queue_free()
	# relaxed keeps one glow a flight
	for run in [0, 9]:
		var on := 0
		var was := false
		var t2 := 0.0
		while t2 < Game.FLIGHT_SECONDS:
			var lit2 := Game.catch_window(run, t2) and Game.flatness(run, t2) >= Game.flat_needed(run, true)
			if lit2 and not was:
				on += 1
			was = lit2
			t2 += 1.0 / 240.0
		check(on == 1, "relaxed, run %d: still one glow a flight (%d)" % [run, on])


## Q5 (Daniele 2026-11-18: "very unclear"): what to do, when, and why a miss happened must read on screen.
func test_clarity() -> void:
	print("[clarity] coach lines, the closing ring, the catch label, early/late on a drop")
	var keys := {}
	for r in S.rows():
		keys[r["key"]] = r
	for suffix in ["goal", "zone", "nudge", "early", "late", "early_hint", "late_hint", "ghost"]:
		var k: String = "mg.coaster_flip." + suffix
		check(keys.has(k) and keys[k]["en"] != "" and keys[k]["th"] != "", "string " + k)
	var g := spawn()
	check(g.closing() < 0.0, "no closing ring before the flick")
	run_for(g, Game.INTRO_SECONDS + 0.05)
	g.flick()
	check(is_equal_approx(g.closing(), 1.0), "the closing ring starts wide at the flick")
	run_for(g, g.apex_time() * 0.5)
	var mid: float = g.closing()
	check(mid > 0.3 and mid < 0.7, "halfway up it is halfway in (%.2f)" % mid)
	while g.state == Game.State.FLIGHT and g.flight_t < g.apex_time():
		g.advance(STEP)
	check(absf(g.closing()) < 0.02, "the rings meet at the top of the arc")
	check(g.ring_lit(), "and the ring is lit right there")
	g.tap()
	check(g.state == Game.State.CAUGHT, "tapping when the rings meet catches")
	check(g.catches == 1, "catches counted (the coach's catch line goes after the first)")
	run_for(g, Game.RESULT_SECONDS + 0.02)
	g.flick()
	run_for(g, 0.1)
	g.tap()
	check(g.state == Game.State.DROPPED and g.drop_reason == "early", "a tap before the top is too early")
	run_for(g, Game.RESULT_SECONDS + 0.02)
	g.flick()
	run_for(g, g.apex_time() + 0.3)
	g.tap()
	check(g.state == Game.State.DROPPED and g.drop_reason == "late", "a tap after the top is too late")
	run_for(g, Game.RESULT_SECONDS + 0.02)
	g.flick()
	run_for(g, g.flight_dur + 0.05)
	check(g.drop_reason == "late", "no tap at all is too late")
	g.queue_free()
	# the stack rises from the table into the ring and lands back
	var h := spawn()
	run_for(h, Game.INTRO_SECONDS + 0.05)
	var base: Vector2 = h.stack_pos()
	h.flick()
	while h.flight_t < h.apex_time():
		h.advance(STEP)
	var top: Vector2 = h.stack_pos()
	check(top.distance_to(h.ring_now) < 20.0, "at the top of the arc the stack is in the ring")
	check(top.y < base.y - 250.0, "the flight goes well up from the table")
	h.tap()
	run_for(h, Game.LAND_SECONDS + 0.01)
	check(h.stack_pos().distance_to(base) < 1.0, "a caught stack lands back on the table")
	check(Game.spin_frame(0.0) == 0 and Game.spin_frame(0.25) == 2 and Game.spin_frame(0.5) == 4 and Game.spin_frame(-0.25) == 6, "spin frames: flat, edge on, flat bottom up")
	h.queue_free()


## §3: as built (spin and flat need tighten per catch); from catch DRIFT_FROM the ring drifts and the flight time moves.
func test_ramp_drift() -> void:
	print("[ramp] the ring stays put early, drifts from catch %d; flight time follows its height" % Game.DRIFT_FROM)
	check(is_equal_approx(Game.flight_for(Game.TABLE_Y - Game.RING_REST.y), Game.FLIGHT_SECONDS), "ring at rest: the old flight")
	check(Game.flight_for(500.0) > Game.FLIGHT_SECONDS and Game.flight_for(300.0) < Game.FLIGHT_SECONDS, "higher ring, longer flight")
	var g := spawn({"seed": 4242})
	run_for(g, Game.INTRO_SECONDS + 0.05)
	var moved := 0
	var durs := {}
	var guard := 0
	while not g.done and guard < 30:
		var before: int = g.run
		g.flick()
		if before < Game.DRIFT_FROM:
			check(g.ring_center() == Game.RING_REST, "catch %d: the ring is at rest" % before)
		elif g.ring_center() != Game.RING_REST:
			moved += 1
			durs[snappedf(g.flight_dur, 0.01)] = true
		wait_flat(g)
		g.tap()
		run_for(g, Game.RESULT_SECONDS + 0.02)
		guard += 1
	check(g.best_run == Game.FULL_RUN, "a bot still catches all ten with the drift (%d)" % g.best_run)
	check(moved >= 3, "the ring drifted on the late catches (%d)" % moved)
	check(durs.size() >= 2, "drifting changes the flight time (%d values)" % durs.size())
	check(g.drops_left == Game.DROPS, "no drops")
	g.queue_free()
	# a drop sends the ring home
	var h := spawn({"seed": 4242})
	run_for(h, Game.INTRO_SECONDS + 0.05)
	for i in Game.DRIFT_FROM:
		h.flick()
		wait_flat(h)
		h.tap()
		run_for(h, Game.RESULT_SECONDS + 0.02)
	check(h.ring_center() != Game.RING_REST, "after %d catches the ring has drifted" % Game.DRIFT_FROM)
	h.flick()
	h.tap()
	check(h.ring_center() == Game.RING_REST, "a drop sends the ring home")
	h.queue_free()


## A person: aims at the top of the arc with a reaction jitter. Average lands above a miss; relaxed scores >= normal.
func play_human(seed_v: int, sigma: float, is_relaxed: bool) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var g := spawn({"seed": seed_v})
	g.relaxed = is_relaxed
	run_for(g, Game.INTRO_SECONDS + 0.05)
	var guard := 0
	while not g.done and guard < 60:
		if g.state == Game.State.READY:
			g.flick()
			var at: float = g.apex_time() + rng.randfn(0.0, sigma)
			while g.state == Game.State.FLIGHT and g.flight_t < at:
				g.advance(STEP)
			g.tap()
		run_for(g, Game.RESULT_SECONDS + 0.02)
		guard += 1
	if not g.done:
		g.abandon()
	var sc := float(_result.get("score", 0.0))
	g.queue_free()
	return sc


func test_average_and_relaxed() -> void:
	print("[players] sharp, average and sloppy hands; relaxed never scores less")
	var sums := {}
	for kind in [["sharp", 0.02], ["average", 0.06], ["sloppy", 0.11]]:
		for rl in [false, true]:
			var tot := 0.0
			for n in 8:
				tot += play_human(1000 + n, kind[1], rl)
			sums["%s%s" % [kind[0], "_r" if rl else ""]] = tot / 8.0
	print("  mean scores: ", sums)
	check(float(sums["sharp"]) >= Base.TIER_PERFECT - 0.05, "a sharp hand reaches perfect-ish (%.2f)" % sums["sharp"])
	check(float(sums["average"]) >= Rules.MINIGAME_MISS_BELOW and float(sums["average"]) < float(sums["sharp"]), "an average hand lands above a miss (%.2f)" % sums["average"])
	check(float(sums["sloppy"]) < float(sums["average"]), "a sloppy hand scores less (%.2f)" % sums["sloppy"])
	for k in ["sharp", "average", "sloppy"]:
		check(float(sums[k + "_r"]) >= float(sums[k]) - 0.001, "relaxed scores at least normal: %s (%.2f vs %.2f)" % [k, sums[k + "_r"], sums[k]])


func test_art_and_juice() -> void:
	print("[art + juice] voxel sprites; every §2.3 beat answers")
	store = Store.new()
	var g := spawn({"regular": "jules"})
	check(g.has_art(), "all Coaster Flip sprites load (import first)")
	check(g._art.has("regular_jules"), "the table's regular sprite loads")
	check(g.loaded_regulars() <= 2, "at most two regular sprites loaded (memory rule: %d)" % g.loaded_regulars())
	var f = g.fx()
	f.auto_step = false
	run_for(g, Game.INTRO_SECONDS + 0.05)
	g.flick()
	check(f.squash_scale("stack") != Vector2.ONE, "swipe: the stack whooshes (squash)")
	check(f.particles_alive() > 0, "swipe: a puff off the table")
	while g.state == Game.State.FLIGHT and not g.ring_lit():
		g.advance(STEP)
	check(f.flash_amount("ring") > 0.0, "ring flat: the ring pulses")
	var pops: int = f.pops_alive()
	g.tap()
	check(g.state == Game.State.CAUGHT, "caught")
	check(f.pops_alive() > pops, "catch: +1 pop")
	check(g.hit_stop_left > 0.0, "catch: hit-stop")
	check(g._cheer > 0.0, "catch: the table's regular cheers")
	run_for(g, Game.LAND_SECONDS + 0.02)
	check(g._landed and f.squash_scale("stack") != Vector2.ONE, "the stack lands with a clack (squash)")
	run_for(g, Game.RESULT_SECONDS)
	g.flick()
	g.tap()
	check(g.state == Game.State.DROPPED, "dropped")
	check(f.trauma > 0.0, "drop: shake")
	check(f.edge_amount() > 0.0, "drop: red edge")
	check(f.combo == 0, "drop: the combo breaks")
	check(g._scatter.size() >= 1, "drop: the coasters scatter")
	run_for(g, 1.6)
	check(g._scatter.size() == 0, "the scattered coasters leave the screen")
	g.queue_free()


func test_rivals_in_game() -> void:
	print("[rivals] tonight's regular to beat, the ghost stack, the board line (as Neon Moth)")
	store = Store.new()
	var g := spawn()
	check(not g.rival.is_empty() and g.rival.has("points") and g.rival.has("name"), "a regular to beat tonight")
	check(g.ghost.is_empty(), "no ghost before a first round tonight")
	var target := int(g.rival["points"])
	run_for(g, Game.INTRO_SECONDS + 0.05)
	var guard := 0
	while not g.done and guard < 30:
		g.flick()
		wait_flat(g)
		g.tap()
		run_for(g, Game.RESULT_SECONDS + 0.02)
		guard += 1
	var ex: Dictionary = _result.get("extra", {})
	check(ex.get("rival") is Dictionary and int(ex["rival"].get("points", -1)) == target, "the result names the regular to beat")
	check(ex.get("board") is Dictionary and int(ex["board"].get("rank", 0)) >= 1, "the result carries the board line")
	check(bool(ex.get("beat", false)) == (Base.points_for(float(_result.get("score", 0.0))) > target), "beat = passed the regular's points")
	var mine := Rivals.mine("coaster_flip", store)
	check(int(mine["best"]) == Base.points_for(float(_result.get("score", 0.0))), "tonight's best is kept")
	check(int(mine["ghost"].get("stack", 0)) == Game.FULL_RUN, "the ghost keeps the stack reached")
	g.queue_free()
	var h := spawn()
	check(int(h.ghost.get("stack", 0)) == Game.FULL_RUN, "next round: the ghost stack shows")
	h.queue_free()
	# a weak round does not overwrite tonight's best or ghost
	var k := spawn()
	run_for(k, Game.INTRO_SECONDS + 0.05)
	k.flick()
	wait_flat(k)
	k.tap()
	run_for(k, Game.RESULT_SECONDS + 0.02)
	k.abandon()
	check(int(Rivals.mine("coaster_flip", store)["ghost"].get("stack", 0)) == Game.FULL_RUN, "a weaker round keeps the best ghost")
	k.queue_free()
