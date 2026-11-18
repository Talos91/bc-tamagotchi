extends "res://scripts/minigames/minigame_base.gd"
## Neon Moth (docs/design/10-minigame-next.md concept D; owner item 35, DECISIONS 2026-11-15). On the lounge game
## cabinet: a moth flies the length of the lounge to the BLACK CABIN neon. One tap = one flutter (an upward kick),
## gravity does the rest. Slip through the gaps between the hanging bulb strings and the speaker stacks: 15 gates in
## a fixed flight, then the sign. A bump singes a wing (1.2 s blink, back to mid-lane); 3 singes end the flight.
## Original to Black Cabin: a moth, bulbs and amps, the venue palette; nothing taken from any existing game.
## Score = 0.8 x gates passed / 15 + 0.2 for reaching the sign. config.seed: the gap layout (default: the Bangkok
## date, so everyone flies the same lounge each night). Feeds action "neon_moth".

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

# Field coordinates: 600 x 1000, y down; drawn scaled to fit the play area.
const FIELD := Vector2(600, 1000)
const MOTH_X := 170.0
const MOTH_R := 20.0
const GRAVITY := 1800.0
const FLAP_SPEED := 620.0
const MAX_FALL := 900.0
const SPEED := 220.0                 ## lounge scroll, field px per second
const GATES := 15
const SPACING := 572.0               ## between gates (2.6 s)
const START_X := 700.0               ## first gate's left edge at the start
const GATE_W := 90.0
const GAP := 300.0
const GAP_RELAXED := 360.0           ## accessibility "relaxed timing"
const GAP_MIN_Y := 280.0             ## gap centre range
const GAP_MAX_Y := 720.0
const GAP_MAX_STEP := 320.0          ## most a gap centre moves from one gate to the next
const SINGES := 3
const BLINK_SECONDS := 1.2
const INTRO_SECONDS := 1.2
const SIGN_BONUS := 0.2
const BKK_OFFSET := 7 * 3600

enum State { INTRO, FLYING, DONE }

var state := State.INTRO
var y := FIELD.y * 0.5
var vy := 0.0
var scroll := 0.0
var gap_y: Array[float] = []
var passed: Array[bool] = []
var hit: Array[bool] = []
var gates_passed := 0
var singes_left := SINGES
var reached_sign := false
var blink := 0.0
var flap_t := 9.0
var seed_used := 0
var _state_t := 0.0


func _init() -> void:
	game_id = "neon_moth"
	action_id = "neon_moth"
	need_id = "nightlife"
	title_key = "mg.neon_moth.title"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _on_start() -> void:
	state = State.INTRO
	y = FIELD.y * 0.5
	vy = 0.0
	scroll = 0.0
	gates_passed = 0
	singes_left = SINGES
	reached_sign = false
	blink = 0.0
	flap_t = 9.0
	_state_t = 0.0
	seed_used = int(config.get("seed", night_seed()))
	gap_y = layout(seed_used)
	passed.clear()
	hit.clear()
	for i in GATES:
		passed.append(false)
		hit.append(false)
	_update_status()
	queue_redraw()


# --- Rules (static where the tests pin them) -------------------------------------------------------

## The Bangkok calendar day, so the lounge is the same for everyone each night and new tomorrow.
static func night_seed(unix := -1.0) -> int:
	var t := Time.get_unix_time_from_system() if unix < 0.0 else unix
	return int(floor((t + BKK_OFFSET) / 86400.0))


static func layout(seed_value: int) -> Array[float]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[float] = []
	var prev := FIELD.y * 0.5
	for i in GATES:
		var c := clampf(rng.randf_range(GAP_MIN_Y, GAP_MAX_Y), prev - GAP_MAX_STEP, prev + GAP_MAX_STEP)
		out.append(c)
		prev = c
	return out


static func score_for(gates: int, sign: bool) -> float:
	return clampf((1.0 - SIGN_BONUS) * float(gates) / GATES + (SIGN_BONUS if sign else 0.0), 0.0, 1.0)


func current_score() -> float:
	return score_for(gates_passed, reached_sign)


func gap_size() -> float:
	return GAP_RELAXED if relaxed else GAP


## Left edge of gate i on screen (field x) right now.
func gate_x(i: int) -> float:
	return START_X + i * SPACING - scroll


