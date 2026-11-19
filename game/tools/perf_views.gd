extends SceneTree
## Per-view cost probe (perf-telemetry 2026-11-19, owner item 41). Windowed only, on the private hidden desktop
## (PROJECT.md Tests, 2026-11-15): Godot --path game -s tools/perf_views.gd -- --win 720x1560 [--phone]
##   [--ablate base,patrons,anim,shadow,omni,ceiling,msaa] [--shots <dir>] [--frames 120] [--quality <0..2>]
## For every camera area the player is set in it, settled 90 frames, then `--frames` frames are timed. One line per
## area and ablation: wall ms (mean / p95), process ms, render CPU / GPU ms, draws, objects, primitives.
## Ablations (each alone, on top of base): patrons = crowd hidden and paused; anim = crowd shown, animation paused;
## shadow = key light shadow off; omni = every omni / spot light off; ceiling = nothing; msaa = MSAA off.

var _args := OS.get_cmdline_user_args()

func _arg(nm: String, def: String) -> String:
	var i := _args.find(nm)
	return _args[i + 1] if i >= 0 and i + 1 < _args.size() else def

func _initialize() -> void:
	seed(41)   # crowd phases and picks repeat run to run (with --fixed-fps 30 for same-frame captures)
	if "--nobatch" in _args:
		load("res://scripts/venue_batch.gd").enabled = false   # the before: no shadow proxies, no merged figures
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if "--win" in _args:
		var wh := _arg("--win", "720x1560").split("x")
		get_root().mode = Window.MODE_WINDOWED
		get_root().size = Vector2i(int(wh[0]), int(wh[1]))
	if "--phone" in _args:
		root.msaa_3d = Viewport.MSAA_DISABLED
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for i in 120:
		await process_frame
	var main = current_scene
	if not main.needs.has_avatar():
		main.needs.set_avatar(preload("res://scripts/avatar.gd").default_record(), "Probe", "")
	if main.start_screen:
		main.start_screen.skip()
	for i in 30:
		await process_frame
	if "--quality" in _args:
		var pq = load("res://scripts/perf_quality.gd")
		if pq:
			pq.apply_level(main, int(_arg("--quality", "2")))
	var surf := 0
	for mi in main.get_node("Venue/Patrons").find_children("*", "MeshInstance3D", true, false):
		surf += mi.mesh.get_surface_count() if mi.mesh else 0
	var prox := main.get_node("Venue").find_children("ShadowProxy*", "MeshInstance3D", true, false).size()
	print("VIEWS crowd_surfaces=%d shadow_proxies=%d" % [surf, prox])
	print("VIEWS window=%s pixels=%s msaa=%d" % [str(get_root().size), str(root.get_texture().get_size()), root.msaa_3d])
	var frames := int(_arg("--frames", "120"))
	var ablations := _arg("--ablate", "base").split(",")
	var shots := _arg("--shots", "")
	var areas := _arg("--areas", "")
	for z in main.player.rig._zones:
		if areas != "" and not str(z.name) in areas.split(","):
			continue
		var r: Rect2 = z.get_meta("rect")
		main.player.global_position = Vector3(r.get_center().x, main.player.global_position.y, r.get_center().y)
		for i in 90:
			await process_frame
		for ab in ablations:
			var undo := _ablate(main, ab)
			for i in 10:
				await process_frame
			var m := await _measure(frames)
			print("VIEW %-12s %-8s wall=%5.2f/%5.2f proc=%5.2f cpu=%5.2f gpu=%5.2f draws=%5d objects=%5d prims=%7d" % [
				str(z.name), ab, m.wall, m.wall95, m.proc, m.cpu, m.gpu, m.draws, m.objects, m.prims])
			if shots != "" and ab == "base":
				root.get_texture().get_image().save_png("%s/%s.png" % [shots, str(z.name)])
			undo.call()
	quit()

func _measure(n: int) -> Dictionary:
	var wall: Array[float] = []
	var proc := 0.0
	var cpu := 0.0
	var gpu := 0.0
	var draws := 0.0
	var objects := 0.0
	var prims := 0.0
	var t := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var now := Time.get_ticks_usec()
		wall.append((now - t) / 1000.0)
		t = now
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	wall.sort()
	var mean := 0.0
	for w in wall:
		mean += w
	return {"wall": mean / n, "wall95": wall[int(n * 0.95)], "proc": proc / n, "cpu": cpu / n, "gpu": gpu / n,
		"draws": int(draws / n), "objects": int(objects / n), "prims": int(prims / n)}

func _ablate(main: Node, ab: String) -> Callable:
	var venue: Node = main.get_node("Venue")
	match ab:
		"patrons":
			var p: Node3D = venue.get_node("Patrons")
			p.visible = false
			p.process_mode = Node.PROCESS_MODE_DISABLED
			return func(): p.visible = true; p.process_mode = Node.PROCESS_MODE_INHERIT
		"anim":
			var anims := venue.get_node("Patrons").find_children("*", "AnimationPlayer", true, false)
			for a in anims:
				a.pause()
			return func():
				for a in anims:
					a.play()
		"shadow":
			var k: DirectionalLight3D = venue.get_node("KeyLight")
			k.shadow_enabled = false
			return func(): k.shadow_enabled = true
		"omni":
			var ls: Array = []
			for l in venue.find_children("*", "Light3D", true, false):
				if not l is DirectionalLight3D and l.visible:
					l.visible = false
					ls.append(l)
			return func():
				for l in ls:
					l.visible = true
		"msaa":
			var was := root.msaa_3d
			root.msaa_3d = Viewport.MSAA_DISABLED
			return func(): root.msaa_3d = was
	return func(): pass
