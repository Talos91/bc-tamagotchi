@tool
extends SceneTree
## Generates res://scenes/venue/venue.tscn (greybox). Run from game/:
##   godot --headless --path . --script res://tools/build_venue.gd
## Re-run after editing; hand-edits to venue.tscn are overwritten. Units are metres.
## Layout (from the art direction renders): entrance Lounge x 0..8, z 0..8, neon sign on the north wall, stairs
## up on the west side. Standing in the lounge facing the sign (north), the red Curtain on the east wall, to
## your right, is the passable opening (z 4.5..6.5) into the main room x 8..26: Bar along the north wall,
## round Tables in the middle, CommunalTable along the south wall, Stage platform at the far east end.

const WALL_H := 3.5
const UP_Y := 2.4

var vroot: Node3D

func _init() -> void:
	vroot = Node3D.new()
	vroot.name = "Venue"
	_lounge()
	_stairs()
	_curtain()
	_main_room()
	_bar()
	_tables()
	_communal_table()
	_stage()
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


func _lounge() -> void:
	var g := _group("Lounge")
	var wall := Color(0.06, 0.06, 0.07)
	_box(g, "Floor", Vector3(0, -0.2, 0), Vector3(8, 0.2, 8), Color(0.2, 0.19, 0.19))
	_box(g, "WallNorth", Vector3(0, 0, -0.2), Vector3(8, WALL_H, 0.2), wall)
	_box(g, "WallWest", Vector3(-0.2, 0, 0), Vector3(0.2, WALL_H, 8), wall)
	_box(g, "WallSouth", Vector3(0, 0, 8), Vector3(8, WALL_H, 0.2), wall)
	_box(g, "WallEastNorth", Vector3(7.8, 0, 0), Vector3(0.2, WALL_H, 4.5), wall)
	_box(g, "WallEastSouth", Vector3(7.8, 0, 6.5), Vector3(0.2, WALL_H, 1.5), wall)
	# White square columns
	_box(g, "ColumnA", Vector3(5.2, 0, 2.5), Vector3(0.4, WALL_H, 0.4), Color(0.8, 0.8, 0.78))
	_box(g, "ColumnB", Vector3(5.2, 0, 6.0), Vector3(0.4, WALL_H, 0.4), Color(0.8, 0.8, 0.78))
	_box(g, "PlantWall", Vector3(2.5, 0, 0.05), Vector3(4.5, 2.6, 0.2), Color(0.05, 0.2, 0.08), false)
	# Red neon BLACK CABIN sign (emissive placeholder) over the plant wall
	_box(g, "NeonSign", Vector3(3.2, 2.7, 0.08), Vector3(3.1, 0.5, 0.08), Color(1.0, 0.05, 0.1), false, 5.0)
	_omni(g, "NeonLight", Color(1.0, 0.1, 0.15), 2.0, 7.0, Vector3(4.7, 2.7, 1.0))
	_omni(g, "LoungeAmber", Color(1.0, 0.7, 0.35), 1.0, 7.0, Vector3(4.0, 3.0, 4.0))
	_box(g, "LongTable", Vector3(2.5, 0, 1.6), Vector3(3.6, 0.8, 0.9), Color(0.2, 0.12, 0.08))
	for i in 3:
		_box(g, "CandleLamp%d" % i, Vector3(3.0 + i * 1.3, 0.8, 1.95), Vector3(0.1, 0.16, 0.1), Color(1.0, 0.7, 0.3), false, 4.0)
	_box(g, "Cabinet", Vector3(6.4, 0, 0.2), Vector3(0.9, 1.7, 0.7), Color(0.4, 0.05, 0.08))
	_box(g, "ShelfWall", Vector3(7.5, 0.8, 6.9), Vector3(0.25, 1.8, 1.0), Color(0.15, 0.1, 0.07), false)

func _stairs() -> void:
	var g := _group("Stairs")
	# Along the west wall, rising toward -z: foot at z=5.1, top at z=1.5, landing (y=2.4) at z 0..1.5
	var steps := 12
	var run := 3.6 / steps
	var rise := UP_Y / steps
	for i in steps:
		_box(g, "Step%d" % i, Vector3(0.4, 0, 5.1 - (i + 1) * run), Vector3(1.6, (i + 1) * rise, run), Color(0.25, 0.23, 0.22), false)
	for i in range(1, steps):
		var f := _box(g, "Fill%d" % i, Vector3(0.0, 0, 5.1 - (i + 1) * run), Vector3(2.0, i * rise, run), Color.BLACK)
		f.visible = false
	_box(g, "Landing", Vector3(0, UP_Y - 0.2, 0), Vector3(2.0, 0.2, 1.5), Color(0.25, 0.23, 0.22))
	var lf := _box(g, "LandingFill", Vector3(0, 0, 0), Vector3(2.0, UP_Y - 0.2, 1.5), Color.BLACK)
	lf.visible = false
	_box(g, "Railing", Vector3(2.0, 0, 1.5), Vector3(0.06, UP_Y + 1.0, 3.6), Color(0.05, 0.04, 0.04))
	var ramp := CSGBox3D.new()
	ramp.name = "StairRamp"
	ramp.size = Vector3(1.6, 0.2, sqrt(3.6 * 3.6 + UP_Y * UP_Y))
	ramp.position = Vector3(1.2, UP_Y * 0.5 - 0.1, 3.3)
	ramp.rotation.x = atan2(UP_Y, 3.6)
	ramp.use_collision = true
	ramp.visible = false
	_own(ramp, g)

