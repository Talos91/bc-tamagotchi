extends "res://scripts/minigames/minigame_base.gd"
## Soi Dash (docs/design/10-minigame-next.md concept C; DECISIONS 2026-11-15 "build them all"). On the lounge game
## cabinet: late for the 20:00 show, run down a neon soi to the Black Cabin door. Three lanes: swipe left / right to
## change lane round parked motorbikes, food carts and tuk-tuks driving at you; swipe up to hop a kerb, a sleeping or
## trotting soi dog, or a monitor lizard crossing the soi; run through the music notes. A bump never ends the run: it
## costs 2 s of the clock. The street is the same for everyone each night (per timing mode).
## Score = 0.6 x notes / notes in the street + 0.4 x seconds to spare at the door / 10; arriving after 20:00 caps
## it at 0.5. config.seed: the street (default: the Bangkok date). Feeds action "soi_dash".
##
## Q6 (docs/design/11-minigame-quality.md, 2026-11-19): drawn from the look B voxel sprites in
## res://assets/minigames/soi_dash/ (flat shapes stay as the fallback when a texture is missing); street life with its
## own moves (§ Daniele 2026-11-18: monitor lizards, stray dogs, food carts, tuk-tuks); every §2.3 beat through mg_fx;
## the §3 ramp (row gap 1.9 -> 1.2, two-lane rows and tuk-tuks after 10 s, dogs after 15 s, lizards after 20 s;
## relaxed: gap +0.4, movers settle 0.5 s earlier, tuk-tuks rush less). Fair rule for movers: a stray or a lizard
## is in its final lane SETTLE units before the runner reaches it; a tuk-tuk only looks faster (it is drawn further
## out and rushes in) and reaches the runner at the same street point as a parked one would.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Rivals = preload("res://scripts/minigames/mg_rivals.gd")

const ART := "res://assets/minigames/soi_dash/"

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
const BKK_OFFSET := 7 * 3600
const GHOST_STEP := 0.25             ## ghost: the runner's lane every this many street units

# --- The ramp (§3): the first 10 s are a warm-up, the middle teaches, the last third tests
const STEP_START := 1.9              ## gap between obstacle rows at the start ...
const STEP_END := 1.2                ## ... and at the door
const STEP_JITTER := 0.15
const RAMP_FROM := 10.0              ## the gap starts shrinking here
const PAIR_FROM := 10.0              ## two-lane rows from here
const TIGHT_FROM := 27.0             ## the last third: two-lane rows come more often
const TUK_FROM := 10.0
const DOG_FROM := 15.0
const LIZARD_FROM := 20.0
const RELAXED_STEP := 0.4            ## relaxed: every gap this much longer

# --- Street life moves
const SETTLE := 0.9                  ## a stray or a lizard is in its final lane this far ahead of the runner
const RELAXED_TELEGRAPH := 0.5       ## relaxed: movers settle this much earlier
const STRAY_SPAN := 1.2              ## street units a stray takes to trot one lane over
const LIZARD_SPAN := 2.4             ## a lizard crawls two lanes, slowly
const TUK_RUSH := 1.6                ## a tuk-tuk is drawn this many times further out: it rushes in
const TUK_RUSH_RELAXED := 1.3
const DOG_WAKE := 1.2                ## a sleeping dog's ear goes up when the runner is this close

# --- Beats
const DASH_SECONDS := 0.18           ## lane dash streak
const PUFF_SECONDS := 0.35           ## hop dust
const DOOR_AHEAD := 0.5              ## the door stands this far past the end of the run
const DOOR_SECONDS := 0.8            ## doors swing, neon flares, then the result
const ART_LANE_PX := 240.0           ## sprite px that fill one lane at the runner (frames are drawn for a 780 px play)

enum State { INTRO, RUNNING, DOOR, DONE }
enum Kind { BIKE, CART, DOG, KERB, NOTE, TUK, STRAY, LIZARD }

var state := State.INTRO
var lane := 0                        ## -1 left, 0 middle, 1 right
var lane_anim := 0.0                 ## drawn lane position, eases toward lane
var hop_t := 0.0                     ## > 0 while in the air
var dist := 0.0                      ## street covered
var clock := CLOCK_SECONDS           ## seconds to 20:00
var items: Array[Dictionary] = []    ## {at, lane, from, kind, done}
var notes_total := 0
var notes := 0
var bumps := 0
var bump_t := 0.0
var arrived := false
var seed_used := 0
var door_t := 0.0
var best_combo := 0
var _state_t := 0.0
var _anim_t := 0.0
var _press_pos := Vector2.ZERO
var _pressed := false
var _dash_from := 0.0
var _dash_t := 0.0
var _puffs: Array = []               ## {pos, t, size}
var _tex := {}
var _glow: Control
## §4.1 competition: tonight's regular to beat, your best run tonight as a ghost runner, the board line.
var rival: Dictionary = {}           ## {regular, name, points}
var rival_passed := false
var ghost: Dictionary = {}           ## your best run tonight {seed, relaxed, step, lanes: [int -1..1]}, or {}
var ghost_lanes: Array[int] = []     ## this run, recorded for the next ghost
var rivals_store: Object = null      ## tests: where mg_rivals keeps tonight's record (default Needs, else memory)
var _record: Dictionary = {}

