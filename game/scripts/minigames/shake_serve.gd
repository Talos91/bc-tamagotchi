extends "res://scripts/minigames/minigame_base.gd"
## Shake & Serve (GDD §9 #2; docs/design/10-minigame-next.md concept B; quality pass Q7, docs/design/11-minigame-quality.md
## §1.2, §2.3, §3, §4.1). At the bar: Nam takes order after order by mood. The recipe shows, then you pick its bottles off the
## backlit shelf in order (each one flies to the shaker and pours), and shake on Nam's nods; the drink slides down the
## bar. The spirits are real bottles from the Black Cabin menu (Pour Perfect's featured drinks); the mixes are classic
## house mixes, labelled as such, until the bar's own cocktail page arrives (a pending fact).
##
## Difficulty rises one level per order (Daniele 2026-11-18: "difficulty levels (more ingredients)"):
##   1 Easy pour      2 bottles (spirit + mixer), 4 nods 0.60 s apart
##   2 House mix      3 bottles, 4 nods 0.55 s apart
##   3 Nam's special  4 bottles, the shelf is restocked in a new order, 6 nods 0.50 s apart
## Endless ramp (docs/design/15-minigame-ramp.md; Daniele 2026-11-20 "increasingly harder and faster (but humanly
## possible not impossible)"): the orders keep coming. From order 4 every order is a 4-bottle special (picked per night,
## round and order), the shelf is restocked every order, and step by step to order 9 (the cap, level 9): the recipe
## look 2.0 -> 1.5 s, pick time 12 -> 7 s, nods 6 -> 8, nod gap 0.50 -> 0.38 s. Level = the order number (cap 9).
## Relaxed timing keeps its slack at every level: the beat window 0.22 -> 0.33 s and the recipe look +1 s.
##
## Per order: recipe 0.6 (-0.2 per wrong bottle) + shake 0.4 x beat accuracy (order_score). An order under 0.5 is sent
## back by Nam (a strike); the third sent back ends the round (lose()). Points = sum of round(33 x order score)
## (uncapped record; 3 perfect orders = 99); the need gain reads score = min(1, points / 100). Feeds the existing action
## "pour_perfect" (Drinks +20-30); a great score or better also earns "shake_serve_friends" (Friends +5) through result
## extra.bonus_action. Shares the bar's 3 tries with Pour Perfect.
## Competition (§4.1) through mg_rivals.gd: tonight's regular to beat in the HUD, the board place on the result.
## Art: look B sprites in game/assets/minigames/shake_serve/ (flat drawing only as a fallback when art is missing).

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const BarMenu = preload("res://scripts/menu/bar_menu.gd")
const Rivals = preload("res://scripts/minigames/mg_rivals.gd")

const ART_DIR := "res://assets/minigames/shake_serve/"
const FIELD := Vector2(720, 1280)

const MEMO_SECONDS := 2.0
const MEMO_RELAXED_EXTRA := 1.0
const PICK_SECONDS := 12.0           ## per order; time out = the missing bottles count as wrong
const BEATS := 4                     ## level 1's nods (kept for older callers)
const BEAT_GAP := 0.55               ## level 2's gap (kept for older callers)
const BEAT_LEAD := 0.8               ## from the last bottle to the first nod
const BEAT_WINDOW := 0.22            ## a tap this far off a nod scores 0 for that beat
const BEAT_WINDOW_RELAXED := 0.33
const SERVE_SECONDS := 1.2
const INTRO_SECONDS := 1.0
const WRONG_COST := 0.2
const RECIPE_PART := 0.6
const SHAKE_PART := 0.4
const POUR_SECONDS := 0.45           ## a picked bottle flies to the shaker and pours
const NOD_SHOW := 0.14               ## Nam's head is down this long around each nod
const BONUS_ACTION := "shake_serve_friends"
## Endless ramp (15-minigame-ramp; Daniele 2026-11-20), from order 4 (index 3) in RAMP_STEPS even steps to the cap.
## why: 1.5 s still reads 4 chips; 7 s picks 4 bottles; 0.38 s nods = 158 a minute, slower than a fast clap.
const RAMP_STEPS := 6                ## orders 4..9; order 9 is the cap
const RAMP_MEMO_END := 1.5
const RAMP_PICK_END := 7.0
const RAMP_BEATS_END := 8
const RAMP_GAP_END := 0.38
const LEVEL_CAP := 9                 ## level = the order number, up to order 9
## why: an order under half (a wrong bottle and a sloppy shake, or a timeout) is a drink Nam would not serve.
const SEND_BACK_BELOW := 0.5
const POINTS_PER_ORDER := 33.0       ## 3 perfect orders = 99 = a perfect old round
## The three opening levels, one per order (index = order); from order 4 on, level 3 with the ramp's numbers.
const LEVELS := [
	{"key": "easy", "bottles": 2, "beats": 4, "gap": 0.60, "restock": false},
	{"key": "house", "bottles": 3, "beats": 4, "gap": 0.55, "restock": false},
	{"key": "special", "bottles": 4, "beats": 6, "gap": 0.50, "restock": true},
]
## Shelf: five spirits (their family in BarMenu.pour_families) and seven mixers, in shelf order (= bottles.png frames).
const SPIRITS := ["gin", "vodka", "rum", "tequila", "whisky"]
const MIXERS := ["lime", "sugar", "soda", "tonic", "ginger", "bitters", "cola"]
## Shelf spirit -> BarMenu pour family id, where they differ.
const FAMILY_IDS := {"tequila": "tequila_mezcal"}
## Classic house mixes per level: [mood line key, spirit family, mixers...] (2, 3 and 4 bottles; orders 4+ use level 3's).
const LEVEL_RECIPES := [
	[
		["gin_tonic", "gin", "tonic"],
		["rum_cola", "rum", "cola"],
		["whisky_soda", "whisky", "soda"],
		["vodka_soda", "vodka", "soda"],
		["tequila_soda", "tequila", "soda"],
	],
	[
		["sour", "whisky", "lime", "sugar"],
		["tonic", "gin", "tonic", "lime"],
		["mule", "vodka", "lime", "ginger"],
		["old_fashioned", "whisky", "sugar", "bitters"],
		["paloma", "tequila", "lime", "soda"],
		["libre", "rum", "cola", "lime"],
		["daiquiri", "rum", "lime", "sugar"],
		["highball", "gin", "soda", "lime"],
	],
	[
		["whisky_sour", "whisky", "lime", "sugar", "bitters"],
		["collins", "gin", "lime", "sugar", "soda"],
		["rum_fizz", "rum", "lime", "sugar", "soda"],
		["tequila_fizz", "tequila", "lime", "sugar", "soda"],
		["gin_mule", "gin", "lime", "sugar", "ginger"],
		["stormy", "rum", "lime", "ginger", "bitters"],
	],
]
## Glass per mix (glass_<kind>.png); highball when not listed.
const GLASS := {"sour": "rocks", "old_fashioned": "rocks", "whisky_sour": "rocks", "daiquiri": "coupe",
	"tequila_fizz": "coupe", "whisky_soda": "rocks"}

