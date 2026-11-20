extends Control
## Contract for every minigame scene (GDD section 9; docs/ui/wireframes.md section 7).
##
## Subclass in _init(): set game_id, action_id (a key of Rules.ACTIONS), need_id, title_key and, for
## daily_once actions, action_key. The frame calls start() once the scene is in the tree. Subclasses
## implement advance(dt) and call finish(score) with a score in 0..1; abandon() finishes with
## current_score() (the pause menu's Leave). A round below `miss_below` is a MISS (06-stakes §7.2): tier MISS, no gain.
## All time advances through advance(dt) so tests can drive a game without a real clock.
##
## Endless ramp (docs/design/15-minigame-ramp.md; Daniele 2026-11-20 "no need to end them at black cabin sign but make
## them become increasingly harder and faster (but humanly possible not impossible)"): every game runs until its loss
## rule (STRIKES strikes: the game's own singes_left / drops_left / balls_left / lives_left) and climbs `ramp_level` up to its cap. The record is uncapped: a game overrides
## record_points() (about 100 = a perfect old round) and finishes with score_of(points); the need gain reads only the
## first RECORD_FULL points, so a long run is a record, not a way to farm the meters. lose() ends a round on its loss
## rule with end_reason "lost" (play telemetry reads end_reason, extra.level, speed, misses).

signal finished(result: Dictionary)
signal status_changed(text: String)

const Rules = preload("res://scripts/rules.gd")
const Fx = preload("res://scripts/minigames/mg_fx.gd")
const S_LEVEL = preload("res://scripts/minigames/strings.gd")

## Haptics (11-minigame-quality §2.2, §2.4): light tick on success, double on failure, strong on perfect.
const HAPTIC_TICK_MS := 15
const HAPTIC_FAIL_MS := 25
const HAPTIC_FAIL_GAP := 0.09  # seconds between the two pulses of a failure
const HAPTIC_STRONG_MS := 45

const STRIKES := 3                  ## every endless game ends on its third strike
const RECORD_FULL := 100.0          ## record points that read as a full round for the need gain (score 1.0)

const TIER_MISS := -1
const TIER_GREAT := 0.6
const TIER_PERFECT := 0.85

var game_id := ""
var action_id := ""
var need_id := ""
var title_key := ""
var action_key := ""  # identifies the target of daily_once actions (the regular's id)
var config: Dictionary = {}  # set by the frame before start()
var relaxed := false  # accessibility "relaxed timing": +50% hit windows
var miss_below := Rules.MINIGAME_MISS_BELOW  # the frame raises it to RUSTY_MISS_BELOW for the first round while Rusty
var fumble := 0.0  # seconds the game stays frozen at the start (Rusty: RUSTY_FUMBLE_SECONDS)

var ramp_level := 1                ## the ramp's level (1 = the start); games send it as extra.level (play telemetry)
var end_reason := ""                ## "lost" on the loss rule; the frame's Leave sets meta "quit" (wins over this)

var running := false
var paused := false
var done := false
var last_status := ""
var hit_stop_left := 0.0  # seconds the real clock skips advance() (mg_fx hit-stop); advance(dt) itself ignores it
var _fx: Fx


func start() -> void:
	ramp_level = 1
	end_reason = ""
	running = true
	paused = false
	done = false
	_on_start()


func set_paused(on: bool) -> void:
	paused = on
	_on_pause(on)


func _process(delta: float) -> void:
	if fumble > 0.0:
		fumble -= delta
		return
	if hit_stop_left > 0.0:
		hit_stop_left -= delta
		return
	if running and not paused:
		advance(delta)


## Score so far, 0..1, used when the player leaves from the pause menu.
func current_score() -> float:
	return 0.0


func abandon() -> void:
	finish(current_score())


## The uncapped record of this round so far (best, board, rivals). Default: the 0..1 score as 0..100.
func record_points() -> int:
	return points_for(current_score())


