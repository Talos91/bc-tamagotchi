extends Node
## Presence (autoload): the network layer for real check-ins in everyone's bar (docs/design/08-presence.md, the
## contract docs/design/08b-presence-api.md). Calls are async and always answer a Dictionary with `ok`; nothing
## blocks single-player play: with ON false (no project configured) every call answers {ok:false, reason:"off"}.
## Transport: presence_api.gd (Supabase) or presence_mock.gd (in memory; tests and the offline client).
## Local state (account tokens, presence mode, push flag, queued verbs) lives in user://presence.json, never in
## save.json; the account id is mirrored into Needs.profile.player_id (reserved there for this).

signal checked_in(answer: Dictionary)
signal tonight_changed(presences: Array, added: Array, removed: Array)
signal inbox_changed(count: int)
signal status_changed(status: String)

const Config = preload("res://scripts/presence/presence_config.gd")
const Api = preload("res://scripts/presence/presence_api.gd")
const Mock = preload("res://scripts/presence/presence_mock.gd")

const ON := Config.URL != ""          ## PRESENCE_ON
const POLL_S := 120.0
const TIMEOUT_S := 4.0
const LONG_TIMEOUT_S := 8.0
const CAP := 40
const TABLEMATE_WINDOW_MIN := 45
const VERBS := ["wave", "cheers", "drink", "phrase"]
const MODES := ["everyone", "here", "nobody"]
const REPORT_REASONS := ["name", "harassment", "other"]
const CODE_RE := "^[A-Za-z0-9]{10}$"
const STORE := "user://presence.json"

var PHRASES: Array = []               ## "p01".."p24"

var store_path := STORE
var apply_to_needs := true            ## false in tests that run two clients in one process
var identity := {}                    ## tests: {"name", "avatar"} sent instead of Needs' profile
var transport: RefCounted = null      ## Api or Mock
var mock: RefCounted = null           ## the Mock when mock mode is on
var status := "off"

var _state := {"user_id": "", "access_token": "", "refresh_token": "", "expires_at": 0.0, "mode": "",
	"push": false, "queue": []}
var _tonight: Dictionary = {}
var _tonight_at := -1.0e9
var _pending_code := ""
var _code_read := false
var _poll: Timer
var _inbox_count := 0
var _auth_busy := false


func _ready() -> void:
	for i in range(1, 25):
		PHRASES.append("p%02d" % i)
	_load()
	if ON and transport == null:
		transport = Api.new(self, Config.URL, Config.ANON_KEY)
	_poll = Timer.new()
	_poll.wait_time = POLL_S
	_poll.timeout.connect(_on_poll)
	add_child(_poll)
	if transport != null:
		_set_status("online")


## Mock mode: an in-memory server (shared when `shared` is given, e.g. two clients in one test).
func use_mock(on := true, shared: RefCounted = null) -> RefCounted:
	if on:
		mock = shared if shared != null else Mock.new()
		transport = mock
		_set_status("online")
	else:
		mock = null
		transport = Api.new(self, Config.URL, Config.ANON_KEY) if ON else null
		_set_status("online" if transport != null else "off")
	return mock


## The debug "Fake presences": n generated players checked in tonight (mock mode only).
func mock_fake_presences(n: int) -> Array:
	if mock == null:
		use_mock(true)
	return mock.add_fakes(n)


func is_active() -> bool:
	return transport != null


func player_id() -> String:
	return str(_state["user_id"])


# ------------------------------------------------------------------ settings

func mode() -> String:
	return str(_state["mode"])


func set_mode(m: String) -> Dictionary:
	if not m in MODES:
		return {"ok": false, "reason": "server", "detail": "bad mode"}
	_state["mode"] = m
	_save()
	if not is_active() or player_id() == "":
		return {"ok": true}
	var r := await _rpc("bc_set_profile", {"p_mode": m}, LONG_TIMEOUT_S)
	if m == "nobody":
		_tonight_at = -1.0e9
	return {"ok": true, "synced": r.get("ok", false)}


# ------------------------------------------------------------------ QR code in the page address

## The table code from `?t=<code>` (web; read once, then removed from the address). "" when none.
func pending_code() -> String:
	if not _code_read:
		_code_read = true
		if OS.has_feature("web"):
			var c = JavaScriptBridge.eval("""(function(){try{var u=new URL(location.href);var t=u.searchParams.get('t')||'';
				if(t){u.searchParams.delete('t');history.replaceState(null,'',u.pathname+(u.search||'')+u.hash);}return t;}
				catch(e){return '';}})()""", true)
			set_pending_code(str(c) if c != null else "")
	return _pending_code


