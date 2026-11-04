extends RefCounted
## Pre-alpha debug actions on the Needs autoload (scripts/ui/debug_panel.gd is the phone-friendly front end, the
## headless test tests/test_debug_tools.gd drives these directly). Each returns a short status line.

const Rules = preload("res://scripts/rules.gd")
const Nightlife = preload("res://scripts/zones/nightlife.gd")


## Clear the WASTED lockout now (the Try again button on the WASTED screen enables itself).
static func clear_lockout(needs: Node) -> String:
	needs.sync()
	var s: Dictionary = Nightlife.state(needs).duplicate()
	s["lockout_until"] = 0.0
	needs.ext[Nightlife.KEY] = s
	needs._dirty = true
	if needs.autosave:
		needs.save_game()
	return "lockout cleared"


## Make the character WASTED right now (meters, visit end and the 12 h lockout as in play). Returns the line index.
static func force_wasted(needs: Node) -> int:
	return Nightlife.get_wasted(needs)


## Jump the game clock (and decay) forward.
static func jump(needs: Node, secs: float) -> String:
	needs.debug_advance(secs)
	if needs.autosave:
		needs.save_game()
	return "clock +%s" % _span(secs)


## Jump to the start of the next bar night (Rules.NIGHT_STARTS_HOUR, Bangkok).
static func jump_night(needs: Node) -> String:
	needs.sync()
	var next_start := float(needs.night_key(needs.clock) + 1) * 86400.0 - (Rules.DAY_UTC_OFFSET_HOURS - Rules.NIGHT_STARTS_HOUR) * 3600.0
	return jump(needs, maxf(60.0, next_start - needs.clock))


## Skip the fatal clock: advance past death so the character is a ghost (06-stakes §5.1). Already a ghost: nothing.
static func make_ghost(needs: Node) -> String:
	if needs.is_ghost():
		return "already a ghost"
	if needs.is_deleted():
		return "deleted: reset the save"
	needs.last_revival_at = 0.0   # let the debug revival run again
	needs.debug_advance((Rules.FATAL_DAYS + 1.0) * 86400.0 - needs.stake_secs())
	return "ghost: %s" % str(needs.is_ghost())


## The debug check-in (06-stakes §10.5): the same code the server will call; revives a ghost. The cooldown is lifted
## first so the panel can be used more than once per 90 days.
static func fake_check_in(needs: Node) -> String:
	needs.last_revival_at = 0.0
	var r: Dictionary = needs.check_in()
	return "check-in: ok %s, revived %s%s" % [str(r["ok"]), str(r["revived"]), "" if r["ok"] else " (%s)" % r["reason"]]


## New game and a deleted save file.
static func reset_save(needs: Node) -> void:
	needs.delete_save()
	needs.new_game()


static func _span(secs: float) -> String:
	return "%d h" % int(round(secs / 3600.0)) if secs < 86400.0 * 2.0 else "%d d" % int(round(secs / 86400.0))
