extends SceneTree
## Renders kit_showcase.tscn in the real renderer (Compatibility) into a 1600 x 1000 SubViewport and saves a PNG.
## Needs a GPU window, not --headless. From game/:
##   godot --path . --script res://assets/kit/capture_showcase.gd -- [out.png]
## Default output: ../docs/art/kit-showcase.png (relative to game/).

const SIZE := Vector2i(1600, 1000)

var frames := 0
var out := "../docs/art/kit-showcase.png"
var vp: SubViewport

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	vp = SubViewport.new()
	vp.size = SIZE
	vp.msaa_3d = Viewport.MSAA_4X
	vp.use_hdr_2d = true            # without it, Compatibility glow lifts the whole frame (bg #1C0D0C -> #92403A)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene: Node = load("res://assets/kit/kit_showcase.tscn").instantiate()
	vp.add_child(scene)
	# Report how the glTF materials came in, so a reviewer can check vertex colour and emission import
	var probe: Node = load("res://assets/kit/tables/table_lamp_lit.glb").instantiate()
	for mi in probe.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s) as StandardMaterial3D
			print("material %s vcol=%s tex=%s emission=%s energy=%.1f cull=%d" % [m.resource_name,
				m.vertex_color_use_as_albedo, m.albedo_texture != null, m.emission_enabled,
				m.emission_energy_multiplier, m.cull_mode])
	probe.free()

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 20:
		return false
	var img := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://").path_join(out) if out.is_relative_path() else out
	var err := img.save_png(path)
	print("showcase captured: ", path, " err=", err)
	return true
