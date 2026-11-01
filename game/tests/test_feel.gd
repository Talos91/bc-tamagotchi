extends SceneTree
## Feel pass (Daniele's playtest of 33dc5b9): camera, walls, movement, facing. Headless, from main.tscn.
##   facing    the Player root is rotated (the spawn's basis): the figure still faces the stick direction in the
##             world in eight directions, keeps its facing while it stops, and faces along the last stretch of a
##             tap-walk when it arrives (no turn-round at the end)
##   movement  speeding up and stopping take a moment but not long; tap-walks never jerk (no frame-to-frame heading
##             change over 25° at speed) and arrive; the stair flights are walked without bouncing off the floor
##   camera    walking through the main room (floor, bar, stage, toilets) never turns the view; the look point
##             moves without jumps; the player stays on screen in the main room's corners, portrait and landscape
##   walls     in the main room's corners, the buffer zone ("meeting room") and the lounge, the corner tables are in
##             view with no standing wall in between (the lounge's from where the player stands near them: its camera
##             looks west, so its east end is under the lens); cut box walls sink to a 0.4 m stub, not to nothing; the bar's
##             back wall and the stage's north wall stay up; the corridor keeps its rule (lounge walls solid)
##   godot --headless --path . --script res://tests/test_feel.gd

var main: Node
var p: Player
var js: TouchJoystick
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
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await physics_frame
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	p = main.player
	js = main.get_node("UI/Joystick")
	for i in 20:
		await physics_frame

	print("facing")
	check(absf(p.global_rotation.y) > 0.5, "the Player root is rotated (%.0f°), the case that turned the figure" % rad_to_deg(p.global_rotation.y))
	teleport(Vector3(7.5, 0.1, 6.5))
	await frames(10)
	var worst := 0.0
	var free_runs := 0
	for k in 8:
		var a := k * TAU / 8.0
		var d := Vector3(sin(a), 0, cos(a))
		js.value = p.world_to_input(d)
		await frames(22)
		# Free run or stopped by a table: faces the stick; sliding along a table: faces the way it really goes
		var rv := p.get_real_velocity()
		var sp := Vector2(rv.x, rv.z).length()
		free_runs += int(sp > 3.0)
		var heading := atan2(rv.x, rv.z) if sp > 1.0 and sp <= 3.0 else atan2(d.x, d.z)
		worst = maxf(worst, absf(angle_difference(p.facing(), heading)))
		js.value = Vector2.ZERO
		await frames(4)
		teleport(Vector3(7.5, 0.1, 6.5), false)
	check(free_runs == 8 and worst < deg_to_rad(8.0), "faces the way it walks in 8 directions (worst %.1f°, %d free runs)" % [rad_to_deg(worst), free_runs])
	js.value = p.world_to_input(Vector3(1, 0, 0))
	await frames(40)
	js.value = Vector2.ZERO
	var before := p.facing()
	var drift := 0.0
	for i in 40:
		await physics_frame
		drift = maxf(drift, absf(angle_difference(p.facing(), before)))
	check(drift < deg_to_rad(3.0), "keeps its facing while it stops (drift %.1f°)" % rad_to_deg(drift))

	print("movement")
	teleport(Vector3(26.0, 0.1, 6.7))
	await frames(5)
	js.value = p.world_to_input(Vector3(1, 0, 0))
	var t_full := 0.0
	for i in 120:
		await physics_frame
		t_full += 1.0 / Engine.physics_ticks_per_second
		if Vector2(p.velocity.x, p.velocity.z).length() > p.speed * 0.95:
			break
	await frames(10)
	js.value = Vector2.ZERO
	var t_stop := 0.0
	for i in 120:
		await physics_frame
		t_stop += 1.0 / Engine.physics_ticks_per_second
		if Vector2(p.velocity.x, p.velocity.z).length() < 0.05:
			break
	check(t_full > 0.12 and t_full < 0.45, "reaches walking speed in %.2f s (0.12-0.45)" % t_full)
	check(t_stop > 0.08 and t_stop < 0.35, "stops in %.2f s (0.08-0.35)" % t_stop)

	print("tap-walks")
	for leg in [[Vector3(22.5, 0.1, 6.5), Vector3(36.0, 0, 11.0)], [Vector3(36.0, 0.1, 11.0), Vector3(23.0, 0, 2.6)],
			[Vector3(30.0, 0.1, 6.7), Vector3(17.7, 0, 5.2)], [Vector3(17.7, 0.1, 5.2), Vector3(7.0, 0, 3.5)]]:
		teleport(leg[0])
		await frames(5)
		p.walk_to(leg[1])
		var jerk := 0.0
		var last_h := INF
		var arrived := false
		for i in 1500:
			await physics_frame
			var v := p.get_real_velocity()
			var h := Vector2(v.x, v.z)
			if h.length() > 1.0:
				var hh := atan2(h.x, h.y)
				if last_h != INF:
					jerk = maxf(jerk, absf(angle_difference(last_h, hh)))
				last_h = hh
			else:
				last_h = INF
			if not p.walking_to:
				arrived = true
				break
		var end_yaw := p.facing()
		await frames(30)
		var miss := Vector2(p.global_position.x - leg[1].x, p.global_position.z - leg[1].z).length()
		check(arrived and miss < 0.6, "tap-walk %s -> %s arrives (miss %.2f m)" % [v2(leg[0]), v2(leg[1]), miss])
		check(jerk < deg_to_rad(25.0), "  no jerk on the way (largest heading step %.1f°)" % rad_to_deg(jerk))
		check(absf(angle_difference(end_yaw, p.facing())) < deg_to_rad(3.0), "  no turn after arriving (%.1f°)" % rad_to_deg(absf(angle_difference(end_yaw, p.facing()))))

	print("stairs")
	teleport(Vector3(9.0, 0.1, 12.25))
	await frames(5)
	var on_floor := 0
	var n := 0
	var bounce := 0
	var last_y := p.global_position.y
	var up := true
	for goal in [Vector3(3.2, 0, 12.25), Vector3(3.15, 0, 7.0)]:
		for i in 500:
			var d: Vector3 = goal - p.global_position
			d.y = 0
			if d.length() < 0.2:
				break
			js.value = p.world_to_input(d.normalized())
			await physics_frame
			n += 1
			on_floor += int(p.is_on_floor())
			var dy := p.global_position.y - last_y
			if dy < -0.01:   # going down while climbing = a bounce
				bounce += 1
			last_y = p.global_position.y
	js.value = Vector2.ZERO
	check(p.global_position.y > 2.0, "climbed both flights (y %.2f)" % p.global_position.y)
	check(float(on_floor) / n > 0.97 and bounce <= 2, "steady on the stairs: on the floor %d of %d frames, %d bounces" % [on_floor, n, bounce])

	print("camera")
	var rig: CameraRig = p.rig
	teleport(Vector3(22.5, 0.1, 6.5))
	await frames(30)
	var yaw0 := rig.yaw
	var yaw_dev := 0.0
	var jump := 0.0
	var zones := {}
	var last_cam := rig.global_position
	for goal in [Vector3(29.0, 0, 11.4), Vector3(30.75, 0, 5.4), Vector3(21.0, 0, 14.5), Vector3(36.0, 0, 3.0)]:
		p.walk_to(goal)
		for i in 1500:
			await process_frame
			zones[rig.zone] = true
			yaw_dev = maxf(yaw_dev, absf(angle_difference(yaw0, rig.yaw)))
			jump = maxf(jump, rig.global_position.distance_to(last_cam))
			last_cam = rig.global_position
			if not p.walking_to:
				break
	js.value = Vector2.ZERO
	check(zones.has("floor") and zones.has("bar") and zones.has("stage") and zones.has("toilets"), "walked through floor, bar, stage and toilets zones: %s" % [zones.keys()])
	check(yaw_dev < deg_to_rad(1.0), "the main-room view never turns (%.1f°)" % rad_to_deg(yaw_dev))
	check(jump < 0.25, "camera moves without jumps (largest step %.2f m per frame)" % jump)
	for size in [Vector2i(1080, 1920), Vector2i(1920, 1080)]:
		root.size = size
		for at in [Vector3(21.3, 0.1, 1.3), Vector3(21.0, 0.1, 13.9), Vector3(39.5, 0.1, 1.5), Vector3(35.0, 0.1, 12.0)]:
			teleport(at)
			await frames(20)
			check(on_screen(p.global_position + Vector3(0, 0.9, 0), 0.04), "player on screen at %s (%dx%d)" % [v2(at), size.x, size.y])
	root.size = Vector2i(1080, 1920)

	print("walls")
	var venue: Node3D = main.get_node("Venue")
	await corner("main room NW (top-left)", Vector3(23.2, 0.1, 2.6), ["WestTable0", "WestTable1"])
	await corner("main room SW (bottom-left)", Vector3(22.0, 0.1, 10.3), ["OpeningTall0", "OpeningTall1"])
	await corner("meeting room (buffer zone)", Vector3(17.7, 0.1, 5.3), ["BufferTall0", "BufferTall1", "BufferTall2", "BufferTall3"])
	await corner("lounge, middle", Vector3(8.0, 0.1, 6.0), ["LongTable", "LoungeTable0"])
	await corner("lounge, north-east", Vector3(11.5, 0.1, 2.6), ["HighCounter", "LoungeTable0"])
	await corner("lounge, south", Vector3(9.5, 0.1, 9.5), ["LoungeTable1", "LongTable"])
	# Stubs: a cut box wall is replaced by its 0.4 m stub, never by nothing
	teleport(Vector3(23.2, 0.1, 2.6))
	await frames(30)
	var stubs := 0
	var bad_stub := 0
	for i in rig._cutaway.size():
		var st: Variant = rig._stubs[i]
		if st != null and rig._cut_amt[i] >= 1.0:
			stubs += 1
			var s: MeshInstance3D = st[0]
			var box := s.global_transform * s.get_aabb()
			if not s.visible or absf(box.size.y - CameraRig.STUB_H) > 0.02 or box.position.y > 0.2:
				bad_stub += 1
	check(stubs > 0 and bad_stub == 0, "%d cut walls stand as 0.4 m stubs (%d wrong)" % [stubs, bad_stub])
	# Back walls stay up: the bar's back wall seen from the counter, the stage's north wall from the stage front
	teleport(Vector3(29.0, 0.1, 11.6))
	await frames(30)
	check(wall_at(Vector3(29.0, 2.0, 15.0)), "the bar's back wall stands behind the counter")
	teleport(Vector3(30.75, 0.1, 5.4))
	await frames(30)
	check(wall_at(Vector3(30.75, 2.5, 0.0)), "the stage's north wall stands behind the stage")
	# Corridor: unchanged rule, the lounge stays closed and the cut walls vanish (no stubs) as before
	teleport(Vector3(8.0, 0.1, 14.1))
	await frames(30)
	var lounge_cut := get_nodes_in_group("cutaway").filter(func(w): return w.has_meta("cut_rooms") and (w.get_meta("cut_rooms") as Array).has("lounge") and not w.visible).size()
	var stub_shown := 0
	for st in rig._stubs:
		if st != null and (st[0] as Node3D).visible:
			stub_shown += 1
	check(rig.zone == "corridor" and lounge_cut == 0 and stub_shown == 0, "corridor: lounge walls solid (%d cut), no stubs (%d)" % [lounge_cut, stub_shown])

	print("\n%s (%d failures)" % ["PASS" if fails.is_empty() else "FAIL", fails.size()])
	quit(0 if fails.is_empty() else 1)


