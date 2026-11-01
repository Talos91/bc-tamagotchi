class_name Player
extends CharacterBody3D
## Diorama controller. Move with WASD / arrows or the on-screen joystick (touch_joystick.gd), relative to the
## camera; or tap / click the floor to walk there along the venue's navmesh (NavigationAgent3D). Any stick or key
## input cancels a tap-walk. The camera is the CameraRig child (camera_rig.gd); the body is a PatronFigure
## (scenes/venue/patron_figure.tscn) with the `look` below, and a warm ring on the floor marks the player.
## main.gd sets `tap_handler` (a tap on a zone walks there and opens it), `input_enabled` (off under sheets and
## minigames), `anim_suffix` (tipsiness: "_warm" plays idle_warm / walk_warm) and `pose_override` (played standing still).
## Seats: `sit_at(seat)` walks to a seat spot of the venue (VenueSession.find_seat) and, on arrival, puts the
## character on it facing the table, at the seat's height, in the seated pose; any stick / key input or a walk
## stands them up where they were. The player is in group "door_user", so swing doors open for them.

@export var speed := 3.6
@export var accel := 18.0
@export var look := {"preset": "patron_06", "skin": Color("bc8860"), "hair": Color("1e1616"), "top": Color("d9c9a6"),
	"bottom": Color("3f5878"), "shoes": Color("e4dde6"), "height": 1.35}

const TAP_MAX_MOVE := 24.0      ## pixels a touch may travel and still count as a tap
const TAP_MAX_TIME := 0.35      ## seconds
const SEAT_REACH := 1.0         ## metres from a seat spot at which a walk to it ends in sitting down

var joystick: TouchJoystick   ## set by main.gd; null = keyboard only
var walking_to := false       ## true while following a tap-to-move path
var input_enabled := true     ## false while a sheet, minigame or dialogue is open
var tap_handler: Callable     ## (world_pos: Vector3) -> bool; true = the tap was taken (e.g. a zone)
var anim_suffix := ""         ## tipsiness set: "", "_warm", "_tipsy", "_merry"
var pose_override := ""       ## played instead of idle while standing still
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _press_index := -1
var _press_pos := Vector2.ZERO
var _press_time := 0
var _move_yaw := 0.0            ## camera yaw latched when a stick / key press starts (see input_to_world)
var _moving := false
var seated := false             ## on a seat (sit_at arrived)
var seat := {}                  ## the seat taken or being walked to: {node, pos, yaw, h, couch, pose}
var _stand_pos := Vector3.ZERO  ## where the player stood before sitting down (they stand up there)

@onready var rig: CameraRig = $CameraRig
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _body: Node3D = $Body
@onready var figure: PatronFigure = $Body/Figure

func _ready() -> void:
	figure.set_look(look)
	add_to_group("door_user")

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		_press_index = -1
		return
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
	if tap_handler.is_valid() and tap_handler.call(hit.position):
		return true
	walk_to(hit.position)
	return true

## The agent's path query snaps the target to the navmesh, so off-mesh taps (a table top) walk to the nearest
## reachable point.
func walk_to(world_pos: Vector3) -> void:
	stand_up()
	_agent.target_position = world_pos
	walking_to = true

## Walk to a seat spot and sit on it (the seat's spot is inside the chair's collider, so the walk ends next to it).
func sit_at(s: Dictionary) -> void:
	stand_up()
	var fwd := Basis(Vector3.UP, float(s["yaw"])) * Vector3(0, 0, 1)
	# Approach from behind the chair, or in front of a couch / banquette (backs to the wall)
	walk_to(s["pos"] + fwd * (0.7 if s.get("couch", false) else -0.45))
	seat = s

## True while walking to a seat taken with sit_at.
func seat_pending() -> bool:
	return not seat.is_empty() and not seated

func stand_up() -> void:
	if seated:
		global_position = _stand_pos
		figure.position.y = 0.0
		velocity = Vector3.ZERO
	seated = false
	seat = {}

func _take_seat() -> void:
	_stand_pos = global_position
	var p: Vector3 = seat["pos"]
	global_position = p
	velocity = Vector3.ZERO
	_body.rotation.y = float(seat["yaw"])
	# As venue_patrons.gd seats the crowd: the preset's thighs sit SEAT_H * FIG_SCALE above its root
	figure.position.y = float(seat["h"]) - PatronFigure.SEAT_H * PatronFigure.FIG_SCALE
	seated = true

func _input_vector() -> Vector2:
	var v := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if joystick and joystick.value.length() > v.length():
		v = joystick.value
	return v.limit_length(1.0) if input_enabled else Vector2.ZERO

func _physics_process(delta: float) -> void:
	var iv := _input_vector()
	if seated:
		if iv.length() > 0.1:
			stand_up()
		else:
			figure.move_speed = 0.0
			figure.play(str(seat.get("pose", "sit")))
			return
	elif seat_pending() and iv.length() <= 0.1:
		# Next to the seat, or the walk ended as close as the navmesh goes: sit if it is within reach, else give up
		var d: Vector3 = seat["pos"] - global_position
		var reach := Vector2(d.x, d.z).length()
		if reach < SEAT_REACH or (not walking_to and reach < 1.6):
			walking_to = false
			_take_seat()
			return
		if not walking_to:
			seat = {}
	var dir := Vector3.ZERO
	if iv.length() > 0.1:
		walking_to = false
		if not _moving:   # a held direction keeps meaning the same way while the camera swings between zones
			_move_yaw = rig.yaw
			_moving = true
		dir = input_to_world(iv)
	else:
		_moving = false
	if iv.length() <= 0.1 and walking_to:
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
	if flat > 0.3:
		figure.play(_anim_name("walk"))
	else:
		figure.play(pose_override if pose_override != "" else _anim_name("idle"))

## World direction for a stick / key vector in the frame latched at the start of the press (camera yaw then).
func input_to_world(v: Vector2) -> Vector3:
	return Basis(Vector3.UP, _move_yaw if _moving else rig.yaw) * Vector3(v.x, 0, v.y)

## Stick vector that walks toward world direction `d` in the current input frame (tests drive the joystick with it).
func world_to_input(d: Vector3) -> Vector2:
	var l := Basis(Vector3.UP, -(_move_yaw if _moving else rig.yaw)) * Vector3(d.x, 0, d.z)
	return Vector2(l.x, l.z)

## The tipsiness variant of a base animation when the figure has it (box placeholders do not).
func _anim_name(base: String) -> String:
	var ap: AnimationPlayer = figure.get("_anim")
	if anim_suffix != "" and ap != null and ap.has_animation(base + anim_suffix):
		return base + anim_suffix
	return base
