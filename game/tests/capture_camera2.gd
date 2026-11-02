extends SceneTree
## Real-window screenshots for camera feel 2 (Daniele, Questions tab 2026-11-02 07:26: "trails behind", "walls or
## furniture still get in the way", "too far, too close or too steep"; not a pass/fail test). HUD on.
##   area-<id>      the player standing in each area, turned three-quarters to the camera, the view settled
##   walk-<k>       a walk across the main room (west to east), shots at 0.25, 0.7, 1.3 and 2.2 s after the start
##                  and one after the stop: where the character sits in the frame while the camera follows
##   occl-<id>      spots where something stood between the camera and the player before this pass
## From game/, one size per run:
##   godot --path . --resolution 1080x1920 --script res://tests/capture_camera2.gd -- --tag=portrait
##   godot --path . --resolution 1920x1080 --script res://tests/capture_camera2.gd -- --tag=landscape
## Writes <prefix><tag>-<shot>.png to docs/art/screens/camera-feel-2/ (--out=DIR, --prefix=before-, --only=areas|walk|occl).

const AREAS := [
	["floor", Vector3(30.0, 0.1, 6.8)], ["bar", Vector3(29.0, 0.1, 11.4)], ["stage", Vector3(30.75, 0.1, 4.6)],
	["toilets", Vector3(21.0, 0.1, 14.2)], ["smoking", Vector3(40.0, 0.1, 15.2)], ["buffer", Vector3(17.7, 0.1, 5.3)],
	["lounge", Vector3(8.0, 0.1, 6.0)], ["merch", Vector3(12.5, 0.1, 2.4)], ["memory", Vector3(5.0, 0.1, 2.0)],
	["patrons", Vector3(4.8, 0.1, 9.6)], ["alcove", Vector3(17.5, 0.1, 11.2)], ["corridor", Vector3(8.0, 0.1, 14.1)],
	["lobby", Vector3(1.1, 0.1, 10.0)],
]
## Spots where something stood between the camera and the player on 14cda24 (sight-line probe): the tree right of
## the stage (raised strip), the west back-bar bays (toilets view), the buffer's east valance (buffer view)
const OCCL := [
	["raised-tree", Vector3(40.3, 0.25, 0.9)], ["toilets-backbar", Vector3(23.6, 0.1, 16.0)], ["buffer-valance", Vector3(19.8, 0.1, 4.6)],
]
const WALK := [Vector3(22.6, 0.1, 6.7), Vector3(38.0, 0, 6.7)]
const WALK_AT := [0.25, 0.7, 1.3, 2.2]

var out := "res://../docs/art/screens/camera-feel-2"
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
	needs.save_path = "user://capture_camera2_save.json"
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
	if only == "" or only == "areas":
		for a in AREAS:
			_place(p, body, a[1], 0.0)
			await _wait(0.4)
			body.global_rotation = Vector3(0, p.rig.yaw + 0.5, 0)   # three-quarters to the camera
			await _wait(1.2)
			await _shot("area-" + a[0])
	if only == "" or only == "walk":
		_place(p, body, WALK[0], -PI * 0.5)
		await _wait(1.5)
		p.walk_to(WALK[1])
		var t0 := Time.get_ticks_msec()
		for k in WALK_AT.size():
			while (Time.get_ticks_msec() - t0) / 1000.0 < WALK_AT[k]:
				await process_frame
			await _shot("walk-%d" % (k + 1))
		while p.walking_to:
			await process_frame
		await _wait(0.6)
		await _shot("walk-%d" % (WALK_AT.size() + 1))
	if only == "" or only == "occl":
		for o in OCCL:
			_place(p, body, o[1], 0.0)
			await _wait(0.4)
			body.global_rotation = Vector3(0, p.rig.yaw + 0.5, 0)
			await _wait(1.2)
			await _shot("occl-" + o[0])
	quit()


func _place(p: Player, body: Node3D, at: Vector3, yaw: float) -> void:
	p.stand_up()
	p.walking_to = false
	p.global_position = at
	p.velocity = Vector3.ZERO
	body.global_rotation = Vector3(0, yaw, 0)
	p.rig.snap()
