@tool
extends SceneTree
## Generates res://assets/chars/chars_showcase.tscn from res://assets/chars/manifest.json. Run from game/:
##   godot --headless --path . --import
##   godot --headless --path . --script res://assets/chars/build_showcase.gd
## Re-run after tools/blender/bc_chars.py re-exports. Three rows (regulars; staff and house band; patrons), every
## preset labelled, under the kit showcase's dark WorldEnvironment plus a warm rim light (art bible section 7).

const MANIFEST := "res://assets/chars/manifest.json"
const OUT := "res://assets/chars/chars_showcase.tscn"
const ROWS := [["regular"], ["staff", "band"], ["patron"]]
const SPACING := 0.95
const ROW_GAP := 2.7
const CABIN_DARK := Color("1c0d0c")
const FLOOR_GREY := Color("3a2c30")

var show: Node3D

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	show = Node3D.new()
	show.name = "CharsShowcase"
	show.set_script(load("res://assets/chars/chars_showcase.gd"))
	_environment()
	var z := 0.0
	var widest := 0.0
	var count := 0
	for roles in ROWS:
		var row := []
		for p in data.presets:
			if p.role in roles:
				row.append(p)
		var width := SPACING * (row.size() - 1)
		widest = max(widest, width)
		for i in row.size():
			_place(row[i], Vector3(-width * 0.5 + i * SPACING, 0, z))
			count += 1
		z -= ROW_GAP
	var depth := -z - ROW_GAP
	_floor(widest + 4.0, depth + 4.0, -depth * 0.5)
	_camera(widest, -depth)
	var ps := PackedScene.new()
	ps.pack(show)
	var err := ResourceSaver.save(ps, OUT)
	print("chars showcase saved: ", err, " (", count, " presets)")
	show.free()
	quit(0 if err == OK else 1)

func _own(n: Node, parent: Node) -> void:
	parent.add_child(n)
	n.owner = show

func _place(p: Dictionary, pos: Vector3) -> void:
	var scene: PackedScene = load(p.path)
	if scene == null:
		push_error("missing " + p.path)
		return
	var inst := scene.instantiate()
	inst.name = p.name
	_own(inst, show)
	inst.position = pos
	var label := Label3D.new()
	label.name = p.name + "_label"
	label.text = p.display
	label.font_size = 32
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 1, 1, 0.8)
	label.position = pos + Vector3(0, 0.02, 0.5)
	_own(label, show)

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
	_own(we, show)
	var key := DirectionalLight3D.new()
	key.name = "WarmKey"
	key.light_color = Color(1.0, 0.72, 0.5)
	key.light_energy = 1.0
	key.rotation_degrees = Vector3(-50, -30, 0)
	key.shadow_enabled = true
	_own(key, show)
	var fill := DirectionalLight3D.new()
	fill.name = "RedFill"
	fill.light_color = Color(1.0, 0.12, 0.1)
	fill.light_energy = 0.15
	fill.rotation_degrees = Vector3(-30, 140, 0)
	_own(fill, show)
	# Art bible section 7: every character gets a warm rim light from the nearest lamp
	var rim := DirectionalLight3D.new()
	rim.name = "WarmRim"
	rim.light_color = Color(1.0, 0.62, 0.32)
	rim.light_energy = 0.7
	rim.rotation_degrees = Vector3(-25, 160, 0)
	_own(rim, show)

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
	_own(mi, show)

func _camera(widest: float, back_z: float) -> void:
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 40.0
	var centre := Vector3(0, 0.55, back_z * 0.5)
	var dist: float = max(widest * 1.0, -back_z * 2.0)
	var pos := centre + Vector3(0, dist * 0.72, dist * 0.72)
	cam.transform = Transform3D(Basis.looking_at(centre - pos, Vector3.UP), pos)
	cam.current = true
	_own(cam, show)
