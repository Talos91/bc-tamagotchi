extends SceneTree
## Presence network layer (docs/design/08b-presence-api.md), headless. Offline by default: every rule runs against
## the in-memory server (presence_mock.gd) with two-plus clients sharing it — check-in, one per night, opening hours,
## tablemates (45 min), P1 visibility, P3 table, verbs and limits, inbox, hide/report, push budget, offline queue and
## reconnect, delete_me, polling diffs, the autoload's Needs.check_in hook.
##   godot --headless --path . -s tests/test_presence_net.gd
## Live two-client run against the real Supabase project (needs network; leaves no rows: both players delete_me):
##   godot --headless --path . -s tests/test_presence_net.gd -- --live [--code <table code>]

const PresenceScript = preload("res://scripts/presence/presence.gd")
const Mock = preload("res://scripts/presence/presence_mock.gd")

var fails := 0
var checks := 0
var mock: RefCounted
var _n := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ", what)


func _init() -> void:
	await process_frame
	if "--live" in OS.get_cmdline_user_args():
		await _live()
	else:
		await _offline()
	print("presence_net: %d checks, %d failures" % [checks, fails])
	print("TEST PRESENCE_NET ", "PASS" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)


func client(mode := "everyone", name := "") -> Node:
	_n += 1
	var p: Node = PresenceScript.new()
	p.store_path = "user://test_presence_%d.json" % _n
	p.apply_to_needs = false
	root.add_child(p)
	p.reset_local()
	if mock != null:
		p.use_mock(true, mock)
	else:
		p.go_live()           # live run only (08b §1.1: nothing goes on the network unless asked)
	if mode != "":
		await p.set_mode(mode)
	if name != "":
		p.identity = {"name": name}
	return p


static func bkk(y: int, mo: int, d: int, h: int, mi := 0) -> float:
	return Time.get_unix_time_from_datetime_dict({"year": y, "month": mo, "day": d, "hour": h, "minute": mi,
		"second": 0}) - 7 * 3600.0


func find(rows: Array, id: String) -> Dictionary:
	for r in rows:
		if r.get("player_id", "") == id:
			return r
	return {}


func _offline() -> void:
	await _off_switch()
	mock = Mock.new()
	await _clock_rules()
	await _checkin_and_tablemates()
	await _verbs_and_inbox()
	await _push_budget()
	await _offline_queue()
	await _report_and_delete()
	await _check_out()
	await _still_here()
	await _autoload_hook()
	await _perf()


func _perf() -> void:
	var p: Node = await client("")
	var r: Dictionary = await p.perf_report("v0.3.0 test", {"ua": "test", "dpr": 2}, {"fps_p50": 58, "fps_p5": 31})
	check(r.get("ok") and mock.perf_reports[-1]["player_id"] == p.player_id() and mock.perf_reports[-1]["numbers"]["fps_p5"] == 31,
		"perf report stored with the player id (%s)" % r)
	for i in 29:
		await p.perf_report("v", {}, {})
	r = await p.perf_report("v", {}, {})
	check(r.get("reason") == "limit", "31st perf report in a day: limit")


func _off_switch() -> void:
	var p: Node = PresenceScript.new()
	p.store_path = "user://test_presence_off.json"
	root.add_child(p)
	p.reset_local()
	p.transport = null
	var r: Dictionary = await p.checkin("AAAAAAAAAA")
	check(r.get("reason") == "off", "no transport: checkin off (%s)" % r)
	r = await p.tonight()
	check(r.get("reason") == "off" and r.get("presences") == [], "no transport: tonight off, empty")
	r = await p.send_verb("x", "wave")
	check(r.get("reason") == "off", "no transport: verb off")
	check(PresenceScript.ON == (preload("res://scripts/presence/presence_config.gd").URL != ""), "ON follows config")
	p.queue_free()