func set_pending_code(code: String) -> void:
	_code_read = true
	_pending_code = code if RegEx.create_from_string(CODE_RE).search(code) != null else ""


func clear_pending_code() -> void:
	_pending_code = ""


# ------------------------------------------------------------------ calls

func checkin(code: String) -> Dictionary:
	if not is_active():
		return {"ok": false, "reason": "off"}
	if mode() == "":
		return {"ok": false, "reason": "need_mode"}
	if RegEx.create_from_string(CODE_RE).search(code) == null:
		return {"ok": false, "reason": "bad_code"}
	var name := ""
	var avatar := {}
	var needs := _needs()
	if needs != null:
		name = str(needs.profile.get("display_name", ""))
		avatar = needs.avatar()
	if not identity.is_empty():
		name = str(identity.get("name", name))
		avatar = identity.get("avatar", avatar)
	var r := await _rpc("bc_check_in", {"p_code": code, "p_display_name": name, "p_avatar": avatar,
		"p_mode": mode()}, TIMEOUT_S)
	if not r.get("ok", false):
		return r
	if code == _pending_code:
		_pending_code = ""
	if r.get("first_of_night", false) and needs != null:
		r["needs"] = needs.check_in()
	_tonight_at = -1.0e9
	checked_in.emit(r)
	return r


func tonight(force := false) -> Dictionary:
	if not is_active():
		return {"ok": false, "reason": "off", "presences": []}
	if not force and not _tonight.is_empty() and _now() - _tonight_at < POLL_S:
		return _tonight
	var r := await _rpc("bc_tonight", {}, TIMEOUT_S)
	if not r.get("ok", false):
		var cached: Array = _tonight.get("presences", [])
		return {"ok": false, "reason": r.get("reason", "server"), "presences": cached}
	var old := _ids(_tonight.get("presences", []))
	var new_ids := _ids(r.get("presences", []))
	_tonight = r
	_tonight_at = _now()
	var added := new_ids.filter(func(i): return not old.has(i))
	var removed := old.filter(func(i): return not new_ids.has(i))
	if not added.is_empty() or not removed.is_empty():
		tonight_changed.emit(r.get("presences", []), added, removed)
	await _flush_queue()
	return r


func send_verb(to: String, kind: String, payload := {}) -> Dictionary:
	if not is_active():
		return {"ok": false, "reason": "off"}
	if not kind in VERBS:
		return {"ok": false, "reason": "bad_kind"}
	if to == player_id():
		return {"ok": false, "reason": "self"}
	var r := await _edge("verb", {"to": to, "kind": kind, "payload": payload}, LONG_TIMEOUT_S)
	if r.get("reason", "") == "offline":
		var q: Array = _state["queue"]
		q.append({"to": to, "kind": kind, "payload": payload, "night": _local_night(), "at": _now()})
		_save()
		return {"ok": false, "reason": "offline", "queued": true}
	return r


func inbox() -> Dictionary:
	if not is_active():
		return {"ok": false, "reason": "off", "events": []}
	var r := await _rpc("bc_inbox", {}, LONG_TIMEOUT_S)
	if r.get("ok", false):
		var c: int = (r.get("events", []) as Array).size()
		if c != _inbox_count:
			_inbox_count = c
			inbox_changed.emit(c)
	return r


func mark_read(ids: Array) -> Dictionary:
	if not is_active():
		return {"ok": false, "reason": "off"}
	var int_ids := ids.map(func(i): return int(i))   # JSON numbers parse as floats; bigint wants 12, not 12.0
	return await _rpc("bc_mark_read", {"p_ids": int_ids}, LONG_TIMEOUT_S)


func hide(other: String) -> Dictionary:
	if not is_active():
		return {"ok": false, "reason": "off"}
	_tonight_at = -1.0e9
	return await _rpc("bc_hide", {"p_player": other}, LONG_TIMEOUT_S)


func report(other: String, reason: String) -> Dictionary:
	if not is_active():
		return {"ok": false, "reason": "off"}
	if not reason in REPORT_REASONS:
		return {"ok": false, "reason": "server", "detail": "bad reason"}
	_tonight_at = -1.0e9
	return await _rpc("bc_report", {"p_player": other, "p_reason": reason}, LONG_TIMEOUT_S)


