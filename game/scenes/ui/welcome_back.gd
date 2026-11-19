extends Control
## Welcome Back dialogue (GDD §2.5): Nam says hello by name, the first drink is on her, and everything counts double
## for 15 minutes (the x2 replaces the daily multiplier; Needs handles the maths). Never guilt copy.

signal dismissed

const UI = preload("res://scripts/minigames/mg_ui.gd")
const Skin = preload("res://scripts/ui/bc_skin.gd")
const T = preload("res://scripts/zones/venue_strings.gd")
const Rules = preload("res://scripts/rules.gd")

var ok_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(player_name: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(UI.BG_DEEP, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(UI.dp(340), get_viewport_rect().size.x - UI.dp(32)), 0)
	var pb := Skin.panel_box(20.0, true, 0.97)   # D2 Back-bar (bc_skin.gd)
	pb.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", pb)
	Skin.led_strip(panel)
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(UI.dp(20)))
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UI.dp(12)))
	pad.add_child(col)
	col.add_child(UI.title(T.t("venue.welcome.title"), 28))
	col.add_child(UI.label(T.t("venue.cast.nam"), 14, UI.SMOKE))
	var who := player_name if player_name != "" else T.t("venue.welcome.friend")
	col.add_child(UI.wrap(UI.label(T.t("venue.welcome.line", {"name": who}), 18, UI.CREAM)))
	col.add_child(UI.wrap(UI.label("x%d · %s" % [int(Rules.WELCOME_BACK_GAIN_MULT), T.t("venue.welcome.bonus")], 15, UI.GOLD)))
	ok_button = UI.button(T.t("venue.welcome.ok"), "primary")
	ok_button.pressed.connect(func(): dismissed.emit())
	col.add_child(ok_button)
