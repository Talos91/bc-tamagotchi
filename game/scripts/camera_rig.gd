class_name CameraRig
extends Node3D
## Portrait diorama camera: a fixed-angle, elevated three-quarter view that follows the player. Zones are the Marker3D
## nodes in group "camera_zone" (venue CameraZones/*, written by tools/build_venue.gd) with metas rect / clamp (Rect2
## in x,z), yaw, pitch (degrees), dist, look_y, optional see_through (Array of Rect2 in x,z). A zone with meta
## fallback=true applies only where no other does; one with meta base=true (the lounge) gives way to any other area
## inside it (its corners: merch, memory, patrons), hysteresis or not. Every area has its own framing again (Daniele, Questions tab
## 2026-11-01: "back to a view per area"; the feel pass had made the main room one view).
## Lives in player.tscn as a top_level child, so it ignores the player's transform.
##
## Areas: `zone` is the area the player stands in (HUD title, band earshot), `view` the framing in use. Inside one room
## (ROOMS) a new area takes over after ZONE_DWELL seconds, so skirting an edge or cutting across a corner of an area
## never turns the view; at a door the view changes at once, as before. An area button calls focus_on(area): the view
## turns to that area's framing straight away (anywhere in the same room as the area; elsewhere at the threshold into
## it), follows the player there unclamped and settles on the area's framing when they arrive; release_focus() when
## the walk is over. The swing takes longer the more the view turns (swing_time + SWING_PER_HALF_TURN for 180°), so a
## half turn from stage to bar is one slow, even orbit.
##
## Follow: the look point is a critically damped spring (follow_time) on the player plus a lead of lead_time seconds
## of their velocity, so what is ahead of them is in view; clamped to the zone's clamp rect and raised with the
## player (stairs, raised strip). Yaw, pitch and distance ease to a new zone's framing on their own spring
## (swing_time). snap() jumps straight to the framing (teleports, scene start).
## Camera feel 2 (Daniele, Questions tab 2026-11-02: "trails behind when walking"): the follow is tight (follow_time
## 0.12 s, the lead builds in LEAD_SETTLE 0.25 s), so the character stays within ~0.5 m of the frame's focus at walking
## speed and is never left behind at the start of a walk. The look point is that tight follow of the player plus a
## framing offset (the zone's clamp and look height) on its own spring: CLAMP_SETTLE at a room's edge, the swing's
## time when the view changes, so a new area's framing eases in while the player stays tracked. The rig steps in _physics_process, in lockstep with the
## player's movement (the body moves only on physics ticks; a tight follow at the display rate would shake it on
## screen), and with a fixed delta, so the tests measure it deterministically. set_process(false) still turns it off
## (street_shot.gd, start_screen.gd): the switch is is_processing(). snap() frames the player at once (it does not wait
## for the next tick), and so does collecting the zones, so `zone` is set from the first frame.
##
## Walls (group "cutaway", meta cut_normal = the outward normal of the room whose camera looks through them):
##   entrance zones (lobby, corridor)  as before: a piece is hidden when its cut_normal faces the camera or it
##       crosses the sight line to the player (feet, chest, head), and only if its meta cut_rooms (if any) has the
##       zone: a room's walls stay solid until the character is through its door (Daniele 2026-11-02, corridor kept)
##   everywhere else (Daniele's playtest of 33dc5b9)  a piece is cut when it crosses the sight line to the player,
##       or when it is in view and wholly nearer to the camera than the player is, whatever room it belongs to; its
##       cut_normal still cuts it only inside the rooms of its cut_rooms (another room's walls facing the camera stay
##       up unless they are in front of the player). Box walls sink to a stub of STUB_H (10 % of the room height) in
##       CUT_TIME instead of vanishing, so the room still reads and the corners stay in view; wall-mounted kit
##       pieces and doors hide at once. A view's see_through rects cut every piece standing on them, the door in
##       it too (shut, it would stand alone in the sunk wall and hide the tables behind it): the smoking room's view
##       looks through the main room's south-east wall and red door, so the room is in sight from the approach.
##   Pieces with meta cut_sight_only (the buffer's open curtains) are cut only on the sight line, in every zone.
##   Swing doors (group "swing_door") are tested with their box as they stand now (open or shut), so an open leaf
##   between the camera and the player is hidden.
## Hanging props in group "occluder" (metas occluder_center, occluder_radius) between the camera and the look point
## are hidden. Render layer 2 (ceiling) is never drawn by this camera.
##
## Effects hook (drunk sway, shake, close-ins): set fx_offset / fx_tilt / fx_fov_scale every frame you want them;
## they are added on top of the follow after smoothing (never smoothed or clamped here) and do not move `yaw`, so
## stick directions stay put. Set them back to ZERO / ZERO / 1.0 to stop. A screen overlay or another Camera3D made
## current for a cut-scene does not need the rig at all; make this one current again afterwards and call snap().