func _clock_rules() -> void:
	# Night key = needs.gd night_key (Bangkok day from 06:00): Friday 2026-11-20 01:30 belongs to Thursday's night.
	var fri21 := bkk(2026, 11, 20, 21)
	var sat0130 := bkk(2026, 11, 21, 1, 30)
	var needs_key := func(t: float) -> int: return int(floor((t + (7.0 - 6.0) * 3600.0) / 86400.0))
	check(Mock.night_of(fri21) == needs_key.call(fri21) and Mock.night_of(sat0130) == Mock.night_of(fri21),
		"night key matches needs.gd and after-midnight belongs to the night before")
	check(Mock.night_str(Mock.night_of(fri21)) == "2026-11-20", "night string")
	check(mock.is_open(fri21), "Friday 21:00 open")
	check(mock.is_open(sat0130), "Saturday 01:30 (Friday night) open")
	check(not mock.is_open(bkk(2026, 11, 21, 2, 30)), "02:30 closed")
	check(not mock.is_open(bkk(2026, 11, 20, 18, 59)), "18:59 closed")
	check(not mock.is_open(bkk(2026, 11, 23, 21)), "Monday 21:00 closed")
	check(not mock.is_open(bkk(2026, 11, 24, 1)), "Tuesday 01:00 (Monday night) closed")
	check(mock.is_open(bkk(2026, 11, 23, 1)), "Monday 01:00 (Sunday night) open")
	mock.ignore_hours = true
	check(mock.is_open(bkk(2026, 11, 23, 12)), "ignore_hours opens any time")
	mock.ignore_hours = false
	var p: Node = await client("")
	mock.now_override = bkk(2026, 11, 21, 3)
	var r: Dictionary = await p.checkin(Mock.code_for("Table3"))
	check(r.get("reason") == "need_mode", "no presence mode yet: need_mode, nothing written (%s)" % r)
	check(p.player_id() == "", "need_mode makes no account")
	await p.set_mode("everyone")
	r = await p.checkin(Mock.code_for("Table3"))
	check(r.get("reason") == "closed", "03:00 check-in refused: closed (%s)" % r)
	r = await p.checkin("ZZZZZZZZZZ")
	check(r.get("reason") == "bad_code", "unknown code: bad_code")
	r = await p.checkin("short")
	check(r.get("reason") == "bad_code", "malformed code refused locally")
	for i in 3:
		await p.checkin("ZZZZZZZZZZ")
	r = await p.checkin(Mock.code_for("Table3"))
	check(r.get("reason") == "rate_limited", "6th try in 10 min: rate_limited (%s)" % r)
	p.queue_free()


