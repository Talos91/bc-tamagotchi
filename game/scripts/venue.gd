extends Node3D
## Runtime side of the generated venue (tools/build_venue.gd): puts the ceiling on render layer 2 (the diorama
## camera hides it), re-bakes the navmesh if the scene shipped without one, flickers tealights, turns the disco ball.

const CEILING_LAYER_MASK := 1 << 1

var _tealights: Array[Light3D] = []
var _base_energy: Array[float] = []
var _phase: Array[float] = []
var _rate: Array[float] = []
var _t := 0.0

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