func sign_x() -> float:
	return gate_x(GATES)


## The first gate the moth has not cleared yet (GATES when all are behind it).
func next_gate() -> int:
	for i in GATES:
		if gate_x(i) + GATE_W >= MOTH_X - MOTH_R:
			return i
	return GATES


# --- Play ------------------------------------------------------------------------------------------

func flap() -> void:
	if not running or paused or state == State.DONE:
		return
	if state == State.INTRO:
		state = State.FLYING
		_state_t = 0.0
	vy = -FLAP_SPEED
	flap_t = 0.0


func advance(dt: float) -> void:
	_state_t += dt
	flap_t += dt
	match state:
		State.INTRO:
			y = FIELD.y * 0.5 + sin(_state_t * 4.0) * 12.0  # hovering, waiting for the first tap
			if _state_t >= INTRO_SECONDS:
				state = State.FLYING
				_state_t = 0.0
		State.FLYING:
			_fly(dt)
	queue_redraw()


func _fly(dt: float) -> void:
	scroll += SPEED * dt
	vy = minf(vy + GRAVITY * dt, MAX_FALL)
	y += vy * dt
	blink = maxf(0.0, blink - dt)
	var g := gap_size()
	for i in GATES:
		var gx := gate_x(i)
		if not passed[i] and gx + GATE_W < MOTH_X - MOTH_R:
			passed[i] = true
			if not hit[i]:
				gates_passed += 1
				_update_status()
				_juice_gate(i)
		if blink <= 0.0 and not hit[i] and MOTH_X + MOTH_R > gx and MOTH_X - MOTH_R < gx + GATE_W:
			if y - MOTH_R < gap_y[i] - g * 0.5 or y + MOTH_R > gap_y[i] + g * 0.5:
				hit[i] = true
				_singe()
				if state == State.DONE:
					return
	if blink <= 0.0 and (y - MOTH_R < 0.0 or y + MOTH_R > FIELD.y):
		_singe()
		if state == State.DONE:
			return
	y = clampf(y, MOTH_R, FIELD.y - MOTH_R)
	if sign_x() <= MOTH_X + MOTH_R:
		reached_sign = true
		haptic("strong")
		fx().burst("confetti", _xf() * Vector2(MOTH_X, y))
		_end()


func _singe() -> void:
	singes_left -= 1
	haptic("fail")
	var f := fx()
	f.shake(Fx.TRAUMA_BUMP)
	f.fail_edge()
	f.combo_break()
	f.burst("ember", _xf() * Vector2(MOTH_X, y))
	_update_status()
	if singes_left <= 0:
		_end()
		return
	blink = BLINK_SECONDS
	y = FIELD.y * 0.5
	vy = 0.0


## Q1 proof of the shared juice kit (mg_fx): a gate passed answers with "+1", a gold flare in the gap, sparks, a
## tick and the combo. The full Neon Moth beats (§2.3: wing snap, wing icon breaking, neon flare) are job Q4.
func _juice_gate(i: int) -> void:
	var f := fx()
	var at := _xf() * Vector2(gate_x(i) + GATE_W * 0.5, gap_y[i])
	f.pop("+1", at + Vector2(0, -20))
	f.flare(at, 90.0)
	f.burst("spark", at, 8)
	f.combo_step("", Vector2(size.x * 0.5, size.y * 0.16))
	haptic("tick")


func _end() -> void:
	state = State.DONE
	queue_redraw()
	finish(current_score())


func _result_extra() -> Dictionary:
	return {"gates": gates_passed, "sign": reached_sign, "seed": seed_used}


func _update_status() -> void:
	set_status(S.t("mg.neon_moth.status", {"gates": gates_passed, "total": GATES, "wings": singes_left}))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		flap()


# --- Drawing ---------------------------------------------------------------------------------------

func _xf() -> Transform2D:
	var k := minf(size.x / FIELD.x, size.y / FIELD.y)
	var off := (size - FIELD * k) * 0.5
	return Transform2D(0.0, Vector2(k, k), 0.0, off)


