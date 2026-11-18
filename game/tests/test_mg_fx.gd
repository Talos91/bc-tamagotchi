extends SceneTree
## Headless tests for the shared minigame juice kit (job Q1, docs/design/11-minigame-quality.md §2.2, §2.4, §4.1):
## mg_fx.gd (pop, combo, flash + red edge, shake + reduce motion, hit-stop, squash, particles budget, glow), the
## web haptics rule in minigame_base.gd, the result moment in result_card.gd (stamp, count-up, NEW BEST ribbon,
## competition lines) and the Neon Moth proof wiring.
##   godot --headless --path . --script res://tests/test_mg_fx.gd
## Exit code 0 = all pass.

const Fx = preload("res://scripts/minigames/mg_fx.gd")
const Base = preload("res://scripts/minigames/minigame_base.gd")
const CardScript = preload("res://scripts/minigames/result_card.gd")
const NeedsScript = preload("res://scripts/needs.gd")
const Moth = preload("res://scripts/minigames/neon_moth.gd")
const S = preload("res://scripts/minigames/strings.gd")

const T0 := 1_800_000_000.0
const TEST_SAVE := "user://test_mg_fx_save.json"
const STEP := 1.0 / 120.0

var failures := 0
var checks := 0


func _initialize() -> void:
	TranslationServer.set_locale("en")
	S.install()
	test_pop()
	test_combo()
	test_flash_edge()
	test_shake()
	test_hit_stop()
	test_squash()
	test_particles()
	test_glow()
	test_haptics()
	test_result_moment()
	test_competition_lines()
	test_neon_moth_proof()
	print("")
	print("%d checks, %d failed" % [checks, failures])
	print("MG FX TESTS ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("  FAIL: ", msg)


func fresh_needs() -> Node:
	var n: Node = NeedsScript.new()
	n.autosave = false
	n.time_override = T0
	n.save_path = TEST_SAVE
	n.new_game()
	return n


func make_fx() -> Fx:
	var host := Control.new()
	host.size = Vector2(1080, 1400)
	root.add_child(host)
	var f: Fx = Fx.new()
	f.auto_step = false
	host.add_child(f)
	return f


func drop(f: Fx) -> void:
	var host := f.get_parent()
	host.free()


func test_pop() -> void:
	print("[pop] rises 40 px, 1.3 -> 1.0, fades in 0.5 s")
	check(is_equal_approx(Fx.pop_scale(0.0), 1.3), "starts at 1.3")
	check(is_equal_approx(Fx.pop_scale(Fx.POP_SECONDS), 1.0), "settles at 1.0")
	check(is_equal_approx(Fx.pop_offset(Fx.POP_SECONDS), -40.0), "rises 40 px (%.1f)" % Fx.pop_offset(Fx.POP_SECONDS))
	check(Fx.pop_alpha(0.0) == 1.0 and Fx.pop_alpha(Fx.POP_SECONDS) == 0.0, "fades out")
	var f := make_fx()
	f.pop("+1", Vector2(500, 500))
	f.pop("CLEAN", Vector2(500, 600))
	check(f.pops_alive() == 2, "two pops alive")
	f.step(0.3)
	check(f.pops_alive() == 2, "still alive at 0.3 s")
	f.step(0.25)
	check(f.pops_alive() == 0, "gone after 0.5 s")
	for i in 30:
		f.pop(str(i), Vector2.ZERO)
	check(f.pops_alive() == Fx.POP_MAX, "capped at %d" % Fx.POP_MAX)
	drop(f)


func test_combo() -> void:
	print("[combo] CLEAN ×N from the second step, grows, shatters on a break")
	var f := make_fx()
	f.combo_step()
	check(f.combo_text() == "", "one step shows nothing")
	f.combo_step()
	f.combo_step()
	check(f.combo_text() == "CLEAN ×3", "reads CLEAN ×3 (%s)" % f.combo_text())
	var bumped := f.combo_scale()
	f.step(Fx.COMBO_BUMP_SECONDS)
	var rest := f.combo_scale()
	check(bumped > rest and rest >= 1.0, "a step bumps the readout (%.2f > %.2f)" % [bumped, rest])
	for i in 5:
		f.combo_step()
	f.step(Fx.COMBO_BUMP_SECONDS)
	check(f.combo_scale() > rest, "the readout grows with the count")
	var before := f.particles_alive()
	var lost := f.combo_break()
	check(lost == 8 and f.combo == 0 and f.combo_text() == "", "break resets (lost %d)" % lost)
	check(f.particles_alive() > before, "a shown combo shatters into sparks")
	f.combo_step("PERFECT")
	f.combo_step("PERFECT")
	check(f.combo_text() == "PERFECT ×2", "a game's own word (%s)" % f.combo_text())
	drop(f)


func test_flash_edge() -> void:
	print("[flash] object white 60 ms, red edge 120 ms")
	var f := make_fx()
	f.flash("moth")
	check(f.flash_amount("moth") == 1.0, "flash starts full")
	check(f.flash_color("moth", Color.RED) == Color.WHITE, "tints to white")
	f.step(0.03)
	check(f.flash_amount("moth") > 0.0 and f.flash_amount("moth") < 1.0, "fading at 30 ms")
	f.step(0.04)
	check(f.flash_amount("moth") == 0.0, "gone after 60 ms")
	check(f.flash_amount("other") == 0.0, "other objects untouched")
	f.fail_edge()
	check(f.edge_amount() == 1.0, "edge on")
	f.step(0.1)
	check(f.edge_amount() > 0.0, "edge still on at 100 ms")
	f.step(0.03)
	check(f.edge_amount() == 0.0, "edge off after 120 ms")
	drop(f)


func test_shake() -> void:
	print("[shake] trauma 0.3 / 0.6, max 10 px, 0.25 s, reduce motion")
	var f := make_fx()
	var host: Control = f.get_parent()
	host.position = Vector2(7, 9)
	check(f.shake(Fx.TRAUMA_BUMP), "a bump shakes")
	f.step(STEP)
	check(f.target == host, "shakes its parent by default")
	var maxd := 0.0
	var moved := false
	var t := 0.0
	while f.trauma > 0.0 and t < 1.0:
		f.step(STEP)
		t += STEP
		var d := (host.position - Vector2(7, 9)).length()
		maxd = maxf(maxd, d)
		moved = moved or d > 0.01
	check(moved, "the host moved")
	check(maxd <= Fx.SHAKE_MAX_PX * 1.415, "within max px (%.2f)" % maxd)
	check(absf(t - Fx.SHAKE_SECONDS) < 0.02, "lasts 0.25 s (%.3f)" % t)
	check(host.position == Vector2(7, 9), "the host returns to rest (%s)" % host.position)
	f.shake(Fx.TRAUMA_LOSS)
	var big := 0.0
	for i in 200:
		big = maxf(big, f.shake_offset().length())
	check(big > 3.0 and big <= Fx.SHAKE_MAX_PX * 1.415, "a lost life shakes harder (%.2f)" % big)
	f.shake(1.0)
	f.shake(1.0)
	check(f.trauma <= 1.0, "trauma capped at 1")
	f.step(1.0)
	f.reduce_motion = true
	check(not f.shake(Fx.TRAUMA_LOSS) and f.trauma == 0.0, "reduce motion: no shake")
	drop(f)
	var n := fresh_needs()
	check(not Fx.reduce_motion_on(n), "default: shake allowed")
	Fx.set_reduce_motion(n, true)
	check(Fx.reduce_motion_on(n) and n.ext["ui"]["reduce_motion"] == true, "setting stored in Needs.ext.ui")
	Fx.set_reduce_motion(n, false)
	check(not Fx.reduce_motion_on(n), "setting off again")
	check(not Fx.reduce_motion_on(null), "no Needs: shake allowed")
	n.free()


func test_hit_stop() -> void:
	print("[hit-stop] 50 ms freeze of the host on the real clock")
	var g: Control = Moth.new()
	g.size = Vector2(1080, 1400)
	root.add_child(g)
	g.config = {"seed": 7}
	g.start()
	var f: Fx = g.fx()
	check(f.get_parent() == g and g.fx() == f, "fx() is one overlay per game")
	check(f.hit_stop(), "applied to a minigame")
	check(is_equal_approx(g.hit_stop_left, Fx.HIT_STOP_SECONDS), "50 ms")
	var t0: float = g._state_t
	g._process(0.03)
	check(g._state_t == t0, "frozen during the stop")
	g._process(0.03)
	g._process(0.03)
	check(g._state_t > t0, "runs again after")
	g.hit_stop(0.01)
	g.hit_stop(0.2)
	check(is_equal_approx(g.hit_stop_left, 0.2), "longest stop wins")
	g.free()
	var plain := make_fx()
	check(not plain.hit_stop(), "no-op on a host without hit_stop")
	drop(plain)


func test_squash() -> void:
	print("[squash] tap squash springs back")
	check(Fx.squash_at(0.0) == Fx.SQUASH, "starts squashed")
	check(Fx.squash_at(Fx.SQUASH_SECONDS).is_equal_approx(Vector2.ONE), "back to 1")
	var f := make_fx()
	check(f.squash_scale("moth") == Vector2.ONE, "idle object at 1")
	f.squash("moth")
	check(f.squash_scale("moth").x > 1.0 and f.squash_scale("moth").y < 1.0, "wide and flat on the tap")
	f.step(Fx.SQUASH_SECONDS + 0.01)
	check(f.squash_scale("moth") == Vector2.ONE, "done")
	drop(f)


func test_particles() -> void:
	print("[particles] sparks, embers, confetti; at most 200 alive")
	var f := make_fx()
	for kind in ["spark", "ember", "confetti"]:
		var n := f.burst(kind, Vector2(100, 100))
		check(n == int(Fx.BURSTS[kind]["count"]), "%s burst emits %d" % [kind, n])
	var nodes := 0
	for c in f.get_children():
		if c is CPUParticles2D:
			nodes += 1
			check(c.one_shot and c.emitting, "one-shot burst")
	check(nodes == 3, "three particle nodes")
	for i in 20:
		f.burst("confetti", Vector2.ZERO)
	check(f.particles_alive() == Fx.MAX_PARTICLES, "budget holds at %d (%d)" % [Fx.MAX_PARTICLES, f.particles_alive()])
	check(f.burst("spark", Vector2.ZERO) == 0, "nothing emitted over budget")
	f.step(2.0)
	check(f.particles_alive() == 0 and not f.busy(), "bursts expire")
	check(f.burst("spark", Vector2.ZERO) > 0, "budget frees up")
	drop(f)


func test_glow() -> void:
	print("[glow] shared soft circle, cached")
	var t := Fx.glow_texture()
	check(t != null and t.get_width() == Fx.GLOW_TEX_SIZE, "glow texture %dpx" % Fx.GLOW_TEX_SIZE)
	check(Fx.glow_texture() == t, "built once")
	check(Fx.glow_material().blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "additive material")
	var f := make_fx()
	f.flare(Vector2(10, 10), 50.0)
	check(f.busy(), "a flare animates")
	f.step(Fx.FLARE_SECONDS + 0.01)
	check(not f.busy(), "and ends")
	drop(f)


func test_haptics() -> void:
	print("[haptics] web_android vibrates, iPhone web does not (§2.4)")
	var feats := func(list: Array) -> Callable:
		return func(tag: String) -> bool: return list.has(tag)
	check(Base.vibrate_supported_by(feats.call(["web", "web_android"])), "Android browser: yes")
	check(not Base.vibrate_supported_by(feats.call(["web", "web_ios"])), "iPhone browser: no API")
	check(not Base.vibrate_supported_by(feats.call(["web", "web_ios", "mobile"])), "iPhone browser even if mobile is set")
	check(not Base.vibrate_supported_by(feats.call(["web", "web_windows"])), "desktop browser: no")
	check(Base.vibrate_supported_by(feats.call(["mobile", "android"])), "native phone: yes")
	check(not Base.vibrate_supported_by(feats.call(["pc", "windows"])), "desktop: no")
	check(not Base.vibrate_supported(), "headless desktop run reports no vibration")
	check(not Base.haptic("tick") and not Base.haptic("fail") and not Base.haptic("strong"), "haptics are a no-op here")
	# no game guards its vibration with the old mobile-only test any more
	for f in ["coaster_flip", "neon_moth", "pour_perfect", "shake_serve", "soi_dash"]:
		var src := FileAccess.get_file_as_string("res://scripts/minigames/%s.gd" % f)
		check(src.find("vibrate_handheld") < 0, "%s calls the shared helper" % f)


func card_for(result: Dictionary, n: Node, anim := true) -> Control:
	var card: Control = CardScript.new()
	card.animate = anim
	card.size = Vector2(1080, 1920)
	root.add_child(card)
	card.show_result(result, n)
	return card


func moth_result(points: int, tier: int, extra := {}) -> Dictionary:
	return {"game_id": "neon_moth", "action_id": "neon_moth", "need_id": "nightlife", "key": "",
		"score": points / 100.0, "points": points, "tier": tier, "miss": tier < 0, "extra": extra}


func find_named(node: Node, prefix: String) -> Array:
	var out := []
	for c in node.get_children():
		if str(c.name).begins_with(prefix):
			out.append(c)
		out.append_array(find_named(c, prefix))
	return out


func test_result_moment() -> void:
	print("[result] stamp slams, score counts up 0.6 s, NEW BEST ribbon lands")
	check(CardScript.count_up(80, 0.0) == 0 and CardScript.count_up(80, CardScript.COUNT_SECONDS) == 80, "count-up 0 -> 80")
	check(CardScript.count_up(80, 0.3) > 40 and CardScript.count_up(80, 0.3) < 80, "ease-out midway (%d)" % CardScript.count_up(80, 0.3))
	check(is_equal_approx(CardScript.stamp_scale_at(0.0), CardScript.STAMP_FROM_SCALE), "stamp starts big")
	check(CardScript.stamp_scale_at(CardScript.STAMP_SECONDS + 0.06) < 1.0, "landing dip")
	check(CardScript.stamp_scale_at(CardScript.ANIM_END) == 1.0, "stamp at rest")
	check(CardScript.ribbon_scale_at(CardScript.RIBBON_AT - 0.01) == 0.0, "ribbon waits for the count")
	var over := 0.0
	for i in 40:
		over = maxf(over, CardScript.ribbon_scale_at(CardScript.RIBBON_AT + i * 0.01))
	check(over > 1.0, "ribbon overshoots (%.2f)" % over)
	check(is_equal_approx(CardScript.ribbon_scale_at(CardScript.ANIM_END), 1.0), "ribbon lands at 1")

	var n := fresh_needs()
	n.ext["minigame_best"] = {"neon_moth": 70}
	var card := card_for(moth_result(82, 1, {"rival": {"regular": "tt", "points": 92}}), n)
	card.set_process(false)
	check(card.outcome["new_best"] and card.outcome["prev_best"] == 70, "outcome carries the old best")
	check(card.score_shown() == 0, "score starts at 0 (%d)" % card.score_shown())
	check(card._stamp.scale.x > 2.0, "stamp starts big (%.2f)" % card._stamp.scale.x)
	check(card._ribbon != null and not card._ribbon.visible, "ribbon hidden at first")
	card.advance_anim(CardScript.STAMP_SECONDS + 0.01)
	check(card._landed, "stamp landed")
	check(card._fx.trauma > 0.0, "landing shakes the card")
	check(card._fx.particles_alive() > 0, "a great round throws sparks")
	card.advance_anim(0.3)
	var mid: int = card.score_shown()
	check(mid > 0 and mid < 82, "counting (%d)" % mid)
	card.advance_anim(CardScript.ANIM_END)
	check(card.score_shown() == 82, "lands on 82 (%d)" % card.score_shown())
	check(card._ribbon.visible and is_equal_approx(card._ribbon.scale.x, 1.0), "NEW BEST ribbon shown")
	check(card._comp.modulate.a == 1.0, "competition lines faded in")
	var lines := find_named(card, "Compete_")
	check(lines.size() == 2, "two competition lines (%d)" % lines.size())
	check(is_equal_approx(card._stamp.rotation_degrees, CardScript.STAMP_REST_DEG), "stamp rests tilted")
	check(card._glow.visible, "great: glow behind the stamp")
	card.free()

	# Buttons work from the first frame (the moment never blocks).
	var n2 := fresh_needs()
	var card2 := card_for(moth_result(40, 0), n2)
	card2.set_process(false)
	var done_hit := [false]
	card2.done.connect(func(): done_hit[0] = true)
	var any_done := false
	for b in _all_buttons(card2):
		if b.text == S.t("mg.result.done"):
			b.pressed.emit()
			any_done = true
	check(any_done and done_hit[0], "DONE works before the moment ends")
	check(card2._ribbon == null, "first score: no ribbon")
	check(not card2._glow.visible, "good tier: no glow")
	card2.free()

	# animate = false opens in the end state, without the landing effects.
	var n3 := fresh_needs()
	var card3 := card_for(moth_result(95, 2), n3, false)
	check(card3.score_shown() == 95 and card3._stamp.scale == Vector2.ONE, "no-anim card opens at rest")
	check(card3._fx.trauma == 0.0 and card3._fx.particles_alive() == 0, "no shake, no confetti")
	card3.free()

	# Reduce motion: the landing never shakes.
	var n4 := fresh_needs()
	Fx.set_reduce_motion(n4, true)
	var card4 := card_for(moth_result(95, 2), n4)
	card4.set_process(false)
	card4.advance_anim(CardScript.STAMP_SECONDS + 0.01)
	check(card4._landed and card4._fx.trauma == 0.0, "reduce motion: no shake on landing")
	check(card4._fx.particles_alive() >= int(Fx.BURSTS["confetti"]["count"]), "perfect: confetti still falls")
	card4.free()

	# A miss: ash stamp, no ribbon, no gain, prev best kept.
	var n5 := fresh_needs()
	n5.ext["minigame_best"] = {"neon_moth": 60}
	var card5 := card_for(moth_result(10, -1), n5)
	card5.set_process(false)
	card5.advance_anim(CardScript.ANIM_END)
	check(card5.outcome["miss"] and card5.outcome["prev_best"] == 60 and card5._ribbon == null, "miss: no ribbon")
	check(card5._stamp.get_theme_color("font_color") == CardScript.TIER_COLORS[-1], "miss stamp in ash")
	card5.free()
	for x in [n, n2, n3, n4, n5]:
		x.free()


func _all_buttons(node: Node) -> Array:
	var out := []
	for c in node.get_children():
		if c is Button:
			out.append(c)
		out.append_array(_all_buttons(c))
	return out


func test_competition_lines() -> void:
	print("[compete] over your best, tonight's regular to beat")
	var o := {"new_best": true, "prev_best": 70}
	var lines: Array = CardScript.competition_lines(moth_result(82, 1), o)
	check(lines.size() == 1 and lines[0]["text"] == "+12 over your best", "over best (%s)" % str(lines))
	lines = CardScript.competition_lines(moth_result(82, 1), {"new_best": false, "prev_best": 90})
	check(lines.is_empty(), "no line when the best is not beaten and no rival")
	lines = CardScript.competition_lines(moth_result(84, 1, {"rival": {"name": "Tt", "points": 92}}), {})
	check(lines.size() == 1 and lines[0]["text"] == "Tt 92 · 8 short", "short of the regular (%s)" % str(lines))
	lines = CardScript.competition_lines(moth_result(95, 2, {"rival": {"name": "Tt", "points": 92}}), {})
	check(lines[0]["text"] == "You beat Tt (92)", "beat the regular (%s)" % str(lines))
	lines = CardScript.competition_lines(moth_result(92, 2, {"rival": {"name": "Tt", "points": 92}}), {})
	check(lines[0]["text"] == "Level with Tt (92)", "level (%s)" % str(lines))
	lines = CardScript.competition_lines(moth_result(50, 0, {"rival": {"regular": "hiro", "points": 70}}), {})
	check(lines.size() == 1 and lines[0]["text"].ends_with("70 · 20 short") and not lines[0]["text"].begins_with("hiro"),
		"regular id resolves to the cast name (%s)" % str(lines))
	TranslationServer.set_locale("th")
	lines = CardScript.competition_lines(moth_result(84, 1, {"rival": {"name": "Tt", "points": 92}}), {})
	check(lines[0]["text"].find("8") >= 0 and lines[0]["text"] != "Tt 92 · 8 short", "Thai line (%s)" % lines[0]["text"])
	TranslationServer.set_locale("en")


func test_neon_moth_proof() -> void:
	print("[neon moth] the kit answers a gate and a singe")
	var g: Control = Moth.new()
	g.size = Vector2(1080, 1400)
	g.config = {"seed": 20261115}
	root.add_child(g)
	g.start()
	var t := 0.0
	while g.gates_passed == 0 and not g.done and t < 30.0:
		var nx: int = g.next_gate()
		var target: float = g.gap_y[nx] if nx < Moth.GATES else Moth.FIELD.y * 0.5
		if g.state != Moth.State.INTRO and g.y > target + 30.0 and g.vy >= 0.0:
			g.flap()
		g.advance(STEP)
		t += STEP
	check(g.gates_passed == 1, "first gate passed")
	var f: Fx = g.fx()
	f.auto_step = false
	check(f.pops_alive() == 1 and f.combo == 1, "gate: a pop and a combo step")
	check(f.particles_alive() > 0 and f.busy(), "gate: sparks and a flare")
	var before := f.particles_alive()
	g._singe()
	check(f.trauma > 0.0, "singe shakes")
	check(f.edge_amount() == 1.0, "singe: red edge")
	check(f.combo == 0, "singe breaks the combo")
	check(f.particles_alive() > before, "singe: embers")
	g.free()
