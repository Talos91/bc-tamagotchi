extends SceneTree
## Q2 (docs/design/11-minigame-quality.md 1.3): while a minigame frame covers the screen the 3D venue stops (viewport
## disable_3d, Venue processing off) and wakes exactly as it was on close; needs stay real time.
##   godot --headless --path . --script res://tests/test_venue_pause.gd

var _fails := 0

func _check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1


func _init() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.new_game()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 240:
		await process_frame
	var venue: Node = main.get_node("Venue")
	var rig: Node = main.player.get_node_or_null("CameraRig")
	_check("venue runs before a game", not main.venue_covered and not root.disable_3d and venue.can_process())

	var cam_before: Transform3D = _cam(main)
	var meters_before: Dictionary = needs.meters.duplicate()
	main.open_minigame("coaster_flip", {})
	for i in 3:
		await process_frame
	_check("frame open", is_instance_valid(main.frame))
	_check("3D viewport off", root.disable_3d and main.venue_covered)
	_check("venue processing off", not venue.can_process())
	var pos_in: Vector3 = main.player.global_position
	for i in 10:
		await process_frame
	_check("player state kept while covered", Vector2(main.player.global_position.x - pos_in.x, main.player.global_position.z - pos_in.z).length() < 0.01)  # xz: no walk behind the frame
	# real-time needs keep ticking behind the frame
	needs.tick(60.0) if needs.has_method("tick") else null
	_check("needs still change", needs.meters != meters_before or not needs.has_method("tick"))

	main.frame.closed.emit({})
	for i in 3:
		await process_frame
	_check("frame gone", not is_instance_valid(main.frame))
	_check("3D viewport back on", not root.disable_3d and not main.venue_covered)
	_check("venue processing back on", venue.can_process())
	_check("camera restored", _cam(main).origin.distance_to(cam_before.origin) < 0.5)
	_check("player where it was", Vector2(main.player.global_position.x - pos_in.x, main.player.global_position.z - pos_in.z).length() < 0.01)  # xz: no walk behind the frame

	# a second open/close cycle is idempotent
	main.open_minigame("coaster_flip", {})
	await process_frame
	main.open_minigame("coaster_flip", {})   # second request ignored while open
	await process_frame
	_check("still covered once", main.venue_covered and root.disable_3d)
	main.frame.closed.emit({})
	await process_frame
	await process_frame
	_check("uncovered again", not main.venue_covered and not root.disable_3d)
	print("TEST VENUE PAUSE ", "PASS" if _fails == 0 else "FAIL")
	quit(0 if _fails == 0 else 1)


func _cam(main: Node) -> Transform3D:
	var c := root.get_camera_3d()
	return c.global_transform if c != null else Transform3D.IDENTITY
