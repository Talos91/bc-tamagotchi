extends SceneTree
## Venue fixes (owner feedback 2026-11-02, items 4 5 6 7 8 11; handoffs/venue-fixes-2026-11-02.md): before|after captures
## of the six places, the game's own views with the HUD on (player placed, rig snapped) and, where the gameplay camera
## cannot show the change, a fixed overview camera (`cam`: position, look-at; the ceiling layer is left out as the rig does).
## From game/, windowed (headless renders nothing):
##   godot --path . --script res://tests/capture_venue_fixes.gd -- --tag=portrait --out=<dir> [--only=bar,buffer]
## Writes <view>.png (landscape-<view>.png) to docs/art/screens/venue-fixes/after/ by default.

const VIEWS := [
	# 4 door between the bar and the walled bar area; 5 the raised bar floor and staff room
	{"name": "bar", "player": Vector3(32.0, 0.1, 11.4), "yaw": PI},
	{"name": "bar-east", "player": Vector3(35.2, 0.1, 11.5), "yaw": PI},
	{"name": "bar-door-top", "player": Vector3(33.0, 0.1, 9.0), "yaw": PI, "cam": [Vector3(33.2, 3.4, 11.2), Vector3(35.8, 0.6, 14.0)]},
	{"name": "bar-side", "player": Vector3(30.0, 0.1, 9.0), "yaw": PI, "cam": [Vector3(26.5, 2.0, 11.6), Vector3(30.5, 1.2, 14.0)]},
	# 15 (follow-up) the walled bar area stays solid in the views that looked into it
	{"name": "staff-from-smoking", "player": Vector3(39.6, 0.1, 11.6), "yaw": PI},
	{"name": "staff-from-floor", "player": Vector3(36.8, 0.1, 9.6), "yaw": PI},
	{"name": "staff-from-bar", "player": Vector3(35.4, 0.1, 11.5), "yaw": PI * 0.5},
	# 6 the buffer curtains in the way; 8 the buffer's east side
	{"name": "buffer", "player": Vector3(17.7, 0.1, 5.3), "yaw": 0.0},
	{"name": "buffer-west", "player": Vector3(16.0, 0.1, 5.3), "yaw": PI * 0.5},
	{"name": "buffer-east", "player": Vector3(19.6, 0.1, 5.3), "yaw": -PI * 0.5},
	{"name": "buffer-from-main", "player": Vector3(21.6, 0.1, 5.3), "yaw": -PI * 0.5},
	{"name": "buffer-top", "player": Vector3(17.7, 0.1, 5.3), "yaw": 0.0, "cam": [Vector3(13.0, 3.6, 5.3), Vector3(19.5, 0.8, 5.3)]},
	{"name": "buffer-east-in", "player": Vector3(17.0, 0.1, 4.2), "yaw": 0.0, "cam": [Vector3(15.3, 1.9, 5.3), Vector3(20.1, 1.6, 5.3)]},
	{"name": "buffer-west-in", "player": Vector3(18.6, 0.1, 4.2), "yaw": 0.0, "cam": [Vector3(19.9, 1.9, 5.3), Vector3(15.4, 1.6, 5.3)]},
	# 7 the male toilet door
	{"name": "toilets", "player": Vector3(21.2, 0.1, 15.6), "yaw": PI},
	{"name": "toilets-top", "player": Vector3(21.2, 0.1, 15.6), "yaw": PI, "cam": [Vector3(20.6, 3.2, 14.4), Vector3(23.3, 0.9, 16.9)]},
	# 11 the barrier across the unused corridor (old-corridor alcove off the lounge)
	{"name": "alcove", "player": Vector3(14.2, 0.1, 11.2), "yaw": PI * 0.5},
	{"name": "alcove-top", "player": Vector3(13.6, 0.1, 9.6), "yaw": PI * 0.5, "cam": [Vector3(12.0, 3.4, 9.0), Vector3(16.2, 0.5, 11.3)]},
]

var out := "res://../docs/art/screens/venue-fixes/after"
var tag := "portrait"
var only: PackedStringArray = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	var full := Vector2i(1080, 1920) if tag == "portrait" else Vector2i(1920, 1080)
	root.size = full / 2
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = full
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_venue_fixes_save.json"
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
	var free := Camera3D.new()
	free.fov = 75.0
	free.cull_mask = 0xFFFFF & ~(1 << 1)
	root.add_child(free)
	for v in VIEWS:
		if not only.is_empty() and not only.has(v.name):
			continue
		_place(p, body, v.player, v.yaw)
		await _wait(1.8)
		var rig_cam := root.get_viewport().get_camera_3d()
		if v.has("cam"):
			free.look_at_from_position(v.cam[0], v.cam[1], Vector3.UP)
			free.make_current()
		paused = true
		await _wait(0.15)
		var img := await _grab()
		var nm: String = v.name if tag == "portrait" else "landscape-" + v.name
		var path := out.path_join(nm + ".png")
		img.save_png(path)
		print("saved ", path, " ", img.get_size())
		paused = false
		if v.has("cam") and rig_cam:
			rig_cam.make_current()
	quit()


func _grab() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()


func _place(p: Player, body: Node3D, at: Vector3, yaw: float) -> void:
	p.stand_up()
	p.walking_to = false
	p.global_position = at
	p.velocity = Vector3.ZERO
	body.global_rotation = Vector3(0, yaw, 0)
	p.rig.snap()
