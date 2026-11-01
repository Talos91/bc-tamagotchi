extends SceneTree
## Headless smoke test of the build version label (scripts/version_info.gd, docs/tech/versioning.md): the version in
## project.godot is MAJOR.MINOR.PATCH; the string is "v<version>" plus " · <sha>" and " · dirty" when a build stamp
## (game/build_info.json, tools/version.py) is present; the label is on the start screen (visible, bottom right) and
## on the HUD in play, in portrait and landscape, and shows the ProjectSettings version.
##   godot --headless --path . --script res://tests/smoke_version.gd

const VersionInfo = preload("res://scripts/version_info.gd")

var fails: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _init() -> void:
	await process_frame
	var needs: Node = root.get_node_or_null("Needs")
	needs.autosave = false
	needs.new_game()
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))

	print("string")
	var re := RegEx.create_from_string(r"^\d+\.\d+\.\d+$")
	check(re.search(ver) != null, "project.godot version '%s' is MAJOR.MINOR.PATCH" % ver)
	check(VersionInfo.version() == ver, "helper reads ProjectSettings")
	check(VersionInfo.compose("0.2.0", {}) == "v0.2.0", "no stamp: version only")
	check(VersionInfo.compose("0.2.0", {"sha": "33dc5b9", "dirty": false}) == "v0.2.0 · 33dc5b9", "stamp: version · sha")
	check(VersionInfo.compose("0.2.0", {"sha": "33dc5b9", "dirty": true}) == "v0.2.0 · 33dc5b9 · dirty", "dirty stamp: version · sha · dirty")
	var stamp := VersionInfo.build()
	check(VersionInfo.text().begins_with("v" + ver), "text() starts with v<version> (stamp: %s)" % ("yes" if not stamp.is_empty() else "none"))
	if not stamp.is_empty():
		check(VersionInfo.text().contains(str(stamp.get("sha", "?"))), "text() carries the stamped sha")

	print("start screen")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.intro = true
	root.add_child(main)
	for i in 5:
		await process_frame
	var ss: Node = main.start_screen
	check(is_instance_valid(ss), "start screen running")
	for size in [Vector2i(1080, 1920), Vector2i(1920, 1080)]:
		root.size = size
		for i in 3:
			await process_frame
		var tag := "start %dx%d" % [size.x, size.y]
		_label_ok(ss._screen.get_node_or_null("VersionLabel"), tag)
	root.size = Vector2i(1080, 1920)

	print("in play")
	ss.skip()
	for i in 10:
		await process_frame
	var hud: Control = main.hud
	check(hud.visible, "HUD visible after the start screen")
	for size in [Vector2i(1080, 1920), Vector2i(1920, 1080)]:
		root.size = size
		for i in 3:
			await process_frame
		_label_ok(hud.get_node_or_null("VersionLabel"), "hud %dx%d" % [size.x, size.y])

	print("SMOKE VERSION ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


func _label_ok(l: Label, tag: String) -> void:
	check(l != null, tag + ": VersionLabel exists")
	if l == null:
		return
	check(l.is_visible_in_tree(), tag + ": visible")
	check(l.text == VersionInfo.text() and l.text.begins_with("v" + str(ProjectSettings.get_setting("application/config/version"))), tag + ": shows '" + l.text + "'")
	var vp := root.get_visible_rect()
	var r := l.get_global_rect()
	check(vp.encloses(r) and r.get_center().x > vp.size.x * 0.6 and r.get_center().y > vp.size.y * 0.9, tag + ": inside the viewport, bottom right (%s of %s)" % [r, vp.size])
