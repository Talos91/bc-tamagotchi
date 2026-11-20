extends RefCounted
## Draw-call batching at load (perf-telemetry 2026-11-19, owner item 41: "a friend tried to play and game was lagging
## like crazy"). Same pixels, far fewer draw calls; a phone browser pays for every WebGL call. Numbers and method in
## handoffs/worker-reports-2026-11/perf-telemetry.md (tools/perf_views.gd).
##
## shadow_proxies(venue): the key light's shadow map drew every shadow-casting venue mesh again (~2,200 of the ~2,600
##   draws a frame). Each venue group gets shadow-only meshes (positions only, one per cull mode) that hold the
##   geometry of its static casters; the originals stop casting. A child of its group, so it hides with the group
##   (start screen, door culls). A piece that hides alone at run time (groups cutaway, occluder: camera_rig.gd) gets its
##   own proxy as its child, so its shadow still goes with it. Left out, still casting on their own: what moves
##   (swing_door, nodes with a script and what is under them), the ceiling, skinned meshes, transparent or alpha-cut
##   materials, shader materials, hidden nodes, and a cut-away piece of one mesh.
## merge_figure(model, keep): a patron preset is ten skinned parts, fifteen surfaces that differ only in albedo colour
##   (one shared seam texture, seam_share.gd). The parts under one skeleton merge into one skinned mesh per material
##   kind, the colour carried per vertex (sRGB, as the material's albedo was): 15 surfaces -> 1-2. Props (`keep`, the
##   drinks shown per pose) stay their own nodes.

const SKIP_GROUPS := ["Patrons", "Navigation", "CameraZones", "Thresholds", "Looks", "Doors"]

## Off switch for measuring the before (tools/perf_views.gd --nobatch).
static var enabled := true


# --- shadow proxies ------------------------------------------------------------------------------------------------

static func shadow_proxies(venue: Node3D) -> Dictionary:
	var stats := {"casters": 0, "proxies": 0}
	if not enabled:
		return stats
	for g in venue.get_children():
		if g is Node3D and not String(g.name) in SKIP_GROUPS and g.get_script() == null:
			_proxy_root(g, stats, 1)
	return stats


## The static casters under `root` (stopping at nodes that move or hide alone) go into shadow-only children of `root`.
## A cut-away or occluder piece (it hides as one at run time) gets its own proxies, as a child of itself.
static func _proxy_root(root: Node3D, stats: Dictionary, min_casters: int) -> void:
	var casters: Array[MeshInstance3D] = []
	var subs: Array[Node3D] = []
	_gather(root, root, casters, subs)
	for sub in subs:
		_proxy_root(sub, stats, 2)
	var surfaces := 0
	for mi in casters:
		surfaces += mi.mesh.get_surface_count()
	if casters.size() < min_casters and surfaces < 2:   # one caster of several surfaces still saves draws (perf-iphone)
		return
	if casters.is_empty():
		return
	var buckets := {}   # cull mode -> [PackedVector3Array, PackedInt32Array]
	var inv: Transform3D = root.global_transform.affine_inverse()
	for mi in casters:
		var xf: Transform3D = inv * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var cull := (mi.get_active_material(s) as BaseMaterial3D).cull_mode
			if not buckets.has(cull):
				buckets[cull] = [PackedVector3Array(), PackedInt32Array()]
			_append_positions(mi.mesh, s, xf, buckets[cull])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stats.casters += 1
	for cull in buckets:
		var b: Array = buckets[cull]
		if (b[1] as PackedInt32Array).is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = b[0]
		arrays[Mesh.ARRAY_INDEX] = b[1]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = cull
		mesh.surface_set_material(0, m)
		var mi := MeshInstance3D.new()
		mi.name = "ShadowProxy%d" % cull
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		root.add_child(mi)
		stats.proxies += 1


static func _gather(n: Node, root: Node3D, casters: Array[MeshInstance3D], subs: Array[Node3D]) -> void:
	if n != root:
		if n.get_script() != null or n.is_in_group("ceiling") or n.is_in_group("swing_door"):
			return
		if n is Node3D and not (n as Node3D).visible:
			return
		if n.is_in_group("cutaway") or n.is_in_group("occluder"):
			subs.append(n as Node3D)
			return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and _proxy_ok(mi):
			casters.append(mi)
	for c in n.get_children():
		_gather(c, root, casters, subs)


