extends SceneTree
## Real-window screenshots of the player after each minigame returns (owner list 2026-11-20 item 7: "after playing a
## match of clap game my character became invisible when i went back to the bar", "happens with all games"). Not a
## pass/fail test (tests/test_mg_return.gd is the check). Each of the 8 games opens through main.open_minigame, is
## left through the frame's real path (abandon -> result card -> Done), and the bar is shot a second later.
##   godot --path . --resolution 540x960 --script res://tests/capture_mg_return.gd -- --tag=portrait --prefix=before-
##   godot --path . --resolution 960x540 --script res://tests/capture_mg_return.gd -- --tag=landscape --prefix=before-
## Writes <prefix><tag>-<n>-<game>.png to docs/art/screens/creator-fix/mg-return/ (--out=DIR); --games=a,b limits.

const VenueSession = preload("res://scripts/zones/venue_session.gd")

var out := "res://../docs/art/screens/creator-fix/mg-return"
var tag := "portrait"
var prefix := ""
var only: PackedStringArray = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--prefix="):
			prefix = a.substr(9)
		elif a.begins_with("--games="):
			only = a.substr(8).split(",")
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
	print("saved ", path)


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_mg_return_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.5)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	await _wait(1.0)
	await _shot("0-start")
	_dump(main, "start")
	var n := 1
	for gid: String in VenueSession.GAMES:
		if not only.is_empty() and not gid in only:
			continue
		main.open_minigame(gid, {})
		await _wait(0.8)
		var fr: Node = main.frame
		fr.game.abandon()
		await _wait(0.4)
		if is_instance_valid(fr._card):
			fr._card.done.emit()
		await _wait(1.2)
		await _shot("%d-%s" % [n, gid])
		_dump(main, gid)
		n += 1
	quit(0)


func _dump(main: Node, label: String) -> void:
	var p: Node3D = main.player
	var shown := 0
	var total := 0
	for mi in p.find_children("*", "MeshInstance3D", true, false):
		total += 1
		if (mi as MeshInstance3D).is_visible_in_tree():
			shown += 1
	var cam := root.get_camera_3d()
	print("DUMP %s pos=%s visible=%s meshes %d/%d cam=%s disable_3d=%s" % [label, p.global_position, p.is_visible_in_tree(),
		shown, total, cam.global_position if cam else Vector3.ZERO, root.disable_3d])
