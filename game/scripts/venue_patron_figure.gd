class_name PatronFigure
extends Node3D
## One person in the venue (player, patron, staff). `set_look(dict)` builds it:
##   {"preset": "patron_05"}           -> res://assets/chars/presets/patron_05.glb if it is imported (rigged, with
##                                        idle / walk / sit animations from tools/blender/bc_chars.py)
##   {"skin": Color, "hair": Color, "top": Color, "bottom": Color, "shoes": Color, "height": 1.3}
##                                     -> chibi box placeholder (head cube 40% of the height, art bible §7),
##                                        also the fallback when the preset is missing.
## `play("idle" | "walk" | "sit")` switches pose. Pivot at the feet, front +Z; seated figures expect a 0.45 m seat
## (the presets' sit pose puts the hips there). Idles breathe and turn the head now and then.
## To swap placeholders for the final characters, replace this scene; the venue only calls set_look() and play().

const PRESET_DIR := "res://assets/chars/presets/"
const SEAT_H := 0.45

var look := {}
var state := "idle"
var move_speed := 0.0            ## m/s, scales the walk cycle

var _model: Node3D
var _anim: AnimationPlayer
var _head_mod: HeadTurn
# Box placeholder parts
var _hips: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _leg_len := 0.33
var _t := 0.0
var _turn := 0.0
var _turn_goal := 0.0
var _next_turn := 0.0

## Turns the head bone of a preset on top of its animation.
class HeadTurn extends SkeletonModifier3D:
	var yaw := 0.0
	var bone := -1
	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk and bone >= 0:
			sk.set_bone_pose_rotation(bone, Quaternion(Vector3.UP, yaw) * sk.get_bone_pose_rotation(bone))

func _ready() -> void:
	_t = randf() * 10.0
	_next_turn = randf_range(2.0, 6.0)
	if _model == null:
		set_look(look)

func set_look(d: Dictionary) -> void:
	look = d
	if _model:
		remove_child(_model)
		_model.free()
	_model = null
	_anim = null
	_head_mod = null
	_legs.clear()
	_arms.clear()
	var preset: String = d.get("preset", "")
	var path := PRESET_DIR + preset + ".glb"
	if preset != "" and ResourceLoader.exists(path):
		var ps := load(path) as PackedScene
		if ps:
			_build_preset(ps)
	if _model == null:
		_build_boxes(d)
	play(state, true)

func is_preset() -> bool:
	return _anim != null

func play(s: String, force := false) -> void:
	if s == state and not force:
		return
	state = s
	if _anim:
		_anim.play(s if _anim.has_animation(s) else "idle", 0.25)
	elif _hips:
		_pose_boxes(0.0)

func _build_preset(ps: PackedScene) -> void:
	_model = ps.instantiate()
	_model.name = "Model"
	add_child(_model)
	var found := _model.find_children("*", "AnimationPlayer", true, false)
	if found.size() > 0:
		_anim = found[0]
		# Loop flags are not in the committed import settings
		for lib_name in _anim.get_animation_library_list():
			var lib := _anim.get_animation_library(lib_name)
			for a in lib.get_animation_list():
				lib.get_animation(a).loop_mode = Animation.LOOP_NONE if a == "cheers" else Animation.LOOP_LINEAR
	var sks := _model.find_children("*", "Skeleton3D", true, false)
	if sks.size() > 0:
		var sk: Skeleton3D = sks[0]
		for i in sk.get_bone_count():
			if sk.get_bone_name(i).begins_with("head"):
				_head_mod = HeadTurn.new()
				_head_mod.bone = i
				sk.add_child(_head_mod)
				break
	for mi in _model.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m

