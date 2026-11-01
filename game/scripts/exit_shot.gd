extends "res://scripts/street_shot.gd"
## Exit shot (Daniele 2026-11-02, docs/design/DECISIONS.md): leaving the club, before the walk-out totals card, a
## short shot from the street. A quick dip to black, then the start screen's still view (the opposite pavement, the
## door under the BLACK CABIN neon, street lights on): the street door swings open, the character steps out onto
## the pavement and stops, the door swings shut behind them, the neon stays lit; then main.gd shows the walk-out card
## as before. About 4 s; a tap skips straight to the card. Totals, rules and the card itself are unchanged.
##
## main.gd plays it when the visit ends because the player left (not idle, not debug), and only where the start
## screen is on (main.tscn running as the game, or `intro` set by a test). The character goes back to main's spawn
## with the diorama camera before the card opens; GO OUT starts the next visit from there, as before.

const DIP := 0.25            ## to black and back
const WALK := 1.7            ## from inside the lobby out onto the pavement
const OUT_X := 1.5           ## stop this far in front of the facade (outside the door's 1.2 m reach)
const OUT_Z := 0.5           ## a step to the side of the doorway
const LINGER := 0.4          ## after the door is shut
const LANDSCAPE_PITCH := 4.0 ## the still view tilted down a little in landscape so the character on the pavement is in
const LANDSCAPE_FOV := 60.0

enum Phase { DIP_OUT, OUT, DONE }

var phase := Phase.DIP_OUT
var summary: Dictionary = {}
var _t := 0.0
var _p0: Vector3
var _p1: Vector3
var _shut_t := -1.0
var _layer: CanvasLayer
var _black: ColorRect


func begin(m: Node, s: Dictionary) -> void:
	main = m
	summary = s
	_layer = CanvasLayer.new()
	_layer.name = "ExitShot"
	_layer.layer = 6
	main.add_child(_layer)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, DIP)
	tw.tween_callback(_on_black)
	tw.tween_property(_black, "color:a", 0.0, DIP)


## Under black: out to the street, the character just inside the closed door facing it.
func _on_black() -> void:
	if phase == Phase.DONE:
		return
	street = _street()
	street.set_on(true)
	_make_camera("ExitCamera")
	_place_exit_camera()
	var cz: float = street.door_center.z
	_p0 = Vector3(main._spawn.origin.x, 0.0, cz)
	_p1 = Vector3(street.face_x - OUT_X, 0.0, cz + OUT_Z)
	_take_player()
	main.player.visible = true
	_shut_door()
	_drive(_p0, -PI * 0.5, 0.0)
	phase = Phase.OUT
	_t = 0.0


func tap() -> void:
	skip()


func skip() -> void:
	if phase == Phase.DONE:
		return
	_finish()


func _process(delta: float) -> void:
	if phase != Phase.OUT:
		return
	_t += delta
	_place_exit_camera()
	var d := _p1 - _p0
	var yaw := atan2(d.x, d.z)
	_drive(_p0.lerp(_p1, leg(_t, WALK, 0.3, 0.5)), yaw, leg_speed(_t, WALK, 0.3, 0.5, d.length()))
	if _t > WALK and door_open() < 0.001:
		if _shut_t < 0.0:
			_shut_t = _t
		elif _t - _shut_t >= LINGER:
			_finish()
	elif _t > WALK + 4.0:   # the door never moved (no venue doors): don't hang
		_finish()


## The start screen's still view; in landscape a little lower and wider (the short frame would cut the character).
func _place_exit_camera() -> void:
	_place_view_camera()
	if not _portrait():
		cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(LANDSCAPE_PITCH), -PI * 0.5, 0)), cam.global_position)
		_set_fov(false, LANDSCAPE_FOV)


## Back inside, out of view: the street dark, the character at the spawn, the diorama camera; then the card.
func _finish() -> void:
	phase = Phase.DONE
	if street == null:
		street = _street()
	_shut_door()
	street.set_on(false)
	_give_back_player()
	main.player.input_enabled = false
	if is_instance_valid(_layer):
		_layer.queue_free()
	queue_free()
	main.end_exit_shot(summary)
