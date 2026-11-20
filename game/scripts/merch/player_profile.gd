extends Node
## PlayerProfile (autoload): one consistent player across versions, phones and lost local saves, plus what merch they
## own (Daniele 2026-11-20; docs/design/14-merch-shop.md).
##
## Local first: the save (Needs) stays the truth on the phone and the game never waits for the network. This node
## mirrors it to the server through Presence (the same anonymous account, scripts/presence/presence.gd):
##   - the character (name, avatar record incl. worn merch, personality, created-at) -> profiles (bc_profile_save),
##     only when it changed, newest look wins on the server;
##   - owned merch -> inventory: a free pick is owned at once locally, then claimed on the server (bc_claim_item);
##     the server's list is merged back (union), so a second phone or a wiped save gets its pieces again;
##   - the player code (profiles.restore_code): shown in the shop; typing it on another phone / after the save was
##     lost brings the character and its pieces back (bc_profile_restore). When the anonymous account changes under
##     a save that still knows its code (lost session), the restore runs by itself.
##   - a save with no character on an account whose server profile has one (local save lost, session kept) gets the
##     character back from the server.
## Local state: Needs.ext["merch"] = {"owned": {id: {"at", "source", "synced"}}, "code", "account", "pushed"}.
## Off (no network: tests, desktop, ?presence=off) everything still works locally.

signal changed                      ## owned items, the code or the character changed (the shop redraws)

const Merch = preload("res://scripts/merch/merch.gd")
const CHECK_S := 15.0               ## how often a changed character is looked for (no request unless it changed)

var needs: Node
var presence: Node
var busy := false
var server_ok := true               ## false once the server answered that the functions are missing (migration not on)
var _timer: Timer


func _ready() -> void:
	needs = get_node_or_null("/root/Needs")
	presence = get_node_or_null("/root/Presence")
	_timer = Timer.new()
	_timer.wait_time = CHECK_S
	_timer.timeout.connect(func(): sync())
	add_child(_timer)
	_timer.start()
	_ask_persistent_storage()
	sync.call_deferred()


## Ask the browser to keep this site's storage (Safari and Chrome may otherwise evict it when space runs low or the
## site sits unused; an installed home-screen app is kept anyway). Harmless where unsupported.
func _ask_persistent_storage() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{navigator.storage&&navigator.storage.persist&&navigator.storage.persist()}catch(e){}", true)


# ------------------------------------------------------------------ local state

func state() -> Dictionary:
	if needs == null:
		return {"owned": {}, "code": "", "account": "", "pushed": ""}
	if not (needs.ext.get("merch") is Dictionary):
		needs.ext["merch"] = {}
	var s: Dictionary = needs.ext["merch"]
	for k in {"owned": {}, "code": "", "account": "", "pushed": ""}.keys():
		if not s.has(k):
			s[k] = {} if k == "owned" else ""
	return s


func owned() -> Array:
	var out := []
	for id in state()["owned"]:
		if Merch.has_item(id):
			out.append(id)
	return out


func owns(id: String) -> bool:
	return state()["owned"].has(id)


func code() -> String:
	return str(state()["code"])


## Pieces the player owns in one category, in shop order (what the wardrobe offers).
func owned_in(cat: String) -> Array:
	var out := []
	for it in Merch.items(cat):
		if owns(str(it["id"])):
			out.append(str(it["id"]))
	return out


func _own(id: String, at: float, source: String, synced: bool) -> void:
	var o: Dictionary = state()["owned"]
	if o.has(id):
		o[id]["synced"] = bool(o[id].get("synced", false)) or synced
		o[id]["at"] = minf(float(o[id].get("at", at)), at)
	else:
		o[id] = {"at": at, "source": source, "synced": synced}
	_mark()


func _mark() -> void:
	if needs != null:
		needs._dirty = true
		if needs.autosave:
			needs.save_game()


# ------------------------------------------------------------------ shop

## Pick a piece for free (the shop, 2026-11-20): owned locally at once, claimed on the server when online.
## {ok, new, synced} or {ok:false, reason: "unknown_item" | "not_free"}.
func claim(id: String) -> Dictionary:
	if not Merch.has_item(id):
		return {"ok": false, "reason": "unknown_item"}
	var was := owns(id)
	_own(id, Time.get_unix_time_from_system(), "free_pick", false)
	changed.emit()
	var r := await _rpc("bc_claim_item", {"p_item": id})
	if r.get("ok", false):
		_own(id, float(r.get("acquired_at", Time.get_unix_time_from_system())), "free_pick", true)
	elif r.get("reason", "") == "not_free":
		state()["owned"].erase(id)      # the server says the free pick is over: not owned
		_mark()
		changed.emit()
		return {"ok": false, "reason": "not_free"}
	return {"ok": true, "new": not was, "synced": r.get("ok", false)}


## Wear a piece (or "" to take `slot` off): writes the avatar record through Needs like the creator does.
func wear(id: String, slot := "") -> void:
	if needs == null or (id != "" and not owns(id)):
		return
	var rec: Dictionary = Merch.wear(needs.avatar(), id, slot)
	needs.set_avatar(rec, str(needs.profile.get("display_name", "")), needs.personality)
	changed.emit()


