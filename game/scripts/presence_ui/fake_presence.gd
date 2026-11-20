extends RefCounted
## "Fake presences" (docs/design/08-presence.md §8, build step 2): an offline presence source that answers in the
## shapes of the backend contract (docs/design/08b-presence-api.md §3, the `Presence` autoload), so the venue, the
## card, the verbs, the inbox and the check-in flow run with no backend. Twelve generated people checked in tonight,
## two of them in mode "here" (only viewers checked in tonight see them), Mai a tablemate, Ploy a friend; a received
## wave and a drink in the inbox. Nothing leaves the phone. Deterministic: the same seed gives the same night.
##
## Calls answer through a callback, at once (PresenceClient wraps the real, awaited autoload the same way):
##   tonight(cb)                         cb.call({ok, reason, me_checked_in, presences: [<presence>]})
##   checkin(code, mode, cb)             cb.call({ok, reason, table_id, label, first_of_night, tablemates: [<presence>]})
##   send_verb(to, kind, payload, cb)    cb.call({ok, reason})
##   inbox(cb)                           cb.call({ok, events: [{id, from: {player_id, display_name, avatar}, kind, payload, at}]})
##   mark_read(ids) / hide(id) / report(id, reason)
## <presence> as 08b §3.2: player_id, display_name, avatar, table_id ("" unless the viewer checked in), zone, at,
## tablemate, friend, regular, first_time, me, plus nights_together (client card; not in 08b v1).
## Test hooks: arrive() (a late check-in), receive() (a verb for this phone), `offline`, `closed`, `codes`.

const Avatar = preload("res://scripts/avatar.gd")

const NAMES := ["Mai", "Ploy", "Ton", "Fah", "Beam", "Nok", "Arthit", "Kanya", "June", "Pim", "Golf", "Mew"]
const PresenceMock = preload("res://scripts/presence/presence_mock.gd")   ## every code's table and zone (arrive())
## In-game tables (layout.json ids) and their zones (08 §7.7)
const TABLES := {"Table0": "Tables", "Table1": "Tables", "Table2": "Tables", "Table3": "Tables", "Table4": "Tables",
	"WestTable0": "Tables", "WestTable1": "Tables", "LongTable": "Lounge", "BufferTall0": "Buffer",
	"BufferTall1": "Buffer", "LoungeTable0": "Lounge", "EastTable": "Tables"}
const CODE_RE := "^[A-Za-z0-9]{10}$"

var people: Array = []          ## tonight's check-ins (the server's rows): <presence> + "visibility" (everyone | here)
var events: Array = []          ## verbs received by this phone, newest last; "read" once marked
var sent: Array = []            ## verbs this phone sent: {to, kind, payload}
var hidden: Dictionary = {}     ## player_id -> true (Hide / Report)
var reports: Array = []
var checkins: Array = []        ## {code, mode, table_id}
var codes := {"TESTTABLE2": "Table2", "TESTTABLE1": "Table1"}   ## table codes (10 characters, 08b §5)
var offline := false
var closed := false
var viewer_here := false        ## the viewer checked in tonight (PresenceClient sets it from Needs before each call)
var _next := 0


func _init(seed_value := 2611) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var now := Time.get_unix_time_from_system()
	var t := TABLES.keys()
	for i in NAMES.size():
		people.append({
			"player_id": "fake-%02d" % i,
			"display_name": NAMES[i],
			"avatar": Avatar.random_record(rng),
			"table_id": t[i % t.size()],
			"zone": TABLES[t[i % t.size()]],
			"at": now - 60.0 * (90 - i * 7),
			"visibility": "here" if i in [9, 10] else "everyone",
			"regular": i % 3 == 0,
			"first_time": i % 3 == 2,
			"tablemate": i == 0,
			"friend": i == 1,
			"me": false,
			"nights_together": 3 if i == 0 else (1 if i == 1 else 0),
		})
	_next = NAMES.size()
	receive("Ploy", "wave")
	receive("Mai", "drink", {"drink_id": "guinness_draught", "band": 0})


