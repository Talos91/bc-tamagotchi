extends SceneTree
## Real-window screenshots for the camera-areas pass (owner items 30-32, Daniele 2026-11-10; not a pass/fail test).
## Every shot is taken after a real walk (tap-to-move path), so the views come and go as they do in play. HUD on.
##   item-<id>        item 30: walked from the middle of the lounge to each main lounge item, view settled
##   corridor-end     item 31: walked east along the corridor to its end (the lounge wall and the Sticker door)
##   door-swing       item 31: half a second after stepping through the Sticker door into the lounge
##   door-in          item 31: just inside the lounge, view settled (the corner by the game machine and the door)
##   curtains         item 32: walked east across the lounge to the buffer's curtains
##   buffer           item 32: inside the buffer (the small room before the main room)
##   main             item 32: through into the main room
## From game/, one size per run:
##   godot --path . --resolution 1080x1920 --script res://tests/capture_camera_areas.gd -- --tag=portrait --prefix=before-
##   godot --path . --resolution 1920x1080 --script res://tests/capture_camera_areas.gd -- --tag=landscape --prefix=before-
## Writes <prefix><tag>-<shot>.png to docs/art/screens/camera-areas/ (--out=DIR, --only=items|door|curtains).

const LOUNGE_MID := Vector3(8.0, 0.1, 6.0)
const ITEMS := [
	["booth", Vector3(9.2, 0, 1.5)], ["memory", Vector3(5.0, 0, 2.0)], ["merch", Vector3(12.5, 0, 2.4)],
	["couch", Vector3(5.3, 0, 5.0)], ["pinball", Vector3(3.9, 0, 7.2)], ["patrons", Vector3(4.8, 0, 9.6)],
	["cabinet", Vector3(10.3, 0, 11.6)], ["counter", Vector3(12.3, 0, 11.3)],
]

var out := "res://../docs/art/screens/camera-areas"
var tag := "portrait"
var prefix := ""
var only := ""
var p: Player
var body: Node3D


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
	print("saved ", path, " ", img.get_size(), " view=", p.rig.view, " at ", p.global_position)


func _walk(to: Vector3) -> void:
	p.walk_to(to)
	await _wait(0.1)
	var t0 := Time.get_ticks_msec()
	while p.walking_to and Time.get_ticks_msec() - t0 < 12000:
		await process_frame


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_camera_areas_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	p = main.player
	body = p.get_node("Body")
	if only == "" or only == "items":
		for it in ITEMS:
			_place(LOUNGE_MID)
			await _wait(0.6)
			await _walk(it[1])
			await _wait(1.6)
			await _shot("item-" + it[0])
	if only == "" or only == "door":
		_place(Vector3(6.0, 0.1, 14.1))
		await _wait(0.6)
		await _walk(Vector3(13.6, 0, 14.15))
		await _wait(1.6)
		await _shot("corridor-end")
		p.walk_to(Vector3(13.6, 0, 11.6))
		var t0 := Time.get_ticks_msec()
		while p.global_position.z > 12.9 and Time.get_ticks_msec() - t0 < 6000:
			await process_frame
		await _wait(0.5)
		await _shot("door-swing")
		while p.walking_to:
			await process_frame
		await _wait(1.6)
		await _shot("door-in")
	if only == "" or only == "curtains":
		_place(Vector3(12.8, 0.1, 6.6))
		await _wait(0.6)
		await _walk(Vector3(15.0, 0, 5.4))
		await _wait(1.0)
		await _shot("curtains")
		await _walk(Vector3(17.7, 0, 5.4))
		await _wait(1.6)
		await _shot("buffer")
		await _walk(Vector3(22.8, 0, 6.6))
		await _wait(1.6)
		await _shot("main")
	quit()


func _place(at: Vector3) -> void:
	p.stand_up()
	p.walking_to = false
	p.global_position = at
	p.velocity = Vector3.ZERO
	body.global_rotation = Vector3(0, 0, 0)
	p.rig.snap()
