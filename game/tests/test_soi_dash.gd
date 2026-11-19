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
	test_ramp()
	test_movers()
	test_sprites()
	test_scores()
	test_good_runner()
	test_idle_runner()
	test_relaxed()
	test_beats()
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


func spawn(config := {"seed": 20261115}, relaxed := false) -> Control:
	var g: Control = Game.new()
	g.size = Vector2(1080, 1400)
	g.config = config
	g.relaxed = relaxed
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


## §3 ramp: warm-up rows are single-lane parked things and kerbs; street life joins on schedule; the gap shrinks.
func test_ramp() -> void:
	print("[ramp] warm-up first, street life on schedule, rows closer toward the door")
	for sd in [1, 42, 20261115, 99]:
		var a := Game.street(sd)
		var rows := {}
		var early_bad := ""
		for it in a:
			var at := float(it["at"])
			var k := int(it["kind"])
			if k == Game.Kind.NOTE:
				continue
			var key := snappedf(at, 0.001)
			rows[key] = rows.get(key, 0) + 1
			if k == Game.Kind.TUK and at < Game.TUK_FROM:
				early_bad = "tuk-tuk at %.2f" % at
			if (k == Game.Kind.DOG or k == Game.Kind.STRAY) and at < Game.DOG_FROM:
				early_bad = "dog at %.2f" % at
			if k == Game.Kind.LIZARD and at < Game.LIZARD_FROM:
				early_bad = "lizard at %.2f" % at
		var pair_early := false
		for key in rows:
			if rows[key] > 1 and float(key) < Game.PAIR_FROM:
				pair_early = true
		check(early_bad == "", "seed %d: street life waits for its time (%s)" % [sd, early_bad])
		check(not pair_early, "seed %d: no two-lane row in the first 10 s" % sd)
		var keys := rows.keys()
		keys.sort()
		var first := 0.0
		var last := 0.0
		var nf := 0
		var nl := 0
		for i in range(1, keys.size()):
			var gap := float(keys[i]) - float(keys[i - 1])
			if float(keys[i]) < 12.0:
				first += gap
				nf += 1
			elif float(keys[i]) > 28.0:
				last += gap
				nl += 1
		check(nf > 0 and nl > 0 and first / nf > last / nl + 0.3, "seed %d: rows closer at the end (%.2f -> %.2f)" % [sd, first / maxf(1, nf), last / maxf(1, nl)])
	var kinds := {}
	for sd in range(1, 30):
		for it in Game.street(sd):
			kinds[int(it["kind"])] = true
	for k in [Game.Kind.BIKE, Game.Kind.CART, Game.Kind.TUK, Game.Kind.DOG, Game.Kind.STRAY, Game.Kind.LIZARD, Game.Kind.KERB, Game.Kind.NOTE]:
		check(kinds.has(k), "the streets have kind %d" % k)
	check(is_equal_approx(Game.row_step(0.0), 1.9) and is_equal_approx(Game.row_step(Game.RUN_SECONDS - 1.0), 1.2), "row gap 1.9 -> 1.2")
	check(is_equal_approx(Game.row_step(20.0, true) - Game.row_step(20.0), 0.4), "relaxed gap +0.4")


## Movers: a stray or a lizard is in its lane SETTLE ahead (0.5 earlier relaxed); a tuk-tuk rushes but meets the
## runner at its own street point.
func test_movers() -> void:
	print("[movers] strays and lizards settle before the runner, tuk-tuks rush in")
	var stray := {"at": 20.0, "lane": 1, "from": 0, "kind": Game.Kind.STRAY, "done": false}
	var liz := {"at": 25.0, "lane": -1, "from": 1, "kind": Game.Kind.LIZARD, "done": false}
	check(is_equal_approx(Game.mover_lane(stray, 3.0), 0.0), "a far stray is still in its first lane")
	check(Game.mover_lane(stray, 1.5) > 0.0 and Game.mover_lane(stray, 1.5) < 1.0, "a stray trots across")
	check(is_equal_approx(Game.mover_lane(stray, Game.SETTLE), 1.0), "a stray is in its lane SETTLE ahead")
	check(is_equal_approx(Game.mover_lane(liz, Game.SETTLE), -1.0) and is_equal_approx(Game.mover_lane(liz, Game.SETTLE + Game.LIZARD_SPAN), 1.0), "a lizard crawls two lanes and settles")
	check(is_equal_approx(Game.mover_lane(stray, Game.SETTLE + 0.5, true), 1.0) and Game.mover_lane(stray, Game.SETTLE + 0.5) < 1.0, "relaxed settles 0.5 earlier")
	var tuk := {"at": 15.0, "lane": 0, "from": 0, "kind": Game.Kind.TUK, "done": false}
	check(Game.drawn_dist(tuk, 2.0) > 2.0 and is_equal_approx(Game.drawn_dist(tuk, 0.0), 0.0), "a tuk-tuk shows further out and reaches the runner at its point")
	check(Game.drawn_dist(tuk, 2.0, true) < Game.drawn_dist(tuk, 2.0), "relaxed tuk-tuks rush less")
	check(Game.hoppable(Game.Kind.STRAY) and Game.hoppable(Game.Kind.LIZARD) and not Game.hoppable(Game.Kind.TUK), "dogs and lizards are hopped, tuk-tuks dodged")
	# a hop clears a lizard; a stray in the lane bumps a runner on the ground
	var g := spawn()
	var one: Array[Dictionary] = [{"at": 3.0, "lane": 0, "from": 2, "kind": Game.Kind.LIZARD, "done": false}]
	g.items = one
	g.move(0)
	while g.dist < 2.8:
		g.advance(STEP)
	g.hop()
	while g.dist < 3.3:
		g.advance(STEP)
	check(g.bumps == 0, "hopping a lizard clears it")
	var two: Array[Dictionary] = [{"at": 4.0, "lane": 0, "from": 1, "kind": Game.Kind.STRAY, "done": false}]
	g.items = two
	while g.dist < 4.3:
		g.advance(STEP)
	check(g.bumps == 1, "a stray in the lane bumps a runner on the ground")
	g.queue_free()


