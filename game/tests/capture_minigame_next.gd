extends SceneTree
## Real-window screenshots of the new minigames (docs/design/10-minigame-next.md), not a pass/fail test.
##   godot --path . --resolution 540x960 --screen 1 --script res://tests/capture_minigame_next.gd -- <game_id> [out dir]
## Opens the game in the minigame lab, plays it with a small scripted player, saves <game_id>-play.png mid-round
## and <game_id>-result.png on the result card.

var out_dir := "res://../docs/art/screens/minigame-next"
var game_id := "coaster_flip"
var lab: Control


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		game_id = args[0]
	if args.size() > 1:
		out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	lab = load("res://scenes/minigames/minigame_lab.tscn").instantiate()
	root.add_child(lab)
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir.path_join(name + ".png"))
	img.save_png(path)
	print("saved ", path, " ", img.get_size())


func _run() -> void:
	await process_frame
	var needs: Node = lab.needs
	needs.autosave = false
	needs.save_path = "user://capture_next_save.json"
	needs.new_game()
	await _wait(0.4)
	await _shot("build-lab")
	lab.launch_by_id(game_id)
	await _wait(0.2)
	var g = lab.frame.game
	match game_id:
		"coaster_flip":
			await _wait(1.2)
			for i in 5:
				g.flick()
				while g.state == g.State.FLIGHT and not (g.catchable() and g.alignment() >= g.flat_needed(g.run) + 0.02):
					await process_frame
				g.tap()
				await _wait(0.7)
			g.flick()
			await _wait(0.35)
		"neon_moth":
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 9000 and not g.done:
				var n: int = g.next_gate()
				var target: float = g.gap_y[n] if n < g.GATES else 500.0
				if g.state != g.State.INTRO and g.y > target + 30.0 and g.vy >= 0.0:
					g.flap()
				await process_frame
		_:
			await _wait(4.0)
	await _shot("build-%s-play" % game_id)
	g.finish(0.9)
	await _wait(0.6)
	await _shot("build-%s-result" % game_id)
	quit(0)
