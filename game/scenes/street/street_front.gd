extends Node3D
## The club's front on the night street (BACKLOG B8, start screen): the building face around the venue's street door,
## the BLACK CABIN neon above it, pavement, kerb and road, a streetlight on a utility pole with Bangkok's cable
## bundle, a potted plant, a parked scooter, the neighbouring shophouses and the dark sky above. No photo of the
## real front yet: everything here is a plausible stand-in, built in code from plain boxes and kit pieces so it is
## easy to replace.
##
## Placed from the venue's StreetDoor (meta `center`, the middle of the opening on the lobby's west wall, whose
## outer face is 0.1 m west of it); the street runs north-south along -x. Not part of build_venue.gd: the start
## screen (scripts/start_screen.gd) adds it at runtime and hides it, lights included, once the player is inside, so
## the venue keeps its light count.

const DOOR_W := 1.2          ## opening of the street door (build_venue.gd DOOR_W)
const DOOR_H := 2.3          ## its lintel height (build_venue.gd `_wall_z(... [STREET_DOOR], 2.3)`)
const SLAB := 0.3            ## facade thickness, in front of the lobby wall
const PAVE_W := 2.2          ## pavement from the facade to the kerb
const ROAD_W := 2.4          ## a narrow soi
const FAR_PAVE := 0.34       ## the opposite pavement (the start camera stands on it), up to build_venue.gd's StreetFacade across
const NEON := "res://assets/kit/lounge/neon_sign.glb"

const C_FACADE := Color("17141a")      ## black-painted render, a little warm
const C_TRIM := Color("2c1d17")        ## dark wood / steel round the door
const C_PAVE := Color("1d1e24")
const C_KERB := Color("4a4a50")
const C_ROAD := Color("0c0c10")
const C_NEXT_L := Color("2a2a30")      ## shophouse to the north (taller, grey)
const C_NEXT_R := Color("2b2320")      ## low shop to the south (roller shutter)
const NEON_RED := Color("ff2a14")
const SODIUM := Color("ffc070")

var lights: Array[Light3D] = []
var door_center := Vector3(-0.1, 0, 7.2)
var face_x := -0.2            ## x of the facade's street face
var far_pave_x := -5.1        ## middle of the opposite pavement (where the start camera stands)
var mats := {}


