extends SceneTree
## Static-merge check (perf-iphone 2026-11-20), headless: Godot --headless --path game -s tools/perf_merge.gd
## Loads the venue (its own merge runs), prints the merged chunks and, per group, what is still drawn alone and why.

func _initialize() -> void:
	var venue: Node3D = load("res://scenes/venue/venue.tscn").instantiate()
	root.add_child(venue)
	await process_frame
	await process_frame
	var shad := 0
	for l in venue.find_children("*", "Light3D", true, false):
		if l.shadow_enabled:
			shad += 1
			print("SHADOWED ", l.get_path(), " ", l.get_class())
	var casters := 0
	for mi: GeometryInstance3D in venue.find_children("*", "GeometryInstance3D", true, false):
		if mi.is_visible_in_tree() and mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and mi.layers != 0:
			casters += 1
	print("LIGHTS shadowed=%d casters_visible=%d" % [shad, casters])
	var VB = load("res://scripts/venue_batch.gd")
	var st: Dictionary = {} if VB.MERGE_STATIC else await VB.merge_static(venue)
	for i in 120:   # the venue's own merge is sliced over frames
		await process_frame
	var n := 0
	for m in venue.find_children("Merged_*", "MeshInstance3D", true, false):
		n += 1
		st["surf_total"] = st.get("surf_total", 0) + m.mesh.get_surface_count()
	st["chunks_found"] = n
	print("MERGE ", st)
	# What is still drawn on its own (layer 1, visible, not merged), by reason, per group.
	for g in venue.get_children():
		var why := {}
		for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
			if not mi.is_visible_in_tree() or mi.layers & 1 == 0 or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or String(mi.name).begins_with("Merged_"):
				continue
			var r := _why(mi, g)
			why[r] = why.get(r, 0) + (mi.mesh.get_surface_count() if mi.mesh else 0)
		if not why.is_empty():
			print("LEFT %-12s %s" % [g.name, why])
	quit()

func _why(mi: MeshInstance3D, g: Node) -> String:
	var n: Node = mi
	while n != g:
		if n.get_script() != null:
			return "script:" + str(n.get_script().resource_path.get_file())
		if n.is_in_group("ceiling"):
			return "ceiling"
		if n.is_in_group("swing_door"):
			return "swing_door"
		n = n.get_parent()
	if mi.skin != null:
		return "skinned"
	for s in mi.mesh.get_surface_count():
		var m := mi.get_active_material(s)
		if not m is BaseMaterial3D:
			return "shadermat"
		if (m as BaseMaterial3D).transparency != 0:
			return "transparent"
	if mi.material_overlay != null:
		return "overlay"
	return "other(lit/cell)"
