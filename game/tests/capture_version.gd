extends SceneTree
## Screenshots of the build version label (scripts/version_info.gd) on the start screen and on the HUD in play, one
## orientation per run, at half of 1080x1920 / 1920x1080 (as capture_start.gd: a full-size window is clipped to the
## screen; the canvas_items stretch lays the UI out exactly as at full size):
##   godot --path . --resolution 540x960 --script res://tests/capture_version.gd -- --tag=portrait
##   godot --path . --resolution 960x540 --script res://tests/capture_version.gd -- --tag=landscape
## Writes to docs/art/screens/version/ (override with --out=DIR): <tag>-1-start, <tag>-2-hud.

var out := "res://../docs/art/screens/version"
var tag := "shot"


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var needs := root.get_node_or_null("Needs")
	needs.autosave = false
	needs.new_game()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.intro = true
	root.add_child(main)
	await _frames(90)
	_save("1-start")
	main.start_screen.skip()
	await _frames(20)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	await _frames(60)
	_save("2-hud")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(nm: String) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s-%s.png" % [out, tag, nm]
	print("capture ", path, " ", img.get_size(), " -> ", img.save_png(path))
