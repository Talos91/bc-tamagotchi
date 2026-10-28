extends Node
## Needs system (autoload "Needs"). GDD §2. Four meters that decay in real time from wall-clock
## timestamps, so the character keeps draining while the app is closed. All numbers live in rules.gd.
##
## Two clocks: the REAL clock (system time, what is saved as last_seen) and the GAME clock `clock`
## (unix seconds that advance by real elapsed x multiplier). With multiplier 1 they are the same.
## Visits, daily multipliers and Welcome Back all run on the game clock, so the debug multiplier
## exercises them too.

const Rules = preload("res://scripts/rules.gd")
const Save = preload("res://scripts/save.gd")

signal meter_changed(meter_id: String, value: float)
signal vibe_changed(vibe: float, state: String)
signal vibe_state_changed(old_state: String, new_state: String)
signal low_meter_crossed(meter_id: String)  # lowest meter fell below 40 (§2.6 notification hook)
signal action_applied(action_id: String, result: Dictionary)
signal visit_started(info: Dictionary)
signal visit_ended(summary: Dictionary)
signal welcome_back_started(reason: String)
signal tab_changed(total: float)
signal clock_multiplier_changed(multiplier: float)

var meters: Dictionary = {}  # meter id -> float 0..100
var personality := ""
var tab := 0.0  # overflow from full meters (§2.5)
var clock := 0.0  # game clock, unix seconds
var multiplier := 1.0
var vibe_state := ""

var save_path := Rules.SAVE_PATH
var autosave := true
## Tests set this to a fixed real time (unix seconds) to drive the real clock by hand; -1 = system time.
var time_override := -1.0

var profile: Dictionary = {"player_id": "", "display_name": ""}
var visit_log: Array = []
var ext: Dictionary = {}

# Out of Town (§2.1)
var out_of_town_until := 0.0
var last_out_of_town_start := 0.0

# Daily multiplier bookkeeping (§2.4)
var daily_day := -1
var visits_today := 0
var daily_keys: Dictionary = {}  # "action|key" -> true, cleared each day

# Welcome Back (§2.5)
var homebody_flag := false  # Vibe dropped below 25 since the last Welcome Back
var welcome_until := 0.0  # game clock; gains doubled while clock < this
var first_drink_free := true

# Current visit
var visit_active := false
var visit_start := 0.0
var visit_last_action := 0.0
var visit_points: Dictionary = {}  # meter -> cumulative points counted this visit (for tiers)
var visit_gains: Dictionary = {}  # meter -> points actually added to the meter this visit
var visit_action_totals: Dictionary = {}  # action id -> base points used (for caps)
var visit_once: Dictionary = {}  # action id -> true (once_per_visit)
var visit_actions := 0
var visit_welcome := false
var last_visit_end := 0.0

var _last_real := 0.0
var _last_lowest_id := ""
var _dirty := false
var _save_timer := 0.0
var _emit_cache: Dictionary = {}


func _ready() -> void:
	if not _load_from_disk():
		new_game()
	set_process(true)


func _process(delta: float) -> void:
	sync()
	_save_timer += delta
	if autosave and _dirty and _save_timer >= Rules.AUTOSAVE_SECONDS:
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if autosave and not meters.is_empty():
			sync()
			save_game()


# --- Time ----------------------------------------------------------------------------------------

func real_now() -> float:
	return time_override if time_override >= 0.0 else Time.get_unix_time_from_system()


## Advances the game clock by real elapsed time since the last call (x multiplier) and decays meters.
func sync() -> void:
	var now := real_now()
	var dt := maxf(0.0, now - _last_real)  # a device clock set backwards never refunds or drains
	_last_real = now
	if dt > 0.0:
		advance_game(dt * multiplier)


## Moves the game clock forward by `secs` and applies decay for that span.
func advance_game(secs: float) -> void:
	if secs <= 0.0:
		return
	var decaying := secs
	if out_of_town_until > clock:
		decaying = maxf(0.0, secs - (out_of_town_until - clock))
	clock += secs
	if decaying > 0.0:
		var hours := decaying / 3600.0
		for m in Rules.METERS:
			meters[m] = decay_value(meters[m], hours, Rules.decay_rate(m, personality), true)
	if visit_active and clock - visit_last_action >= Rules.VISIT_IDLE_SECONDS:
		end_visit("idle")
	_refresh()


