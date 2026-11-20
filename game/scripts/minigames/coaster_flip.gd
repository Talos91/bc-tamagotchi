extends "res://scripts/minigames/minigame_base.gd"
## Coaster Flip (docs/design/10-minigame-next.md concept A; DECISIONS 2026-11-15 "build them all"). At a tall table:
## a stack of Black Cabin coasters on the table edge. Swipe up to flick the stack into the air; it tumbles up into the
## catch ring, and at the top of the arc, in the ring, it spins flat and the ring glows: tap then to catch. A catch adds
## a coaster. A missed catch drops the stack.
##
## Endless ramp (docs/design/15-minigame-ramp.md; Daniele 2026-11-20 "increasingly harder and faster (but humanly possible
## not impossible)"): no clock and no full-run end; the round ends only on the third drop (lose()) or Leave. The
## difficulty follows the TOTAL catches this round (`catches`), not the current stack: a drop costs one of 3 drops and
## restarts the stack (`run`) but keeps the level. Per catch: spin +0.12 turns/s and flat need +0.02, both capped at
## catch 10 (2.4 turns/s, 0.95: today's hardest timing, the catch window stays the catch-10 window plus the 50 ms tap
## grace); after catch 10 the flight shortens 1.3 s -> 0.9 s by catch 25; from catch DRIFT_FROM the ring drifts, its
## range growing to 1.5x by catch 25. Level = 1 + catches / 5, capped at 6 (catch 25). Points = 10 a catch (uncapped
## record; the need gain reads the first 100); the ghost is the best stack reached.
## config.regular: the table's regular (cast id), watching from across the table. Feeds action "coaster_flip".
##
## Quality pass Q5 (docs/design/11-minigame-quality.md; DECISIONS 2026-11-18 Coaster Flip "very unclear, needs
## improvement"): the goal reads in the first seconds (a swipe coach over the stack, the ring marked CATCH, a closing
## ring that meets the catch ring at the exact top of the arc, and every miss says why: too early / too late); voxel
## sprites from game/assets/minigames/coaster_flip/ (look B); every §2.3 beat through mg_fx; the §3 ramp (as built, and
## from catch DRIFT_FROM the ring drifts: a higher ring is a longer flight); §4.1 competition through mg_rivals exactly
## like Neon Moth (tonight's regular to beat, your best stack tonight as a ghost stack, the board line on the result).
## The 0.3.1 catch rule (item 37) is kept: one glow per flight, at the top of the arc, in the ring.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Cast = preload("res://scripts/cast.gd")
const Rivals = preload("res://scripts/minigames/mg_rivals.gd")

const ART_DIR := "res://assets/minigames/coaster_flip/"

const DROPS := 3                     ## = STRIKES: the third drop ends the round
const FLIGHT_SECONDS := 1.3          ## one flip, up and down, with the ring at rest
## Catchable while the stack is in the ring: within this fraction of the flight either side of the top of the arc.
## 0.3.1 (item 37): the catch used to count anywhere from 15 % to 92 % of the flight, the coasters spun flat from the
## flick, and the ring glowed 3-5 times a flight for 50-190 ms wherever the stack was; a player tapping when it lit
## (about 200 ms to react) never caught. Now the spin is flat at the top, in the ring: one glow per flight, timed by
## the arc. Threshold and spin speed are unchanged.
const RING_HALF := 0.15
const TAP_LATENCY := 0.05            ## a tap also counts if the coasters were flat this long before (input lag on web)
const SPIN_BASE := 1.2               ## turns per second at catch 0
const SPIN_PER_CATCH := 0.12
const FLAT_BASE := 0.75              ## |cos(spin)| needed to count as flat at catch 0
const FLAT_PER_CATCH := 0.02
const FLAT_MAX := 0.95
## Endless ramp (15-minigame-ramp; Daniele 2026-11-20). All by TOTAL catches this round.
## why: catch 10 was the old round's hardest timing (2.4 turns/s, flat 0.95); past it only the tempo rises.
const RAMP_SPIN_CAP_AT := 10         ## spin (and so the catch window) stops rising at this catch
## why: after catch 10 the flips come quicker, 1.3 s -> 0.9 s by catch 25 (the ring's height still scales it).
const RAMP_FLIGHT_FROM := 10
const RAMP_FLIGHT_CAP_AT := 25
const RAMP_FLIGHT_MIN := 0.9         ## a flight with the ring at rest, from catch RAMP_FLIGHT_CAP_AT
## why: the drift range widens to 1.5x by catch 25 (a wider spread of ring heights = flight times to read).
const RAMP_DRIFT_CAP_AT := 25
const RAMP_DRIFT_MAX := 1.5
## why: a level every 5 catches, the top level at catch 25 where every number above has stopped.
const RAMP_LEVEL_EVERY := 5
const LEVEL_CAP := 6
const POINTS_PER_CATCH := 10         ## 10 catches = 100 = a perfect old round
const STACK_DRAW_MAX := 30           ## coasters drawn in a stack at most (a long run would leave the screen)
const RELAXED_EASE := 0.15           ## accessibility: the flat threshold drops by this much
const INTRO_SECONDS := 1.0
const RESULT_SECONDS := 0.6
const LAND_SECONDS := 0.2            ## a caught stack goes back down onto the table (the clack)
const SWIPE_PX := 60.0               ## upward drag that counts as a flick

