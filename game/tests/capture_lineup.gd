extends SceneTree
## Real-window screenshots for the HUD live chip (act on stage now), Who's playing tonight + the Calendar tab (tonight-lineup, 2026-11-20; not a pass/fail
## test). Clock pinned: a lineup night (Wed 18 Nov 22:00, Mut Matthew on stage), the special night (Thu 19, John Mayer
## Night 23:00), a closed Monday (23 Nov), a week without data (Tue 24), the calendar (Fri 20, then Thu 19 tapped) and Thai.
##   godot --path . --resolution 540x960 --script res://tests/capture_lineup.gd -- <out dir> <suffix>

const TE = preload("res://scripts/tonight_events.gd")

var out_dir := "res://../docs/art/screens/tonight-lineup"
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


func _open(at: Array) -> void:
	TE.now_override = TE.bkk_unix(at[0], at[1], at[2], at[3], at[4])
	main.open_tonight()
	await _wait(0.6)


func _close() -> void:
	main.tonight.close()
	await _wait(0.3)


func _scroll_down() -> void:
	var sc: ScrollContainer = main.tonight.find_child("Scroll", true, false)
	sc.scroll_vertical = 100000
	await _wait(0.3)


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_lineup_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.5)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	await _wait(1.0)
	for c in [[[2026, 11, 20, 23, 30], "0a-hud-on-stage-fri20"], [[2026, 11, 18, 21, 5], "0b-hud-between-sets-wed18"],
			[[2026, 11, 16, 21, 0], "0c-hud-closed-mon16-next-tue"]]:
		var h: Array = c[0]
		TE.now_override = TE.bkk_unix(h[0], h[1], h[2], h[3], h[4])
		await _wait(0.6)
		await _shot(c[1])
	await _open([2026, 11, 18, 22, 0])
	await _shot("1-lineup-wed18")
	var c: Control = main.tonight.act_cards[1]
	(main.tonight.find_child("Scroll", true, false) as ScrollContainer).ensure_control_visible(c)
	await _wait(0.3)
	await _shot("2-lineup-wed18-now")
	await _close()
	await _open([2026, 11, 19, 23, 0])
	await _shot("3-special-thu19")
	await _scroll_down()
	await _shot("4-special-thu19-program")
	await _close()
	await _open([2026, 11, 23, 21, 0])
	await _shot("5-closed-mon23")
	await _close()
	await _open([2026, 11, 24, 21, 0])
	await _shot("6-empty-tue24")
	await _close()
	await _open([2026, 11, 20, 21, 30])
	main.tonight.show_mode("calendar")
	await _wait(0.4)
	await _shot("7-calendar-fri20")
	main.tonight.select_day("2026-11-19")
	await _wait(0.4)
	await _scroll_down()
	await _shot("8-calendar-thu19-tapped")
	await _close()
	TranslationServer.set_locale("th")
	main.hud.retitle()
	await _open([2026, 11, 18, 22, 0])
	await _shot("9-lineup-th")
	main.tonight.show_mode("calendar")
	await _wait(0.4)
	await _shot("10-calendar-th")
	await _close()
	TranslationServer.set_locale("en")
	TE.now_override = -1
	quit(0)
