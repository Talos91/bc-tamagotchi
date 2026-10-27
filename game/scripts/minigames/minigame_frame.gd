extends Control
## Shared minigame frame (wireframes section 7): title, need glyph, best + status line, pause, play area,
## pause sheet, result card. Usage: add the scene, call open(game_scene), listen for `closed`.
## The frame owns the result card, so every game gets Needs.apply_action for free.

signal closed(result: Dictionary)  # DONE on the result card; result is the game's result dictionary

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Glyph = preload("res://scripts/minigames/need_glyph.gd")
const ResultCardScene = preload("res://scenes/ui/result_card.tscn")

var needs: Node  # optional injection for the result card
var game: Control
var game_scene: PackedScene
var game_config: Dictionary = {}
var last_result: Dictionary = {}

var _title: Label
var _glyph: Control
var _status: Label
var _content: Control
var _pause_layer: Control
var _card: Control
var _best_text := ""
var _game_status := ""


func _ready() -> void:
	S.install()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UI.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var safe := _safe_margins()
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = UI.dp(16)
	top.offset_right = -UI.dp(16)
	top.offset_top = safe.y + UI.dp(8)
	top.add_theme_constant_override("separation", int(UI.dp(2)))
	add_child(top)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(UI.dp(12)))
	top.add_child(bar)
	var pause_btn := Button.new()
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.custom_minimum_size = Vector2(UI.dp(48), UI.dp(48))
	pause_btn.add_theme_stylebox_override("normal", UI.box(UI.BG_BASE, 24, UI.LINE, 2.0))
	pause_btn.add_theme_stylebox_override("hover", UI.box(UI.BG_BASE, 24, UI.LINE, 2.0))
	pause_btn.add_theme_stylebox_override("pressed", UI.box(UI.BG_PLUM, 24, UI.LINE, 2.0))
	pause_btn.text = "II"
	pause_btn.add_theme_font_size_override("font_size", int(UI.dp(15)))
	pause_btn.add_theme_color_override("font_color", UI.CREAM)
	pause_btn.add_theme_color_override("font_hover_color", UI.CREAM)
	pause_btn.add_theme_color_override("font_pressed_color", UI.CREAM)
	pause_btn.pressed.connect(_open_pause)
	bar.add_child(pause_btn)
	_title = UI.label("", 24, UI.NEON, HORIZONTAL_ALIGNMENT_CENTER)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_title)
	_glyph = Glyph.new()
	_glyph.custom_minimum_size = Vector2(UI.dp(48), UI.dp(48))
	bar.add_child(_glyph)
	_status = UI.label("", 13, UI.SMOKE, HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(_status)

	_content = Control.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.offset_top = safe.y + UI.dp(8 + 48 + 2 + 22 + 8)
	_content.offset_bottom = -safe.w
	_content.clip_contents = true
	add_child(_content)

	_pause_layer = Control.new()
	_pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.visible = false
	add_child(_pause_layer)


## Top/bottom safe area in px (x unused). Phones with cutouts report them; desktop gets a small default.
func _safe_margins() -> Vector4:
	var top_m := UI.dp(24)
	var bottom_m := UI.dp(12)
	var rect := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if rect.size.y > 0 and screen.y > rect.size.y + 4 and OS.has_feature("mobile"):
		top_m = maxf(top_m, float(rect.position.y))
		bottom_m = maxf(bottom_m, float(screen.y - rect.end.y))
	return Vector4(0, top_m, 0, bottom_m)


func open(scene: PackedScene, config := {}) -> void:
	game_scene = scene
	game_config = config
	_start_game()


func _start_game() -> void:
	if is_instance_valid(game):
		game.queue_free()
	if is_instance_valid(_card):
		_card.queue_free()
	game = game_scene.instantiate()
	game.config = game_config
	game.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(game)
	game.finished.connect(_on_finished)
	game.status_changed.connect(_on_status)
	_title.text = S.t("mg.%s.title" % game.game_id)
	_glyph.need = game.need_id
	var n := _get_needs()
	var best := 0
	if n != null:
		best = int(n.ext.get("minigame_best", {}).get(game.game_id, 0))
	_best_text = S.t("mg.frame.best", {"score": best}) if best > 0 else S.t("mg.frame.no_best")
	_game_status = ""
	_refresh_status()
	game.start()


func _get_needs() -> Node:
	if needs != null:
		return needs
	return get_tree().root.get_node_or_null("Needs") if is_inside_tree() else null


func _on_status(text: String) -> void:
	_game_status = text
	_refresh_status()


func _refresh_status() -> void:
	_status.text = _best_text if _game_status == "" else "%s  ·  %s" % [_best_text, _game_status]


func _on_finished(result: Dictionary) -> void:
	last_result = result
	_pause_layer.visible = false
	_card = ResultCardScene.instantiate()
	_card.again.connect(_start_game)
	_card.done.connect(func(): closed.emit(last_result))
	add_child(_card)
	_card.show_result(result, needs)


func _open_pause() -> void:
	if not is_instance_valid(game) or game.done:
		return
	game.set_paused(true)
	for c in _pause_layer.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(UI.BG_DEEP, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(UI.dp(300), 0)
	col.add_theme_constant_override("separation", int(UI.dp(12)))
	center.add_child(col)
	col.add_child(UI.label(S.t("mg.pause.title"), 24, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	var resume := UI.button(S.t("mg.pause.resume"), "primary")
	resume.pressed.connect(_close_pause)
	col.add_child(resume)
	var how := UI.button(S.t("mg.pause.how_to"), "secondary")
	var how_label := UI.wrap(UI.label("", 15, UI.SMOKE, HORIZONTAL_ALIGNMENT_CENTER))
	how.pressed.connect(func(): how_label.text = S.t("mg.%s.how_to" % game.game_id))
	col.add_child(how)
	col.add_child(how_label)
	var leave := UI.button(S.t("mg.pause.leave"), "ghost")
	leave.pressed.connect(_leave)
	col.add_child(leave)
	col.add_child(UI.wrap(UI.label(S.t("mg.pause.leave_note"), 13, UI.ASH, HORIZONTAL_ALIGNMENT_CENTER)))
	_pause_layer.visible = true


func _close_pause() -> void:
	_pause_layer.visible = false
	if is_instance_valid(game):
		game.set_paused(false)


func _leave() -> void:
	_pause_layer.visible = false
	if is_instance_valid(game):
		game.set_paused(false)
		game.abandon()
