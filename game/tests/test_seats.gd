extends SceneTree
## Every seat in the venue faces what it belongs to (Daniele's playtest of 33dc5b9: "tapping a seat often sits the
## character the wrong way round"). Walks the whole list of spots in group "seat" (tools/build_venue.gd `_seat`)
## and checks each one's forward (+z of its yaw, the figure's front) against its target:
##   a table / tall table / counter  the nearest point of that table's footprint (kit instance named by meta table)
##   the bar ("Bar")                  the nearest bar counter piece (Counter0..), south of the stools
##   the memory corner ("memory")     the room (south): photo chairs with their backs to the TV corner
##   smoking-room chairs              their table (meta table) like any other
## (The tiny two-stool tables face the stage across them, so they pass by their table too.) A seat passes when the
## angle between its forward and the direction to the target is under 35°; a seat whose table is missing fails. Then it seats the player on a sample of seats through the real code path
## (VenueSession.find_seat + Player.sit_at) and checks the *world* facing of the figure, which is what the
## camera shows: the root-rotation bug of 33dc5b9 kept the local yaw right and the world facing 90° off.
##   godot --headless --path . --script res://tests/test_seats.gd [-- --list]

const MAX_ANGLE := 35.0

var fails: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _init() -> void:
	await process_frame
	var needs := root.get_node_or_null("Needs")
	needs.autosave = false
	needs.new_game()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await physics_frame
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	for i in 10:
		await physics_frame
	var venue: Node3D = main.get_node("Venue")
	var list := OS.get_cmdline_user_args().has("--list")

	print("every seat faces its table")
	var seats := get_nodes_in_group("seat")
	check(seats.size() > 60, "seat spots found: %d" % seats.size())
	var bad := 0
	for s in seats:
		var n := s as Node3D
		var table := str(n.get_meta("table", ""))
		var target := _target(venue, n, table)
		if target == Vector3.INF:
			check(false, "%s: table '%s' not found" % [n.name, table])
			bad += 1
			continue
		var fwd := Vector3(sin(n.global_rotation.y), 0, cos(n.global_rotation.y))
		var to := Vector3(target.x - n.global_position.x, 0, target.z - n.global_position.z)
		var ang := rad_to_deg(fwd.angle_to(to.normalized())) if to.length() > 0.01 else 0.0
		if list or ang >= MAX_ANGLE:
			print("    %-22s table %-14s yaw %6.0f  to target %6.0f  off %5.0f%s" % [n.name, table, rad_to_deg(n.global_rotation.y),
				rad_to_deg(atan2(to.x, to.z)), ang, "  <-- WRONG" if ang >= MAX_ANGLE else ""])
		if ang >= MAX_ANGLE:
			bad += 1
	check(bad == 0, "%d of %d seats face their table, bar or corner (within %.0f°)" % [seats.size() - bad, seats.size(), MAX_ANGLE])

	print("the seated player faces the seat's way in the world")
	var p: Player = main.player
	var sess: VenueSession = main.session
	var crowd := get_first_node_in_group("venue_patrons")
	# One seat per table, so every kind of seat is covered: chairs, couches, stools, bar, smoking, memory corner
	var done := {}
	var tried := 0
	for s in seats:
		var table := str(s.get_meta("table", ""))
		if done.has(table):
			continue
		done[table] = true
		if crowd != null and crowd.is_taken(s):
			crowd.vacate(s)
		var seat := {"node": s, "pos": s.global_position, "yaw": s.global_rotation.y, "h": float(s.get_meta("seat_h", 0.45)),
			"couch": s.get_meta("couch", false), "table": table, "pose": "sit_drink"}
		p.stand_up()
		p.global_position = s.global_position - Vector3(sin(seat.yaw), 0, cos(seat.yaw)) * 0.6 + Vector3(0, 0.1, 0)
		p.seat = seat
		p.walking_to = false
		for i in 60:
			await physics_frame
			if p.seated:
				break
		tried += 1
		var ok := p.seated and absf(angle_difference(p.facing(), float(seat.yaw))) < 0.05 \
			and absf(angle_difference(p.get_node("Body").global_rotation.y, float(seat.yaw))) < 0.05
		if not ok:
			check(false, "%s (%s): seated %s, body world yaw %.0f, seat yaw %.0f" % [s.name, table, p.seated,
				rad_to_deg(p.get_node("Body").global_rotation.y), rad_to_deg(seat.yaw)])
	check(tried > 20, "seated the player at one seat of each of %d tables and checked world facing" % tried)
	p.stand_up()

	print("\n%s (%d failures)" % ["PASS" if fails.is_empty() else "FAIL", fails.size()])
	quit(0 if fails.is_empty() else 1)


## World point a seat should face: the nearest point of its table's footprint (so the end chairs of a long table
## count as facing it), or Vector3.INF if the table cannot be found. Counter stools face the nearest bar counter.
func _target(venue: Node3D, s: Node3D, table: String) -> Vector3:
	var nodes: Array = []
	if table == "Bar":
		nodes = venue.find_children("Counter*", "Node3D", true, false)
	elif table == "memory":
		# Photo chairs with their backs to the TV corner on the north wall, facing the room (photo 25)
		return s.global_position + Vector3(0, 0, 1)
	elif table != "":
		var t := venue.find_child(table, true, false)
		nodes = [t] if t != null else []
	if nodes.is_empty():
		return Vector3.INF
	var best := Vector3.INF
	for n in nodes:
		var box := _footprint(n as Node3D)
		var q := Vector3(clampf(s.global_position.x, box.position.x, box.end.x), 0, clampf(s.global_position.z, box.position.z, box.end.z))
		if best == Vector3.INF or q.distance_to(s.global_position) < best.distance_to(s.global_position):
			best = q
	return best


## World box of a node's meshes (its origin when it has none).
func _footprint(n: Node3D) -> AABB:
	var box := AABB(n.global_position, Vector3.ZERO)
	for v in n.find_children("*", "VisualInstance3D", true, false) + ([n] if n is VisualInstance3D else []):
		box = box.merge((v as VisualInstance3D).global_transform * (v as VisualInstance3D).get_aabb())
	return box
