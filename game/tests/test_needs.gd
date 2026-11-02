extends SceneTree
## Headless tests for the needs system (GDD §2). Exit code 0 = all pass.
##   godot --headless --path . --script res://tests/test_needs.gd
## Drives Needs through its real-time override, so "a week" runs instantly.

const Rules = preload("res://scripts/rules.gd")
const Save = preload("res://scripts/save.gd")
const NeedsScript = preload("res://scripts/needs.gd")
const CardScript = preload("res://scripts/minigames/result_card.gd")
const Base = preload("res://scripts/minigames/minigame_base.gd")

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
	test_welcome_back_replaces_daily()
	test_candle_talk_lean()
	test_start_value()
	test_debug_clock()
	test_stake_stages()
	test_stake_clock_and_death()
	test_stand_in_counts()
	test_visit_holds_death()
	test_out_of_town_stake()
	test_never_dead_when_visiting()
	test_weekly_sample_visits()
	test_ghost()
	test_revival()
	test_deletion_and_retire()
	test_annoyances()
	test_misses()
	test_tries()
	test_minigame_played()
	test_old_save_and_clock()
	test_o1_first_checkin()
	test_o2_no_stand_in_revival()
	test_o3_memory()
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
	# Soft floor: x0.3 below 30 (DECISIONS: Orchestrator calls after wave 2, (a))
	check(Rules.SOFT_FLOOR_FACTOR == 0.3, "soft floor factor is 0.3")
	check(near(NeedsScript.decay_value(30.0, 10.0, 1.0), 27.0, 0.001), "soft floor cuts decay to 30% below 30")
	check(near(NeedsScript.decay_value(35.0, 10.0, 1.0), 35.0 - 5.0 - 1.5, 0.001), "decay crossing 30 is split")
	# The floor keeps the empty window in the GDD's 6-9 day band even for the fastest meter: Drinks 100 -> 0.
	var h := 0.0
	var dv := 100.0
	while dv > 0.0 and h < 24.0 * 40.0:
		dv = NeedsScript.decay_value(dv, 1.0, Rules.DECAY_PER_HOUR["drinks"], true)
		h += 1.0
	print("  drinks 100 -> 0 with the soft floor: %.1f days" % (h / 24.0))
	check(h / 24.0 > 6.0 and h / 24.0 < 16.0, "drinks empties in a bounded window with the floor (%.1f days)" % (h / 24.0))
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
	var want := {"music": 30.0, "friends": 23.0, "drinks": 40.0, "nightlife": 26.0}
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
	set_all(n, 10.0)  # not Empty: an Empty meter's annoyance would drag the gains (06-stakes §7.1)
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
	set_all(n, 10.0)  # not Empty (06-stakes §7.1)
	for i in 5:
		n.apply_action("applaud")
	check(near(n.meters["music"], 16.0, 1e-6), "applaud capped at +6 per visit (%.1f)" % (n.meters["music"] - 10.0))
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


func test_welcome_back_replaces_daily() -> void:
	print("[welcome back] x2 replaces the daily multiplier, never stacks (DECISIONS (b))")
	check(Rules.gain_mult(1, true) == 2.0 and Rules.gain_mult(2, true) == 2.0 and Rules.gain_mult(3, true) == 2.0, "Welcome Back is x2 on any visit number")
	check(Rules.gain_mult(2, false) == 0.75 and Rules.gain_mult(1, false) == 1.0, "without it the daily ladder applies")
	var n := fresh()
	set_all(n, 50.0)
	n.apply_action("listen_song")
	n.end_visit()  # visit 1 of the day, no welcome
	n.time_override += 60.0
	set_all(n, 10.0)  # Vibe below 25 ...
	n.debug_advance(0.0)
	n.homebody_flag = true  # ... so the second visit of the day is a Welcome Back
	n.begin_visit()
	check(n.welcome_active() and n.visits_today == 2, "second visit of the day is a Welcome Back")
	set_all(n, 40.0)
	var g: float = n.apply_action("order_drink")["gains"]["drinks"]
	check(near(g, 30.0, 1e-6), "15-pt drink on visit 2 during Welcome Back = 30, not 22.5 (%.2f)" % g)
	n.free()


