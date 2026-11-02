extends SceneTree
## Real-window captures for the touch-anywhere control: HUD with no stick graphic, the area buttons slid away, and a
## real-input check through the window (Input.parse_input_event passes the real GUI): a drag on empty play area moves the
## stick, a drag from an area button does not. Not a pass/fail test.
##   godot --path . --resolution 1080x1920 --script res://tests/capture_touch.gd -- <out dir> portrait
##   godot --path . --resolution 1920x1080 --script res://tests/capture_touch.gd -- <out dir> landscape

var out_dir := "res://../docs/art/screens/touch-anywhere"
var suffix := "portrait"
var main: Node

func _initialize() -> void:
	var rest: Array = []
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			rest.append(a)
	if rest.size() > 0:
		out_dir = rest[0]
	if rest.size() > 1:
		suffix = rest[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run()

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir).path_join("%s-%s.png" % [name, suffix])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())

## Real input arrives in window pixels; the HUD lives in canvas units (stretch), so convert.
func _win(p: Vector2) -> Vector2:
	return root.get_final_transform() * p

func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = _win(pos)
	e.pressed = pressed
	Input.parse_input_event(e)

func _drag(pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = _win(pos)
	e.relative = rel * root.get_final_transform().get_scale()
	Input.parse_input_event(e)

func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_touch_save.json"
	needs.new_game()
	needs.profile["display_name"] = "Mali"
	main = load("res://scenes/main.tscn").instantiate()
	main.intro = false
	root.add_child(main)
	await _wait(1.5)
	if is_instance_valid(main.welcome):
		main.welcome.queue_free()
		main.welcome = null
		main._sync_block()
	await _wait(0.5)
	await _shot("1-hud-no-stick")
	var js: TouchJoystick = main.get_node("UI/Joystick")
	var size := root.get_visible_rect().size
	var start := Vector2(size.x * 0.3, size.y * 0.6)
	# Real input: a drag on empty play area moves the stick
	TouchJoystick.debug_ring = true
	_touch(start, true)
	await process_frame
	var pos := start
	for i in 6:
		pos += Vector2(0, 12)
		_drag(pos, Vector2(0, 12))
		await process_frame
	print("REAL drag on play area: stick ", js.value, " player speed ", main.get_node("Player").velocity.length())
	await _wait(0.3)
	await _shot("2-debug-ring-only")
	TouchJoystick.debug_ring = false
	_touch(pos, false)
	await _wait(0.3)
	print("REAL release: stick ", js.value)
	# Real input: a drag that starts on an area button
	var btn: Button = main.hud.find_child("Area_lounge", true, false)
	var c := btn.get_global_rect().get_center()
	_touch(c, true)
	await process_frame
	_drag(c + Vector2(0, -60), Vector2(0, -60))
	await process_frame
	_drag(c + Vector2(0, -120), Vector2(0, -60))
	await process_frame
	print("REAL drag from an area button: stick ", js.value)
	_touch(c + Vector2(0, -120), false)
	await _wait(0.3)
	# Area buttons slid away
	main.hud.set_areas_shown(false)
	await _wait(0.6)
	await _shot("3-areas-hidden")
	main.hud.set_areas_shown(true)
	await _wait(0.6)
	await _shot("4-areas-back")
	quit(0)
