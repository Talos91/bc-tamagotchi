extends SceneTree
## Feel pass (Daniele's playtest of 33dc5b9): camera, walls, movement, facing. Headless, from main.tscn.
##   facing    the Player root is rotated (the spawn's basis): the figure still faces the stick direction in the
##             world in eight directions, keeps its facing while it stops, and faces along the last stretch of a
##             tap-walk when it arrives (no turn-round at the end)
##   movement  speeding up and stopping take a moment but not long; tap-walks never jerk (no frame-to-frame heading
##             change over 25° at speed) and arrive; the stair flights are walked without bouncing off the floor
##   camera    a view per area again (Daniele, Questions tab 2026-11-01): walking floor -> stage -> bar -> toilets
##             turns the view to each area's yaw with no jumps and no fast spins (yaw speed capped, camera steps
##             small); skirting into an area for less than the dwell never turns it; the player stays on screen in
##             the main room's corners, portrait and landscape
##   areas     every area button (needs_hud AREAS) from the middle of the main room: the camera turns to the area at
##             once, the player is on screen every frame of the walk, the walk ends inside the area with its sheet
##             open, and the camera settles on the area's framing (yaw, pitch, distance, look point in its clamp)
##   smoking   the smoking room is in view from the main room in front of its door (its view takes over there, the
##             tables unhidden by walls) and from inside at every corner; walking in through the red door the player
##             is never behind a standing wall or the open door leaf
##   follow    camera feel 2 (Daniele, Questions tab 2026-11-02: "trails behind when walking"): walking across the
##             floor the look point is never more than FOLLOW_TRAIL behind the player nor more than FOLLOW_NEAR from
##             them, it is back on them soon after the stop, and the camera does not shake at the start, the stop or
##             on the stairs (largest change of the camera's step from one tick to the next)
##   framing   every area's pitch and distance are the camera-feel-2 values (FRAMING), and standing in each area the
##             character is at least MIN_HEIGHT_PX tall on a 450 x 800 portrait screen (the smoking room's view a bit
##             less, MIN_HEIGHT_SMOKING, so the room shows from the main room)
##   occlusion walks through every area (OCCL_ROUTES): on every other tick nothing visible stands on the sight line
##             from the camera to the player's chest or head (furniture, walls, kit pieces, doors; other characters
##             are not counted)
##   walls     in the main room's corners, the buffer zone ("meeting room") and the lounge, the corner tables are in
##             view with no standing wall in between (the lounge's from where the player stands near them: its camera
##             looks west, so its east end is under the lens); cut box walls sink to a 0.4 m stub, not to nothing; the bar's
##             back wall and the stage's north wall stay up; the corridor keeps its rule (lounge walls solid)
## Timing is deterministic: the camera rig steps on physics ticks with a fixed delta, and every speed here is taken
## per tick (the old turn-speed check used the wall clock and flaked under load).
##   godot --headless --path . --script res://tests/test_feel.gd

const FOLLOW_TRAIL := 0.35      ## metres the look point may fall behind the player while walking
const FOLLOW_NEAR := 0.9        ## metres the look point may be from the player while walking (lead included)
const SHAKE_MAX := 0.012        ## metres: largest tick-to-tick change of the camera's step
const MIN_HEIGHT_PX := 80.0     ## the character's height on screen, in a 450 x 800 portrait frame
const MIN_HEIGHT_SMOKING := 72.0    ## the smoking view stays a little wider: its four tables show from the red door
## Camera feel 2 framings: area -> [pitch, distance] (build_venue.gd _camera_zones)
const FRAMING := {"lobby": [-40.0, 5.0], "corridor": [-36.0, 5.0], "buffer": [-40.0, 4.6], "alcove": [-50.0, 4.2],
	"merch": [-38.0, 5.0], "memory": [-38.0, 5.0], "patrons": [-34.0, 4.8], "lounge": [-40.0, 5.0], "bar": [-40.0, 5.2],
	"stage": [-34.0, 5.2], "toilets": [-42.0, 4.8], "smoking": [-46.0, 5.4], "floor": [-36.0, 5.6]}
