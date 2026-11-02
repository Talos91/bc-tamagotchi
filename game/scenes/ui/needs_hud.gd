extends Control
## Venue HUD (wireframes §3): Leave (door), the four need rings with the lowest breathing, Welcome Back x2 chip,
## tipsiness chip, zone name (large on entry, small after 2 s), band caption, area buttons on the right edge (one per
## area, AREAS: a tap walks there and the camera focuses on it, main.walk_to_area; the area of the lowest meter gets
## its colour edge, the area the player is in is dimmed), the zone prompt at the bottom, rising +N chips and the action
## card after each plain action, and the orientation toggle at the top right, under the bar's right end on the zone
## name's row (scripts/ui/orientation.gd). Drops to 60% while walking. Built in code with the minigame UI helpers;
## the project theme supplies the fonts (zone names in Kristi, the brand script).

signal leave_pressed
signal prompt_pressed
signal area_pressed(area: String)

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const T = preload("res://scripts/zones/venue_strings.gd")
const N = preload("res://scripts/zones/nightlife_strings.gd")
const Rules = preload("res://scripts/rules.gd")
const Ring = preload("res://scenes/ui/meter_ring.gd")
const PromptScene = preload("res://scenes/ui/zone_prompt.tscn")
const CardScene = preload("res://scenes/ui/action_card.tscn")
const Orientation = preload("res://scripts/ui/orientation.gd")
const OrientationToggle = preload("res://scenes/ui/orientation_toggle.gd")
const VersionInfo = preload("res://scripts/version_info.gd")

## Area buttons, top to bottom: camera area, label key, the zone walked to in that area (a zone id, or the first zone
## of that kind whose approach is in the area; main.walk_to_area), the need it refills ("" none). The floor's is the
## round table in the middle of the row of five, facing the stage (the hosts move from night to night, cast.gd). Daniele (Questions tab 2026-11-01): "press the area
## button, your character walks there and the scene focuses there". The entrance has Leave; the old-corridor alcove
## has nothing to do.
const AREAS := [["lounge", "venue.area.lounge", "arcade", "nightlife"], ["buffer", "venue.area.buffer", "tall", ""],
	["floor", "venue.area.floor", "table:Table2", "friends"], ["stage", "venue.area.stage", "stage", "music"],
	["bar", "venue.area.bar", "bar", "drinks"], ["toilets", "venue.area.toilets", "toilet", ""],
	["smoking", "venue.area.smoking", "smoking", ""]]

var session: VenueSession
var needs: Node
var rings := {}
var prompt: Control
var card: Control
var _title: Label
var _caption: Label
var _status: Label
var _x2: Label
var _tipsy: Label
var _stake: Label     ## Last Call chip (06-stakes §10.5: the venue shows no stage chip but this one)
var _annoy_row: HBoxContainer
var annoy_chips := {}  ## annoyance id -> its small chip under the title (colour of its meter)
var _areas := {}      ## area -> its button
var _here := ""
var _top: Control
var orientation_toggle: Button
var _zone_name := ""
var _title_age := 0.0
var _clock := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func setup(s: VenueSession, n: Node) -> void:
	session = s
	needs = n
	Orientation.restore(needs)
	needs.meter_changed.connect(_on_meter)
	needs.annoyances_changed.connect(func(_a): _refresh_status())
	needs.stake_stage_changed.connect(func(_o, _n): _refresh_status())
	session.action_done.connect(_on_action)
	session.state_changed.connect(_refresh_status)
	for m in Rules.METERS:
		rings[m].set_value(needs.meters[m], true)
	_refresh_status()


func _on_meter(m: String, v: float) -> void:
	if rings.has(m):
		rings[m].set_value(v)