## Pure decay of one meter over `hours` at `rate` per hour, with the §2.1 soft floor (halved below 30).
static func decay_value(value: float, hours: float, rate: float, soft_floor := true) -> float:
	var v := value
	var h := hours
	if soft_floor:
		var floor_at := Rules.SOFT_FLOOR_BELOW
		if v > floor_at:
			var to_floor := (v - floor_at) / rate
			if h <= to_floor:
				return v - rate * h
			h -= to_floor
			v = floor_at
		return maxf(Rules.METER_MIN, v - rate * Rules.SOFT_FLOOR_FACTOR * h)
	return maxf(Rules.METER_MIN, v - rate * h)


func set_clock_multiplier(m: float) -> void:
	sync()
	multiplier = maxf(0.0, m)
	clock_multiplier_changed.emit(multiplier)


func toggle_debug_clock() -> void:
	set_clock_multiplier(1.0 if multiplier != 1.0 else Rules.DEBUG_CLOCK_MULTIPLIER)


## Debug: jump the game clock (and decay) forward, e.g. a day.
func debug_advance(secs: float) -> void:
	sync()
	advance_game(secs)


# --- Vibe ----------------------------------------------------------------------------------------

func vibe() -> float:
	var total := 0.0
	for m in Rules.METERS:
		total += meters[m]
	return total / Rules.METERS.size()


func lowest_meter() -> String:
	var low: String = Rules.METERS[0]
	for m in Rules.METERS:
		if meters[m] < meters[low]:
			low = m
	return low


func _refresh() -> void:
	for m in Rules.METERS:
		var v: float = meters[m]
		if absf(v - _emit_cache.get(m, -1000.0)) >= 0.01:
			_emit_cache[m] = v
			meter_changed.emit(m, v)
	var vb := vibe()
	var st := Rules.vibe_state(vb)
	if st != vibe_state:
		var old := vibe_state
		vibe_state = st
		if st == Rules.VIBE_HOMEBODY:
			homebody_flag = true
		if old != "":
			vibe_state_changed.emit(old, st)
	vibe_changed.emit(vb, st)
	var low := lowest_meter()
	var low_v: float = meters[low]
	if _last_lowest_id != "" and low_v < Rules.NOTIFY_LOWEST_METER_CROSSES \
			and _emit_cache.get("_low_prev", 100.0) >= Rules.NOTIFY_LOWEST_METER_CROSSES:
		low_meter_crossed.emit(low)
	_emit_cache["_low_prev"] = low_v
	_last_lowest_id = low


# --- Visits --------------------------------------------------------------------------------------

func day_key(game_clock: float) -> int:
	return int(floor((game_clock + Rules.DAY_UTC_OFFSET_HOURS * 3600.0) / 86400.0))


func current_daily_mult() -> float:
	return Rules.daily_mult(maxi(visits_today, 1))


func welcome_active() -> bool:
	return clock < welcome_until


func begin_visit() -> void:
	if visit_active:
		return
	sync()
	var dk := day_key(clock)
	if dk != daily_day:
		daily_day = dk
		visits_today = 0
		daily_keys.clear()
	visits_today += 1
	visit_active = true
	visit_start = clock
	visit_last_action = clock
	visit_points.clear()
	visit_gains.clear()
	visit_action_totals.clear()
	visit_once.clear()
	visit_actions = 0
	for m in Rules.METERS:
		visit_points[m] = 0.0
		visit_gains[m] = 0.0
	# Welcome Back (§2.5): Vibe went below 25 since last time, or 7+ days away.
	var reason := ""
	if last_visit_end > 0.0 and clock - last_visit_end >= Rules.WELCOME_BACK_AWAY_DAYS * 86400.0:
		reason = "away"
	if homebody_flag:
		reason = "vibe"
	visit_welcome = false
	if reason != "":
		homebody_flag = false
		welcome_until = clock + Rules.WELCOME_BACK_MINUTES * 60.0
		first_drink_free = true
		visit_welcome = true
		welcome_back_started.emit(reason)
	visit_started.emit({"number": visits_today, "daily_mult": current_daily_mult(), "welcome": visit_welcome, "reason": reason})
	_dirty = true