static func _proxy_ok(mi: MeshInstance3D) -> bool:
	if mi.mesh == null or mi.skin != null or (mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).get_blend_shape_count() > 0) or not mi.is_inside_tree():
		return false
	if mi.layers & 1 == 0:
		return false
	for s in mi.mesh.get_surface_count():
		if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		var m := mi.get_active_material(s)
		if not m is BaseMaterial3D:
			return false
		var b := m as BaseMaterial3D
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or b.grow or b.use_point_size or b.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
			return false
	return true


static func _append_positions(mesh: Mesh, s: int, xf: Transform3D, b: Array) -> void:
	var a := mesh.surface_get_arrays(s)
	var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var base := (b[0] as PackedVector3Array).size()
	var out_v: PackedVector3Array = b[0]
	for v in verts:
		out_v.append(xf * v)
	var out_i: PackedInt32Array = b[1]
	var idx = a[Mesh.ARRAY_INDEX]
	if idx == null or (idx as PackedInt32Array).is_empty():
		for i in verts.size():
			out_i.append(base + i)
	else:
		for i in idx:
			out_i.append(base + i)
	b[0] = out_v
	b[1] = out_i


# --- static meshes (main pass) --------------------------------------------------------------------------------------

## Cell size of a merged chunk (metres, x and z) and the most lights one chunk may be paired with: the Compatibility
## renderer lights each object with at most rendering/limits/opengl/max_lights_per_object (8) of the omni / spot
## lights whose box (Light3D.get_aabb(), a cube of the range for an omni) overlaps the object's box. A chunk is only
## made when every light any of its meshes was lit by is still among its own at most 8: then each pixel gets the same
## lights as before (a light that pairs with the bigger box but reaches none of its vertices adds exactly 0).
## 2026-11-19 (perf-telemetry): first version off, it counted lights by sphere, fewer than the engine pairs, so some
## chunks lost a light (2.7 % of corridor pixels). 2026-11-20 (perf-iphone): pairing by the engine's own boxes, a chunk
## grows mesh by mesh while it stays within 8 lights, identical materials share a surface, untextured plain ones too.
const MERGE_STATIC := true
const CELL := 8.0
const MAX_LIGHTS := 8

## Every static, opaque venue mesh drawn on layer 1 is merged per group (and per cut-away piece), per CELL and per
## material: plain ones (venue kit, seam texture, or a plain colour) into one surface with colour / roughness /
## metallic per vertex (PLAIN_SHADER), others per identical material. The originals stay in the tree with layers = 0
## (drawn by no camera), so nothing that looks them up changes.
## Work per frame when `sliced` (venue.gd): the merge runs over the first frames of the start screen instead of
## holding the title back (~0.4 s native, ~1 s or more in a phone browser).
const SLICE_MS := 6
## Merged chunks store their vertices compressed (positions 16-bit within the chunk's box, as the imported kit meshes
## are): the copies cost ~11 MB of GPU buffers uncompressed (perf-iphone 2026-11-20).
const COMPRESS := true

static func merge_static(venue: Node3D, sliced := false) -> Dictionary:
	var stats := {"meshes": 0, "chunks": 0, "surfaces": 0, "lit_out": 0, "jobs": []}
	if not enabled:
		return stats
	var lights: Array[AABB] = []
	for l in venue.find_children("*", "Light3D", true, false):
		if not l is DirectionalLight3D:
			lights.append((l as Light3D).global_transform * (l as Light3D).get_aabb())
	for g in venue.get_children():
		if g is Node3D and not String(g.name) in SKIP_GROUPS and g.get_script() == null:
			_merge_root(g, lights, stats, 1)   # plans the chunks (cheap); the vertex work is in _make_chunk
	if sliced:
		var w := MergeWorker.new()
		w.name = "MergeWorker"
		w.stats = stats
		w.vb = load("res://scripts/venue_batch.gd")
		venue.add_child(w)
		return stats
	for j in stats.jobs:
		_make_chunk(j[0], j[1], j[2], j[3], stats)
	_done(stats)
	return stats


