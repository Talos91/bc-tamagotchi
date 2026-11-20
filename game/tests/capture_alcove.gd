extends SceneTree
## Real-window screenshots of the lounge's unused corridor (the "alcove", owner list 2026-11-20 item 5: "the unused
## corridor (the blocked one) in the lounge has the end wall invisible and you can see trough both ways"). Not a
## pass/fail test. The player is placed at points around the alcove (the area's view snapped), in the lounge and in
## the main room on the other side of its end wall. From game/, one size per run:
##   godot --path . --resolution 540x960 --script res://tests/capture_alcove.gd -- --tag=portrait --prefix=before-
##   godot --path . --resolution 960x540 --script res://tests/capture_alcove.gd -- --tag=landscape --prefix=before-
## Writes <prefix><tag>-<shot>.png to docs/art/screens/creator-fix/alcove/ (--out=DIR).

const SHOTS := [   # name, player position[, facing yaw]; the view is the area's (or its spot's) own
	["curtains", Vector3(13.6, 0.1, 7.4), PI * 0.5],   # lounge, facing east: the curtains view, the alcove on its right
	["curtains-far", Vector3(14.2, 0.1, 6.0), PI * 0.5],
	["main-west", Vector3(20.6, 0.1, 9.4)],        # main room floor view: its camera stands in the lounge, looking east
	["main-alcove", Vector3(20.6, 0.1, 11.2)],     # the same view with the player in line with the alcove
	["alcove", Vector3(15.6, 0.1, 11.2)],          # the alcove's own view, at the rope, looking south
	["toilets", Vector3(20.6, 0.1, 12.6)],         # the toilets view, the alcove on its right
]
## Inspection shots: the rig settles in a view (its walls cut as that view cuts them), is then frozen, and the camera
## looks straight down the alcove at its end, from the lounge (curtains view) and from the main room (floor view).
const LOOKS := [
	["look-from-lounge", Vector3(13.6, 0.1, 7.4), PI * 0.5, Vector3(12.6, 2.4, 11.25), Vector3(20.0, 1.2, 11.25)],
	["look-from-main", Vector3(20.6, 0.1, 9.4), -PI * 0.5, Vector3(24.5, 2.4, 11.25), Vector3(16.0, 1.2, 11.25)],
]

var out := "res://../docs/art/screens/creator-fix/alcove"
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
	needs.save_path = "user://capture_alcove_save.json"
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