func end_visit(reason := "left") -> void:
	if not visit_active:
		return
	visit_active = false
	last_visit_end = clock
	var summary := {
		"start": visit_start, "end": clock, "day": daily_day, "number": visits_today,
		"gains": visit_gains.duplicate(), "actions": visit_actions, "welcome": visit_welcome, "reason": reason,
	}
	visit_log.append({"start": visit_start, "end": clock, "day": daily_day, "number": visits_today,
		"gains": visit_gains.duplicate(), "actions": visit_actions, "welcome": visit_welcome})
	if visit_log.size() > Rules.VISIT_LOG_MAX:
		visit_log = visit_log.slice(visit_log.size() - Rules.VISIT_LOG_MAX)
	visit_ended.emit(summary)
	_dirty = true
	if autosave:
		save_game()


# --- Actions -------------------------------------------------------------------------------------

## Applies a refill action (§2.3) with diminishing returns (§2.4). `score` 0..1 scales ranged gains.
## `key` identifies the target of daily_once actions (e.g. the regular's id).
## Returns {"ok", "reason", "gains": {meter: points added}, "tab": overflow}.
func apply_action(action_id: String, score := 1.0, key := "") -> Dictionary:
	var def: Variant = Rules.ACTIONS.get(action_id)
	if def == null:
		return {"ok": false, "reason": "unknown_action", "gains": {}, "tab": 0.0}
	sync()
	if not visit_active:
		begin_visit()
	if def.get("once_per_visit", false) and visit_once.has(action_id):
		return {"ok": false, "reason": "once_per_visit", "gains": {}, "tab": 0.0}
	var dk := "%s|%s" % [action_id, key]
	if def.get("daily_once", false):
		if key == "":
			return {"ok": false, "reason": "key_required", "gains": {}, "tab": 0.0}
		if daily_keys.has(dk):
			return {"ok": false, "reason": "daily_once", "gains": {}, "tab": 0.0}
	var cap_left := INF
	if def.has("cap_per_visit"):
		cap_left = float(def["cap_per_visit"]) - float(visit_action_totals.get(action_id, 0.0))
		if cap_left <= 0.0:
			return {"ok": false, "reason": "cap_reached", "gains": {}, "tab": 0.0}
	var s := clampf(score, 0.0, 1.0)
	var mult := Rules.gain_mult(maxi(visits_today, 1), welcome_active())
	var gains := {}
	var overflow := 0.0
	var used := 0.0
	for m in def["gains"]:
		var g: Variant = def["gains"][m]
		var base: float = lerpf(g[0], g[1], s) if g is Array else float(g)
		base = minf(base, cap_left)
		used = maxf(used, base)
		var raw := base * mult
		var eff := _tiered(visit_points[m], raw)
		visit_points[m] += raw
		var room: float = Rules.METER_MAX - meters[m]
		var add := minf(eff, room)
		meters[m] += add
		visit_gains[m] += add
		gains[m] = add
		overflow += (eff - add) * Rules.OVERFLOW_TO_TAB_RATIO
	visit_action_totals[action_id] = visit_action_totals.get(action_id, 0.0) + used
	if def.get("once_per_visit", false):
		visit_once[action_id] = true
	if def.get("daily_once", false):
		daily_keys[dk] = true
	visit_actions += 1
	visit_last_action = clock
	if overflow > 0.0:
		tab += overflow
		tab_changed.emit(tab)
	_dirty = true
	_refresh()
	var result := {"ok": true, "reason": "", "gains": gains, "tab": overflow}
	action_applied.emit(action_id, result)
	if autosave:
		save_game()
	return result


## Diminishing returns (§2.4): of `raw` new points after `before` already counted this visit, how many land.
static func _tiered(before: float, raw: float) -> float:
	var edges := [Rules.DIMINISH_TIER_1_END, Rules.DIMINISH_TIER_2_END, INF]
	var factors := [Rules.DIMINISH_TIER_1_FACTOR, Rules.DIMINISH_TIER_2_FACTOR, Rules.DIMINISH_TIER_3_FACTOR]
	var pos := before
	var left := raw
	var out := 0.0
	for i in 3:
		if pos >= edges[i]:
			continue
		var take := minf(left, edges[i] - pos)
		out += take * factors[i]
		pos += take
		left -= take
		if left <= 0.0:
			break
	return out


# --- Out of Town (§2.1) --------------------------------------------------------------------------

func can_start_out_of_town() -> bool:
	return last_out_of_town_start <= 0.0 \
		or clock - last_out_of_town_start >= Rules.OUT_OF_TOWN_COOLDOWN_DAYS * 86400.0


func start_out_of_town(days: float) -> bool:
	sync()
	if not can_start_out_of_town():
		return false
	out_of_town_until = clock + minf(days, Rules.OUT_OF_TOWN_MAX_DAYS) * 86400.0
	last_out_of_town_start = clock
	_dirty = true
	return true


