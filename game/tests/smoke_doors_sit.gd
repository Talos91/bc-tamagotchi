extends SceneTree
## Headless smoke test of Daniele's v4 playtest notes (doors, sitting, stairs), from main.tscn:
##   doors   the navmesh runs through the street door, the Sticker door and the red door; each leaf swings open as
##           the player walks through and closes after; the staff door stays shut to the player and blocks them
##   sitting "sit" at Prae's table (id mali) walks the player to a chair and seats them on it, facing the table at
##           the seat's height; a minute seated refills Friends as before; stick input stands them up; the same on a
##           raised-strip couch, a tall-table stool and a bar stool ("Take a stool": a minute gives bar_chat); and at
##           each new kind of seat zone (tiny tables, long table, lounge counter, rectangular and smoking tables)
##   stairs  up the first flight to the landing, up the second until the rope; the game cabinet stays reachable
##   godot --headless --path . --script res://tests/smoke_doors_sit.gd

var main: Node
var needs: Node
var p: Player
var s: VenueSession
var js: TouchJoystick
var doors: Node
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
		needs.meters[m] = 20.0
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
	doors = main.get_node("Venue/Doors")

	print("spawn")
	for i in 20:   # HUD title and navigation map settle
		await physics_frame
	check(main.zones.current.is_empty() and not main.hud.prompt.is_showing(), "spawn in the lobby is outside the exit zone: no prompt at the start (%s)" % p.global_position)
	check(main.hud._title.text == "ENTRANCE", "HUD zone name in the lobby: %s" % main.hud._title.text)

	print("doors")
	var names := []
	for d in doors.doors:
		names.append(str(d.node.name))
	check(names.has("StreetDoor") and names.has("StickerDoor") and names.has("RedDoor") and names.has("StaffDoorBar"), "swing doors built: %s" % [names])
	var map: RID = p.get_world_3d().navigation_map
	for leg in [["lobby -> street step", Vector3(1.2, 0, 9.0), Vector3(-1.0, 0, 7.2)],
			["corridor -> lounge (Sticker door)", Vector3(8.0, 0, 14.1), Vector3(13.6, 0, 11.6)],
			["main room -> smoking room (red door)", Vector3(39.6, 0, 11.4), Vector3(40.0, 0, 15.2)]]:
		var path := NavigationServer3D.map_get_path(map, leg[1], leg[2], true)
		var end: Vector3 = path[path.size() - 1] if path.size() > 0 else Vector3(INF, 0, 0)
		check(Vector2(end.x - leg[2].x, end.z - leg[2].z).length() < 0.3, "navmesh path %s ends at the goal (%s)" % [leg[0], end.snapped(Vector3.ONE * 0.01)])
	await through_door("StickerDoor", Vector3(13.65, 0.1, 14.6), Vector3(13.65, 0, 11.8), func(q: Vector3): return q.z < 12.4)
	await through_door("RedDoor", Vector3(39.6, 0.1, 11.4), Vector3(39.6, 0, 14.6), func(q: Vector3): return q.z > 13.6)
	await through_door("StreetDoor", Vector3(1.6, 0.1, 7.2), Vector3(-1.0, 0, 7.2), func(q: Vector3): return q.x < -0.5)
	check(main.zones.current.get("kind", "") == "exit", "the step outside the street door is in the exit zone (leave from there)")
	# Staff door: shut to the player, and solid
	teleport(Vector3(37.55, 0.1, 11.4))
	await walk(Vector3(37.55, 0, 14.0), 150)
	check(doors.openness("StaffDoorBar") < 0.01, "staff door stays shut for the player")
	check(p.global_position.z < 12.6, "staff door blocks the player (z %.2f)" % p.global_position.z)

	print("sitting")
	var f0: float = needs.meters["friends"]
	var prae: Dictionary = main.zones.first_of("table", true)
	var seat := await sit_at(prae, "sit")
	check(not seat.is_empty() and not seat.get("couch", true), "at Prae's table (%s): seated on a chair" % prae.get("id", "?"))
	s.tick(VenueSession.SIT_SECONDS + 1.0)
	check(s.sitting.is_empty() and needs.meters["friends"] > f0, "a minute seated refills Friends (%.1f -> %.1f)" % [f0, needs.meters["friends"]])
	check(p.seated, "still seated after the minute")
	await stand_with_stick()
	seat = await sit_at(main.zones.by_id("table:Raised1"), "sit")
	check(str(seat.get("table", "")) == "Raised1", "raised strip: seated at Raised1 (%s)" % [seat.get("node", null)])
	if not seat.get("couch", false):   # take a couch place explicitly: the chair may be nearer
		await stand_with_stick()
		for n in get_nodes_in_group("seat"):
			if n.get_meta("table", "") == "Raised1" and n.get_meta("couch", false):
				var c: Dictionary = {"node": n, "pos": n.global_position, "yaw": n.global_rotation.y, "h": float(n.get_meta("seat_h")), "couch": true, "table": "Raised1", "pose": "sit_hold"}
				p.sit_at(c)
				await until_seated()
				check_on_seat(c)
				break
	await stand_with_stick()
	var tall: Dictionary = main.zones.first_of("tall")
	seat = await sit_at(tall, "sit")
	check(not seat.is_empty() and absf(float(seat.get("h", 0.0)) - 0.75) < 0.01, "tall table %s: seated on a tall stool" % tall.get("id", "?"))
	await stand_with_stick()
	var bar: Dictionary = main.zones.first_of("bar")
	seat = await sit_at(bar, "stool")
	check(str(seat.get("table", "")) == "Bar" and absf(float(seat.get("h", 0.0)) - 0.8) < 0.01, "bar: seated on a bar stool")
	var stool_row: Dictionary = s.rows_for(bar).filter(func(r): return r["id"] == "stool")[0]
	check(not stool_row["enabled"], "Take a stool is disabled while on a stool")
	var fb: float = needs.meters["friends"]
	s.tick(VenueSession.SIT_SECONDS + 1.0)
	check(needs.meters["friends"] > fb and needs.visit_action_totals.get("bar_chat", 0.0) > 0.0, "a minute on the stool chats (bar_chat): Friends %.1f -> %.1f" % [fb, needs.meters["friends"]])
	check(p.seated, "still on the stool after the minute")
	await stand_with_stick()
	# Every seat in the club is sittable (Daniele 2026-11-02): one of each new kind of seat zone
	for id in ["table:Tiny2", "table:TinyE0", "table:LongTable", "table:HighCounter", "table:RectTableW", "table:RectTableE", "table:Smoke1"]:
		var tz: Dictionary = main.zones.by_id(id)
		check(not tz.is_empty(), "zone %s built" % id)
		if tz.is_empty():
			continue
		var ff: float = needs.meters["friends"]
		seat = await sit_at(tz, "sit")
		check(str(seat.get("table", "")) == id.get_slice(":", 1), "%s: seated at its table (%s)" % [id, seat.get("node", null)])
		s.tick(VenueSession.SIT_SECONDS + 1.0)
		check(needs.meters["friends"] > ff, "%s: a seated minute refills Friends" % id)
		await stand_with_stick()

	print("stairs")
	teleport(Vector3(9.0, 0.1, 12.25))
	await walk(Vector3(3.2, 0, 12.25), 600)
	check(absf(p.global_position.y - 1.6) < 0.12 and p.global_position.x < 4.2, "first flight climbed to the landing (%s)" % p.global_position.snapped(Vector3.ONE * 0.01))
	await walk(Vector3(3.15, 0, 7.0), 400)
	check(p.global_position.z > 9.9 and p.global_position.y > 2.1 and p.global_position.y < 2.8, "second flight climbed to the rope, not past it (%s)" % p.global_position.snapped(Vector3.ONE * 0.01))
	var cab: Dictionary = main.zones.first_of("cabinet")
	var cpath := NavigationServer3D.map_get_path(map, Vector3(12.0, 0, 9.0), cab["approach"], true)
	var cend: Vector3 = cpath[cpath.size() - 1] if cpath.size() > 0 else Vector3(INF, 0, 0)
	check(Vector2(cend.x - cab["approach"].x, cend.z - cab["approach"].z).length() < 0.3, "game cabinet reachable (%s)" % cab["approach"])

	print("SMOKE DOORS SIT ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


func teleport(pos: Vector3) -> void:
	p.stand_up()
	p.walking_to = false
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rig.snap()


## Joystick walk toward `goal` (x, z) for at most `frames` physics frames.
func walk(goal: Vector3, frames: int) -> void:
	for i in frames:
		var d: Vector3 = goal - p.global_position
		d.y = 0
		if d.length() < 0.2:
			break
		js.value = p.world_to_input(d.normalized())
		await physics_frame
	js.value = Vector2.ZERO
	await physics_frame


## Walk through a door; the leaf must be (nearly) fully open while the player is in the opening, and closed again
## after they have gone on.
func through_door(door: String, from: Vector3, to: Vector3, arrived: Callable) -> void:
	teleport(from)
	for i in 30:
		await physics_frame
	check(doors.openness(door) < 0.01, "%s closed while nobody is near" % door)
	var in_opening := 1.0
	for i in 400:
		var d: Vector3 = to - p.global_position
		d.y = 0
		if d.length() < 0.2:
			break
		js.value = p.world_to_input(d.normalized())
		await physics_frame
		var c: Vector3 = doors.doors.filter(func(x): return x.node.name == door)[0].center
		if Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length() < 0.3:
			in_opening = minf(in_opening, doors.openness(door))
	js.value = Vector2.ZERO
	check(arrived.call(p.global_position), "%s: walked through (%s)" % [door, p.global_position.snapped(Vector3.ONE * 0.01)])
	check(in_opening > 0.8, "%s: open while the player is in the doorway (%.2f)" % [door, in_opening])
	await walk(to + (to - from).normalized() * 1.0, 60)
	for i in 120:
		await physics_frame
	check(doors.openness(door) < 0.05, "%s closes after the player has passed (%.2f)" % [door, doors.openness(door)])


## Stands next to the zone, does the row and waits until seated; returns the seat (or {}).
func sit_at(zone: Dictionary, row_id: String) -> Dictionary:
	teleport(zone["approach"] + Vector3(0, 0.1, 0))
	for i in 20:
		await physics_frame
	check(main.zones.current.get("id", "") == zone["id"], "at zone %s" % zone["id"])
	check(s.do_row(zone, row_id), "row %s at %s" % [row_id, zone["id"]])
	await until_seated()
	if not p.seated:
		return {}
	check_on_seat(p.seat)
	return p.seat


func until_seated() -> void:
	for i in 900:
		if p.seated:
			break
		await physics_frame
	for i in 3:
		await physics_frame


func check_on_seat(seat: Dictionary) -> void:
	var pos: Vector3 = seat["pos"]
	var want_y := float(seat["h"]) - PatronFigure.SEAT_H * PatronFigure.FIG_SCALE
	check(p.seated and p.global_position.distance_to(pos) < 0.02, "on the seat spot %s" % seat["node"].name)
	check(absf(angle_difference(p.get_node("Body").rotation.y, float(seat["yaw"]))) < 0.02, "facing the seat's way (yaw %.0f)" % rad_to_deg(seat["yaw"]))
	check(absf(p.figure.position.y - want_y) < 0.01, "seat height %.2f (figure lowered to %.3f)" % [seat["h"], p.figure.position.y])
	check(p.figure.state.begins_with("sit"), "seated pose (%s)" % p.figure.state)


func stand_with_stick() -> void:
	js.value = Vector2(0.0, 1.0)
	for i in 4:
		await physics_frame
	js.value = Vector2.ZERO
	await physics_frame
	check(not p.seated, "stick input stands the player up")
