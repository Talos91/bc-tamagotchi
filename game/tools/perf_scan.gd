extends SceneTree
## Static cost scan of the venue (perf-telemetry 2026-11-19): what the renderer is handed, per venue group, headless.
## Godot --headless --path game -s tools/perf_scan.gd

func _initialize() -> void:
	if "--figure" in OS.get_cmdline_user_args():
		for f in OS.get_cmdline_user_args()[OS.get_cmdline_user_args().find("--figure") + 1].split(","):
			figure(f)
		quit()
		return
	var venue: Node3D = load("res://scenes/venue/venue.tscn").instantiate()
	root.add_child(venue)
	await process_frame
	var tot := {"mi": 0, "surf": 0, "mats": {}, "meshes": {}, "tris": 0, "shadow_cast": 0, "transp": 0, "lights": 0, "mm": 0}
	for g in venue.get_children():
		var s := {"mi": 0, "surf": 0, "mats": {}, "meshes": {}, "tris": 0, "shadow_cast": 0, "transp": 0, "lights": 0, "mm": 0}
		_scan(g, s)
		if s.mi + s.lights + s.mm == 0:
			continue
		print("GROUP %-16s mi=%5d surfaces=%5d meshes=%4d mats=%3d tris=%7d castshadow=%4d transparent=%4d lights=%2d multimesh=%d" % [g.name, s.mi, s.surf, s.meshes.size(), s.mats.size(), s.tris, s.shadow_cast, s.transp, s.lights, s.mm])
		for k in ["mi", "surf", "tris", "shadow_cast", "transp", "lights", "mm"]:
			tot[k] += s[k]
		tot.mats.merge(s.mats)
		tot.meshes.merge(s.meshes)
	print("TOTAL mi=%d surfaces=%d meshes=%d mats=%d tris=%d castshadow=%d transparent=%d lights=%d multimesh=%d" % [tot.mi, tot.surf, tot.meshes.size(), tot.mats.size(), tot.tris, tot.shadow_cast, tot.transp, tot.lights, tot.mm])
	var shaders := {}
	for m in tot.mats:
		if m is BaseMaterial3D:
			var b: BaseMaterial3D = m
			var key := "tex=%s emis=%s transp=%d shading=%d" % [b.albedo_texture != null, b.emission_enabled, b.transparency, b.shading_mode]
			shaders[key] = shaders.get(key, 0) + 1
		else:
			shaders[m.get_class()] = shaders.get(m.get_class(), 0) + 1
	for k in shaders:
		print("MATKIND %s x%d" % [k, shaders[k]])
	quit()

func _scan(n: Node, s: Dictionary) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		s.mi += 1
		s.meshes[mi.mesh] = true
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			s.shadow_cast += 1
		for i in mi.mesh.get_surface_count():
			s.surf += 1
			var m := mi.get_active_material(i)
			if m:
				s.mats[m] = true
				if m is BaseMaterial3D and (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					s.transp += 1
			var a = mi.mesh.surface_get_arrays(i) if mi.mesh is ArrayMesh else []
			if a.size() > 0:
				var idx = a[Mesh.ARRAY_INDEX]
				s.tris += (idx.size() if idx != null else a[Mesh.ARRAY_VERTEX].size()) / 3
	elif n is MultiMeshInstance3D:
		s.mm += 1
	elif n is Light3D:
		s.lights += 1
	for c in n.get_children():
		_scan(c, s)

## --figure <preset>: one preset's meshes (skinned or not, surfaces, vertices, materials)
static func figure(nm: String) -> void:
	var m: Node3D = load("res://assets/chars/presets/%s.glb" % nm).instantiate()
	var tot_v := 0
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		var line := "FIG %-20s skin=%s parent=%s surf=%d" % [mi.name, mi.skin != null, mi.get_parent().get_class(), mi.mesh.get_surface_count()]
		for i in mi.mesh.get_surface_count():
			var a = mi.mesh.surface_get_arrays(i)
			var mat := mi.get_active_material(i) as BaseMaterial3D
			tot_v += a[Mesh.ARRAY_VERTEX].size()
			line += " [v=%d tex=%s col=%s]" % [a[Mesh.ARRAY_VERTEX].size(), mat.albedo_texture.resource_path.get_file() if mat and mat.albedo_texture else "-", mat.albedo_color.to_html(false) if mat else "-"]
		print(line)
	var sk = m.find_children("*", "Skeleton3D", true, false)
	print("FIG bones=%d verts=%d" % [sk[0].get_bone_count() if sk.size() > 0 else 0, tot_v])
	preload("res://scripts/seam_share.gd").share(m)
	var r: Vector2i = preload("res://scripts/venue_batch.gd").merge_figure(m, ["drink_beer", "drink_mug", "glass_gold", "beer_left", "bottle"])
	print("FIG merged %s surfaces %d -> %d" % [nm, r.x, r.y])
	m.free()