func test_candle_talk_lean() -> void:
	print("[candle talk lean] +5 Friends action approved in DECISIONS (k)")
	var def: Dictionary = Rules.ACTIONS.get("candle_talk_lean", {})
	check(not def.is_empty() and def["gains"] == {"friends": 5.0}, "candle_talk_lean exists and is +5 Friends")
	var n := fresh()
	set_all(n, 40.0)
	var r: Dictionary = n.apply_action("candle_talk_lean", 1.0, "tong")
	check(r["ok"] and near(r["gains"]["friends"], 5.0, 1e-6), "lean bonus gives +5 Friends")
	check(near(n.meters["friends"], 45.0, 1e-6) and near(n.meters["music"], 40.0, 1e-6), "only Friends moves")
	n.free()


func test_start_value() -> void:
	print("[start value] new character starts at 75 on every meter (GDD §2.1)")
	var n := fresh()
	for m in Rules.METERS:
		check(near(n.meters[m], 75.0, 1e-6), "%s starts at 75" % m)
	check(Rules.vibe_state(n.vibe()) == Rules.VIBE_GOOD, "a new character is Good")
	n.free()


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


# --- Stakes (docs/design/06-stakes.md v3 §10.10; DECISIONS 2026-11-02 O1-O4) ----------------------

## Moves the real clock `secs` on and syncs (one jump: the fatal clock is exact inside it).
func go(n: Node, secs: float) -> void:
	n.time_override += secs
	n.sync()


func test_stake_stages() -> void:
	print("[stake 1] stage edges 9.99 / 10 / 14.99 / 15 / 17.99 / 18 / 20.99 / 21")
	var want := {9.99: "fine", 10.0: "restless", 14.99: "restless", 15.0: "fading", 17.99: "fading", 18.0: "last_call", 20.99: "last_call"}
	for d in want:
		check(Rules.stake_stage(d) == want[d], "stage at %.2f days is %s" % [d, want[d]])
	check(Rules.FATAL_DAYS == 21.0 and Rules.GHOST_WINDOW_DAYS == 14.0 and Rules.REVIVE_COOLDOWN_DAYS == 90.0, "Daniele's three numbers")
	var n := fresh()
	n.advance_game(Rules.FATAL_DAYS * DAY - 1.0)
	check(n.stake_stage == "last_call" and not n.is_ghost(), "one second before 21.0 days: Last Call, alive")
	n.free()


func test_stake_clock_and_death() -> void:
	print("[stake 2] ghost at exactly 21.0 days, deleted at 35.0 (O4 numbers as written)")
	var n := fresh()
	go(n, 21.0 * DAY)
	check(n.is_ghost() and n.stake_stage == "ghost", "ghost at 21.0 days")
	check(near(n.dead_at, T0 + 21.0 * DAY, 0.001), "dead_at is exactly day 21 (%.1f)" % (n.dead_at - T0))
	go(n, 13.99 * DAY)
	check(n.is_ghost(), "still a ghost at day 34.99")
	var deleted := []
	n.character_deleted.connect(func(): deleted.append(true))
	go(n, 0.02 * DAY)
	check(n.stake_stage == "deleted" and n.is_deleted() and deleted.size() == 1, "deleted at day 35, farewell signalled once")
	n.free()
	var m := fresh()
	set_all(m, 100.0)
	go(m, 30.0 * DAY)
	var expect: float = NeedsScript.decay_value(100.0, 21.0 * 24.0, Rules.decay_rate("music"), true)
	check(near(m.meters["music"], expect, 0.01), "decay ran for 21 days only (%.2f vs %.2f)" % [m.meters["music"], expect])
	m.free()


