extends "res://scripts/minigames/minigame_base.gd"
## Pour Perfect (GDD section 9 #1, Bar, Drinks +20-30). Hold to pour; release to lock the layer on its
## target line. Three layers, one glass. Overfilling only foams: it costs a little score, never the reward.
## Controls: press and hold anywhere, release. Feeds action "pour_perfect".
## config.drink: a real menu item id (scripts/menu/bar_menu.gd); its name shows above the glass and its pour style
## colours the layers. Without one (the minigame lab) the glass is the plain amber/gold/cream pour.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const BarMenu = preload("res://scripts/menu/bar_menu.gd")
const Rivals = preload("res://scripts/minigames/mg_rivals.gd")

## Cumulative fill (0 = empty, 1 = rim) each layer must reach.
const TARGETS: Array[float] = [0.30, 0.58, 0.82]
const LAYER_COLORS: Array[Color] = [UI.AMBER, UI.GOLD, UI.CREAM]
const POUR_RATE := 0.075  # glass heights per second, before the flow wobble
const FLOW_WOBBLE := 0.35  # +-35% flow, sine, so releasing on time takes feel not arithmetic
const PERFECT_ERR := 0.02  # within this of the line scores 1.0
const MISS_ERR := 0.20  # this far or more scores 0.0 for the layer
const OVERFILL_PER_UNIT := 2.0  # score lost per glass-height of foam
const OVERFILL_MAX_PENALTY := 0.3
const INTRO_SECONDS := 1.5
const SETTLE_SECONDS := 0.8
const TIME_LIMIT := 30.0  # seconds after the glass arrives

## Look B sprites (game/assets/minigames/README.md, Pour Perfect). Loaded lazily; without them the flat draw stays.
const ASSET_DIR := "res://assets/minigames/pour_perfect/"
const PINT_FRAME := Vector2(316, 682)
const PINT_ANCHOR := Vector2(158.0, 676.6)
const PINT_IN_BL := Vector2(26.0, 643.2)
const PINT_IN_TR := Vector2(290.0, 20.7)
const TAP_FRAME := Vector2(156, 326)
const TAP_SPOUT := Vector2(146.0, 179.9)
const STREAM_W := 32.0
const FOAM_FRAME := Vector2(172, 66)
const FOAM_ANCHOR := Vector2(82.0, 60.7)
const FOAM_RISE_SECONDS := 0.7  # the head grows while the tap runs
## Relaxed timing (11-minigame-quality section 3): the perfect band x1.5, the flow -20 %.
const RELAXED_BAND := 1.5
const RELAXED_FLOW := 0.8
const SPILL_BURST_GAP := 0.12

enum State { INTRO, READY, POURING, SETTLE, DONE }

var state := State.INTRO
var layer := 0
var level := 0.0  # current fill 0..1 (clamped at the rim)
var spill := 0.0  # glass heights poured past the rim
var locked: Array[float] = []
var elapsed := 0.0  # time since the glass arrived
var _pour_t := 0.0
var _state_t := 0.0
var _pressed := false
var drink_id := ""
var layer_colors: Array[Color] = LAYER_COLORS
var _tex := {}
var _foam := 0.0  # 0..1: how high the foam head has risen on the layer being poured
var _spill_t := 0.0
## §4.1 competition: tonight's regular to beat, your best pour tonight as ghost ticks on the glass, the board line.
var rival: Dictionary = {}           ## {regular, name, points}
var rival_passed := false
var ghost: Dictionary = {}           ## your best pour tonight {levels: [fill per layer]}, or {}
var rivals_store: Object = null      ## tests: where mg_rivals keeps tonight's record (default Needs, else memory)
var _record: Dictionary = {}


func _init() -> void:
	game_id = "pour_perfect"
	action_id = "pour_perfect"
	need_id = "drinks"
	title_key = "mg.pour_perfect.title"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _on_start() -> void:
	state = State.INTRO
	layer = 0
	level = 0.0
	spill = 0.0
	locked.clear()
	elapsed = 0.0
	_pour_t = 0.0
	_state_t = 0.0
	_pressed = false
	_foam = 0.0
	_spill_t = 0.0
	_record = {}
	var t := Rivals.tonight(game_id, rivals_store)
	rival = t["rival"]
	rival_passed = false
	var g: Dictionary = t["ghost"]
	ghost = g if g.get("levels") is Array and (g["levels"] as Array).size() == TARGETS.size() else {}
	drink_id = str(config.get("drink", ""))
	var cols := BarMenu.pour_colors(drink_id) if drink_id != "" else ([] as Array[Color])
	layer_colors = cols if cols.size() == TARGETS.size() else LAYER_COLORS
	_update_status()
	queue_redraw()


