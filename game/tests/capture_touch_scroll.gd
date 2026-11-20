extends SceneTree
## Real-window screenshots of touch scrolling (owner list 2026-11-20 item 6: "on my phone i cannot scroll"). Not a
## pass/fail test (tests/test_touch_scroll.gd is the check). Each panel is shot, then a finger swipe (ScreenTouch +
## ScreenDrag through Input, as a phone sends them) goes up 40 % of its list starting on a card, and it is shot again.
##   godot --path . --resolution 540x960 --script res://tests/capture_touch_scroll.gd -- --tag=portrait --prefix=after-
## Writes <prefix><tag>-<panel>-<0|1>.png to docs/art/screens/creator-fix/scroll/ (--out=DIR).

var out := "res://../docs/art/screens/creator-fix/scroll"
var tag := "portrait"
var prefix := ""
var main: Node


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
	needs.save_path = "user://capture_touch_scroll_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.5)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	await _wait(0.5)
	main.open_tonight()
	await _pair("tonight", main.tonight)
	for tb in main.tonight.find_children("Tab_calendar", "BaseButton", true, false):
		tb.pressed.emit()
	await _pair("calendar", main.tonight)
	main.tonight.closed.emit()
	await _wait(0.3)
	main.open_menu("drinks")
	await _pair("menu", main.menu_list)
	main.close_menu()
	await _wait(0.3)
	main.open_creator()
	await _pair("creator", main.creator)
	quit(0)


func _pair(nm: String, panel: Node) -> void:
	await _wait(0.6)
	await _shot(nm + "-0")
	var sc: ScrollContainer = null
	for s: ScrollContainer in panel.find_children("*", "ScrollContainer", true, false):
		if s.is_visible_in_tree() and s.get_v_scroll_bar().max_value - s.get_v_scroll_bar().page > 40.0:
			sc = s
			break
	if sc != null:
		var xf := sc.get_global_transform_with_canvas()
		var a: Vector2 = xf * Vector2(sc.size.x * 0.5, sc.size.y * 0.75)
		await _swipe(a, a - Vector2(0, sc.size.y * xf.get_scale().y * 0.4))
	await _wait(0.6)
	await _shot(nm + "-1")


func _swipe(a: Vector2, b: Vector2) -> void:
	var xf := root.get_final_transform()
	var t := InputEventScreenTouch.new()
	t.pressed = true
	t.position = xf * a
	Input.parse_input_event(t)
	await process_frame
	var last: Vector2 = xf * a
	for i in range(1, 11):
		var d := InputEventScreenDrag.new()
		d.position = xf * a.lerp(b, i / 10.0)
		d.relative = d.position - last
		last = d.position
		Input.parse_input_event(d)
		await process_frame
	var u := InputEventScreenTouch.new()
	u.position = last
	Input.parse_input_event(u)
	await process_frame
