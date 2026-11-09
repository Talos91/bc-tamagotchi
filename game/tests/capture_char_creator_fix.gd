extends SceneTree
## Captures for the creator fix (owner items 26-27, 2026-11-09): the hair picker with the new styles, the three starter
## looks, the refused-name state (the reason above the button), the × on every step. Needs a GPU window:
##   godot --path . --script res://tests/capture_char_creator_fix.gd -- --tag=portrait|landscape [--out=<dir>]
## Default out: docs/art/screens/char-creator/fix/<tag>-<name>.png at 1080x1920 or 1920x1080.

const Avatar = preload("res://scripts/avatar.gd")
const Creator = preload("res://scripts/ui/character_creator.gd")

var out := "res://../docs/art/screens/char-creator/fix"
var tag := "portrait"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
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
	var path := out.path_join("%s-%s.png" % [tag, nm])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _apply(c: Control, rec: Dictionary) -> void:
	c.record = Avatar.normalize(c.record.merged(rec, true))
	c._refresh_figure()
	c._show_tab()


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_creator_fix_save.json"
	needs.new_game()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.intro = true
	root.add_child(main)
	await _wait(1.2)
	main.start_screen.tap()
	await _wait(0.6)
	var c: Control = null
	for n in main.start_screen._modal.get_children():
		if n is Creator:
			c = n
	# Hair picker: the new long style chosen
	c._next.pressed.emit()
	_apply(c, {"body": "regular", "head": "soft", "face": "soft", "skin": "Skin3", "hair": "long_straight", "hair_colour": "HairDarkBrown", "look": "dress", "top_colour": "DressRed"})
	await _wait(1.2)
	await _shot("01-hair-long")
	_apply(c, {"hair": "pigtails", "hair_colour": "HairAuburn", "skin": "Skin2", "look": "easy", "top_colour": "Teal"})
	await _wait(1.2)
	await _shot("02-hair-pigtails")
	_apply(c, {"hair": "double_bun", "hair_colour": "HairBlack", "skin": "Skin5", "body": "petite", "head": "heart"})
	await _wait(1.2)
	await _shot("03-hair-buns")
	# The three starter looks
	c._next.pressed.emit()
	_apply(c, {"look": "easy", "top_colour": "Mustard", "hair": "pigtails", "hair_colour": "HairBrown", "skin": "Skin4", "body": "petite", "head": "round", "face": "bright"})
	await _wait(1.0)
	await _shot("04-look-easy")
	_apply(c, {"look": "dress", "top_colour": "DressRed", "hair": "long_straight", "hair_colour": "HairBlack", "skin": "Skin3", "body": "regular", "head": "soft", "face": "soft"})
	await _wait(1.0)
	await _shot("05-look-dress")
	_apply(c, {"look": "smart", "top_colour": "Sky", "hair": "crop", "hair_colour": "HairDarkBrown", "skin": "Skin6", "body": "broad", "head": "square", "face": "easy"})
	await _wait(1.0)
	await _shot("06-look-smart")
	# You tab: Into the bar with no name -> the reason above the button
	c._next.pressed.emit()
	c.choose("name", "")
	c._next.pressed.emit()
	await _wait(0.6)
	await _shot("07-name-refused")
	c.choose("name", "Mai")
	c._next.pressed.emit()
	await _wait(2.0)
	await _shot("08-left-walk-in")
	quit()
