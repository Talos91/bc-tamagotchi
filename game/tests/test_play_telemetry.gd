extends SceneTree
## Gameplay telemetry (scripts/play_telemetry.gd, autoload PlayTelemetry; Daniele 2026-11-20), headless and offline:
## the presence mock stands in for Supabase. Inert while Presence is off; the minigame frame's hook records mg_start /
## mg_end with score, duration, end reason (lost / quit / closed / timer / sign_end / arrived), misses, best and
## reached; venue visits; a tab closed mid-visit reports on the next start; offline keeps the queue and sends later;
## sending never blocks the caller; a refused batch is dropped, not retried forever; nothing personal beyond the name.
##   godot --headless --path . -s tests/test_play_telemetry.gd

const Mock = preload("res://scripts/presence/presence_mock.gd")
const TelScript = preload("res://scripts/play_telemetry.gd")
const FrameScene = preload("res://scenes/ui/minigame_frame.tscn")
const STORE := "user://test_play_telemetry.json"

var fails := 0
var checks := 0
var tel: Node
var pres: Node
var mock: RefCounted


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ", what)


func _init() -> void:
	await process_frame
	tel = root.get_node_or_null("PlayTelemetry")
	pres = root.get_node_or_null("Presence")
	check(tel != null and pres != null, "PlayTelemetry and Presence are autoloads")
	if tel != null and pres != null:
		await _run()
	print("play_telemetry: %d checks, %d failures" % [checks, fails])
	print("TEST PLAY_TELEMETRY ", "PASS" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)


func ends() -> Array:
	return mock.play_events.filter(func(e): return e["kind"] == "mg_end")


func settle() -> void:
	for i in 6:
		await process_frame


