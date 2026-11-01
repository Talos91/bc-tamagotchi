extends SceneTree
## Real-window screenshots for the area camera (Daniele, Questions tab 2026-11-01: "back to a view per area"; not a
## pass/fail test). HUD on, so the area buttons and the version label are in the picture.
##   area-<id>        every area button pressed from the middle of the main room (the lounge's from the floor of the
##                    main room too): the character walks there, the shot is taken once the camera has settled
##   smoking-out-*    the smoking room from the main room: from the west along the south wall, at the red door, and
##                    from the north-east corner by the wine fridge
##   smoking-in-*     inside it: middle, the four corners
##   version          the bottom-right corner of the bar shot, 3x (the version label)
## From game/, one size per run:
##   godot --path . --resolution 1080x1920 --script res://tests/capture_areas.gd -- --tag=portrait
##   godot --path . --resolution 1920x1080 --script res://tests/capture_areas.gd -- --tag=landscape
## Writes <prefix><tag>-<shot>.png to docs/art/screens/area-camera/ (--out=DIR, --prefix=before-, --only=smoking).
## On a build without area buttons (the "before" run) the area shots are skipped.

const STILLS := [
	{"name": "smoking-out-west", "player": Vector3(36.6, 0.1, 11.6), "yaw": PI * 0.5},
	{"name": "smoking-out-door", "player": Vector3(39.6, 0.1, 11.9), "yaw": 0.0},
	{"name": "smoking-out-ne", "player": Vector3(41.0, 0.1, 10.8), "yaw": -PI * 0.75},
	{"name": "smoking-in-middle", "player": Vector3(40.0, 0.1, 15.2), "yaw": PI},
	{"name": "smoking-in-nw", "player": Vector3(39.0, 0.1, 13.6), "yaw": PI * 0.25},
	{"name": "smoking-in-ne", "player": Vector3(41.1, 0.1, 13.7), "yaw": -PI * 0.25},
	{"name": "smoking-in-sw", "player": Vector3(39.0, 0.1, 17.3), "yaw": PI * 0.75},
	{"name": "smoking-in-se", "player": Vector3(41.2, 0.1, 17.3), "yaw": -PI * 0.75},
]

var out := "res://../docs/art/screens/area-camera"
var tag := "portrait"
var prefix := ""
var only := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--prefix="):
			prefix = a.substr(9)
		elif a.begins_with("--only="):
			only = a.substr(7)
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(nm: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := out.path_join("%s%s-%s.png" % [prefix, tag, nm])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
	return img


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_areas_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	var p: Player = main.player
	var body: Node3D = p.get_node("Body")
	var hud: Control = main.hud
	if only == "" or only == "areas":
		var areas: Array = hud.get_script().get_script_constant_map().get("AREAS", []) if main.has_method("walk_to_area") else []
		for a in areas:
			var id: String = a[0]
			_place(p, body, Vector3(30.0, 0.1, 7.0), PI * 0.5)
			await _wait(0.8)
			main.walk_to_area(id)
			for i in 1200:
				await process_frame
				if not p.walking_to and main.pending_zone == "":
					break
			await _wait(0.2)
			if is_instance_valid(main.sheet):
				main.close_sheet()   # the sheet opens on arrival; the shot is of the framing
			await _wait(1.6)
			var img := await _shot("area-" + id)
			if id == "bar":
				var s := img.get_size()
				var w := int(s.x * 0.34)
				var h := int(s.y * (0.05 if s.y > s.x else 0.08))
				var crop := img.get_region(Rect2i(s.x - w, s.y - h, w, h))
				crop.resize(w * 3, h * 3, Image.INTERPOLATE_NEAREST)
				crop.save_png(out.path_join("%s%s-version.png" % [prefix, tag]))
			await _wait(0.3)
	if only == "" or only == "smoking":
		for s in STILLS:
			_place(p, body, s.player, s.yaw)
			await _wait(1.5)
			await _shot(s.name)
	quit()


func _place(p: Player, body: Node3D, at: Vector3, yaw: float) -> void:
	p.stand_up()
	p.walking_to = false
	p.global_position = at
	p.velocity = Vector3.ZERO
	body.global_rotation = Vector3(0, yaw, 0)
	p.rig.snap()
