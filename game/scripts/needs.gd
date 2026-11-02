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
signal stake_stage_changed(old_stage: String, new_stage: String)  # 06-stakes §10.1: fine / restless / fading / last_call / ghost / deleted
signal rescued(from_stage: String)  # a counting visit from restless on (Close Call polaroid from last_call)
signal revived  # a check-in brought a ghost back
signal character_deleted  # the ghost window ran out (day 35): show the farewell card, then complete_deletion()
signal annoyances_changed(active: Array)

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

# Stakes (docs/design/06-stakes.md v3 §10). `last_counted_visit` is the fatal clock; `stake_paused` is the Out of Town
# time since it. `stake_stage` is derived (see _refresh), never trusted from the save.
var last_counted_visit := 0.0
var stake_paused := 0.0  # seconds of Out of Town since last_counted_visit (the clock does not run through them)
var created_at := 0.0
var nights_out := 0
var stake_stage := "fine"
var dead_at := 0.0  # game clock the character died (0 = alive)
var last_revival_at := 0.0
var lives := 1
var zombie_next_visit := false
var visit_zombie := false  # this visit is the zombie arrival after a revival
var annoy_cleared: Dictionary = {}  # annoyance id -> true: seen to this visit
var minigame_tries: Dictionary = {}  # game id -> rounds played this visit (misses included)
var visit_minigame_rounds := 0
var last_calendar_at := 0.0
var going: Array = []
var last_retire_at := 0.0
var stake_notified: Array = []
var has_checked_in := false  # a real check-in happened at least once (DECISIONS 2026-11-02, O1)
var checkin_nights: Array = []  # bar nights (night_key) the character checked in on (O3)
## Tests flip these; the game leaves them at the Rules defaults.
var real_visit_required := Rules.REAL_VISIT_REQUIRED
var calendar_habit_enabled := Rules.CALENDAR_HABIT_ENABLED

var _last_real := 0.0
var _deleted_emitted := false
var _annoy_cache: Array = []
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


## Moves the game clock forward by `secs` and applies decay for that span. The fatal clock (06-stakes §10.1) runs here:
## Out of Town time is left out of it, a character dies at exactly FATAL_DAYS (decay stops there), but never in the
## middle of a visit, and a ghost's meters are frozen until a revival.
func advance_game(secs: float) -> void:
	if secs <= 0.0:
		return
	if dead_at > 0.0:
		clock += secs
		_idle_check()
		_refresh()
		return
	var oot := 0.0
	if out_of_town_until > clock:
		oot = minf(secs, out_of_town_until - clock)
	var live := secs
	var dies := false
	if not visit_active:
		var need := Rules.FATAL_DAYS * 86400.0 - stake_secs()
		if oot + maxf(need, 0.0) <= secs:
			live = oot + maxf(need, 0.0)
			dies = true
	stake_paused += minf(oot, live)
	clock += live
	var decaying := maxf(0.0, live - oot)
	if decaying > 0.0:
		var hours := decaying / 3600.0
		for m in Rules.METERS:
			meters[m] = decay_value(meters[m], hours, Rules.decay_rate(m, personality), true)
	if dies:
		dead_at = clock
		clock += secs - live
	_idle_check()
	_refresh()


func _idle_check() -> void:
	if visit_active and clock - visit_last_action >= Rules.VISIT_IDLE_SECONDS:
		end_visit("idle")


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


# --- Stakes: the fatal clock (06-stakes §3-§5, §10.1) -------------------------------------------

## Seconds on the fatal clock: since the last counting visit, Out of Town time left out.
func stake_secs() -> float:
	return maxf(0.0, clock - last_counted_visit - stake_paused)


func days_since_visit() -> float:
	return stake_secs() / 86400.0


func is_ghost() -> bool:
	return dead_at > 0.0 and clock < dead_at + Rules.GHOST_WINDOW_DAYS * 86400.0


func is_deleted() -> bool:
	return dead_at > 0.0 and clock >= dead_at + Rules.GHOST_WINDOW_DAYS * 86400.0