func _cube(parent: Node3D, size: Vector3, center: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _build_boxes(d: Dictionary) -> void:
	var h: float = d.get("height", 1.3)
	var skin: Color = d.get("skin", Color("d2a07a"))
	var hair: Color = d.get("hair", Color("3e2618"))
	var top: Color = d.get("top", Color("c99430"))
	var bottom: Color = d.get("bottom", Color("3f5878"))
	var shoes: Color = d.get("shoes", Color("d9c9a6"))
	var head_h := h * 0.4
	_leg_len = h * 0.25
	var torso_h := h - head_h - _leg_len
	_model = Node3D.new()
	_model.name = "Boxes"
	add_child(_model)
	_hips = Node3D.new()
	_hips.name = "Hips"
	_hips.position.y = _leg_len
	_model.add_child(_hips)
	_cube(_hips, Vector3(0.34, torso_h, 0.22), Vector3(0, torso_h * 0.5, 0), top)
	_cube(_hips, Vector3(0.35, 0.05, 0.23), Vector3(0, 0.03, 0), bottom)        # belt line
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(0.09 * side, 0, 0)
		_hips.add_child(leg)
		_cube(leg, Vector3(0.14, _leg_len - 0.06, 0.16), Vector3(0, -(_leg_len - 0.06) * 0.5, 0), bottom)
		_cube(leg, Vector3(0.15, 0.06, 0.2), Vector3(0, -_leg_len + 0.03, 0.02), shoes)
		_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(0.21 * side, torso_h - 0.04, 0)
		_hips.add_child(arm)
		_cube(arm, Vector3(0.09, torso_h * 0.8, 0.11), Vector3(0, -torso_h * 0.4, 0), top)
		_cube(arm, Vector3(0.08, 0.07, 0.09), Vector3(0, -torso_h * 0.8 - 0.03, 0), skin)
		_arms.append(arm)
	_head = Node3D.new()
	_head.name = "Head"
	_head.position.y = torso_h
	_hips.add_child(_head)
	var hw := head_h * 0.95
	_cube(_head, Vector3(hw, head_h, hw * 0.9), Vector3(0, head_h * 0.5, 0), skin)
	_cube(_head, Vector3(hw + 0.04, head_h * 0.3, hw * 0.9 + 0.04), Vector3(0, head_h * 0.87, -0.02), hair)
	_cube(_head, Vector3(hw + 0.04, head_h * 0.55, 0.08), Vector3(0, head_h * 0.62, -hw * 0.45 - 0.02), hair)
	for side in [-1.0, 1.0]:
		_cube(_head, Vector3(0.06, 0.09, 0.02), Vector3(0.1 * side, head_h * 0.45, hw * 0.45 + 0.005), Color("160b0a"))

## Procedural poses for the box placeholder (the presets carry their own animations).
func _pose_boxes(cycle: float) -> void:
	var seated := state == "sit"
	_hips.position.y = SEAT_H if seated else _leg_len
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		if seated:
			_legs[i].rotation.x = -PI * 0.5
			_arms[i].rotation.x = -0.6
		elif state == "walk":
			_legs[i].rotation.x = sin(cycle) * 0.55 * s
			_arms[i].rotation.x = -sin(cycle) * 0.5 * s
		else:
			_legs[i].rotation.x = 0.0
			_arms[i].rotation.x = 0.0

func _process(delta: float) -> void:
	_t += delta
	# Occasional head turn: pick a new glance every few seconds, ease toward it
	_next_turn -= delta
	if _next_turn <= 0.0:
		_turn_goal = 0.0 if absf(_turn_goal) > 0.01 else randf_range(-0.7, 0.7)
		_next_turn = randf_range(2.5, 7.0)
	_turn = lerpf(_turn, _turn_goal if state != "walk" else 0.0, 1.0 - exp(-3.0 * delta))
	if _anim:
		if _head_mod:
			_head_mod.yaw = _turn
		_anim.speed_scale = clampf(move_speed / 1.1, 0.6, 2.4) if state == "walk" else 1.0
	elif _hips:
		var cycle := _t * TAU * clampf(move_speed / 1.1, 0.8, 2.6) * 0.9
		_pose_boxes(cycle)
		var bob := sin(_t * TAU * 0.35) * 0.01          # breathing
		if state == "walk":
			bob = absf(sin(cycle)) * 0.04
		_hips.position.y += bob
		_head.rotation.y = _turn
