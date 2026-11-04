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

## World direction (flat, unit) the player moved over `n` physics frames.
func heading(p: Player, n: int) -> Vector3:
	var a := p.global_position
	await frames(n)
	var d := p.global_position - a
	d.y = 0.0
	return d.normalized() if d.length() > 0.05 else Vector3.ZERO

## Owner item 17, rolled back by Daniele 2026-11-04 (the fixed axis was "very hard to manoeuvre"): the stick is
## camera-relative again (Player.ControlFrame.CAMERA), latched for the length of a press. A drag "up" is held in the
## lobby (camera yaw 0), the player is moved to the main room (yaw -90) and then to the bar (yaw 180) with the finger
## still down: the walk keeps its world direction (the latch). After the finger lifts, a new drag up walks screen-up of
## the bar camera. The fixed frames (the one-line switch) still ignore the camera, CAMERA follows it.
func fixed_axis(p: Player, start: Vector2) -> void:
	var rig := p.rig
	var frame := Player.control_frame
	check(frame == Player.ControlFrame.CAMERA, "the stick is camera-relative by default (%s)" % Player.ControlFrame.keys()[frame])
	p.walking_to = false
	p.global_position = Vector3(1.5, 0.05, 9.5)   # lobby
	rig.snap()
	await frames(5)
	var yaw0 := rig.yaw
	touch(0, start, true)
	var pos := start
	for i in 6:
		pos += Vector2(0, -15)
		drag(0, pos, Vector2(0, -15))
	var h0: Vector3 = await heading(p, 20)
	var cy0 := p.control_yaw()
	var want := Basis(Vector3.UP, cy0) * Vector3(0, 0, -1)
	check(h0.dot(want) > 0.97, "drag up in the lobby walks screen-up of the lobby camera (%s, want %s)" % [h0, want])
	var seen := [rad_to_deg(yaw0)]
	for spot in [Vector3(26.0, 0.05, 8.5), Vector3(30.0, 0.05, 10.8)]:   # main room floor, then the bar
		p.global_position = spot
		rig.snap()
		await frames(3)
		seen.append(rad_to_deg(rig.yaw))
		var h: Vector3 = await heading(p, 20)
		check(absf(angle_difference(rig.yaw, yaw0)) > deg_to_rad(45.0), "  the camera turned (yaw %.0f -> %.0f)" % [rad_to_deg(yaw0), rad_to_deg(rig.yaw)])
		check(h.dot(h0) > 0.97, "  the held drag walks the same world way at (%.0f, %.0f): %s vs %s" % [spot.x, spot.z, h, h0])
		check(absf(angle_difference(p.control_yaw(), cy0)) < 0.001, "  the press keeps its latched yaw while the camera turns (%.0f)" % rad_to_deg(p.control_yaw()))
	touch(0, pos, false)
	await frames(30)
	# A fresh drag after the swing follows the new camera: screen-up of the bar view
	p.global_position = Vector3(30.0, 0.05, 10.8)   # back on the open floor in front of the bar
	rig.snap()
	await frames(3)
	touch(0, start, true)
	pos = start
	for i in 6:
		pos += Vector2(0, -15)
		drag(0, pos, Vector2(0, -15))
	var h2: Vector3 = await heading(p, 10)
	var up2 := Basis(Vector3.UP, rig.yaw) * Vector3(0, 0, -1)
	check(h2.dot(up2) > 0.97, "a new drag up under the bar camera (yaw %.0f) walks screen-up of that camera: %s (want %s)" % [rad_to_deg(rig.yaw), h2, up2])
	touch(0, pos, false)
	await frames(20)
	# The switch: CAMERA follows the camera's yaw, the fixed frames do not
	for f in [Player.ControlFrame.VENUE_NORTH, Player.ControlFrame.FIRST_CAMERA, Player.ControlFrame.MAIN_ROOM]:
		Player.control_frame = f
		var a := p.input_to_world(Vector2(0, -1))
		var saved := rig.yaw
		rig.yaw = saved + 1.3
		var b := p.input_to_world(Vector2(0, -1))
		rig.yaw = saved
		check(a.distance_to(b) < 0.001, "frame %s ignores the camera yaw" % Player.ControlFrame.keys()[f])
	Player.control_frame = Player.ControlFrame.CAMERA
	var c0 := p.input_to_world(Vector2(0, -1))
	rig.yaw += 1.3
	var c1 := p.input_to_world(Vector2(0, -1))
	rig.yaw -= 1.3
	check(c0.distance_to(c1) > 0.5, "frame CAMERA (the old stick) follows the camera yaw")
	Player.control_frame = frame
	print("  camera yaws seen: ", seen)

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

	# 7. stick frame (owner item 17, fixed axis rolled back 11-04): camera-relative, a held drag keeps its way through a swing
	await fixed_axis(p, start)

	print("test_touch: ", "PASS" if failed == 0 else "FAIL (%d)" % failed)
	quit(1 if failed else 0)