# ------------------------------------------------------------------ server

func online() -> bool:
	return presence != null and presence.is_active() and server_ok


func _rpc(fn: String, args: Dictionary) -> Dictionary:
	if not online():
		return {"ok": false, "reason": "off"}
	var r: Dictionary = await presence._rpc(fn, args, presence.LONG_TIMEOUT_S)
	if not r.get("ok", false) and r.get("reason", "") == "server" and str(r.get("detail", "")).contains("function"):
		server_ok = false               # the migration is not on this server yet: stay local, quietly
	return r


## What the server should hold for this character ("" avatar when there is no character yet).
func _payload() -> Dictionary:
	var has: bool = needs.has_avatar()
	var rec: Dictionary = needs.avatar() if has else {}
	return {"p_display_name": str(needs.profile.get("display_name", "")) if has else null,
		"p_avatar": rec if has else null, "p_personality": needs.personality if has else null,
		"p_created_at": float(rec.get("created_at", needs.created_at)) if has else null,
		"p_avatar_at": float(rec.get("edited_at", 0.0)) if has else null,
		"p_build": str(ProjectSettings.get_setting("application/config/version", ""))}


## Bring the local save and the server together. Cheap when nothing changed (no request).
func sync(force := false) -> Dictionary:
	if needs == null or not online() or busy:
		return {"ok": false, "reason": "off" if not online() else "busy"}
	busy = true
	var r := await _sync(force)
	busy = false
	return r


func _sync(force: bool) -> Dictionary:
	var s := state()
	# The anonymous account changed under a save that knows its code (lost session): take the character back.
	if presence.player_id() == "":
		await presence._ensure_auth()
	var account := str(presence.player_id())
	if account == "":
		return {"ok": false, "reason": "offline"}
	if str(s["account"]) != "" and str(s["account"]) != account and code() != "":
		var back := await _rpc("bc_profile_restore", {"p_code": code()})
		if back.get("ok", false):
			_apply_server(back, false)
			if presence.has_method("after_restore"):
				presence.after_restore()   # tonight's check-in and unread verbs came along (20261121000003)
	var p := _payload()
	var sig := JSON.stringify(p) + "|" + account
	var unsynced := []
	for id in s["owned"]:
		if not bool(s["owned"][id].get("synced", false)):
			unsynced.append(id)
	if not force and sig == str(s["pushed"]) and unsynced.is_empty() and str(s["account"]) == account:
		return {"ok": true, "unchanged": true}
	var r: Dictionary
	if needs.has_avatar():
		r = await _rpc("bc_profile_save", p)
	else:
		r = await _rpc("bc_profile_get", {})
	if not r.get("ok", false):
		return r
	# Only a save that never met the server takes the character from it (a lost save); after the player's own reset
	# the save still knows its account, so the deleted character stays deleted.
	var take: bool = not needs.has_avatar() and str(s["account"]) == ""
	s["account"] = account
	_apply_server(r, take)
	for id in unsynced:
		var c := await _rpc("bc_claim_item", {"p_item": id})
		if c.get("ok", false):
			_own(id, float(c.get("acquired_at", Time.get_unix_time_from_system())), "free_pick", true)
	s["pushed"] = JSON.stringify(_payload()) + "|" + account
	_mark()
	changed.emit()
	return {"ok": true}


## Merge a profile answer: code, owned pieces (union), and the character when the local save has none.
func _apply_server(r: Dictionary, take_character: bool) -> void:
	var s := state()
	if r.get("restore_code") != null and str(r["restore_code"]) != "":
		s["code"] = str(r["restore_code"])
	for row in r.get("inventory", []):
		if row is Dictionary and Merch.has_item(str(row.get("item_id", ""))):
			_own(str(row["item_id"]), float(row.get("acquired_at", 0.0)), str(row.get("source", "free_pick")), true)
	var av = r.get("avatar")
	if take_character and av is Dictionary and not (av as Dictionary).is_empty():
		needs.set_avatar(av, str(r.get("display_name", "")), str(r.get("personality", "")))
		if r.get("character_created_at") != null:
			needs.profile["avatar"]["created_at"] = float(r["character_created_at"])


## Type a player code (another phone, or after the save was lost): the character and its pieces come back here.
## {ok} or {ok:false, reason: "bad_code" | "rate_limited" | "offline" | "off" | ...}.
func restore(p_code: String) -> Dictionary:
	if not online():
		return {"ok": false, "reason": "off"}
	var r := await _rpc("bc_profile_restore", {"p_code": p_code})
	if not r.get("ok", false):
		return r
	state()["account"] = str(presence.player_id())
	state()["owned"] = {}
	_apply_server(r, true)
	state()["pushed"] = JSON.stringify(_payload()) + "|" + str(presence.player_id())
	_mark()
	changed.emit()
	if presence.has_method("after_restore"):
		presence.after_restore()
	return {"ok": true}