func delete_me() -> Dictionary:
	if not is_active():
		return {"ok": false, "reason": "off"}
	if player_id() == "":
		return {"ok": true}
	if bool(_state["push"]):
		await push_disable()
	var r := await _rpc("bc_delete_me", {}, LONG_TIMEOUT_S)
	if r.get("ok", false):
		_state.merge({"user_id": "", "access_token": "", "refresh_token": "", "expires_at": 0.0, "queue": []}, true)
		_save()
		_tonight = {}
		var needs := _needs()
		if needs != null:
			needs.profile["player_id"] = ""
	return r


## Perf telemetry beacon (08b §3.7): one report per visit; the client hook comes later.
func perf_report(version: String, device: Dictionary, numbers: Dictionary) -> Dictionary:
	if not is_active():
		return {"ok": false, "reason": "off"}
	return await _rpc("bc_perf_report", {"p_version": version, "p_device": device, "p_numbers": numbers}, LONG_TIMEOUT_S)


# ------------------------------------------------------------------ polling (venue on screen)

func start_polling() -> void:
	if is_active() and _poll.is_stopped():
		_poll.start()
		_on_poll()


func stop_polling() -> void:
	if _poll != null:
		_poll.stop()


func _on_poll() -> void:
	await tonight(true)
	await inbox()


# ------------------------------------------------------------------ Web Push

## "yes", "needs_install" (iPhone/iPad not on the home screen) or "no".
func push_supported() -> String:
	if not OS.has_feature("web"):
		return "no"
	var s = JavaScriptBridge.eval("""(function(){var ios=/iPhone|iPad|iPod/.test(navigator.userAgent)||
		(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
		var standalone=window.navigator.standalone===true||window.matchMedia('(display-mode: standalone)').matches;
		if(!('serviceWorker' in navigator)||!('PushManager' in window)||!('Notification' in window))
		{return (ios&&!standalone)?'needs_install':'no';}
		if(ios&&!standalone){return 'needs_install';}return 'yes';})()""", true)
	return str(s) if s != null else "no"


func push_enabled() -> bool:
	return bool(_state["push"])


## Ask the browser for notification permission and subscribe this device. Call it from a tap (the browser needs a
## user gesture to show its permission prompt).
func push_enable() -> Dictionary:
	if not is_active():
		return {"ok": false, "reason": "off"}
	var sup := push_supported()
	if sup != "yes":
		return {"ok": false, "reason": "needs_install" if sup == "needs_install" else "unsupported"}
	var k := await _edge("verb", {"action": "public_key"}, LONG_TIMEOUT_S)
	if not k.get("ok", false):
		return k
	JavaScriptBridge.eval("""(function(key){window.bcPushResult=null;
		function b64u(s){s=s.replace(/-/g,'+').replace(/_/g,'/');while(s.length%4)s+='=';
			var r=atob(s),a=new Uint8Array(r.length);for(var i=0;i<r.length;i++)a[i]=r.charCodeAt(i);return a;}
		function enc(buf){var s='',b=new Uint8Array(buf);for(var i=0;i<b.length;i++)s+=String.fromCharCode(b[i]);
			return btoa(s).replace(/\\+/g,'-').replace(/\\//g,'_').replace(/=+$/,'');}
		Notification.requestPermission().then(function(p){
			if(p!=='granted'){window.bcPushResult={ok:false,reason:'denied'};return;}
			return navigator.serviceWorker.ready.then(function(reg){
				return reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:b64u(key)});
			}).then(function(sub){window.bcPushResult={ok:true,endpoint:sub.endpoint,
				p256dh:enc(sub.getKey('p256dh')),auth:enc(sub.getKey('auth'))};});
		}).catch(function(e){window.bcPushResult={ok:false,reason:'unsupported',detail:String(e)};});
	})(%s)""" % JSON.stringify(str(k["public_key"])), true)
	var waited := 0.0
	var res: Dictionary = {}
	while waited < 90.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
		var s = JavaScriptBridge.eval("window.bcPushResult?JSON.stringify(window.bcPushResult):''", true)
		if s != null and str(s) != "":
			res = JSON.parse_string(str(s))
			break
	if res.is_empty() or not res.get("ok", false):
		return res if not res.is_empty() else {"ok": false, "reason": "denied", "detail": "no answer"}
	var r := await _rpc("bc_save_push", {"p_endpoint": res["endpoint"], "p_p256dh": res["p256dh"],
		"p_auth": res["auth"]}, LONG_TIMEOUT_S)
	if r.get("ok", false):
		_state["push"] = true
		_save()
	return r


