extends SceneTree
## Overflow seating (Daniele 2026-11-20: "optional seating appearing only when you pass the 4 people";
## scripts/presence_ui/overflow_seats.gd, venue_patrons.gd _table_overflow / _settle), against "Fake presences" with
## the viewer checked in tonight (so real tables reach this phone, 08 §6.2):
##   slots    every QR table with chairs has its extra seats computed; each one clears the other tables' tap zones,
##            every seat spot, the room's colliders, and stays near its own table; round tables get 4 more (8)
##   table3   9 check-ins at Table3: its 4 chairs (anonymous patrons get up for them), 4 extra chairs that appear
##            with them, 1 standing; nobody overlaps; all 9 at Table3
##   bar      12 at the Bar: 9 stools + 3 extra stools on the stool row, along the counter
##   tall     6 at BufferTall1: its 2 tall stools, extra tall stools, the rest standing on the floor with a drink
##   entry    a viewer entering a bar already full at Table3 (the list answers at once): same seating, no walk
##   leave    someone on a table chair leaves: the last extra-seat person moves onto it and that extra chair goes;
##            everyone leaves: no extra chair is left
##   p3       a viewer not checked in: no real table, never an extra chair (zone seating as before)
##   godot --headless --path . --script res://tests/test_overflow_seats.gd

const PresenceClient = preload("res://scripts/presence_ui/presence_client.gd")
const OverflowSeats = preload("res://scripts/presence_ui/overflow_seats.gd")
const Avatar = preload("res://scripts/avatar.gd")

