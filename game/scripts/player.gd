class_name Player
extends CharacterBody3D
## Diorama controller. Move with WASD / arrows or by dragging anywhere on empty play area (touch_joystick.gd), relative to
## the camera (`control_frame`, below); or tap / click the floor to walk there along the venue's navmesh (NavigationAgent3D). Any stick or key
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
## Movement polish (owner feedback 2026-11-04, items 17 and 18):
##   axis        `control_frame` picks the frame of the stick and the keys. Default CAMERA (camera-relative, the
##       camera yaw latched for the length of a press, as before): the fixed axis tried for item 17 was rolled back
##       by Daniele on 2026-11-04 ("very hard to manoeuvre"). One-line switch: the default of `control_frame` (VENUE_NORTH: screen-up = venue north, -z; FIRST_CAMERA: the yaw of the camera the first
##       time the stick is used, the lobby's after the start screen, which is north today; MAIN_ROOM: screen-up =
##       east, the main room's view; CAMERA: the old camera-relative stick, latched for the length of a press).
##   not stuck   tap-walk paths are cleaned of repeated points (a run of them filled the pursuit's search window and
##       the figure swung to and fro forever by the buffer's tall tables); a walk that stops getting closer re-plans,
##       counts as arrived within ARRIVE_NEAR, gives up after STALL_REPLANS; and a stick held into a table or a chair
##       (the figure stops, no slide) walks round it along the navmesh toward a point ahead in the stick's
##       direction (`_steer_stick`), as long as the stick keeps pointing the same way.

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
const ARRIVE_NEAR := 0.3        ## a tap-walk that stalls this close to its end counts as arrived
const STALL_TIME := 0.5         ## seconds without 5 cm of progress along a tap-walk before it re-plans
const STALL_REPLANS := 2        ## re-plans before a stalled tap-walk gives up
const DETOUR_BLOCKED := 0.1     ## seconds the stick must be blocked (figure not moving its way) before it walks round
const DETOUR_MAX := 1.5         ## seconds one detour may last before it is re-planned
const DETOUR_TURN := 35.0       ## degrees the stick may turn and keep its detour
const DETOUR_REACH := [1.5, 2.5, 3.5]   ## metres ahead in the stick's direction the detour heads for (first that works)
const NAV_LOOK := 0.12          ## seconds of stick motion checked against the walkable area (navmesh) ahead
const NAV_OFF := 0.15           ## metres off the navmesh beyond which the stick is free (seats, test spots)

enum ControlFrame { VENUE_NORTH, FIRST_CAMERA, MAIN_ROOM, CAMERA }
## Which frame the stick / keys move in (owner item 17). THE one-line switch: change this default.
## Rolled back to CAMERA by Daniele 2026-11-04 after playing the live build: the fixed axis was "very hard to manoeuvre".
static var control_frame := ControlFrame.CAMERA
const MAIN_ROOM_YAW := -PI / 2.0     ## the main room's camera yaw (screen-up = east)
static var _first_yaw := NAN         ## FIRST_CAMERA: latched on first use, kept for the session

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
var _walk_best := INF               ## tap-walk: least distance left so far (stall check)
var _walk_stall := 0.0
var _replans := 0
var _blocked := 0.0                 ## stick: seconds the figure has not moved its way
var _detour := PackedVector3Array() ## stick: navmesh path round an obstacle, followed while the stick holds its direction
var _detour_i := 0
var _detour_dir := Vector2.ZERO
var _detour_t := 0.0

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
	_walk_best = INF
	_walk_stall = 0.0
	_replans = 0
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
	var stick := Vector3.ZERO
	if iv.length() > 0.1:
		walking_to = false
		if not _moving:   # CAMERA frame: a held direction keeps meaning the same way while the camera swings
			_move_yaw = rig.yaw
			_moving = true
		stick = input_to_world(iv) * _speed()
		want = _steer_stick(stick, delta)
	else:
		_moving = false
		_detour = PackedVector3Array()
		_blocked = 0.0
		if walking_to:
			want = _follow_path()
			_check_stall(delta)
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
	# Stick blocked: the figure is not getting its way (head-on into a table, wedged between two chairs)
	if stick.length() > 1.0 and _detour.is_empty():
		var way := Vector2(stick.x, stick.z).normalized()
		_blocked = _blocked + delta if moved.dot(way) < 0.35 * stick.length() else 0.0
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
		_path = _clean(_agent.get_current_navigation_path())
		_path_i = 0
		if _path.size() < 2:
			if _path.size() == 1 or _agent.is_navigation_finished():
				walking_to = false
			return Vector3.ZERO
	var r := _pursue(_path, _path_i)
	_path_i = r["i"]
	if r["left"] < ARRIVE_DONE:
		walking_to = false
		_path = PackedVector3Array()
		return Vector3.ZERO
	return r["dir"] * _speed() * clampf(r["left"] / ARRIVE_SLOW, 0.15, 1.0)

