extends SceneTree
## Real-window screenshots for the lounge revamp (Daniele 2026-11-02, BACKLOG B7 B9-B11; not a pass/fail test). HUD on.
##   lounge           the lounge from its own view (west), from the middle of the room
##   merch / -sheet   at the merch counter (its own view, north), and its sheet
##   memory           the memory corner and the game machine, top left (their view, north)
##   patrons / -sheet in front of the Top patrons board under the stairs, and its sheet
##   stair-foot       at the foot of the stair: the high counter, records and posters
##   corridor-west / -east  the entrance corridor's portraits, from either end; portrait-<n>-sheet a portrait opened
##   curtain-*        the buffer's open curtains from the main room (west strip, by the opening) and from the buffer
##   area-lounge      the Lounge area button pressed from the middle of the main room
##   portrait-wall    a review camera (not the game's) inside the corridor looking along the portraits
## From game/, one size per run:
##   godot --path . --resolution 1080x1920 --script res://tests/capture_lounge.gd -- --tag=portrait
##   godot --path . --resolution 1920x1080 --script res://tests/capture_lounge.gd -- --tag=landscape
## The window is half size and its viewport renders at the full size (portrait 1080x1920, landscape 1920x1080).
## Writes <prefix><tag>-<shot>.png to docs/art/screens/lounge-revamp/ (--out=DIR, --prefix=before-, --only=a,b).
## Sheets are skipped on a build without their zone (the "before" run).

const STILLS := [
	{"name": "lounge", "player": Vector3(8.0, 0.1, 6.5), "yaw": PI * 0.5},
	{"name": "merch", "player": Vector3(13.6, 0.1, 2.75), "yaw": 0.0, "sheet": "merch"},
	{"name": "memory", "player": Vector3(7.2, 0.1, 1.9), "yaw": 0.0},
	{"name": "patrons", "player": Vector3(4.85, 0.1, 9.1), "yaw": PI * 0.5, "sheet": "patrons"},
	{"name": "stair-foot", "player": Vector3(9.4, 0.1, 11.4), "yaw": PI * 0.5},
	{"name": "corridor-west", "player": Vector3(3.0, 0.1, 14.0), "yaw": -PI * 0.5, "sheet": "portrait:0"},
	{"name": "corridor-east", "player": Vector3(10.2, 0.1, 14.0), "yaw": -PI * 0.5, "sheet": "portrait:6"},
	{"name": "curtain-main-west", "player": Vector3(21.6, 0.1, 5.3), "yaw": PI * 0.5},
	{"name": "curtain-main-strip", "player": Vector3(21.2, 0.1, 9.8), "yaw": 0.0},
	{"name": "curtain-buffer", "player": Vector3(18.2, 0.1, 5.4), "yaw": -PI * 0.5},
]

var out := "res://../docs/art/screens/lounge-revamp"
var tag := "portrait"
var prefix := ""
var only: PackedStringArray = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--prefix="):
			prefix = a.substr(9)
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	# A half-size window whose viewport renders at the full size (the screen is shorter than 1920)
	var full := Vector2i(1080, 1920) if tag == "portrait" else Vector2i(1920, 1080)
	root.size = full / 2
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = full
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
	needs.save_path = "user://capture_lounge_save.json"
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
	for s in STILLS:
		if not only.is_empty() and not only.has(s.name):
			continue
		_place(p, body, s.player, s.yaw)
		await _wait(1.8)
		await _shot(s.name)
		var zid: String = s.get("sheet", "")
		if zid != "" and not main.zones.by_id(zid).is_empty():
			main.open_sheet(main.zones.by_id(zid))
			await _wait(0.5)
			await _shot(("%s-sheet" % zid.replace(":", "-")))
			main.close_sheet()
			await _wait(0.3)
	if only.is_empty() or only.has("portrait-wall"):
		_place(p, body, Vector3(13.0, 0.1, 14.0), -PI * 0.5)
		var cam := Camera3D.new()
		cam.fov = 62.0
		cam.cull_mask = p.rig.camera.cull_mask
		main.add_child(cam)
		cam.global_position = Vector3(2.4, 2.1, 13.45)
		cam.look_at(Vector3(8.0, 1.45, 14.9))
		cam.current = true
		main.hud.visible = false
		await _wait(1.0)
		await _shot("portrait-wall")
		cam.queue_free()
		p.rig.camera.current = true
		main.hud.visible = true
		await _wait(0.3)
	if (only.is_empty() or only.has("area-lounge")) and main.has_method("walk_to_area"):
		_place(p, body, Vector3(30.0, 0.1, 7.0), PI * 0.5)
		await _wait(0.8)
		main.walk_to_area("lounge")
		for i in 1500:
			await process_frame
			if not p.walking_to and main.pending_zone == "":
				break
		await _wait(0.2)
		if is_instance_valid(main.sheet):
			main.close_sheet()
		await _wait(1.6)
		await _shot("area-lounge")
	quit()


func _place(p: Player, body: Node3D, at: Vector3, yaw: float) -> void:
	p.stand_up()
	p.walking_to = false
	p.global_position = at
	p.velocity = Vector3.ZERO
	body.global_rotation = Vector3(0, yaw, 0)
	p.rig.snap()