## Look B: every sprite the game draws is in the sheet, and the set fits the 4 MB texture budget (plan §1.3).
func test_sprites() -> void:
	print("[sprites] voxel sprites present, within budget")
	for n in ["runner", "motorbike", "food_cart", "tuk_tuk_front", "soi_dog", "soi_dog_trot", "monitor_lizard", "kerb", "note", "shopfront", "road_tile", "lane_dash", "door_front", "backdrop"]:
		var m: Dictionary = Game.sprite_meta(n)
		check(not m.is_empty() and ResourceLoader.exists(Game.ART + str(m.get("file", ""))), "sprite " + n)
	var f := FileAccess.open(Game.ART + "sprites.json", FileAccess.READ)
	var j: Dictionary = JSON.parse_string(f.get_as_text())
	check(float(j.get("texture_bytes_loaded", 1e9)) <= 4.0 * 1024 * 1024, "textures within 4 MB (%s)" % str(j.get("texture_mb_loaded")))


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
					if Game.hoppable(int(ob["kind"])):
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


## Relaxed timing (§3): longer gaps, earlier movers; the same bot does no worse.
func test_relaxed() -> void:
	print("[relaxed] a gentler street, never a worse run for the same bot")
	for sd in [7, 20261115, 31337]:
		var a := spawn({"seed": sd})
		run_bot(a)
		var sa := float(_result.get("score", 0.0))
		var b := spawn({"seed": sd}, true)
		run_bot(b)
		var sb := float(_result.get("score", 0.0))
		check(b.done and b.arrived, "seed %d relaxed: the runner reaches the door" % sd)
		check(b.items.size() < a.items.size(), "seed %d relaxed: fewer rows (%d < %d)" % [sd, b.items.size(), a.items.size()])
		check(b.bumps <= a.bumps + 1 and sb >= sa - 0.05, "seed %d relaxed: no worse (bumps %d vs %d, score %.2f vs %.2f)" % [sd, b.bumps, a.bumps, sb, sa])
		a.queue_free()
		b.queue_free()


## §2.3 beats through mg_fx: note chime + combo, bump shake / clock flash / -2 s, hop dust, lane streak, the door.
func test_beats() -> void:
	print("[beats] notes, bumps, hops, swipes and the door answer")
	var g := spawn()
	var f = g.fx()
	f.auto_step = false
	g.move(1)
	check(g._dash_t > 0.0, "a lane change draws a dash streak")
	g.hop()
	check(g._puffs.size() == 1 and f.squash_scale("runner") != Vector2.ONE, "a hop kicks up dust and squashes the runner")
	var row: Array[Dictionary] = [{"at": 2.0, "lane": 1, "from": 1, "kind": Game.Kind.NOTE, "done": false},
		{"at": 2.3, "lane": 1, "from": 1, "kind": Game.Kind.NOTE, "done": false},
		{"at": 3.0, "lane": 1, "from": 1, "kind": Game.Kind.BIKE, "done": false}]
	g.items = row
	while g.dist < 2.4:
		g.advance(STEP)
	check(g.notes == 2 and f.combo == 2 and f.combo_text() != "", "two notes in a row make a combo (%d)" % f.combo)
	check(f.pops_alive() >= 2, "each note pops")
	while g.dist < 3.1:
		g.advance(STEP)
	check(g.bumps == 1 and f.combo == 0, "a bump breaks the combo")
	check(f.flash_amount("clock") > 0.0 and f.edge_amount() > 0.0, "a bump flashes the clock and the edge")
	check(f.reduce_motion or f.trauma > 0.0, "a bump shakes")
	check(g.best_combo == 2, "best combo kept for the result")
	g.queue_free()
	var k := spawn()
	var none: Array[Dictionary] = []
	k.items = none
	k.notes_total = 1
	while not k.arrived:
		k.advance(STEP)
	check(k.state == Game.State.DOOR and not k.done, "at the door: doors swing before the result")
	var t := 0.0
	while not k.done and t < 2.0:
		k.advance(STEP)
		t += STEP
	check(k.done and t <= Game.DOOR_SECONDS + 0.05, "the result follows the door (%.2f s)" % t)
	check(not _result.is_empty() and _result["extra"].has("best_combo"), "the result carries the combo")
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
		var sc: float = g.art_scale()
		for lane in [-1, 0, 1]:
			var p: Vector2 = g._pt(0.0, lane * 2.0)
			# Q6: the drawn sprites. The runner at the top of a hop, its shadow, and the widest street life at the
			# runner: the food cart, the tuk-tuk, the monitor lizard facing either way (drawn at 0.85).
			var rects: Array[Rect2] = [g.sprite_rect("runner", p - Vector2(0, g.hop_lift_px()), sc),
				Rect2(p + Vector2(-60, -10) * sc, Vector2(120, 20) * sc),
				g.sprite_rect("food_cart", p, sc), g.sprite_rect("tuk_tuk_front", p, sc)]
			var lz: Rect2 = g.sprite_rect("monitor_lizard", p, sc * 0.85)
			rects.append(lz)
			rects.append(Rect2(Vector2(2.0 * p.x - lz.end.x, lz.position.y), lz.size))
			for q in rects:
				if q.size == Vector2.ZERO or not r.encloses(q):
					ok = false
					why = "lane %d: %s" % [lane, q]
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
