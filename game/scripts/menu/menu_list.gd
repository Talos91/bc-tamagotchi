extends Control
## The real Black Cabin menu as a bottom sheet (same look as scenes/ui/zone_sheet.gd): header, Drinks / Kitchen
## tabs, then a scrolling list by section with stars, chillies and THB prices as printed. Tapping a drink emits
## item_chosen(id); VenueSession.order_item() applies its effect (scripts/menu/bar_menu.gd). Kitchen rows are
## shown but do nothing yet. Alcoholic rows are disabled while Merry. Tapping above the sheet, or Esc, closes it.

signal item_chosen(id: String)
signal closed

const UI = preload("res://scripts/minigames/mg_ui.gd")
const BarMenu = preload("res://scripts/menu/bar_menu.gd")

const MAX_W := 430.0  ## dp; phone width in landscape too, like the zone sheet
const MAX_H := 0.78   ## share of the viewport height the sheet may take

var tab := "drinks"
var merry := false
var buttons := {}  # item id -> Button (drinks) or Label row (kitchen)
var tab_buttons := {}
var _list: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(start_tab := "drinks", is_merry := false) -> void:
	tab = start_tab
	merry = is_merry
	for c in get_children():
		c.queue_free()
	var dim := Button.new()
	dim.flat = true
	dim.focus_mode = Control.FOCUS_NONE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	for st in ["normal", "hover", "pressed"]:
		dim.add_theme_stylebox_override(st, UI.box(Color(UI.BG_DEEP, 0.25), 0))
	dim.pressed.connect(close)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "MenuSheet"
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
	var title := UI.label(BarMenu.t("menu.head"), 18, UI.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UI.button(BarMenu.t("menu.close"), "secondary")
	x.name = "Close"
	x.pressed.connect(close)
	head.add_child(x)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", int(UI.dp(8)))
	col.add_child(tabs)
	for t_id in ["drinks", "kitchen"]:
		var b := Button.new()
		b.name = "Tab_" + t_id
		b.text = BarMenu.t("menu.tab." + t_id)
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = UI.dp(40)
		b.add_theme_font_size_override("font_size", int(UI.dp(15)))
		b.add_theme_stylebox_override("normal", UI.box(UI.BG_BASE, 10, UI.LINE, 1.0))
		b.add_theme_stylebox_override("hover", UI.box(UI.BG_BASE, 10, UI.LINE, 1.0))
		b.add_theme_stylebox_override("pressed", UI.box(UI.BG_PLUM, 10, UI.GOLD, 2.0))
		b.add_theme_color_override("font_color", UI.SMOKE)
		b.add_theme_color_override("font_pressed_color", UI.GOLD)
		b.add_theme_color_override("font_hover_pressed_color", UI.GOLD)
		b.pressed.connect(show_tab.bind(t_id))
		tabs.add_child(b)
		tab_buttons[t_id] = b

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", int(UI.dp(2)))
	_scroll.add_child(_list)
	col.add_child(UI.wrap(UI.label(BarMenu.t("menu.price_note"), 12, UI.ASH)))

	var vp := get_viewport_rect().size
	var w := minf(UI.dp(MAX_W), vp.x)
	panel.custom_minimum_size.x = w
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = 0
	panel.offset_bottom = 0
	_scroll.custom_minimum_size.y = maxf(vp.y * MAX_H - UI.dp(170), UI.dp(160))
	show_tab(tab)


func show_tab(t_id: String) -> void:
	tab = t_id
	for k in tab_buttons:
		tab_buttons[k].set_pressed_no_signal(k == t_id)
	for c in _list.get_children():
		c.queue_free()
	buttons.clear()
	if t_id == "kitchen":
		_list.add_child(UI.wrap(UI.label(BarMenu.t("menu.kitchen_soon"), 14, UI.SMOKE)))
	for s in BarMenu.sections(t_id):
		var h := UI.label(s["title"].to_upper(), 13, UI.GOLD)
		h.custom_minimum_size.y = UI.dp(30)
		h.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_list.add_child(h)
		for it in s["items"]:
			_list.add_child(_row(it))
	_scroll.scroll_vertical = 0


func _row(it: Dictionary) -> Control:
	var id: String = it["id"]
	var kitchen: bool = it["group"] == "kitchen"
	var blocked: bool = merry and it["effect"] == "alcohol"
	var root: Control
	if kitchen:
		root = PanelContainer.new()
		var pb := UI.box(Color(0, 0, 0, 0), 0)
		pb.content_margin_left = UI.dp(10)
		pb.content_margin_right = UI.dp(18)  # clear of the scrollbar
		root.add_theme_stylebox_override("panel", pb)
	else:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = blocked
		for st in ["normal", "hover", "disabled"]:
			b.add_theme_stylebox_override(st, UI.box(UI.BG_BASE, 10, UI.LINE, 1.0))
		b.add_theme_stylebox_override("pressed", UI.box(UI.BG_PLUM, 10, UI.LINE, 1.0))
		b.pressed.connect(func(): item_chosen.emit(id))
		root = b
	root.name = "Item_" + id
	root.custom_minimum_size.y = UI.dp(44)
	buttons[id] = root
	var inner := HBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = UI.dp(10)
	inner.offset_right = -UI.dp(10)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", int(UI.dp(8)))
	root.add_child(inner)
	var marks := ("★ " if it.get("star", false) else "") + ("🌶 " if it.get("chilli", false) else "")
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override("separation", 0)
	inner.add_child(texts)
	var dim := blocked
	var nm := UI.label(marks + BarMenu.name_of(id), 15, UI.ASH if dim else UI.CREAM)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(nm)
	var sub := ""
	if blocked:
		sub = BarMenu.t("menu.merry")
	elif it.has("region"):
		sub = str(it["region"])
	if sub != "":
		texts.add_child(UI.label(sub, 12, UI.ASH))
	var price := UI.label(BarMenu.price_text(id), 13, UI.ASH if dim else UI.SMOKE, HORIZONTAL_ALIGNMENT_RIGHT)
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(price)
	return root


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
