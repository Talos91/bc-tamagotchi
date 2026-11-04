extends CanvasLayer
## Pre-alpha debug panel (owner 2026-11-04): a small Debug button on every screen while Rules.PRE_ALPHA is true, opening
## a touch-sized panel with the actions of scripts/debug_tools.gd (clear the WASTED lockout, force WASTED, clock jumps,
## ghost and debug check-in, reset the save with a confirmation). Own top layer, so it shows over the start screen and
## the WASTED screen too (the owner was locked out on the phone with no way to skip it). Built in code.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const Rules = preload("res://scripts/rules.gd")
const Nightlife = preload("res://scripts/zones/nightlife.gd")
const Tools = preload("res://scripts/debug_tools.gd")

var main: Node
var needs: Node
var toggle: Button
var panel: PanelContainer
var status: Label
var reset_btn: Button
var _reset_armed := false


func setup(main_node: Node, needs_node: Node) -> void:
	main = main_node
	needs = needs_node
	layer = 100
	name = "DebugPanel"
	toggle = Button.new()
	toggle.name = "DebugToggle"
	toggle.text = "Debug"
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.add_theme_font_size_override("font_size", int(UI.dp(12)))
	toggle.modulate = Color(1, 1, 1, 0.75)
	toggle.anchor_top = 1.0
	toggle.anchor_bottom = 1.0
	toggle.offset_left = UI.dp(6)
	toggle.offset_right = UI.dp(62)
	toggle.offset_top = -UI.dp(34)
	toggle.offset_bottom = -UI.dp(6)
	toggle.pressed.connect(func(): set_open(not panel.visible))
	add_child(toggle)

	panel = PanelContainer.new()
	panel.name = "DebugSheet"
	panel.visible = false
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = UI.dp(10)
	panel.offset_right = -UI.dp(10)
	panel.offset_top = UI.dp(40)
	panel.offset_bottom = -UI.dp(44)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.05, 0.96)
	sb.set_corner_radius_all(int(UI.dp(10)))
	sb.set_content_margin_all(UI.dp(10))
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", int(UI.dp(6)))
	scroll.add_child(box)

	var title := Label.new()
	title.text = "Debug (pre-alpha)"
	title.add_theme_font_size_override("font_size", int(UI.dp(18)))
	box.add_child(title)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", int(UI.dp(13)))
	box.add_child(status)

	_row(box, "WASTED", [["Clear lockout", _clear_lockout], ["Force WASTED", _force_wasted]])
	_row(box, "Clock", [["+1 hour", _jump.bind(3600.0)], ["+12 hours", _jump.bind(12.0 * 3600.0)], ["+1 night", _jump_night]])
	_row(box, "Stakes (ghost, revival)", [["Make ghost", _make_ghost], ["Fake check-in (revive)", _check_in]])
	reset_btn = _button(box, "Reset save", _reset)
	var close := _button(box, "Close", func(): set_open(false))
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_status()


func set_open(v: bool) -> void:
	panel.visible = v
	_reset_armed = false
	reset_btn.text = "Reset save"
	if v:
		_refresh_status()


func _row(box: VBoxContainer, label: String, buttons: Array) -> void:
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", int(UI.dp(13)))
	l.modulate = Color(1, 0.85, 0.5)
	box.add_child(l)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(UI.dp(6)))
	box.add_child(h)
	for b in buttons:
		_button(h, b[0], b[1]).size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := UI.button(text, "secondary")
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _refresh_status() -> void:
	if needs == null or status == null:
		return
	var lock := 0.0
	lock = Nightlife.seconds_left(needs)
	status.text = "Lockout left: %s   Stage: %s   Ghost: %s   Lives: %d" % [
		"none" if lock <= 0.0 else Nightlife.clock_text(lock), needs.stake_stage, str(needs.is_ghost()), needs.lives]


func _say(s: String) -> void:
	_refresh_status()
	status.text += "\n" + s


func _clear_lockout() -> void:
	var s := Tools.clear_lockout(needs)
	_say(s)


func _force_wasted() -> void:
	var line := Tools.force_wasted(needs)
	set_open(false)
	if main != null and main.has_method("_show_wasted"):
		main._show_wasted(line)


func _jump(secs: float) -> void:
	_say(Tools.jump(needs, secs))


func _jump_night() -> void:
	_say(Tools.jump_night(needs))


func _make_ghost() -> void:
	_say(Tools.make_ghost(needs))


func _check_in() -> void:
	_say(Tools.fake_check_in(needs))


func _reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		reset_btn.text = "Tap again to confirm: erases the save"
		return
	Tools.reset_save(needs)
	set_open(false)
	if main != null and main.get_tree().current_scene == main:
		main.get_tree().reload_current_scene()
