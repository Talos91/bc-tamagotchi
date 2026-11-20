extends "res://scripts/minigames/minigame_base.gd"
## Neon Pinball (GDD section 9 #10; DECISIONS: runs on the lounge arcade cabinet's screen). A simplified
## pinball with its own small physics. Controls: hold the left / right half of the screen for that
## flipper, swipe up on the right third to launch (a tap also launches), swipe sideways to nudge the ball
## (tilt: nudge too often and the flippers go dead for a moment). Light all ten letters of BLACK CABIN for a bonus.
## Feeds action "pinball" (Nightlife +10-20).
## Endless ramp (docs/design/15-minigame-ramp.md; Daniele 2026-11-20): no time cap. 3 balls; the last ball drained =
## lose(). The level rises by 1 each time BLACK CABIN is spelled (the letters then go dark to be spelled again) and
## every 60 s of play, up to LEVEL_CAP: gravity +100 a step (cap 2100), ball save -1 s a step (cap 4 s; relaxed +5 s),
## word bonus 1500 x level. The ball save works once per ball, and a ball left in the lane launches itself after
## LANE_AUTO_LAUNCH s, so an idle player still loses. Record points = pinball points / 30 (3000 = 100), uncapped; the
## cabinet screen keeps the raw pinball points.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Rivals = preload("res://scripts/minigames/mg_rivals.gd")

# Field coordinates: 600 x 1000, y down. Playfield x 0..540, launch lane x 540..600.
const FIELD := Vector2(600, 1000)
const BALL_R := 13.0
const GRAVITY := 1500.0             ## level 1 gravity (today's table)
const RAMP_GRAVITY_STEP := 100.0    ## why: +100 a level = a steeper table, still slower than a real one at the cap
const GRAVITY_CAP := 2100.0         ## why: +40 % at the top level; the flippers swing in 0.05 s, so still playable
const LEVEL_CAP := 7                ## why: today's numbers + 6 steps (gravity 2100, ball save 4 s)
const RAMP_LEVEL_SECONDS := 60.0    ## why: a long ball also climbs, not only spelling the word
const MAX_SPEED := 2300.0
const SUBSTEP := 1.0 / 480.0
const BALLS := 3
const BALL_SAVE_SECONDS := 10.0     ## level 1 ball save
const RAMP_SAVE_STEP := 1.0         ## why: -1 s a level, the table gets less forgiving
const BALL_SAVE_MIN := 4.0          ## why: 4 s still covers a straight drain off the launch
const LANE_AUTO_LAUNCH := 8.0       ## why: without the time cap an idle player must still reach the loss rule
const LAUNCH_SPEED_MIN := 1750.0
const LAUNCH_SPEED_MAX := 2300.0
const LANE_X := 570.0
const LANE_REST_Y := 940.0
const FULL_POINTS := 3000.0  # pinball points that map to score 1.0 (= 100 record points)
const RECORD_DIVISOR := 30.0  ## why: record points = pinball points / 30, so 3000 = 100 as before; uncapped
const BUMPER_POINTS := 100
const LETTER_POINTS := 250
const WORD_BONUS := 1500  # x the level the word is spelled at
const LETTERS := "BLACKCABIN"
const NUDGE_SPEED := 260.0
const NUDGE_TILT := 0.4
const TILT_LIMIT := 1.0
const TILT_DECAY := 0.25
const TILT_LOCK_SECONDS := 2.5
const FLIPPER_LEN := 108.0
const FLIPPER_THICK := 10.0
const FLIPPER_SPEED := 20.0  # rad/s
const FLIPPER_REST := 0.52  # radians below horizontal
const FLIPPER_UP := -0.45
const BUMPERS: Array[Vector3] = [Vector3(170, 340, 38), Vector3(370, 340, 38), Vector3(270, 470, 38)]
const SENSOR_R := 24.0
## Look B sprites (game/assets/minigames/README.md, Neon Pinball): art px per field unit 1.3 (780 px wide play area).
const ASSET_DIR := "res://assets/minigames/neon_pinball/"
const ART_PPU := 1.3
const BEZEL := Vector2(36, 28)
const BUMPER_ANCHOR := Vector2(74.0, 76.7)
const BALL_ANCHOR := Vector2(18.0, 20.0)
const FLIPPER_ANCHOR := Vector2(26.0, 26.0)
const LETTER_ANCHOR := Vector2(44.0, 49.0)
const TRAIL_LEN := 9
const TRAIL_MIN_SPEED := 500.0
const BUMPER_HIT_STOP := 0.04
## Relaxed timing (11-minigame-quality section 3): ball save +5 s at every level, tilt limit +1.
const RELAXED_SAVE_EXTRA := 5.0
const RELAXED_TILT_EXTRA := 1.0