## A spot in each area (framing check)
const AREA_SPOTS := {"floor": Vector3(30.0, 0.1, 6.8), "bar": Vector3(29.0, 0.1, 11.4), "stage": Vector3(30.75, 0.1, 4.6),
	"toilets": Vector3(21.0, 0.1, 14.2), "smoking": Vector3(40.0, 0.1, 15.2), "buffer": Vector3(17.7, 0.1, 5.3),
	"lounge": Vector3(8.0, 0.1, 6.0), "merch": Vector3(12.5, 0.1, 2.4), "memory": Vector3(5.0, 0.1, 2.0),
	"patrons": Vector3(4.8, 0.1, 9.6), "alcove": Vector3(17.5, 0.1, 11.2), "corridor": Vector3(8.0, 0.1, 14.1),
	"lobby": Vector3(1.1, 0.1, 10.0)}
## Occlusion walks: [label, start, waypoints]
const OCCL_ROUTES := [
	["lobby", Vector3(1.1, 0.1, 12.5), [Vector3(1.0, 0, 6.0), Vector3(1.2, 0, 12.8)]],
	["corridor", Vector3(2.6, 0.1, 14.1), [Vector3(13.6, 0, 14.1)]],
	["lounge", Vector3(13.6, 0.1, 12.0), [Vector3(8.0, 0, 6.0), Vector3(4.0, 0, 4.0), Vector3(12.0, 0, 9.0), Vector3(9.0, 0, 11.5), Vector3(13.0, 0, 6.0)]],
	["merch", Vector3(11.0, 0.1, 3.0), [Vector3(14.6, 0, 2.6), Vector3(11.0, 0, 1.2)]],
	["memory", Vector3(7.0, 0.1, 2.0), [Vector3(3.2, 0, 1.4), Vector3(7.5, 0, 1.2)]],
	["patrons", Vector3(5.5, 0.1, 10.5), [Vector3(4.4, 0, 9.0), Vector3(6.2, 0, 8.2)]],
	["buffer", Vector3(15.8, 0.1, 5.3), [Vector3(19.6, 0, 5.3), Vector3(17.7, 0, 3.4), Vector3(17.7, 0, 7.2), Vector3(16.0, 0, 5.2)]],
	["lounge -> floor", Vector3(12.0, 0.1, 5.3), [Vector3(22.6, 0, 6.6)]],
	["floor -> lounge", Vector3(22.6, 0.1, 6.6), [Vector3(12.0, 0, 5.3)]],
	["alcove", Vector3(16.0, 0.1, 11.2), [Vector3(19.4, 0, 11.6), Vector3(16.0, 0, 10.6)]],
	["floor", Vector3(22.5, 0.1, 6.5), [Vector3(38.5, 0, 6.6), Vector3(23.2, 0, 2.6), Vector3(22.0, 0, 10.3), Vector3(36.5, 0, 2.0), Vector3(37.0, 0, 9.5)]],
	["raised strip", Vector3(40.3, 0.3, 0.8), [Vector3(40.3, 0.15, 9.9), Vector3(40.4, 0.15, 2.0)]],
	["stage", Vector3(28.0, 0.1, 5.2), [Vector3(33.5, 0, 5.0), Vector3(30.0, 0, 3.5)]],
	["bar", Vector3(24.5, 0.1, 11.5), [Vector3(34.5, 0, 11.4), Vector3(26.0, 0, 11.2)]],
	["toilets", Vector3(21.0, 0.1, 13.0), [Vector3(21.0, 0, 15.9), Vector3(23.6, 0, 16.0), Vector3(21.2, 0, 13.0)]],
	["smoking", Vector3(39.6, 0.1, 13.6), [Vector3(41.1, 0, 17.3), Vector3(39.0, 0, 17.3), Vector3(40.0, 0, 13.4)]],
]

