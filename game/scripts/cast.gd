extends RefCounted
## Cast roles (docs/design/03-cast.md): regular, owner, staff, band, patron. The role of a cast id is the one
## tools/blender/bc_chars.py writes for its preset in the character manifest, so the cast table has one source.
## Only regulars are befriended: hearts, heart story beats and the heart next to their name. Owners (Prae, id mali,
## one of Black Cabin's owners, Daniele 2026-11-02) host a table and chat, but never carry a friendship track.
## An id with no preset (a test id, a regular not modelled yet) counts as a regular.

const Chars = preload("res://assets/chars/bc_chars.gd")
const S = preload("res://scripts/minigames/strings.gd")

const REGULAR := "regular"
const OWNER := "owner"

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


## What the game calls a cast member: the cast.<id>.name string, else the preset's display name from the manifest
## (a regular with no strings yet), else the id.
static func name_of(id: String) -> String:
	var key := "cast.%s.name" % id
	var s := S.t(key)
	if s != key:
		return s
	role(id)
	return str(_names.get(id, id))
