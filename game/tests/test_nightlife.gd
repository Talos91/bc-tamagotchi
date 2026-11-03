extends SceneTree
## Nightlife (DECISIONS "Playtest of 33dc5b9", BACKLOG B12): drunk levels at 3 / 4 / 7 / 10, WASTED at 11, the minor
## needs reset, the 12 h lockout through a save and load and the debug clock, Try again, Check the plumbing (and that it
## is offered only in the toilets), Light one up, and the WASTED lines in English and Thai.
##   godot --headless --path . --script res://tests/test_nightlife.gd

const Rules = preload("res://scripts/rules.gd")
const Save = preload("res://scripts/save.gd")
const Nightlife = preload("res://scripts/zones/nightlife.gd")
const N = preload("res://scripts/zones/nightlife_strings.gd")
const Tipsiness = preload("res://scripts/zones/tipsiness.gd")
const TEST_SAVE := "user://test_nightlife_save.json"
const T0 := 1793000000.0   # a fixed real time (unix seconds) for the save / load checks

var needs: Node
var main: Node
var fails: Array[String] = []
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _init() -> void:
	await process_frame
	needs = root.get_node_or_null("Needs")
	if needs == null:
		print("NIGHTLIFE FAIL: Needs autoload missing")
		quit(1)
		return
	var keep_path: String = needs.save_path
	needs.autosave = false
	needs.save_path = TEST_SAVE
	test_rules()
	test_cast_tonight()
	test_wear_off()
	test_strings()
	test_save_lockout()
	await test_venue()
	await test_locked_boot()
	needs.time_override = -1.0
	needs.delete_save()
	needs.save_path = keep_path
	needs.new_game()
	print("\n%d checks, %d failed" % [checks, fails.size()])
	if fails.is_empty():
		print("NIGHTLIFE TESTS PASS")
	else:
		print("NIGHTLIFE TESTS FAIL:\n  " + "\n  ".join(fails))
	quit(0 if fails.is_empty() else 1)


func test_rules() -> void:
	print("[rules] drunk from 3, growing from 4 to 10, WASTED at 11")
	check(Rules.DRUNK_FROM == 3 and Rules.DRUNK_FULL == 10 and Rules.WASTED_AFTER == 10, "Daniele's numbers: 3, 10, past 10")
	check(Nightlife.drunk_level(0) == 0.0 and Nightlife.drunk_level(2) == 0.0, "sober up to 2 drinks")
	var l3 := Nightlife.drunk_level(3)
	var l4 := Nightlife.drunk_level(4)
	var l7 := Nightlife.drunk_level(7)
	var l10 := Nightlife.drunk_level(10)
	check(l3 > 0.0 and l3 < 0.2, "3 drinks: the effect starts, light (%.3f)" % l3)
	check(l4 > l3 and l7 > l4 and l10 > l7, "it grows from 4 to 10 (%.3f, %.3f, %.3f)" % [l4, l7, l10])
	check(is_equal_approx(l10, 1.0) and Nightlife.drunk_level(11) == 1.0, "strongest at 10")
	check(not Nightlife.is_wasted(10) and Nightlife.is_wasted(11), "10 drinks is not WASTED, 11 is")
	check(Rules.WASTED_LOCKOUT_HOURS == 12.0, "lockout 12 h")
	check(Nightlife.clock_text(12 * 3600.0) == "12:00:00" and Nightlife.clock_text(61.2) == "0:01:02", "countdown text")
	var def: Dictionary = Rules.ACTIONS.get("light_one_up", {})
	check(def.get("gains", {}).has("friends") and def.has("cap_per_visit"), "light_one_up: a small Friends gain, capped per visit")


