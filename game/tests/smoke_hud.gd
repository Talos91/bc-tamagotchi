extends SceneTree
## Headless smoke test: main.tscn boots with the Needs autoload and the debug HUD, the HUD opens and an action runs.
##   godot --headless --path . --script res://tests/smoke_hud.gd

func _init() -> void:
	await process_frame  # autoloads finish _ready after _init
	var needs: Node = root.get_node_or_null("Needs")
	if needs == null:
		print("SMOKE HUD FAIL: Needs autoload missing")
		quit(1)
		return
	needs.autosave = false
	needs.new_game()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var hud: Control = main.get_node_or_null("UI/NeedsDebug")
	var ok := hud != null
	if ok:
		hud._toggle.pressed.emit()
		ok = hud._panel.visible
		var before: float = needs.meters["drinks"]
		needs.meters["drinks"] = 20.0
		hud._do_action("order_drink")
		await process_frame
		ok = ok and needs.meters["drinks"] > 20.0 and hud._bars["drinks"].value > 20.0
		hud._clock_btn.pressed.emit()
		ok = ok and needs.multiplier == 60.0
		print("hud drinks bar: ", hud._bars["drinks"].value, " (was ", before, "), multiplier ", needs.multiplier)
	ok = _check_thai(main) and ok
	print("SMOKE HUD ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)


## Thai lays out with the bundled fonts: the project theme is ours, has Thai glyphs, and a Thai Label gets width and height.
func _check_thai(main: Node) -> bool:
	var theme := ThemeDB.get_project_theme()
	var font: Font = theme.default_font if theme != null else null
	if font == null or not font.has_char(0x0E01):
		print("thai: project theme has no default font with Thai glyphs")
		return false
	var thai := "สวัสดีครับ น้ำเลื่อนแก้วมาให้"
	var w := font.get_string_size(thai, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var l := Label.new()
	l.text = thai
	main.add_child(l)
	var size := l.get_minimum_size()
	l.queue_free()
	for variation in ["LabelDisplayXL", "LabelDisplayL", "LabelBody"]:
		var f: Font = theme.get_font("font", variation)
		if f == null or not f.has_char(0x0E01) or f.get_string_size(thai, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x <= 0.0:
			print("thai: ", variation, " cannot lay out Thai")
			return false
	print("thai: string width ", w, ", label min size ", size)
	return w > 0.0 and size.x > 0.0 and size.y > 0.0