const CEILING_LAYER_MASK := 1 << 1
const HYSTERESIS := 0.6         ## metres a zone keeps the player after they cross its edge
const ENTRANCE_ZONES := ["lobby", "corridor"]
const STUB_H := 0.4             ## metres of a cut wall that stay standing (10 % of the 4 m room)
const CUT_TIME := 0.18          ## seconds for a wall to sink to its stub, or rise back
const LEAD_MAX := 1.2           ## metres the look point may lead the player
const LEAD_SETTLE := 0.25       ## spring time of the lead (how quickly it builds up and dies away)
const CLAMP_SETTLE := 0.2       ## spring time of the framing offset inside one view (the camera stops at the clamp)
const ZONE_DWELL := 0.3         ## seconds a new area of the same room must hold the player before the view turns
const SWING_PER_HALF_TURN := 0.4    ## extra seconds of swing for a 180° turn (scaled by the turn)
const SETTLE_95 := 0.42             ## spring time (see _spring) that settles 95 % in 1 s: (1 + x) e^-x = 0.05 at x 4.74
## Camera zones that are one room (the view changes between them after ZONE_DWELL); every other zone is its own room.
## The smoking room counts as the main room's: its view takes over in front of the red door.
## The lounge's top corners (merch shop, memory corner) are the lounge's (lounge revamp 2026-11-02).
const ROOMS := {"floor": "main", "bar": "main", "stage": "main", "toilets": "main", "smoking": "main",
	"merch": "lounge", "memory": "lounge", "patrons": "lounge"}

@export var follow_time := 0.12     ## seconds for the look point to catch up with the player (spring)
@export var swing_time := 1.0       ## seconds for yaw, pitch and distance to settle (95 %) on a new area's framing
@export var lead_time := 0.25       ## seconds of the player's velocity the camera looks ahead
@export var portrait_hfov := 52.0
@export var landscape_vfov := 42.0
@export var landscape_dist_scale := 1.5   ## landscape shows less height (vfov 42): farther, so the raised strip stays in frame from mid-floor

## Effects hook, see the header. World metres; extra pitch, yaw, roll in radians; field-of-view multiplier.
var fx_offset := Vector3.ZERO
var fx_tilt := Vector3.ZERO
var fx_fov_scale := 1.0

var zone := ""                  ## the area the player is in, "" before the first frame
var view := ""                  ## the framing in use: `zone`, or the area of focus_on() while it holds
var focus := ""                 ## area an area button is walking the player to ("" = none); see focus_on()
var _cand := ""                 ## area the player has stepped into, waiting for ZONE_DWELL
var _cand_t := 0.0
var _swing := 1.0               ## settle time of the current turn
var yaw := 0.0                  ## current yaw in radians (player input is relative to it)
var _zones: Array[Node3D] = []
var _look := Vector3.ZERO      ## the look point: _follow + _frame
var _follow := Vector3.ZERO    ## tight follow of the player (feet height) plus the lead
var _follow_v := Vector3.ZERO
var _frame := Vector3.ZERO     ## framing offset: clamp correction and look height
var _frame_v := Vector3.ZERO
var _swing_age := 0.0          ## seconds since the view last changed
var _lead := Vector3.ZERO
var _lead_v := Vector3.ZERO
var _yaw_v := 0.0
var _pitch := -0.6
var _pitch_v := 0.0
var _dist := 9.0
var _dist_v := 0.0
var _snap := true
var _cutaway: Array[Node3D] = []
var _cut_boxes: Array[AABB] = []   ## world boxes of _cutaway, same order (the venue is static)
var _cut_amt: Array[float] = []    ## 0 = standing, 1 = cut (sunk to its stub / hidden)
var _stubs: Array = []             ## per piece: [stub MeshInstance3D, base y, height] for box walls, else null
var _occluders: Array[Node3D] = []

@onready var camera: Camera3D = $Camera3D
@onready var _target: Node3D = get_parent()