func test_stand_in_counts() -> void:
	print("[stake 3] stand-in: an accepted refill resets the clock then; walking in or a miss does not")
	var n := fresh()
	set_all(n, 50.0)
	go(n, 12.0 * DAY)
	check(n.stake_stage == "restless", "day 12 is Restless")
	n.begin_visit()
	check(near(n.days_since_visit(), 12.0, 0.001), "walking in does not count")
	var card: Control = CardScript.new()
	card.needs = n
	card.apply(_card_result("pour_perfect", "pour_perfect", 0.1, true))
	check(near(n.days_since_visit(), 12.0, 0.001), "a missed minigame does not count")
	var r: Dictionary = n.apply_action("order_drink")
	check(r["ok"] and n.days_since_visit() == 0.0 and n.last_counted_visit == n.clock, "one accepted refill resets the clock at that moment")
	check(n.stake_stage == "fine", "and the stage drops to Fine")
	card.free()
	n.free()


func test_visit_holds_death() -> void:
	print("[stake 4] a visit in progress at 21.0 days does not die; ending it without a counting action makes a ghost")
	var n := fresh()
	go(n, 21.0 * DAY - 400.0)
	n.begin_visit()
	go(n, 450.0)
	check(n.visit_active and not n.is_ghost() and n.stake_stage == "last_call", "past 21.0 days inside a visit: alive, held at Last Call")
	go(n, 200.0)
	check(not n.visit_active and n.is_ghost(), "the idle end of the visit makes it a ghost")
	n.free()


func test_out_of_town_stake() -> void:
	print("[stake 5] Out of Town freezes the stake clock; it cannot start from day 10")
	var n := fresh()
	go(n, 2.0 * DAY)
	check(n.start_out_of_town(14.0), "starts at day 2")
	go(n, 14.0 * DAY)
	check(near(n.days_since_visit(), 2.0, 0.001) and n.stake_stage == "fine", "14 days away cost no stake time (%.3f)" % n.days_since_visit())
	go(n, 8.0 * DAY)
	check(near(n.days_since_visit(), 10.0, 0.001) and n.stake_stage == "restless", "then it runs on")
	n.last_out_of_town_start = 0.0  # cooldown out of the way: only the Restless rule is under test
	check(not n.can_start_out_of_town(), "cannot start at day 10 or later")
	n.free()


func test_never_dead_when_visiting() -> void:
	print("[stake 6] meters at 0 for 30 days with a counting visit every 20 days: never dead")
	var n := fresh()
	set_all(n, 0.0)
	var dead := false
	for i in 3:
		go(n, 20.0 * DAY)
		dead = dead or n.is_ghost()
		set_all(n, 0.0)
		check(n.apply_action("order_drink")["ok"], "visit %d lands" % i)
		n.end_visit()
	check(not dead and not n.is_ghost() and n.lives == 1, "alive after 60 days")
	n.free()


func test_weekly_sample_visits() -> void:
	print("[stake 7] 12 weeks of one sample visit a week: always Fine; only Thirsty on arrival; no misses")
	var n := fresh()
	var worst := "fine"
	var seen := {}
	for w in 12:
		go(n, 7.0 * DAY)
		if n.stake_stage != "fine":
			worst = n.stake_stage
		for id in n.annoyances():
			seen[id] = true
		n.begin_visit()
		n.apply_action("order_drink")
		n.apply_action("pour_perfect", 0.5)
		for i in 3:
			n.apply_action("listen_song")
		n.apply_action("front_row_rhythm", 0.5)
		n.apply_action("candle_talk", 0.5, "mali")
		n.apply_action("sit_with", 1.0, "joe")
		n.apply_action("enter_lounge")
		n.apply_action("pinball", 0.5)
		n.end_visit()
	check(worst == "fine", "a weekly player is always Fine (%s)" % worst)
	check(seen.keys().all(func(k): return k == "thirsty"), "only Thirsty on arrival (%s)" % str(seen.keys()))
	check(0.5 >= Rules.MINIGAME_MISS_BELOW, "the sample visit scores above the miss line (and spends no coins: none exist)")
	n.free()


