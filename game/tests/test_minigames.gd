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
const Rivals = preload("res://scripts/minigames/mg_rivals.gd")
const CardScript = preload("res://scripts/minigames/result_card.gd")
const Glyph = preload("res://scripts/minigames/need_glyph.gd")
const Cast = preload("res://scripts/cast.gd")
const Zones = preload("res://scripts/zones/venue_zones.gd")
const Chars = preload("res://assets/chars/bc_chars.gd")
const FrameScene = preload("res://scenes/ui/minigame_frame.tscn")

const T0 := 1_800_000_000.0
const TEST_SAVE := "user://test_minigames_save.json"
const SIZE := Vector2(1080, 1400)

class RivalStore:
	extends RefCounted
	var ext := {}


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
	test_q9_sprites_fx_rivals()
	await test_chat_cast()
	test_cast()
	test_pinball()
	test_pinball_pour_rivals()
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
	print("[tiers] miss / 0 good / 1 great / 2 perfect (06-stakes §7.2)")
	check(Base.tier_for(0.0) == Base.TIER_MISS and Base.tier_for(0.24) == Base.TIER_MISS, "below 0.25 is a miss")
	check(Base.tier_for(0.25) == 0, "0.25 is good")
	check(Base.tier_for(0.3, 0.4) == Base.TIER_MISS and Base.tier_for(0.4, 0.4) == 0, "Rusty raises the line to 0.4")
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
	for id in ["tt", "tong", "ploy", "jules", "dougie", "lung_nop", "bow", "hiro"]:
		for i in range(1, 7):
			need_keys.append("npc.%s.talk.%d" % [id, i])
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
	print("[pour] layer thresholds, the spoil band and the glass-by-glass ramp")
	check(Pour.layer_score(0.30, 0.30) == 1.0, "exact = 1.0")
	check(Pour.layer_score(0.31, 0.30) == 1.0, "within 0.02 = 1.0")
	check(Pour.layer_score(0.40, 0.30) < 1.0 and Pour.layer_score(0.40, 0.30) > 0.0, "0.10 off is partial")
	check(is_equal_approx(Pour.layer_score(0.49, 0.30), 0.0) or Pour.layer_score(0.50, 0.30) == 0.0, "0.20 off = 0")
	check(is_equal_approx(Pour.layer_score(0.2, 0.3), Pour.layer_score(0.4, 0.3)), "under and over score the same")
	check(Pour.TARGETS[0] < Pour.TARGETS[1] and Pour.TARGETS[1] < Pour.TARGETS[2] and Pour.TARGETS[2] < 1.0, "targets ascend below the rim")
	# Endless ramp (docs/design/15-minigame-ramp.md): layer points, the spoil band, the per-glass numbers and lines.
	check(Pour.layer_points(1.0) == 33 and Pour.layer_points(0.0) == 0 and Pour.layer_points(0.5) == 17, "a layer = round(33 x its score)")
	check(Pour.is_spoiled(0.41, 0.30) and Pour.is_spoiled(0.19, 0.30), "more than 0.10 off the line spoils the layer")
	check(not Pour.is_spoiled(0.39, 0.30) and not Pour.is_spoiled(0.21, 0.30), "within 0.10 is a scored layer")
	check(not Pour.is_spoiled(0.44, 0.30, true) and Pour.is_spoiled(0.46, 0.30, true), "relaxed: the spoil band x1.5")
	check(Pour.idle_seconds() == 8.0 and Pour.idle_seconds(true) > 8.0, "8 s idle spoils (relaxed waits longer)")
	check(is_equal_approx(Pour.rate_at(1), 0.075) and is_equal_approx(Pour.wobble_at(1), 0.35), "glass 1 pours as before")
	var rises := true
	for gl in range(2, Pour.GLASS_CAP + 1):
		rises = rises and Pour.rate_at(gl) > Pour.rate_at(gl - 1) and Pour.wobble_at(gl) > Pour.wobble_at(gl - 1)
	check(rises, "pour rate and wobble rise every glass up to glass %d" % Pour.GLASS_CAP)
	check(is_equal_approx(Pour.rate_at(Pour.GLASS_CAP), 0.15) and is_equal_approx(Pour.wobble_at(Pour.GLASS_CAP), 0.55), "cap: 0.15 glass/s, wobble 55 %")
	check(Pour.rate_at(25) == Pour.rate_at(Pour.GLASS_CAP) and Pour.wobble_at(25) == Pour.wobble_at(Pour.GLASS_CAP), "the numbers stop at the cap")
	check(Pour.glass_targets(20000, 1) == Pour.TARGETS, "glass 1 keeps today's lines")
	var lines_ok := true
	var differs := false
	for sd in [20000, 20001, 7]:
		for gl in range(2, 31):
			var tg: Array[float] = Pour.glass_targets(sd, gl)
			lines_ok = lines_ok and tg.size() == 3 and tg == Pour.glass_targets(sd, gl)
			lines_ok = lines_ok and tg[0] >= Pour.LINE_MIN - 1e-6 and tg[2] <= Pour.LINE_MAX + 1e-6
			lines_ok = lines_ok and tg[1] - tg[0] >= Pour.LINE_GAP - 1e-6 and tg[2] - tg[1] >= Pour.LINE_GAP - 1e-6
			differs = differs or tg != Pour.glass_targets(sd, 2)
	check(lines_ok, "later glasses: 3 seeded lines, ordered, >= 0.18 apart within 0.2..0.9, same seed same lines")
	check(differs, "later glasses get new lines")


