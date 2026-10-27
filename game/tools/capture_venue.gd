extends SceneTree
## Screenshots of main.tscn in a real window (not headless). Run from game/, one size per run:
##   godot --path . --resolution 540x960 --script res://tools/capture_venue.gd -- --tag=portrait
##   godot --path . --resolution 960x540 --script res://tools/capture_venue.gd -- --tag=landscape
## (half of 1080x1920 and 1920x1080; orientation is undecided, so both are captured.)
## Writes <tag>-<shot>.png to docs/art/screens/2026-10-27-integration/ (override with --out=DIR): the diorama
## gameplay camera in each zone, then eye-level cameras that show the ceiling, placed like the direction renders.
## The player and the patron crowd (Venue/Patrons) are in every shot.
## Prints the average frame rate per gameplay shot (vsync off).

const SHOTS := [
	{"name": "lounge", "player": Vector3(4.5, 0, 6.0)},
	{"name": "entrance", "player": Vector3(11.0, 0, 6.0)},
	{"name": "floor", "player": Vector3(16.0, 0, 5.5)},
	{"name": "bar", "player": Vector3(16.6, 0, 7.4)},
	{"name": "stage", "player": Vector3(25.5, 0.5, 5.0)},
]
## Eye-level views matched to R01 (main room from the entrance), R02 (lounge), R03 (main room from the stage end)
const EYE := [
	{"name": "eye-R01-entrance", "from": Vector3(10.6, 1.9, 6.4), "at": Vector3(30.0, 1.4, 4.6), "fov": 62.0, "player": Vector3(14.5, 0, 5.6)},
	{"name": "eye-R02-lounge", "from": Vector3(6.6, 1.7, 9.6), "at": Vector3(3.4, 1.6, 0.0), "fov": 66.0, "player": Vector3(4.6, 0, 4.4)},
	{"name": "eye-R03-from-stage", "from": Vector3(23.6, 3.2, 8.4), "at": Vector3(12.0, 0.0, 2.5), "fov": 64.0, "player": Vector3(18.0, 0, 5.2)},
]

func _init() -> void:
	var tag := "shot"
	var out := "res://../docs/art/screens/2026-10-27-integration"
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
	p.global_position = Vector3(15.0, 0, 5.5)
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
