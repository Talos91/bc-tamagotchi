extends "res://scripts/minigames/minigame_base.gd"
## Neon Moth (docs/design/10-minigame-next.md concept D; owner item 35, DECISIONS 2026-11-15). On the lounge game
## cabinet: a moth flies the length of the lounge to the BLACK CABIN neon. One tap = one flutter (an upward kick),
## gravity does the rest. Slip through the gaps between the hanging bulb strings and the speaker stacks: GATES gates in
## a fixed flight, then the sign. A bump singes a wing (1.2 s blink, back to mid-lane); 3 singes end the flight.
## Original to Black Cabin: a moth, bulbs and amps, the venue palette; nothing taken from any existing game.
## Score = 0.8 x gates passed / GATES + 0.2 for reaching the sign. config.seed: the gap layout (default: the Bangkok
## date, so everyone flies the same lounge each night). Feeds action "neon_moth" (Nightlife 10-20, unchanged).
##
## Quality pass Q4 (docs/design/11-minigame-quality.md; DECISIONS 2026-11-18 "needs to be faster and more complex",
## several gates on screen): voxel sprites from game/assets/minigames/neon_moth/ (look B), every §2.3 beat through the
## juice kit mg_fx, a §3 ramp (faster scroll, closer gates, tighter and taller-stepping gaps, bobbing gaps from gate
## MOVE_FROM on, the last TIGHT_LAST gates tight) and §4.1 competition through mg_rivals (tonight's regular to beat
## shown in play, your best run tonight as a ghost moth, the board line on the result card).

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Rivals = preload("res://scripts/minigames/mg_rivals.gd")

const ART_DIR := "res://assets/minigames/neon_moth/"

# Field coordinates: 600 x 1000, y down; drawn scaled to fit the play area.
const FIELD := Vector2(600, 1000)
const MOTH_X := 170.0
const MOTH_R := 20.0
const GRAVITY := 1800.0
const FLAP_SPEED := 620.0
const MAX_FALL := 900.0
const GATES := 20
const START_X := 640.0               ## first gate's left edge at the start
const GATE_W := 90.0
const GAP_MIN_Y := 280.0             ## gap centre range
const GAP_MAX_Y := 720.0
const SINGES := 3
const BLINK_SECONDS := 1.2
const INTRO_SECONDS := 1.2
const SIGN_BONUS := 0.2
const SIGN_AFTER := 340.0            ## from the last gate's left edge to the sign
const BKK_OFFSET := 7 * 3600

# §3 ramp (normal): first gates a warm-up, the middle teaches, the last third tests. Starting values, tuned by the bot.
const SPEED_START := 200.0           ## lounge scroll, field px per second, at the first gate ...
const SPEED_END := 250.0             ## ... and at the sign
const SPEED_RELAXED_CAP := 225.0
const SPACING_START := 390.0         ## gate to gate (left edges): 2-3 gates on screen
const SPACING_END := 290.0
const GAP_START := 340.0             ## gap height at gate 0 ...
const GAP_END := 262.0               ## ... at the last gate before the tight run
const GAP_TIGHT := 250.0             ## the last TIGHT_LAST gates
const TIGHT_LAST := 3
const GAP_RELAXED_PLUS := 60.0       ## accessibility "relaxed timing": every gap this much taller
const STEP_START := 200.0            ## most a gap centre moves from one gate to the next ...
const STEP_END := 320.0
const MOVE_FROM := 7                 ## gates from here on may bob up and down
const MOVE_CHANCE := 0.45
const MOVE_AMP := 45.0
const MOVE_PERIOD := 2.4
const COMBO_EVERY := 3               ## clean gates in a row that make a combo beat
const GHOST_STEP := 24.0             ## ghost: the moth's height every this many px of flight

# Kept for older callers (tests, the lab): the ramp's ends.
const GAP := GAP_START
const GAP_MAX_STEP := STEP_END