# §3 ramp, added in Q5: from this many catches this round the ring drifts to a new spot before each flip. A higher ring
# is a longer flight (the top of the arc comes later), a lower one shorter; the closing ring shows when.
const DRIFT_FROM := 6
const DRIFT_X := 90.0                ## field px either side
const DRIFT_UP := 110.0              ## field px higher at most ...
const DRIFT_DOWN := 70.0             ## ... or lower
const DRIFT_GLIDE := 3.0             ## how fast the ring glides to its new spot (1/s, exponential)
const CHEER_SECONDS := 1.6

# Field coordinates: 600 x 1000, y down; drawn scaled to fit the play area (portrait and landscape alike).
const FIELD := Vector2(600, 1000)
const TABLE_Y := 700.0               ## the table line (front top edge)
const STACK_X := 300.0
const RING_REST := Vector2(300, 330)
const STACK_STEP := 9.0              ## field px per coaster in a stack
const COASTER_LIFT := 18.0           ## the bottom coaster's centre above the table line
const GHOST_X := 120.0
const REGULAR_POS := Vector2(500, 676)  ## the table's regular, behind the table (the neck hides under the top)

# Sprite scales (field px per sprite px).
const SPR_COASTER := 0.62
const SPR_RING := 0.62
const SPR_TABLE := 528.0 / 688.0     ## the table top is 0.88 x the field width
const SPR_LEG := 1.2
const SPR_HEAD := 1.1
const SPR_HEAD_HUD := 0.55
const SPR_ICON := 0.26

enum State { INTRO, READY, FLIGHT, CAUGHT, DROPPED, DONE }

var state := State.INTRO
var run := 0                 ## catches in the current run (the stack on the table is run + 1 coasters)
var best_run := 0
var drops_left := DROPS
var elapsed := 0.0
var flight_t := 0.0
var flight_dur := FLIGHT_SECONDS   ## this flight's length (the ring's height sets it)
var flights := 0                   ## flips so far this round
var catches := 0                   ## catches so far this round: the ramp, the points (coach: the hint until the first)
var regular := ""                  ## the table's regular (config.regular): hearts on the result card, as before
var beat := false                  ## passed tonight's regular to beat
var drop_reason := ""              ## "early" | "late": why the last drop happened (shown, and the tests read it)
var ring_off := Vector2.ZERO       ## where the ring is drifting to (field px from RING_REST)
var ring_now := Vector2.ZERO       ## where the ring is drawn now
var rival: Dictionary = {}         ## tonight's regular to beat {regular, name, points}
var ghost: Dictionary = {}         ## your best run tonight {stack}, or {}
var rivals_store: Object = null    ## tests: where mg_rivals keeps tonight's record (default Needs, else memory)
var _record: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _state_t := 0.0
var _anim_t := 0.0
var _press_pos := Vector2.ZERO
var _pressed := false
var _was_lit := false
var _landed := false
var _catch_pos := Vector2.ZERO
var _cheer := 0.0
var _nudge := 0.0
var _scatter: Array = []           ## dropped coasters flying off: {p, v, a, spin}
var _art: Dictionary = {}          ## sprite name -> {tex, glow, fw, fh, frames, anchor}
var _glow_layer: Control


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
	elapsed = 0.0
	flight_t = 0.0
	flight_dur = FLIGHT_SECONDS
	flights = 0
	catches = 0
	beat = false
	drop_reason = ""
	ring_off = Vector2.ZERO
	ring_now = Vector2.ZERO
	_state_t = 0.0
	_cheer = 0.0
	_nudge = 0.0
	_was_lit = false
	_scatter.clear()
	_record = {}
	_rng.seed = int(config.get("seed", Cast.night()))
	regular = str(config.get("regular", ""))
	var t := Rivals.tonight(game_id, rivals_store)
	rival = t["rival"]
	var g: Dictionary = t["ghost"]
	ghost = g if int(g.get("stack", 0)) > 0 else {}
	_load_art()
	_ensure_glow_layer()
	_update_status()
	queue_redraw()


