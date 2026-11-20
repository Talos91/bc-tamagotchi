extends RefCounted
## In-memory twin of the server side of supabase/migrations/20261120000002_player_profile_merch.sql for tests and
## the offline client: bc_profile_save, bc_profile_get, bc_claim_item, bc_profile_restore, with the same answers.
## install(mock) registers them on a presence mock (presence_mock.gd `extensions`).

const Merch = preload("res://scripts/merch/merch.gd")
const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var mock: RefCounted
var profiles := {}       ## uid -> {display_name, avatar, personality, character_created_at, avatar_at, build, restore_code}
var inventory := {}      ## uid -> {item_id: {acquired_at, source}}
var attempts := {}       ## uid -> [unix]
var shop_free := true
var catalogue := {}      ## item_id -> true (the seeded merch_items rows)


static func install(m: RefCounted) -> RefCounted:
	var s = load("res://scripts/merch/merch_server_mock.gd").new()
	s.mock = m
	for id in Merch.all_ids():
		s.catalogue[id] = true
	m.extensions["bc_profile_save"] = s._fn_save
	m.extensions["bc_profile_get"] = s._fn_get
	m.extensions["bc_claim_item"] = s._fn_claim
	m.extensions["bc_profile_restore"] = s._fn_restore
	return s


## Test hook: the migration is not on the server (the functions answer like a missing PostgREST function).
static func uninstall(m: RefCounted) -> void:
	for fn in ["bc_profile_save", "bc_profile_get", "bc_claim_item", "bc_profile_restore"]:
		m.extensions.erase(fn)


func _now() -> float:
	return mock.now()


func _ensure(uid: String) -> Dictionary:
	if not profiles.has(uid):
		profiles[uid] = {"display_name": "", "avatar": {}, "personality": "", "character_created_at": null,
			"avatar_at": null, "build": "", "restore_code": null}
	return profiles[uid]


func _json(uid: String) -> Dictionary:
	var p := _ensure(uid)
	var inv := []
	var mine: Dictionary = inventory.get(uid, {})
	for id in mine:
		inv.append({"item_id": id, "source": mine[id]["source"], "acquired_at": mine[id]["acquired_at"]})
	inv.sort_custom(func(a, b): return float(a["acquired_at"]) < float(b["acquired_at"]))
	return {"ok": true, "player_id": uid, "display_name": p["display_name"], "avatar": p["avatar"],
		"personality": p["personality"], "character_created_at": p["character_created_at"], "avatar_at": p["avatar_at"],
		"restore_code": p["restore_code"], "inventory": inv}


func _new_code() -> String:
	while true:
		var c := ""
		for i in 10:
			c += ALPHABET[randi() % ALPHABET.length()]
		var taken := false
		for u in profiles:
			if profiles[u]["restore_code"] == c:
				taken = true
		if not taken:
			return c
	return ""


func _fn_save(uid: String, a: Dictionary) -> Dictionary:
	var av = a.get("p_avatar")
	if av != null and not (av is Dictionary):
		return {"ok": false, "reason": "server", "detail": "bad avatar"}
	var p := _ensure(uid)
	var at = a.get("p_avatar_at")
	var newer: bool = p["avatar_at"] == null or at == null or float(at) >= float(p["avatar_at"])
	if newer:
		if a.get("p_display_name") != null:
			p["display_name"] = str(a["p_display_name"]).left(24)
		if av != null:
			p["avatar"] = (av as Dictionary).duplicate(true)
			p["avatar_at"] = float(at) if at != null else _now()
		if a.get("p_personality") != null:
			p["personality"] = str(a["p_personality"]).left(24)
	if p["character_created_at"] == null and a.get("p_created_at") != null and float(a["p_created_at"]) > 0.0:
		p["character_created_at"] = float(a["p_created_at"])
	if a.get("p_build") != null:
		p["build"] = str(a["p_build"]).left(40)
	if p["restore_code"] == null:
		p["restore_code"] = _new_code()
	return _json(uid)


func _fn_get(uid: String, _a: Dictionary) -> Dictionary:
	if not profiles.has(uid):
		return {"ok": true, "player_id": uid, "inventory": []}
	return _json(uid)


func _fn_claim(uid: String, a: Dictionary) -> Dictionary:
	var id := str(a.get("p_item", ""))
	if not catalogue.has(id):
		return {"ok": false, "reason": "unknown_item"}
	if not shop_free:
		return {"ok": false, "reason": "not_free"}
	_ensure(uid)
	if not inventory.has(uid):
		inventory[uid] = {}
	var is_new: bool = not inventory[uid].has(id)
	if is_new:
		inventory[uid][id] = {"acquired_at": _now(), "source": "free_pick"}
	return {"ok": true, "item_id": id, "new": is_new, "source": "free_pick", "acquired_at": inventory[uid][id]["acquired_at"]}


func _fn_restore(uid: String, a: Dictionary) -> Dictionary:
	var tries: Array = attempts.get(uid, []).filter(func(t): return t > _now() - 3600.0)
	if tries.size() >= 10:
		return {"ok": false, "reason": "rate_limited"}
	tries.append(_now())
	attempts[uid] = tries
	var code := RegEx.create_from_string("[^A-Za-z0-9]").sub(str(a.get("p_code", "")), "", true).to_upper()
	var src := ""
	for u in profiles:
		if profiles[u]["restore_code"] == code and code != "":
			src = u
	if src == "":
		return {"ok": false, "reason": "bad_code"}
	if src == uid:
		return _json(uid)
	var s: Dictionary = profiles[src]
	var p := _ensure(uid)
	s["restore_code"] = null
	for k in ["display_name", "avatar", "personality", "character_created_at", "avatar_at"]:
		p[k] = s[k].duplicate(true) if s[k] is Dictionary else s[k]
	p["restore_code"] = code
	if not inventory.has(uid):
		inventory[uid] = {}
	for id in inventory.get(src, {}):
		if not inventory[uid].has(id):
			inventory[uid][id] = inventory[src][id]
	inventory.erase(src)
	return _json(uid)
