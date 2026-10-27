class_name CameraRig
extends Node3D
## Portrait diorama camera: a fixed-angle, elevated three-quarter view that follows the player and frames one
## zone at a time. Zones are the Marker3D nodes in group "camera_zone" (venue CameraZones/*, written by
## tools/build_venue.gd) with metas rect / clamp (Rect2 in x,z), yaw, pitch (degrees), dist, look_y. Switching
## zone eases position, yaw, pitch and distance. A zone with meta fallback=true applies only where no other does. Walls in group "cutaway" whose meta cut_normal faces the camera
## are hidden, as are hanging props in group "occluder" (metas occluder_center, occluder_radius) that sit
## between the camera and the look target; render layer 2 (ceiling) is never drawn by this camera.
## Lives in player.tscn as a top_level child, so it ignores the player's transform.

const CEILING_LAYER_MASK := 1 << 1
const HYSTERESIS := 0.3        ## metres a zone keeps the player after they cross its edge

@export var smoothing := 3.5   ## higher = snappier
@export var portrait_hfov := 52.0
@export var landscape_vfov := 42.0
@export var landscape_dist_scale := 1.3

var zone := ""                  ## current zone name, "" before the first frame
var yaw := 0.0                  ## current yaw in radians (player input is relative to it)
var _zones: Array[Node3D] = []
var _look := Vector3.ZERO
var _pitch := -0.6
var _dist := 9.0
var _snap := true
var _cutaway: Array[Node3D] = []
var _occluders: Array[Node3D] = []

@onready var camera: Camera3D = $Camera3D
@onready var _target: Node3D = get_parent()

func _ready() -> void:
	top_level = true
	camera.cull_mask &= ~CEILING_LAYER_MASK
	camera.near = 0.3
	camera.far = 80.0
	# Zones and cutaway walls belong to the venue, which may enter the tree after the player
	_collect.call_deferred()

func _collect() -> void:
	_zones.clear()
	for n in get_tree().get_nodes_in_group("camera_zone"):
		_zones.append(n)
	_cutaway.clear()
	for n in get_tree().get_nodes_in_group("cutaway"):
		_cutaway.append(n)
	_occluders.clear()
	for n in get_tree().get_nodes_in_group("occluder"):
		_occluders.append(n)

func snap() -> void:
	_snap = true

## World direction for a stick/WASD vector (x right, y down) relative to the current view.
func input_to_world(v: Vector2) -> Vector3:
	return Basis(Vector3.UP, yaw) * Vector3(v.x, 0, v.y)

func world_to_input(d: Vector3) -> Vector2:
	var l := Basis(Vector3.UP, -yaw) * Vector3(d.x, 0, d.z)
	return Vector2(l.x, l.z)

func _zone_for(p: Vector3) -> Node3D:
	var flat := Vector2(p.x, p.z)
	for z in _zones:
		if z.name.to_lower() == zone and not z.get_meta("fallback", false) and (z.get_meta("rect") as Rect2).grow(HYSTERESIS).has_point(flat):
			return z
	var fallback: Node3D = null
	for z in _zones:
		if (z.get_meta("rect") as Rect2).has_point(flat):
			if not z.get_meta("fallback", false):
				return z
			fallback = z
	return fallback

func _process(delta: float) -> void:
	if _zones.is_empty() or not is_instance_valid(_target):
		return
	var portrait := get_viewport().get_visible_rect().size.aspect() < 1.0
	if portrait:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = portrait_hfov
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = landscape_vfov
	var p := _target.global_position
	var z := _zone_for(p)
	if z == null:
		return
	zone = z.name.to_lower()
	var c: Rect2 = z.get_meta("clamp")
	var want_look := Vector3(clampf(p.x, c.position.x, c.end.x), z.get_meta("look_y"), clampf(p.z, c.position.y, c.end.y))
	var want_yaw := deg_to_rad(z.get_meta("yaw"))
	var want_pitch := deg_to_rad(z.get_meta("pitch"))
	var want_dist: float = z.get_meta("dist") * (1.0 if portrait else landscape_dist_scale)
	if _snap:
		_look = want_look
		yaw = want_yaw
		_pitch = want_pitch
		_dist = want_dist
		_snap = false
	else:
		var k := 1.0 - exp(-smoothing * delta)
		_look = _look.lerp(want_look, k)
		yaw = lerp_angle(yaw, want_yaw, k)
		_pitch = lerpf(_pitch, want_pitch, k)
		_dist = lerpf(_dist, want_dist, k)
	var b := Basis.from_euler(Vector3(_pitch, yaw, 0))
	global_transform = Transform3D(b, _look + b.z * _dist)
	_update_cutaway(Vector3(b.z.x, 0, b.z.z).normalized())
	_update_occluders(global_position, _look)

func _update_cutaway(back: Vector3) -> void:
	for w in _cutaway:
		if is_instance_valid(w):
			w.visible = (w.get_meta("cut_normal") as Vector3).dot(back) < 0.35

func _update_occluders(from: Vector3, to: Vector3) -> void:
	for o in _occluders:
		if is_instance_valid(o):
			var c: Vector3 = o.global_position + (o.get_meta("occluder_center") as Vector3)
			var on_line := Geometry3D.get_closest_point_to_segment(c, from, to)
			o.visible = c.distance_to(on_line) > (o.get_meta("occluder_radius") as float) + 0.4
