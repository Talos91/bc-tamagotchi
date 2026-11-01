extends SceneTree
## Headless smoke test of the start screen and exit shot (BACKLOG B8, scripts/start_screen.gd, scripts/exit_shot.gd),
## from main.tscn with `intro` on:
##   title    the street front is built and lit (neon sign and foliage), the still camera is current and aimed at the
##            door, only "Tap to enter" is on screen (English and Thai), no visit, HUD hidden, session suspended
##   entry    a tap: the camera eases to over the shoulder (behind, to the right, above the head) before the door
##            opens; the door swings open for the character; the camera follows through the doorway; the pull-back
##            to the diorama camera starts while the door is closing; no cut (camera speed stays bounded); the street
##            goes dark, the visit starts, the HUD fades in, the door ends shut, lights back to the venue's own,
##            the player at the spawn and walking again; about 4 to 6.5 s
##   exit     leaving: the street shot plays before the walk-out card (street lit, its camera current, no HUD, no
##            card yet), the door opens, the character ends outside on the pavement, the door shuts, then the card;
##            back inside: street dark, diorama camera, lights back to the venue's own
##   skips    a second tap mid-entry lands at the end at once, door shut; a tap during the exit shot opens the card
##   off      without `intro` (as every other suite) main.tscn starts straight in the venue and leaving opens the card
##            at once
##   godot --headless --path . --script res://tests/smoke_start.gd

const StartScreen = preload("res://scripts/start_screen.gd")
const ExitShot = preload("res://scripts/exit_shot.gd")

var needs: Node
var fails: Array[String] = []
## Engine delta of the current frame. The SceneTree script's _process runs first, then process_frame is emitted, and
## only then the nodes move: a sample taken after `await process_frame` sees the camera as the PREVIOUS frame left
## it, moved by the previous frame's delta (kept in the entry loop as `moved_by`).
var frame_delta := 0.0