# --- Rules (static where the tests pin them) -------------------------------------------------------

## Turns per second after `caught` catches this round (capped at catch RAMP_SPIN_CAP_AT).
static func spin_rate(caught: int) -> float:
	return SPIN_BASE + SPIN_PER_CATCH * mini(caught, RAMP_SPIN_CAP_AT)


static func flat_needed(caught: int, relaxed_timing := false) -> float:
	var f := minf(FLAT_MAX, FLAT_BASE + FLAT_PER_CATCH * caught)
	return f - (RELAXED_EASE if relaxed_timing else 0.0)


## How flat the spinning coasters are at time t of a flight (1 = flat, 0 = edge on): flat at the top of the arc.
static func flatness(caught: int, t: float, dur := FLIGHT_SECONDS) -> float:
	return absf(cos(TAU * spin_rate(caught) * (t - dur * 0.5)))


## The stack is inside the catch ring at time t of a flight of `dur` seconds.
static func in_ring(t: float, dur := FLIGHT_SECONDS) -> bool:
	return absf(t / dur - 0.5) <= RING_HALF


## The one catchable flat moment of a flight: in the ring AND within a quarter turn of the top of the arc. Q5: with
## relaxed timing (flat need -0.15) a fast spin also came flat a half turn either side while still in the ring, and the
## ring glowed 3 times a flight at run 9; this keeps the 0.3.1 rule (one glow per flight) for relaxed too.
static func catch_window(caught: int, t: float, dur := FLIGHT_SECONDS) -> bool:
	return in_ring(t, dur) and absf(t - dur * 0.5) <= 0.25 / spin_rate(caught)


## A flight's length for a ring `rise` field px above the stack: a higher ring is a longer flight (free fall).
## After `caught` catches the flight shortens by this factor (1 up to catch RAMP_FLIGHT_FROM, 0.9/1.3 from the cap).
static func flight_scale(caught: int) -> float:
	var k := clampf(float(caught - RAMP_FLIGHT_FROM) / float(RAMP_FLIGHT_CAP_AT - RAMP_FLIGHT_FROM), 0.0, 1.0)
	return lerpf(1.0, RAMP_FLIGHT_MIN / FLIGHT_SECONDS, k)


static func flight_for(rise: float, caught := 0) -> float:
	var rest := TABLE_Y - RING_REST.y
	return FLIGHT_SECONDS * sqrt(maxf(0.25, rise / rest)) * flight_scale(caught)


## How wide the ring drifts after `caught` catches: 0 before DRIFT_FROM, then 1 -> RAMP_DRIFT_MAX by RAMP_DRIFT_CAP_AT.
static func drift_scale(caught: int) -> float:
	if caught < DRIFT_FROM:
		return 0.0
	var k := clampf(float(caught - DRIFT_FROM) / float(RAMP_DRIFT_CAP_AT - DRIFT_FROM), 0.0, 1.0)
	return lerpf(1.0, RAMP_DRIFT_MAX, k)


## The ramp level after `caught` catches: 1 + one every RAMP_LEVEL_EVERY, capped at LEVEL_CAP.
static func level_at(caught: int) -> int:
	return mini(LEVEL_CAP, 1 + caught / RAMP_LEVEL_EVERY)


static func points_of(caught: int) -> int:
	return POINTS_PER_CATCH * caught


func record_points() -> int:
	return points_of(catches)


func current_score() -> float:
	return score_of(record_points())


func live_points() -> int:
	return record_points()


## When this flight reaches the top of its arc, in the ring.
func apex_time() -> float:
	return flight_dur * 0.5


## Flatness now, 0 when the stack is not in the air (the tests and the ring use it).
func alignment() -> float:
	return flatness(catches, flight_t, flight_dur) if state == State.FLIGHT else 0.0


func catchable() -> bool:
	return state == State.FLIGHT and catch_window(catches, flight_t, flight_dur)


## The ring is lit: the stack is in it and flat enough to catch. Once per flight (item 37).
func ring_lit() -> bool:
	return catchable() and alignment() >= flat_needed(catches, relaxed)


## The catch ring's centre for the next (or current) flight.
func ring_center() -> Vector2:
	return RING_REST + ring_off


# --- Play ------------------------------------------------------------------------------------------

func flick() -> void:
	if (state != State.READY and state != State.INTRO) or not running or paused:
		return
	state = State.FLIGHT
	_state_t = 0.0
	flight_t = 0.0
	flight_dur = flight_for(TABLE_Y - ring_center().y, catches)
	flights += 1
	drop_reason = ""
	_was_lit = false
	# §2.3 swipe: the stack whooshes up (motion trail in the draw code), a tick
	var f := fx()
	f.squash("stack")
	f.burst("spark", _xf() * Vector2(STACK_X, TABLE_Y - COASTER_LIFT), 5)
	haptic("tick")


