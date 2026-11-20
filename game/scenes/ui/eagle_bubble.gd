extends Control
## The entrance falcon's speech bubble (Daniele 2026-11-20: "the eagle on the table at the entrance should be the one
## greeting you and sending the entrance message as a chat bubble instead of as a popup"). A chat bubble in the
## Candle Talk bubble's style (mg_ui box, BG_BASE, LINE border) with the speaker's name over the line and a tail
## pointing down at the bird; it follows the bird on screen (main.gd's camera), never blocks input (the player can
## walk at once) nor catches a tap (the area buttons under it stay usable) and fades after SHOW_SECS. Hidden while the bird is off screen.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const T = preload("res://scripts/zones/venue_strings.gd")

const SHOW_SECS := 6.0
const HEAD_Y := 0.9           ## metres over the bird's pivot (the top of its head is at about 0.8)
const TAIL := 12.0            ## tail height, dp
const TOP_BAND := 176.0       ## dp kept clear at the top in portrait: the need rings, the zone title and the LIVE line
const TOP_BAND_LAND := 84.0   ## in landscape (the zone title sits left, under the Leave button)

var target: Node3D            ## the falcon (venue group "entrance_greeter")
var avoid: Control            ## kept clear of (main.gd: the HUD's prompt pill)
var side := 0                 ## 0 over the head, 1 right of it, -1 left of it
var line := ""
var panel: PanelContainer
var text_label: Label
var _age := 0.0
var _gone := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func open(bird: Node3D, text: String) -> void:
	target = bird
	line = text
	panel = PanelContainer.new()
	panel.name = "Bubble"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE   # taps go through to the HUD and the world; it fades by itself
	panel.add_theme_stylebox_override("panel", UI.box(Color(UI.BG_BASE, 0.94), 18, UI.LINE, 2.0))
	panel.custom_minimum_size = Vector2(minf(UI.dp(220), get_viewport_rect().size.x - UI.dp(48)), 0)
	add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, int(UI.dp(14)))
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(UI.dp(10)))
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UI.dp(2)))
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)
	var who := UI.label(T.t("venue.eagle.name"), 13, UI.GOLD)
	who.name = "Speaker"
	col.add_child(who)
	text_label = UI.wrap(UI.label(text, 16, UI.CREAM))
	text_label.name = "Line"
	col.add_child(text_label)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	_follow()


func _process(delta: float) -> void:
	_age += delta
	_follow()
	if _age > SHOW_SECS:
		dismiss()


## Places the bubble over the bird's head, its tail pointing down at it; when the HUD band leaves no room above (the
## lobby view looks north at the bird high on screen), beside the head instead, tail pointing sideways. Kept on
## screen and clear of `avoid` (the HUD's prompt pill).
func _follow() -> void:
	if panel == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(target) or not target.is_inside_tree():
		panel.visible = false
		return
	var head := target.global_position + Vector3(0, HEAD_Y, 0)
	if cam.is_position_behind(head):
		panel.visible = false
		return
	var p := cam.unproject_position(head)
	var vp := get_viewport_rect().size
	panel.visible = Rect2(Vector2.ZERO, vp).has_point(p)
	var sz := panel.get_combined_minimum_size()
	panel.size = sz
	var m := UI.dp(12)
	var top := UI.dp(TOP_BAND if vp.y > vp.x else TOP_BAND_LAND)
	var pos := Vector2(p.x - sz.x * 0.5, p.y - sz.y - UI.dp(TAIL))
	side = 0
	if pos.y < top:
		side = 1 if p.x < vp.x * 0.5 else -1
		pos = Vector2(p.x + UI.dp(TAIL) if side > 0 else p.x - UI.dp(TAIL) - sz.x, p.y - sz.y * 0.5)
	pos.x = clampf(pos.x, m, vp.x - sz.x - m)
	pos.y = clampf(pos.y, top, vp.y - sz.y - m)
	if avoid != null and is_instance_valid(avoid) and avoid.is_visible_in_tree():
		var ar := avoid.get_global_rect()
		if ar.intersects(Rect2(pos, sz)):
			pos.y = maxf(top, ar.position.y - sz.y - m)
	panel.position = pos
	queue_redraw()


func _draw() -> void:
	if panel == null or not panel.visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(target):
		return
	var tip := cam.unproject_position(target.global_position + Vector3(0, HEAD_Y, 0))
	var r := Rect2(panel.position, panel.size)
	var w := UI.dp(9)
	var pts: PackedVector2Array
	if side == 0:
		var bx := clampf(tip.x, r.position.x + UI.dp(20), r.end.x - UI.dp(20))
		pts = PackedVector2Array([Vector2(bx - w, r.end.y - 1.0), Vector2(bx + w, r.end.y - 1.0), Vector2(bx, r.end.y + UI.dp(TAIL))])
	else:
		var ex := r.position.x + 1.0 if side > 0 else r.end.x - 1.0
		var by := clampf(tip.y, r.position.y + UI.dp(16), r.end.y - UI.dp(16))
		pts = PackedVector2Array([Vector2(ex, by - w), Vector2(ex, by + w), Vector2(ex - side * UI.dp(TAIL), by)])
	draw_colored_polygon(pts, Color(UI.BG_BASE, 0.94))
	draw_polyline(PackedVector2Array([pts[0], pts[2], pts[1]]), UI.LINE, 2.0)


func dismiss() -> void:
	if _gone:
		return
	_gone = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)
