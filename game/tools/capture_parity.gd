extends SceneTree
## Parity captures: main.tscn seen from the exact camera of direction renders 05 and 06
## (docs/art/parity-measurements.md, Cameras), at the render's aspect. Run from game/ in a real window:
##   godot --path . --resolution 1672x941 --script res://tools/capture_parity.gd -- --shot=R05 --n=1
##   godot --path . --resolution 1446x1087 --script res://tools/capture_parity.gd -- --shot=R06 --n=1
## Writes docs/art/screens/parity/<n>-<shot>-game.png. The ceiling layer is hidden and walls whose cutaway
## normal faces the camera are hidden, as in the renders. game/tools/parity_compose.py makes the two-up.

const SHOTS := {
	"R05": {"from": Vector3(9.4, 7.2, 7.0), "at": Vector3(20.5, 0.3, 6.6), "fov": 48.0, "player": Vector3(12.8, 0, 6.0)},
	"R06": {"from": Vector3(27.2, 6.8, 9.6), "at": Vector3(16.0, 0.3, 6.6), "fov": 54.0, "player": Vector3(17.0, 0, 7.6)},
}

func _init() -> void:
	var shot := "R05"
	var n := "0"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--n="):
			n = a.substr(4)
	var s: Dictionary = SHOTS[shot]
	var out := ProjectSettings.globalize_path("res://../docs/art/screens/parity")
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var needs := root.get_node_or_null("Needs")
	if needs:
		needs.autosave = false
	main.get_node("UI").visible = false
	var post := main.get_node_or_null("Post")
	if post:
		post.visible = false
	var p: Node3D = main.get_node("Player")
	p.global_position = s.player
	var rig = p.get("rig")
	if rig:   # the diorama rig runs its own cutaway every frame; this camera decides alone
		rig.process_mode = Node.PROCESS_MODE_DISABLED
	p.set("velocity", Vector3.ZERO)
	var cam := Camera3D.new()
	cam.fov = s.fov
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.cull_mask = 1
	cam.far = 80.0
	main.add_child(cam)
	cam.look_at_from_position(s.from, s.at)
	cam.make_current()
	var fwd := -cam.global_transform.basis.z
	for i in 10:
		await process_frame
	for w in get_nodes_in_group("cutaway"):
		var nrm: Vector3 = w.get_meta("cut_normal", Vector3.ZERO)
		w.visible = nrm.dot(fwd) >= -0.3
	for o in get_nodes_in_group("occluder"):
		o.visible = true
	for i in 50:
		await process_frame
	cam.make_current()
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := out.path_join("%s-%s-game.png" % [n, shot])
	img.save_png(path)
	print("PARITY SAVED ", path, " ", img.get_size())
	quit()
