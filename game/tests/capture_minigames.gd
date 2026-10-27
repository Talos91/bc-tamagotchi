extends SceneTree
## Real-window screenshot run for the minigame lab (not a pass/fail test).
##   godot --path . --resolution 540x960 --script res://tests/capture_minigames.gd -- <output dir>
## Plays each game briefly, saves one PNG per game plus the lab before and after a result.

var out_dir := "res://../docs/art/screens/2026-10-27-minigames"
var lab: Control
var needs: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	lab = load("res://scenes/minigames/minigame_lab.tscn").instantiate()
	root.add_child(lab)
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _finish_game(score: float) -> void:
	lab.frame.game.finish(score)
	await _wait(0.4)


func _run() -> void:
	await process_frame
	needs = lab.needs  # the autoload, or the lab's own instance when autoloads are absent in script mode
	needs.autosave = false
	needs.save_path = "user://capture_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 35.0
	lab._refresh_meters(false)
	await _wait(0.6)
	await _shot("00-lab")

	lab.launch_by_id("pour_perfect")
	await _wait(1.9)
	var g = lab.frame.game
	g.press()
	await _wait(3.4)
	await _shot("01-pour-perfect")
	g.release()
	await _wait(0.2)
	await _finish_game(0.9)
	await _shot("05-result-card")
	lab.frame._card.done.emit()
	await _wait(0.8)
	await _shot("06-lab-after-result")

	lab.launch_by_id("front_row_rhythm", {"song": 1})
	await _wait(0.5)
	g = lab.frame.game
	await _wait(6.0)
	for n in g.notes:
		if n["state"] == 0 and absf(g.clock - n["time"]) < 0.5:
			pass
	await _shot("02-front-row-rhythm")
	await _finish_game(0.7)
	lab.frame._card.done.emit()
	await _wait(0.5)

	lab.launch_by_id("candle_talk", {"regular": "mali", "seed": 3})
	await _wait(0.5)
	g = lab.frame.game
	g.choose(g.line["best"])
	await _wait(2.2)
	g.choose(g.line["best"])
	await _wait(0.3)
	await _shot("03-candle-talk")
	await _finish_game(0.9)
	lab.frame._card.done.emit()
	await _wait(0.5)

	lab.launch_by_id("neon_pinball")
	await _wait(0.5)
	g = lab.frame.game
	g.launch(0.9)
	await _wait(2.6)
	g.set_flipper(0, true)
	await _wait(0.1)
	await _shot("04-neon-pinball")
	await _finish_game(0.5)
	lab.frame._card.done.emit()
	await _wait(0.5)

	# Thai once, so the second language is checked on screen.
	lab._toggle_lang()
	await _wait(0.4)
	await _shot("07-lab-thai")
	quit(0)
