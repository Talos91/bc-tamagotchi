extends "res://scripts/minigames/minigame_base.gd"
## Candle Talk (GDD section 9 #5, Candle Floor, Friends +10-20, hearts). Five turns: the regular says a
## line, you play one of three topic cards. The best card lights the candle fully, a near card half, a
## miss not at all. Branching: line 3 (a story beat) only comes up if the candle is already at 2+;
## otherwise the talk turns to food. Score = candle light / turns. Hearts (0-3) are stored by the result card.
## Content: scenes/minigames/candle_talk/<regular>.json; strings in i18n/strings.csv (npc.<id>.talk.N).
## config: {"regular": "mali", "seed": int}.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

const DATA_DIR := "res://scenes/minigames/candle_talk/"
const REACT_SECONDS := 1.8
const FULL := 1.0
const HALF := 0.5

enum Phase { ASK, REACT, CLOSE }

var regular := "mali"
var data: Dictionary = {}
var turn := 0  # 0-based
var turns := 5
var candle := 0.0  # light gained so far (max = turns)
var phase := Phase.ASK
var line: Dictionary = {}
var card_order: Array = []
var used_lines: Array = []
var history: Array = []  # per turn: 1.0 / 0.5 / 0.0
var _phase_t := 0.0
var _reaction := ""
var _rng := RandomNumberGenerator.new()
var _bubble: Label
var _cards_box: HBoxContainer
var _name_label: Label
var _hint: Label


func _init() -> void:
	game_id = "candle_talk"
	action_id = "candle_talk"
	need_id = "friends"
	title_key = "mg.candle_talk.title"


