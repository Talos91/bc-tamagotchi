extends SceneTree
## Owner list 2026-11-20 item 6: "on my phone i cannot scroll" (Tonight, the calendar, menus, lists). Real touches
## through Input (InputEventScreenTouch + InputEventScreenDrag, mapped through root.get_final_transform(), the mouse
## emulated from them as on a phone) on every scrollable panel: a drag that starts on a card or a button scrolls the
## list (scripts/ui/touch_scroll.gd), does not press what it started on, and a tap still presses.
##   godot --headless --path . --script res://tests/test_touch_scroll.gd

var _fails := 0
var main: Node


func _check(label: String, ok: bool) -> void:
	print(("ok   " if ok else "FAIL ") + label)
	if not ok:
		_fails += 1


func _init() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://test_touch_scroll_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 60:
		await process_frame
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	for i in 5:
		await process_frame
	_check("TouchScroll autoload present", root.get_node_or_null("TouchScroll") != null)

	# Tonight: lineup, then every other tab it has (the monthly calendar)
	main.open_tonight()
	await _settle()
	await _drag_panel("tonight", main.tonight)
	for tb in main.tonight.find_children("*", "BaseButton", true, false):
		if tb.is_visible_in_tree() and str(tb.name).to_lower().contains("tab"):
			await _tap(tb)
			await _settle()
			await _drag_panel("tonight tab " + str(tb.name), main.tonight)
	main.tonight.closed.emit()
	await _settle()

	# The real menu (drinks and kitchen)
	for t in ["drinks", "kitchen"]:   # bundles is one screen long
		main.open_menu(t)
		await _settle()
		await _drag_panel("menu " + t, main.menu_list)
		main.close_menu()
		await _settle()

	# a tap on a menu row still orders it
	main.open_menu("drinks")
	await _settle()
	var chosen := [""]
	main.menu_list.item_chosen.connect(func(id): chosen[0] = id)
	var row := _stop_control_in(_scroll_of(main.menu_list), 0.3, true)
	_check("menu: a row to tap", row != null)
	if row != null:
		await _tap(row)
		await _settle()
		_check("menu: a tap on a row still orders it (%s)" % chosen[0], chosen[0] != "")
	main.close_menu()
	await _settle()

	# The character creator (photo booth)
	main.open_creator()
	await _settle()
	await _drag_panel("creator", main.creator)
	main.close_creator()
	await _settle()

	print("TEST TOUCH SCROLL ", "PASS" if _fails == 0 else "FAIL")
	quit(0 if _fails == 0 else 1)


func _settle() -> void:
	for i in 8:
		await process_frame


## The panel's scrollable ScrollContainer (the first visible one with something to scroll).
func _scroll_of(panel: Node) -> ScrollContainer:
	if panel == null:
		return null
	for sc: ScrollContainer in panel.find_children("*", "ScrollContainer", true, false):
		var vb := sc.get_v_scroll_bar()
		if sc.is_visible_in_tree() and vb.max_value - vb.page > 40.0:
			return sc
	return null


## A MOUSE_FILTER_STOP control inside the scroll's visible area, about `frac` down it (a card, a row, a button).
func _stop_control_in(sc: ScrollContainer, frac: float, button := false) -> Control:
	if sc == null:
		return null
	var view := Rect2(sc.get_global_transform_with_canvas().origin, sc.size * sc.get_global_transform_with_canvas().get_scale())
	var best: Control = null
	var best_d := INF
	var aim := view.position + Vector2(view.size.x * 0.5, view.size.y * frac)
	for c: Control in sc.find_children("*", "Control", true, false):
		if not c.is_visible_in_tree() or c.mouse_filter != Control.MOUSE_FILTER_STOP or (button and not c is BaseButton):
			continue
		var r := Rect2(c.get_global_transform_with_canvas().origin, c.size * c.get_global_transform_with_canvas().get_scale())
		if not view.encloses(r) or r.size.y < 20.0:
			continue
		var d := r.get_center().distance_to(aim)
		if d < best_d:
			best_d = d
			best = c
	return best


func _drag_panel(label: String, panel: Node) -> void:
	var sc := _scroll_of(panel)
	_check("%s: has a scrollable list" % label, sc != null)
	if sc == null:
		return
	var on := _stop_control_in(sc, 0.75)
	_check("%s: a card / button under the finger (%s)" % [label, on.get_class() if on else "none"], on != null)
	if on == null:
		return
	var pressed := [false]
	var btn: BaseButton = on as BaseButton
	var p := on.get_parent()
	while btn == null and p != null and p != sc:
		btn = p as BaseButton
		p = p.get_parent()
	if btn != null:
		btn.pressed.connect(func(): pressed[0] = true)
	var start: Vector2 = on.get_global_transform_with_canvas() * (on.size * 0.5)
	var before := sc.scroll_vertical
	var travel := sc.size.y * sc.get_global_transform_with_canvas().get_scale().y * 0.4
	await _swipe(start, start - Vector2(0, travel))
	_check("%s: drag up from a %s scrolls the list (%d -> %d)" % [label, on.get_class(), before, sc.scroll_vertical], sc.scroll_vertical > before + 60)
	if btn != null:
		_check("%s: the drag did not press the %s it started on" % [label, btn.get_class()], not pressed[0])
	var mid := sc.scroll_vertical
	await _swipe(start - Vector2(0, travel), start)
	for i in 30:
		await process_frame
	_check("%s: drag down scrolls back (%d -> %d)" % [label, mid, sc.scroll_vertical], sc.scroll_vertical < mid - 60)


## A finger from `a` to `b` (canvas coords) in 10 moves, as a phone sends it.
func _swipe(a: Vector2, b: Vector2) -> void:
	var xf := root.get_final_transform()
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.pressed = true
	t.position = xf * a
	Input.parse_input_event(t)
	Input.flush_buffered_events()
	await process_frame
	var last: Vector2 = xf * a
	for i in range(1, 11):
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = xf * a.lerp(b, i / 10.0)
		d.relative = d.position - last
		last = d.position
		Input.parse_input_event(d)
		Input.flush_buffered_events()
		await process_frame
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.pressed = false
	u.position = last
	Input.parse_input_event(u)
	Input.flush_buffered_events()
	await process_frame


func _tap(ctrl: Control) -> void:
	var at: Vector2 = root.get_final_transform() * (ctrl.get_global_transform_with_canvas() * (ctrl.size * 0.5))
	for down in [true, false]:
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.pressed = down
		t.position = at
		Input.parse_input_event(t)
		Input.flush_buffered_events()
		await process_frame
	await process_frame