# --- Scoring (static: the tests pin these) ---------------------------------------------------------

static func perfect_band(relaxed_on := false) -> float:
	return PERFECT_ERR * (RELAXED_BAND if relaxed_on else 1.0)


static func layer_score(lvl: float, target: float, relaxed_on := false) -> float:
	var err := absf(lvl - target)
	var band := perfect_band(relaxed_on)
	return clampf(1.0 - maxf(0.0, err - band) / (MISS_ERR - band), 0.0, 1.0)


static func overfill_penalty(spill_amount: float) -> float:
	return minf(OVERFILL_MAX_PENALTY, maxf(0.0, spill_amount) * OVERFILL_PER_UNIT)


static func total_score(levels: Array, spill_amount: float, relaxed_on := false) -> float:
	var sum := 0.0
	for i in TARGETS.size():
		sum += layer_score(float(levels[i]) if i < levels.size() else 0.0, TARGETS[i], relaxed_on)
	return clampf(sum / TARGETS.size() - overfill_penalty(spill_amount), 0.0, 1.0)


static func flow_rate(pour_time: float, relaxed_on := false) -> float:
	return POUR_RATE * (RELAXED_FLOW if relaxed_on else 1.0) * (1.0 + FLOW_WOBBLE * sin(pour_time * 2.3))


func current_score() -> float:
	var lv := locked.duplicate()
	if state == State.POURING or state == State.READY:
		lv.append(level)
	return total_score(lv, spill, relaxed)


func live_points() -> int:
	return points_for(current_score())


## The pour that just ended, as tonight's ghost (kept only if it is your best tonight): where each layer was locked.
func ghost_data() -> Dictionary:
	var lv: Array = []
	for i in TARGETS.size():
		lv.append(snappedf(float(locked[i]) if i < locked.size() else 0.0, 0.001))
	return {"levels": lv}


# --- Play ------------------------------------------------------------------------------------------

func press() -> void:
	if state == State.READY and running and not paused:
		state = State.POURING
		_pressed = true
		_pour_t = 0.0
		_foam = 0.0
		haptic("tick")
		var geo := _geo()
		fx().squash("tap")
		fx().burst("spark", Vector2(geo["cx"], geo["spout_y"] + 20.0), 5)


func release() -> void:
	_pressed = false
	if state == State.POURING:
		_lock_layer()


func _lock_layer() -> void:
	locked.append(level)
	state = State.SETTLE
	_state_t = 0.0
	_lock_beat(layer, level)
	_check_rival()
	_update_status()


## §4.1: passing tonight's regular as the layers lock in.
func _check_rival() -> void:
	if rival_passed or rival.is_empty() or live_points() <= int(rival.get("points", 0)):
		return
	rival_passed = true
	fx().pop(S.t("mg.rivals.passed", {"regular": str(rival.get("name", ""))}), Vector2(size.x * 0.5, size.y * 0.2), UI.NEON, 44)


## Release beat: on the line (inside the perfect band) the line flashes with a PERFECT pop; otherwise the pour
## answers with its layer score and a short tick. Never a shake: a pour is calm.
func _lock_beat(i: int, lvl: float) -> void:
	var geo := _geo()
	var ty: float = geo["y_bottom"] - TARGETS[i] * geo["inner_h"]
	var at := Vector2(geo["cx"], ty - 24.0)
	var f := fx()
	var err := absf(lvl - TARGETS[i])
	if err <= perfect_band(relaxed):
		f.flash("line%d" % i)
		f.pop(S.t("mg.fx.perfect"), at, UI.GOLD, 76)
		f.flare(Vector2(geo["cx"], ty), geo["inner_w"] * 0.8, UI.GOLD)
		f.burst("confetti", Vector2(geo["cx"], ty), 24)
		f.combo_step(S.t("mg.fx.perfect"), Vector2(geo["cx"], ty + 80.0))
		f.hit_stop()
		haptic("strong")
	else:
		var sc := layer_score(lvl, TARGETS[i], relaxed)
		f.combo_break()
		f.pop("%d" % roundi(sc * 100.0), at, UI.CREAM if sc >= 0.5 else UI.SMOKE, 56)
		haptic("tick")


