extends Control
## Zone interaction sheet (wireframes §4): header (zone · person, gold), the greeting line, then one row per thing
## you'd do here: need glyph, title, sub-line, GAME chip on minigame rows. Disabled rows show the reason. Tapping
## the scene above the sheet, or Esc, closes it. Rows come from VenueSession.rows_for().

signal row_chosen(row_id: String)
signal closed

const UI = preload("res://scripts/minigames/mg_ui.gd")
const T = preload("res://scripts/zones/venue_strings.gd")
const Glyph = preload("res://scripts/minigames/need_glyph.gd")

const MAX_W := 430.0  ## dp; the sheet stays phone-width in landscape

var buttons := {}  # row id -> Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(header: Array[String], rows: Array[Dictionary]) -> void:
	for c in get_children():
		c.queue_free()
	buttons.clear()
	var dim := Button.new()
	dim.flat = true
	dim.focus_mode = Control.FOCUS_NONE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_theme_stylebox_override("normal", UI.box(Color(UI.BG_DEEP, 0.25), 0))
	dim.add_theme_stylebox_override("hover", UI.box(Color(UI.BG_DEEP, 0.25), 0))
	dim.add_theme_stylebox_override("pressed", UI.box(Color(UI.BG_DEEP, 0.25), 0))
	dim.pressed.connect(close)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Sheet"
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb := UI.box(Color(UI.BG_DEEP, 0.96), 20, UI.LINE, 2.0)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(UI.dp(16 if side != "bottom" else 28)))
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UI.dp(6)))
	pad.add_child(col)
	var handle := ColorRect.new()
	handle.color = UI.LINE
	handle.custom_minimum_size = Vector2(UI.dp(40), UI.dp(4))
	handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(handle)
	col.add_child(UI.label(header[0], 18, UI.GOLD))
	if header.size() > 1 and header[1] != "":
		col.add_child(UI.wrap(UI.label(header[1], 16, UI.CREAM)))
	for r in rows:
		col.add_child(_row(r))

	var w := minf(UI.dp(MAX_W), get_viewport_rect().size.x)
	panel.custom_minimum_size.x = w
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = 0  # grows upward to fit (grow_vertical BEGIN)
	panel.offset_bottom = 0


func _row(r: Dictionary) -> Control:
	var b := Button.new()
	b.name = "Row_" + str(r["id"])
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, UI.dp(64))
	b.disabled = not r["enabled"]
	for st in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(st, UI.box(UI.BG_BASE, 12, UI.LINE, 1.0))
	b.add_theme_stylebox_override("pressed", UI.box(UI.BG_PLUM, 12, UI.LINE, 1.0))
	b.pressed.connect(func(): row_chosen.emit(r["id"]))
	buttons[r["id"]] = b
	var inner := HBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = UI.dp(12)
	inner.offset_right = -UI.dp(12)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", int(UI.dp(12)))
	b.add_child(inner)
	if r["need"] != "":
		var g := Glyph.new()
		g.need = r["need"]
		g.custom_minimum_size = Vector2(UI.dp(24), UI.dp(24))
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if not r["enabled"]:
			g.tint = UI.ASH
		inner.add_child(g)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override("separation", 0)
	inner.add_child(texts)
	texts.add_child(UI.label(r["title"], 17, UI.CREAM if r["enabled"] else UI.ASH))
	var sub: String = r["sub"] if r["enabled"] else r["reason"]
	if sub != "":
		texts.add_child(UI.label(sub, 13, UI.SMOKE if r["enabled"] else UI.ASH))
	if r["game"]:
		var chip := UI.label(T.t("venue.sheet.game"), 13, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sb := UI.box(Color(0, 0, 0, 0), 8, UI.GOLD, 2.0)
		sb.content_margin_left = UI.dp(6)
		sb.content_margin_right = UI.dp(6)
		chip.add_theme_stylebox_override("normal", sb)
		inner.add_child(chip)
	return b


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
