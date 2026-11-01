extends "res://scripts/street_shot.gd"
## WASTED (DECISIONS "Playtest of 33dc5b9"): past Rules.WASTED_AFTER drinks the character pukes and collapses, a camera
## of its own closes in from where the diorama camera was (as exit_shot.gd does, the rig is untouched), the screen goes
## dark and the WASTED screen comes up (scenes/ui/wasted_screen.gd). About 4 s; a tap skips to the screen.
## The rules (meters, lockout, visit ended, save) were applied by Nightlife.get_wasted before this starts.
## begin_locked(): the game opened during a lockout: straight to the screen on the dark.
## Try again (once the lockout is over) gives the character back and calls main.gd's end_wasted().

const Nightlife = preload("res://scripts/zones/nightlife.gd")
const WastedScreen = preload("res://scenes/ui/wasted_screen.gd")

const PUKE := 1.5            ## doubled over, puking
const FALL := 0.7            ## keels over backwards
const LIE := 0.6             ## out cold, before the dark
const DARK := 0.8            ## fade to dark
const DARK_ALPHA := 0.9      ## the venue stays faintly there behind the screen
const CLOSE_DIST := 2.4      ## the close-up: metres from the body, along the diorama camera's line of sight
const CLOSE_FOV := 42.0
const UI_BLACK := Color("0A0506")

enum Phase { PUKE, FALL, LIE, DARK, SCREEN, DONE }

var phase := Phase.PUKE
var line := 0
var screen: Control
var _t := 0.0
var _layer: CanvasLayer
var _black: ColorRect
var _yaw := 0.0
var _cam0: Transform3D
var _cam1: Transform3D
var _fov0 := 50.0
var _puke: CPUParticles3D


func begin(m: Node, l: int) -> void:
	main = m
	line = l
	_make_layer()
	var p: Player = main.player
	var body: Node3D = p.get_node("Body")
	_yaw = body.global_rotation.y
	var rig_cam: Camera3D = p.rig.camera
	_cam0 = rig_cam.global_transform
	_fov0 = rig_cam.fov
	_take_player()
	body.global_rotation = Vector3(0, _yaw, 0)
	p.figure.move_speed = 0.0
	p.figure.play("idle_merry")
	_make_camera("WastedCamera")
	cam.cull_mask = rig_cam.cull_mask
	cam.keep_aspect = rig_cam.keep_aspect
	cam.global_transform = _cam0
	cam.fov = _fov0
	var look := p.global_position + Vector3(0, 0.35, 0)
	var back := (_cam0.origin - look).normalized()
	_cam1 = Transform3D(Basis.IDENTITY, look + back * CLOSE_DIST).looking_at(look, Vector3.UP)
	_puke = _make_puke(body)
	phase = Phase.PUKE
	_t = 0.0


## Opened during a lockout: no shot, the screen at once over the dark venue.
func begin_locked(m: Node) -> void:
	main = m
	line = Nightlife.last_line(main.needs)
	_make_layer()
	_take_player()
	main.player.visible = false
	_black.color.a = 1.0
	_show_screen()


func _make_layer() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "Wasted"
	_layer.layer = 6
	main.add_child(_layer)
	_black = ColorRect.new()
	_black.color = Color(UI_BLACK, 0.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)


## Green-yellow voxel chunks from the mouth, forward and down.
func _make_puke(body: Node3D) -> CPUParticles3D:
	var pk := CPUParticles3D.new()
	pk.name = "Puke"
	body.add_child(pk)
	pk.position = Vector3(0, 1.4, 0.22)
	pk.amount = 60
	pk.lifetime = 0.9
	pk.local_coords = false
	pk.direction = Vector3(0, -0.2, 1)
	pk.spread = 14.0
	pk.initial_velocity_min = 1.2
	pk.initial_velocity_max = 2.0
	pk.gravity = Vector3(0, -9.8, 0)
	pk.scale_amount_min = 0.6
	pk.scale_amount_max = 1.3
	var g := Gradient.new()
	g.set_color(0, Color("C8D23C"))
	g.set_color(1, Color("8A9A2A"))
	pk.color_ramp = g
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.4
	bm.material = m
	pk.mesh = bm
	pk.emitting = true
	return pk


func _process(delta: float) -> void:
	if phase >= Phase.SCREEN:
		return
	_t += delta
	var p: Player = main.player
	var body: Node3D = p.get_node("Body")
	var all := PUKE + FALL + LIE
	var k := leg(minf(_t, all), all, 0.6, 0.9)
	cam.global_transform = _cam0.interpolate_with(_cam1, k)
	cam.fov = lerpf(_fov0, CLOSE_FOV, k)
	match phase:
		Phase.PUKE:
			# doubled over, heaving
			body.rotation = Vector3(0.35 + 0.08 * sin(_t * 14.0), _yaw, 0)
			if _t >= PUKE:
				_puke.emitting = false
				phase = Phase.FALL
		Phase.FALL:
			var f := clampf((_t - PUKE) / FALL, 0.0, 1.0)
			body.rotation = Vector3(lerpf(0.35, -PI * 0.5, f * f), _yaw, lerpf(0.0, 0.18, f))
			body.position.y = lerpf(0.0, 0.12, f)
			if f >= 1.0:
				p.figure.play("idle")
				phase = Phase.LIE
		Phase.LIE:
			if _t >= all:
				phase = Phase.DARK
		Phase.DARK:
			_black.color.a = DARK_ALPHA * clampf((_t - all) / DARK, 0.0, 1.0)
			if _t >= all + DARK:
				_show_screen()


func tap() -> void:
	skip()


## Straight to the screen: the body down, the camera in, the dark.
func skip() -> void:
	if phase >= Phase.SCREEN:
		return
	var body: Node3D = main.player.get_node("Body")
	body.rotation = Vector3(-PI * 0.5, _yaw, 0.18)
	body.position.y = 0.12
	if is_instance_valid(_puke):
		_puke.emitting = false
	cam.global_transform = _cam1
	cam.fov = CLOSE_FOV
	_black.color.a = DARK_ALPHA
	_show_screen()


func _show_screen() -> void:
	phase = Phase.SCREEN
	set_process_input(false)   # the screen's button takes the taps from here on
	screen = WastedScreen.new()
	screen.name = "WastedScreen"
	_layer.add_child(screen)
	screen.open(main.needs, line)
	screen.try_again.connect(_on_try_again)


## Try again (enabled once the lockout is over): the character back on their feet at the spawn, then main.gd.
func _on_try_again() -> void:
	if phase == Phase.DONE or Nightlife.locked(main.needs):
		return
	phase = Phase.DONE
	var body: Node3D = main.player.get_node("Body")
	body.position = Vector3.ZERO
	if is_instance_valid(_puke):
		_puke.queue_free()
	_give_back_player()
	main.player.input_enabled = false
	if is_instance_valid(_layer):
		_layer.queue_free()
	queue_free()
	main.end_wasted()
