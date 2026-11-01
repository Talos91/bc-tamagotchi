extends SceneTree
## Real-window screenshot run for Daniele's third batch of Questions-tab answers (not a pass/fail test): the corridor
## neon and the memory-corner light box in Kristi, the menu list with dimmed THB prices, and Pour Perfect's rotation
## of 12 drinks, one per family. From game/, one size per run:
##   godot --path . --resolution 1080x1920 --script res://tests/capture_answers3.gd -- --capture-size=1080x1920 --tag=portrait
##   godot --path . --resolution 1920x1080 --script res://tests/capture_answers3.gd -- --capture-size=1920x1080 --tag=landscape
## Writes <n>-<shot>-<tag>.png to docs/art/screens/answers-3/ (override with --out=DIR).

const BarMenu = preload("res://scripts/menu/bar_menu.gd")
const PourScene := "res://scenes/minigames/pour_perfect/pour_perfect.tscn"

var out := "res://../docs/art/screens/answers-3"
var tag := "portrait"
var main: Node
var cam: Camera3D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(nm: String, dir := "") -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := (out if dir == "" else out.path_join(dir)).path_join("%s-%s.png" % [nm, tag])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _eye(from: Vector3, at: Vector3, fov: float) -> void:
	cam.fov = fov
	cam.keep_aspect = Camera3D.KEEP_HEIGHT if root.get_visible_rect().size.aspect() >= 1.0 else Camera3D.KEEP_WIDTH
	cam.look_at_from_position(from, at)
	cam.make_current()
	await _wait(0.4)


func _place(p: Node3D, pos: Vector3, yaw := 0.0) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.get_node("Body").rotation.y = yaw
	p.rig.snap()
	await _wait(1.0)


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_answers3_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	var p = main.player
	cam = Camera3D.new()
	main.add_child(cam)

	# 1. Corridor end-wall neon: the game camera looking east down the corridor, then up close at eye level
	await _place(p, Vector3(11.4, 0, 14.1), -PI * 0.5)
	await _shot("1-corridor-sign")
	main.get_node("UI").visible = false
	await _eye(Vector3(12.2, 1.75, 14.07), Vector3(15.45, 1.95, 14.07), 52.0)
	await _shot("1-corridor-sign-close")
	cam.clear_current()
	main.get_node("UI").visible = true

	# 2. Memory corner light box: the corner at eye level as in photo 25 (TV, lamps, chairs, the box), then the box
	main.get_node("UI").visible = false
	await _place(p, Vector3(8.5, 0, 4.0), PI)
	await _eye(Vector3(6.0, 1.5, 3.9), Vector3(5.0, 0.85, 0.3), 62.0)
	await _shot("2-memory-corner")
	await _eye(Vector3(6.6, 1.45, 2.6), Vector3(6.1, 0.85, 0.3), 46.0)
	await _shot("2-memory-box-close")
	cam.clear_current()
	main.get_node("UI").visible = true

	# 3. The menu list: drinks (spirits by the glass, wine by the bottle further down) and kitchen, prices dimmed
	var z: Dictionary = main.zones.first_of("bar")
	await _place(p, z["approach"] + Vector3(0, 0.1, 0))
	main.open_sheet(main.zones.current)
	await _wait(0.5)
	main.sheet.buttons["menu"].pressed.emit()
	await _wait(0.6)
	await _shot("3-menu-drinks")
	var ml = main.menu_list
	var whites: Control = ml.buttons.get("petes_pure_sauvignon_blanc_2023")
	if whites:
		ml._scroll.scroll_vertical = int(whites.position.y - 60)
	await _wait(0.4)
	await _shot("3-menu-wine")
	ml.show_tab("kitchen")
	await _wait(0.4)
	await _shot("3-menu-kitchen")
	ml.close()
	await _wait(0.4)

	# 4. Pour Perfect in the game: tonight's drink of the night from the bar sheet
	main.open_sheet(main.zones.current)
	await _wait(0.3)
	main.sheet.buttons["pour"].pressed.emit()
	await _wait(1.9)
	var g = main.frame.game
	await _pour(g)
	await _shot("4-pour-perfect-" + g.drink_id)
	print("tonight (night %d): %s" % [BarMenu.night_of(Time.get_unix_time_from_system()), g.drink_id])

	print("CAPTURE DONE ", out)
	quit(0)


## Two layers poured and the third running, so the drink's colours show.
func _pour(g) -> void:
	g.press()
	await _wait(4.2)
	g.release()
	await _wait(1.0)
	g.press()
	await _wait(3.6)
	g.release()
	await _wait(1.0)
	g.press()
	await _wait(1.6)