func test_pour_play() -> void:
	print("[pour] scripted play: precise pourer glass after glass, overpourer, spoiled layers, idle player")
	var g: Control = spawn(Pour)
	g.config = {"seed": 20000}
	var results := []
	g.finished.connect(func(r): results.append(r))
	g.start()
	check(g.ramp_level == 1 and g.glass == 1 and g.lives_left == Base.STRIKES, "starts on glass 1, level 1, 3 lives")
	pour_glass(g)
	check(not g.done and results.is_empty(), "a full glass no longer ends the round")
	check(g.record_points() >= 95, "a precise glass 1 = %d points (about the old 100)" % g.record_points())
	var glasses := 1
	while glasses < 12 and pour_glass(g):
		glasses += 1
	check(glasses == 12 and not g.done and g.glass >= 12, "the precise pourer keeps pouring past the old end (%d glasses)" % glasses)
	check(g.ramp_level == Pour.GLASS_CAP, "the level reaches the cap (%d)" % g.ramp_level)
	check(g.record_points() > 100 and g.lives_left == Base.STRIKES, "points uncapped (%d), no strike" % g.record_points())
	# then the pourer walks off: the idle layers spoil, the round ends on exactly the third
	var lives_seen := []
	var early_end := false
	var guard := 0
	while not g.done and guard < 60 * 60:
		var before: int = g.lives_left
		g.advance(1.0 / 60.0)
		guard += 1
		if g.lives_left != before:
			lives_seen.append(g.lives_left)
		early_end = early_end or (g.done and g.lives_left > 0)
	check(lives_seen == [2, 1, 0] and not early_end, "idle layers: a strike each, the end on the third (%s)" % str(lives_seen))
	check(results.size() == 1, "finished once")
	if results.size() == 1:
		var ex: Dictionary = results[0]["extra"]
		check(g.end_reason == "lost", "end_reason lost")
		check(int(ex.get("level", 0)) == Pour.GLASS_CAP and int(ex.get("misses", -1)) == 3, "result extra: level %s, misses %s" % [ex.get("level"), ex.get("misses")])
		check(is_equal_approx(float(ex.get("speed", 0.0)), Pour.rate_at(g.glass)), "result extra: speed = the pour rate")
		check(int(results[0]["points"]) == g.record_points(), "result points = the record (%d)" % results[0]["points"])
		check(is_equal_approx(results[0]["score"], minf(1.0, g.record_points() / 100.0)), "score = min(1, points/100)")
		check(results[0]["action_id"] == "pour_perfect" and results[0]["need_id"] == "drinks", "result names action and need")
	g.queue_free()

	var g2: Control = spawn(Pour)
	var res2 := []
	g2.finished.connect(func(r): res2.append(r))
	g2.start()
	pour_glass(g2, 2.0)  # never lets go before the rim
	check(res2.size() == 1 and g2.end_reason == "lost", "overpourer: three spills, three strikes, lost")
	check(res2.size() == 1 and res2[0]["score"] < 0.4, "overpouring scores low")
	check(g2.spill > 0.0 and g2.layers_done == 3, "spill recorded, three layers spoiled")
	g2.queue_free()

	var g5: Control = spawn(Pour)
	g5.start()
	pour_layer(g5, 0.15)
	check(g5.lives_left == 2 and g5.record_points() == 0 and g5.layer_scores.size() == 1 and g5.layer_scores[0] == 0.0, "0.15 off the line spoils the layer: a strike, 0 points")
	check(is_equal_approx(g5.locked[0], Pour.TARGETS[0]), "a spoiled layer is evened to its line")
	pour_layer(g5, 0.08)
	var sc5: float = g5.layer_scores[1] if g5.layer_scores.size() > 1 else -1.0
	check(g5.lives_left == 2 and sc5 > 0.4 and sc5 < 0.9, "0.08 off is a scored layer (%.2f)" % sc5)
	check(g5.record_points() == Pour.layer_points(sc5), "points = round(33 x layer score) (%d)" % g5.record_points())
	g5.queue_free()

	var g3: Control = spawn(Pour)
	var res3 := []
	g3.finished.connect(func(r): res3.append(r))
	g3.start()
	_advance(g3, 26.0)  # never touches the screen: 1.5 s intro, then 8 s + 0.8 s settle per spoiled layer
	check(not g3.done and g3.lives_left == 1, "idle: two strikes by 26 s (%d left)" % g3.lives_left)
	_advance(g3, 4.0)
	check(res3.size() == 1 and g3.end_reason == "lost", "idle player loses on the third spoiled layer, not a stuck screen")
	check(res3.size() == 1 and int(res3[0]["extra"].get("level", 0)) == 1 and int(res3[0]["extra"].get("misses", 0)) == 3, "idle: result extra level 1, misses 3")
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
	print("[rhythm] endless set: tempo ramp, stages, chords and double taps, 3 missed claps")
	# The ramp numbers (docs/design/15-minigame-ramp.md): 96 BPM +4 every 8 bars to 152; lead 1.7 -> 1.2; level 1..15.
	check(Rhythm.bpm_at(0) == 96.0 and Rhythm.bpm_at(1) == 100.0 and Rhythm.bpm_at(14) == 152.0, "tempo 96, +4 a step, 152 at step 14")
	check(Rhythm.bpm_at(15) == 152.0 and Rhythm.bpm_at(60) == 152.0, "tempo stops at the 152 BPM cap")
	check(is_equal_approx(Rhythm.lead_at(0), 1.7) and is_equal_approx(Rhythm.lead_at(14), 1.2) and is_equal_approx(Rhythm.lead_at(40), 1.2), "notes fall 1.7 s -> 1.2 s at the cap")
	check(Rhythm.level_at(0) == 1 and Rhythm.level_at(14) == 15 and Rhythm.level_at(50) == 15 and Rhythm.LEVEL_CAP == 15, "level 1 + tempo steps, cap 15")
	var rising := true
	for k in 14:
		if not (Rhythm.bpm_at(k + 1) > Rhythm.bpm_at(k) and Rhythm.lead_at(k + 1) < Rhythm.lead_at(k) and Rhythm.level_at(k + 1) == Rhythm.level_at(k) + 1):
			rising = false
	check(rising, "every step up to the cap: faster tempo, shorter lead, next level")
	# The clock through changing tempo: beat -> time by accumulated segments, and back.
	check(is_equal_approx(Rhythm.beat_time(32.0), 20.0) and is_equal_approx(Rhythm.beat_time(64.0), 39.2), "8 bars at 96 = 20 s, the next 8 at 100 = 19.2 s")
	check(is_equal_approx(Rhythm.beat_time(-4.0), -2.5), "the count-in runs at 96 BPM")
	check(absf(Rhythm.time_to_beat(Rhythm.beat_time(77.5)) - 77.5) < 1e-6 and absf(Rhythm.time_to_beat(Rhythm.beat_time(1000.25)) - 1000.25) < 1e-6, "time_to_beat inverts beat_time (past the cap too)")
	check(Rhythm.step_at_time(19.9) == 0 and Rhythm.step_at_time(20.1) == 1 and Rhythm.step_at_time(-1.0) == 0, "the tempo steps at bar 9")
	# The stages by bar, in the generated chunks (seeded, deterministic).
	var c0: Array[Dictionary] = Rhythm.chunk_notes(0, 7)
	var c1: Array[Dictionary] = Rhythm.chunk_notes(1, 7)
	var c2: Array[Dictionary] = Rhythm.chunk_notes(2, 7)
	var c3: Array[Dictionary] = Rhythm.chunk_notes(3, 7)
	check(c0.size() == 32, "bars 1-8: one quarter note a beat (%d)" % c0.size())
	var one_at_a_time := true
	for i in range(1, c0.size()):
		if float(c0[i]["beat"]) == float(c0[i - 1]["beat"]) or fmod(float(c0[i]["beat"]), 1.0) != 0.0:
			one_at_a_time = false
	check(one_at_a_time, "bars 1-8: quarters, one lane at a time")
	var has_chord := func(arr: Array[Dictionary]) -> bool:
		for i in range(1, arr.size()):
			if float(arr[i]["beat"]) == float(arr[i - 1]["beat"]) and int(arr[i]["lane"]) != int(arr[i - 1]["lane"]):
				return true
		return false
	var has_double := func(arr: Array[Dictionary]) -> bool:
		for i in range(1, arr.size()):
			if float(arr[i]["beat"]) - float(arr[i - 1]["beat"]) == 0.5 and int(arr[i]["lane"]) == int(arr[i - 1]["lane"]):
				return true
		return false
	var has_run := func(arr: Array[Dictionary]) -> bool:
		for i in range(3, arr.size()):
			var ok := true
			for j in 3:
				var a: Dictionary = arr[i - 3 + j]
				var b: Dictionary = arr[i - 2 + j]
				if float(b["beat"]) - float(a["beat"]) != 0.5 or int(b["lane"]) == int(a["lane"]):
					ok = false
			if ok:
				return true
		return false
	check(not has_chord.call(c0) and has_chord.call(c1) and not has_double.call(c1), "bar 9: chords (two lanes at once) start, no double taps yet")
	check(has_double.call(c2) and not has_run.call(c2), "bar 17: double taps (same lane, half a beat apart) start, no runs yet")
	check(has_run.call(c3), "bar 25: eighth-note runs swapping lanes")
	check(str(Rhythm.chunk_notes(5, 7)) == str(Rhythm.chunk_notes(5, 7)) and str(Rhythm.chunk_notes(5, 7)) != str(Rhythm.chunk_notes(5, 8)), "chunks are seeded: same night same set, another night another")
	var playable := true
	var sorted := true
	for k in 20:
		var ch: Array[Dictionary] = Rhythm.chunk_notes(k, 3)
		var last_beat := [-9.0, -9.0]
		for i in ch.size():
			var lane: int = ch[i]["lane"]
			if float(ch[i]["beat"]) - float(last_beat[lane]) < 0.5 - 1e-6:
				playable = false
			last_beat[lane] = float(ch[i]["beat"])
			if i > 0 and float(ch[i]["time"]) < float(ch[i - 1]["time"]):
				sorted = false
	check(playable, "same-lane claps never closer than half a beat (0.2 s at 152 BPM)")
	check(sorted, "every chunk is sorted by time")
	# Expected claps a beat from the cell weights (single 1, chord 2, double 2, run 4 over 2 beats): rises to the cap.
	var density := func(k: int) -> float:
		var w: PackedFloat32Array = Rhythm.cell_weights(k)
		var tot: float = w[0] + w[1] + w[2] + w[3]
		return (w[0] + 2.0 * w[1] + 2.0 * w[2] + 4.0 * w[3]) / (tot + w[3])
	var denser := true
	for k in range(Rhythm.STAGE_RUNS, 14):
		if not (density.call(k + 1) > density.call(k)):
			denser = false
	check(denser and is_equal_approx(density.call(14), density.call(30)) and density.call(0) == 1.0, "density rises every step to the cap, then holds")
	check(Rhythm.chunk_notes(14, 3).size() > c0.size(), "the cap chunk holds more claps than bars 1-8")

	# Two notes at once in different lanes, and two close notes in one lane (the nearest unjudged note).
	var g4: Control = spawn(Rhythm)
	g4.config = {"seed": 7}
	g4.start()
	g4.clock = 10.0
	g4.notes = [{"time": 10.0, "lane": 0, "beat": 16.0, "state": 0}, {"time": 10.0, "lane": 1, "beat": 16.0, "state": 0},
		{"time": 10.3, "lane": 0, "beat": 16.5, "state": 0}, {"time": 10.5, "lane": 0, "beat": 16.8, "state": 0}]
	g4.tap(0)
	g4.tap(1)
	check(g4.notes[0]["state"] == 1 and g4.notes[1]["state"] == 1, "a chord: one tap a lane judges both notes")
	g4.clock = 10.3
	g4.tap(0)
	check(g4.notes[2]["state"] == 1 and g4.notes[3]["state"] == 0, "a double tap: the first tap takes the nearer note")
	g4.clock = 10.46
	g4.tap(0)
	check(g4.notes[3]["state"] == 1 and g4.perfect == 4, "a double tap: the second tap takes the next one")
	g4.queue_free()

	for mode in ["perfect", "sloppy", "idle"]:
		var g: Control = spawn(Rhythm)
		g.config = {"seed": 7}
		var res := []
		g.finished.connect(func(r): res.append(r))
		g.start()
		check(g.last_status == S.t("mg.ramp.status", {"level": 1, "points": 0, "lives": 3}), "%s: status shows level, points, lives" % mode)
		# The bot plays until a moment, then stops (idle): perfect past the cap, sloppy 50 s, idle from the start.
		var play_until: float = Rhythm.beat_time(32.0 * 14.0) + 4.0 if mode == "perfect" else (50.0 if mode == "sloppy" else -99.0)
		var off: float = 0.0 if mode == "perfect" else 0.11
		var at_stop := {}
		var max_notes := 0
		var done_before_third := false
		var guard := 0
		while not g.done and guard < 20000:
			g.advance(1.0 / 60.0)
			guard += 1
			max_notes = maxi(max_notes, g.notes.size())
			if g.missed == 2 and g.done:
				done_before_third = true
			if g.clock >= play_until:
				if at_stop.is_empty():
					at_stop = {"missed": g.missed, "level": g.ramp_level, "perfect": g.perfect, "good": g.good}
				continue
			for n in g.notes:
				if float(n["time"]) > g.clock + 0.2:
					break
				if n["state"] == 0 and absf(g.clock - (float(n["time"]) + off)) <= 1.0 / 120.0:
					g.tap(int(n["lane"]))
		check(res.size() == 1 and g.done, "%s: the round ends with a result (guard %d)" % [mode, guard])
		if res.is_empty():
			g.queue_free()
			continue
		var r: Dictionary = res[0]
		var sc: float = r["score"]
		var ex: Dictionary = r["extra"]
		print("  %s: level %d, %d BPM, points %d, perfect %d good %d missed %d, %.0f s" % [mode, g.ramp_level, ex["speed"], g.record_points(), g.perfect, g.good, g.missed, g.clock])
		check(g.missed == 3 and not done_before_third and g.end_reason == "lost", "%s: lost on exactly the 3rd missed clap" % mode)
		check(ex["level"] == g.ramp_level and ex["misses"] == 3 and ex["lives_left"] == 0, "%s: result extra carries level and misses" % mode)
		check(absf(sc - minf(1.0, g.record_points() / 100.0)) < 1e-6 and r["points"] == g.record_points(), "%s: score = min(1, points/100), points = the record" % mode)
		check(max_notes < 260, "%s: the chart stays chunked (max %d notes held)" % [mode, max_notes])
		if mode == "perfect":
			check(at_stop.get("missed", -1) == 0, "perfect player misses nothing up to the cap (chords and double taps included)")
			check(at_stop.get("level", 0) == 15 and g.ramp_level == 15 and ex["speed"] == 152, "perfect player reaches level 15 at 152 BPM")
			check(g.record_points() > 100 and g.perfect > 300 and g.record_points() == 2 * g.perfect, "perfect player: 2 a clap, far past an old song (%d)" % g.record_points())
			check(sc == 1.0, "perfect player scores 1.0")
			check_rhythm_gain(sc, 18.0)
		elif mode == "sloppy":
			check(at_stop.get("missed", -1) == 0 and at_stop.get("perfect", -1) == 0 and int(at_stop.get("good", 0)) > 60, "110 ms-late player: every clap good, none missed (%s)" % [at_stop])
			check(g.record_points() == g.good, "good claps are worth 1")
			check_rhythm_gain(sc, lerpf(12.0, 18.0, sc))
		else:
			check(sc == 0.0 and g.record_points() == 0 and ex["level"] == 1 and g.clock < 4.0, "idle player: out after 3 claps, level 1, 0 points")
		check(r["action_id"] == "front_row_rhythm" and r["need_id"] == "music", "%s: action and need" % mode)
		g.queue_free()


