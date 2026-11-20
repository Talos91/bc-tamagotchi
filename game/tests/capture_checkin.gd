extends SceneTree
## Real-window screenshots of the QR check-in card (owner list 2026-11-20 item 4: "the who can reach out tonight selector
## doesn t work and the only way is to click skip"). Not a pass/fail test (test_presence_client "real checkin (item 4)"
## is the check). Presence in mock mode, a first check-in from Table2's code: the card, a choice made, then Check in.
##   godot --path . --resolution 540x960 --script res://tests/capture_checkin.gd -- --tag=portrait --prefix=after-
## Writes <prefix><tag>-<n>-<state>.png to docs/art/screens/creator-fix/checkin/ (--out=DIR).

var out := "res://../docs/art/screens/creator-fix/checkin"
var tag := "portrait"
var prefix := ""


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
	print("saved ", path)


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_checkin_save.json"
	needs.new_game()
	needs.set_avatar(load("res://scripts/avatar.gd").default_record(), "Ty", "night_owl")   # a character already made
	var pres: Node = root.get_node("Presence")
	pres.reset_local("user://capture_checkin_presence.json")
	var mock: RefCounted = pres.use_mock(true)
	needs.profile.erase("presence_mode")
	pres.set_pending_code(mock.code_for("Table2"))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.intro = true
	root.add_child(main)
	await _wait(1.5)
	var ss: Node = main.start_screen
	var flow: Control = ss._modal.find_child("CheckInFlow", true, false) if is_instance_valid(ss) and is_instance_valid(ss._modal) else null
	if flow == null:
		print("no check-in card")
		quit(1)
		return
	await _shot("1-card")
	flow.choose("here")
	await _wait(0.3)
	await _shot("2-chosen")
	(flow.find_child("CheckIn", true, false) as Button).pressed.emit()
	await _wait(2.0)
	await _shot("3-after-check-in")
	quit(0)
