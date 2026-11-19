extends Control
## Shared result card (wireframes section 7): score tier word, number, best, need gained, AGAIN / DONE.
## The result is a moment (11-minigame-quality §2.2, job Q1): the tier stamp slams in with a short shake and a haptic,
## the score counts up, a NEW BEST ribbon lands, then the competition lines (§4.1: over your best, tonight's regular
## to beat from result.extra.rival = {regular, points}; ghost and board come later per game). The buttons work from
## the first frame: the moment never blocks. Its clock is advance_anim(dt), driven by _process; tests drive it.
## show_result() applies the result to the Needs autoload exactly once, via Needs.apply_action(action_id,
## score, key), then renders what actually landed. `needs` can be injected (tests, lab fallback).

signal again
signal done

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Glyph = preload("res://scripts/minigames/need_glyph.gd")
const BCSkin = preload("res://scripts/ui/bc_skin.gd")
const Base = preload("res://scripts/minigames/minigame_base.gd")
const Rules = preload("res://scripts/rules.gd")
const Cast = preload("res://scripts/cast.gd")
const Fx = preload("res://scripts/minigames/mg_fx.gd")

const BEST_KEY := "minigame_best"  # Needs.ext[BEST_KEY][game_id] = best points (0..100)
const HEARTS_KEY := "hearts"  # Needs.ext[HEARTS_KEY][regular_id] = 0..MAX_HEARTS (DECISIONS: hearts 0-3), regulars only
const MAX_HEARTS := 3
const LEAN_ACTION := "candle_talk_lean"  # Rules.ACTIONS key for the extra.lean bonus
const PLAYED_ACTION := "minigame_played"  # Rules.ACTIONS key applied after every round that is not a miss
const GAIN_EPSILON := 0.05

# Result moment timeline (seconds from the card opening); starting values, tunable.
const STAMP_SECONDS := 0.22  # the stamp falls from STAMP_FROM_SCALE to 1 and lands
const STAMP_FROM_SCALE := 2.4
const STAMP_FROM_DEG := -16.0
const STAMP_REST_DEG := -4.0
const STAMP_BOUNCE_SECONDS := 0.12  # the landing dip
const STAMP_BOUNCE := 0.08
const STAMP_TRAUMA := 0.35  # card shake on landing (off with reduce motion)
const COUNT_SECONDS := 0.6  # the score counts up after the landing
const RIBBON_AT := STAMP_SECONDS + COUNT_SECONDS
const RIBBON_SECONDS := 0.22
const RIBBON_DEG := -6.0
const LINES_AT := RIBBON_AT
const LINES_FADE_SECONDS := 0.25
const ANIM_END := RIBBON_AT + 0.25
const STAMP_LINE := 1.3  # stamp holder height per px of font size
const TIER_COLORS :={-1: UI.ASH, 0: UI.CREAM, 1: UI.GOLD, 2: UI.NEON}

var needs: Node
var outcome: Dictionary = {}  # filled by apply(): ok, reason, gains, tab, best, prev_best, new_best, hearts, again_ok
var anim_t := 0.0
var animate := true  # false: the card opens in its end state (no slam, no shake, no haptic)
var _points := 0
var _tier := 0
var _landed := true
var _stamp: Label
var _stamp_holder: Control
var _glow: TextureRect
var _score_label: Label
var _ribbon: Control
var _comp: VBoxContainer
var _fx: Fx


func _get_needs() -> Node:
	if needs != null:
		return needs
	var tree := get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree != null:
		needs = tree.root.get_node_or_null("Needs")
	return needs