func _checkin_and_tablemates() -> void:
	var t0 := bkk(2026, 11, 20, 21)
	mock.now_override = t0
	var a: Node = await client("everyone", "Mai")
	var b: Node = await client("everyone", "Ploy")
	var c: Node = await client("everyone", "Nok")
	var home: Node = await client("everyone", "Beam")
	var here: Node = await client("here", "Fah")
	var hidden: Node = await client("nobody", "Tong")
	set_meta("a", a); set_meta("b", b); set_meta("c", c); set_meta("home", home); set_meta("here", here)
	var r: Dictionary = await a.checkin(Mock.code_for("Table3"))
	check(r.get("ok") and r.get("first_of_night") and r.get("table_id") == "Table3" and r.get("night") == "2026-11-20",
		"A checks in at Table3: first of night (%s)" % r)
	check(r.get("tablemates") == [], "A alone: no tablemates")
	mock.now_override = t0 + 600.0
	r = await b.checkin(Mock.code_for("Table3"))
	check(r.get("ok") and r["tablemates"].size() == 1 and r["tablemates"][0]["player_id"] == a.player_id(),
		"B 10 min later at Table3: tablemate A (%s)" % [r.get("tablemates")])
	check(r["tablemates"][0]["display_name"] == "Mai" and r["tablemates"][0]["table_id"] == "Table3", "tablemate row has name and table")
	mock.now_override = t0 + 50 * 60.0
	r = await c.checkin(Mock.code_for("Table3"))
	var ids: Array = r["tablemates"].map(func(x): return x["player_id"])
	check(ids.has(b.player_id()) and not ids.has(a.player_id()), "C 50 min after A, 40 after B: tablemate B only (%s)" % [ids])
	r = await here.checkin(Mock.code_for("Raised2"))
	check(r.get("ok"), "here-mode player checks in")
	r = await hidden.checkin(Mock.code_for("Table3"))
	check(r.get("ok") and r.get("first_of_night") and r.get("tablemates") == [], "nobody-mode check-in counts, no tablemates")

	var ta: Dictionary = await a.tonight(true)
	var rows: Array = ta["presences"]
	check(ta.get("me_checked_in") and ta.get("my_table") == "Table3", "A's tonight: checked in at Table3")
	check(rows[0]["me"] and rows[0]["player_id"] == a.player_id(), "own row first, me:true")
	check(not find(rows, b.player_id()).is_empty() and find(rows, b.player_id())["tablemate"], "A sees B as tablemate")
	check(find(rows, b.player_id())["table_id"] == "Table3", "checked-in viewer sees the real table (P3)")
	check(not find(rows, here.player_id()).is_empty(), "checked-in viewer sees a here-mode player")
	check(find(rows, hidden.player_id()).is_empty(), "nobody-mode player never shown")
	check(rows[1]["tablemate"], "tablemates sorted before others")
	var th: Dictionary = await home.tonight(true)
	var hb := find(th["presences"], b.player_id())
	check(not th.get("me_checked_in") and hb.get("table_id") == "" and hb.get("zone") == "Tables",
		"viewer at home: no table, zone only (P3) (%s)" % hb)
	check(find(th["presences"], here.player_id()).is_empty(), "viewer at home does not see a here-mode player")
	check(hb.get("first_time") == true and hb.get("regular") == false, "first_time / regular flags")
	r = await home.send_verb(here.player_id(), "wave")
	check(r.get("reason") == "not_tonight", "verb to someone the sender cannot see: not_tonight (%s)" % r)

	mock.now_override = t0 + 60 * 60.0
	r = await a.checkin(Mock.code_for("Table1"))
	check(r.get("ok") and not r.get("first_of_night") and r.get("moved"), "A rescans at Table1: same visit, moved")
	ta = await a.tonight(true)
	check(ta.get("my_table") == "Table1", "A's presence moved to Table1")
	r = await a.checkin(Mock.code_for("Table3"))
	check(r.get("moved") and not r.get("first_of_night"), "and back to Table3")

	# Polling diff: a late check-in shows up in `added`.
	var got := []
	var cb := func(_p, added, _r): got.append_array(added)
	b.tonight_changed.connect(cb)
	await b.tonight(true)
	got.clear()
	var late: Node = await client("everyone", "Joy")
	await late.checkin(Mock.code_for("BufferTall2"))
	await b.tonight()               # cached (< 2 min): no request, no signal
	check(got.is_empty(), "tonight() within POLL_S answers from cache")
	await b.tonight(true)
	check(got.has(late.player_id()), "late check-in arrives in tonight_changed added (%s)" % [got])
	b.tonight_changed.disconnect(cb)
	set_meta("late", late)
	# Fake presences for the offline client.
	var fakes: Array = mock.add_fakes(12)
	var tf: Dictionary = await home.tonight(true)
	check(fakes.size() == 12 and fakes.all(func(i): return not find(tf["presences"], i).is_empty()), "12 fake presences tonight")
	check(find(tf["presences"], fakes[0])["avatar"] is Dictionary and not find(tf["presences"], fakes[0])["avatar"].is_empty(), "fakes carry an avatar record")
	# "Nobody" set mid-night hides at once.
	r = await late.set_mode("nobody")
	tf = await home.tonight(true)
	check(find(tf["presences"], late.player_id()).is_empty(), "switching to Nobody hides tonight's presence at once")


