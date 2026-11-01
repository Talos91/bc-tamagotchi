class_name VenueSession
extends Node
## What the player can do in each zone and what it earns: the GDD §2.3 refill table, applied only through
## Needs.apply_action with the existing action ids (rules.gd). Owns the visit lifecycle in the room (arrive, leave),
## passive listening to the house band, the one-minute sit, tipsiness (03-cast §5.1) and the drink menu.
## Sitting takes a real seat (find_seat): the player walks to a free chair, couch place or stool of the zone's table
## and sits on it; the minute runs once seated and stops when they stand up. Zones without seats (the game cabinet)
## keep the old stand-still minute. "Take a stool" at the bar seats the player for a minute's chat (bar_chat).
## UI-free: the HUD and sheets read rows_for() and listen to the signals; main.gd opens minigames on request.

signal action_done(card: Dictionary)  ## {line, gains, tab, ok, reason, quiet}; quiet = passive, chips only
signal minigame_requested(game_id: String, config: Dictionary)
signal visit_begun(info: Dictionary)
signal visit_finished(summary: Dictionary)  ## Needs' summary + start_meters, end_meters, tipsy
signal welcome_back(reason: String)
signal state_changed  ## tipsiness, sitting or band state the HUD shows

const Rules = preload("res://scripts/rules.gd")
const Tipsiness = preload("res://scripts/zones/tipsiness.gd")
const HouseBand = preload("res://scripts/zones/house_band.gd")
const T = preload("res://scripts/zones/venue_strings.gd")

const BARTENDER := "nam"
const SIT_SECONDS := 60.0          ## GDD §2.3 "Sit at a table ... for 60 s"
const HEARD_FRACTION := 0.6        ## share of a song spent within earshot for it to count as heard
const EARSHOT_ZONES := ["stage", "floor"]  ## camera zones within earshot of the stage (Stage, Candle Floor)
const TRIED_KEY := "drinks_tried"  ## Needs.ext[TRIED_KEY][drink_id] = true (persists with the save)
## Try-something-new menu, in order. All alcoholic; the Thai iced tea and water rows are the non-alcoholic ones.
const MENU := ["lychee_fizz", "thai_tea_sour", "mekhong_mule", "butterfly_gin", "pandan_colada", "smoky_old_fashioned"]
const GAMES := {
	"pour_perfect": "res://scenes/minigames/pour_perfect/pour_perfect.tscn",
	"front_row_rhythm": "res://scenes/minigames/front_row_rhythm/front_row_rhythm.tscn",
	"candle_talk": "res://scenes/minigames/candle_talk/candle_talk.tscn",
	"neon_pinball": "res://scenes/minigames/neon_pinball/neon_pinball.tscn",
}

var needs: Node
var zones: VenueZones
var player: Player
var band: HouseBand
var busy := false              ## a sheet, minigame or dialogue is open: passive listening pauses
var tipsy := Tipsiness.new()
var drinks_this_visit := 0
var songs_heard := 0
var start_meters := {}
var sitting := {}              ## {zone, key, left, seat (bool)} from "sit" until the minute is up or they stand
var _heard := 0.0
var _quiet_end := false


func setup(needs_node: Node, zones_node: VenueZones, player_node: Player) -> void:
	needs = needs_node
	zones = zones_node
	player = player_node
	band = HouseBand.new()
	band.name = "HouseBand"
	add_child(band)
	band.song_started.connect(_on_song_started)
	band.song_ended.connect(_on_song_ended)
	needs.visit_started.connect(_on_visit_started)
	needs.visit_ended.connect(_on_visit_ended)
	needs.welcome_back_started.connect(func(reason): welcome_back.emit(reason))
	needs.action_applied.connect(_on_action_applied)


# --- Visit ---------------------------------------------------------------------------------------

## The character walks in: starts a visit (Welcome Back, if due, fires from inside Needs.begin_visit).
func arrive() -> void:
	needs.begin_visit()


## Leaving through the street door or the HUD's Leave button.
func leave() -> void:
	cancel_sit()
	needs.end_visit("left")


func _on_visit_started(info: Dictionary) -> void:
	start_meters = needs.meters.duplicate()
	tipsy.reset(needs.real_now())
	drinks_this_visit = 0
	songs_heard = 0
	_heard = 0.0
	_apply_mood()
	visit_begun.emit(info)


