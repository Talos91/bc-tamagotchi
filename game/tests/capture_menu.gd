extends SceneTree
## Real-window screenshot run for the real menu (not a pass/fail test). Bar sheet, the menu list (drinks and
## kitchen) and Pour Perfect pouring a real drink, from main.tscn at the bar.
##   godot --path . --resolution 1080x1920 --script res://tests/capture_menu.gd -- --skip-intro --capture-size=1080x1920 <out dir> <suffix>
## (--capture-size makes main.gd size the window borderless so it is not clamped to the screen.)
## suffix: "portrait" or "landscape" (only names the files).

var out_dir := "res://../docs/art/screens/menu"
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
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_menu_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 40.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	var z: Dictionary = main.zones.first_of("bar")
	main.player.global_position = z["approach"] + Vector3(0, 0.1, 0)
	main.player.rig.snap()
	await _wait(1.5)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	main.open_sheet(main.zones.current)
	await _wait(0.6)
	await _shot("1-bar-sheet")
	main.sheet.buttons["menu"].pressed.emit()
	await _wait(0.6)
	await _shot("2-menu-drinks")
	main.menu_list.show_tab("kitchen")
	await _wait(0.4)
	await _shot("3-menu-kitchen")
	main.menu_list.item_chosen.emit("guinness_draught")
	await _wait(1.2)
	await _shot("4-ordered-guinness")
	main.open_sheet(main.zones.current)
	await _wait(0.3)
	main.session.pours_this_visit = 2  # third featured pour: Guinness Draught, to show the stout layers
	main.sheet.buttons["pour"].pressed.emit()
	await _wait(1.9)
	var g = main.frame.game
	g.press()
	await _wait(5.2)
	g.release()
	await _wait(1.0)
	g.press()
	await _wait(2.4)
	await _shot("5-pour-perfect-" + g.drink_id)
	quit(0)
