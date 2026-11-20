extends Node
## Gameplay telemetry (autoload PlayTelemetry; Daniele 2026-11-20: "implement telemetry for people playing seeing when
## they lose and such tonight then tmr we look at the results and adjust"). Three events, queued here and sent in
## batches through Presence.play_events() into the Supabase table public.play_events
## (supabase/migrations/20261120000001_play_events.sql; read with docs/tech/telemetry-queries.sql):
##   mg_start       game, difficulty
##   mg_end         game, score (0..100), duration_s, reason (lost / quit / timer / sign_end / arrived / complete /
##                  closed), misses, best (a new personal best), difficulty, reached {level, gates, lives_left, ...}
##   venue_session  length_s, games (minigames played), reason (left / closed = the tab closed mid-visit)
## Every event also carries the player's display name, the build ("v0.4.0 · 1a2b3c4") and a coarse device class
## ("ios dpr3 mem4"). Nothing else personal. Same terms as the perf beacon (Daniele 11-19: "auto", not anonymous).
## Fail-safe: nothing here awaits on the game's path; events wait in a queue (kept in user://play_telemetry.json, at
## most MAX_QUEUE) and are sent every FLUSH_S seconds and after each round; offline or a server error keeps them for
## the next try. Inert unless Presence is active (web build; tests opt in with Presence.use_mock()), like presence.
## Hook: minigame_frame.gd calls watch(game) once per round (one line) and marks the pause menu's Leave as "quit".

const VersionInfo = preload("res://scripts/version_info.gd")

const STORE := "user://play_telemetry.json"
const FLUSH_S := 15.0
const BATCH := 50
const MAX_QUEUE := 400
## Numbers copied from a round's result extra into mg_end.reached (whatever the game has).
const REACHED_KEYS := ["level", "speed", "gates", "sign", "notes", "notes_total", "bumps", "arrived", "spare", "letters",
	"word", "points", "perfect", "good", "missed", "best_combo", "best_run", "beat", "lean"]
const LIVES_KEYS := ["singes_left", "drops_left", "balls_left", "lives_left"]

var store_path := STORE
var queue: Array = []
var session := {}            ## the open venue visit: {start, games, seen}; persisted so a closed tab still reports
var sending := false
var _timer: Timer
var _device := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	if not session.is_empty():      # the last visit never ended (tab closed): report it now, up to its last sign of life
		_queue_session("closed", float(session.get("seen", session.get("start", 0.0))))
	_timer = Timer.new()
	_timer.wait_time = FLUSH_S
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	_timer.start()
	var needs := get_node_or_null("/root/Needs")
	if needs != null:
		needs.visit_started.connect(func(_i): visit_started())
		needs.visit_ended.connect(func(s: Dictionary): visit_ended(str(s.get("reason", "left"))))


func _presence() -> Node:
	return get_node_or_null("/root/Presence") if is_inside_tree() else null


## Recording happens only when the network layer is on (web build, or a test's mock).
func active() -> bool:
	var p := _presence()
	return p != null and p.is_active()


# ------------------------------------------------------------------ events

func record(kind: String, game: String, data: Dictionary) -> void:
	if not active():
		return
	queue.append({"kind": kind, "game": game, "client_at": snappedf(_now(), 0.001), "player_name": _player_name(),
		"build": VersionInfo.text().left(40), "device": device_class(), "data": data})
	if queue.size() > MAX_QUEUE:
		queue = queue.slice(queue.size() - MAX_QUEUE)
	_save()


## The frame's hook: one call when a round starts. Listens for the round's end (or its node going away unfinished).
func watch(game: Node, best_before := -1) -> void:
	if not active() or game == null:
		return
	var gid := str(game.get("game_id"))
	var diff: Variant = difficulty_of(game)
	var t0 := Time.get_ticks_msec()
	record("mg_start", gid, {"difficulty": diff})
	game.finished.connect(func(result: Dictionary): _round_ended(game, result, t0, best_before, diff), CONNECT_ONE_SHOT)
	game.tree_exiting.connect(func():
		if is_instance_valid(game) and not bool(game.get("done")):
			_round_ended(game, {"score": float(game.call("current_score")) if game.has_method("current_score") else 0.0,
				"extra": {}}, t0, best_before, diff, "closed"), CONNECT_ONE_SHOT)


func _round_ended(game: Node, result: Dictionary, t0: int, best_before: int, diff, forced := "") -> void:
	var extra: Dictionary = result.get("extra", {}) if result.get("extra") is Dictionary else {}
	var points := int(result.get("points", roundi(clampf(float(result.get("score", 0.0)), 0.0, 1.0) * 100.0)))
	var reason := forced if forced != "" else end_reason(game, extra)
	var data := {"score": points, "duration_s": snappedf((Time.get_ticks_msec() - t0) / 1000.0, 0.1), "reason": reason,
		"misses": misses_of(game, extra), "best": best_before >= 0 and points > best_before, "difficulty": diff,
		"tier": int(result.get("tier", 0)), "reached": reached_of(game, extra)}
	record("mg_end", str(game.get("game_id")), data)
	if not session.is_empty():
		session["games"] = int(session.get("games", 0)) + 1
		_save()
	flush()