static var _meta := {}


func _init() -> void:
	game_id = "soi_dash"
	action_id = "soi_dash"
	need_id = "nightlife"
	title_key = "mg.soi_dash.title"
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # the road tile and the lane dashes repeat


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
	door_t = 0.0
	best_combo = 0
	_state_t = 0.0
	_anim_t = 0.0
	_dash_t = 0.0
	_puffs.clear()
	seed_used = int(config.get("seed", night_seed()))
	items = street(seed_used, relaxed)
	_record = {}
	var t := Rivals.tonight(game_id, rivals_store)
	rival = t["rival"]
	rival_passed = false
	var g: Dictionary = t["ghost"]
	# the ghost only runs the same street: same seed and same timing mode
	ghost = g if int(g.get("seed", -1)) == seed_used and bool(g.get("relaxed", false)) == relaxed and g.get("lanes") is Array else {}
	ghost_lanes.clear()
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


## Obstacles hopped (low across the lane) rather than dodged.
static func hoppable(kind: int) -> bool:
	return kind == Kind.DOG or kind == Kind.KERB or kind == Kind.STRAY or kind == Kind.LIZARD


## Gap to the next row at street point `at` (§3 ramp, before jitter).
static func row_step(at: float, relaxed_on := false) -> float:
	var t := clampf((at - RAMP_FROM) / (RUN_SECONDS * SPEED - 1.0 - RAMP_FROM), 0.0, 1.0)
	return lerpf(STEP_START, STEP_END, t) + (RELAXED_STEP if relaxed_on else 0.0)


## The night's street: rows of obstacles (never all three lanes blocked; a hoppable one blocks one lane) with notes
## in the free lanes between them. Warm-up rows are parked bikes, carts and kerbs; the street life joins on the ramp.
## Relaxed: the same rows in the same order, each gap RELAXED_STEP longer (the street ends sooner, so fewer rows).
static func street(seed_value: int, relaxed_on := false) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Dictionary] = []
	var at := FIRST_AT                   # the row's place in the normal street: decides what it is
	var pos := FIRST_AT                  # where it stands (relaxed: every gap longer, same rows in the same order)
	while pos < RUN_SECONDS * SPEED - 1.0:
		var roll := rng.randi_range(0, 9)
		var l := rng.randi_range(-1, 1)
		var pair_below := 2 if at >= TIGHT_FROM else (1 if at >= PAIR_FROM else -1)
		if roll <= 5:
			var kind := Kind.BIKE if rng.randf() < 0.6 else Kind.CART
			if at >= TUK_FROM and rng.randf() < 0.35:
				kind = Kind.TUK
			out.append(_item(pos, l, l, kind))
			if roll <= pair_below:  # two blocked lanes: the third stays open
				var l2 := l + (1 if l < 1 else -1)
				out.append(_item(pos, l2, l2, Kind.BIKE if rng.randf() < 0.6 else Kind.CART))
		else:
			var r := rng.randf()
			var kind := Kind.KERB
			var from := l
			if at >= LIZARD_FROM and r < 0.3:
				kind = Kind.LIZARD
				from = l + (2 if rng.randf() < 0.5 else -2)       # crawls in two lanes from one side
			elif at >= DOG_FROM and r < 0.7:
				if rng.randf() < 0.5:
					kind = Kind.DOG
				else:
					kind = Kind.STRAY
					from = l + (1 if rng.randf() < 0.5 else -1)   # trots one lane over
			out.append(_item(pos, l, from, kind))
		# notes on the way to the next row, in a lane that row leaves open
		var nl := rng.randi_range(-1, 1)
		for k in 2:
			var na := pos + 0.45 + k * 0.3
			var blocked := false
			for it in out:
				if absf(float(it["at"]) - na) < 0.2 and int(it["lane"]) == nl:
					blocked = true
			if not blocked:
				out.append(_item(na, nl, nl, Kind.NOTE))
		var step := row_step(at) + rng.randf_range(-STEP_JITTER, STEP_JITTER)
		at += step
		pos += step + (RELAXED_STEP if relaxed_on else 0.0)
	return out


