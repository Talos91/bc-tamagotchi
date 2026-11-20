extends Control
## The Tonight sheet (backlog D1 + D2; docs/design/09-tonight-events.md): a bottom sheet in the menu list's look, opened
## from the HUD's Tonight button. Two tabs:
##   Tonight  - tonight's date and the bar's state (open / doors at 19:00 / closed), tonight's special-event card, then
##              "Who's playing tonight": one card per act from the bar's weekly lineup poster (photo, name, genre, set
##              time, description), the act on stage now (Bangkok clock) lit up; then Coming up.
##   Calendar - the month's special events on a Mon–Sun grid (‹ › to change month); tap a day for its events and
##              lineup below the grid.
## Offline, from res://data/events/ (scripts/tonight_events.gd). Tapping above the sheet, Close, or Esc closes it.
## D2 Back-bar skin (bc_skin.gd): wood sheet with an LED strip on top, the neon sign head, lit LED-shelf cards.

signal closed

const UI = preload("res://scripts/minigames/mg_ui.gd")
const TE = preload("res://scripts/tonight_events.gd")
const BCSkin = preload("res://scripts/ui/bc_skin.gd")

const MAX_W := 430.0  ## dp; phone width in landscape too, like the menu list
const MAX_H := 0.84   ## share of the viewport height the sheet may take (HUD row stays visible above it)
const PHOTO := 84.0   ## dp, act photo on a lineup card
const PHOTO_S := 60.0 ## dp, act photo in the calendar's day panel