## The need-gain score (0..1) of `points` record points: the first RECORD_FULL count.
static func score_of(points: float) -> float:
	return clampf(points / RECORD_FULL, 0.0, 1.0)


## The round ends on its loss rule (third strike).
func lose() -> void:
	if done:
		return
	end_reason = "lost"
	finish(current_score())


## Raises the ramp to level n (the game's own numbers follow `ramp_level`): a LEVEL pop and a strong tick.
func level_up(n: int) -> void:
	if n <= ramp_level:
		return
	ramp_level = n
	_on_level(n)
	fx().pop(S_LEVEL.t("mg.ramp.level", {"n": n}), Vector2(size.x * 0.5, size.y * 0.24), Color("FFDD78"), 52)
	haptic("strong")


## A game hook for its own level-up beat.
func _on_level(_n: int) -> void:
	pass


func finish(score: float) -> void:
	if done:
		return
	done = true
	running = false
	var s := clampf(score, 0.0, 1.0)
	finished.emit({
		"game_id": game_id, "action_id": action_id, "need_id": need_id, "key": action_key,
		"title_key": title_key, "score": s, "points": maxi(points_for(s), record_points()), "tier": tier_for(s, miss_below), "miss": s < miss_below,
		"extra": _result_extra(),
	})


## The shared juice overlay (mg_fx.gd), created on first use as the game's top child.
func fx() -> Fx:
	if _fx == null or not is_instance_valid(_fx):
		_fx = Fx.new()
		_fx.target = self
		add_child(_fx)
	return _fx


## Freezes the game for `seconds` on the real clock (a big hit). Tests driving advance(dt) are not affected.
func hit_stop(seconds: float) -> void:
	hit_stop_left = maxf(hit_stop_left, seconds)


## Vibration is possible on native phones and on Android browsers (Vibration API). The web export never sets
## "mobile" (Godot feature tags: web + web_android / web_ios), which is why the old `OS.has_feature("mobile")` guard
## never fired on the live build. iPhone browsers (WebKit) have no Vibration API: no haptics there from the web.
static func vibrate_supported_by(has_feature: Callable) -> bool:
	if has_feature.call("web_ios"):
		return false
	return has_feature.call("mobile") or has_feature.call("web_android")


static func vibrate_supported() -> bool:
	return vibrate_supported_by(Callable(OS, "has_feature"))


## One pulse of `ms` milliseconds where the platform can vibrate. Returns whether it fired.
static func vibrate(ms: int) -> bool:
	if not vibrate_supported():
		return false
	Input.vibrate_handheld(ms)
	return true


## kind: "tick" (success), "fail" (double pulse), "strong" (perfect). Returns whether it fired.
static func haptic(kind: String) -> bool:
	match kind:
		"fail":
			if not vibrate(HAPTIC_FAIL_MS):
				return false
			var tree := Engine.get_main_loop() as SceneTree
			if tree != null:
				tree.create_timer(HAPTIC_FAIL_GAP).timeout.connect(func(): vibrate(HAPTIC_FAIL_MS))
			return true
		"strong":
			return vibrate(HAPTIC_STRONG_MS)
		_:
			return vibrate(HAPTIC_TICK_MS)


func set_status(text: String) -> void:
	last_status = text
	status_changed.emit(text)


## -1 = miss (below `miss_below`, 06-stakes §7.2), 0 = good, 1 = great, 2 = perfect.
static func tier_for(score: float, below := Rules.MINIGAME_MISS_BELOW) -> int:
	if score < below:
		return TIER_MISS
	if score >= TIER_PERFECT:
		return 2
	if score >= TIER_GREAT:
		return 1
	return 0


static func points_for(score: float) -> int:
	return roundi(clampf(score, 0.0, 1.0) * 100.0)


func _result_extra() -> Dictionary:
	return {}


func advance(_dt: float) -> void:
	pass


func _on_start() -> void:
	pass


func _on_pause(_on: bool) -> void:
	pass
