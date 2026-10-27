extends RefCounted
## JSON save file in user://. Versioned; unknown keys survive a load/save cycle so later systems
## (multiplayer, memories, wardrobe) can add fields without breaking older builds or this one.
##
## Schema (version 1):
## {
##   "version": 1,
##   "saved_at_unix": float,       # real wall clock at write time
##   "last_seen_unix": float,      # real wall clock; elapsed time since this is decayed on load
##   "profile": { "player_id": "", "display_name": "", ... },   # reserved for accounts / multiplayer
##   "needs":   { owned by needs.gd: meters, clock_unix, personality, tab, daily, visit state, ... },
##   "visits":  [ { start, end, day, number, gains{meter:pts}, actions, welcome }, ... ],
##   "ext":     { "<system>": {...} }                         # namespace for systems added later
## }
## Rule for additions: add a key, never rename or retype one; bump VERSION only when a migration is needed.

const VERSION := 1


static func empty() -> Dictionary:
	return {
		"version": VERSION,
		"saved_at_unix": 0.0,
		"last_seen_unix": 0.0,
		"profile": {"player_id": "", "display_name": ""},
		"needs": {},
		"visits": [],
		"ext": {},
	}


## Writes atomically (tmp file then rename) so a crash mid-write cannot corrupt the save.
static func write(data: Dictionary, path: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Save: cannot open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("Save: rename failed (%s)" % error_string(err))
		return false
	return true


## Returns the migrated save dictionary, or {} if there is no readable save.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save: %s is not valid JSON, ignoring" % path)
		return {}
	return migrate(parsed)


## Brings an older save up to VERSION and fills missing top-level keys. Unknown keys are kept.
static func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 0))
	# if v < 2: ... (migrations go here, one block per version step)
	var out := empty()
	for k in data:
		out[k] = data[k]
	out["version"] = maxi(v, VERSION) if v <= VERSION else v
	return out


static func delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
