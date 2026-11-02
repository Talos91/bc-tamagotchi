extends RefCounted
## Top patrons (Daniele 2026-11-02, BACKLOG B7 and B10): the lounge's "Top patrons" board under the stairs and the ten
## portraits on the entrance corridor's south wall show the same ten people, rank 1 first. PLACEHOLDERS until there are
## accounts and check-ins: invented nicknames, invented check-in counts, and a patron preset as each one's look.
## What ranks patrons (check-ins at the real bar is the guess here) is an open question for Daniele.
## Portraits are rendered from the presets by tools/render_portraits.gd into PORTRAIT_DIR (<preset>.png).

const PORTRAIT_DIR := "res://assets/venue/portraits/"
const TOP := [
	{"name": "Beam", "preset": "patron_01", "checkins": 48},
	{"name": "Mint", "preset": "patron_02", "checkins": 41},
	{"name": "Oat", "preset": "patron_03", "checkins": 37},
	{"name": "Fah", "preset": "patron_05", "checkins": 33},
	{"name": "Pond", "preset": "patron_06", "checkins": 29},
	{"name": "Jay", "preset": "patron_07", "checkins": 26},
	{"name": "Ning", "preset": "patron_09", "checkins": 22},
	{"name": "Tum", "preset": "patron_11", "checkins": 19},
	{"name": "Kai", "preset": "patron_12", "checkins": 17},
	{"name": "Ice", "preset": "patron_14", "checkins": 15},
]


static func count() -> int:
	return TOP.size()


## Rank r (0-based) -> its entry, {} out of range.
static func at(r: int) -> Dictionary:
	return TOP[r] if r >= 0 and r < TOP.size() else {}


static func portrait_path(r: int) -> String:
	var p := at(r)
	return PORTRAIT_DIR + str(p["preset"]) + ".png" if not p.is_empty() else ""


static func portrait(r: int) -> Texture2D:
	var path := portrait_path(r)
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)
