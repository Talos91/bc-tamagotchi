class_name VenueZones
extends Node3D
## Interaction zones, built at runtime from the layout of record (res://assets/kit/layout.json), so nothing is placed
## in scenes/venue/. One Area3D trigger per zone; while the player stands in one or more, `current` is the one whose
## centre is nearest and `zone_changed` fires when it changes. `zone_at(point)` answers floor taps.
##
## Zone kinds and where they come from in layout.json (plan v4, docs/art/plan-v4.md):
##   bar      the bar_counter run (zone Bar), approached from the stool side; Nam is the bartender (spawn Bar_Bartender)
##   stage    the stage_carpet_tile bounds (zone Stage: the stage is at floor level, marked by carpets) plus the
##            floor in front, approached at spawn Wander_StageFront
##   table    every round_table of zones Tables, Raised and Lounge; REGULAR_TABLE hosts the regular (id mali, shown
##            as Prae since 2026-11-01); the raised strip's small tables reach their couch seats (radius x 0.95 at least)
##   arcade   the pinball (pinball_machine, or arcade_cabinet while the kit lacked it) on the lounge's west wall
##   cabinet  the Black Cabin game machine (game_cabinet_bc) by the stairs: stub, generic sheet for now
##   tall     every tall_table_square (buffer zone and the main room's west opening): stub, generic sheet
##   smoking  the smoking room, one zone over its tables: stub, generic sheet
##   exit     the street door under exit_sign ExitSignStreet (lobby west wall), approached from its front; it reaches
##            out over the step of street beyond the door
## A zone is a Dictionary: id, kind, shape ("rect" | "circle"), rect (Rect2 in x,z), center (Vector2 x,z), radius,
## approach (Vector3 on the floor), regular ("" or a cast id). Where zones overlap, circles (a table, the cabinet)
## win over the big rects (bar, stage, smoking), then the nearest centre.

signal zone_changed(zone: Dictionary)

const S = preload("res://scripts/minigames/strings.gd")
const LAYOUT_PATH := "res://assets/kit/layout.json"
const REGULAR := "mali"           ## only regular with Candle Talk content (scenes/minigames/candle_talk/mali.json)
const REGULAR_TABLE := "Table2"   ## her table: the round one in the middle of the row of five, facing the stage
const TRIGGER_HEIGHT := 2.4
const TABLE_RADIUS := 1.15        ## metres around a round table's centre (x its scale)
const TALL_RADIUS := 1.0
const FRONT_RADIUS := 1.1        ## around the floor point in front of a wall machine (pinball, game cabinet)
const TABLE_ZONES := ["Tables", "Raised", "Lounge"]
## Trigger depth in front of the counter's centre line; the floor by the stools is open now, so the player orders
## from right behind them (BAR_APPROACH metres from the counter line).
const BAR_DEPTH := 3.4
const BAR_APPROACH := 1.6
const STAGE_FRONT := 2.2          ## metres of floor south of the carpet that count as the front row
const EXIT_DEPTH := 1.8           ## metres in front of the street door

var zones: Array[Dictionary] = []
var current: Dictionary = {}
var player: Node3D
var _inside := {}  # zone id -> true


func _ready() -> void:
	if zones.is_empty():
		build(defs_from_layout(LAYOUT_PATH))