static func _done(stats: Dictionary) -> void:
	for k in ["jobs", "mats", "white"]:
		stats.erase(k)


## Runs the planned chunks a few milliseconds per frame (the start screen keeps its frame rate). A child of the venue,
## so it goes with it; no coroutine is left waiting if the game quits mid-way.
class MergeWorker extends Node:
	var stats: Dictionary
	var vb: GDScript

	func _process(_d: float) -> void:
		var t0 := Time.get_ticks_usec()
		var jobs: Array = stats.jobs
		while not jobs.is_empty() and Time.get_ticks_usec() - t0 < SLICE_MS * 1000:
			var j: Array = jobs.pop_front()
			if is_instance_valid(j[0]):
				vb._make_chunk(j[0], j[1], j[2], j[3], stats)
		stats.frames = stats.get("frames", 0) + 1
		if jobs.is_empty():
			vb._done(stats)
			queue_free()


## Indices of the lights whose boxes overlap `box` (the engine's pairing test).
static func _lights_of(box: AABB, lights: Array[AABB]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in lights.size():
		if lights[i].intersects(box):
			out.append(i)
	return out


static func _merge_root(root: Node3D, lights: Array[AABB], stats: Dictionary, min_meshes: int) -> void:
	var all: Array[MeshInstance3D] = []
	var subs: Array[Node3D] = []
	_gather_static(root, root, all, subs)
	for sub in subs:
		_merge_root(sub, lights, stats, 1)
	if all.size() < min_meshes:
		return
	var cells := {}
	for mi in all:
		var c := mi.global_transform * mi.get_aabb().get_center()
		var k := Vector2i(floori(c.x / CELL), floori(c.z / CELL))
		if not cells.has(k):
			cells[k] = []
		cells[k].append(mi)
	var inv: Transform3D = root.global_transform.affine_inverse()
	for k in cells:
		# Greedy chunks: a mesh joins the first chunk whose box, grown by it, still pairs with at most MAX_LIGHTS lights.
		var chunks: Array = []   # [box, [meshes]]
		for mi: MeshInstance3D in cells[k]:
			var b: AABB = mi.global_transform * mi.get_aabb()
			if _lights_of(b, lights).size() > MAX_LIGHTS:
				stats.lit_out += 1   # lit by more than 8 already: left as it is
				continue
			var placed := false
			for ch in chunks:
				var grown: AABB = (ch[0] as AABB).merge(b)
				if _lights_of(grown, lights).size() <= MAX_LIGHTS:
					ch[0] = grown
					(ch[1] as Array).append(mi)
					placed = true
					break
			if not placed:
				chunks.append([b, [mi]])
		var n := 0
		for ch in chunks:
			stats.jobs.append([root, inv, ch[1], "Merged_%d_%d_%d" % [k.x, k.y, n]])
			n += 1


## Makes the chunk when it draws fewer surfaces than its meshes did (one mesh of many surfaces counts too).
static func _make_chunk(root: Node3D, inv: Transform3D, list: Array, nm: String, stats: Dictionary) -> bool:
	var groups := {}
	var before := 0
	for mi: MeshInstance3D in list:
		var xf: Transform3D = inv * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if not _opaque(mat):
				continue
			before += 1
			var src := mi.mesh.surface_get_arrays(s)
			var fmt := _fmt_of(src)
			var info := _mat_info(mat, stats)
			var plain: bool = info[0] and not fmt & (Mesh.ARRAY_FORMAT_TEX_UV2 | Mesh.ARRAY_FORMAT_BONES)
			var tex: Texture2D = mat.albedo_texture if plain else null
			if not plain and info[1] and not fmt & (Mesh.ARRAY_FORMAT_TEX_UV2 | Mesh.ARRAY_FORMAT_BONES):
				plain = true
				tex = _white(stats)
				fmt |= Mesh.ARRAY_FORMAT_TEX_UV   # zero UVs are added for it (a 1x1 white texture reads 1.0 anywhere)
			var keep := Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2 | Mesh.ARRAY_FORMAT_COLOR
			var key: String = ("plain|%d" % tex.get_rid().get_id() if plain else "mat|" + str(info[2])) + "|%d" % (fmt & keep)
			if not groups.has(key):
				groups[key] = {"mat": mat, "tex": tex, "fmt": fmt, "plain": plain, "parts": []}
			groups[key].parts.append([_transformed(src, xf), mat.albedo_color, null, Vector2(mat.roughness, mat.metallic) if plain else null])
	if groups.size() >= before:
		return false
	var mesh := ArrayMesh.new()
	for key in groups:
		var gr: Dictionary = groups[key]
		var arrays := _concat(gr.parts, gr.fmt | (Mesh.ARRAY_FORMAT_TEX_UV2 if gr.plain else 0), gr.plain)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES if COMPRESS else 0)
		var m: Material = gr.mat
		if gr.plain:
			m = ShaderMaterial.new()
			(m as ShaderMaterial).shader = _plain_shader()
			(m as ShaderMaterial).set_shader_parameter("texture_albedo", gr.tex)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	var chunk := MeshInstance3D.new()
	chunk.name = nm
	chunk.mesh = mesh
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.set_meta("bc_parts", list.duplicate())   # the meshes it draws (tests check sight lines against their boxes)
	root.add_child(chunk)
	for mi: MeshInstance3D in list:
		_retire(mi)
	stats.meshes += list.size()
	stats.chunks += 1
	stats.surfaces += mesh.get_surface_count()
	return true