## GDD section 9 tuning: a song gives +12 to +18 Music by accuracy.
func check_rhythm_gain(score: float, expected: float) -> void:
	var def: Dictionary = Rules.ACTIONS["front_row_rhythm"]
	check(def["gains"]["music"] == [12.0, 18.0], "Front Row Rhythm range is +12-18 Music")
	var n := fresh_needs()
	n.meters["music"] = 20.0
	n.apply_action("front_row_rhythm", score)
	var got: float = n.meters["music"] - 20.0
	check(got >= 12.0 - 0.01 and got <= 18.0 + 0.01, "rhythm gain %.2f within 12-18" % got)
	check(absf(got - expected) < 0.5 or score < 0.95, "rhythm gain %.2f matches score %.2f" % [got, score])
	n.free()


# --- Candle Talk ---------------------------------------------------------------------------------

func test_candle_logic() -> void:
	print("[candle] data, card light, branching")
	var d := Candle.load_data("tt")
	check(not d.is_empty() and d["lines"].size() >= 6 and d["lines"].size() <= 8, "Tt has 6-8 lines")
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
	# Endless (docs/design/15-minigame-ramp.md): the reply timer, the level, the points, the lines coming round again.
	check(Candle.reply_time(1) == 0.0 and Candle.reply_time(5) == 0.0, "turns 1-5: no reply timer")
	check(Candle.reply_time(6) == 8.0 and Candle.reply_time(7) == 7.5 and Candle.reply_time(14) == 4.0, "timer 8 s at turn 6, -0.5 s a turn, 4 s at turn 14")
	check(Candle.reply_time(15) == 4.0 and Candle.reply_time(60) == 4.0, "the timer stops at the 4 s cap")
	check(Candle.level_at_turn(1) == 1 and Candle.level_at_turn(5) == 1 and Candle.level_at_turn(6) == 2 and Candle.level_at_turn(14) == 10 and Candle.level_at_turn(40) == 10, "level 1 for turns 1-5, +1 a turn, 10 at turn 14")
	var ramp_ok := true
	for tn in range(6, 14):
		if not (Candle.reply_time(tn + 1) < Candle.reply_time(tn) and Candle.level_at_turn(tn + 1) == Candle.level_at_turn(tn) + 1):
			ramp_ok = false
	check(ramp_ok, "every turn up to 14: less time, next level")
	check(Candle.points_of([1.0, 0.5, 0.0, 1.0]) == 50 and Candle.points_of([]) == 0, "points: 20 a best card, 10 a near one, 0 off")
	check(Candle.first_light([1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0], 5) == 5.0 and Candle.first_light([0.5, 1.0], 5) == 1.5, "the score reads the first five turns only")
	var lines: Array = d["lines"]
	check(int(Candle.next_round_line(lines, [1, 2, 3, 5, 6], 6, 0)["id"]) == 4, "turn 6: the one line not said yet")
	var never_prev := true
	for roll in 12:
		if int(Candle.next_round_line(lines, [], 4, roll)["id"]) == 4:
			never_prev = false
	check(never_prev, "a new round never opens with the line just said")


