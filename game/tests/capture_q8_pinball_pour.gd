extends SceneTree
## Real-render screenshots of Neon Pinball and Pour Perfect with the look B sprites and the juice beats (job Q8,
## docs/design/11-minigame-quality.md section 2.3), not a pass/fail test. Hidden desktop only (PROJECT Tests, 2026-11-15):
##   godot --path . --audio-driver Dummy --resolution 540x960 --script res://tests/capture_q8_pinball_pour.gd -- [out dir]
## Each shot renders in a SubViewport of the exact size (portrait 1080x1920, landscape 1920x1080).

const Pinball = preload("res://scripts/minigames/neon_pinball.gd")
const Pour = preload("res://scripts/minigames/pour_perfect.gd")
const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

const PORTRAIT := Vector2i(1080, 1920)
const LANDSCAPE := Vector2i(1920, 1080)
const DT := 1.0 / 60.0

var out_dir := "res://../docs/art/screens/q8-pinball-pour"


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


func _game(vp: SubViewport, sz: Vector2i, script: GDScript) -> Control:
	var g: Control = script.new()
	g.size = Vector2(sz)
	vp.add_child(g)
	g.start()
	g.set_process(false)
	g.fx().auto_step = false  # the overlay runs on the stepped clock so pops expire on time
	return g


func _frames(g: Control, n: int) -> void:
	for i in n:
		g.advance(DT)
		g.fx().step(DT)
		await process_frame


func _pour(sz: Vector2i, tag: String) -> void:
	# Mid-pour: stream, rising foam, the tap squashed.
	var vp := _viewport(sz)
	var g: Control = _game(vp, sz, Pour)
	await _frames(g, 100)
	g.press()
	while g.level < 0.20:
		g.advance(DT)
		g.fx().step(DT)
	await _frames(g, 6)
	await _shot(vp, "%s-pour-stream" % tag)
	vp.queue_free()
	await process_frame
	# PERFECT on the first line, then the second layer mid-pour with the first locked.
	vp = _viewport(sz)
	g = _game(vp, sz, Pour)
	await _frames(g, 100)
	g.press()
	while g.level < Pour.TARGETS[0]:
		g.advance(DT / 4.0)
	g.release()
	await _frames(g, 6)
	await _shot(vp, "%s-pour-perfect" % tag)
	await _frames(g, 60)
	g.press()
	while g.level < 0.48:
		g.advance(DT)
		g.fx().step(DT)
	await _frames(g, 4)
	await _shot(vp, "%s-pour-layer2" % tag)
	vp.queue_free()
	await process_frame
	# Overfill: foam spills over the rim.
	vp = _viewport(sz)
	g = _game(vp, sz, Pour)
	await _frames(g, 100)
	g.press()
	while g.spill < 0.06:
		g.advance(DT)
		g.fx().step(DT)
	await _frames(g, 5)
	await _shot(vp, "%s-pour-spill" % tag)
	vp.queue_free()
	await process_frame


func _pinball(sz: Vector2i, tag: String) -> void:
	var vp := _viewport(sz)
	var g: Control = _game(vp, sz, Pinball)
	for i in 6:
		g.lit[i] = true
	g.launch(1.0)
	var t := 0.0
	var start_pts: int = g.points
	while g.points < start_pts + 100 and not g.done and t < 20.0:
		g.advance(1.0 / 120.0)
		g.fx().step(1.0 / 120.0)
		t += 1.0 / 120.0
		g.set_flipper(0, g.pos.y > 760.0 and g.pos.x < 270.0)
		g.set_flipper(1, g.pos.y > 760.0 and g.pos.x >= 270.0)
	await _frames(g, 5)
	await _shot(vp, "%s-pinball-bumper" % tag)
	for k in 40:
		await _frames(g, 6)
		if g.ball_state != Pinball.Ball.LIVE:
			break
	await _shot(vp, "%s-pinball-play" % tag)
	vp.queue_free()
	await process_frame


func _run() -> void:
	await process_frame
	await _pour(PORTRAIT, "portrait")
	await _pour(LANDSCAPE, "landscape")
	await _pinball(PORTRAIT, "portrait")
	await _pinball(LANDSCAPE, "landscape")
	print("CAPTURE Q8 DONE")
	quit(0)
