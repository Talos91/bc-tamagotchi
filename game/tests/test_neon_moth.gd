extends SceneTree
## Headless tests for Neon Moth (docs/design/10-minigame-next.md §D): layout per night, scoring tiers, a scripted
## flyer, singes, the action, strings and the venue registry.
##   godot --headless --path . --script res://tests/test_neon_moth.gd
## Exit code 0 = all pass.

const Rules = preload("res://scripts/rules.gd")
const Base = preload("res://scripts/minigames/minigame_base.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Game = preload("res://scripts/minigames/neon_moth.gd")
const Session = preload("res://scripts/zones/venue_session.gd")

const STEP := 1.0 / 120.0

var failures := 0
var checks := 0
var _result: Dictionary = {}


func _initialize() -> void:
	test_layout()
	test_scores()
	test_good_flyer()
	test_idle_and_singes()
	test_tap_input()
	test_action_strings_registry()
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
	root.add_child(g)
	_result = {}
	g.finished.connect(func(r: Dictionary) -> void: _result = r)
	g.start()
	return g


func test_layout() -> void:
	print("[layout] same lounge per night, a new one tomorrow, fair steps")
	var a := Game.layout(42)
	check(a.size() == Game.GATES, "15 gates")
	check(a == Game.layout(42), "the same seed gives the same gaps")
	check(a != Game.layout(43), "another night gives other gaps")
	var ok := true
	for i in a.size():
		if a[i] < Game.GAP_MIN_Y - 0.01 or a[i] > Game.GAP_MAX_Y + 0.01:
			ok = false
		if i > 0 and absf(a[i] - a[i - 1]) > Game.GAP_MAX_STEP + 0.01:
			ok = false
	check(ok, "gaps stay in range and never jump more than GAP_MAX_STEP")
	var bkk_midnight := 1_800_000_000.0 - fmod(1_800_000_000.0 + Game.BKK_OFFSET, 86400.0)
	check(Game.night_seed(bkk_midnight - 1.0) + 1 == Game.night_seed(bkk_midnight), "the seed turns over at Bangkok midnight")


func test_scores() -> void:
	print("[score] gates and the sign")
	check(Base.tier_for(Game.score_for(4, false)) == Base.TIER_MISS, "4 gates is a miss")
	check(Base.tier_for(Game.score_for(5, false)) == 0, "5 gates is good")
	check(Base.tier_for(Game.score_for(12, false)) == 1, "12 gates is great")
	check(Base.tier_for(Game.score_for(13, true)) == 2, "13 gates and the sign is perfect")
	check(Base.tier_for(Game.score_for(15, false)) == 1, "the sign is needed for perfect")
	check(is_equal_approx(Game.score_for(15, true), 1.0), "a clean flight scores 1.0")


## A simple flyer: flutter whenever it sinks below the next gap's centre.
func fly_bot(g: Control, max_secs := 80.0) -> void:
	var t := 0.0
	while not g.done and t < max_secs:
		var n: int = g.next_gate()
		var target: float = g.gap_y[n] if n < Game.GATES else Game.FIELD.y * 0.5
		if g.state != Game.State.INTRO and g.y > target + 30.0 and g.vy >= 0.0:
			g.flap()
		g.advance(STEP)
		t += STEP


func test_good_flyer() -> void:
	print("[play] a bot flies the whole lounge")
	var g := spawn()
	fly_bot(g)
	check(g.done, "the flight ends")
	check(g.reached_sign, "the moth reaches the sign")
	check(g.gates_passed >= 14, "14+ gates (%d), singes left %d" % [g.gates_passed, g.singes_left])
	check(int(_result.get("tier", -9)) == 2, "perfect tier (%s)" % str(_result.get("score")))
	check(_result.get("action_id", "") == "neon_moth", "result names the action")
	check(int(_result.get("extra", {}).get("seed", 0)) == 20261115, "result carries the seed")
	g.queue_free()
	for sd in [1, 7, 99, 2026]:
		var h := spawn({"seed": sd})
		fly_bot(h)
		check(h.reached_sign and h.gates_passed >= 13, "seed %d is flyable (%d gates)" % [sd, h.gates_passed])
		h.queue_free()


func test_idle_and_singes() -> void:
	print("[play] never tapping singes three times and ends as a miss")
	var g := spawn()
	var t := 0.0
	while not g.done and t < 60.0:
		g.advance(STEP)
		t += STEP
	check(g.done and g.singes_left == 0, "three singes end the flight")
	check(bool(_result.get("miss", false)), "an idle flight is a miss")
	check(t < 15.0, "it ends quickly (%.1f s)" % t)
	g.queue_free()
	var r := spawn({"seed": 5})
	r.relaxed = true
	check(r.gap_size() > Game.GAP, "relaxed timing widens the gaps")
	r.queue_free()
	var k := spawn()
	fly_bot(k, 12.0)
	var before: int = k.gates_passed
	k.abandon()
	check(int(_result.get("extra", {}).get("gates", -1)) == before, "leaving keeps the gates so far")
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
	for suffix in ["title", "subtitle", "how_to", "tier_1", "tier_2", "tier_3", "status", "hint", "row", "row_sub"]:
		var k: String = "mg.neon_moth." + suffix
		check(keys.has(k) and keys[k]["en"] != "" and keys[k]["th"] != "", "string " + k)
	check(Session.GAMES.has("neon_moth") and ResourceLoader.exists(Session.GAMES["neon_moth"]), "venue registry has the scene")
	check(Session.ROW_GAMES.get("moth", "") == "neon_moth", "the cabinet row counts its tries")
