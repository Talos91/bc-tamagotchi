extends RefCounted
## Tipsiness for one visit (03-cast §5.1), and the drink count the nightlife rules read (scripts/zones/nightlife.gd).
## Counted from alcoholic drinks only; non-alcoholic drinks refill Drinks exactly as much and add nothing.
## 0 Clear, 1-2 Warm, 3-4 Tipsy, 5+ Merry: the looks (player idle/walk set). The count keeps going past Merry since the
## playtest of 33dc5b9 (DECISIONS): drunk from 3, strongest at 10, WASTED past 10 (Rules.DRUNK_*, WASTED_AFTER).
## A glass of water takes Rules.WATER_SOBER_DRINKS off at once; otherwise one drink wears off every
## Rules.DRUNK_SOBER_MINUTES since the last change. Times are the game clock (Needs.clock), so the debug clock speeds
## it up. Resets each visit.

const Rules = preload("res://scripts/rules.gd")

const CLEAR := 0
const WARM := 1
const TIPSY := 2
const MERRY := 3
const DROP_SECONDS := Rules.DRUNK_SOBER_MINUTES * 60.0
const ANIM_SUFFIX := ["", "_warm", "_tipsy", "_merry"]

var drinks := 0
var _since := 0.0  # game-clock seconds of the last change


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
	drinks = maxi(0, drinks - Rules.WATER_SOBER_DRINKS)
	_since = now


## Applies the timed wear-off. Returns true if the count changed.
func update(now: float) -> bool:
	var before := drinks
	while drinks > 0 and now - _since >= DROP_SECONDS:
		drinks -= 1
		_since += DROP_SECONDS
	return drinks != before