var info := {}        ## TE.tonight() as shown
var coming := {}      ## TE.upcoming() as shown
var rows: Array = []  ## the Coming up row containers, in order (tests read them)
var act_cards: Array = []   ## the lineup cards on the Tonight tab, in set order (tests read them)
var tonight_card: PanelContainer
var state_label: Label
var mode := "tonight"        ## "tonight" | "calendar"
var cal_month := ""          ## "yyyy-mm" shown on the calendar
var cal_selected := ""       ## "yyyy-mm-dd" tapped on the calendar
var cal_cells := {}          ## "yyyy-mm-dd" -> Button (tests read them)
var day_panel: VBoxContainer ## the tapped day's events and lineup
var _unix := -1
var _scroll: ScrollContainer
var _body: VBoxContainer
var _tabs := {}
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
	_unix = unix
	info = TE.tonight(unix)
	coming = TE.upcoming(unix)
	cal_month = TE.month_key(info["day"])
	cal_selected = info["date"]

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
	var sb := BCSkin.sheet_box()
	sb.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	BCSkin.led_strip(panel, true)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(UI.dp(16 if side != "bottom" else 24)))
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UI.dp(8)))
	pad.add_child(col)
	var handle := ColorRect.new()
	handle.color = Color(BCSkin.BRASS, 0.5)
	handle.custom_minimum_size = Vector2(UI.dp(40), UI.dp(4))
	handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(handle)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := BCSkin.neon_title(TE.t("tonight.head"), 21)
	title.name = "Head"
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UI.button(TE.t("tonight.close"), "secondary")
	x.name = "Close"
	x.custom_minimum_size.x = UI.dp(84)
	x.pressed.connect(close)
	head.add_child(x)

	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", int(UI.dp(8)))
	col.add_child(tabs)
	for m in ["tonight", "calendar"]:
		var b := BCSkin.button(TE.t("tonight.tab." + m), "secondary")
		b.name = "Tab_" + m
		b.custom_minimum_size.y = UI.dp(40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(show_mode.bind(m))
		tabs.add_child(b)
		_tabs[m] = b

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
	_max_h = maxf(vp.y * MAX_H - UI.dp(190), UI.dp(160))
	scroll.custom_minimum_size.y = _max_h
	show_mode("tonight")


## Switch tabs: rebuild the scrolling body for the Tonight list or the month calendar.
func show_mode(m: String) -> void:
	mode = m
	for k in _tabs:
		BCSkin.style_button(_tabs[k], "primary" if k == m else "secondary")
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	rows.clear()
	act_cards.clear()
	cal_cells.clear()
	tonight_card = null
	day_panel = null
	if m == "calendar":
		_build_calendar()
	else:
		_build_tonight()
	_scroll.scroll_vertical = 0
	_fit.call_deferred()


## Fit the content when it is short, scroll when it is not (after the labels have wrapped to their width).
func _fit() -> void:
	if not is_instance_valid(_body):
		return
	_scroll.custom_minimum_size.y = clampf(_body.get_combined_minimum_size().y, UI.dp(120), _max_h)


# --- Tonight tab -------------------------------------------------------------------------------------------------

func _build_tonight() -> void:
	tonight_card = _tonight_card()
	_body.add_child(tonight_card)

	if info["state"] != "closed" and (not info["acts"].is_empty() or info["lineup_known"]):
		var lh := UI.label(TE.t("tonight.playing"), 15, UI.GOLD)
		lh.name = "LineupHead"
		_body.add_child(lh)
		if info["acts"].is_empty():
			_body.add_child(UI.wrap(UI.label(TE.t("tonight.lineup.none"), 13, UI.ASH)))
		var acts: Array = info["acts"]
		for i in acts.size():
			var c := _act_card(acts[i], i == int(info["now_act"]), PHOTO, true)
			c.name = "Act_%d" % i
			_body.add_child(c)
			act_cards.append(c)
	elif info["state"] != "closed":
		var nl := UI.wrap(UI.label(TE.t("tonight.lineup.missing"), 13, UI.ASH))
		nl.name = "LineupMissing"
		_body.add_child(nl)

	var up := UI.label(TE.t("tonight.upcoming"), 15, UI.GOLD)
	up.name = "UpcomingHead"
	_body.add_child(up)
	for ev in coming["events"]:
		var r := _row(ev)
		_body.add_child(r)
		rows.append(r)
	for ym in coming["missing"]:
		var l := UI.wrap(UI.label(TE.t("tonight.upcoming.missing", {"month": TE.month_text(ym)}), 13, UI.ASH))
		l.name = "Missing_" + ym
		_body.add_child(l)
	if coming["events"].is_empty() and coming["missing"].is_empty():
		_body.add_child(UI.wrap(UI.label(TE.t("tonight.upcoming.none"), 13, UI.ASH)))


func _tonight_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "TonightCard"
	var has_event: bool = not info["events"].is_empty()
	var cs := BCSkin.row_box(has_event)
	cs.set_content_margin_all(0)
	if has_event:
		cs.bg_color = Color("2A0C0E")
		cs.border_color = Color(UI.GOLD, 0.8)
	card.add_theme_stylebox_override("panel", cs)
	if has_event:
		BCSkin.led_strip(card)
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
			_event_lines(v, ev, 22, "EventTitle")
	return card


## An event's title, subtitle (guest bartender), time and lineup lines.
func _event_lines(v: VBoxContainer, ev: Dictionary, size: float, title_name := "") -> void:
	var tl := UI.wrap(UI.label(str(ev["title"]), size, UI.CREAM))
	if title_name != "":
		tl.name = title_name
	v.add_child(tl)
	if str(ev.get("subtitle", "")) != "":
		v.add_child(UI.wrap(UI.label(str(ev["subtitle"]), 14, UI.SMOKE)))
	var tm := TE.time_text(ev)
	if tm != "":
		v.add_child(UI.label(tm, 15 if size > 18 else 13, UI.GOLD))
	if ev.has("lineup"):
		v.add_child(UI.wrap(UI.label(TE.t("tonight.lineup", {"names": ", ".join(PackedStringArray(ev["lineup"]))}), 14 if size > 18 else 12, UI.SMOKE)))


## One act from the weekly poster: photo (or a neon initial when the poster has none), name, genre or role, set time,
## and the poster's description. `now` lights it like the LED shelf and adds the "Now on stage" tag.
func _act_card(a: Dictionary, now: bool, photo_dp: float, with_desc: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var cs := BCSkin.row_box(now)
	cs.set_content_margin_all(0)
	if now:
		cs.bg_color = Color("2A0C0E")
		cs.border_color = Color(BCSkin.LED, 0.9)
	card.add_theme_stylebox_override("panel", cs)
	if now:
		BCSkin.led_strip(card)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, int(UI.dp(10)))
	card.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(UI.dp(12)))
	m.add_child(h)
	h.add_child(_photo(a, photo_dp, now))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", int(UI.dp(2)))
	h.add_child(v)
	if now:
		var tg := BCSkin.chip(TE.t("tonight.now_on_stage"), BCSkin.VELVET)
		tg.name = "NowOnStage"
		tg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(tg)
	var nm := UI.wrap(UI.label(str(a["name"]), 17 if with_desc else 15, UI.CREAM))
	nm.name = "ActName"
	v.add_child(nm)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", int(UI.dp(8)))
	v.add_child(line)
	var kind := TE.act_kind_text(a)
	if kind != "":
		var k := UI.wrap(UI.label(kind, 13, UI.SMOKE))
		k.name = "ActKind"
		line.add_child(k)
	var tm := UI.label(TE.act_time_text(a), 13, UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	tm.name = "ActTime"
	tm.size_flags_horizontal = Control.SIZE_SHRINK_END if kind != "" else Control.SIZE_EXPAND_FILL
	line.add_child(tm)
	if with_desc and str(a.get("description", "")) != "":
		var d := UI.wrap(UI.label(str(a["description"]), 12, UI.ASH))
		d.name = "ActDesc"
		v.add_child(d)
	return card


func _photo(a: Dictionary, size_dp: float, lit: bool) -> Control:
	var frame := PanelContainer.new()
	frame.name = "Photo"
	frame.custom_minimum_size = Vector2(UI.dp(size_dp), UI.dp(size_dp))
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sb := BCSkin.cubby_box(BCSkin.LED if lit else UI.GOLD, lit)
	sb.set_content_margin_all(UI.dp(2))
	frame.add_theme_stylebox_override("panel", sb)
	var tex := TE.act_photo(a)
	if tex != null:
		var tr := TextureRect.new()
		tr.name = "Pic"
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tr)
	else:
		var n := BCSkin.neon_title(str(a["name"]).substr(0, 1).to_upper(), size_dp * 0.42, UI.GOLD)
		n.name = "Initial"
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(n)
	return frame


