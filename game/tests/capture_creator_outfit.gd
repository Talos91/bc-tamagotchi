extends SceneTree
## Real-window screenshots of the character creator (owner list 2026-11-20 items 1 and 3: "character creation is
## superunresponsve", "too little variety expecially in clothing"). Not a pass/fail test. Every tab (the Outfit tab
## also scrolled to its end), then with --variety a sheet of outfits made on the new Outfit tab. Hidden desktop:
##   godot --path . --resolution 540x960 --script res://tests/capture_creator_outfit.gd -- --tag=portrait --prefix=after- [--variety]
## Writes <prefix><tag>-<shot>.png to docs/art/screens/creator-fix/creator/ (--out=DIR).

const Avatar = preload("res://scripts/avatar.gd")
const Creator = preload("res://scripts/ui/character_creator.gd")

const OUTFITS := [   # pieces picked on the Outfit tab, one shot each
	{"top": "shirt_aloha", "top_colour": "Teal", "print_colour": "Cream", "bottom": "shorts", "bottom_colour": "Sand", "shoes": "sneakers", "hat": "hat_bucket", "glasses": "glasses_tinted"},
	{"top": "leather", "top_colour": "LeatherBlack", "bottom": "jeans_ripped", "bottom_colour": "JeansBlue", "shoes": "boots", "hat": "", "glasses": "glasses_round"},
	{"top": "dress", "top_colour": "Fuchsia", "shoes": "loafers", "hat": "hat_fedora", "glasses": ""},
	{"top": "tee_stripe", "top_colour": "Cobalt", "print_colour": "ShirtWhite", "bottom": "skirt_long", "bottom_colour": "Olive", "shoes": "sneakers", "hat": "hat_beanie", "glasses": ""},
	{"top": "hoodie", "top_colour": "Lilac", "bottom": "trousers", "bottom_colour": "Charcoal", "shoes": "sneakers", "hat": "hat_cap", "glasses": ""},
	{"top": "shirt_check", "top_colour": "Coral", "print_colour": "StoolBlack", "bottom": "skirt", "bottom_colour": "Denim", "shoes": "boots", "hat": "hat_flat_cap", "glasses": "glasses_round"},
]

var out := "res://../docs/art/screens/creator-fix/creator"
var tag := "portrait"
var prefix := ""
var variety := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--prefix="):
			prefix = a.substr(9)
		elif a == "--variety":
			variety = true
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	var full := Vector2i(1080, 1920) if tag == "portrait" else Vector2i(1920, 1080)
	root.size = full / 2
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = full
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(nm: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := out.path_join("%s%s-%s.png" % [prefix, tag, nm])
	img.save_png(path)
	print("saved ", path)


func _run() -> void:
	await process_frame
	var c: Control = Creator.new()
	root.add_child(c)
	c.open("edit", Avatar.default_record(), "Ty", "night_owl")
	await _wait(1.0)
	await _shot("1-body")
	c._go_tab(1)
	await _wait(1.5)   # the hair cards' pictures
	await _shot("2-hair")
	c._go_tab(2)
	await _wait(0.6)
	await _shot("3-outfit")
	c._scroll.scroll_vertical = 100000
	await _wait(0.4)
	await _shot("4-outfit-end")
	if variety:
		var n := 5
		for o: Dictionary in OUTFITS:
			for k in ["top", "top_colour", "print_colour", "bottom", "bottom_colour", "shoes", "hat", "glasses"]:
				if o.has(k):
					c.choose(k, o[k])
			c._scroll.scroll_vertical = 0
			await _wait(0.5)
			await _shot("%d-outfit-%s" % [n, o["top"]])
			n += 1
	quit(0)
