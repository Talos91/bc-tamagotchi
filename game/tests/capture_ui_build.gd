extends SceneTree
## Real-window screenshots for the UI build (docs/design/12-ui-notch.md U1–U6; not a pass/fail test). One orientation
## per run; half of 1080x1920 / 1920x1080 (the canvas_items stretch lays the UI out exactly as at full size):
##   godot --path . --resolution 540x960 --script res://tests/capture_ui_build.gd -- --tag=portrait --out=DIR
##   godot --path . --resolution 960x540 --script res://tests/capture_ui_build.gd -- --tag=landscape --out=DIR
## --part=start: the start screen title only (needs intro); --part=venue (default): HUD at the bar with mixed meters,
## the bar's zone sheet, the Tonight sheet pinned to 21 Oct 2026 (The Cabin Jam), a Pour Perfect result with NEW BEST.

const ResultCardScene = preload("res://scenes/ui/result_card.tscn")
const TE = preload("res://scripts/tonight_events.gd")

var out := ""
var tag := "portrait"
var part := "venue"


func _init() -> void:
	out = "res://../docs/art/screens/ui-build"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--part="):
			part = a.substr(7)
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var needs := root.get_node_or_null("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_ui_build_save.json"
	if part == "start":
		var m0: Node = load("res://scenes/main.tscn").instantiate()
		m0.intro = true
		root.add_child(m0)
		await _frames(120)
		await _save("start-%s" % tag)
		quit(0)
		return
	needs.new_game()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(30)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	var lv := {"music": 72.0, "friends": 46.0, "drinks": 18.0, "nightlife": 88.0}
	for m in lv:
		needs.meters[m] = lv[m]
		needs.meter_changed.emit(m, lv[m])
	var bar: Dictionary = main.zones.first_of("bar")
	main.player.global_position = bar["approach"] + Vector3(0, 0.1, 0)
	main.player.rig.snap()
	await _frames(120)
	main._on_zone_changed(main.zones.current)
	main.hud.retitle()
	await _frames(10)
	await _save("hud-%s" % tag)
	main.open_sheet(main.zones.current)
	await _frames(20)
	await _save("menu-%s" % tag)
	if is_instance_valid(main.sheet):
		main.sheet.close()
	await _frames(10)
	TE.now_override = TE.bkk_unix(2026, 10, 21, 20)
	main.open_tonight()
	await _frames(30)
	await _save("tonight-%s" % tag)
	main.tonight.close()
	TE.now_override = -1
	await _frames(10)
	main.hud.visible = false
	main.get_node("UI/Joystick").visible = false
	var card: Control = ResultCardScene.instantiate()
	card.needs = needs
	main.overlay.add_child(card)
	card._build({"game_id": "pour_perfect", "tier": 2, "points": 96},
		{"ok": true, "gains": {"drinks": 23.0}, "tab": 0.0, "best": 96, "new_best": true, "again_ok": true})
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if card.has_method("skip_anim"):
		card.skip_anim()
	await _frames(10)
	await _save("result-%s" % tag)
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := out.path_join(name + ".png")
	print("capture ", path, " ", img.get_size(), " -> ", img.save_png(path))