func test_candle_play() -> void:
	print("[candle] endless talks: best, near and off players, the reply timer, 3 gutters")
	# best: the best card for 20 turns, then no answer (3 timeouts). half: the near card for 5 turns, then no answer.
	# off: an off card every turn (out on turn 3).
	for mode in ["best", "half", "off"]:
		var g: Control = spawn(Candle)
		g.config = {"regular": "tt", "seed": 7}
		var res := []
		g.finished.connect(func(r): res.append(r))
		g.start()
		check(g.last_status == S.t("mg.ramp.status", {"level": 1, "points": 0, "lives": 3}), "%s: status shows level, points, lives" % mode)
		var answer_turns := 20 if mode == "best" else (5 if mode == "half" else 99)
		var turns_seen := 0
		var seen_turn := -1
		var repeats := 0
		var prev_id := -1
		var timers := {}
		var gutters_at_5 := -1
		var done_before_third := false
		var guard := 0
		while not g.done and guard < 2000:
			guard += 1
			if g.done == false and g.gutters < 3 and g.phase == Candle.Phase.CLOSE:
				done_before_third = true
			if g.phase == Candle.Phase.ASK and g.turn != seen_turn:
				seen_turn = g.turn
				turns_seen += 1
				var id := int(g.line["id"])
				if id == prev_id:
					repeats += 1
				prev_id = id
				timers[g.turn + 1] = g.reply_total
				if g.turn == 5:
					gutters_at_5 = g.gutters
			if g.phase == Candle.Phase.ASK and g.history.size() < answer_turns:
				if mode == "best":
					g.choose(g.line["best"])
				elif mode == "half":
					g.choose(g.line["ok"][0])
				else:
					for c in g.line["cards"]:
						if Candle.card_light(g.line, c) == 0.0:
							g.choose(c)
							break
			g.advance(0.5)
		check(res.size() == 1 and g.done, "%s: the talk ends with a result (guard %d)" % [mode, guard])
		if res.is_empty():
			g.queue_free()
			continue
		var r: Dictionary = res[0]
		var ex: Dictionary = r["extra"]
		print("  %s: %d turns, level %d, points %d, score %.2f, gutters %d" % [mode, g.history.size(), g.ramp_level, g.record_points(), r["score"], g.gutters])
		check(r["action_id"] == "candle_talk" and r["need_id"] == "friends", "%s: action and need" % mode)
		check(r["key"] == "tt", "%s: daily_once key is the regular's id" % mode)
		check(g.gutters == 3 and not done_before_third and g.end_reason == "lost", "%s: the candle goes out on exactly the 3rd gutter" % mode)
		check(ex["level"] == g.ramp_level and ex["misses"] == 3 and ex["lives_left"] == 0, "%s: result extra carries level and misses" % mode)
		check(repeats == 0, "%s: never the same line twice in a row" % mode)
		check(absf(float(r["score"]) - minf(1.0, Candle.points_of(g.history.slice(0, 5)) / 100.0)) < 1e-6, "%s: score = the first five turns' points / 100" % mode)
		check(r["points"] == maxi(g.record_points(), roundi(float(r["score"]) * 100.0)), "%s: points = the uncapped record" % mode)
		if mode == "best":
			check(turns_seen == 23 and g.history.size() == 23, "best: 20 answered turns + 3 timeouts (%d)" % turns_seen)
			check(timers.get(5, -1.0) == 0.0 and timers.get(6, -1.0) == 8.0 and timers.get(10, -1.0) == 6.0 and timers.get(14, -1.0) == 4.0 and timers.get(23, -1.0) == 4.0, "best: reply timer 8 s at turn 6 down to 4 s from turn 14 (%s)" % [timers])
			check(g.ramp_level == 10, "best: level 10 at the cap")
			check(g.record_points() == 400, "best: 20 best cards = 400 points, far past an old talk")
			check(r["score"] == 1.0 and r["tier"] == 2 and ex["lean"] == true and 3 in g.used_lines, "best: the first five light the candle fully, story branch, lean bonus")
			var each_line_back := true
			for l in g.data["lines"]:
				if g.used_lines.count(int(l["id"])) < 3:
					each_line_back = false
			check(each_line_back, "best: every line comes round again (%s)" % [g.used_lines])
		elif mode == "half":
			check(gutters_at_5 == 0, "half: a near card never gutters")
			check(g.history.size() == 8 and g.history.slice(5) == [0.0, 0.0, 0.0], "half: then three timeouts put the candle out")
			check(is_equal_approx(r["score"], 0.5) and g.record_points() == 50 and ex["lean"] == false, "half: score 0.5, 50 points, no lean")
		else:
			check(turns_seen == 3 and g.history == [0.0, 0.0, 0.0], "off: three off cards, out on turn 3")
			check(r["score"] == 0.0 and g.record_points() == 0 and 4 in g.used_lines and not (3 in g.used_lines), "off path takes the food branch, scores 0 (still the minimum reward)")
			check(ex["level"] == 1, "off: still level 1")
		g.queue_free()


