extends SceneTree
## Headless tests for Neon Moth (docs/design/10-minigame-next.md §D): layout per night, scoring tiers, a scripted
## flyer, singes, the action, strings and the venue registry. Q4 (11-minigame-quality §2.3, §3, §4.1): the ramp, the
## voxel sprites, the juice beats, and mg_rivals (regulars to beat, tonight's best, ghost run, board).
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
	test_scores()
	test_good_flyer()
	test_idle_and_singes()
	test_tap_input()
	test_action_strings_registry()
	test_ramp()
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
	print("[layout] same lounge per night, a new one tomorrow, fair steps")
	var a := Game.layout(42)
	check(a.size() == Game.GATES and Game.GATES == 20, "20 gates (Q4: more gates, closer together)")
	check(a == Game.layout(42), "the same seed gives the same gaps")
	check(a != Game.layout(43), "another night gives other gaps")
	var ok := true
	var c: Dictionary = Game.course(42)
	for i in a.size():
		var amp := Game.MOVE_AMP if c["phase"][i] >= 0.0 else 0.0
		if a[i] - amp < Game.GAP_MIN_Y - 0.01 or a[i] + amp > Game.GAP_MAX_Y + 0.01:
			ok = false
		if i > 0 and absf(a[i] - a[i - 1]) > lerpf(Game.STEP_START, Game.STEP_END, Game.ramp(i)) + 0.01:
			ok = false
	check(ok, "gaps stay in range and never jump more than the ramp's step")
	var bkk_midnight := 1_800_000_000.0 - fmod(1_800_000_000.0 + Game.BKK_OFFSET, 86400.0)
	check(Game.night_seed(bkk_midnight - 1.0) + 1 == Game.night_seed(bkk_midnight), "the seed turns over at Bangkok midnight")


func test_scores() -> void:
	print("[score] gates and the sign")
	check(Base.tier_for(Game.score_for(6, false)) == Base.TIER_MISS, "6 gates is a miss")
	check(Base.tier_for(Game.score_for(7, false)) == 0, "7 gates is good")
	check(Base.tier_for(Game.score_for(15, false)) == 1, "15 gates is great")
	check(Base.tier_for(Game.score_for(17, true)) == 2, "17 gates and the sign is perfect")
	check(Base.tier_for(Game.score_for(16, true)) == 1, "16 gates and the sign is great")
	check(Base.tier_for(Game.score_for(20, false)) == 1, "the sign is needed for perfect")
	check(is_equal_approx(Game.score_for(20, true), 1.0), "a clean flight scores 1.0")


## A simple flyer: flutter whenever it sinks below the next gap's centre (where it is now: gaps bob).
## react: seconds of delay before it sees where the gap is; slop: px it lets the moth sink; jitter: up to this many
## seconds late on each tap (seeded). react 0.2 / slop 70 / jitter 0.1 plays like an average player (Q4 calibration:
## mean score 0.61 over 8 nights; a sharp bot 0.98, a sloppy one 0.30).
func fly_bot(g: Control, max_secs := 80.0, react := 0.0, slop := 30.0, jitter := 0.0) -> void:
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
		g.advance(STEP)
		t += STEP


func test_good_flyer() -> void:
	print("[play] a bot flies the whole lounge")
	var g := spawn()
	fly_bot(g)
	check(g.done, "the flight ends")
	check(g.reached_sign, "the moth reaches the sign")
	check(g.gates_passed >= 18, "18+ gates (%d), singes left %d" % [g.gates_passed, g.singes_left])
	check(int(_result.get("tier", -9)) == 2, "perfect tier (%s)" % str(_result.get("score")))
	check(_result.get("action_id", "") == "neon_moth", "result names the action")
	check(int(_result.get("extra", {}).get("seed", 0)) == 20261115, "result carries the seed")
	g.queue_free()
	for sd in [1, 7, 99, 2026]:
		var h := spawn({"seed": sd})
		fly_bot(h)
		check(h.reached_sign and h.gates_passed >= 17, "seed %d is flyable (%d gates)" % [sd, h.gates_passed])
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
	for k in ["mg.rivals.you", "mg.rivals.to_beat", "mg.rivals.you_now", "mg.rivals.passed", "mg.rivals.ghost", "mg.result.board"]:
		check(keys.has(k) and keys[k]["en"] != "" and keys[k]["th"] != "", "string " + k)
	check(Session.GAMES.has("neon_moth") and ResourceLoader.exists(Session.GAMES["neon_moth"]), "venue registry has the scene")
	check(Session.ROW_GAMES.get("moth", "") == "neon_moth", "the cabinet row counts its tries")