func tap() -> void:
	if state != State.FLIGHT or not running or paused:
		return
	var a := alignment()
	var late := flight_t - TAP_LATENCY
	if catch_window(catches, late, flight_dur):
		a = maxf(a, flatness(catches, late, flight_dur))
	if catchable() and a >= flat_needed(catches, relaxed):
		_catch(a)
	else:
		_drop("early" if flight_t < apex_time() else "late")


func _catch(_a: float) -> void:
	_catch_pos = stack_pos()
	run += 1
	catches += 1
	best_run = maxi(best_run, run)
	state = State.CAUGHT
	_state_t = 0.0
	_landed = false
	level_up(level_at(catches))
	_update_status()
	# §2.3 catch: hit-stop, "+1", sparks in the ring; the stack grows with a clack when it lands (advance)
	var f := fx()
	var at := _xf() * _catch_pos
	f.hit_stop()
	f.pop("+1", at + Vector2(0, -50) * _k())
	f.burst("spark", at, 10)
	f.flare(at, 120.0 * _k())
	f.combo_step("", Vector2(size.x * 0.5, size.y * 0.145))
	if run % 5 == 0:
		f.flare(at, 200.0 * _k(), UI.AMBER)
		f.burst("confetti", at, 14)
		haptic("strong")
	else:
		haptic("tick")
	# §4.1 + §2.3: passing tonight's regular; their head reacts and the line pops
	if not beat and not rival.is_empty() and record_points() > int(rival.get("points", 0)):
		beat = true
		_cheer = CHEER_SECONDS
		f.squash("rival")
		f.pop(S.t("mg.rivals.passed", {"regular": str(rival.get("name", ""))}), _xf() * Vector2(FIELD.x * 0.5, 200.0), UI.NEON, 44)
	elif regular != "":
		_cheer = maxf(_cheer, 0.6)  # the table's regular cheers every catch
	# the ring drifts from catch DRIFT_FROM on (§3), wider as the round goes on
	_pick_ring()


func _drop(reason := "late") -> void:
	var from := stack_pos()
	var n := run + 1
	drops_left -= 1
	run = 0  # the stack starts again; the difficulty (catches) stays
	state = State.DROPPED
	_state_t = 0.0
	drop_reason = reason
	_pick_ring()
	_update_status()
	# §2.3 drop: the coasters scatter, shake 0.3, the red edge, a double buzz
	for i in mini(n, 8):
		_scatter.append({"p": from + Vector2(0, -i * STACK_STEP), "v": Vector2(_rng.randf_range(-380, 380), _rng.randf_range(-520, -180)),
			"a": _rng.randf(), "spin": _rng.randf_range(-3.0, 3.0)})
	var f := fx()
	f.shake(Fx.TRAUMA_LOSS if drops_left <= 0 else Fx.TRAUMA_BUMP)
	f.fail_edge()
	f.combo_break()
	f.burst("ember", _xf() * from, 8)
	f.pop(S.t("mg.coaster_flip.early" if reason == "early" else "mg.coaster_flip.late"), _xf() * Vector2(FIELD.x * 0.5, ring_now.y + 130.0), UI.NEON, 46)
	if drops_left > 0:
		var strike := S.t("mg.ramp.last") if drops_left == 1 else S.t("mg.ramp.strike", {"lives": drops_left})
		f.pop(strike, _xf() * Vector2(FIELD.x * 0.5, TABLE_Y - 120.0), UI.AMBER, 40)
	f.squash("drop%d" % maxi(0, drops_left))
	haptic("fail")


## The next flight's ring: at rest, or drifting once the round has DRIFT_FROM catches (a drop keeps the drift).
func _pick_ring() -> void:
	var k := drift_scale(catches)
	if k > 0.0:
		ring_off = Vector2(_rng.randf_range(-DRIFT_X, DRIFT_X), _rng.randf_range(-DRIFT_UP, DRIFT_DOWN)) * k
	else:
		ring_off = Vector2.ZERO


