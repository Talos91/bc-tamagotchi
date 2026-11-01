## Top-down orthographic renders of the built venue (the real voxel room, not the diagram).
##   godot --path . --resolution 1920x1080 --script res://tools/capture_plan.gd -- --out=../docs/art/screens/plan
## Writes plan-render-venue.png (everything), plan-render-main.png, plan-render-lounge.png (lobby, corridor, lounge,
## buffer) and plan-render-southeast.png (bar end, toilets, smoking room). North (-z) is up.
extends SceneTree

const SHOTS := [
	{"name": "plan-render-venue", "centre": Vector3(21.5, 0, 7.5), "width": 48.0},
	{"name": "plan-render-main", "centre": Vector3(31.0, 0, 8.0), "width": 24.0},
	{"name": "plan-render-lounge", "centre": Vector3(9.0, 0, 7.0), "width": 20.0},
	{"name": "plan-render-southeast", "centre": Vector3(37.0, 0, 13.0), "width": 14.0},
]

func _init() -> void:
	var out := "res://../docs/art/screens/plan"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var needs := root.get_node_or_null("Needs")
	if needs:
		needs.autosave = false
	main.get_node("UI").visible = false
	var p: Node3D = main.get_node("Player")
	p.global_position = Vector3(1.2, 0, 7.2)
	# Hide anything above head height so the camera sees the floor (ceiling, roof, upper fixtures)
	for n in main.find_children("*", "VisualInstance3D", true, false):
		if n.global_position.y > 3.6:
			n.visible = false
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.near = 0.1
	cam.far = 80.0
	for s in SHOTS:
		cam.size = s.width
		var from: Vector3 = s.centre + Vector3(0, 30, 0)
		cam.look_at_from_position(from, s.centre, Vector3(0, 0, -1))
		cam.make_current()
		for i in 25:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(s.name + ".png"))
		print("saved ", s.name)
	print("PLAN CAPTURE DONE ", out)
	quit()