enum Ball { LANE, LIVE, GONE }

var walls: Array = []  # [Vector2 a, Vector2 b]
var letter_pos: Array[Vector2] = []
var lit: Array[bool] = []
var points := 0
var balls_left := BALLS
var ball_state := Ball.LANE
var pos := Vector2(LANE_X, LANE_REST_Y)
var vel := Vector2.ZERO
var play_time := 0.0
var ball_time := 0.0
var tilt := 0.0
var tilt_lock := 0.0
var flip_held := [false, false]
var flip_angle := [FLIPPER_REST, FLIPPER_REST]
var bumper_flash: Array[float] = [0.0, 0.0, 0.0]
var word_done := false  # BLACK CABIN spelled at least once this round
var words := 0  # times BLACK CABIN was spelled this round
var _level_t := 0.0  # play seconds towards the next time level
var _lane_t := 0.0  # seconds the ball has waited in the lane
var _save_used := false  # the ball save works once per ball
var toast := ""
var _toast_t := 0.0
var _press_pos := Vector2.ZERO
var _press_t := 0.0
var _pressing := false
var _scale := 1.0
var _origin := Vector2.ZERO
var _tex := {}
var _trail: Array[Vector2] = []
var _glow: Control
## §4.1 competition (no ghost: a pinball run is physics and chance, there is no run to replay).
var rival: Dictionary = {}           ## tonight's regular to beat {regular, name, points}
var rival_passed := false
var rivals_store: Object = null      ## tests: where mg_rivals keeps tonight's record (default Needs, else memory)
var _record: Dictionary = {}


func _init() -> void:
	game_id = "neon_pinball"
	action_id = "pinball"
	need_id = "nightlife"
	title_key = "mg.neon_pinball.title"
	_build_field()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_glow = Control.new()
	_glow.name = "Glow"
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw.connect(_draw_glow)
	add_child(_glow)


func _build_field() -> void:
	walls.clear()
	# Top arc, centre (270, 300) radius 270 over the playfield; lane exit continues into the same arc.
	var arc_c := Vector2(300, 300)
	var prev := Vector2(0, 300)
	for i in range(1, 33):
		var a := PI + PI * i / 32.0
		var p := arc_c + Vector2(cos(a), sin(a)) * 300.0
		walls.append([prev, p])
		prev = p
	walls.append([Vector2(0, 300), Vector2(0, 780)])
	walls.append([Vector2(0, 780), Vector2(150, 880)])
	walls.append([Vector2(540, 780), Vector2(390, 880)])
	walls.append([Vector2(540, 780), Vector2(540, 340)])  # lane inner wall
	walls.append([Vector2(600, 300), Vector2(600, 975)])  # outer right wall
	walls.append([Vector2(540, 975), Vector2(600, 975)])  # lane floor
	# Slingshot-ish deflectors above the flippers.
	walls.append([Vector2(60, 640), Vector2(130, 740)])
	walls.append([Vector2(480, 640), Vector2(410, 740)])
	letter_pos.clear()
	lit.clear()
	for i in 5:
		letter_pos.append(Vector2(110 + i * 80, 190))
	for i in 5:
		letter_pos.append(Vector2(110 + i * 80, 580))
	for i in 10:
		lit.append(false)


# --- Scoring ---------------------------------------------------------------------------------------

static func score_from(pts: int) -> float:
	return clampf(float(pts) / FULL_POINTS, 0.0, 1.0)


## Record points (best, board, rivals): pinball points / 30, uncapped.
static func record_of(pts: int) -> int:
	return floori(float(pts) / RECORD_DIVISOR)


func record_points() -> int:
	return record_of(points)


