extends RefCounted
## Tipsiness for one visit (03-cast §5.1). Counted from alcoholic drinks only; non-alcoholic drinks refill Drinks
## exactly as much and add nothing. 0 Clear, 1-2 Warm, 3-4 Tipsy, 5+ Merry. A glass of water drops one state at once;
## otherwise one state drops every DROP_SECONDS of real time since the last change. Resets each visit.
## No state ever lowers a reward: this only drives looks (player idle/walk set) and what Nam will pour.

const CLEAR := 0
const WARM := 1
const TIPSY := 2
const MERRY := 3
const DROP_SECONDS := 30.0 * 60.0  ## 03-cast §5.1 proposal: one state per 30 real minutes
const STATE_TOP := [0, 2, 4, 5]    ## drink count at the top of each state, used when a state drops
const ANIM_SUFFIX := ["", "_warm", "_tipsy", "_merry"]

var drinks := 0
var _since := 0.0  # real unix seconds of the last change


static func state_for(count: int) -> int:
	if count >= 5:
		return MERRY
	if count >= 3:
		return TIPSY
	if count >= 1:
		return WARM
	return CLEAR


func state() -> int:
	return state_for(drinks)


func reset(now: float) -> void:
	drinks = 0
	_since = now


func add_alcohol(now: float) -> void:
	update(now)
	drinks += 1
	_since = now


func water(now: float) -> void:
	update(now)
	_drop()
	_since = now


## Applies the timed drop. Returns true if the state changed.
func update(now: float) -> bool:
	var before := state()
	while drinks > 0 and now - _since >= DROP_SECONDS:
		_drop()
		_since += DROP_SECONDS
	return state() != before


func _drop() -> void:
	var s := state()
	if s > CLEAR:
		drinks = STATE_TOP[s - 1]
