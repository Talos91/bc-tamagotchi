class_name Player
extends CharacterBody3D
## Diorama controller. Move with WASD / arrows or the on-screen joystick (touch_joystick.gd), relative to the
## camera; or tap / click the floor to walk there along the venue's navmesh (NavigationAgent3D). Any stick or key
## input cancels a tap-walk. The camera is the CameraRig child (camera_rig.gd); the body is a PatronFigure
## (scenes/venue/patron_figure.tscn) with the `look` below, and a warm ring on the floor marks the player.
## main.gd sets `tap_handler` (a tap on a zone walks there and opens it), `input_enabled` (off under sheets and
## minigames), `anim_suffix` (tipsiness: "_warm" plays idle_warm / walk_warm) and `pose_override` (played standing still).
## Seats: `sit_at(seat)` walks to a seat spot of the venue (VenueSession.find_seat) and, on arrival, slides the
## character onto it (SIT_TIME) facing the table, at the seat's height, in the seated pose; any stick / key input or
## a walk stands them up where they were. The player is in group "door_user", so swing doors open for them.
## Feel (Daniele's playtest of 33dc5b9): one acceleration on the whole velocity (accel / decel), the figure turns
## toward where it really goes (`facing()` / `face()`, always world yaw) and keeps its facing when it stops;
## tap-walks follow the navmesh path by pure pursuit and ease in at the end.

@export var speed := 3.6
@export var accel := 14.0       ## m/s² while speeding up or changing direction
@export var decel := 22.0       ## m/s² while coming to a stop
@export var turn_rate := 14.0   ## 1/s: how quickly the figure turns to face where it is going
@export var look := {"preset": "patron_06", "skin": Color("bc8860"), "hair": Color("1e1616"), "top": Color("d9c9a6"),
	"bottom": Color("3f5878"), "shoes": Color("e4dde6"), "height": 1.35}

const TAP_MAX_MOVE := 24.0      ## pixels a touch may travel and still count as a tap
const TAP_MAX_TIME := 0.35      ## seconds
const SEAT_REACH := 1.0         ## metres from a seat spot at which a walk to it ends in sitting down
const SIT_TIME := 0.3           ## seconds to slide and turn onto a seat
const PATH_LOOKAHEAD := 0.45    ## metres along a tap-walk path the player steers toward (rounds corners smoothly)
const ARRIVE_SLOW := 0.9        ## metres before the end of a tap-walk where the player starts slowing down
const ARRIVE_DONE := 0.04       ## metres from the end of a tap-walk that count as arrived (zone approach points sit near a zone edge)

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
var _path := PackedVector3Array()   ## tap-walk path (navmesh), followed by pure pursuit
var _path_i := 0                    ## segment of _path the player is on
var seated := false             ## on a seat (sit_at arrived)
var seat := {}                  ## the seat taken or being walked to: {node, pos, yaw, h, couch, pose}
var _stand_pos := Vector3.ZERO  ## where the player stood before sitting down (they stand up there)
var _sit_t := -1.0              ## 0..1 while sliding onto a seat, -1 otherwise
var _sit_from := Vector3.ZERO
var _sit_from_yaw := 0.0

@onready var rig: CameraRig = $CameraRig
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _body: Node3D = $Body
@onready var figure: PatronFigure = $Body/Figure

func _ready() -> void:
	figure.set_look(look)
	add_to_group("door_user")
	# Steady on the stair wedges and the raised-strip ramps: stick to the floor going down, same speed up and down
	floor_snap_length = 0.4
	floor_constant_speed = true
	floor_max_angle = deg_to_rad(50.0)

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
	_path = PackedVector3Array()
	_path_i = 0
	walking_to = true

## Walk to a seat spot and sit on it (the seat's spot is inside the chair's collider, so the walk ends next to it).
func sit_at(s: Dictionary) -> void:
	stand_up()
	var fwd := Basis(Vector3.UP, float(s["yaw"])) * Vector3(0, 0, 1)
	# Approach from behind the chair, or in front of a couch / banquette (backs to the wall)
	walk_to(s["pos"] + fwd * (0.7 if s.get("couch", false) else -0.45))
	seat = s

## True while walking to a seat taken with sit_at (or sliding onto it).
func seat_pending() -> bool:
	return not seat.is_empty() and not seated

func stand_up() -> void:
	if seated or _sit_t >= 0.0:
		global_position = _stand_pos
		figure.position.y = 0.0
		velocity = Vector3.ZERO
	seated = false
	_sit_t = -1.0
	seat = {}

## World yaw the figure faces (0 = +z, south: the figure's front is +z). The Player root itself may be rotated (the
## spawn's basis in main.tscn and the start screen), so facing is read and written in world space, never as the
## Body's local rotation: writing a world yaw into the local one turned the figure by the root's 90° (walking, and
## every seat "the wrong way round", playtest of 33dc5b9).
func facing() -> float:
	return _body.global_rotation.y

func face(yaw: float) -> void:
	_body.global_rotation = Vector3(0, yaw, 0)

func _turn_toward(yaw: float, rate: float, delta: float) -> void:
	face(lerp_angle(facing(), yaw, 1.0 - exp(-rate * delta)))