static func _item(at: float, l: int, from: int, kind: int) -> Dictionary:
	return {"at": at, "lane": l, "from": from, "kind": kind, "done": false}


## Where a mover is drawn (lane units, -1..1, beyond for the gutters) when it is `d` ahead of the runner. Parked
## things and notes sit in their lane. A stray or a lizard eases from `from` to `lane` and is there SETTLE ahead.
static func mover_lane(it: Dictionary, d: float, relaxed_on := false) -> float:
	var k := int(it["kind"])
	if k != Kind.STRAY and k != Kind.LIZARD:
		return float(it["lane"])
	var settle := SETTLE + (RELAXED_TELEGRAPH if relaxed_on else 0.0)
	var span := STRAY_SPAN if k == Kind.STRAY else LIZARD_SPAN
	var u := clampf((settle + span - d) / span, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	return lerpf(float(it["from"]), float(it["lane"]), u)


## The distance a thing is drawn at: a tuk-tuk drives at the runner, so it shows further out and closes faster.
static func drawn_dist(it: Dictionary, d: float, relaxed_on := false) -> float:
	if int(it["kind"]) == Kind.TUK and d > 0.0:
		return d * (TUK_RUSH_RELAXED if relaxed_on else TUK_RUSH)
	return d


static func score_for(got: int, total: int, spare: float) -> float:
	var n := float(got) / total if total > 0 else 0.0
	var s := 0.6 * n + 0.4 * clampf(spare / SPARE_FULL, 0.0, 1.0)
	if spare < 0.0:
		s = minf(s, 0.5)
	return clampf(s, 0.0, 1.0)


func live_points() -> int:
	return points_for(current_score())


## The run that just ended, as tonight's ghost (only kept if it is your best tonight): the lane at every step.
func ghost_data() -> Dictionary:
	return {"seed": seed_used, "relaxed": relaxed, "step": GHOST_STEP, "lanes": ghost_lanes.duplicate()}


## The ghost runner's lane at a street distance (NAN when the ghost run ended before that point).
func ghost_lane_at(d: float) -> float:
	var lanes: Array = ghost.get("lanes", [])
	var i := int(floor(d / float(ghost.get("step", GHOST_STEP))))
	if i < 0 or i >= lanes.size():
		return NAN
	return float(lanes[i])


## §4.1: passing tonight's regular on the street.
func _check_rival() -> void:
	if rival_passed or rival.is_empty() or live_points() <= int(rival.get("points", 0)):
		return
	rival_passed = true
	fx().pop(S.t("mg.rivals.passed", {"regular": str(rival.get("name", ""))}), Vector2(size.x * 0.5, size.y * 0.3), UI.NEON, 44)


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
	if state == State.DONE or state == State.DOOR or not running or paused:
		return
	_begin()
	var to := clampi(lane + dir, -1, 1)
	if to != lane:
		_dash_from = lane_anim
		_dash_t = DASH_SECONDS
	lane = to


func hop() -> void:
	if state == State.DONE or state == State.DOOR or not running or paused:
		return
	_begin()
	if hop_t <= 0.0:
		hop_t = HOP_SECONDS
		var f := fx()
		f.squash("runner")
		_puff(runner_px(), 1.0)


func _begin() -> void:
	if state == State.INTRO:
		state = State.RUNNING
		_state_t = 0.0


func advance(dt: float) -> void:
	_state_t += dt
	_anim_t += dt
	match state:
		State.INTRO:
			if _state_t >= INTRO_SECONDS:
				_begin()
		State.RUNNING:
			_run(dt)
		State.DOOR:
			door_t += dt
			if door_t >= DOOR_SECONDS:
				state = State.DONE
				finish(score_for(notes, notes_total, clock))
	lane_anim = move_toward(lane_anim, float(lane), dt / LANE_SECONDS)
	_dash_t = maxf(0.0, _dash_t - dt)
	for p in _puffs:
		p["t"] += dt
	_puffs = _puffs.filter(func(p): return p["t"] < PUFF_SECONDS)
	queue_redraw()
	if _glow != null:
		_glow.queue_redraw()


func _run(dt: float) -> void:
	dist += SPEED * dt
	clock -= dt
	while float(ghost_lanes.size()) * GHOST_STEP <= dist:
		ghost_lanes.append(lane)
	var was_air := airborne()
	hop_t = maxf(0.0, hop_t - dt)
	if was_air and not airborne():
		_puff(runner_px(), 0.7)          # landing dust
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
				_note_beat(it)
				_check_rival()
				_update_status()
			Kind.DOG, Kind.KERB, Kind.STRAY, Kind.LIZARD:
				if not airborne():
					_bump(it)
			_:
				_bump(it)
	if dist >= RUN_SECONDS * SPEED:
		arrived = true
		state = State.DOOR
		door_t = 0.0
		_door_beat()


func _bump(it: Dictionary) -> void:
	it["done"] = true
	if bump_t > 0.0:
		return
	bumps += 1
	clock -= BUMP_COST
	bump_t = BUMP_SECONDS
	var f := fx()
	f.combo_break()
	f.shake(Fx.TRAUMA_BUMP)
	f.fail_edge()
	f.flash("clock")
	f.pop(S.t("mg.soi_dash.bump", {"secs": int(BUMP_COST)}), clock_px() + Vector2(0, 100), UI.NEON)
	haptic("fail")
	_update_status()


func _note_beat(it: Dictionary) -> void:
	var f := fx()
	var p := _pt(0.0, float(it["lane"]) * 2.0) - Vector2(0, 120.0 * art_scale())
	f.pop("+1", p, UI.GOLD)
	f.flare(p, 70.0 * art_scale(), UI.GOLD)
	f.burst("spark", p, 6)
	best_combo = maxi(best_combo, f.combo_step(S.t("mg.soi_dash.combo"), Vector2(size.x * 0.5, size.y * 0.25)))
	haptic("tick")


func _door_beat() -> void:
	var f := fx()
	var p := _pt(DOOR_AHEAD, 0.0)
	var sc := art_scale() * _k(DOOR_AHEAD)
	var sign_p := p - Vector2(0, 240.0 * sc)
	f.flare(sign_p, 260.0 * sc, UI.NEON)
	f.burst("confetti", sign_p)
	haptic("strong")


func _puff(pos: Vector2, size_k: float) -> void:
	_puffs.append({"pos": pos, "t": 0.0, "size": size_k})


func _result_extra() -> Dictionary:
	if _record.is_empty():
		_record = Rivals.record(game_id, points_for(score_for(notes, notes_total, clock)), ghost_data(), rivals_store)
	return {"notes": notes, "notes_total": notes_total, "bumps": bumps, "spare": clock, "arrived": arrived, "seed": seed_used,
		"best_combo": best_combo, "relaxed": relaxed, "rival": rival, "board": _record["board_line"]}


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


# --- Layout ----------------------------------------------------------------------------------------

## Half the road's width at the runner, in px: the kerbs (l = +-3) stay inside the screen in portrait, and the road
## does not stretch across a wide landscape screen. 0.3.1 (item 37): it was size.x * 0.40 * 0.66 per lane unit, which
## put the side lanes (l = +-2) at 0.5 +- 0.53 of the width at the runner, off the screen.
func road_half() -> float:
	return minf(size.x * 0.42, size.y * 0.32)


## Perspective factor at street distance d: 1 at the runner, smaller far away.
func _k(d: float) -> float:
	return 1.0 / (1.0 + maxf(d, -0.5) * 0.45)


## Screen point for street distance d ahead (0 = the runner) in lane position l (-3..3: kerb to kerb, lanes at
## -2 / 0 / 2).
func _pt(d: float, l: float) -> Vector2:
	var horizon := size.y * 0.16
	var base := size.y * 0.86
	var k := _k(d)
	var yy := horizon + (base - horizon) * k
	return Vector2(size.x * 0.5 + l / 3.0 * road_half() * k, yy)


## Sprite scale at the runner: one lane holds ART_LANE_PX of sprite; capped at 1.5 so the voxels stay crisp.
func art_scale() -> float:
	return clampf(road_half() * 2.0 / 3.0 / ART_LANE_PX, 0.4, 1.5)


func runner_px() -> Vector2:
	return _pt(0.0, lane_anim * 2.0)


func clock_px() -> Vector2:
	return Vector2(size.x * 0.5, 50.0)


## Highest the runner's hop lifts the feet, px.
func hop_lift_px() -> float:
	return 110.0 * art_scale()


## The screen rect a sprite frame covers when drawn with its anchor at `pos` and scale `sc` ({} sprites: zero).
func sprite_rect(sprite: String, pos: Vector2, sc: float) -> Rect2:
	var m := sprite_meta(sprite)
	if m.is_empty():
		return Rect2(pos, Vector2.ZERO)
	var a := Vector2(m["anchor_px"][0], m["anchor_px"][1])
	return Rect2(pos - a * sc, Vector2(m["frame_w"], m["frame_h"]) * sc)


static func sprite_meta(sprite: String) -> Dictionary:
	if _meta.is_empty():
		var f := FileAccess.open(ART + "sprites.json", FileAccess.READ)
		if f != null:
			var j = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				_meta = j.get("sprites", {})
	return _meta.get(sprite, {})


# --- Drawing ---------------------------------------------------------------------------------------

func _t(file: String) -> Texture2D:
	if not _tex.has(file):
		var path := ART + file
		_tex[file] = load(path) if ResourceLoader.exists(path) else null
	return _tex[file]


func _sprites() -> bool:
	return _t("runner.png") != null and not sprite_meta("runner").is_empty()


## Draws frame `frame` of `sprite` with its anchor at `pos`, scale `sc` (negative x mirrors), on `ci`. glow: the
## half-size `_glow` sheet stretched over the same frame rect (README: glow_scale 2).
func _spr(ci: CanvasItem, sprite: String, frame: int, pos: Vector2, sc: Vector2, col := Color.WHITE, glow := false) -> void:
	var m := sprite_meta(sprite)
	if m.is_empty():
		return
	var tex := _t(m.get("glow_file", "") if glow else m["file"])
	if tex == null:
		return
	var fw: float = m["frame_w"]
	var fh: float = m["frame_h"]
	var a := Vector2(m["anchor_px"][0], m["anchor_px"][1])
	var src := Rect2(frame * fw, 0, fw, fh)
	if glow:
		src = Rect2(frame * fw * 0.5, 0, fw * 0.5, fh * 0.5)
	ci.draw_set_transform(pos, 0.0, sc)
	ci.draw_texture_rect_region(tex, Rect2(-a, Vector2(fw, fh)), src, col)
	ci.draw_set_transform(Vector2.ZERO)


func _ensure_glow() -> void:
	if _glow != null and is_instance_valid(_glow):
		return
	_glow = Control.new()
	_glow.name = "Glow"
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	move_child(_glow, 0)                 # under the mg_fx overlay


func _draw() -> void:
	if size.x <= 0.0:
		return
	if not _sprites():
		_draw_flat()
		return
	_ensure_glow()
	var f := fx()
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG_DEEP)
	_draw_backdrop()
	_draw_road()
	# shophouses either side, far to near, then the door, the street life and the runner
	for s in _shops():
		_spr(self, "shopfront", s["frame"], s["pos"], s["sc"], Color(0.85, 0.85, 0.9))
	var left := RUN_SECONDS * SPEED - dist + DOOR_AHEAD
	if left < VIEW + 1.0:
		var sc := art_scale() * _k(left) * 1.2
		_spr(self, "door_front", 1 if state == State.DOOR or state == State.DONE else 0, _pt(left, 0.0), Vector2(sc, sc))
	for it in _visible():
		_draw_item(it, float(it["at"]) - dist)
	_draw_ghost()
	_draw_runner()
	_draw_puffs()
	var cc := UI.GOLD if clock > 5.0 else UI.NEON
	UI.draw_text(self, S.t("mg.soi_dash.clock", {"clock": clock_text(clock)}), clock_px(), 40, f.flash_color("clock", cc))
	_draw_rivals()
	if state == State.INTRO:
		UI.draw_text(self, S.t("mg.soi_dash.hint"), Vector2(size.x * 0.5, size.y - 60), 40, UI.SMOKE)
		if not ghost.is_empty():
			UI.draw_text(self, S.t("mg.soi_dash.ghost"), Vector2(size.x * 0.5, size.y - 108), 26, Color(0.75, 0.9, 1.0, 0.8))


