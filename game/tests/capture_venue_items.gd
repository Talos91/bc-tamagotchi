extends SceneTree
## Real-window screenshots of three venue items (owner list 2026-11-20): 8 "there's 2 arcade machines, keep only the
## big one", 9 "the screen for share a memory is facing the wall instead of the player", 10 "entrance door doesn't fit
## the full door frame and has the top open". Not a pass/fail test. Each item: the area's own view with the player
## there, then a frozen camera looking straight at it. From game/, one size per run:
##   godot --path . --resolution 540x960 --script res://tests/capture_venue_items.gd -- --tag=portrait --prefix=before-
## Writes <prefix><tag>-<shot>.png to docs/art/screens/creator-fix/venue-items/ (--out=DIR).

const SHOTS := [   # name, player position[, facing yaw]
	["arcade", Vector3(11.4, 0.1, 10.6), PI],
	["memory", Vector3(5.6, 0.1, 2.2), 0.0],
	["door", Vector3(1.2, 0.1, 9.6), -PI * 0.5],
]
const LOOKS := [   # name, player position, facing, camera from, camera at
	["look-arcade", Vector3(11.4, 0.1, 9.0), PI, Vector3(11.4, 2.0, 9.4), Vector3(11.4, 1.0, 12.9)],
	["look-memory", Vector3(6.4, 0.1, 3.4), 0.0, Vector3(5.6, 1.9, 2.6), Vector3(2.6, 1.0, 0.75)],
	["look-door", Vector3(1.2, 0.1, 11.5), -PI * 0.5, Vector3(2.05, 1.25, 7.2), Vector3(0.0, 1.45, 7.2)],
]

var out := "res://../docs/art/screens/creator-fix/venue-items"
var tag := "portrait"
var prefix := ""
var p: Node
var body: Node3D


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
	print("saved ", path, " view=", p.rig.view, " at ", p.global_position)


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_venue_items_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	p = main.player
	for ui in main.get_children():   # HUD and debug buttons off: the area buttons sat on the alcove's part of the frame
		if ui is CanvasLayer:
			ui.visible = false
	body = p.get_node("Body")
	for s in SHOTS:
		p.stand_up()
		p.walking_to = false
		p.global_position = s[1]
		p.velocity = Vector3.ZERO
		if s.size() > 2:
			p.face(s[2])
		p.rig.zone = p.rig.area_at(s[1])
		p.rig.snap()
		for i in 150:   # spots with a heading need the facing for a few ticks, then the swing and the walls' sink
			await physics_frame
		await _wait(0.3)
		await _shot(s[0])
	for s in LOOKS:
		p.rig.set_physics_process(true)
		p.global_position = s[1]
		p.face(s[2])
		p.rig.zone = p.rig.area_at(s[1])
		p.rig.snap()
		for i in 150:
			await physics_frame
		p.rig.set_physics_process(false)
		p.rig.camera.look_at_from_position(s[3], s[4])
		await _wait(0.3)
		await _shot(s[0])
	quit()
