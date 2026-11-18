extends "res://scripts/minigames/minigame_base.gd"
## Coaster Flip (docs/design/10-minigame-next.md concept A; DECISIONS 2026-11-15 "build them all"). At a tall table:
## a stack of Black Cabin coasters on the table edge. Swipe up to flick the stack into the air; it tumbles, and the
## catch ring glows when the coasters reach it at the top of the arc, spinning flat: tap then to catch. A catch adds a coaster (the next flip spins
## faster, the flat moment gets shorter). A missed catch drops the stack: 3 drops, 45 s, or 10 caught in a run ends it.
## Score = min(best run, 10) / 10 x (0.85 + 0.15 x mean catch quality): best run 2 or less is a miss.
## config.regular: the table's regular (cast id); their stack to beat shows on a card. Feeds action "coaster_flip".

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Cast = preload("res://scripts/cast.gd")

const DROPS := 3
const TIME_LIMIT := 45.0
const FULL_RUN := 10                 ## a run of this many catches scores 1.0 (with clean catches) and ends the round
const FLIGHT_SECONDS := 1.3          ## one flip, up and down
## Catchable while the stack is in the ring: within this fraction of the flight either side of the top of the arc.
## 0.3.1 (item 37): the catch used to count anywhere from 15 % to 92 % of the flight, the coasters spun flat from the
## flick, and the ring glowed 3-5 times a flight for 50-190 ms wherever the stack was; a player tapping when it lit
## (about 200 ms to react) never caught. Now the spin is flat at the top, in the ring: one glow per flight, timed by
## the arc. Threshold and spin speed are unchanged.
const RING_HALF := 0.15
const TAP_LATENCY := 0.05            ## a tap also counts if the coasters were flat this long before (input lag on web)
const SPIN_BASE := 1.2               ## turns per second at run 0
const SPIN_PER_CATCH := 0.12
const FLAT_BASE := 0.75              ## |cos(spin)| needed to count as flat at run 0
const FLAT_PER_CATCH := 0.02
const FLAT_MAX := 0.95
const RELAXED_EASE := 0.15           ## accessibility: the flat threshold drops by this much
const INTRO_SECONDS := 1.0
const RESULT_SECONDS := 0.6
const SWIPE_PX := 60.0               ## upward drag that counts as a flick
## Stack to beat per regular (03-cast voices; design doc §A). Anyone else: DEFAULT_TO_BEAT.
const TO_BEAT := {"tt": 7, "dougie": 5, "bow": 6, "tong": 4, "ploy": 6, "jules": 8, "lung_nop": 3, "hiro": 9}
const DEFAULT_TO_BEAT := 6

enum State { INTRO, READY, FLIGHT, CAUGHT, DROPPED, DONE }

var state := State.INTRO
var run := 0                 ## catches in the current run (the stack on the table is run + 1 coasters)
var best_run := 0
var drops_left := DROPS
var qualities: Array[float] = []   ## quality of each catch in the best run so far
var _run_q: Array[float] = []
var elapsed := 0.0
var flight_t := 0.0
var regular := ""
var to_beat := DEFAULT_TO_BEAT
var beat := false
var _state_t := 0.0
var _press_pos := Vector2.ZERO
var _pressed := false


func _init() -> void:
	game_id = "coaster_flip"
	action_id = "coaster_flip"
	need_id = "friends"
	title_key = "mg.coaster_flip.title"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _on_start() -> void:
	state = State.INTRO
	run = 0
	best_run = 0
	drops_left = DROPS
	qualities.clear()
	_run_q.clear()
	elapsed = 0.0
	flight_t = 0.0
	beat = false
	_state_t = 0.0
	regular = str(config.get("regular", ""))
	to_beat = int(TO_BEAT.get(regular, DEFAULT_TO_BEAT))
	_update_status()
	queue_redraw()


# --- Rules (static where the tests pin them) -------------------------------------------------------

static func spin_rate(caught: int) -> float:
	return SPIN_BASE + SPIN_PER_CATCH * caught


