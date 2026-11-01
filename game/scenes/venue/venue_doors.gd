extends Node
## Swing doors of the generated venue (tools/build_venue.gd `_swing_door`): hinge pivots in group "swing_door" with
## metas center (Vector3, the middle of the opening) and users (the group whose members open it: "door_user" for
## the player and the crowd, "staff_door_user" for staff at the staff-only doors). A leaf swings open, away from
## whoever comes within REACH of the opening, and closes HOLD seconds after the last of them has gone.

const REACH := 1.2
const OPEN_DEG := 95.0
const OPEN_TIME := 0.25      ## seconds to swing fully open (the player walks 1.2 m in about 0.33 s)
const CLOSE_TIME := 0.8
const HOLD := 0.6

## {node, base, center, normal, users, open (0..1), side (+1 / -1), hold}
var doors: Array[Dictionary] = []


func _ready() -> void:
	var venue := get_parent()
	for d in get_tree().get_nodes_in_group("swing_door"):
		if venue.is_ancestor_of(d):
			var n: Node3D = d
			doors.append({"node": n, "base": n.rotation.y, "center": venue.to_global(n.get_meta("center")),
				"normal": n.global_basis.z, "users": str(n.get_meta("users")), "open": 0.0, "side": 1.0, "hold": 0.0})


func _process(delta: float) -> void:
	for d in doors:
		var near := _nearest_user(d)
		if near != null:
			if d.open < 0.02:   # swing away from whoever opens it
				d.side = -1.0 if (near.global_position - d.center).dot(d.normal) > 0.0 else 1.0
			d.hold = HOLD
		else:
			d.hold -= delta
		var want := 1.0 if d.hold > 0.0 else 0.0
		d.open = move_toward(d.open, want, delta / (OPEN_TIME if want > d.open else CLOSE_TIME))
		var e: float = 1.0 - pow(1.0 - d.open, 2.0)   # ease out
		(d.node as Node3D).rotation.y = d.base + d.side * deg_to_rad(OPEN_DEG) * e


func _nearest_user(d: Dictionary) -> Node3D:
	var best: Node3D = null
	var best_d := REACH
	for u in get_tree().get_nodes_in_group(d.users):
		var p: Vector3 = (u as Node3D).global_position
		if absf(p.y - d.center.y) > 2.0:
			continue
		var dist := Vector2(p.x - d.center.x, p.z - d.center.z).length()
		if dist < best_d:
			best_d = dist
			best = u
	return best


## 0 closed .. 1 fully open, by door node name (tests and captures).
func openness(door_name: String) -> float:
	for d in doors:
		if (d.node as Node).name == door_name:
			return d.open
	return -1.0


## Captures: hold a door at `t` (0..1) swung toward the side of `toward` (stop _process first).
func pose(door_name: String, t: float, toward: Vector3) -> void:
	for d in doors:
		if (d.node as Node).name == door_name:
			d.open = t
			d.side = 1.0 if (toward - d.center).dot(d.normal) > 0.0 else -1.0
			(d.node as Node3D).rotation.y = d.base + d.side * deg_to_rad(OPEN_DEG) * (1.0 - pow(1.0 - t, 2.0))