func _verbs_and_inbox() -> void:
	var a: Node = get_meta("a")
	var b: Node = get_meta("b")
	var home: Node = get_meta("home")
	var r: Dictionary = await home.checkin(Mock.code_for("Bar"))
	check(r.get("ok") and r.get("table_id") == "Bar", "the player at home arrives at the bar counter")
	r = await a.send_verb(b.player_id(), "wave")
	check(r.get("ok") and r.get("event_id", 0) > 0, "A waves at B (%s)" % r)
	r = await a.send_verb(b.player_id(), "wave")
	check(r.get("reason") == "limit", "second wave same night: limit")
	for i in 3:
		r = await a.send_verb(b.player_id(), "phrase", {"phrase": "p0%d" % (i + 1), "emoji": "🍸"})
		check(r.get("ok"), "phrase %d ok" % (i + 1))
	r = await a.send_verb(b.player_id(), "phrase", {"phrase": "p05"})
	check(r.get("reason") == "limit", "4th phrase: limit")
	r = await a.send_verb(home.player_id(), "phrase", {"phrase": "p25"})
	check(r.get("reason") == "bad_kind", "unknown phrase id refused")
	r = await a.send_verb(home.player_id(), "drink", {"drink_id": "negroni", "band": 5})
	check(r.get("reason") == "bad_kind", "drink with a band outside 4/6/9 refused")
	r = await a.send_verb(home.player_id(), "drink", {"drink_id": "negroni", "band": 6})
	check(r.get("ok"), "drink to a player at home who is in everyone's bar")
	r = await a.send_verb(a.player_id(), "wave")
	check(r.get("reason") == "self", "verb to self refused")
	r = await a.send_verb(b.player_id(), "hug")
	check(r.get("reason") == "bad_kind", "unknown verb refused")
	var inbox: Dictionary = await b.inbox()
	var ev: Array = inbox["events"]
	check(ev.size() == 4 and ev[0]["kind"] == "wave" and ev[0]["from"]["display_name"] == "Mai", "B's inbox: wave + 3 phrases from Mai (%d)" % ev.size())
	check(ev[1]["payload"].get("phrase") == "p01" and ev[1]["payload"].get("emoji") == "🍸", "phrase payload kept")
	r = await b.mark_read(ev.map(func(e): return e["id"]))
	check(r.get("marked") == 4, "mark_read 4")
	inbox = await b.inbox()
	check(inbox["events"].is_empty(), "inbox empty after mark_read")
	var ti: Dictionary = await b.tonight(true)
	check(ti["presences"][1]["player_id"] == a.player_id(), "someone you interacted with (and a tablemate) sorts first")
	# Hide: gone both ways; their verbs are accepted and dropped silently.
	r = await b.hide(a.player_id())
	check(r.get("ok"), "B hides A")
	ti = await b.tonight(true)
	check(find(ti["presences"], a.player_id()).is_empty(), "A gone from B's bar")
	var ta: Dictionary = await a.tonight(true)
	check(find(ta["presences"], b.player_id()).is_empty(), "B gone from A's bar")
	r = await a.send_verb(b.player_id(), "cheers")
	check(r.get("ok") and r.get("event_id") == 0 and not r.get("pushed", false), "A's cheers to B accepted and dropped (sender not told)")
	inbox = await b.inbox()
	check(inbox["events"].is_empty(), "nothing from a hidden player reaches the inbox")


func _push_budget() -> void:
	var c: Node = get_meta("c")
	var home: Node = get_meta("home")
	var here: Node = get_meta("here")
	var r: Dictionary = await c.mock_push_subscribe()
	check(r.get("ok"), "C subscribes to push")
	var senders := []
	for nm in ["S1", "S2", "S3", "S4"]:
		var s: Node = await client("everyone", nm)
		await s.checkin(Mock.code_for("Table4"))
		senders.append(s)
	r = await senders[0].send_verb(c.player_id(), "wave")
	check(r.get("ok") and r.get("pushed"), "wave to a subscribed player is pushed (%s)" % r)
	check(mock.pushes_sent[-1]["body"] == "S1 waved at you at Black Cabin", "push text names the sender (%s)" % mock.pushes_sent[-1])
	r = await senders[0].send_verb(c.player_id(), "cheers")
	check(r.get("ok") and not r.get("pushed"), "second verb from the same sender: inbox only (1 push per sender a night)")
	r = await senders[1].send_verb(c.player_id(), "wave")
	check(r.get("pushed"), "second sender pushed")
	r = await senders[2].send_verb(c.player_id(), "wave")
	check(r.get("pushed"), "third sender pushed")
	r = await senders[3].send_verb(c.player_id(), "wave")
	check(r.get("ok") and not r.get("pushed"), "fourth push in a night refused: cap 3")
	r = await senders[0].send_verb(home.player_id(), "wave")
	check(r.get("ok") and not r.get("pushed"), "not subscribed: no push")
	var inbox: Dictionary = await c.inbox()
	check(inbox["events"].size() == 5, "every verb is in the inbox, pushed or not (%d)" % inbox["events"].size())
	set_meta("senders", senders)


