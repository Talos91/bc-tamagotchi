extends SceneTree
## Headless tests for the four first-playable minigames, the result card and the string table.
##   godot --headless --path . --script res://tests/test_minigames.gd
## Exit code 0 = all pass. Games are driven through advance(dt) with scripted "players" (bots).

const Rules = preload("res://scripts/rules.gd")
const NeedsScript = preload("res://scripts/needs.gd")
const Base = preload("res://scripts/minigames/minigame_base.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Pour = preload("res://scripts/minigames/pour_perfect.gd")
const Rhythm = preload("res://scripts/minigames/front_row_rhythm.gd")
const Candle = preload("res://scripts/minigames/candle_talk.gd")
const Pinball = preload("res://scripts/minigames/neon_pinball.gd")
const CardScript = preload("res://scripts/minigames/result_card.gd")

const T0 := 1_800_000_000.0
const TEST_SAVE := "user://test_minigames_save.json"
const SIZE := Vector2(1080, 1400)

var failures := 0
var checks := 0


func _initialize() -> void:
	test_tiers()
	test_strings()
	test_beatmaps()
	test_pour_thresholds()
	test_pour_play()
	test_rhythm_play()
	test_candle_logic()
	test_candle_play()
	test_pinball()
	test_result_card()
	print("")
	print("%d checks, %d failed" % [checks, failures])
	print("MINIGAME TESTS ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("  FAIL: ", msg)


func fresh_needs() -> Node:
	var n: Node = NeedsScript.new()
	n.autosave = false
	n.time_override = T0
	n.save_path = TEST_SAVE
	n.new_game()
	return n


func spawn(script: GDScript) -> Control:
	var g: Control = script.new()
	g.size = SIZE
	root.add_child(g)
	return g


# --- Tiers ---------------------------------------------------------------------------------------

func test_tiers() -> void:
	print("[tiers] 0 good / 1 great / 2 perfect, never a fail tier")
	check(Base.tier_for(0.0) == 0, "score 0 is still tier 0 (no fail word)")
	check(Base.tier_for(0.59) == 0, "0.59 -> tier 0")
	check(Base.tier_for(0.6) == 1, "0.60 -> tier 1")
	check(Base.tier_for(0.849) == 1, "0.849 -> tier 1")
	check(Base.tier_for(0.85) == 2, "0.85 -> tier 2")
	check(Base.tier_for(1.0) == 2, "1.0 -> tier 2")
	check(Base.points_for(0.876) == 88, "points rounds to 0-100")
	check(Base.points_for(2.0) == 100 and Base.points_for(-1.0) == 0, "points clamps")


# --- Strings -------------------------------------------------------------------------------------

func test_strings() -> void:
	print("[strings] key format, EN+TH present, length budgets, every key the scenes use")
	var rows := S.rows()
	check(rows.size() > 60, "string table loaded (%d rows)" % rows.size())
	var re := RegEx.create_from_string("^[a-z0-9_]+(\\.[a-z0-9_]+)+$")
	var seen := {}
	for r in rows:
		var k: String = r["key"]
		check(re.search(k) != null, "key format: " + k)
		check(not seen.has(k), "duplicate key: " + k)
		seen[k] = true
		check(r["en"] != "" and r["th"] != "", "missing EN or TH: " + k)
		check(r["context"] != "", "missing context: " + k)
		var mx: int = r["max"]
		if mx > 0:
			check(S.cluster_count(r["en"]) <= mx, "EN over budget %d: %s (%d)" % [mx, k, S.cluster_count(r["en"])])
			check(S.cluster_count(r["th"]) <= mx, "TH over budget %d: %s (%d)" % [mx, k, S.cluster_count(r["th"])])
		else:
			check(false, "no max for " + k)
		# placeholders must match between languages
		var ph := RegEx.create_from_string("\\{[a-z_]+\\}")
		var en_ph := []
		for m in ph.search_all(r["en"]):
			en_ph.append(m.get_string())
		var th_ph := []
		for m in ph.search_all(r["th"]):
			th_ph.append(m.get_string())
		en_ph.sort()
		th_ph.sort()
		check(en_ph == th_ph, "placeholders differ EN/TH: " + k)
	var need_keys: Array[String] = []
	for g in ["pour_perfect", "front_row_rhythm", "candle_talk", "neon_pinball"]:
		for suffix in ["title", "subtitle", "how_to", "tier_1", "tier_2", "tier_3"]:
			need_keys.append("mg.%s.%s" % [g, suffix])
	for m in Rules.METERS:
		need_keys.append("need.%s.name" % m)
	for i in range(1, 7):
		need_keys.append("npc.mali.talk.%d" % i)
	for k in need_keys:
		check(seen.has(k), "scene uses missing key: " + k)
	S.install()
	TranslationServer.set_locale("th")
	check(S.t("mg.result.done") == "เสร็จ", "tr() resolves Thai")
	check(S.t("mg.pour_perfect.status", {"n": 2, "total": 3}) == "ชั้นที่ 2 จาก 3", "placeholders fill in Thai")
	TranslationServer.set_locale("en")
	check(S.t("mg.pour_perfect.status", {"n": 2, "total": 3}) == "layer 2 of 3", "placeholders fill in English")


# --- Beat maps -----------------------------------------------------------------------------------

func test_beatmaps() -> void:
	print("[beat maps] JSON parsing and judgement")
	for id in Rhythm.SONGS:
		var s := Rhythm.load_song(id)
		check(s["ok"], "%s parses (%s)" % [id, s.get("error", "")])
		if s["ok"]:
			var secs: float = s["length_seconds"]
			print("  %s: %d notes, %.0f s at %d bpm" % [id, s["notes"].size(), secs, s["bpm"]])
			check(s["notes"].size() > 30, id + " has notes")
			check(secs >= 45.0 and secs <= 90.0, id + " length %.0f s within 45-90 (GDD 60-90)" % secs)
			var sorted := true
			for i in range(1, s["notes"].size()):
				if s["notes"][i]["time"] < s["notes"][i - 1]["time"]:
					sorted = false
			check(sorted, id + " notes sorted by time")
	var ok := Rhythm.parse_beatmap('{"bpm":120,"lanes":2,"length_beats":8,"offset":0.5,"notes":[[2,1],[1,0]]}')
	check(ok["ok"], "minimal map parses")
	check(is_equal_approx(ok["notes"][0]["time"], 1.0) and ok["notes"][0]["lane"] == 0, "beat 1 at 120 bpm + 0.5 offset = 1.0 s, sorted first")
	check(is_equal_approx(ok["length_seconds"], 4.5), "length seconds from beats")
	check(not Rhythm.parse_beatmap("not json")["ok"], "garbage rejected")
	check(not Rhythm.parse_beatmap('{"bpm":120,"lanes":2,"notes":[]}')["ok"], "missing length_beats rejected")
	check(not Rhythm.parse_beatmap('{"bpm":0,"lanes":2,"length_beats":4,"notes":[]}')["ok"], "zero bpm rejected")
	check(not Rhythm.parse_beatmap('{"bpm":120,"lanes":2,"length_beats":4,"notes":[[1,2]]}')["ok"], "lane out of range rejected")
	check(not Rhythm.parse_beatmap('{"bpm":120,"lanes":2,"length_beats":4,"notes":[[9,0]]}')["ok"], "beat past the end rejected")
	check(not Rhythm.parse_beatmap('{"bpm":120,"lanes":2,"length_beats":4,"notes":[[1]]}')["ok"], "short note entry rejected")
	check(Rhythm.judge(0.0) == 1 and Rhythm.judge(0.07) == 1, "on the beat is perfect")
	check(Rhythm.judge(-0.1) == 2 and Rhythm.judge(0.14) == 2, "within 140 ms is good")
	check(Rhythm.judge(0.2) == 0, "200 ms off is no hit")
	check(Rhythm.judge(0.2, 1.5) == 2, "relaxed timing widens windows by 50%")
	check(is_equal_approx(Rhythm.score_from(10, 0, 10), 1.0), "all perfect = 1.0")
	check(is_equal_approx(Rhythm.score_from(0, 10, 10), 0.6), "all good = 0.6")
	check(Rhythm.score_from(0, 0, 10) == 0.0 and Rhythm.score_from(0, 0, 0) == 0.0, "no hits = 0, empty map safe")


# --- Pour ----------------------------------------------------------------------------------------

func test_pour_thresholds() -> void:
	print("[pour] layer thresholds and overfill penalty")
	check(Pour.layer_score(0.30, 0.30) == 1.0, "exact = 1.0")
	check(Pour.layer_score(0.31, 0.30) == 1.0, "within 0.02 = 1.0")
	check(Pour.layer_score(0.40, 0.30) < 1.0 and Pour.layer_score(0.40, 0.30) > 0.0, "0.10 off is partial")
	check(is_equal_approx(Pour.layer_score(0.49, 0.30), 0.0) or Pour.layer_score(0.50, 0.30) == 0.0, "0.20 off = 0")
	check(is_equal_approx(Pour.layer_score(0.2, 0.3), Pour.layer_score(0.4, 0.3)), "under and over score the same")
	check(Pour.overfill_penalty(0.0) == 0.0, "no spill, no penalty")
	check(is_equal_approx(Pour.overfill_penalty(0.05), 0.1), "0.05 spill = 0.1 penalty")
	check(Pour.overfill_penalty(5.0) == Pour.OVERFILL_MAX_PENALTY, "penalty capped")
	check(Pour.total_score(Pour.TARGETS, 0.0) == 1.0, "perfect layers = 1.0")
	check(Pour.total_score([1.0, 1.0, 1.0], 0.3) < 0.5, "pouring everything to the rim scores low")
	check(Pour.total_score([], 0.0) == 0.0, "no layers = 0 (still earns the minimum reward upstream)")
	check(Pour.TARGETS[0] < Pour.TARGETS[1] and Pour.TARGETS[1] < Pour.TARGETS[2] and Pour.TARGETS[2] < 1.0, "targets ascend below the rim")


func test_pour_play() -> void:
	print("[pour] scripted play: precise pourer and overpourer")
	var g: Control = spawn(Pour)
	var results := []
	g.finished.connect(func(r): results.append(r))
	g.start()
	_advance(g, 1.6)
	for i in Pour.TARGETS.size():
		g.press()
		var guard := 0
		while g.level < Pour.TARGETS[i] and guard < 5000:
			g.advance(1.0 / 240.0)
			guard += 1
		g.release()
		_advance(g, 1.0)
	check(results.size() == 1, "finished once")
	check(results[0]["score"] >= 0.95, "precise pour scores %.2f" % results[0]["score"])
	check(results[0]["action_id"] == "pour_perfect" and results[0]["need_id"] == "drinks", "result names action and need")
	g.queue_free()

	var g2: Control = spawn(Pour)
	var res2 := []
	g2.finished.connect(func(r): res2.append(r))
	g2.start()
	_advance(g2, 1.6)
	for i in 3:
		g2.press()
		_advance(g2, 14.0)  # never let go until time runs out
		g2.release()
		_advance(g2, 1.0)
	check(res2.size() == 1, "overpourer still finishes")
	check(res2[0]["score"] < 0.4, "overpouring scores low (%.2f)" % res2[0]["score"])
	check(g2.spill > 0.0, "spill recorded")
	g2.queue_free()

	var g3: Control = spawn(Pour)
	var res3 := []
	g3.finished.connect(func(r): res3.append(r))
	g3.start()
	_advance(g3, 40.0)  # never touches the screen
	check(res3.size() == 1 and res3[0]["score"] >= 0.0, "idle player gets a result, not a stuck screen")
	g3.queue_free()

	var g4: Control = spawn(Pour)
	var res4 := []
	g4.finished.connect(func(r): res4.append(r))
	g4.start()
	g4.abandon()
	check(res4.size() == 1, "abandon (Leave) finishes with a result")
	g4.queue_free()


func _advance(g: Control, secs: float, step := 1.0 / 60.0) -> void:
	var t := 0.0
	while t < secs and not g.done:
		g.advance(step)
		t += step


# --- Rhythm --------------------------------------------------------------------------------------

func test_rhythm_play() -> void:
	print("[rhythm] scripted players on a full song")
	for mode in ["perfect", "sloppy", "idle"]:
		var g: Control = spawn(Rhythm)
		g.config = {"song": 1}
		var res := []
		g.finished.connect(func(r): res.append(r))
		g.start()
		var guard := 0
		while not g.done and guard < 20000:
			g.advance(1.0 / 60.0)
			guard += 1
			if mode == "idle":
				continue
			for n in g.notes:
				if n["state"] != 0:
					continue
				var off: float = 0.0 if mode == "perfect" else 0.11
				if absf(g.clock - (n["time"] + off)) < 1.0 / 120.0:
					g.tap(n["lane"])
		check(res.size() == 1, "%s: song ends with a result" % mode)
		var sc: float = res[0]["score"]
		print("  %s: score %.2f, perfect %d good %d missed %d" % [mode, sc, g.perfect, g.good, g.missed])
		if mode == "perfect":
			check(sc >= 0.95, "perfect player scores >= 0.95")
		elif mode == "sloppy":
			check(sc > 0.45 and sc < 0.75, "110 ms-late player lands in the good band")
		else:
			check(sc == 0.0 and g.missed == g.notes.size(), "idle player misses everything and loses nothing else")
		check(res[0]["action_id"] == "front_row_rhythm" and res[0]["need_id"] == "music", "%s: action and need" % mode)
		g.queue_free()


# --- Candle Talk ---------------------------------------------------------------------------------

func test_candle_logic() -> void:
	print("[candle] data, card light, branching")
	var d := Candle.load_data("mali")
	check(not d.is_empty() and d["lines"].size() >= 6 and d["lines"].size() <= 8, "Mali has 6-8 lines")
	for l in d["lines"]:
		check(l["best"] in l["cards"], "line %d best card is offered" % l["id"])
		for o in l["ok"]:
			check(o in l["cards"], "line %d near card is offered" % l["id"])
		check(S.t(l["key"]) != l["key"], "line %d text exists" % l["id"])
	var l1: Dictionary = d["lines"][0]
	check(Candle.card_light(l1, l1["best"]) == 1.0, "best card lights fully")
	check(Candle.card_light(l1, l1["ok"][0]) == 0.5, "near card lights half")
	check(Candle.card_light(l1, "music") == 0.0, "off card gives no light")
	check(Candle.pick_line(d["lines"], 0, 0.0, [])["id"] == 1, "turn 1 = line 1")
	check(Candle.pick_line(d["lines"], 2, 2.0, [1, 2])["id"] == 3, "branch: candle at 2 -> story line 3")
	check(Candle.pick_line(d["lines"], 2, 1.0, [1, 2])["id"] == 4, "branch: candle at 1 -> food line 4")
	check(Candle.pick_line(d["lines"], 3, 1.0, [1, 2, 4])["id"] == 5, "turn 4 = line 5")
	check(Candle.score_from(5.0, 5) == 1.0 and Candle.score_from(2.5, 5) == 0.5, "score = light / turns")


func test_candle_play() -> void:
	print("[candle] full conversations")
	for mode in ["best", "off"]:
		var g: Control = spawn(Candle)
		g.config = {"regular": "mali", "seed": 7}
		var res := []
		g.finished.connect(func(r): res.append(r))
		g.start()
		var turns_seen := 0
		var guard := 0
		while not g.done and guard < 2000:
			guard += 1
			if g.phase == Candle.Phase.ASK:
				turns_seen += 1
				if mode == "best":
					g.choose(g.line["best"])
				else:
					for c in g.line["cards"]:
						if Candle.card_light(g.line, c) == 0.0:
							g.choose(c)
							break
			g.advance(0.5)
		check(res.size() == 1, "%s: conversation ends with a result" % mode)
		check(turns_seen == 5, "%s: five turns" % mode)
		check(res[0]["action_id"] == "candle_talk" and res[0]["need_id"] == "friends", "%s: action and need" % mode)
		check(res[0]["key"] == "mali", "%s: daily_once key is the regular's id" % mode)
		if mode == "best":
			check(res[0]["score"] == 1.0 and res[0]["tier"] == 2, "best cards light the candle fully")
			check(res[0]["extra"]["lean"] == true and 3 in g.used_lines, "best path takes the story branch and earns the lean bonus")
		else:
			check(res[0]["score"] == 0.0 and 4 in g.used_lines and not (3 in g.used_lines), "off path takes the food branch, scores 0 (still the minimum reward)")
		g.queue_free()


# --- Pinball -------------------------------------------------------------------------------------

func test_pinball() -> void:
	print("[pinball] physics sanity and a scripted game")
	check(Pinball.score_from(0) == 0.0 and Pinball.score_from(1500) == 0.5 and Pinball.score_from(99999) == 1.0, "points map to 0..1")
	var g: Control = spawn(Pinball)
	var res := []
	g.finished.connect(func(r): res.append(r))
	g.start()
	check(g.ball_state == Pinball.Ball.LANE, "ball waits in the lane")
	g.launch(0.9)
	var exited := false
	var out_of_bounds := false
	var steps := 0
	while steps < 400:
		g.advance(1.0 / 60.0)
		steps += 1
		if g.pos.x < 540.0 and g.pos.y < 400.0:
			exited = true
		if g.pos.x < -5.0 or g.pos.x > 605.0 or g.pos.y < -5.0:
			out_of_bounds = true
	check(exited, "launched ball leaves the lane and reaches the playfield")
	check(not out_of_bounds, "ball never escapes the cabinet")
	# Bot: keep both flippers up when the ball is low, relaunch when waiting.
	var t := 0.0
	var guard := 0
	while not g.done and guard < 60000:
		guard += 1
		if g.ball_state == Pinball.Ball.LANE:
			g.launch(randf_range(0.6, 1.0))
		var low: bool = g.pos.y > 790.0 and g.vel.y > -50.0
		g.set_flipper(0, low and g.pos.x < 270.0)
		g.set_flipper(1, low and g.pos.x >= 270.0)
		g.advance(1.0 / 60.0)
		if g.pos.x < -5.0 or g.pos.x > 605.0 or g.pos.y < -5.0:
			out_of_bounds = true
	check(res.size() == 1, "bot game finishes (3 balls or 3 min cap), %d frames" % guard)
	check(not out_of_bounds, "ball stayed inside for a whole game")
	if res.size() == 1:
		print("  bot: %d points, score %.2f, %d letters, balls left %d, %.0f s" % [g.points, res[0]["score"], g.lit.count(true), g.balls_left, g.play_time])
		check(res[0]["action_id"] == "pinball" and res[0]["need_id"] == "nightlife", "action and need")
		check(g.points > 0, "bot scored something")
	g.queue_free()
	# Tilt: nudging too often locks the flippers.
	var g2: Control = spawn(Pinball)
	g2.start()
	g2.launch()
	g2.advance(0.05)
	g2.nudge(1)
	g2.nudge(-1)
	g2.nudge(1)
	check(g2.tilt_lock > 0.0, "three nudges in a row tilt")
	g2.set_flipper(0, true)
	check(not g2.flip_held[0], "flippers dead while tilted")
	g2.queue_free()
	# Ball save: a drain inside 10 s does not cost a ball.
	var g3: Control = spawn(Pinball)
	g3.start()
	g3.launch()
	g3.ball_state = Pinball.Ball.LIVE
	g3.pos = Vector2(270, 1100)
	g3.ball_time = 3.0
	g3.advance(1.0 / 60.0)
	check(g3.balls_left == Pinball.BALLS and g3.ball_state == Pinball.Ball.LANE, "ball save returns the ball for free")
	g3.pos = Vector2(270, 1100)
	g3.ball_time = 20.0
	g3.ball_state = Pinball.Ball.LIVE
	g3.advance(1.0 / 60.0)
	check(g3.balls_left == Pinball.BALLS - 1, "later drain costs a ball")
	g3.queue_free()


# --- Result card ---------------------------------------------------------------------------------

func test_result_card() -> void:
	print("[result card] calls Needs.apply_action with the game's action id")
	var cases := [
		{"game": "pour_perfect", "action": "pour_perfect", "meter": "drinks", "key": ""},
		{"game": "front_row_rhythm", "action": "front_row_rhythm", "meter": "music", "key": ""},
		{"game": "candle_talk", "action": "candle_talk", "meter": "friends", "key": "mali"},
		{"game": "neon_pinball", "action": "pinball", "meter": "nightlife", "key": ""},
	]
	for c in cases:
		var n := fresh_needs()
		n.meters[c["meter"]] = 20.0
		var seen := []
		n.action_applied.connect(func(id, _r): seen.append(id))
		var card: Control = CardScript.new()
		card.needs = n
		var result := {"game_id": c["game"], "action_id": c["action"], "need_id": c["meter"], "key": c["key"],
			"score": 1.0, "points": 100, "tier": 2, "extra": {}}
		var o: Dictionary = card.apply(result)
		check(seen == [c["action"]], "%s applies exactly one action '%s' (saw %s)" % [c["game"], c["action"], str(seen)])
		check(o["ok"] and n.meters[c["meter"]] > 20.0, "%s raises %s" % [c["game"], c["meter"]])
		var def: Dictionary = Rules.ACTIONS[c["action"]]
		var top: float = def["gains"][c["meter"]][1]
		check(is_equal_approx(n.meters[c["meter"]] - 20.0, top), "%s perfect score gains the GDD maximum %.0f" % [c["game"], top])
		check(n.ext["minigame_best"][c["game"]] == 100, "%s best score saved in Needs.ext" % c["game"])
		card.free()
		n.free()

	# Minimum, never zero (GDD 9): score 0 still earns the low end.
	var n2 := fresh_needs()
	n2.meters["drinks"] = 20.0
	var card2: Control = CardScript.new()
	card2.needs = n2
	var o2: Dictionary = card2.apply({"game_id": "pour_perfect", "action_id": "pour_perfect", "key": "", "score": 0.0, "points": 0, "tier": 0, "extra": {}})
	check(is_equal_approx(n2.meters["drinks"] - 20.0, 20.0), "score 0 still earns the minimum +20 Drinks")
	check(o2["again_ok"], "AGAIN offered while the next round still earns")
	# Repeat until diminishing returns hide AGAIN.
	var hidden := false
	for i in 12:
		var oo: Dictionary = card2.apply({"game_id": "pour_perfect", "action_id": "pour_perfect", "key": "", "score": 1.0, "points": 100, "tier": 2, "extra": {}})
		if not oo["again_ok"]:
			hidden = true
			break
	check(hidden, "AGAIN is hidden once another round would earn nothing")
	card2.free()
	n2.free()

	# Candle Talk: once per regular per day, hearts only on a good talk.
	var n3 := fresh_needs()
	n3.meters["friends"] = 30.0
	var card3: Control = CardScript.new()
	card3.needs = n3
	var talk := {"game_id": "candle_talk", "action_id": "candle_talk", "key": "mali", "score": 0.9, "points": 90, "tier": 2, "extra": {"regular": "mali"}}
	var t1: Dictionary = card3.apply(talk)
	check(t1["ok"] and t1["hearts"] == 1, "good talk earns Friends and the first heart")
	check(not t1["again_ok"], "no AGAIN for a once-a-day action")
	var t2: Dictionary = card3.apply(talk)
	check(not t2["ok"] and t2["reason"] == "daily_once", "second talk with Mali the same day earns nothing")
	var weak := talk.duplicate()
	weak["key"] = "ploy"
	weak["score"] = 0.3
	weak["extra"] = {"regular": "ploy"}
	var t3: Dictionary = card3.apply(weak)
	check(t3["ok"] and t3["hearts"] == 0, "weak talk: still earns, no heart")
	card3.free()
	n3.free()

	# Unknown action: no crash, no gain.
	var n4 := fresh_needs()
	var card4: Control = CardScript.new()
	card4.needs = n4
	var o4: Dictionary = card4.apply({"game_id": "x", "action_id": "nope", "key": "", "score": 1.0, "points": 100, "tier": 2, "extra": {}})
	check(not o4["ok"], "unknown action id is refused by Needs")
	card4.free()
	n4.free()