func _process(delta: float) -> bool:
	frame_delta = delta
	return false


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
	check(street.get_node_or_null("NeonSign") != null and street.get_node_or_null("Foliage_foliage_glow") != null, "neon sign on red-lit foliage over the door")
	check(root.get_viewport().get_camera_3d() == ss.cam, "start camera is current")
	var to_door: Vector3 = Vector3(street.face_x, 1.8, street.door_center.z) - ss.cam.global_position
	check((-ss.cam.global_basis.z).dot(to_door.normalized()) > 0.95, "start camera looks at the door")
	check(not needs.visit_active, "visit not started on the start screen")
	check(not main.hud.visible and not main.get_node("UI/Joystick").visible, "HUD and joystick hidden")
	check(main.session.process_mode == Node.PROCESS_MODE_DISABLED, "session (band, sit minute) suspended")
	check(not main.player.visible and not main.player.input_enabled, "character out of sight, no walking")
	var en_tap := StartScreen.text_for("venue.start.tap")
	TranslationServer.set_locale("th")
	var th_tap := StartScreen.text_for("venue.start.tap")
	TranslationServer.set_locale("en")
	check(en_tap == "Tap to enter", "English: %s" % en_tap)
	check(th_tap != "venue.start.tap" and th_tap.unicode_at(0) >= 0x0E00 and th_tap.unicode_at(0) <= 0x0E7F, "Thai: %s" % th_tap)
	var labels := []
	for n in _all(ss._layer, []):
		if n is Label and (n as Label).is_visible_in_tree() and n.name != "VersionLabel":  # the build version is not a title
			labels.append((n as Label).text)
	check(labels == [en_tap], "only the prompt on screen, no title: %s" % [labels])
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
	var shoulder_before_door := false
	var door_seen_open := false
	var open_at_pull := -1.0
	var max_speed := 0.0   # per frame: step over the engine delta that produced it
	var max_step := 0.0   # largest displacement in a single frame, whatever its length
	var moved_by := 0.0   # engine delta of the frame before this sample: what moved the camera since the last one
	var last_pos: Vector3 = ss_cam.global_position
	while is_instance_valid(main.start_screen) and Time.get_ticks_msec() - t0 < 12000:
		await process_frame
		var step_delta := moved_by
		moved_by = frame_delta
		var open: float = doors.openness("StreetDoor")
		max_open = maxf(max_open, open)
		var pp: Vector3 = main.player.global_position
		if is_instance_valid(ss_cam):
			var c := ss_cam.global_position
			if not door_seen_open and open > 0.05:
				door_seen_open = true
				shoulder_before_door = c.x < pp.x - 0.8 and c.z - pp.z > 0.15 and absf(c.y - StartScreen.FOLLOW_H) < 0.1
				print("  door starts opening: camera %s, character %s" % [c.snapped(Vector3.ONE * 0.01), pp.snapped(Vector3.ONE * 0.01)])
			var step := c.distance_to(last_pos)
			max_step = maxf(max_step, step)
			if step_delta > 0.0:
				max_speed = maxf(max_speed, step / step_delta)
			last_pos = c
		if is_instance_valid(ss) and ss.phase == StartScreen.Phase.PULL:
			if not saw_pull:
				open_at_pull = open
			saw_pull = true
		if is_instance_valid(ss_cam) and ss_cam.global_position.x > street.face_x + 0.2 and ss_cam.global_position.y > 1.4 and ss_cam.global_position.y < 2.2:
			cam_inside = true   # through the doorway (lintel 2.3 m) just above the character's head
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	check(not is_instance_valid(main.start_screen), "sequence ends (%.1f s)" % secs)
	check(secs >= 4.0 and secs <= 6.5, "about 4 to 6 s: %.1f s" % secs)
	check(saw_pull, "camera pulls back to the diorama camera")
	check(shoulder_before_door, "camera over the shoulder before the door opens")
	check(open_at_pull > 0.05 and open_at_pull < 0.99, "pull-back starts while the door closes (door %.2f open)" % open_at_pull)
	# Speed per frame is the step over the engine delta that made it, so a frame hitch (a long delta, a long step) leaves
	# it unchanged; wall-clock time between samples did not, and read 13 to 14.6 m/s now and then. The camera tops out
	# near 8 m/s; a cut (1 m in one frame) reads 60 m/s at 60 fps or more.
	check(max_speed < 12.0, "no cut: camera speed at most %.1f m/s (biggest step %.2f m)" % [max_speed, max_step])
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

	print("exit")
	main._on_leave()
	await process_frame
	var xs: Node = main.exit_shot
	check(xs != null and not is_instance_valid(main.walk_out), "leaving plays the exit shot first, no card yet")
	t0 = Time.get_ticks_msec()
	while is_instance_valid(xs) and xs.phase == ExitShot.Phase.DIP_OUT and Time.get_ticks_msec() - t0 < 2000:
		await process_frame
	check(street.visible and _visible_lights() == inside + 2, "street lit again: %d lights" % _visible_lights())
	check(root.get_viewport().get_camera_3d() == xs.cam, "street camera current")
	check(not main.hud.visible, "HUD hidden in the exit shot")
	max_open = 0.0
	var shut_before_card := false
	var player_out := Vector3.ZERO
	while is_instance_valid(main.exit_shot) and Time.get_ticks_msec() - t0 < 10000:
		max_open = maxf(max_open, doors.openness("StreetDoor"))
		player_out = main.player.global_position
		shut_before_card = doors.openness("StreetDoor") < 0.01
		await process_frame
	secs = (Time.get_ticks_msec() - t0) / 1000.0
	check(not is_instance_valid(main.exit_shot), "exit shot ends (%.1f s)" % secs)
	check(secs >= 2.5 and secs <= 6.0, "a short shot: %.1f s" % secs)
	check(max_open > 0.9, "door swung open to let them out (%.2f)" % max_open)
	check(player_out.x < street.face_x - 1.0, "character ends out on the pavement %s" % player_out.snapped(Vector3.ONE * 0.01))
	check(shut_before_card, "door shut behind them before the card")
	check(is_instance_valid(main.walk_out) and main.walk_out.showing == "summary", "then the walk-out card")
	check(not street.visible and _visible_lights() <= inside, "street dark again, lights %d" % _visible_lights())
	check(root.get_viewport().get_camera_3d() == main.player.rig.camera, "diorama camera behind the card")

	print("exit skip")
	main._go_out()
	await _frames(3)
	check(needs.visit_active and not is_instance_valid(main.walk_out), "GO OUT: next visit")
	main._on_leave()
	await _wait(0.6)
	main.exit_shot.tap()
	await process_frame
	check(not is_instance_valid(main.exit_shot) and is_instance_valid(main.walk_out), "a tap skips to the card")
	await _frames(3)
	check(doors.openness("StreetDoor") < 0.01 and not street.visible, "door shut, street dark after the skip")
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
	main._on_leave()
	await process_frame
	check(main.exit_shot == null and is_instance_valid(main.walk_out), "leaving opens the card at once, as before")
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
