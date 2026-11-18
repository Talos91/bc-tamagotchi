extends SceneTree
## Real-render screenshots of the Q1 juice kit (docs/design/11-minigame-quality.md §2.2), not a pass/fail test.
## Hidden desktop only (PROJECT Tests, 2026-11-15):
##   godot --path . --audio-driver Dummy --resolution 540x960 --script res://tests/capture_q1_juice.gd -- [out dir]
## Each shot renders in a SubViewport of the exact size (portrait 1080x1920, landscape 1920x1080), so the window size
## does not matter. Shots: the result moment at three times (stamp falling, landed + counting, at rest) for a perfect
## NEW BEST that beats tonight's regular, a great round short of the regular, a miss, and Neon Moth mid-flight with
## a pop, the combo and sparks.

const CardScript = preload("res://scripts/minigames/result_card.gd")
const NeedsScript = preload("res://scripts/needs.gd")
const Moth = preload("res://scripts/minigames/neon_moth.gd")
const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

const PORTRAIT := Vector2i(1080, 1920)
const LANDSCAPE := Vector2i(1920, 1080)

var out_dir := "res://../docs/art/screens/q1-juice"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	TranslationServer.set_locale("en")
	S.install()
	_run()


func _needs(best: int) -> Node:
	var n: Node = NeedsScript.new()
	n.autosave = false
	n.save_path = "user://capture_q1_save.json"
	n.new_game()
	if best > 0:
		n.ext["minigame_best"] = {"neon_moth": best}
	n.meters["nightlife"] = 40.0
	return n


func _viewport(sz: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = sz
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = UI.BG_DEEP
	bg.size = Vector2(sz)
	vp.add_child(bg)
	return vp


func _backdrop(vp: SubViewport, sz: Vector2i) -> void:
	# a finished Neon Moth flight behind the card, as in the game
	var g: Control = Moth.new()
	g.position = Vector2(0, 0)
	g.size = Vector2(sz)
	g.config = {"seed": 20261115}
	vp.add_child(g)
	g.start()
	g.set_process(false)
	for i in 900:
		g.advance(1.0 / 120.0)
	g.fx().visible = false


func _shot(vp: SubViewport, name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir.path_join(name + ".png"))
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _card(vp: SubViewport, sz: Vector2i, result: Dictionary, best: int) -> Control:
	var card: Control = CardScript.new()
	card.size = Vector2(sz)
	vp.add_child(card)
	card.show_result(result, _needs(best))
	card.set_process(false)  # the moment's clock is driven below so each shot lands at a known time
	return card


func _drive(card: Control, to_t: float) -> void:
	while card.anim_t < to_t:
		card.advance_anim(1.0 / 60.0)
		await process_frame


func _result(points: int, tier: int, rival: int) -> Dictionary:
	return {"game_id": "neon_moth", "action_id": "neon_moth", "need_id": "nightlife", "key": "",
		"score": points / 100.0, "points": points, "tier": tier, "miss": tier < 0,
		"extra": {"gates": 15, "sign": tier == 2, "seed": 20261115, "rival": {"regular": "tt", "points": rival}}}


func _moment(sz: Vector2i, tag: String, result: Dictionary, best: int, times: Array) -> void:
	var vp := _viewport(sz)
	_backdrop(vp, sz)
	var card := _card(vp, sz, result, best)
	for pair in times:
		await _drive(card, pair[0])
		await _shot(vp, "%s-%s" % [tag, pair[1]])
	vp.queue_free()
	await process_frame


func _moth(sz: Vector2i, tag: String) -> void:
	var vp := _viewport(sz)
	var g: Control = Moth.new()
	g.size = Vector2(sz)
	g.config = {"seed": 20261115}
	vp.add_child(g)
	g.start()
	g.set_process(false)
	var fx = g.fx()
	fx.auto_step = false  # the overlay runs on the game's stepped clock here, so pops expire on time
	var t := 0.0
	while g.gates_passed < 3 and not g.done and t < 40.0:
		var nx: int = g.next_gate()
		var target: float = g.gap_y[nx] if nx < Moth.GATES else Moth.FIELD.y * 0.5
		if g.state != Moth.State.INTRO and g.y > target + 30.0 and g.vy >= 0.0:
			g.flap()
		g.advance(1.0 / 120.0)
		fx.step(1.0 / 120.0)
		t += 1.0 / 120.0
	for i in 8:  # let the pop rise and the sparks spread for a few real frames
		g.advance(1.0 / 60.0)
		fx.step(1.0 / 60.0)
		await process_frame
	await _shot(vp, "%s-neon-moth-gate" % tag)
	g._singe()
	for i in 3:
		g.advance(1.0 / 60.0)
		fx.step(1.0 / 60.0)
		await process_frame
	await _shot(vp, "%s-neon-moth-singe" % tag)
	vp.queue_free()
	await process_frame


func _run() -> void:
	await process_frame
	var perfect := _result(96, 2, 92)
	var great := _result(82, 1, 92)
	var miss := _result(14, -1, 92)
	var times := [[0.10, "1-stamp"], [0.40, "2-count"], [1.30, "3-rest"]]
	await _moment(PORTRAIT, "portrait-perfect", perfect, 84, times)
	await _moment(PORTRAIT, "portrait-great", great, 70, [[1.30, "3-rest"]])
	await _moment(PORTRAIT, "portrait-miss", miss, 60, [[1.30, "3-rest"]])
	await _moment(LANDSCAPE, "landscape-perfect", perfect, 84, times)
	await _moth(PORTRAIT, "portrait")
	await _moth(LANDSCAPE, "landscape")
	print("CAPTURE Q1 DONE")
	quit(0)
