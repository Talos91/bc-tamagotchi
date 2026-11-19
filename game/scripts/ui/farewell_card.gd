extends Control
## The farewell card (06-stakes §6, §10.5): shown when the ghost window ran out or after Retire. The game keeps no copy;
## DONE calls Needs.complete_deletion() (the caller does) and a new game starts at character creation.

signal done

const UI = preload("res://scripts/minigames/mg_ui.gd")
const Skin = preload("res://scripts/ui/bc_skin.gd")
const T = preload("res://scripts/zones/venue_strings.gd")


## `who` the character's name ("" = a stand-in), `nights` nights out, `lives` lives.
func open(who: String, nights: int, lives: int) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UI.BG_DEEP, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(UI.dp(330), 0)
	var pb := Skin.panel_box(20.0, true, 0.97)   # D2 Back-bar (bc_skin.gd)
	pb.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", pb)
	Skin.led_strip(panel)
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(UI.dp(18)))
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UI.dp(10)))
	pad.add_child(col)
	if who == "":
		who = T.t("venue.stake.name_fallback")
	col.add_child(UI.title(T.t("venue.stake.farewell.title", {"name": who}), 28))
	col.add_child(UI.label(T.t("venue.stake.farewell.stats", {"n": nights, "lives": lives}), 15, UI.CREAM))
	col.add_child(UI.wrap(UI.label(T.t("venue.stake.farewell.body"), 14, UI.SMOKE)))
	var btn := UI.button(T.t("venue.stake.farewell.done"), "primary")
	btn.pressed.connect(func(): done.emit())
	col.add_child(btn)
