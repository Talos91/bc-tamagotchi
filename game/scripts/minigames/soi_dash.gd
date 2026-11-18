extends "res://scripts/minigames/minigame_base.gd"
## Soi Dash (docs/design/10-minigame-next.md concept C; DECISIONS 2026-11-15 "build them all"). On the lounge game
## cabinet: late for the 20:00 show, run down a neon soi to the Black Cabin sign. Three lanes: swipe left / right to
## change lane round motorbikes and food carts, swipe up to hop a kerb or a sleeping soi dog, run through the music
## notes. A bump never ends the run: it costs 2 s of the clock. The street is the same for everyone each night.
## Score = 0.6 x notes / notes in the street + 0.4 x seconds to spare at the door / 10; arriving after 20:00 caps
## it at 0.5. config.seed: the street (default: the Bangkok date). Feeds action "soi_dash".

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

const RUN_SECONDS := 40.0            ## the street at full speed
const CLOCK_SECONDS := 50.0          ## the clock to 20:00 when the run starts (19:59:10 on the display)
const SPARE_FULL := 10.0             ## seconds to spare that score the full time part
const BUMP_COST := 2.0
const SPEED := 1.0                   ## street units per second (the street is RUN_SECONDS long)
const VIEW := 4.0                    ## street units visible ahead
const HIT_ZONE := 0.12               ## an item at distance within this of the runner touches them
const HOP_SECONDS := 0.6
const LANE_SECONDS := 0.12           ## lane change animation
const BUMP_SECONDS := 0.8            ## blink after a bump (no second bump)
const INTRO_SECONDS := 1.2
const SWIPE_PX := 50.0
const FIRST_AT := 2.5                ## first obstacle this far into the street
const STEP_MIN := 1.3                ## gap between obstacle rows
const STEP_MAX := 1.9
const BKK_OFFSET := 7 * 3600

enum State { INTRO, RUNNING, DONE }
enum Kind { BIKE, CART, DOG, KERB, NOTE }

var state := State.INTRO
var lane := 0                        ## -1 left, 0 middle, 1 right
var lane_anim := 0.0                 ## drawn lane position, eases toward lane
var hop_t := 0.0                     ## > 0 while in the air
var dist := 0.0                      ## street covered
var clock := CLOCK_SECONDS           ## seconds to 20:00
var items: Array[Dictionary] = []    ## {at, lane, kind, done}
var notes_total := 0
var notes := 0
var bumps := 0
var bump_t := 0.0
var arrived := false
var seed_used := 0
var _state_t := 0.0
var _press_pos := Vector2.ZERO
var _pressed := false


func _init() -> void:
	game_id = "soi_dash"
	action_id = "soi_dash"
	need_id = "nightlife"
	title_key = "mg.soi_dash.title"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _on_start() -> void:
	state = State.INTRO
	lane = 0
	lane_anim = 0.0
	hop_t = 0.0
	dist = 0.0
	clock = CLOCK_SECONDS
	notes = 0
	bumps = 0
	bump_t = 0.0
	arrived = false
	_state_t = 0.0
	seed_used = int(config.get("seed", night_seed()))
	items = street(seed_used)
	notes_total = 0
	for it in items:
		if it["kind"] == Kind.NOTE:
			notes_total += 1
	_update_status()
	queue_redraw()


# --- Rules (static where the tests pin them) -------------------------------------------------------

static func night_seed(unix := -1.0) -> int:
	var t := Time.get_unix_time_from_system() if unix < 0.0 else unix
	return int(floor((t + BKK_OFFSET) / 86400.0))


## The night's street: rows of obstacles (never all three lanes blocked; a dog or kerb blocks one lane and is hopped)
## with notes in the free lanes between them.
static func street(seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Dictionary] = []
	var at := FIRST_AT
	while at < RUN_SECONDS * SPEED - 1.0:
		var roll := rng.randi_range(0, 9)
		var l := rng.randi_range(-1, 1)
		if roll <= 5:
			out.append({"at": at, "lane": l, "kind": Kind.BIKE if rng.randf() < 0.6 else Kind.CART, "done": false})
			if roll <= 1:  # two blocked lanes: the third stays open
				var l2 := l + (1 if l < 1 else -1)
				out.append({"at": at, "lane": l2, "kind": Kind.BIKE, "done": false})
		else:
			out.append({"at": at, "lane": l, "kind": Kind.DOG if rng.randf() < 0.5 else Kind.KERB, "done": false})
		# notes on the way to the next row, in a lane that row leaves open
		var nl := rng.randi_range(-1, 1)
		for k in 2:
			var na := at + 0.45 + k * 0.3
			var blocked := false
			for it in out:
				if absf(float(it["at"]) - na) < 0.2 and int(it["lane"]) == nl:
					blocked = true
			if not blocked:
				out.append({"at": na, "lane": nl, "kind": Kind.NOTE, "done": false})
		at += rng.randf_range(STEP_MIN, STEP_MAX)
	return out


