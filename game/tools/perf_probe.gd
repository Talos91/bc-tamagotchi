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
	if "--variants" in ua:
		variants(ua[ua.find("--variants") + 1], ua[ua.find("--variants") + 2])
		return
	if "--cull-final" in ua:
		cull_final(ua[ua.find("--cull-final") + 1])
		return
	if "--door" in ua:
		door(int(ua[ua.find("--door") + 1]) if ua.size() > ua.find("--door") + 1 and ua[ua.find("--door") + 1].is_valid_int() else 2)
		return
	if "--door-gpu" in ua:
		door_gpu(float(ua[ua.find("--door-gpu") + 1]))
		return
	if "--door-shots" in ua:
		door_shots(ua[ua.find("--door-shots") + 1])
		return
	if "--door-cull" in ua:
		door_cull(ua[ua.find("--door-cull") + 1])
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

## --variants <dir> <tag>: portrait captures of the look options for the owner card: base (MSAA 2x, full res), MSAA
## off, 3D at 0.75 scale. Run at 1080x1920 for those, and at 720x1280 (tag dpr2) for the pixel-ratio cap at 2.
func variants(dir: String, tag: String) -> void:
	var vp := root.get_viewport()
	for i in 180:
		await process_frame
	var main = current_scene
	await _variant_set(vp, dir, tag, "start")
	if main.start_screen:
		main.start_screen.skip()
	for i in 30:
		await process_frame
	for area in ["Floor", "Bar", "Lounge"]:
		for z in main.player.rig._zones:
			if str(z.name) == area:
				var r: Rect2 = z.get_meta("rect")
				main.player.global_position = Vector3(r.get_center().x, main.player.global_position.y, r.get_center().y)
		for i in 90:
			await process_frame
		await _variant_set(vp, dir, tag, area.to_lower())
	quit()

func _variant_set(vp: Viewport, dir: String, tag: String, where: String) -> void:
	var opts := [["base", Viewport.MSAA_2X, 1.0]]
	if tag != "dpr2":
		opts += [["msaa-off", Viewport.MSAA_DISABLED, 1.0], ["scale075", Viewport.MSAA_2X, 0.75]]
	for o in opts:
		vp.msaa_3d = o[1]
		vp.scaling_3d_scale = o[2]
		for i in 6:
			await process_frame
		var img := vp.get_texture().get_image()
		if tag == "dpr2":
			img.resize(1080, 1920, Image.INTERPOLATE_BILINEAR)
		var nm: String = o[0] if tag != "dpr2" else "dpr2"
		img.save_jpg("%s/%s-%s.jpg" % [dir, where, nm], 0.9)
		_line("%s-%s" % [where, nm])
	vp.msaa_3d = Viewport.MSAA_2X
	vp.scaling_3d_scale = 1.0


# --- Door entrance (perf-door 2026-11-11, owner item 16) -----------------------------------------------------------

func _door_setup() -> Node:
	if "--phone" in OS.get_cmdline_user_args():
		root.msaa_3d = Viewport.MSAA_DISABLED   # phone graphics (phone_graphics.gd); the ratio cap is the window size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# --win WxH: set the window size from here (Windows shrank --resolution windows on this machine)
	if "--win" in OS.get_cmdline_user_args():
		var wh: PackedStringArray = OS.get_cmdline_user_args()[OS.get_cmdline_user_args().find("--win") + 1].split("x")
		get_root().mode = Window.MODE_WINDOWED
		get_root().size = Vector2i(int(wh[0]), int(wh[1]))
		for i in 10:
			await process_frame
		print("DOOR window=%s pixels=%s" % [str(get_root().size), str(root.get_texture().get_size())])
	# --old: every venue group back on at the door, as before perf-door (start_screen.gd HIDDEN_THROUGH_DOOR)
	preload("res://scripts/start_screen.gd").hide_through_door = not "--old" in OS.get_cmdline_user_args()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for i in 120:
		await process_frame
	var main = current_scene
	if not main.needs.has_avatar():
		main.needs.set_avatar(preload("res://scripts/avatar.gd").default_record(), "Probe", "")
	return main