func advance(dt: float) -> void:
	_state_t += dt
	_anim_t += dt
	_cheer = maxf(0.0, _cheer - dt)
	_nudge = maxf(0.0, _nudge - dt)
	if ring_now == Vector2.ZERO:
		ring_now = ring_center()
	if state != State.FLIGHT:
		ring_now = ring_now.lerp(ring_center(), 1.0 - exp(-DRIFT_GLIDE * dt))
	if state != State.INTRO and state != State.DONE:
		elapsed += dt
	_step_scatter(dt)
	match state:
		State.INTRO:
			if _state_t >= INTRO_SECONDS:
				state = State.READY
				_state_t = 0.0
		State.FLIGHT:
			ring_now = ring_center()
			flight_t += dt
			var lit := ring_lit()
			if lit and not _was_lit:
				# §2.3 ring "flat": the ring pulses
				var f := fx()
				f.flash("ring")
				f.flare(_xf() * ring_now, 150.0 * _k(), UI.GOLD)
			_was_lit = lit
			if flight_t >= flight_dur:
				_drop("late")  # nobody caught it
		State.CAUGHT, State.DROPPED:
			if state == State.CAUGHT and not _landed and _state_t >= LAND_SECONDS:
				_landed = true
				var f := fx()
				f.squash("stack")
				f.burst("spark", _xf() * Vector2(STACK_X, TABLE_Y - COASTER_LIFT), 4)
			if _state_t >= RESULT_SECONDS:
				if drops_left <= 0:
					_end()
					return
				state = State.READY
				_state_t = 0.0
	queue_redraw()
	if _glow_layer != null:
		_glow_layer.queue_redraw()


func _step_scatter(dt: float) -> void:
	for s in _scatter:
		s["v"] = s["v"] + Vector2(0, 1800.0 * dt)
		s["p"] = s["p"] + s["v"] * dt
		s["a"] = float(s["a"]) + float(s["spin"]) * dt
	_scatter = _scatter.filter(func(s: Dictionary) -> bool: return s["p"].y < FIELD.y + 120.0)


## The third drop: the round is lost (the only end besides Leave).
func _end() -> void:
	state = State.DONE
	queue_redraw()
	lose()


## The run that just ended, as tonight's ghost (only kept if it is your best tonight): the stack you reached.
func ghost_data() -> Dictionary:
	return {"stack": best_run}


func _result_extra() -> Dictionary:
	if _record.is_empty():
		_record = Rivals.record(game_id, record_points(), ghost_data(), rivals_store)
	return {"best_run": best_run, "catches": catches, "beat": beat, "regular": regular, "rival": rival,
		"board": _record["board_line"], "level": ramp_level, "speed": snappedf(spin_rate(catches), 0.01),
		"misses": DROPS - drops_left}


func _update_status() -> void:
	set_status(S.t("mg.ramp.status", {"level": ramp_level, "points": record_points(), "lives": drops_left}))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_press_pos = event.position
			if state == State.FLIGHT:
				tap()  # catch on touch-down: no lag from waiting for the lift
		elif _pressed:
			_pressed = false
			if state == State.READY or state == State.INTRO:
				if _press_pos.y - event.position.y >= SWIPE_PX:
					flick()
				else:
					_nudge_swipe()
	elif event is InputEventMouseMotion and _pressed and (state == State.READY or state == State.INTRO):
		if _press_pos.y - event.position.y >= SWIPE_PX:
			_pressed = false
			flick()  # flick as soon as the finger has gone far enough up: no wait for the lift


## A tap where a swipe is wanted: say so (every input answers, §2.1).
func _nudge_swipe() -> void:
	_nudge = 1.0
	var f := fx()
	f.squash("coach")
	f.pop(S.t("mg.coaster_flip.nudge"), _xf() * Vector2(FIELD.x * 0.5, TABLE_Y - 150.0), UI.CREAM, 40)


# --- Art -------------------------------------------------------------------------------------------

## Loads the shared sprites and only the regulars on screen (the table's and tonight's rival), README memory rule.
func _load_art() -> void:
	var meta: Variant = null
	var f := FileAccess.open(ART_DIR + "sprites.json", FileAccess.READ)
	if f != null:
		meta = JSON.parse_string(f.get_as_text())
	if not meta is Dictionary:
		return
	var want := ["coaster", "ring", "table_top", "table_leg", "backdrop"]
	for id in [regular, str(rival.get("regular", ""))]:
		if id != "":
			want.append("regular_" + id)
	var sprites: Dictionary = meta.get("sprites", {})
	for name in want:
		if _art.has(name) or not sprites.has(name):
			continue
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
	for n in ["coaster", "ring", "table_top", "table_leg", "backdrop"]:
		if not _art.has(n):
			return false
	return true


## Regular sprites loaded right now (the memory rule: never all eight).
func loaded_regulars() -> int:
	var n := 0
	for k in _art:
		if str(k).begins_with("regular_"):
			n += 1
	return n


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
	ci.draw_texture_rect_region(tex, Rect2(pos - a["anchor"] * sc, Vector2(fw, fh) * sc), src, col)


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
	if _fx != null and is_instance_valid(_fx):
		move_child(_glow_layer, _fx.get_index())  # glows under the juice overlay


