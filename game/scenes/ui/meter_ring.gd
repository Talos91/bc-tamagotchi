extends Control
## One compact need ring (wireframes §3, `(M)(F)(D)(N)`): the need glyph inside an arc that fills with the meter.
## `low` makes it breathe (the lowest meter). `value` eases toward `target` so gains animate live.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const Glyph = preload("res://scripts/minigames/need_glyph.gd")

var need := "music"
var target := 0.0
var value := 0.0
var low := false
var _glyph: Control
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(UI.dp(44), UI.dp(44))
	pivot_offset = custom_minimum_size * 0.5
	_glyph = Glyph.new()
	_glyph.need = need
	_glyph.custom_minimum_size = Vector2(UI.dp(22), UI.dp(22))
	_glyph.size = _glyph.custom_minimum_size
	_glyph.position = (custom_minimum_size - _glyph.size) * 0.5
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
	var s := 1.0 + (0.07 * (0.5 + 0.5 * sin(_t * TAU / 1.6)) if low else 0.0)
	scale = Vector2(s, s)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - UI.dp(3)
	var col := UI.need_color(need)
	draw_circle(c, r + UI.dp(2), Color(UI.BG_DEEP, 0.85))
	draw_arc(c, r, 0, TAU, 48, Color(UI.LINE, 0.9), UI.dp(3.5), true)
	var frac := clampf(value / 100.0, 0.0, 1.0)
	if frac > 0.002:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * frac, maxi(4, int(48 * frac)), col, UI.dp(3.5), true)
	if low:
		draw_arc(c, r + UI.dp(4), 0, TAU, 48, Color(col, 0.35 + 0.3 * sin(_t * TAU / 1.6)), UI.dp(1.5), true)