var needs: Node
var fake: Variant
var fails: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _init() -> void:
	await process_frame
	needs = root.get_node_or_null("Needs")
	needs.autosave = false
	needs.new_game()
	needs.set_avatar(Avatar.default_record(), "Dan", "")
	PresenceClient.reset()
	fake = PresenceClient.use_fake()
	fake.people.clear()
	needs.checkin_nights.append(needs.night_key(needs.clock))

	print("slots")
	var main := await _main()
	var pat: Node = main.get_node("Venue/Patrons")
	check(pat.overflow_at("Table3").is_empty(), "no extra chair before anyone checks in")
	pat._table_overflow("__probe__")
	var ov: OverflowSeats = pat._overflow
	var spots: Array[Node3D] = []
	for s in pat.get_node("Spots").get_children():
		if s.get_meta("pose", "") == "sit":
			spots.append(s)
	var bad_zone := 0
	var bad_spot := 0
	var far := 0
	var total := 0
	var tables := ["Table0", "Table1", "Table2", "Table3", "Table4", "WestTable0", "WestTable1", "RectTableW",
		"RectTableE", "EastTable", "OpeningTall0", "OpeningTall1", "LongTable", "BufferTall0", "BufferTall1",
		"BufferTall2", "BufferTall3", "Bar",
		# QR remake 2026-11-20: the small and raised tables have codes too
		"Tiny0", "Tiny1", "Tiny2", "Tiny3", "Tiny4", "Tiny5", "TinyE0", "TinyE1", "TinyE2",
		"Raised0", "Raised1", "Raised2", "Raised3", "Raised4"]
	for t in tables:
		var sl: Dictionary = ov.slots(t)
		check(not sl.is_empty(), "%s: slots computed" % t)
		for kind in ["seats", "stand"]:
			for slot: Dictionary in sl.get(kind, []):
				total += 1
				var p: Vector3 = slot.pos
				for z in ov._zones:
					if z != t and Vector2(p.x, p.z).distance_to(ov._zones[z][0]) < float(ov._zones[z][1]):
						bad_zone += 1
				for s in spots:
					if _flat(s.global_position - p) < 0.44:
						bad_spot += 1
				var near := INF
				for s in spots:
					if str(s.get_meta("table", "")) == t:
						near = minf(near, _flat(s.global_position - p))
				if near > 1.6:
					far += 1
				if not ov._clear(t, p, 0.0, kind == "stand"):
					bad_spot += 1
	check(total > 100, "%d extra seats and standing spots over %d tables" % [total, tables.size()])
	check(bad_zone == 0, "none inside another table's tap zone (seats' reach + SEAT_MARGIN)")
	check(bad_spot == 0, "none on a seat spot, a wall or a piece of furniture")
	check(far == 0, "each one by its own table (within 1.6 m of one of its chairs)")
	for t in ["Table0", "Table1", "Table2", "Table3", "Table4", "EastTable", "WestTable0", "WestTable1"]:
		check(ov.slots(t)["seats"].size() == OverflowSeats.SEAT_CAP - 4, "%s: 4 chairs + %d extra = cap %d" % [t, OverflowSeats.SEAT_CAP - 4, OverflowSeats.SEAT_CAP])
	check(ov.slots("Bar")["seats"].size() == OverflowSeats.BAR_CAP - 9, "Bar: 9 stools + %d along the counter" % (OverflowSeats.BAR_CAP - 9))

	print("table3")
	var anon_before := _anon_at(pat, "Table3")
	var ids3 := []
	for i in 9:
		ids3.append(fake.arrive("T3_%d" % i, "Table3", 30 + i)["player_id"])
	pat.poll_presence()
	await _settle_walks(pat)
	var at3 := _at(pat, "Table3")
	check(at3["base"] == 4 and at3["seat"] == 4 and at3["stand"] == 1, "9 at Table3: 4 own chairs, 4 extra chairs, 1 standing (%s)" % str(at3))
	check(_anon_at(pat, "Table3") == 0, "no anonymous patron left at Table3 (%d there before got up for them)" % anon_before)
	var chairs := 0
	for m in pat.overflow_at("Table3"):
		if m.get_node_or_null("Chair") != null:
			chairs += 1
	check(chairs == 4, "4 extra chairs in the room (%d)" % chairs)
	check(_overlaps(pat) == 0, "no two people on the same spot (%d)" % _overlaps(pat))
	var everyone_there := true
	for id in ids3:
		var f: PatronFigure = pat.presence_figure(id)
		if f == null or str(f.get_meta("seat").get_meta("table", "")) != "Table3":
			everyone_there = false
	check(everyone_there, "all 9 are at Table3")
	var sitting := 0
	for id in ids3:
		var f: PatronFigure = pat.presence_figure(id)
		var seat: Node3D = f.get_meta("seat")
		if f.state == "sit" and f.position.distance_to(seat.position) < 0.6:
			sitting += 1
	check(sitting == 9, "each on its spot (%d)" % sitting)

	print("bar")
	for i in 12:
		fake.arrive("Bar_%d" % i, "Bar", 60 + i)
	pat.poll_presence()
	await _settle_walks(pat)
	var atb := _at(pat, "Bar")
	check(atb["base"] == 9 and atb["seat"] == 3 and atb["stand"] == 0, "12 at the Bar: 9 stools + 3 extra stools (%s)" % str(atb))
	var on_row := 0
	for m in pat.overflow_at("Bar"):
		if absf(m.global_position.z - 12.2) < 0.05 and m.global_position.x > 23.0 and m.global_position.x < 35.75:
			on_row += 1
	check(on_row == 3, "on the stool row, along the counter")

	print("tall")
	for i in 6:
		fake.arrive("Tall_%d" % i, "BufferTall1", 90 + i)
	pat.poll_presence()
	await _settle_walks(pat)
	var att := _at(pat, "BufferTall1")
	var nseat: int = ov.slots("BufferTall1")["seats"].size()
	check(att["base"] == 2 and att["seat"] == nseat and att["stand"] == 4 - nseat and nseat >= 1, "6 at BufferTall1: 2 stools, %d extra tall stools, %d standing (%s)" % [nseat, 4 - nseat, str(att)])
	var standing_ok := 0
	var stands := 0
	for id in pat.presences:
		var f: PatronFigure = pat.presences[id]
		var seat: Node3D = f.get_meta("seat")
		if seat.get_meta("stand", false):
			stands += 1
			if f.look["anims"]["sit"] == "stand_drink" and absf(f.position.y - seat.position.y) < 0.01 and seat.get_node_or_null("Chair") == null:
				standing_ok += 1
	check(stands > 0 and standing_ok == stands, "standing ones on the floor with a drink, no chair (%d/%d)" % [standing_ok, stands])
	check(_overlaps(pat) == 0, "still nobody overlapping")

	print("leave")
	var base_one := ""
	for id in ids3:
		if not pat.presence_figure(id).get_meta("seat").has_meta("overflow"):
			base_one = id
			break
	var stand_one := ""
	for id in ids3:
		if pat.presence_figure(id).get_meta("seat").get_meta("stand", false):
			stand_one = id
	fake.hide(base_one)
	pat.poll_presence()
	var after := _at(pat, "Table3")
	check(after["base"] == 4 and after["seat"] == 4 and after["stand"] == 0, "one on a table chair left: the standing one sits, 4 + 4 (%s)" % str(after))
	fake.hide(ids3[8] if ids3[8] != base_one else ids3[7])
	pat.poll_presence()
	var after2 := _at(pat, "Table3")
	check(after2["base"] + after2["seat"] == 7 and after2["base"] == 4 and after2["seat"] == 3, "another left: 4 + 3, one extra chair gone (%s)" % str(after2))
	check(stand_one == "" or pat.presence_figure(stand_one) == null or pat.presence_figure(stand_one).state == "sit", "the one who stood is sitting now")
	for id in ids3:
		fake.hide(id)
	pat.poll_presence()
	await create_timer(0.8).timeout   # the chairs shrink away in 0.35 s
	await _frames(2)
	check(pat.overflow_at("Table3").is_empty(), "everyone left Table3: no extra chair left")
	var left_nodes := 0
	for c in pat.get_children():
		if String(c.name).begins_with("Overflow_Table3") and not c.is_queued_for_deletion():
			left_nodes += 1
	check(left_nodes == 0, "their chairs are gone from the scene (%d)" % left_nodes)
	await _free(main)

	print("entry")
	fake.people.clear()
	fake.hidden.clear()
	for i in 9:
		fake.arrive("E3_%d" % i, "Table3", 130 + i)
	main = await _main()
	pat = main.get_node("Venue/Patrons")
	var ate := _at(pat, "Table3")
	check(ate["base"] == 4 and ate["seat"] == 4 and ate["stand"] == 1, "entering a bar with 9 at Table3: 4 + 4 + 1 standing (%s)" % str(ate))
	check(pat.arrivals_walking() == 0, "already seated, nobody walking in")
	check(_overlaps(pat) == 0, "nobody overlapping")
	await _free(main)

	print("p3")
	needs.checkin_nights.clear()
	main = await _main()
	pat = main.get_node("Venue/Patrons")
	var any_overflow := 0
	for c in pat.get_children():
		if String(c.name).begins_with("Overflow_"):
			any_overflow += 1
	check(pat.presences.size() == 9 and any_overflow == 0, "viewer not checked in: 9 seated by zone, no extra chair (%d)" % any_overflow)
	# hotfix 3 (Daniele 11-20 "we not all at the same table"): the venue was up before the check-in answered; the
	# next list carries the table and everyone already seated moves to it
	needs.checkin_nights.append(needs.night_key(needs.clock))
	pat.poll_presence()
	await _settle_walks(pat)
	var moved := _at(pat, "Table3")
	check(moved["base"] == 4 and moved["seat"] == 4 and moved["stand"] == 1,
		"after the check-in the 9 already seated move to Table3: 4 + 4 + 1 standing (%s)" % str(moved))
	check(_overlaps(pat) == 0, "nobody overlapping after the move")
	print("inbox")
	var who: String = pat.presences.keys()[0]
	pat._on_inbox([{"id": 901, "kind": "wave", "payload": {}, "from": {"player_id": who, "display_name": "Jack"}}])
	var banner: Node = pat.get_node_or_null("PresenceBanner")
	var btext := ""
	if banner != null:
		btext = (banner.find_child("Text", true, false) as Label).text
	check(btext.contains("Jack"), "a received wave shows a banner naming the sender (%s)" % btext)
	pat._on_inbox([{"id": 901, "kind": "wave", "payload": {}, "from": {"player_id": who, "display_name": "Jack"}}])
	check(pat.get_children().filter(func(c): return String(c.name).begins_with("PresenceBanner")).size() == 1,
		"the same verb is announced once")
	print("still")
	var prompt: Control = pat.show_still_prompt()
	check(prompt != null and pat.show_still_prompt() == prompt, "Still at Black Cabin? prompt: one at a time")
	(prompt.find_child("Yes", true, false) as Button).pressed.emit()
	await process_frame
	check(fake.still_answers.size() == 1 and pat.get_node_or_null("StillPrompt") == null, "Yes answers and closes it")
	var left := [false]
	pat.leave_requested.connect(func(): left[0] = true)
	prompt = pat.show_still_prompt()
	(prompt.find_child("Leave", true, false) as Button).pressed.emit()
	check(left[0], "Leave asks main to leave the bar")
	await _free(main)

	PresenceClient.reset()
	print("FAILS: %d" % fails.size())
	for f in fails:
		print("  - " + f)
	quit(1 if fails.size() > 0 else 0)


