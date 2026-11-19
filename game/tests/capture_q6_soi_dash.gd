extends SceneTree
## Real-render screenshots of Soi Dash with the look B sprites, the street life and the juice beats (job Q6,
## docs/design/11-minigame-quality.md §2.3), not a pass/fail test. Hidden desktop only (PROJECT Tests, 2026-11-15):
##   godot --path . --audio-driver Dummy --resolution 540x960 --script res://tests/capture_q6_soi_dash.gd -- [out dir]
## Each shot renders in a SubViewport of the exact size (portrait 1080x1920, landscape 1920x1080); the game fills the
## play area under a 200 px title band as in the minigame frame.

const Game = preload("res://scripts/minigames/soi_dash.gd")
const UI = preload("res://scripts/minigames/mg_ui.gd")
const S = preload("res://scripts/minigames/strings.gd")

const PORTRAIT := Vector2i(1080, 1920)
const LANDSCAPE := Vector2i(1920, 1080)
const DT := 1.0 / 60.0
const TOP := 200.0

var out_dir := "res://../docs/art/screens/q6-soi-dash"


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
	bg.color = UI.BG_BASE
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


func _game(vp: SubViewport, sz: Vector2i, cfg := {"seed": 20261115}) -> Control:
	var g: Control = Game.new()
	g.position = Vector2(0, TOP)
	g.size = Vector2(sz) - Vector2(0, TOP)
	g.config = cfg
	vp.add_child(g)
	g.start()
	g.set_process(false)
	g.fx().auto_step = false
	return g


func _step(g: Control, n: int) -> void:
	for i in n:
		g.advance(DT)
		g.fx().step(DT)


## Advances to street point `at` with a careful runner (same idea as the suite's bot), without frames.
func _run_to(g: Control, at: float, careful := true) -> void:
	while g.dist < at and not g.done:
		if careful:
			var ob: Dictionary = g.next_obstacle(g.lane)
			if not ob.is_empty():
				var d: float = float(ob["at"]) - g.dist
				if d < 0.35:
					if Game.hoppable(int(ob["kind"])):
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
		_step(g, 1)


## The first street point >= from where `kind` is in view ahead of the runner (d within [lo, hi]).
func _find(g: Control, kind: int, from: float, lo := 1.0, hi := 2.4) -> float:
	var best := 1e9
	for it in g.items:
		if int(it["kind"]) == kind and float(it["at"]) - hi >= from:
			best = minf(best, float(it["at"]))
	return best - (lo + hi) * 0.5 if best < 1e8 else from


func _shots(sz: Vector2i, tag: String) -> void:
	# 1. Warm-up: parked bikes and carts, notes, shophouses, the runner mid-stride.
	var vp := _viewport(sz)
	var g := _game(vp, sz)
	g.hop()
	_run_to(g, 4.0)
	await _shot(vp, "%s-1-warmup" % tag)
	# 2. A tuk-tuk rushing in, notes combo on screen.
	_run_to(g, _find(g, Game.Kind.TUK, g.dist + 0.5, 0.6, 2.0))
	await _shot(vp, "%s-2-tuktuk" % tag)
	# 3. A stray dog trotting across / a sleeping dog.
	_run_to(g, _find(g, Game.Kind.STRAY, g.dist + 0.5, 1.2, 2.0))
	await _shot(vp, "%s-3-stray" % tag)
	# 4. A monitor lizard crawling over, mid-hop with dust.
	_run_to(g, _find(g, Game.Kind.LIZARD, g.dist + 0.5, 1.3, 2.2))
	await _shot(vp, "%s-4-lizard" % tag)
	vp.queue_free()
	await process_frame
	# 5. A bump: shake, red edge, clock flash and -2 s.
	vp = _viewport(sz)
	g = _game(vp, sz)
	_run_to(g, 6.0)
	var ob: Dictionary = g.next_obstacle(g.lane)
	while not ob.is_empty() and Game.hoppable(int(ob["kind"])):
		g.move(1 if g.lane < 1 else -1)
		ob = g.next_obstacle(g.lane)
	var b0: int = g.bumps
	while g.bumps == b0 and not g.done:
		_step(g, 1)
	_step(g, 3)
	await _shot(vp, "%s-5-bump" % tag)
	# 6. The door: doors swing open, neon flares, confetti.
	_run_to(g, Game.RUN_SECONDS * Game.SPEED + 0.01)
	_step(g, 12)
	await _shot(vp, "%s-6-door" % tag)
	vp.queue_free()
	await process_frame


func _run() -> void:
	await process_frame
	await _shots(PORTRAIT, "portrait")
	await _shots(LANDSCAPE, "landscape")
	quit(0)
