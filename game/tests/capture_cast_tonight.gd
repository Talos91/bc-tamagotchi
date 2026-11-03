extends SceneTree
## Capture for 2026-11-03: Ty and Prae both in the bar on the night of 2026-11-03 Bangkok. The night number comes from
## the real rule (Cast.night_at at 19:00 +07), not a pinned 0. Not a pass/fail test.
##   godot --path . --resolution 450x800 --script res://tests/capture_cast_tonight.gd -- --tag=phone
## Writes 1-ty-<tag>.png and 2-prae-<tag>.png to docs/art/screens/cast-tonight/.

const Cast = preload("res://scripts/cast.gd")

var out := "res://../docs/art/screens/cast-tonight"
var tag := "phone"
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
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
	var path := out.path_join("%s-%s.png" % [nm, tag])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _place(p: Node3D, pos: Vector3, yaw := 0.0) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.get_node("Body").rotation.y = yaw
	p.rig.snap()
	await _wait(1.0)


func _run() -> void:
	await process_frame
	Cast.night_override = Cast.night_at(1793707200.0)   # 2026-11-03 19:00 +07
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_cast_tonight_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	var p = main.player
	var tt: Node3D = main.find_child("Host_tt", true, false)
	var prae: Node3D = main.find_child("Host_mali", true, false)
	print("night ", Cast.night(), "; tt ", tt, "; prae ", prae)
	await _place(p, Vector3(5.3, 0.1, 5.6), -PI * 0.5)
	await _shot("1-ty")
	await _place(p, prae.global_position + Vector3(-0.6, 0.1, 1.4), PI * 0.75)
	await _shot("2-prae")
	quit(0)