func build(center: Vector3) -> void:
	door_center = center
	face_x = center.x - 0.1
	var cz := center.z
	var fx := face_x
	var f := _mat("facade", C_FACADE, 0.92)
	# --- our building: two floors and a parapet, the door cut out of the slab ---
	var x0 := fx - SLAB
	_box("FacadeN", Vector3(x0, 0, cz - 3.4), Vector3(SLAB, 6.4, 3.4 - DOOR_W * 0.5), f)
	_box("FacadeS", Vector3(x0, 0, cz + DOOR_W * 0.5), Vector3(SLAB, 6.4, 3.4 - DOOR_W * 0.5), f)
	_box("FacadeHead", Vector3(x0, DOOR_H, cz - DOOR_W * 0.5), Vector3(SLAB, 6.4 - DOOR_H, DOOR_W), f)
	_box("Parapet", Vector3(x0 - 0.1, 6.2, cz - 3.5), Vector3(SLAB + 0.1, 0.25, 7.0), _mat("parapet", Color("221e24"), 0.9))
	_box("FloorBand", Vector3(x0 - 0.06, 4.05, cz - 3.4), Vector3(0.06, 0.18, 6.8), _mat("band", Color("221d22"), 0.9))
	# Door surround: jambs and head proud of the face, a step-sill, a small warm bulb box over the door
	var trim := _mat("trim", C_TRIM, 0.7)
	_box("JambN", Vector3(x0 - 0.08, 0, cz - DOOR_W * 0.5 - 0.14), Vector3(0.08, DOOR_H + 0.14, 0.14), trim)
	_box("JambS", Vector3(x0 - 0.08, 0, cz + DOOR_W * 0.5), Vector3(0.08, DOOR_H + 0.14, 0.14), trim)
	_box("DoorHead", Vector3(x0 - 0.08, DOOR_H, cz - DOOR_W * 0.5 - 0.14), Vector3(0.08, 0.14, DOOR_W + 0.28), trim)
	_box("DoorSill", Vector3(x0 - 0.25, -0.05, cz - DOOR_W * 0.5 - 0.1), Vector3(0.25 + SLAB, 0.07, DOOR_W + 0.2), _mat("sill", Color("34343a"), 0.8))
	# Sign board above the door with the kit neon (BLACK over CABIN, red tubes) on it, facing the street
	_box("SignBoard", Vector3(x0 - 0.06, DOOR_H + 0.3, cz - 1.35), Vector3(0.06, 1.55, 2.7), _mat("signboard", Color("0a090b"), 0.95))
	var neon := _scene(NEON, "NeonSign", Vector3(x0 - 0.1, DOOR_H + 0.4, cz), -90.0, Vector3(1.5, 1.4, 1.0))
	if neon:
		_boost_emission(neon, 3.0)
	# Red spill of the neon on the face, the door and the pavement (one light)
	lights.append(_omni("NeonWash", NEON_RED, 1.5, 4.6, Vector3(fx - 1.1, DOOR_H + 1.0, cz)))
	# Door-side plaque: a small lit menu box north of the door
	_box("MenuBox", Vector3(x0 - 0.07, 1.05, cz - 1.45), Vector3(0.07, 0.62, 0.46), _mat("menubox", Color("1a1414"), 0.8))
	_box("MenuFace", Vector3(x0 - 0.08, 1.1, cz - 1.41), Vector3(0.01, 0.52, 0.38), _mat("menuface", Color("c8a27a"), 0.7, 0.25))
	for r in 4:
		_box("MenuLine%d" % r, Vector3(x0 - 0.09, 1.48 - r * 0.09, cz - 1.36), Vector3(0.005, 0.03, 0.28 - (r % 2) * 0.08), _mat("menuline", Color("3a2418"), 0.8))
	# Upper floor: two windows (one lit behind a red blind), AC units, a drainpipe
	for i in 2:
		var wz := cz - 2.2 + i * 3.0
		var lit := i == 1
		_box("UpWinFrame%d" % i, Vector3(x0 - 0.05, 4.55, wz - 0.05), Vector3(0.05, 1.3, 1.5), trim)
		_box("UpWin%d" % i, Vector3(x0 - 0.06, 4.6, wz), Vector3(0.02, 1.2, 1.4),
			_mat("win_lit", Color("7a2a1c"), 0.6, 0.45) if lit else _mat("win_dark", Color("0d1118"), 0.25))
		_box("UpWinBar%d" % i, Vector3(x0 - 0.07, 5.18, wz), Vector3(0.02, 0.04, 1.4), trim)
	# Wall AC unit under the dark window: grey box, grille slats, a pipe down the wall
	var ac := _mat("ac", Color("8c8a86"), 0.6)
	_box("AcUnit", Vector3(x0 - 0.3, 4.05, cz - 2.0), Vector3(0.3, 0.5, 0.8), ac)
	for s in 5:
		_box("AcSlat%d" % s, Vector3(x0 - 0.31, 4.12 + s * 0.08, cz - 1.95), Vector3(0.01, 0.025, 0.7), _mat("ac_slat", Color("4a4a4c"), 0.6))
	_box("AcPipe", Vector3(x0 - 0.06, 2.3, cz - 1.75), Vector3(0.05, 1.75, 0.05), _mat("pipe", Color("3a3a40"), 0.6))
	_box("Drainpipe", Vector3(x0 - 0.1, 0, cz + 3.2), Vector3(0.08, 6.3, 0.08), _mat("pipe", Color("3a3a40"), 0.6))
	# --- neighbours: a taller grey shophouse north, a low shop with a roller shutter south ---
	var nl := _mat("next_l", C_NEXT_L, 0.9)
	_box("NextNorth", Vector3(x0 + 0.05, 0, cz - 9.5), Vector3(SLAB, 11.0, 6.1), nl)
	for fl in 3:
		for k in 2:
			var lit2 := fl == 1 and k == 0
			_box("NextNorthWin%d_%d" % [fl, k], Vector3(x0, 4.4 + fl * 2.2, cz - 8.8 + k * 2.6), Vector3(0.05, 1.1, 1.3),
				_mat("win_warm", Color("ffcf8a"), 0.6, 0.7) if lit2 else _mat("win_dark", Color("0d1118"), 0.25))
	_box("NextNorthShutter", Vector3(x0, 0, cz - 9.0), Vector3(0.04, 3.0, 5.2), _mat("shutter", Color("3e3c42"), 0.6))
	for s in 14:
		_box("NorthRib%d" % s, Vector3(x0 - 0.02, 0.15 + s * 0.2, cz - 9.0), Vector3(0.02, 0.03, 5.2), _mat("rib", Color("2a282e"), 0.6))
	var nr := _mat("next_r", C_NEXT_R, 0.9)
	_box("NextSouth", Vector3(x0 + 0.05, 0, cz + 3.4), Vector3(SLAB, 4.0, 6.0), nr)
	_box("NextSouthShutter", Vector3(x0, 0, cz + 3.9), Vector3(0.04, 2.8, 4.6), _mat("shutter", Color("3e3c42"), 0.6))
	for s in 13:
		_box("SouthRib%d" % s, Vector3(x0 - 0.02, 0.15 + s * 0.2, cz + 3.9), Vector3(0.02, 0.03, 4.6), _mat("rib", Color("2a282e"), 0.6))
	_box("SouthSignStrip", Vector3(x0 - 0.04, 3.0, cz + 3.9), Vector3(0.04, 0.45, 4.6), _mat("strip", Color("2d4a3c"), 0.8))
	# --- ground: pavement (around the venue's own street step), kerb, road ---
	var pave := _mat("pave", C_PAVE, 0.95)
	var kerb_x := fx - PAVE_W
	var step_x := center.x - 1.7            # build_venue.gd StreetStep: x -1.8..-0.2, z cz - 1.6 .. cz + 1.6
	_slab("PaveOuter", Rect2(kerb_x, cz - 10.0, step_x - kerb_x, 20.0), 0.0, pave)
	_slab("PaveN", Rect2(step_x, cz - 10.0, fx - step_x, 8.4), 0.0, pave)
	_slab("PaveS", Rect2(step_x, cz + 1.6, fx - step_x, 8.4), 0.0, pave)
	var kerb := _mat("kerb", C_KERB, 0.8)
	_box("Kerb", Vector3(kerb_x - 0.18, -0.15, cz - 10.0), Vector3(0.18, 0.15, 20.0), kerb)
	var road_x := kerb_x - 0.18 - ROAD_W
	_slab("Road", Rect2(road_x, cz - 10.0, ROAD_W, 20.0), -0.15, _mat("road", C_ROAD, 0.4))
	for s in 4:
		_box("Lane%d" % s, Vector3(road_x + ROAD_W * 0.5 - 0.05, -0.15, cz - 9.0 + s * 5.0), Vector3(0.1, 0.005, 2.0), _mat("lane", Color("8a8470"), 0.6))
	_box("KerbFar", Vector3(road_x - 0.18, -0.15, cz - 10.0), Vector3(0.18, 0.15, 20.0), kerb)
	_slab("PaveFar", Rect2(road_x - 0.18 - FAR_PAVE, cz - 10.0, FAR_PAVE, 20.0), 0.0, pave)
	far_pave_x = road_x - 0.18 - FAR_PAVE * 0.5
	# --- street dressing ---
	_pole_and_light(Vector3(kerb_x + 0.25, 0, cz + 2.7))
	_plant(Vector3(fx - 0.35, 0, cz + 1.2))
	_scooter(Vector3(fx - 1.55, 0, cz - 2.4), deg_to_rad(-28.0))


