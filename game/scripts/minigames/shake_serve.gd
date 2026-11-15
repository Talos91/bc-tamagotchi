extends "res://scripts/minigames/minigame_base.gd"
## Shake & Serve (GDD §9 #2; docs/design/10-minigame-next.md concept B; DECISIONS 2026-11-15 "build them all"). At the
## bar: Nam takes three orders by mood ("something sour, something bright"). The recipe shows for 2 s; then tap its
## three bottles on the backlit shelf in order, and shake on Nam's four nods. The spirits are real bottles from the
## Black Cabin menu (Pour Perfect's featured drinks); the mixes are classic house mixes, labelled as such, until the
## bar's own cocktail page arrives (a pending fact).
## Per order: recipe 0.6 (-0.2 per wrong bottle) + shake 0.4 x beat accuracy; round score = mean of the 3 orders.
## Feeds the existing action "pour_perfect" (Drinks +20-30); a great round or better also earns "shake_serve_friends"
## (Friends +5) through result extra.bonus_action. Shares the bar's 3 tries with Pour Perfect (Rules.MINIGAME_TRY_POOL).

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const BarMenu = preload("res://scripts/menu/bar_menu.gd")

const ORDERS := 3
const MEMO_SECONDS := 2.0
const PICK_SECONDS := 12.0           ## per order; time out = the missing bottles count as wrong
const BEATS := 4
const BEAT_GAP := 0.55               ## Nam's nods
const BEAT_LEAD := 0.8               ## from the last bottle to the first nod
const BEAT_WINDOW := 0.22            ## a tap this far off a nod scores 0 for that beat
const BEAT_WINDOW_RELAXED := 0.33
const SERVE_SECONDS := 0.9
const INTRO_SECONDS := 1.0
const WRONG_COST := 0.2
const RECIPE_PART := 0.6
const SHAKE_PART := 0.4
const BONUS_ACTION := "shake_serve_friends"
## Shelf: five spirits (their family in BarMenu.pour_families) and seven mixers, in shelf order.
const SPIRITS := ["gin", "vodka", "rum", "tequila", "whisky"]
const MIXERS := ["lime", "sugar", "soda", "tonic", "ginger", "bitters", "cola"]
## Shelf spirit -> BarMenu pour family id, where they differ.
const FAMILY_IDS := {"tequila": "tequila_mezcal"}
## Classic house mixes: [mood line key, spirit family, mixer, mixer].
const RECIPES := [
	["sour", "whisky", "lime", "sugar"],
	["tonic", "gin", "tonic", "lime"],
	["mule", "vodka", "lime", "ginger"],
	["old_fashioned", "whisky", "sugar", "bitters"],
	["paloma", "tequila", "lime", "soda"],
	["libre", "rum", "cola", "lime"],
	["daiquiri", "rum", "lime", "sugar"],
	["highball", "gin", "soda", "lime"],
]

enum State { INTRO, MEMO, PICK, SHAKE, SERVE, DONE }

var state := State.INTRO
var orders: Array = []               ## recipe rows for this round
var order := 0
var step := 0                        ## bottles picked right in this order
var wrongs := 0
var taps: Array[float] = []          ## shake tap times (since the shake began)
var order_scores: Array[float] = []
var flash := ""                      ## shelf id flashing (wrong pick)
var flash_t := 0.0
var _state_t := 0.0


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
	_state_t = 0.0
	orders = pick_orders(int(config.get("night", BarMenu.night_of(Time.get_unix_time_from_system()))), int(config.get("n", 0)))
	_update_status()
	queue_redraw()


# --- Rules (static where the tests pin them) -------------------------------------------------------

## Three different recipes for a night and the n-th round of the visit (same for everyone on a night).
static func pick_orders(night: int, n := 0) -> Array:
	var out: Array = []
	for k in ORDERS:
		out.append(RECIPES[posmod(night * 3 + n * ORDERS + k, RECIPES.size())])
	return out


static func shelf() -> Array:
	return SPIRITS + MIXERS