## A chat with every regular (each has a set of their own since 2026-11-02; Prae, an owner, is silent for now and offers
## no talk), through the real frame: it starts with the regular's own lines, the five turns play out, the result card
## applies the talk, DONE closes the frame and hands control back. Hearts for regulars.
func test_chat_cast() -> void:
	print("[chat] every regular's talk starts, finishes and gives control back")
	var ids := []
	for p in Chars.manifest().get("presets", []):
		if str(p.get("role", "")) == "regular":
			ids.append(str(p["name"]))
	check(ids.size() == 8, "eight regulars in the manifest (%s)" % [ids])
	for id in ids:
		var n := fresh_needs()
		n.meters["friends"] = 30.0
		var fr: Control = FrameScene.instantiate()
		fr.needs = n
		root.add_child(fr)
		await process_frame   # the frame builds itself in _ready
		var closed := []
		fr.closed.connect(func(r): closed.append(r))
		fr.open(load("res://scenes/minigames/candle_talk/candle_talk.tscn"), {"regular": id, "seed": 3})
		var g: Control = fr.game
		check(g.running and g.phase == Candle.Phase.ASK and str(g.data.get("regular", "")) == id, "%s: the talk starts with their own lines" % id)
		check(g._name_label.text != "" and not g._name_label.text.begins_with("cast."), "%s: a real name over the bubble (%s)" % [id, g._name_label.text])
		# Endless since 2026-11-20: the best card for the five scored turns, then no answer until 3 timeouts put the
		# candle out (turns 6-8).
		var guard := 0
		var asked := -1
		while not g.done and guard < 400:
			guard += 1
			if g.phase == Candle.Phase.ASK and g.turn != asked:
				asked = g.turn
				check(g._cards_box.get_children().filter(func(c): return not c.is_queued_for_deletion()).size() == 3, "%s: three topic cards to tap (turn %d)" % [id, g.turn + 1])
				if g.turn < 5:
					g.choose(g.line["best"])
			g.advance(0.5)
		check(g.done and g.history.size() == 8 and g.end_reason == "lost", "%s: five turns, then three timeouts end it" % id)
		check(is_instance_valid(fr._card) and closed.is_empty(), "%s: the result card is up, the frame still open" % id)
		fr._card.done.emit()
		check(closed.size() == 1 and closed[0]["extra"]["regular"] == id, "%s: DONE closes the frame (control goes back)" % id)
		check(n.meters["friends"] > 30.0, "%s: the talk refilled Friends (%.1f)" % [id, n.meters["friends"]])
		var kept: bool = n.ext.get(CardScript.HEARTS_KEY, {}).has(id)
		check(kept == Cast.befriends(id), "%s: hearts kept only for regulars (kept %s)" % [id, kept])
		fr.free()
		n.free()


