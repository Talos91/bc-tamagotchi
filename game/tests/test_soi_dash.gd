extends SceneTree
## Headless tests for Soi Dash (docs/design/10-minigame-next.md §C): the night's street (generated ahead in chunks),
## points, a scripted runner, bumps and lives, swipes, the action, strings and the venue registry. Endless ramp
## (docs/design/15-minigame-ramp.md; Daniele 2026-11-20): no clock, no door; speed 1.0 -> 1.6 at 60 s, level 1..7,
## 2 points a street unit + 1 a note, the third bump loses.
##   godot --headless --path . --script res://tests/test_soi_dash.gd
## Exit code 0 = all pass.

const Rules = preload("res://scripts/rules.gd")
const Base = preload("res://scripts/minigames/minigame_base.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Game = preload("res://scripts/minigames/soi_dash.gd")
const Session = preload("res://scripts/zones/venue_session.gd")
const Rivals = preload("res://scripts/minigames/mg_rivals.gd")


## Stands in for Needs: mg_rivals only reads and writes `ext`.
class Store:
	extends RefCounted
	var ext := {}


const STEP := 1.0 / 120.0
const LONG_RUN := 75.0               ## seconds the good runner runs: past the speed cap (60 s) and the old street (40)

var failures := 0
var checks := 0
var _result: Dictionary = {}
var store := Store.new()


func _initialize() -> void:
	test_street()
	test_chunks()
	test_ramp()
	test_movers()
	test_sprites()
	test_points()
	test_good_runner()
	test_hop_at_cap()
	test_idle_runner()
	test_relaxed()
	test_beats()
	test_swipes()
	test_bounds()
	test_action_strings_registry()
	test_rivals()
	check(checks >= 120, "the suite ran its checks (%d)" % checks)
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
	g.rivals_store = store
	root.add_child(g)
	_result = {}
	g.finished.connect(func(r: Dictionary) -> void: _result = r)
	g.start()
	return g


func test_street() -> void:
	print("[street] same street per night, never all lanes blocked, notes to collect")
	for sd in [1, 42, 20261115]:
		var a := Game.street(sd, false, 120.0)
		check(a.size() > 60, "seed %d has a long street (%d items)" % [sd, a.size()])
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
		check(notes >= 45, "seed %d: notes all the way (%d in 120 units)" % [sd, notes])
		var ordered := true
		for i in range(1, a.size()):
			if float(a[i]["at"]) < float(a[i - 1]["at"]):
				ordered = false
		check(ordered, "seed %d: items come in street order (the game drops them from the front)" % sd)
	check(str(Game.street(7)) == str(Game.street(7)), "the same seed gives the same street")
	check(str(Game.street(7)) != str(Game.street(8)), "another night gives another street")
	check(str(Game.street(7, false, 60.0)).begins_with(str(Game.street(7)).trim_suffix("]")), "a longer street starts with the same rows")


## The street is generated AHEAD units ahead as the runner goes and dropped BEHIND; the rows are street()'s.
func test_chunks() -> void:
	print("[chunks] generated ahead, dropped behind, the same street as street()")
	for rel in [false, true]:
		var g := spawn({"seed": 4242}, rel)
		check(str(g.items) == str(Game.street(4242, rel, Game.AHEAD)), "relaxed %s: the start is street(seed) up to AHEAD units" % str(rel))
		g.queue_free()
	var h := spawn()
	run_bot(h, 30.0)
	check(not h.items.is_empty() and float(h.items[0]["at"]) >= h.dist - Game.BEHIND - 0.001, "what lies behind is dropped (first item %.2f, runner %.2f)" % [float(h.items[0]["at"]), h.dist])
	check(float(h.items[h.items.size() - 1]["at"]) >= h.dist + Game.AHEAD - 2.5, "the street is ready AHEAD units ahead")
	check(h.items.size() < 60, "only a short stretch is kept (%d items)" % h.items.size())
	h.queue_free()


## The ramp: warm-up rows are single-lane parked things and kerbs; street life joins on schedule; the gap shrinks;
## the speed rises a second at a time up to 1.6 at 60 s; a level every 10 s up to 7.
func test_ramp() -> void:
	print("[ramp] warm-up first, street life on schedule, rows closer, faster each second up to the cap")
	for sd in [1, 42, 20261115, 99]:
		var a := Game.street(sd, false, 80.0)
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
		check(early_bad == "", "seed %d: street life waits for its place (%s)" % [sd, early_bad])
		check(not pair_early, "seed %d: no two-lane row in the first 10 units" % sd)
		var keys := rows.keys()
		keys.sort()
		var first := 0.0
		var last := 0.0
		var nf := 0
		var nl := 0
		var min_gap := 99.0
		for i in range(1, keys.size()):
			var gap := float(keys[i]) - float(keys[i - 1])
			min_gap = minf(min_gap, gap)
			if float(keys[i]) < 12.0:
				first += gap
				nf += 1
			elif float(keys[i]) > 45.0:
				last += gap
				nl += 1
		check(nf > 0 and nl > 0 and first / nf > last / nl + 0.5, "seed %d: rows closer later on (%.2f -> %.2f)" % [sd, first / maxf(1, nf), last / maxf(1, nl)])
		check(nl > 0 and absf(last / nl - Game.STEP_END) < 0.1, "seed %d: past the ramp rows stay 1.2 apart on average (%.2f)" % [sd, last / maxf(1, nl)])
		check(min_gap >= Game.STEP_END - Game.STEP_JITTER - 0.001, "seed %d: never closer than 1.05 (%.2f)" % [sd, min_gap])
	var kinds := {}
	for sd in range(1, 30):
		for it in Game.street(sd):
			kinds[int(it["kind"])] = true
	for k in [Game.Kind.BIKE, Game.Kind.CART, Game.Kind.TUK, Game.Kind.DOG, Game.Kind.STRAY, Game.Kind.LIZARD, Game.Kind.KERB, Game.Kind.NOTE]:
		check(kinds.has(k), "the streets have kind %d" % k)
	check(is_equal_approx(Game.row_step(0.0), 1.9) and is_equal_approx(Game.row_step(Game.STEP_FULL_AT), 1.2) and is_equal_approx(Game.row_step(500.0), 1.2), "row gap 1.9 -> 1.2, then stays")
	check(is_equal_approx(Game.row_step(20.0, true) - Game.row_step(20.0), 0.4) and is_equal_approx(Game.row_step(500.0, true), 1.6), "relaxed gap +0.4, also at the cap")
	# speed and level by seconds of running
	check(is_equal_approx(Game.speed_at(0.0), 1.0) and is_equal_approx(Game.speed_at(1.0), 1.01) and is_equal_approx(Game.speed_at(30.0), 1.3), "speed 1.0 + 0.01 a second")
	check(is_equal_approx(Game.speed_at(60.0), 1.6) and is_equal_approx(Game.speed_at(61.0), 1.6) and is_equal_approx(Game.speed_at(900.0), 1.6) and Game.SPEED_CAP == 1.6, "speed capped at 1.6 from 60 s")
	var rising := true
	for s in range(1, 60):
		if Game.speed_at(float(s)) <= Game.speed_at(float(s - 1)):
			rising = false
	check(rising, "faster every second up to the cap")
	check(Game.level_at(0.0) == 1 and Game.level_at(9.9) == 1 and Game.level_at(10.0) == 2 and Game.level_at(59.9) == 6, "a level every 10 s")
	check(Game.level_at(60.0) == 7 and Game.level_at(600.0) == 7 and Game.LEVEL_CAP == 7, "level 7 at 60 s and no higher")
	# why the cap is playable: a hop clears one row before the next; 2.5 s of preview
	check(Game.HOP_SECONDS * Game.SPEED_CAP < Game.STEP_END - Game.STEP_JITTER, "a hop at the cap (%.2f units) is shorter than the closest rows (%.2f)" % [Game.HOP_SECONDS * Game.SPEED_CAP, Game.STEP_END - Game.STEP_JITTER])
	check(Game.VIEW / Game.SPEED_CAP >= 2.49, "2.5 s of street seen ahead at the cap")


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
	for n in ["runner", "motorbike", "food_cart", "tuk_tuk_front", "soi_dog", "soi_dog_trot", "monitor_lizard", "kerb", "note", "shopfront", "road_tile", "lane_dash", "backdrop"]:
		var m: Dictionary = Game.sprite_meta(n)
		check(not m.is_empty() and ResourceLoader.exists(Game.ART + str(m.get("file", ""))), "sprite " + n)
	var f := FileAccess.open(Game.ART + "sprites.json", FileAccess.READ)
	var j: Dictionary = JSON.parse_string(f.get_as_text())
	check(float(j.get("texture_bytes_loaded", 1e9)) <= 4.0 * 1024 * 1024, "textures within 4 MB (%s)" % str(j.get("texture_mb_loaded")))


func test_points() -> void:
	print("[points] 2 a street unit + 1 a note, uncapped; the need score reads the first 100")
	check(Game.points_of(0.0, 0) == 0 and Game.points_of(40.0, 30) == 110 and Game.points_of(10.2, 3) == 23, "2 a unit + 1 a note (the old street with its notes ~ 110)")
	check(Game.points_of(300.0, 200) == 800, "the record is uncapped")
	var g := spawn()
	for pair in [[0.0, 0], [5.0, 2], [12.4, 5], [40.0, 20], [55.0, 31], [200.0, 90]]:
		g.dist = float(pair[0])
		g.notes = int(pair[1])
		var pts: int = g.record_points()
		check(pts == Game.points_of(float(pair[0]), int(pair[1])) and g.live_points() == pts, "%.1f units, %d notes: %d points" % [float(pair[0]), int(pair[1]), pts])
		check(is_equal_approx(g.current_score(), minf(1.0, float(pts) / 100.0)), "score = min(1, points / 100) (%.2f)" % g.current_score())
	g.queue_free()


## A runner that looks ahead in its lane: hops dogs and kerbs, moves round bikes and carts (two lanes over when the
## next one is blocked too), steers to notes only through a clear lane. On a port of the rules it ran 150 s on 40
## streets (normal and relaxed) without a bump (calibrated 2026-11-20).
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
						var moved := false
						for dir in [1, -1]:
							var l: int = g.lane + dir
							if l >= -1 and l <= 1 and _clear(g, l, 0.4):
								g.move(dir)
								moved = true
								break
						if not moved:  # both neighbours blocked here: head for the open lane two over
							for dir in [1, -1]:
								var l2: int = g.lane + 2 * dir
								if l2 >= -1 and l2 <= 1 and _clear(g, l2, 0.4):
									g.move(dir)
									break
			if _clear(g, g.lane, 0.6):
				for it in g.items:  # steer to the next note when the way is clear
					if it["kind"] == Game.Kind.NOTE and not it["done"] and float(it["at"]) - g.dist > 0.15 and float(it["at"]) - g.dist < 0.6:
						var tl: int = int(it["lane"])
						if tl != g.lane:
							var sl: int = g.lane + signi(tl - g.lane)
							var o3: Dictionary = g.next_obstacle(sl)
							if o3.is_empty() or (float(o3["at"]) - g.dist > 0.4 and float(o3["at"]) > float(it["at"]) + 0.2):
								g.move(signi(tl - g.lane))
						break
		g.advance(STEP)
		t += STEP


## No obstacle in lane l within `ahead` street units.
func _clear(g: Control, l: int, ahead: float) -> bool:
	var o: Dictionary = g.next_obstacle(l)
	return o.is_empty() or float(o["at"]) - g.dist > ahead


func test_good_runner() -> void:
	print("[play] a bot runs well past the old street, up to the speed cap and level 7")
	for sd in [20261115, 7, 31337]:
		var g := spawn({"seed": sd})
		run_bot(g, LONG_RUN)
		check(not g.done, "seed %d: no door, no clock: still running after %.0f s" % [sd, LONG_RUN])
		check(g.bumps <= 1 and g.lives_left >= 2, "seed %d: few bumps (%d)" % [sd, g.bumps])
		check(g.dist > Game.RUN_SECONDS * 2.0, "seed %d: well past the old 40-unit street (%.1f)" % [sd, g.dist])
		check(g.record_points() > 100 and g.notes > 30, "seed %d: points past 100 (%d, %d notes)" % [sd, g.record_points(), g.notes])
		check(g.ramp_level == Game.LEVEL_CAP and is_equal_approx(g.speed(), Game.SPEED_CAP), "seed %d: level 7 at 1.6 street/s (level %d, %.2f)" % [sd, g.ramp_level, g.speed()])
		check(g.last_status == g.status_text() and g.last_status.contains(str(g.record_points())), "seed %d: the status line shows level, points, lives (%s)" % [sd, g.last_status])
		g.abandon()
		var ex: Dictionary = _result.get("extra", {})
		check(int(ex.get("level", 0)) == 7 and is_equal_approx(float(ex.get("speed", 0.0)), 1.6) and int(ex.get("misses", -1)) == g.bumps, "seed %d: result extra level 7, speed 1.6, misses" % sd)
		check(not ex.has("arrived") and not ex.has("spare"), "seed %d: no door, no clock in the result" % sd)
		check(int(_result.get("points", 0)) == g.record_points() and is_equal_approx(float(_result.get("score", 0.0)), 1.0), "seed %d: the record is the points, the need score 1.0" % sd)
		check(g.end_reason == "", "seed %d: leaving is not a loss" % sd)
		if sd == 20261115:
			check(_result.get("action_id", "") == "soi_dash", "result names the action")
		g.queue_free()


## At the top speed a hop still clears a row before the next one, even at the closest rows (1.05 apart).
func test_hop_at_cap() -> void:
	print("[cap] at 1.6 street/s a hop clears a kerb and lands before the next row")
	var g := spawn()
	g.move(0)
	g.run_t = 60.0
	var base: float = g.dist
	var two: Array[Dictionary] = [{"at": base + 1.0, "lane": 0, "from": 0, "kind": Game.Kind.KERB, "done": false},
		{"at": base + 1.0 + Game.STEP_END - Game.STEP_JITTER, "lane": 0, "from": 0, "kind": Game.Kind.LIZARD, "done": false}]
	g.items = two
	var hops := 0
	while g.dist < base + 2.6 and not g.done:
		var ob: Dictionary = g.next_obstacle(0)
		if not ob.is_empty() and float(ob["at"]) - g.dist < 0.25 and not g.airborne():
			g.hop()
			hops += 1
		g.advance(STEP)
	check(is_equal_approx(g.speed(), Game.SPEED_CAP), "running at the cap (%.2f)" % g.speed())
	check(hops == 2 and g.bumps == 0, "two hops, no bump (hops %d, bumps %d)" % [hops, g.bumps])
	g.queue_free()


func test_idle_runner() -> void:
	print("[play] standing in the middle lane: the third bump loses")
	var g := spawn()
	var t := 0.0
	var early_end := false
	while not g.done and t < 120.0:
		var lives: int = g.lives_left
		g.advance(STEP)
		t += STEP
		if g.done and lives > 1:
			early_end = true
	check(not early_end, "one or two bumps never end the run")
	check(g.done and g.bumps == 3 and g.lives_left == 0 and g.end_reason == "lost", "the third bump loses (bumps %d, end %s)" % [g.bumps, g.end_reason])
	var ex: Dictionary = _result.get("extra", {})
	check(int(ex.get("level", 0)) == g.ramp_level and int(ex.get("level", 0)) >= 1 and int(ex.get("misses", 0)) == 3, "result extra: level and misses 3")
	check(is_equal_approx(float(_result.get("score", -1.0)), minf(1.0, g.record_points() / 100.0)), "score = min(1, points / 100)")
	check(float(_result.get("score", 1.0)) < 0.8, "idle is not great (%s)" % str(_result.get("score")))
	g.queue_free()
	var k := spawn()
	run_bot(k, 10.0)
	var pts: int = k.record_points()
	k.abandon()
	check(int(_result.get("points", -1)) == pts and pts > 0, "leaving keeps the points so far (%d)" % pts)
	k.queue_free()


## Relaxed timing: longer gaps, earlier movers; the same bot does no worse.
func test_relaxed() -> void:
	print("[relaxed] a gentler street, never a worse run for the same bot")
	for sd in [7, 20261115, 31337]:
		var na := 0
		var nb := 0
		for it in Game.street(sd, false, 60.0):
			if it["kind"] != Game.Kind.NOTE:
				na += 1
		for it in Game.street(sd, true, 60.0):
			if it["kind"] != Game.Kind.NOTE:
				nb += 1
		check(nb < na, "seed %d relaxed: fewer obstacles in the same 60 units (%d < %d)" % [sd, nb, na])
		var a := spawn({"seed": sd})
		run_bot(a, 45.0)
		var b := spawn({"seed": sd}, true)
		run_bot(b, 45.0)
		check(not b.done and b.bumps <= a.bumps + 1, "seed %d relaxed: no worse (bumps %d vs %d)" % [sd, b.bumps, a.bumps])
		check(is_equal_approx(b.speed(), a.speed()), "seed %d relaxed: the same speed ramp" % sd)
		a.queue_free()
		b.queue_free()


## §2.3 beats through mg_fx: note chime + combo, bump shake / status flash / strike pop, hop dust, lane streak, levels.
func test_beats() -> void:
	print("[beats] notes, bumps, hops, swipes and levels answer")
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
	var pops0: int = f.pops_alive()
	while g.dist < 3.1:
		g.advance(STEP)
	check(g.bumps == 1 and g.lives_left == 2 and f.combo == 0, "a bump costs a life and breaks the combo")
	check(f.flash_amount("status") > 0.0 and f.edge_amount() > 0.0, "a bump flashes the readout and the edge")
	check(f.pops_alive() > pops0, "a bump pops the lives left")
	check(f.reduce_motion or f.trauma > 0.0, "a bump shakes")
	check(g.best_combo == 2, "best combo kept for the result")
	check(not g.done, "one bump goes on")
	g.queue_free()
	var k := spawn()
	var kf = k.fx()
	kf.auto_step = false
	var none: Array[Dictionary] = []
	k.items = none
	k.move(0)
	var t := 0.0
	var popped := false
	while k.ramp_level < 2 and t < 12.0:
		var p0: int = kf.pops_alive()
		k.advance(STEP)
		t += STEP
		if k.ramp_level == 2:
			popped = kf.pops_alive() > p0
	check(k.ramp_level == 2 and absf(k.run_t - Game.LEVEL_SECONDS) < 0.05, "level 2 after 10 s of running (%.2f s)" % k.run_t)
	check(popped, "level up: a LEVEL pop")
	check(k.last_status.contains("2"), "the status line shows the new level (%s)" % k.last_status)
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
	for suffix in ["title", "subtitle", "how_to", "tier_1", "tier_2", "tier_3", "hint", "row", "row_sub", "combo", "ghost"]:
		var k: String = "mg.soi_dash." + suffix
		check(keys.has(k) and keys[k]["en"] != "" and keys[k]["th"] != "", "string " + k)
	for k in ["mg.ramp.level", "mg.ramp.status", "mg.ramp.strike", "mg.ramp.last"]:
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


func test_rivals() -> void:
	print("[rivals] the regular to beat, the ghost runner, the board line")
	store = Store.new()
	var g := spawn()
	check(not g.rival.is_empty() and g.rival.has("points") and str(g.rival.get("name", "")) != "", "a regular to beat in play")
	check(g.ghost.is_empty(), "no ghost before the first run tonight")
	run_bot(g, 45.0)
	g.abandon()
	check(g.ghost_lanes.size() >= int(g.dist / Game.GHOST_STEP) - 1, "the run recorded its lanes (%d)" % g.ghost_lanes.size())
	var ex: Dictionary = _result.get("extra", {})
	check(ex.get("rival") is Dictionary and ex["rival"].has("points"), "result carries the rival")
	check(ex.get("board") is Dictionary and int(ex["board"].get("rank", 0)) >= 1 and int(ex["board"].get("count", 0)) >= 2, "result carries the board place")
	check(g.rival_passed == (g.live_points() > int(g.rival["points"])), "passing the regular is flagged in play")
	var points: int = int(_result.get("points", 0))
	check(points == g.record_points() and points > 100, "the record sent is the uncapped points (%d)" % points)
	check(int(Rivals.tonight("soi_dash", store)["best"]) == points, "tonight's best is that run")
	var run_len: int = g.ghost_lanes.size()
	g.queue_free()
	var h := spawn()
	check(h.ghost.get("lanes") is Array and h.ghost["lanes"].size() == run_len and run_len > 100 and run_len <= Game.GHOST_MAX, "the next run has tonight's best as a ghost (%d samples)" % run_len)
	h.advance(Game.INTRO_SECONDS + 0.01)
	for i in 120:
		h.advance(STEP)
	check(not is_nan(h.ghost_lane_at(h.dist)), "the ghost has a lane on the street")
	check(is_nan(h.ghost_lane_at(run_len * Game.GHOST_STEP + 5.0)), "the ghost ends where that run ended")
	h.queue_free()
	var other := spawn({"seed": 77})
	check(other.ghost.is_empty(), "a ghost from another night's street is not shown")
	other.queue_free()
	var rel := spawn({"seed": 20261115}, true)
	check(rel.ghost.is_empty(), "a ghost from the other timing mode is not shown")
	rel.queue_free()
	# an idle run is worse: tonight's best and ghost stay
	var lanes_before: Array = Rivals.tonight("soi_dash", store)["ghost"].get("lanes", [])
	var k := spawn()
	var t := 0.0
	while not k.done and t < 120.0:
		k.advance(STEP)
		t += STEP
	check(k.done and int(_result.get("points", 100)) < points, "an idle run scores less than the bot")
	check(int(Rivals.tonight("soi_dash", store)["best"]) == points, "a worse run keeps tonight's best")
	check(Rivals.tonight("soi_dash", store)["ghost"].get("lanes", []) == lanes_before, "a worse run keeps the ghost")
	k.queue_free()
	# a very long run: the recorded ghost stops at GHOST_MAX samples (the save stays small)
	var m := spawn()
	m.move(0)
	m.bump_t = 1000.0                   # no bumps while the run jumps far down the soi
	m.dist = Game.GHOST_STEP * float(Game.GHOST_MAX + 400)
	m.advance(STEP)
	check(m.ghost_lanes.size() == Game.GHOST_MAX and m.ghost_data()["lanes"].size() == Game.GHOST_MAX, "ghost capped at %d samples (%d)" % [Game.GHOST_MAX, m.ghost_lanes.size()])
	check(not m.items.is_empty() and float(m.items[0]["at"]) >= m.dist - Game.BEHIND - 0.001 and float(m.items[m.items.size() - 1]["at"]) > m.dist, "the street was generated ahead and the far past dropped (%d items)" % m.items.size())
	m.queue_free()