func _phase_name(ss) -> String:
	if not is_instance_valid(ss):
		return "play"
	return ["title", "walk", "pull", "done"][ss.phase]

## --door [entries]: tap the start screen and log the entrance frame by frame (draws, objects, visible lights, CPU and
## GPU ms of the viewport, wall ms), then a summary per stretch: title, walk to the door, walk through the open door,
## pull-back, the first second of play. Entries after the first reload main.tscn in the same process (second entry).
func door(entries: int) -> void:
	for n in entries:
		if n > 0:
			change_scene_to_file("res://scenes/main.tscn")
			for i in 3:
				await process_frame
		var main = await _door_setup()
		remove_meta("said") if has_meta("said") else null
		print("DOOR entry=%d viewport=%s pixels=%s msaa=%d" % [n + 1, str(root.get_visible_rect().size), str(root.get_texture().get_size()), root.msaa_3d])
		var ss = main.start_screen
		var stats := {}
		var t0 := Time.get_ticks_usec()
		var last := t0
		var play_frames := 0
		ss.tap()
		while play_frames < 45:
			await process_frame
			var now := Time.get_ticks_usec()
			var ph := _phase_name(ss)
			if ph == "walk" and is_instance_valid(ss) and ss.door_open() > 0.0:
				ph = "walk-door"
			if ph == "play":
				play_frames += 1
			if ph == "pull" and not has_meta("said"):
				set_meta("said", true)
				print("DOOR entry=%d seen rects %s, patrons hidden %d of %d" % [n + 1, str(ss._seen_rects), ss._hidden_figs.size(), current_scene.get_node("Venue/Patrons").get_child_count() - 1])
			# --hide-layer2: hide every mesh on render layer 2 (the ceiling the diorama camera never draws) from door to play
			if "--hide-layer2" in OS.get_cmdline_user_args():
				if not has_meta("l2"):
					var l2: Array = []
					for v in current_scene.find_children("*", "VisualInstance3D", true, false):
						if (v as VisualInstance3D).layers & 2 and v.visible:
							l2.append(v)
					set_meta("l2", l2)
					print("DOOR layer2 meshes=%d: %s" % [l2.size(), ", ".join(l2.slice(0, 12).map(func(n): return str(current_scene.get_path_to(n))))])
				for v in get_meta("l2"):
					v.visible = ph == "play" or ph == "walk"
			# --hide A,B: keep these venue groups off from the door to play (what-if, not the game's own hiding)
			if "--hide" in OS.get_cmdline_user_args():
				for gname in OS.get_cmdline_user_args()[OS.get_cmdline_user_args().find("--hide") + 1].split(","):
					current_scene.get_node("Venue/" + gname).visible = ph == "play" or ph == "walk"
			var lit := 0
			for l in current_scene.find_children("*", "Light3D", true, false):
				if l.is_visible_in_tree():
					lit += 1
			var d := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			var cpu := RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
			var gpu := RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			var wall := (now - last) / 1000.0
			last = now
			if "--frames" in OS.get_cmdline_user_args():
				print("F t=%.2f %s draws=%d obj=%d lights=%d cpu=%.2f gpu=%.2f wall=%.1f" % [(now - t0) / 1e6, ph, d, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), lit, cpu, gpu, wall])
			if not stats.has(ph):
				stats[ph] = {"n": 0, "draws": [], "gpu": [], "cpu": [], "wall": [], "lights": 0}
			var st: Dictionary = stats[ph]
			st.n += 1
			st.draws.append(d)
			st.gpu.append(gpu)
			st.cpu.append(cpu)
			st.wall.append(wall)
			st.lights = maxi(st.lights, lit)
		for ph in ["walk", "walk-door", "pull", "play"]:
			if not stats.has(ph):
				continue
			var st: Dictionary = stats[ph]
			print("DOOR entry=%d %-9s frames=%3d draws mean=%5d max=%5d  lights max=%2d  gpu ms mean=%.2f max=%.2f  cpu ms mean=%.2f max=%.2f  wall ms mean=%.1f max=%.1f" % [n + 1, ph, st.n,
				_mean(st.draws), _max(st.draws), st.lights, _mean(st.gpu), _max(st.gpu), _mean(st.cpu), _max(st.cpu), _mean(st.wall), _max(st.wall)])
	quit()

