extends SceneTree
## Headless test of the lounge revamp and its follow-up (Daniele 2026-11-02; BACKLOG B7, B9-B11; DECISIONS "Lounge
## revamp and corridor portraits" and "Lounge revamp answers"), from main.tscn:
##   layout    the merch counter top right, the game machine back by the stair foot (the bottom step faces it), the
##             memory corner alone top left, the Top patrons board under the second flight of the stairs, ten
##             portraits on the entrance corridor's south wall, the stair where Daniele confirmed it, nothing
##             overlapping the machine
##   sheets    merch (six in-game coin items with their coin prices, "coming soon"), Top patrons (ten names, rank
##             order, this month's check-ins), every portrait (its patron's name, the picture, a message written by
##             that patron); each opens as a real sheet
##   taps      a screen tap on the merch counter, on the board and on a portrait walks there and opens its sheet;
##             walking along the corridor passes every portrait's zone and shows its prompt
##   raised    every table of the raised strip (Raised3 too) opens its sheet from a tap in the main room; Raised3's chair
##             and both couch places are walked to and sat in from the main room, as the east rectangular table's
##             0.6 m move west opened a lane
##   curtain   the buffer's open curtains stand visible and on screen from the main-room side (and from the buffer)
##   camera    the lounge's merch, memory corner and patrons views take over in their corners, the rest keeps the
##             lounge view; the seven area buttons still walk to their area and open its sheet (Lounge -> pinball)
##   godot --headless --path . --script res://tests/test_lounge.gd

const Patrons = preload("res://scripts/zones/patrons.gd")
const T = preload("res://scripts/zones/venue_strings.gd")