# Layout in field px (FIELD fits the play area; the backdrop covers the rest).
const NAM_POS := Vector2(118, 268)           ## neck
const SPR_NAM := 1.55
const BUBBLE := Rect2(214, 132, 486, 150)
const CHIP_Y := 340.0
const CHIP_W := 150.0
const CHIP_GAP := 12.0
const SHELF_Y := [628.0, 862.0]              ## shelf boards (bottle bottoms)
const SHELF_X0 := 85.0
const SHELF_DX := 110.0
const SPR_BOTTLE := 1.0
const BAR_Y := 1122.0                        ## the bar top's front edge
const SHAKER_POS := Vector2(300, 1112)       ## bottom centre
const SPR_SHAKER := 0.78
const SPR_GLASS := 1.25
const SERVE_FROM := 300.0
const SERVE_TO := 610.0
const RING_Y := 1242.0

enum State { INTRO, MEMO, PICK, SHAKE, SERVE, DONE }

var state := State.INTRO
var order := 0                       ## index of the current order (0 = the first); the level is order + 1, capped
var step := 0                        ## bottles picked right in this order
var wrongs := 0
var taps: Array[float] = []          ## shake tap times (since the shake began)
var order_scores: Array[float] = []
var lives_left := STRIKES            ## orders Nam may still send back before the round is lost
var sent_back := 0
var shelf_order: Array = []          ## shelf ids in slot order (restocked from level 3, every order)
var flash := ""                      ## shelf id flashing (wrong pick)
var flash_t := 0.0
var rival: Dictionary = {}           ## tonight's regular to beat {regular, name, points}
var rival_passed := false
var rivals_store: Object = null      ## tests: where mg_rivals keeps tonight's record (default Needs, else memory)
var pours: Array = []                ## [{id, from, t}] bottles flying to the shaker and pouring
var nam_face := 0                    ## 0 up, 2 smile, 3 frown (nam.png frames); the nod frame is timed
var nam_face_t := 0.0
var rattle_t := 0.0                  ## the shelf rattles after a wrong bottle
var shake_anim := 0.0                ## > 0 while the shaker swings after a tap
var level_banner_t := 0.0
var _record: Dictionary = {}
var _recipe: Array = []              ## the current order's recipe row (generated per order, never a whole list)
var _night := 0
var _round_n := 0
var _state_t := 0.0
var _anim_t := 0.0
var _art: Dictionary = {}            ## sprite name -> {tex, fw, fh, frames, anchor}


func _init() -> void:
	game_id = "shake_serve"
	action_id = "pour_perfect"
	need_id = "drinks"
	title_key = "mg.shake_serve.title"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _on_start() -> void:
	state = State.INTRO
	order = 0
	step = 0
	wrongs = 0
	taps.clear()
	order_scores.clear()
	lives_left = STRIKES
	sent_back = 0
	pours.clear()
	_state_t = 0.0
	_anim_t = 0.0
	nam_face = 0
	rattle_t = 0.0
	shake_anim = 0.0
	level_banner_t = 0.0
	_record = {}
	_night = int(config.get("night", BarMenu.night_of(Time.get_unix_time_from_system())))
	_round_n = int(config.get("n", 0))
	_recipe = order_at(_night, _round_n, 0)
	shelf_order = shelf()
	var t := Rivals.tonight(game_id, rivals_store)
	rival = t["rival"]
	rival_passed = false
	_load_art()
	_update_status()
	queue_redraw()


# --- Rules (static where the tests pin them) -------------------------------------------------------

## One mix per level for a night and the n-th round of the visit (same for everyone on a night; the next round brings
## other mixes).
static func pick_orders(night: int, n := 0) -> Array:
	var out: Array = []
	for k in LEVELS.size():
		out.append(order_at(night, n, k))
	return out