## Reads layout.json and returns the zone list. Pure; tests call it directly.
static func defs_from_layout(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("VenueZones: cannot read " + path)
		return out
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	var kit: Array = d.get("kit", [])
	var spots := {}
	for s in d.get("spawns", []):
		spots[str(s["spot"])] = _v3(s["position"])

	var bar := _bounds(kit.filter(func(k): return k["object"] == "bar_counter"))
	if bar.size != Vector2.ZERO:
		var front := bar.position.y + bar.size.y * 0.5  # counter centre line (z)
		var r := Rect2(bar.position.x - 0.5, front - BAR_DEPTH, bar.size.x + 1.0, BAR_DEPTH)
		var tender: Vector3 = spots.get("Bar_Bartender", Vector3(r.get_center().x, 0, front))
		out.append(_zone("bar", "bar", r, Vector3(tender.x, 0, front - BAR_APPROACH)))

	var stage := _bounds(kit.filter(func(k): return k["zone"] == "Stage" and k["object"] == "stage_carpet_tile"))
	if stage.size != Vector2.ZERO:
		var r := Rect2(stage.position.x - 0.8, stage.position.y - 0.5, stage.size.x + 1.6, stage.size.y + 0.5 + STAGE_FRONT + 0.5)
		out.append(_zone("stage", "stage", r, spots.get("Wander_StageFront", Vector3(r.get_center().x, 0, r.end.y - 0.6))))

	for k in kit:
		if k["object"] == "round_table" and k["zone"] in TABLE_ZONES:
			var p := _v3(k["position"])
			var z := _zone("table:" + str(k["name"]), "table", Rect2(), p)
			z["shape"] = "circle"
			z["center"] = Vector2(p.x, p.z)
			z["radius"] = TABLE_RADIUS * maxf(float(k["scale"][0]), 0.95)
			z["regular"] = REGULAR if str(k["name"]) == REGULAR_TABLE else ""
			out.append(z)

	for k in kit:
		if k["object"] in ["pinball_machine", "arcade_cabinet"]:
			var p := _v3(k["position"])
			# The machine stands against a wall: the zone is the floor in front of it (its front is +z turned by
			# rotation_y), so it never reaches through the wall into the room behind.
			var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(float(k["rotation_y"])))
			var a: Vector3 = spots.get("Wander_Arcade", p + fwd * 1.2)
			var z := _zone("arcade", "arcade", Rect2(), a)
			z["shape"] = "circle"
			z["center"] = Vector2(a.x, a.z)
			z["radius"] = FRONT_RADIUS
			out.append(z)
			break

	for k in kit:
		if k["object"] == "game_cabinet_bc":
			var p := _v3(k["position"])
			var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(float(k["rotation_y"])))
			var a := p + fwd * 1.0
			var z := _zone("cabinet", "cabinet", Rect2(), a)
			z["shape"] = "circle"
			z["center"] = Vector2(a.x, a.z)
			z["radius"] = FRONT_RADIUS
			out.append(z)
			break

	for k in kit:
		if k["object"] == "tall_table_square":
			var p := _v3(k["position"])
			var z := _zone("tall:" + str(k["name"]), "tall", Rect2(), p)
			z["shape"] = "circle"
			z["center"] = Vector2(p.x, p.z)
			z["radius"] = TALL_RADIUS
			out.append(z)

	var smoke := _bounds(kit.filter(func(k): return k["object"] == "smoke_table_square"))
	if smoke.size != Vector2.ZERO:
		var r := smoke.grow(1.0)
		out.append(_zone("smoking", "smoking", r, spots.get("Wander_Smoking", Vector3(r.get_center().x, 0, r.get_center().y))))

	for k in kit:
		if k["object"] == "exit_sign" and str(k["name"]) == "ExitSignStreet":
			var p := _v3(k["position"])
			# The sign faces the room: rotation 90 = +x (lobby west wall), 0 = +z (a north wall)
			var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(float(k["rotation_y"])))
			var c := p + fwd * EXIT_DEPTH * 0.5
			var w := 2.0 if absf(fwd.x) < 0.5 else EXIT_DEPTH
			var dd := EXIT_DEPTH if absf(fwd.x) < 0.5 else 2.0
			var r := Rect2(c.x - w * 0.5, c.z - dd * 0.5, w, dd)
			var out_pt := p - fwd * (EXIT_DEPTH + 0.2)   # the step of street outside the open door
			r = r.expand(Vector2(out_pt.x, out_pt.z))
			out.append(_zone("exit", "exit", r, p + fwd * 0.9))
	return out