## Why a round ended. A game (or the ramp job) can say it outright with `end_reason` (property or meta); the pause
## menu's Leave sets meta "quit". Otherwise read from the game's own state.
static func end_reason(game: Object, extra: Dictionary) -> String:
	if game.has_meta("end_reason"):
		return str(game.get_meta("end_reason"))
	var own = game.get("end_reason")
	if own is String and own != "":
		return own
	if bool(extra.get("sign", game.get("reached_sign") == true)):
		return "sign_end"
	if extra.has("arrived"):
		return "arrived" if bool(extra["arrived"]) else "timer"
	for k in LIVES_KEYS:
		var v = game.get(k)
		if (v is int or v is float) and v <= 0:
			return "lost"
	var el = game.get("elapsed")
	var lim = _const(game, "TIME_LIMIT")
	if (el is float or el is int) and (lim is float or lim is int) and el >= lim:
		return "timer"
	var pt = game.get("play_time")
	var cap = _const(game, "TIME_CAP")
	if (pt is float or pt is int) and (cap is float or cap is int) and pt >= cap:
		return "timer"
	return "complete"


static func _const(o: Object, name: String) -> Variant:
	var sc = o.get_script()
	return sc.get_script_constant_map().get(name) if sc is Script else null


static func difficulty_of(game: Object) -> Variant:
	var c = game.get("config")
	if c is Dictionary and c.has("difficulty"):
		return c["difficulty"]
	var d = game.get("difficulty")
	return d if (d is int or d is float or d is String) else 0


static func misses_of(game: Object, extra: Dictionary) -> int:
	var m = game.get("misses")
	if m is int or m is float:
		return int(m)
	for k in ["missed", "bumps"]:
		if extra.has(k):
			return int(extra[k])
	return 0


static func reached_of(game: Object, extra: Dictionary) -> Dictionary:
	var out := {}
	for k in REACHED_KEYS:
		var v = extra.get(k, game.get(k) if k in ["level", "speed"] else null)
		if v is int or v is float or v is bool:
			out[k] = snappedf(v, 0.01) if v is float else v
	for k in LIVES_KEYS:
		var v = game.get(k)
		if v is int:
			out["lives_left"] = v
	return out


# ------------------------------------------------------------------ venue visits

func visit_started() -> void:
	if not active():
		return
	if not session.is_empty():
		_queue_session("closed", float(session.get("seen", session.get("start", 0.0))))
	session = {"start": _now(), "games": 0, "seen": _now()}
	_save()


func visit_ended(reason := "left") -> void:
	if session.is_empty() or not active():
		return
	_queue_session(reason, _now())
	flush()


func _queue_session(reason: String, end_at: float) -> void:
	var s := session
	session = {}
	record("venue_session", "", {"length_s": int(maxf(0.0, end_at - float(s.get("start", end_at)))),
		"games": int(s.get("games", 0)), "reason": reason})
	_save()


# ------------------------------------------------------------------ sending

func _on_tick() -> void:
	if not session.is_empty():
		session["seen"] = _now()
		_save()
	flush()


## Sends the queue in batches. Never awaited by game code; one send at a time; offline keeps the rest for later.
func flush() -> void:
	if sending or queue.is_empty() or not active():
		return
	sending = true
	while not queue.is_empty() and is_inside_tree():
		var batch := queue.slice(0, BATCH)
		var r: Dictionary = await _presence().play_events(batch)
		var why := str(r.get("reason", ""))
		if not r.get("ok", false) and why in ["offline", "off", "auth", ""]:
			break                       # try again at the next tick
		queue = queue.slice(batch.size())   # sent, or refused for good (limit / bad data): never retried forever
		_save()
		if not r.get("ok", false):
			break
	sending = false


# ------------------------------------------------------------------ device, name, storage

func _player_name() -> String:
	var needs := get_node_or_null("/root/Needs")
	return str(needs.profile.get("display_name", "")).left(40) if needs != null else ""


## "ios dpr3 mem4" / "android dpr2.6 mem8" / "web dpr1" / "windows": the platform, pixel ratio and memory class.
func device_class() -> String:
	if _device != "":
		return _device
	if OS.has_feature("web"):
		var os := "ios" if OS.has_feature("web_ios") else ("android" if OS.has_feature("web_android") else "web")
		var js = JavaScriptBridge.eval("(window.devicePixelRatio||1).toFixed(1).replace('.0','')+' mem'+(navigator.deviceMemory||0)", true)
		_device = (os + " dpr" + str(js if js != null else "?")).left(60)
	else:
		_device = OS.get_name().to_lower()
	return _device


func _now() -> float:
	return Time.get_unix_time_from_system()


func _load() -> void:
	if not FileAccess.file_exists(store_path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(store_path))
	if d is Dictionary:
		queue = d.get("queue", []) if d.get("queue") is Array else []
		session = d.get("session", {}) if d.get("session") is Dictionary else {}


func _save() -> void:
	var f := FileAccess.open(store_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"queue": queue, "session": session}))


## Test hook: empty state at `path`.
func reset_local(path := "") -> void:
	if path != "":
		store_path = path
	queue = []
	session = {}
	sending = false
	_save()