## The far soi (blurred render): covers the play area, its vanishing point on the horizon, creeping closer as the
## runner nears the door (slow parallax against the road).
func _draw_backdrop() -> void:
	var tex := _t("backdrop.png")
	if tex == null:
		return
	var ts := Vector2(tex.get_size())
	var zoom := 1.0 + 0.12 * clampf(dist / (RUN_SECONDS * SPEED), 0.0, 1.0)
	var sc := maxf(size.x / ts.x, size.y / ts.y) * zoom
	var dsz := ts * sc
	var vp := Vector2(0.5, 0.36)                     # the soi's far end in the render
	var horizon := size.y * 0.16
	var pos := Vector2(size.x * 0.5, horizon) - vp * dsz
	pos.y = minf(pos.y, 0.0)
	pos.x = clampf(pos.x, size.x - dsz.x, 0.0)
	draw_texture_rect(tex, Rect2(pos, dsz), false, Color(0.75, 0.72, 0.78))


func _draw_road() -> void:
	var tex := _t("road_tile.png")
	var n := 26
	var d_near := -0.3
	for i in n:
		# strips spaced so each is about as tall on screen as the next
		var a := d_near + (VIEW - d_near) * pow(float(i) / n, 1.6)
		var b := d_near + (VIEW - d_near) * pow(float(i + 1) / n, 1.6)
		var pts := PackedVector2Array([_pt(a, -3.0), _pt(a, 3.0), _pt(b, 3.0), _pt(b, -3.0)])
		var shade := Color(0.8, 0.78, 0.85).lerp(Color(0.35, 0.3, 0.4), clampf(a / VIEW, 0.0, 1.0))
		if tex != null:
			var va := (a + dist) * 1.5
			var vb := (b + dist) * 1.5
			var uvs := PackedVector2Array([Vector2(0, -va), Vector2(3, -va), Vector2(3, -vb), Vector2(0, -vb)])
			draw_polygon(pts, PackedColorArray([shade]), uvs, tex)
		else:
			draw_colored_polygon(pts, Color("24141A"))
		# kerb stones: black and white blocks scrolling with the street
		var white := int(floor((a + dist) * 3.0)) % 2 == 0
		var kc := Color(0.82, 0.8, 0.78) if white else Color(0.1, 0.09, 0.1)
		kc = kc.lerp(Color(0.2, 0.15, 0.2), clampf(a / VIEW, 0.0, 1.0) * 0.6)
		var w := maxf(2.0, 14.0 * _k(a) * art_scale())
		for side in [-1.0, 1.0]:
			draw_line(_pt(a, side * 3.0), _pt(b, side * 3.0), kc, w)
	# lane dashes, scrolling
	var dash := _t("lane_dash.png")
	var period := 0.7
	for j in 8:
		var dd := j * period - fposmod(dist, period)
		if dd < -0.3 or dd > VIEW:
			continue
		for l in [-1.0, 1.0]:
			var p0 := _pt(dd, l)
			var p1 := _pt(dd + 0.3, l)
			var w := maxf(2.0, 10.0 * _k(dd) * art_scale())
			var col := Color(1, 1, 1, 0.75 * (1.0 - clampf(dd / VIEW, 0.0, 1.0) * 0.6))
			if dash != null:
				draw_texture_rect(dash, Rect2(p1.x - w * 0.5, p1.y, w, p0.y - p1.y), false, col)
			else:
				draw_line(p0, p1, col, w)


