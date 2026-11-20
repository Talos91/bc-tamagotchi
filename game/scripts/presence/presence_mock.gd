extends RefCounted
## In-memory presence server with the same rules as supabase/migrations (08b §1): one check-in per night, opening
## hours Tue–Sun 19:00–02:00 Bangkok, tablemates within 45 min, P1 visibility, P3 table only for checked-in viewers,
## verb limits, hide/report, push budget. Same four methods as presence_api.gd. One mock can be shared by several
## Presence nodes (the two-client test). Tokens are "mock:<uid>".

const Avatar = preload("res://scripts/avatar.gd")

## The check-in tables = docs/venue/qr/codes.json table_ids (QR remake 2026-11-20: Buffer + Main room, raised
## tables, bar; no Lounge). tests/test_qr_codes.gd keeps this, the codes and the venue's seats in step.
const TABLES := {
	"BufferTall0": "Buffer", "BufferTall1": "Buffer", "BufferTall2": "Buffer", "BufferTall3": "Buffer",
	"OpeningTall0": "Buffer", "OpeningTall1": "Buffer",
	"Table0": "Tables", "Table1": "Tables", "Table2": "Tables", "Table3": "Tables", "Table4": "Tables",
	"WestTable0": "Tables", "WestTable1": "Tables", "RectTableW": "Tables", "RectTableE": "Tables", "EastTable": "Tables",
	"Tiny0": "Tables", "Tiny1": "Tables", "Tiny2": "Tables", "Tiny3": "Tables", "Tiny4": "Tables", "Tiny5": "Tables",
	"TinyE0": "Tables", "TinyE1": "Tables", "TinyE2": "Tables",
	"Raised0": "Raised", "Raised1": "Raised", "Raised2": "Raised", "Raised3": "Raised", "Raised4": "Raised",
	"Bar": "Bar",
}
const PHRASE_RE := "^p(0[1-9]|1[0-9]|2[0-4])$"

var now_override := -1.0      ## unix seconds; -1 = system clock
var ignore_hours := false
var online := true            ## false: every call answers {ok:false, reason:"offline"}
var push_max_per_night := 3
var push_per_sender := 1
var push_from_hour := 19
var push_until_hour := 2
var tablemate_window_min := 45
var verbs_per_night := 40

var codes := {}               ## code -> {table_id, label, zone, active}
var profiles := {}            ## uid -> {display_name, avatar, mode, banned, name_hidden}
var checkins := {}            ## "uid|night" -> {player_id, night, table_id, at, first_at, display_name, avatar, visibility}
var attempts := {}            ## uid -> [unix]
var tablemates := {}          ## "night|a|b" -> table_id
var events: Array = []        ## {id, from, to, kind, payload, night, at, read}
var blocks := {}              ## "blocker|blocked" -> true
var reports: Array = []
var subs := {}                ## uid -> [endpoint]
var push_log: Array = []      ## {to, from, night, status}
var perf_reports: Array = []
var play_events: Array = []   ## bc_play_events rows: {player_id, at, kind, game, player_name, build, device, data}
var pushes_sent: Array = []   ## {to, title, body} — what a phone would have shown
var _seq := 0
var _uid_seq := 0


func _init() -> void:
	for t in TABLES:
		codes[code_for(t)] = {"table_id": t, "label": _label(t), "zone": TABLES[t], "active": true}


## A deterministic 10-character code per table for tests ("MkTable3xx" style, padded).
static func code_for(table_id: String) -> String:
	var s := ("Mk" + table_id.replace("Table", "T").replace("Tall", "L").replace("Opening", "Op")).rpad(10, "x").left(10)
	return s


static func _label(t: String) -> String:
	return t.replace("Table", "Table ").replace("Tall", "Tall ").strip_edges()


func now() -> float:
	return now_override if now_override >= 0.0 else Time.get_unix_time_from_system()


static func night_of(t: float) -> int:
	return int(floor((t + 3600.0) / 86400.0))     # Bangkok (UTC+7) day starting at 06:00


static func night_str(n: int) -> String:
	return Time.get_date_string_from_unix_time(n * 86400)


static func bkk_hour(t: float) -> int:
	return int(fposmod(t + 7 * 3600.0, 86400.0) / 3600.0)


func is_open(t := -1.0) -> bool:
	if t < 0.0:
		t = now()
	if ignore_hours:
		return true
	var isodow := ((night_of(t) + 3) % 7) + 1
	var h := bkk_hour(t)
	return isodow != 1 and (h >= 19 or h < 2)


# ------------------------------------------------------------------ transport interface

