extends Node3D
## Simulated crowd for the venue (Venue/Patrons). Spots are the Marker3D children of Spots/, written by
## tools/build_venue.gd and named by zone (Tables_T0_C1, Bar_Stool3, Banquette_Seat1, CommunalTable_T0_S1,
## Lounge_Chair0, Bar_Bartender, Wander_Aisle, ...) with metas zone, pose ("sit" | "stand" | "staff" | "wander")
## and seat_h. On ready it seats `seated_count` patrons (at least one per seating zone), puts the bartender behind
## the bar and sends `wanderer_count` patrons walking between the Wander_* spots on the navmesh.
## The player takes seats from the same spots (VenueSession.find_seat): is_taken() tells which have a patron, and
## vacate() gets that patron up to wander. Walkers are in group "door_user" (swing doors open for them); the staff
## member at the order hatch now and then walks through the bar door to behind the counter (group "staff_door_user") and back.
## Figures are PatronFigure scenes (scenes/venue/patron_figure.tscn): character presets when they are imported,
## palette-swapped box placeholders otherwise.
## The cast placed tonight (Cast.hosts(): Tt at the Long Table, Prae every other night) come first: a regular takes a
## seat of their table, which leaves group "seat" so neither patrons nor the player take it; an owner stands at the
## edge of hers, facing the room.

const FIGURE := preload("res://scenes/venue/patron_figure.tscn")
## The 24 anonymous patrons (bc_chars.py PATRONS, styled after the crowd in renders 05/06). patron_06 is the player.
const PATRON_PRESETS := ["patron_01", "patron_02", "patron_03", "patron_04", "patron_05", "patron_07", "patron_08",
	"patron_09", "patron_10", "patron_11", "patron_12", "patron_13", "patron_14", "patron_15", "patron_16",
	"patron_17", "patron_18", "patron_19", "patron_20", "patron_21", "patron_22", "patron_23", "patron_24"]
## Band spots (pose band_*) -> preset and the animation it plays (renders 05/06: drums, guitars, bass; Jo sings). The
## guest at the left of the stage plays the electric piano (Daniele 2026-11-02; was band_guitar, play_guitar).
const BAND := {"band_drums": ["boy", "play_drums"], "band_keys": ["band_keys", "play_keys"],
	"band_bass": ["pete", "play_bass"], "band_vocal": ["jo", "sing"]}
## Seated pose by spot: at a table or the bar, forearms on the top with a glass, some chatting; on the drum-stool
## poufs facing the stage and in lounge chairs, glass held at the chest; now and then the front row applauds.
const TABLE_POSES := ["sit_drink", "sit_drink", "sit_talk"]
const FREE_POSES := ["sit_hold", "sit_hold", "sit_applaud"]
const SEAT_ZONES := ["Tables", "Bar", "Lounge", "Buffer", "Raised", "Smoking"]
const WALK_SPEED := 1.1
const SERVER_START := Vector3(30.0, 0, 6.7)
## Staff door from behind the counter into the walled bar area (build_venue.gd BAR_DOOR, wall x BAR_X1 + 0.1): the
## walled area and the strip behind the counter stand on a raised floor, BARTENDER_LIFT up (owner items 4 and 5). The
## hatch staff only ever goes through this one, so they never step down or up (owner item 15); the north staff door
## into the main room stays shut.
const BAR_DOOR_X := 35.85
const BAR_DOOR_Z := 13.9
## PatronFigure draws presets at its FIG_SCALE; seated figures are lowered so their thighs land on the seat.
const FIG_SCALE := PatronFigure.FIG_SCALE
## The bartender stands on the raised floor behind the counter (05/06 show them chest-up over the 1.1 m bar);
## build_venue.gd BAR_FLOOR_H, the same height, also raises the walled bar area and the hatch staff in it
const BARTENDER_LIFT := 0.45   # figures are 1.16 m: 0.5 m of them shows over the 1.1 m counter, head and shoulders (photo 09)
const Cast = preload("res://scripts/cast.gd")
const Avatar = preload("res://scripts/avatar.gd")
const PresenceClient = preload("res://scripts/presence_ui/presence_client.gd")
const Badge = preload("res://scripts/presence_ui/presence_badge.gd")
const PresenceTaps = preload("res://scripts/presence_ui/presence_taps.gd")
## Where an owner stands at each of her spots: offset from the table's centre (past the corner between two chairs, clear
## of their backs) and the yaw she faces, turned west toward whoever arrives from the lounge side. WestTable0 is 1.8 m
## from the main room's west wall, so she takes its south-east corner there; at the buffer's tall table (stools east and
## west, a mirror wall south) she stands on its north side, in the lane. Other tables: HOST_OFFSET, facing away.
const HOST_OFFSET := Vector3(-0.9, 0, 0.9)
const OWNER_SPOTS := {
	"table:WestTable0": [Vector3(0.9, 0, 0.9), -PI * 0.25],
	"table:Table0": [Vector3(-0.9, 0, 0.9), -PI * 0.25],
	"tall:BufferTall3": [Vector3(0, 0, -0.8), -PI * 0.5],
}
## A regular's chair at their table, by preference: Tt on the Long Table's banquette, facing the lounge.
const HOST_SEATS := {"tt": ["Lounge_Banquette1", "Lounge_Banquette0", "Lounge_Banquette2"]}