## Shopfront placements, far to near: {frame, pos, sc (x mirrored on the right)}.
func _shops() -> Array:
	var out: Array = []
	var period := 0.8
	var count := 9
	for j in count:
		var d := j * period - fposmod(dist, period) - 0.4
		var idx := int(floor((dist + 0.4) / period)) + j  # stable id per shop as it scrolls
		var k := art_scale() * _k(d) * 1.25
		for side in [-1, 1]:
			out.append({"frame": posmod(idx * 2 + (1 if side > 0 else 0), 3), "pos": _pt(d, side * 3.55),
				"sc": Vector2(k * -side, k), "d": d})
	out.sort_custom(func(a, b): return a["d"] > b["d"])
	return out


func _visible() -> Array:
	var vis: Array = []
	for it in items:
		var d := float(it["at"]) - dist
		var dd := drawn_dist(it, d, relaxed)
		if not it["done"] and d > -HIT_ZONE and dd < VIEW:
			vis.append(it)
	vis.sort_custom(func(a, b): return drawn_dist(a, float(a["at"]) - dist, relaxed) > drawn_dist(b, float(b["at"]) - dist, relaxed))
	return vis


func _draw_item(it: Dictionary, d: float) -> void:
	var dd := drawn_dist(it, d, relaxed)
	var lp := mover_lane(it, d, relaxed)
	var p := _pt(dd, lp * 2.0)
	var k := art_scale() * _k(dd)
	var fade := clampf((VIEW - dd) / 0.6, 0.0, 1.0)             # far things fade in out of the dark
	var col := Color(1, 1, 1, fade)
	match int(it["kind"]):
		Kind.NOTE:
			var bob := sin(_anim_t * 6.0 + float(it["at"]) * 3.0) * 8.0 * k
			_spr(self, "note", 0, p - Vector2(0, 90.0 * k + bob), Vector2(k, k), col)
		Kind.BIKE:
			_spr(self, "motorbike", 0, p, Vector2(k, k), col)
		Kind.CART:
			_spr(self, "food_cart", 0, p, Vector2(k, k), col)
			# steam off the noodle pot
			for s in 3:
				var ph := fposmod(_anim_t * 0.8 + s * 0.33, 1.0)
				var sp := p + Vector2((-30.0 + s * 18.0 + sin(ph * 6.0 + s) * 8.0) * k, (-200.0 - ph * 90.0) * k)
				draw_circle(sp, (10.0 + ph * 16.0) * k, Color(1, 1, 1, 0.18 * (1.0 - ph) * fade))
		Kind.TUK:
			var bob := absf(sin(_anim_t * 18.0)) * 4.0 * k
			_spr(self, "tuk_tuk_front", 0, p - Vector2(0, bob), Vector2(k, k), col)
		Kind.DOG:
			_spr(self, "soi_dog", 1 if d < DOG_WAKE else 0, p, Vector2(k, k), col)
		Kind.STRAY:
			var moving := absf(mover_lane(it, d + 0.05, relaxed) - lp) > 0.001
			var dir := signf(float(it["lane"]) - float(it["from"]))
			var fr := int(_anim_t * 8.0) % 2 if moving else 1
			_spr(self, "soi_dog_trot", fr, p, Vector2(k * (dir if dir != 0.0 else 1.0), k), col)
		Kind.LIZARD:
			var dir := signf(float(it["lane"]) - float(it["from"]))
			var fr := 1 if fposmod(_anim_t, 1.1) < 0.25 else 0          # tongue flick
			var wig := sin(_anim_t * 9.0) * 0.04
			var lk := k * 0.85
			draw_set_transform(p, wig, Vector2(lk * dir, lk))
			var m := sprite_meta("monitor_lizard")
			var tex := _t("monitor_lizard.png")
			if tex != null and not m.is_empty():
				var a := Vector2(m["anchor_px"][0], m["anchor_px"][1])
				draw_texture_rect_region(tex, Rect2(-a, Vector2(m["frame_w"], m["frame_h"])),
					Rect2(fr * float(m["frame_w"]), 0, m["frame_w"], m["frame_h"]), col)
			draw_set_transform(Vector2.ZERO)
		Kind.KERB:
			_spr(self, "kerb", 0, p, Vector2(k, k), col)