var main: Node
var p: Player
var js: TouchJoystick
var fails: Array[String] = []
var geoms: Array[GeometryInstance3D] = []   ## meshes that could hide the player (not the player, not characters)


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
	var spin := 0.0
	var jump := 0.0
	var views := {}
	for goal in [Vector3(30.75, 0, 5.4), Vector3(29.0, 0, 11.4), Vector3(21.0, 0, 14.5)]:
		p.walk_to(goal)
		var last_cam := rig.global_position
		var last_yaw := rig.yaw
		for i in 1800:
			await physics_frame   # the rig steps once per physics tick with a fixed delta: no wall clock here
			views[rig.view] = true
			spin = maxf(spin, absf(angle_difference(last_yaw, rig.yaw)) * Engine.physics_ticks_per_second)
			last_yaw = rig.yaw
			jump = maxf(jump, rig.global_position.distance_to(last_cam))
			last_cam = rig.global_position
			if not p.walking_to and rig.view == rig.zone and absf(rig._yaw_v) < 0.02:
				break
		await frames(60)
		check(rig.zone == rig.view and absf(angle_difference(rig.yaw, deg_to_rad(zone_marker(rig.zone).get_meta("yaw")))) < deg_to_rad(2.0),
			"  walked to %s: the %s view, settled on its yaw" % [v2(goal), rig.zone])
	check(views.has("stage") and views.has("bar") and views.has("toilets"), "a view per area on the way: %s" % [views.keys()])
	check(spin < deg_to_rad(260.0), "no fast spins (fastest turn %.0f°/s)" % rad_to_deg(spin))
	check(jump < 0.3, "camera moves without jumps (largest step %.2f m per frame)" % jump)
	# Skirting into an area for less than the dwell never turns the view
	teleport(Vector3(30.0, 0.1, 8.6))
	await frames(30)
	var v0 := rig.view
	p.global_position = Vector3(30.0, 0.1, 9.9)
	await frames(8)
	p.global_position = Vector3(30.0, 0.1, 8.6)
	await frames(30)
	check(v0 == "floor" and rig.view == "floor", "a step into the bar and back within the dwell keeps the floor view (%s -> %s)" % [v0, rig.view])
	for size in [Vector2i(1080, 1920), Vector2i(1920, 1080)]:
		root.size = size
		for at in [Vector3(21.3, 0.1, 1.3), Vector3(21.0, 0.1, 13.9), Vector3(39.5, 0.1, 1.5), Vector3(35.0, 0.1, 12.0)]:
			teleport(at)
			await frames(20)
			check(on_screen(p.global_position + Vector3(0, 0.9, 0), 0.04), "player on screen at %s (%dx%d)" % [v2(at), size.x, size.y])
		# From the middle of the floor the raised strip's tables are in frame (test_lounge taps them from here)
		teleport(Vector3(30.0, 0.1, 7.0))
		await frames(5)
		rig.snap()   # again, now that the window's new size is in effect (the framing settles over a second otherwise)
		await frames(5)
		var raised := 0
		for i in 5:
			raised += int(on_screen((main.get_node("Venue").find_child("Raised%d" % i, true, false) as Node3D).global_position + Vector3(0, 0.75, 0), 0.0))
		check(raised == 5, "from the middle of the floor %d of 5 raised-strip tables in frame (%dx%d)" % [raised, size.x, size.y])
	root.size = Vector2i(1080, 1920)

	print("follow")
	await follow_walk()
	await stairs_shake()

	print("framing")
	for a in FRAMING:
		var m := zone_marker(a)
		check(m != null and is_equal_approx(float(m.get_meta("pitch")), FRAMING[a][0]) and is_equal_approx(float(m.get_meta("dist")), FRAMING[a][1]),
			"%s view: pitch %s, distance %s (want %s, %s)" % [a, m.get_meta("pitch") if m else "?", m.get_meta("dist") if m else "?", FRAMING[a][0], FRAMING[a][1]])
	for a in AREA_SPOTS:
		teleport(AREA_SPOTS[a])
		await frames(10)
		var cam: Camera3D = rig.camera
		var r := root.get_visible_rect()
		var h := (cam.unproject_position(p.global_position) - cam.unproject_position(p.global_position + Vector3(0, 1.35, 0))).length() * 800.0 / r.size.y
		check(rig.view == a and h >= (MIN_HEIGHT_SMOKING if a == "smoking" else MIN_HEIGHT_PX), "standing in the %s (view %s): the character is %.0f px tall of 800" % [a, rig.view, h])

	print("areas")
	for a in main.hud.AREAS:
		await area_button(a[0], main.area_zone(a[0]).get("kind", "?"))

	print("smoking room")
	var tables := ["Smoke0", "Smoke1", "Smoke2", "Smoke3"]
	for at in [Vector3(36.6, 0.1, 11.6), Vector3(39.6, 0.1, 11.9), Vector3(41.0, 0.1, 11.3)]:
		teleport(at)
		await frames(40)
		var shown := 0
		var hid := []
		for t in tables:
			var top := (main.get_node("Venue").find_child(t, true, false) as Node3D).global_position + Vector3(0, 0.9, 0)
			var w := standing_between(rig.global_position, top)
			shown += int(on_screen(top, 0.0) and w.is_empty())
			hid.append_array(w)
		check(rig.view == "smoking" and on_screen(p.global_position + Vector3(0, 0.9, 0), 0.04) and shown == 4,
			"from the main room at %s: the smoking view (%s), the player and %d of 4 tables in sight%s" % [v2(at), rig.view, shown, "" if hid.is_empty() else " (behind %s)" % [hid]])
	for at in [Vector3(40.0, 0.1, 15.2), Vector3(39.0, 0.1, 13.6), Vector3(41.1, 0.1, 13.7), Vector3(39.0, 0.1, 17.3), Vector3(41.2, 0.1, 17.3)]:
		teleport(at)
		await frames(40)
		var walls := standing_between(rig.global_position, p.global_position + Vector3(0, 1.1, 0))
		check(rig.view == "smoking" and on_screen(p.global_position + Vector3(0, 0.9, 0), 0.04) and walls.is_empty(),
			"inside at %s: player in sight%s" % [v2(at), "" if walls.is_empty() else " but behind " + ", ".join(walls)])
	for leg in [[Vector3(30.0, 0.1, 9.0), Vector3(40.0, 0, 15.2)], [Vector3(41.0, 0.1, 6.0), Vector3(39.0, 0, 16.5)], [Vector3(40.0, 0.1, 15.2), Vector3(36.6, 0, 11.4)]]:
		teleport(leg[0])
		await frames(20)
		p.walk_to(leg[1])
		var hidden := 0
		var off := 0
		var n_frames := 0
		var blockers := {}
		for i in 1500:
			await process_frame
			n_frames += 1
			off += int(not on_screen(p.global_position + Vector3(0, 0.9, 0), 0.0))
			var walls := standing_between(rig.global_position, p.global_position + Vector3(0, 1.1, 0))
			if not walls.is_empty():
				hidden += 1
				for w in walls:
					blockers[w] = true
			if not p.walking_to:
				break
		check(hidden <= 2 and off == 0, "walk %s -> %s: in sight %d of %d frames%s" % [v2(leg[0]), v2(leg[1]), n_frames - hidden, n_frames, "" if blockers.is_empty() else " (behind %s)" % [blockers.keys()]])

	print("walls")
	var venue: Node3D = main.get_node("Venue")
	await corner("main room NW (top-left)", Vector3(23.2, 0.1, 2.6), ["WestTable0", "WestTable1"])
	await corner("main room SW (bottom-left)", Vector3(22.0, 0.1, 10.3), ["OpeningTall0", "OpeningTall1"])
	await corner("meeting room (buffer zone)", Vector3(17.7, 0.1, 5.3), ["BufferTall0", "BufferTall1", "BufferTall2", "BufferTall3"])
	await corner("lounge, middle", Vector3(8.0, 0.1, 6.0), ["LongTable", "LoungeTable0"])
	await corner("lounge, north-east", Vector3(11.5, 0.1, 2.6), ["MerchStand", "CollectiblesShelf"])   # the merch shop since the lounge revamp
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

	print("occlusion")
	for gi in main.find_children("*", "GeometryInstance3D", true, false):
		if not p.is_ancestor_of(gi) and not in_figure(gi):
			geoms.append(gi)
	for r in OCCL_ROUTES:
		await occlusion_walk(r[0], r[1], r[2])

	print("\n%s (%d failures)" % ["PASS" if fails.is_empty() else "FAIL", fails.size()])
	quit(0 if fails.is_empty() else 1)


