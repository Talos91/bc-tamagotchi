extends RefCounted
## The player's avatar record (docs/design/07-character-creator.md §4; answers DECISIONS 2026-11-09).
## Lives in save.json under profile.avatar; personality stays in needs.personality, the name in profile.display_name.
##   {"v": 1, "body", "head", "face", "skin", "hair", "hair_colour", "look", "top_colour", "worn": {slot: item},
##    "created_at", "edited_at"}
## Values are ids and swatch names, never hexes. Options offered by the creator come from res://data/avatar.json;
## any part id the kit has is accepted in a record (the legacy look uses parts the creator does not offer), and an
## unknown id falls back per slot to the default, so a removed part never breaks a save.
## `resolve(rec)` turns a record into what PatronFigure needs: the parts library body, the part ids to show and the
## colour per material slot (hex). `check_name(s)` is the local name filter (§5.4); "" means the name is fine.

const DATA_PATH := "res://data/avatar.json"
const MANIFEST := "res://assets/chars/manifest.json"
const V := 1
const LIBRARY := "res://assets/chars/parts/parts_%s.glb"

static var _data: Dictionary = {}
static var _kit: Dictionary = {}      ## manifest part lists by slot, as sets
static var _hex: Dictionary = {}      ## swatch name -> "#RRGGBB"


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		var parts: Dictionary = m["parts"]
		for k in parts:
			_kit[k] = {}
			for id in parts[k]:
				_kit[k][str(id)] = true
		for group in m["swatches"]:
			for sw in m["swatches"][group]:
				_hex[sw] = m["swatches"][group][sw]
	return _data


static func library_path(body: String) -> String:
	return LIBRARY % body


static func hex(swatch: String) -> String:
	data()
	return str(_hex.get(swatch, ""))


## A new character's starting look (the creator opens on it).
static func default_record() -> Dictionary:
	var r: Dictionary = data()["default"].duplicate(true)
	r["v"] = V
	r["worn"] = {}
	return r


## The look of every save made before the creator: exactly the old player figure (preset patron_06, beard included).
static func legacy_record() -> Dictionary:
	var r: Dictionary = data()["legacy"].duplicate(true)
	r["v"] = V
	return r


## A random look from the offered options ("Surprise me", and new games).
static func random_record(rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var d := data()
	var pick := func(a: Array) -> Variant: return a[rng.randi() % a.size()]
	var look: String = pick.call(d["look_order"])
	var r := {
		"v": V, "worn": {},
		"body": pick.call(d["bodies"]), "head": pick.call(d["heads"]), "face": pick.call(d["face_order"]),
		"skin": pick.call(d["skins"]), "hair": pick.call(d["hairs"]), "hair_colour": pick.call(d["hair_colours"]),
		"look": look, "top_colour": pick.call(d["looks"][look]["top_colours"]),
	}
	return r


## Every field present and valid; unknown values fall back to the default's.
static func normalize(rec: Variant) -> Dictionary:
	var d := data()
	var base := default_record()
	if not (rec is Dictionary):
		return base
	var r: Dictionary = (rec as Dictionary).duplicate(true)
	var ok := {
		"body": d["bodies"].has(r.get("body")),
		"head": _kit["heads"].has(str(r.get("head", ""))),
		"face": d["faces"].has(r.get("face")),
		"skin": d["skins"].has(r.get("skin")),
		"hair": _kit["hair"].has(str(r.get("hair", ""))),
		"hair_colour": _hex.has(str(r.get("hair_colour", ""))) and str(r.get("hair_colour", "")).begins_with("Hair"),
		"look": d["looks"].has(r.get("look")),
	}
	for k in ok:
		if not ok[k]:
			r[k] = base[k]
	var look: Dictionary = d["looks"][r["look"]]
	if not _hex.has(str(r.get("top_colour", ""))):
		r["top_colour"] = look["top_colours"][0]
	var worn: Dictionary = r.get("worn", {}) if r.get("worn") is Dictionary else {}
	var clean := {}
	for slot in worn:
		if d["worn_items"].has(worn[slot]):
			clean[slot] = worn[slot]
	r["worn"] = clean
	r["v"] = V
	return r


## {"body", "library", "ids": [part ids to show], "colours": {material slot: "#hex"}} for PatronFigure.
static func resolve(rec: Variant) -> Dictionary:
	var d := data()
	var r := normalize(rec)
	var face: Dictionary = d["faces"][r["face"]]
	var look: Dictionary = d["looks"][r["look"]]
	var ids := ["head_" + r["head"], "hair_" + r["hair"], "eyes_" + face["eyes"], "mouth_" + face["mouth"],
		"top_" + look["top"], "bottom_" + look["bottom"], "shoes_" + look["shoes"], "hands"]
	if str(face.get("brows", "none")) != "none":
		ids.append("brows_" + face["brows"])
	var colours := {"skin": hex(r["skin"]), "hair": hex(r["hair_colour"]), "top": hex(r["top_colour"])}
	for slot in look["colours"]:
		colours[slot] = hex(look["colours"][slot])
	for slot in r["worn"]:
		var item: String = r["worn"][slot]
		ids.append(item)
		var info: Dictionary = d["worn_items"][item]
		if info.has("colour_from"):
			colours[item] = hex(r[info["colour_from"]])
	ids.append_array(d["props"])
	return {"body": r["body"], "library": library_path(r["body"]), "ids": ids, "colours": colours}


# --- Name (§5.4) ---------------------------------------------------------------------------------

## The trimmed name with runs of spaces collapsed to one.
static func clean_name(s: String) -> String:
	var out := s.strip_edges()
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out


## "" when the name is fine, else the reason: "short", "long", "chars", "cast", "blocked".
static func check_name(raw: String) -> String:
	var rules: Dictionary = data()["name"]
	var s := clean_name(raw)
	if s.length() < int(rules["min"]):
		return "short"
	if s.length() > int(rules["max"]):
		return "long"
	var re := RegEx.create_from_string(str(rules["allowed"]))
	if re == null or re.search(s) == null:
		return "chars"
	var low := s.to_lower()
	for c in rules["cast"]:
		if low == str(c) or low.replace(" ", "") == str(c).replace(" ", ""):
			return "cast"
	var folded := _fold(low)
	for w in rules["blocked"]:
		if folded.contains(_fold(str(w))):
			return "blocked"
	return ""


## Lower case, look-alike digits and symbols to letters, spaces and punctuation removed.
static func _fold(s: String) -> String:
	const MAP := {"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s", "!": "i"}
	var out := ""
	for ch in s.to_lower():
		if MAP.has(ch):
			out += MAP[ch]
		elif ch in [" ", ".", "-", "'", "_"]:
			continue
		else:
			out += ch
	return out


# --- Personality -> who greets you first (GDD §7.1, Q11) -----------------------------------------

static func greeter(personality: String) -> String:
	return str(data()["greeters"].get(personality, ""))
