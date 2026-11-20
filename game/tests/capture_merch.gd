extends SceneTree
## Renders for the merch-shop review card (needs a window: run on the hidden desktop, never Daniele's):
##   sheet-<cat>.png        the ten pieces of a category, each on a figure (bodies and looks vary), front three-quarter
##   sheet-<cat>-back.png   the same from behind (wings, keg, guitar, tail, mane)
##   shop-portrait.png      the shop panel at the merch stand; wardrobe-portrait.png the photo booth wardrobe
##   godot --path . --resolution 1600x900 --script res://tests/capture_merch.gd -- --out=<dir>

const Merch = preload("res://scripts/merch/merch.gd")
const Avatar = preload("res://scripts/avatar.gd")
const MerchShop = preload("res://scripts/merch/merch_shop.gd")
const FigureScene = preload("res://scenes/venue/patron_figure.tscn")

var out := "res://../docs/art/screens/merch-shop"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	_run()


func _shot(nm: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(nm + ".png"))
	print("shot ", nm)


func _stage() -> Node3D:
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("1a0b0c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.45, 0.42)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffd9b0")
	key.light_energy = 1.3
	key.rotation_degrees = Vector3(-35, 20, 0)
	w.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("ff6070")
	fill.light_energy = 0.5
	fill.rotation_degrees = Vector3(-20, 200, 0)
	w.add_child(fill)
	return w


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_merch.json"
	var bodies := ["regular", "petite", "broad", "tall"]
	for cat in Merch.SLOTS:
		for back in [false, true]:
			var w := _stage()
			var items := Merch.items(cat)
			for i in items.size():
				var rec := Avatar.default_record()
				rec["body"] = bodies[i % 4]
				rec["hair"] = Avatar.data()["hairs"][i % Avatar.data()["hairs"].size()]
				rec["skin"] = Avatar.data()["skins"][i % Avatar.data()["skins"].size()]
				rec = Merch.wear(rec, str(items[i]["id"]))
				var f: Node3D = FigureScene.instantiate()
				w.add_child(f)
				f.position = Vector3((i % 5 - 2) * 0.62, (i / 5) * 1.05, -(i / 5) * 0.9)   # back row raised
				f.rotation.y = PI + 0.5 if back else 0.45
				f.set_look({"avatar": rec})
				var lbl := Label3D.new()
				lbl.text = str(items[i]["name"])
				lbl.font_size = 22
				lbl.pixel_size = 0.0025
				lbl.position = f.position + Vector3(0, -0.06, 0.25)
				lbl.modulate = Color("ffdd78")
				w.add_child(lbl)
			var cam := Camera3D.new()
			cam.fov = 32.0
			w.add_child(cam)
			cam.look_at_from_position(Vector3(0, 1.5, 4.6), Vector3(0, 0.95, -0.45))
			cam.make_current()
			await _shot("sheet-%s%s" % [cat, "-back" if back else ""])
			w.queue_free()
			await process_frame
	# the panels, portrait
	root.size = Vector2i(540, 960)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1080, 1920)
	var prof: Node = root.get_node("PlayerProfile")
	needs.new_game()
	var r := Avatar.default_record()
	needs.set_avatar(r, "Juno", "")
	for id in ["horse_mask", "bc_cap", "star_shades", "bc_logo_tee", "angel_wings"]:
		await prof.claim(id)
	prof.state()["code"] = "BC7KQ2M9XA"
	prof.wear("bc_cap")
	prof.wear("bc_logo_tee")
	var shop: Control = MerchShop.new()
	root.add_child(shop)
	shop.open("shop", prof, needs)
	shop._select("horse_mask")
	await _shot("shop-portrait")
	shop._go("top")
	await _shot("shop-tees-portrait")
	shop.queue_free()
	shop = MerchShop.new()
	root.add_child(shop)
	shop.open("wardrobe", prof, needs)
	await _shot("wardrobe-portrait")
	shop.queue_free()
	shop = MerchShop.new()
	root.add_child(shop)
	shop.open("shop", prof, needs)
	shop._open_restore()
	await _shot("restore-portrait")
	quit(0)
