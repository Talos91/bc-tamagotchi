extends "res://scripts/minigames/minigame_base.gd"
## Pour Perfect (GDD section 9 #1, Bar, Drinks +20-30). Hold to pour; release to lock the layer on its
## target line. Three layers, one glass. Overfilling only foams: it costs a little score, never the reward.
## Controls: press and hold anywhere, release. Feeds action "pour_perfect".

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

## Cumulative fill (0 = empty, 1 = rim) each layer must reach.
const TARGETS: Array[float] = [0.30, 0.58, 0.82]
const LAYER_COLORS: Array[Color] = [UI.AMBER, UI.GOLD, UI.CREAM]
const POUR_RATE := 0.075  # glass heights per second, before the flow wobble
const FLOW_WOBBLE := 0.35  # +-35% flow, sine, so releasing on time takes feel not arithmetic
const PERFECT_ERR := 0.02  # within this of the line scores 1.0
const MISS_ERR := 0.20  # this far or more scores 0.0 for the layer
const OVERFILL_PER_UNIT := 2.0  # score lost per glass-height of foam
const OVERFILL_MAX_PENALTY := 0.3
const INTRO_SECONDS := 1.5
const SETTLE_SECONDS := 0.8
const TIME_LIMIT := 30.0  # seconds after the glass arrives

enum State { INTRO, READY, POURING, SETTLE, DONE }

var state := State.INTRO
var layer := 0
var level := 0.0  # current fill 0..1 (clamped at the rim)
var spill := 0.0  # glass heights poured past the rim
var locked: Array[float] = []
var elapsed := 0.0  # time since the glass arrived
var _pour_t := 0.0
var _state_t := 0.0
var _pressed := false


func _init() -> void:
	game_id = "pour_perfect"
	action_id = "pour_perfect"
	need_id = "drinks"
	title_key = "mg.pour_perfect.title"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _on_start() -> void:
	state = State.INTRO
	layer = 0
	level = 0.0
	spill = 0.0
	locked.clear()
	elapsed = 0.0
	_pour_t = 0.0
	_state_t = 0.0
	_pressed = false
	_update_status()
	queue_redraw()


# --- Scoring (static: the tests pin these) ---------------------------------------------------------

static func layer_score(lvl: float, target: float) -> float:
	var err := absf(lvl - target)
	return clampf(1.0 - maxf(0.0, err - PERFECT_ERR) / (MISS_ERR - PERFECT_ERR), 0.0, 1.0)


static func overfill_penalty(spill_amount: float) -> float:
	return minf(OVERFILL_MAX_PENALTY, maxf(0.0, spill_amount) * OVERFILL_PER_UNIT)


static func total_score(levels: Array, spill_amount: float) -> float:
	var sum := 0.0
	for i in TARGETS.size():
		sum += layer_score(float(levels[i]) if i < levels.size() else 0.0, TARGETS[i])
	return clampf(sum / TARGETS.size() - overfill_penalty(spill_amount), 0.0, 1.0)


static func flow_rate(pour_time: float) -> float:
	return POUR_RATE * (1.0 + FLOW_WOBBLE * sin(pour_time * 2.3))


func current_score() -> float:
	var lv := locked.duplicate()
	if state == State.POURING or state == State.READY:
		lv.append(level)
	return total_score(lv, spill)


# --- Play ------------------------------------------------------------------------------------------

func press() -> void:
	if state == State.READY and running and not paused:
		state = State.POURING
		_pressed = true
		_pour_t = 0.0


func release() -> void:
	_pressed = false
	if state == State.POURING:
		_lock_layer()


func _lock_layer() -> void:
	locked.append(level)
	state = State.SETTLE
	_state_t = 0.0
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(18)
	_update_status()


func advance(dt: float) -> void:
	_state_t += dt
	match state:
		State.INTRO:
			if _state_t >= INTRO_SECONDS:
				state = State.READY
				_state_t = 0.0
		State.READY:
			elapsed += dt
		State.POURING:
			elapsed += dt
			_pour_t += dt
			var add := flow_rate(_pour_t) * dt
			level += add
			if level > 1.0:
				spill += level - 1.0
				level = 1.0
			if elapsed >= TIME_LIMIT:
				release()
		State.SETTLE:
			elapsed += dt
			if _state_t >= SETTLE_SECONDS:
				layer += 1
				if layer >= TARGETS.size() or elapsed >= TIME_LIMIT:
					state = State.DONE
					finish(total_score(locked, spill))
				else:
					state = State.READY
					_state_t = 0.0
					_update_status()
	if state == State.READY and elapsed >= TIME_LIMIT:
		# Time ran out waiting: lock what is in the glass so nobody is stuck.
		_lock_layer()
	queue_redraw()


