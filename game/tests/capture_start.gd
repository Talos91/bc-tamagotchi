extends SceneTree
## Screenshots of the start screen, the entry and the exit shot (scripts/start_screen.gd, scripts/exit_shot.gd) in a
## real window, one orientation per run:
##   godot --path . --resolution 540x960 --script res://tests/capture_start.gd -- --tag=portrait
##   godot --path . --resolution 960x540 --script res://tests/capture_start.gd -- --tag=landscape
## (half of 1080x1920 and 1920x1080, as tools/capture_venue.gd: a full-size window is clipped to the screen.)
## Writes to docs/art/screens/start/ (override with --out=DIR):
##   <tag>-1-title      the start screen
##   <tag>-2-shoulder   the camera eased to over the shoulder, walking to the door
##   <tag>-3-door       at the door, the door open
##   <tag>-4-pull       the pull-back to the game camera, the door closing
##   <tag>-5-play       the first gameplay frame, HUD in
##   <tag>-6-exit-out   leaving: stepping out of the open door
##   <tag>-7-exit-shut  leaving: out on the pavement, the door shut, the neon on (the walk-out card comes next)

const StartScreen = preload("res://scripts/start_screen.gd")
const ExitShot = preload("res://scripts/exit_shot.gd")

var out := ""
var tag := "shot"


func _init() -> void:
	out = "res://../docs/art/screens/start"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var needs := root.get_node_or_null("Needs")
	needs.autosave = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.intro = true
	root.add_child(main)
	await _frames(90)
	var ss: Node = main.start_screen
	_save("1-title")
	ss.tap()
	await _until(func(): return ss._t >= 1.45)
	_save("2-shoulder")
	await _until(func(): return ss._t >= StartScreen.LEG_A + StartScreen.DOOR_WAIT * 0.9)
	_save("3-door")
	await _until(func(): return not is_instance_valid(ss) or (ss.phase == StartScreen.Phase.PULL and ss._t - ss._pull_t0 >= 0.7))
	_save("4-pull")
	await _until(func(): return not is_instance_valid(main.start_screen))
	await _wait(0.7)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
		await _frames(30)
	_save("5-play")
	main._on_leave()
	await process_frame
	var xs: Node = main.exit_shot
	await _until(func(): return not is_instance_valid(xs) or (xs.phase == ExitShot.Phase.OUT and xs._t >= 0.75))
	_save("6-exit-out")
	await _until(func(): return not is_instance_valid(xs) or (xs._shut_t >= 0.0 and xs._t - xs._shut_t >= 0.3))
	_save("7-exit-shut")
	quit()


func _save(nm: String) -> void:
	var img := root.get_texture().get_image()
	var path := "%s/%s-%s.png" % [out, tag, nm]
	print("capture ", path, " ", img.get_size(), " -> ", img.save_png(path))


func _until(cond: Callable) -> void:
	var t := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t < 15000:
		await process_frame


func _frames(k: int) -> void:
	for i in k:
		await process_frame


func _wait(secs: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < secs * 1000.0:
		await process_frame
