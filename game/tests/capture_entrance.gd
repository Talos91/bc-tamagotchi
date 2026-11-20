extends SceneTree
## Entrance round (Daniele 2026-11-20, photos docs/venue/photos/2026-11-20-entrance-round/): before|after captures of
## the entrance (eagle greeter), the marble corridor, the poster booth, the mural corridor, the Sticker door and the
## lounge. The game's own views with the HUD on (player placed, rig snapped) plus fixed overview cameras (`cam`:
## position, look-at; the ceiling layer is left out as the rig does). From game/, windowed (headless renders nothing),
## on a hidden desktop only (PROJECT.md Tests):
##   godot --path . --script res://tests/capture_entrance.gd -- --tag=portrait|landscape --out=<dir> [--only=a,b]
## Writes <tag>-<view>.png at 1080x1920 / 1920x1080.

const VIEWS := [
	# The arrival: in by the street door (west wall), the eagle on its table against the east wall greets them
	{"name": "entrance", "player": Vector3(1.12, 0.1, 7.2), "yaw": PI * 0.5, "arrive": true},
	{"name": "entrance-top", "player": Vector3(1.12, 0.1, 7.2), "yaw": PI * 0.5, "cam": [Vector3(0.15, 2.4, 7.2), Vector3(2.15, 0.9, 7.2)]},
	# Photo 13: from left of the falcon looking right, the door to the corridor beside the table
	{"name": "eagle-door", "player": Vector3(0.5, 0.1, 6.0), "yaw": PI * 0.5, "cam": [Vector3(1.5, 1.6, 5.4), Vector3(1.15, 1.0, 8.6)]},
	{"name": "eagle-close", "player": Vector3(0.5, 0.1, 6.0), "yaw": PI * 0.5, "cam": [Vector3(0.9, 1.5, 7.0), Vector3(2.0, 1.1, 7.25)]},
	# The marble stretch with the red floor lamp, looking south to the booth
	{"name": "corridor-marble", "player": Vector3(1.1, 0.1, 10.8), "yaw": 0.0},
	{"name": "booth", "player": Vector3(1.1, 0.1, 12.6), "yaw": 0.0},
	{"name": "booth-top", "player": Vector3(1.1, 0.1, 11.0), "yaw": 0.0, "cam": [Vector3(1.4, 2.6, 9.4), Vector3(0.9, 1.0, 14.6)]},
	# The long corridor (mural on the lounge side), the corridor end and the Sticker door
	{"name": "corridor", "player": Vector3(7.0, 0.1, 14.1), "yaw": -PI * 0.5},
	{"name": "corridor-top", "player": Vector3(7.0, 0.1, 14.1), "yaw": -PI * 0.5, "cam": [Vector3(4.0, 2.4, 14.7), Vector3(9.0, 1.4, 13.3)]},
	{"name": "sticker-door", "player": Vector3(12.6, 0.1, 14.2), "yaw": -PI * 0.5},
	{"name": "sticker-door-top", "player": Vector3(11.0, 0.1, 14.4), "yaw": -PI * 0.5, "cam": [Vector3(13.65, 1.6, 14.8), Vector3(13.65, 1.3, 13.1)]},
	# The lounge (photos 07-11): the Sticker door from inside (07), the memory corner (09), the curtained corner (08),
	# the merch stand in the middle
	{"name": "lounge", "player": Vector3(7.5, 0.1, 6.5), "yaw": PI},
	{"name": "lounge-south", "player": Vector3(9.0, 0.1, 10.5), "yaw": PI},
	{"name": "sticker-door-lounge", "player": Vector3(12.0, 0.1, 9.0), "yaw": PI, "cam": [Vector3(12.6, 1.8, 8.6), Vector3(13.6, 1.1, 13.0)]},
	{"name": "memory-corner", "player": Vector3(7.0, 0.1, 4.0), "yaw": PI, "cam": [Vector3(7.6, 1.7, 4.6), Vector3(4.2, 0.8, 0.2)]},
	{"name": "lounge-ne", "player": Vector3(10.0, 0.1, 5.0), "yaw": PI, "cam": [Vector3(8.6, 1.9, 2.0), Vector3(15.4, 1.0, 1.4)]},
	{"name": "merch-centre", "player": Vector3(9.5, 0.1, 8.5), "yaw": PI, "cam": [Vector3(14.6, 2.8, 10.2), Vector3(11.6, 0.6, 6.6)]},
]

var out := "res://../docs/art/screens/venue-entrance/after"
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
	root.size = full
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
	needs.save_path = "user://capture_entrance_save.json"
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
	free.fov = 70.0
	free.cull_mask = 0xFFFFF & ~(1 << 1)
	root.add_child(free)
	for v in VIEWS:
		if not only.is_empty() and not only.has(v.name):
			continue
		_place(p, body, v.player, v.yaw)
		if v.get("arrive", false) and main.has_method("greet_at_door"):
			main.greet_at_door()
		await _wait(1.8)
		var rig_cam := root.get_viewport().get_camera_3d()
		if v.has("cam"):
			free.look_at_from_position(v.cam[0], v.cam[1], Vector3.UP)
			free.make_current()
		paused = true
		await _wait(0.15)
		var img := await _grab()
		var path := out.path_join("%s-%s.png" % [tag, v.name])
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