func test_ghost() -> void:
	print("[stake 8] ghost: actions refused, decay frozen, begin_visit allowed and counts nothing")
	var n := fresh()
	set_all(n, 60.0)
	go(n, 21.0 * DAY)
	var m0: Dictionary = n.meters.duplicate()
	go(n, 5.0 * DAY)
	check(n.meters == m0, "meters frozen over 5 ghost days")
	var r: Dictionary = n.apply_action("order_drink")
	check(not r["ok"] and r["reason"] == "ghost", "apply_action refused with reason ghost")
	n.begin_visit()
	check(n.visit_active and n.is_ghost(), "the ghost can walk in")
	var d: float = n.days_since_visit()
	n.apply_action("order_drink")
	check(n.days_since_visit() >= d and n.is_ghost(), "nothing counts")
	check(n.ghost_reminder_reached() == 0.0, "day 26: no reminder yet")
	go(n, 2.0 * DAY)
	check(n.ghost_reminder_reached() == 28.0, "day 28 reminder reached")
	n.free()


func test_revival() -> void:
	print("[stake 9] Fake check-in in the window revives (floor 40, clock 0, Welcome Back, lives 2, zombie); a second within 90 days is refused")
	var n := fresh()
	set_all(n, 10.0)
	go(n, 25.0 * DAY)
	var res: Dictionary = n.check_in()
	check(res["ok"] and res["revived"], "check-in revives")
	check(n.meters["friends"] == 40.0 and n.meters["drinks"] == 40.0 and n.meters["music"] >= 40.0, "meters floored at 40")
	check(n.days_since_visit() == 0.0 and n.lives == 2 and n.zombie_next_visit and not n.is_ghost(), "clock 0, lives 2, zombie flag")
	var wb := []
	n.welcome_back_started.connect(func(r): wb.append(r))
	n.begin_visit()
	check(wb == ["revival"] and n.welcome_active() and n.visit_zombie and not n.zombie_next_visit, "the next visit is the zombie arrival with Welcome Back")
	n.end_visit()
	go(n, 22.0 * DAY)
	check(n.is_ghost(), "dies again")
	var again: Dictionary = n.check_in()
	check(not again["ok"] and again["reason"] == "revive_cooldown" and n.is_ghost(), "a second revival within 90 days is refused")
	go(n, 14.0 * DAY)
	check(n.is_deleted(), "and the window runs out")
	n.free()


func test_deletion_and_retire() -> void:
	print("[stake 10] deletion keeps player_id and settings; Retire does the same at once and is refused within 7 days")
	var n := fresh()
	n.profile = {"player_id": "abc", "display_name": "Mali"}
	n.ext = {"ui": {"orientation": "portrait"}, "minigame_best": {"pour_perfect": 80}, "hearts": {"tt": 2}}
	n.tab = 12.0
	n.visit_log.append({"start": T0})
	set_all(n, 30.0)
	go(n, 36.0 * DAY)
	check(n.is_deleted(), "deleted at day 36")
	n.complete_deletion()
	check(n.profile["player_id"] == "abc" and n.profile["display_name"] == "", "player_id kept, name gone")
	check(n.ext.get("ui", {}).get("orientation", "") == "portrait" and not n.ext.has("minigame_best") and not n.ext.has("hearts"), "settings kept, bests and hearts gone")
	check(n.tab == 0.0 and n.visit_log.is_empty() and n.meters["music"] == Rules.START_VALUE and n.lives == 1 and not n.is_ghost(), "everything else reset")
	n.profile["display_name"] = "Nok"
	n.ext["hearts"] = {"x": 1}
	check(n.retire(), "Retire deletes at once")
	check(n.profile["player_id"] == "abc" and n.profile["display_name"] == "" and not n.ext.has("hearts"), "Retire wipes the character, keeps the account")
	go(n, 6.0 * DAY)
	check(not n.retire(), "a second Retire inside 7 days is refused")
	go(n, 1.1 * DAY)
	check(n.retire(), "and allowed after 7")
	n.free()


