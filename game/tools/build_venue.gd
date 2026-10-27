@tool
extends SceneTree
## Generates res://scenes/venue/venue.tscn (greybox). Run from game/:
##   godot --headless --path . --script res://tools/build_venue.gd
## Re-run after editing; hand-edits to venue.tscn are overwritten. Units are metres.
## Main room x 0..18, z 0..8 (bar on the z=0 wall, stage at x=15..18). The lounge sits up the stairs at
## y=2.4, x 0..12, z 8..15. Stairs rise along +z in the main room's west corner (x 0.5..2.0, z 4.4..8).

const WALL_H := 3.5
const LOUNGE_Y := 2.4

var vroot: Node3D

func _init() -> void:
	vroot = Node3D.new()
	vroot.name = "Venue"
	_main_room()
	_bar()
	_tables()
	_stage()
	_stairs()
	_lounge()
	_signs_and_lights()
	var ps := PackedScene.new()
	ps.pack(vroot)
	var err := ResourceSaver.save(ps, "res://scenes/venue/venue.tscn")
	print("venue saved: ", err)
	quit(0 if err == OK else 1)

func _mat(col: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m

func _own(n: Node, parent: Node) -> void:
	parent.add_child(n)
	n.owner = vroot

func _group(gname: String) -> Node3D:
	var g := Node3D.new()
	g.name = gname
	_own(g, vroot)
	return g

## Box from min corner `pos` with size `size`; collision on by default.
func _box(parent: Node, nm: String, pos: Vector3, size: Vector3, col: Color, collide := true, emit := 0.0) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.name = nm
	b.size = size
	b.position = pos + size * 0.5
	b.material = _mat(col, emit)
	b.use_collision = collide
	_own(b, parent)
	return b

func _cyl(parent: Node, nm: String, center: Vector3, r: float, h: float, col: Color) -> CSGCylinder3D:
	var c := CSGCylinder3D.new()
	c.name = nm
	c.radius = r
	c.height = h
	c.sides = 12
	c.position = center + Vector3(0, h * 0.5, 0)
	c.material = _mat(col)
	c.use_collision = true
	_own(c, parent)
	return c

func _omni(parent: Node, nm: String, col: Color, energy: float, rng: float, pos: Vector3) -> void:
	var l := OmniLight3D.new()
	l.name = nm
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	_own(l, parent)

func _main_room() -> void:
	var g := _group("MainRoom")
	var wall := Color(0.09, 0.08, 0.09)
	_box(g, "Floor", Vector3(0, -0.2, 0), Vector3(18, 0.2, 8), Color(0.22, 0.21, 0.21))
	_box(g, "WallNorth", Vector3(0, 0, -0.2), Vector3(18, WALL_H, 0.2), wall)
	_box(g, "WallWest", Vector3(-0.2, 0, 0), Vector3(0.2, WALL_H, 8), wall)
	_box(g, "WallEast", Vector3(18, 0, 0), Vector3(0.2, WALL_H, 8), wall)
	# South wall with a 2.5 m opening at the west end for the stairs
	_box(g, "WallSouth", Vector3(2.5, 0, 8), Vector3(15.5, WALL_H, 0.2), wall)

func _bar() -> void:
	var g := _group("Bar")
	var wood := Color(0.16, 0.09, 0.06)
	_box(g, "Counter", Vector3(3, 0, 1.0), Vector3(9, 1.1, 0.7), wood)
	_box(g, "CounterTop", Vector3(2.95, 1.1, 0.95), Vector3(9.1, 0.06, 0.8), Color(0.07, 0.05, 0.04), false)
	_box(g, "BackBar", Vector3(3, 0, 0.0), Vector3(9, 1.0, 0.5), wood)
	_box(g, "BottleShelf", Vector3(3, 1.4, 0.05), Vector3(9, 1.4, 0.3), Color(0.12, 0.07, 0.05), false)
	# Amber shelf lights (emissive placeholders)
	for i in 4:
		_box(g, "ShelfLight%d" % i, Vector3(3.2 + i * 2.2, 1.35, 0.3), Vector3(1.8, 0.06, 0.12), Color(1.0, 0.62, 0.15), false, 3.0)
	for i in 6:
		_cyl(g, "Stool%d" % i, Vector3(3.8 + i * 1.4, 0, 1.9), 0.2, 0.55, Color(0.25, 0.12, 0.1))

func _tables() -> void:
	var g := _group("Tables")
	for i in 4:
		var x := 4.0 + i * 3.0
		_cyl(g, "Table%d" % i, Vector3(x, 0, 4.5), 0.5, 0.75, Color(0.2, 0.12, 0.08))
		_box(g, "Candle%d" % i, Vector3(x - 0.04, 0.75, 4.46), Vector3(0.08, 0.14, 0.08), Color(1.0, 0.7, 0.3), false, 4.0)
		for s in 3:
			var a := s * TAU / 3.0
			_cyl(g, "Stool%d_%d" % [i, s], Vector3(x + cos(a) * 0.85, 0, 4.5 + sin(a) * 0.85), 0.18, 0.45, Color(0.18, 0.1, 0.09))

func _stage() -> void:
	var g := _group("Stage")
	_box(g, "Platform", Vector3(15, 0, 0.5), Vector3(3, 0.5, 7), Color(0.12, 0.1, 0.1))
	# Red velvet curtain wall along the east end
	_box(g, "CurtainBack", Vector3(17.6, 0, 0.1), Vector3(0.3, WALL_H, 7.8), Color(0.45, 0.04, 0.05), false)
	for i in 5:
		_box(g, "CurtainFold%d" % i, Vector3(17.4, 0, 0.3 + i * 1.5), Vector3(0.2, WALL_H, 0.5), Color(0.35, 0.02, 0.04), false)
	_box(g, "Drums", Vector3(16.6, 0.5, 3.2), Vector3(0.9, 0.7, 0.9), Color(0.05, 0.05, 0.06), false)
	_box(g, "Amp", Vector3(16.3, 0.5, 1.2), Vector3(0.6, 0.9, 0.4), Color(0.05, 0.05, 0.06), false)
	_box(g, "StageWash", Vector3(15.1, WALL_H - 0.3, 0.8), Vector3(2.8, 0.1, 6.4), Color(1.0, 0.1, 0.1), false, 1.5)
	_box(g, "DiscoBall", Vector3(14.4, 3.0, 3.8), Vector3(0.4, 0.4, 0.4), Color(0.8, 0.8, 0.9), false, 0.8)

func _stairs() -> void:
	var g := _group("Stairs")
	var steps := 12
	var run := 3.6 / steps
	for i in steps:
		_box(g, "Step%d" % i, Vector3(0.5, 0, 4.4 + i * run), Vector3(1.5, (i + 1) * LOUNGE_Y / steps, run), Color(0.25, 0.23, 0.22), false)
	# Solid fill under the ramp (hidden) so nobody walks under the stairs, plus a railing on the open side
	for i in range(1, steps):
		var f := _box(g, "Fill%d" % i, Vector3(0.0, 0, 4.4 + i * run), Vector3(2.0, i * LOUNGE_Y / steps, run), Color.BLACK)
		f.visible = false
	_box(g, "Railing", Vector3(2.0, 0, 4.4), Vector3(0.06, LOUNGE_Y + 1.0, 3.6), Color(0.05, 0.04, 0.04))
	# Invisible ramp so the capsule climbs without step-up logic
	var ang := atan2(LOUNGE_Y, 3.6)
	var ramp := CSGBox3D.new()
	ramp.name = "StairRamp"
	ramp.size = Vector3(1.5, 0.2, sqrt(3.6 * 3.6 + LOUNGE_Y * LOUNGE_Y))
	ramp.position = Vector3(1.25, LOUNGE_Y * 0.5 - 0.1, 4.4 + 1.8)
	ramp.rotation.x = -ang
	ramp.use_collision = true
	ramp.visible = false
	_own(ramp, g)

func _lounge() -> void:
	var g := _group("Lounge")
	var wall := Color(0.06, 0.06, 0.07)
	_box(g, "Floor", Vector3(0, LOUNGE_Y - 0.2, 8), Vector3(12, 0.2, 7), Color(0.2, 0.19, 0.19))
	_box(g, "WallSouth", Vector3(0, LOUNGE_Y, 15), Vector3(12, WALL_H, 0.2), wall)
	_box(g, "WallWest", Vector3(-0.2, LOUNGE_Y, 8), Vector3(0.2, WALL_H, 7.2), wall)
	_box(g, "WallEast", Vector3(12, LOUNGE_Y, 8), Vector3(0.2, WALL_H, 7.2), wall)
	_box(g, "LongTable", Vector3(3, LOUNGE_Y, 10.9), Vector3(5, 0.8, 0.9), Color(0.2, 0.12, 0.08))
	for i in 5:
		_box(g, "Bench%d" % i, Vector3(3.2 + i * 1.0, LOUNGE_Y, 12.0), Vector3(0.7, 0.45, 0.4), Color(0.18, 0.1, 0.09), false)
	_box(g, "CRT", Vector3(10.5, LOUNGE_Y, 9.0), Vector3(0.8, 0.7, 0.6), Color(0.1, 0.1, 0.12), false)
	_box(g, "CRTScreen", Vector3(10.5, LOUNGE_Y + 0.15, 8.95), Vector3(0.5, 0.4, 0.05), Color(0.3, 0.6, 0.7), false, 1.5)
	_box(g, "Cabinet", Vector3(10.8, LOUNGE_Y, 12.0), Vector3(0.9, 1.7, 0.7), Color(0.4, 0.05, 0.08))

func _signs_and_lights() -> void:
	var g := _group("Lights")
	_box(g, "PlantWall", Vector3(3.0, LOUNGE_Y, 14.8), Vector3(6, 2.6, 0.2), Color(0.05, 0.2, 0.08), false)
	# Red neon BLACK CABIN sign (emissive placeholder) over the plant wall
	_box(g, "NeonSign", Vector3(4.2, LOUNGE_Y + 2.7, 14.7), Vector3(3.6, 0.5, 0.08), Color(1.0, 0.05, 0.1), false, 5.0)
	_omni(g, "NeonLight", Color(1.0, 0.1, 0.15), 2.0, 7.0, Vector3(6.0, LOUNGE_Y + 2.7, 14.0))
	_omni(g, "BarAmberLight", Color(1.0, 0.6, 0.2), 1.6, 8.0, Vector3(7.5, 2.4, 1.2))
	_omni(g, "StageRedWash", Color(1.0, 0.05, 0.05), 1.8, 7.0, Vector3(16.0, 3.0, 4.0))
	_omni(g, "LoungeAmber", Color(1.0, 0.7, 0.35), 1.0, 7.0, Vector3(6.0, LOUNGE_Y + 2.5, 11.0))