## The original stops drawing in the main pass: its transparent surfaces (if any) move to a child of their own; a mesh that still casts its own shadow (no proxy took it) keeps casting it, shadow only.
static func _retire(mi: MeshInstance3D) -> void:
	var rest := ArrayMesh.new()
	for s in mi.mesh.get_surface_count():
		var mat := mi.get_active_material(s) as BaseMaterial3D
		if not _opaque(mat):
			rest.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mi.mesh.surface_get_arrays(s))
			rest.surface_set_material(rest.get_surface_count() - 1, mat)
	if rest.get_surface_count() > 0:
		var r := MeshInstance3D.new()
		r.name = String(mi.name) + "_Rest"
		r.mesh = rest
		r.layers = mi.layers
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(r)   # a child, so it hides with the original
	if mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		mi.layers = 0
	else:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## Per-run caches live in the merge's own stats (never in static vars: a texture or material held by a static var is
## freed after the renderer at exit and crashes the engine).
static func _mat_info(m: BaseMaterial3D, stats: Dictionary) -> Array:
	if not stats.has("mats"):
		stats.mats = {}
	if not stats.mats.has(m):
		stats.mats[m] = [_plain_textured(m), _plain_colour(m), _mat_key(m) + "|" + str(m.albedo_color)]
	return stats.mats[m]

static func _white(stats: Dictionary) -> ImageTexture:
	if not stats.has("white"):
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		stats.white = ImageTexture.create_from_image(img)
	return stats.white


## A StandardMaterial3D at its defaults but for albedo colour (opaque), roughness and metallic, with no texture.
static func _plain_colour(m: BaseMaterial3D) -> bool:
	if not m is StandardMaterial3D or m.albedo_texture != null or m.albedo_color.a < 1.0:
		return false
	if _default_mat == null:
		_default_mat = StandardMaterial3D.new()
	for p in m.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE and not p.name in ["albedo_color", "roughness", "metallic", "resource_name", "resource_path", "resource_local_to_scene"]:
			if str(m.get(p.name)) != str(_default_mat.get(p.name)):
				return false
	return true


