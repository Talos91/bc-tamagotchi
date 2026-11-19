extends SceneTree
## Real-window screenshots for presence wave 1, client side (not a pass/fail test), with "Fake presences":
## 1 the venue with live patrons (LIVE badge, floor ring), 2 a live patron's card, 3 the reactions (a wave sent: bubbles
## over both, the card's status; the phrase wheel open), 4 the start-screen inbox, 5 the check-in consent card,
## 6 the check-in result. Run on the hidden desktop only (PROJECT.md Tests, 2026-11-15):
##   godot --path . --resolution 1080x1920 --script res://tests/capture_presence_client.gd -- <out dir> <suffix>

const PresenceClient = preload("res://scripts/presence_ui/presence_client.gd")
const Avatar = preload("res://scripts/avatar.gd")

var out_dir := "res://../docs/art/screens/presence-client"
var suffix := "portrait"
var needs: Node


func _initialize() -> void:
	var rest: Array = []
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			rest.append(a)
	if rest.size() > 0:
		out_dir = rest[0]
	if rest.size() > 1:
		suffix = rest[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir).path_join("%s-%s.png" % [name, suffix])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


## A floor point 1.3 m from a figure toward the room's aisle (on the navmesh).
func _beside(f: Node3D) -> Vector3:
	var p := f.global_position + Vector3(1.3, 0, 1.3)
	var map := f.get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map, Vector3(p.x, 0.0, p.z)) + Vector3(0, 0.1, 0)


func _on_screen(pat: Node) -> int:
	var cam := root.get_viewport().get_camera_3d()
	var r := root.get_viewport().get_visible_rect()
	var n := 0
	for id in pat.presences:
		var b: Vector3 = pat.presences[id].global_position + Vector3(0, 1.1, 0)
		if not cam.is_position_behind(b) and r.has_point(cam.unproject_position(b)):
			n += 1
	return n


func _run() -> void:
	await process_frame
	needs = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_presence_save.json"
	needs.new_game()
	needs.set_avatar(Avatar.default_record(), "Dan", "")
	for m in needs.meters:
		needs.meters[m] = 60.0
	needs.profile["presence_mode"] = "everyone"
	var fake: Variant = PresenceClient.use_fake()
	PresenceClient.set_pending_code("")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.2)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	var pat: Node = main.get_node("Venue/Patrons")
	# The tablemate (Mai) and her table: stand the player beside it
	var target_id := "fake-00"
	if not pat.presences.has(target_id):
		target_id = pat.presences.keys()[0]
	# Stand beside each presence in turn; keep the spot whose game camera shows the most of them
	var best_n := -1
	var best_at := Vector3.ZERO
	for id in pat.presences:
		var at: Vector3 = _beside(pat.presences[id])
		main.player.global_position = at
		main.player.rig.snap()
		await _wait(0.6)
		var n := _on_screen(pat)
		if n > best_n:
			best_n = n
			best_at = at
			target_id = id
	main.player.global_position = best_at
	main.player.rig.snap()
	await _wait(1.5)
	print("badge shot: %d presences on screen" % _on_screen(pat))
	await _shot("1-badge")
	# Close-up for review: a camera over the presence's shoulder distance (not a game camera)
	var f: Node3D = pat.presences[target_id]
	var game_cam := root.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 45.0
	main.add_child(cam)
	cam.look_at_from_position(f.global_position + Vector3(2.2, 2.0, 2.2), f.global_position + Vector3(0, 0.8, 0))
	cam.make_current()
	await _wait(0.4)
	await _shot("1b-badge-closeup")
	cam.queue_free()
	game_cam.make_current()
	await _wait(0.3)
	var taps: Node = null
	for c in root.get_children():
		if c.get_script() == preload("res://scripts/presence_ui/presence_taps.gd"):
			taps = c
	var card: Control = taps.open_card(target_id)
	await _wait(0.6)
	await _shot("2-card")
	card.buttons["wave"].pressed.emit()
	await _wait(0.35)
	await _shot("3a-wave-sent")
	card.buttons["phrase"].pressed.emit()
	await _wait(0.4)
	await _shot("3b-phrase-wheel")
	card.close()
	main.queue_free()
	await _wait(0.5)
	# Start screen: the inbox
	fake = PresenceClient.use_fake()
	main = load("res://scenes/main.tscn").instantiate()
	main.intro = true
	root.add_child(main)
	await _wait(1.5)
	await _shot("4a-start-inbox-button")
	main.start_screen.open_inbox()
	await _wait(0.5)
	await _shot("4b-inbox")
	main.queue_free()
	await _wait(0.5)
	# Check-in from a table code, first time (consent)
	fake = PresenceClient.use_fake()
	needs.profile.erase("presence_mode")
	PresenceClient.set_pending_code("TESTTABLE2")
	main = load("res://scenes/main.tscn").instantiate()
	main.intro = true
	root.add_child(main)
	await _wait(1.5)
	await _shot("5-checkin-consent")
	var flow: Node = main.start_screen._modal.find_child("CheckInFlow", true, false)
	flow.choose("everyone")
	await _wait(0.3)
	await _shot("5b-consent-chosen")
	flow.find_child("CheckIn", true, false).pressed.emit()
	await _wait(0.5)
	await _shot("6-checkin-done")
	quit(0)
