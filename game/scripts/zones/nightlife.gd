extends RefCounted
## Nightlife rules (DECISIONS "Playtest of 33dc5b9", BACKLOG B12): the drunk level, WASTED and its lockout, and
## Check the plumbing. UI-free and static; VenueSession calls it, the drunk overlay (scripts/ui/drunk_overlay.gd)
## and the WASTED screen (scenes/ui/wasted_screen.gd) read it. Numbers in rules.gd.
##
## Saved in Needs.ext[KEY] = {"lockout_until": game-clock seconds, "wasted": times, "line": last line shown}.
## The lockout runs on the game clock (Needs.clock), which keeps moving while the app is closed (it is restored
## and synced on load), so it survives a restart, and the debug clock (F2 +1 day, F3 x60) skips it.

const Rules = preload("res://scripts/rules.gd")
const KEY := "nightlife"


## 0 below Rules.DRUNK_FROM drinks, then growing to 1.0 at Rules.DRUNK_FULL: 3 -> 0.125, 4 -> 0.25, 7 -> 0.625.
static func drunk_level(drinks: int) -> float:
	if drinks < Rules.DRUNK_FROM:
		return 0.0
	return clampf(float(drinks - Rules.DRUNK_FROM + 1) / float(Rules.DRUNK_FULL - Rules.DRUNK_FROM + 1), 0.0, 1.0)


static func is_wasted(drinks: int) -> bool:
	return drinks > Rules.WASTED_AFTER


static func state(needs: Node) -> Dictionary:
	return needs.ext.get(KEY, {})


static func lockout_until(needs: Node) -> float:
	return float(state(needs).get("lockout_until", 0.0))


static func seconds_left(needs: Node) -> float:
	return maxf(0.0, lockout_until(needs) - needs.clock)


static func locked(needs: Node) -> bool:
	return seconds_left(needs) > 0.0


## The character is WASTED: every minor need (the four meters) drops to Rules.WASTED_METER_VALUE, the visit ends
## (reason "wasted") and the player is locked out for Rules.WASTED_LOCKOUT_HOURS. Saved at once. Returns the index of
## the line to show (never the same as last time).
static func get_wasted(needs: Node, rng: RandomNumberGenerator = null) -> int:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	needs.sync()
	for m in Rules.METERS:
		needs.force_meter(m, Rules.WASTED_METER_VALUE)
	var s: Dictionary = state(needs).duplicate()
	var last := int(s.get("line", -1))
	var line := rng.randi_range(0, Rules.WASTED_LINES - 1)
	if line == last:
		line = (line + 1 + rng.randi_range(0, Rules.WASTED_LINES - 2)) % Rules.WASTED_LINES
	s["lockout_until"] = needs.clock + Rules.WASTED_LOCKOUT_HOURS * 3600.0
	s["wasted"] = int(s.get("wasted", 0)) + 1
	s["line"] = line
	needs.ext[KEY] = s
	needs.end_visit("wasted")   # saves when autosave is on
	if needs.autosave:
		needs.save_game()
	return line


## The line chosen when the character got WASTED (shown again on the locked screen after a restart).
static func last_line(needs: Node) -> int:
	return clampi(int(state(needs).get("line", 0)), 0, Rules.WASTED_LINES - 1)


## Check the plumbing: the drink need back to Rules.PLUMBING_DRINKS_TO ("the character pees and is ready to drink
## all over"), and this visit's Drinks points forgotten so the next round counts in full again.
static func check_plumbing(needs: Node) -> void:
	if not needs.visit_active:
		needs.begin_visit()
	needs.force_meter(Rules.DRINKS, Rules.PLUMBING_DRINKS_TO, true)
	needs.visit_last_action = needs.clock
	if needs.autosave:
		needs.save_game()


## "11:59:58" for the Try again countdown.
static func clock_text(secs: float) -> String:
	var s := ceili(secs)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
