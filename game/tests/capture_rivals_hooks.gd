extends SceneTree
## Real-render screenshots of Neon Pinball, Pour Perfect and Soi Dash with the shared mg_rivals competition
## (job rivals-hooks): in play (regular to beat, ghost) and the result card (the rival and board lines). Not a
## pass/fail test. Hidden desktop only (PROJECT Tests, 2026-11-15):
##   godot --path . --audio-driver Dummy --resolution 540x960 --script res://tests/capture_rivals_hooks.gd -- [out dir]
## Each shot renders in a SubViewport of the exact size (portrait 1080x1920, landscape 1920x1080).

const CardScript = preload("res://scripts/minigames/result_card.gd")
const NeedsScript = preload("res://scripts/needs.gd")
const Pinball = preload("res://scripts/minigames/neon_pinball.gd")
const Pour = preload("res://scripts/minigames/pour_perfect.gd")
const Soi = preload("res://scripts/minigames/soi_dash.gd")
const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

const PORTRAIT := Vector2i(1080, 1920)
const LANDSCAPE := Vector2i(1920, 1080)
const STEP := 1.0 / 120.0
const SEED := 20261119


class Store:
	extends RefCounted
	var ext := {}


var out_dir := "res://../docs/art/screens/rivals-hooks"
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


func _game(vp: SubViewport, sz: Vector2i, script: GDScript, config := {}) -> Control:
	var g: Control = script.new()
	g.size = Vector2(sz)
	g.config = config
	g.rivals_store = store
	vp.add_child(g)
	g.start()
	g.set_process(false)
	g.fx().auto_step = false
	return g


func _frames(g: Control, n: int) -> void:
	for i in n:
		g.advance(1.0 / 60.0)
		g.fx().step(1.0 / 60.0)
		await process_frame


func _card(vp: SubViewport, sz: Vector2i, g: Control, result: Dictionary, game: String, tag: String) -> void:
	g.fx().visible = false
	var n: Node = NeedsScript.new()
	n.autosave = false
	n.save_path = "user://capture_rivals_save.json"
	n.new_game()
	n.ext["minigame_best"] = {game: 40}
	n.meters["nightlife"] = 40.0
	var card: Control = CardScript.new()
	card.size = Vector2(sz)
	vp.add_child(card)
	card.show_result(result, n)
	card.set_process(false)
	while card.anim_t < 1.4:
		card.advance_anim(1.0 / 60.0)
		await process_frame
	await _shot(vp, tag)


# --- Pinball: no ghost; the regular to beat, passed in play, the board line on the result
func _pinball(sz: Vector2i, tag: String) -> void:
	var vp := _viewport(sz)
	var g := _game(vp, sz, Pinball)
	var result := {}
	g.finished.connect(func(r: Dictionary) -> void: result.merge(r, true))
	await _frames(g, 20)
	g.launch(0.9)
	g.points = 900
	await _frames(g, 30)
	await _shot(vp, "%s-pinball-1-play" % tag)
	g.points = 2250
	await _frames(g, 6)
	await _shot(vp, "%s-pinball-2-passed" % tag)
	g.finish(g.current_score())
	await _card(vp, sz, g, result, "neon_pinball", "%s-pinball-3-result" % tag)
	vp.queue_free()
	await process_frame


# --- Pour: a precise pour first (the ghost), then a second glass with its ghost lines
func _pour_pour(g: Control, wobble: float) -> void:
	await _frames(g, 100)
	for i in Pour.TARGETS.size():
		g.press()
		var guard := 0
		while g.level < Pour.TARGETS[i] + (wobble if i == 1 else 0.0) and guard < 5000:
			g.advance(1.0 / 240.0)
			g.fx().step(1.0 / 240.0)
			guard += 1
		g.release()
		await _frames(g, 60)


func _pour(sz: Vector2i, tag: String) -> void:
	var vp0 := _viewport(sz)
	var g0 := _game(vp0, sz, Pour)
	await _pour_pour(g0, 0.0)
	await _frames(g0, 90)
	vp0.queue_free()
	await process_frame
	var vp := _viewport(sz)
	var g := _game(vp, sz, Pour)
	var result := {}
	g.finished.connect(func(r: Dictionary) -> void: result.merge(r, true))
	await _frames(g, 110)
	await _shot(vp, "%s-pour-1-intro" % tag)
	g.press()
	while g.level < Pour.TARGETS[0] and g.state == Pour.State.POURING:
		g.advance(1.0 / 240.0)
		g.fx().step(1.0 / 240.0)
	g.release()
	await _frames(g, 60)
	await _shot(vp, "%s-pour-2-play" % tag)
	for i in range(1, Pour.TARGETS.size()):
		g.press()
		var guard := 0
		while g.level < Pour.TARGETS[i] + (0.04 if i == 1 else 0.0) and guard < 5000:
			g.advance(1.0 / 240.0)
			g.fx().step(1.0 / 240.0)
			guard += 1
		g.release()
		await _frames(g, 60)
	await _frames(g, 60)
	await _card(vp, sz, g, result, "pour_perfect", "%s-pour-3-result" % tag)
	vp.queue_free()
	await process_frame


# --- Soi Dash: a first run records the ghost runner; the second shows it and the HUD
func _soi_bot(g: Control, max_secs: float, stop_at: float) -> void:
	var t := 0.0
	while not g.done and t < max_secs and g.dist < stop_at:
		if g.state == Soi.State.RUNNING or g.state == Soi.State.INTRO:
			var ob: Dictionary = g.next_obstacle(g.lane)
			if not ob.is_empty():
				var d: float = float(ob["at"]) - g.dist
				if d < 0.35:
					if Soi.hoppable(int(ob["kind"])):
						if d < 0.25:
							g.hop()
					else:
						for dir in [1, -1]:
							var l: int = g.lane + dir
							if l >= -1 and l <= 1:
								var o2: Dictionary = g.next_obstacle(l)
								if o2.is_empty() or float(o2["at"]) - g.dist > 0.4:
									g.move(dir)
									break
		g.advance(STEP)
		g.fx().step(STEP)
		t += STEP


func _soi(sz: Vector2i, tag: String) -> void:
	var vp0 := _viewport(sz)
	var g0 := _game(vp0, sz, Soi, {"seed": SEED})
	_soi_bot(g0, 80.0, 1000.0)
	vp0.queue_free()
	await process_frame
	var vp := _viewport(sz)
	var g := _game(vp, sz, Soi, {"seed": SEED})
	var result := {}
	g.finished.connect(func(r: Dictionary) -> void: result.merge(r, true))
	await _frames(g, 20)
	await _shot(vp, "%s-soi-1-intro" % tag)
	# run a few steps off the ghost's line so both runners show, then play on
	_soi_bot(g, 60.0, 12.0)
	g.move(1 if g.ghost_lane_at(g.dist) <= float(g.lane) else -1)
	await _frames(g, 14)
	await _shot(vp, "%s-soi-2-play" % tag)
	_soi_bot(g, 80.0, 1000.0)
	await _frames(g, 6)
	await _card(vp, sz, g, result, "soi_dash", "%s-soi-3-result" % tag)
	vp.queue_free()
	await process_frame


func _run() -> void:
	await process_frame
	for pair in [[PORTRAIT, "portrait"], [LANDSCAPE, "landscape"]]:
		store = Store.new()
		await _pinball(pair[0], pair[1])
		await _pour(pair[0], pair[1])
		await _soi(pair[0], pair[1])
	print("CAPTURE RIVALS-HOOKS DONE")
	quit(0)
