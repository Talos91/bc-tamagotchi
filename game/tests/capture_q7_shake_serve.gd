extends SceneTree
## Real-render screenshots of Shake & Serve after job Q7 (docs/design/11-minigame-quality.md §1.2, §2.3, §3, §4.1), not
## a pass/fail test. Hidden desktop only (PROJECT Tests, 2026-11-15):
##   godot --path . --audio-driver Dummy --resolution 540x960 --script res://tests/capture_q7_shake_serve.gd -- [out dir]
## Each shot renders in a SubViewport of the exact size (portrait 1080x1920, landscape 1920x1080): the recipe (level 1),
## mixing (a bottle pouring into the shaker), a wrong bottle, the shake on Nam's nod, the level change to Nam's special
## (restocked shelf, 4 bottles), the serve, and the result card with tonight's regular and the board place.

const CardScript = preload("res://scripts/minigames/result_card.gd")
const NeedsScript = preload("res://scripts/needs.gd")
const Game = preload("res://scripts/minigames/shake_serve.gd")
const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

const PORTRAIT := Vector2i(1080, 1920)
const LANDSCAPE := Vector2i(1920, 1080)
const STEP := 1.0 / 60.0
const NIGHT := 20411


class Store:
	extends RefCounted
	var ext := {}


var out_dir := "res://../docs/art/screens/q7-shake-serve"


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


func _frames(g: Control, n: int) -> void:
	for i in n:
		if not g.done:
			g.advance(STEP)
		g.fx().step(STEP)
		await process_frame


## Runs until the game reaches a state (bot picks right bottles and taps every nod unless told otherwise).
func _until(g: Control, cond: Callable, pick := true, shake := true) -> void:
	var guard := 0
	while not g.done and not cond.call() and guard < 6000:
		guard += 1
		if pick and g.state == Game.State.PICK:
			g.pick(g.wanted())
		if shake and g.state == Game.State.SHAKE:
			var i: int = g.taps.size()
			if i < Game.beats_of(g.order) and g._state_t >= g.nod_time(i) + 0.02:
				g.shake_tap()
		g.advance(STEP)
		g.fx().step(STEP)


func _play(sz: Vector2i, tag: String) -> Dictionary:
	var vp := _viewport(sz)
	var g: Control = Game.new()
	g.size = Vector2(sz)
	g.config = {"night": NIGHT}
	g.rivals_store = Store.new()
	vp.add_child(g)
	g.start()
	g.set_process(false)
	g.fx().auto_step = false
	var result := {}
	g.finished.connect(func(r: Dictionary) -> void: result.merge(r, true))
	# 1 recipe, level 1
	_until(g, func(): return g.state == Game.State.MEMO and g._state_t > 0.6, false, false)
	await _frames(g, 2)
	await _shot(vp, "%s-1-recipe-level1" % tag)
	# 2 mixing: first bottle flies and pours
	_until(g, func(): return g.state == Game.State.PICK, false, false)
	g.pick(g.wanted())
	await _frames(g, 20)
	await _shot(vp, "%s-2-mixing-pour" % tag)
	# 3 shake on a nod
	_until(g, func(): return g.state == Game.State.SHAKE and g.taps.size() >= 2 and g._state_t >= g.nod_time(2) - 0.01)
	g.shake_tap()
	await _frames(g, 3)
	await _shot(vp, "%s-3-shake-nod" % tag)
	# 4 serve
	_until(g, func(): return g.state == Game.State.SERVE and g._state_t > 0.5)
	await _frames(g, 2)
	await _shot(vp, "%s-4-serve" % tag)
	# 5 level 2 with a wrong bottle
	_until(g, func(): return g.order == 1 and g.state == Game.State.PICK, false, false)
	g.pick(g.wanted())
	g.pick("cola" if g.wanted() != "cola" else "bitters")
	await _frames(g, 4)
	await _shot(vp, "%s-5-level2-wrong-bottle" % tag)
	# 6 level change: Nam's special, restocked shelf, 4 bottles
	_until(g, func(): return g.order == 2 and g.state == Game.State.MEMO and g._state_t > 0.15)
	await _frames(g, 6)
	await _shot(vp, "%s-6-level3-change" % tag)
	_until(g, func(): return g.state == Game.State.PICK and g.order == 2, false, false)
	g.pick(g.wanted())
	g.pick(g.wanted())
	await _frames(g, 18)
	await _shot(vp, "%s-7-level3-mixing" % tag)
	_until(g, func(): return g.done)
	await _frames(g, 2)
	g.fx().visible = false
	var n: Node = NeedsScript.new()
	n.autosave = false
	n.save_path = "user://capture_q7_save.json"
	n.new_game()
	n.ext["minigame_best"] = {"shake_serve": 70}
	n.meters["drinks"] = 40.0
	var card: Control = CardScript.new()
	card.size = Vector2(sz)
	vp.add_child(card)
	card.show_result(result, n)
	card.set_process(false)
	while card.anim_t < 1.4:
		card.advance_anim(1.0 / 60.0)
		await process_frame
	await _shot(vp, "%s-8-result" % tag)
	vp.queue_free()
	await process_frame
	return result


func _run() -> void:
	await process_frame
	var r := await _play(PORTRAIT, "portrait")
	print("portrait result points %d extra %s" % [int(r.get("points", 0)), str(r.get("extra", {}))])
	r = await _play(LANDSCAPE, "landscape")
	print("landscape result points %d extra %s" % [int(r.get("points", 0)), str(r.get("extra", {}))])
	print("CAPTURE Q7 DONE")
	quit(0)
