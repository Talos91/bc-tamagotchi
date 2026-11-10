extends RefCounted
## One GPU texture per seam image (perf-iphone-2, owner item 33: an iPhone lost its graphics entering the venue).
## bc_kit.py / bc_chars.py pack one of two seam images into every glb ("bc_seam": 1 px dark seam on every voxel edge;
## "bc_seam2": on the 2-voxel grid; seam_image() in tools/blender/bc_kit.py), and the glTF importer extracts each as
## its own <glb>_bc_seam[2].png: 164 files holding 2 distinct images. Each loaded as its own texture, they were ~137
## textures, 34 MB of the ~250 MB an iPhone gives the page at pixel ratio 3. share() points every material under a node
## at the first texture seen of each kind; the others lose their last reference and are freed. No look change: the
## same pixels and the same import (smoke_start checks the files are byte-identical, so a generator change that
## makes them differ fails a test instead of silently showing one seam everywhere).
## *.import is gitignored here, so this is done at run time rather than with an import script.

static var _canon := {}   ## "bc_seam" / "bc_seam2" -> the one texture kept


## Kind of seam texture ("bc_seam", "bc_seam2") or "" for any other texture.
static func kind(t: Texture2D) -> String:
	if t == null:
		return ""
	var f := t.resource_path.get_file()
	if f.ends_with("_bc_seam2.png"):
		return "bc_seam2"
	if f.ends_with("_bc_seam.png"):
		return "bc_seam"
	return ""


## Every BaseMaterial3D on the meshes under root (mesh surfaces, surface overrides, material overrides) now uses
## the shared seam textures. Cheap to call again: materials already shared are skipped by identity.
static func share(root: Node) -> void:
	if root == null:
		return
	_walk(root)


static func _walk(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				_fix(mi.mesh.surface_get_material(i))
				_fix(mi.get_surface_override_material(i))
		_fix(mi.material_override)
	for c in n.get_children():
		_walk(c)


static func _fix(m: Material) -> void:
	var b := m as BaseMaterial3D
	if b == null:
		return
	b.albedo_texture = _shared(b.albedo_texture)
	b.emission_texture = _shared(b.emission_texture)


static func _shared(t: Texture2D) -> Texture2D:
	var k := kind(t)
	if k == "":
		return t
	if not _canon.has(k):
		_canon[k] = t
	return _canon[k]
