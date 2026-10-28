extends Control
## Proximity prompt (wireframes §3 context hint, bottom third): one pill naming what this spot offers.
## Tap it, or press E / Space / Enter on a keyboard, to open the zone's sheet.

signal pressed

const UI = preload("res://scripts/minigames/mg_ui.gd")
const T = preload("res://scripts/zones/venue_strings.gd")

var pill: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill = Button.new()
	pill.name = "Pill"
	pill.focus_mode = Control.FOCUS_NONE
	pill.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pill.offset_bottom = -UI.dp(118)
	pill.custom_minimum_size = Vector2(UI.dp(250), UI.dp(56))
	pill.add_theme_font_size_override("font_size", int(UI.dp(16)))
	pill.add_theme_stylebox_override("normal", UI.box(Color(UI.BG_DEEP, 0.92), 28, UI.GOLD, 2.0))
	pill.add_theme_stylebox_override("hover", UI.box(Color(UI.BG_DEEP, 0.92), 28, UI.GOLD, 2.0))
	pill.add_theme_stylebox_override("pressed", UI.box(UI.BG_PLUM, 28, UI.GOLD, 2.0))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		pill.add_theme_color_override(c, UI.CREAM)
	pill.pressed.connect(func(): pressed.emit())
	add_child(pill)
	pill.visible = false


## Shows `text` (empty hides). Keyboard players see the key hint too.
func show_text(text: String) -> void:
	pill.visible = text != ""
	pill.text = "  %s   [E]  " % text if text != "" and not DisplayServer.is_touchscreen_available() else "  %s  " % text
	var ms := pill.get_combined_minimum_size()
	pill.offset_left = -ms.x * 0.5
	pill.offset_right = ms.x * 0.5
	pill.offset_top = pill.offset_bottom - ms.y


func is_showing() -> bool:
	return pill.visible
