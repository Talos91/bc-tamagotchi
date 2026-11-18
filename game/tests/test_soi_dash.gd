extends SceneTree
## Headless tests for Soi Dash (docs/design/10-minigame-next.md §C): the night's street, scoring, a scripted runner,
## bumps and the clock, swipes, the action, strings and the venue registry.
##   godot --headless --path . --script res://tests/test_soi_dash.gd
## Exit code 0 = all pass.

const Rules = preload("res://scripts/rules.gd")
const Base = preload("res://scripts/minigames/minigame_base.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Game = preload("res://scripts/minigames/soi_dash.gd")
const Session = preload("res://scripts/zones/venue_session.gd")

const STEP := 1.0 / 120.0

var failures := 0
var checks := 0
var _result: Dictionary = {}


func _initialize() -> void:
	test_street()
	test_scores()
	test_good_runner()
	test_idle_runner()
	test_swipes()
	test_bounds()
	test_action_strings_registry()
	print("")
	print("%d checks, %d failed" % [checks, failures])
	print("SOI DASH TESTS ", "PASS" if failures == 0 else "FAIL")
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


func test_street() -> void:
	print("[street] same street per night, never all lanes blocked, notes to collect")
	for sd in [1, 42, 20261115]:
		var a := Game.street(sd)
		check(a.size() > 20, "seed %d has a street (%d items)" % [sd, a.size()])
		var rows := {}
		var notes := 0
		for it in a:
			if it["kind"] == Game.Kind.NOTE:
				notes += 1
				continue
			var key := snappedf(float(it["at"]), 0.001)
			rows[key] = rows.get(key, 0) + 1
		var worst := 0
		for k in rows:
			worst = maxi(worst, rows[k])
		check(worst <= 2, "seed %d: at most two lanes blocked at once" % sd)
		check(notes >= 15, "seed %d: 15+ notes (%d)" % [sd, notes])
	check(str(Game.street(7)) == str(Game.street(7)), "the same seed gives the same street")
	check(str(Game.street(7)) != str(Game.street(8)), "another night gives another street")
	check(Game.clock_text(50.0) == "19:59:10", "the clock reads 19:59:10 with 50 s to go")
	check(Game.clock_text(-3.0) == "20:00:03", "past 20:00 reads late")


func test_scores() -> void:
	print("[score] notes, spare seconds, late cap")
	check(is_equal_approx(Game.score_for(30, 30, 10.0), 1.0), "all notes, 10 s spare = 1.0")
	check(Base.tier_for(Game.score_for(30, 30, 9.0)) == 2, "all notes and 9 s spare is perfect")
	check(Game.score_for(30, 30, -1.0) <= 0.5, "late caps at 0.5")
	check(Base.tier_for(Game.score_for(2, 30, -2.0)) == Base.TIER_MISS, "late with almost no notes is a miss")
	check(Base.tier_for(Game.score_for(10, 30, 4.0)) == 0, "a third of the notes and 4 s spare is good")


## A runner that looks ahead in its lane: hops dogs and kerbs, moves round bikes and carts, steers to notes.
func run_bot(g: Control, max_secs := 60.0) -> void:
	var t := 0.0
	while not g.done and t < max_secs:
		if g.state == Game.State.RUNNING or g.state == Game.State.INTRO:
			var ob: Dictionary = g.next_obstacle(g.lane)
			if not ob.is_empty():
				var d: float = float(ob["at"]) - g.dist
				if d < 0.35:
					if ob["kind"] == Game.Kind.DOG or ob["kind"] == Game.Kind.KERB:
						if d < 0.25:
							g.hop()
					else:
						for dir in [1, -1]:
							var l: int = g.lane + dir
							if l >= -1 and l <= 1:
								var o2: Dictionary = g.next_obstacle(l)
								if o2.is_empty() or float(o2["at"]) - g.dist > 0.4:
									g.move(dir)
									break
			if g.next_obstacle(g.lane).is_empty() or float(g.next_obstacle(g.lane)["at"]) - g.dist > 0.6:
				for it in g.items:  # steer to the next note when the way is clear
					if it["kind"] == Game.Kind.NOTE and not it["done"] and float(it["at"]) - g.dist > 0.15 and float(it["at"]) - g.dist < 0.6:
						var tl: int = int(it["lane"])
						var o3: Dictionary = g.next_obstacle(tl)
						if tl != g.lane and (o3.is_empty() or float(o3["at"]) > float(it["at"]) + 0.2):
							g.move(signi(tl - g.lane))
						break
		g.advance(STEP)
		t += STEP


func test_good_runner() -> void:
	print("[play] a bot runs the soi")
	var g := spawn()
	run_bot(g)
	check(g.done and g.arrived, "the runner reaches the door")
	check(g.bumps <= 4, "few bumps (%d)" % g.bumps)
	check(g.notes * 2 >= g.notes_total, "half the notes or more (%d of %d)" % [g.notes, g.notes_total])
	check(int(_result.get("tier", -9)) >= 1, "great or perfect (%s)" % str(_result.get("score")))
	check(_result.get("action_id", "") == "soi_dash", "result names the action")
	g.queue_free()


func test_idle_runner() -> void:
	print("[play] standing in the middle lane: bumps cost the clock, the run still ends")
	var g := spawn()
	var t := 0.0
	while not g.done and t < 70.0:
		g.advance(STEP)
		t += STEP
	check(g.done and g.arrived, "the run always ends at the door")
	check(g.bumps > 0, "an idle runner bumps (%d)" % g.bumps)
	check(absf(g.clock - (Game.CLOCK_SECONDS - g.dist / Game.SPEED - g.bumps * Game.BUMP_COST)) < 0.001, "each bump cost 2 s (clock %.3f, bumps %d, dist %.3f)" % [g.clock, g.bumps, g.dist])
	check(float(_result.get("score", 1.0)) < 0.6, "idle is not great (%s)" % str(_result.get("score")))
	g.queue_free()
	var k := spawn()
	run_bot(k, 10.0)
	k.abandon()
	check(float(_result.get("score", 1.0)) <= 0.6, "leaving early scores only the notes so far")
	k.queue_free()


func test_swipes() -> void:
	print("[input] swipe right, left, up")
	var g := spawn()
	_swipe(g, Vector2(500, 900), Vector2(700, 900))
	check(g.lane == 1 and g.state == Game.State.RUNNING, "swipe right moves right and starts the run")
	_swipe(g, Vector2(500, 900), Vector2(300, 900))
	check(g.lane == 0, "swipe left moves back")
	_swipe(g, Vector2(500, 900), Vector2(500, 750))
	check(g.airborne(), "swipe up hops")
	_swipe(g, Vector2(500, 900), Vector2(510, 905))
	check(g.lane == 0, "a tap does nothing")
	g.queue_free()


func _swipe(g: Control, a: Vector2, b: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = a
	g._gui_input(e)
	var f := InputEventMouseButton.new()
	f.button_index = MOUSE_BUTTON_LEFT
	f.pressed = false
	f.position = b
	g._gui_input(f)


func test_action_strings_registry() -> void:
	print("[needs + strings + registry]")
	var def: Dictionary = Rules.ACTIONS.get("soi_dash", {})
	check(def.get("gains", {}).get("nightlife", []) == [10.0, 20.0], "Nightlife [10, 20]")
	var keys := {}
	for r in S.rows():
		keys[r["key"]] = r
	for suffix in ["title", "subtitle", "how_to", "tier_1", "tier_2", "tier_3", "status", "clock", "hint", "row", "row_sub"]:
		var k: String = "mg.soi_dash." + suffix
		check(keys.has(k) and keys[k]["en"] != "" and keys[k]["th"] != "", "string " + k)
	check(Session.GAMES.has("soi_dash") and ResourceLoader.exists(Session.GAMES["soi_dash"]), "venue registry has the scene")
	check(Session.ROW_GAMES.get("dash", "") == "soi_dash", "the cabinet row counts its tries")


## Item 37 (0.3.1): the road, the three lanes, the runner, the obstacles and the clock stay on screen. Play-area
## sizes are the minigame frame's content at phone portrait (450x800, 390x844), phone landscape (844x390) and PC
## web windows (1280x720, 1920x969), through the project's 1080x1920 canvas_items / expand stretch.
func test_bounds() -> void:
	print("[layout] everything inside the play area, portrait and landscape")
	var top := 200.0   # the frame's title bar and status line above the play area
	for vp in [Vector2(450, 800), Vector2(390, 844), Vector2(844, 390), Vector2(1280, 720), Vector2(1920, 969)]:
		var k := minf(vp.x / 1080.0, vp.y / 1920.0)
		var area: Vector2 = vp / k - Vector2(0, top)
		var g := spawn()
		g.size = area
		var r := Rect2(Vector2.ZERO, area)
		var ok := true
		var why := ""
		for lane in [-1, 0, 1]:
			var p: Vector2 = g._pt(0.0, lane * 2.0)
			# the runner (shadow +-50, body 200 tall, a hop lifts 110) and the widest obstacle (cart +-80, 170 tall)
			for q in [p + Vector2(-80, 16), p + Vector2(80, 16), p + Vector2(-80, -310), p + Vector2(80, -310)]:
				if not r.has_point(q):
					ok = false
					why = "lane %d at %s" % [lane, q]
		for l in [-3.0, 3.0]:
			for d in [0.0, Game.VIEW]:
				var e: Vector2 = g._pt(d, l)
				if not r.has_point(e):
					ok = false
					why = "kerb %s at d %s: %s" % [l, d, e]
		var lane_w: float = g._pt(0.0, 2.0).x - g._pt(0.0, 0.0).x
		check(ok, "%dx%d (play area %dx%d): road, lanes, runner inside %s" % [vp.x, vp.y, area.x, area.y, why])
		check(lane_w >= 200.0, "%dx%d: lanes wide enough for a cart (%d px)" % [vp.x, vp.y, lane_w])
		g.queue_free()