func _update_status() -> void:
	set_status(S.t("mg.pour_perfect.status", {"n": mini(layer + 1, TARGETS.size()), "total": TARGETS.size()}))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press()
		else:
			release()


# --- Drawing ---------------------------------------------------------------------------------------

func _glass_rect() -> Rect2:
	var gw := minf(size.x * 0.42, 430.0)
	var gh := minf(size.y * 0.62, 760.0)
	var slide := 1.0 if state != State.INTRO else ease(clampf(_state_t / INTRO_SECONDS, 0.0, 1.0), 0.4)
	var x := size.x * 0.5 - gw * 0.5 + (1.0 - slide) * size.x * 0.6
	return Rect2(x, size.y * 0.16, gw, gh)


func _draw() -> void:
	if size.x <= 0.0:
		return
	var g := _glass_rect()
	# Bar top.
	draw_rect(Rect2(0, g.end.y + 6, size.x, size.y - g.end.y), UI.BG_BASE)
	draw_rect(Rect2(0, g.end.y + 6, size.x, 4), UI.LINE)
	# Fill: locked layers then the layer being poured.
	var y_bottom := g.end.y - 8.0
	var inner_h := g.size.y - 16.0
	var inner_x := g.position.x + 10.0
	var inner_w := g.size.x - 20.0
	var prev := 0.0
	for i in locked.size():
		var top_y := y_bottom - locked[i] * inner_h
		draw_rect(Rect2(inner_x, top_y, inner_w, (locked[i] - prev) * inner_h), LAYER_COLORS[i])
		prev = locked[i]
	if state == State.POURING or (state == State.READY and level > prev):
		var li := mini(layer, LAYER_COLORS.size() - 1)
		draw_rect(Rect2(inner_x, y_bottom - level * inner_h, inner_w, (level - prev) * inner_h), LAYER_COLORS[li])
		if state == State.POURING:
			draw_rect(Rect2(g.position.x + g.size.x * 0.5 - 8, g.position.y - 120, 16, 120 + (1.0 - level) * inner_h), LAYER_COLORS[li])
	if spill > 0.0:
		var foam := minf(1.0, spill * 4.0)
		for k in 6:
			draw_circle(Vector2(g.position.x + g.size.x * (0.12 + 0.15 * k), g.position.y + 4 - foam * 18.0 * (0.5 + 0.5 * sin(k * 2.1))), 14.0 + foam * 10.0, UI.CREAM)
	# Glass outline with ribs.
	draw_rect(g, UI.CREAM, false, 5.0)
	for k in range(1, 6):
		var rx := g.position.x + g.size.x * k / 6.0
		draw_line(Vector2(rx, g.position.y + 12), Vector2(rx, g.end.y - 12), Color(UI.CREAM, 0.12), 2.0)
	# Target lines for every layer; the active one is bright.
	for i in TARGETS.size():
		var ty := y_bottom - TARGETS[i] * inner_h
		var active := i == layer and state != State.DONE
		var col := UI.GOLD if active else Color(UI.SMOKE, 0.5)
		draw_line(Vector2(g.position.x - 30, ty), Vector2(g.end.x + 30, ty), col, 4.0 if active else 2.0)
		if i < locked.size():
			UI.draw_text(self, str(roundi(layer_score(locked[i], TARGETS[i]) * 100.0)), Vector2(g.end.x + 90, ty + 12), 36, UI.CREAM)
	# Hint.
	var hint := ""
	match state:
		State.READY:
			hint = S.t("mg.pour_perfect.hint_ready")
		State.POURING:
			hint = S.t("mg.pour_perfect.hint_pour")
		State.INTRO:
			hint = S.t("mg.pour_perfect.hint_intro")
	if hint != "":
		UI.draw_text(self, hint, Vector2(size.x * 0.5, size.y - 150), 44, UI.SMOKE)
	# Thumb zone ring.
	if state == State.READY or state == State.POURING:
		var c := Vector2(size.x * 0.5, size.y - 300)
		draw_arc(c, 90.0, 0, TAU, 48, UI.GOLD if _pressed else UI.LINE, 6.0, true)
