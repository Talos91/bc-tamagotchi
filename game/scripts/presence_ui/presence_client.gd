extends RefCounted
## Presence wave 1, client side (docs/design/08-presence.md; owner item 40, Daniele 2026-11-19): the one place the
## venue, the card, the inbox and the check-in flow ask for presence data. It picks the source:
##   - the `Presence` autoload of the 🌐 presence-backend worker (scripts/presence/, contract
##     docs/design/08b-presence-api.md) when it is in the tree and active (Presence.ON with a URL, or its mock mode);
##     its awaited calls are wrapped by RealSource below so every caller uses one callback style;
##   - "Fake presences" (fake_presence.gd, same answer shapes) when asked for: `-- --fake-presences` on the command
##     line, `?presence=fake` in the web address, or use_fake() from a test;
##   - otherwise nothing: active() is false and the game is exactly the single-player game (08 §8).
## It also keeps what this phone remembers about the night (needs.ext["presence"]): verbs sent per pair (§5.1 limits,
## so a used verb shows "Sent" before asking the server), players interacted with, and the Friends points of
## received verbs waiting for the next visit. Mode (P1): "everyone" | "here" | "nobody" ("" = never asked).

const Fake = preload("res://scripts/presence_ui/fake_presence.gd")

## 08b §2 (the autoload's constants; repeated so the client works without the backend branch)
const PRESENCE_CAP := 40
const PRESENCE_POLL_S := 120.0
const VERBS_PER_NIGHT := 40
const LIMITS := {"wave": 1, "cheers": 1, "drink": 1, "phrase": 3}   ## per pair per night (§5.1)
const MODES := ["everyone", "here", "nobody"]
const REPORT_REASONS := ["name", "harassment", "other"]

static var _source: Variant = null       ## the fake or a RealSource
static var _kind := ""                    ## "", "fake", "real"
static var _code := ""                    ## table code waiting to check in (fake / no autoload)
static var _code_read := false
static var cache: Array = []              ## tonight's list, last good fetch, sorted and capped
static var online := true                 ## false after a failed fetch (the "offline" dot, §8)


## Wraps the `Presence` autoload (08b): its calls are `await`ed and answered through the callback.
class RealSource extends RefCounted:
	var node: Node
	func _init(n: Node) -> void:
		node = n
	func tonight(cb: Callable) -> void:
		cb.call(await node.tonight())
	func checkin(code: String, mode: String, cb: Callable) -> void:
		if node.mode() != mode and mode in ["everyone", "here", "nobody"]:
			await node.set_mode(mode)
		cb.call(await node.checkin(code))
	func send_verb(to: String, kind: String, payload: Dictionary, cb: Callable) -> void:
		cb.call(await node.send_verb(to, kind, payload))
	func inbox(cb: Callable) -> void:
		cb.call(await node.inbox())
	func mark_read(ids: Array) -> void:
		node.mark_read(ids)
	func hide(id: String) -> void:
		node.hide(id)
	func report(id: String, reason: String) -> void:
		node.report(id, reason)


## True when presence is on in this run (the backend, or fake presences asked for).
static func active() -> bool:
	_pick()
	return _kind != ""


static func is_fake() -> bool:
	_pick()
	return _kind == "fake"


static func use_fake(seed_value := 2611) -> Variant:
	_source = Fake.new(seed_value)
	_kind = "fake"
	cache = []
	online = true
	return _source


## Presence off again (tests).
static func reset() -> void:
	_source = null
	_kind = ""
	_code = ""
	_code_read = true
	cache = []
	online = true


static func _autoload() -> Node:
	var ml := Engine.get_main_loop() as SceneTree
	return ml.root.get_node_or_null("Presence") if ml != null else null


static func _pick() -> void:
	if _kind != "":
		return
	var n := _autoload()
	if n != null and n.has_method("is_active") and n.is_active():
		_source = RealSource.new(n)
		_kind = "real"
		return
	if "--fake-presences" in OS.get_cmdline_user_args() or _web_param("presence") == "fake":
		use_fake()


