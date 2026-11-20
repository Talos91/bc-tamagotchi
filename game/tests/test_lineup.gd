extends SceneTree
## Who's playing tonight + the month calendar (tonight-lineup, 2026-11-20), headless: the weekly lineup files
## (res://data/events/lineup-<monday>.json), act set slots and "now on stage" by the Bangkok clock, photos, text, the
## Tonight tab's act cards (lineup night, special night, closed Monday, week without data) and the Calendar tab (grid,
## special days, tap a day, month change), EN + TH, portrait + landscape, no raw keys, data copies match docs/.
##   godot --headless --path . --script res://tests/test_lineup.gd

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
	TE.reset_cache()
	_copies()
	_data()
	_slots()
	_text()
	_stage()
	await _stage_chip()
	await _tonight_tab()
	await _calendar_tab()
	TE.now_override = -1
	print("lineup: %d checks, %d failures" % [checks, fails])
	print("TEST LINEUP ", "PASS" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)


func _u(h: Array) -> int:
	return TE.bkk_unix(h[0], h[1], h[2], h[3], h[4] if h.size() > 4 else 0)


## The game's copies under res://data/events/ are the docs/venue/events/ files byte for byte.
func _copies() -> void:
	var docs := ProjectSettings.globalize_path("res://").path_join("../docs/venue/events/")
	for f in ["2026-11.json", "lineup-2026-11-16.json"]:
		var a := FileAccess.get_file_as_string(TE.DATA_DIR + f)
		var b := FileAccess.get_file_as_string(docs + f)
		check(a != "" and a == b, "res://data/events/%s matches docs/venue/events/%s" % [f, f])


func _data() -> void:
	check(TE.week_monday("2026-11-16") == "2026-11-16", "week_monday: Monday is its own week")
	check(TE.week_monday("2026-11-22") == "2026-11-16", "week_monday: Sunday 22 belongs to Mon 16")
	check(TE.week_monday("2026-11-20") == "2026-11-16", "week_monday: Friday 20 -> Mon 16")
	check(TE.week_monday("2026-11-23") == "2026-11-23", "week_monday: Mon 23 starts the next week")
	check(TE.week_monday("2026-12-01") == "2026-11-30", "week_monday across a month edge")
	var counts := {"2026-11-16": 3, "2026-11-17": 3, "2026-11-18": 3, "2026-11-19": 3, "2026-11-20": 3, "2026-11-21": 3, "2026-11-22": 3}
	for d in counts:
		var lu := TE.lineup(d)
		check(lu["known"] and lu["acts"].size() == counts[d], "%s: %d acts (got %d)" % [d, counts[d], lu["acts"].size()])
	check(not TE.lineup("2026-11-24")["known"], "week of 23 Nov: no file, not invented")
	check(not TE.lineup("2026-11-15")["known"], "week of 9 Nov: no file, not invented")
	check(TE.lineup("2026-11-19")["title"] == "John Mayer Night", "Thursday 19 is John Mayer Night")
	var thu: Array = TE.lineup("2026-11-19")["acts"]
	check(thu.map(func(a): return a["name"]) == ["Kirk", "Jayson Creer x Earth", "Jayson Creer x Angie"], "John Mayer Night program in order")
	var fri: Array = TE.lineup("2026-11-20")["acts"]
	check(fri[2]["name"] == "Sam Sermsartr", "after-midnight act sorts last (01:00 after 23:15)")
	var photos := 0
	for d in counts:
		for a in TE.lineup(d)["acts"]:
			if a.has("photo"):
				photos += 1
				check(TE.act_photo(a) != null, "photo loads: " + str(a["photo"]))
			else:
				check(TE.act_photo(a) == null, "no photo on the poster: " + str(a["name"]))
			check(str(a.get("slug", "")) != "" and str(a["slug"]) == str(a["slug"]).to_lower(), "slug set: " + str(a["name"]))
	check(photos == 18, "18 act photos (6 lineup posters x 3), got %d" % photos)
	# tonight() carries the lineup; closed Monday shows none
	var wed := TE.tonight(_u([2026, 11, 18, 22, 0]))
	check(wed["lineup_known"] and wed["acts"].size() == 3 and wed["now_act"] == 1, "Wed 18 22:00: 3 acts, Mut Matthew on stage")
	check(wed["events"].size() == 1 and str(wed["events"][0]["title"]).begins_with("Bartender Guest Shift"), "Wed 18: the guest shift too")
	var mon := TE.tonight(_u([2026, 11, 16, 21, 0]))
	check(mon["state"] == "closed" and mon["acts"].is_empty() and mon["now_act"] == -1, "Mon 16: closed by the game's hours, no act cards")
	var later := TE.tonight(_u([2026, 11, 20, 15, 0]))
	check(later["state"] == "later" and later["acts"].size() == 3 and later["now_act"] == -1, "Fri 15:00: lineup shown, nobody on stage yet")


