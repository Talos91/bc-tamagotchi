extends SceneTree
## Headless smoke test: loads main.tscn and walks the player with the joystick along Daniele's route (plan v4): lobby
## spawn, entrance corridor, Sticker door, up the lounge's east side, through the buffer zone into the main room, along
## the aisle past Mali's row, then up the 15 cm step onto the raised strip in the east. Stick input is camera-relative.
##   godot --headless --path . --script res://tests/smoke_stairs.gd

func _init() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var p: Player = main.get_node("Player")
	var js: TouchJoystick = main.get_node("UI/Joystick")
	await process_frame
	# Waypoints: lounge, curtain, aisle between the table rows, stage steps, onto the stage
	var legs := [Vector3(1.1, 0, 14.0), Vector3(13.6, 0, 14.1), Vector3(13.6, 0, 12.0), Vector3(14.3, 0, 5.3), Vector3(17.7, 0, 5.3),
		Vector3(22.5, 0, 6.5), Vector3(30.0, 0, 6.7), Vector3(38.6, 0, 3.0), Vector3(40.3, 0.15, 2.2)]
	for t in legs:
		for i in 1500:
			var d: Vector3 = t - p.global_position
			d.y = 0
			if d.length() < 0.25:
				break
			js.value = p.world_to_input(d.normalized())
			await physics_frame
	js.value = Vector2.ZERO
	for i in 30:
		await physics_frame
	print("final pos: ", p.global_position)
	var ok := p.global_position.x > 39.6 and p.global_position.z < 3.0 and p.global_position.y > 0.1
	print("SMOKE ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
