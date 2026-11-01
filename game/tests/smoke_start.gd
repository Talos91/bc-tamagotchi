extends SceneTree
## Headless smoke test of the start screen (BACKLOG B8, scripts/start_screen.gd), from main.tscn with `intro` on:
##   title    the street front is built and lit, the start camera is current, the title and "Tap to enter" read in
##            English and Thai, the visit has not begun, the HUD is hidden, the session does not process
##   entry    a tap walks the character in: the street door swings open for them, the camera hands over to the
##            diorama rig in the lobby, the street goes dark, the visit starts, the HUD fades in, the door ends shut,
##            the light count inside is back to the venue's own, the player stands at the spawn and can walk
##   skip     a second run: tap, then tap again mid-walk: everything lands at the end at once, door shut
##   off      without `intro` (as every other suite) main.tscn starts straight in the venue
##   godot --headless --path . --script res://tests/smoke_start.gd

const StartScreen = preload("res://scripts/start_screen.gd")

var needs: Node
var fails: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _init() -> void:
	await process_frame
	needs = root.get_node_or_null("Needs")
	needs.autosave = false
	var inside := await _venue_lights()
	needs.new_game()

	print("title")
	var main := await _main(true)
	var ss: Node = main.start_screen
	check(ss != null, "start screen runs")
	var street: Node3D = main.get_node_or_null("Street")
	check(street != null and street.visible and street.lights.size() == 2, "street front built, lit by %d lights" % (street.lights.size() if street else -1))
	check(street.get_node_or_null("NeonSign") != null, "the kit neon sign hangs over the door")
	check(root.get_viewport().get_camera_3d() == ss.cam, "start camera is current")
	var to_door: Vector3 = Vector3(street.face_x, 1.8, ss._cam0.z) - ss.cam.global_position
	check((-ss.cam.global_basis.z).dot(to_door.normalized()) > 0.95, "start camera looks at the door")
	check(not needs.visit_active, "visit not started on the start screen")
	check(not main.hud.visible and not main.get_node("UI/Joystick").visible, "HUD and joystick hidden")
	check(main.session.process_mode == Node.PROCESS_MODE_DISABLED, "session (band, sit minute) suspended")
	check(not main.player.visible and not main.player.input_enabled, "character out of sight, no walking")
	var en_title := StartScreen.text_for("venue.start.title")
	var en_tap := StartScreen.text_for("venue.start.tap")
	TranslationServer.set_locale("th")
	var th_tap := StartScreen.text_for("venue.start.tap")
	TranslationServer.set_locale("en")
	check(en_title == "BLACK CABIN" and en_tap == "Tap to enter", "English: %s / %s" % [en_title, en_tap])
	check(th_tap != "venue.start.tap" and th_tap.unicode_at(0) >= 0x0E00 and th_tap.unicode_at(0) <= 0x0E7F, "Thai: %s" % th_tap)
	check(ss._title.text == en_title and ss._prompt.text == en_tap, "title and prompt on screen")
	var lights_title := _visible_lights()
	print("  lights on the start screen: ", lights_title, " (venue alone ", inside, ")")
	check(lights_title <= 48, "start screen within max_renderable_lights 48")
	await _frames(20)
	check(not needs.visit_active, "still waiting after 20 frames")

	print("entry")
	var t0 := Time.get_ticks_msec()
	ss.tap()
	var ss_cam: Camera3D = ss.cam
	var saw_pull := false
	var cam_inside := false
	var doors: Node = main.get_node("Venue/Doors")
	var max_open := 0.0
	while is_instance_valid(main.start_screen) and Time.get_ticks_msec() - t0 < 12000:
		await process_frame
		max_open = maxf(max_open, doors.openness("StreetDoor"))
		if is_instance_valid(ss) and ss.phase == StartScreen.Phase.PULL:
			saw_pull = true
		if is_instance_valid(ss_cam) and ss_cam.global_position.x > street.face_x + 0.2 and ss_cam.global_position.y > 1.4 and ss_cam.global_position.y < 2.2:
			cam_inside = true   # through the doorway (lintel 2.3 m) just above the character's head
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	check(not is_instance_valid(main.start_screen), "sequence ends (%.1f s)" % secs)
	check(secs >= 4.0 and secs <= 6.5, "about 4 to 6 s: %.1f s" % secs)
	check(saw_pull, "camera pulls back to the diorama camera")
	check(cam_inside, "camera followed through the doorway at head height")
	check(max_open > 0.9, "street door swung open for the character (%.2f)" % max_open)
	check(needs.visit_active, "visit started")
	check(root.get_viewport().get_camera_3d() == main.player.rig.camera, "diorama camera current")
	check(main.player.rig.zone == "lobby", "lobby camera zone: %s" % main.player.rig.zone)
	check(not street.visible, "street hidden inside")
	await _wait(0.7)   # HUD fade 0.5 s, door shut
	check(main.hud.visible and main.hud.modulate.a > 0.99, "HUD visible (alpha %.2f)" % main.hud.modulate.a)
	check(main.get_node("UI/Joystick").visible, "joystick visible")
	check(doors.openness("StreetDoor") < 0.01, "street door shut (%.2f)" % doors.openness("StreetDoor"))
	var lights_in := _visible_lights()
	check(lights_in <= inside and lights_in <= 42, "lights inside %d (venue alone %d, budget 42)" % [lights_in, inside])
	var sp: Vector3 = main._spawn.origin
	check(Vector2(main.player.global_position.x - sp.x, main.player.global_position.z - sp.z).length() < 0.2, "player at the lobby spawn %s" % main.player.global_position.snapped(Vector3.ONE * 0.01))
	check(main.player.input_enabled and main.player.is_physics_processing(), "player walks again")
	check(main.session.process_mode == Node.PROCESS_MODE_INHERIT, "session processing")
	main.queue_free()
	await _frames(3)

	print("skip")
	needs.new_game()
	main = await _main(true)
	ss = main.start_screen
	ss.tap()
	await _wait(0.6)
	t0 = Time.get_ticks_msec()
	ss.tap()
	await process_frame
	check(not is_instance_valid(main.start_screen), "second tap skips to the end")
	check(needs.visit_active, "visit started after skip")
	await _frames(3)
	doors = main.get_node("Venue/Doors")
	check(doors.openness("StreetDoor") < 0.01, "street door shut after skip (%.2f)" % doors.openness("StreetDoor"))
	await _wait(0.8)
	check(doors.openness("StreetDoor") < 0.01, "and stays shut")
	check(main.hud.visible and main.hud.modulate.a > 0.99, "HUD visible after skip")
	check(_visible_lights() <= inside, "lights inside after skip %d" % _visible_lights())
	main.queue_free()
	await _frames(3)

	print("off")
	needs.new_game()
	main = await _main(false)
	check(main.start_screen == null and main.get_node_or_null("Street") == null, "no start screen without intro")
	check(needs.visit_active, "visit starts at once, as before")
	main.queue_free()
	await _frames(3)

	print("SMOKE START ", "PASS" if fails.is_empty() else "FAIL (%d): %s" % [fails.size(), fails])
	quit(0 if fails.is_empty() else 1)


func _main(with_intro: bool) -> Node:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.intro = with_intro
	root.add_child(m)
	for i in 3:
		await process_frame
	return m


## Lights the venue alone shows (main.tscn without a start screen).
func _venue_lights() -> int:
	var m := await _main(false)
	await _frames(3)
	var n := _visible_lights()
	m.queue_free()
	await _frames(3)
	return n


func _visible_lights() -> int:
	var n := 0
	for l in _all(root, []):
		if l is Light3D and (l as Light3D).is_visible_in_tree():
			n += 1
	return n


func _all(n: Node, acc: Array) -> Array:
	acc.append(n)
	for c in n.get_children():
		_all(c, acc)
	return acc


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _wait(secs: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < secs * 1000.0:
		await process_frame
