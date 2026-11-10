extends SceneTree
## Real-window portrait screenshots for perf-iphone-2 (owner item 33; not a pass/fail test): the start screen, the
## character creator (Edit look), the bar and the lounge, each placed and settled (no walk), HUD on.
## From game/ (one Godot at a time):
##   godot --path . --resolution 540x960 --script res://tests/capture_perf_iphone2.gd -- --prefix=before-
##   godot --path . --resolution 540x960 --script res://tests/capture_perf_iphone2.gd -- --prefix=phone- --phone
## --phone = phone graphics as the web shell sets it (scripts/phone_graphics.gd, DECISIONS 2026-11-10): MSAA off on
## the game view and the creator preview for real; the pixel-ratio cap (2 of 3) is approximated by scaling each
## picture to 2/3 and back (the browser stretches a 2/3 canvas the same way). Writes <prefix><shot>.png (1080x1920)
## to docs/art/screens/perf-iphone-2/ (--out=DIR).

var out := "res://../docs/art/screens/perf-iphone-2"
var prefix := ""
var phone := false
var p: Player


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--prefix="):
			prefix = a.substr(9)
		elif a == "--phone":
			phone = true
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	var full := Vector2i(1080, 1920)
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
	if phone:
		var s := img.get_size()
		img.resize(s.x * 2 / 3, s.y * 2 / 3, Image.INTERPOLATE_BILINEAR)
		img.resize(s.x, s.y, Image.INTERPOLATE_BILINEAR)
	var path := out.path_join("%s%s.png" % [prefix, nm])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _main(intro: bool) -> Node:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.intro = intro
	root.add_child(m)
	if phone:
		root.get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	await _wait(1.0)
	if is_instance_valid(m.welcome):
		m.welcome.ok_button.pressed.emit()
	return m


func _area(m: Node, area: String) -> void:
	var z: Dictionary = m.area_zone(area)
	p.stand_up()
	p.walking_to = false
	p.global_position = z["approach"]
	p.velocity = Vector3.ZERO
	p.rig.focus_on(area)
	p.rig.snap()
	await _wait(2.5)


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_perf_iphone2_save.json"
	needs.new_game()
	needs.set_avatar(preload("res://scripts/avatar.gd").default_record(), "Mai", "")
	for k in needs.meters:
		needs.meters[k] = 60.0
	var m := await _main(true)
	await _wait(2.0)
	await _shot("01-start")
	m.queue_free()
	await _wait(0.5)
	m = await _main(false)
	p = m.player
	m.open_creator()
	if phone and is_instance_valid(m.creator) and m.creator._preview:
		m.creator._preview.msaa_3d = Viewport.MSAA_DISABLED
	await _wait(2.0)
	await _shot("02-creator")
	m.close_creator()
	await _wait(0.5)
	await _area(m, "bar")
	await _shot("03-bar")
	await _area(m, "lounge")
	await _shot("04-lounge")
	quit()