func signup() -> Dictionary:
	if not online:
		return {"ok": false, "reason": "offline"}
	_uid_seq += 1
	var uid := "00000000-0000-4000-8000-%012d" % _uid_seq
	return {"ok": true, "user_id": uid, "access_token": "mock:" + uid, "refresh_token": "mockr:" + uid,
		"expires_at": now() + 3600.0}


func refresh(refresh_token: String) -> Dictionary:
	if not online:
		return {"ok": false, "reason": "offline"}
	var uid := refresh_token.trim_prefix("mockr:")
	return {"ok": true, "user_id": uid, "access_token": "mock:" + uid, "refresh_token": refresh_token,
		"expires_at": now() + 3600.0}


func rpc(fn: String, args: Dictionary, token: String, _timeout: float) -> Dictionary:
	if not online:
		return {"ok": false, "reason": "offline"}
	var uid := token.trim_prefix("mock:")
	if not token.begins_with("mock:") or uid == "":
		return {"ok": false, "reason": "auth"}
	match fn:
		"bc_set_profile": return _set_profile(uid, args.get("p_display_name"), args.get("p_avatar"), args.get("p_mode"))
		"bc_check_in": return _check_in(uid, str(args.get("p_code", "")), str(args.get("p_display_name", "")),
				args.get("p_avatar", {}), str(args.get("p_mode", "")))
		"bc_tonight": return _tonight(uid)
		"bc_send_verb": return _send_verb(uid, str(args.get("p_to", "")), str(args.get("p_kind", "")), args.get("p_payload", {}))
		"bc_inbox": return _inbox(uid)
		"bc_mark_read": return _mark_read(uid, args.get("p_ids", []))
		"bc_hide": return _hide(uid, str(args.get("p_player", "")))
		"bc_report": return _report(uid, str(args.get("p_player", "")), str(args.get("p_reason", "")))
		"bc_save_push":
			_ensure(uid)
			subs[uid] = [str(args.get("p_endpoint", ""))]
			return {"ok": true}
		"bc_delete_push":
			subs.erase(uid)
			return {"ok": true}
		"bc_delete_me": return _delete_me(uid)
		"bc_perf_report":
			var today := perf_reports.filter(func(r): return r["player_id"] == uid and r["at"] > now() - 86400.0)
			if today.size() >= 30:
				return {"ok": false, "reason": "limit"}
			perf_reports.append({"player_id": uid, "at": now(), "version": str(args.get("p_version", "")).left(40),
				"device": args.get("p_device", {}), "numbers": args.get("p_numbers", {})})
			return {"ok": true, "id": perf_reports.size()}
		"bc_play_events":
			var evs = args.get("p_events", [])
			if not evs is Array or evs.size() > 50:
				return {"ok": false, "reason": "server", "detail": "events must be an array of at most 50"}
			if play_events.filter(func(r): return r["player_id"] == uid and r["at"] > now() - 86400.0).size() >= 3000:
				return {"ok": false, "reason": "limit"}
			var n := 0
			for e in evs:
				if not e is Dictionary or not str(e.get("kind", "")) in ["mg_start", "mg_end", "venue_session"]:
					continue
				play_events.append({"player_id": uid, "at": now(), "kind": e["kind"], "game": str(e.get("game", "")).left(40),
					"player_name": str(e.get("player_name", "")).left(40), "build": str(e.get("build", "")).left(40),
					"device": str(e.get("device", "")).left(60), "client_at": e.get("client_at"),
					"data": e.get("data", {}) if e.get("data") is Dictionary else {}})
				n += 1
			return {"ok": true, "stored": n}
	return {"ok": false, "reason": "server", "detail": "no function " + fn}


func edge(fn: String, body: Dictionary, token: String, timeout: float) -> Dictionary:
	if not online:
		return {"ok": false, "reason": "offline"}
	if fn != "verb":
		return {"ok": false, "reason": "server", "detail": "no edge " + fn}
	if body.get("action", "") == "public_key":
		return {"ok": true, "public_key": "BMockPublicKeyForTests"}
	var r := rpc("bc_send_verb", {"p_to": body.get("to", ""), "p_kind": body.get("kind", ""),
		"p_payload": body.get("payload", {})}, token, timeout)
	if r.get("ok", false):
		r["pushed"] = bool(r.get("push", false))
		if r["pushed"]:
			pushes_sent.append({"to": str(body.get("to", "")), "title": "Black Cabin",
				"body": push_text(str(r.get("from_name", "")), str(body.get("kind", "")))})
	return r