func _row(ev: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.name = "Row_" + str(ev["date"])
	var bs := BCSkin.row_box()
	bs.set_content_margin_all(0)
	box.add_theme_stylebox_override("panel", bs)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, int(UI.dp(10)))
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, int(UI.dp(6)))
	box.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(UI.dp(10)))
	m.add_child(h)
	h.add_child(_date_block(str(ev["date"])))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 0)
	h.add_child(mid)
	mid.add_child(UI.wrap(UI.label(str(ev["title"]), 15, UI.CREAM)))
	if str(ev.get("subtitle", "")) != "":
		mid.add_child(UI.wrap(UI.label(str(ev["subtitle"]), 12, UI.ASH)))
	if ev.has("lineup"):
		mid.add_child(UI.wrap(UI.label(", ".join(PackedStringArray(ev["lineup"])), 12, UI.ASH)))
	var tm := UI.label(str(ev.get("time", "")), 13, UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	tm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tm)
	return box


## A bar-tab date block: the weekday in gold over the day number (the row's date, read as on a tab).
func _date_block(date: String) -> Control:
	var p := date.split("-")
	var d: Dictionary = TE.local(TE.bkk_unix(int(p[0]), int(p[1]), int(p[2]), 12))
	var blk := PanelContainer.new()
	blk.name = "Date"
	blk.tooltip_text = TE.date_text(date)
	blk.custom_minimum_size = Vector2(UI.dp(52), UI.dp(50))
	var sb := BCSkin.cubby_box(UI.GOLD)
	sb.set_content_margin_all(UI.dp(3))
	blk.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	blk.add_child(v)
	v.add_child(UI.label(TE.t("tonight.day.%d" % int(d["weekday"])), 12, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var n := UI.label("%02d" % int(d["day"]), 20, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	n.theme_type_variation = &"LabelDisplayS"
	n.add_theme_font_size_override("font_size", int(UI.dp(20)))
	v.add_child(n)
	return blk


# --- Calendar tab ------------------------------------------------------------------------------------------------

func _build_calendar() -> void:
	var nav := HBoxContainer.new()
	nav.name = "MonthNav"
	_body.add_child(nav)
	var prev := BCSkin.button("<", "ghost")
	prev.name = "PrevMonth"
	prev.custom_minimum_size = Vector2(UI.dp(48), UI.dp(44))
	prev.pressed.connect(func(): set_month(_shift_month(cal_month, -1)))
	nav.add_child(prev)
	var mt := BCSkin.neon_title(TE.month_text(cal_month), 18, UI.GOLD)
	mt.name = "MonthTitle"
	mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(mt)
	var nxt := BCSkin.button(">", "ghost")
	nxt.name = "NextMonth"
	nxt.custom_minimum_size = Vector2(UI.dp(48), UI.dp(44))
	nxt.pressed.connect(func(): set_month(_shift_month(cal_month, 1)))
	nav.add_child(nxt)

	var evs: Variant = TE.month_events(cal_month)
	if evs == null:
		var ml := UI.wrap(UI.label(TE.t("tonight.no_data", {"month": TE.month_text(cal_month)}), 13, UI.ASH))
		ml.name = "CalMissing"
		_body.add_child(ml)
	var by_date := {}
	if evs != null:
		for ev in evs:
			by_date[ev["date"]] = true

	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", int(UI.dp(4)))
	grid.add_theme_constant_override("v_separation", int(UI.dp(4)))
	_body.add_child(grid)
	for wd in [1, 2, 3, 4, 5, 6, 0]:
		var hl := UI.label(TE.t("tonight.day.%d" % wd), 11, UI.ASH, HORIZONTAL_ALIGNMENT_CENTER)
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(hl)
	var y := int(cal_month.substr(0, 4))
	var mo := int(cal_month.substr(5, 2))
	var first: Dictionary = TE.local(TE.bkk_unix(y, mo, 1, 12))
	var lead := (int(first["weekday"]) + 6) % 7
	for i in lead:
		grid.add_child(Control.new())
	var days := _days_in_month(y, mo)
	for dnum in range(1, days + 1):
		var date := "%04d-%02d-%02d" % [y, mo, dnum]
		var cell := _day_cell(date, dnum, by_date.has(date), TE.lineup(date)["acts"].size() > 0)
		grid.add_child(cell)
		cal_cells[date] = cell

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", int(UI.dp(12)))
	_body.add_child(legend)
	legend.add_child(_swatch(Color("2A0C0E"), UI.GOLD, false))
	legend.add_child(UI.label(TE.t("tonight.cal.special"), 11, UI.GOLD))
	legend.add_child(_swatch(Color(BCSkin.WOOD_DEEP, 0.9), BCSkin.BRASS_DIM, true))
	legend.add_child(UI.label(TE.t("tonight.cal.lineup"), 11, BCSkin.CREAM))

	_body.add_child(BCSkin.rule())
	day_panel = VBoxContainer.new()
	day_panel.name = "DayPanel"
	day_panel.add_theme_constant_override("separation", int(UI.dp(6)))
	_body.add_child(day_panel)
	if not cal_selected.begins_with(cal_month):
		cal_selected = ""
	_fill_day_panel()


func _day_cell(date: String, dnum: int, special: bool, has_lineup: bool) -> Button:
	var b := Button.new()
	b.name = "Day_" + date
	b.text = str(dnum)
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, UI.dp(42))
	b.add_theme_font_size_override("font_size", int(UI.dp(15)))
	var is_tonight: bool = date == info["date"]
	var sel := date == cal_selected
	for st in ["normal", "hover", "pressed"]:
		var fill := Color("2A0C0E") if special else Color(BCSkin.WOOD_DEEP, 0.9)
		var edge := Color(UI.GOLD, 0.9) if special else Color(BCSkin.BRASS_DIM, 0.6)
		var s := StyleBoxFlat.new()
		s.bg_color = fill.lightened(0.08) if st != "normal" else fill
		s.set_corner_radius_all(int(UI.dp(8)))
		s.border_color = Color(BCSkin.LED, 1.0) if sel else edge
		s.set_border_width_all(maxi(1, int(UI.dp(2.0 if sel else 1.0))))
		if is_tonight:
			s.shadow_color = Color(BCSkin.LED, 0.45)
			s.shadow_size = int(UI.dp(5))
		b.add_theme_stylebox_override(st, s)
	var fg := UI.GOLD if special else (BCSkin.CREAM if has_lineup else BCSkin.ASH)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, fg)
	if has_lineup:
		var bar := ColorRect.new()
		bar.color = Color(BCSkin.LED, 0.85)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		bar.offset_left = UI.dp(8)
		bar.offset_right = -UI.dp(8)
		bar.offset_top = -UI.dp(5)
		bar.offset_bottom = -UI.dp(3)
		b.add_child(bar)
	b.pressed.connect(select_day.bind(date))
	return b


## A small legend key drawn like a day cell (no glyphs: the web font lacks most symbols).
func _swatch(fill: Color, edge: Color, led_bar: bool) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(UI.dp(18), UI.dp(14))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(int(UI.dp(3)))
	s.border_color = edge
	s.set_border_width_all(maxi(1, int(UI.dp(1))))
	p.add_theme_stylebox_override("panel", s)
	if led_bar:
		var bar := ColorRect.new()
		bar.color = Color(BCSkin.LED, 0.85)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		bar.offset_left = UI.dp(3)
		bar.offset_right = -UI.dp(3)
		bar.offset_top = -UI.dp(4)
		bar.offset_bottom = -UI.dp(2)
		p.add_child(bar)
	return p


## Tap on a calendar day: its events and lineup appear under the grid.
func select_day(date: String) -> void:
	cal_selected = date
	show_mode("calendar")


func set_month(ym: String) -> void:
	cal_month = ym
	show_mode("calendar")


func _fill_day_panel() -> void:
	if cal_selected == "":
		day_panel.add_child(UI.wrap(UI.label(TE.t("tonight.cal.pick"), 13, UI.ASH)))
		return
	var dh := UI.label(TE.date_text(cal_selected), 16, UI.GOLD)
	dh.name = "DayHead"
	day_panel.add_child(dh)
	var evs: Variant = TE.month_events(cal_month)
	var any := false
	if evs != null:
		for ev in evs:
			if ev["date"] == cal_selected:
				var card := PanelContainer.new()
				card.name = "DayEvent"
				var cs := BCSkin.row_box(true)
				cs.bg_color = Color("2A0C0E")
				cs.border_color = Color(UI.GOLD, 0.8)
				card.add_theme_stylebox_override("panel", cs)
				var v := VBoxContainer.new()
				v.add_theme_constant_override("separation", int(UI.dp(2)))
				card.add_child(v)
				_event_lines(v, ev, 16)
				day_panel.add_child(card)
				any = true
	var lu := TE.lineup(cal_selected)
	if lu["title"] != "" and not any:
		day_panel.add_child(UI.wrap(UI.label(str(lu["title"]), 15, UI.CREAM)))
	var acts: Array = lu["acts"]
	var now_i := TE.now_on_stage(cal_selected, _unix if _unix >= 0 else TE.now_unix())
	for i in acts.size():
		var c := _act_card(acts[i], i == now_i, PHOTO_S, false)
		c.name = "DayAct_%d" % i
		day_panel.add_child(c)
		any = true
	if not any:
		var p := cal_selected.split("-")
		var wd: int = TE.local(TE.bkk_unix(int(p[0]), int(p[1]), int(p[2]), 12))["weekday"]
		var key := "tonight.cal.closed" if wd == TE.CLOSED_WEEKDAY else ("tonight.cal.nothing" if lu["known"] else "tonight.cal.no_lineup")
		var nl := UI.wrap(UI.label(TE.t(key), 13, UI.ASH))
		nl.name = "DayNothing"
		day_panel.add_child(nl)


static func _shift_month(ym: String, by: int) -> String:
	var y := int(ym.substr(0, 4))
	var m := int(ym.substr(5, 2)) - 1 + by
	y += floori(m / 12.0)
	m = posmod(m, 12) + 1
	return "%04d-%02d" % [y, m]


static func _days_in_month(y: int, m: int) -> int:
	var n := TE._next_month("%04d-%02d" % [y, m])
	var u := TE.bkk_unix(int(n.substr(0, 4)), int(n.substr(5, 2)), 1, 12) - TE.DAY
	return int(TE.local(u)["day"])
