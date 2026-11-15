extends SceneTree
## Tonight + upcoming events (backlog D1/D2, docs/design/09-tonight-events.md), headless:
## Bangkok date → evening mapping, after-midnight (still the previous evening until 02:00), closed Monday, months
## with and without data (never invented), month and year rollover, strings (EN + TH, every dynamic key), the sheet
## (rows, tonight card, no raw keys on screen, both orientations) and the HUD button opening it from main.tscn.
##   godot --headless --path . --script res://tests/test_tonight.gd

const TE = preload("res://scripts/tonight_events.gd")
const Sheet = preload("res://scenes/tonight_sheet.gd")

var fails := 0
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ", what)


func _init() -> void:
	await process_frame
	TranslationServer.set_locale("en")
	_clock()
	_evenings()
	_data()
	_strings()
	await _sheet()
	await _hud()
	TE.now_override = -1
	print("tonight: %d checks, %d failures" % [checks, fails])
	print("TEST TONIGHT ", "PASS" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)


func _clock() -> void:
	var u := TE.bkk_unix(2026, 10, 21, 20, 0)
	var l := TE.local(u)
	check(l["hour"] == 20 and l["day"] == 21 and l["weekday"] == 3, "bkk_unix/local round trip: %s" % [l])
	# 18:30 UTC on the 21st is 01:30 in Bangkok on the 22nd
	var utc := int(Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 21, "hour": 18, "minute": 30, "second": 0}))
	check(TE.local(utc)["day"] == 22 and TE.local(utc)["hour"] == 1, "UTC+7: 18:30Z is 01:30 the next day")
	check(TE.evening(utc)["date"] == "2026-10-21", "UTC+7: 01:30 Bangkok belongs to the previous evening")
	TE.now_override = u
	check(TE.now_unix() == u, "now_override pins the clock")
	TE.now_override = -1
	check(absi(TE.now_unix() - int(Time.get_unix_time_from_system())) < 5, "real clock without an override")


func _ev(h: Array) -> Dictionary:
	return TE.evening(TE.bkk_unix(h[0], h[1], h[2], h[3], h[4] if h.size() > 4 else 0))


func _evenings() -> void:
	# [bangkok time] -> evening date, state
	var cases := [
		[[2026, 10, 21, 20, 0], "2026-10-21", "open", "Wed evening"],
		[[2026, 10, 21, 19, 0], "2026-10-21", "open", "19:00 sharp opens"],
		[[2026, 10, 21, 18, 59], "2026-10-21", "later", "18:59 still before doors"],
		[[2026, 10, 22, 0, 0], "2026-10-21", "open", "midnight is still Wednesday's evening"],
		[[2026, 10, 22, 1, 59], "2026-10-21", "open", "01:59 still Wednesday's evening"],
		[[2026, 10, 22, 2, 0], "2026-10-22", "later", "02:00: the evening is over, tonight is Thursday"],
		[[2026, 10, 22, 12, 0], "2026-10-22", "later", "Thursday noon"],
		[[2026, 10, 19, 20, 0], "2026-10-19", "closed", "Monday evening is closed"],
		[[2026, 10, 19, 12, 0], "2026-10-19", "closed", "Monday noon: closed tonight"],
		[[2026, 10, 19, 1, 0], "2026-10-18", "open", "Monday 01:00 is still Sunday's open evening"],
		[[2026, 10, 20, 1, 30], "2026-10-19", "closed", "Tuesday 01:30 is Monday's (closed) evening"],
		[[2026, 10, 20, 2, 0], "2026-10-20", "later", "Tuesday 02:00: tonight is Tuesday, doors at 19:00"],
		[[2026, 10, 18, 23, 0], "2026-10-18", "open", "Sunday evening is open"],
		[[2026, 11, 1, 1, 0], "2026-10-31", "open", "month edge: 1 Nov 01:00 is Halloween night"],
		[[2027, 1, 1, 1, 0], "2026-12-31", "open", "year edge: New Year 01:00 is 31 Dec's evening"],
	]
	for c in cases:
		var e := _ev(c[0])
		check(e["date"] == c[1] and e["state"] == c[2], "%s: got %s %s, want %s %s" % [c[3], e["date"], e["state"], c[1], c[2]])
	var mon := _ev([2026, 10, 19, 20, 0])
	check(mon["next_open"]["weekday"] == 2 and mon["next_open"]["day"] == 20, "closed Monday: next open is Tuesday the 20th")
	var mon2 := _ev([2026, 11, 30, 20, 0])   # Monday 30 Nov -> Tuesday 1 Dec
	check(mon2["state"] == "closed" and mon2["next_open"]["month"] == 12 and mon2["next_open"]["day"] == 1, "closed Monday at a month edge: next open 1 Dec")


