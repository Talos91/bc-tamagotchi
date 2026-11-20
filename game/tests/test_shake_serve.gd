extends SceneTree
## Headless tests for Shake & Serve (docs/design/10-minigame-next.md §B; quality pass Q7, 11-minigame-quality.md):
## orders per night and level, real bottles from the menu, the three levels (more bottles, faster nods, the restocked
## shelf), scoring, scripted bartenders, relaxed timing, taps on the shelf, art and budget, juice, tonight's regular,
## the shared bar tries, the Friends bonus, strings and the venue registry.
## Endless ramp (docs/design/15-minigame-ramp.md; Daniele 2026-11-20): orders keep coming (4-bottle specials from order 4,
## faster to the cap at order 9); an order under half is sent back, the third sent back loses; 33 points an order.
##   godot --headless --path . --script res://tests/test_shake_serve.gd
## Exit code 0 = all pass (and at least MIN_CHECKS checks ran: a script that fails to compile runs none).

const Rules = preload("res://scripts/rules.gd")
const NeedsScript = preload("res://scripts/needs.gd")
const Base = preload("res://scripts/minigames/minigame_base.gd")
const S = preload("res://scripts/minigames/strings.gd")
const BarMenu = preload("res://scripts/menu/bar_menu.gd")
const CardScript = preload("res://scripts/minigames/result_card.gd")
const Game = preload("res://scripts/minigames/shake_serve.gd")
const Session = preload("res://scripts/zones/venue_session.gd")

const T0 := 1_800_000_000.0
const STEP := 1.0 / 120.0
const MIN_CHECKS := 120
const OLD_ORDERS := 3                ## the old round ended after 3 orders
const LONG_RUN := 12                 ## a scripted perfect bartender's run: well past the old end and the cap (order 9)


class Store:
	extends RefCounted
	var ext := {}


var failures := 0
var checks := 0
var _result: Dictionary = {}


