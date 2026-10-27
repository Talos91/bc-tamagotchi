extends Control
## Debug HUD for the needs system: four meters, Vibe, clock multiplier, one button per refill action.
## Portrait layout for the 1080x1920 base. Built in code so the action list follows rules.gd.
## Toggle with the NEEDS button (top right) or F1. Talks to the Needs autoload only through signals
## and calls, so it can be removed without touching the system.

const Rules = preload("res://scripts/rules.gd")

const FONT := 34
const COLORS := {"music": Color("e0679c"), "friends": Color("f2b84b"), "drinks": Color("5bb8e0"), "nightlife": Color("9b7be0")}

var needs: Node
var _panel: PanelContainer
var _toggle: Button
var _bars: Dictionary = {}
var _bar_labels: Dictionary = {}
var _vibe_label: Label
var _visit_label: Label
var _status: Label
var _clock_btn: Button
var _score: HSlider
var _score_label: Label
var _key_edit: LineEdit


func _ready() -> void:
	needs = get_node_or_null("/root/Needs")
	_build()
	if needs == null:
		_status.text = "Needs autoload missing"
		return
	needs.meter_changed.connect(func(_m, _v): _refresh())
	needs.vibe_changed.connect(func(_v, _s): _refresh())
	needs.clock_multiplier_changed.connect(func(_m): _refresh())
	needs.visit_started.connect(func(_i): _refresh())
	needs.visit_ended.connect(_on_visit_ended)
	needs.welcome_back_started.connect(func(r): _status.text = "Welcome Back (%s): gains x2 for %d min" % [r, Rules.WELCOME_BACK_MINUTES])
	needs.action_applied.connect(_on_action)
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_panel.visible = not _panel.visible


func _build() -> void:
	_toggle = Button.new()
	_toggle.text = "NEEDS"
	_toggle.add_theme_font_size_override("font_size", FONT)
	_toggle.anchor_left = 1.0
	_toggle.anchor_right = 1.0
	_toggle.offset_left = -220.0
	_toggle.offset_right = -20.0
	_toggle.offset_top = 20.0
	_toggle.offset_bottom = 100.0
	_toggle.pressed.connect(func(): _panel.visible = not _panel.visible)
	add_child(_toggle)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 20.0
	_panel.offset_right = -20.0
	_panel.offset_top = 110.0
	_panel.offset_bottom = -20.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.05, 0.92)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)

	_vibe_label = _label(box, "")
	for m in Rules.METERS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var name_l := _label(row, m.capitalize())
		name_l.custom_minimum_size.x = 210
		var bar := ProgressBar.new()
		bar.max_value = Rules.METER_MAX
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 46)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = COLORS[m]
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		var val_l := _label(row, "")
		val_l.custom_minimum_size.x = 110
		val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_bars[m] = bar
		_bar_labels[m] = val_l

	_visit_label = _label(box, "")
	_status = _label(box, "")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var ctl := HBoxContainer.new()
	ctl.add_theme_constant_override("separation", 10)
	box.add_child(ctl)
	_clock_btn = _button(ctl, "", func(): needs.toggle_debug_clock())
	_button(ctl, "+1 day", func(): needs.debug_advance(86400.0))
	_button(ctl, "+1 hour", func(): needs.debug_advance(3600.0))
	var ctl2 := HBoxContainer.new()
	ctl2.add_theme_constant_override("separation", 10)
	box.add_child(ctl2)
	_button(ctl2, "Begin visit", func(): needs.begin_visit())
	_button(ctl2, "End visit", func(): needs.end_visit("left"))
	_button(ctl2, "New game", func(): needs.new_game(); needs.save_game())

	var sc := HBoxContainer.new()
	box.add_child(sc)
	_score_label = _label(sc, "")
	_score_label.custom_minimum_size.x = 230
	_score = HSlider.new()
	_score.min_value = 0.0
	_score.max_value = 1.0
	_score.step = 0.05
	_score.value = 0.5
	_score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score.custom_minimum_size.y = 50
	_score.value_changed.connect(func(_v): _refresh())
	sc.add_child(_score)
	var kr := HBoxContainer.new()
	box.add_child(kr)
	_label(kr, "Target key:")
	_key_edit = LineEdit.new()
	_key_edit.text = "mali"
	_key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_edit.add_theme_font_size_override("font_size", FONT)
	kr.add_child(_key_edit)

	for id in Rules.ACTIONS:
		var def: Dictionary = Rules.ACTIONS[id]
		var b := _button(box, "%s  [%s]" % [def["label"], _gain_text(def)], _do_action.bind(id))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 76
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT


func _gain_text(def: Dictionary) -> String:
	var parts: PackedStringArray = []
	for m in def["gains"]:
		var g: Variant = def["gains"][m]
		var amt := "%d-%d" % [g[0], g[1]] if g is Array else "%d" % g
		parts.append("%s +%s" % [String(m).substr(0, 1).to_upper(), amt])
	return " ".join(parts)


func _label(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", FONT - 4)
	b.custom_minimum_size.y = 70
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _do_action(id: String) -> void:
	var r: Dictionary = needs.apply_action(id, _score.value, _key_edit.text)
	if not r["ok"]:
		_status.text = "%s: blocked (%s)" % [id, r["reason"]]


func _on_action(id: String, r: Dictionary) -> void:
	var parts: PackedStringArray = []
	for m in r["gains"]:
		parts.append("%s +%.1f" % [m, r["gains"][m]])
	if r["tab"] > 0.0:
		parts.append("Tab +%.1f" % r["tab"])
	_status.text = "%s: %s" % [id, ", ".join(parts)]
	_refresh()


func _on_visit_ended(s: Dictionary) -> void:
	var parts: PackedStringArray = []
	for m in s["gains"]:
		parts.append("%s +%.1f" % [m, s["gains"][m]])
	_status.text = "Left (%s). Gained: %s" % [s["reason"], ", ".join(parts)]
	_refresh()


func _refresh() -> void:
	if needs == null or _vibe_label == null or needs.meters.is_empty():
		return
	_vibe_label.text = "Vibe %.0f  (%s)   Tab %.0f" % [needs.vibe(), needs.vibe_state.to_upper(), needs.tab]
	for m in Rules.METERS:
		_bars[m].value = needs.meters[m]
		_bar_labels[m].text = "%.1f" % needs.meters[m]
	var vs := "in visit #%d (x%.2f)" % [needs.visits_today, needs.current_daily_mult()] if needs.visit_active else "not in a visit"
	if needs.welcome_active():
		vs += "  WELCOME BACK x2"
	_visit_label.text = "Visit: %s" % vs
	_clock_btn.text = "Clock x%d" % int(needs.multiplier) if needs.multiplier != 1.0 else "Clock x1 (real)"
	_score_label.text = "Score %.2f" % _score.value
