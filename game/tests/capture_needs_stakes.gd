extends SceneTree
## Real-window screenshots of the new stakes HUD states (not a pass/fail test): the venue HUD with Last Call and two
## annoyances, a MISS result card, the street-door home with the Last Call chip and postcard, the ghost home, the farewell card.
##   godot --path . --resolution 1080x1920 --script res://tests/capture_needs_stakes.gd -- <out dir> <suffix>

var out_dir := "res://../docs/art/screens/needs-stakes"
var suffix := "portrait"
var main: Node
var needs: Node
const DAY := 86400.0


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


func _fresh(days: float, intro: bool) -> void:
	if is_instance_valid(main):
		main.queue_free()
		await process_frame
	needs.new_game()
	needs.last_counted_visit = needs.clock - days * DAY
	if days >= 21.0:
		needs.dead_at = needs.clock - (days - 21.0) * DAY  # died at day 21; the ghost window runs 14 days on
	needs._refresh()
	main = load("res://scenes/main.tscn").instantiate()
	main.intro = intro
	root.add_child(main)
	await _wait(1.2)


func _run() -> void:
	await process_frame
	needs = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_stakes_save.json"
	needs.new_game()
	needs.profile["display_name"] = "Mali"
	# 1: venue HUD at day 19: Last Call chip, Thirsty and Earworm
	needs.meters["drinks"] = 5.0
	needs.meters["music"] = 3.0
	needs.meters["friends"] = 45.0
	needs.meters["nightlife"] = 45.0
	needs.last_counted_visit = needs.clock - 19.0 * DAY
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.5)
	if is_instance_valid(main.welcome):
		main.welcome.queue_free()
		main.welcome = null
		main._sync_block()
	needs.last_counted_visit = needs.clock - 19.0 * DAY
	needs._refresh()
	main.hud._refresh_status()
	await _wait(0.5)
	await _shot("1-hud-last-call")
	# 2: a MISS card
	main.open_minigame("pour_perfect", {"drink": "guinness_draught"})
	await _wait(0.8)
	main.frame.game.finish(0.1)
	await _wait(0.8)
	await _shot("2-miss-card")
	# 3: the street-door home at day 19 (Last Call), annoyances on
	for m in needs.meters:
		needs.meters[m] = 60.0
	needs.meters["drinks"] = 5.0
	await _fresh(19.0, true)
	needs.meters["drinks"] = 5.0
	needs.meters["music"] = 3.0
	main.start_screen._fill_stake_box()
	await _wait(0.5)
	await _shot("3-home-last-call")
	# 4: the ghost
	await _fresh(25.0, true)
	main.start_screen._fill_stake_box()
	await _wait(0.5)
	await _shot("4-home-ghost")
	# 5: the farewell card
	await _fresh(40.0, false)
	await _wait(0.5)
	await _shot("5-farewell")
	quit(0)