# --- Drawing ---------------------------------------------------------------------------------------

func _xf() -> Transform2D:
	var k := minf(size.x / FIELD.x, size.y / FIELD.y)
	var off := (size - FIELD * k) * 0.5
	return Transform2D(0.0, Vector2(k, k), 0.0, off)


func _k() -> float:
	return maxf(0.01, minf(size.x / FIELD.x, size.y / FIELD.y))


## Where the stack's bottom coaster is now (field px): on the table, in the air, or going back down after a catch.
func stack_pos() -> Vector2:
	var base := Vector2(STACK_X, TABLE_Y - COASTER_LIFT)
	match state:
		State.FLIGHT:
			var h := sin(clampf(flight_t / flight_dur, 0.0, 1.0) * PI)  # 0 at the table, 1 at the top of the arc
			return base.lerp(ring_now + Vector2(0, mini(run, STACK_DRAW_MAX) * STACK_STEP * 0.5), h)
		State.CAUGHT:
			var k := clampf(_state_t / LAND_SECONDS, 0.0, 1.0)
			return _catch_pos.lerp(base, k * k)
	return base


## The coaster sheet frame for a spin of `turns` (0 flat top up, 2 edge on, 4 flat bottom up).
static func spin_frame(turns: float) -> int:
	return posmod(roundi(turns * 8.0), 8)


## How far the closing ring still is from the catch ring: 1 at the flick, 0 at the top of the arc (the timing cue).
func closing() -> float:
	if state != State.FLIGHT:
		return -1.0
	return clampf((apex_time() - flight_t) / apex_time(), -1.0, 1.0)


func _draw() -> void:
	if size.x <= 0.0:
		return
	if _glow_layer != null:
		_glow_layer.size = size
	if ring_now == Vector2.ZERO:
		ring_now = ring_center()
	# the main-room tables, blurred: covers the whole play area
	if _art.has("backdrop"):
		var b: Dictionary = _art["backdrop"]
		var cover: float = maxf(size.x / b["fw"], size.y / b["fh"])
		var w: float = b["fw"] * cover
		var h: float = b["fh"] * cover
		draw_texture_rect(b["tex"], Rect2(Vector2((size.x - w) * 0.5, (size.y - h) * 0.5), Vector2(w, h)), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("1A0A0C"))
	draw_set_transform_matrix(_xf())
	_draw_regular()
	_draw_table()
	_draw_ghost()
	_draw_ring()
	_draw_stack()
	_draw_scatter()
	_draw_hud()
	_draw_coach()
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_table() -> void:
	if not has_art():
		draw_rect(Rect2(36, TABLE_Y, 528, 30), Color("B88A5C"))
		draw_rect(Rect2(36, TABLE_Y + 30, 528, 22), Color("6E482E"))
		draw_rect(Rect2(276, TABLE_Y + 52, 48, FIELD.y), Color("3A2218"))
		return
	var leg: Dictionary = _art["table_leg"]
	var top: Dictionary = _art["table_top"]
	var y0: float = TABLE_Y + (top["fh"] - top["anchor"].y) * SPR_TABLE - 4.0
	var step: float = (leg["fh"] - leg["anchor"].y) * SPR_LEG
	var y := y0
	while y < FIELD.y + 200.0:
		_blit(self, "table_leg", 0, Vector2(STACK_X, y), Vector2.ONE * SPR_LEG)
		y += step
	_blit(self, "table_top", 0, Vector2(STACK_X, TABLE_Y), Vector2.ONE * SPR_TABLE)


## The table's regular, across the table: calm, cheering on catches.
func _draw_regular() -> void:
	if regular == "" or not _art.has("regular_" + regular):
		return
	var bob := sin(_anim_t * 2.0) * 2.0
	_blit(self, "regular_" + regular, 1 if _cheer > 0.0 else 0, REGULAR_POS + Vector2(0, bob - (6.0 if _cheer > 0.0 else 0.0)), Vector2.ONE * SPR_HEAD)


## Your best stack tonight, faint at the side of the table: the height to reach.
func _draw_ghost() -> void:
	if ghost.is_empty():
		return
	var n := int(ghost.get("stack", 0)) + 1
	var col := Color(0.75, 0.9, 1.0, 0.3)
	for i in mini(n, STACK_DRAW_MAX):
		_coaster(Vector2(GHOST_X, TABLE_Y - COASTER_LIFT - i * STACK_STEP), 0, col)
	UI.draw_text(self, str(n - 1), Vector2(GHOST_X, TABLE_Y - COASTER_LIFT - n * STACK_STEP - 36.0), 30, Color(0.75, 0.9, 1.0, 0.7))


