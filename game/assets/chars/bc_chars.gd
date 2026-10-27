class_name BCChars
extends RefCounted
## Runtime helpers for the voxel character kit (tools/blender/bc_chars.py, see README.md beside this file).
## A character is one glTF scene: Skeleton3D "Skeleton3D" with one MeshInstance3D per part, skinned to the bones
## root, hips, spine, head, arm_L, arm_R, leg_L, leg_R, plus an AnimationPlayer. Materials are named
## <slot>__<Swatch> (skin__Skin4, top__Mustard, hat_bucket__Olive), so recolouring is by name prefix.

const MANIFEST := "res://assets/chars/manifest.json"
## bc_kit v2 bakes the jitter into the texture at 1/1.07 and multiplies the colour factor by 1.07 to compensate
const JMAX := 1.07
const ONE_SHOTS := ["cheers"]

## Cast bible 5.1 tipsiness levels: 0 Clear, 1 Warm, 2 Tipsy, 3 Merry.
const TIPSY_SUFFIX := ["", "_warm", "_tipsy", "_merry"]

static var _manifest: Dictionary

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return _manifest

## Looping is not stored in the .glb import settings (they are not committed), so set it here.
static func setup_animations(root: Node) -> AnimationPlayer:
	var ap := root.find_children("*", "AnimationPlayer", true, false)
	if ap.is_empty():
		return null
	var player: AnimationPlayer = ap[0]
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			var a := lib.get_animation(anim_name)
			a.loop_mode = Animation.LOOP_NONE if anim_name in ONE_SHOTS else Animation.LOOP_LINEAR
	return player

## Which animation to play for a base state ("idle" or "walk"), tipsiness 0-3 and Vibe 0-100 (GDD 2.2).
## Low Vibe (Meh and below) replaces the idle with idle_sad; tipsiness still shows in the walk.
static func anim_for(base: String, tipsy: int, vibe: float) -> String:
	if base == "idle" and vibe < 50.0 and tipsy == 0:
		return "idle_sad"
	if base == "idle" or base == "walk":
		return base + TIPSY_SUFFIX[clampi(tipsy, 0, 3)]
	return base

## Recolour every surface whose material is <slot>__*, e.g. recolour(char, "skin", Color("a06e4a")).
## Colours are swatch hexes (manifest.json "swatches"); pass the plain hex, the JMAX factor is applied here.
static func recolour(root: Node, slot: String, srgb: Color) -> void:
	var lin := srgb.srgb_to_linear()
	var c := Color(minf(lin.r * JMAX, 1.0), minf(lin.g * JMAX, 1.0), minf(lin.b * JMAX, 1.0)).linear_to_srgb()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s) as StandardMaterial3D
			if m == null or not m.resource_name.begins_with(slot + "__"):
				continue
			var dup := m.duplicate() as StandardMaterial3D
			dup.resource_name = slot + "__custom"
			dup.albedo_color = c
			mi.set_surface_override_material(s, dup)

## On a parts library (parts/parts_<body>.glb), show only the named parts, e.g.
## ["head_round", "hair_bob", "eyes_dot", "brows_flat", "mouth_smile", "top_tee", "bottom_jeans",
##  "shoes_sneakers", "hands", "drink_beer"].
static func show_parts(root: Node, ids: Array) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mi.visible = String(mi.name) in ids
