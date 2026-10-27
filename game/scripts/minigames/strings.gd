extends RefCounted
## String table loader. Reads res://i18n/strings.csv (key,en,th,context,max) at runtime and registers one
## Translation per language, so tr() works without importing the CSV or touching project settings.

const CSV_PATH := "res://i18n/strings.csv"
const LANGS := ["en", "th"]

static var _translations: Array = []


static func rows() -> Array:
	var out: Array = []
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		return out
	f.get_csv_line()  # header
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() >= 3 and r[0] != "":
			out.append({"key": r[0], "en": r[1], "th": r[2],
				"context": r[3] if r.size() > 3 else "", "max": int(r[4]) if r.size() > 4 and r[4] != "" else 0})
	return out


static func install(force := false) -> bool:
	if not _translations.is_empty() and not force:
		return true
	for t in _translations:
		TranslationServer.remove_translation(t)
	_translations.clear()
	var by_lang := {}
	for l in LANGS:
		var tr_obj := Translation.new()
		tr_obj.locale = l
		by_lang[l] = tr_obj
	var all := rows()
	for r in all:
		for l in LANGS:
			by_lang[l].add_message(r["key"], r[l])
	for l in LANGS:
		TranslationServer.add_translation(by_lang[l])
		_translations.append(by_lang[l])
	return not all.is_empty()


## Translated string with {named} placeholders filled from `vars`.
static func t(key: String, vars: Dictionary = {}) -> String:
	install()
	var s := String(TranslationServer.translate(key))
	if not vars.is_empty():
		s = s.format(vars)
	return s


## Grapheme-ish length for the length budget: Thai combining marks do not count.
static func cluster_count(s: String) -> int:
	var n := 0
	for i in s.length():
		var c := s.unicode_at(i)
		if c == 0x0E31 or (c >= 0x0E34 and c <= 0x0E3A) or (c >= 0x0E47 and c <= 0x0E4E):
			continue
		n += 1
	return n
