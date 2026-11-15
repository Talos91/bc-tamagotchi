extends RefCounted
## Black Cabin's real event calendar, offline (backlog D1 upcoming events, D2 Tonight; docs/design/09-tonight-events.md).
## Data: res://data/events/<yyyy-mm>.json, a copy of docs/venue/events/<yyyy-mm>.json (format in its README). A month
## without a file is "not in the game yet": nothing is ever invented for it.
## Clock: Bangkok (UTC+7, no daylight saving). Opening hours Tue–Sun 19:00–02:00, so before 02:00 "tonight" is still the
## previous evening, and the Monday evening (Mon 02:00 → Tue 02:00) is closed.
## Strings: res://i18n/strings_tonight.csv, registered in project.godot; install() is the editor/test fallback.

const DATA_DIR := "res://data/events/"
const CSV_PATH := "res://i18n/strings_tonight.csv"
const PROBE := "tonight.head"
const UTC_OFFSET := 7 * 3600   ## Bangkok
const OPEN_HOUR := 19
const CLOSE_HOUR := 2          ## the evening runs past midnight to 02:00
const CLOSED_WEEKDAY := 1      ## Monday (Time weekday: 0 = Sunday)
const UPCOMING_MAX := 6
const DAY := 86400

## Unix seconds (UTC) that stand in for "now"; -1 = the real clock. Tests and captures pin it.
static var now_override := -1
static var _months := {}       ## "yyyy-mm" -> events Array, or null when the month has no file
static var _installed := false


static func now_unix() -> int:
	return now_override if now_override >= 0 else int(Time.get_unix_time_from_system())


## Unix seconds (UTC) for a Bangkok wall-clock time; tests and captures use it to pin the clock.
static func bkk_unix(year: int, month: int, day: int, hour := 0, minute := 0) -> int:
	var d := {"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": 0}
	return int(Time.get_unix_time_from_datetime_dict(d)) - UTC_OFFSET


## Bangkok wall clock for a unix time: {year, month, day, weekday, hour, minute, second}.
static func local(unix: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(unix + UTC_OFFSET)


static func date_key(d: Dictionary) -> String:
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


static func month_key(d: Dictionary) -> String:
	return "%04d-%02d" % [d["year"], d["month"]]


## Which evening "tonight" is at that moment, and the bar's state:
##   {date: "yyyy-mm-dd", day: {year, month, day, weekday}, state: "open" | "later" | "closed", next_open: {...}}
## open   = between 19:00 and 02:00 of an evening the bar opens
## later  = 02:00–19:00 on a day the bar opens: tonight is this evening, doors at 19:00
## closed = the Monday evening (Mon 02:00 to Tue 02:00); next_open is the Tuesday
static func evening(unix := -1) -> Dictionary:
	if unix < 0:
		unix = now_unix()
	var t := local(unix)
	var eve := t
	if t["hour"] < CLOSE_HOUR:
		eve = local(unix - DAY)
	var day := {"year": eve["year"], "month": eve["month"], "day": eve["day"], "weekday": eve["weekday"]}
	var state := "open"
	if eve["weekday"] == CLOSED_WEEKDAY:
		state = "closed"
	elif t["hour"] >= CLOSE_HOUR and t["hour"] < OPEN_HOUR:
		state = "later"
	var out := {"date": date_key(day), "day": day, "state": state, "next_open": day}
	if state == "closed":
		var nxt := local(_noon_unix(day) + DAY)
		out["next_open"] = {"year": nxt["year"], "month": nxt["month"], "day": nxt["day"], "weekday": nxt["weekday"]}
	return out


## Noon (Bangkok) of a calendar day, as unix seconds: stepping whole days from noon never crosses a date edge.
static func _noon_unix(d: Dictionary) -> int:
	return bkk_unix(d["year"], d["month"], d["day"], 12)


## The events of one month (sorted by date), or null when res://data/events/<ym>.json does not exist.
static func month_events(ym: String) -> Variant:
	if _months.has(ym):
		return _months[ym]
	var path := DATA_DIR + ym + ".json"
	var out: Variant = null
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("events")) == TYPE_ARRAY:
			var evs: Array = []
			for e in parsed["events"]:
				if typeof(e) == TYPE_DICTIONARY and str(e.get("date", "")).begins_with(ym) and str(e.get("title", "")) != "":
					evs.append(e)
			evs.sort_custom(func(a, b): return str(a["date"]) + str(a.get("time", "")) < str(b["date"]) + str(b.get("time", "")))
			out = evs
		else:
			push_error("tonight_events: bad JSON in " + path)
	_months[ym] = out
	return out


