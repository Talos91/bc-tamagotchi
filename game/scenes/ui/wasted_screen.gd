extends Control
## WASTED screen (DECISIONS "Playtest of 33dc5b9"): on the dark, WASTED in red Kristi, one of ten lines about blacking
## out in Lato underneath, what it cost, and Try again, disabled with a countdown until the lockout ends
## (Nightlife.seconds_left, game clock: F2 / F3 on the debug clock skip it). Built in code with the UI helpers.
## scripts/wasted_shot.gd puts it on its own layer; Try again is handled there.

signal try_again

const UI = preload("res://scripts/minigames/mg_ui.gd")
const N = preload("res://scripts/zones/nightlife_strings.gd")
const Rules = preload("res://scripts/rules.gd")
const Nightlife = preload("res://scripts/zones/nightlife.gd")

const TITLE_DP := 84.0

var needs: Node
var line := 0
var title: Label
var line_label: Label
var try_button: Button
var _clock := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func open(n: Node, l: int) -> void:
	needs = n
	line = l
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(minf(UI.dp(360), get_viewport_rect().size.x - UI.dp(40)), 0)
	col.add_theme_constant_override("separation", int(UI.dp(14)))
	center.add_child(col)
	# In capitals as Daniele wrote it (UI.title would title-case a script): Kristi, red, a dark red glow
	title = UI.label(N.t("nightlife.wasted.title"), TITLE_DP, UI.NEON, HORIZONTAL_ALIGNMENT_CENTER)
	title.theme_type_variation = &"LabelTitle"
	title.add_theme_font_size_override("font_size", int(UI.dp(TITLE_DP)))
	title.add_theme_color_override("font_shadow_color", Color(UI.RED, 0.85))
	title.add_theme_constant_override("shadow_outline_size", int(UI.dp(6)))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	col.add_child(title)
	line_label = UI.wrap(UI.label(N.t("nightlife.wasted.line.%d" % line), 20, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(line_label)
	col.add_child(UI.wrap(UI.label(N.t("nightlife.wasted.note", {"h": int(Rules.WASTED_LOCKOUT_HOURS)}), 14, UI.SMOKE, HORIZONTAL_ALIGNMENT_CENTER)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UI.dp(10))
	col.add_child(gap)
	try_button = UI.button("", "primary")
	try_button.pressed.connect(func():
		if not Nightlife.locked(needs):
			try_again.emit())
	col.add_child(try_button)
	refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= 0.25:
		_clock = 0.0
		refresh()


## Button state and countdown from the lockout.
func refresh() -> void:
	if needs == null:
		return
	var left := Nightlife.seconds_left(needs)
	try_button.disabled = left > 0.0
	try_button.text = N.t("nightlife.wasted.wait", {"time": Nightlife.clock_text(left)}) if left > 0.0 else N.t("nightlife.wasted.try")
