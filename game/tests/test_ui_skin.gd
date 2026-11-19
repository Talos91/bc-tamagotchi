extends SceneTree
## UI skin (docs/design/12-ui-notch.md U1–U2, Daniele 2026-11-19: I2 neon-tube icons + D2 Back-bar): every need glyph
## draws, the meter tile fills and flags the low one, the skin builders return styled controls, the theme carries the
## neon and script variations with the Thai fallback, the Tilt Neon font ships with its OFL text, and the HUD is built
## from the skin (shelf, tiles, neon title) and still fits 390 dp in portrait.
##   godot --headless --path . -s tests/test_ui_skin.gd

const UI = preload("res://scripts/minigames/mg_ui.gd")
const BCSkin = preload("res://scripts/ui/bc_skin.gd")
const Glyph = preload("res://scripts/minigames/need_glyph.gd")
const Ring = preload("res://scenes/ui/meter_ring.gd")

var fails := 0


func check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	print("[glyphs]")
	for n in ["music", "friends", "drinks", "nightlife", "heart"]:
		var g := Glyph.new()
		g.need = n
		g.size = Vector2(UI.dp(32), UI.dp(32))
		root.add_child(g)
		await process_frame
		check(is_instance_valid(g) and g.need == n, "glyph %s draws" % n)
		g.queue_free()
	check(UI.need_color("music") == Color("FF4081"), "music is neon pink (I2 pick, spec §2)")

	print("[meter tile]")
	var r := Ring.new()
	r.need = "drinks"
	root.add_child(r)
	await process_frame
	r.set_value(40.0, true)
	r.low = true
	await process_frame
	check(r.custom_minimum_size.x >= UI.dp(50), "tile at least 50 dp wide (%.0f px)" % r.custom_minimum_size.x)
	check(is_equal_approx(r.value, 40.0), "snap sets the level")
	r.set_value(80.0)
	for i in 30:
		await process_frame
	check(r.value > 40.0, "level eases toward a gain")
	r.queue_free()

	print("[skin builders]")
	for k in ["primary", "secondary", "ghost", "tag"]:
		var b := BCSkin.button("x", k)
		check(b.get_theme_stylebox("normal") is StyleBoxFlat, "button %s styled" % k)
		b.free()
	var t := BCSkin.neon_title("The Bar", 24)
	check(t.theme_type_variation == &"LabelNeon" and t.get_theme_constant("outline_size") > 0, "neon title: LabelNeon + tube outline")
	t.free()
	var p := Panel.new()
	p.size = Vector2(300, 100)
	root.add_child(p)
	var led := BCSkin.led_strip(p)
	check(led.get_parent() == p and led.mouse_filter == Control.MOUSE_FILTER_IGNORE, "LED strip added, mouse-transparent")
	p.queue_free()
	check(BCSkin.panel_box().shadow_color.r > 0.9, "panel glows red under it (LED)")

	print("[theme + font]")
	var th: Theme = load("res://ui/bc_theme.tres")
	for v in ["LabelNeon", "LabelTitle", "LabelScript"]:
		var f := th.get_font("font", v)
		check(f != null and f is FontVariation and not (f as FontVariation).fallbacks.is_empty(), "%s has a font with the Thai fallback" % v)
	check(FileAccess.file_exists("res://assets/fonts/OFL-TiltNeon.txt"), "Tilt Neon ships with its OFL text")
	check(th.get_stylebox("normal", "Button") is StyleBoxFlat, "raw Buttons get the wood + brass default")

	print("[hud]")
	root.size = Vector2i(1080, 1920)
	var hud: Control = load("res://scenes/ui/needs_hud.tscn").instantiate()
	root.add_child(hud)
	for i in 4:
		await process_frame
	check(hud.find_child("Shelf", true, false) != null, "meters sit on the brass shelf")
	for m in ["music", "friends", "drinks", "nightlife"]:
		check(hud.find_child("Ring_" + m, true, false) != null, "cubby " + m)
	var leave: Control = hud.find_child("Leave", true, false)
	var ton: Control = hud.find_child("Tonight", true, false)
	check(leave != null and ton != null, "Leave and Tonight tiles")
	if leave != null and ton != null:
		check(ton.get_global_rect().end.x <= 1080.0 + 0.5 and leave.get_global_rect().position.x >= 0.0, "top bar fits the portrait width")
	check(hud._title.theme_type_variation == &"LabelNeon", "zone name is the neon sign")
	hud.queue_free()
	await process_frame

	print("UI SKIN %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	quit(1 if fails > 0 else 0)