## Cast after Daniele's answers of 2026-11-01/02: Tt is regular #4 (hearts, lines, a name), Prae is a silent owner,
## Khun Joy is retired, every regular has a name string and a well-formed Candle Talk set, and the nightly placement
## (Cast.hosts) keeps Tt at the Long Table and brings Prae every other night to each of her three spots.
func test_cast() -> void:
	print("[cast] Tt, Prae, no Khun Joy, regulars' names and lines, tonight's hosts")
	check(Cast.role("tt") == Cast.REGULAR and Cast.befriends("tt") and Cast.has_lines("tt"), "Tt is a regular with hearts and lines")
	check(S.t("cast.tt.name") == "Ty" and Zones.tag_text("tt") == "Ty  ♥", "Ty's name and heart tag (%s)" % Zones.tag_text("tt"))   # renamed Ty in dd4e03c (id stays tt)
	var tt_preset: Dictionary = {}
	for p in Chars.manifest().get("presets", []):
		if str(p["name"]) == "tt":
			tt_preset = p
	check(str(tt_preset.get("body", "")) == "tall" and ResourceLoader.exists("res://assets/chars/presets/tt.glb"), "Tt has a model preset (tall body, tt.glb)")
	check(Cast.is_owner("mali") and not Cast.befriends("mali") and not Cast.has_lines("mali"), "Prae is an owner with no hearts and no lines")
	check(S.t("npc.mali.talk.1") == "npc.mali.talk.1", "Prae's old quiz-captain lines are gone")
	var joy := false
	for p in Chars.manifest().get("presets", []):
		joy = joy or str(p["name"]).contains("joy") or str(p.get("display", "")).contains("Joy")
	for r in S.rows():
		joy = joy or str(r["en"]).contains("Khun Joy") or str(r["key"]).contains("joy")
	joy = joy or ResourceLoader.exists("res://assets/chars/presets/khun_joy.glb")
	check(not joy, "no Khun Joy in presets, models or strings")
	for p in Chars.manifest().get("presets", []):
		if str(p.get("role", "")) != "regular":
			continue
		var id := str(p["name"])
		var key := "cast.%s.name" % id
		check(S.t(key) != key and Cast.name_of(id) == S.t(key), "%s has a name string (%s)" % [id, S.t(key)])
		var d := Candle.load_data(id)
		check(d.get("regular", "") == id and d.get("lines", []).size() == 6, "%s has a Candle Talk set of six lines" % id)
		for l in d.get("lines", []):
			check(l["best"] in l["cards"] and l["ok"].all(func(o): return o in l["cards"]) and S.t(l["key"]) != l["key"], "%s line %d: cards and text" % [id, l["id"]])
		check(Candle.pick_line(d["lines"], 2, 2.0, [1, 2])["id"] == 3 and Candle.pick_line(d["lines"], 2, 1.0, [1, 2])["id"] == 4, "%s: story line 3 behind the candle, line 4 otherwise" % id)
	var spots := {}
	for n in 6:
		var h: Dictionary = Cast.hosts(n)
		check(h.get(Cast.TT_ZONE, "") == "tt", "night %d: Tt at the Long Table" % n)
		var prae := h.keys().filter(func(k): return h[k] == "mali")
		check(prae.size() == (1 if n % 2 == 0 else 0), "night %d: Prae %s" % [n, "in" if n % 2 == 0 else "out"])
		for k in prae:
			spots[k] = true
	check(spots.size() == 3 and spots.has("table:WestTable0") and spots.has("table:Table0") and spots.has("tall:BufferTall3"), "Prae's three spots in turn (%s)" % [spots.keys()])
	Cast.night_override = 4
	var defs := Zones.defs_from_layout(Zones.LAYOUT_PATH)
	Cast.night_override = -1
	var by := {}
	for z in defs:
		by[z["id"]] = z
	check(by.has("table:LongTable") and by["table:LongTable"]["regular"] == "tt" and by["table:LongTable"]["host"] == "tt", "Long Table zone: Tt hosts it and offers the talk")
	check(by.has("tall:BufferTall3") and by["tall:BufferTall3"]["host"] == "mali" and by["tall:BufferTall3"]["regular"] == "", "night 4: Prae at the buffer tall table, no talk")
	check(defs.filter(func(z): return z["regular"] != "").size() == 1, "one zone offers a Candle Talk")


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
	# Bot: keep both flippers up when the ball is low, relaunch when waiting (up to 4 minutes: no clock ends it now).
	var guard := 0
	while not g.done and guard < 60 * 240:
		guard += 1
		if g.ball_state == Pinball.Ball.LANE:
			g.launch(randf_range(0.6, 1.0))
		var low: bool = g.pos.y > 790.0 and g.vel.y > -50.0
		g.set_flipper(0, low and g.pos.x < 270.0)
		g.set_flipper(1, low and g.pos.x >= 270.0)
		g.advance(1.0 / 60.0)
		if g.pos.x < -5.0 or g.pos.x > 605.0 or g.pos.y < -5.0:
			out_of_bounds = true
	check(g.done == (g.balls_left == 0), "only the last drained ball ends the round (%.0f s, %d balls left)" % [g.play_time, g.balls_left])
	check(g.points > 0, "bot scored something")
	# Then the player walks away: the ball launches itself after LANE_AUTO_LAUNCH and drains; the save is once a ball.
	g.set_flipper(0, false)
	g.set_flipper(1, false)
	guard = 0
	while not g.done and guard < 60 * 600:
		guard += 1
		g.advance(1.0 / 60.0)
		if g.pos.x < -5.0 or g.pos.x > 605.0 or g.pos.y < -5.0:
			out_of_bounds = true
	check(res.size() == 1, "the round ends on the third drained ball, %.0f s (state %d, balls %d, pos %s, vel %s)" % [g.play_time, g.ball_state, g.balls_left, str(g.pos), str(g.vel)])
	check(not out_of_bounds, "ball stayed inside for a whole game")
	if res.size() == 1:
		print("  bot: %d points (record %d), level %d, %d words, %.0f s" % [g.points, g.record_points(), g.ramp_level, g.words, g.play_time])
		var ex: Dictionary = res[0]["extra"]
		check(res[0]["action_id"] == "pinball" and res[0]["need_id"] == "nightlife", "action and need")
		check(g.end_reason == "lost" and g.balls_left == 0, "end_reason lost with no balls left")
		check(int(ex.get("level", 0)) == g.ramp_level and int(ex.get("misses", -1)) == 3, "result extra: level %s, misses %s" % [ex.get("level"), ex.get("misses")])
		check(is_equal_approx(float(ex.get("speed", 0.0)), Pinball.gravity_at(g.ramp_level)), "result extra: speed = gravity")
		check(is_equal_approx(res[0]["score"], minf(1.0, g.record_points() / 100.0)), "score = min(1, points/100)")
	g.queue_free()
	# Ramp numbers: rise a step a level, stop at the cap (docs/design/15-minigame-ramp.md).
	check(Pinball.record_of(3000) == 100 and Pinball.record_of(9000) == 300 and Pinball.record_of(29) == 0, "record = pinball points / 30, uncapped")
	var rises := true
	for lv in range(2, Pinball.LEVEL_CAP + 1):
		rises = rises and Pinball.gravity_at(lv) > Pinball.gravity_at(lv - 1) and Pinball.ball_save_at(lv) < Pinball.ball_save_at(lv - 1)
		rises = rises and Pinball.word_bonus_at(lv) > Pinball.word_bonus_at(lv - 1)
	check(rises, "gravity, ball save and word bonus step every level up to %d" % Pinball.LEVEL_CAP)
	check(Pinball.LEVEL_CAP == 7 and Pinball.gravity_at(1) == 1500.0 and Pinball.gravity_at(7) == 2100.0, "gravity 1500 -> 2100 at level 7")
	check(Pinball.ball_save_at(1) == 10.0 and Pinball.ball_save_at(7) == 4.0, "ball save 10 s -> 4 s at level 7")
	check(Pinball.ball_save_at(1, true) == 15.0 and Pinball.ball_save_at(7, true) == 9.0, "relaxed keeps +5 s at every level")
	check(Pinball.word_bonus_at(1) == 1500 and Pinball.word_bonus_at(7) == 10500, "word bonus 1500 x level")
	check(Pinball.gravity_at(12) == 2100.0 and Pinball.ball_save_at(12) == 4.0 and Pinball.word_bonus_at(12) == 10500, "the numbers stop at the cap")
	# Time levels: +1 every 60 s of play, capped; no clock ends the round (the old cap was 180 s).
	var g4: Control = spawn(Pinball)
	g4.start()
	g4.ball_state = Pinball.Ball.GONE  # test only: no ball on the table, the clock still runs
	for i in 100:
		g4.advance(2.0)
	check(not g4.done and g4.ramp_level == 4, "200 s: level 4, still running past the old 3 minute cap (level %d)" % g4.ramp_level)
	for i in 150:
		g4.advance(2.0)
	check(g4.ramp_level == Pinball.LEVEL_CAP and not g4.done, "500 s: level capped at %d (%d)" % [Pinball.LEVEL_CAP, g4.ramp_level])
	g4.queue_free()
	# Scripted perfect player: spells BLACK CABIN 7 times; each word pays 1500 x level, darkens the letters, levels up.
	var g5: Control = spawn(Pinball)
	var res5 := []
	g5.finished.connect(func(r): res5.append(r))
	g5.start()
	var words_ok := true
	for w in 7:
		var lv_before: int = g5.ramp_level
		var pts_before: int = g5.points
		for i in 9:
			g5.lit[i] = true
		g5.ball_state = Pinball.Ball.LIVE
		g5.pos = g5.letter_pos[9]
		g5.vel = Vector2.ZERO
		g5.advance(Pinball.SUBSTEP)
		words_ok = words_ok and g5.words == w + 1 and g5.lit.count(true) == 0
		words_ok = words_ok and g5.points - pts_before == Pinball.LETTER_POINTS + Pinball.word_bonus_at(lv_before)
		words_ok = words_ok and g5.ramp_level == mini(lv_before + 1, Pinball.LEVEL_CAP)
	check(words_ok, "each word: bonus x level, letters dark again, level +1 (level %d, %d points)" % [g5.ramp_level, g5.points])
	check(g5.ramp_level == Pinball.LEVEL_CAP and g5.record_points() > 100, "7 words: level cap, record %d > 100" % g5.record_points())
	for k in 3:
		check(not g5.done, "not over before the third drain (%d)" % k)
		g5.ball_state = Pinball.Ball.LIVE
		g5.pos = Vector2(270, 1100)
		g5.vel = Vector2.ZERO
		g5.ball_time = 20.0
		g5.advance(Pinball.SUBSTEP)
	check(g5.done and res5.size() == 1 and g5.end_reason == "lost", "the third drained ball loses")
	if res5.size() == 1:
		check(int(res5[0]["points"]) == g5.record_points() and res5[0]["score"] == 1.0, "result points = the record (%d), score 1.0" % res5[0]["points"])
		check(int(res5[0]["extra"].get("level", 0)) == Pinball.LEVEL_CAP and int(res5[0]["extra"].get("words", 0)) == 7, "result extra: level and words")
	g5.queue_free()
	# A ball left in the lane launches itself.
	var g6: Control = spawn(Pinball)
	g6.start()
	_advance(g6, Pinball.LANE_AUTO_LAUNCH - 0.2)
	check(g6.ball_state == Pinball.Ball.LANE, "the ball waits in the lane for a while")
	_advance(g6, 0.4)
	check(g6.ball_state == Pinball.Ball.LIVE, "then launches itself (%d)" % g6.ball_state)
	g6.queue_free()
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
	check(g3.ball_save_seconds() == 10.0, "level 1 ball save 10 s")
	g3.pos = Vector2(270, 1100)
	g3.ball_time = 3.0
	g3.ball_state = Pinball.Ball.LIVE
	g3.advance(1.0 / 60.0)
	check(g3.balls_left == Pinball.BALLS - 1, "the save works once a ball: a second quick drain costs it")
	g3.pos = Vector2(270, 1100)
	g3.ball_time = 3.0
	g3.ball_state = Pinball.Ball.LIVE
	g3.advance(1.0 / 60.0)
	check(g3.balls_left == Pinball.BALLS - 1, "the next ball gets its own save")
	g3.pos = Vector2(270, 1100)
	g3.ball_time = 20.0
	g3.ball_state = Pinball.Ball.LIVE
	g3.advance(1.0 / 60.0)
	check(g3.balls_left == Pinball.BALLS - 2 and not g3.done, "later drain costs a ball")
	g3.relaxed = true
	check(g3.ball_save_seconds() == 15.0, "relaxed: ball save 15 s at level 1")
	g3.queue_free()