static func push_text(from_name: String, kind: String) -> String:
	match kind:
		"wave": return "%s waved at you at Black Cabin" % from_name
		"cheers": return "%s raised a glass to you" % from_name
		"drink": return "%s sent you a drink" % from_name
		"phrase": return "%s sent you a message" % from_name
	return "%s said hi" % from_name


# ------------------------------------------------------------------ test helpers

## n generated players checked in tonight (the debug "Fake presences"); returns their ids.
func add_fakes(n: int, seed_value := 7) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var names := ["Mai", "Ploy", "Nok", "Beam", "Fah", "Tong", "Joy", "Earth", "Mint", "Ice", "Pim", "Bank",
		"Kaew", "Oat", "Fern", "Nut", "Bow", "Toon", "May", "Gun"]
	var ids := []
	var tables := TABLES.keys()
	var t := now()
	for i in n:
		_uid_seq += 1
		var uid := "f0000000-0000-4000-8000-%012d" % _uid_seq
		var nm: String = names[i % names.size()] + ("" if i < names.size() else str(i / names.size() + 1))
		var av := Avatar.random_record(rng)
		profiles[uid] = {"display_name": nm, "avatar": av, "mode": "everyone", "banned": false, "name_hidden": false}
		var tid: String = tables[rng.randi() % tables.size()]
		var at := t - rng.randf_range(0.0, 3.0 * 3600.0)
		checkins["%s|%d" % [uid, night_of(t)]] = {"player_id": uid, "night": night_of(t), "table_id": tid, "at": at,
			"first_at": at, "display_name": nm, "avatar": av, "visibility": "everyone"}
		ids.append(uid)
	return ids


# ------------------------------------------------------------------ rules

static func _lo(x: String, y: String) -> String:
	return x if x < y else y


static func _hi(x: String, y: String) -> String:
	return y if x < y else x


func _ensure(uid: String) -> Dictionary:
	if not profiles.has(uid):
		profiles[uid] = {"display_name": "", "avatar": {}, "mode": "", "banned": false, "name_hidden": false}
	return profiles[uid]


func _blocked_between(x: String, y: String) -> bool:
	return blocks.has(x + "|" + y) or blocks.has(y + "|" + x)


func _shown_name(uid: String) -> String:
	var p: Dictionary = profiles.get(uid, {})
	if p.get("name_hidden", false):
		return "Guest %04d" % (abs(uid.hash()) % 10000)
	return str(p.get("display_name", ""))


func _set_profile(uid: String, name, avatar, mode) -> Dictionary:
	if mode != null and not str(mode) in ["", "everyone", "here", "nobody"]:
		return {"ok": false, "reason": "server", "detail": "bad mode"}
	var p := _ensure(uid)
	if name != null:
		p["display_name"] = str(name).left(24)
	if avatar is Dictionary:
		p["avatar"] = avatar
	if mode != null:
		p["mode"] = str(mode)
		if mode == "nobody":
			var k := "%s|%d" % [uid, night_of(now())]
			if checkins.has(k):
				checkins[k]["visibility"] = "nobody"
	return {"ok": true}


func _check_in(uid: String, code: String, name: String, avatar, mode: String) -> Dictionary:
	if not mode in ["everyone", "here", "nobody"]:
		return {"ok": false, "reason": "need_mode"}
	_set_profile(uid, name, avatar, mode)
	var p: Dictionary = profiles[uid]
	if p["banned"]:
		return {"ok": false, "reason": "banned"}
	var t := now()
	var tries: Array = attempts.get(uid, []).filter(func(a): return a > t - 600.0)
	if tries.size() >= 5:
		return {"ok": false, "reason": "rate_limited"}
	tries.append(t)
	attempts[uid] = tries
	var vt: Dictionary = codes.get(code, {})
	if vt.is_empty() or not vt["active"]:
		return {"ok": false, "reason": "bad_code"}
	if not is_open(t):
		return {"ok": false, "reason": "closed"}
	var n := night_of(t)
	var k := "%s|%d" % [uid, n]
	var first := not checkins.has(k)
	var moved := false
	if first:
		checkins[k] = {"player_id": uid, "night": n, "table_id": vt["table_id"], "at": t, "first_at": t,
			"display_name": p["display_name"], "avatar": p["avatar"], "visibility": mode}
	else:
		moved = checkins[k]["table_id"] != vt["table_id"]
		checkins[k].merge({"table_id": vt["table_id"], "at": t, "display_name": p["display_name"],
			"avatar": p["avatar"], "visibility": mode}, true)
	if mode != "nobody":
		for ck in checkins:
			var c: Dictionary = checkins[ck]
			if c["night"] != n or c["table_id"] != vt["table_id"] or c["player_id"] == uid:
				continue
			if c["visibility"] == "nobody" or profiles[c["player_id"]]["banned"] or c["at"] <= t - tablemate_window_min * 60.0:
				continue
			if _blocked_between(uid, c["player_id"]):
				continue
			var a: String = _lo(uid, c["player_id"])
			var b: String = _hi(uid, c["player_id"])
			if not tablemates.has("%d|%s|%s" % [n, a, b]):
				tablemates["%d|%s|%s" % [n, a, b]] = vt["table_id"]
	var mates := _presences(uid, n).filter(func(x): return x["tablemate"] and x["table_id"] == vt["table_id"])
	return {"ok": true, "night": night_str(n), "night_key": n, "table_id": vt["table_id"], "label": vt["label"],
		"first_of_night": first, "moved": moved, "tablemates": mates}