## Records best/hearts (regulars only), applies the refill and returns the outcome. No UI; safe to call off-tree.
## A round uses one of the visit's tries (misses included, 06-stakes §7.2). A MISS (result.miss) earns nothing: no best,
## no hearts, no refill, no minigame_played, and a missed Candle Talk leaves the regular's talk of the day open.
func apply(result: Dictionary) -> Dictionary:
	var n := _get_needs()
	var points := int(result.get("points", 0))
	var game_id := str(result.get("game_id", ""))
	var missed := bool(result.get("miss", false))
	var new_best := false
	var best := points
	var hearts := -1
	var prev := int(n.ext.get(BEST_KEY, {}).get(game_id, 0)) if n != null else 0
	if n != null and not n.note_minigame_round(game_id):
		_outcome({"ok": false, "reason": "tries", "gains": {}, "tab": 0.0}, 0, false, -1, false, true, missed)
		outcome["prev_best"] = prev
		return outcome
	if missed:
		_outcome({"ok": false, "reason": "miss", "gains": {}, "tab": 0.0}, prev, false, -1,
			n == null or n.minigame_tries_left(game_id) > 0, false, true)
		outcome["prev_best"] = prev
		return outcome
	if n != null:
		var bests: Dictionary = n.ext.get(BEST_KEY, {})
		best = maxi(prev, points)
		new_best = points > prev and prev > 0
		bests[game_id] = best
		n.ext[BEST_KEY] = bests
		# Hearts for regulars only: a talk with an owner (Prae) refills Friends, but no hearts are kept or shown.
		var reg := str(result.get("extra", {}).get("regular", ""))
		if reg != "" and Cast.befriends(reg):
			hearts = int(n.ext.get(HEARTS_KEY, {}).get(reg, 0))
			if float(result.get("score", 0.0)) >= Base.TIER_GREAT:
				var hs: Dictionary = n.ext.get(HEARTS_KEY, {})
				hearts = mini(MAX_HEARTS, hearts + 1)
				hs[reg] = hearts
				n.ext[HEARTS_KEY] = hs
	var applied := {"ok": false, "reason": "no_needs", "gains": {}, "tab": 0.0}
	if n != null:
		applied = n.apply_action(str(result.get("action_id", "")), float(result.get("score", 0.0)), str(result.get("key", "")))
		# Candle Talk lean bonus (DECISIONS (k)): a fully lit candle also earns candle_talk_lean, shown as one gain.
		if applied.get("ok", false) and bool(result.get("extra", {}).get("lean", false)):
			var lean: Dictionary = n.apply_action(LEAN_ACTION, 1.0, str(result.get("key", "")))
			_fold(applied, lean)
		# A game's own bonus action (Shake & Serve: shake_serve_friends on a great round), shown as one gain with the round.
		var bonus_id := str(result.get("extra", {}).get("bonus_action", ""))
		if applied.get("ok", false) and bonus_id != "" and Rules.ACTIONS.has(bonus_id):
			_fold(applied, n.apply_action(bonus_id, 1.0))
		# Any round that is not a miss is "play a minigame" (06-stakes §2): +3 Nightlife, capped +9 a visit
		if applied.get("ok", false):
			_fold(applied, n.apply_action(PLAYED_ACTION))
	var again: bool = n == null or n.minigame_tries_left(game_id) > 0
	_outcome(applied, best, new_best, hearts, again, false, false, str(result.get("action_id", "")))
	outcome["prev_best"] = prev
	return outcome


func _fold(applied: Dictionary, extra: Dictionary) -> void:
	if extra.get("ok", false):
		for m in extra["gains"]:
			applied["gains"][m] = float(applied["gains"].get(m, 0.0)) + float(extra["gains"][m])
		applied["tab"] = float(applied.get("tab", 0.0)) + float(extra.get("tab", 0.0))


## `again`: tries are left; `plenty`: tries ran out on this round or before it (the card says so); AGAIN is also
## hidden when the next round would earn nothing (diminishing returns, daily_once).
func _outcome(applied: Dictionary, best: int, new_best: bool, hearts: int, again: bool, tries_out: bool, missed: bool, action_id := "") -> Dictionary:
	var total := 0.0
	for m in applied.get("gains", {}):
		total += float(applied["gains"][m])
	var earns: bool = applied.get("ok", false) and total > GAIN_EPSILON 		and not Rules.ACTIONS.get(action_id, {}).get("daily_once", false)
	outcome = {
		"ok": applied.get("ok", false), "reason": applied.get("reason", ""), "gains": applied.get("gains", {}),
		"tab": applied.get("tab", 0.0), "best": best, "new_best": new_best, "hearts": hearts, "miss": missed,
		"tries_out": tries_out or not again,
		"again_ok": again and (missed or earns),
	}
	return outcome


func show_result(result: Dictionary, needs_node: Node = null) -> void:
	if needs_node != null:
		needs = needs_node
	var o := apply(result)
	_build(result, o)


