extends SceneTree
## Shadow cost check (parity-measurements.md, phone budget). Run from game/ in a real window:
##   godot --path . --resolution 1080x1920 --script res://tools/measure_shadows.gd
## Puts the player on the floor view (the heaviest gameplay shot) and prints fps, GPU time and draw calls with
## the key light's shadow on / off and the PAR spot shadows on / off.

func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var needs := root.get_node_or_null("Needs")
	if needs:
		needs.autosave = false
	main.get_node("UI").visible = false
	var p: Player = main.get_node("Player")
	p.global_position = Vector3(16.0, 0, 5.5)
	p.rig.snap()
	var key: DirectionalLight3D = main.get_node("Venue/KeyLight")
	var spots: Array = []
	for n in main.get_node("Venue/Stage").get_children():
		if n is SpotLight3D and n.shadow_enabled:
			spots.append(n)
	for cfg in [[true, true], [true, false], [false, false]]:
		key.shadow_enabled = cfg[0]
		for s in spots:
			s.shadow_enabled = cfg[1]
		for i in 30:
			await process_frame
		var t0 := Time.get_ticks_usec()
		var frames := 0
		var gpu := 0.0
		while Time.get_ticks_usec() - t0 < 2000000:
			await process_frame
			frames += 1
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		print("SHADOWS key=%s spots=%s fps=%.0f gpu=%.2fms draw_calls=%d" % [cfg[0], cfg[1],
			frames / ((Time.get_ticks_usec() - t0) / 1e6), gpu / frames,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	quit()