## Starts the slide onto the seat: position, facing and height ease in over SIT_TIME, then `seated` is set.
func _take_seat() -> void:
	_stand_pos = global_position
	_sit_from = global_position
	_sit_from_yaw = facing()
	velocity = Vector3.ZERO
	walking_to = false
	_sit_t = 0.0

func _sit_step(delta: float) -> void:
	_sit_t = minf(_sit_t + delta / SIT_TIME, 1.0)
	var e := smoothstep(0.0, 1.0, _sit_t)
	global_position = _sit_from.lerp(seat["pos"], e)
	face(lerp_angle(_sit_from_yaw, float(seat["yaw"]), e))
	# As venue_patrons.gd seats the crowd: the preset's thighs sit SEAT_H * FIG_SCALE above its root
	figure.position.y = lerpf(0.0, float(seat["h"]) - PatronFigure.SEAT_H * PatronFigure.FIG_SCALE, e)
	figure.move_speed = 0.0
	figure.play(str(seat.get("pose", "sit")) if _sit_t > 0.3 else _anim_name("idle"))
	if _sit_t >= 1.0:
		_sit_t = -1.0
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
	if _sit_t >= 0.0:
		if iv.length() > 0.1:
			stand_up()
		else:
			_sit_step(delta)
			return
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
			_take_seat()
			_sit_step(delta)
			return
		if not walking_to:
			seat = {}
	# Wanted velocity: the stick / keys at full speed, or the tap-walk path, slowing down on arrival
	var want := Vector3.ZERO
	if iv.length() > 0.1:
		walking_to = false
		if not _moving:   # a held direction keeps meaning the same way while the camera swings between zones
			_move_yaw = rig.yaw
			_moving = true
		want = input_to_world(iv) * _speed()
	else:
		_moving = false
		if walking_to:
			want = _follow_path()
	# One acceleration on the whole horizontal velocity (not per axis, which bent diagonal starts and stops):
	# speeding up and turning use accel, easing off uses decel
	var hv := Vector3(velocity.x, 0, velocity.z)
	var rate := accel if want.length() > 0.01 and want.length() >= hv.length() - 0.01 else decel
	hv = hv.move_toward(want, rate * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	# Face where the body really goes (after sliding along a wall), or where the input points while blocked.
	# Coming to a stop keeps the last facing, so a stop never turns the figure round.
	var real := get_real_velocity()
	var moved := Vector2(real.x, real.z)
	if want.length() > 0.1:
		var f := moved if moved.length() > 0.6 else Vector2(want.x, want.z)
		_turn_toward(atan2(f.x, f.y), turn_rate, delta)
	var flat := moved.length()
	figure.move_speed = flat
	if flat > 0.3:
		figure.play(_anim_name("walk"))
	else:
		figure.play(pose_override if pose_override != "" else _anim_name("idle"))

## Velocity along the tap-walk path by pure pursuit: steer at the point PATH_LOOKAHEAD metres further along the
## path from the nearest point on it, so corners become one smooth curve instead of a stop-and-turn at each
## waypoint, and slow down over the last ARRIVE_SLOW metres so the end is never overshot (the old waypoint
## stepping overshot and turned the figure round as it arrived).
func _follow_path() -> Vector3:
	if _path.size() < 2:
		_agent.get_next_path_position()   # runs the (synchronous) path query when the target changed
		_path = _agent.get_current_navigation_path()
		_path_i = 0
		if _path.size() < 2:
			if _path.size() == 1 or _agent.is_navigation_finished():
				walking_to = false
			return Vector3.ZERO
	var pos := Vector2(global_position.x, global_position.z)
	var best_i := _path_i
	var best_t := 0.0
	var best_d := INF
	for i in range(_path_i, mini(_path_i + 4, _path.size() - 1)):
		var a := _flat(i)
		var ab := _flat(i + 1) - a
		var t := clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var d := pos.distance_to(a + ab * t)
		if d < best_d:
			best_d = d
			best_i = i
			best_t = t
	_path_i = best_i
	var here := _flat(best_i).lerp(_flat(best_i + 1), best_t)
	var left := here.distance_to(_flat(best_i + 1))
	for i in range(best_i + 1, _path.size() - 1):
		left += _flat(i).distance_to(_flat(i + 1))
	if left + best_d < ARRIVE_DONE:
		walking_to = false
		_path = PackedVector3Array()
		return Vector3.ZERO
	var goal := _flat(_path.size() - 1)
	var need := PATH_LOOKAHEAD
	var from := here
	for i in range(best_i + 1, _path.size()):
		var seg := from.distance_to(_flat(i))
		if seg >= need:
			goal = from.move_toward(_flat(i), need)
			break
		need -= seg
		from = _flat(i)
	var dir := (goal - pos).normalized()
	return Vector3(dir.x, 0, dir.y) * _speed() * clampf((left + best_d) / ARRIVE_SLOW, 0.15, 1.0)

## Walk speed: Thirsty (a Drinks meter that ran Empty, 06-stakes §7.1) slows the venue walk by 25 %.
func _speed() -> float:
	var n := get_node_or_null("/root/Needs")
	return speed * (n.walk_mult() if n != null and n.has_method("walk_mult") else 1.0)


func _flat(i: int) -> Vector2:
	return Vector2(_path[i].x, _path[i].z)

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
