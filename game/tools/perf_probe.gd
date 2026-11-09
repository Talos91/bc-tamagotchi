extends SceneTree
## Perf probe (perf-iphone 2026-11-10): Godot's render monitors on the start screen and inside, one line each.
## Windowed only (headless has no renderer): Godot --path game --resolution 750x1624 -s tools/perf_probe.gd [-- --skip-intro]

func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()

func _line(tag: String) -> void:
	var lights := 0
	var lit := 0
	var shad := 0
	for l in current_scene.find_children("*", "Light3D", true, false):
		lights += 1
		if l.is_visible_in_tree():
			lit += 1
			if l.shadow_enabled:
				shad += 1
	print("PERF %s fps=%d draws=%d objects=%d prims=%d vram=%.1fMB tex=%.1fMB buf=%.1fMB lights=%d visible=%d shadowed=%d static=%.1fMB" % [tag,
		Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, lights, lit, shad, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])

func _run() -> void:
	var ua := OS.get_cmdline_user_args()
	if "--cull-final" in ua:
		cull_final(ua[ua.find("--cull-final") + 1])
		return
	if "--cull-test" in OS.get_cmdline_user_args():
		cull_test()
		return
	for i in 180:
		await process_frame
	_line("first" if not "--skip-intro" in OS.get_cmdline_user_args() else "inside")
	var main = current_scene
	if "--skip-intro" in OS.get_cmdline_user_args():
		var rig = main.player.rig
		for z in rig._zones:
			var r: Rect2 = z.get_meta("rect")
			main.player.global_position = Vector3(r.get_center().x, main.player.global_position.y, r.get_center().y)
			for i in 60:
				await process_frame
			_line("in:" + str(z.name))
	quit()

## --cull-test: at the start screen, hide each top-level venue group alone; print draws and how many pixels change.
func cull_test() -> void:
	for i in 180:
		await process_frame
	var venue: Node = current_scene.get_node("Venue")
	var base := root.get_texture().get_image()
	_line("base")
	var hide_ok: Array = []
	for g in venue.get_children():
		if not g is Node3D or g.name in ["CameraZones", "Thresholds"]:
			continue
		g.visible = false
		for i in 4:
			await process_frame
		var img := root.get_texture().get_image()
		var diff := 0
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				var a := img.get_pixel(x, y)
				var b := base.get_pixel(x, y)
				if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.02:
					diff += 1
		print("CULL %s diff_px=%d draws=%d" % [g.name, diff, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		if diff == 0:
			hide_ok.append(g)
		g.visible = true
	for g in hide_ok:
		g.visible = false
	for i in 4:
		await process_frame
	_line("all-invisible-groups-hidden " + ",".join(hide_ok.map(func(n): return str(n.name))))
	quit()

const CULL := ["Patrons", "Stairs", "Buffer", "MainRoom", "Stage", "Tables", "Raised", "Bar", "Vestibule", "Smoking", "ClosedRooms", "Outside"]

func _diff(a: Image, b: Image, path: String) -> int:
	var d := Image.create(a.get_width(), a.get_height(), false, Image.FORMAT_RGB8)
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			var e := absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b)
			if e > 0.02:
				n += 1
			d.set_pixel(x, y, Color(minf(1.0, e * 8.0), 0, 0) if e > 0.02 else p.darkened(0.8))
	d.save_png(path)
	return n

## --cull-final <dir>: noise (two baselines) vs the cut set; saves base/cut/diff PNGs.
func cull_final(dir: String) -> void:
	for i in 180:
		await process_frame
	var venue: Node = current_scene.get_node("Venue")
	var b1 := root.get_texture().get_image()
	await process_frame
	var b2 := root.get_texture().get_image()
	_line("base")
	for n in CULL:
		venue.get_node(n).visible = false
	await process_frame
	await process_frame
	var c := root.get_texture().get_image()
	_line("cut")
	b1.save_png(dir + "/start-before.png")
	c.save_png(dir + "/start-after.png")
	print("NOISE b1-b2 px=", _diff(b1, b2, dir + "/diff-noise.png"), "  CUT b2-cut px=", _diff(b2, c, dir + "/diff-cut.png"))
	quit()