func _offline_queue() -> void:
	var b: Node = get_meta("b")
	var c: Node = get_meta("c")
	var seen := []
	b.status_changed.connect(func(s): seen.append(s))
	var before: Dictionary = await b.tonight(true)
	mock.online = false
	var r: Dictionary = await b.tonight(true)
	check(r.get("reason") == "offline" and r["presences"].size() == before["presences"].size(), "offline tonight: cached list, no error")
	check(b.status == "offline" and seen.has("offline"), "status offline")
	r = await b.send_verb(c.player_id(), "wave")
	check(r.get("reason") == "offline" and r.get("queued"), "verb offline: queued")
	r = await b.checkin(Mock.code_for("Table3"))
	check(r.get("reason") == "offline", "check-in offline: refused, never queued")
	mock.online = true
	await b.tonight(true)
	check(b.status == "online", "status back online")
	var inbox: Dictionary = await c.inbox()
	check(inbox["events"].any(func(e): return e["from"]["player_id"] == b.player_id() and e["kind"] == "wave"),
		"queued wave delivered on reconnect")
	# A verb queued last night is dropped.
	mock.online = false
	await b.send_verb(get_meta("home").player_id(), "cheers")
	mock.online = true
	mock.now_override += 24 * 3600.0
	await b.tonight(true)
	inbox = await get_meta("home").inbox()
	check(not inbox["events"].any(func(e): return e["kind"] == "cheers" and e["from"]["player_id"] == b.player_id()),
		"verb queued on a night that ended is dropped")
	mock.now_override -= 24 * 3600.0


func _report_and_delete() -> void:
	var c: Node = get_meta("c")
	var senders: Array = get_meta("senders")
	var target: Node = get_meta("home")
	for s in senders.slice(0, 3):
		var r: Dictionary = await s.report(target.player_id(), "name")
		check(r.get("ok"), "report ok")
	var r2: Dictionary = await s_tonight(c)
	var row := find(r2["presences"], target.player_id())
	check(row.get("display_name", "").begins_with("Guest "), "3 reports in 30 days: name shown as Guest #### (%s)" % row.get("display_name"))
	var bad: Dictionary = await c.report(target.player_id(), "rude")
	check(not bad.get("ok"), "unknown report reason refused")
	var id: String = c.player_id()
	check(mock.rows_of(id) > 0, "C has rows before delete")
	var d: Dictionary = await c.delete_me()
	check(d.get("ok") and mock.rows_of(id) == 0 and c.player_id() == "", "delete_me: no rows left, local id cleared")


## Hotfix 3 (Daniele 11-20/21): Leave checks out at once; nothing else does; a re-scan checks in again.
func _check_out() -> void:
	mock.now_override = bkk(2026, 11, 27, 22)
	var x: Node = await client("everyone", "Lek")
	var y: Node = await client("everyone", "Om")
	var z: Node = await client("everyone", "Late")   # never scans: still sees everyone
	await x.checkin(Mock.code_for("WestTable0"))
	await y.checkin(Mock.code_for("WestTable0"))
	check(x.my_table == "WestTable0", "my_table set by the check-in answer")
	var rows: Array = (await z.tonight(true))["presences"]
	check(not find(rows, x.player_id()).is_empty() and not find(rows, y.player_id()).is_empty(),
		"a player who did not scan sees both check-ins")
	mock.now_override += 80 * 60.0   # phones locked, "Still here?" not answered yet (E): still in until 90 min
	rows = (await z.tonight(true))["presences"]
	check(not find(rows, x.player_id()).is_empty(), "no heartbeat: still shown 80 min later with phones locked")
	var r: Dictionary = await x.check_out()
	check(r.get("ok") and r.get("was_in"), "Leave: check_out ok (%s)" % r)
	check(x.my_table == "", "my_table cleared on Leave")
	rows = (await y.tonight(true))["presences"]
	check(find(rows, x.player_id()).is_empty(), "the others' next poll drops the player who left")
	check(find(rows, y.player_id())["table_id"] == "WestTable0", "the one who stayed keeps the table")
	var tx: Dictionary = await x.tonight(true)
	check(not tx.get("presences", []).is_empty() and find(tx["presences"], y.player_id())["table_id"] == "",
		"after Leave the player is no longer 'here' (tables hidden)")
	r = await x.checkin(Mock.code_for("WestTable0"))
	check(r.get("ok") and not r.get("first_of_night"), "re-scan the same night: in again, not a first scan")
	rows = (await y.tonight(true))["presences"]
	check(not find(rows, x.player_id()).is_empty(), "after the re-scan the others see them again")
	for n in [x, y, z]:
		n.queue_free()


