extends SceneTree
## Captures for the character creator build review (docs/design/07-character-creator.md; DECISIONS 2026-11-09).
## Each creator step (new character, from the start screen's first tap), the one-time card of an older save, the photo
## booth in the lounge (game camera, its prompt, and the creator it opens). Needs a GPU window (not --headless):
##   godot --path . --script res://tests/capture_char_creator.gd -- --tag=portrait|landscape [--out=<dir>]
## Default out: docs/art/screens/char-creator/build/<tag>-<name>.png at 1080x1920 or 1920x1080.

const Avatar = preload("res://scripts/avatar.gd")
const Creator = preload("res://scripts/ui/character_creator.gd")

var out := "res://../docs/art/screens/char-creator/build"
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


func _creator(ss: Node) -> Control:
	if not is_instance_valid(ss._modal):
		return null
	for c in ss._modal.get_children():
		if c is Creator:
			return c
	return null


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_creator_save.json"
	# 1. New character: the creator from the first tap, one shot per step
	needs.new_game()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.intro = true
	root.add_child(main)
	await _wait(1.2)
	main.start_screen.tap()
	await _wait(0.6)
	var c := _creator(main.start_screen)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	c.record = Avatar.random_record(rng)
	c.record.merge({"body": "regular", "head": "round", "face": "easy", "skin": "Skin4", "hair": "bob", "hair_colour": "HairBlack", "look": "night_out", "top_colour": "LeatherBlack"}, true)
	c._refresh_figure()
	c._show_tab()
	await _wait(1.0)
	await _shot("01-body")
	c._next.pressed.emit()
	await _wait(1.0)
	await _shot("02-hair")
	c._next.pressed.emit()
	await _wait(0.8)
	await _shot("03-outfit")
	c._next.pressed.emit()
	c.choose("name", "Mai")
	await _wait(0.8)
	await _shot("04-you")
	c.choose("name", "Nam")
	c._next.pressed.emit()
	await _wait(0.4)
	await _shot("05-name-refused")
	c.choose("name", "Mai")
	c._next.pressed.emit()
	await _wait(2.5)
	await _shot("06-walk-in")
	main.queue_free()
	await _wait(0.3)
	# 2. A save from before the creator: the one-time card over the street, old look
	needs.new_game()
	needs.nights_out = 5
	needs.profile["display_name"] = "Somchai"
	main = load("res://scenes/main.tscn").instantiate()
	main.intro = true
	root.add_child(main)
	await _wait(1.2)
	await _shot("07-old-save-card")
	main.start_screen._keep_look()
	await _wait(0.6)
	await _shot("08-start-edit-look")
	main.queue_free()
	await _wait(0.3)
	# 3. The photo booth in the lounge, from the game camera, and the creator it opens
	needs.new_game()
	needs.set_avatar(Avatar.default_record().merged({"look": "smart", "top_colour": "Sky", "hair": "quiff", "hair_colour": "HairBleach", "skin": "Skin5"}, true), "Mai", "night_owl")
	for m in needs.meters:
		needs.meters[m] = 60.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	var p: Player = main.player
	var body: Node3D = p.get_node("Body")
	var booth: Dictionary = main.zones.by_id("booth")
	p.global_position = Vector3(8.0, 0.1, 6.5)   # the lounge view (as capture_lounge_followup's "lounge" still)
	body.rotation.y = PI
	p.rig.snap()
	await _wait(1.8)
	await _shot("09-booth-lounge")
	p.global_position = booth["approach"] + Vector3(0, 0.1, 0)
	p.rig.snap()
	await _wait(1.2)
	await _shot("10-booth-prompt")
	main.open_sheet(booth)
	await _wait(1.0)
	await _shot("11-booth-creator")
	main.close_creator()
	p.global_position = Vector3(6.0, 0.1, 8.0)
	p.rig.snap()
	# A review camera (not the game's) close on the booth
	var cam := Camera3D.new()
	cam.fov = 45.0
	cam.cull_mask = p.rig.camera.cull_mask
	main.add_child(cam)
	cam.global_position = Vector3(9.9, 1.9, 4.0)
	cam.look_at(Vector3(9.2, 1.15, 0.5))
	cam.current = true
	main.hud.visible = false
	await _wait(1.0)
	await _shot("12-booth-close")
	quit()