## Area button `area` pressed in the middle of the main room: see the header.
func area_button(area: String, kind: String) -> void:
	var rig: CameraRig = p.rig
	teleport(Vector3(30.0, 0.1, 7.0))
	await frames(30)
	var want := zone_marker(area)
	main.walk_to_area(area)
	await frames(2)
	var off := 0
	var steps := 0
	var jump := 0.0
	var last_cam := rig.global_position
	for i in 2400:
		await physics_frame
		steps += 1
		off += int(not on_screen(p.global_position + Vector3(0, 0.9, 0), 0.0))
		jump = maxf(jump, rig.global_position.distance_to(last_cam))
		last_cam = rig.global_position
		if not p.walking_to:
			break
	await frames(3)
	var sheet_ok: bool = is_instance_valid(main.sheet) and main.sheet_zone.get("kind", "") == kind
	main.close_sheet()
	await frames(120)
	var portrait := root.get_visible_rect().size.aspect() < 1.0
	var dist: float = want.get_meta("dist") * (1.0 if portrait else rig.landscape_dist_scale)
	var c: Rect2 = want.get_meta("clamp")
	var look := rig.global_position - rig.global_basis.z * dist   # the look point, in front of the camera
	var framed := rig.zone == area and rig.view == area and rig.focus == "" \
		and absf(angle_difference(rig.yaw, deg_to_rad(want.get_meta("yaw")))) < deg_to_rad(1.5) \
		and absf(angle_difference(rig._pitch, deg_to_rad(want.get_meta("pitch")))) < deg_to_rad(1.5) and absf(rig._dist - dist) < 0.1 \
		and c.grow(0.15).has_point(Vector2(look.x, look.z))
	check(sheet_ok and rig.area_at(p.global_position) == area, "%s button: walked into the area (%s), its %s sheet opened" % [area, rig.area_at(p.global_position), kind])
	check(off == 0 and jump < 0.3, "  player on screen all the walk (%d of %d frames off), no camera jumps (%.2f m)" % [off, steps, jump])
	check(framed and on_screen(p.global_position + Vector3(0, 0.9, 0), 0.04), "  camera settled on the %s framing (view %s, yaw %.0f°)" % [area, rig.view, rad_to_deg(rig.yaw)])


