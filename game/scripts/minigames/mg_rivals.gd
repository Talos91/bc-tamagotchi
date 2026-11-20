extends RefCounted
## Offline competition for every minigame (docs/design/11-minigame-quality.md §4.1, job Q4; DECISIONS 2026-11-18:
## personal best, a regular to beat, ghost run, board; no practice rounds). No server: tonight's regulars "play"
## each game with a score seeded from the Bangkok night (Cast.night(), turning at 06:00), so every player sees the same
## numbers tonight and new ones tomorrow. They are clearly the cast, never presented as real players.
##
## THE API THE GAMES CALL (Neon Moth is the template; Coaster Flip, Soi Dash, Shake & Serve... copy it):
##   const Rivals = preload("res://scripts/minigames/mg_rivals.gd")
##   _on_start():
##       var t := Rivals.tonight(game_id)            # {night, best, ghost, rival, board}
##       rival = t.rival                             # {regular, name, points}: the regular to beat (show it in play)
##       ghost = t.ghost                             # {} or what you saved with your best run tonight
##   _result_extra():                                # called once by finish()
##       var r := Rivals.record(game_id, points_for(score), my_ghost_data)
##       return {..., "rival": rival, "board": r.board_line}   # result_card shows both lines
##
##   tonight(game_id, store = null) -> Dictionary
##       night: int; best: your best points tonight (0 = none); ghost: Dictionary (empty = none);
##       rival: {regular, name, points} = the regular just above your best tonight (the next rung), or the top one when
##       you are above everyone; board: rows (see board()).
##   record(game_id, points, ghost := {}, store = null) -> Dictionary
##       Keeps your best tonight and, when this run beats it, its ghost. Returns {best, new_best, board, board_line}
##       where board_line = {rank, count} for the result card ("#2 of 5 tonight").
##   board(game_id, player_points := -1, night := -1) -> Array[Dictionary]
##       Tonight's rows, best first: {id, name, points, you}. player_points < 0 leaves you out. The lounge "Top
##       patrons" board (job Q10) reads the same rows.
##   lineup(game_id, night) -> Array[String]: the LINEUP regulars who play that game that night (seeded).
##   regular_points(game_id, regular, night) -> int: one regular's seeded score, 5..100 x SCALE.
##   to_beat(game_id, best, night) -> Dictionary: as `rival` above.
##   set_skill(game_id, table): optional per-game skill table (regular -> mean score 0..1) when the house mix differs.
##
## The all-time personal best stays where it was (result_card: Needs.ext["minigame_best"], NEW BEST ribbon); this file
## keeps only tonight: Needs.ext[EXT_KEY][game_id] = {night, best, ghost}. A ghost is the game's own small record
## (Neon Moth: the moth's height every GHOST_STEP px of the flight, ints; keep it to a few hundred numbers, JSON-safe:
## ints, floats, strings, arrays, dictionaries). Without a Needs node (tests, the lab) it keeps an in-memory store.

const Cast = preload("res://scripts/cast.gd")
const S = preload("res://scripts/minigames/strings.gd")

const EXT_KEY := "minigame_tonight"
const LINEUP := ["tt", "tong", "ploy", "jules", "dougie", "lung_nop", "bow", "hiro"]
const PLAYERS_A_NIGHT := 4          ## regulars on a game's board each night
## Mean score (0..1) per regular, from the 03-cast voices: Hiro the sharp one, Lung Nop plays for fun.
const SKILL := {"hiro": 0.86, "jules": 0.8, "tt": 0.72, "bow": 0.66, "ploy": 0.62, "dougie": 0.55, "tong": 0.48, "lung_nop": 0.34}
const SPREAD := 0.09                ## night-to-night spread (normal sigma) around a regular's mean
const DEFAULT_SKILL := 0.6
## Endless ramp (docs/design/15-minigame-ramp.md, card minigame-ramp-rivals, awaiting Daniele): the games have no
## ceiling now, so tonight's regulars score on SCALE x the old 0-100 to keep the board a contest.
const SCALE := 1.5

static var _skills := {}            ## game_id -> {regular: mean}, set_skill()
static var _mem := {}               ## the store without Needs: {EXT_KEY: {...}} like Needs.ext


static func set_skill(game_id: String, table: Dictionary) -> void:
	_skills[game_id] = table


## Clears the in-memory store (tests).
static func reset_memory() -> void:
	_mem = {}


static func night() -> int:
	return Cast.night()


static func _skill(game_id: String, regular: String) -> float:
	var t: Dictionary = _skills.get(game_id, SKILL)
	return float(t.get(regular, SKILL.get(regular, DEFAULT_SKILL)))


