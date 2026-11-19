extends SceneTree
## Presence wave 1, client side, against "Fake presences" (scripts/presence_ui/; docs/design/08-presence.md §3.1, §5.1,
## §6; owner item 40):
##   off      presence off by default: no presence, the crowd exactly as before (seated_count anonymous patrons)
##   spawn    fake presences sit as their own avatars, LIVE badge + floor ring each, none on anonymous patrons; the
##            anonymous fill shrinks by as many (headcount holds); their chairs leave group "seat", vacate() never moves
##            them; a viewer not checked in never sees "tonight"-only people nor anyone at their real table (P3)
##   late     a check-in later that night shows at the next poll, walks in from the street door and sits down
##   gone     a presence hidden from the list fades out at the next poll and its chair is free again
##   card     a tap on a presence opens its card (name, avatar, tags, nights together, four verbs); a wave is sent
##            (fake source got it, button "Sent", bubbles over the player and the presence), limits per pair per night,
##            a drink from the menu and a phrase; Hide takes them out at once
##   inbox    the start screen shows "Inbox · N" for received verbs; the inbox lists them; a new one arrives; Got it
##            marks them read and queues Friends +2 each for the visit
##   checkin  opened from a table code: the consent card first (nothing preselected, Check in off until a choice),
##            the check-in (table, tablemates, needs.check_in ran), Into the bar walks in; then the viewer sees the
##            real tables and the "tonight"-only people; offline: an error and Not now, nothing checked in
##   godot --headless --path . --script res://tests/test_presence_client.gd

const PresenceClient = preload("res://scripts/presence_ui/presence_client.gd")
const Badge = preload("res://scripts/presence_ui/presence_badge.gd")
const Avatar = preload("res://scripts/avatar.gd")
const StartScreen = preload("res://scripts/start_screen.gd")

