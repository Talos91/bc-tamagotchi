extends SceneTree
## Walk-stuck test (owner feedback 2026-11-04, item 18: "walking between tables often gets the character stuck").
## Samples many start / goal pairs on the venue's navmesh around the furniture Daniele named (the lounge tables, the
## long table, the bar stools, the buffer room's tall tables) and the rest of the main room, and tap-walks the real
## Player (walk_to, pure pursuit on the NavigationAgent3D path, move_and_slide against the real colliders) from each
## start to each goal. A walk fails when it ends more than MAX_SHORT metres short of its goal or stalls (moves less
## than STALL_MOVE in STALL_TIME while still walking, or runs past its time budget: 1.5 x the navmesh path's walking
## time + 4 s).
## The goals are the approach points of the seat spots (group "seat", the point Player.sit_at walks to), snapped to the
## navmesh; the starts are random navmesh points in the same room, 1.5 to 9 m away (fixed seed). Pairs whose navmesh
## path does not reach the goal (an island) are counted apart as "unreachable" and also fail.
## The player is stepped by hand (FIXED_DT per step, many steps per physics frame) so the run is not tied to real
## time; doors are not crossed (start and goal are in the same room).
## A second section holds the stick straight at a goal 3 to 6 m away for 2 s (what a player does) and counts wedges:
## the stick held, the figure not moving (under a fifth of walking speed) for 0.5 s or more while a short way round
## exists from where it stands (navmesh path to the goal <= WEDGE_DETOUR x the straight line + 1 m: a table or chairs
## in between). A longer way round is a wall the player walks round on purpose (the stage's front row of tiny tables,
## a dead end between two table groups), so a stop there is right; such pairs are skipped up front and such stops are
## counted apart as "walls". Fails over MAX_WEDGE_SHARE.
##   godot --headless --path . --script res://tests/test_walk.gd [-- --list] [-- --seed=N]

const MAX_SHORT := 0.3
const STALL_TIME := 3.0
const STALL_MOVE := 0.1
const FIXED_DT := 1.0 / 60.0
const STEPS_PER_FRAME := 120
const STARTS_PER_GOAL := 3
const MAX_WEDGE_SHARE := 0.02
const WEDGE_DETOUR := 1.5

const LOUNGE := Rect2(2.35, 0.0, 13.1, 13.05)
const BUFFER := Rect2(15.45, 3.0, 4.65, 4.6)
const MAIN := Rect2(20.1, 0.0, 21.7, 12.85)   # main room without the smoking room and the corridor side
const ROOMS := {"lounge": LOUNGE, "buffer": BUFFER, "main": MAIN}