func _data() -> void:
	TE.reset_cache()
	check(TE.has_month("2026-10"), "2026-10 is bundled (res://data/events/2026-10.json)")
	check(not TE.has_month("2026-11"), "2026-11 has no data yet (poster missing): not invented")
	var oct: Array = TE.month_events("2026-10")
	check(oct.size() == 9, "October has the 9 poster events (got %d)" % oct.size())
	var sorted := true
	for i in range(1, oct.size()):
		sorted = sorted and str(oct[i - 1]["date"]) <= str(oct[i]["date"])
	check(sorted, "October events sorted by date")

	var jam := TE.tonight(TE.bkk_unix(2026, 10, 21, 21, 0))
	check(jam["known"] and jam["events"].size() == 1 and jam["events"][0]["title"] == "The Cabin Jam", "21 Oct: The Cabin Jam tonight")
	check(jam["events"][0].get("lineup", []).size() == 4, "The Cabin Jam has its 4-name lineup")
	var late := TE.tonight(TE.bkk_unix(2026, 10, 22, 1, 15))
	check(late["events"].size() == 1 and late["events"][0]["title"] == "The Cabin Jam", "after midnight: still The Cabin Jam")
	var plain := TE.tonight(TE.bkk_unix(2026, 10, 23, 20, 0))
	check(plain["known"] and plain["events"].is_empty() and plain["state"] == "open", "23 Oct: known month, no event: a regular night")
	var hallo := TE.tonight(TE.bkk_unix(2026, 11, 1, 0, 30))
	check(hallo["events"].size() == 1 and hallo["events"][0]["title"] == "Halloween", "1 Nov 00:30 shows Halloween (31 Oct)")
	var monday := TE.tonight(TE.bkk_unix(2026, 10, 19, 21, 0))
	check(monday["state"] == "closed" and monday["events"].is_empty(), "Monday: closed, no event shown")
	var nov := TE.tonight(TE.bkk_unix(2026, 11, 15, 20, 0))
	check(not nov["known"] and nov["events"].is_empty() and nov["state"] == "open", "15 Nov: month without data, nothing invented")

	var up := TE.upcoming(TE.bkk_unix(2026, 10, 21, 20, 0))
	var dates: Array = up["events"].map(func(e): return e["date"])
	check(dates == ["2026-10-25", "2026-10-29", "2026-10-31"], "upcoming after 21 Oct: %s" % [dates])
	check(up["missing"] == ["2026-11"], "upcoming names November as missing: %s" % [up["missing"]])
	var up_late := TE.upcoming(TE.bkk_unix(2026, 10, 22, 1, 0))
	check(up_late["events"].size() == 3 and up_late["events"][0]["date"] == "2026-10-25", "upcoming after midnight excludes tonight's event only")
	var up_start := TE.upcoming(TE.bkk_unix(2026, 10, 1, 12, 0))
	check(up_start["events"].size() == TE.UPCOMING_MAX, "upcoming capped at %d" % TE.UPCOMING_MAX)
	var up_nov := TE.upcoming(TE.bkk_unix(2026, 11, 15, 20, 0))
	check(up_nov["events"].is_empty() and up_nov["missing"] == ["2026-11", "2026-12"], "upcoming in November: both months missing")
	check(TE._next_month("2026-12") == "2027-01", "next month rolls the year")


func _strings() -> void:
	var f := FileAccess.open(TE.CSV_PATH, FileAccess.READ)
	check(f != null, "strings_tonight.csv opens")
	if f == null:
		return
	var head := f.get_csv_line()
	check(head.size() >= 3 and head[0] == "key" and head[1] == "en" and head[2] == "th", "csv header key,en,th")
	var keys := {}
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() >= 3 and r[0] != "":
			keys[r[0]] = true
			check(r[1].strip_edges() != "" and r[2].strip_edges() != "", "EN and TH for " + r[0])
	var dyn: Array = []
	for i in 7:
		dyn.append("tonight.day.%d" % i)
	for i in range(1, 13):
		dyn.append("tonight.month.%d" % i)
		dyn.append("tonight.month_long.%d" % i)
	for k in dyn:
		check(keys.has(k) and TE.t(k) != k, "dynamic key resolves: " + k)
	check(TE.date_text("2026-10-21") == "Wed 21 Oct", "date_text: " + TE.date_text("2026-10-21"))
	check(TE.month_text("2026-11") == "November 2026", "month_text: " + TE.month_text("2026-11"))
	check(TE.time_text({"time": "22:45", "time_kind": "showtime"}) == "Showtime 22:45", "showtime text")
	check(TE.time_text({"time": "21:15", "time_kind": "onwards"}) == "From 21:15", "onwards text")
	check(TE.state_text(_ev([2026, 10, 19, 20])).contains("Tue"), "closed line names Tuesday")
	TranslationServer.set_locale("th")
	check(TE.t("tonight.button") == "คืนนี้", "Thai button label")
	check(not TE.date_text("2026-10-21").contains("tonight."), "Thai date has no raw keys")
	TranslationServer.set_locale("en")