func test_annoyances() -> void:
	print("[stake 11] annoyances on at their trigger, off on the named action; drag x0.85 per annoyance; own refill never dragged")
	var cure := {"thirsty": ["order_drink", "drinks"], "earworm": ["listen_song", "music"], "phone_face": ["social_verb", "friends"], "rusty": ["dance_30s", "nightlife"]}
	for id in cure:
		var n := fresh()
		set_all(n, 50.0)
		n.meters[Rules.ANNOYANCES[id]] = 5.0
		check(n.is_annoyed(id), "%s on when its meter is below 10" % id)
		n.begin_visit()
		check(n.is_annoyed(id), "%s still on at visit start" % id)
		n.apply_action(cure[id][0])
		check(not n.is_annoyed(id), "%s off after %s" % [id, cure[id][0]])
		n.meters[Rules.ANNOYANCES[id]] = 2.0
		n._refresh()
		check(not n.is_annoyed(id), "%s stays off for the rest of the visit even if the meter dips" % id)
		n.end_visit()
		check(n.is_annoyed(id), "%s is back after the visit when the meter is still empty" % id)
		n.free()
	var d := fresh()
	set_all(d, 50.0)
	d.meters["music"] = 2.0
	d.meters["friends"] = 2.0
	check(d.annoyances().size() == 2, "two on")
	var g: float = d.apply_action("order_drink")["gains"]["drinks"]
	check(near(g, 15.0 * 0.7225, 0.0001), "a third meter's gain is x0.7225 (%.4f)" % g)
	var own: float = d.apply_action("listen_song")["gains"]["music"]
	check(near(own, 5.0 * 0.85, 0.0001), "a meter's own refill is dragged only by the other annoyance, x0.85 not x0.7225 (%.3f)" % own)
	d.free()
	var c := fresh()
	go(c, 8.0 * DAY)
	check(not c.is_annoyed("out_of_loop"), "out_of_loop is off while the calendar habit is disabled")
	c.set_calendar_habit_enabled(true)
	check(not c.is_annoyed("out_of_loop"), "turning it on starts nobody annoyed")
	go(c, 8.0 * DAY)
	check(c.is_annoyed("out_of_loop"), "on after 7 days without the calendar")
	c.open_calendar()
	check(not c.is_annoyed("out_of_loop"), "off when the calendar is opened")
	c.free()
	var w := fresh()
	set_all(w, 50.0)
	w.meters["drinks"] = 1.0
	check(near(w.walk_mult(), Rules.THIRSTY_WALK_MULT, 1e-6) and near(w.music_duck_db(), 0.0, 1e-6), "Thirsty walks x0.75")
	w.meters["music"] = 1.0
	check(near(w.music_duck_db(), Rules.EARWORM_DUCK_DB, 1e-6), "Earworm ducks the music -9 dB")
	w.free()


func _card_result(game: String, action: String, score: float, miss: bool, key := "") -> Dictionary:
	return {"game_id": game, "action_id": action, "need_id": "", "key": key, "score": score, "points": roundi(score * 100.0),
		"tier": -1 if miss else 0, "miss": miss, "extra": {"regular": key} if key != "" else {}}


func test_misses() -> void:
	print("[stake 12] miss: 0.24 gives nothing and uses a try; 0.25 is good; Rusty raises the first round to 0.4")
	var n := fresh()
	set_all(n, 50.0)
	var card: Control = CardScript.new()
	card.needs = n
	var seen := []
	n.action_applied.connect(func(id, _r): seen.append(id))
	var rs := []
	var base: Control = Base.new()
	base.game_id = "pour_perfect"
	base.finished.connect(func(r): rs.append(r))
	base.finish(0.24)
	check(rs[0]["miss"] and rs[0]["tier"] == Base.TIER_MISS, "0.24 finishes as a miss")
	var o: Dictionary = card.apply(rs[0])
	check(o["miss"] and not o["ok"] and o["gains"].is_empty() and seen.is_empty(), "no gain, no minigame_played, no action at all (so Pour Perfect serves no drink)")
	check(n.meters["drinks"] == 50.0 and not n.ext.get("minigame_best", {}).has("pour_perfect"), "no meter change, no best")
	check(n.minigame_tries_left("pour_perfect") == 2, "but it used a try")
	var good: Control = Base.new()
	good.game_id = "pour_perfect"
	good.finished.connect(func(r): rs.append(r))
	good.finish(0.25)
	check(not rs[1]["miss"] and rs[1]["tier"] == 0, "0.25 is good")
	var r2 := fresh()
	set_all(r2, 50.0)
	r2.meters["nightlife"] = 3.0
	r2.begin_visit()
	check(r2.is_annoyed("rusty") and r2.minigame_miss_below() == Rules.RUSTY_MISS_BELOW, "Rusty: the first round misses below 0.4")
	var rb: Control = Base.new()
	rb.miss_below = r2.minigame_miss_below()
	var out := []
	rb.finished.connect(func(r): out.append(r))
	rb.finish(0.3)
	check(out[0]["miss"], "0.3 misses while Rusty")
	var c2: Control = CardScript.new()
	c2.needs = r2
	c2.apply(out[0])
	check(not r2.is_annoyed("rusty") and r2.minigame_miss_below() == Rules.MINIGAME_MISS_BELOW, "that round saw to Rusty (a miss counts); the next line is 0.25")
	card.free()
	c2.free()
	base.free()
	good.free()
	rb.free()
	n.free()
	r2.free()


