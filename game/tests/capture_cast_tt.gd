extends SceneTree
## Real-window screenshot run for the cast pass of 2026-11-02 (not a pass/fail test): Tt, the new regular #4, seated at
## the lounge's Long Table under his "Tt  ♥" tag (game camera, then a free camera on him), and Prae, the owner, with
## her straight long hair at her spot (the night is pinned to 0: she is in, at WestTable0, the main room's top-left).
## From game/, one size per run:
##   godot --path . --resolution 800x1422 --script res://tests/capture_cast_tt.gd -- --tag=portrait --capture-size=1080x1920
##   godot --path . --resolution 1920x1080 --script res://tests/capture_cast_tt.gd -- --tag=landscape --capture-size=1920x1080
## A 1080x1920 window is clipped to the screen, so portrait renders a 9:16 window that fits and scales the frame to
## --capture-size (Lanczos). Writes <n>-<shot>-<tag>.png to docs/art/screens/cast-tt/ (override with --out=DIR).

const Cast = preload("res://scripts/cast.gd")

var out := "res://../docs/art/screens/cast-tt"
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
	Cast.night_override = 0
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_cast_tt_save.json"
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
	var tt: Node3D = main.find_child("Host_tt", true, false)
	var prae: Node3D = main.find_child("Host_mali", true, false)
	var tt_tag: Label3D = main.zones.get_node("Tag_tt")
	var prae_tag: Label3D = main.zones.get_node("Tag_mali")
	print("tt ", tt.global_position, " tag '", tt_tag.text, "'; prae ", prae.global_position, " tag '", prae_tag.text, "'")
	var wide := root.get_visible_rect().size.aspect() >= 1.0

	# 1. The game camera in the lounge with the player at the Long Table, across from Tt
	var t := tt.global_position
	await _place(p, Vector3(5.3, 0.1, 5.6), -PI * 0.5)
	await _shot("1-tt-game")

	# 2. The game camera in the main room with the player beside Prae at her spot tonight (WestTable0)
	var h := prae.global_position
	await _place(p, h + Vector3(-0.6, 0.1, 1.4), PI * 0.75)
	await _shot("4-prae-game")

	# 3-4. A free camera on Tt at his table (he sits on the banquette, facing east into the lounge): the table and his
	# tag, then closer on him
	main.get_node("UI").visible = false
	await _place(p, Vector3(9.0, 0.1, 11.0))
	await _eye(t + Vector3(4.2, 2.2, 1.8 if wide else 1.3), Vector3(3.3, 1.0, 5.0), 44.0 if wide else 56.0)
	await _shot("2-tt-long-table")
	await _eye(t + Vector3(2.4, 1.5, 1.0), t + Vector3(0, 0.8, 0), 36.0)
	await _shot("3-tt-close")

	# 5-6. A free camera on Prae: front, then three-quarter
	await _place(p, Vector3(26.0, 0.1, 6.5))
	var fwd := Vector3(prae.global_basis.z.x, 0, prae.global_basis.z.z).normalized()
	await _eye(h + fwd * 2.6 + Vector3(0, 1.1, 0), h + Vector3(0, 0.95 if wide else 1.05, 0), 40.0)
	await _shot("5-prae-front")
	var q := fwd.rotated(Vector3.UP, deg_to_rad(40.0))
	await _eye(h + q * 2.6 + Vector3(0, 1.2, 0), h + Vector3(0, 1.0, 0), 40.0)
	await _shot("6-prae-three-quarter")
	cam.clear_current()
	main.get_node("UI").visible = true
	quit(0)