static func score_for(got: int, total: int, spare: float) -> float:
	var n := float(got) / total if total > 0 else 0.0
	var s := 0.6 * n + 0.4 * clampf(spare / SPARE_FULL, 0.0, 1.0)
	if spare < 0.0:
		s = minf(s, 0.5)
	return clampf(s, 0.0, 1.0)


func spare() -> float:
	return clock - maxf(0.0, (RUN_SECONDS * SPEED - dist) / SPEED)


func current_score() -> float:
	# Leaving early: the notes so far count, the time part only at the door
	return score_for(notes, notes_total, clock) if arrived else score_for(notes, notes_total, 0.0)


func airborne() -> bool:
	return hop_t > 0.0


## The next obstacle (not a note) ahead in a lane, or {}.
func next_obstacle(in_lane: int) -> Dictionary:
	var best := {}
	for it in items:
		if it["kind"] != Kind.NOTE and not it["done"] and int(it["lane"]) == in_lane and float(it["at"]) >= dist - HIT_ZONE:
			if best.is_empty() or float(it["at"]) < float(best["at"]):
				best = it
	return best


# --- Play ------------------------------------------------------------------------------------------

func move(dir: int) -> void:
	if state == State.DONE or not running or paused:
		return
	_begin()
	lane = clampi(lane + dir, -1, 1)


func hop() -> void:
	if state == State.DONE or not running or paused:
		return
	_begin()
	if hop_t <= 0.0:
		hop_t = HOP_SECONDS


func _begin() -> void:
	if state == State.INTRO:
		state = State.RUNNING
		_state_t = 0.0


func advance(dt: float) -> void:
	_state_t += dt
	match state:
		State.INTRO:
			if _state_t >= INTRO_SECONDS:
				_begin()
		State.RUNNING:
			_run(dt)
	lane_anim = move_toward(lane_anim, float(lane), dt / LANE_SECONDS)
	queue_redraw()


func _run(dt: float) -> void:
	dist += SPEED * dt
	clock -= dt
	hop_t = maxf(0.0, hop_t - dt)
	bump_t = maxf(0.0, bump_t - dt)
	for it in items:
		if it["done"]:
			continue
		var d := float(it["at"]) - dist
		if d < -HIT_ZONE:
			it["done"] = true
			continue
		if absf(d) > HIT_ZONE or int(it["lane"]) != lane:
			continue
		match int(it["kind"]):
			Kind.NOTE:
				it["done"] = true
				notes += 1
				_update_status()
			Kind.DOG, Kind.KERB:
				if not airborne():
					_bump(it)
			_:
				_bump(it)
	if dist >= RUN_SECONDS * SPEED:
		arrived = true
		state = State.DONE
		queue_redraw()
		finish(score_for(notes, notes_total, clock))


func _bump(it: Dictionary) -> void:
	it["done"] = true
	if bump_t > 0.0:
		return
	bumps += 1
	clock -= BUMP_COST
	bump_t = BUMP_SECONDS
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(30)
	_update_status()


func _result_extra() -> Dictionary:
	return {"notes": notes, "notes_total": notes_total, "bumps": bumps, "spare": clock, "arrived": arrived, "seed": seed_used}


func _update_status() -> void:
	set_status(S.t("mg.soi_dash.status", {"notes": notes, "clock": clock_text(clock)}))


## "19:59:10"-style time of night for a clock with `secs` left to 20:00 (late shows past 20:00).
static func clock_text(secs: float) -> String:
	var t := 20 * 3600 - int(ceil(secs))
	return "%02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_press_pos = event.position
		elif _pressed:
			_pressed = false
			var d: Vector2 = event.position - _press_pos
			if d.length() < SWIPE_PX:
				return
			if absf(d.x) > absf(d.y):
				move(1 if d.x > 0.0 else -1)
			elif d.y < 0.0:
				hop()


# --- Drawing ---------------------------------------------------------------------------------------

## Half the road's width at the runner, in px: the kerbs (l = +-3) stay inside the screen in portrait, and the road
## does not stretch across a wide landscape screen. 0.3.1 (item 37): it was size.x * 0.40 * 0.66 per lane unit, which
## put the side lanes (l = +-2) at 0.5 +- 0.53 of the width at the runner, off the screen.
func road_half() -> float:
	return minf(size.x * 0.42, size.y * 0.32)


## Screen point for street distance d ahead (0 = the runner) in lane position l (-3..3: kerb to kerb, lanes at
## -2 / 0 / 2).
func _pt(d: float, l: float) -> Vector2:
	var horizon := size.y * 0.16
	var base := size.y * 0.86
	var k := 1.0 / (1.0 + d * 0.45)          # 1 at the runner, smaller far away
	var yy := horizon + (base - horizon) * k
	return Vector2(size.x * 0.5 + l / 3.0 * road_half() * k, yy)


