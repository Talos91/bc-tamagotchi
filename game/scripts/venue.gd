extends Node3D
## Runtime side of the generated venue (tools/build_venue.gd): puts the ceiling on render layer 2 (the diorama
## camera hides it), re-bakes the navmesh if the scene shipped without one, flickers tealights, turns the disco ball,
## and lifts the player's own colours so they read in the dark room.

const CEILING_LAYER_MASK := 1 << 1
## Look D, darker still (Daniele 2026-11-02: "the player must stay readable between candle pools"): every material of the
## player's figure also emits its own albedo at this energy, a hero light that costs no Light3D (budget 42) and lights
## nothing else. Patrons are not lifted, so the player stands out from the crowd.
const PLAYER_LIFT := 0.15

var _tealights: Array[Light3D] = []
var _base_energy: Array[float] = []
var _phase: Array[float] = []
var _rate: Array[float] = []
var _t := 0.0
var _player: Node3D
var _lifted := {}   # source material -> its lifted copy

@onready var _disco: Node3D = get_node_or_null("MainRoom/DiscoBall")

func _ready() -> void:
	for n in get_tree().get_nodes_in_group("ceiling"):
		if is_ancestor_of(n):
			_to_ceiling_layer(n)
	var region: NavigationRegion3D = $Navigation
	if region.navigation_mesh == null or region.navigation_mesh.get_polygon_count() == 0:
		region.bake_navigation_mesh(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1923
	for l in get_tree().get_nodes_in_group("tealight"):
		if is_ancestor_of(l):
			_tealights.append(l)
			_base_energy.append(l.light_energy)
			_phase.append(rng.randf() * TAU)
			_rate.append(rng.randf_range(1.0, 2.0))
	_find_player.call_deferred()

## The player (a Player sibling under the same main scene): lift its figure now and whenever it is rebuilt (set_look).
func _find_player() -> void:
	for n in get_parent().get_children():
		if n is Player:
			_player = n
	if _player == null:
		return
	_lift(_player)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	if n is GeometryInstance3D and is_instance_valid(_player) and _player.is_ancestor_of(n):
		_lift.call_deferred(n)

func _lift(n: Node) -> void:
	if not is_instance_valid(n):
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		if mi.material_override is BaseMaterial3D:
			mi.material_override = _lifted_copy(mi.material_override)
		else:
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i) as BaseMaterial3D
				if m and not _lifted.values().has(m):
					mi.set_surface_override_material(i, _lifted_copy(m))
	for c in n.get_children():
		_lift(c)

func _lifted_copy(m: BaseMaterial3D) -> BaseMaterial3D:
	if _lifted.values().has(m):
		return m
	if not _lifted.has(m):
		var r := m.duplicate() as BaseMaterial3D
		if not r.emission_enabled:
			r.emission_enabled = true
			r.emission = m.albedo_color
			r.emission_texture = m.albedo_texture
			r.emission_energy_multiplier = PLAYER_LIFT
		_lifted[m] = r
	return _lifted[m]

func _to_ceiling_layer(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = CEILING_LAYER_MASK
	for c in n.get_children():
		_to_ceiling_layer(c)

func _process(delta: float) -> void:
	_t += delta
	# Tealights flicker ±8% at 1-2 Hz (art bible §4); lamps stay steady
	for i in _tealights.size():
		var f := sin(_t * TAU * _rate[i] + _phase[i]) * 0.6 + sin(_t * TAU * _rate[i] * 2.3 + _phase[i] * 1.7) * 0.4
		_tealights[i].light_energy = _base_energy[i] * (1.0 + 0.08 * f)
	if _disco:
		_disco.rotate_y(delta * 0.35)