func _mean(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(1.0, a.size())

func _max(a: Array) -> float:
	var m := 0.0
	for v in a:
		m = maxf(m, v)
	return m

## Pixels that differ between two captures (any channel by more than 1/255), counted on every pixel.
func _count_diff(a: PackedByteArray, b: PackedByteArray) -> int:
	if a == b:
		return 0
	var n := 0
	for i in range(0, a.size(), 4):
		if absi(a[i] - b[i]) > 1 or absi(a[i + 1] - b[i + 1]) > 1 or absi(a[i + 2] - b[i + 2]) > 1:
			n += 1
	return n

func _grab() -> PackedByteArray:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img.get_data()

## --door-cull <groups|path,path>: run the entrance at a fixed 30 fps (start with --fixed-fps 30), pause every
## SAMPLE frames and hide each candidate alone; a candidate is seen at that moment if any pixel changes. Prints, per
## candidate, the first and last time (seconds since the tap) it was seen. "groups" = the venue's top-level groups;
## otherwise a comma list of venue paths whose children are the candidates.
const SAMPLE := 2
func door_cull(what: String) -> void:
	var main = await _door_setup()
	var venue: Node = main.get_node("Venue")
	var cands: Array[Node3D] = []
	var rects: Array[Rect2] = preload("res://scripts/start_screen.gd").seen_rects(venue)
	if what == "figs":
		for f in venue.get_node("Patrons").get_children():
			if f is Node3D and f.name != "Spots":
				cands.append(f)
	elif what == "groups":
		for g in venue.get_children():
			if g is Node3D and not g is Light3D and not g.name in ["CameraZones", "Thresholds"]:
				cands.append(g)
	else:
		for path in what.split(","):
			for c in venue.get_node(path).get_children():
				if c is Node3D:
					cands.append(c)
	var seen := {}
	var ss = main.start_screen
	ss.tap()
	var frame := 0
	var samples := 0
	var noise := 0
	var after := 0
	while after < 4:
		await process_frame
		frame += 1
		if not is_instance_valid(ss):
			after += 1
		if frame % SAMPLE != 0 and is_instance_valid(ss):
			continue
		var t := frame / 30.0
		var ph := _phase_name(ss)
		paused = true
		var base := await _grab()
		var base2 := await _grab()
		noise = maxi(noise, _count_diff(base, base2))
		for c in cands:
			if not c.visible:
				continue
			c.visible = false
			var img := await _grab()
			c.visible = true
			var d := _count_diff(base, img)
			if d > 0:
				var key := str(venue.get_path_to(c))
				if not seen.has(key):
					seen[key] = [t, t, 0, ph, d]
					if what == "figs":
						print("DOORCULL FIG %s seen at %.2f (%s) px=%d pos=%s in_sight=%s" % [key, t, ph, d, str(c.global_position), preload("res://scripts/start_screen.gd").in_sight(c.global_position, rects)])
				seen[key][1] = t
				seen[key][2] += 1
				seen[key][4] = maxi(seen[key][4], d)
		paused = false
		samples += 1
	print("DOORCULL viewport=%s samples=%d noise_px=%d" % [str(root.get_visible_rect().size), samples, noise])
	for c in cands:
		var key := str(venue.get_path_to(c))
		if seen.has(key):
			var s: Array = seen[key]
			print("DOORCULL SEEN %-28s first=%.2f (%s) last=%.2f samples=%d max_px=%d" % [key, s[0], s[3], s[1], s[2], s[4]])
		else:
			print("DOORCULL NEVER %s" % key)
	quit()


func _gpu_ms(n: int) -> float:
	var s := 0.0
	for i in n:
		await RenderingServer.frame_post_draw
		s += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	return s / n

## --door-gpu <seconds after the door starts to open>: pause the entrance there and time the GPU with each candidate
## hidden alone (venue groups and the Lobby's / Lounge's children, the street's children, every visible light).
func door_gpu(after: float) -> void:
	var main = await _door_setup()
	var ss = main.start_screen
	ss.tap()
	var t_open := -1.0
	var t := 0.0
	while true:
		await process_frame
		t += 1.0 / 30.0
		if t_open < 0.0 and ss.door_open() > 0.0:
			t_open = t
		if t_open >= 0.0 and t - t_open >= after:
			break
	paused = true
	var base := await _gpu_ms(30)
	print("DOORGPU at door+%.2fs phase=%s base gpu=%.2f ms draws=%d cam_y=%.2f" % [after, _phase_name(ss), base, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), ss.cam.global_position.y])
	var cands: Array = []
	var venue: Node = main.get_node("Venue")
	for g in venue.get_children():
		if g is Node3D and g.is_visible_in_tree():
			cands.append(g)
	for path in ["Venue/Lobby", "Venue/Lounge", "Street"]:
		var n := main.get_node_or_null(path)
		if n:
			for c in n.get_children():
				if c is Node3D and c.is_visible_in_tree():
					cands.append(c)
	for c in main.get_children():
		if c is Node3D and c.name != "Venue" and c.name != "Street" and c.is_visible_in_tree():
			cands.append(c)
	for l in main.find_children("*", "Light3D", true, false):
		if l.is_visible_in_tree():
			cands.append(l)
	var rows: Array = []
	for c in cands:
		c.visible = false
		var g := await _gpu_ms(20)
		c.visible = true
		rows.append([base - g, str(main.get_path_to(c)) + (" (shadow)" if c is Light3D and c.shadow_enabled else "")])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 25):
		print("DOORGPU saves %6.2f ms  %s" % [r[0], r[1]])
	paused = false
	quit()


