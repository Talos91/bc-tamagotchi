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
	if casters.size() < min_casters:
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

## Cell size of a merged chunk (metres, x and z) and the most lights one chunk may be touched by: the Compatibility
## renderer lights each object with at most rendering/limits/opengl/max_lights_per_object (8), so a chunk that would
## gather more is split into its single meshes again (left as they were).
## OFF (2026-11-19): measured -8 to -22 % draws in the wide views (Corridor 2,926 -> 2,275) but it shifts the
## lighting on some corridor wall pieces (2.7 % of pixels, captures in docs/art/screens/perf-telemetry/) and adds
## speckles where coplanar stage-floor faces now share one draw. Kept for a later pass; venue.gd calls it only when on.
const MERGE_STATIC := false
const CELL := 4.0
const MAX_LIGHTS := 8

## Every static, opaque venue mesh drawn on layer 1 is merged per group (and per cut-away piece), per CELL and per
## material: plain textured ones (venue kit, seam texture) into one surface with colour / roughness / metallic per
## vertex (PLAIN_SHADER), others per identical material. The originals stay in the tree with layers = 0 (drawn by no
## camera), so nothing that looks them up changes.
static func merge_static(venue: Node3D) -> Dictionary:
	var stats := {"meshes": 0, "chunks": 0, "surfaces": 0}
	if not enabled:
		return stats
	var lights: Array = []
	for l in venue.find_children("*", "Light3D", true, false):
		if not l is DirectionalLight3D:
			lights.append([(l as Light3D).global_position, float(l.get("omni_range") if l is OmniLight3D else l.get("spot_range"))])
	for g in venue.get_children():
		if g is Node3D and not String(g.name) in SKIP_GROUPS and g.get_script() == null:
			_merge_root(g, lights, stats, 1)
	return stats


static func _merge_root(root: Node3D, lights: Array, stats: Dictionary, min_meshes: int) -> void:
	var all: Array[MeshInstance3D] = []
	var subs: Array[Node3D] = []
	_gather_static(root, root, all, subs)
	for sub in subs:
		_merge_root(sub, lights, stats, 2)
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
		var list: Array = cells[k]
		if list.size() < 2:
			continue
		var box: AABB = (list[0] as MeshInstance3D).global_transform * (list[0] as MeshInstance3D).get_aabb()
		for mi in list:
			box = box.merge((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb())
		var n_lights := 0
		for l in lights:
			var p: Vector3 = l[0]
			if (p.clamp(box.position, box.end) - p).length() <= l[1]:
				n_lights += 1
		if n_lights > MAX_LIGHTS:
			stats.lit_out = stats.get("lit_out", 0) + list.size()
			continue
		var groups := {}
		for mi: MeshInstance3D in list:
			var xf: Transform3D = inv * mi.global_transform
			for s in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(s) as BaseMaterial3D
				var src := mi.mesh.surface_get_arrays(s)
				var fmt := _fmt_of(src)
				var plain := _plain_textured(mat) and not fmt & (Mesh.ARRAY_FORMAT_TEX_UV2 | Mesh.ARRAY_FORMAT_BONES)
				var key := ("plain|%d" % mat.albedo_texture.get_rid().get_id() if plain else "mat|%d" % mat.get_instance_id()) + "|%d" % (fmt & (Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2 | Mesh.ARRAY_FORMAT_COLOR))
				if not groups.has(key):
					groups[key] = {"mat": mat, "fmt": fmt, "plain": plain, "parts": []}
				groups[key].parts.append([_transformed(src, xf), mat.albedo_color, null, Vector2(mat.roughness, mat.metallic) if plain else null])
		var mesh := ArrayMesh.new()
		for key in groups:
			var gr: Dictionary = groups[key]
			var arrays := _concat(gr.parts, gr.fmt | (Mesh.ARRAY_FORMAT_TEX_UV2 if gr.plain else 0), gr.plain)
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var m: Material = gr.mat
			if gr.plain:
				m = ShaderMaterial.new()
				(m as ShaderMaterial).shader = _plain_shader()
				(m as ShaderMaterial).set_shader_parameter("texture_albedo", (gr.mat as BaseMaterial3D).albedo_texture)
			mesh.surface_set_material(mesh.get_surface_count() - 1, m)
		var chunk := MeshInstance3D.new()
		chunk.name = "Merged_%d_%d" % [k.x, k.y]
		chunk.mesh = mesh
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(chunk)
		for mi: MeshInstance3D in list:
			mi.layers = 0
		stats.meshes += list.size()
		stats.chunks += 1
		stats.surfaces += mesh.get_surface_count()


## Format bits of a surface's arrays (primitive meshes have no surface_get_format).
static func _fmt_of(a: Array) -> int:
	var f := 0
	for pair in [[Mesh.ARRAY_NORMAL, Mesh.ARRAY_FORMAT_NORMAL], [Mesh.ARRAY_TANGENT, Mesh.ARRAY_FORMAT_TANGENT],
			[Mesh.ARRAY_TEX_UV, Mesh.ARRAY_FORMAT_TEX_UV], [Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_FORMAT_TEX_UV2],
			[Mesh.ARRAY_COLOR, Mesh.ARRAY_FORMAT_COLOR], [Mesh.ARRAY_BONES, Mesh.ARRAY_FORMAT_BONES]]:
		if a[pair[0]] != null and a[pair[0]].size() > 0:
			f |= pair[1]
	return f


## Static, opaque, layer-1 meshes under `root`, as _gather (shadow proxies) but whatever their shadow setting.
static func _gather_static(n: Node, root: Node3D, out: Array[MeshInstance3D], subs: Array[Node3D]) -> void:
	if n != root:
		if n.get_script() != null or n.is_in_group("ceiling") or n.is_in_group("swing_door"):
			return
		if n is Node3D and not (n as Node3D).visible:
			return
		if n.is_in_group("cutaway") or n.is_in_group("occluder"):
			subs.append(n as Node3D)
			return
		if String(n.name).begins_with("ShadowProxy") or String(n.name).begins_with("Merged_"):
			return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.layers == 1 and mi.material_overlay == null and _proxy_ok(mi) and mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			var ok := true
			for s in mi.mesh.get_surface_count():
				ok = ok and mi.get_active_material(s) is BaseMaterial3D
			if ok:
				out.append(mi)
	for c in n.get_children():
		_gather_static(c, root, out, subs)


## Mesh arrays moved by `xf` (positions; normals and tangents by the normal matrix).
static func _transformed(a: Array, xf: Transform3D) -> Array:
	var nb := xf.basis.inverse().transposed()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	for i in v.size():
		v[i] = xf * v[i]
	a[Mesh.ARRAY_VERTEX] = v
	if a[Mesh.ARRAY_NORMAL] != null:
		var nn: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		for i in nn.size():
			nn[i] = (nb * nn[i]).normalized()
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
			uv.append_array(a[Mesh.ARRAY_TEX_UV])
		if p[3] != null:   # plain textured part: roughness, metallic per vertex (PLAIN_SHADER)
			for i in pv.size():
				uv2.append(p[3])
		elif fmt & Mesh.ARRAY_FORMAT_TEX_UV2:
			uv2.append_array(a[Mesh.ARRAY_TEX_UV2])
		if with_color:
			for i in pv.size():
				col.append(c)
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
