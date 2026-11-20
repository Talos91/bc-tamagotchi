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
	_weeks.clear()


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
	var lu := lineup(e["date"])
	e["lineup_known"] = lu["known"]
	e["acts"] = lu["acts"] if e["state"] != "closed" else []
	e["now_act"] = now_on_stage(e["date"], unix if unix >= 0 else now_unix()) if e["state"] == "open" else -1
	return e


# --- Weekly lineup ("who's playing tonight") ------------------------------------------------------------------------
## res://data/events/lineup-<monday yyyy-mm-dd>.json, a copy of docs/venue/events/lineup-<monday>.json: one file per
## week (Mon–Sun) from the bar's weekly "This week on stage" posters, found by name like the month files (no list to
## update). Each day: {date, day, title?, poster, acts: [{slug, name, genre?, role?, start, end? | till_late?,
## description?, photo?}]}. Photos: res://assets/events/<photo>. A week without a file is "not in yet": nothing invented.

const PHOTO_DIR := "res://assets/events/"
const LATE_MIN := (24 + CLOSE_HOUR) * 60   ## 02:00, as minutes after the evening's midnight-before
static var _weeks := {}        ## "yyyy-mm-dd" (Monday) -> {date: day dict} or null


## The Monday (yyyy-mm-dd) of the Mon–Sun week holding a date.
static func week_monday(date: String) -> String:
	var p := date.split("-")
	var u := bkk_unix(int(p[0]), int(p[1]), int(p[2]), 12)
	var wd: int = local(u)["weekday"]
	return date_key(local(u - ((wd + 6) % 7) * DAY))


static func _week(monday: String) -> Variant:
	if _weeks.has(monday):
		return _weeks[monday]
	var path := DATA_DIR + "lineup-" + monday + ".json"
	var out: Variant = null
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("days")) == TYPE_ARRAY:
			var by := {}
			for d in parsed["days"]:
				if typeof(d) != TYPE_DICTIONARY or typeof(d.get("acts")) != TYPE_ARRAY:
					continue
				var acts: Array = []
				for a in d["acts"]:
					if typeof(a) == TYPE_DICTIONARY and str(a.get("name", "")) != "" and _minutes(str(a.get("start", ""))) >= 0:
						acts.append(a)
				acts.sort_custom(func(x, y): return _minutes(str(x["start"])) < _minutes(str(y["start"])))
				by[str(d.get("date", ""))] = {"title": str(d.get("title", "")), "acts": acts}
			out = by
		else:
			push_error("tonight_events: bad JSON in " + path)
	_weeks[monday] = out
	return out


## The lineup of one evening: {known: the week has a file, title: the poster's day title or "", acts: [...]}.
static func lineup(date: String) -> Dictionary:
	var wk: Variant = _week(week_monday(date))
	if wk == null:
		return {"known": false, "title": "", "acts": []}
	var d: Dictionary = wk.get(date, {"title": "", "acts": []})
	return {"known": true, "title": d["title"], "acts": d["acts"]}


## "21:15" -> minutes after the evening's start-of-day; times before noon are after midnight (01:00 -> 25*60).
static func _minutes(hhmm: String) -> int:
	var p := hhmm.split(":")
	if p.size() != 2 or not p[0].is_valid_int() or not p[1].is_valid_int():
		return -1
	var h := int(p[0])
	if h < 12:
		h += 24
	return h * 60 + int(p[1])


## [start, end) minutes of each act: its end, else the next act's start, else 02:00 (till late, or last of the night).
static func act_slots(acts: Array) -> Array:
	var out: Array = []
	for i in acts.size():
		var a: Dictionary = acts[i]
		var s := _minutes(str(a["start"]))
		var e := _minutes(str(a.get("end", "")))
		if e < 0 or bool(a.get("till_late", false)):
			e = _minutes(str(acts[i + 1]["start"])) if i + 1 < acts.size() and not bool(a.get("till_late", false)) else LATE_MIN
		out.append([s, maxi(e, s)])
	return out


## Index of the act on stage at that moment of that evening, or -1 (between sets, before, after, other evening).
static func now_on_stage(date: String, unix: int) -> int:
	var e := evening(unix)
	if e["date"] != date:
		return -1
	var t := local(unix)
	var m: int = t["hour"] * 60 + t["minute"] + (24 * 60 if t["hour"] < 12 else 0)
	var acts: Array = lineup(date)["acts"]
	var slots := act_slots(acts)
	for i in slots.size():
		if m >= slots[i][0] and m < slots[i][1]:
			return i
	return -1


