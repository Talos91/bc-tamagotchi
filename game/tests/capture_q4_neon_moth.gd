extends SceneTree
## Real-render screenshots of Neon Moth after job Q4 (docs/design/11-minigame-quality.md §1.2, §2.3, §3, §4.1), not a
## pass/fail test. Hidden desktop only (PROJECT Tests, 2026-11-15):
##   godot --path . --audio-driver Dummy --resolution 540x960 --script res://tests/capture_q4_neon_moth.gd -- [out dir]
## Each shot renders in a SubViewport of the exact size (portrait 1080x1920, landscape 1920x1080). A first flight is
## flown off-screen so the shots carry tonight's ghost; then: intro (ghost hint, regular to beat), mid-flight with
## several gates on screen and the ghost, a singe, the sign reached, and the result card with the regular and board lines.

const CardScript = preload("res://scripts/minigames/result_card.gd")
const NeedsScript = preload("res://scripts/needs.gd")
const Moth = preload("res://scripts/minigames/neon_moth.gd")
const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

const PORTRAIT := Vector2i(1080, 1920)
const LANDSCAPE := Vector2i(1920, 1080)
const STEP := 1.0 / 120.0
const SEED := 20261119


class Store:
	extends RefCounted
	var ext := {}


var out_dir := "res://../docs/art/screens/q4-neon-moth"
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
	var g: Control = Moth.new()
	g.size = Vector2(sz)
	g.config = {"seed": SEED}
	g.rivals_store = store
	vp.add_child(g)
	g.start()
	g.set_process(false)
	g.fx().auto_step = false
	return g


## One bot step: flutter when below the gap. slop: how loose the flying is (the ghost flight flies tighter).
func _bot(g: Control, slop: float) -> void:
	var nx: int = g.next_gate()
	if g.state != Moth.State.INTRO and g.y > g.gap_center(nx) + slop and g.vy >= 0.0:
		g.flap()
	g.advance(STEP)
	g.fx().step(STEP)


func _frames(g: Control, n: int) -> void:
	for i in n:
		g.advance(1.0 / 60.0)
		g.fx().step(1.0 / 60.0)
		await process_frame


func _ghost_flight() -> void:
	var vp := _viewport(PORTRAIT)
	var g := _game(vp, PORTRAIT)
	var t := 0.0
	while not g.done and t < 80.0:
		_bot(g, 20.0)
		t += STEP
	print("ghost flight: gates %d sign %s" % [g.gates_passed, str(g.reached_sign)])
	vp.queue_free()
	await process_frame


func _play(sz: Vector2i, tag: String) -> Dictionary:
	var vp := _viewport(sz)
	var g := _game(vp, sz)
	await _frames(g, 20)
	await _shot(vp, "%s-1-intro" % tag)
	# mid-flight: into the bobbing second half, several gates on screen, the ghost alongside
	var t := 0.0
	while not g.done and g.gates_passed < 9 and t < 60.0:
		_bot(g, 45.0)
		t += STEP
	while not g.done and g.gates_on_screen() < 3 and t < 60.0:
		_bot(g, 45.0)
		t += STEP
	await _frames(g, 4)
	await _shot(vp, "%s-2-play" % tag)
	var keep_y: float = g.y
	g._singe()
	await _frames(g, 3)
	await _shot(vp, "%s-3-singe" % tag)
	g.blink = 0.0
	g.y = keep_y
	var result := {}
	g.finished.connect(func(r: Dictionary) -> void: result.merge(r, true))  # lambdas copy locals: fill the dict in place
	# fly on to the sign
	while not g.done and t < 120.0:
		_bot(g, 30.0)
		t += STEP
		if g.sign_x() < Moth.FIELD.x - 40.0 and g.sign_x() > Moth.MOTH_X + 120.0 and not g.has_meta("shot_sign"):
			g.set_meta("shot_sign", true)
			await _frames(g, 2)
			await _shot(vp, "%s-4-sign-ahead" % tag)
	await _frames(g, 6)
	await _shot(vp, "%s-5-sign-reached" % tag)
	g.fx().visible = false
	var n: Node = NeedsScript.new()
	n.autosave = false
	n.save_path = "user://capture_q4_save.json"
	n.new_game()
	n.ext["minigame_best"] = {"neon_moth": 60}
	n.meters["nightlife"] = 40.0
	var card: Control = CardScript.new()
	card.size = Vector2(sz)
	vp.add_child(card)
	card.show_result(result, n)
	card.set_process(false)
	while card.anim_t < 1.4:
		card.advance_anim(1.0 / 60.0)
		await process_frame
	await _shot(vp, "%s-6-result" % tag)
	vp.queue_free()
	await process_frame
	return result


func _run() -> void:
	await process_frame
	await _ghost_flight()
	var r := await _play(PORTRAIT, "portrait")
	print("portrait result points %d extra %s" % [int(r.get("points", 0)), str(r.get("extra", {}))])
	r = await _play(LANDSCAPE, "landscape")
	print("landscape result points %d extra %s" % [int(r.get("points", 0)), str(r.get("extra", {}))])
	print("CAPTURE Q4 DONE")
	quit(0)