# Sprite scales (field px per sprite px): the batten and the cabinets are GATE_W wide.
const SPR_GATE := GATE_W / 124.0
const SPR_CAB := GATE_W / 112.0
const SPR_MOTH := 0.8
const SPR_SIGN := 0.7
const SPR_WING := 1.2

enum State { INTRO, FLYING, DONE }

var state := State.INTRO
var y := FIELD.y * 0.5
var vy := 0.0
var scroll := 0.0
var gap_y: Array[float] = []         ## gap centres at rest
var gate_off: Array[float] = []      ## gate left edges along the flight (gate_x = START_X + gate_off - scroll)
var move_phase: Array[float] = []    ## < 0: still gate; else the bob's phase
var passed: Array[bool] = []
var hit: Array[bool] = []
var gates_passed := 0
var clean_run := 0
var singes_left := SINGES
var reached_sign := false
var blink := 0.0
var flap_t := 9.0
var fly_t := 0.0
var seed_used := 0
var rival: Dictionary = {}           ## tonight's regular to beat {regular, name, points}
var rival_passed := false
var ghost: Dictionary = {}           ## your best run tonight on this lounge {seed, step, ys, gates}, or {}
var ghost_ys: Array[int] = []        ## this run, recorded for the next ghost
var rivals_store: Object = null      ## tests: where mg_rivals keeps tonight's record (default Needs, else memory)
var _record: Dictionary = {}
var _state_t := 0.0
var _anim_t := 0.0
var _sign_flare := 0.0
var _art: Dictionary = {}            ## sprite name -> {tex, glow, fw, fh, frames, anchor}
var _glow_layer: Control


func _init() -> void:
	game_id = "neon_moth"
	action_id = "neon_moth"
	need_id = "nightlife"
	title_key = "mg.neon_moth.title"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # the cord tiles


func _on_start() -> void:
	state = State.INTRO
	y = FIELD.y * 0.5
	vy = 0.0
	scroll = 0.0
	gates_passed = 0
	clean_run = 0
	singes_left = SINGES
	reached_sign = false
	blink = 0.0
	flap_t = 9.0
	fly_t = 0.0
	_state_t = 0.0
	_sign_flare = 0.0
	_record = {}
	seed_used = int(config.get("seed", night_seed()))
	var c := course(seed_used)
	gap_y = c["centre"]
	gate_off = c["x"]
	move_phase = c["phase"]
	passed.clear()
	hit.clear()
	for i in GATES:
		passed.append(false)
		hit.append(false)
	var t := Rivals.tonight(game_id, rivals_store)
	rival = t["rival"]
	rival_passed = false
	var g: Dictionary = t["ghost"]
	ghost = g if int(g.get("seed", -1)) == seed_used and g.get("ys") is Array else {}
	ghost_ys.clear()
	_load_art()
	_ensure_glow_layer()
	_update_status()
	queue_redraw()


# --- Rules (static where the tests pin them) -------------------------------------------------------

## The Bangkok calendar day, so the lounge is the same for everyone each night and new tomorrow.
static func night_seed(unix := -1.0) -> int:
	var t := Time.get_unix_time_from_system() if unix < 0.0 else unix
	return int(floor((t + BKK_OFFSET) / 86400.0))


## How far into the flight gate i sits, 0 (first) .. 1 (last).
static func ramp(i: int) -> float:
	return clampf(float(i) / float(GATES - 1), 0.0, 1.0)


## Gap height of gate i (normal); relaxed adds GAP_RELAXED_PLUS.
static func gap_at(i: int, is_relaxed := false) -> float:
	var g := GAP_TIGHT if i >= GATES - TIGHT_LAST else lerpf(GAP_START, GAP_END, clampf(float(i) / float(GATES - TIGHT_LAST - 1), 0.0, 1.0))
	return g + (GAP_RELAXED_PLUS if is_relaxed else 0.0)