## The recipe of order i (0-based) for a night and the n-th round: orders 1-3 one per level (as before), then level 3's
## mixes in a seeded order per block of six, never the same mix twice in a row.
static func order_at(night: int, n: int, i: int) -> Array:
	if i < LEVELS.size():
		var list: Array = LEVEL_RECIPES[i]
		return list[posmod(night * 3 + n + i * 7, list.size())]
	var top: Array = LEVEL_RECIPES[LEVELS.size() - 1]
	var b := (i - LEVELS.size()) / top.size()
	var p := _shuffled_mixes(night, n, b, top.size())
	var prev: int
	if b > 0:
		prev = _shuffled_mixes(night, n, b - 1, top.size())[top.size() - 1]
	else:
		prev = posmod(night * 3 + n + (LEVELS.size() - 1) * 7, top.size())
	if p[0] == prev:
		var tmp := p[0]
		p[0] = p[1]
		p[1] = tmp
	return top[p[(i - LEVELS.size()) % top.size()]]


## Indexes 0..size-1 in a seeded order (block b of the endless orders of a night and round).
static func _shuffled_mixes(night: int, n: int, b: int, size_n: int) -> Array[int]:
	var out: Array[int] = []
	for k in size_n:
		out.append(k)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("shake_serve_orders_%d_%d_%d" % [night, n, b])
	for k in range(size_n - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp := out[k]
		out[k] = out[j]
		out[j] = tmp
	return out


## Every mix of every level (strings, tests).
static func all_recipes() -> Array:
	var out: Array = []
	for list in LEVEL_RECIPES:
		out.append_array(list)
	return out


## A fresh array each call (a folded constant would be shared and could be sorted or shuffled in place).
static func shelf() -> Array:
	var out: Array = []
	out.append_array(SPIRITS)
	out.append_array(MIXERS)
	return out


## The restocked shelf of order order_i (level 3 = index 2, then every order): the same twelve bottles in a new order, seeded
## by the night and the order (same for everyone).
static func restocked(night: int, order_i := 2) -> Array:
	var ids := shelf()
	var rng := RandomNumberGenerator.new()
	if order_i <= LEVELS.size() - 1:
		rng.seed = hash("shake_serve_restock_%d" % night)
	else:
		rng.seed = hash("shake_serve_restock_%d_%d" % [night, order_i])
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	if str(ids) == str(shelf()):
		ids.reverse()
	return ids


static func level(i: int) -> Dictionary:
	return LEVELS[clampi(i, 0, LEVELS.size() - 1)]


## Steps into the endless ramp of order i: 0 for orders 1-3, then 1..RAMP_STEPS (capped at order 9).
static func ramp_step(i: int) -> int:
	return clampi(i - (LEVELS.size() - 1), 0, RAMP_STEPS)


static func _ramp_t(i: int) -> float:
	return float(ramp_step(i)) / float(RAMP_STEPS)


## Nods of order i: the opening levels, then 6 -> 8.
static func beats_of(i: int) -> int:
	if i < LEVELS.size():
		return int(level(i)["beats"])
	return roundi(lerpf(float(level(i)["beats"]), float(RAMP_BEATS_END), _ramp_t(i)))


## Seconds between the nods of order i: the opening levels, then 0.50 -> 0.38.
static func gap_of(i: int) -> float:
	if i < LEVELS.size():
		return float(level(i)["gap"])
	return lerpf(float(level(i)["gap"]), RAMP_GAP_END, _ramp_t(i))


## The recipe look of order i before relaxed timing: 2.0 s, then 2.0 -> 1.5 from order 4.
static func memo_at(i: int) -> float:
	return lerpf(MEMO_SECONDS, RAMP_MEMO_END, _ramp_t(i))


## Pick time of order i: 12 s, then 12 -> 7 from order 4.
static func pick_at(i: int) -> float:
	return lerpf(PICK_SECONDS, RAMP_PICK_END, _ramp_t(i))


static func bottles_of(i: int) -> int:
	return int(level(i)["bottles"])


## Order i restocks the shelf (level 3, and every order after it).
static func restocks(i: int) -> bool:
	return i >= LEVELS.size() - 1


## The ramp level of order i: the order number, capped at LEVEL_CAP.
static func level_of_order(i: int) -> int:
	return mini(i + 1, LEVEL_CAP)


## The real bottle Nam pours for a spirit family (Pour Perfect's featured drink of that family), or "".
static func bottle_of(family: String) -> String:
	var fam: String = FAMILY_IDS.get(family, family)
	for f in BarMenu.pour_families():
		if str(f.get("id", "")) == fam:
			return str(f.get("drink", ""))
	return ""


static func beat_accuracy(offset: float, window := BEAT_WINDOW) -> float:
	return clampf(1.0 - absf(offset) / window, 0.0, 1.0)


## Recipe part minus the wrong bottles, plus the shake part times the mean beat accuracy (any number of nods).
static func order_score(wrong: int, beat_accs: Array) -> float:
	var acc := 0.0
	for a in beat_accs:
		acc += float(a)
	acc = acc / maxf(1.0, float(beat_accs.size()))
	return clampf(maxf(0.0, RECIPE_PART - WRONG_COST * wrong) + SHAKE_PART * acc, 0.0, 1.0)


## Nam sends an order back below SEND_BACK_BELOW (a strike).
static func sent_back_for(score: float) -> bool:
	return score < SEND_BACK_BELOW


static func order_points(score: float) -> int:
	return roundi(POINTS_PER_ORDER * clampf(score, 0.0, 1.0))


## Record points of a list of order scores (uncapped).
static func points_of(scores: Array) -> int:
	var p := 0
	for v in scores:
		p += order_points(float(v))
	return p


func record_points() -> int:
	return points_of(order_scores)


func current_score() -> float:
	return score_of(record_points())


func live_points() -> int:
	return record_points()


func recipe() -> Array:
	return _recipe


func bottles_needed() -> int:
	return maxi(0, recipe().size() - 1)


## The shelf id the current order needs next ("" outside PICK).
func wanted() -> String:
	return str(recipe()[1 + step]) if state == State.PICK and step < bottles_needed() else ""


## Seconds of nod i after the shake began, at level lv (default: the current order's level).
func nod_time(i: int, lv := -1) -> float:
	return BEAT_LEAD + i * gap_of(order if lv < 0 else lv)


func beat_window() -> float:
	return BEAT_WINDOW_RELAXED if relaxed else BEAT_WINDOW


func memo_seconds() -> float:
	return memo_at(order) + (MEMO_RELAXED_EXTRA if relaxed else 0.0)


# --- Play ------------------------------------------------------------------------------------------

func pick(id: String) -> void:
	if state != State.PICK or not running or paused:
		return
	if id == wanted():
		step += 1
		_juice_pour(id)
		if step >= bottles_needed():
			_begin_shake()
	else:
		wrongs += 1
		flash = id
		flash_t = 0.35
		_juice_wrong(id)
	_update_status()


func shake_tap() -> void:
	if state == State.SHAKE and running and not paused and taps.size() < beats_of(order):
		taps.append(_state_t)
		_juice_shake(taps.size() - 1)


func _begin_shake() -> void:
	state = State.SHAKE
	_state_t = 0.0
	taps.clear()


func _score_shake() -> Array:
	var w := beat_window()
	var accs: Array = []
	var used := {}
	for i in beats_of(order):
		var best := 0.0
		var best_j := -1
		for j in taps.size():
			if used.has(j):
				continue
			var a := beat_accuracy(taps[j] - nod_time(i), w)
			if a > best:
				best = a
				best_j = j
		if best_j >= 0:
			used[best_j] = true
		accs.append(best)
	return accs


func advance(dt: float) -> void:
	_state_t += dt
	_anim_t += dt
	flash_t = maxf(0.0, flash_t - dt)
	rattle_t = maxf(0.0, rattle_t - dt)
	shake_anim = maxf(0.0, shake_anim - dt)
	level_banner_t = maxf(0.0, level_banner_t - dt)
	nam_face_t = maxf(0.0, nam_face_t - dt)
	if nam_face_t <= 0.0:
		nam_face = 0
	for p in pours:
		p["t"] = float(p["t"]) + dt
	pours = pours.filter(func(p): return float(p["t"]) < POUR_SECONDS + 0.25)
	match state:
		State.INTRO:
			if _state_t >= INTRO_SECONDS:
				_next_memo()
		State.MEMO:
			if _state_t >= memo_seconds():
				state = State.PICK
				_state_t = 0.0
		State.PICK:
			if _state_t >= pick_at(order):
				wrongs += bottles_needed() - step  # the missing bottles count as wrong
				_begin_shake()
		State.SHAKE:
			var last := nod_time(beats_of(order) - 1)
			if _state_t >= last + BEAT_WINDOW_RELAXED + 0.1 or taps.size() >= beats_of(order) and _state_t > last:
				var sc := order_score(wrongs, _score_shake())
				order_scores.append(sc)
				state = State.SERVE
				_state_t = 0.0
				if sent_back_for(sc):
					sent_back += 1
					lives_left = maxi(0, STRIKES - sent_back)
				_juice_serve()
				_update_status()
		State.SERVE:
			if _state_t >= SERVE_SECONDS:
				if lives_left <= 0:
					state = State.DONE
					queue_redraw()
					lose()
					return
				order += 1
				_next_memo()
	queue_redraw()


func _next_memo() -> void:
	state = State.MEMO
	_state_t = 0.0
	step = 0
	wrongs = 0
	taps.clear()
	pours.clear()
	_recipe = order_at(_night, _round_n, order)
	if restocks(order):
		shelf_order = restocked(_night, order)
	if order > 0:
		level_up(level_of_order(order))
		_juice_level()
	_update_status()


# --- Juice (§2.3: every input answers) ----------------------------------------------------------------

## Bottle tap: the bottle lifts off the shelf, flies to the shaker and pours a splash.
func _juice_pour(id: String) -> void:
	var from := shelf_pos(id)
	pours.append({"id": id, "from": from, "t": 0.0})
	nam_face = 2
	nam_face_t = 0.35
	var f := fx()
	f.squash("bottle_" + id)
	f.flash("bottle_" + id)
	f.pop(_label_of(id), _xf() * chip_rect(step - 1).get_center() + Vector2(0, -40), UI.GOLD, 36)  # the real bottle
	f.burst("spark", _xf() * (SHAKER_POS + Vector2(0, -190)), 8)
	haptic("tick")


## Wrong bottle: the shelf rattles, the bottle flashes, Nam frowns, a short red edge.
func _juice_wrong(id: String) -> void:
	rattle_t = 0.3
	nam_face = 3
	nam_face_t = 0.6
	var f := fx()
	f.shake(Fx.TRAUMA_BUMP * 0.6)
	f.fail_edge()
	f.combo_break()
	f.pop(S.t("mg.shake_serve.wrong"), _xf() * (shelf_pos(id) + Vector2(0, -170)), UI.NEON, 36)
	haptic("fail")


## Shake tap: on a nod = splash particles + a tick + combo; off = a dim pop.
func _juice_shake(i: int) -> void:
	shake_anim = 0.3
	var f := fx()
	f.squash("shaker")
	var best := 0.0
	for k in beats_of(order):
		best = maxf(best, beat_accuracy(taps[i] - nod_time(k), beat_window()))
	var top := _xf() * (SHAKER_POS + Vector2(0, -210))
	if best >= 0.5:
		f.burst("spark", top, 10)
		f.flare(_xf() * ring_pos(mini(i, beats_of(order) - 1)), 60.0)
		f.combo_step("", _xf() * Vector2(118, BAR_Y - 130))
		f.pop(S.t("mg.shake_serve.on_beat"), top + Vector2(110, 0), UI.GOLD, 40)
		haptic("tick")
	else:
		f.combo_break()
		f.pop(S.t("mg.shake_serve.off_beat"), top + Vector2(110, 0), UI.SMOKE, 32)


## Serve: the glass slides down the bar, ice clinks, Nam reacts, the order's points pop. Under half: Nam frowns and
## sends it back (a strike: the red edge, a double buzz, the lives left).
func _juice_serve() -> void:
	var sc: float = order_scores[order_scores.size() - 1]
	nam_face = 2 if sc >= TIER_GREAT else 3
	nam_face_t = SERVE_SECONDS
	var f := fx()
	var at := _xf() * Vector2(SERVE_TO, BAR_Y - 80)
	f.pop("+%d" % order_points(sc), at + Vector2(0, -60), UI.GOLD if sc >= TIER_GREAT else UI.CREAM, 52)
	f.burst("spark", at, 6)
	if sent_back_for(sc):
		f.pop(S.t("mg.shake_serve.sent_back"), _xf() * Vector2(FIELD.x * 0.5, 470.0), UI.NEON, 48)
		if lives_left > 0:
			var strike := S.t("mg.ramp.last") if lives_left == 1 else S.t("mg.ramp.strike", {"lives": lives_left})
			f.pop(strike, _xf() * Vector2(FIELD.x * 0.5, 540.0), UI.AMBER, 40)
		f.shake(Fx.TRAUMA_LOSS if lives_left <= 0 else Fx.TRAUMA_BUMP)
		f.fail_edge()
		f.combo_break()
		haptic("fail")
	elif sc >= TIER_PERFECT:
		f.burst("confetti", at, 16)
		f.hit_stop()
		haptic("strong")
	else:
		haptic("tick")
	# §4.1: passing tonight's regular in play
	if not rival_passed and not rival.is_empty() and record_points() > int(rival.get("points", 0)):
		rival_passed = true
		f.pop(S.t("mg.rivals.passed", {"regular": str(rival.get("name", ""))}), _xf() * Vector2(FIELD.x * 0.5, 420.0), UI.NEON, 44)


## A new order: banner, a gold flare, and from level 3 the restocked shelf.
func _juice_level() -> void:
	level_banner_t = 1.4
	var f := fx()
	f.flare(_xf() * Vector2(FIELD.x * 0.5, 80.0), 220.0, UI.AMBER)
	if restocks(order):
		f.pop(S.t("mg.shake_serve.restock"), _xf() * Vector2(FIELD.x * 0.5, 712.0), UI.NEON, 40)
		f.burst("spark", _xf() * Vector2(FIELD.x * 0.5, SHELF_Y[0]), 12)
	haptic("tick")



func _result_extra() -> Dictionary:
	if _record.is_empty():
		_record = Rivals.record(game_id, record_points(), {}, rivals_store)
	var extra := {"orders": order_scores.duplicate(), "level": ramp_level, "speed": snappedf(gap_of(order), 0.01),
		"misses": sent_back, "sent_back": sent_back, "rival": rival, "board": _record["board_line"]}
	if current_score() >= TIER_GREAT:
		extra["bonus_action"] = BONUS_ACTION
	return extra


func _update_status() -> void:
	set_status(S.t("mg.ramp.status", {"level": ramp_level, "points": record_points(), "lives": lives_left}))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if state == State.SHAKE:
			shake_tap()
		elif state == State.PICK:
			var id := shelf_at(event.position)
			if id != "":
				pick(id)


# --- Layout ----------------------------------------------------------------------------------------

func _xf() -> Transform2D:
	var k := minf(size.x / FIELD.x, size.y / FIELD.y)
	var off := (size - FIELD * k) * 0.5
	return Transform2D(0.0, Vector2(k, k), 0.0, off)


## Field position (bottom centre) of a shelf slot.
static func slot_pos(i: int) -> Vector2:
	return Vector2(SHELF_X0 + (i % 6) * SHELF_DX, SHELF_Y[i / 6])


func shelf_pos(id: String) -> Vector2:
	var i := shelf_order.find(id)
	return slot_pos(maxi(0, i))


## Tap target of a shelf slot in field px (the bottle plus its label).
static func slot_rect(i: int) -> Rect2:
	var p := slot_pos(i)
	return Rect2(p.x - SHELF_DX * 0.5, p.y - 160.0, SHELF_DX, 196.0)


## Shelf id under a screen point ("" when none).
func shelf_at(p: Vector2) -> String:
	var q := _xf().affine_inverse() * p
	for i in shelf_order.size():
		if slot_rect(i).has_point(q):
			return str(shelf_order[i])
	return ""


## Recipe chip k of the current order, in field px.
func chip_rect(k: int) -> Rect2:
	var n := maxi(1, bottles_needed())
	var x0 := FIELD.x * 0.5 - (n * CHIP_W + (n - 1) * CHIP_GAP) * 0.5
	return Rect2(x0 + k * (CHIP_W + CHIP_GAP), CHIP_Y, CHIP_W, 84)


func ring_pos(i: int) -> Vector2:
	var n := beats_of(order)
	return Vector2(FIELD.x * 0.5 + (i - (n - 1) * 0.5) * 92.0, RING_Y)


func _label_of(id: String) -> String:
	if id in SPIRITS:
		var b := bottle_of(id)
		if b != "" and BarMenu.has(b):
			return BarMenu.name_of(b)
	return S.t("mg.shake_serve.bottle." + id)


func _short_label(id: String) -> String:
	if id in SPIRITS:
		return S.t("mg.shake_serve.bottle." + id)
	return _label_of(id)


func glass_kind() -> String:
	var r := recipe()
	return str(GLASS.get(str(r[0]), "highball")) if not r.is_empty() else "highball"


## Nam's frame now: the nod frame around each nod while shaking, else the face set by the last beat.
func nam_frame() -> int:
	if state == State.SHAKE:
		for i in beats_of(order):
			if absf(_state_t - nod_time(i)) <= NOD_SHOW * 0.5:
				return 1
	return nam_face


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
		var names: Variant = m.get("frame_names")
		_art[name] = {"tex": load(path), "fw": float(m["frame_w"]), "fh": float(m["frame_h"]),
			"frames": int(m.get("frames", 1)), "anchor": Vector2(float(a[0]), float(a[1])),
			"names": names if names is Array else []}


## Sprites the game draws with (the tests check them; the flat drawing is only a fallback when art is missing).
func has_art() -> bool:
	for n in ["bottles", "shaker", "nam", "bar_top", "backdrop", "glass_highball", "glass_rocks", "glass_coupe"]:
		if not _art.has(n):
			return false
	return int(_art["nam"]["frames"]) >= 4


func _frame_of(name: String, frame_name: String) -> int:
	var a: Dictionary = _art.get(name, {})
	var names: Array = a.get("names", [])
	return maxi(0, names.find(frame_name))


func _blit(name: String, frame: int, pos: Vector2, sc: float, col := Color.WHITE, rot := 0.0, sq := Vector2.ONE) -> void:
	var a: Dictionary = _art.get(name, {})
	if a.is_empty():
		return
	var fw: float = a["fw"]
	var fh: float = a["fh"]
	var fr := clampi(frame, 0, int(a["frames"]) - 1)
	draw_set_transform_matrix(_xf() * Transform2D(rot, Vector2(sc, sc) * sq, 0.0, pos))
	draw_texture_rect_region(a["tex"], Rect2(-a["anchor"], Vector2(fw, fh)), Rect2(fr * fw, 0.0, fw, fh), col)
	draw_set_transform_matrix(_xf())


# --- Drawing ---------------------------------------------------------------------------------------

func _draw() -> void:
	if size.x <= 0.0:
		return
	_draw_backdrop()
	draw_set_transform_matrix(_xf())
	_draw_hud()
	_draw_nam()
	_draw_chips()
	_draw_shelf()
	_draw_bar()
	_draw_pours()
	_draw_rings()
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_backdrop() -> void:
	var bd: Dictionary = _art.get("backdrop", {})
	if bd.is_empty():
		draw_rect(Rect2(Vector2.ZERO, size), UI.BG_DEEP)
		return
	var tex: Texture2D = bd["tex"]
	var ts := Vector2(bd["fw"], bd["fh"])
	var k := maxf(size.x / ts.x, size.y / ts.y)
	draw_texture_rect(tex, Rect2((size - ts * k) * 0.5, ts * k), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.18))


