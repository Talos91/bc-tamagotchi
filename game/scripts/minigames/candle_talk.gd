extends "res://scripts/minigames/minigame_base.gd"
## Candle Talk (GDD section 9 #5, Candle Floor, Friends +10-20, hearts). The regular says a line, you play one of
## three topic cards. The best card lights the candle fully, a near card half, an off card not at all. Branching: line 3
## (a story beat) only comes up in the first five turns if the candle is already at 2+; otherwise the talk turns to food.
## Endless (docs/design/15-minigame-ramp.md; Daniele 2026-11-20 "make them become increasingly harder"): past turn 5
## the talk goes on; when the regular's lines are used up they come round again (a new round, never the line just
## said; the card order is reshuffled every turn; the story gate no longer applies). From turn 6 a reply timer: 8 s,
## -0.5 s a turn, 4 s from turn 14 (a shrinking bar under the bubble and the seconds on the hint line). A timeout or an
## off card gutters the candle (a strike; a near card does not); the 3rd gutter puts it out: the closing line, then
## lose(). Points (the uncapped record): 20 a best card, 10 a near one. Score (need gain, hearts, lean) = the first five
## turns' light / 5, exactly as before (history[0..4]). Level = 1 for turns 1-5, then +1 a turn, 10 at turn 14.
## Hearts (0-3) are stored by the result card,
## for regulars only (cast.gd): a talk with an owner refills Friends and keeps no hearts (Prae, id mali, has no lines
## yet, so no talk is offered at her spot).
## Content: scenes/minigames/candle_talk/<regular>.json; strings in i18n/strings.csv (npc.<id>.talk.N). Reactions and
## closings are shared (mg.candle_talk.react.*, .close.*) unless the regular has their own (npc.<id>.react.*, .close.*).
## config: {"regular": "tt", "seed": int}.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

const Cast = preload("res://scripts/cast.gd")
const Rivals = preload("res://scripts/minigames/mg_rivals.gd")

## Look B sprites (game/assets/minigames/README.md; only this regular's sprite is loaded), the section 2.3 beats through
## mg_fx (the card flies to the candle, the flame flares and the regular smiles on the best card, the flame gutters on a
## miss, NO shake) and section 4.1 competition through mg_rivals (job Q9). Payouts unchanged.
const ART_DIR := "res://assets/minigames/candle_talk/"
const ART_NEEDED := ["candle", "flame", "card", "backdrop"]
const FLY_SECONDS := 0.4
const FLARE_SECONDS := 0.6
const GUTTER_SECONDS := 0.9
const CARD_BOX_DP := 84.0

const DATA_DIR := "res://scenes/minigames/candle_talk/"
## An id with no lines of its own (a test id, a cast member added without a file) talks with this set, so a chat
## always starts. Every regular has a set (2026-11-02).
const FALLBACK := "tt"
const REACT_SECONDS := 1.8
const FULL := 1.0
const HALF := 0.5
const CLOSE_SECONDS := 2.2

## The endless ramp (docs/design/15-minigame-ramp.md, Daniele 2026-11-20).
const TIMER_FROM_TURN := 6      ## why: turns 1-5 stay the calm talk they were (they feed hearts and the lean)
const REPLY_START := 8.0        ## why: 8 s to answer at turn 6, plenty for a line and 3 cards
const REPLY_STEP := 0.5         ## why: half a second less each turn
const REPLY_CAP := 4.0          ## why: 4 s (turn 14) still reads a one-line question and 3 short cards
const LEVEL_CAP := 10           ## why: level 1 for turns 1-5, +1 a turn, 10 at turn 14 (the timer's cap)
const POINTS_BEST := 20         ## why: five best cards = 100 = a perfect old talk
const POINTS_HALF := 10

enum Phase { ASK, REACT, CLOSE }

