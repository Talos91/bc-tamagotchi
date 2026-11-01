extends Node3D
## Simulated crowd for the venue (Venue/Patrons). Spots are the Marker3D children of Spots/, written by
## tools/build_venue.gd and named by zone (Tables_T0_C1, Bar_Stool3, Banquette_Seat1, CommunalTable_T0_S1,
## Lounge_Chair0, Bar_Bartender, Wander_Aisle, ...) with metas zone, pose ("sit" | "stand" | "staff" | "wander")
## and seat_h. On ready it seats `seated_count` patrons (at least one per seating zone), puts the bartender behind
## the bar and sends `wanderer_count` patrons walking between the Wander_* spots on the navmesh.
## The player takes seats from the same spots (VenueSession.find_seat): is_taken() tells which have a patron, and
## vacate() gets that patron up to wander. Walkers are in group "door_user" (swing doors open for them); the staff
## member at the order hatch now and then steps out through the staff door (group "staff_door_user") and back.
## Figures are PatronFigure scenes (scenes/venue/patron_figure.tscn): character presets when they are imported,
## palette-swapped box placeholders otherwise.

const FIGURE := preload("res://scenes/venue/patron_figure.tscn")
## The 24 anonymous patrons (bc_chars.py PATRONS, styled after the crowd in renders 05/06). patron_06 is the player.
const PATRON_PRESETS := ["patron_01", "patron_02", "patron_03", "patron_04", "patron_05", "patron_07", "patron_08",
	"patron_09", "patron_10", "patron_11", "patron_12", "patron_13", "patron_14", "patron_15", "patron_16",
	"patron_17", "patron_18", "patron_19", "patron_20", "patron_21", "patron_22", "patron_23", "patron_24"]
## Band spots (pose band_*) -> preset and the animation it plays (renders 05/06: drums, two guitars, bass; Jo sings)
const BAND := {"band_drums": ["boy", "play_drums"], "band_guitar": ["band_guitar", "play_guitar"],
	"band_bass": ["pete", "play_bass"], "band_vocal": ["jo", "sing"]}
## Seated pose by spot: at a table or the bar, forearms on the top with a glass, some chatting; on the drum-stool
## poufs facing the stage and in lounge chairs, glass held at the chest; now and then the front row applauds.
const TABLE_POSES := ["sit_drink", "sit_drink", "sit_talk"]
const FREE_POSES := ["sit_hold", "sit_hold", "sit_applaud"]
const SEAT_ZONES := ["Tables", "Bar", "Lounge", "Buffer", "Raised", "Smoking"]
const WALK_SPEED := 1.1
const SERVER_START := Vector3(30.0, 0, 6.7)
## Staff door of the walled bar area (build_venue.gd STAFF_DOOR_BAR, wall z MAIN_SE_Z + 0.1)
const STAFF_DOOR_X := 37.55
const STAFF_DOOR_Z := 12.75
## PatronFigure draws presets at its FIG_SCALE; seated figures are lowered so their thighs land on the seat.
const FIG_SCALE := PatronFigure.FIG_SCALE
## The bartender stands on the raised duckboard behind the counter (05/06 show them chest-up over the 1.1 m bar)
const BARTENDER_LIFT := 0.3
## The host of the hosted table (VenueZones.REGULAR at REGULAR_TABLE: Prae, an owner) stands this far from its centre:
## past the corner between its west and south chairs (clear of their backs), on the side the main room's camera sees
const HOST_OFFSET := Vector3(-0.9, 0, 0.9)

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
var _runner: PatronFigure           # hatch staff on errands through the staff door
var _errand: Array[Vector3] = []
var _errand_wait := 0.0
var _hatch_pos := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

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
			"wander": _wander_points.append(s.global_position)
			_:
				if BAND.has(pose):
					band.append(s)
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
		if chosen.size() >= seated_count:
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
	_place_host(seats)
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

## The owner who hosts a table stands at its edge facing the room, greeting whoever comes over: working the floor, not
## seated as a guest (03-cast §2.3; Prae, Daniele 2026-11-02).
func _place_host(seats: Array[Node3D]) -> void:
	var c := Vector3.ZERO
	var k := 0
	for s in seats:
		if s.get_meta("table", "") == VenueZones.REGULAR_TABLE:
			c += s.position
			k += 1
	if k == 0:
		return
	c /= k
	var f := _spawn(VenueZones.REGULAR, "Host_" + VenueZones.REGULAR)
	f.position = Vector3(c.x, 0, c.z) + HOST_OFFSET
	f.rotation.y = atan2(HOST_OFFSET.x, HOST_OFFSET.z)
	f.play("idle")

func is_taken(seat: Node3D) -> bool:
	return taken.has(seat)

## The patron on `seat` gets up and wanders off, so the player can sit there.
func vacate(seat: Node3D) -> void:
	var f: PatronFigure = taken.get(seat)
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
	}
	add_child(f)
	figures.append(f)
	return f

func _process(delta: float) -> void:
	_walk_wanderers(delta)
	_pace_bartender(delta)
	_run_errand(delta)

## Hatch staff: wait at the hatch, walk to the staff door, out a step into the main room, pause, and back (straight
## lines: the staff room is off the navmesh). The door swings for them (venue_doors.gd); the player never passes.
func _run_errand(delta: float) -> void:
	if _runner == null:
		return
	if _errand.is_empty():
		_errand_wait -= delta
		_runner.play("idle")
		_runner.rotation.y = lerp_angle(_runner.rotation.y, PI, 1.0 - exp(-6.0 * delta))
		if _errand_wait <= 0.0:
			var inside := Vector3(STAFF_DOOR_X, 0, STAFF_DOOR_Z + 0.6)
			var outside := Vector3(STAFF_DOOR_X, 0, STAFF_DOOR_Z - 1.3)
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
