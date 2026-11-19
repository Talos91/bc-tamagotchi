extends Control
## Need pictograms as neon tubes (I2, Daniele 2026-11-19; spec docs/design/12-ui-notch.md §2): beamed eighth notes
## (music), two people (friends), cocktail glass with an olive (drinks), disco ball with a sparkle (nightlife), and a
## heart. Each stroke is drawn as a tube: two soft glow passes, the coloured tube, then a pale hot core, like the bar's
## own signs. Drawn with primitives, no emoji, no font, no texture. Set `need` to music / friends / drinks / nightlife /
## heart. `tint` overrides the colour; `ring` adds a tube circle around the glyph; `glow` 0 draws the tube without halo.

const UI = preload("res://scripts/minigames/mg_ui.gd")

var need := "music":
	set(v):
		need = v
		queue_redraw()
var tint := Color(0, 0, 0, 0)  # transparent = use the need's own colour
var ring := false
var glow := 1.0

var _o := Vector2.ZERO
var _u := 1.0
var _w := 2.0
var _c := Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(UI.dp(36), UI.dp(36))


func _draw() -> void:
	_c = tint if tint.a > 0.0 else UI.need_color(need)
	if need == "heart" and tint.a <= 0.0:
		_c = UI.NEON
	var s := minf(size.x, size.y)
	_o = (size - Vector2(s, s)) * 0.5
	_u = s / 24.0
	# Tubes thicken a little at small sizes so they still read at 22 dp (the spec's I2 caveat).
	_w = maxf(1.9 * _u, 2.4)
	if ring:
		_tube(_arc(Vector2(12, 12), 11.2, 0.0, TAU, 40))
	match need:
		"music":
			_tube(_ellipse(Vector2(7.2, 18.2), 2.9, 2.1, -0.4))
			_tube(_ellipse(Vector2(17.2, 16.2), 2.9, 2.1, -0.4))
			_tube(_pts([Vector2(9.8, 17.4), Vector2(9.8, 5.6), Vector2(19.8, 3.6), Vector2(19.8, 15.4)]))
			_tube(_pts([Vector2(9.8, 9.0), Vector2(19.8, 7.0)]))
		"friends":
			_tube(_arc(Vector2(16.4, 7.4), 2.9, 0.0, TAU, 20))
			_tube(_arc(Vector2(16.8, 19.6), 5.6, PI * 1.42, TAU, 12))
			_tube(_arc(Vector2(9.0, 9.4), 3.3, 0.0, TAU, 22))
			_tube(_arc(Vector2(9.0, 22.2), 6.6, PI, TAU, 18))
		"drinks":
			_tube(_pts([Vector2(3.6, 5.0), Vector2(20.4, 5.0), Vector2(12, 13.6), Vector2(3.6, 5.0)]))
			_tube(_pts([Vector2(12, 13.6), Vector2(12, 20.2)]))
			_tube(_pts([Vector2(7.4, 20.6), Vector2(16.6, 20.6)]))
			_tube(_pts([Vector2(13.4, 8.6), Vector2(18.6, 1.8)]))
			_tube(_arc(Vector2(12.6, 9.4), 1.5, 0.0, TAU, 12))
		"nightlife":
			var cen := Vector2(11.0, 14.0)
			_tube(_pts([Vector2(11.0, 2.4), Vector2(11.0, 6.6)]))
			_tube(_arc(cen, 7.2, 0.0, TAU, 32))
			_tube(_ellipse(cen, 3.0, 7.2, 0.0))
			_tube(_pts([Vector2(4.0, 14.0), Vector2(18.0, 14.0)]))
			_tube(_pts([Vector2(5.4, 10.4), Vector2(16.6, 10.4)]))
			_tube(_pts([Vector2(5.4, 17.6), Vector2(16.6, 17.6)]))
			_sparkle(Vector2(19.6, 4.6), 2.8)
		"heart":
			var hp := PackedVector2Array()
			for i in 41:
				var t := i / 40.0 * TAU
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				hp.append(_o + (Vector2(12, 11.5) + Vector2(x, y) * 0.62) * _u)
			draw_colored_polygon(hp, Color(_c, 0.35))
			_tube_px(hp)


## One neon tube along grid points (24-unit grid): glow, glow, tube, hot core.
func _tube(grid: PackedVector2Array) -> void:
	var px := PackedVector2Array()
	for p in grid:
		px.append(_o + p * _u)
	_tube_px(px)


func _tube_px(px: PackedVector2Array) -> void:
	if glow > 0.0:
		draw_polyline(px, Color(_c, 0.10 * glow), _w * 4.0, true)
		draw_polyline(px, Color(_c, 0.24 * glow), _w * 2.3, true)
	draw_polyline(px, _c, _w, true)
	draw_polyline(px, _c.lerp(Color.WHITE, 0.6), maxf(_w * 0.38, 1.0), true)


func _pts(a: Array) -> PackedVector2Array:
	return PackedVector2Array(a)


func _arc(c: Vector2, r: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		p.append(c + Vector2(cos(a), sin(a)) * r)
	return p


func _ellipse(c: Vector2, rx: float, ry: float, rot: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return p


## Four-point star: a filled diamond pinched at the waist, glow behind.
func _sparkle(c: Vector2, r: float) -> void:
	var p := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0 - PI * 0.5
		var rr := r if i % 2 == 0 else r * 0.32
		p.append(_o + (c + Vector2(cos(a), sin(a)) * rr) * _u)
	if glow > 0.0:
		draw_circle(_o + c * _u, r * _u * 1.1, Color(_c, 0.16 * glow))
	draw_colored_polygon(p, _c.lerp(Color.WHITE, 0.45))
