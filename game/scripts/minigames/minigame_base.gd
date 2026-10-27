extends Control
## Contract for every minigame scene (GDD section 9; docs/ui/wireframes.md section 7).
##
## Subclass in _init(): set game_id, action_id (a key of Rules.ACTIONS), need_id, title_key and, for
## daily_once actions, action_key. The frame calls start() once the scene is in the tree. Subclasses
## implement advance(dt) and call finish(score) with a score in 0..1; abandon() finishes with
## current_score() (the pause menu's Leave). No fail state: any finish is a valid result and earns the
## minimum. All time advances through advance(dt) so tests can drive a game without a real clock.

signal finished(result: Dictionary)
signal status_changed(text: String)

const TIER_GREAT := 0.6
const TIER_PERFECT := 0.85

var game_id := ""
var action_id := ""
var need_id := ""
var title_key := ""
var action_key := ""  # identifies the target of daily_once actions (the regular's id)
var config: Dictionary = {}  # set by the frame before start()
var relaxed := false  # accessibility "relaxed timing": +50% hit windows

var running := false
var paused := false
var done := false
var last_status := ""


func start() -> void:
	running = true
	paused = false
	done = false
	_on_start()


func set_paused(on: bool) -> void:
	paused = on
	_on_pause(on)


func _process(delta: float) -> void:
	if running and not paused:
		advance(delta)


## Score so far, 0..1, used when the player leaves from the pause menu.
func current_score() -> float:
	return 0.0


func abandon() -> void:
	finish(current_score())


func finish(score: float) -> void:
	if done:
		return
	done = true
	running = false
	var s := clampf(score, 0.0, 1.0)
	finished.emit({
		"game_id": game_id, "action_id": action_id, "need_id": need_id, "key": action_key,
		"title_key": title_key, "score": s, "points": points_for(s), "tier": tier_for(s),
		"extra": _result_extra(),
	})


func set_status(text: String) -> void:
	last_status = text
	status_changed.emit(text)


## 0 = good, 1 = great, 2 = perfect. Never a fail tier (GDD section 9).
static func tier_for(score: float) -> int:
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