func _initialize() -> void:
	test_orders_and_bottles()
	test_levels()
	test_ramp_numbers()
	test_scores()
	test_perfect_bartender()
	test_sloppy_bartender()
	test_relaxed()
	test_taps_on_shelf()
	test_art()
	test_juice_and_rivals()
	test_tries_and_bonus()
	test_strings_registry()
	print("")
	print("%d checks, %d failed" % [checks, failures])
	if checks < MIN_CHECKS:
		failures += 1
		print("  FAIL: only %d checks ran (expected >= %d): did the game script compile?" % [checks, MIN_CHECKS])
	print("SHAKE SERVE TESTS ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("  FAIL: ", msg)


func spawn(config := {"night": 100}, is_relaxed := false, sz := Vector2(1080, 1400)) -> Control:
	var g: Control = Game.new()
	g.size = sz
	g.config = config
	g.relaxed = is_relaxed
	g.rivals_store = Store.new()
	root.add_child(g)
	_result = {}
	g.finished.connect(func(r: Dictionary) -> void: _result.merge(r, true))
	g.start()
	return g


func adv(g: Control, secs: float) -> void:
	var t := 0.0
	while t < secs and not g.done:
		g.advance(STEP)
		t += STEP


func test_orders_and_bottles() -> void:
	print("[orders] one mix per level, same per night; real bottles for the spirits")
	var o := Game.pick_orders(100)
	check(o.size() == Game.LEVELS.size(), "three opening orders")
	for k in Game.LEVELS.size():
		check(o[k].size() - 1 == int(Game.LEVELS[k]["bottles"]), "order %d has level %d's bottles (%d)" % [k + 1, k + 1, o[k].size() - 1])
	check(o[0] != o[1] and o[1] != o[2] and o[0] != o[2], "three different mixes")
	check(str(Game.pick_orders(100)) == str(o), "same night, same orders")
	check(str(Game.pick_orders(100, 1)) != str(o), "the next round of the visit brings others")
	check(str(Game.pick_orders(101)) != str(o), "the next night brings others")
	# endless orders: level 3's mixes, per night + round + order, never the same mix twice in a row
	var top: Array = Game.LEVEL_RECIPES[Game.LEVELS.size() - 1]
	var four_ok := true
	var repeat_ok := true
	var same_ok := true
	var kinds := {}
	for night in [100, 101, 20411]:
		for i in range(Game.LEVELS.size() - 1, 40):
			var r: Array = Game.order_at(night, 0, i)
			four_ok = four_ok and r.size() - 1 == 4 and top.has(r)
			if i > Game.LEVELS.size() - 1:
				repeat_ok = repeat_ok and str(r) != str(Game.order_at(night, 0, i - 1))
			same_ok = same_ok and str(r) == str(Game.order_at(night, 0, i))
			if night == 100:
				kinds[str(r[0])] = true
	check(four_ok, "every order from 4 on is a 4-bottle mix from level 3's list")
	check(repeat_ok, "never the same mix twice in a row")
	check(same_ok, "the same night, round and order bring the same mix")
	check(kinds.size() == top.size(), "every level-3 mix comes round (%d of %d)" % [kinds.size(), top.size()])
	var rounds_differ := false
	for i in range(3, 12):
		rounds_differ = rounds_differ or str(Game.order_at(100, 0, i)) != str(Game.order_at(100, 1, i))
	check(rounds_differ, "the next round of the visit brings other endless orders")
	var keys := {}
	for r in Game.all_recipes():
		check(str(r[1]) in Game.SPIRITS, "recipe %s starts with a spirit" % r[0])
		var ok := true
		var seen := {}
		for m in range(2, r.size()):
			ok = ok and str(r[m]) in Game.MIXERS and not seen.has(str(r[m]))
			seen[str(r[m])] = true
		check(ok, "recipe %s uses distinct shelf mixers" % r[0])
		check(not keys.has(str(r[0])), "recipe key %s is unique" % r[0])
		keys[str(r[0])] = true
	for fam in Game.SPIRITS:
		var b := Game.bottle_of(fam)
		check(b != "" and BarMenu.has(b), "a real menu bottle for %s (%s)" % [fam, b])


func test_levels() -> void:
	print("[levels] more bottles, faster nods; level 3 restocks the shelf")
	for k in range(1, Game.LEVELS.size()):
		var a: Dictionary = Game.LEVELS[k - 1]
		var b: Dictionary = Game.LEVELS[k]
		check(int(b["bottles"]) > int(a["bottles"]), "level %d has more bottles than level %d" % [k + 1, k])
		check(float(b["gap"]) < float(a["gap"]), "level %d nods come faster" % [k + 1])
		check(int(b["beats"]) >= int(a["beats"]), "level %d has at least as many nods" % [k + 1])
	check(int(Game.LEVELS[0]["bottles"]) == 2 and int(Game.LEVELS[2]["bottles"]) == 4, "2 bottles, then up to 4")
	var r := Game.restocked(100)
	var sorted_r := r.duplicate()
	sorted_r.sort()
	var sorted_s := Game.shelf()
	sorted_s.sort()
	check(str(sorted_r) == str(sorted_s), "restocked shelf has the same twelve bottles")
	check(str(r) != str(Game.shelf()), "restocked shelf is in a new order")
	check(str(Game.restocked(100)) == str(r), "same night, same restock")
	check(str(Game.restocked(100, 2)) == str(r), "level 3's restock is as before")
	check(str(Game.restocked(100, 5)) != str(Game.restocked(100, 6)), "every endless order restocks the shelf anew")
	check(str(Game.restocked(100, 7)) == str(Game.restocked(100, 7)), "same night and order, same restock")
	# in play: the levels arrive one per order; from order 4 every order restocks (right bottles, no shaking: 0.6 an order)
	var g := spawn()
	var seen_bottles: Array[int] = []
	var restock_ok := true
	var level_ok := true
	var guard := 0
	while not g.done and guard < 40000 and g.order < 7:
		guard += 1
		if g.state == Game.State.PICK:
			if seen_bottles.size() == g.order:
				seen_bottles.append(g.bottles_needed())
				restock_ok = restock_ok and (str(g.shelf_order) == str(Game.restocked(100, g.order) if g.order >= 2 else Game.shelf()))
				level_ok = level_ok and g.ramp_level == g.order + 1
			g.pick(g.wanted())
		g.advance(STEP)
	check(str(seen_bottles) == "[2, 3, 4, 4, 4, 4, 4]", "bottles per order in play: 2, 3, 4, then 4 (%s)" % str(seen_bottles))
	check(restock_ok, "the shelf keeps its order until level 3, then every order restocks it")
	check(level_ok, "the level is the order number")
	check(not g.done and g.lives_left == Base.STRIKES, "0.6 an order is served, never sent back (%d lives)" % g.lives_left)
	g.abandon()
	check(int(_result.get("extra", {}).get("level", 0)) == 8, "the result carries the level reached (%s)" % str(_result.get("extra", {}).get("level")))
	g.queue_free()


## The ramp (15-minigame-ramp): orders 1-3 as before, then each number gets harder per order up to the cap at order 9.
func test_ramp_numbers() -> void:
	print("[ramp] recipe look, pick time, nods and nod gap per order; cap at order 9")
	for i in Game.LEVELS.size():
		check(is_equal_approx(Game.memo_at(i), Game.MEMO_SECONDS) and is_equal_approx(Game.pick_at(i), Game.PICK_SECONDS), "order %d: today's look and pick time" % (i + 1))
		check(Game.beats_of(i) == int(Game.LEVELS[i]["beats"]) and is_equal_approx(Game.gap_of(i), float(Game.LEVELS[i]["gap"])), "order %d: today's nods" % (i + 1))
		check(Game.ramp_step(i) == 0, "order %d is not in the endless ramp yet" % (i + 1))
	var harder := true
	var level_ok := true
	for i in range(3, 9):
		harder = harder and Game.memo_at(i) < Game.memo_at(i - 1) and Game.pick_at(i) < Game.pick_at(i - 1) and Game.gap_of(i) < Game.gap_of(i - 1)
		harder = harder and Game.beats_of(i) >= Game.beats_of(i - 1) and Game.bottles_of(i) == 4
		level_ok = level_ok and Game.level_of_order(i) == i + 1
	check(harder, "orders 4-9: shorter look, less pick time, quicker nods, at least as many nods, 4 bottles")
	check(level_ok, "the level is the order number")
	check(Game.ramp_step(3) == 1 and Game.ramp_step(8) == Game.RAMP_STEPS and Game.ramp_step(40) == Game.RAMP_STEPS, "ramp steps 1..6 from order 4, capped at order 9")
	check(is_equal_approx(Game.memo_at(8), 1.5), "cap: recipe look 1.5 s")
	check(is_equal_approx(Game.pick_at(8), 7.0), "cap: pick time 7 s")
	check(Game.beats_of(8) == 8, "cap: 8 nods (%d)" % Game.beats_of(8))
	check(is_equal_approx(Game.gap_of(8), 0.38), "cap: nods 0.38 s apart (%.3f)" % Game.gap_of(8))
	check(Game.level_of_order(8) == 9 and Game.LEVEL_CAP == 9, "cap: level 9 at order 9")
	var flat := true
	for i in range(9, 40):
		flat = flat and Game.memo_at(i) == Game.memo_at(8) and Game.pick_at(i) == Game.pick_at(8)
		flat = flat and Game.beats_of(i) == Game.beats_of(8) and Game.gap_of(i) == Game.gap_of(8) and Game.level_of_order(i) == 9
	check(flat, "past order 9 nothing gets harder")
	check(Game.gap_of(8) > Game.BEAT_WINDOW, "at the cap the nods are still further apart than the beat window")



func test_scores() -> void:
	print("[score] recipe and shake parts")
	check(is_equal_approx(Game.order_score(0, [1.0, 1.0, 1.0, 1.0]), 1.0), "clean order = 1.0")
	check(is_equal_approx(Game.order_score(1, [1.0, 1.0, 1.0, 1.0]), 0.8), "one wrong bottle = 0.8")
	check(is_equal_approx(Game.order_score(0, [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]), 1.0), "six clean nods = 1.0")
	check(is_equal_approx(Game.order_score(0, [1.0, 1.0, 1.0, 0.0, 0.0, 0.0]), 0.8), "half the nods = 0.6 + 0.2")
	check(is_equal_approx(Game.order_score(5, [0.0, 0.0, 0.0, 0.0]), 0.0), "never below 0")
	check(Game.beat_accuracy(0.0) == 1.0 and Game.beat_accuracy(Game.BEAT_WINDOW) == 0.0, "beat window")
	# points: 33 an order x its score, uncapped; score (0..1) = min(1, points / 100)
	check(Game.order_points(1.0) == 33 and Game.order_points(0.0) == 0, "33 points for a perfect order")
	check(Game.points_of([1.0, 1.0, 1.0]) == 99, "3 perfect orders = 99 (a perfect old round)")
	check(Game.points_of([1.0, 1.0, 1.0, 1.0, 1.0]) == 165, "points keep counting past 100")
	check(is_equal_approx(Base.score_of(Game.points_of([1.0, 1.0, 1.0, 1.0, 1.0])), 1.0), "the score stops at 1.0")
	check(Base.tier_for(Base.score_of(Game.points_of([0.2, 0.2, 0.2]))) == Base.TIER_MISS, "a sloppy round is a miss")
	check(Game.sent_back_for(0.49) and not Game.sent_back_for(0.5), "under half is sent back")
	check(Game.sent_back_for(Game.order_score(1, [0.0, 0.0, 0.0, 0.0])), "one wrong bottle and no shake (0.4) is sent back")
	check(not Game.sent_back_for(Game.order_score(0, [0.0, 0.0, 0.0, 0.0])), "the right bottles without a shake (0.6) are served")


## A scripted bartender: wrong_first = one wrong bottle before each order; offset = tap this far after each nod
## (NAN = never shake). Stops when the round ends or once `max_orders` orders are served (the round itself is endless).
func play(g: Control, wrong_first: bool, offset: float, max_orders := 99) -> void:
	var guard := 0
	while not g.done and guard < 60000 and g.order < max_orders:
		guard += 1
		match g.state:
			Game.State.PICK:
				if wrong_first and g.step == 0 and g.wrongs == 0:
					for id in Game.shelf():
						if id != g.wanted():
							g.pick(id)
							break
				g.pick(g.wanted())
			Game.State.SHAKE:
				var i: int = g.taps.size()
				if not is_nan(offset) and i < Game.beats_of(g.order) and g._state_t >= g.nod_time(i) + offset:
					g.shake_tap()
		g.advance(STEP)


func test_perfect_bartender() -> void:
	print("[play] the right bottles and every nod: orders keep coming, past the old end and the cap")
	var g := spawn()
	play(g, false, 0.0, LONG_RUN)
	check(not g.done, "no end after %d orders: the round goes on" % OLD_ORDERS)
	check(g.order_scores.size() == LONG_RUN, "%d orders served (%d)" % [LONG_RUN, g.order_scores.size()])
	var clean := true
	for s in g.order_scores:
		clean = clean and s >= 0.9
	check(clean, "every order clean, up to the cap (%s)" % str(g.order_scores))
	check(g.lives_left == Base.STRIKES and g.sent_back == 0, "nothing sent back")
	check(g.ramp_level == Game.LEVEL_CAP, "the level reaches the cap (%d)" % g.ramp_level)
	check(g.record_points() > 100 and g.record_points() >= 30 * LONG_RUN, "points keep counting past 100 (%d)" % g.record_points())
	check(g.last_status == S.t("mg.ramp.status", {"level": g.ramp_level, "points": g.record_points(), "lives": Base.STRIKES}), "the status line: level, points, lives (%s)" % g.last_status)
	var pts: int = g.record_points()
	g.abandon()
	check(g.end_reason == "", "leaving is not a loss")
	check(int(_result.get("points", 0)) == pts, "the result carries the uncapped points (%s)" % str(_result.get("points")))
	check(is_equal_approx(float(_result.get("score", 0.0)), 1.0), "score = min(1, points / 100)")
	check(int(_result.get("tier", -9)) == 2, "perfect (%s)" % str(_result.get("score")))
	check(_result.get("action_id", "") == "pour_perfect", "feeds the bar's Drinks action")
	check(_result.get("game_id", "") == "shake_serve", "its own game id (best score)")
	check(_result.get("need_id", "") == "drinks", "the Drinks need")
	var ex: Dictionary = _result.get("extra", {})
	check(ex.get("bonus_action", "") == "shake_serve_friends", "a great round earns the Friends bonus")
	check(ex.get("orders", []).size() == LONG_RUN, "every order score on the result")
	check(int(ex.get("level", 0)) == Game.LEVEL_CAP, "result extra carries the level")
	check(is_equal_approx(float(ex.get("speed", 0.0)), 0.38), "result extra carries the speed (nod gap at the cap)")
	check(int(ex.get("misses", -1)) == 0, "result extra: no misses")
	g.queue_free()


func test_sloppy_bartender() -> void:
	print("[play] one wrong bottle each order and no shaking: sent back 3 times, lost; idle times out to a loss")
	var g := spawn()
	# the first order: Nam sends it back as it is served
	var guard := 0
	while g.state != Game.State.SERVE and guard < 20000:
		guard += 1
		if g.state == Game.State.PICK:
			if g.step == 0 and g.wrongs == 0:
				g.pick("cola" if g.wanted() != "cola" else "lime")
			g.pick(g.wanted())
		g.advance(STEP)
	check(is_equal_approx(g.order_scores[0], 0.4), "0.4 = recipe minus one bottle, no shake (%s)" % str(g.order_scores))
	check(g.sent_back == 1 and g.lives_left == 2, "under half is sent back: a strike (%d left)" % g.lives_left)
	check(g.nam_frame() == 3, "Nam frowns at a sent-back drink")
	check(g._fx.edge_amount() > 0.0, "a sent-back drink flashes the red edge")
	check(g.last_status == S.t("mg.ramp.status", {"level": 1, "points": 13, "lives": 2}), "the status line shows the lives left (%s)" % g.last_status)
	play(g, true, NAN, 2)
	check(not g.done and g.lives_left == 1, "two sent back: still playing, one left")
	play(g, true, NAN)
	check(g.done, "the round ends")
	check(g.order_scores.size() == 3, "lost on exactly the 3rd sent back (%d orders)" % g.order_scores.size())
	check(g.end_reason == "lost", "the round is lost (%s)" % g.end_reason)
	var s := float(_result.get("score", 0.0))
	check(int(_result.get("points", 0)) == 39 and is_equal_approx(s, 0.39), "3 x 13 points = 39, score 0.39 (%s)" % str(s))
	check(not _result.get("extra", {}).has("bonus_action"), "no bonus below great")
	check(int(_result.get("extra", {}).get("level", 0)) == 3, "result extra carries the level (3)")
	check(int(_result.get("extra", {}).get("misses", 0)) == 3, "result extra: 3 misses")
	g.queue_free()
	var h := spawn()
	adv(h, 120.0)
	check(h.done and bool(_result.get("miss", false)), "doing nothing times out to a miss")
	check(h.end_reason == "lost" and h.order_scores.size() == 3, "idle: three timed-out orders sent back, lost")
	h.queue_free()
	var m := spawn()
	play(m, false, 0.12, OLD_ORDERS)
	check(not m.done and m.lives_left == Base.STRIKES, "a bit late on every nod is still served")
	m.abandon()
	var ms := float(_result.get("score", 0.0))
	check(ms > 0.6 and ms < 1.0, "a bit late on every nod, 3 orders, lands between good and perfect (%s)" % str(ms))
	m.queue_free()


func test_relaxed() -> void:
	print("[relaxed] wider beat window and a longer look at the recipe; levels kept")
	var scores := {}
	for rel in [false, true]:
		var g := spawn({"night": 100}, rel)
		play(g, false, 0.18, OLD_ORDERS)
		check(not g.done, "0.18 s late is still served (relaxed %s)" % str(rel))
		g.abandon()
		scores[rel] = float(_result.get("score", 0.0))
		g.queue_free()
	check(scores[true] >= scores[false], "relaxed scores >= normal for the same taps (%s vs %s)" % [scores[true], scores[false]])
	check(scores[true] > scores[false], "0.18 s late counts more in relaxed")
	var a := spawn({"night": 100}, false)
	var b := spawn({"night": 100}, true)
	check(b.memo_seconds() > a.memo_seconds(), "relaxed shows the recipe longer")
	check(b.beat_window() > a.beat_window(), "relaxed beat window is wider")
	a.order = 8
	b.order = 8
	check(is_equal_approx(b.memo_seconds() - a.memo_seconds(), Game.MEMO_RELAXED_EXTRA), "relaxed keeps its extra second at the cap")
	a.queue_free()
	b.queue_free()


func test_taps_on_shelf() -> void:
	print("[input] a tap on a bottle picks it, portrait and landscape")
	for sz in [Vector2(1080, 1400), Vector2(1920, 900)]:
		var g := spawn({"night": 100}, false, sz)
		adv(g, Game.INTRO_SECONDS + Game.MEMO_SECONDS + 0.05)
		check(g.state == Game.State.PICK, "picking after the recipe (%s)" % str(sz))
		var ok := true
		for i in g.shelf_order.size():
			var screen: Vector2 = g._xf() * (Game.slot_pos(i) + Vector2(0, -60))
			ok = ok and g.shelf_at(screen) == str(g.shelf_order[i])
			ok = ok and screen.x >= 0.0 and screen.x <= sz.x and screen.y >= 0.0 and screen.y <= sz.y
		check(ok, "every bottle is on screen and tappable (%s)" % str(sz))
		var want: String = g.wanted()
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = g._xf() * (g.shelf_pos(want) + Vector2(0, -60))
		g._gui_input(ev)
		check(g.step == 1, "tapping the wanted bottle pours it (%s)" % str(sz))
		check(g.pours.size() == 1, "the bottle flies to the shaker")
		g.queue_free()


func test_art() -> void:
	print("[art] look B sprites load; budget")
	var g := spawn()
	check(g.has_art(), "all sprites load (nam with 4 frames)")
	var f := FileAccess.open(Game.ART_DIR + "sprites.json", FileAccess.READ)
	var meta: Dictionary = JSON.parse_string(f.get_as_text())
	check(float(meta.get("texture_mb_loaded", 99.0)) <= 4.0, "texture budget <= 4 MB (%s MB)" % str(meta.get("texture_mb_loaded")))
	var names: Array = meta["sprites"]["bottles"]["frame_names"]
	check(str(names) == str(Game.shelf()), "bottle frames follow the shelf ids")
	check(str(meta["sprites"]["nam"]["frame_names"]) == str(["up", "nod", "smile", "frown"]), "nam frames: up, nod, smile, frown")
	g.queue_free()


func test_juice_and_rivals() -> void:
	print("[juice + rivals] every beat answers; tonight's regular and the board")
	var g := spawn()
	check(not g.rival.is_empty() and g.rival.has("points"), "a regular to beat tonight")
	adv(g, Game.INTRO_SECONDS + Game.MEMO_SECONDS + 0.05)
	g.pick("cola" if g.wanted() != "cola" else "lime")
	check(g.rattle_t > 0.0 and g.nam_frame() == 3, "a wrong bottle rattles the shelf, Nam frowns")
	check(g._fx != null and g._fx.edge_amount() > 0.0, "a wrong bottle flashes the red edge")
	g.pick(g.wanted())
	check(g.nam_frame() == 2, "a right bottle: Nam smiles")
	check(g._fx.pops_alive() >= 2, "pops for the wrong and the right bottle")
	g.pick(g.wanted())
	check(g.state == Game.State.SHAKE, "level 1 shakes after two bottles")
	adv(g, g.nod_time(0) - g._state_t)
	check(g.nam_frame() == 1, "Nam nods on the beat")
	var before: int = g._fx.particles_alive()
	g.shake_tap()
	check(g.shake_anim > 0.0, "the shaker swings")
	check(g._fx.particles_alive() > before, "an on-beat shake splashes")
	adv(g, 3.0)
	check(g.state == Game.State.SERVE or g.state == Game.State.MEMO, "the drink is served")
	g.queue_free()
	# the record and the board line on the result
	var h := spawn()
	play(h, false, 0.0, 6)
	h.abandon()
	var ex: Dictionary = _result.get("extra", {})
	check(ex.get("rival", {}).has("points"), "result carries the rival")
	check(int(ex.get("board", {}).get("rank", 0)) >= 1, "result carries the board place (%s)" % str(ex.get("board")))
	check(int(ex.get("board", {}).get("rank", 0)) == 1, "six perfect orders top tonight's board (%d points)" % int(_result.get("points", 0)))
	h.queue_free()


func test_tries_and_bonus() -> void:
	print("[needs] the bar's 3 tries are shared; the bonus lands on the card")
	check(Rules.MINIGAME_TRY_POOL.get("shake_serve", "") == "pour_perfect", "try pool: shake_serve uses pour_perfect's tries")
	var def: Dictionary = Rules.ACTIONS.get("shake_serve_friends", {})
	check(def.get("gains", {}).get("friends", 0.0) == 5.0, "bonus = Friends +5")
	var n: Node = NeedsScript.new()
	n.autosave = false
	n.time_override = T0
	n.save_path = "user://test_shake_serve_save.json"
	n.new_game()
	root.add_child(n)
	for m in n.meters:
		n.meters[m] = 20.0
	n.note_minigame_round("pour_perfect")
	n.note_minigame_round("shake_serve")
	check(n.minigame_tries_left("pour_perfect") == 1 and n.minigame_tries_left("shake_serve") == 1, "two rounds at the bar leave one try for both")
	var card: Control = CardScript.new()
	card.needs = n
	root.add_child(card)
	var before := float(n.meters["friends"])
	var out: Dictionary = card.apply({"game_id": "shake_serve", "action_id": "pour_perfect", "need_id": "drinks", "key": "",
		"title_key": "mg.shake_serve.title", "score": 0.9, "points": 90, "tier": 2, "miss": false,
		"extra": {"bonus_action": "shake_serve_friends"}})
	check(out.get("ok", false), "the card applies the round")
	check(float(n.meters["friends"]) > before, "the Friends bonus is applied with it")
	check(n.minigame_tries_left("pour_perfect") == 0, "the third bar round used the last shared try")
	card.queue_free()
	n.queue_free()


func test_strings_registry() -> void:
	print("[strings + registry]")
	var keys := {}
	for r in S.rows():
		keys[r["key"]] = r
	var need: Array[String] = []
	for suffix in ["title", "subtitle", "how_to", "tier_1", "tier_2", "tier_3", "status", "nam", "hint_memo", "hint_pick",
			"hint_shake", "served", "row", "row_sub", "level", "wrong", "on_beat", "off_beat", "restock"]:
		need.append("mg.shake_serve." + suffix)
	for lv in Game.LEVELS:
		need.append("mg.shake_serve.level." + str(lv["key"]))
	for r in Game.all_recipes():
		need.append("mg.shake_serve.order." + str(r[0]))
	for id in Game.SPIRITS + Game.MIXERS:
		need.append("mg.shake_serve.bottle." + str(id))
	for k in ["mg.rivals.to_beat", "mg.rivals.you_now", "mg.rivals.passed", "mg.shake_serve.sent_back", "mg.ramp.status",
			"mg.ramp.strike", "mg.ramp.last", "mg.ramp.level"]:
		need.append(k)
	for k in need:
		check(keys.has(k) and keys[k]["en"] != "" and keys[k]["th"] != "", "string " + k)
	check(Session.GAMES.has("shake_serve") and ResourceLoader.exists(Session.GAMES["shake_serve"]), "venue registry has the scene")
	check(Session.ROW_GAMES.get("shake", "") == "shake_serve", "the bar row counts its tries")
