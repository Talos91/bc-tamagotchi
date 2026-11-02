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
##   table    every round_table of zones Tables, Raised and Lounge; the raised strip's small tables reach their couch
##            seats (radius x 0.95 at least). Raised3 was boxed in until the east rectangular table moved 0.6 m west
##            (Daniele 2026-11-02): its chair and couch places are walked to like the others'
##   arcade   the pinball (pinball_machine, or arcade_cabinet while the kit lacked it) on the lounge's west wall
##   cabinet  the Black Cabin game machine (game_cabinet_bc) by the stairs: stub, generic sheet for now
##   memory   the memory corner in the lounge's north-west (around its crt_monitor): share a photo (coming soon), sit
##   merch    the merch counter (merch_stand) top right of the lounge: the merch list, placeholders (BACKLOG B11)
##   patrons  the "Top patrons" board (patrons_board) under the lounge stairs: the ten names (B10, scripts/zones/patrons.gd)
##   portrait one per frame on the entrance corridor's south wall (portrait_frame Portrait<rank>): the patron's portrait
##            and a message from the owner (placeholder); id "portrait:<rank>" (B7)
##   tall     every tall_table_square (buffer zone and the main room's west opening): stub, generic sheet
##   smoking  the smoking room, one zone over its tables: Light one up (nightlife) and the generic sit
##   toilet   the toilets vestibule behind the bar's west end (Vestibule kit at floor level): the secret
##            Check the plumbing, offered nowhere else
##   table    also every other group of seats (spawns' "table": tiny tables, the lounge long table and counter, the
##            rectangular tables, the smoking-room tables; Daniele 2026-11-02: every seat is sittable), centred on its
##            table (or its seats) and reaching just past the farthest seat
##   exit     the street door under exit_sign ExitSignStreet (lobby west wall), approached from its front; it reaches
##            out over the step of street beyond the door
## A zone is a Dictionary: id, kind, shape ("rect" | "circle"), rect (Rect2 in x,z), center (Vector2 x,z), radius,
## approach (Vector3 on the floor), optional slack (extra metres a finished walk may end outside it, main.gd), host ("" or the cast id placed there tonight, of any role: Cast.hosts()), regular
## (the host when they have Candle Talk lines, so the zone offers a talk; else ""). Tonight Tt (a regular) hosts the
## lounge's Long Table and Prae (an owner, silent for now) is at one of her spots every other night (cast.gd).
## Where zones overlap, circles (a table, the cabinet) win over the big rects (bar, stage, smoking), then the nearest
## centre.

signal zone_changed(zone: Dictionary)

