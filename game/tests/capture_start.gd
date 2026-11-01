extends SceneTree
## Screenshots of the start screen and entry (scripts/start_screen.gd) in a real window, one orientation per run:
##   godot --path . --resolution 540x960 --script res://tests/capture_start.gd -- --tag=portrait
##   godot --path . --resolution 960x540 --script res://tests/capture_start.gd -- --tag=landscape
## (half of 1080x1920 and 1920x1080, as tools/capture_venue.gd: a full-size window is clipped to the screen.)
## Writes <tag>-1-title.png (the start screen), -2-door (walking in, the door open), -3-pull (pulling back over the
## lobby), -4-play (first gameplay frame, HUD in) to docs/art/screens/start/ (override with --out=DIR).

const SHOTS := [["2-door", 2.2], ["3-pull", 4.1]]   ## seconds after the tap

func _init() -> void:
	var tag := "shot"
	var out := "res://../docs/art/screens/start"
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
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.intro = true
	root.add_child(main)
	for i in 90:
		await process_frame
	var ss: Node = main.start_screen
	_save(out, tag, "1-title")
	ss.tap()
	for s in SHOTS:
		while is_instance_valid(ss) and ss._t < s[1]:
			await process_frame
		_save(out, tag, s[0])
	while is_instance_valid(main.start_screen):
		await process_frame
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 700:
		await process_frame
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
		for i in 30:
			await process_frame
	_save(out, tag, "4-play")
	quit()


func _save(out: String, tag: String, nm: String) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s-%s.png" % [out, tag, nm]
	print("capture ", path, " ", img.get_size(), " -> ", img.save_png(path))
