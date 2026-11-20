extends SceneTree
## Real-render screenshots of the endless ramp (docs/design/15-minigame-ramp.md, card minigame-ramp-review): each of
## the 8 minigames near its cap level, with the frame's status line (level · points · lives) as a caption. Not a
## pass/fail test. Hidden desktop only (PROJECT Tests, 2026-11-15):
##   godot --path . --audio-driver Dummy --resolution 540x960 --script res://tests/capture_ramp.gd -- [out dir]
## Each game is warped toward its cap the cheapest honest way: a bot plays it (Moth, Shake & Serve, Rhythm, Candle),
## or its counters are set to the cap and play goes on from there (Coaster Flip, Soi Dash, Pinball, Pour Perfect).

const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")
const Moth = preload("res://scripts/minigames/neon_moth.gd")
const Shake = preload("res://scripts/minigames/shake_serve.gd")

const PORTRAIT := Vector2i(1080, 1920)
const STEP := 1.0 / 60.0
const SEED := 20261120


class Store:
	extends RefCounted
	var ext := {}


var out_dir := "res://../docs/art/screens/minigame-ramp"
var store := Store.new()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	TranslationServer.set_locale("en")
	S.install()
	_run()


func _game(id: String, config := {}) -> Array:
	var vp := SubViewport.new()
	vp.size = PORTRAIT
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = UI.BG_DEEP
	bg.size = Vector2(PORTRAIT)
	vp.add_child(bg)
	var g: Control = load("res://scripts/minigames/%s.gd" % id).new()
	g.position = Vector2(0, 110)
	g.size = Vector2(PORTRAIT) - Vector2(0, 110)
	var c := {"seed": SEED}
	c.merge(config, true)
	g.config = c
	if "rivals_store" in g:
		g.rivals_store = store
	vp.add_child(g)
	var cap := UI.label("", 12, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	cap.position = Vector2(0, 6)
	cap.size = Vector2(PORTRAIT.x, 100)
	vp.add_child(cap)
	g.start()
	g.set_process(false)
	g.fx().auto_step = false
	return [vp, g, cap]


func _step(g: Control, n := 1) -> void:
	for i in n:
		if g.done:
			return
		g.advance(STEP)
		g.fx().step(STEP)


func _shot(v: Array, name: String, title: String) -> void:
	var g: Control = v[1]
	(v[2] as Label).text = "%s\nlevel %d · %d points" % [title, g.ramp_level, g.record_points()]
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = (v[0] as SubViewport).get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir.path_join(name + ".png"))
	img.save_png(path)
	print("saved ", path, "  level ", g.ramp_level, "  points ", g.record_points(), "  done ", g.done)
	(v[0] as SubViewport).queue_free()


func _run() -> void:
	await _moth()
	await _coaster()
	await _shake()
	await _soi()
	await _pinball()
	await _pour()
	await _rhythm()
	await _candle()
	print("capture_ramp done")
	quit()


func _moth() -> void:
	var v := _game("neon_moth")
	var g: Control = v[1]
	var t := 0.0
	while not g.done and g.gates_cleared < 31 and t < 150.0:
		var nx: int = g.next_gate()
		if g.state != Moth.State.INTRO and g.y > g.gap_center(nx) + 10.0 and g.vy >= 0.0:
			g.flap()
		g.singes_left = maxi(g.singes_left, 2)   # keep the flight going to the cap for the picture
		_step(g)
		t += STEP
	await _shot(v, "1-neon-moth-cap", "Neon Moth")


func _coaster() -> void:
	var v := _game("coaster_flip")
	var g: Control = v[1]
	_step(g, 90)
	g.catches = 25
	g.run = 12
	g.level_up(6)
	g.flick()
	var t := 0.0
	while g.state != 0 and not g.ring_lit() and t < 3.0:
		_step(g)
		t += STEP
	await _shot(v, "2-coaster-flip-cap", "Coaster Flip")


func _shake() -> void:
	var v := _game("shake_serve")
	var g: Control = v[1]
	var guard := 0
	while not g.done and guard < 60000 and not (g.order >= 8 and g.state == Shake.State.SHAKE and g.taps.size() >= 3):
		guard += 1
		match g.state:
			Shake.State.PICK:
				g.pick(g.wanted())
			Shake.State.SHAKE:
				var i: int = g.taps.size()
				if i < Shake.beats_of(g.order) and g._state_t >= g.nod_time(i):
					g.shake_tap()
		_step(g)
	await _shot(v, "3-shake-serve-cap", "Shake & Serve")


func _soi() -> void:
	var v := _game("soi_dash")
	var g: Control = v[1]
	var t := 0.0
	while not g.done and t < 62.0:
		g.lives_left = 3   # an idle runner bumps; kept alive to reach the cap speed for the picture
		_step(g)
		t += STEP
	g.lives_left = 3
	_step(g, 30)
	await _shot(v, "4-soi-dash-cap", "Soi Dash")


func _pinball() -> void:
	var v := _game("neon_pinball")
	var g: Control = v[1]
	g.words = 6
	g.level_up(7)
	g.launch(0.9)
	_step(g, 70)
	await _shot(v, "5-neon-pinball-cap", "Neon Pinball")


func _pour() -> void:
	var v := _game("pour_perfect")
	var g: Control = v[1]
	_step(g, 120)
	for i in 9:
		g._next_glass()
	_step(g, 150)
	g.press()
	_step(g, 150)
	await _shot(v, "6-pour-perfect-cap", "Pour Perfect")


func _rhythm() -> void:
	var v := _game("front_row_rhythm")
	var g: Control = v[1]
	var guard := 0
	while not g.done and g.ramp_level < 15 and guard < 40000:
		guard += 1
		for n in g.notes:
			if int(n["state"]) == 0 and g.clock - float(n["time"]) >= -STEP * 0.5 and g.clock - float(n["time"]) < STEP * 0.5:
				g.tap(int(n["lane"]))
		g.missed = 0   # a clean picture at the cap: the capture bot is not the subject
		g.lives_left = 3
		_step(g)
	_step(g, 40)
	await _shot(v, "7-front-row-rhythm-cap", "Front Row Rhythm")


func _candle() -> void:
	var v := _game("candle_talk", {"regular": "tt"})
	var g: Control = v[1]
	var guard := 0
	while not g.done and g.turn < 13 and guard < 20000:
		guard += 1
		if g.phase == 0:
			g.choose(str(g.line.get("best", "")))
		_step(g)
	_step(g, 60)
	await _shot(v, "8-candle-talk-cap", "Candle Talk")
