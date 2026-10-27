extends SceneTree
## Headless smoke test: loads main.tscn and walks the player with the joystick from the lounge spawn, through the
## curtain and down the z 5.5 aisle of the main room, up the ramp onto the stage. Stick input is camera-relative.
##   godot --headless --path . --script res://tests/smoke_stairs.gd

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var p: Player = main.get_node("Player")
	var js: TouchJoystick = main.get_node("UI/Joystick")
	await process_frame
	# Waypoints: lounge, curtain, aisle between the table rows, stage steps, onto the stage
	var legs := [Vector3(7.0, 0, 5.8), Vector3(12.0, 0, 5.6), Vector3(21.0, 0, 5.5), Vector3(22.8, 0, 5.5), Vector3(24.6, 0, 5.5)]
	for t in legs:
		for i in 900:
			var d: Vector3 = t - p.global_position
			d.y = 0
			if d.length() < 0.25:
				break
			js.value = p.rig.world_to_input(d.normalized())
			await physics_frame
	js.value = Vector2.ZERO
	for i in 30:
		await physics_frame
	print("final pos: ", p.global_position)
	var ok := p.global_position.x > 23.0 and p.global_position.y > 0.4
	print("SMOKE ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
