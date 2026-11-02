extends SceneTree
## Real-window screenshots for the lounge follow-up (Daniele's lounge revamp answers, 2026-11-02; not a pass/fail test). HUD on.
##   lounge       the lounge from its own view (west), from the middle of the room
##   stair-foot   at the foot of the stair: the game machine back facing the bottom step, the high counter beyond it
##   machine      the player at the machine, its sheet open
##   memory       the memory corner, now alone top left
##   merch / merch-sheet   the merch counter and its sheet (in-game coin items, coming soon)
##   patrons-sheet, portrait-<n>-sheet   the Top patrons sheet (this month) and a portrait sheet (the patron's own message)
##   raised-top       a review camera straight down on the east tables and the raised strip (the lane to Raised3)
##   raised3-seated   the player sitting at Raised3 on the strip after walking there from the main room
## From game/, one size per run:
##   godot --path . --resolution 1080x1920 --script res://tests/capture_lounge_followup.gd -- --tag=portrait
##   godot --path . --resolution 1920x1080 --script res://tests/capture_lounge_followup.gd -- --tag=landscape
## Writes <prefix><tag>-<shot>.png to docs/art/screens/lounge-followup/ (--out=DIR, --prefix=, --only=a,b).

const STILLS := [
	{"name": "lounge", "player": Vector3(8.0, 0.1, 6.5), "yaw": PI * 0.5},
	{"name": "stair-foot", "player": Vector3(9.4, 0.1, 11.4), "yaw": PI * 0.5},
	{"name": "machine", "player": Vector3(10.3, 0.1, 11.6), "yaw": 0.0, "sheet": "cabinet"},
	{"name": "memory", "player": Vector3(7.2, 0.1, 1.9), "yaw": 0.0},
	{"name": "merch", "player": Vector3(13.6, 0.1, 2.75), "yaw": 0.0, "sheet": "merch"},
	{"name": "patrons", "player": Vector3(4.85, 0.1, 9.1), "yaw": PI * 0.5, "sheet": "patrons"},
	{"name": "corridor-east", "player": Vector3(10.2, 0.1, 14.0), "yaw": -PI * 0.5, "sheet": "portrait:6"},
	{"name": "raised-east", "player": Vector3(36.0, 0.1, 6.5), "yaw": -PI * 0.5},
]

var out := "res://../docs/art/screens/lounge-followup"
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
	if only.is_empty() or only.has("raised-top"):
		_place(p, body, Vector3(36.0, 0.1, 6.5), -PI * 0.5)
		var top := Camera3D.new()
		top.fov = 40.0
		top.cull_mask = p.rig.camera.cull_mask
		main.add_child(top)
		top.global_position = Vector3(38.2, 11.0, 6.8)
		top.look_at(Vector3(38.2, 0.0, 6.8), Vector3(1, 0, 0))
		top.current = true
		main.hud.visible = false
		await _wait(1.0)
		await _shot("raised-top")
		top.queue_free()
		p.rig.camera.current = true
		main.hud.visible = true
		await _wait(0.3)
	if only.is_empty() or only.has("raised3-seated"):
		_place(p, body, Vector3(36.0, 0.1, 6.5), -PI * 0.5)
		await _wait(0.8)
		var seat_node: Node3D = null
		for n in root.get_tree().get_nodes_in_group("seat"):
			if n.get_meta("table", "") == "Raised3" and not n.get_meta("couch", false):
				seat_node = n
		p.sit_at({"node": seat_node, "pos": seat_node.global_position, "yaw": seat_node.global_rotation.y, "h": float(seat_node.get_meta("seat_h")),
			"couch": false, "table": "Raised3", "pose": "sit_drink"})
		for i in 1500:
			await process_frame
			if p.seated:
				break
		await _wait(2.0)
		print("raised3 seated: ", p.seated, " at ", p.global_position, " seat ", seat_node.global_position)
		await _shot("raised3-seated")
		# A review camera (not the game's) from the lane the move opened: the player seated at Raised3, the couch beyond
		var cam := Camera3D.new()
		cam.fov = 55.0
		cam.cull_mask = p.rig.camera.cull_mask
		main.add_child(cam)
		cam.global_position = Vector3(37.2, 2.4, 5.4)
		cam.look_at(Vector3(40.3, 0.5, 7.2))
		cam.current = true
		main.hud.visible = false
		await _wait(1.0)
		await _shot("raised3-seated-close")
		cam.queue_free()
		p.rig.camera.current = true
		main.hud.visible = true
	quit()


func _place(p: Player, body: Node3D, at: Vector3, yaw: float) -> void:
	p.stand_up()
	p.walking_to = false
	p.global_position = at
	p.velocity = Vector3.ZERO
	body.global_rotation = Vector3(0, yaw, 0)
	p.rig.snap()
