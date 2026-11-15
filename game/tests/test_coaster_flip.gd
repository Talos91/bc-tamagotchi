extends SceneTree
## Headless tests for Coaster Flip (docs/design/10-minigame-next.md §A): rules, scoring tiers, scripted players,
## the swipe gesture, the action's gains and cap, strings and the venue registry.
##   godot --headless --path . --script res://tests/test_coaster_flip.gd
## Exit code 0 = all pass.

const Rules = preload("res://scripts/rules.gd")
const NeedsScript = preload("res://scripts/needs.gd")
const Base = preload("res://scripts/minigames/minigame_base.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Game = preload("res://scripts/minigames/coaster_flip.gd")
const Session = preload("res://scripts/zones/venue_session.gd")

const T0 := 1_800_000_000.0
const STEP := 1.0 / 120.0

var failures := 0
var checks := 0
var _result: Dictionary = {}


func _initialize() -> void:
	test_rules()
	test_perfect_player()
	test_clumsy_player()
	test_no_catch_and_time_limit()
	test_swipe_and_regular()
	test_action()
	test_strings_and_registry()
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
	check(is_equal_approx(Game.flatness(0, 0.0), 1.0), "flat at the flick")
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
	print("[input] swipe up flicks, a tap in the air catches; the regular's stack to beat")
	var g := spawn({"regular": "tt"})
	check(g.to_beat == 7, "Tt's stack to beat is 7")
	run_for(g, Game.INTRO_SECONDS + 0.05)
	_mouse(g, true, Vector2(500, 1100))
	_mouse(g, false, Vector2(500, 1100))
	check(g.state == Game.State.READY, "a tap on the table does not flick")
	_mouse(g, true, Vector2(500, 1100))
	_mouse(g, false, Vector2(500, 1000))
	check(g.state == Game.State.FLIGHT, "a swipe up flicks")
	wait_flat(g)
	_mouse(g, true, Vector2(500, 600))
	check(g.state == Game.State.CAUGHT and g.run == 1, "touch-down in the air catches")
	_mouse(g, false, Vector2(500, 600))
	run_for(g, Game.RESULT_SECONDS + 0.02)
	for i in 7:
		g.flick()
		wait_flat(g)
		g.tap()
		run_for(g, Game.RESULT_SECONDS + 0.02)
	check(g.beat, "eight caught beats Tt's seven")
	g.abandon()
	check(bool(_result.get("extra", {}).get("beat", false)), "result extra says the regular was beaten")
	g.queue_free()
	var h := spawn({"regular": "nobody_here"})
	check(h.to_beat == Game.DEFAULT_TO_BEAT, "an unknown host uses the default stack")
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
