extends Control
## Flat need pictograms (style guide section 4): eighth note, two heads, coupe, crescent moon with a spark.
## Drawn with primitives, no emoji, no font. Set `need` to music / friends / drinks / nightlife / heart.

const UI = preload("res://scripts/minigames/mg_ui.gd")

var need := "music":
	set(v):
		need = v
		queue_redraw()
var tint := Color(0, 0, 0, 0)  # transparent = use the need's own colour
var ring := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(UI.dp(36), UI.dp(36))


func _draw() -> void:
	var c: Color = tint if tint.a > 0.0 else UI.need_color(need)
	if need == "heart" and tint.a <= 0.0:
		c = UI.NEON
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var u := s / 24.0
	if ring:
		draw_arc(size * 0.5, s * 0.5 - 2.0, 0, TAU, 40, c, 3.0, true)
	var w := 2.0 * u
	match need:
		"music":
			draw_circle(o + Vector2(9, 18) * u, 3.4 * u, c)
			draw_line(o + Vector2(12.2, 17.5) * u, o + Vector2(12.2, 4) * u, c, w)
			draw_polyline(PackedVector2Array([o + Vector2(12.2, 4) * u, o + Vector2(18, 6.5) * u, o + Vector2(17, 11) * u]), c, w, true)
		"friends":
			draw_arc(o + Vector2(9, 9.5) * u, 3.6 * u, 0, TAU, 24, c, w, true)
			draw_arc(o + Vector2(15.5, 9.5) * u, 3.6 * u, 0, TAU, 24, c, w, true)
			draw_arc(o + Vector2(12, 22) * u, 7 * u, PI, TAU, 16, c, w, true)
		"drinks":
			draw_polyline(PackedVector2Array([o + Vector2(4, 5) * u, o + Vector2(20, 5) * u, o + Vector2(12, 13.5) * u, o + Vector2(4, 5) * u]), c, w, true)
			draw_line(o + Vector2(12, 13.5) * u, o + Vector2(12, 20) * u, c, w)
			draw_line(o + Vector2(7.5, 20.5) * u, o + Vector2(16.5, 20.5) * u, c, w)
		"nightlife":
			var pts := PackedVector2Array()
			for i in 25:
				var a := lerpf(-1.9, 1.9, i / 24.0)
				pts.append(o + (Vector2(11, 12) + Vector2(cos(a), sin(a)) * 8.0) * u)
			for i in 25:
				var a2 := lerpf(1.9, -1.9, i / 24.0)
				pts.append(o + (Vector2(14.5, 12) + Vector2(cos(a2), sin(a2)) * 6.0) * u)
			draw_polyline(pts, c, w, true)
			draw_line(o + Vector2(19, 4) * u, o + Vector2(19, 8) * u, c, w * 0.7)
			draw_line(o + Vector2(17, 6) * u, o + Vector2(21, 6) * u, c, w * 0.7)
		"heart":
			var hp := PackedVector2Array()
			for i in 41:
				var t := i / 40.0 * TAU
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				hp.append(o + (Vector2(12, 11.5) + Vector2(x, y) * 0.62) * u)
			draw_colored_polygon(hp, c)