func zone_marker(nm: String) -> Node3D:
	for z in get_nodes_in_group("camera_zone"):
		if z.name.to_lower() == nm:
			return z
	return null


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


## Joystick walk east across the floor and stop: see FOLLOW_TRAIL, FOLLOW_NEAR, SHAKE_MAX.
func follow_walk() -> void:
	var rig: CameraRig = p.rig
	teleport(Vector3(23.0, 0.1, 6.7))
	await frames(30)
	var trail := 0.0
	var near := 0.0
	var shake := 0.0
	var last := rig.global_position
	var step := Vector3.ZERO
	js.value = p.world_to_input(Vector3(1, 0, 0))
	for i in 150:
		await physics_frame
		var d := Vector3(rig._look.x - p.global_position.x, 0, rig._look.z - p.global_position.z)
		var v := p.get_real_velocity()
		if Vector2(v.x, v.z).length() > 0.5:
			trail = maxf(trail, -d.dot(Vector3(v.x, 0, v.z).normalized()))
			near = maxf(near, d.length())
		if i > 0:
			shake = maxf(shake, (rig.global_position - last - step).length())
		step = rig.global_position - last
		last = rig.global_position
	js.value = Vector2.ZERO
	var back := -1.0
	for i in 60:
		await physics_frame
		shake = maxf(shake, (rig.global_position - last - step).length())
		step = rig.global_position - last
		last = rig.global_position
		if back < 0.0 and Vector2(rig._look.x - p.global_position.x, rig._look.z - p.global_position.z).length() < 0.15:
			back = (i + 1) / float(Engine.physics_ticks_per_second)
	check(rig.view == "floor" and trail <= FOLLOW_TRAIL, "walking the floor the look point trails the player by at most %.2f m (bound %.2f)" % [trail, FOLLOW_TRAIL])
	check(near <= FOLLOW_NEAR, "  and stays within %.2f m of them (bound %.2f)" % [near, FOLLOW_NEAR])
	check(back > 0.0 and back <= 0.8, "  back on the player %.2f s after the stop (bound 0.8)" % back)
	check(shake <= SHAKE_MAX, "  no shake at the start and the stop (largest step change %.3f m per tick)" % shake)


