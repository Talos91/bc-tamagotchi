class_name Player
extends CharacterBody3D
## Third-person controller. Move: WASD / arrows, or the on-screen joystick (touch_joystick.gd).
## Look: right mouse drag or a one-finger drag; mouse wheel zooms.

@export var speed := 4.5
@export var accel := 18.0
@export var cam_distance := 5.0
@export var cam_height := 1.6

var yaw := 0.0
var pitch := -0.35
var joystick: TouchJoystick   ## set by main.gd; null = keyboard only
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var _pivot: Node3D = $CameraPivot
@onready var _cam: Camera3D = $CameraPivot/Camera3D
@onready var _body: Node3D = $Body

func _ready() -> void:
	_cam.position = Vector3(0, 0, cam_distance)
	_pivot.position = Vector3(0, cam_height, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_look(event.relative)
	elif event is InputEventScreenDrag:
		_look(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_distance = maxf(2.5, cam_distance - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_distance = minf(9.0, cam_distance + 0.5)
		_cam.position.z = cam_distance

func _look(rel: Vector2) -> void:
	yaw -= rel.x * 0.005
	pitch = clampf(pitch - rel.y * 0.005, -1.2, 0.2)

func _input_vector() -> Vector2:
	var v := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if joystick and joystick.value.length() > v.length():
		v = joystick.value
	return v.limit_length(1.0)

func _physics_process(delta: float) -> void:
	_pivot.rotation = Vector3(pitch, yaw, 0)
	var iv := _input_vector()
	var dir := Basis(Vector3.UP, yaw) * Vector3(iv.x, 0, iv.y)
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	if dir.length() > 0.1:
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)