func _slots() -> void:
	var cases := [
		[[2026, 11, 18, 19, 29], "2026-11-18", -1, "Wed 19:29: before the first set"],
		[[2026, 11, 18, 19, 30], "2026-11-18", 0, "Wed 19:30: Aomsin starts"],
		[[2026, 11, 18, 21, 5], "2026-11-18", -1, "Wed 21:05: between sets"],
		[[2026, 11, 18, 23, 50], "2026-11-18", 2, "Wed 23:50: Far x Jayson Creer"],
		[[2026, 11, 19, 1, 30], "2026-11-18", 2, "Thu 01:30: still Wednesday's till-late set"],
		[[2026, 11, 19, 21, 30], "2026-11-19", 0, "Thu 21:30: Kirk opening (runs to the next set)"],
		[[2026, 11, 19, 22, 45], "2026-11-19", 1, "Thu 22:45: the cover set"],
		[[2026, 11, 20, 0, 40], "2026-11-19", 2, "Fri 00:40: closing set"],
		[[2026, 11, 21, 0, 10], "2026-11-20", 1, "Sat 00:10: Run Baby Run (23:15-00:45)"],
		[[2026, 11, 21, 0, 50], "2026-11-20", -1, "Sat 00:50: between Run Baby Run and Sam"],
		[[2026, 11, 21, 1, 0], "2026-11-20", 2, "Sat 01:00: Sam Sermsartr"],
		[[2026, 11, 21, 21, 0], "2026-11-20", -1, "another evening's date: -1"],
	]
	for c in cases:
		var got := TE.now_on_stage(c[1], _u(c[0]))
		check(got == c[2], "%s: got %d want %d" % [c[3], got, c[2]])
	var s := TE.act_slots(TE.lineup("2026-11-18")["acts"])
	check(s[2][1] == TE.LATE_MIN, "till late runs to 02:00")


func _text() -> void:
	var tue: Array = TE.lineup("2026-11-17")["acts"]
	check(TE.act_time_text(tue[0]) == "19:30–21:00", "span text: " + TE.act_time_text(tue[0]))
	check(TE.act_time_text(tue[2]) == "23:45 – late", "till late text: " + TE.act_time_text(tue[2]))
	check(TE.act_kind_text(tue[1]) == "80s Rock", "genre line")
	var thu: Array = TE.lineup("2026-11-19")["acts"]
	check(TE.act_time_text(thu[0]) == "21:15", "start-only text")
	check(TE.act_kind_text(thu[0]) == "Opening set" and TE.act_kind_text(thu[1]) == "Cover set" and TE.act_kind_text(thu[2]) == "Closing set", "role lines")
	TranslationServer.set_locale("th")
	check(not TE.act_kind_text(thu[0]).contains("tonight.") and not TE.act_time_text(tue[2]).contains("tonight."), "Thai role and late text resolve")
	TranslationServer.set_locale("en")


