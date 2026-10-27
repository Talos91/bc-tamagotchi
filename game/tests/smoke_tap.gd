extends SceneTree
## Headless smoke test: tap-to-move. Loads main.tscn, sends the player from the lounge to the stage along the
## navmesh (as a floor tap would), then taps the screen centre; checks arrival and the camera zone changes, and that
## the patron crowd spawned (10-14 figures, a bartender, someone seated in every seating zone).
##   godot --headless --path . --script res://tests/smoke_tap.gd

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var p: Player = main.get_node("Player")
	for i in 3:
		await physics_frame
	var zones := {}
	var ok := true
	for goal in [Vector3(16.0, 0, 5.0), Vector3(16.6, 0, 7.6), Vector3(26.5, 0.5, 5.0), Vector3(4.0, 0, 6.5)]:
		p.walk_to(goal)
		for i in 1800:
			await physics_frame
			zones[p.rig.zone] = true
			if not p.walking_to:
				break
		var miss := Vector2(p.global_position.x - goal.x, p.global_position.z - goal.z).length()
		print("goal ", goal, " reached ", p.global_position.snapped(Vector3.ONE * 0.01), " miss ", snappedf(miss, 0.01), " zone ", p.rig.zone)
		ok = ok and miss < 0.6
	# A tap on the middle of the screen must land on the navmesh and start a walk
	await process_frame
	var tapped := p.tap_at(root.get_visible_rect().size * 0.5)
	print("tap at screen centre: ", tapped, " walking ", p.walking_to)
	ok = ok and tapped and p.walking_to
	print("zones seen: ", zones.keys())
	ok = ok and zones.has("lounge") and zones.has("floor") and zones.has("bar") and zones.has("stage")
	var crowd: Array = main.get_node("Venue/Patrons").figures
	var seated_zones := {}
	for f in crowd:
		if f.state == "sit":
			seated_zones[str(f.name).get_slice("_", 1)] = true
	print("patrons: ", crowd.size(), " presets: ", crowd.filter(func(f): return f.is_preset()).size(), " seated zones: ", seated_zones.keys())
	ok = ok and crowd.size() >= 10 and crowd.size() <= 14 and main.has_node("Venue/Patrons/Bartender") and seated_zones.size() == 5
	print("SMOKE TAP ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