## Format bits of a surface's arrays (primitive meshes have no surface_get_format).
static func _fmt_of(a: Array) -> int:
	var f := 0
	for pair in [[Mesh.ARRAY_NORMAL, Mesh.ARRAY_FORMAT_NORMAL], [Mesh.ARRAY_TANGENT, Mesh.ARRAY_FORMAT_TANGENT],
			[Mesh.ARRAY_TEX_UV, Mesh.ARRAY_FORMAT_TEX_UV], [Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_FORMAT_TEX_UV2],
			[Mesh.ARRAY_COLOR, Mesh.ARRAY_FORMAT_COLOR], [Mesh.ARRAY_BONES, Mesh.ARRAY_FORMAT_BONES]]:
		if a[pair[0]] != null and a[pair[0]].size() > 0:
			f |= pair[1]
	return f


## Static, layer-1 meshes under `root` with at least one opaque surface, as _gather (shadow proxies) but whatever
## their shadow setting. Their transparent surfaces stay drawn on their own (_make_chunk).
static func _gather_static(n: Node, root: Node3D, out: Array[MeshInstance3D], subs: Array[Node3D]) -> void:
	if n != root:
		if n.get_script() != null or n.is_in_group("ceiling") or n.is_in_group("swing_door"):
			return
		if n is Node3D and not (n as Node3D).visible:
			return
		if n.is_in_group("cutaway") or n.is_in_group("occluder"):
			subs.append(n as Node3D)
			return
		if String(n.name).begins_with("ShadowProxy") or String(n.name).begins_with("Merged_") or String(n.name).ends_with("_Rest"):
			return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.layers == 1 and mi.material_overlay == null and mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and _merge_ok(mi):
			out.append(mi)
	for c in n.get_children():
		_gather_static(c, root, out, subs)


static func _merge_ok(mi: MeshInstance3D) -> bool:
	if mi.mesh == null or mi.skin != null or (mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).get_blend_shape_count() > 0) or not mi.is_inside_tree():
		return false
	var opaque := 0
	for s in mi.mesh.get_surface_count():
		if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		var m := mi.get_active_material(s)
		if not m is BaseMaterial3D:
			return false
		if _opaque(m as BaseMaterial3D):
			opaque += 1
	return opaque > 0


static func _opaque(b: BaseMaterial3D) -> bool:
	return b.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not b.grow and not b.use_point_size and b.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED


