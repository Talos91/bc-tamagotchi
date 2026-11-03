extends RefCounted
## Cast roles (docs/design/03-cast.md): regular, owner, staff, band, patron. The role of a cast id is the one
## tools/blender/bc_chars.py writes for its preset in the character manifest, so the cast table has one source.
## Only regulars are befriended: hearts, heart story beats and the heart next to their name. Owners (Prae, id mali,
## one of Black Cabin's owners, Daniele 2026-11-02) are in the room, but never carry a friendship track.
## An id with no preset (a test id, a regular not modelled yet) counts as a regular.
##
## Who is in tonight and where (03-cast §2.3, §3.2): `hosts(night)` maps a venue zone id to the cast id there.
##   Tt (regular #4, quiz captain) hosts the lounge's Long Table every night: regulars' own nights (§3.2) are not
##   built yet, so he stands in for them all, as Prae did.
##   Prae is in every other night (Daniele 2026-11-02), at one of her three spots, a different one each time she is in.
## A night runs 19:00-02:00 Bangkok time, so it is counted from 06:00 to 06:00.

const Chars = preload("res://assets/chars/bc_chars.gd")
const S = preload("res://scripts/minigames/strings.gd")

const REGULAR := "regular"
const OWNER := "owner"

const TALK_DIR := "res://scenes/minigames/candle_talk/"
const TT := "tt"
const TT_ZONE := "table:LongTable"
const PRAE := "mali"
## Daniele 2026-11-02: "the first table top-left of the main room, the first centre table from the left, or the
## tall-table room next to the kitchen" (top = north, -z): WestTable0, Table0 of the row of five, a buffer tall table.
const PRAE_ZONES := ["table:WestTable0", "table:Table0", "tall:BufferTall3"]
const BANGKOK_UTC_H := 7
const NIGHT_TURNS_H := 6

## Tests and captures pin the night here (>= 0); -1 = tonight by the clock.
static var night_override := -1

static var _roles: Dictionary = {}
static var _names: Dictionary = {}


static func role(id: String) -> String:
	if _roles.is_empty():
		for p in Chars.manifest().get("presets", []):
			_roles[str(p.get("name", ""))] = str(p.get("role", REGULAR))
			_names[str(p.get("name", ""))] = str(p.get("display", p.get("name", "")))
	return str(_roles.get(id, REGULAR))


## Hearts, heart beats and the heart by the name: regulars only.
static func befriends(id: String) -> bool:
	return role(id) == REGULAR


static func is_owner(id: String) -> bool:
	return role(id) == OWNER


## A Candle Talk set of their own (candle_talk/<id>.json). Prae has none until she gives her lines (§2.1): she is
## silent, so her spot offers no talk.
static func has_lines(id: String) -> bool:
	return FileAccess.file_exists(TALK_DIR + id + ".json")


## What the game calls a cast member: the cast.<id>.name string, else the preset's display name from the manifest
## (a regular with no strings yet), else the id.
static func name_of(id: String) -> String:
	var key := "cast.%s.name" % id
	var s := S.t(key)
	if s != key:
		return s
	role(id)
	return str(_names.get(id, id))


## Tonight's number: days since 1970 in Bangkok, the day turning at 06:00 (after closing).
static func night() -> int:
	if night_override >= 0:
		return night_override
	return night_at(Time.get_unix_time_from_system())


## The night number of a real moment (unix seconds): the same for every save, player and time zone.
static func night_at(unix_time: float) -> int:
	return int(floor((unix_time + (BANGKOK_UTC_H - NIGHT_TURNS_H) * 3600.0) / 86400.0))


## Prae is in on even nights.
static func prae_in(n: int) -> bool:
	return n % 2 == 0


## Prae's zone on night n ("" when she is out): her three spots in turn, one per night she is in.
static func prae_zone(n: int) -> String:
	return PRAE_ZONES[(n / 2) % PRAE_ZONES.size()] if prae_in(n) else ""


## Zone id -> cast id of everyone placed in the room on night n (-1 = tonight).
static func hosts(n := -1) -> Dictionary:
	if n < 0:
		n = night()
	var out := {TT_ZONE: TT}
	var pz := prae_zone(n)
	if pz != "":
		out[pz] = PRAE
	return out