func test_ramp() -> void:
	print("[ramp] faster, closer, tighter; several gates on screen; relaxed widens and caps")
	check(is_equal_approx(Game.gap_at(0), 340.0) and is_equal_approx(Game.gap_at(Game.GATES - 1), Game.GAP_TIGHT), "gap 340 -> 250")
	var mono := true
	for i in range(1, Game.GATES):
		if Game.gap_at(i) > Game.gap_at(i - 1) + 0.01:
			mono = false
	check(mono, "gaps only tighten")
	for i in range(Game.GATES - Game.TIGHT_LAST, Game.GATES):
		check(is_equal_approx(Game.gap_at(i), Game.GAP_TIGHT), "last gates tight (%d)" % i)
	check(is_equal_approx(Game.gap_at(5, true), Game.gap_at(5) + 60.0), "relaxed: +60 px every gap")
	var moving := 0
	var early := 0
	for sd in range(1, 31):
		var c: Dictionary = Game.course(sd)
		for i in Game.GATES:
			if c["phase"][i] >= 0.0:
				moving += 1
				if i < Game.MOVE_FROM:
					early += 1
	check(early == 0, "only later gates bob")
	check(moving >= 30 * 3, "bobbing gates are common in the second half (%d over 30 nights)" % moving)
	var g := spawn()
	var v0: float = g.speed()
	g.scroll = g.course_length() * 0.95
	check(g.speed() > v0 + 40.0, "the scroll speeds up (%.0f -> %.0f)" % [v0, g.speed()])
	g.queue_free()
	var h := spawn()
	var t := 0.0
	var most := 0
	var frames := 0
	var several := 0
	while not h.done and t < 60.0:
		var n: int = h.next_gate()
		if h.state != Game.State.INTRO and h.y > h.gap_center(n) + 30.0 and h.vy >= 0.0:
			h.flap()
		h.advance(STEP)
		t += STEP
		if h.state == Game.State.FLYING and h.next_gate() < Game.GATES - 2:
			frames += 1
			most = maxi(most, h.gates_on_screen())
			if h.gates_on_screen() >= 2:
				several += 1
	check(most >= 3, "up to 3 gates on screen (%d)" % most)
	check(frames > 0 and float(several) / frames > 0.85, "2+ gates on screen nearly all flight (%.0f %%)" % (100.0 * several / maxi(frames, 1)))
	check(t > 25.0 and t < 40.0, "a full flight lasts 25-40 s (%.1f s)" % t)
	h.queue_free()
	var r := spawn()
	r.relaxed = true
	r.scroll = r.course_length() * 0.95
	check(r.speed() <= Game.SPEED_RELAXED_CAP + 0.01, "relaxed caps the scroll at 225")
	r.queue_free()


func test_average_and_relaxed() -> void:
	print("[ramp] an average player lands good/great; relaxed never scores below normal")
	var tiers := {}
	var normal_sum := 0.0
	var relaxed_sum := 0.0
	for sd in [3, 11, 20261119, 424242, 77, 5, 8, 13]:
		var g := spawn({"seed": sd})
		fly_bot(g, 80.0, 0.2, 70.0, 0.1)
		var tier := Base.tier_for(g.current_score())
		tiers[tier] = int(tiers.get(tier, 0)) + 1
		normal_sum += g.current_score()
		g.queue_free()
		var r := spawn({"seed": sd})
		r.relaxed = true
		fly_bot(r, 80.0, 0.2, 70.0, 0.1)
		relaxed_sum += r.current_score()
		r.queue_free()
	print("    average bot tiers ", tiers, " normal %.2f relaxed %.2f" % [normal_sum / 8.0, relaxed_sum / 8.0])
	check(int(tiers.get(0, 0)) + int(tiers.get(1, 0)) >= 5, "an average run mostly lands good or great")
	check(normal_sum / 8.0 > 0.45 and normal_sum / 8.0 < 0.8, "an average player's mean sits between good and great")
	check(int(tiers.get(Base.TIER_MISS, 0)) <= 1, "an average run rarely misses")
	check(relaxed_sum >= normal_sum - 0.001, "relaxed scores at least normal for the same player")


func test_art_and_juice() -> void:
	print("[art + juice] voxel sprites drawn; every §2.3 beat answers")
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
	check(popped, "gate passed: +1 pop")
	check(hf.combo >= 3, "clean gates build the combo (%d)" % hf.combo)
	# singe: drive the moth into the floor
	var wings: int = h.singes_left
	h.blink = 0.0
	h.vy = Game.MAX_FALL
	h.y = Game.FIELD.y - Game.MOTH_R - 1.0
	h.advance(STEP)
	check(h.singes_left == wings - 1, "a bump singes a wing")
	check(hf.edge_amount() > 0.0, "singe: red edge")
	check(hf.combo == 0, "singe: the combo breaks")
	check(hf.squash_scale("wing%d" % h.singes_left) != Vector2.ONE, "singe: the wing icon breaks (squash)")
	h.queue_free()
	var k := spawn()
	k.fx().auto_step = false
	fly_bot(k)
	check(k.reached_sign and k._sign_flare > 0.0, "sign reached: the neon flares")
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
	print("[rivals in game] the regular to beat, the result lines, the ghost next try")
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
	g.queue_free()
	var h := spawn()
	var ys: Array = h.ghost.get("ys", [])
	check(ys.size() > 100, "the next try flies with tonight's best as a ghost (%d samples)" % ys.size())
	check(ys.size() < 600, "the ghost stays small")
	h.flap()
	for i in 240:
		h.advance(STEP)
	check(not is_nan(h.ghost_y_at(h.scroll)), "the ghost has a height mid-flight")
	check(int(Rivals.tonight("neon_moth", store)["best"]) == points, "tonight's best is that flight")
	h.queue_free()
	var other := spawn({"seed": 99})
	check(other.ghost.is_empty(), "a ghost from another lounge layout is not shown")
	other.queue_free()