func advance(dt: float) -> void:
	_state_t += dt
	_foam = move_toward(_foam, 1.0 if state == State.POURING else 0.0, dt / FOAM_RISE_SECONDS)
	match state:
		State.INTRO:
			if _state_t >= INTRO_SECONDS:
				state = State.READY
				_state_t = 0.0
		State.READY:
			elapsed += dt
		State.POURING:
			elapsed += dt
			_pour_t += dt
			var add := flow_rate(_pour_t, relaxed) * dt
			level += add
			if level > 1.0:
				spill += level - 1.0
				level = 1.0
			if elapsed >= TIME_LIMIT:
				release()
		State.SETTLE:
			elapsed += dt
			if _state_t >= SETTLE_SECONDS:
				layer += 1
				if layer >= TARGETS.size() or elapsed >= TIME_LIMIT:
					state = State.DONE
					finish(total_score(locked, spill, relaxed))
				else:
					state = State.READY
					_state_t = 0.0
					_update_status()
	if state == State.READY and elapsed >= TIME_LIMIT:
		# Time ran out waiting: lock what is in the glass so nobody is stuck.
		_lock_layer()
	queue_redraw()


## Overfill: foam spills over the rim as spark particles; the first spill also reddens the edge (short, clear).
func _spill_beat(first: bool, dt: float) -> void:
	var geo := _geo()
	var f := fx()
	var rim := Vector2(geo["cx"] + (geo["inner_w"] * 0.5) * (1.0 if int(_pour_t * 8.0) % 2 == 0 else -1.0), geo["rim_y"])
	if first:
		f.fail_edge()
		f.pop(S.t("mg.pour_perfect.spill"), Vector2(geo["cx"], geo["rim_y"] - 60.0), UI.CREAM, 56)
		f.combo_break()
		haptic("fail")
	_spill_t -= dt
	if _spill_t <= 0.0:
		_spill_t = SPILL_BURST_GAP
		f.burst("spark", rim, 6)


func _result_extra() -> Dictionary:
	if _record.is_empty():
		_record = Rivals.record(game_id, live_points(), ghost_data(), rivals_store)
	return {"rival": rival, "board": _record["board_line"]}


func _update_status() -> void:
	set_status(S.t("mg.pour_perfect.status", {"n": mini(layer + 1, TARGETS.size()), "total": TARGETS.size()}))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press()
		else:
			release()


# --- Drawing ---------------------------------------------------------------------------------------

func _t(file: String) -> Texture2D:
	if not _tex.has(file):
		var path := ASSET_DIR + file
		_tex[file] = load(path) if ResourceLoader.exists(path) else null
	return _tex[file]


func _sprites() -> bool:
	return _t("pint.png") != null and _t("tap.png") != null


func _glass_rect() -> Rect2:
	var gw := minf(size.x * 0.42, 430.0)
	var sprite := _sprites()
	var gh := minf(size.y * (0.55 if sprite else 0.62), 760.0)
	var slide := 1.0 if state != State.INTRO else ease(clampf(_state_t / INTRO_SECONDS, 0.0, 1.0), 0.4)
	var x := size.x * 0.5 - gw * 0.5 + (1.0 - slide) * size.x * 0.6
	return Rect2(x, size.y * (0.28 if sprite else 0.16), gw, gh)


## Where the glass fill, the rim and the tap spout sit on screen (sprite or flat), for the draw and the beats.
func _geo() -> Dictionary:
	var g := _glass_rect()
	var geo := {"g": g, "cx": g.position.x + g.size.x * 0.5, "sprite": _sprites()}
	if geo["sprite"]:
		var s := minf(g.size.x / PINT_FRAME.x, g.size.y / PINT_FRAME.y)
		var a := Vector2(geo["cx"], g.end.y)
		var ts := s * 0.8
		geo["s"] = s
		geo["ts"] = ts
		geo["anchor"] = a
		geo["y_bottom"] = a.y + (PINT_IN_BL.y - PINT_ANCHOR.y) * s
		geo["inner_h"] = (PINT_IN_BL.y - PINT_IN_TR.y) * s
		geo["inner_x"] = a.x + (PINT_IN_BL.x - PINT_ANCHOR.x) * s
		geo["inner_w"] = (PINT_IN_TR.x - PINT_IN_BL.x) * s
		geo["rim_y"] = a.y - PINT_ANCHOR.y * s + 10.0 * s
		geo["spout_y"] = geo["rim_y"] - 50.0
		geo["tap_top"] = geo["spout_y"] - TAP_SPOUT.y * ts
	else:
		geo["y_bottom"] = g.end.y - 8.0
		geo["inner_h"] = g.size.y - 16.0
		geo["inner_x"] = g.position.x + 10.0
		geo["inner_w"] = g.size.x - 20.0
		geo["rim_y"] = g.position.y
		geo["spout_y"] = g.position.y - 120.0
		geo["tap_top"] = g.position.y - 150.0
	return geo


