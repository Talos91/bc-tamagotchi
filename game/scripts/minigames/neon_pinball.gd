extends "res://scripts/minigames/minigame_base.gd"
## Neon Pinball (GDD section 9 #10; DECISIONS: runs on the lounge arcade cabinet's screen). A simplified
## pinball with its own small physics. Controls: hold the left / right half of the screen for that
## flipper, swipe up on the right third to launch (a tap also launches), swipe sideways to nudge the ball
## (tilt: nudge too often and the flippers go dead for a moment). 3 balls, 10 s ball save, 3 minute cap.
## Light all ten letters of BLACK CABIN for a bonus. Feeds action "pinball" (Nightlife +10-20).

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

# Field coordinates: 600 x 1000, y down. Playfield x 0..540, launch lane x 540..600.
const FIELD := Vector2(600, 1000)
const BALL_R := 13.0
const GRAVITY := 1500.0
const MAX_SPEED := 2300.0
const SUBSTEP := 1.0 / 480.0
const BALLS := 3
const BALL_SAVE_SECONDS := 10.0
const TIME_CAP := 180.0
const LAUNCH_SPEED_MIN := 1750.0
const LAUNCH_SPEED_MAX := 2300.0
const LANE_X := 570.0
const LANE_REST_Y := 940.0
const FULL_POINTS := 3000.0  # points that map to score 1.0
const BUMPER_POINTS := 100
const LETTER_POINTS := 250
const WORD_BONUS := 1500
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
var word_done := false
var toast := ""
var _toast_t := 0.0
var _press_pos := Vector2.ZERO
var _press_t := 0.0
var _pressing := false
var _scale := 1.0
var _origin := Vector2.ZERO


func _init() -> void:
	game_id = "neon_pinball"
	action_id = "pinball"
	need_id = "nightlife"
	title_key = "mg.neon_pinball.title"
	_build_field()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


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


func current_score() -> float:
	return score_from(points)


func _on_start() -> void:
	points = 0
	balls_left = BALLS
	play_time = 0.0
	tilt = 0.0
	tilt_lock = 0.0
	word_done = false
	for i in lit.size():
		lit[i] = false
	flip_angle = [FLIPPER_REST, FLIPPER_REST]
	flip_held = [false, false]
	_serve()
	_update_status()


func _serve() -> void:
	ball_state = Ball.LANE
	pos = Vector2(LANE_X, LANE_REST_Y)
	vel = Vector2.ZERO
	ball_time = 0.0


func launch(power := 0.85) -> void:
	if ball_state != Ball.LANE or not running or paused:
		return
	ball_state = Ball.LIVE
	ball_time = 0.0
	vel = Vector2(0, -lerpf(LAUNCH_SPEED_MIN, LAUNCH_SPEED_MAX, clampf(power, 0.0, 1.0)))


func nudge(dir: int) -> void:
	if ball_state != Ball.LIVE or tilt_lock > 0.0:
		return
	vel.x += dir * NUDGE_SPEED
	tilt += NUDGE_TILT
	if tilt >= TILT_LIMIT:
		tilt_lock = TILT_LOCK_SECONDS
		tilt = 0.6
		flip_held = [false, false]
		_say(S.t("mg.neon_pinball.tilt"))


func set_flipper(side: int, held: bool) -> void:
	flip_held[side] = held and tilt_lock <= 0.0


func _say(text: String) -> void:
	toast = text
	_toast_t = 1.6


# --- Physics ---------------------------------------------------------------------------------------

func advance(dt: float) -> void:
	play_time += dt
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
	if play_time >= TIME_CAP:
		finish(score_from(points))
		return
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
	vel.y += GRAVITY * h
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
			_update_status()
	for i in letter_pos.size():
		if not lit[i] and pos.distance_to(letter_pos[i]) < SENSOR_R + BALL_R * 0.5:
			lit[i] = true
			points += LETTER_POINTS
			if not word_done and not lit.has(false):
				word_done = true
				points += WORD_BONUS
				_say(S.t("mg.neon_pinball.word"))
			_update_status()
	if pos.y > FIELD.y + 40.0 and pos.x < 540.0:
		_drain()


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