var needs: Node
var fails: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _init() -> void:
	await process_frame
	needs = root.get_node_or_null("Needs")
	needs.autosave = false
	needs.new_game()
	needs.set_avatar(Avatar.default_record(), "Dan", "")

	print("off")
	PresenceClient.reset()
	check(not PresenceClient.active(), "presence off by default")
	var main := await _main(false)
	var pat: Node = main.get_node("Venue/Patrons")
	check(pat.presences.is_empty() and root.get_tree().get_nodes_in_group("presence").is_empty(), "no presence in the venue")
	check(_count(pat, "Patron") == pat.seated_count, "crowd as before: %d anonymous seated" % _count(pat, "Patron"))
	await _free(main)

	print("spawn")
	var fake: Variant = PresenceClient.use_fake()
	check(PresenceClient.active() and PresenceClient.is_fake(), "fake presences on")
	main = await _main(false)
	pat = main.get_node("Venue/Patrons")
	var shown: int = pat.presences.size()
	var visible_people := 0
	for p in fake.people:
		if p["visibility"] == "everyone":
			visible_people += 1
	check(shown == visible_people and shown == 10, "%d presences seated (12 checked in, 2 only for people here)" % shown)
	check(_count(pat, "Patron") == pat.seated_count - shown, "anonymous fill shrank by %d: headcount holds (%d + %d)" % [shown, _count(pat, "Patron"), shown])
	var badges := 0
	var rings := 0
	var bad_seat := 0
	var at_own_table := 0
	var avatar_look := 0
	for id in pat.presences:
		var f: PatronFigure = pat.presences[id]
		if f.get_node_or_null("LiveBadge") != null:
			badges += 1
		if f.get_node_or_null("LiveRing") != null:
			rings += 1
		if f.look.has("avatar") and f.is_in_group("presence") and String(f.name).begins_with("Presence_"):
			avatar_look += 1
		var seat: Node3D = f.get_meta("seat")
		if seat.is_in_group("seat") or pat.taken.get(seat) != f:
			bad_seat += 1
		if str(f.get_meta("presence")["table_id"]) != "":
			at_own_table += 1
	check(badges == shown and rings == shown, "LIVE badge and floor ring on each (%d, %d)" % [badges, rings])
	check(avatar_look == shown, "each is their own avatar, Presence_<id>, group presence")
	check(bad_seat == 0, "their chairs are theirs and out of group seat")
	check(at_own_table == 0, "viewer not checked in: no real table reaches this phone, seats by zone (P3)")
	var npc_badges := 0
	for f in pat.figures:
		if not f.is_in_group("presence") and Badge.has_badge(f):
			npc_badges += 1
	check(npc_badges == 0, "no badge on anonymous patrons, cast, staff, band")
	var some_id: String = pat.presences.keys()[0]
	var some: PatronFigure = pat.presences[some_id]
	var some_seat: Node3D = some.get_meta("seat")
	var some_pos := some.position
	pat.vacate(some_seat)
	check(pat.presences[some_id] == some and some.position == some_pos and pat.taken.get(some_seat) == some, "vacate() never moves a presence")
	check(some.get_node("LiveBadge") is Sprite3D and some.get_node("LiveBadge").texture == Badge.icon(), "badge is the live icon")

	print("late")
	var late: Dictionary = fake.arrive("Lateo", "Table2", 99)
	pat.poll_presence()
	var lf: PatronFigure = pat.presence_figure(late["player_id"])
	check(lf != null, "late check-in spawned at the next poll")
	check(pat.arrivals_walking() == 1 and lf.state == "walk", "it walks in")
	check(lf != null and lf.global_position.distance_to(pat._door_point) < 0.5, "from the street door")
	check(Badge.has_badge(lf), "with its LIVE badge")
	Engine.time_scale = 6.0
	var t0 := Time.get_ticks_msec()
	while pat.arrivals_walking() > 0 and Time.get_ticks_msec() - t0 < 12000:
		await process_frame
	Engine.time_scale = 1.0
	check(pat.arrivals_walking() == 0 and lf.state == "sit", "and sits down at its seat (%.1f s real)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var lseat: Node3D = lf.get_meta("seat")
	check(lf.position.distance_to(lseat.position) < 0.6, "on its own chair")

	print("gone")
	var gone_id: String = pat.presences.keys()[1]
	var gone_seat: Node3D = pat.presences[gone_id].get_meta("seat")
	fake.hide(gone_id)
	pat.poll_presence()
	check(not pat.presences.has(gone_id), "a hidden presence leaves at the next poll")
	check(gone_seat.is_in_group("seat") and not pat.taken.has(gone_seat), "its chair is free again")

	print("card")
	var taps: Node = null
	for c in root.get_children():
		if c.get_script() == preload("res://scripts/presence_ui/presence_taps.gd"):
			taps = c
	check(taps != null, "tap catcher after the game scene")
	var target_id: String = pat.presences.keys()[0]
	var target: PatronFigure = pat.presences[target_id]
	var game_cam := root.get_viewport().get_camera_3d()
	var off_sp := game_cam.unproject_position(target.global_position + Vector3(0, 0.7, 0))
	if not root.get_viewport().get_visible_rect().has_point(off_sp):
		check(taps.pick(off_sp) == "", "a presence off screen is never picked")
	# A camera that frames the presence (the game camera may look elsewhere): a real tap through the input pipeline
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.look_at_from_position(target.global_position + Vector3(0, 3.0, 4.0), target.global_position + Vector3(0, 0.7, 0))
	cam.make_current()
	await _frames(1)
	var sp := cam.unproject_position(target.global_position + Vector3(0, 0.7, 0))
	var picked: String = taps.pick(sp) if taps else ""
	check(picked == target_id, "a tap on a presence picks it (%s at %s)" % [picked, sp])
	var player_target: Vector3 = main.player.walk_target()
	for pressed in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.position = sp
		ev.pressed = pressed
		root.get_viewport().push_input(ev, true)
		await _frames(1)
	var card: Control = taps.card
	await _frames(2)
	check(card != null and card.is_inside_tree(), "the tap opens the card")
	check(main.player.walk_target() == player_target, "the tap did not walk the player")
	cam.queue_free()
	game_cam.make_current()
	check(not main.player.input_enabled, "the player does not walk while the card is up")
	var tp: Dictionary = target.get_meta("presence")
	check(_label(card, "Name").to_lower() == str(tp["display_name"]).to_lower(), "name: %s" % _label(card, "Name"))
	check(_label(card, "Tags").begins_with("LIVE"), "tags: %s" % _label(card, "Tags"))
	check(_label(card, "Nights") != "", "nights together: %s" % _label(card, "Nights"))
	check(card.find_child("Portrait", true, false) is SubViewportContainer, "avatar portrait")
	check(card.buttons.size() == 4, "four verbs: wave, cheers, send a drink, say")
	var sent_before: int = fake.sent.size()
	card.buttons["wave"].pressed.emit()
	await _frames(2)
	check(fake.sent.size() == sent_before + 1 and fake.sent[-1]["kind"] == "wave" and fake.sent[-1]["to"] == target_id, "a wave reached the source")
	check(card.buttons["wave"].disabled and card.buttons["wave"].text.begins_with("Sent"), "Wave now reads Sent")
	check(main.player.figure.find_child("VerbBubble", false, false) != null, "bubble over the player")
	check(target.find_child("VerbBubble", false, false) != null, "bubble over the presence (it reacts)")
	check("waved" in card.status.text.to_lower(), "status: %s" % card.status.text.replace("\n", " / "))
	card.send("wave", {})
	check(card.last_result.get("reason", "") == "limit" and fake.sent.size() == sent_before + 1, "a second wave tonight is refused (1 per pair)")
	card.buttons["drink"].pressed.emit()
	var drink_btn: Button = card.sub.find_child("Drink_*", true, false)
	check(drink_btn != null and card.sub.get_child_count() == 3, "three drinks from the menu")
	if drink_btn:
		drink_btn.pressed.emit()
	check(fake.sent[-1]["kind"] == "drink" and str(fake.sent[-1]["payload"].get("drink_id", "")) != "", "a drink was sent: %s" % [fake.sent[-1]["payload"]])
	card.buttons["phrase"].pressed.emit()
	var ph: Button = card.sub.find_child("Phrase_01", true, false)
	check(ph != null and card.sub.find_child("Phrases", true, false).get_child_count() == 12, "phrase wheel: 12 fixed lines")
	for i in 4:
		card.send("phrase", {"phrase": "p02"})
	var phrases := 0
	for s in fake.sent:
		if s["kind"] == "phrase":
			phrases += 1
	check(phrases == 3 and card.buttons["phrase"].disabled, "phrases: 3 per pair per night (%d)" % phrases)
	card.close()
	await _frames(2)
	check(not is_instance_valid(card) and main.player.input_enabled, "closed; the player walks again")
	card = taps.open_card(target_id)
	await _frames(1)
	card.hide_them()
	await _frames(2)
	check(not pat.presences.has(target_id) and fake.hidden.has(target_id), "Hide: out of this bar at once, recorded")
	await _free(main)

	print("inbox")
	fake = PresenceClient.use_fake()
	main = await _main(true)
	var ss: Node = main.start_screen
	var ib: Button = ss._inbox_btn
	check(ib != null and ib.visible and ib.text == "Inbox · 2", "start screen: %s" % (ib.text if ib else "no button"))
	var box: Control = ss.open_inbox()
	await _frames(2)
	var items: Node = box.find_child("Items", true, false)
	var lines: Array = []
	for c in items.get_children():
		lines.append((c as Label).text)
	check(lines.size() == 2 and "Ploy waved at you" in lines, "inbox lists them: %s" % [lines])
	box.got_it()
	await _frames(2)
	var unread := 0
	for it in fake.events:
		if not it.get("read", false):
			unread += 1
	check(unread == 0, "Got it marks them read")
	check(int(needs.ext["presence"].get("pending_social", 0)) == 1 or needs.visit_active, "Friends +2 for the wave waits for the visit")
	check(not ib.visible, "button gone with nothing unread")
	fake.receive("Ton", "phrase", {"phrase": "p01"})
	ss.refresh_inbox()
	check(ib.visible and ib.text == "Inbox · 1", "a new one arrives: %s" % ib.text)
	box = ss.open_inbox()
	await _frames(2)
	var l0: Label = box.find_child("Items", true, false).get_child(0)
	check("Ton" in l0.text and "This song!" in l0.text, "phrase line: %s" % l0.text)
	box.got_it()
	await _free(main)

	print("checkin")
	fake = PresenceClient.use_fake()
	needs.profile.erase("presence_mode")
	PresenceClient.set_pending_code("TESTTABLE2")
	main = await _main(true)
	ss = main.start_screen
	await _frames(3)
	var flow: Control = ss._modal.find_child("CheckInFlow", true, false) if is_instance_valid(ss._modal) else null
	check(flow != null, "opened from a table code: the check-in card")
	check(flow != null and flow.find_child("Mode_everyone", true, false) != null and flow.find_child("Mode_nobody", true, false) != null, "consent first time: three options")
	var go: Button = flow.find_child("CheckIn", true, false) if flow else null
	var none_on := true
	for m in ["everyone", "here", "nobody"]:
		if flow and flow.mode_buttons[m].button_pressed:
			none_on = false
	check(go != null and go.disabled and none_on, "nothing preselected, Check in off")
	check(ss.phase == StartScreen.Phase.TITLE and not main.player.visible, "still on the start screen")
	flow.choose("everyone")
	check(not go.disabled, "a choice turns Check in on")
	go.pressed.emit()
	await _frames(1)
	check(str(needs.profile.get("presence_mode", "")) == "everyone", "choice kept in the profile (P1)")
	check(flow.result.get("ok", false) and flow.result.get("table_id", "") == "Table2", "checked in at Table2")
	check(fake.checkins.size() == 1 and fake.checkins[0]["mode"] == "everyone", "the source got the code and the mode")
	check(PresenceClient.viewer_here(needs), "needs.check_in ran: checked in tonight")
	var mates: Node = flow.find_child("Tablemates", true, false)
	check(mates != null and "Ton" in mates.text, "tablemates: %s" % (mates.text if mates else "none"))
	var enter: Button = flow.find_child("Enter", true, false)
	enter.pressed.emit()
	await _frames(3)
	check(ss.phase != StartScreen.Phase.TITLE and not is_instance_valid(ss._modal), "Into the bar: walking in")
	check(PresenceClient.pending_code() == "", "the code is used once")
	await _free(main)
	main = await _main(false)
	pat = main.get_node("Venue/Patrons")
	at_own_table = 0
	for id in pat.presences:
		var f: PatronFigure = pat.presences[id]
		if str(f.get_meta("seat").get_meta("table", "")) == fake.table_of(id):
			at_own_table += 1
	check(pat.presences.size() == 12, "checked in: the 'tonight'-only people show too (%d)" % pat.presences.size())
	check(at_own_table >= 10, "and sit at their real tables (%d of %d)" % [at_own_table, pat.presences.size()])
	await _free(main)

	print("offline")
	fake = PresenceClient.use_fake()
	fake.offline = true
	main = await _main(false)
	pat = main.get_node("Venue/Patrons")
	check(pat.presences.is_empty() and _count(pat, "Patron") == pat.seated_count and not PresenceClient.online, "offline venue: anonymous room, no error, offline flag")
	await _free(main)
	needs.new_game()
	needs.set_avatar(Avatar.default_record(), "Dan", "")
	needs.profile["presence_mode"] = "nobody"
	PresenceClient.set_pending_code("TESTTABLE1")
	main = await _main(true)
	ss = main.start_screen
	await _frames(3)
	flow = ss._modal.find_child("CheckInFlow", true, false) if is_instance_valid(ss._modal) else null
	check(flow != null and flow.find_child("Mode_everyone", true, false) == null, "consent already given: straight to the check-in")
	var err: Node = flow.find_child("Error", true, false) if flow else null
	check(err != null and "No signal" in err.text and not PresenceClient.viewer_here(needs), "offline: %s; nothing checked in" % (err.text if err else "-"))
	flow.find_child("Skip", true, false).pressed.emit()
	await _frames(3)
	check(ss.phase != StartScreen.Phase.TITLE, "Not now walks in")
	await _free(main)
	PresenceClient.reset()

	print("TEST PRESENCE CLIENT ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	for f in fails:
		print("  - ", f)
	quit(0 if fails.is_empty() else 1)


func _main(with_intro: bool) -> Node:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.intro = with_intro
	root.add_child(m)
	await _frames(3)
	return m


func _free(m: Node) -> void:
	m.queue_free()
	await _frames(3)


func _count(pat: Node, prefix: String) -> int:
	var n := 0
	for c in pat.get_children():
		if String(c.name).begins_with(prefix) and not c.is_queued_for_deletion():
			n += 1
	return n


func _label(n: Node, nm: String) -> String:
	var l := n.find_child(nm, true, false) as Label
	return l.text if l else ""


func _frames(k: int) -> void:
	for i in k:
		await process_frame