## Path without repeated points: the navmesh query can return a run of identical corners, and their zero-length
## segments filled the pursuit's search window, so the figure never saw the rest of the path (owner item 18).
static func _clean(path: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for q in path:
		if out.is_empty() or Vector2(q.x - out[-1].x, q.z - out[-1].z).length() > 0.01:
			out.append(q)
	return out

## Pure pursuit on `path` from segment `from_i`: {i: the nearest segment, dir: flat unit Vector3 toward the point
## PATH_LOOKAHEAD further along the path, left: metres left to the end (along the path + distance off it)}. The
## nearest segment is searched over the next 2 m of path (at least four segments).
func _pursue(path: PackedVector3Array, from_i: int) -> Dictionary:
	var pos := Vector2(global_position.x, global_position.z)
	var best_i := from_i
	var best_t := 0.0
	var best_d := INF
	var span := 0.0
	var i := from_i
	while i < path.size() - 1 and (i < from_i + 4 or span < 2.0):
		var a := _fl(path[i])
		var ab := _fl(path[i + 1]) - a
		var t := clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var d := pos.distance_to(a + ab * t)
		if d < best_d:
			best_d = d
			best_i = i
			best_t = t
		span += ab.length()
		i += 1
	var here := _fl(path[best_i]).lerp(_fl(path[best_i + 1]), best_t)
	var left := here.distance_to(_fl(path[best_i + 1]))
	for k in range(best_i + 1, path.size() - 1):
		left += _fl(path[k]).distance_to(_fl(path[k + 1]))
	var goal := _fl(path[path.size() - 1])
	var need := PATH_LOOKAHEAD
	var from := here
	for k in range(best_i + 1, path.size()):
		var seg := from.distance_to(_fl(path[k]))
		if seg >= need:
			goal = from.move_toward(_fl(path[k]), need)
			break
		need -= seg
		from = _fl(path[k])
	var dir := (goal - pos).normalized()
	return {"i": best_i, "dir": Vector3(dir.x, 0, dir.y), "left": left + best_d}

## A tap-walk that stops getting closer (a corner it cannot round) re-plans from where it is; within ARRIVE_NEAR of
## the end it counts as arrived; after STALL_REPLANS it gives up, so the player is never left "walking" on the spot.
func _check_stall(delta: float) -> void:
	if not walking_to or _path.size() < 2:
		return
	var left: float = _pursue(_path, _path_i)["left"]
	if left < _walk_best - 0.05:
		_walk_best = left
		_walk_stall = 0.0
		return
	_walk_stall += delta
	if _walk_stall < STALL_TIME:
		return
	_walk_stall = 0.0
	_walk_best = INF
	if left < ARRIVE_NEAR or _replans >= STALL_REPLANS:
		walking_to = false
		_path = PackedVector3Array()
		return
	_replans += 1
	_path = PackedVector3Array()   # _follow_path queries the same goal again from here

## Stick velocity, kept on the walkable area. The navmesh is the floor 0.4 m clear of every collider, so a stick-walk
## that stays on it never wedges the 0.35 m capsule between two stools or into a pocket by a table (most of the
## "stuck between tables" of owner item 18): a step that would leave it slides along its edge instead, which also
## rounds chair and table corners smoothly. Head-on into an edge (the slide has little left), or physically blocked
## for DETOUR_BLOCKED seconds, the figure takes the navmesh path to a point DETOUR_REACH ahead in the stick's
## direction and follows it while the stick keeps its direction (within DETOUR_TURN), for up to DETOUR_MAX. A wall
## with nothing walkable behind it gives no detour (the point ahead snaps back next to the figure) and a detour much
## longer than the straight line, or one through a door, is refused, so pushing into a wall still just stops. Off the
## navmesh (a seat, a spot a test put the player on) the stick is free, as before.
func _steer_stick(stick: Vector3, delta: float) -> Vector3:
	var way := Vector2(stick.x, stick.z).normalized()
	if not _detour.is_empty():
		_detour_t += delta
		var r := _pursue(_detour, _detour_i)
		_detour_i = r["i"]
		if _detour_t > DETOUR_MAX or r["left"] < 0.25 or rad_to_deg(absf(way.angle_to(_detour_dir))) > DETOUR_TURN:
			_detour = PackedVector3Array()
			_blocked = 0.0
		else:
			return r["dir"] * stick.length()
	var map := get_world_3d().navigation_map
	var pos := global_position
	var on := NavigationServer3D.map_get_closest_point(map, pos)
	if _fl(on).distance_to(_fl(pos)) > NAV_OFF or absf(on.y - pos.y) > 0.4:
		return stick
	var want := stick
	var next := pos + stick * NAV_LOOK
	# Stairs and ramps (the lounge stair's second flight has no navmesh: it ends at the rope): where the floor just
	# ahead is not level with the figure's feet the stick is free, as before. The ray starts 0.25 m up, inside any
	# stool or table collider (a ray from inside a box does not hit it), so furniture never counts as a step.
	var q := PhysicsRayQueryParameters3D.create(next + Vector3(0, 0.25, 0), next + Vector3(0, -0.3, 0))
	q.exclude = [get_rid()]
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not floor_hit.is_empty() and absf(floor_hit.position.y - pos.y) > 0.03:
		return stick
	var c := NavigationServer3D.map_get_closest_point(map, next)
	if _fl(c).distance_to(_fl(next)) > 0.02 or absf(c.y - next.y) > 0.4:
		# The step would leave the walkable area: slide along its edge
		var slide := (_fl(c) - _fl(pos)) / NAV_LOOK
		if absf(c.y - next.y) > 0.4:
			slide = Vector2.ZERO
		slide = slide.limit_length(stick.length())
		want = Vector3(slide.x, 0, slide.y)
		if slide.length() < 0.35 * stick.length():
			_blocked = DETOUR_BLOCKED   # head-on: look for a way round now
	if _blocked < DETOUR_BLOCKED:
		return want
	_blocked = 0.0
	for reach: float in DETOUR_REACH:
		var ahead := NavigationServer3D.map_get_closest_point(map, pos + Vector3(way.x, 0, way.y) * reach)
		if (_fl(ahead) - _fl(pos)).dot(way) < 0.5 or absf(ahead.y - pos.y) > 0.4:
			continue
		var path := _clean(NavigationServer3D.map_get_path(map, pos, ahead, true))
		# A path that never gets there (the point ahead is on an island of the navmesh) is no way round
		if path.size() < 2 or _fl(path[-1]).distance_to(_fl(ahead)) > 0.3:
			continue
		var length := 0.0
		for k in path.size() - 1:
			length += _fl(path[k]).distance_to(_fl(path[k + 1]))
		if length > _fl(pos).distance_to(_fl(ahead)) * 1.5 + 0.5 or _through_door(path):
			continue
		_detour = path
		_detour_i = 0
		_detour_dir = way
		_detour_t = 0.0
		return _pursue(_detour, 0)["dir"] * stick.length()
	return want

## True when `path` passes a swing door (group "swing_door", meta center): a detour never takes the player into
## another room by itself (the red door, while they push at the staff room's wall).
func _through_door(path: PackedVector3Array) -> bool:
	for d in get_tree().get_nodes_in_group("swing_door"):
		var c := _fl(d.get_meta("center", Vector3.INF))
		for k in path.size() - 1:
			var a := _fl(path[k])
			var ab := _fl(path[k + 1]) - a
			var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
			if c.distance_to(a + ab * t) < 0.8:
				return true
	return false

## Walk speed: Thirsty (a Drinks meter that ran Empty, 06-stakes §7.1) slows the venue walk by 25 %.
func _speed() -> float:
	var n := get_node_or_null("/root/Needs")
	return speed * (n.walk_mult() if n != null and n.has_method("walk_mult") else 1.0)


static func _fl(q: Vector3) -> Vector2:
	return Vector2(q.x, q.z)

## Yaw of the frame the stick and keys move in (see control_frame): screen-up walks toward -z turned by this yaw.
func control_yaw() -> float:
	match control_frame:
		ControlFrame.VENUE_NORTH:
			return 0.0
		ControlFrame.FIRST_CAMERA:
			if is_nan(_first_yaw):
				_first_yaw = rig.yaw
			return _first_yaw
		ControlFrame.MAIN_ROOM:
			return MAIN_ROOM_YAW
	return _move_yaw if _moving else rig.yaw

## World direction for a stick / key vector (x right, y down) in the control frame.
func input_to_world(v: Vector2) -> Vector3:
	return Basis(Vector3.UP, control_yaw()) * Vector3(v.x, 0, v.y)

## Stick vector that walks toward world direction `d` in the control frame (tests drive the joystick with it).
func world_to_input(d: Vector3) -> Vector2:
	var l := Basis(Vector3.UP, -control_yaw()) * Vector3(d.x, 0, d.z)
	return Vector2(l.x, l.z)

## The tipsiness variant of a base animation when the figure has it (box placeholders do not).
func _anim_name(base: String) -> String:
	var ap: AnimationPlayer = figure.get("_anim")
	if anim_suffix != "" and ap != null and ap.has_animation(base + anim_suffix):
		return base + anim_suffix
	return base