func _draw_runner() -> void:
	var p := runner_px()
	var sc := art_scale()
	var prog := 1.0 - hop_t / HOP_SECONDS if airborne() else 0.0
	var lift := sin(clampf(prog, 0.0, 1.0) * PI) * hop_lift_px()
	# shadow stays on the road and shrinks with the hop
	var sh := 1.0 - 0.4 * (lift / maxf(1.0, hop_lift_px()))
	draw_set_transform(p + Vector2(0, 4), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 58.0 * sc * sh, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	# lane dash streak
	if _dash_t > 0.0:
		var a := _dash_t / DASH_SECONDS
		var x0 := _pt(0.0, _dash_from * 2.0).x
		for i in 3:
			var y := p.y - lift - (50.0 + i * 50.0) * sc
			draw_line(Vector2(x0, y), Vector2(p.x, y), Color(UI.CYAN, 0.55 * a), maxf(2.0, (8.0 - i * 2.0) * sc))
	if bump_t > 0.0 and int(bump_t * 10.0) % 2 == 0:
		return
	var fr := int(dist * 8.0) % 4 if state == State.RUNNING or state == State.DOOR else 0
	if airborne():
		fr = 4 if prog < 0.35 else 5
	var sq := fx().squash_scale("runner")
	var col := Color(1, 0.55, 0.55) if bump_t > 0.0 else Color.WHITE
	_spr(self, "runner", fr, p - Vector2(0, lift), Vector2(sc * sq.x, sc * sq.y), col)


## Your best run tonight, a faint runner on the lane it took at this point of the street.
func _draw_ghost() -> void:
	if ghost.is_empty() or state != State.RUNNING:
		return
	var gl := ghost_lane_at(dist)
	if is_nan(gl):
		return
	var p := _pt(0.0, gl * 2.0)
	var sc := art_scale()
	if _sprites():
		_spr(self, "runner", int(dist * 8.0) % 4, p, Vector2(sc, sc), Color(0.75, 0.9, 1.0, 0.35))
	else:
		draw_rect(Rect2(p + Vector2(-30, -200), Vector2(60, 200)), Color(0.75, 0.9, 1.0, 0.3))


func _draw_rivals() -> void:
	# §4.1: tonight's regular to beat, and you
	if not rival.is_empty():
		var rc := UI.GOLD if rival_passed else UI.CREAM
		_text_right(S.t("mg.rivals.to_beat"), Vector2(size.x - 20.0, 120.0), 20, UI.SMOKE)
		_text_right("%s %d" % [str(rival.get("name", "")), int(rival.get("points", 0))], Vector2(size.x - 20.0, 152.0), 28, rc)
		_text_right(S.t("mg.rivals.you_now", {"score": live_points()}), Vector2(size.x - 20.0, 180.0), 22, UI.GOLD if rival_passed else UI.SMOKE)


func _draw_puffs() -> void:
	for pf in _puffs:
		var u: float = pf["t"] / PUFF_SECONDS
		var sc := art_scale() * float(pf["size"])
		for side in [-1.0, 1.0]:
			for i in 2:
				var c := Vector2(pf["pos"]) + Vector2(side * (30.0 + u * 70.0 + i * 20.0), -8.0 - u * 20.0 - i * 6.0) * sc
				draw_circle(c, (14.0 + u * 14.0 - i * 4.0) * sc, Color(0.75, 0.68, 0.62, 0.45 * (1.0 - u)))


func _draw_glow() -> void:
	if size.x <= 0.0 or not _sprites():
		return
	for s in _shops():
		var flick := 0.55 + 0.15 * sin(_anim_t * 3.0 + float(s["frame"]) * 2.0)
		_spr(_glow, "shopfront", s["frame"], s["pos"], s["sc"], Color(1, 1, 1, flick), true)
	var left := RUN_SECONDS * SPEED - dist + DOOR_AHEAD
	if left < VIEW + 1.0:
		var sc := art_scale() * _k(left) * 1.2
		var open := state == State.DOOR or state == State.DONE
		var a := 0.7 + (0.3 * minf(1.0, door_t * 4.0) if open else 0.15 * sin(_anim_t * 4.0))
		_spr(_glow, "door_front", 1 if open else 0, _pt(left, 0.0), Vector2(sc, sc), Color(1, 1, 1, a), true)
	for it in _visible():
		var d := float(it["at"]) - dist
		var dd := drawn_dist(it, d, relaxed)
		var p := _pt(dd, mover_lane(it, d, relaxed) * 2.0)
		var k := art_scale() * _k(dd)
		match int(it["kind"]):
			Kind.NOTE:
				var bob := sin(_anim_t * 6.0 + float(it["at"]) * 3.0) * 8.0 * k
				_spr(_glow, "note", 0, p - Vector2(0, 90.0 * k + bob), Vector2(k, k), Color(1, 1, 1, 0.8), true)
			Kind.TUK:
				_spr(_glow, "tuk_tuk_front", 0, p, Vector2(k, k), Color(1, 1, 1, 0.9), true)
				Fx.draw_glow(_glow, p + Vector2(10.0, -60.0) * k, 90.0 * k, Color(1.0, 0.85, 0.5, 0.35))


## No textures (a stripped build): the 0.3.1 flat shapes.
func _draw_flat() -> void:
	var horizon := size.y * 0.16
	draw_rect(Rect2(0, 0, size.x, size.y), Color("140A0C"))
	var road := PackedVector2Array([_pt(VIEW, -3.0), _pt(VIEW, 3.0), _pt(-0.2, 3.0), _pt(-0.2, -3.0)])
	draw_colored_polygon(road, Color("24141A"))
	for l in [-0.5, 0.5]:
		draw_line(_pt(VIEW, l * 2.0), _pt(-0.2, l * 2.0), UI.LINE, 4.0)
	UI.draw_text(self, "BLACK CABIN", Vector2(size.x * 0.5, horizon - 10), 40, Color(UI.NEON, 0.6))
	for it in _visible():
		var d := float(it["at"]) - dist
		var p := _pt(drawn_dist(it, d, relaxed), mover_lane(it, d, relaxed) * 2.0)
		var s := (p.y - horizon) / (size.y * 0.7)
		var c := UI.ASH
		match int(it["kind"]):
			Kind.NOTE: c = UI.GOLD
			Kind.BIKE: c = UI.CYAN
			Kind.CART: c = UI.AMBER
			Kind.TUK: c = UI.RED_HI
			Kind.DOG, Kind.STRAY: c = Color("C4A07A")
			Kind.LIZARD: c = Color("4E5638")
		var h := 120.0 if not hoppable(int(it["kind"])) else 34.0
		draw_rect(Rect2(p + Vector2(-50, -h) * s, Vector2(100, h) * s), c)
	var p := runner_px()
	var lift := sin(clampf(hop_t / HOP_SECONDS, 0.0, 1.0) * PI) * 110.0
	if not (bump_t > 0.0 and int(bump_t * 10.0) % 2 == 0):
		draw_rect(Rect2(p + Vector2(-30, -200 - lift), Vector2(60, 200)), UI.RED)
	_draw_ghost()
	_draw_rivals()
	UI.draw_text(self, S.t("mg.soi_dash.clock", {"clock": clock_text(clock)}), clock_px(), 40, UI.GOLD if clock > 5.0 else UI.NEON)


func _text_right(text: String, pos: Vector2, size_px: int, col: Color) -> void:
	var theme := ThemeDB.get_project_theme()
	var font: Font = theme.default_font if theme != null and theme.default_font != null else ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string_outline(font, pos - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 6, Color(0, 0, 0, 0.7))
	draw_string(font, pos - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