var main: Node
var needs: Node
var p: Player
var s: VenueSession
var js: TouchJoystick
var venue: Node3D
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
	for m in needs.meters:
		needs.meters[m] = 50.0
	root.size = Vector2i(1080, 1920)   # portrait, as on the phone (a headless window is square: the landscape framing)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await physics_frame
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	await process_frame
	p = main.player
	s = main.session
	js = main.get_node("UI/Joystick")
	venue = main.get_node("Venue")
	for i in 20:
		await physics_frame

	print("layout")
	var cab: Node3D = venue.find_child("GameCabinet", true, false)
	var crt: Node3D = venue.find_child("CRT", true, false)
	var stair_foot := Vector3(8.05, 0.0, 12.25)   # build_venue STAIR_LOWER: the first flight's bottom step, at its east end
	check(cab != null and absf(cab.global_position.x - 10.3) < 0.05 and absf(cab.global_position.z - 12.65) < 0.05, "game machine back by the stair foot (%s)" % (cab.global_position if cab else "missing"))
	var cab_fwd: Vector3 = cab.global_transform.basis.z if cab else Vector3.ZERO
	check(cab != null and absf(cab_fwd.z + 1.0) < 0.05 and absf(cab.global_position.z - stair_foot.z) < 0.8 and cab.global_position.x - stair_foot.x > 1.0 and cab.global_position.x - stair_foot.x < 3.0,
		"the stair's bottom step faces the machine, which faces the room")
	check(cab != null and crt != null and cab.global_position.distance_to(crt.global_position) > 8.0, "the memory corner keeps only itself on the north wall: the machine is not there")
	var overlap := ""
	if cab != null:
		var mrect := Rect2(cab.global_position.x - 0.4, cab.global_position.z - 0.5, 0.8, 1.0)
		for n in ["HighCounter", "CounterStool0", "CounterStool1", "StairPlant", "LoungeTable1"]:
			var o: Node3D = venue.find_child(n, true, false)
			if o != null and mrect.grow(0.25).has_point(Vector2(o.global_position.x, o.global_position.z)):
				overlap += n + " "
		for n in ["HighCounter", "CounterStool0", "CounterStool1"]:
			var o: Node3D = venue.find_child(n, true, false)
			check(o != null and absf(o.global_position.z - 13.05) < 1.6 and o.global_position.x > cab.global_position.x + 0.6 and o.global_position.x < 13.0, "%s stands east of the machine, short of the Sticker door (%s)" % [n, o.global_position if o else "missing"])
	check(overlap == "", "nothing stands on or against the game machine (%s)" % overlap)
	var cz: Dictionary = main.zones.first_of("cabinet")
	check(not cz.is_empty() and Vector2(cz["approach"].x - 10.3, cz["approach"].z - 12.65).length() < 1.6, "the machine's zone sits at its new place")
	var stand: Node3D = venue.find_child("MerchStand", true, false)
	check(stand != null and stand.global_position.x > 11.0 and stand.global_position.z < 3.0, "merch counter top right (%s)" % (stand.global_position if stand else "missing"))
	var board: Node3D = venue.find_child("PatronsBoard", true, false)
	var up_rect := Rect2(2.35, 7.75, 1.6, 3.6)   # build_venue STAIR_UPPER: the second flight along the west wall
	check(board != null and absf(board.global_position.x - up_rect.end.x) < 0.2 and board.global_position.z > up_rect.position.y and board.global_position.z < up_rect.end.y and board.global_position.y + 1.0 < 1.6,
		"Top patrons board under the second flight, facing the room (%s)" % (board.global_position if board else "missing"))
	var frames := []
	for r in 10:
		var f: Node3D = venue.find_child("Portrait%d" % r, true, false)
		if f != null and f.global_position.z > 14.5 and f.global_position.x > 2.15 and f.global_position.x < 15.45 and f.find_child("Picture", true, false) != null:
			frames.append(r)
	check(frames.size() == 10, "ten framed portraits with pictures on the corridor's south wall (%d)" % frames.size())
	var stair: Node3D = venue.find_child("StairRunLower", true, false)
	check(stair != null and absf(stair.global_position.x - 6.05) < 0.05 and absf(stair.global_position.z - 12.25) < 0.05, "the stair's first flight where Daniele confirmed it")
	for id in ["merch", "patrons", "cabinet", "memory", "arcade"]:
		check(not main.zones.by_id(id).is_empty() or not main.zones.first_of(id).is_empty(), "zone %s built" % id)
	for r in 10:
		check(main.zones.by_id("portrait:%d" % r).get("rank", -1) == r, "zone portrait:%d built" % r)

	print("sheets")
	var mz: Dictionary = main.zones.by_id("merch")
	var mrows := s.rows_for(mz)
	check(mrows.size() == VenueSession.MERCH_ITEMS.size() and mrows.size() == 6, "merch lists six items (%d)" % mrows.size())
	var prices := VenueSession.MERCH_ITEMS.map(func(i): return i["price"])
	check(prices == [30, 30, 30, 60, 80, 120], "merch prices are the wardrobe tiers of 04-coins.md (%s)" % [prices])
	var merch_ok := true
	for i in mrows.size():
		var r: Dictionary = mrows[i]
		merch_ok = merch_ok and not r["enabled"] and r["reason"] == T.t("venue.sheet.merch.tbc", {"price": prices[i]}) and r["reason"].contains(str(prices[i])) and r["reason"].contains("coins") \
			and r["title"] != "" and not r["title"].begins_with("venue.") and not r["reason"].contains("{")
	check(merch_ok, "every merch item shows its coin price and 'coming soon', not for sale yet")
	var greet: String = s.header_for(mz)[1]
	check(s.header_for(mz)[0] == T.t("venue.sheet.merch.head") and greet.contains("character") and greet.contains("coins") and not greet.to_lower().contains("price to be confirmed"), "merch sheet: cosmetic merch for the character, bought with coins (%s)" % greet)
	await open_and_check(mz, func(sh): return sh.buttons.size() == 6, "merch sheet opens with its six rows")
	var pz: Dictionary = main.zones.by_id("patrons")
	var prows := s.rows_for(pz)
	var names_ok := prows.size() == 10
	for r in mini(prows.size(), 10):
		names_ok = names_ok and prows[r]["info"] and prows[r]["title"].contains(Patrons.at(r)["name"]) and prows[r]["title"].begins_with("%d." % (r + 1))
	check(names_ok, "Top patrons lists the ten placeholder names in rank order")
	check(Patrons.count() == 10 and Patrons.at(0)["checkins"] >= Patrons.at(9)["checkins"], "placeholder ranking: rank 1 has the most check-ins")
	var pgreet: String = s.header_for(pz)[1]
	check(pgreet.contains("This month") and pgreet.contains("check-ins at the bar") and pgreet.contains("placeholder"), "Top patrons sheet: this month's check-ins at the bar, names and counts placeholders (%s)" % pgreet)
	check(prows.all(func(r): return r["sub"].contains("this month") and r["sub"].contains("check-ins")), "each Top patrons line counts check-ins this month")
	await open_and_check(pz, func(sh): return sh.find_children("Info_*", "", true, false).size() == 10 and sh.find_child("Scroll", true, false) != null, "Top patrons sheet opens: ten lines in a scroll list")
	for r in 10:
		var z: Dictionary = main.zones.by_id("portrait:%d" % r)
		var nm: String = Patrons.at(r)["name"]
		var head := s.header_for(z)
		var rows := s.rows_for(z)
		var msg: String = rows[0]["sub"] if rows.size() == 1 else ""
		check(head[0].contains(nm) and head[0].contains(str(r + 1)) and s.image_for(z) != null and rows.size() == 1 and msg.contains(nm) and not msg.contains("{"),
			"portrait %d: %s, the picture and a message written by the patron" % [r, nm])
		check(rows.size() == 1 and rows[0]["title"] == T.t("venue.sheet.portrait.from", {"name": nm}) and rows[0]["title"].contains(nm) and not rows[0]["title"].to_lower().contains("owner") and not msg.to_lower().contains("owner"),
			"portrait %d: titled as a message from %s, not from the bar's owner" % [r, nm])
		await open_and_check(z, func(sh): return sh.find_child("Picture", true, false) != null and sh.find_child("Info_message", true, false) != null, "portrait %d sheet opens with the picture" % r)

	print("taps")
	await tap_object("merch", Vector3(11.4, 0.1, 3.2), stand.global_position + Vector3(0, 0.95, 0.1) if stand else Vector3.ZERO)
	await tap_object("patrons", Vector3(7.0, 0.1, 9.0), board.global_position + Vector3(0.1, 0.5, 0) if board else Vector3.ZERO)
	var f3: Node3D = venue.find_child("Portrait3", true, false)
	await tap_object("portrait:3", Vector3(2.0, 0.1, 14.0), f3.global_position + Vector3(0, 0.4, -0.05) if f3 else Vector3.ZERO)
	# Walking the corridor from the lobby to the Sticker door passes every portrait, each with its prompt
	teleport(Vector3(1.6, 0.1, 14.1))
	await physics_frame
	var seen := {}
	var prompt_ok := true
	for i in 900:
		var d := Vector3(14.6, 0, 14.1) - p.global_position
		d.y = 0
		if d.length() < 0.25:
			break
		js.value = p.world_to_input(d.normalized())
		await physics_frame
		var cid: String = main.zones.current.get("id", "")
		if cid.begins_with("portrait:") and not seen.has(cid):
			seen[cid] = true
			await process_frame
			prompt_ok = prompt_ok and main.hud.prompt.is_showing() and s.prompt_for(main.zones.current) == T.t("venue.prompt.portrait")
	js.value = Vector2.ZERO
	check(seen.size() == 10, "walking the corridor passes all ten portraits (%d: %s)" % [seen.size(), seen.keys()])
	check(prompt_ok, "each portrait shows its prompt as the player passes")

	print("raised strip")
	for i in 5:
		var id := "table:Raised%d" % i
		var t: Node3D = venue.find_child("Raised%d" % i, true, false)
		await tap_object(id, Vector3(30.0, 0.1, 7.0), t.global_position + Vector3(0, 0.75, 0) if t else Vector3.ZERO)

	# Raised3 (Daniele 2026-11-02): the east rectangular table moved 0.6 m west, so its chair and both couch places can be
	# walked to and sat in from the main room, and the rectangular table's own four seats still work
	var rect_e: Node3D = venue.find_child("RectTableE", true, false)
	var r3: Node3D = venue.find_child("Raised3", true, false)
	var diamond: Node3D = venue.find_child("EastTable", true, false)
	check(rect_e != null and absf(rect_e.global_position.x - 37.6) < 0.05 and r3 != null and rect_e.global_position.x < r3.global_position.x - 2.5, "the east rectangular table stands 0.6 m west (%s)" % (rect_e.global_position if rect_e else "missing"))
	check(diamond != null and absf(diamond.global_position.x - 37.6) < 0.05, "the east diamond table, whose chairs sealed the strip's north lane, moved with it (%s)" % (diamond.global_position if diamond else "missing"))
	var r3_seats := get_nodes_in_group("seat").filter(func(n): return n.get_meta("table", "") == "Raised3")
	check(r3_seats.size() == 3, "Raised3 has its chair and two couch places (%d)" % r3_seats.size())
	for seat_node in r3_seats:
		var pose := "sit_hold" if seat_node.get_meta("couch", false) else "sit_drink"
		var want := {"node": seat_node, "pos": seat_node.global_position, "yaw": seat_node.global_rotation.y, "h": float(seat_node.get_meta("seat_h")),
			"couch": seat_node.get_meta("couch", false), "table": "Raised3", "pose": pose}
		teleport(Vector3(36.0, 0.1, 6.5))
		main.pending_zone = ""
		await frames_n(10)
		p.sit_at(want)
		for i in 1500:
			await physics_frame
			if p.seated:
				break
		check(p.seated and p.global_position.distance_to(want["pos"]) < 0.05 and absf(angle_difference(p.facing(), float(want["yaw"]))) < 0.05,
			"from the main room the player walks to Raised3 %s and sits facing the table (seated %s, %.2f m off)" % [seat_node.name, p.seated, p.global_position.distance_to(want["pos"])])
		p.stand_up()
	# By tap and the sheet's Sit row: the nearest free place
	teleport(Vector3(33.5, 0.1, 6.5))
	main.pending_zone = ""
	await frames_n(30)
	p.tap_at(p.rig.camera.unproject_position(r3.global_position + Vector3(0, 0.75, 0)))
	for i in 2400:
		await physics_frame
		if is_instance_valid(main.sheet):
			break
	var sit_ok: bool = is_instance_valid(main.sheet) and main.session.do_row(main.sheet_zone, "sit")
	main.close_sheet()
	for i in 1500:
		await physics_frame
		if p.seated:
			break
	check(sit_ok and p.seated and str(p.seat.get("table", "")) == "Raised3", "tap Raised3, press Sit: seated at Raised3 (seat %s)" % [p.seat.get("node", null)])
	p.stand_up()
	for sname in ["Tables_RectTableE_W0", "Tables_RectTableE_W1", "Tables_RectTableE_E0", "Tables_RectTableE_E1"]:
		var sn: Node3D = null
		for n in get_nodes_in_group("seat"):
			if n.name == sname:
				sn = n
		var seated_ok := false
		if sn != null:
			teleport(Vector3(34.5, 0.1, 8.0))
			main.pending_zone = ""
			await frames_n(5)
			p.sit_at({"node": sn, "pos": sn.global_position, "yaw": sn.global_rotation.y, "h": 0.45, "couch": false, "table": "RectTableE", "pose": "sit_drink"})
			for k in 1500:
				await physics_frame
				if p.seated:
					break
			seated_ok = p.seated and p.global_position.distance_to(sn.global_position) < 0.05
			p.stand_up()
		check(seated_ok, "the east rectangular table's seat %s still works" % sname)

	print("curtain")
	var curtains := get_nodes_in_group("cutaway").filter(func(n): return str(n.name).begins_with("Curtain_"))
	check(curtains.size() == 4 and curtains.all(func(c): return c.get_meta("cut_sight_only", false)), "the buffer's four curtain panels hide only on the sight line")
	var main_side := curtains.filter(func(c): return c.global_position.x > 19.0)
	for at in [Vector3(21.6, 0.1, 5.3), Vector3(22.4, 0.1, 6.2), Vector3(21.4, 0.1, 4.2)]:
		teleport(at)
		await frames_n(30)
		var shown := main_side.filter(func(c): return c.is_visible_in_tree() and on_screen(c.global_position + Vector3(0, 1.6, 0)))
		check(p.rig.zone == "floor" and shown.size() == 2, "from the main room at %s both main-side curtains stand in view (%d)" % [at, shown.size()])
	teleport(Vector3(18.0, 0.1, 5.3))
	await frames_n(30)
	check(curtains.filter(func(c): return c.is_visible_in_tree()).size() == 4, "from the buffer all four curtains stand")

	print("camera")
	for v in [["merch", Vector3(13.4, 0.1, 2.6), 0.0], ["memory", Vector3(6.4, 0.1, 1.9), 0.0], ["patrons", Vector3(4.85, 0.1, 9.1), 130.0], ["lounge", Vector3(8.0, 0.1, 6.5), 90.0]]:
		teleport(v[1])
		await frames_n(60)
		check(p.rig.view == v[0] and absf(rad_to_deg(angle_difference(p.rig.yaw, deg_to_rad(v[2])))) < 3.0 and on_screen(p.global_position + Vector3(0, 1.0, 0)),
			"%s: its own view (view %s, yaw %.0f), player on screen" % [v[0], p.rig.view, rad_to_deg(p.rig.yaw)])
	# Walking from the middle of the lounge into the merch corner turns the view there (dwell, same room)
	teleport(Vector3(9.6, 0.1, 3.0))
	await frames_n(20)
	await walk(Vector3(13.0, 0, 2.7), 400)
	await frames_n(40)
	check(p.rig.view == "merch", "walking into the merch corner from the lounge turns to the merch view (%s)" % p.rig.view)
	for a in main.hud.AREAS:
		var area: String = a[0]
		main.close_sheet()
		await process_frame
		teleport(Vector3(30.0, 0.1, 7.0) if area != "floor" else Vector3(36.0, 0.1, 6.0))
		main.pending_zone = ""
		await frames_n(5)
		main.walk_to_area(area)
		for i in 2400:
			await physics_frame
			if is_instance_valid(main.sheet) or (not p.walking_to and main.pending_zone == ""):
				break
		await process_frame
		var z: Dictionary = main.sheet_zone if is_instance_valid(main.sheet) else {}
		var want: String = a[2]
		check(is_instance_valid(main.sheet) and (z.get("id", "") == want or z.get("kind", "") == want) and main.player.rig.area_at(p.global_position) == area,
			"area button %s walks there and opens %s (%s)" % [area, want, z.get("id", "none")])
	main.close_sheet()
	await process_frame
	# The Lounge button from inside the lounge (from the merch corner) still walks to the pinball
	teleport(Vector3(13.4, 0.1, 2.6))
	main.pending_zone = ""
	await frames_n(5)
	main.walk_to_area("lounge")
	for i in 1800:
		await physics_frame
		if is_instance_valid(main.sheet) or (not p.walking_to and main.pending_zone == ""):
			break
	check(is_instance_valid(main.sheet) and main.sheet_zone.get("kind", "") == "arcade", "Lounge button from the merch corner opens the pinball")
	main.close_sheet()

	print("TEST LOUNGE ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


func teleport(pos: Vector3) -> void:
	p.stand_up()
	p.walking_to = false
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rig.snap()


func frames_n(n: int) -> void:
	for i in n:
		await process_frame


func walk(goal: Vector3, n: int) -> void:
	for i in n:
		var d: Vector3 = goal - p.global_position
		d.y = 0
		if d.length() < 0.2:
			break
		js.value = p.world_to_input(d.normalized())
		await physics_frame
	js.value = Vector2.ZERO
	await physics_frame


func on_screen(w: Vector3) -> bool:
	var cam: Camera3D = p.rig.camera
	if cam.is_position_behind(w):
		return false
	return root.get_visible_rect().has_point(cam.unproject_position(w))


## Opens the zone's sheet through main.gd and checks it with `test`, then closes it.
func open_and_check(z: Dictionary, test: Callable, what: String) -> void:
	main.close_sheet()
	await process_frame
	main.open_sheet(z)
	await process_frame
	check(is_instance_valid(main.sheet) and main.sheet_zone.get("id", "") == z.get("id", "") and test.call(main.sheet), what)
	main.close_sheet()
	await process_frame


## From `start`, a screen tap where `target` is (it must be on screen) walks to the zone and opens its sheet.
func tap_object(id: String, start: Vector3, target: Vector3) -> void:
	main.close_sheet()
	await process_frame
	teleport(start)
	main.pending_zone = ""
	await frames_n(30)
	var cam: Camera3D = p.rig.camera
	var vis := on_screen(target)
	var tapped := vis and p.tap_at(cam.unproject_position(target))
	for i in 2400:
		await physics_frame
		if is_instance_valid(main.sheet) or (not p.walking_to and main.pending_zone == ""):
			break
	await process_frame
	var up: bool = is_instance_valid(main.sheet) and main.sheet_zone.get("id", "") == id
	check(vis and tapped and up, "tap on %s from %s: on screen %s, sheet %s (%s)" % [id, start, vis, up, main.sheet_zone.get("id", "none") if is_instance_valid(main.sheet) else "none"])
	main.close_sheet()
	await process_frame