func _run() -> void:
	# 1. inert headless: Presence off -> nothing is queued or written
	pres.use_mock(false)
	tel.reset_local(STORE)
	check(not tel.active(), "inert while Presence is off (headless)")
	tel.record("mg_start", "neon_moth", {"difficulty": 0})
	tel.visit_started()
	check(tel.queue.is_empty() and tel.session.is_empty(), "nothing queued while inert")

	pres.reset_local("user://test_play_presence.json")
	pres.apply_to_needs = false
	mock = pres.use_mock(true)
	check(tel.active(), "active with the mock")

	# 2. a round lost: pinball out of balls, through the real frame and its one hook
	var fr: Control = FrameScene.instantiate()
	root.add_child(fr)
	await process_frame
	fr.open(load("res://scenes/minigames/neon_pinball/neon_pinball.tscn"))
	var g: Control = fr.game
	check(tel.queue.size() == 1 and tel.queue[0]["kind"] == "mg_start" and tel.queue[0]["game"] == "neon_pinball",
		"mg_start queued when the round starts")
	check(tel.queue[0]["data"].has("difficulty"), "mg_start carries the difficulty")
	g.balls_left = 0
	g.finish(0.3)
	await settle()
	var e: Array = ends()
	check(e.size() == 1, "mg_end sent after the round (%d)" % e.size())
	if e.size() == 1:
		var d: Dictionary = e[0]["data"]
		check(d["reason"] == "lost", "pinball out of balls = lost (%s)" % d["reason"])
		check(int(d["score"]) == 30, "score in points 0..100 (%s)" % str(d["score"]))
		check(d.has("duration_s") and d.has("misses") and d.has("best") and d.has("reached") and d.has("difficulty"),
			"mg_end has duration, misses, best, reached, difficulty")
		check(int(d["reached"].get("lives_left", -1)) == 0, "reached.lives_left = 0")
		check(e[0]["build"].begins_with("v") and e[0]["device"] != "", "build and device class on every event")
		check(e[0].has("player_name"), "player name field present")
		var keys: Array = e[0].keys()
		keys.sort()
		check(keys == ["at", "build", "client_at", "data", "device", "game", "kind", "player_id", "player_name"],
			"nothing else personal in the row: %s" % str(keys))
	check(mock.play_events.filter(func(x): return x["kind"] == "mg_start").size() == 1, "mg_start sent too")
	check(tel.queue.is_empty(), "queue empty after a good send")

	# 3. quit from the pause menu
	fr._start_game()
	await process_frame
	fr._open_pause()
	fr._leave()
	await settle()
	check(ends().size() == 2 and ends()[-1]["data"]["reason"] == "quit", "Leave = quit (%s)" % str(ends()[-1]["data"].get("reason") if ends().size() > 0 else "-"))

	# 4. closed mid-round: the frame goes away while the game runs
	fr._start_game()
	await process_frame
	fr.queue_free()
	await settle()
	check(ends().size() == 3 and ends()[-1]["data"]["reason"] == "closed", "frame freed mid-round = closed")

	# 5. other end reasons from the games' own state
	var moth = load("res://scenes/minigames/neon_moth/neon_moth.tscn").instantiate()
	check(TelScript.end_reason(moth, {"sign": true}) == "sign_end", "an old row with sign = sign_end")
	moth.singes_left = 0
	check(TelScript.end_reason(moth, {"sign": false}) == "lost", "moth out of wings = lost")
	moth.singes_left = 3
	moth.end_reason = "lost"   # the endless ramp (15-minigame-ramp): lose() sets it on the third strike
	check(TelScript.end_reason(moth, {}) == "lost", "the game's own end_reason = lost")
	moth.set_meta("end_reason", "timer")
	check(TelScript.end_reason(moth, {}) == "timer", "an explicit end_reason wins (ramp job hook)")
	moth.free()
	var dash = load("res://scenes/minigames/soi_dash/soi_dash.tscn").instantiate()
	check(TelScript.end_reason(dash, {"arrived": true}) == "arrived" and TelScript.end_reason(dash, {"arrived": false}) == "timer",
		"soi dash: arrived / timer")
	check(TelScript.misses_of(dash, {"bumps": 4}) == 4, "misses from bumps")
	dash.free()

	# 6. offline: queued, kept on disk, sent at the next chance
	mock.online = false
	var before: int = mock.play_events.size()
	tel.record("mg_start", "coaster_flip", {"difficulty": 1})
	tel.flush()
	await settle()
	check(tel.queue.size() == 1 and mock.play_events.size() == before, "offline: kept in the queue")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(STORE))
	check(saved is Dictionary and (saved["queue"] as Array).size() == 1, "queue saved to disk")
	mock.online = true
	tel._on_tick()
	await settle()
	check(tel.queue.is_empty() and mock.play_events.size() == before + 1, "back online: sent at the next tick")

	# 7. never blocks: a slow server does not hold the caller
	pres.mock_delay_s = 0.5
	tel.record("mg_start", "pour_perfect", {})
	var t0 := Time.get_ticks_msec()
	tel.flush()
	check(Time.get_ticks_msec() - t0 < 50 and tel.sending, "flush returns at once while the send is in flight")
	tel.record("mg_start", "pour_perfect", {})
	check(tel.queue.size() == 2, "recording continues during a send")
	await create_timer(1.6).timeout
	pres.mock_delay_s = 0.0
	tel.flush()
	await settle()
	check(tel.queue.is_empty() and not tel.sending, "slow send finished, all sent")

	# 8. a venue visit, and a tab closed mid-visit
	tel.reset_local(STORE)
	mock.play_events.clear()
	tel.visit_started()
	tel.session["start"] = tel.session["start"] - 125.0
	tel.session["games"] = 2
	tel.visit_ended("left")
	await settle()
	var vs: Array = mock.play_events.filter(func(x): return x["kind"] == "venue_session")
	check(vs.size() == 1 and int(vs[0]["data"]["games"]) == 2 and int(vs[0]["data"]["length_s"]) >= 125 and vs[0]["data"]["reason"] == "left",
		"venue_session: length and games played")
	tel.visit_started()
	tel.session["start"] = tel.session["start"] - 60.0
	tel._save()
	var t2: Node = TelScript.new()
	t2.store_path = STORE
	root.add_child(t2)          # a fresh start: the open visit is reported as closed
	await settle()
	t2.flush()
	await settle()
	vs = mock.play_events.filter(func(x): return x["kind"] == "venue_session")
	check(vs.size() == 2 and vs[-1]["data"]["reason"] == "closed" and int(vs[-1]["data"]["length_s"]) >= 60,
		"tab closed mid-visit: reported on the next start")
	t2.queue_free()
	tel.reset_local(STORE)

	# 9. a refused batch (daily limit) is dropped, not retried forever
	for i in 3000:
		mock.play_events.append({"player_id": pres.player_id(), "at": mock.now(), "kind": "mg_start"})
	tel.record("mg_start", "neon_moth", {})
	tel.flush()
	await settle()
	check(tel.queue.is_empty(), "limit: the batch is dropped")
	tel.reset_local(STORE)
	pres.use_mock(false)