# --- The table code (QR, 08b §5: ?t=<code>) ---------------------------------------------------------

## The code the game was opened with, once ("" = none). The autoload reads and cleans the address itself.
static func pending_code() -> String:
	_pick()
	if _kind == "real":
		return _source.node.pending_code()
	if not _code_read:
		_code_read = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--checkin="):
				_code = a.get_slice("=", 1)
		if _code == "" and OS.has_feature("web"):
			_code = _web_param("t")
			if _code != "":
				JavaScriptBridge.eval("(function(){var u=new URL(location.href);u.searchParams.delete('t');history.replaceState(null,'',u.pathname+(u.search||'')+u.hash);})()")
	return _code


static func set_pending_code(code: String) -> void:
	if _kind == "real":
		_source.node.set_pending_code(code)
		return
	_code = code
	_code_read = true


static func clear_code() -> void:
	if _kind == "real":
		_source.node.clear_pending_code()
	_code = ""


static func _web_param(key: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var v: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get(%s) || ''" % JSON.stringify(key), true)
	return str(v) if v != null else ""


# --- Mode (P1) -------------------------------------------------------------------------------------

static func mode(needs: Node) -> String:
	if _kind == "real":
		return _source.node.mode()
	return str(needs.profile.get("presence_mode", "")) if needs != null else ""


## Saved locally at once; the real source syncs it with the check-in (RealSource.checkin).
static func set_mode(needs: Node, m: String) -> void:
	if needs != null:
		needs.profile["presence_mode"] = m
		_mark_dirty(needs)


# --- Calls -------------------------------------------------------------------------------------------

## Is the viewer checked in tonight (the real table is shown only then, P3)?
static func viewer_here(needs: Node) -> bool:
	return needs != null and needs.checkin_nights.has(needs.night_key(needs.clock))


## Tonight's presences, the viewer's own row dropped, sorted by the §2.2 priority and cut at the cap.
## cb.call(list, ok). Presence off: ([], true). Offline: (cached list, false).
static func fetch_tonight(needs: Node, cb: Callable) -> void:
	if not active():
		cb.call([], true)
		return
	if _kind == "fake":
		_source.viewer_here = viewer_here(needs)
	_source.tonight(func(r: Dictionary):
		var ok: bool = r.get("ok", false)
		online = ok
		if ok:
			var list: Array = []
			for p in r.get("presences", []):
				if not p.get("me", false):
					list.append(p)
			cache = sort_by_priority(list, needs)
		cb.call(cache if ok else [], ok))


## Tablemates, then friends, then players this phone interacted with, then the most recent arrivals (§2.2).
static func sort_by_priority(list: Array, needs: Node) -> Array:
	var seen: Dictionary = _state(needs).get("interacted", {})
	var out := list.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka := _rank(a, seen)
		var kb := _rank(b, seen)
		if ka != kb:
			return ka < kb
		return float(a.get("at", 0.0)) > float(b.get("at", 0.0)))
	return out.slice(0, PRESENCE_CAP)


static func _rank(p: Dictionary, seen: Dictionary) -> int:
	if p.get("tablemate", false):
		return 0
	if p.get("friend", false):
		return 1
	if seen.has(p.get("player_id", "")):
		return 2
	return 3


## How many of a verb this phone may still send to `to` tonight (§5.1 per pair, plus VERBS_PER_NIGHT in total).
static func verbs_left(needs: Node, to: String, kind: String) -> int:
	var st := _night_state(needs)
	var total := 0
	for k in st["sent"]:
		total += int(st["sent"][k])
	var used := int(st["sent"].get(to + "|" + kind, 0))
	return maxi(0, mini(int(LIMITS.get(kind, 1)) - used, VERBS_PER_NIGHT - total))