func _draw_ring() -> void:
	var c := ring_now
	var lit := state == State.FLIGHT and ring_lit()
	var tint := _fx.flash_color("ring", Color.WHITE) if _fx_ok() else Color.WHITE
	if _art.has("ring"):
		_blit(self, "ring", 0 if lit else 1, c, Vector2.ONE * SPR_RING, tint if lit else Color(1, 1, 1, 0.75))
	else:
		draw_arc(c, 90.0, 0, TAU, 64, UI.GOLD if lit else Color(UI.GOLD, 0.35), 8.0 if lit else 4.0, true)
	# the timing cue: a ring closing in on the catch ring, meeting it at the top of the arc
	var k := closing()
	if k > 0.0:
		var r := 88.0 * (1.0 + 1.7 * k)
		draw_arc(c, r, 0, TAU, 64, Color(UI.CREAM, 0.35 + 0.5 * (1.0 - k)), 5.0, true)
	if catches == 0 and state != State.DONE:
		UI.draw_text(self, S.t("mg.coaster_flip.zone"), c + Vector2(0, -112.0), 28, Color(UI.GOLD, 0.9))


func _draw_stack() -> void:
	if state == State.DROPPED or state == State.DONE and drops_left <= 0:
		return
	var p := stack_pos()
	var n := mini(run + 1, STACK_DRAW_MAX)
	var sq := _fx.squash_scale("stack") if _fx_ok() else Vector2.ONE
	if state == State.FLIGHT:
		var turns := spin_rate(catches) * (flight_t - apex_time())
		var fr := spin_frame(turns)
		# §2.3 whoosh: motion trail frames on the way up
		if flight_t < apex_time() * 0.7:
			for j in [2, 1]:
				var tb := maxf(0.0, flight_t - j * 0.035)
				var hb := sin(clampf(tb / flight_dur, 0.0, 1.0) * PI)
				var pb := Vector2(STACK_X, TABLE_Y - COASTER_LIFT).lerp(ring_now + Vector2(0, mini(run, STACK_DRAW_MAX) * STACK_STEP * 0.5), hb)
				_draw_pile(pb, n, spin_frame(spin_rate(catches) * (tb - apex_time())), Color(1, 1, 1, 0.22 / j), Vector2.ONE)
		_draw_pile(p, n, fr, Color.WHITE, Vector2.ONE)
		return
	_draw_pile(p, n, 0, Color.WHITE, sq)


## A stack of n coasters, bottom coaster at p; edge-on frames stack tighter.
func _draw_pile(p: Vector2, n: int, frame: int, col: Color, sq: Vector2) -> void:
	var flat := absf(cos(TAU * frame / 8.0))
	var step := STACK_STEP * maxf(0.25, flat) * sq.y
	for i in n:
		_coaster(p + Vector2(0, -i * step), frame, col, sq)


func _coaster(c: Vector2, frame: int, col: Color, sq := Vector2.ONE) -> void:
	if _art.has("coaster"):
		_blit(self, "coaster", frame, c, Vector2(sq.x, sq.y) * SPR_COASTER, col)
		return
	var flat := maxf(0.12, absf(cos(TAU * frame / 8.0)))
	var pts := PackedVector2Array()
	for k in 32:
		var a := TAU * k / 32.0
		pts.append(c + Vector2(cos(a) * 50.0 * sq.x, sin(a) * 15.0 * flat * sq.y))
	draw_colored_polygon(pts, Color(Color("50201A"), col.a))


func _draw_scatter() -> void:
	for s in _scatter:
		_coaster(s["p"], spin_frame(float(s["a"])), Color(1, 1, 1, 0.9))


func _draw_hud() -> void:
	# drops left: one coaster per drop left, lost ones go dark
	for i in DROPS:
		var p := Vector2(42 + i * 58, 46)
		var sq := _fx.squash_scale("drop%d" % i) if _fx_ok() else Vector2.ONE
		var col := Color.WHITE if i < drops_left else Color(0.35, 0.2, 0.2, 0.6)
		if _art.has("coaster"):
			_blit(self, "coaster", 0, p, sq * SPR_ICON * 1.25, col)
		else:
			draw_circle(p, 16.0, UI.CREAM if i < drops_left else UI.LINE)
	UI.draw_text(self, S.t("mg.coaster_flip.drops"), Vector2(96, 92), 20, UI.SMOKE)
	# the level (no clock: the round runs until the third drop)
	UI.draw_text(self, S.t("mg.ramp.level", {"n": ramp_level}), Vector2(FIELD.x * 0.5, 40.0), 26, UI.GOLD)
	# tonight's regular to beat, and you (as Neon Moth)
	if not rival.is_empty():
		var col := UI.GOLD if beat else UI.CREAM
		var rid := "regular_" + str(rival.get("regular", ""))
		var hx := FIELD.x - 20.0
		if _art.has(rid):
			var sq := _fx.squash_scale("rival") if _fx_ok() else Vector2.ONE
			_blit(self, rid, 1 if beat else 0, Vector2(FIELD.x - 52.0, 84.0), sq * SPR_HEAD_HUD)
			hx = FIELD.x - 96.0
		_text_right(S.t("mg.rivals.to_beat"), Vector2(hx, 38.0), 20, UI.SMOKE)
		_text_right("%s %d" % [str(rival.get("name", "")), int(rival.get("points", 0))], Vector2(hx, 68.0), 28, col)
		_text_right(S.t("mg.rivals.you_now", {"score": record_points()}), Vector2(hx, 96.0), 22, UI.GOLD if beat else UI.SMOKE)