func test_tries() -> void:
	print("[stake 13] 3 tries per minigame per visit; a new visit resets; a missed Candle Talk keeps the regular's daily talk")
	var n := fresh()
	set_all(n, 50.0)
	var card: Control = CardScript.new()
	card.needs = n
	var res := _card_result("pinball_x", "pinball", 0.5, false)
	for i in 3:
		check(card.apply(res)["reason"] != "tries", "round %d allowed" % (i + 1))
	var fourth: Dictionary = card.apply(res)
	check(not fourth["ok"] and fourth["reason"] == "tries" and fourth["tries_out"], "the fourth round of the same minigame is refused")
	check(card.apply(_card_result("other_game", "pinball", 0.5, false))["reason"] != "tries", "another minigame has its own tries")
	n.end_visit()
	n.begin_visit()
	check(card.apply(res)["reason"] != "tries", "a new visit resets the count")
	var m := fresh()
	set_all(m, 50.0)
	var c2: Control = CardScript.new()
	c2.needs = m
	var miss: Dictionary = c2.apply(_card_result("candle_talk", "candle_talk", 0.1, true, "tong"))
	check(miss["miss"] and not m.daily_keys.has("candle_talk|tong") and not m.ext.get("hearts", {}).has("tong"), "a missed talk costs no heart and not the daily talk")
	var talk: Dictionary = c2.apply(_card_result("candle_talk", "candle_talk", 0.9, false, "tong"))
	check(talk["ok"] and m.minigame_tries_left("candle_talk") == 1, "the talk is still available, and the miss cost a try")
	card.free()
	c2.free()
	n.free()
	m.free()


func test_minigame_played() -> void:
	print("[stake 14] minigame_played: +3 Nightlife per non-miss round, capped +9 per visit")
	var n := fresh()
	set_all(n, 50.0)
	var card: Control = CardScript.new()
	card.needs = n
	var before: float = n.meters["nightlife"]
	for i in 3:
		card.apply(_card_result("g%d" % i, "applaud", 0.5, false))
	check(near(n.meters["nightlife"] - before, 9.0, 0.001), "three rounds: +9 Nightlife (%.2f)" % (n.meters["nightlife"] - before))
	card.apply(_card_result("g3", "applaud", 0.5, false))
	check(near(n.meters["nightlife"] - before, 9.0, 0.001), "a fourth earns no more minigame_played (cap)")
	check(Rules.ACTIONS["minigame_played"]["cap_per_visit"] == 9.0, "the cap is 9")
	card.free()
	n.free()