# Placeholder palette (art bible §3 and §7 wardrobe; reds avoided for tops so figures read against the room)
const SKINS := ["f0d2b6", "e4ba96", "d2a07a", "bc8860", "a06e4a", "845636", "6a432c", "4e3022"]
const HAIRS := ["1e1616", "3e2618", "6a4228", "7e3220", "e6d0a0", "403a3e"]
const TOPS := ["c99430", "d9c9a6", "3f5878", "66703a", "e4dde6", "2e6a6a", "6c88a8", "e8a030", "403a3e", "8a5aa0"]
const BOTTOMS := ["3f5878", "221110", "403a3e", "4c5a30", "7c7270", "3e2618"]

@export var seated_count := 80   # renders 05/06, Daniele: every table seated, bar stools and poufs taken
@export var wanderer_count := 2
@export var crowd_seed := 1923

var figures: Array[PatronFigure] = []
var _wanderers: Array[Dictionary] = []
var _wander_points: Array[Vector3] = []
var _bartender: PatronFigure
var _bar_x := Vector2(22.6, 35.0)   # plan v4 bar, x 21.8..35.75
var taken := {}                     # seat spot -> the patron on it
var _runner: PatronFigure           # hatch staff on errands through the bar door
var _errand: Array[Vector3] = []
var _errand_wait := 0.0
var _hatch_pos := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
# Presence (08-presence §6; scripts/presence_ui/)
var presences := {}                 ## player_id -> PatronFigure (group "presence")
var _all_seats: Array[Node3D] = []  ## every chair left after the hosts
var _arrivals: Array[Dictionary] = []   ## late check-ins walking in: {fig, path, idx, seat}
var _door_point := Vector3.INF      ## where late check-ins come in (Wander_Lobby, inside the street door)
var _poll_t := 0.0
var _polling := false