## --door-shots <dir>: the entrance at a fixed 30 fps (start with --fixed-fps 30); every 3rd frame from the door
## opening to play, pause and capture the frame twice: as the game draws it (perf-door hiding on) and with every
## group and patron the entrance hides shown again (as before perf-door). Same frame, same patrons, so any changed
## pixel is the hiding's. Prints the changed pixels per frame; saves both captures at the moments in SHOT_AT.
const SHOT_AT := {"door-open": 0.3, "doorway": 1.0, "pull-start": 2.0, "pull-mid": 2.6, "play": 3.6}
func door_shots(dir: String) -> void:
	var main = await _door_setup()
	var ss = main.start_screen
	ss.tap()
	var t := 0.0
	var t_open := -1.0
	var frame := 0
	var after := 0
	var worst := 0
	var n := 0
	var saved := {}
	while after < 10:
		await process_frame
		t += 1.0 / 30.0
		frame += 1
		if not is_instance_valid(ss):
			after += 1
		elif t_open < 0.0 and ss.door_open() > 0.0:
			t_open = t
		if t_open < 0.0 or frame % 3 != 0:
			continue
		var tt := t - t_open
		var shot := ""
		for k in SHOT_AT:
			if not saved.has(k) and tt >= SHOT_AT[k]:
				shot = k
		paused = true
		var hid: Array = []
		if is_instance_valid(ss):
			hid = ss._hidden.duplicate() + ss._hidden_figs.duplicate()
		var a := await _grab_img()
		for h in hid:
			h.visible = true
		var b := await _grab_img()
		for h in hid:
			h.visible = false
		var d := _count_diff(a.get_data(), b.get_data())
		worst = maxi(worst, d)
		n += 1
		print("SHOTS t=%.2f (%s) hidden=%d diff_px=%d" % [tt, _phase_name(ss), hid.size(), d])
		if shot != "":
			saved[shot] = true
			a.save_png("%s/after-%s.png" % [dir, shot])
			b.save_png("%s/before-%s.png" % [dir, shot])
		paused = false
	print("SHOTS frames=%d worst diff_px=%d viewport=%s" % [n, worst, str(root.get_texture().get_size())])
	quit()

func _grab_img() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