func _drain() -> void:
	if ball_time <= BALL_SAVE_SECONDS:
		_say(S.t("mg.neon_pinball.ball_saved"))
		_serve()
		return
	balls_left -= 1
	if balls_left <= 0:
		ball_state = Ball.GONE
		finish(score_from(points))
		return
	_serve()
	_update_status()


func _update_status() -> void:
	set_status(S.t("mg.neon_pinball.status", {"ball": BALLS - balls_left + 1, "balls": BALLS, "points": points}))


func _result_extra() -> Dictionary:
	return {"points": points, "letters": lit.count(true), "word": word_done}


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


func _draw() -> void:
	if size.x <= 0.0:
		return
	var bezel := Vector2(36, 28)
	_scale = minf((size.x - bezel.x * 2.0 - 40.0) / FIELD.x, (size.y - bezel.y * 2.0 - 20.0) / FIELD.y)
	var fs := FIELD * _scale
	_origin = Vector2((size.x - fs.x) * 0.5, (size.y - fs.y) * 0.5)
	# Cabinet: dark body, bezel line, the screen in the one cool light.
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG_DEEP)
	var screen := Rect2(_origin - Vector2(24, 24), fs + Vector2(48, 48))
	draw_rect(screen.grow(26.0), UI.BG_BASE)
	draw_rect(screen.grow(26.0), UI.LINE, false, 4.0)
	draw_rect(screen, Color("06161B"))
	for y in range(int(screen.position.y), int(screen.end.y), 8):
		draw_line(Vector2(screen.position.x, y), Vector2(screen.end.x, y), Color(UI.CYAN, 0.04), 1.0)
	draw_rect(screen, Color(UI.CYAN, 0.5), false, 3.0)
	# Walls.
	for w in walls:
		draw_line(_f(w[0]), _f(w[1]), UI.SMOKE, 5.0)
	# Bumpers.
	for i in BUMPERS.size():
		var b := BUMPERS[i]
		draw_circle(_f(Vector2(b.x, b.y)), b.z * _scale, Color(UI.CYAN, 0.18 + 0.6 * bumper_flash[i]))
		draw_arc(_f(Vector2(b.x, b.y)), b.z * _scale, 0, TAU, 32, UI.CYAN, 4.0, true)
	# Letters of BLACK CABIN: Neon Red when lit (brand moment), Ash otherwise.
	for i in letter_pos.size():
		var col: Color = UI.NEON if lit[i] else UI.ASH
		draw_arc(_f(letter_pos[i]), SENSOR_R * _scale, 0, TAU, 20, Color(col, 0.7), 3.0, true)
		UI.draw_text(self, LETTERS[i], _f(letter_pos[i]) + Vector2(0, 14), 40, col)
	# Flippers.
	for s in 2:
		var p0 := flipper_pivot(s)
		draw_line(_f(p0), _f(p0 + flipper_dir(s) * FLIPPER_LEN), UI.GOLD, FLIPPER_THICK * 2.0 * _scale, true)
		draw_circle(_f(p0), FLIPPER_THICK * _scale, UI.GOLD)
	# Ball.
	draw_circle(_f(pos), BALL_R * _scale, UI.CREAM)
	# Score and tilt on the screen.
	UI.draw_text(self, str(points), _f(Vector2(270, 60)), 58, UI.CYAN)
	if tilt > 0.05:
		draw_rect(Rect2(_f(Vector2(20, 90)), Vector2(200 * _scale * tilt / TILT_LIMIT, 8)), UI.AMBER)
	if _toast_t > 0.0:
		UI.draw_text(self, toast, _f(Vector2(270, 700)), 64, UI.GOLD)
	if ball_state == Ball.LANE:
		UI.draw_text(self, S.t("mg.neon_pinball.hint_launch"), _f(Vector2(270, 780)), 40, UI.SMOKE)
