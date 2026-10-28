extends Control
## Small result card after a plain action (no minigame): the line ("Nam slides one over."), then each need that
## moved with its bar and +N. Same parts as the minigame result card (wireframes §7) without score or buttons;
## it sits above the prompt, does not block the room, and fades after SHOW_SECONDS. Tap to dismiss.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const T = preload("res://scripts/zones/venue_strings.gd")
const Glyph = preload("res://scripts/minigames/need_glyph.gd")
const Rules = preload("res://scripts/rules.gd")

const SHOW_SECONDS := 2.8

var data: Dictionary = {}
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_card(c: Dictionary) -> void:
	data = c
	_panel = PanelContainer.new()
	_panel.name = "Card"
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var w := minf(UI.dp(320), get_viewport_rect().size.x - UI.dp(32))
	_panel.custom_minimum_size.x = w
	_panel.offset_left = -w * 0.5
	_panel.offset_right = w * 0.5
	_panel.offset_bottom = -UI.dp(190)
	_panel.offset_top = _panel.offset_bottom
	_panel.add_theme_stylebox_override("panel", UI.box(Color(UI.BG_BASE, 0.95), 16, UI.LINE, 2.0))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_card_input)
	add_child(_panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(UI.dp(12)))
	_panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UI.dp(6)))
	pad.add_child(col)
	col.add_child(UI.wrap(UI.label(str(c.get("line", "")), 16, UI.CREAM)))
	var gains: Dictionary = c.get("gains", {})
	var needs: Node = get_tree().root.get_node_or_null("Needs")
	for m in Rules.METERS:
		if not gains.has(m) or float(gains[m]) < 0.05:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(UI.dp(8)))
		col.add_child(row)
		var g := Glyph.new()
		g.need = m
		g.custom_minimum_size = Vector2(UI.dp(22), UI.dp(22))
		row.add_child(g)
		row.add_child(UI.label(S.t("need.%s.name" % m), 13, UI.SMOKE))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 100.0
		bar.value = needs.meters.get(m, 0.0) if needs != null else 0.0
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(0, UI.dp(8))
		bar.add_theme_stylebox_override("background", UI.box(UI.BG_RAISED, 4))
		bar.add_theme_stylebox_override("fill", UI.box(UI.need_color(m), 4))
		row.add_child(bar)
		row.add_child(UI.label("+%d" % roundi(float(gains[m])), 15, UI.need_color(m)))
	if float(c.get("tab", 0.0)) > 0.0:
		col.add_child(UI.wrap(UI.label(T.t("venue.card.tab"), 13, UI.SMOKE)))
	var tw := create_tween()
	tw.tween_interval(SHOW_SECONDS)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func _on_card_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch and e.pressed:
		queue_free()