## The coach: what to do now, in one line, plus the animated swipe before the first flips.
func _draw_coach() -> void:
	var line := ""
	var col := UI.CREAM
	match state:
		State.INTRO, State.READY:
			line = S.t("mg.coaster_flip.hint_flick")
			if flights < 2 or _nudge > 0.0:
				_draw_swipe_hand()
		State.FLIGHT:
			line = S.t("mg.coaster_flip.hint_catch") if catches == 0 or ring_lit() else ""
		State.CAUGHT:
			line = S.t("mg.coaster_flip.caught")
			col = UI.GOLD
		State.DROPPED:
			line = S.t("mg.coaster_flip.early_hint" if drop_reason == "early" else "mg.coaster_flip.late_hint")
			col = UI.SMOKE
	if line != "":
		var sq := _fx.squash_scale("coach") if _fx_ok() else Vector2.ONE
		UI.draw_text(self, line, Vector2(FIELD.x * 0.5, FIELD.y - 70.0), int(36 * sq.x), col)
	if (state == State.INTRO or state == State.READY) and catches == 0:
		UI.draw_text(self, S.t("mg.coaster_flip.goal"), Vector2(FIELD.x * 0.5, FIELD.y - 26.0), 24, UI.SMOKE)
	if not ghost.is_empty() and (state == State.INTRO or state == State.READY) and flights == 0:
		UI.draw_text(self, S.t("mg.coaster_flip.ghost"), Vector2(FIELD.x * 0.5, TABLE_Y + 110.0), 22, Color(0.75, 0.9, 1.0, 0.8))


## A finger swiping up over the stack, looping: the gesture shown, not described.
func _draw_swipe_hand() -> void:
	var cyc := fmod(_anim_t, 1.2) / 1.2
	var a := clampf(sin(cyc * PI) * 1.4, 0.0, 1.0)
	var from := Vector2(STACK_X + 70.0, TABLE_Y + 40.0)
	var to := Vector2(STACK_X + 70.0, TABLE_Y - 210.0)
	var at := from.lerp(to, ease(cyc, 0.6))
	draw_line(from, at, Color(UI.CREAM, 0.35 * a), 10.0, true)
	draw_circle(at, 18.0, Color(UI.CREAM, 0.9 * a))
	draw_circle(at, 26.0, Color(UI.CREAM, 0.25 * a), false, 3.0, true)
	var tip := to + Vector2(0, -20.0)
	draw_line(tip, tip + Vector2(-22, 26), Color(UI.GOLD, 0.8), 6.0, true)
	draw_line(tip, tip + Vector2(22, 26), Color(UI.GOLD, 0.8), 6.0, true)
	draw_line(tip, tip + Vector2(0, 70), Color(UI.GOLD, 0.8), 6.0, true)


## Additive halos on their own layer (Fx.glow_material): the ring when it lights.
func _draw_glows() -> void:
	if not _art.has("ring"):
		return
	var lit := state == State.FLIGHT and ring_lit()
	var a := 0.95 if lit else 0.12 + 0.06 * sin(_anim_t * 3.0)
	_glow_layer.draw_set_transform_matrix(_xf())
	_blit(_glow_layer, "ring", 0, ring_now, Vector2.ONE * SPR_RING, Color(1, 1, 1, a), true)
	_glow_layer.draw_set_transform_matrix(Transform2D.IDENTITY)


## Drawing never creates the overlay (no tree changes inside _draw).
func _fx_ok() -> bool:
	return _fx != null and is_instance_valid(_fx)


func _text_right(text: String, pos: Vector2, size_px: int, col: Color) -> void:
	var theme := ThemeDB.get_project_theme()
	var font: Font = theme.default_font if theme != null and theme.default_font != null else ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string_outline(font, pos - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 6, Color(0, 0, 0, 0.7))
	draw_string(font, pos - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