## Mesh arrays moved by `xf` (positions; normals and tangents by the normal matrix).
static func _transformed(a: Array, xf: Transform3D) -> Array:
	var nb := xf.basis.inverse().transposed()
	var v: PackedVector3Array = xf * (a[Mesh.ARRAY_VERTEX] as PackedVector3Array)   # native loop
	a[Mesh.ARRAY_VERTEX] = v
	if a[Mesh.ARRAY_NORMAL] != null:
		var nn: PackedVector3Array = Transform3D(nb, Vector3.ZERO) * (a[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		var sc := nb.get_scale()
		if absf(sc.x - 1.0) > 1e-5 or absf(sc.y - 1.0) > 1e-5 or absf(sc.z - 1.0) > 1e-5 or not nb.is_conformal():
			for i in nn.size():
				nn[i] = nn[i].normalized()
		a[Mesh.ARRAY_NORMAL] = nn
	if a[Mesh.ARRAY_TANGENT] != null:
		var t: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
		for i in range(0, t.size(), 4):
			var tv := (xf.basis * Vector3(t[i], t[i + 1], t[i + 2])).normalized()
			t[i] = tv.x
			t[i + 1] = tv.y
			t[i + 2] = tv.z
			if xf.basis.determinant() < 0.0:
				t[i + 3] = -t[i + 3]
		a[Mesh.ARRAY_TANGENT] = t
	if xf.basis.determinant() < 0.0:   # mirrored: keep the winding facing out
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
		for i in range(0, idx.size(), 3):
			var x := idx[i + 1]
			idx[i + 1] = idx[i + 2]
			idx[i + 2] = x
		a[Mesh.ARRAY_INDEX] = idx
	return a


# --- patron figures ------------------------------------------------------------------------------------------------

## Merges the skinned parts of a preset model (not in the tree yet). Returns the number of surfaces before and after.
static func merge_figure(model: Node3D, keep: Array) -> Vector2i:
	if not enabled:
		return Vector2i.ZERO
	var sks := model.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		return Vector2i.ZERO
	var sk: Skeleton3D = sks[0]
	var parts: Array[MeshInstance3D] = []
	for c in sk.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).skin != null and not String(c.name) in keep:
			var mi := c as MeshInstance3D
			if mi.transform.is_equal_approx(Transform3D.IDENTITY) and not (mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).get_blend_shape_count() > 0) and mi.visible:
				parts.append(mi)
	if parts.size() < 2:
		return Vector2i.ZERO
	var skin := Skin.new()
	var bind_of := {}   # "bone|name|pose" -> merged bind index
	var groups := {}    # material key -> {mat, arrays parts}
	var before := 0
	for mi in parts:
		var remap := PackedInt32Array()
		for i in mi.skin.get_bind_count():
			var key := "%d|%s|%s" % [mi.skin.get_bind_bone(i), mi.skin.get_bind_name(i), str(mi.skin.get_bind_pose(i))]
			if not bind_of.has(key):
				bind_of[key] = skin.get_bind_count()
				skin.add_bind(mi.skin.get_bind_bone(i), mi.skin.get_bind_pose(i))
				if mi.skin.get_bind_name(i) != &"":
					skin.set_bind_name(skin.get_bind_count() - 1, mi.skin.get_bind_name(i))
			remap.append(bind_of[key])
		for s in mi.mesh.get_surface_count():
			before += 1
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if mat == null or mat.vertex_color_use_as_albedo or not mi.mesh is ArrayMesh or (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				return Vector2i.ZERO
			var fmt: int = mi.mesh.surface_get_format(s)
			var plain := _plain_textured(mat) and not fmt & Mesh.ARRAY_FORMAT_TEX_UV2
			var key := ("plain|%d" % mat.albedo_texture.get_rid().get_id() if plain else _mat_key(mat)) + "|%d" % (fmt & (Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2 | Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS))
			if not groups.has(key):
				groups[key] = {"mat": mat, "fmt": fmt, "plain": plain, "parts": []}
			groups[key].parts.append([mi.mesh.surface_get_arrays(s), mat.albedo_color, remap, Vector2(mat.roughness, mat.metallic) if plain else null])
	var merged := MeshInstance3D.new()
	merged.name = "Merged"
	var mesh := ArrayMesh.new()
	for key in groups:
		var gr: Dictionary = groups[key]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _concat(gr.parts, gr.fmt | (Mesh.ARRAY_FORMAT_TEX_UV2 if gr.plain else 0)), [], {},
			Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if gr.fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS else 0)
		var m: Material
		if gr.plain:
			m = ShaderMaterial.new()
			(m as ShaderMaterial).shader = _plain_shader()
			(m as ShaderMaterial).set_shader_parameter("texture_albedo", (gr.mat as BaseMaterial3D).albedo_texture)
		else:
			var b: BaseMaterial3D = (gr.mat as BaseMaterial3D).duplicate()
			b.albedo_color = Color(1, 1, 1, (gr.mat as BaseMaterial3D).albedo_color.a)
			b.vertex_color_use_as_albedo = true
			b.vertex_color_is_srgb = true
			m = b
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	merged.mesh = mesh
	merged.skin = skin
	merged.cast_shadow = parts[0].cast_shadow
	merged.layers = parts[0].layers
	for mi in parts:
		sk.remove_child(mi)
		mi.free()
	sk.add_child(merged)
	merged.owner = model
	merged.skeleton = NodePath("..")
	return Vector2i(before, mesh.get_surface_count())


## StandardMaterial3D's own code (Godot 4.6, generated for a default material with an albedo texture and
## vertex_color_use_as_albedo + vertex_color_is_srgb), with roughness and metallic read per vertex from UV2: the merged
## figure draws as its parts did, whatever each part's roughness and metallic.
const PLAIN_SHADER := """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
void vertex() {
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), COLOR.rgb * (1.0 / 12.92), lessThan(COLOR.rgb, vec3(0.04045)));
	}
}
void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	albedo_tex *= COLOR;
	ALBEDO = albedo_tex.rgb;
	METALLIC = UV2.y;
	SPECULAR = 0.5;
	ROUGHNESS = UV2.x;
}
"""
static var _shader: Shader
static var _default_mat: StandardMaterial3D

