extends Control
## Walk-out summary (wireframes §4b): HEADING HOME, weekday and visit length, one row per need with the bar sweeping
## from the start-of-visit value to the end value and the gain; a taxi line if the player left Merry. BACK TO THE
## FLAT then shows a stand-in for the Flat check-in (meters and Vibe) with GO OUT, which starts the next visit.

signal go_out

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const T = preload("res://scripts/zones/venue_strings.gd")
const Glyph = preload("res://scripts/minigames/need_glyph.gd")
const Rules = preload("res://scripts/rules.gd")
const Tipsiness = preload("res://scripts/zones/tipsiness.gd")

const SWEEP_SECONDS := 1.2

var summary: Dictionary = {}
var bars := {}
var gain_labels := {}
var back_button: Button
var go_button: Button
var showing := ""  ## "summary" or "flat"
var _col: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _frame() -> VBoxContainer:
	for c in get_children():
		c.queue_free()
	bars.clear()
	gain_labels.clear()
	var bg := ColorRect.new()
	bg.color = Color(UI.BG_DEEP, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_col = VBoxContainer.new()
	_col.custom_minimum_size.x = minf(UI.dp(358), get_viewport_rect().size.x - UI.dp(32))
	_col.add_theme_constant_override("separation", int(UI.dp(14)))
	center.add_child(_col)
	return _col


## Visit summary from VenueSession.visit_finished.
func open(s: Dictionary) -> void:
	summary = s
	showing = "summary"
	var col := _frame()
	var title := UI.label(T.t("venue.walkout.title"), 30, UI.GOLD)
	title.theme_type_variation = &"LabelDisplayL"
	col.add_child(title)
	var bkk := Time.get_datetime_dict_from_unix_time(int(float(s.get("end", 0.0)) + Rules.DAY_UTC_OFFSET_HOURS * 3600.0))
	var minutes := maxi(1, roundi((float(s.get("end", 0.0)) - float(s.get("start", 0.0))) / 60.0))
	col.add_child(UI.label(T.t("venue.walkout.when", {"day": T.t("venue.day.%d" % int(bkk["weekday"])), "minutes": minutes}), 15, UI.SMOKE))
	var gains: Dictionary = s.get("gains", {})
	var start: Dictionary = s.get("start_meters", {})
	var end: Dictionary = s.get("end_meters", {})
	var total := 0.0
	for m in Rules.METERS:
		var g := float(gains.get(m, 0.0))
		total += g
		var bar := _meter_row(col, m, float(start.get(m, end.get(m, 0.0))))
		var gl := UI.label("+%d" % roundi(g), 17, UI.need_color(m) if g >= 0.5 else UI.ASH, HORIZONTAL_ALIGNMENT_RIGHT)
		gl.custom_minimum_size.x = UI.dp(44)
		bar.get_parent().add_child(gl)
		gain_labels[m] = gl
		create_tween().tween_property(bar, "value", float(end.get(m, 0.0)), SWEEP_SECONDS).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if total < 0.5:
		col.add_child(UI.wrap(UI.label(T.t("venue.walkout.nothing"), 15, UI.SMOKE)))
	if int(s.get("tipsy", 0)) == Tipsiness.MERRY:
		col.add_child(UI.wrap(UI.label(T.t("venue.walkout.taxi"), 15, UI.AMBER)))
	back_button = UI.button(T.t("venue.walkout.back"), "primary")
	back_button.pressed.connect(open_flat)
	col.add_child(back_button)


## Stand-in for the Flat check-in (wireframes §1) until that screen is built.
func open_flat() -> void:
	showing = "flat"
	var needs: Node = get_tree().root.get_node_or_null("Needs")
	var col := _frame()
	var title := UI.label(T.t("venue.flat.title"), 30, UI.GOLD)
	title.theme_type_variation = &"LabelDisplayL"
	col.add_child(title)
	if needs != null:
		col.add_child(UI.label(T.t("venue.flat.vibe", {"state": S.t("vibe." + Rules.vibe_state(needs.vibe()))}), 17, UI.CREAM))
		for m in Rules.METERS:
			_meter_row(col, m, float(needs.meters[m]))
	col.add_child(UI.wrap(UI.label(T.t("venue.flat.soon"), 14, UI.SMOKE)))
	go_button = UI.button(T.t("venue.flat.go_out"), "primary")
	go_button.pressed.connect(func(): go_out.emit())
	col.add_child(go_button)


func _meter_row(col: Control, m: String, v: float) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UI.dp(10)))
	col.add_child(row)
	var g := Glyph.new()
	g.need = m
	g.custom_minimum_size = Vector2(UI.dp(28), UI.dp(28))
	row.add_child(g)
	var n := UI.label(S.t("need.%s.name" % m), 14, UI.SMOKE)
	n.custom_minimum_size.x = UI.dp(84)
	row.add_child(n)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = v
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(0, UI.dp(10))
	bar.add_theme_stylebox_override("background", UI.box(UI.BG_RAISED, 5))
	bar.add_theme_stylebox_override("fill", UI.box(UI.need_color(m), 5))
	row.add_child(bar)
	bars[m] = bar
	return bar