## Up both stair flights: the camera's step changes smoothly (no shake from the treads).
func stairs_shake() -> void:
	var rig: CameraRig = p.rig
	teleport(Vector3(9.0, 0.1, 12.25))
	await frames(30)
	var shake := 0.0
	var last := rig.global_position
	var step := Vector3.ZERO
	var n := 0
	for goal in [Vector3(3.2, 0, 12.25), Vector3(3.15, 0, 7.6)]:
		for i in 400:
			var d: Vector3 = goal - p.global_position
			d.y = 0
			if d.length() < 0.2:
				break
			js.value = p.world_to_input(d.normalized())
			await physics_frame
			if n > 0:
				shake = maxf(shake, (rig.global_position - last - step).length())
			step = rig.global_position - last
			last = rig.global_position
			n += 1
	js.value = Vector2.ZERO
	check(p.global_position.y > 2.0 and shake <= SHAKE_MAX * 2.0, "  climbing the stairs: largest step change %.3f m per tick (bound %.3f)" % [shake, SHAKE_MAX * 2.0])


## Tap-walks along `goals` from `start`: the sight line from the camera to the player's chest and head stays clear.
func occlusion_walk(label: String, start: Vector3, goals: Array) -> void:
	teleport(start)
	await frames(20)
	var n := 0
	var hid := 0
	var by := {}
	for g in goals:
		p.walk_to(g)
		for i in 1500:
			await physics_frame
			if i % 2 == 0:
				n += 1
				var b := sight_blockers()
				if not b.is_empty():
					hid += 1
					for nm in b:
						by[nm] = by.get(nm, 0) + 1
			if not p.walking_to:
				break
	check(hid == 0, "%s walk: the player in clear sight %d of %d ticks%s" % [label, n - hid, n, "" if by.is_empty() else " (hidden by %s)" % [by]])


## Visible meshes (by their own box) on the camera -> chest or camera -> head line.
func sight_blockers() -> Array:
	var cam: Camera3D = p.rig.camera
	var a := cam.global_position
	var out := []
	for e in [p.global_position + Vector3(0, 0.8, 0), p.global_position + Vector3(0, 1.25, 0)]:
		for g in geoms:
			if not is_instance_valid(g) or not g.is_visible_in_tree() or (g.layers & cam.cull_mask) == 0:
				continue
			var box := g.get_aabb()
			if box.size.y < 0.05 or (box.size.x < 0.02 and box.size.z < 0.02):
				continue
			if not (g.global_transform * box).intersects_segment(a, e):
				continue
			var inv := g.global_transform.affine_inverse()
			if box.intersects_segment(inv * a, inv * e):
				var nm := "%s/%s" % [g.get_parent().name, g.name]
				if not out.has(nm):
					out.append(nm)
	return out


## True when the node is part of a character (crowd, staff, regulars): they may walk in front of the player.
func in_figure(n: Node) -> bool:
	var q := n.get_parent()
	while q != null and q != main:
		if q is PatronFigure:
			return true
		q = q.get_parent()
	return false
