extends Control
## Minigame lab: portrait menu that launches each first-playable minigame inside the shared frame and shows
## the four Needs meters after every result, so the loop (play, result card, meters move) can be felt.
## Run: godot --path game res://scenes/minigames/minigame_lab.tscn   (add --resolution 540x960 for half size)

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Glyph = preload("res://scripts/minigames/need_glyph.gd")
const Rules = preload("res://scripts/rules.gd")
const FrameScene = preload("res://scenes/ui/minigame_frame.tscn")
const NeedsScript = preload("res://scripts/needs.gd")

const GAMES := [
	{"id": "pour_perfect", "scene": "res://scenes/minigames/pour_perfect/pour_perfect.tscn", "need": "drinks"},
	{"id": "front_row_rhythm", "scene": "res://scenes/minigames/front_row_rhythm/front_row_rhythm.tscn", "need": "music"},
	{"id": "candle_talk", "scene": "res://scenes/minigames/candle_talk/candle_talk.tscn", "need": "friends"},
	{"id": "neon_pinball", "scene": "res://scenes/minigames/neon_pinball/neon_pinball.tscn", "need": "nightlife"},
]

var needs: Node
var frame: Control
var _menu: Control
var _bars := {}
var _vibe: Label


func _ready() -> void:
	S.install()
	needs = get_node_or_null("/root/Needs")
	if needs == null:  # run outside the project's autoloads: use a throwaway instance
		needs = NeedsScript.new()
		needs.autosave = false
		add_child(needs)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_menu()


func _build_menu() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
	_bars.clear()
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu)
	var bg := ColorRect.new()
	bg.color = UI.BG_BASE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = UI.dp(16)
	col.offset_right = -UI.dp(16)
	col.offset_top = UI.dp(40)
	col.offset_bottom = -UI.dp(24)
	col.add_theme_constant_override("separation", int(UI.dp(14)))
	_menu.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := UI.label(S.t("lab.title"), 24, UI.CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var lang := UI.button(S.t("lab.lang"), "secondary")
	lang.custom_minimum_size.x = UI.dp(120)
	lang.pressed.connect(_toggle_lang)
	head.add_child(lang)

	_vibe = UI.label("", 17, UI.GOLD)
	col.add_child(_vibe)

	# Meters: fixed order Music, Friends, Drinks, Nightlife.
	var meters := PanelContainer.new()
	meters.add_theme_stylebox_override("panel", UI.box(UI.BG_RAISED, 16, UI.LINE, 2.0))
	col.add_child(meters)
	var mpad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mpad.add_theme_constant_override("margin_" + side, int(UI.dp(14)))
	meters.add_child(mpad)
	var mcol := VBoxContainer.new()
	mcol.add_theme_constant_override("separation", int(UI.dp(10)))
	mpad.add_child(mcol)
	for m in Rules.METERS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(UI.dp(10)))
		mcol.add_child(row)
		var g := Glyph.new()
		g.need = m
		row.add_child(g)
		var name_l := UI.label(S.t("need.%s.name" % m), 14, UI.SMOKE)
		name_l.custom_minimum_size.x = UI.dp(90)
		row.add_child(name_l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 100.0
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(0, UI.dp(8))
		bar.add_theme_stylebox_override("background", UI.box(UI.BG_BASE, 4))
		bar.add_theme_stylebox_override("fill", UI.box(UI.need_color(m), 4))
		row.add_child(bar)
		_bars[m] = bar
	_refresh_meters(false)

	for g in GAMES:
		var b := UI.button("", "secondary")
		b.custom_minimum_size = Vector2(0, UI.dp(76))
		b.pressed.connect(_launch.bind(g))
		col.add_child(b)
		var inner := HBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = UI.dp(14)
		inner.offset_right = -UI.dp(14)
		inner.add_theme_constant_override("separation", int(UI.dp(12)))
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(inner)
		var gl := Glyph.new()
		gl.need = g["need"]
		inner.add_child(gl)
		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(texts)
		texts.add_child(UI.label(S.t("mg.%s.title" % g["id"]), 17, UI.CREAM))
		texts.add_child(UI.label(S.t("mg.%s.subtitle" % g["id"]), 13, UI.SMOKE))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var reset := UI.button(S.t("lab.reset"), "ghost")
	reset.pressed.connect(func():
		needs.new_game()
		_refresh_meters(false))
	col.add_child(reset)


func _refresh_meters(animate := true) -> void:
	for m in Rules.METERS:
		var bar: ProgressBar = _bars.get(m)
		if bar == null:
			continue
		if animate:
			create_tween().tween_property(bar, "value", float(needs.meters[m]), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			bar.value = needs.meters[m]
	_vibe.text = S.t("lab.vibe", {"state": S.t("vibe." + Rules.vibe_state(needs.vibe()))})


func _toggle_lang() -> void:
	TranslationServer.set_locale("th" if TranslationServer.get_locale().begins_with("en") else "en")
	_build_menu()


func _launch(g: Dictionary, config := {}) -> void:
	frame = FrameScene.instantiate()
	frame.needs = needs
	add_child(frame)
	frame.closed.connect(_on_closed)
	frame.open(load(g["scene"]), config)


func launch_by_id(id: String, config := {}) -> void:
	for g in GAMES:
		if g["id"] == id:
			_launch(g, config)


func _on_closed(_result: Dictionary) -> void:
	if is_instance_valid(frame):
		frame.queue_free()
	_refresh_meters(true)