func _on_visit_ended(summary: Dictionary) -> void:
	cancel_sit()
	if _quiet_end:
		return
	var s := summary.duplicate()
	s["start_meters"] = start_meters.duplicate()
	s["end_meters"] = needs.meters.duplicate()
	s["tipsy"] = tipsy.state()
	visit_finished.emit(s)


## Debug (F4): as if the player stayed away a week, then walks back in. Welcome Back fires.
func debug_week_away() -> void:
	_quiet_end = true
	needs.end_visit("debug")
	_quiet_end = false
	needs.debug_advance(Rules.WELCOME_BACK_AWAY_DAYS * 86400.0 + 60.0)
	arrive()


# --- Rows ----------------------------------------------------------------------------------------

## Things you'd do in this zone (wireframes §4): {id, title, sub, need, game, enabled, reason}.
func rows_for(zone: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var merry := tipsy.state() == Tipsiness.MERRY
	match zone.get("kind", ""):
		"bar":
			var no_alc := T.t("venue.sheet.bar.merry") if merry else ""
			rows.append(_row("order", "venue.sheet.bar.order",
				T.t("venue.sheet.bar.order_free") if drinks_this_visit == 0 else T.t("venue.sheet.bar.order_sub"), "drinks", false, no_alc))
			rows.append(_row("pour", "venue.sheet.bar.pour", T.t("venue.sheet.bar.pour_sub", {"best": _best("pour_perfect")}), "drinks", true))
			var nxt := next_new_drink()
			if nxt == "":
				rows.append(_row("try", "venue.sheet.bar.try", "", "drinks", false, T.t("venue.sheet.bar.try_done")))
			else:
				rows.append(_row("try", "venue.sheet.bar.try", T.t("venue.sheet.bar.try_sub", {"drink": T.t("venue.drink." + nxt)}), "drinks", false, no_alc))
			rows.append(_row("mocktail", "venue.sheet.bar.mocktail", T.t("venue.sheet.bar.mocktail_sub"), "drinks"))
			rows.append(_row("water", "venue.sheet.bar.water", T.t("venue.sheet.bar.water_sub"), "drinks"))
			var on_stool: bool = player != null and player.seated and str(player.seat.get("table", "")) == "Bar"
			var why := T.t("venue.sheet.bar.on_stool") if on_stool else ""
			if _cap_left("bar_chat") <= 0.0:
				why = T.t("venue.sheet.plenty")
			rows.append(_row("stool", "venue.sheet.bar.stool", T.t("venue.sheet.bar.stool_sub"), "friends", false, why))
		"stage":
			rows.append(_row("front", "venue.sheet.stage.front", T.t("venue.sheet.stage.front_sub"), "music"))
			rows.append(_row("rhythm", "venue.sheet.stage.rhythm", T.t("venue.sheet.stage.rhythm_sub", {"best": _best("front_row_rhythm")}), "music", true))
			var why := ""
			if _cap_left("applaud") <= 0.0:
				why = T.t("venue.sheet.plenty")
			elif band.playing:
				why = T.t("venue.sheet.stage.between")
			rows.append(_row("applaud", "venue.sheet.stage.applaud", T.t("venue.sheet.stage.applaud_sub"), "music", false, why))
		"table":
			var reg: String = zone.get("regular", "")
			if reg != "":
				var who := _name(reg)
				rows.append(_row("talk", "venue.sheet.table.talk", T.t("venue.sheet.table.talk_sub", {"regular": who, "best": _best("candle_talk")}),
					"friends", true, T.t("venue.sheet.table.talked") if needs.daily_keys.has("candle_talk|" + reg) else ""))
			var sit_title := T.t("venue.sheet.table.sit_regular", {"regular": _name(reg)}) if reg != "" else T.t("venue.sheet.table.sit")
			var sit := _row("sit", "", T.t("venue.sheet.table.sit_sub"), "friends", false,
				T.t("venue.sheet.table.sat") if needs.daily_keys.has("sit_with|" + sit_key(zone)) else "")
			sit["title"] = sit_title
			rows.append(sit)
		"arcade":
			rows.append(_row("pinball", "venue.sheet.arcade.play", T.t("venue.sheet.arcade.play_sub", {"best": _best("neon_pinball")}), "nightlife", true))
		"cabinet", "tall", "smoking":
			# Plan v4 stubs (game cabinet, tall tables, smoking room): the generic table sheet until their own content lands
			var sit := _row("sit", "venue.sheet.table.sit", T.t("venue.sheet.table.sit_sub"), "friends", false,
				T.t("venue.sheet.table.sat") if needs.daily_keys.has("sit_with|" + sit_key(zone)) else "")
			rows.append(sit)
		"exit":
			rows.append(_row("leave", "venue.sheet.exit.leave", T.t("venue.sheet.exit.leave_sub"), ""))
	return rows


## Sheet header and the line under it.
func header_for(zone: Dictionary) -> Array[String]:
	var reg: String = zone.get("regular", "")
	match zone.get("kind", ""):
		"bar":
			return [T.t("venue.sheet.bar.head", {"who": _name(BARTENDER)}),
				T.t("venue.sheet.bar.greet_merry" if tipsy.state() == Tipsiness.MERRY else "venue.sheet.bar.greet")]
		"stage":
			return [T.t("venue.sheet.stage.head"), band_text()]
		"table":
			if reg != "":
				return [T.t("venue.sheet.table.head_regular", {"regular": _name(reg)}), T.t("venue.sheet.table.greet_regular", {"regular": _name(reg)})]
			return [T.t("venue.sheet.table.head"), T.t("venue.sheet.table.greet")]
		"arcade":
			return [T.t("venue.sheet.arcade.head"), T.t("venue.sheet.arcade.greet")]
		"cabinet", "tall", "smoking":
			return [T.t("venue.sheet.%s.head" % zone["kind"]), T.t("venue.sheet.%s.greet" % zone["kind"])]
		"exit":
			return [T.t("venue.sheet.exit.head"), T.t("venue.sheet.exit.greet")]
	return ["", ""]


func prompt_for(zone: Dictionary) -> String:
	match zone.get("kind", ""):
		"table":
			if zone.get("regular", "") != "":
				return T.t("venue.prompt.table_regular", {"regular": _name(zone["regular"])})
			return T.t("venue.prompt.table")
		"":
			return ""
	return T.t("venue.prompt." + str(zone["kind"]))


func band_text() -> String:
	if band.playing:
		return T.t("venue.band.live", {"n": band.song + 1})
	return T.t("venue.band.break", {"s": ceili(band.seconds_left())})


func _row(id: String, title_key: String, sub: String, need: String, game := false, reason := "") -> Dictionary:
	return {"id": id, "title": T.t(title_key) if title_key != "" else "", "sub": sub, "need": need, "game": game,
		"enabled": reason == "", "reason": reason}


func _name(id: String) -> String:
	if id == BARTENDER:
		return T.t("venue.cast.nam")
	return String(TranslationServer.translate("cast.%s.name" % id))


func _best(game_id: String) -> String:
	var b := int(needs.ext.get("minigame_best", {}).get(game_id, 0))
	return T.t("venue.sheet.best", {"score": b}) if b > 0 else T.t("venue.sheet.no_best")


func _cap_left(action_id: String) -> float:
	var def: Dictionary = Rules.ACTIONS[action_id]
	if not def.has("cap_per_visit"):
		return INF
	return float(def["cap_per_visit"]) - float(needs.visit_action_totals.get(action_id, 0.0)) if needs.visit_active else float(def["cap_per_visit"])


func sit_key(zone: Dictionary) -> String:
	## sit_with is once per character per day: the regular's id, or the table for its anonymous patrons.
	return zone["regular"] if zone.get("regular", "") != "" else str(zone["id"])


func next_new_drink() -> String:
	var tried: Dictionary = needs.ext.get(TRIED_KEY, {})
	for d in MENU:
		if not tried.has(d):
			return d
	return ""


# --- Doing things --------------------------------------------------------------------------------

## Performs a row. Returns false if the row is unknown or disabled.
func do_row(zone: Dictionary, row_id: String) -> bool:
	var row: Dictionary = {}
	for r in rows_for(zone):
		if r["id"] == row_id:
			row = r
	if row.is_empty() or not row["enabled"]:
		return false
	var now: float = needs.real_now()
	match row_id:
		"order":
			_drink(now, true, T.t("venue.card.order", {"who": _name(BARTENDER)}))
		"mocktail":
			_drink(now, false, T.t("venue.card.mocktail"))
		"water":
			tipsy.water(now)
			_drink(now, false, T.t("venue.card.water"))
		"try":
			var d := next_new_drink()
			var r: Dictionary = needs.apply_action("order_drink")
			var bonus: Dictionary = needs.apply_action("try_new_drink")
			var tried: Dictionary = needs.ext.get(TRIED_KEY, {})
			tried[d] = true
			needs.ext[TRIED_KEY] = tried
			_count_drink(now, true)
			_card(_merge(r, bonus), T.t("venue.card.try", {"drink": T.t("venue.drink." + d)}))
		"pour":
			_request("pour_perfect", {})
		"front":
			player.walk_to(zone["approach"])
			action_done.emit({"line": T.t("venue.card.front"), "gains": {}, "tab": 0.0, "ok": true, "reason": "", "quiet": false})
		"rhythm":
			_request("front_row_rhythm", {"song": band.song})
		"applaud":
			_card(needs.apply_action("applaud"), T.t("venue.card.applaud"))
		"talk":
			_request("candle_talk", {"regular": zone["regular"]})
		"sit":
			var seat := find_seat(zone)
			sitting = {"zone": zone["id"], "key": sit_key(zone), "left": SIT_SECONDS, "seat": not seat.is_empty()}
			if not seat.is_empty() and seat["node"] != player.seat.get("node"):
				player.sit_at(seat)
			_apply_mood()
			state_changed.emit()
		"stool":
			var seat := find_seat(zone)
			if seat.is_empty():
				return false
			sitting = {"zone": zone["id"], "key": "", "left": SIT_SECONDS, "seat": true, "action": "bar_chat"}
			player.sit_at(seat)
			_apply_mood()
			state_changed.emit()
		"pinball":
			_request("neon_pinball", {})
		"leave":
			leave()
	return true


func _drink(now: float, alcoholic: bool, line: String) -> void:
	var r: Dictionary = needs.apply_action("order_drink")
	_count_drink(now, alcoholic)
	_card(r, line)


func _count_drink(now: float, alcoholic: bool) -> void:
	drinks_this_visit += 1
	if alcoholic and tipsy.state() != Tipsiness.MERRY:
		tipsy.add_alcohol(now)
	_apply_mood()
	state_changed.emit()


func _request(game_id: String, config: Dictionary) -> void:
	cancel_sit(false)   # the minute stops; a seated player stays on the seat through the minigame
	minigame_requested.emit(game_id, config)


## A Pour Perfect landed (every attempt, AGAIN included): it is a drink. Nam pours a mocktail while Merry.
func _on_action_applied(action_id: String, result: Dictionary) -> void:
	if action_id == "pour_perfect" and result.get("ok", false):
		_count_drink(needs.real_now(), true)


func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for m in b.get("gains", {}):
		out["gains"][m] = float(out["gains"].get(m, 0.0)) + float(b["gains"][m])
	out["tab"] = float(out.get("tab", 0.0)) + float(b.get("tab", 0.0))
	out["ok"] = a.get("ok", false) or b.get("ok", false)
	return out


func _card(r: Dictionary, line: String, quiet := false) -> void:
	var total := 0.0
	for m in r.get("gains", {}):
		total += float(r["gains"][m])
	if total < 0.05 and not quiet:
		line = T.t("venue.card.plenty")
	action_done.emit({"line": line, "gains": r.get("gains", {}), "tab": float(r.get("tab", 0.0)), "ok": r.get("ok", false),
		"reason": r.get("reason", ""), "quiet": quiet})


## Ends the sit. `stand` also gets the player off the seat (leaving, the visit ending).
func cancel_sit(stand := true) -> void:
	if stand and is_instance_valid(player):
		player.stand_up()
	if sitting.is_empty():
		return
	sitting = {}
	_apply_mood()
	state_changed.emit()


# --- Passive -------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	tick(delta)


## Everything that happens by standing around. Tests call it with large steps.
func tick(delta: float) -> void:
	if needs == null or not is_instance_valid(player):
		return
	if not busy and band.playing and in_earshot():
		_heard += delta
	# Plan v4: the street door opens into the lobby / L corridor, the lounge's entrance: the bonus still lands on arrival
	if needs.visit_active and player.rig.zone in ["lounge", "lobby", "corridor"] and not needs.visit_once.has("enter_lounge"):
		_card(needs.apply_action("enter_lounge"), T.t("venue.card.lounge"), true)
	if not sitting.is_empty():
		var off := false
		var counting := true
		if sitting["seat"]:
			off = not player.seated and not player.seat_pending()   # stood up, or never got to the seat
			counting = player.seated
		else:
			off = player.walking_to or player.velocity.length() > 0.5 or zones.current.get("id", "") != sitting["zone"]
		if off:
			cancel_sit()
		elif counting:
			sitting["left"] -= delta
			if sitting["left"] <= 0.0:
				var key: String = sitting["key"]
				var action: String = sitting.get("action", "sit_with")
				cancel_sit(false)   # the minute is up; the player keeps the seat until they move
				_card(needs.apply_action(action, 1.0, key), T.t("venue.card.bar_chat" if action == "bar_chat" else "venue.card.sit"))
	if tipsy.update(needs.real_now()):
		_apply_mood()
		state_changed.emit()


func in_earshot() -> bool:
	return player.rig.zone in EARSHOT_ZONES


func _on_song_started(_song: int) -> void:
	_heard = 0.0
	state_changed.emit()


func _on_song_ended(_song: int) -> void:
	if _heard >= HouseBand.SONG_SECONDS * HEARD_FRACTION and needs.visit_active:
		songs_heard += 1
		_card(needs.apply_action("listen_song"), T.t("venue.card.song"), true)
		if songs_heard % HouseBand.SONGS == 0:
			_card(needs.apply_action("finish_set"), T.t("venue.card.set"))
	_heard = 0.0
	state_changed.emit()


func _apply_mood() -> void:
	if not is_instance_valid(player):
		return
	player.anim_suffix = Tipsiness.ANIM_SUFFIX[tipsy.state()]
	player.pose_override = "stand_drink" if not sitting.is_empty() and not sitting["seat"] else ""


# --- Seats ---------------------------------------------------------------------------------------

## The seat spot the player takes at this zone (spots of Venue/Patrons/Spots in group "seat", tagged with their
## table by tools/build_venue.gd; patrons sit on the same spots): the player's own seat if they already sit there,
## else the free seat nearest to them, else the nearest taken one, whose patron gets up to make room.
## {} where the zone has no seats. {node, pos, yaw, h, couch, table, pose}
func find_seat(zone: Dictionary) -> Dictionary:
	var crowd := get_tree().get_first_node_in_group("venue_patrons")
	var mine: Variant = player.seat.get("node")
	var best: Node3D = null
	var best_d := INF
	var taken_best: Node3D = null
	var taken_d := INF
	for s in get_tree().get_nodes_in_group("seat"):
		if not _seat_of(s, zone):
			continue
		if s == mine:
			return player.seat
		var d := (s as Node3D).global_position.distance_to(player.global_position)
		if crowd != null and crowd.is_taken(s):
			if d < taken_d:
				taken_d = d
				taken_best = s
		elif d < best_d:
			best_d = d
			best = s
	if best == null and taken_best != null:
		crowd.vacate(taken_best)
		best = taken_best
	if best == null:
		return {}
	var couch: bool = best.get_meta("couch", false)
	var table: String = best.get_meta("table", "")
	return {"node": best, "pos": best.global_position, "yaw": best.global_rotation.y, "h": float(best.get_meta("seat_h", 0.45)),
		"couch": couch, "table": table, "pose": "sit_hold" if couch or table == "HighCounter" else "sit_drink"}


## A table zone's seats are its table's (zone id "table:<name>" / "tall:<name>"), the bar's are the counter stools,
## the smoking room's are all its chairs.
static func _seat_of(s: Node, zone: Dictionary) -> bool:
	match zone.get("kind", ""):
		"table", "tall":
			return str(s.get_meta("table", "")) == str(zone["id"]).get_slice(":", 1)
		"bar":
			return str(s.get_meta("table", "")) == "Bar"
		"smoking":
			return str(s.get_meta("zone", "")) == "Smoking"
	return false