func _main() -> Node:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.intro = false
	root.add_child(m)
	await _frames(3)
	return m


func _free(m: Node) -> void:
	m.queue_free()
	await _frames(3)


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _settle_walks(pat: Node) -> void:
	Engine.time_scale = 8.0
	var t0 := Time.get_ticks_msec()
	while pat.arrivals_walking() > 0 and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	Engine.time_scale = 1.0
	await _frames(2)


## Presences at `table` by spot: {base, seat (extra chairs), stand}.
func _at(pat: Node, table: String) -> Dictionary:
	var out := {"base": 0, "seat": 0, "stand": 0}
	for id in pat.presences:
		var seat: Node3D = pat.presences[id].get_meta("seat")
		if str(seat.get_meta("table", "")) != table:
			continue
		if not seat.has_meta("overflow"):
			out["base"] += 1
		elif seat.get_meta("stand", false):
			out["stand"] += 1
		else:
			out["seat"] += 1
	return out


func _anon_at(pat: Node, table: String) -> int:
	var n := 0
	for s in pat.taken:
		var f: PatronFigure = pat.taken[s]
		if str(s.get_meta("table", "")) == table and not f.is_in_group("presence"):
			n += 1
	return n


## Seated or standing figures closer than 0.4 m to each other (walkers excluded).
func _overlaps(pat: Node) -> int:
	var pts: Array[Vector3] = []
	for s in pat.taken:
		pts.append(s.global_position)
	var n := 0
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			if _flat(pts[i] - pts[j]) < 0.4:
				n += 1
	return n


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