var regular := "tt"
var data: Dictionary = {}
var turn := 0  # 0-based
var turns := 5  # the scored turns (the first five feed the score, hearts and the lean)
var candle := 0.0  # light gained so far, every turn (the score reads history[0..turns-1])
var round_used: Array = []  # line ids said in the current round (endless: the lines come round again)
var gutters := 0  # strikes: off cards and timeouts
var lives_left := STRIKES
var reply_total := 0.0  # this turn's reply time (0 = no timer)
var reply_left := 0.0
var _out := false  # the third gutter put the candle out (the closing line, then lose())
var _hint_sec := -1
var _bubble_panel: PanelContainer
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
var rival: Dictionary = {}  # tonight's regular to beat {regular, name, points}
var rival_passed := false
var rivals_store: Object = null  # tests: where mg_rivals keeps tonight's record (default Needs, else memory)
var _record: Dictionary = {}
var _art: Dictionary = {}  # sprite name -> {tex, glow, fw, fh, frames, anchor}
var _glow_layer: Control
var _t := 0.0  # flame clock
var _fly: Array = []  # cards in flight {from, w, text, light, t, landed}
var _landed := 0.0  # light the flame has received (cards that reached it)
var _lit_shown := 0.0  # eased 0..1 candle light drawn
var _flare_t := 0.0
var _gutter_t := 0.0
var _smile_t := 0.0


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


## Past the first turns (endless): a line not said yet in this round and not the line just said. The caller starts a
## new round (clears round_used) when every line was said. `roll` picks among the candidates (the game's seeded rng).
static func next_round_line(lines: Array, used_in_round: Array, prev_id: int, roll: int) -> Dictionary:
	var pool: Array = lines.filter(func(l): return not (int(l["id"]) in used_in_round) and int(l["id"]) != prev_id)
	if pool.is_empty():
		pool = lines.filter(func(l): return int(l["id"]) != prev_id)
	if pool.is_empty():
		pool = lines
	if pool.is_empty():
		return {}
	return pool[posmod(roll, pool.size())]


## Seconds to answer on turn `turn_number` (1-based): none before turn 6, 8 s at 6, -0.5 s a turn, 4 s from turn 14.
static func reply_time(turn_number: int) -> float:
	if turn_number < TIMER_FROM_TURN:
		return 0.0
	return maxf(REPLY_START - REPLY_STEP * float(turn_number - TIMER_FROM_TURN), REPLY_CAP)


## The ramp level on turn `turn_number` (1-based): 1 for turns 1-5, +1 a turn, LEVEL_CAP at turn 14.
static func level_at_turn(turn_number: int) -> int:
	return clampi(turn_number - (TIMER_FROM_TURN - 2), 1, LEVEL_CAP)


## Record points of a talk's history (uncapped): 20 a best card, 10 a near one.
static func points_of(hist: Array) -> int:
	var p := 0
	for h in hist:
		if float(h) == FULL:
			p += POINTS_BEST
		elif float(h) == HALF:
			p += POINTS_HALF
	return p


static func score_from(candle_total: float, turn_count: int) -> float:
	return clampf(candle_total / float(maxi(1, turn_count)), 0.0, 1.0)


## Light of the first `turn_count` turns (the scored talk).
static func first_light(hist: Array, turn_count: int) -> float:
	var s := 0.0
	for i in mini(turn_count, hist.size()):
		s += float(hist[i])
	return s


## The score for the need gain, hearts and the lean: the first five turns' light / 5, as before the ramp.
func current_score() -> float:
	return score_from(first_light(history, turns), turns)


func record_points() -> int:
	return points_of(history)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _bubble == null:
		_build_ui()


