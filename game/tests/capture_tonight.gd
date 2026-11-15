extends SceneTree
## Real-window screenshots for the Tonight sheet (docs/design/09-tonight-events.md; not a pass/fail test): the HUD with
## the Tonight button, then the sheet with the clock pinned to four evenings: The Cabin Jam (21 Oct, lineup), a regular
## night (23 Oct), a closed Monday (19 Oct) and today's case, a month with no data (15 Nov), plus Thai.
##   godot --path . --resolution 1080x1920 --script res://tests/capture_tonight.gd -- --skip-intro --capture-size=1080x1920 <out dir> <suffix>

const TE = preload("res://scripts/tonight_events.gd")

var out_dir := "res://../docs/art/screens/tonight"
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


func _sheet_at(unix: int, name: String) -> void:
	TE.now_override = unix
	main.open_tonight()
	await _wait(0.6)
	await _shot(name)
	main.tonight.close()
	await _wait(0.3)


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_tonight_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.5)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	await _wait(1.0)
	await _shot("0-hud-button")
	await _sheet_at(TE.bkk_unix(2026, 10, 21, 21, 30), "1-cabin-jam")
	await _sheet_at(TE.bkk_unix(2026, 10, 23, 20, 0), "2-regular-night")
	await _sheet_at(TE.bkk_unix(2026, 10, 19, 20, 0), "3-closed-monday")
	await _sheet_at(TE.bkk_unix(2026, 11, 15, 20, 0), "4-no-data-november")
	TranslationServer.set_locale("th")
	main.hud.retitle()
	await _sheet_at(TE.bkk_unix(2026, 10, 21, 21, 30), "5-cabin-jam-th")
	TranslationServer.set_locale("en")
	TE.now_override = -1
	quit(0)
