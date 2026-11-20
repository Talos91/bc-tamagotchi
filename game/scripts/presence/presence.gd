extends Node
## Presence (autoload): the network layer for real check-ins in everyone's bar (docs/design/08-presence.md, the
## contract docs/design/08b-presence-api.md). Calls are async and always answer a Dictionary with `ok`; nothing
## blocks single-player play: with ON false (no project configured) every call answers {ok:false, reason:"off"}.
## On-switch (08b §1.1): the network is used only by the web build (players' phones), or when a run asks for it
## (`-- --live` / `-- --presence-live`, or go_live()). Headless tests, the editor and desktop playtests stay inert
## (no transport, no request) unless a test opts in with use_mock() or go_live(). `?presence=off` (or `=fake`) in the
## web address keeps the web build off too.
## Transport: presence_api.gd (Supabase) or presence_mock.gd (in memory; tests and the offline client).
## Local state (account tokens, presence mode, push flag, queued verbs) lives in user://presence.json, never in
## save.json; the account id is mirrored into Needs.profile.player_id (reserved there for this).

signal checked_in(answer: Dictionary)
signal account_restored               ## a player code brought an old account's check-in and verbs here (refetch)
signal tonight_changed(presences: Array, added: Array, removed: Array)
signal inbox_changed(count: int)
signal status_changed(status: String)
signal still_due_changed(due: bool)   ## "Still at Black Cabin?" is waiting for an answer (20261121000002)

const Config = preload("res://scripts/presence/presence_config.gd")
const Api = preload("res://scripts/presence/presence_api.gd")
const Mock = preload("res://scripts/presence/presence_mock.gd")

const ON := Config.URL != ""          ## PRESENCE_ON: a project is configured (the network may be used at all)
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
const SHARED_KEY := "bc_session"      ## web: the session mirrored in localStorage (written at once, shared by tabs)

var PHRASES: Array = []               ## "p01".."p24"

var store_path := STORE
var apply_to_needs := true            ## false in tests that run two clients in one process
var identity := {}                    ## tests: {"name", "avatar"} sent instead of Needs' profile
var transport: RefCounted = null      ## Api or Mock
var mock: RefCounted = null           ## the Mock when mock mode is on
var mock_delay_s := 0.0               ## tests: answer mock calls this much later, like the network (async path)
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
var still_due := false                ## bc_tonight still_due: the hourly "Still at Black Cabin?" wants an answer
var still_deadline := 0.0             ## unix time: no answer by then = checked out
var my_table := ""                    ## the viewer's table tonight (check-in answer, then bc_tonight my_table); "" = not in
var _closing := false                 ## out of the tree: pending calls answer "offline", nothing resumes on a freed node


func _ready() -> void:
	for i in range(1, 25):
		PHRASES.append("p%02d" % i)
	_load()
	if transport == null and live_wanted():
		go_live()
	_poll = Timer.new()
	_poll.wait_time = POLL_S
	_poll.timeout.connect(_on_poll)
	add_child(_poll)
	if transport != null:
		_set_status("online")


func _enter_tree() -> void:
	_closing = false


func _exit_tree() -> void:
	_closing = true
	if _poll != null:
		_poll.stop()


## Should this run use the real network by itself (08b §1.1)? Web build: yes unless `?presence=off|fake`.
## Anything else (headless tests, editor, desktop): only with `-- --live` or `-- --presence-live`.
static func live_wanted() -> bool:
	if not ON:
		return false
	var args := OS.get_cmdline_user_args()
	if "--presence-off" in args:
		return false
	if "--live" in args or "--presence-live" in args:
		return true
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("new URLSearchParams(location.search).get('presence') || ''", true)
		return not str(v if v != null else "") in ["off", "fake"]
	return false


## Switch the real network on (the web build does it in _ready; tests with --live call it). false when ON is false.
func go_live() -> bool:
	if not ON:
		return false
	mock = null
	transport = Api.new(self, Config.URL, Config.ANON_KEY)
	_set_status("online")
	return true


## Mock mode: an in-memory server (shared when `shared` is given, e.g. two clients in one test).
func use_mock(on := true, shared: RefCounted = null) -> RefCounted:
	if on:
		mock = shared if shared != null else Mock.new()
		transport = mock
		_set_status("online")
	else:
		mock = null
		transport = null
		if live_wanted():
			go_live()
		else:
			_set_status("off")
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
	my_table = str(r.get("table_id", ""))
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
	my_table = str(r.get("my_table", "")) if r.get("me_checked_in", false) else ""
	still_deadline = float(r["still_deadline"]) if r.get("still_deadline") != null else 0.0
	_set_still(bool(r.get("still_due", false)))
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


## Leave (Daniele 2026-11-20 "when you press leave should auto check out"): the server stops showing this player
## tonight at once; everyone else's next poll fades them out. A re-scan the same night checks in again. Only Leave
## and the end of the night end a check-in (Daniele 2026-11-21): a locked phone or a closed tab does not.
func check_out() -> Dictionary:
	if not is_active() or player_id() == "":
		return {"ok": true, "skipped": true}
	my_table = ""
	_set_still(false)
	_tonight_at = -1.0e9
	return await _rpc("bc_check_out", {}, LONG_TIMEOUT_S)