func current_score() -> float:
	return score_of(record_points())


func live_points() -> int:
	return record_points()


# --- Ramp (static: the tests pin these) ---------------------------------------------------------------

static func gravity_at(lv: int) -> float:
	return minf(GRAVITY + RAMP_GRAVITY_STEP * float(clampi(lv, 1, LEVEL_CAP) - 1), GRAVITY_CAP)


static func ball_save_at(lv: int, relaxed_on := false) -> float:
	var s := maxf(BALL_SAVE_MIN, BALL_SAVE_SECONDS - RAMP_SAVE_STEP * float(clampi(lv, 1, LEVEL_CAP) - 1))
	return s + (RELAXED_SAVE_EXTRA if relaxed_on else 0.0)


static func word_bonus_at(lv: int) -> int:
	return WORD_BONUS * clampi(lv, 1, LEVEL_CAP)


func _raise_level() -> void:
	if ramp_level < LEVEL_CAP:
		level_up(ramp_level + 1)


func _on_level(_n: int) -> void:
	_update_status()


## §4.1: passing tonight's regular in play.
func _check_rival() -> void:
	if rival_passed or rival.is_empty() or live_points() <= int(rival.get("points", 0)):
		return
	rival_passed = true
	_layout()
	fx().pop(S.t("mg.rivals.passed", {"regular": str(rival.get("name", ""))}), _f(Vector2(270, 250)), UI.NEON, 44)


func _on_start() -> void:
	points = 0
	balls_left = BALLS
	play_time = 0.0
	tilt = 0.0
	tilt_lock = 0.0
	word_done = false
	words = 0
	_level_t = 0.0
	_lane_t = 0.0
	_save_used = false
	for i in lit.size():
		lit[i] = false
	flip_angle = [FLIPPER_REST, FLIPPER_REST]
	flip_held = [false, false]
	_record = {}
	rival = Rivals.tonight(game_id, rivals_store)["rival"]
	rival_passed = false
	_serve()
	_update_status()


func _serve() -> void:
	ball_state = Ball.LANE
	pos = Vector2(LANE_X, LANE_REST_Y)
	vel = Vector2.ZERO
	ball_time = 0.0
	_lane_t = 0.0
	_trail.clear()


## Relaxed timing widens the ball save and the tilt limit; it never changes the payout.
func ball_save_seconds() -> float:
	return ball_save_at(ramp_level, relaxed)


func tilt_limit() -> float:
	return TILT_LIMIT + (RELAXED_TILT_EXTRA if relaxed else 0.0)


func launch(power := 0.85) -> void:
	if ball_state != Ball.LANE or not running or paused:
		return
	ball_state = Ball.LIVE
	ball_time = 0.0
	vel = Vector2(0, -lerpf(LAUNCH_SPEED_MIN, LAUNCH_SPEED_MAX, clampf(power, 0.0, 1.0)))
	_layout()
	fx().burst("spark", _f(Vector2(LANE_X, LANE_REST_Y)), 8)
	haptic("tick")


func nudge(dir: int) -> void:
	if ball_state != Ball.LIVE or tilt_lock > 0.0:
		return
	vel.x += dir * NUDGE_SPEED
	tilt += NUDGE_TILT
	if tilt >= tilt_limit():
		tilt_lock = TILT_LOCK_SECONDS
		tilt = 0.6
		flip_held = [false, false]
		_say(S.t("mg.neon_pinball.tilt"))
		fx().fail_edge()
		haptic("fail")


func set_flipper(side: int, held: bool) -> void:
	flip_held[side] = held and tilt_lock <= 0.0


func _say(text: String) -> void:
	toast = text
	_toast_t = 1.6


# --- Physics ---------------------------------------------------------------------------------------