func _presences(viewer: String, n: int) -> Array:
	var here := checkins.has("%s|%d" % [viewer, n])
	var rows := []
	for ck in checkins:
		var c: Dictionary = checkins[ck]
		if c["night"] != n:
			continue
		var pid: String = c["player_id"]
		var me := pid == viewer
		if not me:
			if profiles[pid]["banned"] or _blocked_between(viewer, pid):
				continue
			if not (c["visibility"] == "everyone" or (c["visibility"] == "here" and here)):
				continue
		var a: String = _lo(viewer, pid)
		var b: String = _hi(viewer, pid)
		var met := events.any(func(e): return e["night"] == n and ((e["from"] == viewer and e["to"] == pid) or (e["to"] == viewer and e["from"] == pid)))
		var nights := 0
		var nights90 := 0
		for ck2 in checkins:
			if checkins[ck2]["player_id"] == pid:
				nights += 1
				if checkins[ck2]["night"] > n - 90:
					nights90 += 1
		rows.append({"player_id": pid, "display_name": c["display_name"] if me else _shown_name(pid),
			"avatar": c["avatar"], "table_id": c["table_id"] if here else "",
			"zone": TABLES.get(c["table_id"], "Tables"), "at": c["at"],
			"tablemate": tablemates.has("%d|%s|%s" % [n, a, b]), "friend": false,
			"regular": nights90 >= 5, "first_time": nights <= 1, "me": me, "_met": met})
	rows.sort_custom(func(x, y):
		for key in ["me", "tablemate", "friend", "_met"]:
			if x[key] != y[key]:
				return x[key]
		return x["at"] > y["at"])
	for r in rows:
		r.erase("_met")
	return rows


func _tonight(uid: String) -> Dictionary:
	var t := now()
	var n := night_of(t)
	var open := is_open(t)
	var mine: Dictionary = checkins.get("%s|%d" % [uid, n], {})
	var pres := []
	var last := []
	if open:
		pres = _presences(uid, n)
	else:
		var ln := n if bkk_hour(t) < 6 else n - 1
		for x in _presences(uid, ln):
			if not x["me"]:
				last.append({"player_id": x["player_id"], "display_name": x["display_name"], "avatar": x["avatar"]})
	return {"ok": true, "night": night_str(n), "open": open, "me_checked_in": open and not mine.is_empty(),
		"my_table": str(mine.get("table_id", "")) if open else "", "presences": pres, "last_night": last,
		"server_time": t}


