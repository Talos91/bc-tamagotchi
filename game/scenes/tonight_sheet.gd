extends Control
## The Tonight sheet (backlog D1 + D2; docs/design/09-tonight-events.md): a bottom sheet in the menu list's look, opened
## from the HUD's Tonight button. Top: tonight's date and the bar's state (open / doors at 19:00 / closed Mondays), then
## tonight's card (event title, time, lineup; or a regular night, closed, or "calendar not in yet"); below, Coming up:
## the next events of this month and the next. Offline, from res://data/events/ (scripts/tonight_events.gd). Tapping
## above the sheet, Close, or Esc closes it.

signal closed

const UI = preload("res://scripts/minigames/mg_ui.gd")
const TE = preload("res://scripts/tonight_events.gd")

const MAX_W := 430.0  ## dp; phone width in landscape too, like the menu list
const MAX_H := 0.78   ## share of the viewport height the scrolling part may take

var info := {}        ## TE.tonight() as shown
var coming := {}      ## TE.upcoming() as shown
var rows: Array = []  ## the Coming up row containers, in order (tests read them)
var tonight_card: PanelContainer
var state_label: Label
var _scroll: ScrollContainer
var _body: VBoxContainer
var _max_h := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()


func open(unix := -1) -> void:
	for c in get_children():
		c.queue_free()
	rows.clear()
	info = TE.tonight(unix)
	coming = TE.upcoming(unix)

	var dim := Button.new()
	dim.flat = true
	dim.focus_mode = Control.FOCUS_NONE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	for st in ["normal", "hover", "pressed"]:
		dim.add_theme_stylebox_override(st, UI.box(Color(UI.BG_DEEP, 0.25), 0))
	dim.pressed.connect(close)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "TonightSheet"
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb := UI.box(Color(UI.BG_DEEP, 0.97), 20, UI.LINE, 2.0)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(UI.dp(16 if side != "bottom" else 24)))
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UI.dp(8)))
	pad.add_child(col)
	var handle := ColorRect.new()
	handle.color = UI.LINE
	handle.custom_minimum_size = Vector2(UI.dp(40), UI.dp(4))
	handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(handle)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := UI.label(TE.t("tonight.head"), 18, UI.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UI.button(TE.t("tonight.close"), "secondary")
	x.name = "Close"
	x.custom_minimum_size.x = UI.dp(84)
	x.pressed.connect(close)
	head.add_child(x)

	state_label = UI.wrap(UI.label(TE.date_text(info["day"]) + "  ·  " + TE.state_text(info), 14,
		UI.RED_HI if info["state"] == "closed" else UI.SMOKE))
	state_label.name = "State"
	col.add_child(state_label)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(UI.dp(6)))
	scroll.add_child(body)

	tonight_card = _tonight_card()
	body.add_child(tonight_card)

	var up := UI.label(TE.t("tonight.upcoming"), 15, UI.GOLD)
	up.name = "UpcomingHead"
	body.add_child(up)
	for ev in coming["events"]:
		var r := _row(ev)
		body.add_child(r)
		rows.append(r)
	for ym in coming["missing"]:
		var l := UI.wrap(UI.label(TE.t("tonight.upcoming.missing", {"month": TE.month_text(ym)}), 13, UI.ASH))
		l.name = "Missing_" + ym
		body.add_child(l)
	if coming["events"].is_empty() and coming["missing"].is_empty():
		body.add_child(UI.wrap(UI.label(TE.t("tonight.upcoming.none"), 13, UI.ASH)))

	col.add_child(UI.wrap(UI.label(TE.t("tonight.hours"), 12, UI.ASH)))

	var vp := get_viewport_rect().size
	var w := minf(UI.dp(MAX_W), vp.x)
	panel.custom_minimum_size.x = w
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = 0
	panel.offset_bottom = 0
	_scroll = scroll
	_body = body
	_max_h = maxf(vp.y * MAX_H - UI.dp(150), UI.dp(160))
	scroll.custom_minimum_size.y = _max_h
	_fit.call_deferred()


## Fit the content when it is short, scroll when it is not (after the labels have wrapped to their width).
func _fit() -> void:
	if not is_instance_valid(_body):
		return
	_scroll.custom_minimum_size.y = clampf(_body.get_combined_minimum_size().y, UI.dp(120), _max_h)


func _tonight_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "TonightCard"
	var has_event: bool = not info["events"].is_empty()
	card.add_theme_stylebox_override("panel", UI.box(UI.BG_PLUM if has_event else UI.BG_RAISED, 14,
		UI.GOLD if has_event else UI.LINE, 2.0))
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, int(UI.dp(12)))
	card.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UI.dp(4)))
	m.add_child(v)
	if info["state"] == "closed":
		v.add_child(UI.wrap(UI.label(TE.t("tonight.closed_card"), 16, UI.CREAM)))
	elif not info["known"]:
		v.add_child(UI.wrap(UI.label(TE.t("tonight.no_data", {"month": TE.month_text(TE.month_key(info["day"]))}), 15, UI.SMOKE)))
	elif not has_event:
		v.add_child(UI.wrap(UI.label(TE.t("tonight.none"), 15, UI.SMOKE)))
	else:
		for ev in info["events"]:
			var tl := UI.wrap(UI.label(str(ev["title"]), 22, UI.CREAM))
			tl.name = "EventTitle"
			v.add_child(tl)
			var tm := TE.time_text(ev)
			if tm != "":
				v.add_child(UI.label(tm, 15, UI.GOLD))
			if ev.has("lineup"):
				v.add_child(UI.wrap(UI.label(TE.t("tonight.lineup", {"names": ", ".join(PackedStringArray(ev["lineup"]))}), 14, UI.SMOKE)))
	return card


func _row(ev: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.name = "Row_" + str(ev["date"])
	box.add_theme_stylebox_override("panel", UI.box(UI.BG_BASE, 10, UI.LINE, 1.0))
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, int(UI.dp(10)))
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, int(UI.dp(6)))
	box.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(UI.dp(10)))
	m.add_child(h)
	var d := UI.label(TE.date_text(str(ev["date"])), 13, UI.SMOKE)
	d.custom_minimum_size.x = UI.dp(84)
	h.add_child(d)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 0)
	h.add_child(mid)
	mid.add_child(UI.wrap(UI.label(str(ev["title"]), 15, UI.CREAM)))
	if ev.has("lineup"):
		mid.add_child(UI.wrap(UI.label(", ".join(PackedStringArray(ev["lineup"])), 12, UI.ASH)))
	var tm := UI.label(str(ev.get("time", "")), 13, UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	h.add_child(tm)
	return box
