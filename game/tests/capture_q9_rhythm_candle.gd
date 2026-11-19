extends SceneTree
## Real-render screenshots of Front Row Rhythm and Candle Talk with the look B sprites, the juice beats and the rivals
## (job Q9, docs/design/11-minigame-quality.md section 2.3, 4.1), not a pass/fail test. Hidden desktop only (PROJECT
## Tests, 2026-11-15):
##   godot --path . --audio-driver Dummy --resolution 540x960 --script res://tests/capture_q9_rhythm_candle.gd -- [out dir]
## Each shot renders in a SubViewport of the exact size (portrait 1080x1920, landscape 1920x1080).

const CardScript = preload("res://scripts/minigames/result_card.gd")
const NeedsScript = preload("res://scripts/needs.gd")
const Rhythm = preload("res://scripts/minigames/front_row_rhythm.gd")
const Candle = preload("res://scripts/minigames/candle_talk.gd")
const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

const PORTRAIT := Vector2i(1080, 1920)
const LANDSCAPE := Vector2i(1920, 1080)
const DT := 1.0 / 120.0


class Store:
	extends RefCounted
	var ext := {}


var out_dir := "res://../docs/art/screens/q9-rhythm-candle"
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


func _game(vp: SubViewport, sz: Vector2i, script: GDScript, cfg: Dictionary) -> Control:
	var g: Control = script.new()
	g.size = Vector2(sz)
	g.rivals_store = store
	g.config = cfg
	vp.add_child(g)
	g.start()
	g.set_process(false)
	g.fx().auto_step = false  # the overlay runs on the stepped clock so pops expire on time
	return g


func _tick(g: Control, dt: float) -> void:
	g.advance(dt)
	g.fx().step(dt)


func _frames(g: Control, n: int) -> void:
	for i in n:
		_tick(g, DT)
		await process_frame


func _result_card(vp: SubViewport, sz: Vector2i, result: Dictionary, game_id: String, shot: String) -> void:
	var n: Node = NeedsScript.new()
	n.autosave = false
	n.save_path = "user://capture_q9_save.json"
	n.new_game()
	n.ext["minigame_best"] = {game_id: 40}
	var card: Control = CardScript.new()
	card.size = Vector2(sz)
	vp.add_child(card)
	card.show_result(result, n)
	card.set_process(false)
	while card.anim_t < 1.4:
		card.advance_anim(1.0 / 60.0)
		await process_frame
	await _shot(vp, shot)


# --- Front Row Rhythm ------------------------------------------------------------------------------

func _rhythm(sz: Vector2i, tag: String) -> void:
	var vp := _viewport(sz)
	var g: Control = _game(vp, sz, Rhythm, {"song": 1})
	await _frames(g, 30)
	await _shot(vp, "%s-rhythm-countin" % tag)
	var result := {}
	g.finished.connect(func(r: Dictionary) -> void: result.merge(r, true))
	var taken := 0
	var skip_next := false
	var shot_hit := false
	var shot_miss := false
	var guard := 0
	while not g.done and guard < 200000:
		guard += 1
		_tick(g, DT)
		for n in g.notes:
			if n["state"] == 0 and g.clock >= n["time"]:
				if taken == 14 and not skip_next:
					skip_next = true  # let this one go by: the puck dims
					continue
				if skip_next and taken == 14:
					continue
				g.tap(n["lane"])
				taken += 1
		if g.combo >= 8 and not shot_hit:
			shot_hit = true
			await _frames(g, 2)
			await _shot(vp, "%s-rhythm-perfect-combo" % tag)
		if skip_next and g.missed >= 1 and not shot_miss:
			shot_miss = true
			await _frames(g, 6)
			await _shot(vp, "%s-rhythm-miss-dim" % tag)
			taken = 15
		if guard % 4 == 0:
			await process_frame
	g.fx().visible = false
	await _result_card(vp, sz, result, "front_row_rhythm", "%s-rhythm-result" % tag)
	print(tag, " rhythm result points ", int(result.get("points", 0)), " extra ", str(result.get("extra", {})))
	vp.queue_free()
	await process_frame


# --- Candle Talk -----------------------------------------------------------------------------------

func _candle(sz: Vector2i, tag: String, regular: String) -> void:
	var vp := _viewport(sz)
	var g: Control = _game(vp, sz, Candle, {"regular": regular, "seed": 7})
	await _frames(g, 10)
	await _shot(vp, "%s-candle-ask" % tag)
	var result := {}
	g.finished.connect(func(r: Dictionary) -> void: result.merge(r, true))
	g.choose(g.line["best"])
	await _frames(g, 24)
	await _shot(vp, "%s-candle-card-flies" % tag)
	await _frames(g, 40)
	await _shot(vp, "%s-candle-best-flare-smile" % tag)
	while g.phase != Candle.Phase.ASK:
		await _frames(g, 6)
	for c in g.line["cards"]:
		if Candle.card_light(g.line, c) == 0.0:
			g.choose(c)
			break
	await _frames(g, 62)
	await _shot(vp, "%s-candle-miss-gutter" % tag)
	var guard := 0
	while not g.done and guard < 4000:
		guard += 1
		if g.phase == Candle.Phase.ASK:
			g.choose(g.line["best"])
		await _frames(g, 12)
	g.fx().visible = false
	await _result_card(vp, sz, result, "candle_talk", "%s-candle-result" % tag)
	print(tag, " candle result points ", int(result.get("points", 0)), " extra ", str(result.get("extra", {})))
	vp.queue_free()
	await process_frame


func _run() -> void:
	await process_frame
	await _rhythm(PORTRAIT, "portrait")
	await _rhythm(LANDSCAPE, "landscape")
	await _candle(PORTRAIT, "portrait", "tt")
	await _candle(LANDSCAPE, "landscape", "tt")
	await _candle(PORTRAIT, "portrait-jules", "jules")
	print("CAPTURE Q9 DONE")
	quit(0)