## Tuesday 2026-11-03 Bangkok (Daniele shows the game at the bar): the night number is the calendar night (not a
## per-save count), it is even, so Prae is in at WestTable0, and Tt is in; the parity rule still holds around it.
func test_cast_tonight() -> void:
	print("[cast] Prae and Ty are both in on the night of 2026-11-03 Bangkok, whatever the save")
	const Cast = preload("res://scripts/cast.gd")
	var open := 1793707200.0    # 2026-11-03 19:00 +07
	var close := 1793728800.0   # 2026-11-04 01:00 +07
	var next_day := 1793768400.0  # 2026-11-04 12:00 +07
	var tonight := Cast.night_at(open)
	check(tonight == 20760 and Cast.night_at(close) == tonight, "19:00 and 01:00 are one night (%d)" % tonight)
	check(Cast.night_at(next_day) == tonight + 1, "the next afternoon is the next night")
	var had_visits: int = needs.nights_out
	for visits in [0, 1, 3]:
		needs.nights_out = visits   # a fresh save, and saves with odd and even visit counts: the cast never reads it
		var h: Dictionary = Cast.hosts(Cast.night_at(open))
		check(h.get(Cast.TT_ZONE, "") == "tt" and h.get("table:WestTable0", "") == "mali", "with %d visits: Ty at the Long Table, Prae at WestTable0" % visits)
	needs.nights_out = had_visits
	check(not Cast.prae_in(tonight + 1) and Cast.hosts(tonight + 1).get(Cast.TT_ZONE, "") == "tt", "the odd night after: Prae out (parity rule), Ty in")


func test_wear_off() -> void:
	print("[wear off] one drink per DRUNK_SOBER_MINUTES of game clock; water takes two off")
	var t := Tipsiness.new()
	t.reset(0.0)
	for i in 6:
		t.add_alcohol(0.0)
	check(t.drinks == 6 and t.state() == Tipsiness.MERRY, "six drinks: Merry")
	t.update(Tipsiness.DROP_SECONDS * 2.0 + 1.0)
	check(t.drinks == 4, "two drinks wear off in 2 x %d min (%d left)" % [int(Rules.DRUNK_SOBER_MINUTES), t.drinks])
	t.water(Tipsiness.DROP_SECONDS * 2.0 + 2.0)
	check(t.drinks == 4 - Rules.WATER_SOBER_DRINKS, "a glass of water takes %d off" % Rules.WATER_SOBER_DRINKS)
	t.update(Tipsiness.DROP_SECONDS * 100.0)
	check(t.drinks == 0, "all worn off in time")


func test_strings() -> void:
	print("[strings] every nightlife string in English and Thai; ten WASTED lines")
	var keys: Array[String] = []
	var f := FileAccess.open(N.CSV_PATH, FileAccess.READ)
	check(f != null, "strings_nightlife.csv readable")
	if f == null:
		return
	f.get_csv_line()
	var th_by_key := {}
	var en_by_key := {}
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() >= 3 and r[0] != "":
			keys.append(r[0])
			en_by_key[r[0]] = r[1]
			th_by_key[r[0]] = r[2]
	var missing := []
	for k in keys:
		if str(en_by_key[k]).strip_edges() == "" or str(th_by_key[k]).strip_edges() == "":
			missing.append(k)
	check(missing.is_empty(), "no empty English or Thai cell (%s)" % ", ".join(missing))
	var lines_en := {}
	for i in Rules.WASTED_LINES:
		var k := "nightlife.wasted.line.%d" % i
		TranslationServer.set_locale("en")
		var en := N.t(k)
		TranslationServer.set_locale("th")
		var th := N.t(k)
		check(en != k and th != k and en != th and en.length() <= 70, "line %d in English and Thai: %s / %s" % [i, en, th])
		lines_en[en] = true
	TranslationServer.set_locale("en")
	check(lines_en.size() == 10 and keys.has("nightlife.wasted.line.9") and not keys.has("nightlife.wasted.line.10"),
		"exactly ten different lines")
	var banned := ["drive", "driving", "car", "die", "dead", "hospital", "kill"]
	var bad := []
	for k in keys:
		for w in banned:
			if (" " + str(en_by_key[k]).to_lower() + " ").contains(" " + w + " "):
				bad.append(k)
	check(bad.is_empty(), "no drink-driving or harm words (%s)" % ", ".join(bad))
	for k in ["nightlife.wasted.title", "nightlife.wasted.try", "nightlife.wasted.wait", "nightlife.wasted.note",
			"nightlife.row.plumbing", "nightlife.prompt.toilet", "nightlife.row.smoke"]:
		check(keys.has(k), "string %s" % k)