static func has_month(ym: String) -> bool:
	return month_events(ym) != null


## Forget loaded months (tests swap the data folder contents).
static func reset_cache() -> void:
	_months.clear()


## Tonight: evening() plus {known: the month has data, events: tonight's events (usually one, maybe none)}.
static func tonight(unix := -1) -> Dictionary:
	var e := evening(unix)
	var ym := month_key(e["day"])
	var evs: Variant = month_events(ym)
	e["known"] = evs != null
	var mine: Array = []
	if evs != null and e["state"] != "closed":
		for ev in evs:
			if ev["date"] == e["date"]:
				mine.append(ev)
	e["events"] = mine
	return e


## Events after tonight in tonight's month and the next one, at most `limit`, plus the months among those two that
## have no data yet: {events: [...], missing: ["yyyy-mm", ...]}.
static func upcoming(unix := -1, limit := UPCOMING_MAX) -> Dictionary:
	var e := evening(unix)
	var d: Dictionary = e["day"]
	var months := [month_key(d), _next_month(month_key(d))]
	var out: Array = []
	var missing: Array = []
	for ym in months:
		var evs: Variant = month_events(ym)
		if evs == null:
			missing.append(ym)
			continue
		for ev in evs:
			if str(ev["date"]) > e["date"] and out.size() < limit:
				out.append(ev)
	return {"events": out, "missing": missing}


static func _next_month(ym: String) -> String:
	var y := int(ym.substr(0, 4))
	var m := int(ym.substr(5, 2)) + 1
	if m > 12:
		m = 1
		y += 1
	return "%04d-%02d" % [y, m]


# --- Text ----------------------------------------------------------------------------------------------------------

static func install() -> void:
	if _installed:
		return
	_installed = true
	if String(TranslationServer.translate(PROBE)) != PROBE:
		return   # project.godot registered the imported translations (always the case in the web export)
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return
	var by_lang := {"en": Translation.new(), "th": Translation.new()}
	for l in by_lang:
		by_lang[l].locale = l
	f.get_csv_line()  # header
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() >= 3 and r[0] != "":
			by_lang["en"].add_message(r[0], r[1])
			by_lang["th"].add_message(r[0], r[2])
	for l in by_lang:
		TranslationServer.add_translation(by_lang[l])


static func t(key: String, vars: Dictionary = {}) -> String:
	install()
	var s := String(TranslationServer.translate(key))
	return s.format(vars) if not vars.is_empty() else s


## "Wed 21 Oct" from a {year, month, day, weekday} dict or a "yyyy-mm-dd" string.
static func date_text(d: Variant) -> String:
	if typeof(d) == TYPE_STRING:
		var p := str(d).split("-")
		var u := bkk_unix(int(p[0]), int(p[1]), int(p[2]), 12)
		d = local(u)
	return t("tonight.date_fmt", {"wd": t("tonight.day.%d" % int(d["weekday"])), "d": int(d["day"]),
		"mon": t("tonight.month.%d" % int(d["month"]))})


static func month_text(ym: String) -> String:
	return t("tonight.month_year", {"mon": t("tonight.month_long.%d" % int(ym.substr(5, 2))), "y": ym.substr(0, 4)})


## "Showtime 22:45" or "From 21:15" (time_kind in the month JSON), "" when the poster gave no time.
static func time_text(ev: Dictionary) -> String:
	var tm := str(ev.get("time", ""))
	if tm == "":
		return ""
	return t("tonight.time.showtime" if str(ev.get("time_kind", "")) == "showtime" else "tonight.time.onwards", {"time": tm})


## The state line under the header.
static func state_text(e: Dictionary) -> String:
	match str(e["state"]):
		"open":
			return t("tonight.state.open")
		"later":
			return t("tonight.state.later")
		_:
			return t("tonight.state.closed", {"day": t("tonight.day.%d" % int(e["next_open"]["weekday"]))})