## The HUD live chip's data (Daniele 2026-11-20: the live song line becomes the act on stage now).
func _stage() -> void:
	var cases := [
		[[2026, 11, 18, 22, 0], "on", "Mut Matthew", true, "Wed 22:00 on stage"],
		[[2026, 11, 18, 21, 5], "next", "Mut Matthew", true, "Wed 21:05 between sets: next up"],
		[[2026, 11, 18, 15, 0], "next", "Aomsin", true, "Wed 15:00 (doors later): the first act tonight"],
		[[2026, 11, 19, 1, 30], "on", "Far x Jayson Creer", true, "Thu 01:30: Wednesday's till-late set"],
		[[2026, 11, 22, 23, 50], "on", "Motherfunky ft. Jayson Creer x JayJay x Nene x Tarr", true, "Sun 23:50: the Cabin Jam"],
		[[2026, 11, 23, 21, 0], "none", "", false, "Mon 23 closed, week of 23 Nov not in: no act"],
		[[2026, 11, 16, 21, 0], "next", "Earn", false, "Mon 16 (closed in the game): next is Tue 17 Earn"],
		[[2026, 11, 15, 21, 0], "next", "Earn", false, "Sun 15 (no lineup file): searches ahead, skips Mon 16"],
		[[2026, 11, 24, 21, 0], "none", "", false, "Tue 24, no data ahead: none"],
	]
	for c in cases:
		var st := TE.stage_now(_u(c[0]))
		var nm := str(st["act"].get("name", ""))
		check(st["kind"] == c[1] and nm == c[2] and bool(st["tonight"]) == c[3], "%s: got %s %s %s" % [c[4], st["kind"], nm, st["tonight"]])
	var on := TE.stage_now(_u([2026, 11, 18, 22, 15]))
	check(TE.stage_line(on) == "On stage: Mut Matthew  ·  R&B Soul Pop", "on line: " + TE.stage_line(on))
	check(TE.stage_sub(on) == "21:15–23:15 · 60 min left", "on sub: " + TE.stage_sub(on))
	check(absf(on["progress"] - 0.5) < 0.01, "progress halfway: %s" % on["progress"])
	check(TE.stage_line(TE.stage_now(_u([2026, 11, 18, 21, 5]))) == "Next: Mut Matthew at 21:15", "next line")
	check(TE.stage_line(TE.stage_now(_u([2026, 11, 16, 21, 0]))) == "Next: Earn · Tue 19:30", "next-day line")
	check(TE.stage_line(TE.stage_now(_u([2026, 11, 23, 21, 0]))) == "Doors Tue 19:00", "closed, nothing ahead: next opening")
	check(TE.stage_line(TE.stage_now(_u([2026, 11, 24, 21, 0]))) == "Live music from 19:00", "open, no data: generic line")
	check(TE.stage_sub(TE.stage_now(_u([2026, 11, 18, 23, 50]))) == "23:45 – late", "till late sub has no countdown")
	TranslationServer.set_locale("th")
	for at in [[2026, 11, 18, 22, 15], [2026, 11, 16, 21, 0], [2026, 11, 23, 21, 0], [2026, 11, 24, 21, 0]]:
		var st := TE.stage_now(_u(at))
		check(not (TE.stage_line(st) + TE.stage_sub(st)).contains("tonight.") and not TE.stage_line(st).contains("{"), "Thai stage line resolves %s" % [at])
	TranslationServer.set_locale("en")