static func _rng(parts: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(parts)
	return rng


## One regular's score tonight in this game, 5..100 x SCALE: their mean plus a seeded spread.
static func regular_points(game_id: String, regular: String, n := -1) -> int:
	if n < 0:
		n = night()
	var rng := _rng("%s|%s|%d" % [game_id, regular, n])
	return clampi(roundi(rng.randfn(_skill(game_id, regular), SPREAD) * 100.0 * SCALE), 5, roundi(100.0 * SCALE))


## Who plays this game tonight: PLAYERS_A_NIGHT of the LINEUP, seeded per game and night.
static func lineup(game_id: String, n := -1) -> Array[String]:
	if n < 0:
		n = night()
	var rng := _rng("%s|lineup|%d" % [game_id, n])
	var pool: Array = LINEUP.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array[String] = []
	for i in mini(PLAYERS_A_NIGHT, pool.size()):
		out.append(str(pool[i]))
	return out


## Tonight's board, best first: {id, name, points, you}. Ties: the regular stays above you (beat them, not tie).
static func board(game_id: String, player_points := -1, n := -1) -> Array[Dictionary]:
	if n < 0:
		n = night()
	var rows: Array[Dictionary] = []
	for r in lineup(game_id, n):
		rows.append({"id": r, "name": Cast.name_of(r), "points": regular_points(game_id, r, n), "you": false})
	if player_points >= 0:
		rows.append({"id": "", "name": S.t("mg.rivals.you"), "points": player_points, "you": true})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["points"]) != int(b["points"]):
			return int(a["points"]) > int(b["points"])
		return not bool(a["you"]) and bool(b["you"]))
	return rows


## The next rung: the regular with the lowest score above `best` tonight; the top regular when you are above all.
static func to_beat(game_id: String, best := 0, n := -1) -> Dictionary:
	var pick: Dictionary = {}
	var top: Dictionary = {}
	for row in board(game_id, -1, n):
		if top.is_empty():
			top = row
		if int(row["points"]) >= best:
			pick = row  # rows run best first, so the last one at or above best is the lowest rung
	var r: Dictionary = pick if not pick.is_empty() else top
	return {"regular": str(r.get("id", "")), "name": str(r.get("name", "")), "points": int(r.get("points", 0))}


## Your place on a board: {rank (1-based), count}; rank 0 when you are not on it.
static func board_line(rows: Array) -> Dictionary:
	for i in rows.size():
		if bool(rows[i].get("you", false)):
			return {"rank": i + 1, "count": rows.size()}
	return {"rank": 0, "count": rows.size()}


# --- Tonight's record (best + ghost) ------------------------------------------------------------------------------

static func _store(store: Object) -> Object:
	if store != null:
		return store
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var n := tree.root.get_node_or_null("Needs")
		if n != null:
			return n
	return null


static func _ext(store: Object) -> Dictionary:
	var s := _store(store)
	if s == null:
		return _mem
	var e: Variant = s.get("ext")
	return e if e is Dictionary else _mem


## Your record for this game tonight: {night, best, ghost}; empty values once the night has turned.
static func mine(game_id: String, store: Object = null, n := -1) -> Dictionary:
	if n < 0:
		n = night()
	var all: Variant = _ext(store).get(EXT_KEY)
	var rec: Variant = all.get(game_id) if all is Dictionary else null
	if rec is Dictionary and int(rec.get("night", -1)) == n:
		return {"night": n, "best": int(rec.get("best", 0)), "ghost": rec.get("ghost", {}) if rec.get("ghost") is Dictionary else {}}
	return {"night": n, "best": 0, "ghost": {}}


static func tonight(game_id: String, store: Object = null, n := -1) -> Dictionary:
	if n < 0:
		n = night()
	var m := mine(game_id, store, n)
	m["rival"] = to_beat(game_id, int(m["best"]), n)
	m["board"] = board(game_id, int(m["best"]) if int(m["best"]) > 0 else -1, n)
	return m


## Keeps your best tonight (and the ghost of the run that set it). Returns {best, new_best, board, board_line}.
static func record(game_id: String, points: int, ghost: Dictionary = {}, store: Object = null, n := -1) -> Dictionary:
	if n < 0:
		n = night()
	var m := mine(game_id, store, n)
	var best := int(m["best"])
	var new_best := points > best
	if new_best:
		var ext := _ext(store)
		var all: Variant = ext.get(EXT_KEY)
		if not all is Dictionary:
			all = {}
		all[game_id] = {"night": n, "best": points, "ghost": ghost}
		ext[EXT_KEY] = all
		best = points
	var rows := board(game_id, best, n)
	# the result line places this run (not only your best) so a weaker try reads honestly
	var line := board_line(board(game_id, points, n))
	return {"best": best, "new_best": new_best, "board": rows, "board_line": line}
