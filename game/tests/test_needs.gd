extends SceneTree
## Headless tests for the needs system (GDD §2). Exit code 0 = all pass.
##   godot --headless --path . --script res://tests/test_needs.gd
## Drives Needs through its real-time override, so "a week" runs instantly.

const Rules = preload("res://scripts/rules.gd")
const Save = preload("res://scripts/save.gd")
const NeedsScript = preload("res://scripts/needs.gd")

const T0 := 1_800_000_000.0  # fixed real start time
const HOUR := 3600.0
const DAY := 86400.0
const TEST_SAVE := "user://test_needs_save.json"

var failures := 0
var checks := 0


func _init() -> void:
	test_decay_window()
	test_decay_simulated_week()
	test_decay_while_closed()
	test_sample_visit()
	test_diminishing_returns()
	test_daily_multiplier_and_visits()
	test_caps_once_and_overflow()
	test_vibe_states()
	test_save_roundtrip()
	test_welcome_back()
	test_debug_clock()
	print("")
	print("%d checks, %d failed" % [checks, failures])
	print("NEEDS TESTS ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("  FAIL: ", msg)


func near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func fresh(t := T0) -> Node:
	var n: Node = NeedsScript.new()
	n.autosave = false
	n.time_override = t
	n.save_path = TEST_SAVE
	n.new_game()
	return n


func set_all(n: Node, v: float) -> void:
	for m in Rules.METERS:
		n.meters[m] = v


func test_decay_window() -> void:
	print("[decay window] GDD §2.1: full to empty, rate only (no soft floor)")
	for m in Rules.METERS:
		var rate: float = Rules.DECAY_PER_HOUR[m]
		var days := Rules.METER_MAX / rate / 24.0
		print("  %-9s %.2f/h  empty in %.2f days (GDD window 6-9.3)" % [m, rate, days])
		check(days >= 5.9 and days <= 9.5, "%s empty window %.2f days outside 5.9-9.5 (GDD says ~6.0-9.3)" % [m, days])
	var d := {"music": 7.6, "friends": 8.3, "drinks": 6.0, "nightlife": 9.3}
	for m in d:
		check(near(100.0 / Rules.DECAY_PER_HOUR[m] / 24.0, d[m], 0.1), "%s differs from the GDD's stated days" % m)


func test_decay_simulated_week() -> void:
	print("[decay week] simulated 7 days of real time, with soft floor as implemented")
	var n := fresh()
	set_all(n, 100.0)
	for h in 168:
		n.time_override = T0 + (h + 1) * HOUR
		n.sync()
	var report := []
	for m in Rules.METERS:
		var expect: float = NeedsScript.decay_value(100.0, 168.0, Rules.decay_rate(m), true)
		report.append("%s %.1f" % [m, n.meters[m]])
		check(near(n.meters[m], expect, 0.05), "%s hourly stepping %.2f != closed form %.2f" % [m, n.meters[m], expect])
	print("  after 7 days from 100: ", ", ".join(report))
	# Without the floor the GDD's weekly table holds: Music -92, Friends -84, Nightlife -76, Drinks bottoms out
	var gdd_week := {"music": 92.0, "friends": 84.0, "nightlife": 76.0}
	for m in gdd_week:
		var lost: float = Rules.DECAY_PER_HOUR[m] * 168.0
		check(near(lost, gdd_week[m], 1.0), "%s weekly decay %.1f vs GDD %.0f" % [m, lost, gdd_week[m]])
	check(Rules.DECAY_PER_HOUR["drinks"] * 168.0 > 100.0, "drinks should bottom out within a week")
	# Soft floor: halved below 30
	check(near(NeedsScript.decay_value(30.0, 10.0, 1.0), 25.0, 0.001), "soft floor halves decay below 30")
	check(near(NeedsScript.decay_value(35.0, 10.0, 1.0), 35.0 - 5.0 - 2.5, 0.001), "decay crossing 30 is split")
	check(NeedsScript.decay_value(1.0, 1000.0, 1.0) == 0.0, "meters never go below 0")
	# Personality modifier: -10% on one meter
	check(near(Rules.decay_rate("nightlife", "night_owl"), 0.45 * 0.9, 1e-6), "night_owl lowers nightlife decay 10%")
	check(near(Rules.decay_rate("music", "night_owl"), 0.55, 1e-6), "night_owl leaves music alone")
	n.free()


func test_decay_while_closed() -> void:
	print("[closed app] decay is computed from timestamps, not frames")
	var a := fresh()
	a.save_game()
	var expect := {}
	for m in Rules.METERS:
		expect[m] = NeedsScript.decay_value(a.meters[m], 3.0 * 24.0, Rules.decay_rate(m), true)
	a.free()
	var b: Node = NeedsScript.new()
	b.autosave = false
	b.save_path = TEST_SAVE
	b.time_override = T0 + 3.0 * DAY  # app reopened three days later, no frames ran in between
	b._load_from_disk()
	for m in Rules.METERS:
		check(near(b.meters[m], expect[m], 0.05), "%s after 3 closed days %.2f != %.2f" % [m, b.meters[m], expect[m]])
	print("  after 3 closed days from 75: ", ", ".join(Rules.METERS.map(func(m): return "%s %.1f" % [m, b.meters[m]])))
	b.free()
	Save.delete(TEST_SAVE)


func test_sample_visit() -> void:
	print("[sample visit] GDD §2.3: 10 minute visit, first of the day")
	var n := fresh()
	set_all(n, 20.0)
	var before: Dictionary = n.meters.duplicate()
	n.apply_action("order_drink")  # free drink on the house
	n.apply_action("pour_perfect", 0.5)  # +25
	for i in 3:
		n.apply_action("listen_song")
	n.apply_action("front_row_rhythm", 0.5)  # +10
	n.apply_action("candle_talk", 0.5, "mali")  # +15
	n.apply_action("sit_with", 1.0, "joe")  # +8
	n.apply_action("enter_lounge")  # +5
	n.apply_action("pinball", 0.5)  # +15
	n.apply_action("dance_30s")
	n.apply_action("dance_30s")  # +6
	var want := {"music": 25.0, "friends": 23.0, "drinks": 40.0, "nightlife": 26.0}
	var got := []
	for m in Rules.METERS:
		var g: float = n.meters[m] - before[m]
		got.append("%s +%.1f (GDD +%.0f)" % [m, g, want[m]])
		check(near(g, want[m], 1.0), "%s gained %.1f, GDD says %.0f" % [m, g, want[m]])
	print("  ", ", ".join(got))
	n.free()


func test_diminishing_returns() -> void:
	print("[diminishing returns] §2.4: 40 full, 41-80 at 50%, beyond at 25%")
	check(near(NeedsScript._tiered(0.0, 40.0), 40.0, 1e-6), "first 40 full")
	check(near(NeedsScript._tiered(40.0, 40.0), 20.0, 1e-6), "41-80 at 50%")
	check(near(NeedsScript._tiered(80.0, 40.0), 10.0, 1e-6), "beyond 80 at 25%")
	check(near(NeedsScript._tiered(30.0, 30.0), 10.0 + 10.0, 1e-6), "straddling the 40 edge splits")
	check(near(NeedsScript._tiered(0.0, 100.0), 40.0 + 20.0 + 5.0, 1e-6), "100 raw from 0 -> 65")
	# Through the real action path: five 30-point pours on one meter
	var n := fresh()
	set_all(n, 0.0)
	var gains := []
	for i in 5:
		gains.append(n.apply_action("pour_perfect", 1.0)["gains"]["drinks"])
	print("  five 30-point pours: ", gains)
	check(near(gains[0], 30.0, 1e-6), "pour 1 full")
	check(near(gains[1], 10.0 + 10.0, 1e-6), "pour 2 straddles 40: 10 full + 20 * 0.5")
	check(near(gains[2], 20.0 * 0.5 + 10.0 * 0.25, 1e-6), "pour 3 straddles 80: 20 * 0.5 + 10 * 0.25")
	check(near(gains[3], 7.5, 1e-6), "pour 4 beyond 80 at 25%")
	check(near(gains[4], 7.5, 1e-6), "pour 5 at 25%")
	check(gains[1] < gains[0] and gains[4] < gains[2], "returns strictly diminish")
	n.free()


func test_daily_multiplier_and_visits() -> void:
	print("[daily multiplier] 1st x1.0, 2nd x0.75, 3rd+ x0.5; new day resets")
	var n := fresh()
	var t := T0
	var out := []
	for i in 4:
		set_all(n, 50.0)  # not homebody, so no Welcome Back muddies the ladder
		var g: float = n.apply_action("order_drink")["gains"]["drinks"]
		out.append(g)
		n.end_visit()
		t += 60.0
		n.time_override = t
	print("  four visits, 15-pt drink: ", out)
	check(near(out[0], 15.0, 1e-6) and near(out[1], 11.25, 1e-6) and near(out[2], 7.5, 1e-6) and near(out[3], 7.5, 1e-6), "daily multiplier ladder")
	n.time_override = t + DAY
	set_all(n, 50.0)
	check(near(n.apply_action("order_drink")["gains"]["drinks"], 15.0, 1e-6), "next real day resets to x1.0")
	# Idle for 10 minutes ends the visit
	n.time_override += Rules.VISIT_IDLE_SECONDS + 1.0
	n.sync()
	check(not n.visit_active, "10 idle minutes end the visit")
	check(n.visit_log.size() == 5, "visit log has one entry per visit (%d)" % n.visit_log.size())
	n.free()


func test_caps_once_and_overflow() -> void:
	print("[caps, once-per, overflow to Tab]")
	var n := fresh()
	set_all(n, 0.0)
	for i in 5:
		n.apply_action("applaud")
	check(near(n.meters["music"], 6.0, 1e-6), "applaud capped at +6 per visit (%.1f)" % n.meters["music"])
	check(n.apply_action("applaud")["reason"] == "cap_reached", "capped action says why")
	check(n.apply_action("enter_lounge")["ok"] and not n.apply_action("enter_lounge")["ok"], "lounge bonus once per visit")
	check(n.apply_action("candle_talk", 1.0, "mali")["ok"], "candle talk first time")
	check(n.apply_action("candle_talk", 1.0, "mali")["reason"] == "daily_once", "candle talk once per regular per day")
	check(n.apply_action("candle_talk", 1.0, "joe")["ok"], "candle talk with another regular")
	check(n.apply_action("candle_talk")["reason"] == "key_required", "daily_once action needs a key")
	check(n.apply_action("nope")["reason"] == "unknown_action", "unknown action rejected")
	set_all(n, 95.0)
	var tab0: float = n.tab
	var r: Dictionary = n.apply_action("pinball", 1.0)  # +20 raw on nightlife, 5 room
	check(n.meters["nightlife"] == 100.0, "meter clamps at 100")
	check(r["tab"] > 0.0 and n.tab > tab0, "overflow becomes Tab (%.1f)" % n.tab)
	n.free()


func test_vibe_states() -> void:
	print("[vibe] thresholds 80 / 50 / 25")
	var n := fresh()
	var cases := [[100.0, "glowing"], [80.0, "glowing"], [79.9, "good"], [50.0, "good"], [49.9, "meh"], [25.0, "meh"], [24.9, "homebody"], [0.0, "homebody"]]
	for c in cases:
		set_all(n, c[0])
		check(Rules.vibe_state(n.vibe()) == c[1], "vibe %.1f -> %s" % [c[0], c[1]])
	var seen := []
	n.vibe_state_changed.connect(func(o, s): seen.append("%s>%s" % [o, s]))
	set_all(n, 60.0)
	n.debug_advance(1.0)
	set_all(n, 10.0)
	n.debug_advance(1.0)
	print("  transitions: ", seen)
	check(seen.size() >= 1 and seen[-1].ends_with(">homebody"), "state transition signal fires")
	n.free()


func test_save_roundtrip() -> void:
	print("[save] round trip and forward compatibility")
	var n := fresh()
	n.set_personality("night_owl")
	set_all(n, 40.0)
	n.apply_action("pour_perfect", 0.5)
	n.apply_action("candle_talk", 0.5, "mali")
	n.end_visit()
	n.ext["multiplayer"] = {"room": "abc"}
	var d: Dictionary = n.to_dict()
	d["future_field"] = {"x": 1}
	check(Save.write(d, TEST_SAVE), "write")
	var back := Save.read(TEST_SAVE)
	check(int(back["version"]) == Save.VERSION, "version stored")
	var n2: Node = NeedsScript.new()
	n2.autosave = false
	n2.time_override = T0  # reopen at the same instant: nothing decays
	n2.save_path = TEST_SAVE
	check(n2._load_from_disk(), "load")
	for m in Rules.METERS:
		check(near(n2.meters[m], n.meters[m], 1e-4), "%s round-trips (%.3f vs %.3f)" % [m, n2.meters[m], n.meters[m]])
	check(n2.personality == "night_owl", "personality")
	check(n2.visit_log.size() == 1 and n2.visit_log[0]["actions"] == 2, "visit log")
	check(n2.daily_keys.has("candle_talk|mali"), "daily keys persist")
	check(n2.ext.get("multiplayer", {}).get("room") == "abc", "ext namespace persists")
	var d2: Dictionary = n2.to_dict()
	check(d2.has("future_field") and d2["future_field"]["x"] == 1, "unknown top-level fields survive a load/save")
	check(Save.migrate({"needs": {}}).has("profile"), "old/partial saves get missing keys")
	check(Save.read("user://does_not_exist.json").is_empty(), "missing file reads as empty")
	n.free()
	n2.free()
	Save.delete(TEST_SAVE)


func test_welcome_back() -> void:
	print("[welcome back] 7+ days away, or Vibe below 25; gains x2 for 15 minutes")
	# Out of Town freezes decay so only the absence rule can trigger it.
	var n := fresh()
	n.apply_action("listen_song")
	n.end_visit()
	check(n.start_out_of_town(14.0), "out of town starts")
	n.time_override = T0 + 6.9 * DAY
	n.begin_visit()
	check(not n.welcome_active(), "6.9 days away: no Welcome Back")
	n.end_visit()
	n.time_override += 7.0 * DAY
	n.begin_visit()
	check(n.welcome_active(), "7+ days away: Welcome Back")
	check(n.vibe() > 25.0, "decay was frozen, so this was the absence rule")
	set_all(n, 40.0)
	var g: float = n.apply_action("listen_song")["gains"]["music"]
	check(near(g, 10.0, 1e-6), "gains doubled during Welcome Back (%.1f)" % g)
	n.end_visit()
	n.time_override += Rules.WELCOME_BACK_MINUTES * 60.0 + 1.0
	n.begin_visit()
	check(not n.welcome_active(), "no second Welcome Back right after")
	n.free()
	# Vibe below 25
	var v := fresh()
	v.apply_action("listen_song")
	v.end_visit()
	set_all(v, 10.0)
	v.debug_advance(1.0)
	check(v.homebody_flag, "vibe below 25 sets the flag")
	var reasons := []
	v.welcome_back_started.connect(func(r): reasons.append(r))
	v.time_override += HOUR
	v.begin_visit()
	check(reasons == ["vibe"], "vibe below 25 triggers Welcome Back (%s)" % [reasons])
	check(not v.homebody_flag, "flag cleared once welcomed")
	v.time_override += 16.0 * 60.0
	v.sync()
	check(not v.welcome_active(), "doubling ends after 15 minutes")
	v.free()
	# Fresh character: no welcome on the very first visit
	var f := fresh()
	f.begin_visit()
	check(not f.welcome_active(), "first ever visit is not a Welcome Back")
	f.free()


func test_debug_clock() -> void:
	print("[debug clock] 1 real minute = 1 game hour, switchable at runtime")
	var n := fresh()
	set_all(n, 100.0)
	n.toggle_debug_clock()
	check(n.multiplier == Rules.DEBUG_CLOCK_MULTIPLIER, "toggle on")
	n.time_override = T0 + 60.0  # one real minute
	n.sync()
	var want: float = 100.0 - Rules.DECAY_PER_HOUR["drinks"]
	check(near(n.meters["drinks"], want, 0.01), "one real minute decays one hour (%.3f vs %.3f)" % [n.meters["drinks"], want])
	n.toggle_debug_clock()
	check(n.multiplier == 1.0, "toggle off")
	var before: float = n.meters["drinks"]
	n.time_override += 60.0
	n.sync()
	check(near(n.meters["drinks"], before - Rules.DECAY_PER_HOUR["drinks"] / 60.0, 0.001), "back to real time")
	n.free()
