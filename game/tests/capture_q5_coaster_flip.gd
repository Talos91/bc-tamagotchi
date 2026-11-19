extends SceneTree
## Real-render screenshots of Coaster Flip after job Q5 (docs/design/11-minigame-quality.md §1.2, §2.3, §3, §4.1), not
## a pass/fail test. Hidden desktop only (PROJECT Tests, 2026-11-15):
##   godot --path . --audio-driver Dummy --resolution 540x960 --script res://tests/capture_q5_coaster_flip.gd -- [out dir]
## Each shot renders in a SubViewport of the exact size (portrait 1080x1920, landscape 1920x1080). A first round is
## played off-screen so the shots carry tonight's ghost stack; then: the first seconds (swipe coach), the stack rising
## with the closing ring, the catch moment (rings met, ring lit), the catch (+1), a drop (too early), a drifted ring
## late in a run, and the result card with the regular to beat and the board line.

const CardScript = preload("res://scripts/minigames/result_card.gd")
const NeedsScript = preload("res://scripts/needs.gd")
const Game = preload("res://scripts/minigames/coaster_flip.gd")
const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

const PORTRAIT := Vector2i(1080, 1920)
const LANDSCAPE := Vector2i(1920, 1080)
const STEP := 1.0 / 120.0
const SEED := 20261119


class Store:
	extends RefCounted
	var ext := {}


var out_dir := "res://../docs/art/screens/q5-coaster-flip"
var store := Store.new()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	TranslationServer.set_locale("en")
	S.install()
	_run()


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


func _shot(vp: SubViewport, name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir.path_join(name + ".png"))
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _game(vp: SubViewport, sz: Vector2i) -> Control:
	var g: Control = Game.new()
	g.size = Vector2(sz)
	g.config = {"seed": SEED, "regular": "jules"}
	g.rivals_store = store
	vp.add_child(g)
	g.start()
	g.set_process(false)
	g.fx().auto_step = false
	return g


func _adv(g: Control, secs: float) -> void:
	var t := 0.0
	while t < secs and not g.done:
		g.advance(STEP)
		g.fx().step(STEP)
		t += STEP


func _frames(g: Control, n: int) -> void:
	for i in n:
		g.advance(1.0 / 60.0)
		g.fx().step(1.0 / 60.0)
		await process_frame


## One clean flip: flick, wait for the rings to meet, tap, settle.
func _catch(g: Control) -> void:
	g.flick()
	while g.state == Game.State.FLIGHT and g.flight_t < g.apex_time():
		g.advance(STEP)
		g.fx().step(STEP)
	g.tap()
	_adv(g, Game.RESULT_SECONDS + 0.02)


func _ghost_round() -> void:
	var vp := _viewport(PORTRAIT)
	var g := _game(vp, PORTRAIT)
	_adv(g, Game.INTRO_SECONDS + 0.05)
	for i in 5:
		_catch(g)
	g.abandon()
	print("ghost round: best run %d" % g.best_run)
	vp.queue_free()
	await process_frame


func _play(sz: Vector2i, tag: String) -> Dictionary:
	var vp := _viewport(sz)
	var g := _game(vp, sz)
	# the first seconds: the swipe coach over the stack, CATCH HERE on the ring, the ghost stack
	await _frames(g, 90)
	await _shot(vp, "%s-1-first-seconds" % tag)
	g.flick()
	while g.flight_t < g.apex_time() * 0.45:
		g.advance(STEP)
		g.fx().step(STEP)
	await _frames(g, 1)
	await _shot(vp, "%s-2-rising" % tag)
	while g.flight_t < g.apex_time() - 0.01:
		g.advance(STEP)
		g.fx().step(STEP)
	await _frames(g, 1)
	await _shot(vp, "%s-3-rings-meet" % tag)
	g.tap()
	await _frames(g, 4)
	await _shot(vp, "%s-4-catch" % tag)
	_adv(g, Game.RESULT_SECONDS)
	# a drop: tapped too early
	g.flick()
	_adv(g, 0.12)
	g.tap()
	await _frames(g, 8)
	await _shot(vp, "%s-5-drop-early" % tag)
	_adv(g, Game.RESULT_SECONDS)
	# a long run: the ring drifts from catch 6, the regular cheers, tonight's regular passed
	var result := {}
	g.finished.connect(func(r: Dictionary) -> void: result.merge(r, true))  # lambdas copy locals: fill the dict in place
	for i in Game.DRIFT_FROM + 1:
		_catch(g)
	_adv(g, 1.0)
	g.flick()
	while g.flight_t < g.apex_time() * 0.6:
		g.advance(STEP)
		g.fx().step(STEP)
	await _frames(g, 1)
	await _shot(vp, "%s-6-drift" % tag)
	while g.flight_t < g.apex_time():
		g.advance(STEP)
		g.fx().step(STEP)
	g.tap()
	_adv(g, Game.RESULT_SECONDS + 0.02)
	g.abandon()
	await _frames(g, 2)
	g.fx().visible = false
	var n: Node = NeedsScript.new()
	n.autosave = false
	n.save_path = "user://capture_q5_save.json"
	n.new_game()
	n.ext["minigame_best"] = {"coaster_flip": 60}
	n.meters["friends"] = 40.0
	var card: Control = CardScript.new()
	card.size = Vector2(sz)
	vp.add_child(card)
	card.show_result(result, n)
	card.set_process(false)
	while card.anim_t < 1.4:
		card.advance_anim(1.0 / 60.0)
		await process_frame
	await _shot(vp, "%s-7-result" % tag)
	vp.queue_free()
	await process_frame
	return result


func _run() -> void:
	await process_frame
	await _ghost_round()
	var r := await _play(PORTRAIT, "portrait")
	print("portrait result points %d extra %s" % [int(r.get("points", 0)), str(r.get("extra", {}))])
	r = await _play(LANDSCAPE, "landscape")
	print("landscape result points %d extra %s" % [int(r.get("points", 0)), str(r.get("extra", {}))])
	print("CAPTURE Q5 DONE")
	quit(0)