func _draw_hud() -> void:
	# lives: one pip per order Nam may still send back; then the level and its name (the banner grows on a new order)
	var lv := mini(order, LEVELS.size() - 1)
	for k in STRIKES:
		var c := Vector2(36 + k * 34, 46)
		draw_circle(c, 11.0, UI.GOLD if k < lives_left else UI.LINE)
	var grow := 1.0 + 0.5 * clampf(level_banner_t - 0.9, 0.0, 0.5) / 0.5
	var lname := S.t("mg.shake_serve.level", {"n": ramp_level, "name": S.t("mg.shake_serve.level." + str(level(lv)["key"]))})
	_text_left(lname, Vector2(20, 96), int(28 * grow), UI.GOLD if level_banner_t > 0.0 else UI.CREAM)
	if not rival.is_empty():
		var col := UI.GOLD if rival_passed else UI.CREAM
		_text_right(S.t("mg.rivals.to_beat"), Vector2(FIELD.x - 20.0, 34.0), 20, UI.SMOKE)
		_text_right("%s %d" % [str(rival.get("name", "")), int(rival.get("points", 0))], Vector2(FIELD.x - 20.0, 66.0), 30, col)
		_text_right(S.t("mg.rivals.you_now", {"score": record_points()}), Vector2(FIELD.x - 20.0, 96.0), 24, UI.GOLD if rival_passed else UI.SMOKE)


