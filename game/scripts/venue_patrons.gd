extends Node3D
## Simulated crowd for the venue (Venue/Patrons). Spots are the Marker3D children of Spots/, written by
## tools/build_venue.gd and named by zone (Tables_T0_C1, Bar_Stool3, Banquette_Seat1, CommunalTable_T0_S1,
## Lounge_Chair0, Bar_Bartender, Wander_Aisle, ...) with metas zone, pose ("sit" | "stand" | "staff" | "wander")
## and seat_h. On ready it seats `seated_count` patrons (at least one per seating zone), puts the bartender behind
## the bar and sends `wanderer_count` patrons walking between the Wander_* spots on the navmesh.
## Figures are PatronFigure scenes (scenes/venue/patron_figure.tscn): character presets when they are imported,
## palette-swapped box placeholders otherwise.

const FIGURE := preload("res://scenes/venue/patron_figure.tscn")
## patron_13..24 are styled after renders 05/06 (big hair, beards, fedoras, red tops) and come first; the older
## anonymous patrons fill in. patron_06 is the player.
const PATRON_PRESETS := ["patron_13", "patron_14", "patron_15", "patron_16", "patron_17", "patron_18", "patron_19",
	"patron_20", "patron_21", "patron_22", "patron_23", "patron_24", "patron_01", "patron_04", "patron_08",
	"patron_12", "patron_05", "patron_10"]
## Band spots (pose band_*) -> house band preset and the animation it holds (renders 05/06: drums, guitar, bass, vocal)
const BAND := {"band_drums": ["boy", "sit"], "band_guitar": ["jules", "idle_warm"], "band_bass": ["pete", "idle_warm"],
	"band_vocal": ["jo", "idle_merry"]}
const SEAT_ZONES := ["Tables", "Bar", "CommunalTable", "Lounge"]
const WALK_SPEED := 1.1
const SERVER_START := Vector3(16.0, 0, 5.6)
## Presets are 1.45-1.75 m; the renders' chibi patrons stand 1.2 m (docs/art/parity-measurements.md), so every
## figure is drawn at this scale and lowered so its hips still land on the seat.
const FIG_SCALE := 0.8

# Placeholder palette (art bible §3 and §7 wardrobe; reds avoided for tops so figures read against the room)
const SKINS := ["f0d2b6", "e4ba96", "d2a07a", "bc8860", "a06e4a", "845636", "6a432c", "4e3022"]
const HAIRS := ["1e1616", "3e2618", "6a4228", "7e3220", "e6d0a0", "403a3e"]
const TOPS := ["c99430", "d9c9a6", "3f5878", "66703a", "e4dde6", "2e6a6a", "6c88a8", "e8a030", "403a3e", "8a5aa0"]
const BOTTOMS := ["3f5878", "221110", "403a3e", "4c5a30", "7c7270", "3e2618"]

@export var seated_count := 66   # renders 05/06: two to four at every table, most bar stools taken
@export var wanderer_count := 2
@export var crowd_seed := 1923

var figures: Array[PatronFigure] = []
var _wanderers: Array[Dictionary] = []
var _wander_points: Array[Vector3] = []
var _bartender: PatronFigure
var _bar_x := Vector2(12.4, 23.6)
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = crowd_seed
	var seats: Array[Node3D] = []
	var staff: Node3D = null
	var band: Array[Node3D] = []
	for s in $Spots.get_children():
		var pose: String = s.get_meta("pose", "")
		match pose:
			"sit": seats.append(s)
			"staff": staff = s
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
		var f := _spawn(presets[n % presets.size()], "Patron%d_%s" % [n, s.name])
		f.position = s.position + Vector3(0, float(s.get_meta("seat_h", PatronFigure.SEAT_H)) - PatronFigure.SEAT_H * FIG_SCALE, 0)
		f.rotation.y = s.rotation.y
		f.play("sit")
		n += 1
	for s in band:
		var b: Array = BAND[s.get_meta("pose")]
		var f := _spawn(b[0], "Band_" + str(b[0]))
		f.position = s.position + Vector3(0, float(s.get_meta("seat_h", 0.0)) - (PatronFigure.SEAT_H * FIG_SCALE if b[1] == "sit" else 0.0), 0)
		f.rotation.y = s.rotation.y
		f.play(b[1])
	if staff:
		_bartender = _spawn("nam", "Bartender")
		_bartender.position = staff.position
		_bartender.rotation.y = staff.rotation.y
		_bartender.set_meta("pace", 0.0)
	for i in mini(wanderer_count, _wander_points.size()):
		var f := _spawn("server" if i == 0 else presets[n % presets.size()], "Server" if i == 0 else "Wanderer%d" % i)
		f.position = _wander_points[(i * 2) % _wander_points.size()]
		if i == 0:   # the server starts in the aisle with the tray (renders 05/06)
			for wp in _wander_points:
				if wp.distance_to(SERVER_START) < f.position.distance_to(SERVER_START):
					f.position = wp
		_wanderers.append({"fig": f, "path": PackedVector3Array(), "idx": 0, "wait": _rng.randf_range(0.5, 4.0)})
		n += 1

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _spawn(preset: String, nm: String) -> PatronFigure:
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
	}
	f.scale = Vector3.ONE * FIG_SCALE
	add_child(f)
	figures.append(f)
	return f

func _process(delta: float) -> void:
	_walk_wanderers(delta)
	_pace_bartender(delta)

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
