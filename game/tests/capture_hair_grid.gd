extends SceneTree
## Every head x hair the creator offers, on every body (owner list 2026-11-20, item 2: "hairs often clips the head and
## looks like bald spots"). Not a pass/fail test (test_avatar's "hair cover" section is the check); a contact sheet per
## body and angle. Rows are heads, columns the offered hairs in creator order.
##   godot --path . --resolution 200x200 --script res://tests/capture_hair_grid.gd -- [--prefix=before-] [--diag]
## --diag paints the skin magenta and the hair green, so any scalp left bare shows at a glance.
## Writes <prefix>hair-<body>-<angle>[-diag].png to docs/art/screens/creator-fix/hair/ (--out=DIR).

const Avatar = preload("res://scripts/avatar.gd")
const FigureScene = preload("res://scenes/venue/patron_figure.tscn")
const Chars = preload("res://assets/chars/bc_chars.gd")
const ANGLES := {"front": Vector3(0.9, 0.55, 2.2), "back": Vector3(-1.2, 0.9, -2.0), "top": Vector3(0.25, 2.4, 0.9)}
const CELL := 200

var out := "res://../docs/art/screens/creator-fix/hair"
var prefix := ""
var diag := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--prefix="):
			prefix = a.substr(9)
		elif a == "--diag":
			diag = true
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(CELL, CELL)
	_run()


## One head-and-shoulders render per combination and angle, tiled into one sheet per body and angle.
func _run() -> void:
	await process_frame
	var d := Avatar.data()
	var hairs: Array = d["hairs"]
	var heads: Array = d["heads"]
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a0e10")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.75, 0.7)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.1
	key.rotation_degrees = Vector3(-40, 25, 0)
	world.add_child(key)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.62
	world.add_child(cam)
	var f: Node3D = FigureScene.instantiate()
	world.add_child(f)
	for body in d["bodies"]:
		var sheets := {}
		for angle in ANGLES:
			sheets[angle] = Image.create(CELL * hairs.size(), CELL * heads.size(), false, Image.FORMAT_RGBA8)
		for r in heads.size():
			for c in hairs.size():
				var rec := Avatar.default_record()
				rec.merge({"body": body, "head": heads[r], "hair": hairs[c], "hair_colour": "HairDarkBrown", "skin": "Skin3"}, true)
				f.set_look({"avatar": rec})
				f.play("idle", true)
				var anim: AnimationPlayer = f.find_children("*", "AnimationPlayer", true, false)[0]
				anim.seek(0.0, true)
				anim.pause()
				if diag:
					Chars.recolour(f, "skin", Color("ff00ff"))
					Chars.recolour(f, "hair", Color("20c020"))
				await process_frame
				var head_y := 0.9
				for sk: Skeleton3D in f.find_children("*", "Skeleton3D", true, false):
					var bi := sk.find_bone("head")
					if bi >= 0:
						head_y = (sk.global_transform * sk.get_bone_global_pose(bi)).origin.y
				var mid := Vector3(0, head_y + 0.13, 0)
				for angle in ANGLES:
					cam.look_at_from_position(mid + (ANGLES[angle] as Vector3).normalized() * 6.0, mid)
					await process_frame
					await RenderingServer.frame_post_draw
					var img := root.get_texture().get_image()
					img.convert(Image.FORMAT_RGBA8)
					sheets[angle].blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(c * CELL, r * CELL))
		for angle in ANGLES:
			var path := out.path_join("%shair-%s-%s%s.png" % [prefix, body, angle, "-diag" if diag else ""])
			sheets[angle].save_png(path)
			print("saved ", path)
	quit()