func _ready() -> void:
	add_to_group("venue_patrons")
	_rng.seed = crowd_seed
	var seats: Array[Node3D] = []
	var staff: Node3D = null
	var hatch: Node3D = null
	var band: Array[Node3D] = []
	for s in $Spots.get_children():
		var pose: String = s.get_meta("pose", "")
		match pose:
			"sit": seats.append(s)
			"staff": staff = s
			"hatch": hatch = s
			"wander":
				_wander_points.append(s.global_position)
				if s.name == "Wander_Lobby":
					_door_point = s.global_position
			_:
				if BAND.has(pose):
					band.append(s)
	_place_hosts(seats)
	_all_seats = seats.duplicate()
	var fill := seated_count - _place_presences(seats)
	var presets := PATRON_PRESETS.duplicate()
	_shuffle(presets)
	# One seat per seating zone first, then fill at random
	_shuffle(seats)
	var chosen: Array[Node3D] = []
	for z in SEAT_ZONES:
		for s in seats:
			if s.get_meta("zone") == z and not chosen.has(s):
				chosen.append(s)
				break
	for s in seats:
		if chosen.size() >= fill:
			break
		if not chosen.has(s):
			chosen.append(s)
	var n := 0
	for s in chosen:
		var f := _spawn(presets[n % presets.size()], "Patron%d_%s" % [n, s.name], {"sit": _seat_pose(s)})
		f.position = s.position + Vector3(0, float(s.get_meta("seat_h", PatronFigure.SEAT_H)) - PatronFigure.SEAT_H * FIG_SCALE, 0)
		f.rotation.y = s.rotation.y
		f.play("sit")
		taken[s] = f
		n += 1
	for s in band:
		var b: Array = BAND[s.get_meta("pose")]
		var f := _spawn(b[0], "Band_" + str(b[0]))
		f.position = s.position + Vector3(0, float(s.get_meta("seat_h", 0.0)) - (PatronFigure.SEAT_H * FIG_SCALE if b[1] == "play_drums" else 0.0), 0)
		f.rotation.y = s.rotation.y
		f.play(b[1])
	if staff:
		_bartender = _spawn("nam", "Bartender", {"idle": "pour"})
		_bartender.position = staff.position + Vector3(0, BARTENDER_LIFT, 0)
		_bartender.rotation.y = staff.rotation.y
		_bartender.set_meta("pace", 0.0)
	if hatch:   # staff member behind the order hatch of the walled staff room (plan v4)
		var h := _spawn("fern", "HatchStaff")
		h.position = hatch.position
		h.rotation.y = hatch.rotation.y
		h.play("idle")
		h.add_to_group("staff_door_user")
		_runner = h
		_hatch_pos = h.position
		_errand_wait = _rng.randf_range(6.0, 12.0)
	for i in mini(wanderer_count, _wander_points.size()):
		var f := _spawn("server" if i == 0 else presets[n % presets.size()], "Server" if i == 0 else "Wanderer%d" % i,
			{"walk": "walk_tray", "idle": "idle_tray"} if i == 0 else {})
		f.position = _wander_points[(i * 2) % _wander_points.size()]
		if i == 0:   # the server starts in the aisle with the tray (renders 05/06)
			for wp in _wander_points:
				if wp.distance_to(SERVER_START) < f.position.distance_to(SERVER_START):
					f.position = wp
		_wanderers.append({"fig": f, "path": PackedVector3Array(), "idx": 0, "wait": _rng.randf_range(0.5, 4.0)})
		f.add_to_group("door_user")
		n += 1

## Tonight's cast (Cast.hosts()): figures named Host_<id>. A regular sits in one of their table's chairs (03-cast §3.1:
## Tt chatting at the Long Table); an owner works the floor at the edge of hers, greeting whoever comes over (§2.3).
## Chairs taken here are removed from `seats` and from group "seat".
func _place_hosts(seats: Array[Node3D]) -> void:
	var hosts := Cast.hosts()
	for zid in hosts:
		var id: String = hosts[zid]
		var table := str(zid).get_slice(":", 1)
		var mine: Array[Node3D] = []
		for s in seats:
			if s.get_meta("table", "") == table:
				mine.append(s)
		if mine.is_empty():
			continue
		var f := _spawn(id, "Host_" + id, {"sit": "sit_talk"})
		if Cast.befriends(id):
			var seat: Node3D = mine[0]
			for want in HOST_SEATS.get(id, []):
				for s in mine:
					if s.name == want:
						seat = s
						break
				if seat.name == want:
					break
			f.position = seat.position + Vector3(0, float(seat.get_meta("seat_h", PatronFigure.SEAT_H)) - PatronFigure.SEAT_H * FIG_SCALE, 0)
			f.rotation.y = seat.rotation.y
			f.play("sit")
			seats.erase(seat)
			seat.remove_from_group("seat")
			continue
		var c := Vector3.ZERO
		for s in mine:
			c += s.position
		c /= mine.size()
		var spot: Array = OWNER_SPOTS.get(zid, [HOST_OFFSET, atan2(HOST_OFFSET.x, HOST_OFFSET.z)])
		f.position = Vector3(c.x, 0, c.z) + spot[0]
		f.rotation.y = spot[1]
		f.play("idle")

