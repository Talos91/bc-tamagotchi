@tool
extends SceneTree
## Generates res://assets/kit/kit_showcase.tscn from res://assets/kit/manifest.json. Run from game/:
##   godot --headless --path . --import
##   godot --headless --path . --script res://assets/kit/build_showcase.gd
## Re-run after tools/blender/bc_kit.py re-exports the kit. Zones in two columns (lines wrapped at MAX_W), every object labelled,
## under a dark WorldEnvironment with glow so the _emissive materials bloom. Units are metres.

const MANIFEST := "res://assets/kit/manifest.json"
const OUT := "res://assets/kit/kit_showcase.tscn"
## Two columns of zones, front (camera side) first, so the whole kit fits one landscape frame.
const COLUMNS := [["tables", "bar", "circulation"], ["stage", "lounge"]]
const GAP := 0.5
const MAX_W := 6.5
const COLUMN_GAP := 1.5
const CABIN_DARK := Color("1c0d0c")
const FLOOR_GREY := Color("3a2c30")

var kit: Node3D

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	kit = Node3D.new()
	kit.name = "KitShowcase"
	_environment()
	var rows := {}
	for o in data.objects:
		if not rows.has(o.zone):
			rows[o.zone] = []
		rows[o.zone].append(o)
	# Lay each column out at x = 0 first, then shift the columns apart once their widths are known
	var col_nodes := []
	var col_widths := []
	var deepest := 0.0
	for column in COLUMNS:
		var z := 0.0
		var widest := 0.0
		var placed := []
		for zone in column:
			if not rows.has(zone):
				continue
			var g := Node3D.new()
			g.name = zone.capitalize().replace(" ", "")
			_own(g, kit)
			placed.append(g)
			for line in _wrap(rows[zone]):
				var depth := 0.0
				var width := -GAP
				for o in line:
					depth = max(depth, o.footprint_m[1])
					width += o.footprint_m[0] + GAP
				widest = max(widest, width)
				z -= depth * 0.5
				var x := -width * 0.5
				for o in line:
					x += o.footprint_m[0] * 0.5
					var y := 0.0
					if o.anchor == "ceiling":
						y = o.height_m + 0.3          # hang it so it clears the floor
					_place(g, o, Vector3(x, y, z))
					x += o.footprint_m[0] * 0.5 + GAP
				z -= depth * 0.5 + 0.7
			z -= 0.6
		deepest = max(deepest, -z)
		col_nodes.append(placed)
		col_widths.append(widest)
	var total := COLUMN_GAP * (COLUMNS.size() - 1)
	for w in col_widths:
		total += w
	var left := -total * 0.5
	for i in col_nodes.size():
		for g in col_nodes[i]:
			g.position.x = left + col_widths[i] * 0.5
		left += col_widths[i] + COLUMN_GAP
	_floor(total + 4.0, deepest + 4.0, -deepest * 0.5)
	_camera(total, -deepest)
	var ps := PackedScene.new()
	ps.pack(kit)
	var err := ResourceSaver.save(ps, OUT)
	print("kit showcase saved: ", err, " (", data.objects.size(), " objects)")
	kit.free()
	quit(0 if err == OK else 1)

## Split a zone's objects into lines no wider than MAX_W metres.
func _wrap(objs: Array) -> Array:
	var lines := [[]]
	var w := 0.0
	for o in objs:
		if w > 0.0 and w + o.footprint_m[0] > MAX_W:
			lines.append([])
			w = 0.0
		lines[-1].append(o)
		w += o.footprint_m[0] + GAP
	return lines

func _own(n: Node, parent: Node) -> void:
	parent.add_child(n)
	n.owner = kit

func _place(parent: Node, o: Dictionary, pos: Vector3) -> void:
	var scene: PackedScene = load(o.path)
	if scene == null:
		push_error("missing " + o.path)
		return
	var inst := scene.instantiate()
	inst.name = o.name
	_own(inst, parent)
	inst.position = pos
	var label := Label3D.new()
	label.name = o.name + "_label"
	label.text = o.name
	label.font_size = 32
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 1, 1, 0.75)
	label.position = pos + Vector3(0, 0.02, o.footprint_m[1] * 0.5 + 0.12)
	if o.anchor == "ceiling":
		label.position.y = 0.02
	_own(label, parent)

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = CABIN_DARK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.32, 0.3)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_own(we, kit)
	# Low warm key plus a red fill: the bible's "every readable object is lit by a nearby source"
	var key := DirectionalLight3D.new()
	key.name = "WarmKey"
	key.light_color = Color(1.0, 0.72, 0.5)
	key.light_energy = 1.0
	key.rotation_degrees = Vector3(-50, -30, 0)
	key.shadow_enabled = true
	_own(key, kit)
	var fill := DirectionalLight3D.new()
	fill.name = "RedFill"
	fill.light_color = Color(1.0, 0.12, 0.1)
	fill.light_energy = 0.15
	fill.rotation_degrees = Vector3(-30, 140, 0)
	_own(fill, kit)

func _floor(w: float, d: float, cz: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = FLOOR_GREY
	m.roughness = 0.3
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(w, d)
	mesh.material = m
	var mi := MeshInstance3D.new()
	mi.name = "Floor"
	mi.mesh = mesh
	mi.position = Vector3(0, 0, cz)
	_own(mi, kit)

func _camera(widest: float, back_z: float) -> void:
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 45.0
	var centre := Vector3(0, 0.6, back_z * 0.5)
	var dist: float = max(widest * 0.95, -back_z * 1.45)
	var pos := centre + Vector3(0, dist * 0.7, dist * 0.72)
	cam.transform = Transform3D(Basis.looking_at(centre - pos, Vector3.UP), pos)
	cam.current = true
	_own(cam, kit)