## The stage the clock says right now. A visit in progress holds a living character at last_call at most.
func compute_stake_stage() -> String:
	if dead_at > 0.0:
		return Rules.STAGE_DELETED if is_deleted() else Rules.STAGE_GHOST
	return Rules.stake_stage(minf(days_since_visit(), float(Rules.STAKE_STAGES[0][1])))


func _restless_days() -> float:
	for t in Rules.STAKE_STAGES:
		if t[0] == "restless":
			return float(t[1])
	return 10.0


## Whole days left before the next hard edge: to death for the living, to deletion for a ghost (rounded up).
func days_left() -> int:
	if dead_at > 0.0:
		return maxi(0, ceili((dead_at + Rules.GHOST_WINDOW_DAYS * 86400.0 - clock) / 86400.0))
	return maxi(0, ceili(Rules.FATAL_DAYS - days_since_visit()))


## Ghost reminder day reached (06-stakes §4: day 28 in the budget, day 33 outside it): the largest passed, or 0.
func ghost_reminder_reached() -> float:
	var out := 0.0
	if is_ghost():
		for d in Rules.GHOST_REMINDER_DAYS:
			if days_since_visit() >= d:
				out = d
	return out


## May an in-game action reset the fatal clock? The stand-in: yes, until a character that has checked in at the bar
## lives under REAL_VISIT_REQUIRED (O1: from the first check-in on, only check_in() and memory_shared() count).
func in_game_visits_count() -> bool:
	return not (real_visit_required and has_checked_in)


## The visit counts: the clock restarts at this moment. From restless on it is a rescue: Welcome Back, and from
## last_call a one-time Close Call polaroid flag (ext["close_call_polaroid"]).
func _count_visit() -> void:
	var from := compute_stake_stage()
	last_counted_visit = clock
	stake_paused = 0.0
	stake_notified.clear()
	if from in ["restless", "fading", "last_call"]:
		if not welcome_active():
			welcome_until = clock + Rules.WELCOME_BACK_MINUTES * 60.0
			first_drink_free = true
			visit_welcome = true
			welcome_back_started.emit("rescue")
		if from == "last_call":
			ext["close_call_polaroid"] = true
		rescued.emit(from)
	_dirty = true


## A real visit (a QR check-in at a table; the server will call this, the debug panel's "Fake check-in" runs the same
## code). Restarts the clock; for a ghost inside the window it is the revival (06-stakes §5.2), once per
## REVIVE_COOLDOWN_DAYS. Returns {ok, reason, revived}.
func check_in() -> Dictionary:
	sync()
	if is_deleted():
		return {"ok": false, "reason": "deleted", "revived": false}
	has_checked_in = true
	var night := night_key(clock)
	if not checkin_nights.has(night):
		checkin_nights.append(night)
		if checkin_nights.size() > Rules.CHECKIN_NIGHTS_KEPT:
			checkin_nights = checkin_nights.slice(checkin_nights.size() - Rules.CHECKIN_NIGHTS_KEPT)
	if is_ghost():
		if last_revival_at > 0.0 and clock - last_revival_at < Rules.REVIVE_COOLDOWN_DAYS * 86400.0:
			_dirty = true
			return {"ok": false, "reason": "revive_cooldown", "revived": false}
		_revive()
		return {"ok": true, "reason": "", "revived": true}
	_count_visit()
	_refresh()
	return {"ok": true, "reason": "", "revived": false}


func _revive() -> void:
	dead_at = 0.0
	last_counted_visit = clock
	stake_paused = 0.0
	last_revival_at = clock
	lives += 1
	zombie_next_visit = true
	stake_notified.clear()
	for m in Rules.METERS:
		meters[m] = maxf(meters[m], Rules.REVIVE_METER_FLOOR)
	_deleted_emitted = false
	_dirty = true
	_refresh()
	revived.emit()
	if autosave:
		save_game()


## The bar night (a count of Bangkok days, each starting at NIGHT_STARTS_HOUR) a game-clock moment belongs to: a
## check-in after midnight belongs to the night it started on (06-stakes §3).
func night_key(game_clock: float) -> int:
	return int(floor((game_clock + (Rules.DAY_UTC_OFFSET_HOURS - Rules.NIGHT_STARTS_HOUR) * 3600.0) / 86400.0))