func is_taken(seat: Node3D) -> bool:
	return taken.has(seat)

## The patron on `seat` gets up and wanders off, so the player can sit there. A presence never does (§6.2); its
## chair is out of group "seat" anyway.
func vacate(seat: Node3D) -> void:
	var f: PatronFigure = taken.get(seat)
	if f != null and f.is_in_group("presence"):
		return
	taken.erase(seat)
	if f == null:
		return
	f.position = seat.position
	f.add_to_group("door_user")
	_wanderers.append({"fig": f, "path": PackedVector3Array(), "idx": 0, "wait": 0.3})

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _seat_pose(s: Node3D) -> String:
	var nm := String(s.name)
	if nm.begins_with("Tables_DrumStool") or nm.begins_with("Lounge_Chair") or nm.begins_with("Lounge_Banquette"):
		return FREE_POSES[_rng.randi() % FREE_POSES.size()]
	return TABLE_POSES[_rng.randi() % TABLE_POSES.size()]

func _spawn(preset: String, nm: String, anims := {}) -> PatronFigure:
	var f: PatronFigure = FIGURE.instantiate()
	f.name = nm
	f.look = {
		"preset": preset,
		"skin": Color(SKINS[_rng.randi() % SKINS.size()]),
		"hair": Color(HAIRS[_rng.randi() % HAIRS.size()]),
		"top": Color(TOPS[_rng.randi() % TOPS.size()]),
		"bottom": Color(BOTTOMS[_rng.randi() % BOTTOMS.size()]),
		"shoes": Color("d9c9a6") if _rng.randf() < 0.5 else Color("221110"),
		"height": _rng.randf_range(1.2, 1.4),
		"anims": anims,
		"merge": true,   # one skinned mesh per figure (venue_batch.gd, owner item 41)
	}
	add_child(f)
	figures.append(f)
	return f

func _process(delta: float) -> void:
	_walk_wanderers(delta)
	_pace_bartender(delta)
	_run_errand(delta)
	if not presences.is_empty() or _polling:
		_walk_arrivals(delta)
		_poll_t += delta
		if _poll_t >= PresenceClient.PRESENCE_POLL_S:
			poll_presence()

# --- Presence (docs/design/08-presence.md §6; owner item 40) ---------------------------------------
## Real people checked in tonight (scripts/presence_ui/presence_client.gd: the backend, or "Fake presences"), seated
## as their own avatars before the anonymous fill, which shrinks by as many so the headcount holds (§6.1). Each has the
## LIVE badge and floor ring (presence_badge.gd), is named Presence_<player_id>, is in group "presence", and its chair
## leaves group "seat" (the player never takes it and vacate() never moves it, §6.2). Every PRESENCE_POLL_S the list is
## fetched again: late check-ins walk in from the street door to their seat, people who are gone (hidden, reported)
## fade out where they sit. Seat: the real table for a viewer checked in tonight, else a chair in that table's zone but
## never that table (P3). Presence off (the default): nothing here runs and the crowd is as before.

## Seats tonight's presences now (the cached / fake list, which answers at once); returns how many were placed. A
## source that answers later sends them in through the door instead (_on_tonight).
func _place_presences(seats: Array[Node3D]) -> int:
	if not PresenceClient.active():
		return 0
	_polling = true
	if PresenceClient.active() and _door_point == Vector3.INF and not _wander_points.is_empty():
		_door_point = _wander_points[0]
	var box := {"ready": true, "list": [], "got": false}
	PresenceClient.fetch_tonight(_needs(), func(list: Array, ok: bool):
		if box["ready"]:
			box["got"] = true
			box["list"] = list
		else:
			_on_tonight(list, ok))
	box["ready"] = false
	var taps := PresenceTaps.new()
	taps.venue = self
	tree_exiting.connect(taps.queue_free)
	get_tree().root.add_child.call_deferred(taps)
	if not box["got"]:
		return 0   # the real source answers later: they walk in through the door (_on_tonight)
	var n := 0
	for p: Dictionary in box["list"]:
		if presences.size() >= PresenceClient.PRESENCE_CAP:
			break
		var seat := _pick_seat(p, seats)
		if seat == null:
			break
		seats.erase(seat)
		_spawn_presence(p, seat, false)
		n += 1
	return n