## The whole flight for a seed: gap centres, gate positions, which gates bob. Same seed, same lounge.
static func course(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var centre: Array[float] = []
	var x: Array[float] = []
	var phase: Array[float] = []
	var prev := FIELD.y * 0.5
	var at := 0.0
	for i in GATES:
		var k := ramp(i)
		var moving := i >= MOVE_FROM and rng.randf() < MOVE_CHANCE
		var amp := MOVE_AMP if moving else 0.0
		var step := lerpf(STEP_START, STEP_END, k) - amp
		var lo := maxf(GAP_MIN_Y + amp, prev - step)
		var hi := minf(GAP_MAX_Y - amp, prev + step)
		var c := clampf(rng.randf_range(GAP_MIN_Y, GAP_MAX_Y), lo, hi)
		centre.append(c)
		phase.append(rng.randf_range(0.0, TAU) if moving else -1.0)
		x.append(at)
		at += lerpf(SPACING_START, SPACING_END, k)
		prev = c
	return {"centre": centre, "x": x, "phase": phase}


## Gap centres at rest (older callers and tests).
static func layout(seed_value: int) -> Array[float]:
	return course(seed_value)["centre"]


static func score_for(gates: int, sign: bool) -> float:
	return clampf((1.0 - SIGN_BONUS) * float(gates) / GATES + (SIGN_BONUS if sign else 0.0), 0.0, 1.0)


func current_score() -> float:
	return score_for(gates_passed, reached_sign)


## Gap height of gate i for this flight (relaxed included).
func gap_size(i := 0) -> float:
	return gap_at(i, relaxed)


## Where gate i's gap centre is right now (bobbing gates move with the flight clock).
func gap_center(i: int) -> float:
	if i >= GATES:
		return FIELD.y * 0.5
	if move_phase[i] < 0.0:
		return gap_y[i]
	return gap_y[i] + MOVE_AMP * sin(TAU * fly_t / MOVE_PERIOD + move_phase[i])


func is_moving(i: int) -> bool:
	return i < GATES and move_phase[i] >= 0.0


## Scroll speed now: SPEED_START -> SPEED_END along the flight; relaxed is capped.
func speed() -> float:
	var v := lerpf(SPEED_START, SPEED_END, clampf(scroll / maxf(1.0, course_length()), 0.0, 1.0))
	return minf(v, SPEED_RELAXED_CAP) if relaxed else v


func course_length() -> float:
	return START_X + gate_off[GATES - 1] + SIGN_AFTER - MOTH_X


## Left edge of gate i on screen (field x) right now.
func gate_x(i: int) -> float:
	return START_X + gate_off[i] - scroll


func sign_x() -> float:
	return START_X + gate_off[GATES - 1] + SIGN_AFTER - scroll


## The first gate the moth has not cleared yet (GATES when all are behind it).
func next_gate() -> int:
	for i in GATES:
		if gate_x(i) + GATE_W >= MOTH_X - MOTH_R:
			return i
	return GATES


## Gates on screen right now (the "several on screen" check).
func gates_on_screen() -> int:
	var n := 0
	for i in GATES:
		var gx := gate_x(i)
		if gx < FIELD.x and gx + GATE_W > 0.0:
			n += 1
	return n


func live_points() -> int:
	return points_for(current_score())


# --- Play ------------------------------------------------------------------------------------------

func flap() -> void:
	if not running or paused or state == State.DONE:
		return
	if state == State.INTRO:
		state = State.FLYING
		_state_t = 0.0
	vy = -FLAP_SPEED
	flap_t = 0.0
	# §2.3 tap: wing snap + ember puff
	var f := fx()
	f.squash("moth")
	f.burst("ember", _xf() * Vector2(MOTH_X - 18.0, y + 8.0), 3)


func advance(dt: float) -> void:
	_state_t += dt
	flap_t += dt
	_anim_t += dt
	_sign_flare = maxf(0.0, _sign_flare - dt)
	match state:
		State.INTRO:
			y = FIELD.y * 0.5 + sin(_state_t * 4.0) * 12.0  # hovering, waiting for the first tap
			if _state_t >= INTRO_SECONDS:
				state = State.FLYING
				_state_t = 0.0
		State.FLYING:
			_fly(dt)
	queue_redraw()
	if _glow_layer != null:
		_glow_layer.queue_redraw()


func _fly(dt: float) -> void:
	fly_t += dt
	scroll += speed() * dt
	vy = minf(vy + GRAVITY * dt, MAX_FALL)
	y += vy * dt
	blink = maxf(0.0, blink - dt)
	while float(ghost_ys.size()) * GHOST_STEP <= scroll:
		ghost_ys.append(roundi(y))
	for i in GATES:
		var gx := gate_x(i)
		if gx > MOTH_X + MOTH_R + 4.0:
			break  # gates are in order: nothing further can be passed or touched yet
		var g := gap_size(i)
		var c := gap_center(i)
		if not passed[i] and gx + GATE_W < MOTH_X - MOTH_R:
			passed[i] = true
			if not hit[i]:
				gates_passed += 1
				_update_status()
				_juice_gate(i)
		if blink <= 0.0 and not hit[i] and MOTH_X + MOTH_R > gx and MOTH_X - MOTH_R < gx + GATE_W:
			if y - MOTH_R < c - g * 0.5 or y + MOTH_R > c + g * 0.5:
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
		_juice_sign()
		_end()


func _singe() -> void:
	singes_left -= 1
	clean_run = 0
	haptic("fail")
	# §2.3 singe: shake, ember burst, red edge, the wing icon breaks
	var f := fx()
	f.shake(Fx.TRAUMA_LOSS if singes_left <= 0 else Fx.TRAUMA_BUMP)
	f.fail_edge()
	f.combo_break()
	f.hit_stop()
	f.burst("ember", _xf() * Vector2(MOTH_X, y))
	var wing := maxi(0, singes_left)
	f.squash("wing%d" % wing)
	f.burst("spark", _xf() * wing_icon_pos(wing), 6)
	_update_status()
	if singes_left <= 0:
		_end()
		return
	blink = BLINK_SECONDS
	y = FIELD.y * 0.5
	vy = 0.0


## §2.3 gate passed: "+1", a gold flash in the gap, sparks, a tick; every COMBO_EVERY clean gates a combo beat.
func _juice_gate(i: int) -> void:
	var f := fx()
	var at := _xf() * Vector2(gate_x(i) + GATE_W * 0.5, gap_center(i))
	f.pop("+1", at + Vector2(0, -20))
	f.flare(at, 90.0)
	f.flash("gate%d" % i)
	f.burst("spark", at, 8)
	clean_run += 1
	f.combo_step("", Vector2(size.x * 0.5, size.y * 0.16))
	if clean_run % COMBO_EVERY == 0:
		f.flare(at, 160.0, UI.AMBER)
		f.burst("confetti", at, 10)
		haptic("strong")
	else:
		haptic("tick")
	# §4.1: passing tonight's regular in play
	if not rival_passed and not rival.is_empty() and live_points() > int(rival.get("points", 0)):
		rival_passed = true
		f.pop(S.t("mg.rivals.passed", {"regular": str(rival.get("name", ""))}), _xf() * Vector2(FIELD.x * 0.5, 190.0), UI.NEON, 44)


## §2.3 sign reached: the neon flares, confetti.
func _juice_sign() -> void:
	var f := fx()
	var c := _xf() * sign_center()
	_sign_flare = 1.0
	f.flare(c, 320.0, UI.NEON)
	f.burst("confetti", c)
	f.burst("confetti", _xf() * Vector2(MOTH_X, y))
	haptic("strong")


func _end() -> void:
	state = State.DONE
	queue_redraw()
	finish(current_score())


## The run that just ended, as tonight's ghost (only kept if it is your best tonight).
func ghost_data() -> Dictionary:
	return {"seed": seed_used, "step": GHOST_STEP, "ys": ghost_ys.duplicate(), "gates": gates_passed}


func _result_extra() -> Dictionary:
	if _record.is_empty():
		_record = Rivals.record(game_id, live_points(), ghost_data(), rivals_store)
	return {"gates": gates_passed, "sign": reached_sign, "seed": seed_used, "rival": rival, "board": _record["board_line"]}


func _update_status() -> void:
	set_status(S.t("mg.neon_moth.status", {"gates": gates_passed, "total": GATES, "wings": singes_left}))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		flap()


## The ghost moth's height at a point of the flight (NAN when the ghost run had ended there).
func ghost_y_at(at_scroll: float) -> float:
	var ys: Array = ghost.get("ys", [])
	var step := float(ghost.get("step", GHOST_STEP))
	if ys.is_empty() or step <= 0.0:
		return NAN
	var f := at_scroll / step
	var i := int(f)
	if i >= ys.size() - 1:
		return NAN
	return lerpf(float(ys[i]), float(ys[i + 1]), f - float(i))


# --- Art -------------------------------------------------------------------------------------------

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
		var m: Dictionary = sprites[name]
		var path: String = ART_DIR + str(m.get("file", ""))
		if not ResourceLoader.exists(path):
			continue
		var a: Array = m.get("anchor_px", [0, 0])
		var e := {"tex": load(path), "glow": null, "fw": float(m["frame_w"]), "fh": float(m["frame_h"]),
			"frames": int(m.get("frames", 1)), "anchor": Vector2(float(a[0]), float(a[1])), "step": float(m.get("stack_step_px", 0.0))}
		if m.has("glow_file") and ResourceLoader.exists(ART_DIR + str(m["glow_file"])):
			e["glow"] = load(ART_DIR + str(m["glow_file"]))
		_art[name] = e


## Sprites the game draws with (the tests check them; the flat drawing is only a fallback when art is missing).
func has_art() -> bool:
	for n in ["moth", "moth_singe", "wing_icon", "bulb_drop", "cord", "batten", "speaker_cab", "neon_sign", "backdrop"]:
		if not _art.has(n):
			return false
	return true


func _blit(ci: CanvasItem, name: String, frame: int, pos: Vector2, sc: float, col := Color.WHITE, glow := false) -> void:
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


func wing_icon_pos(k: int) -> Vector2:
	return Vector2(40 + k * 50, 44)


func sign_center() -> Vector2:
	return Vector2(sign_x() + 150.0, FIELD.y * 0.5)


## Field x range on screen: the whole play area, so landscape shows the room past the 600-wide field.
func _view_x() -> Vector2:
	var xf := _xf()
	var k := xf.get_scale().x
	if k <= 0.0:
		return Vector2(0.0, FIELD.x)
	return Vector2(-xf.origin.x / k, (size.x - xf.origin.x) / k)


func _flight_progress() -> float:
	return clampf(scroll / maxf(1.0, course_length()), 0.0, 1.0)


func _draw() -> void:
	if size.x <= 0.0 or gap_y.is_empty():
		return
	if _glow_layer != null:
		_glow_layer.size = size
	# the lounge toward the neon, blurred: covers the whole play area and pans slowly with the flight
	if _art.has("backdrop"):
		var b: Dictionary = _art["backdrop"]
		var cover: float = maxf(size.x / b["fw"], size.y / b["fh"]) * 1.12
		var w: float = b["fw"] * cover
		var h: float = b["fh"] * cover
		draw_texture_rect(b["tex"], Rect2(Vector2((size.x - w) * _flight_progress(), (size.y - h) * 0.5), Vector2(w, h)), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("1A0A0C"))
	var xf := _xf()
	var vx := _view_x()
	draw_set_transform_matrix(xf)
	for i in GATES:
		var gx := gate_x(i)
		if gx > vx.y + 20.0 or gx + GATE_W < vx.x - 20.0:
			continue
		_draw_gate(i, gx)
	# the BLACK CABIN neon at the end of the room
	if sign_x() < vx.y + 40.0:
		if _art.has("neon_sign"):
			var sc := sign_center()
			_blit(self, "neon_sign", 0, Vector2(sc.x, sc.y + 95.0), SPR_SIGN)
		else:
			var sx := sign_x()
			draw_rect(Rect2(sx, 380, 260, 120), UI.NEON, false, 6.0)
			UI.draw_text(self, "BLACK CABIN", Vector2(sx + 130, 450), 40, UI.NEON)
	_draw_ghost()
	_draw_moth(Vector2(MOTH_X, y))
	_draw_hud()
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_gate(i: int, gx: float) -> void:
	var g := gap_size(i)
	var c := gap_center(i)
	var top := c - g * 0.5
	var bot := c + g * 0.5
	var cx := gx + GATE_W * 0.5
	var lit := 1 if hit[i] else 0
	var tint := _fx.flash_color("gate%d" % i, Color.WHITE) if _fx_ok() else Color.WHITE
	if not has_art():
		draw_rect(Rect2(gx, 0, GATE_W, top), Color("3A2218"))
		draw_rect(Rect2(gx, bot, GATE_W, FIELD.y - bot), Color("231212"))
		return
	# top: two bulb drops whose bottoms are the top of the gap, the batten above them, cords up to the ceiling
	var drop: Dictionary = _art["bulb_drop"]
	var drop_top: float = top - (drop["fh"] - drop["anchor"].y) * SPR_GATE
	var batten_top: float = drop_top - 10.0
	var cord: Dictionary = _art["cord"]
	for dx in [-28.0, 28.0]:
		if batten_top > 0.0:
			draw_texture_rect(cord["tex"], Rect2(cx + dx - 3.0, 0.0, 6.0, batten_top), true)
	_blit(self, "batten", 0, Vector2(cx, drop_top + 4.0), SPR_GATE, tint)
	for dx in [-21.0, 21.0]:
		_blit(self, "bulb_drop", lit, Vector2(cx + dx, drop_top), SPR_GATE, tint)
	# bottom: speaker cabinets from the gap down past the floor; the top one is the horn
	var cab: Dictionary = _art["speaker_cab"]
	var ay: float = cab["anchor"].y * SPR_CAB
	var stepy: float = cab["step"] * SPR_CAB
	var k := 0
	while bot + k * stepy < FIELD.y + 10.0 and k < 12:
		_blit(self, "speaker_cab", 1 if k == 0 else 0, Vector2(cx, bot + ay + k * stepy), SPR_CAB, tint)
		k += 1


## Additive halos on their own layer (Fx.glow_material): lit bulbs and the neon sign.
func _draw_glows() -> void:
	if not has_art() or gap_y.is_empty():
		return
	_glow_layer.draw_set_transform_matrix(_xf())
	var pulse := 0.75 + 0.25 * sin(_anim_t * 3.0)
	var vx := _view_x()
	for i in GATES:
		var gx := gate_x(i)
		if hit[i] or gx > vx.y + 20.0 or gx + GATE_W < vx.x - 20.0:
			continue
		var top := gap_center(i) - gap_size(i) * 0.5
		var drop: Dictionary = _art["bulb_drop"]
		var drop_top: float = top - (drop["fh"] - drop["anchor"].y) * SPR_GATE
		for dx in [-21.0, 21.0]:
			_blit(_glow_layer, "bulb_drop", 0, Vector2(gx + GATE_W * 0.5 + dx, drop_top), SPR_GATE, Color(1, 1, 1, 0.8 * pulse), true)
	if sign_x() < vx.y + 40.0:
		var sc := sign_center()
		var a := clampf(0.7 + 0.2 * sin(_anim_t * 5.0) + _sign_flare, 0.0, 1.6)
		_blit(_glow_layer, "neon_sign", 0, Vector2(sc.x, sc.y + 95.0), SPR_SIGN, Color(1, 1, 1, minf(1.0, a)), true)
		if a > 1.0:
			_blit(_glow_layer, "neon_sign", 0, Vector2(sc.x, sc.y + 95.0), SPR_SIGN, Color(1, 1, 1, a - 1.0), true)
	_glow_layer.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_ghost() -> void:
	if ghost.is_empty() or state == State.INTRO:
		return
	var gy := ghost_y_at(scroll)
	if is_nan(gy):
		return
	_draw_moth_sprite(Vector2(MOTH_X, gy), "moth", int(_anim_t * 10.0) % 4, 0.0, Color(0.75, 0.9, 1.0, 0.35), Vector2.ONE)


func _draw_moth(c: Vector2) -> void:
	if blink > 0.0 and int(blink * 10.0) % 2 == 0:
		return
	var tilt := clampf(vy / MAX_FALL, -0.6, 0.8) * 0.45
	var sq := _fx.squash_scale("moth") if _fx_ok() else Vector2.ONE
	if not has_art():
		draw_circle(c, MOTH_R, Color("D9C4A8"))
		return
	if blink > 0.0 or (state == State.DONE and singes_left <= 0):
		_draw_moth_sprite(c, "moth_singe", int(_anim_t * 8.0) % 2, tilt, Color.WHITE, sq)
		return
	# one tap plays the flap 0-1-2-3 once; gliding, the wings beat slowly
	var frame := int(flap_t * 14.0) if flap_t < 4.0 / 14.0 else int(_anim_t * 6.0) % 4
	_draw_moth_sprite(c, "moth", frame, tilt, Color.WHITE, sq)


func _draw_moth_sprite(c: Vector2, name: String, frame: int, tilt: float, col: Color, sq: Vector2) -> void:
	# the sheet faces up; a quarter turn clockwise faces the flight, tilted with the vertical speed
	var xf := _xf() * Transform2D(PI * 0.5 + tilt, Vector2(SPR_MOTH * sq.y, SPR_MOTH * sq.x), 0.0, c)
	draw_set_transform_matrix(xf)
	_blit(self, name, frame, Vector2.ZERO, 1.0, col)
	draw_set_transform_matrix(_xf())


func _draw_hud() -> void:
	# wings left: one icon per singe left, broken ones stay as a reminder
	for k in SINGES:
		var p := wing_icon_pos(k)
		var sq := _fx.squash_scale("wing%d" % k) if _fx_ok() else Vector2.ONE
		if _art.has("wing_icon"):
			draw_set_transform_matrix(_xf() * Transform2D(0.0, sq * SPR_WING, 0.0, p))
			_blit(self, "wing_icon", 0 if k < singes_left else 1, Vector2.ZERO, 1.0)
			draw_set_transform_matrix(_xf())
		else:
			draw_circle(p, 14.0, UI.CREAM if k < singes_left else UI.LINE)
	# tonight's regular to beat, and you
	if not rival.is_empty():
		var col := UI.GOLD if rival_passed else UI.CREAM
		_text_right(S.t("mg.rivals.to_beat"), Vector2(FIELD.x - 20.0, 34.0), 20, UI.SMOKE)
		_text_right("%s %d" % [str(rival.get("name", "")), int(rival.get("points", 0))], Vector2(FIELD.x - 20.0, 66.0), 30, col)
		_text_right(S.t("mg.rivals.you_now", {"score": live_points()}), Vector2(FIELD.x - 20.0, 96.0), 24, UI.GOLD if rival_passed else UI.SMOKE)
	if state == State.INTRO:
		UI.draw_text(self, S.t("mg.neon_moth.hint"), Vector2(FIELD.x * 0.5, FIELD.y - 90), 34, UI.SMOKE)
		if not ghost.is_empty():
			UI.draw_text(self, S.t("mg.rivals.ghost"), Vector2(FIELD.x * 0.5, FIELD.y - 50), 24, Color(0.75, 0.9, 1.0, 0.8))


## Drawing never creates the overlay (no tree changes inside _draw).
func _fx_ok() -> bool:
	return _fx != null and is_instance_valid(_fx)


func _text_right(text: String, pos: Vector2, size_px: int, col: Color) -> void:
	var theme := ThemeDB.get_project_theme()
	var font: Font = theme.default_font if theme != null and theme.default_font != null else ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string_outline(font, pos - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 6, Color(0, 0, 0, 0.7))
	draw_string(font, pos - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
