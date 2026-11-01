extends SceneTree
## Real-window screenshot run for Prae as an owner (not a pass/fail test): the game camera at her table with her name
## tag (no heart), then a free camera on her at the table, front and three-quarter, and a close-up of the name tag.
## From game/, one size per run:
##   godot --path . --resolution 800x1422 --script res://tests/capture_prae.gd -- --tag=portrait --capture-size=1080x1920
##   godot --path . --resolution 1920x1080 --script res://tests/capture_prae.gd -- --tag=landscape --capture-size=1920x1080
## A 1080x1920 window is clipped to the screen, so portrait renders a 9:16 window that fits and scales the frame to
## --capture-size (Lanczos). Writes <n>-<shot>-<tag>.png to docs/art/screens/prae/ (override with --out=DIR).

var out := "res://../docs/art/screens/prae"
var tag := "portrait"
var size := Vector2i.ZERO
var main: Node
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--capture-size="):
			var wh := a.substr(15).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--out="):
			out = a.substr(6)
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(nm: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	if size != Vector2i.ZERO and img.get_size() != size:
		img.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var path := out.path_join("%s-%s.png" % [nm, tag])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _eye(from: Vector3, at: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.keep_aspect = Camera3D.KEEP_HEIGHT if root.get_visible_rect().size.aspect() >= 1.0 else Camera3D.KEEP_WIDTH
	cam.look_at_from_position(from, at)
	cam.make_current()
	await _wait(0.4)


func _place(p: Node3D, pos: Vector3, yaw := 0.0) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.get_node("Body").rotation.y = yaw
	p.rig.snap()
	await _wait(1.0)


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_prae_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	var p = main.player
	cam = Camera3D.new()
	main.add_child(cam)
	var host: Node3D = main.find_child("Host_mali", true, false)
	var label: Label3D = main.zones.get_node("Tag_mali")
	print("host ", host.global_position, " facing ", host.global_basis.z, " tag '", label.text, "'")
	var vp := root.get_viewport()

	# 1. The game camera with the player beside Prae's table: her figure and the name tag, no heart
	# The main room's camera looks east: the player stands a little east of her, so she is between camera and player
	await _place(p, host.global_position + Vector3(1.8, 0, -0.5), -PI * 0.5)
	await _shot("1-prae-game")
	print("on screen: Prae ", vp.get_camera_3d().unproject_position(host.global_position + Vector3(0, 0.6, 0)),
		" tag ", vp.get_camera_3d().unproject_position(label.global_position),
		" player ", vp.get_camera_3d().unproject_position(p.global_position + Vector3(0, 0.6, 0)))

	# 2-3. A free camera at eye level on her: front, then three-quarter (the tag floats over the table behind her)
	main.get_node("UI").visible = false
	await _place(p, Vector3(26.0, 0, 6.5))
	var h := host.global_position
	var fwd := Vector3(host.global_basis.z.x, 0, host.global_basis.z.z).normalized()
	var wide := root.get_visible_rect().size.aspect() >= 1.0
	await _eye(h + fwd * (2.6 if wide else 2.8) + Vector3(0, 1.1, 0), h + Vector3(0, 0.95 if wide else 1.15, 0), 40.0)
	await _shot("2-prae-front")
	var q := fwd.rotated(Vector3.UP, deg_to_rad(40.0))   # toward the aisle, away from her table's guests
	await _eye(h + q * (2.6 if wide else 2.8) + Vector3(0, 1.2, 0), h + Vector3(0, 0.95 if wide else 1.15, 0), 40.0)
	await _shot("3-prae-three-quarter")

	# 4. The name tag close: "Prae" with no heart, over her head from the front
	var mid := (h + Vector3(0, 1.0, 0)).lerp(label.global_position, 0.5)
	await _eye(h + fwd * 3.2 + Vector3(0, 1.7, 0), mid, 34.0)
	await _shot("4-prae-label")
	cam.clear_current()
	main.get_node("UI").visible = true
	quit(0)