static func load_data(regular_id: String) -> Dictionary:
	var f := FileAccess.open(DATA_DIR + regular_id + ".json", FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or not (json.data is Dictionary):
		return {}
	return json.data


## Light a card earns for a line: 1.0 best, 0.5 near, 0.0 off.
static func card_light(line_data: Dictionary, card: String) -> float:
	if card == line_data.get("best", ""):
		return FULL
	if card in line_data.get("ok", []):
		return HALF
	return 0.0


## The line for a turn, given the candle so far and lines already used (the branch in the design).
static func pick_line(lines: Array, turn_index: int, candle_now: float, used: Array) -> Dictionary:
	var plan := [1, 2, 3, 5, 6]
	var want: int = plan[mini(turn_index, plan.size() - 1)]
	var line_data := _by_id(lines, want)
	var gated := not line_data.is_empty() and candle_now < float(line_data.get("needs_candle", 0))
	if gated:
		line_data = {}
	if line_data.is_empty() or (int(line_data["id"]) in used):
		# Gated line not earned (or already used): first unused ungated line, in file order.
		for l in lines:
			if not (int(l["id"]) in used) and not l.has("needs_candle"):
				return l
	return line_data


static func _by_id(lines: Array, id: int) -> Dictionary:
	for l in lines:
		if int(l["id"]) == id:
			return l
	return {}


static func score_from(candle_total: float, turn_count: int) -> float:
	return clampf(candle_total / float(maxi(1, turn_count)), 0.0, 1.0)


func current_score() -> float:
	return score_from(candle, turns)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _bubble == null:
		_build_ui()


func _build_ui() -> void:
	_name_label = UI.label("", 17, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_bubble = UI.wrap(UI.label("", 17, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	_bubble.add_theme_font_size_override("font_size", int(UI.dp(18)))
	var bubble_panel := PanelContainer.new()
	bubble_panel.name = "Bubble"
	bubble_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bubble_panel.offset_left = UI.dp(24)
	bubble_panel.offset_right = -UI.dp(24)
	bubble_panel.offset_top = UI.dp(24)
	bubble_panel.add_theme_stylebox_override("panel", UI.box(Color(UI.BG_BASE, 0.94), 18, UI.LINE, 2.0))
	add_child(bubble_panel)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, int(UI.dp(14)))
	bubble_panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UI.dp(6)))
	m.add_child(v)
	v.add_child(_name_label)
	v.add_child(_bubble)
	_cards_box = HBoxContainer.new()
	_cards_box.name = "Cards"
	_cards_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_cards_box.offset_left = UI.dp(12)
	_cards_box.offset_right = -UI.dp(12)
	_cards_box.offset_bottom = -UI.dp(24)
	_cards_box.offset_top = -UI.dp(24 + 120)
	_cards_box.add_theme_constant_override("separation", int(UI.dp(8)))
	add_child(_cards_box)
	_hint = UI.label("", 13, UI.ASH, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -UI.dp(24 + 120 + 28)
	_hint.offset_bottom = -UI.dp(24 + 120 + 4)
	add_child(_hint)


func _on_start() -> void:
	if _bubble == null:
		_build_ui()
	regular = str(config.get("regular", "mali"))
	action_key = regular
	data = load_data(regular)
	turns = int(data.get("turns", 5))
	_rng.seed = int(config.get("seed", Time.get_ticks_usec()))
	turn = 0
	candle = 0.0
	used_lines.clear()
	history.clear()
	_name_label.text = S.t("cast.%s.name" % regular)
	_hint.text = S.t("mg.candle_talk.hint")
	_next_turn()


func _next_turn() -> void:
	if turn >= turns:
		_close()
		return
	phase = Phase.ASK
	line = pick_line(data["lines"], turn, candle, used_lines)
	used_lines.append(int(line["id"]))
	card_order = line["cards"].duplicate()
	for i in range(card_order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = card_order[i]
		card_order[i] = card_order[j]
		card_order[j] = t
	_bubble.text = S.t(line["key"])
	_hint.text = S.t("mg.candle_talk.hint")
	set_status(S.t("mg.candle_talk.status", {"regular": S.t("cast.%s.name" % regular), "turn": turn + 1, "total": turns}))
	_fill_cards(true)
	queue_redraw()


func _fill_cards(enabled: bool) -> void:
	for c in _cards_box.get_children():
		c.queue_free()
	if not enabled:
		return
	for card in card_order:
		var b := UI.button(S.t("mg.candle_talk.card." + card), "secondary")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, UI.dp(120))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(choose.bind(card))
		_cards_box.add_child(b)


## Plays a topic card for the current line.
func choose(card: String) -> void:
	if phase != Phase.ASK or not running or paused:
		return
	var light := card_light(line, card)
	history.append(light)
	candle += light
	var kind := "best" if light == FULL else ("ok" if light == HALF else "off")
	_reaction = S.t("mg.candle_talk.react.%s_%d" % [kind, 1 + _rng.randi() % 2])
	_bubble.text = _reaction
	phase = Phase.REACT
	_phase_t = 0.0
	_fill_cards(false)
	queue_redraw()


func _close() -> void:
	phase = Phase.CLOSE
	_phase_t = 0.0
	var tier := tier_for(score_from(candle, turns))
	_bubble.text = S.t("mg.candle_talk.close.tier_%d" % (tier + 1))
	_fill_cards(false)
	_hint.text = ""
	queue_redraw()


func advance(dt: float) -> void:
	_phase_t += dt
	if phase == Phase.REACT and _phase_t >= REACT_SECONDS:
		turn += 1
		_next_turn()
	elif phase == Phase.CLOSE and _phase_t >= 2.2:
		finish(score_from(candle, turns))
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# Tap to skip the reaction / closing line (text reveals by line, not by letter).
	if event is InputEventMouseButton and event.pressed:
		if phase == Phase.REACT:
			_phase_t = REACT_SECONDS
		elif phase == Phase.CLOSE:
			_phase_t = 2.2


func _result_extra() -> Dictionary:
	return {"regular": regular, "lean": score_from(candle, turns) >= TIER_PERFECT, "history": history}


func _draw() -> void:
	if size.x <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG_DEEP)
	var lit := clampf(candle / float(maxi(1, turns)), 0.0, 1.0)
	# Warm glow behind the bubble that brightens with each match.
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	for i in 6:
		draw_circle(c, 120.0 + i * 70.0, Color(UI.GOLD, (0.015 + 0.04 * lit) * (6 - i) / 3.0))
	# Candle: wax, wick, flame sized by the light.
	var base := Vector2(size.x * 0.5, size.y * 0.62)
	draw_rect(Rect2(base.x - 40, base.y - 150, 80, 150), UI.CREAM)
	draw_rect(Rect2(base.x - 40, base.y - 150, 80, 14), Color(UI.GOLD, 0.7))
	draw_line(base + Vector2(0, -150), base + Vector2(0, -172), UI.BG_BASE, 5.0)
	var flame_h := 30.0 + 110.0 * lit
	var flame := PackedVector2Array([
		base + Vector2(0, -172 - flame_h), base + Vector2(-26 - 14 * lit, -172 - flame_h * 0.35),
		base + Vector2(0, -166), base + Vector2(26 + 14 * lit, -172 - flame_h * 0.35)])
	draw_colored_polygon(flame, UI.GOLD)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(0, -172 - flame_h * 0.6), base + Vector2(-12, -172 - flame_h * 0.25),
		base + Vector2(0, -168), base + Vector2(12, -172 - flame_h * 0.25)]), UI.AMBER)
	# Table and the regular's silhouette (flat shapes, placeholder).
	draw_rect(Rect2(0, base.y, size.x, size.y - base.y), UI.BG_BASE)
	draw_rect(Rect2(0, base.y, size.x, 5), UI.LINE)
	var head := Vector2(size.x * 0.5 + 250, size.y * 0.5)
	draw_circle(head, 64.0, UI.BG_RAISED)
	draw_arc(head, 64.0, 0, TAU, 40, UI.LINE, 4.0, true)
	draw_rect(Rect2(head.x - 100, head.y + 80, 200, 120), UI.BG_RAISED)
	# Turn pips.
	for i in turns:
		var col := UI.LINE
		if i < history.size():
			col = UI.GOLD if history[i] == FULL else (UI.AMBER if history[i] == HALF else UI.ASH)
		draw_circle(Vector2(size.x * 0.5 + (i - (turns - 1) * 0.5) * 50.0, size.y * 0.69), 14.0, col)