## E (Daniele 11-21): "Still at Black Cabin?" an hour after the check-in and every hour after a Yes; no answer in
## 30 minutes checks out.
func _still_here() -> void:
	var t0 := bkk(2026, 12, 4, 20)
	mock.now_override = t0
	var x: Node = await client("everyone", "Still")
	var y: Node = await client("everyone", "Watcher")
	await x.checkin(Mock.code_for("Table1"))
	await y.checkin(Mock.code_for("Table2"))
	var asked := []
	x.still_due_changed.connect(func(d): asked.append(d))
	mock.now_override = t0 + 59 * 60.0
	await x.tonight(true)
	check(not x.still_due, "59 min after the check-in: no prompt yet")
	mock.now_override = t0 + 61 * 60.0
	var tx: Dictionary = await x.tonight(true)
	check(x.still_due and asked == [true], "61 min: still_due set, signal once (%s)" % [asked])
	check(absf(x.still_deadline - (t0 + 90 * 60.0)) < 1.0, "deadline = check-in + 90 min")
	var r: Dictionary = await x.still_here()
	check(r.get("ok") and not x.still_due, "Yes, I'm here: ok, prompt cleared")
	mock.now_override = t0 + 61 * 60.0 + 59 * 60.0
	await x.tonight(true)
	check(not x.still_due, "59 min after the Yes: no prompt")
	mock.now_override = t0 + 61 * 60.0 + 61 * 60.0
	await x.tonight(true)
	check(x.still_due, "an hour after the Yes: asked again")
	mock.now_override = t0 + 61 * 60.0 + 91 * 60.0
	var rows: Array = (await y.tonight(true))["presences"]
	check(find(rows, x.player_id()).is_empty(), "no answer within 30 min: the others no longer see them")
	tx = await x.tonight(true)
	check(not tx.get("me_checked_in") and x.my_table == "" and not x.still_due, "and they read as checked out")
	r = await x.still_here()
	check(r.get("reason") == "left", "a late Yes answers left (scan again)")
	r = await x.checkin(Mock.code_for("Table1"))
	check(r.get("ok"), "re-scan checks in again")
	rows = (await y.tonight(true))["presences"]
	check(not find(rows, x.player_id()).is_empty(), "seen again after the re-scan")
	await x.tonight(true)
	check(not x.still_due, "the re-scan restarts the hour")
	for n in [x, y]:
		n.queue_free()


func s_tonight(p: Node) -> Dictionary:
	return await p.tonight(true)


func _autoload_hook() -> void:
	var pres: Node = root.get_node_or_null("Presence")
	var needs: Node = root.get_node_or_null("Needs")
	check(pres != null, "Presence autoload registered")
	if pres == null or needs == null:
		return
	pres.reset_local("user://test_presence_autoload.json")
	pres.use_mock(true, mock)
	pres.set_pending_code("bad")
	check(pres.pending_code() == "", "malformed address code ignored")
	pres.set_pending_code(Mock.code_for("EastTable"))
	check(pres.pending_code() == Mock.code_for("EastTable"), "address code kept")
	await pres.set_mode("everyone")
	mock.now_override = bkk(2026, 11, 20, 22)
	var was: bool = needs.has_checked_in
	var r: Dictionary = await pres.checkin(pres.pending_code())
	check(r.get("ok") and r.get("first_of_night") and r.has("needs"), "autoload check-in runs Needs.check_in (%s)" % r)
	check(needs.has_checked_in and str(needs.profile.get("player_id", "")) == pres.player_id(),
		"Needs marked checked in and profile.player_id = account id (was %s)" % was)
	check(pres.pending_code() == "", "pending code cleared after use")
	r = await pres.checkin(Mock.code_for("EastTable"))
	check(r.get("ok") and not r.get("first_of_night") and not r.has("needs"), "re-scan does not run Needs.check_in again")
	check(pres.push_supported() == "no", "push unsupported off the web")
	pres.use_mock(false)
	pres.reset_local("user://presence.json")