## The real bottle Nam pours for a spirit family (Pour Perfect's featured drink of that family), or "".
static func bottle_of(family: String) -> String:
	var fam: String = FAMILY_IDS.get(family, family)
	for f in BarMenu.pour_families():
		if str(f.get("id", "")) == fam:
			return str(f.get("drink", ""))
	return ""


static func beat_accuracy(offset: float, window := BEAT_WINDOW) -> float:
	return clampf(1.0 - absf(offset) / window, 0.0, 1.0)


static func order_score(wrong: int, beat_accs: Array) -> float:
	var acc := 0.0
	for a in beat_accs:
		acc += float(a)
	acc = acc / BEATS
	return clampf(maxf(0.0, RECIPE_PART - WRONG_COST * wrong) + SHAKE_PART * acc, 0.0, 1.0)


static func round_score(scores: Array) -> float:
	var s := 0.0
	for v in scores:
		s += float(v)
	return s / ORDERS


func current_score() -> float:
	return round_score(order_scores)


func recipe() -> Array:
	return orders[order] if order < orders.size() else []


## The shelf id the current order needs next ("" outside PICK).
func wanted() -> String:
	return str(recipe()[1 + step]) if state == State.PICK and step < 3 else ""


## Seconds of the nod i after the shake began.
static func nod_time(i: int) -> float:
	return BEAT_LEAD + i * BEAT_GAP


# --- Play ------------------------------------------------------------------------------------------

func pick(id: String) -> void:
	if state != State.PICK or not running or paused:
		return
	if id == wanted():
		step += 1
		if step >= 3:
			_begin_shake()
	else:
		wrongs += 1
		flash = id
		flash_t = 0.35
	_update_status()


func shake_tap() -> void:
	if state == State.SHAKE and running and not paused and taps.size() < BEATS:
		taps.append(_state_t)


func _begin_shake() -> void:
	state = State.SHAKE
	_state_t = 0.0
	taps.clear()


func _score_shake() -> Array:
	var w := BEAT_WINDOW_RELAXED if relaxed else BEAT_WINDOW
	var accs: Array = []
	var used := {}
	for i in BEATS:
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
	flash_t = maxf(0.0, flash_t - dt)
	match state:
		State.INTRO:
			if _state_t >= INTRO_SECONDS:
				_next_memo()
		State.MEMO:
			if _state_t >= MEMO_SECONDS:
				state = State.PICK
				_state_t = 0.0
		State.PICK:
			if _state_t >= PICK_SECONDS:
				wrongs += 3 - step  # the missing bottles count as wrong
				_begin_shake()
		State.SHAKE:
			if _state_t >= nod_time(BEATS - 1) + BEAT_WINDOW_RELAXED + 0.1 or taps.size() >= BEATS and _state_t > nod_time(BEATS - 1):
				order_scores.append(order_score(wrongs, _score_shake()))
				state = State.SERVE
				_state_t = 0.0
				if OS.has_feature("mobile"):
					Input.vibrate_handheld(18)
		State.SERVE:
			if _state_t >= SERVE_SECONDS:
				order += 1
				if order >= ORDERS:
					state = State.DONE
					queue_redraw()
					finish(current_score())
					return
				_next_memo()
	queue_redraw()


func _next_memo() -> void:
	state = State.MEMO
	_state_t = 0.0
	step = 0
	wrongs = 0
	taps.clear()
	_update_status()


func _result_extra() -> Dictionary:
	var extra := {"orders": order_scores.duplicate()}
	if current_score() >= TIER_GREAT:
		extra["bonus_action"] = BONUS_ACTION
	return extra


func _update_status() -> void:
	set_status(S.t("mg.shake_serve.status", {"n": mini(order + 1, ORDERS), "total": ORDERS}))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if state == State.SHAKE:
			shake_tap()
		elif state == State.PICK:
			var id := shelf_at(event.position)
			if id != "":
				pick(id)


# --- Layout and drawing ----------------------------------------------------------------------------

func _shelf_rect(i: int) -> Rect2:
	var cols := 4
	var w := size.x * 0.84 / cols
	var h := minf(size.y * 0.10, w * 1.3)
	var x0 := size.x * 0.08
	var y0 := size.y * 0.26
	return Rect2(x0 + (i % cols) * w + 6, y0 + (i / cols) * (h + 18), w - 12, h)


