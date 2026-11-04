extends SceneTree
## Web-label check. In the web export the raw strings*.csv files are not shipped (only the imported .translation
## resources), so every key must resolve through TranslationServer from project.godot's registered translations ALONE,
## without any runtime CSV loader running. This test does not call any loader's install(); it fails for a key that only
## a runtime loader could resolve (the 2026-11-04 bug: raw "name.something.something" labels in the web build).
## Also walks game/scripts and game/scenes for literal .t("key") / tr("key") calls and checks each key.
##   godot --headless --path . --script res://tests/test_string_keys.gd

const TABLES := ["strings", "strings_venue", "strings_ui", "strings_nightlife", "strings_menu"]
const KEY_RE := r'\b(?:\w+\.)?(?:t|tr)\(\s*"([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)"'


func _init() -> void:
	await process_frame
	var fails := 0
	TranslationServer.set_locale("en")
	# 1. every table's translations are registered in project settings
	var reg: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	for t in TABLES:
		for l in ["en", "th"]:
			var p := "res://i18n/%s.%s.translation" % [t, l]
			if not reg.has(p):
				print("FAIL not registered in project.godot: ", p)
				fails += 1
	# 2. every CSV key resolves from the registered translations alone
	var csv_keys := 0
	for t in TABLES:
		var f := FileAccess.open("res://i18n/%s.csv" % t, FileAccess.READ)
		if f == null:
			print("FAIL cannot open csv ", t)
			fails += 1
			continue
		f.get_csv_line()
		while not f.eof_reached():
			var r := f.get_csv_line()
			if r.size() >= 3 and r[0] != "":
				csv_keys += 1
				if String(TranslationServer.translate(r[0])) == r[0]:
					fails += 1
					if fails < 30:
						print("FAIL csv key does not resolve in %s: %s" % [t, r[0]])
	# 3. every literal key used in code resolves
	var re := RegEx.create_from_string(KEY_RE)
	var used := {}
	for root_dir in ["res://scripts", "res://scenes"]:
		_walk(root_dir, re, used)
	for k in used:
		if String(TranslationServer.translate(k)) == k:
			fails += 1
			print("FAIL key used in code has no translation: %s (%s)" % [k, used[k]])
	print("string keys: %d csv rows, %d literal keys in code, %d failures" % [csv_keys, used.size(), fails])
	print("TEST STRING KEYS ", "PASS" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)


func _walk(dir: String, re: RegEx, used: Dictionary) -> void:
	for d in DirAccess.get_directories_at(dir):
		_walk(dir + "/" + d, re, used)
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		var txt := FileAccess.get_file_as_string(dir + "/" + f)
		for m in re.search_all(txt):
			used[m.get_string(1)] = dir.get_file() + "/" + f
