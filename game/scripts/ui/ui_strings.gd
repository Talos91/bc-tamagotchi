extends RefCounted
## UI string table (res://i18n/strings_ui.csv, same columns as strings.csv: key,en,th,context,max), read at runtime
## like scripts/zones/venue_strings.gd falls back to doing, so no project setting is needed.

const PROBE := "ui.orientation.to_landscape"
const CSV_PATH := "res://i18n/strings_ui.csv"

static var _installed := false


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


## Translated string with {named} placeholders filled from `vars`.
static func t(key: String, vars: Dictionary = {}) -> String:
	install()
	var s := String(TranslationServer.translate(key))
	return s.format(vars) if not vars.is_empty() else s