func _curtain() -> void:
	var g := _group("Curtain")
	var red := Color(0.45, 0.04, 0.05)
	# Folds flank the opening (z 4.5..6.5, passable) and a valance hangs above it
	for i in 3:
		_box(g, "FoldNorth%d" % i, Vector3(7.5, 0, 3.6 + i * 0.3), Vector3(0.3, 2.9, 0.3), red, false)
		_box(g, "FoldSouth%d" % i, Vector3(7.5, 0, 6.5 + i * 0.3), Vector3(0.3, 2.9, 0.3), red, false)
	_box(g, "Valance", Vector3(7.5, 2.9, 3.6), Vector3(0.3, 0.6, 3.6), red, false)

func _main_room() -> void:
	var g := _group("MainRoom")
	var wall := Color(0.09, 0.08, 0.09)
	_box(g, "Floor", Vector3(8, -0.2, 0), Vector3(18, 0.2, 8), Color(0.22, 0.21, 0.21))
	_box(g, "WallNorth", Vector3(8, 0, -0.2), Vector3(18, WALL_H, 0.2), wall)
	_box(g, "WallSouth", Vector3(8, 0, 8), Vector3(18, WALL_H, 0.2), wall)
	_box(g, "WallEast", Vector3(26, 0, 0), Vector3(0.2, WALL_H, 8), wall)

func _bar() -> void:
	var g := _group("Bar")
	var wood := Color(0.16, 0.09, 0.06)
	_box(g, "Counter", Vector3(10, 0, 1.0), Vector3(11, 1.1, 0.7), wood)
	_box(g, "CounterTop", Vector3(9.95, 1.1, 0.95), Vector3(11.1, 0.06, 0.8), Color(0.07, 0.05, 0.04), false)
	_box(g, "BackBar", Vector3(10, 0, 0.0), Vector3(11, 1.0, 0.5), wood)
	_box(g, "BottleShelf", Vector3(10, 1.4, 0.05), Vector3(11, 1.4, 0.3), Color(0.12, 0.07, 0.05), false)
	# Amber shelf lights (emissive placeholders)
	for i in 5:
		_box(g, "ShelfLight%d" % i, Vector3(10.2 + i * 2.15, 1.35, 0.3), Vector3(1.8, 0.06, 0.12), Color(1.0, 0.62, 0.15), false, 3.0)
	for i in 7:
		_cyl(g, "Stool%d" % i, Vector3(10.6 + i * 1.5, 0, 1.95), 0.2, 0.55, Color(0.05, 0.05, 0.06))
	_omni(g, "BarAmberLight", Color(1.0, 0.6, 0.2), 1.6, 8.0, Vector3(15.5, 2.4, 1.2))

func _tables() -> void:
	var g := _group("Tables")
	for i in 4:
		var x := 11.5 + i * 3.0
		_cyl(g, "Table%d" % i, Vector3(x, 0, 3.7), 0.5, 0.75, Color(0.2, 0.12, 0.08))
		_box(g, "Candle%d" % i, Vector3(x - 0.04, 0.75, 3.66), Vector3(0.08, 0.14, 0.08), Color(1.0, 0.7, 0.3), false, 4.0)
		for s in 3:
			var a := s * TAU / 3.0
			_cyl(g, "Stool%d_%d" % [i, s], Vector3(x + cos(a) * 0.85, 0, 3.7 + sin(a) * 0.85), 0.18, 0.45, Color(0.05, 0.05, 0.06))

func _communal_table() -> void:
	var g := _group("CommunalTable")
	_box(g, "Table", Vector3(11, 0, 6.8), Vector3(8, 0.8, 0.8), Color(0.2, 0.12, 0.08))
	_box(g, "BenchNorth", Vector3(11, 0, 6.3), Vector3(8, 0.45, 0.35), Color(0.18, 0.1, 0.09), false)
	for i in 3:
		_box(g, "CandleLamp%d" % i, Vector3(12.5 + i * 2.5, 0.8, 7.1), Vector3(0.1, 0.16, 0.1), Color(1.0, 0.7, 0.3), false, 4.0)

func _stage() -> void:
	var g := _group("Stage")
	_box(g, "Platform", Vector3(23, 0, 0.5), Vector3(3, 0.5, 7), Color(0.4, 0.04, 0.05))
	# Walk-on ramp up to the stage
	var ramp := _box(g, "StageRamp", Vector3(0, 0, 0), Vector3(1.3, 0.1, 1.3), Color(0.35, 0.03, 0.04))
	ramp.position = Vector3(22.4, 0.22, 5.5)
	ramp.rotation.z = atan2(0.5, 1.2)
	# Red curtain wall at the far end
	_box(g, "CurtainBack", Vector3(25.6, 0, 0.1), Vector3(0.3, WALL_H, 7.8), Color(0.45, 0.04, 0.05), false)
	for i in 5:
		_box(g, "CurtainFold%d" % i, Vector3(25.3, 0, 0.3 + i * 1.5), Vector3(0.2, WALL_H, 0.5), Color(0.35, 0.02, 0.04), false)
	_box(g, "Drums", Vector3(24.6, 0.5, 3.2), Vector3(0.9, 0.7, 0.9), Color(0.05, 0.05, 0.06), false)
	_box(g, "Amp", Vector3(24.3, 0.5, 1.2), Vector3(0.6, 0.9, 0.4), Color(0.05, 0.05, 0.06), false)
	_box(g, "StageWash", Vector3(23.1, WALL_H - 0.3, 0.8), Vector3(2.8, 0.1, 6.4), Color(1.0, 0.1, 0.1), false, 1.5)
	_box(g, "DiscoBall", Vector3(22.4, 3.0, 3.8), Vector3(0.4, 0.4, 0.4), Color(0.8, 0.8, 0.9), false, 0.8)
	_omni(g, "StageRedWash", Color(1.0, 0.05, 0.05), 1.8, 7.0, Vector3(24.0, 3.0, 4.0))
