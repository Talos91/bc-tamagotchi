extends RefCounted
## The player's avatar record (docs/design/07-character-creator.md §4; answers DECISIONS 2026-11-09).
## Lives in save.json under profile.avatar; personality stays in needs.personality, the name in profile.display_name.
##   {"v": 2, "body", "head", "face", "skin", "hair", "hair_colour", "look", "top", "top_colour", "print_colour",
##    "bottom", "bottom_colour", "shoes", "worn": {slot: item}, "created_at", "edited_at"}
## v2 (owner list 2026-11-20 item 3, wardrobe): top, bottom and shoes are picked apart, with a bottom colour, a pattern
## colour for patterned tops, a hat and glasses (worn). `look` stays in every record: it carries the trims of the
## starter look the pieces came from, and clients from before v2 (live builds, other players' phones) still draw that
## look with top_colour. A v1 record (no `top`) migrates in normalize(): top, bottom, shoes and the bottom colour come
## from its look, so it draws exactly as before.
## Values are ids and swatch names, never hexes. Options offered by the creator come from res://data/avatar.json;
## any part id the kit has is accepted in a record (the legacy look uses parts the creator does not offer), and an
## unknown id falls back per slot to the default, so a removed part never breaks a save.
## `resolve(rec)` turns a record into what PatronFigure needs: the parts library body, the part ids to show and the
## colour per material slot (hex). `check_name(s)` is the local name filter (§5.4); "" means the name is fine.

const DATA_PATH := "res://data/avatar.json"
const MANIFEST := "res://assets/chars/manifest.json"
const V := 2
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
	var top: String = pick.call(d["tops"])
	var r := {
		"v": V, "worn": {},
		"body": pick.call(d["bodies"]), "head": pick.call(d["heads"]), "face": pick.call(d["face_order"]),
		"skin": pick.call(d["skins"]), "hair": pick.call(d["hairs"]), "hair_colour": pick.call(d["hair_colours"]),
		"top": top, "top_colour": pick.call(d["top_colours"]), "print_colour": pick.call(d["print_colours"]),
		"bottom": "dress" if top == "dress" else pick.call(d["bottoms"]), "bottom_colour": pick.call(d["bottom_colours"]),
		"shoes": pick.call(d["shoes"]),
	}
	if rng.randf() < 0.3:
		r["worn"]["hat"] = pick.call(d["hats"])
	if rng.randf() < 0.25:
		r["worn"]["glasses"] = pick.call(d["glasses"])
	r["look"] = look_for(r["top"])
	return r


## The starter look nearest a top: what a client from before v2 draws for this record.
static func look_for(top: String) -> String:
	if top == "dress":
		return "dress"
	if top in ["shirt", "shirt_check", "shirt_aloha", "blazer", "blouse"]:
		return "smart"
	return "easy"


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
	# v1 -> v2: the pieces of its look (a record with no top is v1, or from a client before v2)
	if not r.has("top"):
		r["top"] = look["top"]
		r["bottom"] = look["bottom"]
		r["shoes"] = look["shoes"]
		r["bottom_colour"] = r["top_colour"] if look.get("bottom_follows_top", false) else str(look["colours"].get("bottom", "Denim"))
	if not _kit["tops"].has(str(r.get("top", ""))):
		r["top"] = look["top"]
	if not _kit["bottoms"].has(str(r.get("bottom", ""))):
		r["bottom"] = look["bottom"]
	if not _kit["shoes"].has(str(r.get("shoes", ""))):
		r["shoes"] = look["shoes"]
	if r["top"] == "dress":
		r["bottom"] = "dress"
	elif r["bottom"] == "dress":
		r["bottom"] = "skirt"
	for k in ["bottom_colour", "print_colour"]:
		if not _hex.has(str(r.get(k, ""))):
			r[k] = base[k]
	var worn: Dictionary = r.get("worn", {}) if r.get("worn") is Dictionary else {}
	var clean := {}
	for slot in worn:
		if d["worn_items"].has(worn[slot]) and str(d["worn_items"][worn[slot]]["slot"]) == slot:
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
	var hat_on: bool = r["worn"].has("hat")           # the hair cut at the brim (bc_chars.py hair_under_hat)
	var ids := ["head_" + r["head"], "hair_" + r["hair"] + ("_hat" if hat_on else ""), "eyes_" + face["eyes"],
		"mouth_" + face["mouth"], "top_" + r["top"], "bottom_" + r["bottom"], "shoes_" + r["shoes"], "hands"]
	if str(face.get("brows", "none")) != "none":
		ids.append("brows_" + face["brows"])
	var colours := {"skin": hex(r["skin"]), "hair": hex(r["hair_colour"]), "top": hex(r["top_colour"]),
		"top_print": hex(r["print_colour"])}
	for slot in look["colours"]:                       # the look's trims ...
		colours[slot] = hex(look["colours"][slot])
	if r["top"] != look["top"]:                         # ... or the piece's own when worn outside its look
		for slot in d["top_info"].get(r["top"], {}):
			colours[slot] = hex(d["top_info"][r["top"]][slot])
	if r["shoes"] != look["shoes"]:
		for slot in d["shoe_info"].get(r["shoes"], {}):
			colours[slot] = hex(d["shoe_info"][r["shoes"]][slot])
	colours["bottom"] = colours["top"] if r["top"] == "dress" else hex(r["bottom_colour"])   # the dress: one colour to the hem
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