func _draw_nam() -> void:
	var fr := nam_frame()
	var bob := sin(_anim_t * 2.2) * 3.0
	if _art.has("nam"):
		_blit("nam", fr, NAM_POS + Vector2(0, bob), SPR_NAM)
	else:
		draw_circle(NAM_POS + Vector2(0, -60), 60.0, UI.AMBER)
	# speech bubble with the order
	var r := recipe()
	draw_rect(BUBBLE, Color(UI.BG_RAISED, 0.92))
	draw_rect(BUBBLE, UI.LINE, false, 3.0)
	var tip := PackedVector2Array([BUBBLE.position + Vector2(0, 60), BUBBLE.position + Vector2(-26, 84), BUBBLE.position + Vector2(0, 100)])
	draw_colored_polygon(tip, Color(UI.BG_RAISED, 0.92))
	_text_left(S.t("mg.shake_serve.nam"), BUBBLE.position + Vector2(20, 40), 26, UI.AMBER)
	if not r.is_empty() and state != State.INTRO:
		var line := S.t("mg.shake_serve.order." + str(r[0]))
		UI.draw_text(self, line, BUBBLE.position + Vector2(BUBBLE.size.x * 0.5, 104), _fit(line, 30, BUBBLE.size.x - 36.0), UI.CREAM)
	elif state == State.INTRO:
		UI.draw_text(self, S.t("mg.shake_serve.hint_memo"), BUBBLE.position + Vector2(BUBBLE.size.x * 0.5, 104), 30, UI.SMOKE)


