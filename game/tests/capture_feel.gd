extends SceneTree
## Real-window screenshots for the feel pass (Daniele's playtest of 33dc5b9; not a pass/fail test): the main room's
## north-west (top-left) and south-west (bottom-left) corners, the buffer zone ("meeting room"), the floor, a seat at
## the bar and one at Prae's table (both taken through the game's own "Take a stool" / "Sit" rows), the lounge and
## the entrance corridor (its rule is unchanged), plus a close-up of each seated player taken from in front of the seat
## (along the seat's own yaw, so a figure turned the wrong way shows its side or back). HUD hidden. Uses only API that predates the pass, so the same run
## on an older build gives the "before" pictures. From game/, one size per run:
##   godot --path . --resolution 1080x1920 --script res://tests/capture_feel.gd -- --tag=portrait
##   godot --path . --resolution 1920x1080 --script res://tests/capture_feel.gd -- --tag=landscape
## Writes <prefix><tag>-<shot>.png to docs/art/screens/feel/ (--out=DIR, --prefix=before-).

const SHOTS := [
	{"name": "nw-corner", "player": Vector3(23.2, 0.1, 2.6), "yaw": -0.6},
	{"name": "sw-corner", "player": Vector3(22.0, 0.1, 10.3), "yaw": -2.4},
	{"name": "meeting-room", "player": Vector3(17.7, 0.1, 5.3), "yaw": PI},
	{"name": "floor", "player": Vector3(30.0, 0.1, 6.7), "yaw": PI * 0.5},
	{"name": "lounge", "player": Vector3(7.5, 0.1, 6.5), "yaw": -PI * 0.5},
	{"name": "corridor", "player": Vector3(8.0, 0.1, 14.1), "yaw": PI * 0.5},
]

var out := "res://../docs/art/screens/feel"
var tag := "portrait"
var prefix := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--prefix="):
			prefix = a.substr(9)
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(nm: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := out.path_join("%s%s-%s.png" % [prefix, tag, nm])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_feel_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	main.get_node("UI").visible = false
	var p: Player = main.player
	var body: Node3D = p.get_node("Body")
	for s in SHOTS:
		p.stand_up()
		p.walking_to = false
		p.global_position = s.player
		p.velocity = Vector3.ZERO
		body.global_rotation = Vector3(0, s.yaw, 0)
		p.rig.snap()
		await _wait(1.2)
		await _shot(s.name)
	# Seats through the game's own rows: walk from the zone's approach point, sit down, then the camera settles
	var sess: VenueSession = main.session
	for n in ["sit-bar", "sit-table"]:
		p.stand_up()
		var z: Dictionary = main.zones.first_of("table" if n == "sit-table" else "bar", n == "sit-table")
		p.global_position = z["approach"] + Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
		p.rig.snap()
		await _wait(0.3)
		sess.do_row(z, "sit" if n == "sit-table" else "stool")
		for i in 600:
			await process_frame
			if p.seated:
				break
		await _wait(1.5)
		await _shot(n)
		# Close-up from in front of the seat (its own yaw, 30° to the side, from above the table): the face should look at the table / bar
		var yaw: float = float(p.seat.get("yaw", 0.0))
		print(n, ": seated ", p.seated, " at ", p.seat.get("node", null), " seat yaw ", rad_to_deg(yaw), " body world yaw ", rad_to_deg(body.global_rotation.y))
		var side := Vector3(sin(yaw), 0, cos(yaw)).rotated(Vector3.UP, 0.5)
		var cam := Camera3D.new()
		main.add_child(cam)
		cam.fov = 42.0
		cam.keep_aspect = Camera3D.KEEP_HEIGHT if root.get_visible_rect().size.aspect() >= 1.0 else Camera3D.KEEP_WIDTH
		var back := 2.0 if n == "sit-bar" else 3.2   # the bar back wall is 2.8 m behind the stools
		cam.look_at_from_position(p.global_position + side * back + Vector3(0, 2.1 if n == "sit-bar" else 2.3, 0), p.global_position + Vector3(0, 0.6, 0))
		cam.make_current()
		await _wait(0.4)
		await _shot(n + "-close")
		p.rig.camera.make_current()
		cam.queue_free()
	quit()