## "Yes, I'm here": the hour starts again. Too late: {ok:false, reason:"left"} (checked out; scan again).
func still_here() -> Dictionary:
	if not is_active() or player_id() == "":
		return {"ok": false, "reason": "off"}
	var r := await _rpc("bc_still_here", {}, LONG_TIMEOUT_S)
	if r.get("ok", false) or r.get("reason", "") == "left":
		_set_still(false)
		_tonight_at = -1.0e9
	if r.get("reason", "") == "left":
		my_table = ""
	return r


func _set_still(due: bool) -> void:
	if due != still_due:
		still_due = due
		still_due_changed.emit(due)


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


## Gameplay telemetry (play_telemetry.gd, Daniele 11-20): a batch of at most 50 events into public.play_events.
func play_events(events: Array) -> Dictionary:
	if not is_active():
		return {"ok": false, "reason": "off"}
	return await _rpc("bc_play_events", {"p_events": events}, LONG_TIMEOUT_S)


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
		if _closing or not is_inside_tree():
			return {"ok": false, "reason": "offline", "detail": "closed"}
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
		if _closing or not is_inside_tree():
			return {"ok": false, "reason": "offline", "detail": "closed"}
		await get_tree().process_frame
	_adopt_shared()   # another tab (or this page before a lost file write) may hold a newer session
	if str(_state["access_token"]) != "" and float(_state["expires_at"]) > _now() + 60.0:
		return {"ok": true}
	_auth_busy = true
	var r: Dictionary
	if str(_state["refresh_token"]) != "":
		r = await transport.refresh(str(_state["refresh_token"]))
		if not r.get("ok", false) and r.get("reason", "") != "offline" and _adopt_shared():
			r = await transport.refresh(str(_state["refresh_token"]))   # a rotated token from another tab
		if not r.get("ok", false) and r.get("reason", "") != "offline":
			# The account is lost (hotfix 4): a new one starts. The player code (merch shop) brings the old one's
			# character, tonight's check-in and unread verbs back (bc_profile_restore, 20261121000003).
			_state["lost_user_id"] = str(_state["user_id"])
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
	if transport == null or _closing:
		return {"ok": false, "reason": "off" if transport == null else "offline"}
	var a := await _ensure_auth()
	if not a.get("ok", false):
		_set_status("offline" if a.get("reason", "") == "offline" else status)
		return a
	if mock != null and mock_delay_s > 0.0:
		await get_tree().create_timer(mock_delay_s).timeout
		if _closing:
			return {"ok": false, "reason": "offline", "detail": "closed"}
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
	if FileAccess.file_exists(store_path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(store_path))
		if d is Dictionary:
			for k in _state:
				if d.has(k):
					_state[k] = d[k]
	if _adopt_shared():
		_save()


func _save() -> void:
	var f := FileAccess.open(store_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_state))
	_shared_write()


# The account session on the web (hotfix 4, Daniele 2026-11-21 "My friend send some i got none": his phone was on a
# new anonymous account while tonight's check-in and his friends' verbs sat on the old one). user://presence.json lives
# in IndexedDB, which Godot copies in at start and writes back asynchronously, once per tab; localStorage is written at
# once and every tab reads the same one. The session is kept in both and the newer one wins, so a write that did not
# reach IndexedDB before the page closed, or a second tab (each QR scan can open one) that rotated the refresh token,
# no longer ends in a new sign-up.
func _web_store() -> bool:
	return OS.has_feature("web") and mock == null and store_path == STORE


func _shared_read() -> Dictionary:
	if not _web_store():
		return {}
	var s = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('%s')||''}catch(e){return ''}})()" % SHARED_KEY, true)
	if s == null or str(s) == "":
		return {}
	var d = JSON.parse_string(str(s))
	return d if d is Dictionary else {}


func _shared_write() -> void:
	if not _web_store():
		return
	var v := JSON.stringify({"user_id": _state["user_id"], "access_token": _state["access_token"],
		"refresh_token": _state["refresh_token"], "expires_at": _state["expires_at"]})
	JavaScriptBridge.eval("(function(v){try{localStorage.setItem('%s',v)}catch(e){}})(%s)" % [SHARED_KEY, JSON.stringify(v)], true)


## Take the shared session when it is newer than this tab's (or this tab has none). true when something changed.
func _adopt_shared() -> bool:
	var d := _shared_read()
	var rt := str(d.get("refresh_token", ""))
	if rt == "" or rt == str(_state["refresh_token"]):
		return false
	if str(_state["refresh_token"]) != "" and float(d.get("expires_at", 0.0)) <= float(_state["expires_at"]):
		return false
	_state.merge({"user_id": str(d.get("user_id", "")), "access_token": str(d.get("access_token", "")),
		"refresh_token": rt, "expires_at": float(d.get("expires_at", 0.0))}, true)
	return true


## A player code moved an old account's profile, tonight's check-in and unread verbs to this one: fetch them again.
func after_restore() -> void:
	_tonight_at = -1.0e9
	_inbox_count = -1
	if is_active():
		await tonight(true)
	account_restored.emit()


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