static func flat_needed(caught: int, relaxed_timing := false) -> float:
	var f := minf(FLAT_MAX, FLAT_BASE + FLAT_PER_CATCH * caught)
	return f - (RELAXED_EASE if relaxed_timing else 0.0)


## How flat the spinning coasters are at time t of a flight (1 = flat, 0 = edge on): flat at the top of the arc.
static func flatness(caught: int, t: float) -> float:
	return absf(cos(TAU * spin_rate(caught) * (t - FLIGHT_SECONDS * 0.5)))


## The stack is inside the catch ring at time t of a flight.
static func in_ring(t: float) -> bool:
	return absf(t / FLIGHT_SECONDS - 0.5) <= RING_HALF


static func score_for(best: int, quals: Array) -> float:
	if best <= 0:
		return 0.0
	var q := 0.0
	for v in quals:
		q += float(v)
	q = q / quals.size() if quals.size() > 0 else 0.0
	return clampf(float(mini(best, FULL_RUN)) / FULL_RUN * (0.85 + 0.15 * q), 0.0, 1.0)


func current_score() -> float:
	return score_for(best_run, qualities)


## Flatness now, 0 when the stack is not in the air (the tests and the ring use it).
func alignment() -> float:
	return flatness(run, flight_t) if state == State.FLIGHT else 0.0


func catchable() -> bool:
	return state == State.FLIGHT and in_ring(flight_t)


# --- Play ------------------------------------------------------------------------------------------

func flick() -> void:
	if state == State.READY and running and not paused:
		state = State.FLIGHT
		flight_t = 0.0


func tap() -> void:
	if state != State.FLIGHT or not running or paused:
		return
	var a := alignment()
	var late := flight_t - TAP_LATENCY
	if in_ring(late):
		a = maxf(a, flatness(run, late))
	if catchable() and a >= flat_needed(run, relaxed):
		_catch(a)
	else:
		_drop()


func _catch(a: float) -> void:
	run += 1
	_run_q.append(a)
	if run > best_run or (run == best_run and _mean(_run_q) > _mean(qualities)):
		best_run = run
		qualities = _run_q.duplicate()
	if run > to_beat:
		beat = true
	state = State.CAUGHT
	_state_t = 0.0
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(18)
	_update_status()


func _drop() -> void:
	drops_left -= 1
	run = 0
	_run_q.clear()
	state = State.DROPPED
	_state_t = 0.0
	_update_status()


static func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / a.size()


func advance(dt: float) -> void:
	_state_t += dt
	if state != State.INTRO and state != State.DONE:
		elapsed += dt
	match state:
		State.INTRO:
			if _state_t >= INTRO_SECONDS:
				state = State.READY
				_state_t = 0.0
		State.FLIGHT:
			flight_t += dt
			if flight_t >= FLIGHT_SECONDS:
				_drop()  # nobody caught it
		State.CAUGHT, State.DROPPED:
			if _state_t >= RESULT_SECONDS:
				if drops_left <= 0 or run >= FULL_RUN:
					_end()
					return
				state = State.READY
				_state_t = 0.0
	if state != State.DONE and state != State.FLIGHT and elapsed >= TIME_LIMIT:
		_end()
		return
	queue_redraw()


func _end() -> void:
	state = State.DONE
	queue_redraw()
	finish(current_score())


func _result_extra() -> Dictionary:
	return {"best_run": best_run, "beat": beat, "regular": regular, "to_beat": to_beat}


func _update_status() -> void:
	set_status(S.t("mg.coaster_flip.status", {"stack": run + 1, "best": best_run}))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_press_pos = event.position
			if state == State.FLIGHT:
				tap()  # catch on touch-down: no lag from waiting for the lift
		elif _pressed:
			_pressed = false
			if state == State.READY and _press_pos.y - event.position.y >= SWIPE_PX:
				flick()


# --- Drawing ---------------------------------------------------------------------------------------

func _table_y() -> float:
	return size.y * 0.66


