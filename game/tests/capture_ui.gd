extends SceneTree
## Screenshots for the brand fonts (Lato, Kristi titles, Thai fallback) and the orientation toggle, one orientation per
## run, English then Thai, at half of 1080x1920 / 1920x1080 (as capture_start.gd: a full-size window is clipped to the
## screen; the canvas_items stretch lays the UI out exactly as at full size):
##   godot --path . --resolution 540x960 --script res://tests/capture_ui.gd -- --tag=portrait
##   godot --path . --resolution 960x540 --script res://tests/capture_ui.gd -- --tag=landscape
## Writes to docs/art/screens/ui/ (override with --out=DIR):
##   hud-<tag>-<lang>       the HUD at the bar, the zone name still large (Kristi)
##   result-<tag>-<lang>    a Pour Perfect result card over the room (heading in Kristi)
##   welcome-<tag>-<lang>   Welcome Back (heading in Kristi)
##   toggle-<tag>           the HUD with the orientation toggle ringed in neon

const ResultCardScene = preload("res://scenes/ui/result_card.tscn")
const UI = preload("res://scripts/minigames/mg_ui.gd")

var out := ""
var tag := "portrait"


func _init() -> void:
	out = "res://../docs/art/screens/ui"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var needs := root.get_node_or_null("Needs")
	needs.autosave = false
	needs.new_game()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(30)
	var bar: Dictionary = main.zones.first_of("bar")
	main.player.global_position = bar["approach"] + Vector3(0, 0.1, 0)
	main.player.rig.snap()
	await _frames(90)
	for lang in ["en", "th"]:
		TranslationServer.set_locale(lang)
		main._on_zone_changed(main.zones.current)
		main.hud.retitle()
		await _frames(20)
		_save("hud-%s-%s" % [tag, lang])
		if lang == "en":
			var ring := Panel.new()
			var sb := UI.box(Color(0, 0, 0, 0), 30, UI.NEON, 6.0)
			ring.add_theme_stylebox_override("panel", sb)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			main.overlay.add_child(ring)
			ring.global_position = main.hud.orientation_toggle.get_global_rect().grow(UI.dp(6)).position
			ring.size = main.hud.orientation_toggle.get_global_rect().grow(UI.dp(6)).size
			main.hud.retitle()
			await _frames(4)
			_save("toggle-%s" % tag)
			ring.queue_free()
		main.hud.visible = false
		main.get_node("UI/Joystick").visible = false
		# built from a fixed outcome (no refill applied) so both languages show the same card
		var card: Control = ResultCardScene.instantiate()
		card.needs = needs
		main.overlay.add_child(card)
		card._build({"game_id": "pour_perfect", "tier": 2, "points": 92},
			{"ok": true, "gains": {"drinks": 25.0}, "tab": 0.0, "best": 92, "new_best": false, "again_ok": true})
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames(6)
		_save("result-%s-%s" % [tag, lang])
		card.queue_free()
		main._on_welcome_back("away")
		await _frames(6)
		_save("welcome-%s-%s" % [tag, lang])
		main.welcome.ok_button.pressed.emit()
		await _frames(4)
		main.hud.visible = true
		main.get_node("UI/Joystick").visible = true
	TranslationServer.set_locale("en")
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := out.path_join(name + ".png")
	print("capture ", path, " ", img.get_size(), " -> ", img.save_png(path))
