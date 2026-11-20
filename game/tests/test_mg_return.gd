extends SceneTree
## Owner list 2026-11-20 item 7: "after playing a match of clap game my character became invisible when i went back to
## the bar", "the character becoming invisible happens with all games". A minigame frame disables the Venue (Q2,
## main._cover_venue), which takes its floor colliders out of physics; the player kept running and fell through the
## floor while the game was up. For each of the 8 games: open through main.open_minigame, play for a while, leave
## through the frame's real path (abandon -> result card -> Done) and check the player is back where it stood (y
## too), visible, on the floor, and can walk.
##   godot --headless --path . --script res://tests/test_mg_return.gd

const VenueSession = preload("res://scripts/zones/venue_session.gd")

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1


func _init() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://test_mg_return_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 120:
		await physics_frame
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	for i in 10:
		await physics_frame
	var p: CharacterBody3D = main.player
	var start: Vector3 = p.global_position
	_check("player on the floor before any game (y %.2f)" % start.y, p.is_on_floor() and start.y > -0.5)
	for gid: String in VenueSession.GAMES:
		main.open_minigame(gid, {})
		for i in 90:   # 1.5 s of physics: far enough to fall through the floor before the fix
			await physics_frame
		var fr: Node = main.frame
		_check("%s: frame open, venue covered" % gid, is_instance_valid(fr) and main.venue_covered)
		fr.game.abandon()
		for i in 5:
			await process_frame
		if is_instance_valid(fr._card):
			fr._card.done.emit()
		for i in 30:
			await physics_frame
		var at: Vector3 = p.global_position
		_check("%s: frame closed, venue back" % gid, not is_instance_valid(main.frame) and not main.venue_covered)
		_check("%s: player where it stood (moved %.3f m, y %.2f)" % [gid, at.distance_to(start), at.y], at.distance_to(start) < 0.05)
		_check("%s: player visible and on the floor" % gid, p.is_visible_in_tree() and p.is_on_floor() and p.can_process())
	# and it still walks
	var dest: Vector3 = main.zones.zones[0]["approach"]
	for z in main.zones.zones:   # the nearest zone that is not right here
		if z["approach"].distance_to(start) > 1.0 and z["approach"].distance_to(start) < dest.distance_to(start):
			dest = z["approach"]
	p.walk_to(dest)
	for i in 90:
		await physics_frame
	_check("player walks after the games (%.2f m)" % Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length(),
		Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length() > 0.2 and p.global_position.y > -0.5)
	print("TEST MG RETURN ", "PASS" if _fails == 0 else "FAIL")
	quit(0 if _fails == 0 else 1)
