extends SceneTree
## Renders chars_showcase.tscn (every preset playing its idle) in the Compatibility renderer and saves a PNG.
## Also prints every AnimationPlayer's animation list for one preset and the three part libraries.
## Needs a GPU window, not --headless. From game/:
##   godot --path . --script res://assets/chars/capture_showcase.gd -- [out.png]
## Default output: ../docs/art/chars-showcase-godot.png (relative to game/).

const SIZE := Vector2i(1600, 1000)

var frames := 0
var out := "../docs/art/chars-showcase-godot.png"
var vp: SubViewport

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	vp = SubViewport.new()
	vp.size = SIZE
	vp.msaa_3d = Viewport.MSAA_4X
	vp.use_hdr_2d = true            # Compatibility glow washes the frame out without it (DECISIONS p)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	vp.add_child(load("res://assets/chars/chars_showcase.tscn").instantiate())
	for path in ["res://assets/chars/presets/tong.glb", "res://assets/chars/parts/parts_petite.glb",
			"res://assets/chars/parts/parts_regular.glb", "res://assets/chars/parts/parts_broad.glb"]:
		var probe: Node = load(path).instantiate()
		var player := BCChars.setup_animations(probe)
		var skel := probe.find_children("*", "Skeleton3D", true, false)
		var meshes := probe.find_children("*", "MeshInstance3D", true, false)
		print("%s: %d meshes, bones %s" % [path.get_file(), meshes.size(),
			"none" if skel.is_empty() else str(skel[0].get_bone_count())])
		print("  animations: ", player.get_animation_list() if player else "NO AnimationPlayer")
		if path.ends_with("tong.glb"):
			var m := (meshes[0] as MeshInstance3D).get_active_material(0) as StandardMaterial3D
			print("  material %s tex=%s cull=%d" % [m.resource_name, m.albedo_texture != null, m.cull_mode])
		probe.free()

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 40:
		return false
	var img := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://").path_join(out) if out.is_relative_path() else out
	var err := img.save_png(path)
	print("chars showcase captured: ", path, " err=", err)
	return true