func _cover(tex: Texture2D) -> void:
	var ts := tex.get_size()
	var k := maxf(size.x / ts.x, size.y / ts.y)
	var dsz := ts * k
	draw_texture_rect(tex, Rect2((size - dsz) * 0.5, dsz), false)


func _foam_blobs(cx: float, y: float, width: float, k: float, col: Color, seed_off := 0) -> void:
	var ft := _t("foam.png")
	if ft == null:
		return
	var fk := width / (FOAM_FRAME.x * 1.6) * k
	for j in 3:
		var fr := (j + seed_off) % 3
		var x := cx - width * 0.5 + width * (0.18 + 0.32 * j)
		var dst := Rect2(Vector2(x, y) - FOAM_ANCHOR * fk, FOAM_FRAME * fk)
		draw_texture_rect_region(ft, dst, Rect2(fr * FOAM_FRAME.x, 0, FOAM_FRAME.x, FOAM_FRAME.y), col)


func _draw() -> void:
	if size.x <= 0.0:
		return
	var geo := _geo()
	var g: Rect2 = geo["g"]
	var sprite: bool = geo["sprite"]
	var f := fx()
	var bd := _t("backdrop.png")
	if bd != null:
		_cover(bd)
		draw_rect(Rect2(Vector2.ZERO, size), Color(UI.BG_DEEP, 0.25))
	else:
		# Bar top.
		draw_rect(Rect2(0, g.end.y + 6, size.x, size.y - g.end.y), UI.BG_BASE)
		draw_rect(Rect2(0, g.end.y + 6, size.x, 4), UI.LINE)
	var y_bottom: float = geo["y_bottom"]
	var inner_h: float = geo["inner_h"]
	var inner_x: float = geo["inner_x"]
	var inner_w: float = geo["inner_w"]
	var cx: float = geo["cx"]
	var a: Vector2 = geo.get("anchor", Vector2.ZERO)
	var ps: float = geo.get("s", 1.0)
	# Glass back wall, then the fill, then the front (walls, rim, ribs) over it.
	if sprite:
		draw_texture_rect_region(_t("pint.png"), Rect2(a - PINT_ANCHOR * ps, PINT_FRAME * ps), Rect2(0, 0, PINT_FRAME.x, PINT_FRAME.y))
	# Fill: locked layers then the layer being poured.
	var prev := 0.0
	for i in locked.size():
		var top_y := y_bottom - locked[i] * inner_h
		draw_rect(Rect2(inner_x, top_y, inner_w, (locked[i] - prev) * inner_h), layer_colors[i])
		prev = locked[i]
	var li := mini(layer, layer_colors.size() - 1)
	if state == State.POURING or (state == State.READY and level > prev):
		draw_rect(Rect2(inner_x, y_bottom - level * inner_h, inner_w, (level - prev) * inner_h), layer_colors[li])
		if state == State.POURING:
			var top: float = geo["spout_y"]
			var surf := y_bottom - level * inner_h
			if sprite:
				var sk: float = geo["ts"]
				draw_set_transform(Vector2(cx, top), 0.0, Vector2(sk, sk))
				draw_texture_rect(_t("stream.png"), Rect2(-STREAM_W * 0.5, 0.0, STREAM_W, maxf(0.0, (surf - top) / sk)), true, layer_colors[li])
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_rect(Rect2(cx - 8, top, 16, surf - top), layer_colors[li])
	# Rising foam head on the surface of whatever is in the glass.
	if sprite and (_foam > 0.01 or not locked.is_empty()):
		var lvl_now := level if state == State.POURING or state == State.READY else (locked[-1] if not locked.is_empty() else 0.0)
		var amt := maxf(_foam, 0.0 if locked.is_empty() else 0.15)
		_foam_blobs(cx, y_bottom - lvl_now * inner_h + 6.0, inner_w, 0.5 + 0.5 * amt, Color(UI.CREAM, 0.35 + 0.65 * amt), layer)
	if spill > 0.0:
		var foam := minf(1.0, spill * 4.0)
		if sprite:
			_foam_blobs(cx, geo["rim_y"] + 8.0, inner_w * 1.25, 0.9 + foam * 0.8, UI.CREAM, 1)
		else:
			for k in 6:
				draw_circle(Vector2(g.position.x + g.size.x * (0.12 + 0.15 * k), g.position.y + 4 - foam * 18.0 * (0.5 + 0.5 * sin(k * 2.1))), 14.0 + foam * 10.0, UI.CREAM)
	if sprite:
		draw_texture_rect_region(_t("pint.png"), Rect2(a - PINT_ANCHOR * ps, PINT_FRAME * ps), Rect2(PINT_FRAME.x, 0, PINT_FRAME.x, PINT_FRAME.y))
		# The tap over the glass: its spout sits where the stream starts; it squashes when the pour starts.
		var tk: float = geo["ts"]
		var sq := f.squash_scale("tap")
		draw_set_transform(Vector2(cx, geo["spout_y"]), 0.0, Vector2(tk, tk) * sq)
		draw_texture_rect(_t("tap.png"), Rect2(-TAP_SPOUT, TAP_FRAME), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# Glass outline with ribs.
		draw_rect(g, UI.CREAM, false, 5.0)
		for k in range(1, 6):
			var rx := g.position.x + g.size.x * k / 6.0
			draw_line(Vector2(rx, g.position.y + 12), Vector2(rx, g.end.y - 12), Color(UI.CREAM, 0.12), 2.0)
	# Target lines for every layer; the active one is bright, with the perfect band as a faint strip.
	for i in TARGETS.size():
		var ty := y_bottom - TARGETS[i] * inner_h
		var active := i == layer and state != State.DONE
		var col := UI.GOLD if active else Color(UI.SMOKE, 0.5)
		col = f.flash_color("line%d" % i, col)
		if active:
			var bh := perfect_band(relaxed) * inner_h
			draw_rect(Rect2(inner_x, ty - bh, inner_w, bh * 2.0), Color(UI.GOLD, 0.12))
		var lw := 4.0 if active else 2.0
		if f.flash_amount("line%d" % i) > 0.0:
			lw = 8.0
		draw_line(Vector2(g.position.x - 30, ty), Vector2(g.end.x + 30, ty), col, lw)
		if i < locked.size():
			UI.draw_text(self, str(roundi(layer_score(locked[i], TARGETS[i], relaxed) * 100.0)), Vector2(g.end.x + 90, ty + 12), 36, UI.CREAM)
		if not ghost.is_empty():
			# your best pour tonight: a faint cyan tick where that layer was locked
			var gy := y_bottom - float(ghost["levels"][i]) * inner_h
			draw_line(Vector2(g.position.x - 14, gy), Vector2(g.end.x + 14, gy), Color(0.75, 0.9, 1.0, 0.55), 3.0)
	# The drink being poured.
	if drink_id != "" and BarMenu.has(drink_id):
		UI.draw_text(self, BarMenu.t("menu.pour.pouring", {"drink": BarMenu.name_of(drink_id)}), Vector2(size.x * 0.5, maxf(60.0, geo["tap_top"] - 30.0)), 40, UI.GOLD)
	# §4.1: tonight's regular to beat, and you
	if not rival.is_empty():
		var rc := UI.GOLD if rival_passed else UI.CREAM
		_text_right(S.t("mg.rivals.to_beat"), Vector2(size.x - 20.0, 40.0), 20, UI.SMOKE)
		_text_right("%s %d" % [str(rival.get("name", "")), int(rival.get("points", 0))], Vector2(size.x - 20.0, 72.0), 28, rc)
		_text_right(S.t("mg.rivals.you_now", {"score": live_points()}), Vector2(size.x - 20.0, 100.0), 22, UI.GOLD if rival_passed else UI.SMOKE)
	if not ghost.is_empty() and (state == State.INTRO or (state == State.READY and layer == 0)):
		UI.draw_text(self, S.t("mg.pour_perfect.ghost"), Vector2(size.x * 0.5, size.y - 200), 28, Color(0.75, 0.9, 1.0, 0.8))
	# Hint.
	var hint := ""
	match state:
		State.READY:
			hint = S.t("mg.pour_perfect.hint_ready")
		State.POURING:
			hint = S.t("mg.pour_perfect.hint_pour")
		State.INTRO:
			hint = S.t("mg.pour_perfect.hint_intro")
	if hint != "":
		UI.draw_text(self, hint, Vector2(size.x * 0.5, size.y - 150), 44, UI.SMOKE)
	# Thumb zone ring.
	if state == State.READY or state == State.POURING:
		var c := Vector2(size.x * 0.5, size.y - 300)
		draw_arc(c, 90.0, 0, TAU, 48, UI.GOLD if _pressed else UI.LINE, 6.0, true)


func _text_right(text: String, pos: Vector2, size_px: int, col: Color) -> void:
	var theme := ThemeDB.get_project_theme()
	var font: Font = theme.default_font if theme != null and theme.default_font != null else ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	draw_string_outline(font, pos - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 6, Color(0, 0, 0, 0.7))
	draw_string(font, pos - Vector2(w, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