func _build_ui() -> void:
	_name_label = UI.label("", 17, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_bubble = UI.wrap(UI.label("", 17, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER))
	_bubble.add_theme_font_size_override("font_size", int(UI.dp(18)))
	var bubble_panel := PanelContainer.new()
	_bubble_panel = bubble_panel
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
	_cards_box.offset_top = -UI.dp(24 + CARD_BOX_DP)
	_cards_box.add_theme_constant_override("separation", int(UI.dp(8)))
	add_child(_cards_box)
	_hint = UI.label("", 13, UI.ASH, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -UI.dp(24 + CARD_BOX_DP + 28)
	_hint.offset_bottom = -UI.dp(24 + CARD_BOX_DP + 4)
	add_child(_hint)


func _on_start() -> void:
	if _bubble == null:
		_build_ui()
	regular = str(config.get("regular", "tt"))
	action_key = regular
	data = load_data(regular)
	if data.is_empty():
		data = load_data(FALLBACK)
	turns = int(data.get("turns", 5))
	_rng.seed = int(config.get("seed", Time.get_ticks_usec()))
	turn = 0
	candle = 0.0
	used_lines.clear()
	round_used.clear()
	history.clear()
	gutters = 0
	lives_left = STRIKES
	reply_total = 0.0
	reply_left = 0.0
	_out = false
	_hint_sec = -1
	_name_label.text = Cast.name_of(regular)
	_hint.text = S.t("mg.candle_talk.hint")
	var t := Rivals.tonight(game_id, rivals_store)
	rival = t["rival"]
	rival_passed = false
	_record = {}
	_fly.clear()
	_landed = 0.0
	_lit_shown = 0.0
	_flare_t = 0.0
	_gutter_t = 0.0
	_smile_t = 0.0
	_t = 0.0
	_load_art()
	_ensure_glow_layer()
	_next_turn()


func _next_turn() -> void:
	phase = Phase.ASK
	var lines: Array = data["lines"]
	if turn < turns:
		line = pick_line(lines, turn, candle, used_lines)
	else:
		# Endless: the lines come round again. Every line said in this round -> a new round.
		var all_said := true
		for l in lines:
			if not (int(l["id"]) in round_used):
				all_said = false
				break
		if all_said:
			round_used.clear()
		var prev_id: int = int(used_lines[-1]) if not used_lines.is_empty() else -1
		line = next_round_line(lines, round_used, prev_id, _rng.randi())
	used_lines.append(int(line["id"]))
	round_used.append(int(line["id"]))
	card_order = line["cards"].duplicate()
	for i in range(card_order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = card_order[i]
		card_order[i] = card_order[j]
		card_order[j] = t
	_bubble.text = S.t(line["key"])
	reply_total = reply_time(turn + 1)
	reply_left = reply_total
	_hint_sec = -1
	_update_hint()
	level_up(level_at_turn(turn + 1))
	_update_status()
	_fill_cards(true)
	queue_redraw()


func _update_status() -> void:
	set_status(S.t("mg.ramp.status", {"level": ramp_level, "points": record_points(), "lives": lives_left}))


## The hint line, with the seconds left once the reply timer runs (rewritten only when the whole second changes).
func _update_hint() -> void:
	if phase != Phase.ASK:
		return
	if reply_total <= 0.0:
		_hint.text = S.t("mg.candle_talk.hint")
		return
	var sec := int(ceil(maxf(reply_left, 0.0)))
	if sec != _hint_sec:
		_hint_sec = sec
		_hint.text = "%s · %d" % [S.t("mg.candle_talk.hint"), sec]


func _fill_cards(enabled: bool) -> void:
	for c in _cards_box.get_children():
		c.queue_free()
	if not enabled:
		return
	for card in card_order:
		var b := UI.button(S.t("mg.candle_talk.card." + card), "secondary")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, UI.dp(CARD_BOX_DP))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.set_meta("card", card)
		_style_card(b)
		b.pressed.connect(choose.bind(card))
		_cards_box.add_child(b)


## The button wears the card sprite (a nine-patch of card.png: 0 normal, 1 picked gold edge on hover / press).
func _style_card(b: Button) -> void:
	if not _art.has("card"):
		return
	var a: Dictionary = _art["card"]
	for pair in [["normal", 0], ["hover", 1], ["pressed", 1], ["disabled", 0]]:
		var at := AtlasTexture.new()
		at.atlas = a["tex"]
		at.region = Rect2(float(pair[1]) * a["fw"], 0.0, a["fw"], a["fh"])
		var sb := StyleBoxTexture.new()
		sb.texture = at
		sb.texture_margin_left = 16.0
		sb.texture_margin_right = 16.0
		sb.texture_margin_top = 16.0
		sb.texture_margin_bottom = 16.0
		sb.content_margin_left = 20.0
		sb.content_margin_right = 20.0
		b.add_theme_stylebox_override(pair[0], sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(col, UI.BG_DEEP)


## Plays a topic card for the current line.
func choose(card: String) -> void:
	if phase != Phase.ASK or not running or paused:
		return
	var light := card_light(line, card)
	_start_fly(card, light)
	history.append(light)
	candle += light
	var kind := "best" if light == FULL else ("ok" if light == HALF else "off")
	_reaction = _voice("react.%s_%d" % [kind, 1 + _rng.randi() % 2])
	_bubble.text = _reaction
	phase = Phase.REACT
	_phase_t = 0.0
	_fill_cards(false)
	_hint.text = ""
	if light == 0.0:
		_gutter()  # the flame gutters on landing (_land); the strike counts now
	else:
		_update_status()
	queue_redraw()


## The reply timer ran out: no light this turn and the candle gutters.
func _timeout() -> void:
	history.append(0.0)
	_bubble.text = S.t("mg.candle_talk.timeout")
	phase = Phase.REACT
	_phase_t = 0.0
	_fill_cards(false)
	_hint.text = ""
	_gutter_t = GUTTER_SECONDS
	fx().burst("ember", _flame_pos(), 5)
	_gutter()
	queue_redraw()


## A strike (an off card or a timeout); the third puts the candle out after this reaction.
func _gutter() -> void:
	gutters += 1
	lives_left = maxi(0, STRIKES - gutters)
	if lives_left > 0:
		var word := S.t("mg.ramp.last") if lives_left == 1 else S.t("mg.ramp.strike", {"lives": lives_left})
		fx().pop(word, Vector2(size.x * 0.5, _flame_pos().y - 200.0 * _sc()), UI.NEON, 48)
	else:
		_out = true
	haptic("fail")
	_update_status()


func _close() -> void:
	phase = Phase.CLOSE
	_phase_t = 0.0
	var tier := tier_for(current_score())
	_bubble.text = _voice("close.tier_%d" % (tier + 1))
	_fill_cards(false)
	_hint.text = ""
	queue_redraw()


func advance(dt: float) -> void:
	_phase_t += dt
	_t += dt
	_flare_t = maxf(0.0, _flare_t - dt)
	_gutter_t = maxf(0.0, _gutter_t - dt)
	_smile_t = maxf(0.0, _smile_t - dt)
	_lit_shown = move_toward(_lit_shown, clampf(_landed / float(maxi(1, turns)), 0.0, 1.0), dt * 1.5)
	_step_fly(dt)
	if _glow_layer != null:
		_glow_layer.queue_redraw()
	if phase == Phase.ASK and reply_total > 0.0:
		reply_left -= dt
		_update_hint()
		if reply_left <= 0.0:
			_timeout()
	elif phase == Phase.REACT and _phase_t >= REACT_SECONDS:
		if _out:
			_close()  # the candle is out: the closing line, then the round is lost
		else:
			turn += 1
			_next_turn()
	elif phase == Phase.CLOSE and _phase_t >= CLOSE_SECONDS:
		lose()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# Tap to skip the reaction / closing line (text reveals by line, not by letter).
	if event is InputEventMouseButton and event.pressed:
		if phase == Phase.REACT:
			_phase_t = REACT_SECONDS
		elif phase == Phase.CLOSE:
			_phase_t = CLOSE_SECONDS


func _result_extra() -> Dictionary:
	if _record.is_empty():
		_record = Rivals.record(game_id, record_points(), {}, rivals_store)
	return {"regular": regular, "lean": current_score() >= TIER_PERFECT, "history": history,
		"level": ramp_level, "speed": reply_total, "misses": gutters, "lives_left": lives_left,
		"points": record_points(), "turns": history.size(), "rival": rival, "board": _record["board_line"]}


func live_points() -> int:
	return record_points()


## The candle is out (the third gutter): no flame in the closing.
func _flame_out() -> bool:
	return _out and phase == Phase.CLOSE


# --- Art -------------------------------------------------------------------------------------------

func _fx_ok() -> bool:
	return _fx != null and is_instance_valid(_fx)


## Fit scale of the sprites to the play area (drawn for a 780 px wide play area; never above 1.5x).
func _sc() -> float:
	return clampf(minf(size.x / 780.0, size.y / 1100.0), 0.4, 1.5)


func _table_y() -> float:
	return size.y * 0.62


func _flame_pos() -> Vector2:
	return Vector2(size.x * 0.5, _table_y()) + Vector2(0.0, -165.0) * _sc()


func _regular_pos() -> Vector2:
	return Vector2(size.x * 0.77, _table_y() + 20.0 * _sc())


func _load_art() -> void:
	if not _art.is_empty():
		return
	var meta: Variant = null
	var f := FileAccess.open(ART_DIR + "sprites.json", FileAccess.READ)
	if f != null:
		meta = JSON.parse_string(f.get_as_text())
	if not meta is Dictionary:
		return
	var sprites: Dictionary = meta.get("sprites", {})
	for name in sprites:
		if str(name).begins_with("regular_") and str(name) != "regular_" + regular:
			continue  # only the talking regular is loaded (texture budget)
		var m: Dictionary = sprites[name]
		var path: String = ART_DIR + str(m.get("file", ""))
		if not ResourceLoader.exists(path):
			continue
		var a: Array = m.get("anchor_px", [0, 0])
		var e := {"tex": load(path), "glow": null, "fw": float(m["frame_w"]), "fh": float(m["frame_h"]),
			"frames": int(m.get("frames", 1)), "anchor": Vector2(float(a[0]), float(a[1]))}
		if m.has("glow_file") and ResourceLoader.exists(ART_DIR + str(m["glow_file"])):
			e["glow"] = load(ART_DIR + str(m["glow_file"]))
		_art[name] = e


## Sprites the game draws with (the tests check them; the flat drawing is only a fallback when art is missing).
func has_art() -> bool:
	for n in ART_NEEDED:
		if not _art.has(n):
			return false
	return true


func _blit(ci: CanvasItem, name: String, frame: int, pos: Vector2, sc: Vector2, col := Color.WHITE, glow := false) -> void:
	var a: Dictionary = _art.get(name, {})
	if a.is_empty():
		return
	var tex: Texture2D = a["glow"] if glow else a["tex"]
	if tex == null:
		return
	var div := 2.0 if glow else 1.0
	var fw: float = a["fw"]
	var fh: float = a["fh"]
	var fr := clampi(frame, 0, int(a["frames"]) - 1)
	var src := Rect2(fr * fw / div, 0.0, fw / div, fh / div)
	var anchor: Vector2 = a["anchor"]
	ci.draw_texture_rect_region(tex, Rect2(pos - anchor * sc, Vector2(fw, fh) * sc), src, col)


func _ensure_glow_layer() -> void:
	if _glow_layer != null and is_instance_valid(_glow_layer):
		return
	_glow_layer = Control.new()
	_glow_layer.name = "Glow"
	_glow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_layer.material = Fx.glow_material()
	_glow_layer.size = size
	_glow_layer.draw.connect(_draw_glows)
	add_child(_glow_layer)
	move_child(_glow_layer, 0)  # under the bubble, the cards and the juice overlay


## Which flame frame and how big (0-3 flicker at 8 fps, 4-5 guttering after a miss, bigger as the candle lights).
func _flame_look() -> Dictionary:
	var scale_f := (0.55 + 0.6 * _lit_shown) * (1.0 + 0.45 * (_flare_t / FLARE_SECONDS))
	var frame := int(_t * 8.0) % 4
	if _gutter_t > 0.0:
		frame = 4 + int(_t * 8.0) % 2
		scale_f *= 0.8
	return {"frame": frame, "scale": scale_f}


func _draw_glows() -> void:
	if not has_art() or size.x <= 0.0 or _flame_out():
		return
	_glow_layer.size = size
	var look := _flame_look()
	var fp := _flame_pos()
	var sc := _sc()
	var lit := _lit_shown
	if _gutter_t <= 0.0:
		Fx.draw_glow(_glow_layer, fp + Vector2(0, -40.0 * sc), (230.0 + 260.0 * lit) * sc * (1.0 + 0.3 * _flare_t / FLARE_SECONDS), Color(UI.GOLD, 0.16 + 0.24 * lit))
	_blit(_glow_layer, "flame", look["frame"], fp, Vector2.ONE * sc * float(look["scale"]), Color(1, 1, 1, 0.55 if _gutter_t > 0.0 else 0.85), true)


## A card leaves its button for the flame (section 2.3). The button's rect is read before the buttons are freed.
func _start_fly(card: String, light: float) -> void:
	if _cards_box == null:
		return
	for c in _cards_box.get_children():
		if c is Button and c.get_meta("card", "") == card:
			var r := Rect2(c.global_position - global_position, c.size)
			_fly.append({"from": r.get_center(), "w": maxf(r.size.x, 120.0), "text": c.text, "light": light, "t": 0.0, "landed": false})
			return
	_fly.append({"from": Vector2(size.x * 0.5, size.y * 0.85), "w": size.x * 0.3, "text": S.t("mg.candle_talk.card." + card), "light": light, "t": 0.0, "landed": false})


func _step_fly(dt: float) -> void:
	for c in _fly:
		c["t"] += dt
		if c["t"] >= FLY_SECONDS and not c["landed"]:
			c["landed"] = true
			_land(float(c["light"]))
	_fly = _fly.filter(func(c): return c["t"] < FLY_SECONDS + 0.02)


## The card reaches the flame: best flares it and the regular smiles, a near card flickers it up, a miss guts it. No shake.
func _land(light: float) -> void:
	_landed += light
	var f := fx()
	var fp := _flame_pos()
	var sc := _sc()
	if light == FULL:
		_flare_t = FLARE_SECONDS
		_smile_t = REACT_SECONDS
		f.flare(fp, 190.0 * sc, UI.GOLD)
		f.burst("spark", fp, 12)
		f.squash("regular")
		f.flash("candle")
	elif light == HALF:
		f.flare(fp, 100.0 * sc, UI.AMBER)
		f.burst("ember", fp, 6)
	else:
		_gutter_t = GUTTER_SECONDS
		f.burst("ember", fp, 5)
	if not rival_passed and not rival.is_empty() and live_points() > int(rival.get("points", 0)):
		rival_passed = true
		f.pop(S.t("mg.rivals.passed", {"regular": str(rival.get("name", ""))}), Vector2(size.x * 0.5, fp.y - 260.0 * sc), UI.NEON, 44)


# --- Drawing ---------------------------------------------------------------------------------------

func _draw() -> void:
	if size.x <= 0.0:
		return
	if has_art():
		_draw_art()
	else:
		_draw_flat()
	_draw_hud()


func _text_center(text: String, pos: Vector2, size_px: int, color: Color) -> void:
	UI.draw_text(self, text, pos, size_px, color)


func _draw_hud() -> void:
	var base_y := _table_y()
	var sc := _sc()
	# Turn pips on the table's left, the rival to beat under them.
	var px := size.x * 0.2
	for i in turns:
		var col := UI.LINE
		if i < history.size():
			col = UI.GOLD if history[i] == FULL else (UI.AMBER if history[i] == HALF else UI.ASH)
		draw_circle(Vector2(px + (i - (turns - 1) * 0.5) * 44.0, base_y - 24.0 * sc), 13.0, col)
	if not rival.is_empty():
		var col2 := UI.GOLD if rival_passed else UI.CREAM
		_text_center(S.t("mg.rivals.to_beat"), Vector2(px, base_y + 40.0), 22, UI.SMOKE)
		_text_center("%s %d" % [str(rival.get("name", "")), int(rival.get("points", 0))], Vector2(px, base_y + 76.0), 32, col2)
		_text_center(S.t("mg.rivals.you_now", {"score": live_points()}), Vector2(px, base_y + 110.0), 26, UI.GOLD if rival_passed else UI.SMOKE)
	_draw_reply_bar()


## The reply timer (turn 6 on): a bar under the bubble that shrinks to the centre, gold turning neon in the last 30 %.
func _draw_reply_bar() -> void:
	if phase != Phase.ASK or reply_total <= 0.0 or _bubble_panel == null:
		return
	var k := clampf(reply_left / reply_total, 0.0, 1.0)
	var y := _bubble_panel.position.y + _bubble_panel.size.y + UI.dp(10)
	var full_w := size.x - UI.dp(48)
	var h := UI.dp(6)
	draw_rect(Rect2(UI.dp(24), y, full_w, h), Color(UI.LINE, 0.8))
	var w := full_w * k
	var col := UI.GOLD if k > 0.3 else UI.NEON
	draw_rect(Rect2(size.x * 0.5 - w * 0.5, y, w, h), col)


func _draw_art() -> void:
	var b: Dictionary = _art["backdrop"]
	var tex_size := Vector2(b["fw"], b["fh"])
	var k := maxf(size.x / tex_size.x, size.y / tex_size.y)
	var shown := tex_size * k
	draw_texture_rect(b["tex"], Rect2((size - shown) * 0.5, shown), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.22))
	var sc := _sc()
	var scv := Vector2.ONE * sc
	var base_y := _table_y()
	# The table in front, a touch darker than the backdrop's own.
	draw_rect(Rect2(0, base_y, size.x, size.y - base_y), Color(UI.BG_DEEP, 0.42))
	# The regular across the candle: listen, or smile on a best card (squashed by the juice kit).
	var reg := "regular_" + regular
	if _art.has(reg):
		var sq := _fx.squash_scale("regular") if _fx_ok() else Vector2.ONE
		_blit(self, reg, 1 if (_smile_t > 0.0 or (phase == Phase.CLOSE and current_score() >= TIER_GREAT)) else 0,
			_regular_pos(), scv * sq)
	_blit(self, "candle", 0, Vector2(size.x * 0.5, base_y), scv)
	var look := _flame_look()
	var tint := _fx.flash_color("candle", Color.WHITE) if _fx_ok() else Color.WHITE
	if not _flame_out():
		_blit(self, "flame", look["frame"], _flame_pos(), scv * float(look["scale"]), tint)
	# Cards in flight: the sprite shrinks and arcs to the flame, the label travels with it.
	var fp := _flame_pos()
	for c in _fly:
		var u: float = clampf(c["t"] / FLY_SECONDS, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - u, 3.0)
		var pos: Vector2 = (c["from"] as Vector2).lerp(fp, e) + Vector2(0.0, -120.0 * sc * sin(u * PI))
		var cs: float = lerpf(float(c["w"]) / 204.0, 0.28 * sc, e)
		var picked := 1 if float(c["light"]) == FULL else 0
		_blit(self, "card", picked, pos, Vector2.ONE * cs, Color(1, 1, 1, 1.0 - 0.6 * u * u))
		UI.draw_text(self, str(c["text"]), pos + Vector2(0, 10.0 * cs), maxi(8, int(34.0 * cs / 1.0 * 0.6)), Color(UI.BG_DEEP, 1.0 - u))


func _draw_flat() -> void:
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
	if _flame_out():
		lit = 0.0
	var flame_h := 0.0 if _flame_out() else 30.0 + 110.0 * lit
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


## The regular's own reaction or closing (npc.<id>.<suffix>), else the shared one (mg.candle_talk.<suffix>).
func _voice(suffix: String) -> String:
	var key := "npc.%s.%s" % [regular, suffix]
	var own := S.t(key)
	return own if own != key else S.t("mg.candle_talk." + suffix)
