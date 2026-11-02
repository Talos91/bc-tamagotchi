class_name TouchJoystick
extends Control
## Touch-anywhere stick (owner feedback 2026-11-02, item 13). Fills the screen under the HUD: a touch that lands on
## empty play area (the HUD's buttons and cards sit above and take their own touches) is the stick's centre, and
## dragging from it gives `value`, a Vector2 in -1..1 (y down, like the keyboard axes), the same curve as the old
## fixed stick (RADIUS pixels = full speed). Releasing zeroes it. A touch that stays within Player.TAP_MAX_MOVE is not
## a drag: it is left alone and falls through to the player's tap-to-walk. Nothing is drawn unless `debug_ring` is set.
## Works with the mouse too: project.godot emulates touch from mouse.

const RADIUS := 90.0
const DRAG_START := 24.0   ## pixels before a touch becomes a stick (equals Player.TAP_MAX_MOVE)

static var debug_ring := false   ## faint ring and knob at the stick, for tuning only

var value := Vector2.ZERO
var _touch := -1
var _centre := Vector2.ZERO
var _knob := Vector2.ZERO
var _active := false   ## the touch has travelled past DRAG_START: it is a stick now

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS   # never accept_event(): a tap still reaches Player._unhandled_input
	visibility_changed.connect(func(): if not is_visible_in_tree(): _release())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1:
			_touch = event.index
			_centre = event.position
			_active = false
		elif not event.pressed and event.index == _touch:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch:
		var d: Vector2 = event.position - _centre
		if not _active and d.length() > DRAG_START:
			_active = true
		if _active:
			_knob = d.limit_length(RADIUS)
			value = _knob / RADIUS
			queue_redraw()

func _release() -> void:
	_touch = -1
	_active = false
	_knob = Vector2.ZERO
	value = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	if not (debug_ring and _touch != -1):
		return
	draw_arc(_centre, RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.18), 2.0)
	draw_circle(_centre + _knob, 24.0, Color(1.0, 0.3, 0.3, 0.25))