const S = preload("res://scripts/minigames/strings.gd")
const Cast = preload("res://scripts/cast.gd")
const LAYOUT_PATH := "res://assets/kit/layout.json"
const TRIGGER_HEIGHT := 2.4
const TABLE_RADIUS := 1.15        ## metres around a round table's centre (x its scale)
const TALL_RADIUS := 1.0
const MEMORY_RADIUS := 1.5
const SEAT_MARGIN := 0.35         ## metres past the farthest seat of a seat-group table zone
const FRONT_RADIUS := 1.1        ## around the floor point in front of a wall machine (pinball, game cabinet)
## Approach points for zones whose own centre is out of the walk's reach: the nearest reachable floor (navmesh probe).
## Empty since Raised3 opened up (a zone listed here gets an arrival slack to match, main.gd).
const APPROACH_AT := {}
const BOARD_REACH := 0.75        ## metres in front of the patrons board and a corridor portrait where the walk ends
const PORTRAIT_RADIUS := 0.55    ## portraits hang 1.2 m apart: each zone is the floor right in front of its frame
const TABLE_ZONES := ["Tables", "Raised", "Lounge"]
## Trigger depth in front of the counter's centre line; the floor by the stools is open now, so the player orders
## from right behind them (BAR_APPROACH metres from the counter line).
const BAR_DEPTH := 3.4
const BAR_APPROACH := 1.6
const STAGE_FRONT := 2.2          ## metres of floor south of the carpet that count as the front row
const EXIT_DEPTH := 0.9           ## metres in front of the street door (the doorway only: the spawn at x 1.5 is outside it)
const EXIT_OUTSIDE := 2.0         ## metres beyond it: the step of street outside the open door

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
			var id := "table:" + str(k["name"])
			var a: Vector3 = APPROACH_AT.get(id, p)
			var z := _zone(id, "table", Rect2(), a)
			z["shape"] = "circle"
			z["center"] = Vector2(p.x, p.z)
			z["radius"] = TABLE_RADIUS * maxf(float(k["scale"][0]), 0.95)
			if APPROACH_AT.has(id):
				z["slack"] = maxf(0.0, Vector2(a.x - p.x, a.z - p.z).length() - float(z["radius"])) + 0.3
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
		if k["object"] == "merch_stand":
			var p := _v3(k["position"])
			var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(float(k["rotation_y"])))
			var a := p + fwd * 1.1
			var z := _zone("merch", "merch", Rect2(), a)
			z["shape"] = "circle"
			z["center"] = Vector2(a.x, a.z)
			z["radius"] = FRONT_RADIUS
			out.append(z)
		elif k["object"] == "patrons_board" or k["object"] == "portrait_frame":
			var p := _v3(k["position"])
			var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(float(k["rotation_y"])))
			var portrait: bool = k["object"] == "portrait_frame"
			# The board is read from its view in the north-east: the walk ends a little to that side of it
			var a := p + fwd * BOARD_REACH + (Vector3.ZERO if portrait else Vector3.UP.cross(fwd) * 0.45)
			var id := "portrait:" + str(k["name"]).trim_prefix("Portrait") if portrait else "patrons"
			var z := _zone(id, "portrait" if portrait else "patrons", Rect2(), a)
			z["shape"] = "circle"
			var c := p + fwd * 0.55 if portrait else a   # nearer the wall, so a tap on the frame (the wall behind it) lands in it
			z["center"] = Vector2(c.x, c.z)
			z["radius"] = PORTRAIT_RADIUS if portrait else FRONT_RADIUS
			if portrait:
				z["rank"] = int(str(k["name"]).trim_prefix("Portrait"))
			out.append(z)

	for k in kit:
		if k["object"] == "crt_monitor":   # the memory corner's TV (photo 25)
			var p := _v3(k["position"])
			var a := p + Vector3(1.0, 0, 1.1)
			var z := _zone("memory", "memory", Rect2(), a)
			z["shape"] = "circle"
			z["center"] = Vector2(a.x, a.z)
			z["radius"] = MEMORY_RADIUS
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

	# Every other group of seats becomes a table zone with the plain table sheet (sit_with, once per table per day)
	var have := {}
	for z in out:
		have[str(z["id"]).get_slice(":", 1)] = true
		have[str(z["id"])] = true
	var groups := {}
	for s in d.get("spawns", []):
		var t := str(s.get("table", ""))
		if t != "" and t != "Bar" and not have.has(t):
			if not groups.has(t):
				groups[t] = []
			groups[t].append(_v3(s["position"]))
	for t in groups:
		var seats: Array = groups[t]
		var c := Vector3.ZERO
		for sp in seats:
			c += sp
		c /= seats.size()
		for k in kit:
			if str(k["name"]) == t:
				c = _v3(k["position"])
				break
		var reach := 0.0
		for sp in seats:
			reach = maxf(reach, Vector2(sp.x - c.x, sp.z - c.z).length())
		var z := _zone("table:" + t, "table", Rect2(), c)
		z["shape"] = "circle"
		z["center"] = Vector2(c.x, c.z)
		z["radius"] = reach + SEAT_MARGIN
		out.append(z)

	# The toilets vestibule left behind the bar (its curtain, doors and picture), roofed, so the character is out of
	# view there: home of the secret Check the plumbing (nightlife, DECISIONS "Playtest of 33dc5b9")
	var loo := _bounds(kit.filter(func(k): return k["zone"] == "Vestibule" and float(k["position"][1]) < 0.5))
	if loo.size != Vector2.ZERO:
		var r := loo.grow(0.1)
		out.append(_zone("toilet", "toilet", r, spots.get("Wander_Toilets", Vector3(r.get_center().x, 0, r.get_center().y))))

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
			var out_pt := p - fwd * EXIT_OUTSIDE
			r = r.expand(Vector2(out_pt.x, out_pt.z))
			out.append(_zone("exit", "exit", r, p + fwd * EXIT_DEPTH * 0.6))

	var hosts := Cast.hosts()
	for z in out:
		var who: String = hosts.get(z["id"], "")
		z["host"] = who
		z["regular"] = who if who != "" and Cast.has_lines(who) else ""
	return out


static func _zone(id: String, kind: String, r: Rect2, approach: Vector3) -> Dictionary:
	return {"id": id, "kind": kind, "shape": "rect", "rect": r, "center": r.get_center(), "radius": 0.0,
		"approach": Vector3(approach.x, 0, approach.z), "host": "", "regular": ""}


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
		if z.get("host", "") != "":
			_add_tag(z)


## Floating name over a host's table so players find them.
func _add_tag(z: Dictionary) -> void:
	var tag := Label3D.new()
	tag.name = "Tag_" + str(z["host"])
	tag.text = tag_text(z["host"])
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


## The name over a host's table; a heart only for a regular you befriend (owners have none, Daniele 2026-11-02).
static func tag_text(id: String) -> String:
	return "%s  ♥" % _regular_name(id) if Cast.befriends(id) else _regular_name(id)


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


## Metres on the floor from a point to a zone's footprint: 0 inside it.
static func gap(z: Dictionary, world_pos: Vector3) -> float:
	var p := Vector2(world_pos.x, world_pos.z)
	if z["shape"] == "circle":
		return maxf(0.0, p.distance_to(z["center"]) - float(z["radius"]))
	var r: Rect2 = z["rect"]
	return Vector2(maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0), maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)).length()
