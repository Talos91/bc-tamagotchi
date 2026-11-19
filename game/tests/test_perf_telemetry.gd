extends SceneTree
## Headless test of the perf pass (perf-telemetry 2026-11-19, owner item 41): the telemetry sampler and its report
## (scripts/perf_telemetry.gd, autoload PerfTelemetry: percentiles, areas, spikes, nothing personal in the text),
## auto quality (perf_quality.gd: steps down one level after a slow window in the venue, never up, not after a hand
## pick), and the draw-call batching (venue_batch.gd): a patron preset merges to one skinned surface with the same
## vertices and valid bone binds; the venue's static shadow casters move into shadow-only proxies while cut-away
## walls, doors and the ceiling keep casting on their own.
##   godot --headless --path . --script res://tests/test_perf_telemetry.gd

const Quality = preload("res://scripts/perf_quality.gd")
const VenueBatch = preload("res://scripts/venue_batch.gd")
const SECRET := "Zqxname Probe"

var fails: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _init() -> void:
	await process_frame
	var needs: Node = root.get_node_or_null("Needs")
	needs.autosave = false
	needs.new_game()
	needs.profile["display_name"] = SECRET
	var pt: Node = root.get_node_or_null("PerfTelemetry")
	check(pt != null, "autoload PerfTelemetry is registered")
	if pt == null:
		_end()
		return

	print("percentiles")
	var a: Array = []
	for i in 95:
		a.append(16.0)
	for i in 5:
		a.append(100.0)
	check(is_equal_approx(pt._pct(a, 0.5), 16.0), "median of 95x16 + 5x100 ms is 16 ms")
	check(pt._pct(a, 0.95) >= 16.0 and pt._pct(a, 0.99) == 100.0, "p95 / p99 pick the slow tail")
	check(pt.fps_text(a).begins_with("63 / "), "fps text leads with the median fps: " + pt.fps_text(a))
	check(pt.fps_text([]) == "-", "no frames: '-'")

	print("areas, spikes, report")
	pt.set_process(false)
	for i in 30:
		pt._add("venue:Bar", 20.0)
	pt._add("venue:Lounge", 120.0)
	pt.spikes50 = 1
	pt.spikes100 = 1
	pt.worst = 120.0
	pt.worst_where = "venue:Lounge"
	var r: String = pt.report()
	check(r.begins_with("Black Cabin perf report v"), "report starts with the version")
	check("venue:Bar: 50 / 50 fps (30 frames)" in r, "per-area line for the Bar")
	check("venue:Lounge" in r and "worst 120 ms in venue:Lounge" in r, "spike line names the worst frame and its area")
	check("load: engine up" in r and "draws mean" in r and "renderer:" in r, "load, counters and renderer lines")
	check(not SECRET in r and not "Zqxname" in r, "report holds no player name")
	var ring: Array = []
	for i in pt.KEEP + 50:
		pt._add("ring", float(i))
	check((pt.frames["ring"] as Array).size() == pt.KEEP, "per-area ring keeps KEEP frames")

	print("auto quality")
	Quality.level = 2
	pt._manual = false
	pt.where = "venue:Bar"
	for i in 200:
		pt._auto_quality(50.0)    # 10 s at 20 fps
	check(Quality.level == 1, "a slow window in the venue drops full -> lighter (level %d)" % Quality.level)
	check(pt.quality_log.size() == 1 and pt.quality_log[0].begins_with("auto full->lighter"), "the change is in the report log")
	for i in 400:
		pt._auto_quality(10.0)    # fast again: never back up by itself
	check(Quality.level == 1, "never steps up by itself")
	pt.where = "start"
	for i in 400:
		pt._auto_quality(80.0)
	check(Quality.level == 1, "outside the venue nothing changes")
	pt.set_quality(2)
	pt.where = "venue:Bar"
	for i in 400:
		pt._auto_quality(80.0)
	check(Quality.level == 2 and pt._manual, "after a hand pick auto stays off")
	Quality.level = 2
	pt._manual = false

	print("quality levels on a scene")
	var main := Node3D.new()
	root.add_child(main)
	var venue := Node3D.new()
	venue.name = "Venue"
	main.add_child(venue)
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.shadow_enabled = true
	venue.add_child(key)
	Quality.apply_level(main, 1)
	check(key.shadow_enabled and is_equal_approx(main.get_viewport().scaling_3d_scale, Quality.SCALE_3D), "lighter: 3D at 0.75, shadows kept")
	Quality.apply_level(main, 0)
	check(not key.shadow_enabled, "lowest: no key-light shadow")
	Quality.apply_level(main, 2)
	check(key.shadow_enabled and is_equal_approx(main.get_viewport().scaling_3d_scale, 1.0), "full: as designed")
	main.free()

	print("patron merge")
	for nm in ["patron_05", "boy", "jo"]:
		var ps: PackedScene = load("res://assets/chars/presets/%s.glb" % nm)
		var m: Node3D = ps.instantiate()
		preload("res://scripts/seam_share.gd").share(m)
		var v0 := _verts(m, PatronFigure.DRINKS + ["bottle"])
		var res: Vector2i = VenueBatch.merge_figure(m, PatronFigure.DRINKS + ["bottle"])
		var merged := m.find_child("Merged", true, false) as MeshInstance3D
		check(res.x >= 10 and res.y == 1 and merged != null, "%s: %d skinned surfaces -> %d" % [nm, res.x, res.y])
		if merged:
			check(_verts(m, PatronFigure.DRINKS + ["bottle"]) == v0, "%s: same vertex count (%d)" % [nm, v0])
			var bones: PackedInt32Array = merged.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES]
			var mx := 0
			for b in bones:
				mx = maxi(mx, b)
			check(mx < merged.skin.get_bind_count(), "%s: bone indices within the merged skin (%d binds)" % [nm, merged.skin.get_bind_count()])
			check(merged.mesh.surface_get_material(0) is ShaderMaterial, "%s: one plain-textured material, roughness / metallic per vertex" % nm)
			var props := 0
			for d in PatronFigure.DRINKS + ["bottle"]:
				props += 1 if m.find_child(d, true, false) != null else 0
			check(props == _count_props(ps), "%s: drinks stay their own nodes (%d)" % [nm, props])
		m.free()

	print("shadow proxies")
	var vs: Node3D = load("res://scenes/venue/venue.tscn").instantiate()
	root.add_child(vs)
	await process_frame
	await process_frame
	var proxies := vs.find_children("ShadowProxy*", "MeshInstance3D", true, false)
	check(proxies.size() >= 8, "shadow proxies made (%d)" % proxies.size())
	var ok_mode := true
	for p in proxies:
		ok_mode = ok_mode and (p as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and vs.is_ancestor_of(p) and p.get_parent() != vs
		ok_mode = ok_mode and (p as MeshInstance3D).mesh.get_surface_count() == 1
	check(ok_mode, "every proxy is shadow-only, one surface, under a venue group")
	var casting := 0
	var cut_cast := 0
	var cut_total := 0
	for mi: MeshInstance3D in vs.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("ShadowProxy") or vs.get_node("Patrons").is_ancestor_of(mi):
			continue
		if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			casting += 1
		for grp in ["cutaway", "swing_door"]:
			var n: Node = mi
			while n != vs:
				if n.is_in_group(grp):
					cut_total += 1
					cut_cast += 1 if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 0
					break
				n = n.get_parent()
	print("    meshes still casting on their own: %d; cut-away / door meshes %d, casting %d" % [casting, cut_total, cut_cast])
	check(casting - cut_cast < 120, "static casters moved into proxies (%d left casting alone, %d of them cut-away / door)" % [casting, cut_cast])
	check(cut_total > 0 and cut_cast > 0, "cut-away walls and doors still cast on their own")
	var tri := 0
	for p in proxies:
		tri += ((p as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	check(tri > 50000, "proxies hold the casters' triangles (%d)" % tri)
	vs.free()
	_end()


func _verts(m: Node, skip: Array) -> int:
	var n := 0
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name) in skip:
			continue
		for s in mi.mesh.get_surface_count():
			n += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n


func _count_props(ps: PackedScene) -> int:
	var m: Node = ps.instantiate()
	var n := 0
	for d in PatronFigure.DRINKS + ["bottle"]:
		n += 1 if m.find_child(d, true, false) != null else 0
	m.free()
	return n


func _end() -> void:
	print("RESULT: %s (%d failures)" % ["PASS" if fails.is_empty() else "FAIL", fails.size()])
	for f in fails:
		print("  - " + f)
	quit(0 if fails.is_empty() else 1)