func test_save_lockout() -> void:
	print("[lockout] WASTED resets the minor needs and locks 12 h, through a save / load and the debug clock")
	needs.time_override = T0
	needs.new_game()
	needs.begin_visit()
	for m in Rules.METERS:
		needs.meters[m] = 80.0
	needs.tab = 7.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var line := Nightlife.get_wasted(needs, rng)
	check(line >= 0 and line < Rules.WASTED_LINES, "a line picked (%d)" % line)
	var zero := true
	for m in Rules.METERS:
		zero = zero and needs.meters[m] == Rules.WASTED_METER_VALUE
	check(zero, "all four minor needs reset to %d" % int(Rules.WASTED_METER_VALUE))
	check(needs.tab == 7.0, "Tab untouched")
	check(not needs.visit_active and needs.visit_log.back().get("end", 0.0) > 0.0, "the visit ended")
	check(Nightlife.locked(needs) and is_equal_approx(Nightlife.seconds_left(needs), 12.0 * 3600.0), "locked out for 12 h")
	var line2 := Nightlife.get_wasted(needs, rng)
	check(line2 != line, "the next WASTED shows another line")
	needs.ext[Nightlife.KEY]["line"] = line
	# Save, close the app for 6 real hours, open it again: still locked, 6 h left
	check(needs.save_game(), "saved")
	needs.new_game()
	check(not Nightlife.locked(needs), "a new game has no lockout")
	needs.time_override = T0 + 6.0 * 3600.0
	needs.from_dict(Save.read(TEST_SAVE))
	check(Nightlife.locked(needs), "still locked after a restart")
	check(absf(Nightlife.seconds_left(needs) - 6.0 * 3600.0) < 2.0, "6 h left after 6 h closed (%.0f s)" % Nightlife.seconds_left(needs))
	check(Nightlife.last_line(needs) == line, "the same line comes back on the locked screen")
	var zero2 := true
	for m in Rules.METERS:
		zero2 = zero2 and needs.meters[m] <= Rules.WASTED_METER_VALUE + 0.01
	check(zero2, "the reset meters were saved")
	# Debug clock: x60 makes 6 h pass in 6 real minutes; F2 jumps a day
	needs.set_clock_multiplier(Rules.DEBUG_CLOCK_MULTIPLIER)
	needs.time_override = T0 + 6.0 * 3600.0 + 3.0 * 60.0
	needs.sync()
	check(absf(Nightlife.seconds_left(needs) - 3.0 * 3600.0) < 2.0, "debug clock x60: 3 real minutes take 3 h off")
	needs.set_clock_multiplier(1.0)
	needs.debug_advance(86400.0)
	check(not Nightlife.locked(needs), "debug +1 day (F2) ends the lockout")
	needs.time_override = -1.0


