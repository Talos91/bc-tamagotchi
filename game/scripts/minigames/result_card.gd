extends Control
## Shared result card (wireframes section 7): score tier word, number, best, need gained, AGAIN / DONE.
## show_result() applies the result to the Needs autoload exactly once, via Needs.apply_action(action_id,
## score, key), then renders what actually landed. `needs` can be injected (tests, lab fallback).

signal again
signal done

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Glyph = preload("res://scripts/minigames/need_glyph.gd")
const Base = preload("res://scripts/minigames/minigame_base.gd")
const Rules = preload("res://scripts/rules.gd")
const Cast = preload("res://scripts/cast.gd")

const BEST_KEY := "minigame_best"  # Needs.ext[BEST_KEY][game_id] = best points (0..100)
const HEARTS_KEY := "hearts"  # Needs.ext[HEARTS_KEY][regular_id] = 0..MAX_HEARTS (DECISIONS: hearts 0-3), regulars only
const MAX_HEARTS := 3
const LEAN_ACTION := "candle_talk_lean"  # Rules.ACTIONS key for the extra.lean bonus
const PLAYED_ACTION := "minigame_played"  # Rules.ACTIONS key applied after every round that is not a miss
const GAIN_EPSILON := 0.05

var needs: Node
var outcome: Dictionary = {}  # filled by apply(): ok, reason, gains, tab, best, new_best, hearts, again_ok


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
	if n != null and not n.note_minigame_round(game_id):
		return _outcome({"ok": false, "reason": "tries", "gains": {}, "tab": 0.0}, 0, false, -1, false, true, missed)
	if missed:
		var prev_best := int(n.ext.get(BEST_KEY, {}).get(game_id, 0)) if n != null else 0
		return _outcome({"ok": false, "reason": "miss", "gains": {}, "tab": 0.0}, prev_best, false, -1,
			n == null or n.minigame_tries_left(game_id) > 0, false, true)
	if n != null:
		var bests: Dictionary = n.ext.get(BEST_KEY, {})
		var prev := int(bests.get(game_id, 0))
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
		# Any round that is not a miss is "play a minigame" (06-stakes §2): +3 Nightlife, capped +9 a visit
		if applied.get("ok", false):
			_fold(applied, n.apply_action(PLAYED_ACTION))
	var again: bool = n == null or n.minigame_tries_left(game_id) > 0
	return _outcome(applied, best, new_best, hearts, again, false, false, str(result.get("action_id", "")))


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
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG_BASE, 20, UI.LINE, 2.0))
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(UI.dp(18)))
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UI.dp(10)))
	pad.add_child(col)

	var game_id := str(result.get("game_id", ""))
	var tier := int(result.get("tier", 0))
	var word := S.t("mg.result.miss") if tier < 0 else S.t("mg.%s.tier_%d" % [game_id, tier + 1])
	col.add_child(UI.title(word, 32))

	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", int(UI.dp(14)))
	col.add_child(score_row)
	score_row.add_child(UI.label(str(result.get("points", 0)), 32, UI.CREAM))
	if o.get("new_best", false):
		score_row.add_child(UI.label(S.t("mg.result.new_best"), 15, UI.GOLD))
	else:
		score_row.add_child(UI.label(S.t("mg.result.best", {"score": o.get("best", 0)}), 15, UI.SMOKE))

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
		bar.add_theme_stylebox_override("background", UI.box(UI.BG_RAISED, 4))
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