func _send_verb(uid: String, to: String, kind: String, payload) -> Dictionary:
	if to == uid:
		return {"ok": false, "reason": "self"}
	if not kind in ["wave", "cheers", "drink", "phrase"]:
		return {"ok": false, "reason": "bad_kind"}
	var me := _ensure(uid)
	if me["banned"]:
		return {"ok": false, "reason": "banned"}
	var t := now()
	if not is_open(t):
		return {"ok": false, "reason": "not_tonight"}
	var n := night_of(t)
	var rc: Dictionary = checkins.get("%s|%d" % [to, n], {})
	var sender_here := checkins.has("%s|%d" % [uid, n])
	if rc.is_empty() or rc["visibility"] == "nobody" or (rc["visibility"] == "here" and not sender_here) \
			or profiles[to]["banned"] or blocks.has(uid + "|" + to):
		return {"ok": false, "reason": "not_tonight"}
	if blocks.has(to + "|" + uid):
		return {"ok": true, "event_id": 0, "push": false}
	var per_pair := 3 if kind == "phrase" else 1
	var pair := events.filter(func(e): return e["from"] == uid and e["to"] == to and e["night"] == n and e["kind"] == kind).size()
	var total := events.filter(func(e): return e["from"] == uid and e["night"] == n).size()
	if pair >= per_pair or total >= verbs_per_night:
		return {"ok": false, "reason": "limit"}
	var pl := {}
	var pd: Dictionary = payload if payload is Dictionary else {}
	if kind == "phrase":
		var re := RegEx.create_from_string(PHRASE_RE)
		if re.search(str(pd.get("phrase", ""))) == null:
			return {"ok": false, "reason": "bad_kind", "detail": "phrase"}
		pl = {"phrase": str(pd["phrase"]), "emoji": str(pd.get("emoji", "")).left(8)}
	elif kind == "drink":
		var re2 := RegEx.create_from_string("^[a-z0-9_]{1,40}$")
		if not str(pd.get("band", "")) in ["4", "6", "9"] or re2.search(str(pd.get("drink_id", ""))) == null:
			return {"ok": false, "reason": "bad_kind", "detail": "drink"}
		pl = {"drink_id": str(pd["drink_id"]), "band": int(str(pd["band"]))}
	_seq += 1
	events.append({"id": _seq, "from": uid, "to": to, "kind": kind, "payload": pl, "night": n, "at": t, "read": false})
	var h := bkk_hour(t)
	var in_window := (h >= push_from_hour and h < push_until_hour) if push_from_hour <= push_until_hour \
		else (h >= push_from_hour or h < push_until_hour)
	var to_n := push_log.filter(func(l): return l["to"] == to and l["night"] == n).size()
	var pair_n := push_log.filter(func(l): return l["to"] == to and l["from"] == uid and l["night"] == n).size()
	var do_push: bool = not subs.get(to, []).is_empty() and in_window and to_n < push_max_per_night and pair_n < push_per_sender
	if do_push:
		push_log.append({"to": to, "from": uid, "night": n, "status": "sent"})
	return {"ok": true, "event_id": _seq, "push": do_push, "from_name": _shown_name(uid)}


func _inbox(uid: String) -> Dictionary:
	var out := []
	for e in events:
		if e["to"] != uid or e["read"] or blocks.has(uid + "|" + e["from"]):
			continue
		var p: Dictionary = profiles.get(e["from"], {})
		out.append({"id": e["id"], "kind": e["kind"], "payload": e["payload"], "night": night_str(e["night"]),
			"at": e["at"], "from": {"player_id": e["from"], "display_name": _shown_name(e["from"]),
			"avatar": p.get("avatar", {})}})
	return {"ok": true, "events": out}


func _mark_read(uid: String, ids) -> Dictionary:
	var m := 0
	for e in events:
		if e["to"] == uid and not e["read"] and (ids as Array).has(e["id"]):
			e["read"] = true
			m += 1
	return {"ok": true, "marked": m}


func _hide(uid: String, other: String) -> Dictionary:
	if other != uid and profiles.has(other):
		blocks[uid + "|" + other] = true
	return {"ok": true}


func _report(uid: String, other: String, reason: String) -> Dictionary:
	if other == uid or not reason in ["name", "harassment", "other"] or not profiles.has(other):
		return {"ok": false, "reason": "server", "detail": "bad report"}
	_ensure(uid)
	_hide(uid, other)
	reports.append({"reporter": uid, "target": other, "reason": reason, "at": now()})
	var who := {}
	for r in reports:
		if r["target"] == other and r["at"] > now() - 30 * 86400.0:
			who[r["reporter"]] = true
	if who.size() >= 3:
		profiles[other]["name_hidden"] = true
	return {"ok": true}


func _delete_me(uid: String) -> Dictionary:
	profiles.erase(uid)
	for k in checkins.keys():
		if checkins[k]["player_id"] == uid:
			checkins.erase(k)
	for k in tablemates.keys():
		if uid in k:
			tablemates.erase(k)
	events = events.filter(func(e): return e["from"] != uid and e["to"] != uid)
	for k in blocks.keys():
		if uid in k:
			blocks.erase(k)
	reports = reports.filter(func(r): return r["reporter"] != uid)
	subs.erase(uid)
	attempts.erase(uid)
	return {"ok": true}


## Rows a player still has anywhere (for the delete_me test).
func rows_of(uid: String) -> int:
	var c := 1 if profiles.has(uid) else 0
	for k in checkins:
		if checkins[k]["player_id"] == uid:
			c += 1
	for k in tablemates:
		if uid in k:
			c += 1
	c += events.filter(func(e): return e["from"] == uid or e["to"] == uid).size()
	for k in blocks:
		if uid in k:
			c += 1
	c += 1 if subs.has(uid) else 0
	return c