func _draw() -> void:
	if size.x <= 0.0:
		return
	var xf := _xf()
	draw_set_transform_matrix(xf)
	draw_rect(Rect2(Vector2.ZERO, FIELD), Color("1A0A0C"))
	# far wall: a faint brick rhythm that scrolls slower than the gates
	for k in 14:
		var bx := fposmod(k * 90.0 - scroll * 0.35, FIELD.x + 90.0) - 45.0
		draw_rect(Rect2(bx, 0, 3, FIELD.y), Color(UI.RED, 0.18))
	var g := gap_size()
	for i in GATES:
		var gx := gate_x(i)
		if gx > FIELD.x + 20.0 or gx + GATE_W < -20.0:
			continue
		var top := gap_y[i] - g * 0.5
		var bot := gap_y[i] + g * 0.5
		var cx := gx + GATE_W * 0.5
		# hanging bulb string: three cords with warm bulbs down to the gap
		for c in 3:
			var x := gx + 15.0 + c * 30.0
			draw_line(Vector2(x, 0), Vector2(x, top - 12.0), Color("3A2218"), 4.0)
			var n := int((top - 20.0) / 46.0)
			for b in n:
				var by := top - 14.0 - b * 46.0
				draw_circle(Vector2(x, by), 9.0, Color(UI.GOLD, 0.25) if hit[i] else Color(UI.GOLD, 0.28))
				draw_circle(Vector2(x, by), 6.0, UI.GOLD)
		draw_rect(Rect2(gx, top - 10.0, GATE_W, 10.0), UI.LINE)
		# speaker stack from the floor up to the gap
		var h := FIELD.y - bot
		var boxes := maxi(1, int(h / 110.0))
		var bh := h / boxes
		for b in boxes:
			var r := Rect2(gx, bot + b * bh, GATE_W, bh - 4.0)
			draw_rect(r, Color("231212"))
			draw_rect(r, UI.LINE, false, 3.0)
			draw_circle(r.get_center(), minf(GATE_W, bh) * 0.3, Color("120808"))
			draw_arc(r.get_center(), minf(GATE_W, bh) * 0.3, 0, TAU, 24, UI.ASH, 2.0, true)
		if passed[i] and not hit[i]:
			draw_circle(Vector2(cx, gap_y[i]), 5.0, Color(UI.GOLD, 0.6))
	# the BLACK CABIN neon at the end of the room
	var sx := sign_x()
	if sx < FIELD.x + 40.0:
		draw_rect(Rect2(sx, 380, 260, 120), Color("120606"))
		draw_rect(Rect2(sx, 380, 260, 120), UI.NEON, false, 6.0)
		UI.draw_text(self, "BLACK", Vector2(sx + 130, 432), 44, UI.NEON)
		UI.draw_text(self, "CABIN", Vector2(sx + 130, 484), 44, UI.NEON)
	_draw_moth(Vector2(MOTH_X, y))
	# wings left
	for k in SINGES:
		var c := Vector2(40 + k * 48, 40)
		var col := UI.CREAM if k < singes_left else UI.LINE
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(-18, -14), c + Vector2(-16, 12)]), col)
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(18, -14), c + Vector2(16, 12)]), col)
	if state == State.INTRO:
		UI.draw_text(self, S.t("mg.neon_moth.hint"), Vector2(FIELD.x * 0.5, FIELD.y - 90), 34, UI.SMOKE)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_moth(c: Vector2) -> void:
	if blink > 0.0 and int(blink * 10.0) % 2 == 0:
		return
	var beat := clampf(flap_t / 0.18, 0.0, 1.0)
	var lift := lerpf(-22.0, 10.0, beat)  # wings snap up on a flutter, then glide down
	var tilt := clampf(vy / MAX_FALL, -0.6, 0.8) * 10.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -2), c + Vector2(-30, lift - 6), c + Vector2(-26, lift + 18)]), Color("D9C4A8"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(4, -2), c + Vector2(26, lift - 8), c + Vector2(30, lift + 16)]), Color("E8D6BC"))
	draw_circle(c + Vector2(0, tilt * 0.3), 11.0, Color("A8907F"))
	draw_circle(c + Vector2(12, -4 + tilt * 0.2), 7.0, Color("C4ADA2"))
	draw_line(c + Vector2(15, -9), c + Vector2(24, -22), UI.CREAM, 2.0)
	draw_line(c + Vector2(12, -10), c + Vector2(16, -24), UI.CREAM, 2.0)
	draw_circle(c + Vector2(15, -5), 2.0, UI.NEON)