## main.tscn in the venue: the toilets' secret, the smoking room, drinking to 10, WASTED at 11, Try again.
func test_venue() -> void:
	print("[venue] the toilets, the smoking room, drunk at 3 / 4 / 7 / 10, WASTED at 11, Try again")
	needs.time_override = -1.0
	needs.new_game()
	for m in Rules.METERS:
		needs.meters[m] = 40.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await physics_frame
	var s: VenueSession = main.session
	s.rng.seed = 3
	check(needs.visit_active, "visit started")

	# Check the plumbing: only in the toilets
	var loo: Dictionary = main.zones.first_of("toilet")
	check(not loo.is_empty(), "a toilets zone from the Vestibule kit")
	var elsewhere := []
	for z in main.zones.zones:
		for r in s.rows_for(z):
			if r["id"] == "plumbing" and z["kind"] != "toilet":
				elsewhere.append(z["id"])
		if z["kind"] != "toilet" and s.prompt_for(z).to_lower().contains("plumbing"):
			elsewhere.append(z["id"] + " (prompt)")
	check(elsewhere.is_empty(), "Check the plumbing appears nowhere else (%s)" % ", ".join(elsewhere))
	await teleport(loo)
	check(main.zones.current.get("kind", "") == "toilet", "the player can stand in the toilets (%s)" % main.zones.current.get("id", "none"))
	check(s.prompt_for(loo) == N.t("nightlife.prompt.toilet"), "the toilets prompt hints at it")
	var ids := []
	for r in s.rows_for(loo):
		ids.append(r["id"])
	check(ids == ["plumbing"], "the toilets sheet offers Check the plumbing")
	needs.meters["drinks"] = 85.0
	needs.visit_points["drinks"] = 60.0
	await row("plumbing")
	check(needs.meters["drinks"] == 0.0, "Check the plumbing: drink need to 0")
	check(needs.visit_points["drinks"] == 0.0, "...and this visit's Drinks points forgotten")
	var r: Dictionary = needs.apply_action("order_drink")
	check(is_equal_approx(float(r["gains"]["drinks"]), 15.0), "the next drink counts in full again (+%.1f)" % float(r["gains"]["drinks"]))
	check(is_instance_valid(main.hud.card), "an action card after it")

	# Light one up
	var smoke: Dictionary = main.zones.first_of("smoking")
	await teleport(smoke)
	check(main.zones.current.get("kind", "") == "smoking", "in the smoking room")
	var srows := []
	for rr in s.rows_for(smoke):
		srows.append(rr["id"])
	check(srows.has("smoke") and srows.has("sit"), "smoking room: Light one up and a seat")
	var f0: float = needs.meters["friends"]
	await row("smoke")
	check(not s.smoking.is_empty() and main.player.pose_override == "stand_drink", "a cigarette in hand")
	var cig: Node = main.player.find_child("Cigarette", true, false)
	check(cig != null and cig.find_child("Smoke", true, false) is CPUParticles3D, "cigarette prop with smoke particles")
	check(main.hud._status.text != "", "HUD shows the cigarette burning (%s)" % main.hud._status.text)
	s.tick(Rules.SMOKE_SECONDS * 0.5)
	check(needs.meters["friends"] <= f0 + 0.01, "nothing until it is finished")
	s.tick(Rules.SMOKE_SECONDS * 0.5 + 0.1)
	await process_frame
	check(s.smoking.is_empty() and needs.meters["friends"] > f0, "finished: Friends +%.1f" % (needs.meters["friends"] - f0))
	check(main.player.find_child("Cigarette", true, false) == null and main.player.pose_override == "", "cigarette put out")

	# Drinking: overlay from 3, growing to 10, no WASTED at 10, Nam warns from 8
	var bar: Dictionary = main.zones.first_of("bar")
	await teleport(bar)
	for want in [3, 4, 7, 10]:
		while s.tipsy.drinks < want:
			check(s.order_item("house_shooter"), "alcohol served (drink %d)" % (s.tipsy.drinks + 1))
		main.drunk.snap()
		check(is_equal_approx(main.drunk.amount, Nightlife.drunk_level(want)) and main.drunk.rect.visible,
			"drunk at %d: overlay %.3f" % [want, main.drunk.amount])
	check(needs.visit_active and not Nightlife.locked(needs) and not is_instance_valid(main.wasted_shot), "10 drinks: still standing")
	var order: Dictionary = {}
	for rr in s.rows_for(bar):
		if rr["id"] == "order":
			order = rr
	check(order.get("enabled", false) and order.get("sub", "") == N.t("nightlife.bar.warn"), "Nam warns, never refuses")

	# The 11th: WASTED
	var got := [-1]
	s.wasted.connect(func(l): got[0] = l)
	for m in Rules.METERS:
		needs.meters[m] = 70.0
	check(s.order_item("house_shooter"), "the 11th drink")
	await process_frame
	check(got[0] >= 0, "WASTED (line %d)" % got[0])
	check(not needs.visit_active, "visit over")
	var zero := true
	for m in Rules.METERS:
		zero = zero and needs.meters[m] == Rules.WASTED_METER_VALUE
	check(zero, "every minor need back to unfulfilled")
	check(Nightlife.locked(needs), "locked out")
	check(is_instance_valid(main.wasted_shot) and not is_instance_valid(main.walk_out), "the WASTED shot, no walk-out card")
	check(main._blocked() and not main.hud.visible, "input blocked, HUD hidden")
	var shot: Node = main.wasted_shot
	check(shot.cam != null and shot.cam.current, "a camera of its own")
	for i in 20:
		await process_frame
	shot.skip()
	await process_frame
	var screen: Control = shot.screen
	check(is_instance_valid(screen), "the WASTED screen")
	if not is_instance_valid(screen):
		return
	check(screen.title.text == "WASTED" and screen.title.theme_type_variation == &"LabelTitle", "WASTED in Kristi (LabelTitle)")
	check(screen.line_label.text == N.t("nightlife.wasted.line.%d" % got[0]), "the funny line under it")
	check(screen.try_button.disabled and (screen.try_button.text.contains("12:00:00") or screen.try_button.text.contains("11:59")), "Try again disabled with a countdown (%s)" % screen.try_button.text)
	screen.try_button.pressed.emit()
	await process_frame
	check(is_instance_valid(main.wasted_shot), "pressing it while locked does nothing")
	needs.debug_advance(Rules.WASTED_LOCKOUT_HOURS * 3600.0 + 1.0)
	screen.refresh()
	check(not screen.try_button.disabled and screen.try_button.text == N.t("nightlife.wasted.try"), "debug clock past 12 h: Try again enabled")
	screen.try_button.pressed.emit()
	for i in 3:
		await process_frame
	check(not is_instance_valid(main.wasted_shot), "Try again closes the screen")
	check(needs.visit_active and s.tipsy.drinks == 0, "a new visit, sober")
	check(absf(main.player.get_node("Body").rotation.x) < 0.001 and main.player.rig.camera.current, "back on their feet, diorama camera")
	main.queue_free()
	await process_frame