# --- Result card ---------------------------------------------------------------------------------

## Heart glyphs on a result card.
func _heart_glyphs(card: Control) -> int:
	var k := 0
	for g in card.find_children("*", "Control", true, false):
		if g.get_script() == Glyph and g.need == "heart":
			k += 1
	return k


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
		check(seen == [c["action"], "minigame_played"], "%s applies its action '%s' then minigame_played (saw %s)" % [c["game"], c["action"], str(seen)])
		check(o["ok"] and n.meters[c["meter"]] > 20.0, "%s raises %s" % [c["game"], c["meter"]])
		var def: Dictionary = Rules.ACTIONS[c["action"]]
		var top: float = def["gains"][c["meter"]][1] + (Rules.ACTIONS["minigame_played"]["gains"]["nightlife"] if c["meter"] == "nightlife" else 0.0)
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
		n2.minigame_tries.clear()  # the tries cap is tested in test_needs; here only the diminishing returns
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
	var talk := {"game_id": "candle_talk", "action_id": "candle_talk", "key": "tong", "score": 0.9, "points": 90, "tier": 2, "extra": {"regular": "tong"}}
	var t1: Dictionary = card3.apply(talk)
	check(t1["ok"] and t1["hearts"] == 1, "good talk earns Friends and the first heart")
	check(not t1["again_ok"], "no AGAIN for a once-a-day action")
	var t2: Dictionary = card3.apply(talk)
	check(not t2["ok"] and t2["reason"] == "daily_once", "second talk with Tong the same day earns nothing")
	var weak := talk.duplicate()
	weak["key"] = "ploy"
	weak["score"] = 0.3
	weak["extra"] = {"regular": "ploy"}
	var t3: Dictionary = card3.apply(weak)
	check(t3["ok"] and t3["hearts"] == 0, "weak talk: still earns, no heart")
	# An owner (Prae, id mali; Daniele 2026-11-02): the talk refills Friends, but no hearts are kept or shown.
	var owner := talk.duplicate()
	owner["key"] = "mali"
	owner["extra"] = {"regular": "mali"}
	n3.minigame_tries.clear()  # a fourth Candle Talk round in one visit would be refused (tries are tested in test_needs)
	var t4: Dictionary = card3.apply(owner)
	check(t4["ok"] and t4["gains"].get("friends", 0.0) > 0.0, "a good talk with the owner still refills Friends")
	check(t4["hearts"] == -1 and not n3.ext.get(CardScript.HEARTS_KEY, {}).has("mali"), "owner: no hearts kept (%s)" % t4["hearts"])
	card3._build(talk, t1)
	check(_heart_glyphs(card3) == CardScript.MAX_HEARTS, "a regular's result card draws the hearts row (%d)" % _heart_glyphs(card3))
	for c in card3.get_children():
		c.free()   # _build only queues the old card for deletion
	card3._build(owner, t4)
	check(_heart_glyphs(card3) == 0, "owner: the result card draws no hearts (%d)" % _heart_glyphs(card3))
	card3.free()
	n3.free()

	# Cast roles: owners are never befriended, regulars are; the venue tag carries a heart for regulars only.
	check(Cast.role("mali") == Cast.OWNER and Cast.is_owner("mali") and not Cast.befriends("mali"), "Prae (id mali) is an owner, not befriended")
	check(Cast.befriends("tong") and Cast.befriends("ploy"), "regulars are befriended")
	check(Zones.tag_text("mali") == "Prae", "owner's tag is her name, no heart (%s)" % Zones.tag_text("mali"))
	check(Zones.tag_text("tong").ends_with("♥"), "a regular's tag carries the heart (%s)" % Zones.tag_text("tong"))

	# Lean bonus: extra.lean adds candle_talk_lean (+5 Friends) on top of the talk, and only then.
	var n5 := fresh_needs()
	n5.meters["friends"] = 30.0
	var card5: Control = CardScript.new()
	card5.needs = n5
	var plain := {"game_id": "candle_talk", "action_id": "candle_talk", "key": "tong", "score": 1.0, "points": 100, "tier": 2, "extra": {"regular": "tong", "lean": false}}
	var p1: Dictionary = card5.apply(plain)
	check(absf(p1["gains"]["friends"] - 20.0) < 1e-6, "no lean flag: Friends +20 only (%s)" % [p1["gains"]])
	var leaned := plain.duplicate(true)
	leaned["key"] = "ploy"
	leaned["extra"] = {"regular": "ploy", "lean": true}
	var l1: Dictionary = card5.apply(leaned)
	# Same visit: visit points 20 -> talk +20 lands in full (to 40), lean +5 lands at 50% (tier 2) = 22.5.
	check(absf(l1["gains"]["friends"] - 22.5) < 1e-6, "lean flag: talk 20 + bonus 2.5 after diminishing (%s)" % [l1["gains"]])
	check(absf(n5.meters["friends"] - (30.0 + p1["gains"]["friends"] + l1["gains"]["friends"])) < 1e-6, "shown gain equals what Needs applied")
	var l2: Dictionary = card5.apply(leaned)
	check(not l2["ok"], "lean cannot be farmed: same regular again earns nothing")
	card5.free()
	n5.free()

	# Unknown action: no crash, no gain.
	var n4 := fresh_needs()
	var card4: Control = CardScript.new()
	card4.needs = n4
	var o4: Dictionary = card4.apply({"game_id": "x", "action_id": "nope", "key": "", "score": 1.0, "points": 100, "tier": 2, "extra": {}})
	check(not o4["ok"], "unknown action id is refused by Needs")
	card4.free()
	n4.free()


# --- Q9: sprites, juice beats and rivals for Front Row Rhythm and Candle Talk -----------------------