## Lights off and the street out of view (the player is inside).
func set_on(on: bool) -> void:
	visible = on
	for l in lights:
		l.visible = on


# --- pieces ----------------------------------------------------------------------------------------------------

## Concrete utility pole at the kerb with a sodium streetlight on an arm over the pavement and the cable bundle
## sagging north and south along the street.
func _pole_and_light(p: Vector3) -> void:
	var pole := _mat("pole", Color("5a5852"), 0.85)
	_box("Pole", p + Vector3(-0.11, 0, -0.11), Vector3(0.22, 7.0, 0.22), pole)
	_box("LampArm", p + Vector3(0.0, 5.2, -0.04), Vector3(1.3, 0.08, 0.08), pole)
	_box("LampHead", p + Vector3(1.05, 5.05, -0.14), Vector3(0.45, 0.14, 0.28), _mat("lamphead", Color("2e2e30"), 0.6))
	_box("LampGlass", p + Vector3(1.08, 5.02, -0.11), Vector3(0.39, 0.03, 0.22), _mat("lampglass", SODIUM, 0.4, 3.0))
	lights.append(_omni("Streetlight", SODIUM, 1.3, 7.5, p + Vector3(1.25, 4.8, 0.0)))
	var cable := _mat("cable", Color("08080a"), 0.7)
	for c in 4:
		var y := 6.3 - c * 0.18
		var x := p.x + 0.12 - c * 0.07
		for side in [-1.0, 1.0]:
			var a := Vector3(x, y, p.z)
			var b := Vector3(x, y + 0.2, p.z + side * 9.0)
			var mid := (a + b) * 0.5 + Vector3(0, -0.55 - c * 0.08, 0)
			_line("Cable%d_%d" % [c, int(side)], a, mid, 0.035, cable)
			_line("Cable%d_%db" % [c, int(side)], mid, b, 0.035, cable)
	_box("Transformer", p + Vector3(-0.2, 5.6, 0.12), Vector3(0.4, 0.5, 0.36), _mat("transformer", Color("4e5a52"), 0.7))