## A photo shared at the lounge TV corner, taken on `taken_night` (a night_key; -1 = tonight). Under O3 it counts as a
## real visit only when that is a night the player checked in on, and only for a living character. True if it counted.
func memory_shared(taken_night := -1) -> bool:
	sync()
	if dead_at > 0.0:
		return false
	var night := night_key(clock) if taken_night < 0 else taken_night
	if not checkin_nights.has(night):
		return false
	_count_visit()
	_refresh()
	return true


## Retire (06-stakes §6, §10.5): delete the character at once, no ghost window. Refused within RETIRE_COOLDOWN_DAYS of
## the last Retire (the stamp is the account's, so it survives the deletion).
func retire() -> bool:
	sync()
	if last_retire_at > 0.0 and clock - last_retire_at < Rules.RETIRE_COOLDOWN_DAYS * 86400.0:
		return false
	var at := clock
	complete_deletion()
	last_retire_at = at
	return true


## The farewell card is done (or Retire): the character, meters, Tab, visits, hearts, bests, ext and name all go; the
## account (player_id, the UI settings, the Retire stamp) stays. A new game starts.
func complete_deletion() -> void:
	var keep_id := str(profile.get("player_id", ""))
	var ui: Variant = ext.get("ui")
	var retire_at := last_retire_at
	new_game()
	profile["player_id"] = keep_id
	if ui != null:
		ext["ui"] = ui
	last_retire_at = retire_at
	_dirty = true
	if autosave:
		save_game()


# --- Annoyances (§7.1, §10.3) --------------------------------------------------------------------

## Annoyances on right now: a meter annoyance while its meter is Empty and not yet seen to this visit; out_of_loop when
## the calendar habit is enabled and the calendar was not opened for CALENDAR_HABIT_DAYS.
func annoyances() -> Array:
	var out: Array = []
	for id in Rules.ANNOYANCES:
		if is_annoyed(id):
			out.append(id)
	return out


func is_annoyed(id: String) -> bool:
	if dead_at > 0.0 or meters.is_empty():
		return false
	var m: String = Rules.ANNOYANCES.get(id, "")
	if m != "":
		return not annoy_cleared.has(id) and meters[m] < Rules.ANNOY_EMPTY_BELOW
	if id == "out_of_loop":
		return calendar_habit_enabled and not annoy_cleared.has(id) \
			and clock - last_calendar_at > Rules.CALENDAR_HABIT_DAYS * 86400.0
	return false


## Opening the events calendar (BACKLOG D1) clears out_of_loop.
func open_calendar() -> void:
	sync()
	last_calendar_at = clock
	annoy_cleared["out_of_loop"] = true
	_dirty = true
	_refresh()


## Turning the calendar habit on sets last_calendar_at = now so nobody starts annoyed (§10.3).
func set_calendar_habit_enabled(on: bool) -> void:
	calendar_habit_enabled = on
	if on:
		last_calendar_at = clock
	_refresh()


## Gain multiplier of the drag on `meter` given the annoyances `active`: every one but the meter's own.
func annoy_drag(meter: String, active: Array) -> float:
	var n := 0
	for id in active:
		if Rules.ANNOYANCES[id] != meter:
			n += 1
	return pow(Rules.ANNOY_DRAG_MULT, n)


## Venue walk speed multiplier (Thirsty, §7.1).
func walk_mult() -> float:
	return Rules.THIRSTY_WALK_MULT if is_annoyed("thirsty") else 1.0


## Club music offset in dB (Earworm, §7.1). There is no music bus yet; the audio pass reads this.
func music_duck_db() -> float:
	return Rules.EARWORM_DUCK_DB if is_annoyed("earworm") else 0.0


# --- Minigames: misses and tries (§7.2, §10.4) ---------------------------------------------------