func advance(dt: float) -> void:
	play_time += dt
	_level_t += dt
	while _level_t >= RAMP_LEVEL_SECONDS:
		_level_t -= RAMP_LEVEL_SECONDS
		_raise_level()
	if ball_state == Ball.LANE:
		_lane_t += dt
		if _lane_t >= LANE_AUTO_LAUNCH:
			launch(0.85)
	_toast_t = maxf(0.0, _toast_t - dt)
	tilt = maxf(0.0, tilt - TILT_DECAY * dt)
	tilt_lock = maxf(0.0, tilt_lock - dt)
	for i in 3:
		bumper_flash[i] = maxf(0.0, bumper_flash[i] - dt * 4.0)
	var n := maxi(1, int(ceil(dt / SUBSTEP)))
	var h := dt / n
	for _i in n:
		_step(h)
		if done:
			return
	_check_rival()
	if ball_state == Ball.LIVE and vel.length() > TRAIL_MIN_SPEED:
		_trail.append(pos)
		if _trail.size() > TRAIL_LEN:
			_trail.pop_front()
	elif not _trail.is_empty():
		_trail.pop_front()
	queue_redraw()


func flipper_dir(side: int) -> Vector2:
	var a: float = flip_angle[side]
	return Vector2(cos(a), sin(a)) if side == 0 else Vector2(-cos(a), sin(a))


func flipper_pivot(side: int) -> Vector2:
	return Vector2(150, 880) if side == 0 else Vector2(390, 880)


func _step(h: float) -> void:
	var old_tips := [flipper_pivot(0) + flipper_dir(0) * FLIPPER_LEN, flipper_pivot(1) + flipper_dir(1) * FLIPPER_LEN]
	for s in 2:
		var target := FLIPPER_UP if flip_held[s] else FLIPPER_REST
		flip_angle[s] = move_toward(flip_angle[s], target, FLIPPER_SPEED * h)
	if ball_state != Ball.LIVE:
		return
	ball_time += h
	vel.y += gravity_at(ramp_level) * h
	if vel.length() > MAX_SPEED:
		vel = vel.normalized() * MAX_SPEED
	pos += vel * h
	for w in walls:
		_collide_segment(w[0], w[1], 0.0, Vector2.ZERO, 0.45, 0.0)
	for s in 2:
		var p0 := flipper_pivot(s)
		var tip := p0 + flipper_dir(s) * FLIPPER_LEN
		var tip_v: Vector2 = (tip - old_tips[s]) / h
		_collide_segment(p0, tip, FLIPPER_THICK, tip_v, 0.3, 0.0)
	for i in BUMPERS.size():
		var b := BUMPERS[i]
		var c := Vector2(b.x, b.y)
		var d := pos - c
		var min_d := b.z + BALL_R
		if d.length() < min_d:
			var nrm := d.normalized() if d.length() > 0.001 else Vector2.UP
			pos = c + nrm * min_d
			vel = nrm * maxf(vel.length() * 0.9, 650.0)
			bumper_flash[i] = 1.0
			points += BUMPER_POINTS
			_bumper_beat(i, c)
			_update_status()
	for i in letter_pos.size():
		if not lit[i] and pos.distance_to(letter_pos[i]) < SENSOR_R + BALL_R * 0.5:
			lit[i] = true
			points += LETTER_POINTS
			_letter_beat(i)
			if not lit.has(false):
				_word_complete()
			_update_status()
	if pos.y > FIELD.y + 40.0 and pos.x < 540.0:
		_drain()
	elif pos.x > 540.0 and pos.y > LANE_REST_Y - 30.0 and vel.length() < 60.0:
		_serve()  # a weak launch or a ball falling back into the lane: back to the plunger, no ball lost


## BLACK CABIN spelled: the bonus at this level, the letters go dark to be spelled again, the level rises.
func _word_complete() -> void:
	word_done = true
	words += 1
	points += word_bonus_at(ramp_level)
	for j in lit.size():
		lit[j] = false
	_say(S.t("mg.neon_pinball.word"))
	_word_beat()
	_raise_level()


