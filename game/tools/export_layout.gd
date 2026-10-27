extends SceneTree
## Writes res://assets/kit/layout.json from the generated venue: every kit instance and every person spawn point,
## for the combined Blender review file. Run from game/ after tools/build_venue.gd:
##   godot --headless --path . --script res://tools/export_layout.gd
## Kit entries: {"object", "zone", "name", "position": [x, y, z], "rotation_y": degrees, "scale": [x, y, z]}.
## Spawn entries: {"preset_slot", "spot", "zone", "pose", "seat_h", "position", "rotation_y"}; preset_slot is
## PLAYER, BAR_1 (bartender), PATRON (seats) or PATRON_WANDER (wander points). Units are metres, x east, z south,
## y up (Godot axes; Blender is x, -z, y).

const OUT := "res://assets/kit/layout.json"
const KIT_DIR := "res://assets/kit/"

func _init() -> void:
	var main: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var venue: Node3D = main.get_node("Venue")
	var kit := []
	_collect(venue, venue, kit)
	var spawns := []
	var player: Node3D = main.get_node("Player")
	spawns.append({"preset_slot": "PLAYER", "spot": "Player", "zone": "Lounge", "pose": "stand", "seat_h": 0.0,
		"position": _v(player.position * Vector3(1, 0, 1)), "rotation_y": snappedf(player.rotation_degrees.y, 0.01)})
	for s in venue.get_node("Patrons/Spots").get_children():
		var pose: String = s.get_meta("pose")
		var slot: String = {"staff": "BAR_1", "wander": "PATRON_WANDER"}.get(pose, "PATRON")
		spawns.append({"preset_slot": slot, "spot": str(s.name), "zone": s.get_meta("zone"), "pose": pose,
			"seat_h": s.get_meta("seat_h"), "position": _v(s.position), "rotation_y": snappedf(s.rotation_degrees.y, 0.01)})
	var data := {"source": "res://scenes/venue/venue.tscn", "units": "m", "axes": "godot: x east, y up, z south",
		"room_height_m": 4.0, "kit": kit, "spawns": spawns}
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, " "))
	f.close()
	print("layout written: ", kit.size(), " kit instances, ", spawns.size(), " spawns")
	main.free()
	quit()

func _collect(n: Node, venue: Node3D, out: Array) -> void:
	for c in n.get_children():
		if c is Node3D and c.scene_file_path.begins_with(KIT_DIR):
			var xf := _rel(c, venue)
			var zone := str(venue.get_path_to(c).get_name(0))
			out.append({"object": c.scene_file_path.get_file().get_basename(), "zone": zone, "name": str(c.name),
				"position": _v(xf.origin), "rotation_y": snappedf(rad_to_deg(xf.basis.get_euler().y), 0.01),
				"scale": _v(xf.basis.get_scale())})
		else:
			_collect(c, venue, out)

## Transform relative to the venue root without needing the tree (groups like Lounge/CeilingGrid nest).
func _rel(n: Node3D, venue: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != venue and p is Node3D:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf

func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
