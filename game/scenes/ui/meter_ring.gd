extends Control
## One need meter as a lit back-bar cubby (D2 Back-bar + I2 neon icons, Daniele 2026-11-19; spec
## docs/design/12-ui-notch.md §2–3): a dark cubby that fills from the bottom with the need's colour like a glass filling
## up (the level is the meter), a bright surface line, and the need's neon-tube glyph on top. `low` makes it breathe and
## its edge glow (the lowest meter). `value` eases toward `target` so gains animate live. The file keeps its old name
## (and the HUD names the tiles Ring_<need>) so callers and tests stay the same.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const Glyph = preload("res://scripts/minigames/need_glyph.gd")

const TILE := Vector2(52, 50)   # dp

var need := "music"
var target := 0.0
var value := 0.0
var low := false
var _glyph: Control
var _t := 0.0
var _body: StyleBoxFlat
var _fill: StyleBoxFlat
var _edge: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = TILE * UI.DP
	pivot_offset = custom_minimum_size * 0.5
	var r := int(UI.dp(7))
	_body = StyleBoxFlat.new()
	_body.bg_color = Color("0B0505")
	_body.set_corner_radius_all(r)
	_body.border_color = Color("3A2418")
	_body.set_border_width_all(maxi(2, int(UI.dp(1.2))))
	_body.anti_aliasing = true
	_fill = StyleBoxFlat.new()
	_fill.corner_radius_bottom_left = r - 1
	_fill.corner_radius_bottom_right = r - 1
	_fill.anti_aliasing = true
	_edge = StyleBoxFlat.new()
	_edge.draw_center = false
	_edge.set_corner_radius_all(r)
	_edge.set_border_width_all(maxi(2, int(UI.dp(1.6))))
	_edge.anti_aliasing = true
	_glyph = Glyph.new()
	_glyph.need = need
	_glyph.custom_minimum_size = Vector2(UI.dp(32), UI.dp(32))
	_glyph.size = _glyph.custom_minimum_size
	_glyph.position = (custom_minimum_size - _glyph.size) * 0.5 - Vector2(0, UI.dp(1))
	add_child(_glyph)


func set_value(v: float, snap := false) -> void:
	target = v
	if snap:
		value = v
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if absf(value - target) > 0.05:
		value = lerpf(value, target, 1.0 - exp(-6.0 * delta))
		queue_redraw()
	elif low:
		queue_redraw()
	var s := 1.0 + (0.06 * (0.5 + 0.5 * sin(_t * TAU / 1.6)) if low else 0.0)
	scale = Vector2(s, s)


func _draw() -> void:
	var col := UI.need_color(need)
	var rect := Rect2(Vector2.ZERO, size)
	var pulse := 0.5 + 0.5 * sin(_t * TAU / 1.6)
	if low:
		_body.shadow_color = Color(col, 0.30 + 0.25 * pulse)
		_body.shadow_size = int(UI.dp(6))
	else:
		_body.shadow_color = Color(0, 0, 0, 0.45)
		_body.shadow_size = int(UI.dp(2))
	draw_style_box(_body, rect)
	# Back light: a faint wash of the need's colour at the back of the cubby, so an empty one still says which it is.
	var inset := UI.dp(2)
	var inner := rect.grow(-inset)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.45)), Color(col, 0.07))
	var frac := clampf(value / 100.0, 0.0, 1.0)
	if frac > 0.002:
		var h := inner.size.y * frac
		var fr := Rect2(inner.position.x, inner.end.y - h, inner.size.x, h)
		_fill.bg_color = Color(col, 0.34)
		draw_style_box(_fill, fr)
		# Brighter band just under the surface, then the surface line itself.
		var band := minf(h, UI.dp(5))
		draw_rect(Rect2(fr.position, Vector2(fr.size.x, band)), Color(col, 0.28))
		draw_line(fr.position + Vector2(UI.dp(1), 0), Vector2(fr.end.x - UI.dp(1), fr.position.y), col.lerp(Color.WHITE, 0.35), maxf(2.0, UI.dp(1.2)))
	_edge.border_color = Color(col, 0.55 + 0.45 * pulse) if low else Color(UI.GOLD, 0.16)
	draw_style_box(_edge, rect)
