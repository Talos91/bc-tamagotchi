extends SceneTree
## Captures of the HUD full-screen button (web only, so forced visible here) and the iPhone "Add to Home Screen" hint.
## Not a pass/fail test.
##   godot --path . --resolution 1080x1920 --script res://tests/capture_fullscreen.gd -- <out dir> portrait
##   godot --path . --resolution 1920x1080 --script res://tests/capture_fullscreen.gd -- <out dir> landscape

const FullscreenButton = preload("res://scenes/ui/fullscreen_button.gd")
const U = preload("res://scripts/ui/ui_strings.gd")

var out_dir := "res://../docs/art/screens/perf-iphone-1120"
var suffix := "portrait"
var main: Node

func _initialize() -> void:
	var rest: Array = []
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			rest.append(a)
	if rest.size() > 0:
		out_dir = rest[0]
	if rest.size() > 1:
		suffix = rest[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run()

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir).path_join("%s-%s.png" % [name, suffix])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())

func _run() -> void:
	FullscreenButton.force_show = true
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_fullscreen_save.json"
	needs.new_game()
	needs.profile["display_name"] = "Mali"
	main = load("res://scenes/main.tscn").instantiate()
	main.intro = false
	root.add_child(main)
	await _wait(1.5)
	if is_instance_valid(main.welcome):
		main.welcome.queue_free()
		main.welcome = null
		main._sync_block()
	await _wait(0.5)
	var fb: Button = main.find_child("FullscreenButton", true, false)
	if fb == null:
		print("CAPTURE FAIL: no FullscreenButton")
		quit(1)
		return
	print("button visible=", fb.is_visible_in_tree(), " rect=", fb.get_global_rect())
	await _shot("fs-1-button")
	fb.hint.emit(U.t("ui.fullscreen.ios_hint"))
	await _wait(0.3)
	var hint: Control = main.find_child("FullscreenHint", true, false)
	print("hint visible=", hint != null and hint.is_visible_in_tree(), " rect=", hint.get_global_rect() if hint else Rect2())
	await _shot("fs-2-iphone-hint")
	FullscreenButton.force_show = false
	main.queue_free()
	await _wait(0.3)
	quit(0)
