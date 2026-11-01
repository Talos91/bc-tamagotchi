extends SceneTree
## Headless smoke test of the whole visit loop from main.tscn: Welcome Back on arrival, the Lounge entry bonus, then
## the player walks to the bar, the stage, Mali's table and the arcade, opens each zone's sheet and does its rows
## (plain actions and all four minigames, finished through the shared frame and result card), listens to a song,
## sits a minute on a chair, and leaves through the street door; the walk-out summary must show the visit's gains.
##   godot --headless --path . --script res://tests/smoke_loop.gd

const HouseBand = preload("res://scripts/zones/house_band.gd")

var main: Node
var needs: Node
var fails: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _init() -> void:
	await process_frame
	needs = root.get_node_or_null("Needs")
	if needs == null:
		print("SMOKE LOOP FAIL: Needs autoload missing")
		quit(1)
		return
	needs.autosave = false
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 20.0  # low, so no gain is lost to a full meter
	needs.homebody_flag = true  # Vibe was below 25 since the last visit: Welcome Back is due
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await physics_frame
	var p: Player = main.player
	var s: VenueSession = main.session

	print("arrival")
	check(needs.visit_active, "visit started on arrival")
	check(is_instance_valid(main.welcome), "Welcome Back dialogue shown")
	check(needs.welcome_active(), "Welcome Back x2 active")
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	await process_frame
	check(not main._blocked(), "dialogue dismissed, room playable")
	check(needs.visit_once.has("enter_lounge"), "Lounge entry bonus landed")
	for kind in ["bar", "stage", "table", "arcade", "exit"]:
		check(not main.zones.first_of(kind).is_empty(), "zone %s built from layout.json" % kind)

	print("bar")
	await walk_to("bar")
	check(main.hud.prompt.is_showing(), "prompt shown at the bar")
	var d0: float = needs.meters["drinks"]
	await row("order")
	check(needs.meters["drinks"] > d0, "order a drink refills Drinks (%.1f -> %.1f)" % [d0, needs.meters["drinks"]])
	check(is_instance_valid(main.hud.card), "action card after ordering")
	check(s.tipsy.state() == 1, "one drink: Warm")
	var d1: float = needs.meters["drinks"]
	await row("pour")
	await play_minigame("pour_perfect", 0.8)
	check(needs.meters["drinks"] > d1, "Pour Perfect refills Drinks (%.1f -> %.1f)" % [d1, needs.meters["drinks"]])
	check(s.drinks_this_visit == 2, "Pour Perfect counts as a drink")
	await row("water")
	check(s.tipsy.state() == 0, "water drops a tipsiness state")

	print("stage")
	await walk_to("stage")
	var m0: float = needs.meters["music"]
	await row("rhythm")
	await play_minigame("front_row_rhythm", 0.7)
	var m1: float = needs.meters["music"]
	check(m1 > m0, "Front Row Rhythm refills Music (%.1f -> %.1f)" % [m0, m1])
	s.band.t = 0.0
	s.band.playing = true
	s.tick(HouseBand.SONG_SECONDS)  # a whole song within earshot
	s.band.skip()
	check(needs.meters["music"] > m1, "a song heard in full refills Music (%.1f -> %.1f)" % [m1, needs.meters["music"]])
	check(not s.band.playing, "band between songs")
	var m2: float = needs.meters["music"]
	await row("applaud")
	check(needs.meters["music"] > m2, "applause between songs refills Music")

	print("table")
	await walk_to("table")
	check(main.zones.current.get("regular", "") == "mali", "at Mali's table")
	var f0: float = needs.meters["friends"]
	await row("talk")
	await play_minigame("candle_talk", 0.9)
	var f1: float = needs.meters["friends"]
	check(f1 > f0, "Candle Talk refills Friends (%.1f -> %.1f)" % [f0, f1])
	await row("sit")
	for i in 900:   # the player walks to a free chair at the table and sits; the minute starts once seated
		if p.seated:
			break
		await physics_frame
	check(not s.sitting.is_empty() and p.seated, "sitting down on a chair at the table")
	s.tick(VenueSession.SIT_SECONDS + 1.0)
	check(s.sitting.is_empty() and needs.meters["friends"] > f1, "a minute seated refills Friends (%.1f -> %.1f)" % [f1, needs.meters["friends"]])
	await open_here()
	check(is_instance_valid(main.sheet) and main.sheet.buttons["talk"].disabled, "Candle Talk disabled after today's talk")
	main.close_sheet()
	await process_frame

	print("arcade")
	await walk_to("arcade")
	var n0: float = needs.meters["nightlife"]
	await row("pinball")
	await play_minigame("neon_pinball", 0.7)
	check(needs.meters["nightlife"] > n0, "Neon Pinball refills Nightlife (%.1f -> %.1f)" % [n0, needs.meters["nightlife"]])

	print("leave")
	await walk_to("exit")
	await row("leave")
	await process_frame
	check(not needs.visit_active, "visit ended")
	check(is_instance_valid(main.walk_out) and main.walk_out.showing == "summary", "walk-out summary shown")
	if is_instance_valid(main.walk_out):
		var g: Dictionary = main.walk_out.summary.get("gains", {})
		print("  totals ", g)
		for m in ["music", "friends", "drinks", "nightlife"]:
			check(float(g.get(m, 0.0)) > 0.0, "walk-out total for %s > 0" % m)
		main.walk_out.back_button.pressed.emit()
		await process_frame
		check(main.walk_out.showing == "flat", "back to the flat")
		main.walk_out.go_button.pressed.emit()
		await process_frame
		check(needs.visit_active and needs.visits_today == 2 and not main._blocked(), "GO OUT starts the next visit")

	print("SMOKE LOOP ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


## Walks the player (tap-to-move path) to the first zone of `kind` and waits until it is the current zone.
func walk_to(kind: String) -> void:
	var z: Dictionary = main.zones.first_of(kind, kind == "table")
	main.player.walk_to(z["approach"])
	for i in 2400:
		await physics_frame
		if main.zones.current.get("id", "") == z["id"] and not main.player.walking_to:
			break
	main.player.walking_to = false
	for i in 3:
		await physics_frame
	check(main.zones.current.get("id", "") == z["id"], "walked to %s (at %s)" % [z["id"], main.player.global_position.snapped(Vector3.ONE * 0.01)])


func open_here() -> void:
	main.hud.prompt_pressed.emit()  # same as tapping the prompt pill
	await process_frame


## Opens the current zone's sheet and taps a row.
func row(id: String) -> void:
	await open_here()
	if not is_instance_valid(main.sheet) or not main.sheet.buttons.has(id):
		check(false, "row %s in sheet" % id)
		main.close_sheet()
		await process_frame
		return
	var b: Button = main.sheet.buttons[id]
	check(not b.disabled, "row %s enabled" % id)
	b.pressed.emit()
	await process_frame


## Finishes the open minigame with `score` and taps DONE on the result card.
func play_minigame(game_id: String, score: float) -> void:
	await process_frame
	var fr: Control = main.frame
	if not is_instance_valid(fr):
		check(false, "%s opened" % game_id)
		return
	check(fr.game.game_id == game_id, "%s opened over the room" % game_id)
	for i in 10:
		await process_frame
	fr.game.finish(score)
	await process_frame
	check(is_instance_valid(fr._card), "%s result card" % game_id)
	fr._card.done.emit()
	await process_frame
	check(not is_instance_valid(main.frame), "%s closed, back in the room" % game_id)