func shelf_at(p: Vector2) -> String:
	var ids := shelf()
	for i in ids.size():
		if _shelf_rect(i).grow(6).has_point(p):
			return str(ids[i])
	return ""


func _label_of(id: String) -> String:
	if id in SPIRITS:
		var b := bottle_of(id)
		if b != "" and BarMenu.has(b):
			return BarMenu.name_of(b)
	return S.t("mg.shake_serve.bottle." + id)


func _draw() -> void:
	if size.x <= 0.0:
		return
	var r := recipe()
	# Nam's order
	var box := Rect2(size.x * 0.05, 10, size.x * 0.9, size.y * 0.12)
	draw_rect(box, UI.BG_RAISED)
	draw_rect(box, UI.LINE, false, 3.0)
	if not r.is_empty():
		UI.draw_text(self, S.t("mg.shake_serve.nam"), Vector2(box.position.x + 30, box.position.y + 44), 30, UI.AMBER, false)
		UI.draw_text(self, S.t("mg.shake_serve.order." + str(r[0])), Vector2(size.x * 0.5, box.position.y + 100), 36, UI.CREAM)
	# recipe slots: shown in MEMO, then only what has been picked
	for k in 3:
		var sr := Rect2(size.x * (0.1 + k * 0.28), size.y * 0.16, size.x * 0.24, size.y * 0.06)
		var shown := state == State.MEMO or (state == State.PICK and k < step) or state == State.SHAKE or state == State.SERVE
		draw_rect(sr, UI.AMBER if shown else UI.BG_DEEP)
		draw_rect(sr, UI.AMBER, false, 3.0)
		if not r.is_empty():
			UI.draw_text(self, _label_of(str(r[1 + k])) if shown else "?", sr.get_center() + Vector2(0, 10), 26, UI.BG_DEEP if shown else UI.ASH)
	# backlit shelf
	var ids := shelf()
	var glow := _shelf_rect(0).merge(_shelf_rect(ids.size() - 1)).grow(30)
	draw_rect(glow, Color(UI.AMBER, 0.10))
	for i in ids.size():
		var br := _shelf_rect(i)
		var id := str(ids[i])
		var col := UI.AMBER if id in SPIRITS else UI.GOLD
		if flash != "" and flash == id and flash_t > 0.0:
			col = UI.NEON
		draw_rect(Rect2(br.position.x + br.size.x * 0.38, br.position.y, br.size.x * 0.24, br.size.y * 0.2), Color(col, 0.8))
		draw_rect(Rect2(br.position.x + br.size.x * 0.15, br.position.y + br.size.y * 0.18, br.size.x * 0.7, br.size.y * 0.82), Color(col, 0.55))
		draw_rect(Rect2(br.position.x + br.size.x * 0.1, br.position.y + br.size.y * 0.5, br.size.x * 0.8, br.size.y * 0.28), UI.CREAM)
		UI.draw_text(self, _label_of(id), Vector2(br.get_center().x, br.position.y + br.size.y * 0.7), 20, UI.BG_DEEP)
	# shaker and Nam's nods
	var sc := Vector2(size.x * 0.5, size.y * 0.83)
	var wob := 0.0
	if state == State.SHAKE:
		wob = sin(_state_t * 30.0) * 10.0 * float(taps.size() > 0)
	draw_rect(Rect2(sc + Vector2(-60 + wob, -110), Vector2(120, 170)), Color("B8B0A8"))
	draw_rect(Rect2(sc + Vector2(-42 + wob, -150), Vector2(84, 44)), Color("D8D0C8"))
	for i in BEATS:
		var c := Vector2(size.x * 0.5 + (i - 1.5) * 90.0, size.y * 0.95)
		var lit := state == State.SHAKE and _state_t >= nod_time(i) - 0.05
		var hit_beat := i < taps.size()
		draw_arc(c, 22, 0, TAU, 32, UI.AMBER if lit else UI.LINE, 5.0, true)
		if hit_beat:
			draw_circle(c, 15, UI.AMBER)
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
		UI.draw_text(self, hint, Vector2(size.x * 0.5, size.y * 0.64), 34, UI.SMOKE)
