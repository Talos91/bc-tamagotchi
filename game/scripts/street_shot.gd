extends Node
## What the start screen (start_screen.gd) and the exit shot (exit_shot.gd) share: the street front out on the soi
## (scenes/street/street_front.gd, one `Main/Street` node kept hidden between shots), a camera of their own, the
## character driven along eased legs with physics off, the venue's street door, and the tap: the first one
## `tap()`s, any later one `skip()`s (both overridden), Esc (debug builds) skips.

const StreetFront = preload("res://scenes/street/street_front.gd")

var main: Node                 ## main.gd
var street: Node3D             ## StreetFront
var cam: Camera3D
var _tap_guard := -1


## The street front, built the first time (in front of the venue's street door).
func _street() -> Node3D:
	var s: Node3D = main.get_node_or_null("Street")
	if s != null:
		return s
	s = StreetFront.new()
	s.name = "Street"
	main.add_child(s)
	var d := _door()
	s.build(d.center if not d.is_empty() else Vector3(-0.1, 0, 7.2))
	return s


func _make_camera(nm: String) -> void:
	cam = Camera3D.new()
	cam.name = nm
	cam.near = 0.05
	cam.far = 80.0
	main.add_child(cam)
	cam.make_current()


## The still street view (street_front.gd `view_transform`).
func _place_view_camera() -> void:
	var portrait := _portrait()
	cam.global_transform = street.view_transform(portrait)
	_set_fov(portrait, street.view_fov(portrait))


func _set_fov(portrait: bool, fov: float) -> void:
	cam.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	cam.fov = fov


func _portrait() -> bool:
	return get_viewport().get_visible_rect().size.aspect() < 1.0


# --- Street door ---------------------------------------------------------------------------------

func _doors() -> Node:
	return main.get_node_or_null("Venue/Doors")


## The street door's entry in venue_doors.gd ({node, center, open, hold, ...}), {} without one.
func _door() -> Dictionary:
	var doors := _doors()
	if doors:
		for d in doors.doors:
			if (d.node as Node).name == "StreetDoor":
				return d
	return {}


func door_open() -> float:
	var d := _door()
	return float(d.open) if not d.is_empty() else 0.0


## Shut now, as if nobody had been near it.
func _shut_door() -> void:
	var d := _door()
	if d.is_empty():
		return
	d.hold = 0.0
	_doors().pose("StreetDoor", 0.0, Vector3.ZERO)


# --- The character -------------------------------------------------------------------------------

## Physics, input and the diorama rig off: the shot moves the character (and owns the camera).
func _take_player() -> void:
	var p: Player = main.player
	p.input_enabled = false
	p.set_physics_process(false)
	p.velocity = Vector3.ZERO
	p.rig.set_process(false)
	p.global_transform = Transform3D(Basis.IDENTITY, p.global_position)


## Puts the character at `pos` facing world yaw `yaw` (0 faces +z), walking at `speed` m/s (idle below 0.3).
func _drive(pos: Vector3, yaw: float, speed: float) -> void:
	var p: Player = main.player
	p.global_position = pos
	p.get_node("Body").global_rotation = Vector3(0, yaw, 0)
	p.figure.move_speed = speed
	p.figure.play("walk" if speed > 0.3 else "idle")


## Back at main's spawn facing into the lobby, the diorama camera on, physics on (input stays with main).
func _give_back_player() -> void:
	var p: Player = main.player
	var sp: Transform3D = main._spawn
	p.global_transform = Transform3D(sp.basis, Vector3(sp.origin.x, 0.02, sp.origin.z))
	p.get_node("Body").global_rotation = Vector3(0, PI * 0.5, 0)
	p.figure.move_speed = 0.0
	p.figure.play("idle")
	p.velocity = Vector3.ZERO
	p.visible = true
	p.set_physics_process(true)
	p.rig.snap()
	p.rig.set_process(true)
	p.rig.camera.make_current()
	if is_instance_valid(cam):
		cam.queue_free()


## Fraction of a leg of `dur` s done at time t: speeds up over `acc`, steady, slows down over `dec`.
static func leg(t: float, dur: float, acc: float, dec: float) -> float:
	t = clampf(t, 0.0, dur)
	var v := 1.0 / (dur - (acc + dec) * 0.5)
	if t < acc:
		return 0.5 * v / acc * t * t
	var s := 0.5 * v * acc
	if t < dur - dec:
		return s + v * (t - acc)
	s += v * (dur - dec - acc)
	var u := t - (dur - dec)
	return minf(1.0, s + v * u - 0.5 * v / dec * u * u)


## Speed (m/s) at time t along a leg of `dist` metres (as `leg`).
static func leg_speed(t: float, dur: float, acc: float, dec: float, dist: float) -> float:
	if t <= 0.0 or t >= dur:
		return 0.0
	var v := dist / (dur - (acc + dec) * 0.5)
	if t < acc:
		return v * t / acc
	if t > dur - dec:
		return v * (dur - t) / dec
	return v


# --- Input ---------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	var go := false
	if event is InputEventScreenTouch and event.pressed:
		go = true
	elif event is InputEventMouseButton and event.pressed:
		go = true   # also arrives as ScreenTouch (emulate_touch_from_mouse); _tap_guard drops the twin
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
				go = true
			KEY_ESCAPE:
				if OS.is_debug_build():
					get_viewport().set_input_as_handled()
					skip()
				return
	if go:
		get_viewport().set_input_as_handled()
		if Engine.get_process_frames() != _tap_guard:
			_tap_guard = Engine.get_process_frames()
			tap()


func tap() -> void:
	skip()


func skip() -> void:
	pass