var fails: Array[String] = []
var p: Player
var nav_map: RID
var rng := RandomNumberGenerator.new()


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
	p = main.player
	p.set_physics_process(false)    # stepped by hand below
	p.rig.set_process(false)
	nav_map = p.get_world_3d().navigation_map
	var list := OS.get_cmdline_user_args().has("--list")
	rng.seed = 1104
	var cap := 1000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			rng.seed = int(a.substr(7))
		if a.begins_with("--max="):
			cap = int(a.substr(6))
	var t0 := Time.get_ticks_msec()

	# Goals: seat approach points, by the furniture group they belong to
	var goals := {"lounge tables": [], "long table": [], "bar stools": [], "buffer tables": [], "main room tables": []}
	for s in get_nodes_in_group("seat"):
		var n := s as Node3D
		var table := str(n.get_meta("table", ""))
		var flat := Vector2(n.global_position.x, n.global_position.z)
		var cat := ""
		if table.to_lower().contains("long"):
			cat = "long table"
		elif table == "Bar":
			cat = "bar stools"
		elif BUFFER.has_point(flat):
			cat = "buffer tables"
		elif LOUNGE.has_point(flat):
			cat = "lounge tables"
		elif MAIN.has_point(flat):
			cat = "main room tables"
		else:
			continue
		var fwd := Basis(Vector3.UP, n.global_rotation.y) * Vector3(0, 0, 1)
		var couch := bool(n.get_meta("couch", false))
		var approach := n.global_position + fwd * (0.7 if couch else -0.45)
		var g := NavigationServer3D.map_get_closest_point(nav_map, approach)
		goals[cat].append({"name": n.name, "goal": g, "room": _room_of(Vector2(g.x, g.z))})

	print("walk-stuck: tap-walks from random navmesh starts to seat approach points")
	var total := 0
	var bad := 0
	var worst: Array = []
	for cat in goals:
		var n_walk := 0
		var n_fail := 0
		var n_stall := 0
		var n_unreach := 0
		var shorts: Array[float] = []
		for g in (goals[cat] as Array).slice(0, cap):
			if g["room"] == "":
				continue
			for k in STARTS_PER_GOAL:
				var start := _random_start(g["room"], g["goal"])
				if start == Vector3.INF:
					continue
				var path := NavigationServer3D.map_get_path(nav_map, start, g["goal"], true)
				var r := {}
				if path.size() == 0 or _flat_d(path[path.size() - 1], g["goal"]) > MAX_SHORT:
					r = {"short": INF, "stall": false, "unreach": true}
				else:
					r = await _tap_walk(start, g["goal"])
				n_walk += 1
				var short: float = r["short"]
				var failed: bool = r.get("unreach", false) or r["stall"] or short > MAX_SHORT
				if r.get("unreach", false):
					n_unreach += 1
				elif r["stall"]:
					n_stall += 1
				if not r.get("unreach", false):
					shorts.append(short)
				if failed:
					n_fail += 1
					worst.append([short, "%s %s from (%.2f, %.2f) to (%.2f, %.2f): short %.2f m%s%s" % [cat, g["name"], start.x, start.z,
						g["goal"].x, g["goal"].z, short, " STALL" if r["stall"] else "", " UNREACHABLE" if r.get("unreach", false) else ""]])
				elif list:
					print("    %s %s short %.2f" % [cat, g["name"], short])
		var mean := 0.0
		var mx := 0.0
		for s in shorts:
			mean += s
			mx = maxf(mx, s)
		mean /= maxf(shorts.size(), 1)
		print("  [%d ms]" % (Time.get_ticks_msec() - t0))
		print("  %-17s walks %3d  failed %3d  stalls %3d  unreachable %2d  short mean %.3f max %.2f m" % [cat, n_walk, n_fail, n_stall, n_unreach, mean, mx])
		total += n_walk
		bad += n_fail
	worst.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(worst.size(), 25):
		print("    ", worst[i][1])
	check(total > 300, "enough walks sampled: %d" % total)
	check(bad == 0, "no tap-walk stops short (> %.1f m) or stalls: %d of %d failed" % [MAX_SHORT, bad, total])

	print("walk-stuck: stick held straight at a goal 3 to 6 m away, 2 s")
	var wedges := 0
	var walls := 0
	var sticks := 0
	var wlist: Array[String] = []
	for cat in goals:
		for g in goals[cat]:
			if g["room"] == "":
				continue
			var start := _random_start(g["room"], g["goal"], 3.0, 6.0)
			if start == Vector3.INF:
				continue
			if not _short_way(start, g["goal"]):
				continue
			sticks += 1
			var w: float = await _stick_walk(start, g["goal"])
			if w >= 0.5 and not _short_way(p.global_position, g["goal"]):
				walls += 1
			elif w >= 0.5:
				wedges += 1
				wlist.append("%s %s from (%.2f, %.2f): wedged %.1f s" % [cat, g["name"], start.x, start.z, w])
	for l in wlist.slice(0, 15):
		print("    ", l)
	print("  stick walks %d, wedged (stick held, no motion >= 0.5 s, short way round) %d (%.1f %%), stopped at a wall %d" % [sticks, wedges, 100.0 * wedges / maxf(sticks, 1), walls])
	check(float(wedges) / maxf(sticks, 1) <= MAX_WEDGE_SHARE, "stick wedges <= %.0f %%: %d of %d" % [MAX_WEDGE_SHARE * 100.0, wedges, sticks])

	print("test_walk: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


func _room_of(f: Vector2) -> String:
	for r in ROOMS:
		if (ROOMS[r] as Rect2).has_point(f):
			return r
	return ""


func _flat_d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## True when the navmesh way from `a` to `b` is at most WEDGE_DETOUR x the straight line + 1 m.
func _short_way(a: Vector3, b: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(nav_map, a, b, true)
	if path.size() < 2 or _flat_d(path[path.size() - 1], b) > MAX_SHORT:
		return false
	var length := 0.0
	for k in path.size() - 1:
		length += _flat_d(path[k], path[k + 1])
	return length <= _flat_d(a, b) * WEDGE_DETOUR + 1.0


func _random_start(room: String, goal: Vector3, dmin := 1.5, dmax := 9.0) -> Vector3:
	var rect: Rect2 = ROOMS[room]
	for t in 200:
		var q := Vector3(rng.randf_range(rect.position.x, rect.end.x), goal.y + 0.5, rng.randf_range(rect.position.y, rect.end.y))
		var c := NavigationServer3D.map_get_closest_point(nav_map, q)
		if absf(c.y - goal.y) > 0.3 or _flat_d(c, q) > 0.05:
			continue
		var d := _flat_d(c, goal)
		if d < dmin or d > dmax:
			continue
		var path := NavigationServer3D.map_get_path(nav_map, c, goal, true)
		if path.size() == 0 or _flat_d(path[path.size() - 1], goal) > MAX_SHORT:
			continue   # another island (a table top); not a start the player can stand on
		return c
	return Vector3.INF


func _place(start: Vector3) -> void:
	p.stand_up()
	p.walking_to = false
	p.joystick.value = Vector2.ZERO
	p.velocity = Vector3.ZERO
	p.global_position = start + Vector3(0, 0.02, 0)
	for i in 3:
		p._physics_process(FIXED_DT)


## One tap-walk, stepped by hand. Returns {short, stall}.
func _tap_walk(start: Vector3, goal: Vector3) -> Dictionary:
	await physics_frame
	_place(start)
	p.walk_to(goal)
	var path := NavigationServer3D.map_get_path(nav_map, start, goal, true)
	var length := 0.0
	for k in path.size() - 1:
		length += _flat_d(path[k], path[k + 1])
	var budget := int((length * 1.5 / p.speed + 4.0) / FIXED_DT)   # time budget from the path, not the straight line
	var steps := 0
	var mark := p.global_position
	var mark_t := 0
	var stall := false
	while p.walking_to:
		p._physics_process(FIXED_DT)
		steps += 1
		if steps - mark_t >= int(STALL_TIME / FIXED_DT):
			if _flat_d(p.global_position, mark) < STALL_MOVE:
				stall = true
				break
			mark = p.global_position
			mark_t = steps
		if steps > budget:
			stall = true
			break
		if steps % STEPS_PER_FRAME == 0:
			await physics_frame
	return {"short": _flat_d(p.global_position, goal), "stall": stall}


## Stick held straight at the goal for 2 s; returns the longest time the figure stood still with the stick held
## while it was still more than 0.6 m from the goal (a wedge: no slide along the obstacle).
func _stick_walk(start: Vector3, goal: Vector3) -> float:
	await physics_frame
	_place(start)
	var still := 0.0
	var longest := 0.0
	for i in int(2.0 / FIXED_DT):
		var d := goal - p.global_position
		if Vector2(d.x, d.z).length() < 0.6:
			break
		p.joystick.value = p.world_to_input(Vector3(d.x, 0, d.z).normalized())
		var before := p.global_position
		p._physics_process(FIXED_DT)
		if _flat_d(before, p.global_position) < 0.2 * p.speed * FIXED_DT:
			still += FIXED_DT
			longest = maxf(longest, still)
		else:
			still = 0.0
	p.joystick.value = Vector2.ZERO
	return longest