func test_q9_sprites_fx_rivals() -> void:
	print("[q9] rhythm + candle: look B sprites, fx beats, rivals")
	var rs := RivalStore.new()
	var g: Control = spawn(Rhythm)
	g.rivals_store = rs
	g.config = {"seed": 1}
	g.start()
	check(g.has_art(), "rhythm: all sprites load (import first)")
	check(not g.rival.is_empty(), "rhythm: tonight's regular to beat is set")
	while g.clock < g.notes[0]["time"]:
		g.advance(1.0 / 60.0)
	g.tap(g.notes[0]["lane"])
	check(g.perfect == 1 and g.fx().pops_alive() >= 1, "rhythm: a perfect pops a word")
	g.fx().step(0.01)
	check(g.fx().flash_amount("lane%d" % g.notes[0]["lane"]) > 0.0, "rhythm: a perfect flashes the puck white")
	check(g.fx().trauma == 0.0, "rhythm: no shake on a hit")
	g.tap(1 - g.notes[0]["lane"])
	g.fx().step(0.01)
	check(g.fx().combo >= 1, "rhythm: combo counts")
	g.advance(2.0)  # a missed note
	check(g.missed >= 1 and g.fx().combo == 0 and g.fx().trauma == 0.0, "rhythm: a miss breaks the combo, never shakes")
	check(g.lives_left == Base.STRIKES - g.missed, "rhythm: a missed clap costs a life")
	g.queue_free()
	var res := []
	var g2: Control = spawn(Rhythm)
	g2.rivals_store = rs
	g2.config = {"seed": 1}
	g2.finished.connect(func(r): res.append(r))
	g2.start()
	for i in 20000:
		if g2.done:
			break
		g2.advance(1.0 / 60.0)
	check(res.size() == 1 and res[0]["extra"].has("board") and res[0]["extra"].has("rival"), "rhythm: the result carries rival and board")
	g2.queue_free()
	var c: Control = spawn(Candle)
	c.rivals_store = rs
	c.config = {"regular": "tt", "seed": 7}
	c.start()
	check(c.has_art() and c._art.has("regular_tt") and not c._art.has("regular_hiro"), "candle: sprites load, only this regular's")
	c.choose(c.line["best"])
	check(c._fly.size() == 1, "candle: the card flies")
	c.advance(0.5)
	check(c._flare_t > 0.0 and c._smile_t > 0.0 and c.fx().trauma == 0.0, "candle: best card flares the flame, the regular smiles, no shake")
	c.advance(2.0)
	for k in c.line["cards"]:
		if Candle.card_light(c.line, k) == 0.0:
			c.choose(k)
			break
	c.advance(0.5)
	check(c._gutter_t > 0.0 and c.fx().trauma == 0.0, "candle: a miss gutters the flame, no shake")
	check(not c.rival.is_empty(), "candle: tonight's regular to beat is set")
	c.queue_free()

## Stands in for Needs: mg_rivals only reads and writes `ext`.
class Store:
	extends RefCounted
	var ext := {}


func test_pinball_pour_rivals() -> void:
	print("[rivals] pinball and pour: regular to beat, passing it, the board line, the pour ghost")
	# --- pinball
	var store := Store.new()
	var pb: Control = Pinball.new()
	pb.size = SIZE
	pb.rivals_store = store
	root.add_child(pb)
	var res := []
	pb.finished.connect(func(r): res.append(r))
	pb.start()
	check(not pb.rival.is_empty() and str(pb.rival.get("name", "")) != "" and pb.rival.has("points"), "pinball: a regular to beat in play")
	check(not pb.rival_passed, "pinball: not past the regular at 0 points")
	pb.points = 6000
	pb.launch(0.9)
	pb.advance(1.0 / 60.0)
	check(pb.live_points() >= 200 and pb.live_points() == pb.record_points() and pb.rival_passed, "pinball: points above the regular flag the pass")
	pb.finish(pb.current_score())
	var ex: Dictionary = res[0].get("extra", {}) if res.size() == 1 else {}
	check(ex.get("rival") is Dictionary and ex["rival"].has("points"), "pinball: result carries the rival")
	check(ex.get("board") is Dictionary and int(ex["board"].get("rank", 0)) >= 1 and int(ex["board"].get("count", 0)) >= 2, "pinball: result carries the board place")
	check(res.size() == 1 and int(res[0].get("points", -1)) == pb.record_points() and res[0]["score"] == 1.0, "pinball: result points = the uncapped record (%d), score 1.0" % pb.record_points())
	check(int(Rivals.tonight("neon_pinball", store)["best"]) == pb.record_points(), "pinball: tonight's best saved (record points)")
	check(Rivals.tonight("neon_pinball", store)["ghost"].is_empty(), "pinball: no ghost kept (a physics run is not replayable)")
	pb.queue_free()
	# --- pour
	store = Store.new()
	var a: Control = pour_run(store, true)
	check(a.ghost.is_empty(), "pour: no ghost before the first pour tonight")
	check(not a.rival.is_empty() and a.rival.has("points"), "pour: a regular to beat in play")
	var rr: Array = a.get_meta("results")
	check(rr.size() == 1, "pour: the precise pour finished")
	var pex: Dictionary = rr[0].get("extra", {}) if rr.size() == 1 else {}
	check(pex.get("rival") is Dictionary and pex["rival"].has("points"), "pour: result carries the rival")
	check(pex.get("board") is Dictionary and int(pex["board"].get("rank", 0)) >= 1, "pour: result carries the board place")
	check(a.live_points() >= 95 and a.rival_passed == (a.live_points() > int(a.rival["points"])), "pour: a precise pour scores %d and flags the pass" % a.live_points())
	var best := int(Rivals.tonight("pour_perfect", store)["best"])
	check(best == a.live_points(), "pour: tonight's best saved")
	a.queue_free()
	var b: Control = pour_run(store, false)
	var lv: Array = b.ghost.get("levels", [])
	check(lv.size() == Pour.TARGETS.size(), "pour: the next glass shows tonight's best levels as the ghost")
	var near := true
	for i in lv.size():
		near = near and absf(float(lv[i]) - Pour.TARGETS[i]) < 0.05
	check(near, "pour: the ghost levels sit near the lines")
	check(not b.rival.is_empty(), "pour: still a regular to beat")
	b.queue_free()
	# a worse pour does not replace tonight's ghost or best
	var c: Control = Pour.new()
	c.size = SIZE
	c.rivals_store = store
	root.add_child(c)
	c.start()
	pour_glass(c, 2.0)  # holds every layer over the rim: three spills, three strikes
	check(c.done, "pour: the sloppy pour finished")
	check(int(Rivals.tonight("pour_perfect", store)["best"]) == best, "pour: a worse pour keeps tonight's best")
	check(Rivals.tonight("pour_perfect", store)["ghost"].get("levels", []) == lv, "pour: a worse pour keeps the ghost")
	c.queue_free()


## A precise glass 1 on pour_perfect with `store` as tonight's record (or only the started game), then the pourer
## walks off and the idle layers spoil until the round is lost; results land in meta.
func pour_run(store: Object, play: bool) -> Control:
	var g: Control = Pour.new()
	g.size = SIZE
	g.rivals_store = store
	root.add_child(g)
	var results := []
	g.finished.connect(func(r): results.append(r))
	g.set_meta("results", results)
	g.start()
	if not play:
		return g
	pour_glass(g)
	_advance(g, 40.0)  # three idle layers on glass 2: lost
	return g


## Pours the next layer of `g`: waits for READY, holds until the fill reaches the layer's line + `over` (or the pour
## ends by a spill), releases. Returns false once the round has ended.
func pour_layer(g: Control, over := 0.0) -> bool:
	var guard := 0
	while g.state != Pour.State.READY and not g.done and guard < 600:
		g.advance(1.0 / 60.0)
		guard += 1
	if g.done:
		return false
	g.press()
	var line: float = g.targets[g.layer]
	guard = 0
	while g.state == Pour.State.POURING and g.level < line + over and guard < 40000:
		g.advance(1.0 / 240.0)
		guard += 1
	g.release()
	return not g.done


## Pours the three layers of the glass in front (each released on its line + `over`). Returns false once the round
## has ended.
func pour_glass(g: Control, over := 0.0) -> bool:
	for i in 3:
		if not pour_layer(g, over):
			return false
	return not g.done
