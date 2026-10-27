class_name Player
extends CharacterBody3D
## Diorama controller. Move with WASD / arrows or the on-screen joystick (touch_joystick.gd), relative to the
## camera; or tap / click the floor to walk there along the venue's navmesh (NavigationAgent3D). Any stick or key
## input cancels a tap-walk. The camera is the CameraRig child (camera_rig.gd); the body is a PatronFigure
## (scenes/venue/patron_figure.tscn) with the `look` below, and a warm ring on the floor marks the player.

@export var speed := 3.6
@export var accel := 18.0
@export var look := {"preset": "patron_06", "skin": Color("bc8860"), "hair": Color("1e1616"), "top": Color("d9c9a6"),
	"bottom": Color("3f5878"), "shoes": Color("e4dde6"), "height": 1.35}

const TAP_MAX_MOVE := 24.0      ## pixels a touch may travel and still count as a tap
const TAP_MAX_TIME := 0.35      ## seconds

var joystick: TouchJoystick   ## set by main.gd; null = keyboard only
var walking_to := false       ## true while following a tap-to-move path
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _press_index := -1
var _press_pos := Vector2.ZERO
var _press_time := 0

@onready var rig: CameraRig = $CameraRig
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _body: Node3D = $Body
@onready var figure: PatronFigure = $Body/Figure

func _ready() -> void:
	figure.set_look(look)

func _unhandled_input(event: InputEvent) -> void:
	# Mouse clicks arrive as ScreenTouch too (project.godot emulates touch from mouse)
	if event is InputEventScreenTouch:
		if event.pressed and _press_index == -1:
			_press_index = event.index
			_press_pos = event.position
			_press_time = Time.get_ticks_msec()
		elif not event.pressed and event.index == _press_index:
			_press_index = -1
			if event.position.distance_to(_press_pos) <= TAP_MAX_MOVE and (Time.get_ticks_msec() - _press_time) <= TAP_MAX_TIME * 1000.0:
				tap_at(event.position)

## Walk to whatever floor point is under `screen_pos`.
func tap_at(screen_pos: Vector2) -> bool:
	var cam := rig.camera
	var from := cam.project_ray_origin(screen_pos)
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(screen_pos) * 100.0)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	walk_to(hit.position)
	return true

## The agent's path query snaps the target to the navmesh, so off-mesh taps (a table top) walk to the nearest
## reachable point.
func walk_to(world_pos: Vector3) -> void:
	_agent.target_position = world_pos
	walking_to = true

func _input_vector() -> Vector2:
	var v := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if joystick and joystick.value.length() > v.length():
		v = joystick.value
	return v.limit_length(1.0)

func _physics_process(delta: float) -> void:
	var iv := _input_vector()
	var dir := Vector3.ZERO
	if iv.length() > 0.1:
		walking_to = false
		dir = rig.input_to_world(iv)
	elif walking_to:
		if _agent.is_navigation_finished():
			walking_to = false
		else:
			dir = _agent.get_next_path_position() - global_position
			dir.y = 0
			dir = dir.normalized() if dir.length() > 0.05 else Vector3.ZERO
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	if dir.length() > 0.1:
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(dir.x, dir.z), 12.0 * delta)
	var flat := Vector2(velocity.x, velocity.z).length()
	figure.move_speed = flat
	figure.play("walk" if flat > 0.3 else "idle")
