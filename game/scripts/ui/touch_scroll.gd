extends Node
## Touch scrolling for every ScrollContainer in the game (autoload TouchScroll; owner list 2026-11-20 item 6: "on my
## phone i cannot scroll", Tonight, the calendar, menus, lists).
##
## Why the engine alone did not scroll (Godot 4.6, scroll_container.cpp + viewport.cpp): a ScrollContainer drags only
## from EMULATED MOUSE events that reach its own gui_input, only while DisplayServer.is_touchscreen_available(), and a
## press is delivered to the control under the finger and walks up to its parents only through MOUSE_FILTER_PASS
## controls. Every row, card, chip and button in our panels is MOUSE_FILTER_STOP (they take taps), so a drag that
## started on one never reached the ScrollContainer: the lists only scrolled from the thin gaps between cards.
##
## What this does, once for all panels: it sees the touch first (_input), finds the topmost visible ScrollContainer
## under the finger that has something to scroll, and after DEADZONE pixels of travel scrolls it with the finger and
## flings on release. The engine's own drag is switched off on every ScrollContainer (scroll_deadzone huge) so the two
## never fight; the mouse wheel still works. Once a drag scrolls, the control that took the press is told the pointer
## left it, and the rest of the drag is kept from it, so a drag over a button never presses it; a tap still does.
## Mouse drags work too (project.godot emulates touch from mouse). Check: tests/test_touch_scroll.gd.

const DEADZONE := 20.0          ## canvas pixels a touch travels before it is a scroll (a tap stays under it)
const FRICTION := 2600.0        ## px/s² a fling slows down by
const MIN_FLING := 240.0        ## px/s below which a release just stops
const ENGINE_DEADZONE := 1000000   ## given to every ScrollContainer: the engine's own drag never starts

var _all: Array[ScrollContainer] = []
var _target: ScrollContainer = null
var _index := -1
var _start := Vector2.ZERO
var _from := Vector2.ZERO        ## the target's (h, v) scroll at the press
var _scrolling := false
var _vel := Vector2.ZERO          ## content px/s, for the fling
var _last_t := 0
var _fling: ScrollContainer = null
var _fling_vel := Vector2.ZERO
var _leaving := false             ## our own "pointer left" motion is on its way: let it through


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	for n in get_tree().root.find_children("*", "ScrollContainer", true, false):
		_on_node_added(n)


func _on_node_added(n: Node) -> void:
	if n is ScrollContainer:
		var sc := n as ScrollContainer
		sc.scroll_deadzone = ENGINE_DEADZONE
		_all.append(sc)
		sc.tree_exited.connect(func(): _all.erase(sc), CONNECT_ONE_SHOT)


func is_scrolling() -> bool:
	return _scrolling


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _index == -1:
			_fling = null
			_target = scroll_at(event.position)
			if _target != null:
				_index = event.index
				_start = event.position
				_from = Vector2(_target.scroll_horizontal, _target.scroll_vertical)
				_scrolling = false
				_vel = Vector2.ZERO
				_last_t = Time.get_ticks_usec()
		elif not event.pressed and event.index == _index:
			if _scrolling and is_instance_valid(_target) and _vel.length() > MIN_FLING:
				_fling = _target
				_fling_vel = _vel
			_index = -1
			_target = null
			_scrolling = false
	elif event is InputEventScreenDrag and event.index == _index:
		if not is_instance_valid(_target) or not _target.is_visible_in_tree():
			_index = -1
			_target = null
			_scrolling = false
			return
		var d: Vector2 = event.position - _start
		var axis := _axes(_target)
		if not _scrolling and (absf(d.x) * axis.x > DEADZONE or absf(d.y) * axis.y > DEADZONE):
			_scrolling = true
			_start = event.position
			_from = Vector2(_target.scroll_horizontal, _target.scroll_vertical)
			_leave_pressed_control()
			d = Vector2.ZERO
		if _scrolling:
			var scale := _content_scale(_target)
			_set_scroll(_target, _from - d * scale * axis)
			var now := Time.get_ticks_usec()
			var dt := maxf((now - _last_t) / 1000000.0, 0.001)
			_vel = _vel.lerp(-(event.relative as Vector2) * scale * axis / dt, 0.5)
			_last_t = now
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _scrolling and not _leaving:
		get_viewport().set_input_as_handled()   # the emulated mouse of the same finger: the pressed control never sees it


func _process(delta: float) -> void:
	if _fling == null:
		return
	if not is_instance_valid(_fling) or not _fling.is_visible_in_tree():
		_fling = null
		return
	var before := Vector2(_fling.scroll_horizontal, _fling.scroll_vertical)
	_set_scroll(_fling, before + _fling_vel * delta)
	var sp := _fling_vel.length()
	sp = maxf(sp - FRICTION * delta, 0.0)
	_fling_vel = _fling_vel.normalized() * sp
	if sp < 1.0 or Vector2(_fling.scroll_horizontal, _fling.scroll_vertical) == before:
		_fling = null


## The topmost visible ScrollContainer under a canvas point that has something to scroll (null = none).
func scroll_at(pos: Vector2) -> ScrollContainer:
	var best: ScrollContainer = null
	var best_layer := -1000000
	for sc in _all:
		if not is_instance_valid(sc) or not sc.is_visible_in_tree() or _axes(sc) == Vector2.ZERO:
			continue
		var local: Vector2 = sc.get_global_transform_with_canvas().affine_inverse() * pos
		if not Rect2(Vector2.ZERO, sc.size).has_point(local):
			continue
		var layer := _layer(sc)
		if best == null or layer > best_layer or (layer == best_layer and sc.is_greater_than(best)):
			best = sc
			best_layer = layer
	return best


## 1 on each axis the container can scroll now (enabled and content longer than the view), else 0.
func _axes(sc: ScrollContainer) -> Vector2:
	var hb := sc.get_h_scroll_bar()
	var vb := sc.get_v_scroll_bar()
	var h := sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and hb.max_value - hb.page > 0.5
	var v := sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and vb.max_value - vb.page > 0.5
	return Vector2(1.0 if h else 0.0, 1.0 if v else 0.0)


func _set_scroll(sc: ScrollContainer, at: Vector2) -> void:
	sc.scroll_horizontal = int(round(at.x))
	sc.scroll_vertical = int(round(at.y))


## Canvas pixels to content pixels (a scaled panel scrolls with the finger).
func _content_scale(sc: ScrollContainer) -> float:
	var s := sc.get_global_transform_with_canvas().get_scale()
	return 1.0 / maxf(absf(s.y), 0.001)


func _layer(n: Node) -> int:
	var p := n
	while p != null:
		if p is CanvasLayer:
			return (p as CanvasLayer).layer
		p = p.get_parent()
	return 0


## The control that took the press (a card, a button) must not act on the release: tell it the pointer left it.
## BaseButton presses on release only while `pressing_inside`, which a mouse motion outside its rect clears.
func _leave_pressed_control() -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(-100000, -100000)
	mm.global_position = mm.position
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	_leaving = true
	get_viewport().push_input(mm)
	_leaving = false
