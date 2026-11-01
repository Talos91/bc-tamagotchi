extends Node
## Material overrides on kit instances, applied at load (tools/build_venue.gd adds this node as Venue/Looks): surface
## changes on the children of an instanced .glb are not saved by PackedScene.pack, so they are made here instead.
## Groups set by the generator:
##   look_red_bar      back-bar bays: amber cubby / shelf / soffit glow -> red LED, bottles glow red (photos 09, 16)
##   look_shelf_dull   shelf tiles over the couch: dull browns and glass, no rainbow spines (photo 11)
##   look_neon_red     the neon strip under the raised edge and the couches' base strip on it: saturated red (photo
##                     18; the kit's NeonRed at energy 5 burns to amber-white through the tonemapper)

const RED_LED := Color("ff1a12")
const BOTTLE_RED := Color("c41a14")
const NEON_EDGE := Color("ff0e0a")

var _cache := {}


func _ready() -> void:
	for n in get_tree().get_nodes_in_group("look_red_bar"):
		_apply(n, _red_bar)
	for n in get_tree().get_nodes_in_group("look_shelf_dull"):
		_apply(n, _shelf_dull)
	for n in get_tree().get_nodes_in_group("look_neon_red"):
		_apply(n, _neon_red)


func _apply(n: Node, pick: Callable) -> void:
	if n is MeshInstance3D and n.mesh:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m == null:
				continue
			var r: Material = pick.call(m.resource_name)
			if r:
				mi.set_surface_override_material(i, r)
	for c in n.get_children():
		_apply(c, pick)


func _mat(key: String, col: Color, emit := 0.0, rough := 0.8, alpha := 1.0) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = Color(col, alpha)
	m.roughness = rough
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_cache[key] = m
	return m


func _red_bar(name: String) -> Material:
	if name.begins_with("CubbyGlow"):
		return _mat("bar_cubby_red", Color("6a0806"), 2.2)
	if name.begins_with("ShelfAmber") or name.begins_with("SoffitPeach"):
		return _mat("bar_led_red", RED_LED, 3.0)
	if name.begins_with("Bottle") and not name.ends_with("Cap"):
		return _mat("bar_bottle_red", BOTTLE_RED, 0.9, 0.3)
	if name.begins_with("LabelCream"):
		return _mat("bar_label_red", Color("d89080"), 0.3)
	return null


func _neon_red(name: String) -> Material:
	if name.begins_with("NeonRed"):
		return _mat("edge_neon_red", NEON_EDGE, 2.4, 0.5)
	return null


func _shelf_dull(name: String) -> Material:
	match name:
		"CarpetRed", "DrumRed":
			return _mat("shelf_book_oxblood", Color("4a1c16"))
		"StageBlue", "CeilingPlum":
			return _mat("shelf_book_brown", Color("3a2a22"))
		"ColumnWhite", "LabelCream", "PrintGrey":
			return _mat("shelf_paper", Color("8a7a6a"))
		"CymbalGold":
			return _mat("shelf_brass", Color("7a5a2a"), 0.0, 0.4)
		"BottleGreen", "BottleAmber", "BottleClear":
			return _mat("shelf_glass", Color("5a4a3e"), 0.0, 0.2, 0.85)
	return null