func end_out_of_town() -> void:
	sync()
	out_of_town_until = minf(out_of_town_until, clock)
	_dirty = true


# --- Personality / new game ----------------------------------------------------------------------

func set_personality(p: String) -> void:
	sync()
	personality = p
	_dirty = true


func new_game() -> void:
	meters.clear()
	for m in Rules.METERS:
		meters[m] = Rules.START_VALUE
	personality = ""
	tab = 0.0
	multiplier = 1.0
	_last_real = real_now()
	clock = _last_real
	out_of_town_until = 0.0
	last_out_of_town_start = 0.0
	daily_day = -1
	visits_today = 0
	daily_keys.clear()
	homebody_flag = false
	welcome_until = 0.0
	first_drink_free = true
	visit_active = false
	visit_log.clear()
	last_visit_end = 0.0
	ext = {}
	profile = {"player_id": "", "display_name": ""}
	_save_extra = {}
	_emit_cache.clear()
	vibe_state = ""
	_refresh()
	_dirty = true


# --- Persistence ---------------------------------------------------------------------------------

var _save_extra: Dictionary = {}  # unknown top-level keys from a newer build, written back untouched


func to_dict() -> Dictionary:
	var d := _save_extra.duplicate(true)
	d["version"] = Save.VERSION
	d["saved_at_unix"] = real_now()
	d["last_seen_unix"] = real_now()
	d["profile"] = profile.duplicate(true)
	d["visits"] = visit_log.duplicate(true)
	d["ext"] = ext.duplicate(true)
	var n: Dictionary = d.get("needs", {}).duplicate(true) if d.get("needs") is Dictionary else {}
	n["meters"] = meters.duplicate()
	n["clock_unix"] = clock
	n["personality"] = personality
	n["tab"] = tab
	n["out_of_town_until"] = out_of_town_until
	n["last_out_of_town_start"] = last_out_of_town_start
	n["daily"] = {"day": daily_day, "visits": visits_today, "keys": daily_keys.duplicate()}
	n["homebody_flag"] = homebody_flag
	n["welcome_until"] = welcome_until
	n["first_drink_free"] = first_drink_free
	n["last_visit_end"] = last_visit_end
	d["needs"] = n
	return d


## Restores state from a save dictionary. Time that passed since last_seen is decayed immediately.
func from_dict(d: Dictionary) -> void:
	d = Save.migrate(d)
	_save_extra = {}
	for k in d:
		if not (k in ["version", "saved_at_unix", "last_seen_unix", "profile", "visits", "ext"]):
			_save_extra[k] = d[k]
	profile = d.get("profile", {})
	visit_log = d.get("visits", [])
	ext = d.get("ext", {})
	var n: Dictionary = d.get("needs", {})
	meters.clear()
	var saved_meters: Dictionary = n.get("meters", {})
	for m in Rules.METERS:
		meters[m] = clampf(float(saved_meters.get(m, Rules.START_VALUE)), Rules.METER_MIN, Rules.METER_MAX)
	personality = str(n.get("personality", ""))
	tab = float(n.get("tab", 0.0))
	out_of_town_until = float(n.get("out_of_town_until", 0.0))
	last_out_of_town_start = float(n.get("last_out_of_town_start", 0.0))
	var daily: Dictionary = n.get("daily", {})
	daily_day = int(daily.get("day", -1))
	visits_today = int(daily.get("visits", 0))
	daily_keys = daily.get("keys", {})
	homebody_flag = bool(n.get("homebody_flag", false))
	welcome_until = float(n.get("welcome_until", 0.0))
	first_drink_free = bool(n.get("first_drink_free", true))
	last_visit_end = float(n.get("last_visit_end", 0.0))
	multiplier = 1.0  # the debug multiplier never survives a restart
	visit_active = false  # leaving the app ends the visit (§3)
	clock = float(n.get("clock_unix", real_now()))
	_last_real = float(d.get("last_seen_unix", real_now()))
	_emit_cache.clear()
	vibe_state = ""
	_refresh()
	sync()  # decays for the time the app was closed
	_dirty = false


func save_game() -> bool:
	_save_timer = 0.0
	_dirty = false
	return Save.write(to_dict(), save_path)


func _load_from_disk() -> bool:
	var d := Save.read(save_path)
	if d.is_empty():
		return false
	from_dict(d)
	return true


func delete_save() -> void:
	Save.delete(save_path)