## The recipe chips: every bottle of the mix in MEMO, then only the ones already poured.
func _draw_chips() -> void:
	var r := recipe()
	var n := bottles_needed()
	if r.is_empty() or n == 0 or state == State.INTRO:
		return
	var w := CHIP_W
	var gap := CHIP_GAP
	var x0 := chip_rect(0).position.x
	for k in n:
		var id := str(r[1 + k])
		var rect := chip_rect(k)
		var shown := state == State.MEMO or (state == State.PICK and k < step) or state == State.SHAKE or state == State.SERVE
		draw_rect(rect, Color(UI.AMBER, 0.9) if shown else Color(UI.BG_DEEP, 0.85))
		draw_rect(rect, UI.AMBER, false, 3.0)
		UI.draw_text(self, str(k + 1), rect.position + Vector2(16, 30), 22, UI.BG_DEEP if shown else UI.ASH)
		if shown:
			if _art.has("bottles"):
				_blit("bottles", shelf().find(id), rect.position + Vector2(34, 80), 0.45)
			var bname := _label_of(id)
			UI.draw_text(self, bname, rect.position + Vector2(w * 0.6, 54), _fit(bname, 22, w - 64.0), UI.BG_DEEP)
		else:
			UI.draw_text(self, "?", rect.get_center() + Vector2(0, 12), 34, UI.ASH)
	if state == State.MEMO:
		var left := 1.0 - _state_t / memo_seconds()
		draw_rect(Rect2(x0, CHIP_Y + 92, (n * w + (n - 1) * gap) * left, 6), UI.AMBER)


