extends SceneTree
## Real-window captures for the movement polish (owner item 17, fixed-axis stick). The same walk in every variant:
## from the lounge (camera yaw 90, looking west) east into the buffer zone (camera yaw 0, looking north), the finger
## held on a drag that walks east at the start, the camera swinging on the way; then the finger lifts and the same
## drag is made again under the new camera. The debug ring shows the finger. Not a pass/fail test.
## The figure's on-screen walk is its world velocity projected through the camera (the camera follows it).
## Shots: 1 in the lounge, drag held; 2 in the buffer, same drag still held, after the swing; 3 the same drag again.
##   godot --path . --resolution 540x960 --script res://tests/capture_movement.gd -- <out dir> portrait <frame> <prefix>
##   godot --path . --resolution 960x540 --script res://tests/capture_movement.gd -- <out dir> landscape <frame> <prefix>
## <frame>: camera (the old stick, "before"), north (VENUE_NORTH, also FIRST_CAMERA today), main_room.

const FRAMES := {"camera": Player.ControlFrame.CAMERA, "north": Player.ControlFrame.VENUE_NORTH,
	"first_camera": Player.ControlFrame.FIRST_CAMERA, "main_room": Player.ControlFrame.MAIN_ROOM}
const START := Vector3(12.6, 0.05, 5.2)
const EAST := Vector3(1, 0, 0)

var out_dir := "res://../docs/art/screens/movement-polish"
var suffix := "portrait"
var frame_name := "north"
var prefix := ""
var main: Node
var meta := {}   ## per shot: finger point and drag (window px), the figure's screen point and motion; saved as JSON

func _initialize() -> void:
	var rest: Array = []
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			rest.append(a)
	if rest.size() > 0:
		out_dir = rest[0]
	if rest.size() > 1:
		suffix = rest[1]
	if rest.size() > 2:
		frame_name = rest[2]
	if rest.size() > 3:
		prefix = rest[3]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run()

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

## The figure's screen motion over the last 0.15 s and the finger's drag, for the arrows of the composed strip.
func _mark(name: String, finger: Vector2, dir: Vector2) -> void:
	var p: Player = main.player
	var cam := p.rig.camera
	# The camera follows the figure, so its screen point hardly moves: project its world velocity instead
	var v := Vector3(p.velocity.x, 0, p.velocity.z).normalized()
	var b := cam.unproject_position(p.global_position + Vector3(0, 0.6, 0))
	var a := b - (cam.unproject_position(p.global_position + Vector3(0, 0.6, 0) + v) - b)
	meta[name] = {"finger": [_win(finger).x, _win(finger).y], "drag": [dir.x, dir.y], "fig": [b.x, b.y], "fig_move": [b.x - a.x, b.y - a.y],
		"view": p.rig.view, "yaw": rad_to_deg(p.rig.yaw), "world_move": [p.velocity.x, p.velocity.z], "size": [root.get_visible_rect().size.x, root.get_visible_rect().size.y]}

func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir).path_join("%s%s-%s-%s.png" % [prefix, frame_name, name, suffix])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())

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

## Finger down at `at` and dragged 90 canvas px along `dir` (screen, unit); returns where the finger is.
func _hold(at: Vector2, dir: Vector2) -> Vector2:
	_touch(at, true)
	await process_frame
	var pos := at
	for i in 6:
		pos += dir * 15.0
		_drag(pos, dir * 15.0)
		await process_frame
	return pos

func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_movement_save.json"
	needs.new_game()
	needs.profile["display_name"] = "Mali"
	Player.control_frame = FRAMES[frame_name]
	main = load("res://scenes/main.tscn").instantiate()
	main.intro = false
	root.add_child(main)
	await _wait(1.5)
	if is_instance_valid(main.welcome):
		main.welcome.queue_free()
		main.welcome = null
		main._sync_block()
	var p: Player = main.player
	p.global_position = START
	p.face(PI / 2.0)
	p.rig.snap()
	await _wait(0.8)
	TouchJoystick.debug_ring = true
	var size := root.get_visible_rect().size
	var at := Vector2(size.x * 0.3, size.y * 0.8)
	# The drag that walks east at the start (the frame in force at the press; CAMERA latches the lounge camera)
	var dir: Vector2 = p.world_to_input(EAST).normalized()
	print("frame %s: finger %s, camera yaw %.0f" % [frame_name, dir, rad_to_deg(p.rig.yaw)])
	var pos: Vector2 = await _hold(at, dir)
	await _wait(0.2)
	await _mark("1-lounge", at, dir)
	print("1 at ", p.global_position, " view ", p.rig.view)
	await _shot("1-lounge")
	var t := 0.0
	while t < 3.0 and p.global_position.x < 17.4:
		await physics_frame
		t += 1.0 / 60.0
	await _mark("2-buffer-held", at, dir)
	print("2 at ", p.global_position, " view ", p.rig.view, " yaw ", rad_to_deg(p.rig.yaw))
	await _shot("2-buffer-held")
	_touch(pos, false)
	# Back to the middle of the buffer, the camera settled on its view, then the same drag again
	await _wait(0.4)
	p.global_position = Vector3(16.6, 0.05, 5.2)
	await _wait(1.4)
	var before := p.global_position
	pos = await _hold(at, dir)
	await _wait(0.2)
	await _mark("3-same-drag-again", at, dir)
	var moved := p.global_position - before
	print("3 same drag again: moved ", moved, " (world ", "east" if moved.x > absf(moved.z) else "NOT east", ") yaw ", rad_to_deg(p.rig.yaw))
	await _shot("3-same-drag-again")
	_touch(pos, false)
	TouchJoystick.debug_ring = false
	var f := FileAccess.open(ProjectSettings.globalize_path(out_dir).path_join("%s%s-%s.json" % [prefix, frame_name, suffix]), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "	"))
	f.close()
	quit(0)
