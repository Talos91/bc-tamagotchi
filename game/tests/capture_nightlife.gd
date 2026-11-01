extends SceneTree
## Real-window screenshot run for the nightlife actions (not a pass/fail test; BACKLOG B12, DECISIONS "Playtest of
## 33dc5b9"): Light one up, the secret Check the plumbing prompt and sheet, drunk at 4, 7 and 10, the WASTED collapse
## and screen (English and Thai). From game/, one size per run:
##   godot --path . --resolution 800x1422 --script res://tests/capture_nightlife.gd -- --tag=portrait --capture-size=1080x1920
##   godot --path . --resolution 1920x1080 --script res://tests/capture_nightlife.gd -- --tag=landscape --capture-size=1920x1080
## A 1080x1920 window is clipped to the screen, so portrait renders a 9:16 window that fits and scales the frame up.
## Writes <n>-<shot>-<tag>.png to docs/art/screens/nightlife/ (override with --out=DIR).

const Rules = preload("res://scripts/rules.gd")

var out := "res://../docs/art/screens/nightlife"
var tag := "portrait"
var size := Vector2i.ZERO   ## --capture-size: frames are scaled to this
var main: Node
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--capture-size="):
			var wh := a.get_slice("=", 1).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(nm: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	if size != Vector2i.ZERO and img.get_size() != size:
		img.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var path := out.path_join("%s-%s.png" % [nm, tag])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _place(z: Dictionary, yaw := 0.0, offset := Vector3.ZERO) -> void:
	var p: Player = main.player
	p.walking_to = false
	p.global_position = z["approach"] + offset + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.get_node("Body").rotation.y = yaw
	p.rig.snap()
	await _wait(1.2)


## Close-up from in front of the character, the HUD hidden; back to the game camera after.
func _close(nm: String, from: Vector3, at_h := 1.25) -> void:
	var p: Player = main.player
	main.get_node("UI").visible = false
	cam.fov = 58.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT if root.get_visible_rect().size.aspect() >= 1.0 else Camera3D.KEEP_WIDTH
	cam.cull_mask = p.rig.camera.cull_mask
	var b: Basis = p.get_node("Body").global_basis   # in front of the character as they face now: `from` is (side, up, forward)
	var at := p.global_position + Vector3(0, at_h, 0)
	cam.look_at_from_position(p.global_position + b.x * from.x + Vector3(0, from.y, 0) + b.z * from.z, at)
	cam.make_current()
	await _wait(0.6)
	await _shot(nm)
	p.rig.camera.make_current()
	main.get_node("UI").visible = true


func _row(id: String) -> void:
	main.hud.prompt_pressed.emit()
	await process_frame
	if is_instance_valid(main.sheet) and main.sheet.buttons.has(id):
		main.sheet.buttons[id].pressed.emit()
	await process_frame


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_nightlife_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	var s: VenueSession = main.session
	s.rng.seed = 7
	cam = Camera3D.new()
	main.add_child(cam)

	# 1. Light one up in the smoking room
	var smoke: Dictionary = main.zones.first_of("smoking")
	await _place(smoke, 0.0)
	await _row("smoke")
	s.smoking["left"] = 60.0   # keep it lit for the shots
	await _wait(2.5)
	await _shot("1-smoking")
	await _close("1-smoking-close", Vector3(-0.35, 1.5, 1.15))
	s.cancel_smoke()

	# 2. The toilets: the prompt, then the sheet with the secret row
	var loo: Dictionary = main.zones.first_of("toilet")
	await _place(loo, 0.0)
	await _shot("2-plumbing-prompt")
	main.hud.prompt_pressed.emit()
	await _wait(0.6)
	await _shot("2-plumbing-sheet")
	main.close_sheet()
	await _wait(0.3)

	# 3-5. Drunk at 4, 7 and 10, at the bar
	var bar: Dictionary = main.zones.first_of("bar")
	await _place(bar, PI)
	var n := 3
	for want in [4, 7, 10]:
		while s.tipsy.drinks < want:
			s.order_item("house_shooter")
		if is_instance_valid(main.hud.card):
			main.hud.card.queue_free()
		main.drunk.snap()
		await _wait(1.6)
		await _shot("%d-drunk-%d" % [n, want])
		n += 1

	# 6-7. The 11th: WASTED, mid-puke, then the screen (English, then Thai)
	s.order_item("house_shooter")
	await _wait(0.9)
	await _shot("6-wasted-puke")
	await _wait(1.6)
	await _shot("6-wasted-down")
	await _wait(2.5)
	await _shot("7-wasted-screen")
	TranslationServer.set_locale("th")
	var line: int = main.wasted_shot.line
	main.wasted_shot.screen.queue_free()
	main.wasted_shot._show_screen()
	await _wait(1.0)
	await _shot("7-wasted-screen-th")
	TranslationServer.set_locale("en")
	print("wasted line ", line)
	quit()