func _labels(n: Node) -> Array:
	var out: Array = []
	for c in n.find_children("*", "Label", true, false):
		out.append(c)
	for c in n.find_children("*", "Button", true, false):
		out.append(c)
	return out


func _no_raw_keys(n: Node, tag: String) -> void:
	var raw: Array = []
	var re := RegEx.create_from_string(r"tonight\.[a-z0-9_]")
	for l in _labels(n):
		if re.search(str(l.text)) != null or str(l.text).contains("{"):
			raw.append(l.text)
	check(raw.is_empty(), tag + ": no raw keys or placeholders on screen: %s" % [raw])


func _sheet() -> void:
	for loc in ["en", "th"]:
		TranslationServer.set_locale(loc)
		for size in [Vector2i(1080, 1920), Vector2i(1920, 1080)]:
			root.size = size
			var s := Sheet.new()
			root.add_child(s)
			s.open(TE.bkk_unix(2026, 10, 21, 21, 0))
			for i in 3:
				await process_frame
			var tag := "sheet %s %s" % [loc, size]
			check(s.rows.size() == 3, tag + ": 3 Coming up rows (got %d)" % s.rows.size())
			check(s.tonight_card.find_child("EventTitle", true, false) != null, tag + ": tonight card shows the event")
			check(s.find_child("Missing_2026-11", true, false) != null, tag + ": November named as not in yet")
			var panel: Control = s.find_child("TonightSheet", true, false)
			var vp := root.get_visible_rect()   # canvas_items/expand stretch: landscape is wider than 1920
			check(panel != null and vp.grow(1.0).encloses(panel.get_global_rect()), tag + ": sheet inside the screen %s" % [panel.get_global_rect() if panel else null])
			_no_raw_keys(s, tag)
			s.queue_free()
			await process_frame
	TranslationServer.set_locale("en")
	root.size = Vector2i(1080, 1920)
	for case in [[[2026, 10, 19, 21, 0], "closed"], [[2026, 11, 15, 20, 0], "no data"], [[2026, 10, 23, 20, 0], "regular"]]:
		var h: Array = case[0]
		var s := Sheet.new()
		root.add_child(s)
		s.open(TE.bkk_unix(h[0], h[1], h[2], h[3], h[4]))
		await process_frame
		check(s.tonight_card.find_child("EventTitle", true, false) == null, "sheet %s: no event title" % case[1])
		_no_raw_keys(s, "sheet " + case[1])
		var closed := [false]
		s.closed.connect(func(): closed[0] = true)
		(s.find_child("Close", true, false) as Button).pressed.emit()
		check(closed[0], "sheet %s: Close emits closed" % case[1])
		s.queue_free()
		await process_frame


func _hud() -> void:
	var needs: Node = root.get_node_or_null("Needs")
	check(needs != null, "Needs autoload")
	if needs == null:
		return
	needs.autosave = false
	needs.new_game()
	TE.now_override = TE.bkk_unix(2026, 10, 21, 21, 0)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var hud: Control = main.get_node("UI/Hud")
	var btn: Button = hud.find_child("Tonight", true, false)
	check(btn != null and btn.is_visible_in_tree() and btn.text == "Tonight", "HUD has a visible Tonight button")
	if btn == null:
		return
	var vp := root.get_visible_rect()
	var r := btn.get_global_rect()
	check(vp.encloses(r), "Tonight button on screen %s" % [r])
	var hits: Array = []
	for c: Control in hud.find_children("*", "Control", true, false):
		if (c.name == "Leave" or str(c.name).begins_with("Ring_") or c == hud.orientation_toggle) and c.get_global_rect().intersects(r):
			hits.append(c.name)
	check(hits.is_empty(), "Tonight button clear of Leave, rings and the orientation toggle: %s" % [hits])
	btn.pressed.emit()
	await process_frame
	check(is_instance_valid(main.tonight), "the button opens the Tonight sheet")
	check(not main.player.input_enabled, "the sheet blocks walking while open")
	check(main.tonight.rows.size() == 3, "pinned 21 Oct: three upcoming rows in the game's sheet")
	main.tonight.close()
	for i in 2:
		await process_frame
	check(not is_instance_valid(main.tonight) and main.player.input_enabled, "closing it gives walking back")
	main.queue_free()
	await process_frame