func _build(result: Dictionary, o: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UI.BG_DEEP, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(UI.dp(358), 0)
	# D2 Back-bar (bc_skin.gd, Daniele 2026-11-19): wood card, brass line, LED strip under it; the tier word is the
	# screen's neon sign; NEW BEST is a brass plaque. Motion (stamp, count-up, ribbon) unchanged from Q1.
	var pb := BCSkin.panel_box(20.0, true, 0.97)
	pb.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", pb)
	center.add_child(panel)
	BCSkin.led_strip(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(UI.dp(18)))
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UI.dp(10)))
	pad.add_child(col)

	var game_id := str(result.get("game_id", ""))
	var tier := int(result.get("tier", 0))
	_tier = tier
	_points = int(result.get("points", 0))
	var word := S.t("mg.result.miss") if tier < 0 else S.t("mg.%s.tier_%d" % [game_id, tier + 1])
	col.add_child(_build_stamp(word, tier))

	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", int(UI.dp(14)))
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(score_row)
	_score_label = UI.label(str(_points), 44, UI.CREAM, HORIZONTAL_ALIGNMENT_RIGHT)
	_score_label.theme_type_variation = &"LabelDisplayXL"
	_score_label.add_theme_font_size_override("font_size", int(UI.dp(44)))
	_score_label.custom_minimum_size.x = _score_label.get_combined_minimum_size().x  # no jitter while counting
	score_row.add_child(_score_label)
	if o.get("new_best", false):
		score_row.add_child(_build_ribbon(S.t("mg.result.new_best").to_upper()))
	else:
		score_row.add_child(UI.label(S.t("mg.result.best", {"score": o.get("best", 0)}), 15, UI.SMOKE))

	_comp = VBoxContainer.new()
	_comp.add_theme_constant_override("separation", int(UI.dp(2)))
	col.add_child(_comp)
	for line in competition_lines(result, o):
		var l := UI.wrap(UI.label(line["text"], 15, line["color"], HORIZONTAL_ALIGNMENT_CENTER))
		l.name = "Compete_" + str(line["id"])
		_comp.add_child(l)

	# Need gained: glyph, bar, +N chip. Bars show the meter value after the gain.
	var n := _get_needs()
	var gains: Dictionary = o.get("gains", {})
	for m in Rules.METERS:
		if not gains.has(m):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(UI.dp(10)))
		col.add_child(row)
		var g := Glyph.new()
		g.need = m
		row.add_child(g)
		row.add_child(UI.label(S.t("need.%s.name" % m), 14, UI.SMOKE))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = n.meters.get(m, 0.0) if n != null else 0.0
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size = Vector2(0, UI.dp(8))
		bar.add_theme_stylebox_override("background", UI.box(Color("0B0505"), 4, Color(BCSkin.BRASS_DIM, 0.8), 1.0))
		bar.add_theme_stylebox_override("fill", UI.box(UI.need_color(m), 4))
		row.add_child(bar)
		row.add_child(UI.label("+%d" % roundi(float(gains[m])), 15, UI.need_color(m)))
	if o.get("miss", false):
		col.add_child(UI.wrap(UI.label(S.t("mg.result.miss_line.%d" % posmod(hash(game_id + str(result.get("points", 0))), 3)), 15, UI.SMOKE)))
	elif gains.is_empty():
		var why := "mg.result.nothing_daily" if o.get("reason", "") == "daily_once" else "mg.result.plenty"
		col.add_child(UI.wrap(UI.label(S.t(why), 15, UI.SMOKE)))
	elif float(o.get("tab", 0.0)) > 0.0:
		col.add_child(UI.wrap(UI.label(S.t("mg.result.tab"), 13, UI.SMOKE)))
	if o.get("tries_out", false) and not gains.is_empty():
		col.add_child(UI.wrap(UI.label(S.t("mg.result.plenty"), 13, UI.SMOKE)))

	var extra: Dictionary = result.get("extra", {})
	if extra.has("regular") and int(o.get("hearts", -1)) >= 0:
		var hrow := HBoxContainer.new()
		hrow.add_theme_constant_override("separation", int(UI.dp(4)))
		col.add_child(hrow)
		var hearts := int(o.get("hearts", 0))
		for i in MAX_HEARTS:
			var h := Glyph.new()
			h.need = "heart"
			h.tint = UI.NEON if i < hearts else UI.LINE
			h.custom_minimum_size = Vector2(UI.dp(28), UI.dp(28))
			hrow.add_child(h)
		hrow.add_child(UI.wrap(UI.label(S.t("mg.result.hearts", {"regular": Cast.name_of(str(extra["regular"])), "count": hearts, "max": MAX_HEARTS}), 14, UI.SMOKE)))

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", int(UI.dp(12)))
	col.add_child(btns)
	if o.get("again_ok", false):
		var again_btn := UI.button(S.t("mg.result.again"), "secondary")
		again_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		again_btn.pressed.connect(func(): again.emit())
		btns.add_child(again_btn)
	var done_btn := UI.button(S.t("mg.result.done"), "primary")
	done_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done_btn.pressed.connect(func(): done.emit())
	btns.add_child(done_btn)

	_fx = Fx.new()
	_fx.target = panel
	_fx.reduce_motion = Fx.reduce_motion_on(_get_needs())
	add_child(_fx)
	anim_t = 0.0
	_landed = false
	if animate:
		_apply_anim()
	else:
		skip_anim()