## Who is on the stage right now, for the HUD's live chip and the stage sheet (Daniele 2026-11-20: "change the live
## song thing to what band is playing now ... based on the time"). Returns
##   {kind: "on" | "next" | "none", act, slot: [start, end] minutes, progress 0..1, date: the act's evening,
##    tonight: bool (the act plays this evening), state: evening state}
## on   = an act's set is running now
## next = between sets, before doors, after the last set, or on a closed night: the next act in the lineup data,
##        searched over the next 7 evenings (Mondays skipped while the bar is closed on Mondays)
## none = no lineup data ahead: the chip then names the next opening only.
static func stage_now(unix := -1) -> Dictionary:
	if unix < 0:
		unix = now_unix()
	var e := evening(unix)
	var t := local(unix)
	var m: int = t["hour"] * 60 + t["minute"] + (24 * 60 if t["hour"] < 12 else 0)
	var out := {"kind": "none", "act": {}, "slot": [0, 0], "progress": 0.0, "date": "", "tonight": false, "state": e["state"],
		"next_open": e["next_open"]}
	if e["state"] != "closed":
		var acts: Array = lineup(e["date"])["acts"]
		var slots := act_slots(acts)
		for i in acts.size():
			var s: Array = slots[i]
			if e["state"] == "open" and m >= s[0] and m < s[1]:
				out.merge({"kind": "on", "act": acts[i], "slot": s, "progress": clampf(float(m - s[0]) / maxf(1.0, s[1] - s[0]), 0.0, 1.0),
					"date": e["date"], "tonight": true, "left": s[1] - m}, true)
				return out
			if e["state"] == "later" or m < s[0]:
				out.merge({"kind": "next", "act": acts[i], "slot": s, "date": e["date"], "tonight": true}, true)
				return out
	var noon := _noon_unix(e["day"])
	for k in range(1, 8):
		var d := local(noon + k * DAY)
		if d["weekday"] == CLOSED_WEEKDAY:
			continue
		var key := date_key(d)
		var acts2: Array = lineup(key)["acts"]
		if not acts2.is_empty():
			out.merge({"kind": "next", "act": acts2[0], "slot": act_slots(acts2)[0], "date": key, "tonight": false}, true)
			return out
	return out


## One line for the HUD chip / stage sheet from stage_now():
##   "On stage: Mut Matthew · R&B Soul Pop" | "Next: Far x Jayson Creer at 23:45" | "Next: Earn · Tue 19:30"
##   | "Doors Tue 19:00" (closed, no lineup ahead) | "Live music from 19:00" (no lineup in yet)
static func stage_line(st: Dictionary) -> String:
	match str(st["kind"]):
		"on":
			var kind := act_kind_text(st["act"])
			return t("tonight.stage.on", {"name": str(st["act"]["name"])}) + (("  ·  " + kind) if kind != "" else "")
		"next":
			if st["tonight"]:
				return t("tonight.stage.next", {"name": str(st["act"]["name"]), "time": str(st["act"]["start"])})
			var p := str(st["date"]).split("-")
			var wd: int = local(bkk_unix(int(p[0]), int(p[1]), int(p[2]), 12))["weekday"]
			return t("tonight.stage.next_day", {"name": str(st["act"]["name"]), "day": t("tonight.day.%d" % wd), "time": str(st["act"]["start"])})
	if st["state"] == "closed":
		return t("tonight.stage.doors", {"day": t("tonight.day.%d" % int(st["next_open"]["weekday"]))})
	return t("tonight.stage.unknown")


## The second line under an on-stage act: "21:15–23:15 · 40 min left" (till late: "until late").
static func stage_sub(st: Dictionary) -> String:
	if str(st["kind"]) != "on":
		return ""
	var tt := act_time_text(st["act"])
	if bool(st["act"].get("till_late", false)):
		return tt
	return t("tonight.stage.left", {"time": tt, "min": maxi(1, int(st.get("left", 1)))})


## The act's photo, or null (no photo on the poster, or the crop is missing).
static func act_photo(a: Dictionary) -> Texture2D:
	var f := str(a.get("photo", ""))
	if f == "" or not ResourceLoader.exists(PHOTO_DIR + f):
		return null
	return load(PHOTO_DIR + f) as Texture2D


## "19:30–21:00", "23:45 – late", or "21:15" when the poster gave a start only.
static func act_time_text(a: Dictionary) -> String:
	var s := str(a["start"])
	if bool(a.get("till_late", false)):
		return t("tonight.act.till_late", {"start": s})
	if str(a.get("end", "")) != "":
		return t("tonight.act.span", {"start": s, "end": str(a["end"])})
	return s


## The line under the act's name: its genre, or its role on a special night ("Opening set").
static func act_kind_text(a: Dictionary) -> String:
	if str(a.get("genre", "")) != "":
		return str(a["genre"])
	if str(a.get("role", "")) != "":
		return t("tonight.role." + str(a["role"]))
	return ""


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
