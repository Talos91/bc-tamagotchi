extends SceneTree
## Screenshots of main.tscn in a real window (not headless). Run from game/, one size per run:
##   godot --path . --resolution 540x960 --script res://tools/capture_venue.gd -- --tag=portrait
##   godot --path . --resolution 960x540 --script res://tools/capture_venue.gd -- --tag=landscape
## (half of 1080x1920 and 1920x1080; orientation is undecided, so both are captured.)
## Writes <tag>-<shot>.png to docs/art/screens/v4/ (override with --out=DIR): the diorama
## gameplay camera in each zone, then eye-level cameras that show the ceiling, placed like the direction renders.
## The player and the patron crowd (Venue/Patrons) are in every shot.
## Prints the average frame rate per gameplay shot (vsync off).

const SHOTS := [
	{"name": "lobby", "player": Vector3(1.2, 0, 7.2)},
	{"name": "corridor", "player": Vector3(8.0, 0, 14.1)},
	{"name": "lounge", "player": Vector3(7.5, 0, 6.5)},
	{"name": "buffer", "player": Vector3(17.7, 0, 5.3)},
	{"name": "floor", "player": Vector3(30.0, 0, 6.7)},
	{"name": "bar", "player": Vector3(29.6, 0, 11.3)},
	{"name": "stage", "player": Vector3(30.75, 0, 6.3)},
	{"name": "raised", "player": Vector3(40.4, 0.15, 6.1)},
	{"name": "toilets", "player": Vector3(22.3, 0, 15.8)},
	{"name": "smoking", "player": Vector3(40.0, 0, 15.2)},
]
## Eye-level views matched to the real photos (docs/art/direction): 09 bar from the west end, 11 the raised east
## side from its south end, 14 the buffer zone's south (mirror) side looking at the window, 20 the smoking room's
## window side looking at the emergency exit.
const EYE := [
	{"name": "eye-P09-bar", "from": Vector3(22.6, 1.5, 11.6), "at": Vector3(33.0, 0.9, 13.6), "fov": 62.0, "player": Vector3(27.0, 0, 10.8)},
	{"name": "eye-P11-raised", "from": Vector3(40.2, 1.5, 10.6), "at": Vector3(38.6, 1.3, 1.0), "fov": 64.0, "player": Vector3(38.0, 0, 7.0)},
	{"name": "eye-P14-buffer", "from": Vector3(17.8, 1.4, 7.4), "at": Vector3(17.8, 1.1, 2.6), "fov": 66.0, "player": Vector3(16.6, 0, 5.4)},
	{"name": "eye-P20-smoking", "from": Vector3(39.4, 1.6, 13.2), "at": Vector3(40.2, 1.0, 18.0), "fov": 66.0, "player": Vector3(39.9, 0, 15.3)},
]

func _init() -> void:
	var tag := "shot"
	var out := "res://../docs/art/screens/v4"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var needs := root.get_node_or_null("Needs")
	if needs:
		needs.autosave = false
	var p: Player = main.get_node("Player")
	main.get_node("UI").visible = false
	for s in SHOTS:
		p.global_position = s.player
		p.velocity = Vector3.ZERO
		p.rig.snap()
		for i in 30:
			await process_frame
		var t0 := Time.get_ticks_usec()
		var frames := 0
		var gpu := 0.0
		var cpu := 0.0
		while Time.get_ticks_usec() - t0 < 2000000:
			await process_frame
			frames += 1
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		var fps := frames / ((Time.get_ticks_usec() - t0) / 1e6)
		await _save(out, tag, s.name)
		print("%s %s zone=%s fps=%.0f gpu=%.2fms render_cpu=%.2fms draw_calls=%d" % [tag, s.name, p.rig.zone, fps, gpu / frames, cpu / frames,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	# HUD check: joystick and needs debug HUD over the floor view
	main.get_node("UI").visible = true
	p.global_position = Vector3(30.0, 0, 6.7)
	p.rig.snap()
	for i in 30:
		await process_frame
	await _save(out, tag, "hud")
	main.get_node("UI").visible = false
	var cam := Camera3D.new()
	main.add_child(cam)
	for e in EYE:
		cam.fov = e.fov
		cam.keep_aspect = Camera3D.KEEP_HEIGHT if root.get_visible_rect().size.aspect() >= 1.0 else Camera3D.KEEP_WIDTH
		cam.look_at_from_position(e.from, e.at)
		cam.make_current()
		p.global_position = e.player
		p.velocity = Vector3.ZERO
		for i in 20:
			await process_frame
		await _save(out, tag, e.name)
	print("CAPTURE DONE ", out)
	quit()

func _save(out: String, tag: String, nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out.path_join("%s-%s.png" % [tag, nm]))