# ------------------------------------------------------------------ live (real Supabase project)

func _live() -> void:
	if not PresenceScript.ON:
		check(false, "live: presence_config.gd has no URL")
		return
	mock = null
	var args := OS.get_cmdline_user_args()
	var code := ""
	if "--code" in args:
		code = args[args.find("--code") + 1]
	else:
		var path := ProjectSettings.globalize_path("res://").path_join("../docs/venue/qr/codes.json")
		var codes = JSON.parse_string(FileAccess.get_file_as_string(path))
		code = str(codes.get("Table3", "")) if codes is Dictionary else ""
	var a: Node = await client("everyone")
	var b: Node = await client("everyone")
	a.identity = {"name": "TestA"}
	b.identity = {"name": "TestB"}
	var t0 := Time.get_ticks_msec()
	var ra: Dictionary = await a.checkin(code)
	print("live: A check-in %s (%d ms)" % [JSON.stringify(ra).left(200), Time.get_ticks_msec() - t0])
	check(ra.get("ok", false), "live: A checks in (%s)" % ra.get("reason", ""))
	if not ra.get("ok", false):
		await a.delete_me()
		await b.delete_me()
		return
	var rb: Dictionary = await b.checkin(code)
	check(rb.get("ok") and rb.get("tablemates", []).any(func(x): return x["player_id"] == a.player_id()),
		"live: B checks in at the same table, tablemate A")
	var ta: Dictionary = await a.tonight(true)
	var row := find(ta.get("presences", []), b.player_id())
	check(ta.get("ok") and not row.is_empty() and row.get("tablemate") and row.get("table_id") == ra.get("table_id"),
		"live: A's tonight shows B as tablemate at the table (%d presences)" % ta.get("presences", []).size())
	var v: Dictionary = await a.send_verb(b.player_id(), "wave")
	check(v.get("ok") and int(v.get("event_id", 0)) > 0, "live: A waves at B through the Edge Function (%s)" % v)
	v = await a.send_verb(b.player_id(), "wave")
	check(v.get("reason") == "limit", "live: second wave: limit (%s)" % v)
	v = await a.send_verb(b.player_id(), "phrase", {"phrase": "p07", "emoji": "🍸"})
	check(v.get("ok"), "live: phrase")
	var ib: Dictionary = await b.inbox()
	var evs: Array = ib.get("events", [])
	check(ib.get("ok") and evs.size() == 2 and evs[0]["kind"] == "wave" and evs[0]["from"]["player_id"] == a.player_id(),
		"live: B's inbox has the wave and the phrase (%d)" % evs.size())
	var m: Dictionary = await b.mark_read(evs.map(func(e): return e["id"]))
	check(m.get("marked") == 2, "live: mark_read (%s)" % m)
	ib = await b.inbox()
	check(ib.get("events", [1]).is_empty(), "live: inbox empty after read")
	var h: Dictionary = await b.hide(a.player_id())
	var tb: Dictionary = await b.tonight(true)
	check(h.get("ok") and find(tb.get("presences", []), a.player_id()).is_empty(), "live: B hides A, A gone")
	v = await a.send_verb(b.player_id(), "cheers")
	check(v.get("ok") and int(v.get("event_id", -1)) == 0, "live: cheers to a hider dropped silently (%s)" % v)
	var k: Dictionary = await a._edge("verb", {"action": "public_key"}, 8.0)
	check(k.get("ok") and str(k.get("public_key", "")).length() == 87, "live: VAPID public key served (65-byte point)")
	var pr: Dictionary = await a.perf_report("live-test", {"ua": "headless"}, {"fps_p50": 60})
	check(pr.get("ok") and int(pr.get("id", 0)) > 0, "live: perf report inserted (%s)" % pr)
	var da: Dictionary = await a.delete_me()
	var db: Dictionary = await b.delete_me()
	check(da.get("ok") and db.get("ok"), "live: both players deleted (no rows left)")