## The game opened during a lockout goes straight to the WASTED screen, and Try again waits for the clock.
func test_locked_boot() -> void:
	print("[boot] opened during the lockout")
	needs.new_game()
	needs.begin_visit()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var line := Nightlife.get_wasted(needs, rng)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await physics_frame
	check(is_instance_valid(main.wasted_shot) and is_instance_valid(main.wasted_shot.screen), "straight to the WASTED screen")
	check(not needs.visit_active, "no visit starts")
	if is_instance_valid(main.wasted_shot) and is_instance_valid(main.wasted_shot.screen):
		var screen: Control = main.wasted_shot.screen
		check(screen.line_label.text == N.t("nightlife.wasted.line.%d" % line), "the same line as when it happened")
		check(screen.try_button.disabled, "Try again disabled")
		needs.debug_advance(Rules.WASTED_LOCKOUT_HOURS * 3600.0)
		screen.refresh()
		check(not screen.try_button.disabled, "enabled once the clock has run")
		screen.try_button.pressed.emit()
		for i in 3:
			await process_frame
		check(not is_instance_valid(main.wasted_shot) and needs.visit_active and main.player.visible, "Try again: in through the door")
	main.queue_free()
	await process_frame


func teleport(z: Dictionary) -> void:
	main.player.walking_to = false
	main.player.global_position = z["approach"] + Vector3(0, 0.05, 0)
	main.player.velocity = Vector3.ZERO
	for i in 8:
		await physics_frame
	main.player.velocity = Vector3.ZERO


## Opens the current zone's sheet and taps a row (as tests/smoke_loop.gd does).
func row(id: String) -> void:
	main.hud.prompt_pressed.emit()
	await process_frame
	if not is_instance_valid(main.sheet) or not main.sheet.buttons.has(id):
		check(false, "row %s in sheet" % id)
		main.close_sheet()
		await process_frame
		return
	var b: Button = main.sheet.buttons[id]
	check(not b.disabled, "row %s enabled" % id)
	b.pressed.emit()
	await process_frame
