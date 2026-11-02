extends SceneTree
## Real-window screenshots for the menu follow-ups (not a pass/fail test): the bar sheet (Coke row, Try something new),
## the menu list's Bundles tab, and the bar sheet again after a menu order marked the offered drink as tried.
##   godot --path . --resolution 1080x1920 --script res://tests/capture_menu_followups.gd -- --skip-intro --capture-size=1080x1920 <out dir> <suffix>

var out_dir := "res://../docs/art/screens/menu-followups"
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
	needs.save_path = "user://capture_menu_followups_save.json"
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
	main.menu_list.show_tab("bundles")
	await _wait(0.5)
	await _shot("2-menu-bundles")
	# Order the drink Try something new offers, from the menu: it is marked tried and the Try row moves on
	var offered: String = main.session.next_new_drink()
	main.menu_list.show_tab("drinks")
	main.menu_list.item_chosen.emit(offered)
	await _wait(1.2)
	await _shot("3-ordered-from-menu")
	main.open_sheet(main.zones.current)
	await _wait(0.5)
	await _shot("4-bar-sheet-after-menu-order")
	print("offered first: ", offered, " now offered: ", main.session.next_new_drink(), " tried: ", main.session.tried_count())
	quit(0)
