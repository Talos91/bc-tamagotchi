extends SceneTree
## Captures for the hub card overflow-seats-review (Daniele 2026-11-20): real check-ins past a table's seats, the
## viewer checked in tonight, "Fake presences". Not a pass/fail test. Phone portrait:
##   godot --path . --resolution 450x800 --script res://tests/capture_overflow_seats.gd -- --tag=phone
## Writes to docs/art/screens/overflow-seats/: 1-table3-4 (4 people, no extra chair), 2-table3-9 (4 + 4 extra + 1
## standing), 3-bar-12, 4-tall-6 (game camera, player standing by the table), and close-*.png from a camera over each.

const PresenceClient = preload("res://scripts/presence_ui/presence_client.gd")
const Avatar = preload("res://scripts/avatar.gd")
const NeedsHud = preload("res://scenes/ui/needs_hud.gd")

var out := "res://../docs/art/screens/overflow-seats"
var tag := "phone"
var main: Node
var fake: Variant


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(nm: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := out.path_join("%s-%s.png" % [nm, tag])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _place(pos: Vector3, yaw := 0.0) -> void:
	var p = main.player
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.get_node("Body").rotation.y = yaw
	p.rig.snap()
	await _wait(1.5)


func _close(nm: String, target: Vector3, from: Vector3) -> void:
	var game_cam := root.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	root.add_child(cam)
	cam.look_at_from_position(target + from, target)
	cam.make_current()
	main.player.visible = false
	var layers := main.find_children("*", "CanvasLayer", true, false)
	for l in layers:
		l.visible = false
	await _wait(0.4)
	await _shot(nm)
	for l in layers:
		l.visible = true
	main.player.visible = true
	cam.queue_free()
	if game_cam:
		game_cam.make_current()


func _open(per_table: Dictionary) -> void:
	if main:
		main.queue_free()
		await _wait(0.3)
	fake.people.clear()
	var n := 0
	for t in per_table:
		for i in per_table[t]:
			fake.arrive("%s%d" % [t, i], t, 500 + n)
			n += 1
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	await _wait(0.5)


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_overflow_save.json"
	needs.new_game()
	needs.set_avatar(Avatar.default_record(), "Dan", "")
	for m in needs.meters:
		needs.meters[m] = 60.0
	needs.checkin_nights.append(needs.night_key(needs.clock))
	fake = PresenceClient.use_fake()
	NeedsHud.areas_hidden = true   # the area column slid aside (the player's own toggle), so Table3 is not under it
	var t3 := Vector3(32.7, 0, 8.4)
	var bar := Vector3(29.8, 0, 12.2)
	var tall := Vector3(18.7, 0, 3.9)
	await _open({"Table3": 4})
	await _place(Vector3(31.6, 0.1, 6.9), 0.0)
	await _shot("1-table3-4")
	await _close("close-table3-4", t3, Vector3(0, 2.9, -2.1))
	await _open({"Table3": 9, "Bar": 12, "BufferTall1": 6})
	await _place(Vector3(31.6, 0.1, 6.9), 0.0)
	await _shot("2-table3-9")
	await _place(Vector3(32.7, 0.1, 10.0), PI)
	await _shot("2b-table3-9-from-bar")
	await _close("close-table3-9", t3, Vector3(0, 2.9, -2.1))
	await _place(Vector3(29.8, 0.1, 10.6), 0.0)
	await _shot("3-bar-12")
	await _close("close-bar-12-west", Vector3(25.3, 0, 12.2), Vector3(0, 3.1, -4.6))
	await _close("close-bar-12-east", Vector3(33.6, 0, 12.2), Vector3(0, 3.1, -4.6))
	await _place(Vector3(18.7, 0.1, 5.2), PI)
	await _shot("4-tall-6")
	await _close("close-tall-6", tall, Vector3(0, 3.2, 2.6))
	quit(0)
