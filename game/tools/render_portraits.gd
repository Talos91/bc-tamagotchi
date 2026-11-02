extends SceneTree
## Renders the corridor portraits (BACKLOG B7): head and shoulders of each top patron's preset (scripts/zones/patrons.gd)
## in the game's own voxel graphics, three-quarter front, warm key and red rim on a dark red backdrop, 320 x 400 PNG into
## res://assets/venue/portraits/<preset>.png. Needs a GPU window, not --headless. From game/:
##   godot --path . --script res://tools/render_portraits.gd
## Re-run after the characters are re-exported; then import (godot --headless --path . --import).

const Patrons = preload("res://scripts/zones/patrons.gd")
const SIZE := Vector2i(320, 400)

var vp: SubViewport
var queue: Array = []
var fig: Node3D
var frames := 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Patrons.PORTRAIT_DIR))
	vp = SubViewport.new()
	vp.size = SIZE
	vp.msaa_3d = Viewport.MSAA_4X
	vp.use_hdr_2d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a0608")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5a3a34")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffd2a0")
	key.light_energy = 1.4
	key.rotation_degrees = Vector3(-30, 35, 0)
	vp.add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color("ff2a14")
	rim.light_energy = 3.0
	rim.omni_range = 4.0
	rim.position = Vector3(-0.8, 1.9, -0.9)
	vp.add_child(rim)
	# Backdrop: a lighter wall behind the figure so the silhouette reads
	var disc := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(4.0, 4.0)
	disc.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("4a0c10")
	disc.material_override = m
	disc.position = Vector3(0, 1.3, -1.2)
	vp.add_child(disc)
	for r in Patrons.count():
		queue.append(Patrons.at(r)["preset"])
	_next()

func _next() -> void:
	if is_instance_valid(fig):
		fig.queue_free()
	if queue.is_empty():
		quit(0)
		return
	var preset: String = queue[0]
	fig = (load("res://assets/chars/presets/%s.glb" % preset) as PackedScene).instantiate()
	vp.add_child(fig)
	fig.rotation_degrees.y = 18.0
	var ap := BCChars.setup_animations(fig)
	if ap and ap.has_animation("idle"):
		ap.play("idle")
		ap.seek(0.3, true)
		ap.pause()
	frames = 0

func _process(_delta: float) -> bool:
	if queue.is_empty():
		return true
	frames += 1
	if frames == 2:
		# Frame the head and shoulders from the figure's own bounds (bodies differ in height)
		var top := 0.0
		for mi in fig.find_children("*", "MeshInstance3D", true, false):
			var b := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			top = maxf(top, b.end.y)
		var cam := Camera3D.new()
		cam.fov = 30.0
		vp.add_child(cam)
		var look := Vector3(0, top - 0.4, 0)
		cam.position = look + Vector3(0, 0.12, 2.5)
		cam.look_at(look)
		cam.current = true
		fig.set_meta("cam", cam)
	if frames < 12:
		return false
	var preset: String = queue.pop_front()
	var img := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(Patrons.PORTRAIT_DIR + preset + ".png")
	print("portrait ", preset, " -> ", img.save_png(path))
	(fig.get_meta("cam") as Node).queue_free()
	_next()
	return false
