class_name TouchJoystick
extends Control
## Touch joystick stub, bottom-left. `value` is a Vector2 in -1..1 (y down, like the keyboard axes).
## Works with the mouse too: project.godot emulates touch from mouse.

const RADIUS := 90.0

var value := Vector2.ZERO
var _touch := -1
var _knob := Vector2.ZERO

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1:
			_touch = event.index
			_update(event.position)
		elif not event.pressed and event.index == _touch:
			_touch = -1
			_knob = Vector2.ZERO
			value = Vector2.ZERO
			queue_redraw()
		accept_event()
	elif event is InputEventScreenDrag and event.index == _touch:
		_update(event.position)
		accept_event()

func _update(local: Vector2) -> void:
	_knob = (local - size * 0.5).limit_length(RADIUS)
	value = _knob / RADIUS
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, RADIUS, Color(1, 1, 1, 0.08))
	draw_arc(c, RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.3), 2.0)
	draw_circle(c + _knob, 32.0, Color(1.0, 0.3, 0.3, 0.5))