## The chip itself (scripts/ui/stage_chip.gd) and the HUD using it in place of the song caption.
func _stage_chip() -> void:
	var Chip = load("res://scripts/ui/stage_chip.gd")
	var c: Control = Chip.new()
	root.add_child(c)
	c.refresh(_u([2026, 11, 18, 22, 15]))
	await process_frame
	c.refresh(_u([2026, 11, 18, 22, 15]))
	check(c.name == "Live" and c.photo.visible and c.photo.texture != null, "chip on stage: photo shown")
	check(c.line.text.contains("Mut Matthew") and c.sub.visible, "chip on stage: name and set line")
	var bar: Control = c.find_child("Progress", true, false)
	check(bar != null and bar.size.x > 0.0, "chip on stage: progress bar drawn %s" % [bar.size if bar else null])
	c.refresh(_u([2026, 11, 18, 21, 5]))
	check(not c.photo.visible and not c.sub.visible and c.line.text == "Next: Mut Matthew at 21:15", "chip between sets: next-up line only")
	c.queue_free()
	var needs: Node = root.get_node_or_null("Needs")
	if needs == null:
		check(false, "Needs autoload")
		return
	needs.autosave = false
	needs.new_game()
	TE.now_override = _u([2026, 11, 20, 23, 30])
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	await create_timer(0.4).timeout
	var live: Control = main.get_node("UI/Hud").find_child("Live", true, false)
	check(live != null and live.is_visible_in_tree(), "HUD shows the live chip")
	if live != null:
		check(live.line.text.contains("Run Baby Run") and not live.line.text.contains("song"), "HUD chip names the act on stage, not a song: " + live.line.text)
		check(root.get_visible_rect().encloses(live.get_global_rect()), "HUD chip on screen")
	main.queue_free()
	TE.now_override = -1
	await process_frame


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


func _inside(s: Node, tag: String) -> void:
	var panel: Control = s.find_child("TonightSheet", true, false)
	var vp := root.get_visible_rect()
	check(panel != null and vp.grow(1.0).encloses(panel.get_global_rect()), tag + ": sheet inside the screen")


func _open(at: Array) -> Node:
	var s := Sheet.new()
	root.add_child(s)
	s.open(_u(at))
	return s


func _tonight_tab() -> void:
	for loc in ["en", "th"]:
		TranslationServer.set_locale(loc)
		for size in [Vector2i(1080, 1920), Vector2i(1920, 1080)]:
			root.size = size
			var tag := "tonight %s %s" % [loc, size]
			var s := _open([2026, 11, 18, 22, 0])
			for i in 3:
				await process_frame
			check(s.mode == "tonight", tag + ": opens on the Tonight tab")
			check(s.act_cards.size() == 3, tag + ": 3 act cards")
			var lit: Array = []
			for i in s.act_cards.size():
				if s.act_cards[i].find_child("NowOnStage", true, false) != null:
					lit.append(i)
			check(lit == [1], tag + ": only Mut Matthew is lit as now on stage: %s" % [lit])
			check(s.act_cards[0].find_child("Pic", true, false) != null, tag + ": act card has its photo")
			check(s.act_cards[0].find_child("ActDesc", true, false) != null, tag + ": act card has the description")
			check(s.find_child("LineupHead", true, false) != null, tag + ": Who's playing tonight header")
			for c in s.act_cards:
				var pr: Rect2 = s.find_child("TonightSheet", true, false).get_global_rect()
				var cr: Rect2 = c.get_global_rect()
				check(cr.size.x > 100 and cr.position.x >= pr.position.x - 1 and cr.end.x <= pr.end.x + 1, tag + ": card fits the sheet's width %s in %s" % [cr, pr])
			_inside(s, tag)
			_no_raw_keys(s, tag)
			s.queue_free()
			await process_frame
	TranslationServer.set_locale("en")
	root.size = Vector2i(1080, 1920)
	# special night: John Mayer, no photos -> neon initials
	var j := _open([2026, 11, 19, 23, 0])
	await process_frame
	check(j.tonight_card.find_child("EventTitle", true, false) != null and j.tonight_card.find_child("EventTitle", true, false).text == "John Mayer Night", "Thu 19: John Mayer Night card")
	check(j.act_cards.size() == 3 and j.act_cards[0].find_child("Initial", true, false) != null, "Thu 19: program cards with initials (no poster photos)")
	check(j.act_cards[1].find_child("NowOnStage", true, false) != null, "Thu 19 23:00: the cover set is on")
	_no_raw_keys(j, "special night")
	j.queue_free()
	# closed Monday: no lineup section even though the poster lists Monday
	var m := _open([2026, 11, 23, 21, 0])
	await process_frame
	check(m.act_cards.is_empty() and m.find_child("LineupHead", true, false) == null, "Mon 23: closed, no act cards")
	m.queue_free()
	# week without data
	var e := _open([2026, 11, 24, 21, 0])
	await process_frame
	check(e.act_cards.is_empty() and e.find_child("LineupMissing", true, false) != null, "Tue 24: lineup not in yet, said so")
	_no_raw_keys(e, "empty week")
	e.queue_free()
	await process_frame