func _collide_segment(a: Vector2, b: Vector2, thick: float, seg_vel: Vector2, e: float, _unused: float) -> void:
	var ab := b - a
	var t := clampf((pos - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var closest := a + ab * t
	var d := pos - closest
	var min_d := BALL_R + thick
	var dist := d.length()
	if dist >= min_d:
		return
	var nrm := d / dist if dist > 0.0001 else Vector2(-ab.y, ab.x).normalized()
	pos = closest + nrm * min_d
	var surf := seg_vel * t
	var rel := vel - surf
	var vn := rel.dot(nrm)
	if vn < 0.0:
		vel -= (1.0 + e) * vn * nrm


## The §2.3 beats (all through mg_fx; positions are the game's local px).
func _bumper_beat(i: int, c: Vector2) -> void:
	_layout()
	var f := fx()
	var at := _f(c)
	f.flash("b%d" % i)
	f.squash("b%d" % i)
	f.pop("+%d" % BUMPER_POINTS, at + Vector2(0, -50.0 * _scale), UI.CYAN, 48)
	f.burst("spark", at, 8)
	f.hit_stop(BUMPER_HIT_STOP)
	haptic("tick")


func _letter_beat(i: int) -> void:
	_layout()
	var f := fx()
	var at := _f(letter_pos[i])
	f.squash("l%d" % i)
	f.pop("%s +%d" % [LETTERS[i], LETTER_POINTS], at + Vector2(0, -60.0 * _scale), UI.GOLD, 52)
	f.flare(at, 90.0 * _scale, UI.NEON)
	f.burst("spark", at, 10)
	haptic("tick")


func _word_beat() -> void:
	_layout()
	var f := fx()
	var mid := _f(Vector2(270, 400))
	f.pop(S.t("mg.neon_pinball.word"), mid, UI.NEON, 84)
	f.flare(mid, 420.0 * _scale, UI.NEON)
	f.burst("confetti", mid, 40)
	f.hit_stop()
	haptic("strong")


func _drain() -> void:
	_layout()
	var f := fx()
	var at := _f(Vector2(clampf(pos.x, 40.0, 500.0), FIELD.y - 40.0))
	if ball_time <= ball_save_seconds() and not _save_used:
		_save_used = true
		_say(S.t("mg.neon_pinball.ball_saved"))
		f.pop(S.t("mg.neon_pinball.ball_saved"), at, UI.CREAM, 52)
		_serve()
		return
	f.shake(Fx.TRAUMA_LOSS)
	f.fail_edge()
	f.burst("ember", at, 12)
	haptic("fail")
	balls_left -= 1
	if balls_left <= 0:
		ball_state = Ball.GONE
		_update_status()
		lose()
		return
	f.pop(S.t("mg.ramp.last") if balls_left == 1 else S.t("mg.ramp.strike", {"lives": balls_left}), at + Vector2(0, -70.0 * _scale), UI.AMBER, 52)
	_save_used = false
	_serve()
	_update_status()


func _update_status() -> void:
	set_status(S.t("mg.ramp.status", {"level": ramp_level, "points": record_points(), "lives": balls_left}))


func _result_extra() -> Dictionary:
	if _record.is_empty():
		_record = Rivals.record(game_id, record_points(), {}, rivals_store)
	return {"points": points, "letters": lit.count(true), "word": word_done, "words": words, "level": ramp_level,
		"speed": gravity_at(ramp_level), "misses": BALLS - balls_left, "rival": rival, "board": _record["board_line"]}


# --- Input -----------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.position
			_press_t = play_time
			if ball_state != Ball.LANE:
				set_flipper(0 if event.position.x < size.x * 0.5 else 1, true)
		else:
			if not _pressing:
				return
			_pressing = false
			var delta: Vector2 = event.position - _press_pos
			set_flipper(0, false)
			set_flipper(1, false)
			if ball_state == Ball.LANE:
				if _press_pos.x > size.x * 0.66:
					if delta.y < -120.0:
						launch(clampf(-delta.y / 700.0, 0.5, 1.0))
					elif delta.length() < 40.0:
						launch(0.85)
			elif absf(delta.x) > 90.0 and absf(delta.x) > 1.5 * absf(delta.y):
				nudge(1 if delta.x > 0.0 else -1)
	elif event is InputEventMouseMotion and _pressing and ball_state == Ball.LIVE:
		# Hold the flipper for the half the finger is in; a long sideways drag becomes a nudge on release.
		pass


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode in [KEY_A, KEY_LEFT]:
			set_flipper(0, event.pressed)
		elif event.keycode in [KEY_D, KEY_RIGHT]:
			set_flipper(1, event.pressed)
		elif event.keycode == KEY_SPACE and event.pressed:
			launch()
		elif event.keycode == KEY_Q and event.pressed:
			nudge(-1)
		elif event.keycode == KEY_E and event.pressed:
			nudge(1)


# --- Drawing ---------------------------------------------------------------------------------------

func _f(p: Vector2) -> Vector2:
	return _origin + p * _scale


func _t(file: String) -> Texture2D:
	if not _tex.has(file):
		var path := ASSET_DIR + file
		_tex[file] = load(path) if ResourceLoader.exists(path) else null
	return _tex[file]


## Sets _scale / _origin from the play area (also called by the beats, which need field -> screen positions).
func _layout() -> void:
	_scale = maxf(0.01, minf((size.x - BEZEL.x * 2.0 - 40.0) / FIELD.x, (size.y - BEZEL.y * 2.0 - 20.0) / FIELD.y))
	var fs := FIELD * _scale
	_origin = Vector2((size.x - fs.x) * 0.5, (size.y - fs.y) * 0.5)


## A sprite frame drawn so its anchor pixel sits on field point p; art px -> screen px is _scale / ART_PPU.
func _spr(file: String, frame: int, frame_w: float, anchor: Vector2, p: Vector2, mul := 1.0, tint := Color.WHITE) -> void:
	var tex := _t(file)
	if tex == null:
		return
	var k := _scale / ART_PPU * mul
	var h := tex.get_size().y
	draw_texture_rect_region(tex, Rect2(_f(p) - anchor * k, Vector2(frame_w, h) * k), Rect2(frame * frame_w, 0, frame_w, h), tint)


func _draw() -> void:
	if size.x <= 0.0:
		return
	_layout()
	var fs := FIELD * _scale
	var f := fx()
	var art := _t("playfield.png") != null
	# Cabinet: dark body, bezel line, the screen in the one cool light.
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG_DEEP)
	var screen := Rect2(_origin - Vector2(24, 24), fs + Vector2(48, 48))
	draw_rect(screen.grow(26.0), UI.BG_BASE)
	draw_rect(screen.grow(26.0), UI.LINE, false, 4.0)
	draw_rect(screen, Color("06161B"))
	if art:
		draw_texture_rect(_t("playfield.png"), Rect2(_origin, fs), false)
	else:
		for y in range(int(screen.position.y), int(screen.end.y), 8):
			draw_line(Vector2(screen.position.x, y), Vector2(screen.end.x, y), Color(UI.CYAN, 0.04), 1.0)
	draw_rect(screen, Color(UI.CYAN, 0.5), false, 3.0)
	# Walls (the physics truth; faint over the art).
	for w in walls:
		draw_line(_f(w[0]), _f(w[1]), Color(UI.SMOKE, 0.35 if art else 1.0), 5.0)
	# Bumpers.
	for i in BUMPERS.size():
		var b := BUMPERS[i]
		var c := Vector2(b.x, b.y)
		if _t("bumper.png") != null:
			var sq := f.squash_scale("b%d" % i)
			_spr("bumper.png", 1 if bumper_flash[i] > 0.35 else 0, 148.0, BUMPER_ANCHOR, c, (sq.x + sq.y) * 0.5)
		else:
			draw_circle(_f(c), b.z * _scale, Color(UI.CYAN, 0.18 + 0.6 * bumper_flash[i]))
			draw_arc(_f(c), b.z * _scale, 0, TAU, 32, UI.CYAN, 4.0, true)
	# Letters of BLACK CABIN: lit frame when lit (brand moment), off otherwise.
	for i in letter_pos.size():
		var lf := "letter_%s.png" % LETTERS[i]
		if _t(lf) != null:
			var pulse := f.squash_scale("l%d" % i).x if lit[i] else 1.0
			_spr(lf, 1 if lit[i] else 0, 88.0, LETTER_ANCHOR, letter_pos[i], pulse)
		else:
			var col: Color = UI.NEON if lit[i] else UI.ASH
			draw_arc(_f(letter_pos[i]), SENSOR_R * _scale, 0, TAU, 20, Color(col, 0.7), 3.0, true)
			UI.draw_text(self, LETTERS[i], _f(letter_pos[i]) + Vector2(0, 14), 40, col)
	# Flippers.
	for s in 2:
		var p0 := flipper_pivot(s)
		if _t("flipper.png") != null:
			var k := _scale / ART_PPU
			var a: float = flip_angle[s]
			draw_set_transform(_f(p0), a if s == 0 else -a, Vector2(k, k) if s == 0 else Vector2(-k, k))
			draw_texture_rect(_t("flipper.png"), Rect2(-FLIPPER_ANCHOR, Vector2(148, 52)), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_line(_f(p0), _f(p0 + flipper_dir(s) * FLIPPER_LEN), UI.GOLD, FLIPPER_THICK * 2.0 * _scale, true)
			draw_circle(_f(p0), FLIPPER_THICK * _scale, UI.GOLD)
	# Ball trail (fades with age) then the ball.
	for j in _trail.size():
		var u := float(j + 1) / float(_trail.size() + 1)
		draw_circle(_f(_trail[j]), BALL_R * _scale * (0.35 + 0.55 * u), Color(UI.CYAN, 0.04 + 0.26 * u))
	if _t("ball.png") != null:
		_spr("ball.png", 0, 36.0, BALL_ANCHOR, pos)
	else:
		draw_circle(_f(pos), BALL_R * _scale, UI.CREAM)
	# Score and tilt on the screen.
	UI.draw_text(self, str(points), _f(Vector2(270, 60)), 58, UI.CYAN)
	# §4.1: tonight's regular to beat, and you
	if not rival.is_empty():
		var rc := UI.GOLD if rival_passed else UI.CREAM
		_text_right(S.t("mg.rivals.to_beat"), _f(Vector2(530, 32)), 20, UI.SMOKE)
		_text_right("%s %d" % [str(rival.get("name", "")), int(rival.get("points", 0))], _f(Vector2(530, 62)), 28, rc)
		_text_right(S.t("mg.rivals.you_now", {"score": live_points()}), _f(Vector2(530, 88)), 22, UI.GOLD if rival_passed else UI.SMOKE)
	if tilt > 0.05:
		draw_rect(Rect2(_f(Vector2(20, 90)), Vector2(200 * _scale * tilt / tilt_limit(), 8)), UI.AMBER)
	if _toast_t > 0.0:
		UI.draw_text(self, toast, _f(Vector2(270, 700)), 64, UI.GOLD)
	if ball_state == Ball.LANE:
		UI.draw_text(self, S.t("mg.neon_pinball.hint_launch"), _f(Vector2(270, 780)), 40, UI.SMOKE)
	if _glow != null:
		_glow.queue_redraw()


## Neon halos: drawn on a child with an additive material, over the sprites (README, Glow).
func _draw_glow() -> void:
	if size.x <= 0.0:
		return
	_layout()
	var gt := _t("bumper_glow.png")
	var k := _scale / ART_PPU * 2.0
	for i in BUMPERS.size():
		if gt != null:
			var b := BUMPERS[i]
			var cell := Vector2(74.0, 74.0)  # a glow frame is half size: 74 x 74
			var a := 0.45 + 0.55 * bumper_flash[i]
			_glow.draw_texture_rect_region(gt, Rect2(_f(Vector2(b.x, b.y)) - BUMPER_ANCHOR * 0.5 * k, cell * k), Rect2(0, 0, 74, 74), Color(1, 1, 1, a))
	for i in letter_pos.size():
		if not lit[i]:
			continue
		var lg := _t("letter_%s_glow.png" % LETTERS[i])
		if lg != null:
			var a2 := 0.75 + 0.25 * sin(play_time * 5.0 + i)
			var cell2 := Vector2(44.0, 49.0)  # lit frame of a half-size sheet
			_glow.draw_texture_rect_region(lg, Rect2(_f(letter_pos[i]) - LETTER_ANCHOR * 0.5 * k, cell2 * k), Rect2(44, 0, 44, 49), Color(1, 1, 1, a2))


func _text_right(text: String, pos: Vector2, size_px: int, col: Color) -> void:
	var theme := ThemeDB.get_project_theme()
	var font: Font = theme.default_font if theme != null and theme.default_font != null else ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string_outline(font, pos - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 6, Color(0, 0, 0, 0.7))
	draw_string(font, pos - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