func _draw_shelf() -> void:
	# backlight and boards
	Fx.draw_glow(self, Vector2(FIELD.x * 0.5, 640), 420.0, Color(UI.AMBER, 0.22))
	for y in SHELF_Y:
		draw_rect(Rect2(20, y - 4, FIELD.x - 40, 12), Color("3A2A20"))
		draw_rect(Rect2(20, y - 4, FIELD.x - 40, 3), Color(UI.GOLD, 0.6))
	var flying := {}
	for p in pours:
		flying[str(p["id"])] = true
	var fx_ok := _fx != null and is_instance_valid(_fx)
	for i in shelf_order.size():
		var id := str(shelf_order[i])
		var pos := slot_pos(i)
		var rot := 0.0
		if rattle_t > 0.0:
			rot = sin(_anim_t * 70.0 + i) * 0.08 * (rattle_t / 0.3)
		var col := Color.WHITE
		if flash == id and flash_t > 0.0:
			col = Color(1.0, 0.45, 0.5)
		elif fx_ok:
			col = _fx.flash_color("bottle_" + id, Color.WHITE)
		if flying.has(id):
			col = Color(col, 0.25)   # its ghost stays on the shelf while the bottle pours
		var sq := _fx.squash_scale("bottle_" + id) if fx_ok else Vector2.ONE
		if _art.has("bottles"):
			_blit("bottles", shelf().find(id), pos, SPR_BOTTLE, col, rot, sq)
		else:
			draw_rect(Rect2(pos + Vector2(-24, -130), Vector2(48, 130)), Color(UI.AMBER, 0.7) * col)
		UI.draw_text(self, _short_label(id), pos + Vector2(0, 34), 20, UI.CREAM)


