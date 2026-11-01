extends Button
## HUD orientation toggle (top right, scripts/ui/orientation.gd): a round button with a phone outline drawn in the
## orientation it switches to, and a turn arrow. Tooltip and accessible name come from strings_ui.csv.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const Orientation = preload("res://scripts/ui/orientation.gd")
const U = preload("res://scripts/ui/ui_strings.gd")

const SIZE_DP := 44.0


func _ready() -> void:
	name = "OrientationToggle"
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(UI.dp(SIZE_DP), UI.dp(SIZE_DP))
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for st in ["normal", "hover", "pressed"]:
		add_theme_stylebox_override(st, UI.box(UI.BG_PLUM if st == "pressed" else Color(UI.BG_BASE, 0.85), SIZE_DP * 0.5, UI.LINE, 2.0))
	get_viewport().size_changed.connect(refresh)
	refresh()


## Re-reads the orientation (after the toggle, F7 or a language switch).
func refresh() -> void:
	var key := "ui.orientation.to_portrait" if Orientation.current() == Orientation.LANDSCAPE else "ui.orientation.to_landscape"
	tooltip_text = U.t(key)
	accessibility_name = tooltip_text
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var to_land := Orientation.current() == Orientation.PORTRAIT
	var long := UI.dp(17)
	var short := UI.dp(11)
	var ph := Vector2(long, short) if to_land else Vector2(short, long)
	var rect := Rect2(c - ph * 0.5 + Vector2(UI.dp(1.5), UI.dp(1.5)), ph)
	var w := UI.dp(2)
	draw_rect(rect, UI.CREAM, false, w)
	# speaker dot on the phone's short edge
	var dot := Vector2(rect.end.x - UI.dp(3), rect.get_center().y) if to_land else Vector2(rect.get_center().x, rect.position.y + UI.dp(3))
	draw_circle(dot, UI.dp(1.2), UI.CREAM)
	# turn arrow round the top-left corner
	var r := UI.dp(13)
	var a0 := PI * 1.05
	var a1 := PI * 1.45
	draw_arc(c, r, a0, a1, 12, UI.GOLD, w, true)
	var tip := c + Vector2(cos(a1), sin(a1)) * r
	var along := Vector2(-sin(a1), cos(a1))  # direction of travel at the tip
	var side := Vector2(cos(a1), sin(a1))
	var hs := UI.dp(4)
	draw_colored_polygon(PackedVector2Array([tip + along * hs, tip - along * hs * 0.4 + side * hs, tip - along * hs * 0.4 - side * hs]), UI.GOLD)
