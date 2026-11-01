extends SceneTree

const Orientation = preload("res://scripts/ui/orientation.gd")
## Headless smoke test: main.tscn boots with the Needs autoload and the debug HUD, the HUD opens and an action runs;
## Thai lays out in every theme font; the orientation toggle sits top right clear of the rings and Leave, flips and saves.
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
	ok = await _check_orientation(main, needs) and ok
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
	for variation in ["LabelDisplayXL", "LabelDisplayL", "LabelBody", "LabelTitle"]:
		var f: Font = theme.get_font("font", variation)
		if f == null or not f.has_char(0x0E01) or f.get_string_size(thai, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x <= 0.0:
			print("thai: ", variation, " cannot lay out Thai")
			return false
	print("thai: string width ", w, ", label min size ", size)
	return w > 0.0 and size.x > 0.0 and size.y > 0.0


## Orientation toggle (DECISIONS 2026-11-02, portrait first): top right of the HUD, clear of the need rings and Leave
## in portrait and landscape, in English and Thai; a press flips the orientation and records it in the save; hidden
## with the HUD while the start screen runs.
func _check_orientation(main: Node, needs: Node) -> bool:
	var hud: Control = main.get_node("UI/Hud")
	var btn: Button = hud.orientation_toggle
	if btn == null or not btn.is_visible_in_tree():
		print("orientation: no visible toggle on the HUD")
		return false
	needs.ext.erase(Orientation.EXT_KEY)
	root.size = Vector2i(1080, 1920)
	var ok := await _toggle_clear(hud, Orientation.PORTRAIT, "portrait en")
	btn.pressed.emit()
	ok = ok and Orientation.saved(needs) == Orientation.LANDSCAPE
	ok = await _toggle_clear(hud, Orientation.LANDSCAPE, "landscape en") and ok
	TranslationServer.set_locale("th")
	hud.retitle()
	ok = await _toggle_clear(hud, Orientation.LANDSCAPE, "landscape th") and ok
	var th_tip := btn.tooltip_text
	btn.pressed.emit()
	ok = ok and Orientation.saved(needs) == Orientation.PORTRAIT
	ok = await _toggle_clear(hud, Orientation.PORTRAIT, "portrait th") and ok
	ok = ok and th_tip == "แนวตั้ง" and btn.tooltip_text == "แนวนอน"
	TranslationServer.set_locale("en")
	hud.retitle()
	ok = ok and btn.tooltip_text == "Landscape"
	# not on the start screen: the HUD (and the toggle with it) is hidden while it runs
	var blocker := Node.new()
	main.add_child(blocker)
	main.start_screen = blocker
	main._sync_block()
	var hidden_on_start := not btn.is_visible_in_tree()
	main.start_screen = null
	blocker.queue_free()
	main._sync_block()
	ok = ok and hidden_on_start and btn.is_visible_in_tree()
	print("orientation: saved ", needs.ext.get(Orientation.EXT_KEY), ", thai tip ", th_tip, ", hidden on start screen ", hidden_on_start)
	return ok


func _toggle_clear(hud: Control, want: String, tag: String) -> bool:
	for i in 3:
		await process_frame
	var btn: Button = hud.orientation_toggle
	var vp := root.get_visible_rect()
	var r := btn.get_global_rect()
	var ok := Orientation.current() == want and vp.encloses(r) 		and r.get_center().x > vp.size.x * 0.75 and r.get_center().y < vp.size.y * 0.25 		and r.size.x >= 40.0 * 2.7
	var hits: Array = []
	for c: Control in hud.find_children("*", "Control", true, false):
		if (c.name == "Leave" or str(c.name).begins_with("Ring_")) and c.get_global_rect().intersects(r):
			hits.append(c.name)
	ok = ok and hits.is_empty()
	print("orientation ", tag, ": viewport ", vp.size, ", toggle ", r, ", overlaps ", hits, " -> ", "ok" if ok else "FAIL")
	return ok