## A potted palm beside the door: a black planter and voxel leaf clusters.
func _plant(p: Vector3) -> void:
	_box("Planter", p + Vector3(-0.22, 0, -0.22), Vector3(0.44, 0.5, 0.44), _mat("planter", Color("1b1a1c"), 0.7))
	_box("Soil", p + Vector3(-0.19, 0.5, -0.19), Vector3(0.38, 0.02, 0.38), _mat("soil", Color("2a1c12"), 1.0))
	var greens := [_mat("leaf_a", Color("1f3a22"), 0.9), _mat("leaf_b", Color("2c5230"), 0.9), _mat("leaf_c", Color("3d6b3a"), 0.9)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 818
	for i in 22:
		var ang := i * TAU / 7.3 + rng.randf_range(-0.4, 0.4)
		var h := rng.randf_range(0.6, 1.45)
		var r := rng.randf_range(0.08, 0.3) * (1.6 - h * 0.6)
		var c := p + Vector3(cos(ang) * r, h, sin(ang) * r)
		var s := rng.randf_range(0.16, 0.28)
		var leaf: StandardMaterial3D = greens[2] if h > 1.15 else (greens[1] if h > 0.85 else greens[0])
		_box("Leaf%d" % i, c - Vector3(s, s * 0.55, s) * 0.5, Vector3(s, s * 0.55, s), leaf)
		if i % 3 == 0:
			_line("Stem%d" % i, p + Vector3(0, 0.5, 0), c, 0.03, greens[0])


## A parked step-through scooter, cream with a black seat, turned `yaw` on the pavement.
func _scooter(p: Vector3, yaw: float) -> void:
	var g := Node3D.new()
	g.name = "Scooter"
	g.position = p
	g.rotation.y = yaw
	add_child(g)
	var body := _mat("scooter", Color("cfc6a8"), 0.5)
	var dark := _mat("scooter_dark", Color("141416"), 0.6)
	var tyre := _mat("tyre", Color("0a0a0a"), 0.9)
	_box("WheelF", Vector3(-0.04, 0, 0.55), Vector3(0.08, 0.36, 0.36), tyre, g)
	_box("WheelR", Vector3(-0.05, 0, -0.75), Vector3(0.1, 0.36, 0.36), tyre, g)
	_box("Deck", Vector3(-0.17, 0.22, -0.45), Vector3(0.34, 0.1, 0.75), body, g)
	_box("RearBody", Vector3(-0.2, 0.25, -0.95), Vector3(0.4, 0.42, 0.62), body, g)
	_box("Seat", Vector3(-0.17, 0.67, -0.95), Vector3(0.34, 0.1, 0.62), dark, g)
	_box("Shield", Vector3(-0.2, 0.25, 0.3), Vector3(0.4, 0.62, 0.12), body, g)
	_box("Stem", Vector3(-0.04, 0.85, 0.36), Vector3(0.08, 0.3, 0.08), dark, g)
	_box("Bars", Vector3(-0.32, 1.12, 0.33), Vector3(0.64, 0.05, 0.08), dark, g)
	_box("Headlamp", Vector3(-0.08, 0.98, 0.44), Vector3(0.16, 0.1, 0.04), _mat("headlamp", Color("e8e4d8"), 0.3), g)
	_box("Mudguard", Vector3(-0.08, 0.36, 0.45), Vector3(0.16, 0.06, 0.26), body, g)


# --- helpers ---------------------------------------------------------------------------------------------------

func _mat(key: String, col: Color, rough := 0.85, emit := 0.0) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = col
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	mats[key] = m
	return m


## Box from its min corner and size (as build_venue.gd `_box`), no collider: nothing here is walked on or into.
func _box(nm: String, pos: Vector3, size: Vector3, mat: Material, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos + size * 0.5
	(parent if parent else self).add_child(mi)
	return mi


## Flat ground piece 0.2 thick whose top is at `y`, over rect (x, z).
func _slab(nm: String, r: Rect2, y: float, mat: Material) -> void:
	_box(nm, Vector3(r.position.x, y - 0.2, r.position.y), Vector3(r.size.x, 0.2, r.size.y), mat)


## Square-section bar from a to b.
func _line(nm: String, a: Vector3, b: Vector3, w: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	bm.size = Vector3(w, w, a.distance_to(b))
	mi.mesh = bm
	mi.material_override = mat
	add_child(mi)
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(b - a, up), (a + b) * 0.5)


func _scene(path: String, nm: String, pos: Vector3, rot_deg: float, scl := Vector3.ONE) -> Node3D:
	var ps: PackedScene = load(path) if ResourceLoader.exists(path) else null
	if ps == null:
		push_warning("street_front: missing " + path)
		return null
	var n: Node3D = ps.instantiate()
	n.name = nm
	n.position = pos
	n.rotation_degrees.y = rot_deg
	n.scale = scl
	add_child(n)
	return n


## Raises the emission of every emissive surface under `n` (the kit neon is tuned for the dim lounge; out on the
## street it is the brightest thing in view and should bloom).
func _boost_emission(n: Node, mult: float) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as StandardMaterial3D
			if m and m.emission_enabled:
				var c := m.duplicate() as StandardMaterial3D
				c.emission_energy_multiplier *= mult
				mi.set_surface_override_material(i, c)
	for c in n.get_children():
		_boost_emission(c, mult)


func _omni(nm: String, col: Color, energy: float, rng: float, pos: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = nm
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.light_specular = 0.6
	l.position = pos
	add_child(l)
	return l