static func _zone(id: String, kind: String, r: Rect2, approach: Vector3) -> Dictionary:
	return {"id": id, "kind": kind, "shape": "rect", "rect": r, "center": r.get_center(), "radius": 0.0,
		"approach": Vector3(approach.x, 0, approach.z), "regular": ""}


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## x,z bounds of kit items' positions.
static func _bounds(items: Array) -> Rect2:
	if items.is_empty():
		return Rect2()
	var p0 := _v3(items[0]["position"])
	var r := Rect2(p0.x, p0.z, 0, 0)
	for k in items:
		var p := _v3(k["position"])
		r = r.expand(Vector2(p.x, p.z))
	return r


func build(defs: Array[Dictionary]) -> void:
	zones = defs
	for z in zones:
		var area := Area3D.new()
		area.name = "Zone_" + str(z["id"]).replace(":", "_")
		area.collision_layer = 0
		area.collision_mask = 1
		area.monitorable = false
		var cs := CollisionShape3D.new()
		if z["shape"] == "circle":
			var cyl := CylinderShape3D.new()
			cyl.radius = z["radius"]
			cyl.height = TRIGGER_HEIGHT
			cs.shape = cyl
		else:
			var box := BoxShape3D.new()
			var r: Rect2 = z["rect"]
			box.size = Vector3(r.size.x, TRIGGER_HEIGHT, r.size.y)
			cs.shape = box
		var c: Vector2 = z["center"]
		area.position = Vector3(c.x, TRIGGER_HEIGHT * 0.5, c.y)
		area.add_child(cs)
		add_child(area)
		area.body_entered.connect(_on_body.bind(z["id"], true))
		area.body_exited.connect(_on_body.bind(z["id"], false))
		if z["regular"] != "":
			_add_tag(z)


## Floating name over the regular's table so testers can find her.
func _add_tag(z: Dictionary) -> void:
	var tag := Label3D.new()
	tag.name = "Tag_" + str(z["regular"])
	tag.text = "%s  ♥" % _regular_name(z["regular"])
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.004
	tag.font_size = 48
	tag.outline_size = 12
	tag.modulate = Color("FFDD78")
	tag.outline_modulate = Color("160A0C")
	tag.no_depth_test = true
	var c: Vector2 = z["center"]
	tag.position = Vector3(c.x, 2.1, c.y)
	add_child(tag)


static func _regular_name(id: String) -> String:
	return S.t("cast.%s.name" % id)


func _on_body(body: Node3D, id: String, entered: bool) -> void:
	if body != player:
		return
	if entered:
		_inside[id] = true
	else:
		_inside.erase(id)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	# The areas report the player's whole capsule; the zone is chosen by where the feet are.
	var best: Dictionary = {}
	if not _inside.is_empty():
		best = zone_at(player.global_position, 0.0)
		if not _inside.has(best.get("id", "")):
			best = {}
	if best.get("id", "") != current.get("id", ""):
		current = best
		zone_changed.emit(current)


## Lower is preferred: circles first, then distance to the centre.
static func _rank(z: Dictionary, p: Vector2) -> float:
	return p.distance_to(z["center"]) + (0.0 if z["shape"] == "circle" else 1000.0)


func by_id(id: String) -> Dictionary:
	for z in zones:
		if z["id"] == id:
			return z
	return {}


func first_of(kind: String, regular := false) -> Dictionary:
	for z in zones:
		if z["kind"] == kind and (not regular or z["regular"] != ""):
			return z
	return {}


## The zone whose footprint holds a world point (a floor or object tap), nearest centre first; {} if none.
func zone_at(world_pos: Vector3, grow := 0.2) -> Dictionary:
	var p := Vector2(world_pos.x, world_pos.z)
	var best: Dictionary = {}
	var best_d := INF
	for z in zones:
		var hit := false
		if z["shape"] == "circle":
			hit = p.distance_to(z["center"]) <= float(z["radius"]) + grow
		else:
			hit = (z["rect"] as Rect2).grow(grow).has_point(p)
		var d := _rank(z, p)
		if hit and d < best_d:
			best_d = d
			best = z
	return best