func _ready() -> void:
	top_level = true
	set_process(true)   # the on/off switch other scripts use (see the header); the work is in _physics_process
	camera.cull_mask &= ~CEILING_LAYER_MASK
	camera.near = 0.3
	camera.far = 80.0
	# Zones and cutaway walls belong to the venue, which may enter the tree after the player
	_collect.call_deferred()

func _collect() -> void:
	_zones.clear()
	for n in get_tree().get_nodes_in_group("camera_zone"):
		_zones.append(n)
	for st in _stubs:
		if st != null and is_instance_valid(st[0]):
			(st[0] as Node).queue_free()
	_cutaway.clear()
	_cut_boxes.clear()
	_cut_amt.clear()
	_stubs.clear()
	for n in get_tree().get_nodes_in_group("cutaway"):
		_cutaway.append(n)
		_cut_amt.append(0.0)
		_cut_boxes.append(_world_box(n))
		_stubs.append(_make_stub(n, _cut_boxes[-1]))
	_occluders.clear()
	for n in get_tree().get_nodes_in_group("occluder"):
		_occluders.append(n)
	snap()

## World box of a cutaway piece: its own mesh, or for a kit piece (a scene root) all the meshes under it.
static func _world_box(n: Node3D) -> AABB:
	if n is VisualInstance3D:
		return (n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()
	var box := AABB()
	var first := true
	for v in n.find_children("*", "VisualInstance3D", true, false):
		var b := (v as VisualInstance3D).global_transform * (v as VisualInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return AABB(n.global_position - Vector3(0.3, 0.3, 0.3), Vector3(0.6, 0.6, 0.6)) if first else box

## A full-height box wall gets a twin without collider that stands in for it while it is cut: drawn from its full
## height down to STUB_H, then left as the stub. Lintels, kit pieces and low boxes get none (they just hide).
func _make_stub(n: Node3D, box: AABB) -> Variant:
	var mi := n as MeshInstance3D
	if mi == null or not (mi.mesh is BoxMesh) or box.size.y < 1.0 or box.position.y > 0.6 or mi.get_parent() == null:
		return null
	var h: float = (mi.mesh as BoxMesh).size.y
	var stub := MeshInstance3D.new()
	stub.name = mi.name + "Stub"
	stub.mesh = mi.mesh
	stub.material_override = mi.material_override
	stub.layers = mi.layers
	stub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stub.transform = mi.transform
	stub.visible = false
	mi.get_parent().add_child(stub)
	return [stub, mi.position.y - h * 0.5, h]

## Jump straight to the framing for where the player is now (teleports, scene start), without waiting for a tick.
func snap() -> void:
	_snap = true
	_physics_process(0.0)

## Area button: turn to `area`'s framing now and follow the player to it (see the header).
func focus_on(area: String) -> void:
	focus = area if _marker(area) != null else ""

## The walk is over (arrived or cancelled): back to the area the player is in. Arriving in the focus area adopts it at
## once (no dwell), so the view does not turn away and back.
func release_focus() -> void:
	if focus != "" and is_instance_valid(_target) and area_at(_target.global_position) == focus:
		zone = focus
		_cand = ""
	focus = ""

func _marker(nm: String) -> Node3D:
	for z in _zones:
		if z.name.to_lower() == nm:
			return z
	return null

## The area whose rect holds a world point (no hysteresis), "" outside every area.
func area_at(p: Vector3) -> String:
	var flat := Vector2(p.x, p.z)
	var fallback := ""
	for z in _zones:
		if (z.get_meta("rect") as Rect2).has_point(flat):
			if not z.get_meta("fallback", false):
				return z.name.to_lower()
			fallback = z.name.to_lower()
	return fallback

static func room_of(area: String) -> String:
	return ROOMS.get(area, area)

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
			if not (z.get_meta("base", false) and _inner_at(flat, z) != null):
				return z
	var fallback: Node3D = null
	for z in _zones:
		if (z.get_meta("rect") as Rect2).has_point(flat):
			if not z.get_meta("fallback", false):
				return z
			fallback = z
	return fallback

## An area other than `base` whose rect holds the point, or null.
func _inner_at(flat: Vector2, base: Node3D) -> Node3D:
	for z in _zones:
		if z != base and not z.get_meta("fallback", false) and (z.get_meta("rect") as Rect2).has_point(flat):
			return z
	return null

## Critically damped spring step toward `to` (exact for any delta): returns [value, velocity]. Works on floats and
## vectors; `t` is roughly the time to settle.
static func _spring(x: Variant, v: Variant, to: Variant, t: float, delta: float) -> Array:
	var w := 2.0 / maxf(t, 0.001)
	var e := exp(-w * delta)
	var d: Variant = x - to
	var tmp: Variant = (v + d * w) * delta
	return [to + (d + tmp) * e, (v - tmp * w) * e]

func _physics_process(delta: float) -> void:
	if not is_processing() or _zones.is_empty() or not is_instance_valid(_target):
		return
	var portrait := get_viewport().get_visible_rect().size.aspect() < 1.0
	var base_fov := portrait_hfov if portrait else landscape_vfov
	camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	camera.fov = base_fov * fx_fov_scale
	var p := _target.global_position
	var z := _zone_for(p)
	if z == null:
		return
	# The area the player is in: at once across a door (another room) or while snapping, after ZONE_DWELL inside a room
	var nm := z.name.to_lower()
	if nm == zone or zone == "" or _snap or room_of(nm) != room_of(zone) or nm == focus:
		zone = nm
		_cand = ""
	elif nm != _cand:
		_cand = nm
		_cand_t = 0.0
	else:
		_cand_t += delta
		if _cand_t >= ZONE_DWELL:
			zone = nm
			_cand = ""
	# The framing: the focus area's anywhere in its room, else the area's
	var free := false
	z = _marker(zone)
	if focus != "" and room_of(focus) == room_of(zone):
		z = _marker(focus)
		free = focus != zone   # not there yet: follow the player, settle on the area's clamp once they arrive
	if z.name.to_lower() != view:
		var turn := 0.0 if view == "" else absf(angle_difference(yaw, deg_to_rad(z.get_meta("yaw"))))
		_swing = swing_time + SWING_PER_HALF_TURN * turn / PI
		_swing_age = 0.0
		view = z.name.to_lower()
	_swing_age += delta
	# Look ahead along the player's walk (zero while seated or standing)
	var vel := Vector3.ZERO
	if _target is CharacterBody3D:
		vel = (_target as CharacterBody3D).get_real_velocity()
	var want_lead := Vector3(vel.x, 0, vel.z) * lead_time
	want_lead = want_lead.limit_length(LEAD_MAX)
	var c: Rect2 = Rect2(-1e4, -1e4, 2e4, 2e4) if free else z.get_meta("clamp")
	var want_yaw := deg_to_rad(z.get_meta("yaw"))
	var want_pitch := deg_to_rad(z.get_meta("pitch"))
	var want_dist: float = z.get_meta("dist") * (1.0 if portrait else landscape_dist_scale)
	var jump := _snap
	if _snap:
		_lead = Vector3.ZERO
		_lead_v = Vector3.ZERO
		_follow = Vector3(p.x, maxf(p.y, 0.0), p.z)
		_follow_v = Vector3.ZERO
		_frame = _want_look(p, c, z) - _follow
		_frame_v = Vector3.ZERO
		yaw = want_yaw
		_yaw_v = 0.0
		_pitch = want_pitch
		_pitch_v = 0.0
		_dist = want_dist
		_dist_v = 0.0
		_snap = false
	else:
		var r := _spring(_lead, _lead_v, want_lead, LEAD_SETTLE, delta)
		_lead = r[0]
		_lead_v = r[1]
		var at_player := Vector3(p.x + _lead.x, maxf(p.y, 0.0), p.z + _lead.z)
		r = _spring(_follow, _follow_v, at_player, follow_time, delta)
		_follow = r[0]
		_follow_v = r[1]
		var frame_t := lerpf(_swing * SETTLE_95, CLAMP_SETTLE, smoothstep(0.0, 1.0, _swing_age / _swing))
		r = _spring(_frame, _frame_v, _want_look(at_player, c, z) - at_player, frame_t, delta)
		_frame = r[0]
		_frame_v = r[1]
		r = _spring(yaw, _yaw_v, yaw + angle_difference(yaw, want_yaw), _swing * SETTLE_95, delta)
		yaw = wrapf(r[0], -PI, PI)
		_yaw_v = r[1]
		r = _spring(_pitch, _pitch_v, want_pitch, _swing * SETTLE_95, delta)
		_pitch = r[0]
		_pitch_v = r[1]
		r = _spring(_dist, _dist_v, want_dist, _swing * SETTLE_95, delta)
		_dist = r[0]
		_dist_v = r[1]
	_look = _follow + _frame
	var b := Basis.from_euler(Vector3(_pitch, yaw, 0))
	var at := _look + b.z * _dist
	global_transform = Transform3D(b * Basis.from_euler(fx_tilt), at + fx_offset)
	var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
	_update_cutaway(fwd, global_position, p, z.get_meta("see_through", []), 1e6 if jump else delta)
	_update_occluders(global_position, _look)

## Look point for the player at `p`: clamped to the zone's clamp rect, at the zone's look height above the player's
## feet (they climb stairs and step onto the raised strip).
func _want_look(p: Vector3, c: Rect2, z: Node3D) -> Vector3:
	return Vector3(clampf(p.x, c.position.x, c.end.x), float(z.get_meta("look_y")) + maxf(_target.global_position.y, 0.0), clampf(p.z, c.position.y, c.end.y))

func _update_cutaway(fwd: Vector3, cam: Vector3, player: Vector3, see_through: Array, delta: float) -> void:
	var entrance := zone in ENTRANCE_ZONES
	var back := -fwd
	var ends := [player + Vector3(0, 0.3, 0), player + Vector3(0, 1.1, 0), player + Vector3(0, 1.8, 0)]
	var player_depth := (player - cam).dot(fwd)
	var planes := camera.get_frustum()
	for i in _cutaway.size():
		var w := _cutaway[i]
		if not is_instance_valid(w):
			continue
		var rooms: Variant = w.get_meta("cut_rooms") if w.has_meta("cut_rooms") else null
		var own := rooms == null or (rooms as Array).has(zone)
		var door := w.is_in_group("swing_door")
		if door:
			_cut_boxes[i] = _world_box(w)   # as it stands now, open or shut
		var box := _cut_boxes[i].grow(0.05)
		var on_line := false
		for e in ends:
			if box.intersects_segment(cam, e):
				on_line = true
				break
		var faces := (w.get_meta("cut_normal") as Vector3).dot(back) >= 0.35
		var cut := false
		if w.get_meta("cut_sight_only", false):   # open curtains: only when they hide the player
			cut = on_line
		elif entrance:
			cut = own and (faces or on_line)
		elif on_line or _on_rects(box, see_through) or (own and faces):
			cut = true
		else:
			cut = _max_depth(box, cam, fwd) < player_depth - 0.3 and _in_view(box, planes)
		_set_cut(i, cut, entrance, delta)

## True when the box stands on one of the rects (x, z).
static func _on_rects(box: AABB, rects: Array) -> bool:
	for r: Rect2 in rects:
		if r.intersects(Rect2(box.position.x, box.position.z, box.size.x, box.size.z)):
			return true
	return false

## Sinks a piece to its stub (or hides it) as `cut` says. In the entrance zones pieces just hide, as before.
func _set_cut(i: int, cut: bool, entrance: bool, delta: float) -> void:
	var w := _cutaway[i]
	var amt := 1.0 if cut else 0.0
	if not entrance and _stubs[i] != null:   # box walls sink; kit pieces and doors (no stub) hide at once
		amt = move_toward(_cut_amt[i], amt, delta / CUT_TIME)
	_cut_amt[i] = amt
	var st: Variant = _stubs[i]
	if st == null or entrance:
		w.visible = amt < 0.5
		if st != null:
			(st[0] as Node3D).visible = false
		return
	var stub: MeshInstance3D = st[0]
	w.visible = amt <= 0.0
	stub.visible = amt > 0.0
	if stub.visible:
		var h: float = st[2]
		var s := lerpf(1.0, minf(STUB_H / h, 1.0), smoothstep(0.0, 1.0, amt))
		stub.scale.y = s
		stub.position.y = float(st[1]) + h * s * 0.5

## Farthest distance of the box along the camera's horizontal forward.
static func _max_depth(box: AABB, cam: Vector3, fwd: Vector3) -> float:
	var m := -INF
	for k in 8:
		m = maxf(m, (box.get_endpoint(k) - cam).dot(fwd))
	return m

## False when the whole box is outside one frustum plane (the planes' normals point out of the frustum).
static func _in_view(box: AABB, planes: Array[Plane]) -> bool:
	for pl in planes:
		var outside := true
		for k in 8:
			if not pl.is_point_over(box.get_endpoint(k)):
				outside = false
				break
		if outside:
			return false
	return true

func _update_occluders(from: Vector3, to: Vector3) -> void:
	for o in _occluders:
		if is_instance_valid(o):
			var c: Vector3 = o.global_position + (o.get_meta("occluder_center") as Vector3)
			var on_line := Geometry3D.get_closest_point_to_segment(c, from, to)
			o.visible = c.distance_to(on_line) > (o.get_meta("occluder_radius") as float) + 0.4