func frames(k: int) -> void:
	for i in k:
		await physics_frame
	await process_frame


func teleport(pos: Vector3, snap := true) -> void:
	p.stand_up()
	p.walking_to = false
	js.value = Vector2.ZERO
	p.global_position = pos
	p.velocity = Vector3.ZERO
	if snap:
		p.rig.snap()


func v2(v: Vector3) -> String:
	return "(%.1f, %.1f)" % [v.x, v.z]


func on_screen(w: Vector3, margin: float) -> bool:
	var cam: Camera3D = p.rig.camera
	if cam.is_position_behind(w):
		return false
	var r := root.get_visible_rect()
	var s := cam.unproject_position(w)
	return r.grow(-margin * minf(r.size.x, r.size.y)).has_point(s)


## Player at `at`; each named table must be on screen with no standing (visible) cutaway piece on the line from the
## camera to its top.
func corner(what: String, at: Vector3, tables: Array) -> void:
	teleport(at)
	await frames(40)
	var venue: Node3D = main.get_node("Venue")
	for t in tables:
		var n := venue.find_child(t, true, false) as Node3D
		if n == null:
			check(false, "%s: table %s not found" % [what, t])
			continue
		var top := n.global_position + Vector3(0, 0.9, 0)
		var walls := standing_between(p.rig.global_position, top)
		check(on_screen(top, 0.0) and walls.is_empty(), "%s: %s in view%s" % [what, t, "" if walls.is_empty() else " but behind " + ", ".join(walls)])


## Names of visible cutaway pieces crossing the segment.
func standing_between(a: Vector3, b: Vector3) -> Array:
	var out := []
	var rig: CameraRig = p.rig
	for i in rig._cutaway.size():
		var w := rig._cutaway[i]
		if is_instance_valid(w) and w.is_visible_in_tree() and rig._cut_boxes[i].intersects_segment(a, b):
			out.append(str(w.name))
	return out


## True when a visible cutaway piece stands at `w` (a wall is up there).
func wall_at(w: Vector3) -> bool:
	var rig: CameraRig = p.rig
	for i in rig._cutaway.size():
		var n := rig._cutaway[i]
		if is_instance_valid(n) and n.is_visible_in_tree() and rig._cut_boxes[i].grow(0.05).has_point(w):
			return true
	return false