func _draw() -> void:
	if size.x <= 0.0:
		return
	var horizon := size.y * 0.16
	draw_rect(Rect2(0, 0, size.x, size.y), Color("140A0C"))
	# road
	var road := PackedVector2Array([_pt(VIEW, -3.0), _pt(VIEW, 3.0), _pt(-0.2, 3.0), _pt(-0.2, -3.0)])
	draw_colored_polygon(road, Color("24141A"))
	for l in [-0.5, 0.5]:
		draw_line(_pt(VIEW, l * 2.0), _pt(-0.2, l * 2.0), UI.LINE, 4.0)
	# shophouse neon either side, scrolling
	for k in 8:
		var d := fposmod(k * 0.8 - dist, 6.4)
		var cols: Array[Color] = [UI.CYAN, UI.AMBER, UI.GOLD, UI.RED_HI]
		var c := cols[k % 4]
		for side in [-1, 1]:
			var p := _pt(d, side * 3.35)          # just past the kerb, inside the screen
			var s := (p.y - horizon) / (size.y * 0.7)
			draw_rect(Rect2(p.x - 30 * s - side * 20 * s, p.y - 160 * s, 60 * s, 110 * s), c, false, maxf(2.0, 6.0 * s))
	# the sign at the end of the soi
	var left := RUN_SECONDS * SPEED - dist
	if left < VIEW:
		var p := _pt(left, 0)
		var s := (p.y - horizon) / (size.y * 0.7)
		draw_rect(Rect2(p.x - 200 * s, p.y - 260 * s, 400 * s, 100 * s), UI.NEON, false, maxf(2.0, 8.0 * s))
		UI.draw_text(self, "BLACK CABIN", Vector2(p.x, p.y - 190 * s), maxi(10, int(70 * s)), UI.NEON)
	else:
		UI.draw_text(self, "BLACK CABIN", Vector2(size.x * 0.5, horizon - 10), 40, Color(UI.NEON, 0.6))
	# items, far to near
	var vis: Array = []
	for it in items:
		var d := float(it["at"]) - dist
		if not it["done"] and d > -HIT_ZONE and d < VIEW:
			vis.append(it)
	vis.sort_custom(func(a, b): return float(a["at"]) > float(b["at"]))
	for it in vis:
		_draw_item(it, float(it["at"]) - dist)
	_draw_runner()
	UI.draw_text(self, S.t("mg.soi_dash.clock", {"clock": clock_text(clock)}), Vector2(size.x * 0.5, 50), 40, UI.GOLD if clock > 5.0 else UI.NEON)
	if state == State.INTRO:
		UI.draw_text(self, S.t("mg.soi_dash.hint"), Vector2(size.x * 0.5, size.y - 60), 40, UI.SMOKE)


func _draw_item(it: Dictionary, d: float) -> void:
	var p := _pt(d, float(it["lane"]) * 2.0)
	var s := (p.y - size.y * 0.16) / (size.y * 0.7)
	match int(it["kind"]):
		Kind.NOTE:
			draw_circle(p + Vector2(-8, -40) * s, 16 * s, UI.GOLD)
			draw_line(p + Vector2(6, -40) * s, p + Vector2(6, -110) * s, UI.GOLD, maxf(2.0, 7 * s))
		Kind.BIKE:
			draw_rect(Rect2(p + Vector2(-50, -120) * s, Vector2(100, 90) * s), UI.CYAN)
			draw_circle(p + Vector2(-34, -20) * s, 18 * s, UI.BG_DEEP)
			draw_circle(p + Vector2(34, -20) * s, 18 * s, UI.BG_DEEP)
		Kind.CART:
			draw_rect(Rect2(p + Vector2(-70, -150) * s, Vector2(140, 120) * s), UI.AMBER)
			draw_rect(Rect2(p + Vector2(-80, -170) * s, Vector2(160, 24) * s), UI.RED_HI)
		Kind.DOG:
			draw_rect(Rect2(p + Vector2(-50, -40) * s, Vector2(100, 34) * s), Color("C4A07A"))
			draw_rect(Rect2(p + Vector2(40, -54) * s, Vector2(28, 28) * s), Color("C4A07A"))
		Kind.KERB:
			draw_rect(Rect2(p + Vector2(-80, -26) * s, Vector2(160, 26) * s), UI.ASH)


func _draw_runner() -> void:
	if bump_t > 0.0 and int(bump_t * 10.0) % 2 == 0:
		return
	var p := _pt(0.0, lane_anim * 2.0)
	var lift := sin(clampf(hop_t / HOP_SECONDS, 0.0, 1.0) * PI) * 110.0
	var stride := sin(dist * 18.0) * 10.0 if state == State.RUNNING and not airborne() else 0.0
	var base := p - Vector2(0, lift)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-50, 4), p + Vector2(50, 4), p + Vector2(40, 16), p + Vector2(-40, 16)]), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(base + Vector2(-22, -60 + stride), Vector2(18, 60)), Color("222230"))
	draw_rect(Rect2(base + Vector2(4, -60 - stride), Vector2(18, 60)), Color("222230"))
	draw_rect(Rect2(base + Vector2(-30, -150), Vector2(60, 92)), UI.RED)
	draw_rect(Rect2(base + Vector2(-24, -200), Vector2(48, 48)), Color("6A402A"))