## The score below which the next round is a miss: higher for the first round of the visit while Rusty.
func minigame_miss_below() -> float:
	return Rules.RUSTY_MISS_BELOW if is_annoyed("rusty") and visit_minigame_rounds == 0 else Rules.MINIGAME_MISS_BELOW


func minigame_tries_left(game_id: String) -> int:
	return maxi(0, Rules.MINIGAME_TRIES_PER_VISIT - int(minigame_tries.get(game_id, 0)))


## A round finished: it uses a try (misses included) and sees to Rusty. False, nothing recorded, when no tries were left.
func note_minigame_round(game_id: String) -> bool:
	if not visit_active:
		begin_visit()  # the tries belong to the visit; begin_visit clears them
	if minigame_tries_left(game_id) <= 0:
		return false
	minigame_tries[game_id] = int(minigame_tries.get(game_id, 0)) + 1
	visit_minigame_rounds += 1
	annoy_cleared["rusty"] = true
	_dirty = true
	_refresh()
	return true


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
	var stage := compute_stake_stage()
	if stage != stake_stage:
		var old_stage := stake_stage
		stake_stage = stage
		stake_stage_changed.emit(old_stage, stage)
	if stage == Rules.STAGE_DELETED and not _deleted_emitted:
		_deleted_emitted = true
		character_deleted.emit()
	var act := annoyances()
	if act != _annoy_cache:
		_annoy_cache = act
		annoyances_changed.emit(act)


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
	annoy_cleared.clear()
	minigame_tries.clear()
	visit_minigame_rounds = 0
	for m in Rules.METERS:
		visit_points[m] = 0.0
		visit_gains[m] = 0.0
	# Welcome Back (§2.5): Vibe went below 25 since last time, or 7+ days away; or the zombie arrival after a revival.
	var reason := ""
	if last_visit_end > 0.0 and clock - last_visit_end >= Rules.WELCOME_BACK_AWAY_DAYS * 86400.0:
		reason = "away"
	if homebody_flag:
		reason = "vibe"
	visit_zombie = zombie_next_visit
	if zombie_next_visit:
		zombie_next_visit = false
		reason = "revival"
	visit_welcome = false
	if reason != "":
		homebody_flag = false
		welcome_until = clock + Rules.WELCOME_BACK_MINUTES * 60.0
		first_drink_free = true
		visit_welcome = true
		welcome_back_started.emit(reason)
	visit_started.emit({"number": visits_today, "daily_mult": current_daily_mult(), "welcome": visit_welcome, "reason": reason,
		"zombie": visit_zombie})
	_refresh()
	_dirty = true


func end_visit(reason := "left") -> void:
	if not visit_active:
		return
	visit_active = false
	last_visit_end = clock
	annoy_cleared.clear()
	nights_out += 1
	if dead_at <= 0.0 and days_since_visit() >= Rules.FATAL_DAYS:
		dead_at = clock  # a visit held the death off; it ends without a counting action
	var summary := {
		"start": visit_start, "end": clock, "day": daily_day, "number": visits_today,
		"gains": visit_gains.duplicate(), "actions": visit_actions, "welcome": visit_welcome, "reason": reason,
	}
	visit_log.append({"start": visit_start, "end": clock, "day": daily_day, "number": visits_today,
		"gains": visit_gains.duplicate(), "actions": visit_actions, "welcome": visit_welcome})
	if visit_log.size() > Rules.VISIT_LOG_MAX:
		visit_log = visit_log.slice(visit_log.size() - Rules.VISIT_LOG_MAX)
	visit_ended.emit(summary)
	_refresh()
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
	if dead_at > 0.0:
		return {"ok": false, "reason": "ghost" if is_ghost() else "deleted", "gains": {}, "tab": 0.0}
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
	if in_game_visits_count():
		_count_visit()  # the stand-in for a real visit (§3): any accepted refill restarts the fatal clock
	var annoyed := annoyances()  # the drag of what is on now; this action's own cure comes after
	var mult := Rules.gain_mult(maxi(visits_today, 1), welcome_active())
	var gains := {}
	var overflow := 0.0
	var used := 0.0
	for m in def["gains"]:
		var g: Variant = def["gains"][m]
		var base: float = lerpf(g[0], g[1], s) if g is Array else float(g)
		base = minf(base, cap_left)
		used = maxf(used, base)
		var raw := base * mult * annoy_drag(m, annoyed)
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
	for id in Rules.ANNOYANCES:  # a refill of the annoyance's own meter is the cure; it stays off for the visit
		if Rules.ANNOYANCES[id] != "" and def["gains"].has(Rules.ANNOYANCES[id]):
			annoy_cleared[id] = true
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