## What the server's `tonight` gives this viewer: visible people minus hidden ones; the real table only for a viewer
## checked in tonight (P3), and mode-"here" people only for them.
func view() -> Array:
	var out: Array = []
	for p in people:
		if hidden.has(p["player_id"]):
			continue
		if p["visibility"] == "here" and not viewer_here:
			continue
		var q: Dictionary = p.duplicate(true)
		q.erase("visibility")
		if not viewer_here:
			q["table_id"] = ""
		out.append(q)
	return out


func tonight(cb: Callable) -> void:
	if offline:
		cb.call({"ok": false, "reason": "offline", "presences": []})
		return
	cb.call({"ok": true, "me_checked_in": viewer_here, "presences": view()})


func checkin(code: String, mode: String, cb: Callable) -> void:
	if mode == "":
		cb.call({"ok": false, "reason": "need_mode"})
		return
	if RegEx.create_from_string(CODE_RE).search(code) == null:
		cb.call({"ok": false, "reason": "bad_code"})
		return
	if offline:
		cb.call({"ok": false, "reason": "offline"})
		return
	if closed:
		cb.call({"ok": false, "reason": "closed"})
		return
	var table: String = codes.get(code, TABLES.keys()[absi(hash(code)) % TABLES.size()])
	var first := checkins.is_empty()
	checkins.append({"code": code, "mode": mode, "table_id": table})
	var mates: Array = []
	for p in people:
		if p["table_id"] == table and not hidden.has(p["player_id"]):
			mates.append(p.duplicate(true))
	cb.call({"ok": true, "table_id": table, "label": table.capitalize(), "first_of_night": first, "moved": false,
		"tablemates": mates})


func send_verb(to: String, kind: String, payload: Dictionary, cb: Callable) -> void:
	if offline:
		cb.call({"ok": false, "reason": "offline", "queued": true})
		return
	if hidden.has(to):
		cb.call({"ok": true, "pushed": false})   # 08b §3.3: a hidden receiver is never revealed
		return
	sent.append({"to": to, "kind": kind, "payload": payload.duplicate(true)})
	cb.call({"ok": true, "pushed": false})


func inbox(cb: Callable) -> void:
	if offline:
		cb.call({"ok": false, "reason": "offline", "events": []})
		return
	var out: Array = []
	for e in events:
		if not e.get("read", false):
			out.append(e.duplicate(true))
	cb.call({"ok": true, "events": out})


func mark_read(ids: Array) -> void:
	for e in events:
		if e["id"] in ids:
			e["read"] = true


func hide(player_id: String) -> void:
	hidden[player_id] = true


func report(player_id: String, reason: String) -> void:
	hidden[player_id] = true
	reports.append({"target": player_id, "reason": reason})


# --- Test hooks ----------------------------------------------------------------------------------

## A late check-in: shows at the next poll and walks in.
func arrive(name: String, table_id: String, rng_seed := 7) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var p := {"player_id": "fake-%02d" % _next, "display_name": name, "avatar": Avatar.random_record(rng),
		"table_id": table_id, "zone": TABLES.get(table_id, PresenceMock.TABLES.get(table_id, "Tables")), "at": Time.get_unix_time_from_system(),
		"visibility": "everyone", "regular": false, "first_time": true, "tablemate": false, "friend": false, "me": false,
		"nights_together": 0}
	_next += 1
	people.append(p)
	return p


## Another player sent this phone a verb (the start-screen inbox at the next open, N2).
func receive(from_name: String, kind: String, payload := {}) -> Dictionary:
	var e := {"id": events.size() + 1, "from": {"player_id": "fake-" + from_name.to_lower(), "display_name": from_name,
		"avatar": {}}, "kind": kind, "payload": payload.duplicate(true), "at": Time.get_unix_time_from_system(), "read": false}
	events.append(e)
	return e


## The real table of a person (tests: the view hides it from viewers not checked in).
func table_of(player_id: String) -> String:
	for p in people:
		if p["player_id"] == player_id:
			return p["table_id"]
	return ""