func _build() -> void:
	var top_m := UI.dp(28)
	_top = VBoxContainer.new()
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_left = UI.dp(12)
	_top.offset_right = -UI.dp(12)
	_top.offset_top = top_m
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_theme_constant_override("separation", int(UI.dp(4)))
	add_child(_top)

	# Leave | rings | chips. No separation on the outer row (the pads take the slack) so it fits 390 dp wide.
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 0)
	_top.add_child(bar)
	var leave := Button.new()
	leave.name = "Leave"
	leave.focus_mode = Control.FOCUS_NONE
	leave.custom_minimum_size = Vector2(UI.dp(76), UI.dp(48))
	leave.text = T.t("venue.hud.leave")
	leave.add_theme_font_size_override("font_size", int(UI.dp(13)))
	for st in ["normal", "hover", "pressed"]:
		leave.add_theme_stylebox_override(st, UI.box(UI.BG_PLUM if st == "pressed" else Color(UI.BG_BASE, 0.85), 24, UI.LINE, 2.0))
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		leave.add_theme_color_override(c, UI.CREAM)
	leave.pressed.connect(func(): leave_pressed.emit())
	bar.add_child(leave)

	var left_pad := Control.new()
	left_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(left_pad)
	var ring_row := HBoxContainer.new()
	ring_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_row.add_theme_constant_override("separation", int(UI.dp(8)))
	bar.add_child(ring_row)
	for m in Rules.METERS:
		var r := Ring.new()
		r.need = m
		r.name = "Ring_" + m
		ring_row.add_child(r)
		rings[m] = r
	var right_pad := Control.new()
	right_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(right_pad)

	var chips := VBoxContainer.new()
	chips.custom_minimum_size.x = UI.dp(76)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(chips)
	_x2 = _chip(UI.GOLD)
	chips.add_child(_x2)
	_tipsy = _chip(UI.AMBER)
	chips.add_child(_tipsy)
	_stake = _chip(UI.RED_HI)
	chips.add_child(_stake)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override("separation", int(UI.dp(8)))
	_top.add_child(title_row)
	_title = UI.title("", 30)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # a long name never pushes the toggle off screen
	title_row.add_child(_title)
	orientation_toggle = OrientationToggle.new()
	orientation_toggle.pressed.connect(func():
		Orientation.toggle(needs)
		orientation_toggle.refresh())
	title_row.add_child(orientation_toggle)
	_caption = UI.label("", 14, UI.SMOKE)
	_top.add_child(_caption)
	_status = UI.label("", 14, UI.GOLD)
	_top.add_child(_status)
	_annoy_row = HBoxContainer.new()
	_annoy_row.name = "Annoyances"
	_annoy_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_annoy_row.add_theme_constant_override("separation", int(UI.dp(4)))
	_top.add_child(_annoy_row)
	for id in Rules.ANNOYANCES:
		var meter: String = Rules.ANNOYANCES[id]
		var chip := _chip(UI.need_color(meter) if meter != "" else UI.SMOKE)
		chip.name = "Annoy_" + id
		_annoy_row.add_child(chip)
		annoy_chips[id] = chip

	var col := VBoxContainer.new()
	col.name = "Areas"
	col.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.offset_right = -UI.dp(8)
	col.add_theme_constant_override("separation", int(UI.dp(6)))
	add_child(col)
	for a in AREAS:
		var b := UI.button(T.t(a[1]) + "  ›", "secondary")
		b.name = "Area_" + a[0]
		b.custom_minimum_size = Vector2(UI.dp(96), UI.dp(42))
		b.add_theme_font_size_override("font_size", int(UI.dp(13)))
		b.pressed.connect(func(): area_pressed.emit(a[0]))
		col.add_child(b)
		_areas[a[0]] = b

	add_child(VersionInfo.label())  # build version, bottom right, dim

	prompt = PromptScene.instantiate()
	prompt.pressed.connect(func(): prompt_pressed.emit())
	add_child(prompt)


func _chip(color: Color) -> Label:
	var l := UI.label("", 13, color, HORIZONTAL_ALIGNMENT_CENTER)
	var sb := UI.box(Color(UI.BG_DEEP, 0.85), 12, color, 2.0)
	sb.content_margin_left = UI.dp(6)
	sb.content_margin_right = UI.dp(6)
	l.add_theme_stylebox_override("normal", sb)
	l.visible = false
	return l