## Sets a meter outright (nightlife: Check the plumbing, WASTED). `fresh` also forgets the points this visit already
## counted for it, so the next gains land in full again (§2.4 tiers).
func force_meter(meter: String, value: float, fresh := false) -> void:
	sync()
	meters[meter] = clampf(value, Rules.METER_MIN, Rules.METER_MAX)
	if fresh and visit_points.has(meter):
		visit_points[meter] = 0.0
	_dirty = true
	_refresh()


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
	if dead_at > 0.0 or days_since_visit() >= _restless_days():  # planned time away, not an escape hatch (S10)
		return false
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
	last_counted_visit = clock
	stake_paused = 0.0
	created_at = clock
	nights_out = 0
	stake_stage = "fine"
	dead_at = 0.0
	last_revival_at = 0.0
	lives = 1
	zombie_next_visit = false
	visit_zombie = false
	annoy_cleared.clear()
	minigame_tries.clear()
	visit_minigame_rounds = 0
	last_calendar_at = clock
	going = []
	last_retire_at = 0.0
	stake_notified.clear()
	has_checked_in = false
	checkin_nights.clear()
	_deleted_emitted = false
	_annoy_cache = []
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
	n["last_counted_visit"] = last_counted_visit
	n["stake_paused"] = stake_paused
	n["created_at"] = created_at
	n["nights_out"] = nights_out
	n["stake_stage"] = stake_stage
	n["dead_at"] = dead_at
	n["last_revival_at"] = last_revival_at
	n["lives"] = lives
	n["zombie_next_visit"] = zombie_next_visit
	n["annoy_cleared"] = annoy_cleared.duplicate()
	n["minigame_tries"] = minigame_tries.duplicate()
	n["last_calendar_at"] = last_calendar_at
	n["going"] = going.duplicate()
	n["last_retire_at"] = last_retire_at
	n["stake_notified"] = stake_notified.duplicate()
	n["has_checked_in"] = has_checked_in
	n["checkin_nights"] = checkin_nights.duplicate()
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
	# Stakes (06-stakes §10.7): keys are additive; an old save starts at Fine with its clock at the last visit end (or now)
	last_counted_visit = float(n.get("last_counted_visit", last_visit_end if last_visit_end > 0.0 else clock))
	stake_paused = float(n.get("stake_paused", 0.0))
	var first_visit := real_now()
	for v in visit_log:
		first_visit = minf(first_visit, float(v.get("start", first_visit)))
	created_at = float(n.get("created_at", first_visit))
	nights_out = int(n.get("nights_out", visit_log.size()))
	dead_at = float(n.get("dead_at", 0.0))
	last_revival_at = float(n.get("last_revival_at", 0.0))
	lives = maxi(1, int(n.get("lives", 1)))
	zombie_next_visit = bool(n.get("zombie_next_visit", false))
	visit_zombie = false
	annoy_cleared = {}  # a closed app ended the visit
	minigame_tries = {}
	visit_minigame_rounds = 0
	last_calendar_at = float(n.get("last_calendar_at", clock))
	going = n.get("going", []).duplicate()
	last_retire_at = float(n.get("last_retire_at", 0.0))
	stake_notified = n.get("stake_notified", []).duplicate()
	has_checked_in = bool(n.get("has_checked_in", false))
	checkin_nights = n.get("checkin_nights", []).duplicate()
	stake_stage = str(n.get("stake_stage", "fine"))  # kept only to notice a change on load; _refresh derives the truth
	_deleted_emitted = false
	_annoy_cache = []
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