# --- Result moment -------------------------------------------------------------------------------------------------

## The tier word as a stamp: a plain Control holds it so containers never reset its scale and rotation.
func _build_stamp(word: String, tier: int) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gc: Color = TIER_COLORS.get(tier, UI.GOLD)
	_glow = TextureRect.new()
	_glow.texture = Fx.glow_texture()
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.modulate = Color(gc, 0.0)
	_glow.visible = tier >= 1
	holder.add_child(_glow)
	_stamp = UI.title(word, 32, gc)
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if tier >= 0:
		BCSkin.neon(_stamp, gc)
	else:
		_stamp.add_theme_constant_override("outline_size", int(UI.dp(4)))
		_stamp.add_theme_color_override("font_outline_color", UI.BG_DEEP)
	_stamp.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_stamp)
	# Title font's tall strokes: size the holder from the font size (measuring off-tree under-reports it).
	var font_px := float(_stamp.get_theme_font_size("font_size"))
	holder.custom_minimum_size = Vector2(0, maxf(_stamp.get_combined_minimum_size().y, font_px * STAMP_LINE) + UI.dp(6))
	_stamp_holder = holder
	return holder


func _build_ribbon(text: String) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ribbon := PanelContainer.new()
	ribbon.name = "NewBestRibbon"
	var sb := UI.box(Color("3A2610"), 6, UI.GOLD, 2.0)
	sb.content_margin_left = UI.dp(10)
	sb.content_margin_right = UI.dp(10)
	sb.content_margin_top = UI.dp(3)
	sb.content_margin_bottom = UI.dp(3)
	ribbon.add_theme_stylebox_override("panel", sb)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rl := UI.label(text, 16, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	rl.theme_type_variation = &"LabelDisplayS"
	rl.add_theme_font_size_override("font_size", int(UI.dp(16)))
	ribbon.add_child(rl)
	holder.add_child(ribbon)
	var sz := ribbon.get_combined_minimum_size()
	ribbon.size = sz
	holder.custom_minimum_size = sz
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ribbon = ribbon
	return holder


## Lines under the score: how far over your best, and tonight's regular to beat (result.extra.rival =
## {regular, points} or {name, points}), and the board place (extra.board = {rank, count}, mg_rivals). Each line: {id, text, color}.
static func competition_lines(result: Dictionary, o: Dictionary) -> Array:
	var out: Array = []
	var points := int(result.get("points", 0))
	var prev := int(o.get("prev_best", 0))
	if o.get("new_best", false) and prev > 0:
		out.append({"id": "over_best", "text": S.t("mg.result.over_best", {"gap": points - prev}), "color": UI.GOLD})
	var rival: Variant = result.get("extra", {}).get("rival")
	if rival is Dictionary and rival.has("points"):
		var who := str(rival.get("name", ""))
		if who == "":
			who = Cast.name_of(str(rival.get("regular", "")))
		var rp := int(rival["points"])
		var vars := {"regular": who, "score": rp, "gap": absi(points - rp)}
		if points > rp:
			out.append({"id": "rival", "text": S.t("mg.result.rival_beat", vars), "color": UI.GOLD})
		elif points == rp:
			out.append({"id": "rival", "text": S.t("mg.result.rival_level", vars), "color": UI.CREAM})
		else:
			out.append({"id": "rival", "text": S.t("mg.result.rival_short", vars), "color": UI.SMOKE})
	# Q4 hook (mg_rivals.gd): this run's place on tonight's board, result.extra.board = {rank, count}
	var board: Variant = result.get("extra", {}).get("board")
	if board is Dictionary and int(board.get("rank", 0)) > 0:
		var top := int(board["rank"]) == 1
		out.append({"id": "board", "text": S.t("mg.result.board", {"rank": int(board["rank"]), "count": int(board.get("count", 0))}),
			"color": UI.GOLD if top else UI.SMOKE})
	return out


## Score shown at time t of the count-up (ease-out cubic over COUNT_SECONDS).
static func count_up(points: int, t: float) -> int:
	var k := clampf(t / COUNT_SECONDS, 0.0, 1.0)
	return roundi(float(points) * (1.0 - pow(1.0 - k, 3.0)))


static func stamp_scale_at(t: float) -> float:
	if t < STAMP_SECONDS:
		var k := t / STAMP_SECONDS
		return lerpf(STAMP_FROM_SCALE, 1.0, k * k)
	var u := t - STAMP_SECONDS
	if u < STAMP_BOUNCE_SECONDS:
		return 1.0 - STAMP_BOUNCE * sin(u / STAMP_BOUNCE_SECONDS * PI)
	return 1.0


## Ease-out-back 0 -> 1 with an overshoot: the ribbon lands.
static func ribbon_scale_at(t: float) -> float:
	var r := clampf((t - RIBBON_AT) / RIBBON_SECONDS, 0.0, 1.0)
	if r <= 0.0:
		return 0.0
	var c1 := 1.70158
	return 1.0 + (c1 + 1.0) * pow(r - 1.0, 3.0) + c1 * pow(r - 1.0, 2.0)


func _process(delta: float) -> void:
	if anim_t < ANIM_END:
		advance_anim(delta)


func advance_anim(dt: float) -> void:
	anim_t += dt
	_apply_anim()


## Jumps to the end state without the landing effects.
func skip_anim() -> void:
	_landed = true
	anim_t = ANIM_END
	_apply_anim()


func score_shown() -> int:
	return int(_score_label.text) if _score_label != null else 0


func _apply_anim() -> void:
	if _stamp != null:
		var k := clampf(anim_t / STAMP_SECONDS, 0.0, 1.0)
		var s := stamp_scale_at(anim_t)
		_stamp.pivot_offset = _stamp.size * 0.5
		_stamp.scale = Vector2(s, s)
		_stamp.rotation_degrees = lerpf(STAMP_FROM_DEG, STAMP_REST_DEG, k)
		_stamp.modulate.a = clampf(k * 3.0, 0.0, 1.0)
		if _glow != null and _glow.visible:
			var after := clampf((anim_t - STAMP_SECONDS) / 0.3, 0.0, 1.0)
			_glow.modulate.a = (0.55 if _tier >= 2 else 0.3) * after
	if not _landed and anim_t >= STAMP_SECONDS:
		_land()
	if _score_label != null:
		_score_label.text = str(count_up(_points, anim_t - STAMP_SECONDS))
	if _ribbon != null:
		var rs := ribbon_scale_at(anim_t)
		_ribbon.visible = rs > 0.0
		_ribbon.pivot_offset = _ribbon.size * 0.5
		_ribbon.scale = Vector2(rs, rs)
		_ribbon.rotation_degrees = RIBBON_DEG
	if _comp != null:
		_comp.modulate.a = clampf((anim_t - LINES_AT) / LINES_FADE_SECONDS, 0.0, 1.0)


## The stamp hits the card: a short shake, a haptic by tier, sparks or confetti for great and perfect.
func _land() -> void:
	_landed = true
	if _fx == null:
		return
	_fx.shake(STAMP_TRAUMA)
	Base.haptic("strong" if _tier >= 2 else ("fail" if _tier < 0 else "tick"))
	var at := size * 0.5
	if _stamp_holder != null and _stamp_holder.is_inside_tree():
		at = _stamp_holder.get_global_rect().get_center() - get_global_rect().position
	if _tier >= 2:
		_fx.burst("confetti", at)
	elif _tier == 1:
		_fx.burst("spark", at)