func push_disable() -> Dictionary:
	_state["push"] = false
	_save()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""navigator.serviceWorker&&navigator.serviceWorker.ready.then(function(r){
			return r.pushManager.getSubscription();}).then(function(s){if(s)s.unsubscribe();}).catch(function(){});""", true)
	if not is_active() or player_id() == "":
		return {"ok": true}
	return await _rpc("bc_delete_push", {"p_endpoint": null}, LONG_TIMEOUT_S)


## Test hook: mark push on for the mock (no browser).
func mock_push_subscribe() -> Dictionary:
	_state["push"] = true
	return await _rpc("bc_save_push", {"p_endpoint": "https://push.example/" + player_id(), "p_p256dh": "x",
		"p_auth": "y"}, LONG_TIMEOUT_S)


# ------------------------------------------------------------------ internals

func _ensure_auth() -> Dictionary:
	while _auth_busy:
		await get_tree().process_frame
	if str(_state["access_token"]) != "" and float(_state["expires_at"]) > _now() + 60.0:
		return {"ok": true}
	_auth_busy = true
	var r: Dictionary
	if str(_state["refresh_token"]) != "":
		r = await transport.refresh(str(_state["refresh_token"]))
		if not r.get("ok", false) and r.get("reason", "") != "offline":
			r = await transport.signup()
	else:
		r = await transport.signup()
	_auth_busy = false
	if not r.get("ok", false):
		return r
	_state.merge({"user_id": r["user_id"], "access_token": r["access_token"], "refresh_token": r["refresh_token"],
		"expires_at": r["expires_at"]}, true)
	_save()
	var needs := _needs()
	if needs != null and r["user_id"] != "":
		needs.profile["player_id"] = r["user_id"]
	return {"ok": true}


func _rpc(fn: String, args: Dictionary, timeout: float) -> Dictionary:
	return await _call(func(tok): return await transport.rpc(fn, args, tok, timeout))


func _edge(fn: String, body: Dictionary, timeout: float) -> Dictionary:
	return await _call(func(tok): return await transport.edge(fn, body, tok, timeout))


func _call(f: Callable) -> Dictionary:
	var a := await _ensure_auth()
	if not a.get("ok", false):
		_set_status("offline" if a.get("reason", "") == "offline" else status)
		return a
	var r: Dictionary = await f.call(str(_state["access_token"]))
	if r.get("reason", "") == "auth":       # expired or revoked token: one fresh sign-in, then retry once
		_state["expires_at"] = 0.0
		a = await _ensure_auth()
		if a.get("ok", false):
			r = await f.call(str(_state["access_token"]))
	_set_status("offline" if r.get("reason", "") == "offline" else "online")
	return r


func _flush_queue() -> void:
	var q: Array = _state["queue"]
	if q.is_empty():
		return
	var night := _local_night()
	_state["queue"] = []
	_save()
	for v in q:
		if int(v.get("night", -1)) != night:
			continue             # the night ended: dropped (08 §8)
		var r := await send_verb(str(v["to"]), str(v["kind"]), v.get("payload", {}))
		if r.get("reason", "") == "offline":
			break                # send_verb re-queued it


func _local_night() -> int:
	return Mock.night_of(_now())


func _now() -> float:
	if mock != null:
		return mock.now()
	return Time.get_unix_time_from_system()


func _ids(rows: Array) -> Array:
	var out := []
	for r in rows:
		if not r.get("me", false):
			out.append(str(r.get("player_id", "")))
	return out


func _set_status(s: String) -> void:
	if s != status:
		status = s
		status_changed.emit(s)


func _needs() -> Node:
	if not apply_to_needs or not is_inside_tree():
		return null
	return get_node_or_null("/root/Needs")


func _load() -> void:
	if not FileAccess.file_exists(store_path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(store_path))
	if d is Dictionary:
		for k in _state:
			if d.has(k):
				_state[k] = d[k]


func _save() -> void:
	var f := FileAccess.open(store_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_state))


## Test hook: start from an empty local state (no account, no mode) at `path`.
func reset_local(path := "") -> void:
	if path != "":
		store_path = path
	_state = {"user_id": "", "access_token": "", "refresh_token": "", "expires_at": 0.0, "mode": "", "push": false,
		"queue": []}
	_tonight = {}
	_tonight_at = -1.0e9
	_inbox_count = 0
	_save()
