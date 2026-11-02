extends SceneTree
## Headless test: touch-anywhere control (owner feedback 2026-11-02, items 13 and 14). A headless viewport does not route
## GUI input, so `send` does what the viewport does: the topmost control under the touch (last in draw order, mouse
## filter not IGNORE) gets it; the stick layer (PASS) lets it fall through to Player._unhandled_input, any HUD control
## takes it for itself. A drag on empty play area moves the player and releasing stops it, a short
## tap still walks, a touch that starts on a HUD button is ignored by the stick, nothing fires while the stick is
## hidden (a minigame, menu or the start screen owns the input), and the area buttons slide away and come back.
##   godot --headless --path . --script res://tests/test_touch.gd

var failed := 0

func check(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c:
		failed += 1

var main: Node
var js: TouchJoystick

func send(e: InputEvent) -> void:
	var top: Control = null
	for c: Control in main.get_node("UI").find_children("*", "Control", true, false):
		if c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(e.position):
			top = c   # find_children is pre-order: later = drawn on top
	if top == js:
		js._gui_input(e)
		main.get_node("Player")._unhandled_input(e)

func touch(i: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = pos
	e.pressed = pressed
	send(e)

func drag(i: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = pos
	e.relative = rel
	send(e)

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var p: Player = main.get_node("Player")
	js = main.get_node("UI/Joystick")
	await frames(3)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	await process_frame
	var size := root.get_visible_rect().size
	var start := Vector2(size.x * 0.3, size.y * 0.55)

	# 1. drag on empty play area moves the player; the stick is centred where the finger landed
	check(not js.is_visible_in_tree() == false, "stick layer is live")
	var before := p.global_position
	touch(0, start, true)
	var pos := start
	for i in 6:
		pos += Vector2(0, 12)
		drag(0, pos, Vector2(0, 12))
	check(js.value.y > 0.5 and absf(js.value.x) < 0.1, "drag down gives a stick vector down: %s" % js.value)
	await frames(60)
	var moved := before.distance_to(p.global_position)
	check(moved > 0.5, "drag moves the player (%.2f m)" % moved)
	check(not p.walking_to, "a drag is not a tap-walk")
	# a longer drag saturates at 1
	for i in 10:
		pos += Vector2(0, 30)
		drag(0, pos, Vector2(0, 30))
	check(is_equal_approx(js.value.length(), 1.0), "stick is clamped to 1")

	# 2. release stops
	touch(0, pos, false)
	check(js.value == Vector2.ZERO, "release zeroes the stick")
	await frames(60)
	check(p.velocity.length() < 0.2, "release stops the player (speed %.2f)" % p.velocity.length())

	# 3. a short tap still walks (tap-to-walk), and does not start a stick
	p.walking_to = false
	var centre := size * 0.5
	touch(0, centre, true)
	touch(0, centre, false)
	await process_frame
	check(p.walking_to, "a short tap still starts a tap-walk")
	check(js.value == Vector2.ZERO, "a tap leaves the stick at zero")
	await frames(5)
	# a small jitter under the drag threshold is still a tap
	p.walking_to = false
	touch(0, centre, true)
	drag(0, centre + Vector2(10, 5), Vector2(10, 5))
	check(js.value == Vector2.ZERO, "movement under the drag threshold gives no stick")
	touch(0, centre + Vector2(10, 5), false)
	await process_frame
	check(p.walking_to, "a tap with a little jitter still walks")
	p.walking_to = false
	await frames(30)

	# 4. a touch that starts on a HUD button is ignored
	var area: Button = main.hud.find_child("Area_lounge", true, false)
	check(area != null and area.is_visible_in_tree(), "area button present")
	var on_btn := area.get_global_rect().get_center()
	touch(0, on_btn, true)
	drag(0, on_btn + Vector2(0, -70), Vector2(0, -70))
	drag(0, on_btn + Vector2(0, -140), Vector2(0, -70))
	check(js.value == Vector2.ZERO, "a drag that starts on a HUD button gives no stick")
	touch(0, on_btn + Vector2(0, -140), false)

	# 5. nothing fires while a minigame, menu or the start screen owns the input
	main.player.input_enabled = false
	var iv: Vector2 = p._input_vector()
	touch(0, start, true)
	drag(0, start + Vector2(60, 0), Vector2(60, 0))
	check(p._input_vector() == Vector2.ZERO, "stick has no effect while input is blocked")
	touch(0, start + Vector2(60, 0), false)
	main.player.input_enabled = true
	js.visible = false
	touch(0, start, true)
	drag(0, start + Vector2(60, 0), Vector2(60, 0))
	check(js.value == Vector2.ZERO, "hidden stick layer takes no touches")
	touch(0, start + Vector2(60, 0), false)
	js.visible = true
	# hiding mid-drag releases
	touch(0, start, true)
	drag(0, start + Vector2(60, 0), Vector2(60, 0))
	js.visible = false
	check(js.value == Vector2.ZERO, "hiding the layer mid-drag releases the stick")
	js.visible = true
	await process_frame

	# 6. the area buttons slide away and come back (owner item 14)
	var toggle: Button = main.hud.find_child("AreasToggle", true, false)
	var col: Control = main.hud.find_child("Areas", true, false)
	check(toggle != null and col != null and col.visible and main.hud.areas_shown(), "area buttons shown with a tab")
	var x0 := col.get_global_rect().position.x
	toggle.pressed.emit()
	await frames(30)
	check(not main.hud.areas_shown() and not col.visible, "pressing the tab hides the area buttons")
	check(col.get_global_rect().position.x > x0 + 50.0, "the column slid off to the right")
	check(toggle.is_visible_in_tree(), "the tab stays to bring them back")
	toggle.pressed.emit()
	await frames(30)
	check(main.hud.areas_shown() and col.visible and absf(col.get_global_rect().position.x - x0) < 2.0, "pressing again brings them back")
	toggle.pressed.emit()
	await frames(30)
	check(not main.hud.areas_shown(), "state kept (hidden) for the next press")
	toggle.pressed.emit()
	await frames(30)

	print("test_touch: ", "PASS" if failed == 0 else "FAIL (%d)" % failed)
	quit(1 if failed else 0)