func _calendar_tab() -> void:
	for loc in ["en", "th"]:
		TranslationServer.set_locale(loc)
		for size in [Vector2i(1080, 1920), Vector2i(1920, 1080)]:
			root.size = size
			var tag := "calendar %s %s" % [loc, size]
			var s := _open([2026, 11, 20, 21, 30])
			await process_frame
			(s.find_child("Tab_calendar", true, false) as Button).pressed.emit()
			for i in 3:
				await process_frame
			check(s.mode == "calendar" and s.cal_month == "2026-11", tag + ": calendar on November")
			check(s.cal_cells.size() == 30, tag + ": 30 day cells (got %d)" % s.cal_cells.size())
			check(s.cal_selected == "2026-11-20", tag + ": tonight preselected")
			var acts: Array = s.day_panel.find_children("DayAct_*", "", true, false)
			check(acts.size() == 3, tag + ": tonight's 3 acts under the grid")
			check(s.day_panel.get_child(0).name == "DayHead", tag + ": day head first")
			# grid starts on Monday: 1 Nov 2026 is a Sunday -> 6 blanks after the 7 weekday labels
			var grid: GridContainer = s.find_child("Grid", true, false)
			check(grid.get_child(7 + 6) == s.cal_cells["2026-11-01"], tag + ": 1 Nov (Sunday) in the last column")
			var c19: Button = s.cal_cells["2026-11-19"]
			check(c19.get_global_rect().size.x >= 30 and c19.get_global_rect().size.y >= 30, tag + ": day cell is tappable size %s" % [c19.get_global_rect().size])
			s.select_day("2026-11-19")
			await process_frame
			check(s.day_panel.find_child("DayEvent", true, false) != null, tag + ": 19 Nov shows John Mayer Night")
			check(s.day_panel.find_children("DayAct_*", "", true, false).size() == 3, tag + ": and its program")
			s.select_day("2026-11-16")
			await process_frame
			check(s.day_panel.find_children("DayAct_*", "", true, false).size() == 3, tag + ": Mon 16: the poster's Monday acts")
			s.select_day("2026-11-23")
			await process_frame
			check(s.day_panel.find_child("DayNothing", true, false) != null, tag + ": Mon 23: nothing listed")
			s.select_day("2026-11-09")
			await process_frame
			check(s.day_panel.find_child("DayEvent", true, false) != null, tag + ": Mon 9: the guest shift from the month poster")
			_inside(s, tag)
			_no_raw_keys(s, tag)
			(s.find_child("NextMonth", true, false) as Button).pressed.emit()
			await process_frame
			check(s.cal_month == "2026-12" and s.find_child("CalMissing", true, false) != null, tag + ": December not in yet, said so")
			check(s.cal_cells.size() == 31, tag + ": 31 cells in December")
			(s.find_child("PrevMonth", true, false) as Button).pressed.emit()
			await process_frame
			(s.find_child("PrevMonth", true, false) as Button).pressed.emit()
			await process_frame
			check(s.cal_month == "2026-10" and s.find_child("CalMissing", true, false) == null, tag + ": back to October (in)")
			_no_raw_keys(s, tag + " october")
			(s.find_child("Tab_tonight", true, false) as Button).pressed.emit()
			await process_frame
			check(s.mode == "tonight" and s.act_cards.size() == 3, tag + ": back to the Tonight tab")
			s.queue_free()
			await process_frame
	TranslationServer.set_locale("en")
	root.size = Vector2i(1080, 1920)
	check(Sheet._shift_month("2026-01", -1) == "2025-12" and Sheet._shift_month("2026-12", 1) == "2027-01", "month shift rolls years")
	check(Sheet._days_in_month(2028, 2) == 29 and Sheet._days_in_month(2026, 2) == 28, "days in month (leap year)")
