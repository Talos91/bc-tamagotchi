extends RefCounted
## Overflow seating (Daniele 2026-11-20: "we will be more than 4 people at a table so we need to factor how that look
## i suggest factoring optional seating appearing only when you pass the 4 people"). When more real check-ins share a
## table than it has seats, extra chairs (tall stools at tall tables, drum stools at the tiny ones, bar stools at the
## Bar and the high counter) appear around it at runtime, and the extra people sit on them; past the cap they stand
## next to it. Nothing here touches layout.json or venue.tscn: the slots are computed from the scene once per table
## and a chair exists only while someone sits on it (venue_patrons.gd frees it when they leave).
##
## Slots per table, best first (greedy: each next slot is the one farthest from every chair already there):
##   ring   tables with chairs on several sides: on the table's footprint grown by the base chairs' distance to it,
##          so the extra chairs sit at the same reach (round tables get them on the diagonals, long tables at the ends)
##   line   the Bar, the high counter and the tiny tables (all chairs face one way): further along the same row
##   stand  past the seat cap, a second, wider ring (or the strip behind the row) where they stand with a drink
## Every slot clears: the colliders of the room (walls, furniture, other chairs) by the chair's footprint, every seat
## spot by SEAT_GAP, every other table's tap zone (seats' reach + venue_zones.gd SEAT_MARGIN), the walking spots
## (door, lanes, wander points) and stays on the navmesh floor (within NAV_REACH of a walkable polygon).

const SEAT_CAP := 8              ## seats per table, its own chairs included (the 2-stool tall tables reach 6 at most: room)
const BAR_CAP := 18              ## the Bar takes more along the counter (9 stools + 9 between and past them)
const STAND_CAP := 4             ## standing spots per table past the cap (Bar: 6); past those, the zone as before
const BAR_STAND_CAP := 6
const SEAT_GAP := 0.55           ## metres between two chair centres (cafe chair 0.45 wide; stools STOOL_GAP)
const STOOL_GAP := 0.5
const BAR_GAP := 0.45            ## bar stools squeeze closer along the counter (people do at a busy bar)
const RING_OUT := 0.12           ## round tables: extra chairs this much further out than its own (clear of their backs)
const STAND_GAP := 0.6
const FOOT := 0.2                ## chair footprint radius against colliders
const STAND_OUT := 0.55          ## standing ring: this much further out than the chairs
const LINE_BACK := 0.75          ## Bar standing strip: this far behind the stools
const LINE_REACH := 0.7          ## a row grows at most this far past its end chairs (the counter's own length)
const SEAT_MARGIN := 0.35        ## venue_zones.gd SEAT_MARGIN: another table's tap zone is its seats' reach + this
const ZONE_CLEAR := 0.1          ## plus this, so a chair never lands on the edge of a neighbour's zone
const LANE_CLEAR := 0.6          ## from wander / door / spawn / stand spots
const NAV_REACH := 0.6           ## chairs sit on furniture-cut navmesh; within this of a walkable polygon
const STAND_H := PatronFigure.SEAT_H * PatronFigure.FIG_SCALE   ## a standing slot's seat_h: venue_patrons lifts by seat_h - this

const PROPS := {
	"chair": "res://assets/kit/tables/cafe_chair.glb",
	"tall": "res://assets/kit/buffer/tall_stool.glb",
	"drum": "res://assets/kit/tables/drum_stool.glb",
	"bar": "res://assets/kit/bar/bar_stool.glb",
}

var venue: Node3D                ## the venue scene root (tables, colliders, navmesh)
var holder: Node3D               ## where slot markers live (venue_patrons' frame, a sibling of Spots)
var spots: Node                  ## venue_patrons' $Spots
var _built := false
var _seats_by_table := {}        ## table -> Array[Node3D] base seat spots
var _all_spots: Array[Vector3] = []   ## every sit spot (global)
var _lanes: Array[Vector3] = []  ## wander / spawn / stand spots (global)
var _boxes: Array = []           ## [Transform3D inverse, half extents, owner table name or ""]
var _zones := {}                 ## table -> [Vector2 centre, radius]
var _nav: Array = []             ## [PackedVector2Array poly, y]
var _slots := {}                 ## table -> {"seats": Array[Dictionary], "stand": Array[Dictionary]}; dict {pos, yaw, kind}
var used := {}                   ## Marker3D -> true (live slots)


func _init(venue_root: Node3D, holder_node: Node3D, spots_node: Node) -> void:
	venue = venue_root
	holder = holder_node
	spots = spots_node