## Camera zone name, shown large for 2 s on entry.
func set_zone_name(cam_zone: String) -> void:
	if cam_zone == _zone_name or cam_zone == "":
		return
	_zone_name = cam_zone
	_title.text = UI.title_case(T.t("venue.zone." + cam_zone))
	UI.title_size(_title, 30)
	_title_age = 0.0


## Re-reads the zone name (after a language switch).
func retitle() -> void:
	var z := _zone_name
	_zone_name = ""
	set_zone_name(z)
	orientation_toggle.refresh()


## The area the player is in: its button dims (it stays in place, so the column never shifts under a thumb).
func set_area(area: String) -> void:
	if area == _here:
		return
	_here = area
	for k in _areas:
		_areas[k].modulate.a = 0.5 if k == area else 1.0


func _process(delta: float) -> void:
	_title_age += delta
	if _title_age > 2.0 and _title_age - delta <= 2.0:
		UI.title_size(_title, 18)
	_clock += delta
	if _clock >= 0.25 and session != null:
		_clock = 0.0
		_refresh_status()
	if session != null and is_instance_valid(session.player):
		var walking: bool = session.player.velocity.length() > 0.3
		_top.modulate.a = lerpf(_top.modulate.a, 0.6 if walking else 1.0, 1.0 - exp(-8.0 * delta))


func _refresh_status() -> void:
	if session == null:
		return
	var low: String = needs.lowest_meter()
	for m in rings:
		rings[m].low = m == low
	for a in AREAS:
		var b: Button = _areas[a[0]]
		var edge: Color = UI.need_color(a[3]) if a[3] == low else UI.LINE
		b.add_theme_stylebox_override("normal", UI.box(UI.BG_RAISED, 14, edge, 3.0 if a[3] == low else 2.0))
		b.add_theme_stylebox_override("hover", UI.box(UI.BG_RAISED, 14, edge, 3.0 if a[3] == low else 2.0))
	_caption.text = session.band_text()
	_caption.add_theme_color_override("font_color", UI.RED_HI if session.band.playing else UI.SMOKE)
	if needs.welcome_active():
		_x2.text = T.t("venue.hud.welcome", {"m": ceili((needs.welcome_until - needs.clock) / 60.0)})
		_x2.visible = true
	else:
		_x2.visible = false
	var st: int = session.tipsy.state()
	_tipsy.visible = st > 0
	if st > 0:
		_tipsy.text = T.t("venue.tipsy.%d" % st)
	for id in annoy_chips:
		var on: bool = needs.is_annoyed(id)
		annoy_chips[id].visible = on
		if on:
			annoy_chips[id].text = T.t("venue.annoy." + id)
	_stake.visible = needs.stake_stage == "last_call"
	if _stake.visible:
		_stake.text = T.t("venue.stake.last_call", {"d": needs.days_left()})
	_status.text = T.t("venue.hud.sitting", {"s": ceili(session.sitting["left"])}) if not session.sitting.is_empty() else ""
	if not session.smoking.is_empty():
		_status.text = N.t("nightlife.hud.smoking", {"s": ceili(session.smoking["left"])})


func _on_action(c: Dictionary) -> void:
	for m in c.get("gains", {}):
		if float(c["gains"][m]) >= 0.5 and rings.has(m):
			_float_gain(m, float(c["gains"][m]))
	if c.get("quiet", false):
		return
	if is_instance_valid(card):
		card.queue_free()
	card = CardScene.instantiate()
	add_child(card)
	card.show_card(c)


## "+N" chip that rises from the ring and fades.
func _float_gain(m: String, v: float) -> void:
	var ring: Control = rings[m]
	var l := UI.label("+%d" % roundi(v), 16, UI.need_color(m), HORIZONTAL_ALIGNMENT_CENTER)
	l.theme_type_variation = &"LabelDisplayS"
	add_child(l)
	l.position = ring.global_position - global_position + Vector2(0, ring.size.y)
	l.size = Vector2(ring.size.x, UI.dp(22))
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y + UI.dp(36), 1.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)