static func _plain_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = PLAIN_SHADER
	return _shader


## A StandardMaterial3D at its defaults but for albedo colour and texture, roughness and metallic (every patron part).
static func _plain_textured(m: BaseMaterial3D) -> bool:
	if not m is StandardMaterial3D or m.albedo_texture == null or m.albedo_color.a < 1.0:
		return false
	if _default_mat == null:
		_default_mat = StandardMaterial3D.new()
	for p in m.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE and not p.name in ["albedo_color", "albedo_texture", "roughness", "metallic", "resource_name", "resource_path", "resource_local_to_scene"]:
			if str(m.get(p.name)) != str(_default_mat.get(p.name)):
				return false
	return true


## Every stored property of the material except its albedo colour.
static func _mat_key(m: BaseMaterial3D) -> String:
	var parts := PackedStringArray()
	for p in m.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE and p.name != "albedo_color" and p.name != "resource_name" and p.name != "resource_path":
			var v = m.get(p.name)
			parts.append(str(v.get_rid().get_id()) if v is Resource else str(v))
	return ",".join(parts)


static func _concat(parts: Array, fmt: int, with_color := true) -> Array:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var tan := PackedFloat32Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var col := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var idx := PackedInt32Array()
	for p in parts:
		var a: Array = p[0]
		var c: Color = p[1]
		var remap = p[2]
		var base := v.size()
		var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		v.append_array(pv)
		if fmt & Mesh.ARRAY_FORMAT_NORMAL:
			nrm.append_array(a[Mesh.ARRAY_NORMAL])
		if fmt & Mesh.ARRAY_FORMAT_TANGENT:
			tan.append_array(a[Mesh.ARRAY_TANGENT])
		if fmt & Mesh.ARRAY_FORMAT_TEX_UV:
			if a[Mesh.ARRAY_TEX_UV] != null and (a[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() == pv.size():
				uv.append_array(a[Mesh.ARRAY_TEX_UV])
			else:
				var fz := PackedVector2Array()
				fz.resize(pv.size())
				uv.append_array(fz)
		if p[3] != null:   # plain textured part: roughness, metallic per vertex (PLAIN_SHADER)
			var f2 := PackedVector2Array()
			f2.resize(pv.size())
			f2.fill(p[3])
			uv2.append_array(f2)
		elif fmt & Mesh.ARRAY_FORMAT_TEX_UV2:
			uv2.append_array(a[Mesh.ARRAY_TEX_UV2])
		if with_color:
			var fc := PackedColorArray()
			fc.resize(pv.size())
			fc.fill(c)
			col.append_array(fc)
		elif fmt & Mesh.ARRAY_FORMAT_COLOR:
			col.append_array(a[Mesh.ARRAY_COLOR])
		if remap != null:
			for b in (a[Mesh.ARRAY_BONES] as PackedInt32Array):
				bones.append(remap[b] if b < remap.size() else 0)
			weights.append_array(a[Mesh.ARRAY_WEIGHTS])
		var pi = a[Mesh.ARRAY_INDEX]
		if pi == null or (pi as PackedInt32Array).is_empty():
			for i in pv.size():
				idx.append(base + i)
		else:
			for i in pi:
				idx.append(base + i)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = v
	if fmt & Mesh.ARRAY_FORMAT_NORMAL:
		out[Mesh.ARRAY_NORMAL] = nrm
	if fmt & Mesh.ARRAY_FORMAT_TANGENT:
		out[Mesh.ARRAY_TANGENT] = tan
	if fmt & Mesh.ARRAY_FORMAT_TEX_UV:
		out[Mesh.ARRAY_TEX_UV] = uv
	if fmt & Mesh.ARRAY_FORMAT_TEX_UV2:
		out[Mesh.ARRAY_TEX_UV2] = uv2
	if not col.is_empty():
		out[Mesh.ARRAY_COLOR] = col
	if not bones.is_empty():
		out[Mesh.ARRAY_BONES] = bones
		out[Mesh.ARRAY_WEIGHTS] = weights
	out[Mesh.ARRAY_INDEX] = idx
	return out