## A free overflow slot at `table` as a seat marker (the chair spawned under it), or null when the table is not known,
## has no room left, or is at its cap. Seats first, then standing spots.
func claim(table: String) -> Node3D:
	var sl := slots(table)
	if sl.is_empty():
		return null
	for kind in ["seats", "stand"]:
		var list: Array = sl[kind]
		for i in list.size():
			if _marker_of(table, kind, i) == null:
				return _make(table, kind, i, list[i])
	return null


## The person on `m` left: the marker and its chair go (a short shrink so it does not blink out).
func release(m: Node3D) -> void:
	used.erase(m)
	if not is_instance_valid(m):
		return
	m.set_meta("released", true)
	if m.is_inside_tree():
		var tw := m.create_tween()
		tw.tween_property(m, "scale", Vector3(0.01, 0.01, 0.01), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(m.queue_free)
	else:
		m.free()


## How good a seat is at its table: its own chairs 0, overflow chairs 1.., standing 100.. (promotion order).
static func rank(seat: Node3D) -> int:
	if seat == null or not seat.has_meta("overflow"):
		return 0
	return int(seat.get_meta("rank", 1))


## Live overflow markers at `table` (tests, captures).
func live(table: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for m in used:
		if is_instance_valid(m) and str(m.get_meta("table", "")) == table:
			out.append(m)
	return out


## The table's overflow slots, computed once: {"seats": [...], "stand": [...]}, each {pos (global), yaw, kind}.
func slots(table: String) -> Dictionary:
	if table == "":
		return {}
	_build()
	if not _seats_by_table.has(table):
		return {}
	if not _slots.has(table):
		_slots[table] = _compute(table)
	return _slots[table]


# --- Slots -----------------------------------------------------------------------------------------

func _compute(table: String) -> Dictionary:
	var base: Array = _seats_by_table[table]
	var kind := _prop_kind(table, base[0])
	var bar := table == "Bar"
	var cap := (BAR_CAP if bar else SEAT_CAP) - base.size()
	var stand_cap := BAR_STAND_CAP if bar else STAND_CAP
	var gap := SEAT_GAP if kind == "chair" else (BAR_GAP if kind == "bar" else STOOL_GAP)
	var y: float = base[0].global_position.y
	var line := _is_line(base)
	var seat_c: Array[Dictionary] = []
	var stand_c: Array[Dictionary] = []
	if line:
		var fwd := Vector3(sin(base[0].global_rotation.y), 0, cos(base[0].global_rotation.y))   # yaw 0 faces +z
		var side := Vector3(fwd.z, 0, -fwd.x)
		var lo := INF
		var hi := -INF
		var o: Vector3 = base[0].global_position
		for s: Node3D in base:
			var t := (s.global_position - o).dot(side)
			lo = minf(lo, t)
			hi = maxf(hi, t)
		var t := lo - LINE_REACH
		while t <= hi + LINE_REACH:
			var yaw: float = base[0].global_rotation.y
			seat_c.append({"pos": o + side * t, "yaw": yaw})
			stand_c.append({"pos": o + side * t - fwd * LINE_BACK, "yaw": yaw})
			t += 0.05
	else:
		var box := _table_box(table, base)
		var h: Vector2 = box[1]
		var long := maxf(h.x, h.y) > 1.3 * minf(h.x, h.y) + 0.05
		var c := _table_centre(table, base)
		var d := 0.0
		for s: Node3D in base:
			d += _box_dist(box, s.global_position) if long else _flat(s.global_position - c)
		d /= base.size()
		for i in 72:
			var a := TAU * i / 72.0
			if long:   # long tables: on the footprint grown by the chairs' reach (extra chairs at the ends)
				seat_c.append(_ring_point(box, d, a, y))
				stand_c.append(_ring_point(box, d + STAND_OUT, a, y))
			else:      # round and square tables: a circle a little wider than its own chairs
				for r in [d + RING_OUT, d + RING_OUT + STAND_OUT]:
					var p := Vector3(c.x + sin(a) * r, y, c.z + cos(a) * r)
					(seat_c if r == d + RING_OUT else stand_c).append({"pos": p, "yaw": atan2(c.x - p.x, c.z - p.z)})
	var taken: Array[Vector3] = []
	for s: Node3D in base:
		taken.append(s.global_position)
	var seats := _greedy(table, seat_c, taken, cap, gap, kind)
	for s in seats:
		taken.append(s.pos)
	var stand := _greedy(table, stand_c, taken, stand_cap, STAND_GAP, "stand")
	return {"seats": seats, "stand": stand}


## Best-first pick: the candidate farthest from every chair already there, among those that clear everything.
func _greedy(table: String, cand: Array[Dictionary], taken: Array[Vector3], n: int, gap: float, kind: String) -> Array[Dictionary]:
	var ok: Array[Dictionary] = []
	for c in cand:
		if _clear(table, c.pos, gap, kind == "stand"):
			ok.append(c)
	var out: Array[Dictionary] = []
	var have := taken.duplicate()
	while out.size() < n:
		var best: Dictionary = {}
		var best_d := -1.0
		for c in ok:
			var md := INF
			for h in have:
				md = minf(md, _flat(c.pos - h))
			if md >= gap and md > best_d + 0.001:
				best_d = md
				best = c
		if best.is_empty():
			break
		out.append({"pos": best.pos, "yaw": best.yaw, "kind": kind})
		have.append(best.pos)
	return out


func _clear(table: String, p: Vector3, gap: float, standing: bool) -> bool:
	for s in _all_spots:
		if _flat(p - s) < gap:
			return false
	for l in _lanes:
		if _flat(p - l) < LANE_CLEAR:
			return false
	for t in _zones:
		if t == table:
			continue
		var z: Array = _zones[t]
		if Vector2(p.x, p.z).distance_to(z[0]) < float(z[1]) + ZONE_CLEAR:
			return false
	var foot := FOOT + (0.05 if standing else 0.0)
	for b in _boxes:
		if b[2] == table and not standing:
			continue   # its own table: the ring already keeps the chairs' reach from it
		var q: Vector3 = (b[0] as Transform3D) * (p + Vector3(0, 0.5, 0))
		var h: Vector3 = b[1]
		if absf(q.y) < h.y + 0.45 and absf(q.x) < h.x + foot and absf(q.z) < h.z + foot:
			return false
	return _on_nav(p)


# --- Scene reading (once) ---------------------------------------------------------------------------

func _build() -> void:
	if _built:
		return
	_built = true
	for s in spots.get_children():
		if not s is Node3D:
			continue
		var pose := str(s.get_meta("pose", ""))
		if pose == "sit":
			var t := str(s.get_meta("table", ""))
			_all_spots.append(s.global_position)
			if t != "":
				if not _seats_by_table.has(t):
					_seats_by_table[t] = []
				_seats_by_table[t].append(s)
		elif pose in ["wander", "spawn", "stand", "hatch"]:
			_lanes.append(s.global_position)
	for t in _seats_by_table:
		if t == "Bar":
			continue   # venue_zones.gd makes no circle for the Bar
		var base: Array = _seats_by_table[t]
		var c := _table_centre(t, base)
		var reach := 0.0
		for s: Node3D in base:
			reach = maxf(reach, Vector2(s.global_position.x - c.x, s.global_position.z - c.z).length())
		_zones[t] = [Vector2(c.x, c.z), reach + SEAT_MARGIN]
	for cs in venue.find_children("*", "CollisionShape3D", true, false):
		var sh := (cs as CollisionShape3D).shape
		if not sh is BoxShape3D:
			continue
		var gt: Transform3D = (cs as Node3D).global_transform
		var sc := gt.basis.get_scale()
		var half: Vector3 = (sh as BoxShape3D).size * 0.5 * sc
		var owner_t := ""
		var n: Node = cs.get_parent()
		while n != null and n != venue:
			if _seats_by_table.has(String(n.name)) and n.get_parent() != venue:   # not a zone group ("Bar")
				owner_t = String(n.name)
				break
			n = n.get_parent()
		_boxes.append([Transform3D(gt.basis.orthonormalized(), gt.origin).affine_inverse(), half, owner_t])
	var regions := venue.find_children("*", "NavigationRegion3D", true, false)
	if not regions.is_empty():
		var reg := regions[0] as NavigationRegion3D
		var nm := reg.navigation_mesh
		if nm != null:
			var v := nm.get_vertices()
			var gt := reg.global_transform
			for i in nm.get_polygon_count():
				var idx := nm.get_polygon(i)
				var poly := PackedVector2Array()
				var yy := 0.0
				for k in idx:
					var w: Vector3 = gt * v[k]
					poly.append(Vector2(w.x, w.z))
					yy += w.y
				_nav.append([poly, yy / idx.size(), _rect_of(poly).grow(NAV_REACH)])


func _table_node(table: String) -> Node3D:
	var n := venue.find_child(table, true, false)
	return n as Node3D


func _table_centre(table: String, base: Array) -> Vector3:
	var n := _table_node(table)
	if n != null and not n is Marker3D:
		return n.global_position
	var c := Vector3.ZERO
	for s: Node3D in base:
		c += s.global_position
	return c / base.size()


## The table's footprint: [Transform3D table frame (no scale), half extents (x, z)]; a point when it has no collider.
func _table_box(table: String, base: Array) -> Array:
	var n := _table_node(table)
	if n != null:
		for cs in n.find_children("*", "CollisionShape3D", true, false):
			var sh := (cs as CollisionShape3D).shape
			if sh is BoxShape3D:
				var gt: Transform3D = (cs as Node3D).global_transform
				var half: Vector3 = (sh as BoxShape3D).size * 0.5 * gt.basis.get_scale()
				var flat := Transform3D(gt.basis.orthonormalized(), Vector3(gt.origin.x, base[0].global_position.y, gt.origin.z))
				return [flat, Vector2(half.x, half.z)]
	return [Transform3D(Basis(), _table_centre(table, base)), Vector2.ZERO]


func _box_dist(box: Array, p: Vector3) -> float:
	var q: Vector3 = (box[0] as Transform3D).affine_inverse() * p
	var h: Vector2 = box[1]
	return Vector2(maxf(absf(q.x) - h.x, 0.0), maxf(absf(q.z) - h.y, 0.0)).length()


## The point at distance `d` from the table's footprint along angle `a` (table frame), facing the table.
func _ring_point(box: Array, d: float, a: float, y: float) -> Dictionary:
	var tf: Transform3D = box[0]
	var dir := Vector3(sin(a), 0, cos(a))
	var r := 0.0
	var p := tf * (dir * r)
	while r < 4.0:
		p = tf * (dir * r)
		if _box_dist(box, p) >= d:
			break
		r += 0.01
	p.y = y
	var to := tf.origin - p
	return {"pos": p, "yaw": atan2(to.x, to.z)}


func _is_line(base: Array) -> bool:
	if base.size() < 2:
		return false
	var y0: float = base[0].global_rotation.y
	for s: Node3D in base:
		if absf(angle_difference(s.global_rotation.y, y0)) > deg_to_rad(5.0):
			return false
	return true


func _prop_kind(table: String, s: Node3D) -> String:
	if table == "Bar" or table == "HighCounter" or float(s.get_meta("seat_h", 0.45)) >= 0.79:
		return "bar"
	if table.contains("Tall"):
		return "tall"
	if table.begins_with("Tiny") or String(s.name).contains("DrumStool"):
		return "drum"
	return "chair"


func _on_nav(p: Vector3) -> bool:
	if _nav.is_empty():
		return true
	var q := Vector2(p.x, p.z)
	for e in _nav:
		if absf(float(e[1]) - p.y) > 0.4 or not (e[2] as Rect2).has_point(q):
			continue
		var poly: PackedVector2Array = e[0]
		if Geometry2D.is_point_in_polygon(q, poly):
			return true
		for i in poly.size():
			var c := Geometry2D.get_closest_point_to_segment(q, poly[i], poly[(i + 1) % poly.size()])
			if c.distance_to(q) <= NAV_REACH:
				return true
	return false


static func _rect_of(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for v in poly:
		r = r.expand(v)
	return r


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


# --- Markers ----------------------------------------------------------------------------------------

func _marker_of(table: String, kind: String, i: int) -> Node3D:
	for m in used:
		if is_instance_valid(m) and not m.get_meta("released", false) and str(m.get_meta("table", "")) == table \
				and str(m.get_meta("slot_kind", "")) == kind and int(m.get_meta("slot", -1)) == i:
			return m
	return null


func _make(table: String, kind: String, i: int, slot: Dictionary) -> Node3D:
	var base: Node3D = _seats_by_table[table][0]
	var standing := kind == "stand"
	var m := Marker3D.new()
	m.name = "Overflow_%s_%s%d" % [table, "Stand" if standing else "Seat", i]
	holder.add_child(m)
	m.global_position = slot.pos
	m.global_rotation = Vector3(0, slot.yaw, 0)
	m.set_meta("overflow", true)
	m.set_meta("table", table)
	m.set_meta("zone", base.get_meta("zone", ""))
	m.set_meta("pose", "stand" if standing else "sit")
	m.set_meta("stand", standing)
	m.set_meta("slot_kind", kind)
	m.set_meta("slot", i)
	m.set_meta("rank", (100 if standing else 1) + i)
	m.set_meta("seat_h", STAND_H if standing else float(base.get_meta("seat_h", 0.45)))
	if not standing:
		var ps: PackedScene = load(PROPS[slot.kind])
		if ps != null:
			var chair: Node3D = ps.instantiate()
			chair.name = "Chair"
			m.add_child(chair)
			chair.scale = Vector3(0.01, 0.01, 0.01)
			var tw := chair.create_tween()
			tw.tween_property(chair, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	used[m] = true
	return m
