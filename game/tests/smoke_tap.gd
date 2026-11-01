extends SceneTree
## Headless smoke test: tap-to-move. Loads main.tscn, sends the player from the lobby through the lounge and buffer to
## the floor, the bar, the stage and the smoking room along the navmesh (as a floor tap would), then taps the screen
## centre; checks arrival and the camera zone changes, and that the patron crowd spawned (30-120 figures, a bartender,
## someone seated in at least four seating zones).
##   godot --headless --path . --script res://tests/smoke_tap.gd

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var p: Player = main.get_node("Player")
	for i in 3:
		await physics_frame
	var zones := {}
	var ok := true
	for goal in [Vector3(30.0, 0, 6.7), Vector3(29.6, 0, 11.3), Vector3(30.75, 0, 2.5), Vector3(40.0, 0, 15.2), Vector3(6.0, 0, 10.8)]:
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
	# A tap on a table (or the chip that walks to Prae's) must end with its sheet open. The agent stops short of a table's
	# nav hole and the feet can stay just outside the zone circle: that still counts as arrived (main.ARRIVE_SLACK).
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	await process_frame
	var tapped_sheets := 0
	var tap_goals := ["table:Table2", "table:Table0", "table:Table4", "table:Tiny4", "table:HighCounter", "tall:BufferTall1"]
	for id in tap_goals:
		var z: Dictionary = main.zones.by_id(id)
		main.close_sheet()
		await process_frame
		p.stand_up()
		p.global_position = Vector3(24.0, 0.1, 7.0)
		p.velocity = Vector3.ZERO
		p.walking_to = false
		main.pending_zone = ""
		for i in 3:
			await physics_frame
		main._on_world_tap(z["approach"])
		for i in 1800:
			await physics_frame
			if is_instance_valid(main.sheet) or not p.walking_to:
				break
		await process_frame
		var up: bool = is_instance_valid(main.sheet) and main.sheet_zone.get("id", "") == id
		print("tap on ", id, ": sheet ", up, " gap ", snappedf(VenueZones.gap(z, p.global_position), 0.01))
		ok = ok and up
		tapped_sheets += int(up)
	main.close_sheet()
	await process_frame
	p.stand_up()
	p.global_position = Vector3(24.0, 0.1, 7.0)
	p.walking_to = false
	main.pending_zone = ""
	for i in 3:
		await physics_frame
	main.walk_to_kind("table")   # the "Prae's table" chip
	for i in 1800:
		await physics_frame
		if is_instance_valid(main.sheet) or not p.walking_to:
			break
	await process_frame
	var chip_up: bool = is_instance_valid(main.sheet) and main.sheet_zone.get("regular", "") == "mali" and main.sheet.buttons.has("talk")
	print("Prae's table chip: Candle Talk sheet open ", chip_up)
	ok = ok and chip_up
	main.close_sheet()
	await process_frame
	print("zones seen: ", zones.keys())
	ok = ok and zones.has("lounge") and zones.has("floor") and zones.has("bar") and zones.has("stage")
	var crowd: Array = main.get_node("Venue/Patrons").figures
	var seated_zones := {}
	for f in crowd:
		if f.state == "sit" and str(f.name).begins_with("Patron"):
			seated_zones[str(f.name).get_slice("_", 1)] = true
	print("patrons: ", crowd.size(), " presets: ", crowd.filter(func(f): return f.is_preset()).size(), " seated zones: ", seated_zones.keys())
	ok = ok and crowd.size() >= 30 and crowd.size() <= 120 and main.has_node("Venue/Patrons/Bartender") and seated_zones.size() >= 4
	print("SMOKE TAP ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