func _draw() -> void:
	if size.x <= 0.0:
		return
	var ty := _table_y()
	var sx := size.x * 0.28
	# tall table: top, edge, leg
	draw_rect(Rect2(size.x * 0.06, ty, size.x * 0.88, 30), Color("B88A5C"))
	draw_rect(Rect2(size.x * 0.06, ty + 30, size.x * 0.88, 22), Color("6E482E"))
	draw_rect(Rect2(size.x * 0.46, ty + 52, size.x * 0.08, size.y - ty), Color("3A2218"))
	var rx := minf(size.x * 0.11, 120.0)
	var on_table := run + 1 if state != State.FLIGHT else 0
	for i in on_table:
		_coaster(Vector2(sx, ty - 10 - i * 10), rx, 1.0, i == on_table - 1)
	# the ring where the stack is caught
	var ring_c := Vector2(size.x * 0.38, size.y * 0.30)
	var ring_r := rx * 1.5
	var lit := state == State.FLIGHT and alignment() >= flat_needed(run, relaxed) and catchable()
	draw_arc(ring_c, ring_r, 0, TAU, 64, UI.GOLD if lit else Color(UI.GOLD, 0.35), 8.0 if lit else 4.0, true)
	if state == State.FLIGHT:
		var p := flight_t / FLIGHT_SECONDS
		var h := sin(p * PI)  # 0 at the table, 1 at the top of the arc
		var pos := Vector2(sx, ty - 10).lerp(ring_c, h)
		var tilt := maxf(0.08, alignment())
		for i in run + 1:
			_coaster(pos + Vector2(0, -i * 6.0 * tilt), rx, tilt, i == run)
	# drops left
	for i in DROPS:
		var c := Vector2(size.x * 0.66 + i * 70, ty - 70)
		draw_arc(c, 24, 0, TAU, 32, UI.CREAM if i < drops_left else UI.LINE, 4.0, true)
	UI.draw_text(self, S.t("mg.coaster_flip.drops"), Vector2(size.x * 0.73, ty - 18), 30, UI.SMOKE)
	# the regular's stack to beat
	var who := S.t("mg.coaster_flip.house") if regular == "" else _regular_name()
	UI.draw_text(self, S.t("mg.coaster_flip.to_beat", {"who": who, "n": to_beat}), Vector2(size.x * 0.5, 40), 36, UI.GOLD if beat else UI.CREAM)
	# hint
	var hint := ""
	match state:
		State.INTRO, State.READY:
			hint = S.t("mg.coaster_flip.hint_flick")
		State.FLIGHT:
			hint = S.t("mg.coaster_flip.hint_catch")
		State.CAUGHT:
			hint = S.t("mg.coaster_flip.beat", {"who": _regular_name()}) if beat and run == to_beat + 1 and regular != "" else S.t("mg.coaster_flip.caught")
		State.DROPPED:
			hint = S.t("mg.coaster_flip.dropped")
	UI.draw_text(self, hint, Vector2(size.x * 0.5, size.y - 120), 42, UI.SMOKE)
	if state == State.READY:
		var a := Vector2(size.x * 0.8, size.y - 200)
		draw_line(a, a + Vector2(0, -140), UI.CREAM, 6.0)
		draw_line(a + Vector2(0, -140), a + Vector2(-24, -110), UI.CREAM, 6.0)
		draw_line(a + Vector2(0, -140), a + Vector2(24, -110), UI.CREAM, 6.0)


func _regular_name() -> String:
	return Cast.name_of(regular)


func _coaster(c: Vector2, rx: float, flat: float, top: bool) -> void:
	var ry := maxf(4.0, rx * 0.28 * flat)
	_ellipse(c + Vector2(0, 6), rx, ry, Color("50201A"))
	_ellipse(c, rx, ry, Color("2A1210"))
	_ellipse_outline(c, rx, ry, UI.CREAM)
	if top and flat > 0.5:
		UI.draw_text(self, "BC", c + Vector2(0, 12), 30, UI.NEON)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _ellipse_outline(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 33:
		var a := TAU * k / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, 3.0, true)