func test_old_save_and_clock() -> void:
	print("[stake 15-16] an old save loads at Fine, clock at its last visit end, no calendar annoyance; a backward clock never un-kills")
	var n := fresh()
	var d: Dictionary = n.to_dict()
	for k in ["last_counted_visit", "stake_paused", "created_at", "nights_out", "stake_stage", "dead_at", "last_revival_at", "lives",
			"zombie_next_visit", "annoy_cleared", "minigame_tries", "last_calendar_at", "going", "last_retire_at", "stake_notified"]:
		d["needs"].erase(k)
	d["needs"]["last_visit_end"] = T0 - 3.0 * DAY
	d["visits"] = [{"start": T0 - 100.0 * DAY, "end": T0 - 3.0 * DAY}]
	var o := fresh(T0)
	o.from_dict(d)
	check(o.stake_stage == "fine" and o.lives == 1 and o.dead_at == 0.0 and o.nights_out == 1, "old save: Fine, 1 life, alive")
	check(near(o.days_since_visit(), 3.0, 0.1), "the clock starts at the last visit end (%.2f)" % o.days_since_visit())
	check(o.created_at == T0 - 100.0 * DAY and not o.is_annoyed("out_of_loop"), "created_at from the earliest visit, no calendar annoyance")
	var s := fresh()
	go(s, 21.0 * DAY)
	check(s.is_ghost(), "dead")
	s.time_override -= 30.0 * DAY
	s.sync()
	check(s.is_ghost() and not s.is_deleted(), "a backward device clock never un-kills")
	go(s, 40.0 * DAY)
	check(s.is_deleted(), "and time moving on deletes")
	s.time_override -= 100.0 * DAY
	s.sync()
	check(s.is_deleted(), "nor un-deletes")
	n.free()
	o.free()
	s.free()


func test_o1_first_checkin() -> void:
	print("[O1] real visits are required only after a character's first check-in")
	var n := fresh()
	n.real_visit_required = true
	set_all(n, 50.0)
	go(n, 5.0 * DAY)
	n.apply_action("order_drink")
	check(n.days_since_visit() == 0.0, "before any check-in an in-game refill still resets the clock")
	go(n, 5.0 * DAY)
	check(n.check_in()["ok"] and n.has_checked_in and n.days_since_visit() == 0.0, "the first check-in counts")
	go(n, 5.0 * DAY)
	n.apply_action("order_drink")
	check(near(n.days_since_visit(), 5.0, 0.001), "after it, an in-game refill no longer resets the clock")
	n.check_in()
	check(n.days_since_visit() == 0.0, "only a check-in does")
	var off := fresh()
	off.check_in()
	go(off, 5.0 * DAY)
	off.apply_action("order_drink")
	check(off.days_since_visit() == 0.0, "with the flag off (as shipped) the stand-in always counts")
	check(Rules.REAL_VISIT_REQUIRED == false, "REAL_VISIT_REQUIRED ships false")
	n.free()
	off.free()


func test_o2_no_stand_in_revival() -> void:
	print("[O2] no revival before the server: only the debug check-in revives; the ghost window runs out")
	var n := fresh()
	go(n, 22.0 * DAY)
	check(n.is_ghost(), "ghost")
	n.begin_visit()
	n.apply_action("order_drink")
	n.apply_action("listen_song")
	check(n.is_ghost() and n.lives == 1, "walking in and trying actions does not revive")
	n.end_visit()
	go(n, 13.0 * DAY)
	check(n.is_deleted(), "the window runs out")
	var m := fresh()
	go(m, 22.0 * DAY)
	check(m.check_in()["revived"], "the debug check-in runs the same code and revives")
	n.free()
	m.free()


func test_o3_memory() -> void:
	print("[O3] a memory at the bar counts only for a photo shared on a night the player checked in")
	var n := fresh()
	var first_night: int = n.night_key(n.clock)
	go(n, 6.0 * DAY)
	check(not n.memory_shared(first_night) and near(n.days_since_visit(), 6.0, 0.001), "no check-in that night: the memory does not count")
	check(not n.memory_shared(), "a memory shared tonight without checking in tonight does not count")
	n.check_in()
	var night: int = n.night_key(n.clock)
	go(n, 3.0 * DAY)
	check(n.memory_shared(night) and n.days_since_visit() == 0.0, "a photo from the checked-in night counts as a real visit")
	var g := fresh()
	g.check_in()
	var gn: int = g.night_key(g.clock)
	go(g, 22.0 * DAY)
	check(g.is_ghost() and not g.memory_shared(gn) and g.is_ghost(), "a ghost's memory does not revive or count")
	n.free()
	g.free()