## Send a verb. payload (08b §3.3): drink {drink_id, band}, phrase {phrase: "p01".."p24"}, else {}.
## cb.call({ok, reason}); the local count goes up on ok (and on a queued offline send, which the server delivers later).
static func send_verb(needs: Node, to: String, kind: String, payload: Dictionary, cb: Callable) -> void:
	if not active():
		cb.call({"ok": false, "reason": "off"})
		return
	if verbs_left(needs, to, kind) <= 0:
		cb.call({"ok": false, "reason": "limit"})
		return
	_source.send_verb(to, kind, payload, func(r: Dictionary):
		if r.get("ok", false) or r.get("queued", false):
			var st := _night_state(needs)
			st["sent"][to + "|" + kind] = int(st["sent"].get(to + "|" + kind, 0)) + 1
			_state(needs)["interacted"][to] = true
			_mark_dirty(needs)
		cb.call(r))


## Unread received verbs. cb.call(events).
static func fetch_inbox(cb: Callable) -> void:
	if not active():
		cb.call([])
		return
	_source.inbox(func(r: Dictionary): cb.call(r.get("events", []) if r.get("ok", false) else []))


## Items read: marked on the source; waves, cheers and phrases give Friends +2 each (the "social_verb" row, capped
## per visit), applied now if a visit runs, else when the next one starts.
static func read_inbox(needs: Node, items: Array) -> void:
	var ids: Array = []
	var gains := 0
	for it in items:
		ids.append(it["id"])
		if it.get("kind", "") in ["wave", "cheers", "phrase"]:
			gains += 1
	if active() and not ids.is_empty():
		_source.mark_read(ids)
	if needs == null or gains == 0:
		return
	var st := _state(needs)
	st["pending_social"] = int(st.get("pending_social", 0)) + gains
	_mark_dirty(needs)
	if needs.visit_active:
		apply_pending(needs)
	elif needs.has_signal("visit_started"):
		needs.visit_started.connect(func(_info: Dictionary): apply_pending(needs), CONNECT_ONE_SHOT)


## Friends points from read verbs, applied at the start of a visit.
static func apply_pending(needs: Node) -> int:
	var st := _state(needs)
	var n := int(st.get("pending_social", 0))
	for i in n:
		needs.apply_action("social_verb")
	st["pending_social"] = 0
	if n > 0:
		_mark_dirty(needs)
	return n


static func hide(player_id: String) -> void:
	if active():
		_source.hide(player_id)
	_drop_cached(player_id)


static func report(player_id: String, reason: String) -> void:
	if active():
		_source.report(player_id, reason if reason in REPORT_REASONS else "other")
	_drop_cached(player_id)


static func _drop_cached(player_id: String) -> void:
	for i in range(cache.size() - 1, -1, -1):
		if cache[i].get("player_id", "") == player_id:
			cache.remove_at(i)


## Check in with the table code (mode chosen first, P1). cb.call(answer) with 08b §3.1's fields. The backend runs
## Needs.check_in() itself on the first scan of the night; for the fake this does it.
static func check_in(needs: Node, code: String, cb: Callable) -> void:
	if not active():
		cb.call({"ok": false, "reason": "off"})
		return
	_source.checkin(code, mode(needs), func(r: Dictionary):
		if r.get("ok", false):
			if _kind == "fake" and r.get("first_of_night", false) and needs != null:
				r["needs"] = needs.check_in()
			clear_code()
		cb.call(r))


# --- Local state (needs.ext["presence"]) -----------------------------------------------------------

static func _state(needs: Node) -> Dictionary:
	if needs == null:
		return {"interacted": {}, "night": -1, "sent": {}}
	if not needs.ext.get("presence") is Dictionary:
		needs.ext["presence"] = {}
	var st: Dictionary = needs.ext["presence"]
	if not st.get("interacted") is Dictionary:
		st["interacted"] = {}
	return st


static func _night_state(needs: Node) -> Dictionary:
	var st := _state(needs)
	var night: int = needs.night_key(needs.clock) if needs != null else -1
	if int(st.get("night", -2)) != night or not st.get("sent") is Dictionary:
		st["night"] = night
		st["sent"] = {}
		st["interacted"] = {}
	return st


static func _mark_dirty(needs: Node) -> void:
	if needs != null and needs.get("_dirty") != null:
		needs._dirty = true