## Fetch tonight's list again (every PRESENCE_POLL_S while the venue is on screen; tests call it).
func poll_presence() -> void:
	_poll_t = 0.0
	PresenceClient.fetch_tonight(_needs(), _on_tonight)

func _on_tonight(list: Array, ok: bool) -> void:
	if not ok or not is_inside_tree():
		return   # offline: keep who is shown (§8)
	var ids := {}
	for p: Dictionary in list:
		ids[str(p.get("player_id", ""))] = true
	for id in presences.keys():
		if not ids.has(id):
			remove_presence(id)
	for p: Dictionary in list:
		var id := str(p.get("player_id", ""))
		if presences.has(id) or presences.size() >= PresenceClient.PRESENCE_CAP:
			continue
		var seat := _pick_seat(p, _free_seats())
		if seat == null:
			seat = _bump_patron(p)
		if seat != null:
			_spawn_presence(p, seat, true)

## A presence leaves (hidden, reported, gone from tonight's list): it fades out and its chair is free again.
func remove_presence(id: String) -> void:
	var f: PatronFigure = presences.get(id)
	presences.erase(id)
	if f == null:
		return
	var seat: Node3D = f.get_meta("seat", null)
	if seat != null:
		taken.erase(seat)
		seat.add_to_group("seat")
	for a in _arrivals:
		if a.fig == f:
			_arrivals.erase(a)
			break
	figures.erase(f)
	f.remove_from_group("presence")
	var tw := f.create_tween()
	tw.tween_property(f, "scale", Vector3(0.01, 0.01, 0.01), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(f.queue_free)

func presence_figure(id: String) -> PatronFigure:
	return presences.get(id)

## The presence answers a verb the player sent (§5.1: the sender sees it now): a bubble and a short applaud.
func react(id: String, text: String) -> void:
	var f: PatronFigure = presences.get(id)
	if f == null:
		return
	Badge.bubble(f, text)
	if f.state == "sit" and not _walking(f):
		var pose: String = f.look.get("anims", {}).get("sit", "sit_drink")
		f.look["anims"]["sit"] = "sit_applaud"
		f.play("sit", true)
		get_tree().create_timer(1.6).timeout.connect(_end_react.bind(weakref(f), pose))

## The applaud is over: back to the seated pose (the figure may have left, or the venue gone: then nothing).
func _end_react(ref: WeakRef, pose: String) -> void:
	var f: PatronFigure = ref.get_ref()
	if f != null and f.state == "sit":
		f.look["anims"]["sit"] = pose
		f.play("sit", true)

func _walking(f: PatronFigure) -> bool:
	for a in _arrivals:
		if a.fig == f:
			return true
	return false

func _needs() -> Node:
	return get_node_or_null("/root/Needs")

## Chairs nobody sits on: not a patron's, not a host's or presence's (out of group "seat"), not the player's.
func _free_seats() -> Array[Node3D]:
	var mine: Variant = null
	var pl := get_tree().root.find_child("Player", true, false)
	if pl != null and pl.get("seat") is Dictionary:
		mine = pl.seat.get("node")
	var out: Array[Node3D] = []
	for s in _all_seats:
		if not taken.has(s) and s.is_in_group("seat") and s != mine:
			out.append(s)
	return out

## No free chair for a late check-in: an anonymous patron in that zone gets up and wanders (as for the player).
func _bump_patron(p: Dictionary) -> Node3D:
	var zone := str(p.get("zone", "")) if str(p.get("zone", "")) != "" else _zone_of_table(str(p.get("table_id", "")))
	for want_zone in [zone, ""]:
		for s in taken:
			var f: PatronFigure = taken[s]
			if f.is_in_group("presence") or not s.is_in_group("seat"):
				continue
			if want_zone == "" or s.get_meta("zone", "") == want_zone:
				vacate(s)
				return s
	return null

func _zone_of_table(table: String) -> String:
	for s in _all_seats:
		if str(s.get_meta("table", "")) == table:
			return str(s.get_meta("zone", ""))
	return ""

## §6.2: a viewer checked in tonight gets the real table (08b: table_id is "" for anyone else; a free chair there,
## else the zone); anyone else a chair in the real table's zone (08b `zone`); else any free chair.
func _pick_seat(p: Dictionary, avail: Array[Node3D]) -> Node3D:
	var table := str(p.get("table_id", ""))
	var here := table != ""
	var zone := str(p.get("zone", ""))
	if zone == "" and here:
		zone = _zone_of_table(table)
	var at_table: Array[Node3D] = []
	var in_zone: Array[Node3D] = []
	for s in avail:
		if taken.has(s):
			continue
		var st := str(s.get_meta("table", ""))
		if here and st == table:
			at_table.append(s)
		elif zone != "" and s.get_meta("zone", "") == zone and (here or st != table):
			in_zone.append(s)
	if not at_table.is_empty():
		return at_table[0]
	if not in_zone.is_empty():
		return in_zone[_rng.randi() % in_zone.size()]
	var rest: Array[Node3D] = []
	for s in avail:
		if not taken.has(s) and (here or str(s.get_meta("table", "")) != table):
			rest.append(s)
	return null if rest.is_empty() else rest[_rng.randi() % rest.size()]

func _spawn_presence(p: Dictionary, seat: Node3D, walk_in: bool) -> PatronFigure:
	var id := str(p.get("player_id", ""))
	var f: PatronFigure = FIGURE.instantiate()
	f.name = "Presence_" + id.validate_node_name().replace("@", "_")
	f.look = {"avatar": Avatar.normalize(p.get("avatar", {})), "anims": {"sit": _seat_pose(seat)}}
	add_child(f)
	figures.append(f)
	f.add_to_group("presence")
	f.set_meta("presence", p)
	f.set_meta("seat", seat)
	presences[id] = f
	taken[seat] = f
	seat.remove_from_group("seat")
	Badge.attach(f, p.get("tablemate", false))
	if walk_in and _door_point != Vector3.INF:
		f.global_position = _door_point
		f.add_to_group("door_user")
		var path := NavigationServer3D.map_get_path(get_world_3d().navigation_map, _door_point, seat.global_position, true)
		_arrivals.append({"fig": f, "path": path, "idx": 0, "seat": seat, "t": 0.0})
		f.play("walk")
	else:
		_seat_presence(f, seat)
	return f

func _seat_presence(f: PatronFigure, seat: Node3D) -> void:
	var lift := float(seat.get_meta("seat_h", PatronFigure.SEAT_H)) - PatronFigure.SEAT_H * FIG_SCALE
	f.position = seat.position + Vector3(0, lift, 0)
	f.rotation.y = seat.rotation.y
	f.play("sit")
	Badge.set_floor(f, lift, true)
	f.remove_from_group("door_user")

## Late check-ins walk from the street door along the navmesh, then sit (a path that is empty or ends short: they sit
## when the path is done, or after 25 s, so nobody is ever stuck standing in the aisle).
func _walk_arrivals(delta: float) -> void:
	for i in range(_arrivals.size() - 1, -1, -1):
		var a: Dictionary = _arrivals[i]
		var f: PatronFigure = a.fig
		a.t += delta
		var path: PackedVector3Array = a.path
		if a.idx >= path.size() or a.t > 25.0:
			_seat_presence(f, a.seat)
			_arrivals.remove_at(i)
			continue
		var target: Vector3 = path[a.idx]
		var d := target - f.global_position
		d.y = 0.0
		if d.length() < 0.1:
			a.idx += 1
			continue
		f.global_position += d.normalized() * minf(WALK_SPEED * delta, d.length())
		f.global_position.y = target.y
		f.rotation.y = lerp_angle(f.rotation.y, atan2(d.x, d.z), 1.0 - exp(-8.0 * delta))
		f.move_speed = WALK_SPEED
		f.play("walk")

## Arrivals still walking in (tests).
func arrivals_walking() -> int:
	return _arrivals.size()

## Hatch staff: wait at the hatch, walk to the bar door, through it to behind the counter, pause, and back (straight
## lines on the raised floor: the staff room is off the navmesh). The door swings for them (venue_doors.gd); the
## player never passes.
func _run_errand(delta: float) -> void:
	if _runner == null:
		return
	if _errand.is_empty():
		_errand_wait -= delta
		_runner.play("idle")
		_runner.rotation.y = lerp_angle(_runner.rotation.y, PI, 1.0 - exp(-6.0 * delta))
		if _errand_wait <= 0.0:
			var inside := Vector3(BAR_DOOR_X + 0.7, _hatch_pos.y, BAR_DOOR_Z)
			var outside := Vector3(BAR_DOOR_X - 1.4, _hatch_pos.y, BAR_DOOR_Z)
			_errand = [inside, outside, outside, inside, _hatch_pos]
			_errand_wait = 2.5   # pause outside
		return
	var goal: Vector3 = _errand[0]
	var d := goal - _runner.position
	d.y = 0.0
	if d.length() < 0.05:
		_errand.pop_front()
		if _errand.size() == 3:   # the pause outside, then back in
			_errand_wait -= delta
			if _errand_wait > 0.0:
				_errand.push_front(goal)
				_runner.play("idle")
				return
		if _errand.is_empty():
			_errand_wait = _rng.randf_range(10.0, 20.0)
		return
	_runner.position += d.normalized() * minf(WALK_SPEED * delta, d.length())
	_runner.rotation.y = lerp_angle(_runner.rotation.y, atan2(d.x, d.z), 1.0 - exp(-8.0 * delta))
	_runner.move_speed = WALK_SPEED
	_runner.play("walk")

func _walk_wanderers(delta: float) -> void:
	var map := get_world_3d().navigation_map
	for w in _wanderers:
		var f: PatronFigure = w.fig
		if w.wait > 0.0:
			w.wait -= delta
			f.play("idle")
			if w.wait <= 0.0:
				var goal := _wander_points[_rng.randi() % _wander_points.size()]
				w.path = NavigationServer3D.map_get_path(map, f.global_position, goal, true)
				w.idx = 0
				if w.path.size() < 2:
					w.wait = 1.0          # map not synced yet, or goal unreachable: try again shortly
			continue
		if w.idx >= w.path.size():
			w.wait = _rng.randf_range(4.0, 9.0)
			continue
		var target: Vector3 = w.path[w.idx]
		var d := target - f.global_position
		d.y = 0.0
		if d.length() < 0.1:
			w.idx += 1
			continue
		var step := minf(WALK_SPEED * delta, d.length())
		f.global_position += d.normalized() * step
		f.global_position.y = target.y
		f.rotation.y = lerp_angle(f.rotation.y, atan2(d.x, d.z), 1.0 - exp(-8.0 * delta))
		f.move_speed = WALK_SPEED
		f.play("walk")

## The bartender works the length of the bar: stand, glance, walk to another spot behind the counter.
func _pace_bartender(delta: float) -> void:
	if _bartender == null:
		return
	var goal: float = _bartender.get_meta("pace")
	if goal == 0.0:
		var wait: float = _bartender.get_meta("wait", 0.0) - delta
		_bartender.set_meta("wait", wait)
		_bartender.play("idle")
		_bartender.rotation.y = lerp_angle(_bartender.rotation.y, PI, 1.0 - exp(-6.0 * delta))
		if wait <= 0.0:
			_bartender.set_meta("pace", _rng.randf_range(_bar_x.x, _bar_x.y))
		return
	var dx := goal - _bartender.position.x
	if absf(dx) < 0.05:
		_bartender.set_meta("pace", 0.0)
		_bartender.set_meta("wait", _rng.randf_range(3.0, 8.0))
		return
	_bartender.position.x += signf(dx) * minf(0.9 * delta, absf(dx))
	_bartender.rotation.y = lerp_angle(_bartender.rotation.y, PI * 0.5 * signf(dx), 1.0 - exp(-8.0 * delta))
	_bartender.move_speed = 0.9
	_bartender.play("walk")