func _draw_bar() -> void:
	if _art.has("bar_top"):
		_blit("bar_top", 0, Vector2(FIELD.x * 0.5, BAR_Y), FIELD.x / 724.0 * 1.04)
	else:
		draw_rect(Rect2(0, BAR_Y - 40, FIELD.x, 90), Color("2A2420"))
	# shaker: still, a swing after each tap, a pour-ready wobble while bottles come in
	var fr := 1
	var rot := 0.0
	if shake_anim > 0.0:
		var cyc := [0, 1, 2, 3, 2, 1]
		fr = cyc[int((0.3 - shake_anim) * 30.0) % cyc.size()]
		rot = sin((0.3 - shake_anim) * 40.0) * 0.12
	var fx_ok := _fx != null and is_instance_valid(_fx)
	var sq := _fx.squash_scale("shaker") if fx_ok else Vector2.ONE
	if state != State.SERVE:
		if _art.has("shaker"):
			_blit("shaker", fr, SHAKER_POS, SPR_SHAKER, Color.WHITE, rot, sq)
		else:
			draw_rect(Rect2(SHAKER_POS + Vector2(-50, -170), Vector2(100, 170)), Color("B8B0A8"))
	# serve: the full glass slides down the bar; the shaker waits back at its spot
	if state == State.SERVE:
		if _art.has("shaker"):
			_blit("shaker", 1, SHAKER_POS + Vector2(-150, 0), SPR_SHAKER * 0.8, Color(1, 1, 1, 0.7))
		var t := clampf(_state_t / (SERVE_SECONDS * 0.55), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - t, 3.0)
		var gx := lerpf(SERVE_FROM, SERVE_TO, e)
		var g := "glass_" + glass_kind()
		if _art.has(g):
			_blit(g, 1, Vector2(gx, BAR_Y - 6), SPR_GLASS)
		else:
			draw_rect(Rect2(Vector2(gx - 26, BAR_Y - 110), Vector2(52, 104)), UI.AMBER)
	elif state == State.MEMO or state == State.PICK:
		var g := "glass_" + glass_kind()
		if _art.has(g):
			_blit(g, 0, Vector2(SERVE_FROM + 170, BAR_Y - 6), SPR_GLASS, Color(1, 1, 1, 0.85))


## Picked bottles: fly from the shelf to above the shaker (0.25 s), tip and pour a stream (rest of POUR_SECONDS).
func _draw_pours() -> void:
	var mouth := SHAKER_POS + Vector2(0, -205)
	for p in pours:
		var t := float(p["t"])
		var from: Vector2 = p["from"]
		var id := str(p["id"])
		var above := mouth + Vector2(58, -40)
		var k := clampf(t / 0.25, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 2.0)
		var pos := from.lerp(above, e) + Vector2(0, -sin(k * PI) * 80.0)
		var tip := clampf((t - 0.2) / 0.12, 0.0, 1.0)
		var back := clampf((t - POUR_SECONDS) / 0.25, 0.0, 1.0)
		var rot := -2.0 * tip * (1.0 - back)
		var alpha := 1.0 - back
		if _art.has("bottles"):
			_blit("bottles", shelf().find(id), pos, 0.85, Color(1, 1, 1, alpha), rot)
		if tip >= 1.0 and back <= 0.0:
			var col := Color(UI.AMBER, 0.85) if id in SPIRITS else Color(UI.CREAM, 0.8)
			if id == "cola":
				col = Color("5A2A18")
			elif id == "lime":
				col = Color("9ED36A")
			var wob := sin(_anim_t * 40.0) * 2.0
			draw_line(pos + Vector2(-46, -18), mouth + Vector2(wob, 0), col, 9.0)
			draw_circle(mouth, 12.0 + wob, Color(col, 0.6))


func _draw_rings() -> void:
	var hint := ""
	match state:
		State.MEMO:
			hint = S.t("mg.shake_serve.hint_memo")
		State.PICK:
			hint = S.t("mg.shake_serve.hint_pick")
		State.SHAKE:
			hint = S.t("mg.shake_serve.hint_shake")
		State.SERVE:
			hint = S.t("mg.shake_serve.served")
	if hint != "":
		UI.draw_text(self, hint, Vector2(FIELD.x * 0.5, RING_Y - 56), 30, UI.SMOKE)
	if state != State.SHAKE and state != State.SERVE:
		return
	for i in beats_of(order):
		var c := ring_pos(i)
		var lit := state == State.SHAKE and _state_t >= nod_time(i) - 0.05
		var near := state == State.SHAKE and absf(_state_t - nod_time(i)) < 0.12
		var r := 24.0 + (8.0 if near else 0.0)
		# the closing ring: shrinks onto the beat ring as the nod comes
		if state == State.SHAKE:
			var ahead := nod_time(i) - _state_t
			if ahead > 0.0 and ahead < 0.5:
				draw_arc(c, 24.0 + ahead * 90.0, 0, TAU, 32, Color(UI.CREAM, 0.6), 3.0, true)
		draw_arc(c, r, 0, TAU, 32, UI.AMBER if lit else UI.LINE, 5.0, true)
		if i < taps.size():
			draw_circle(c, 15, UI.AMBER)


## The largest font size up to `size_px` that fits `text` in `width` field px.
func _fit(text: String, size_px: int, width: float) -> int:
	var w := _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	return size_px if w <= width else maxi(14, int(floor(size_px * width / w)))


func _font() -> Font:
	var theme := ThemeDB.get_project_theme()
	return theme.default_font if theme != null and theme.default_font != null else ThemeDB.fallback_font


func _text_left(text: String, pos: Vector2, size_px: int, col: Color) -> void:
	var font := _font()
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 6, Color(0, 0, 0, 0.7))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func _text_right(text: String, pos: Vector2, size_px: int, col: Color) -> void:
	var font := _font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	_text_left(text, pos - Vector2(w, 0), size_px, col)
