extends SceneTree
## Headless test of the character creator (docs/design/07-character-creator.md; DECISIONS 2026-11-09):
##   data      every option the creator offers resolves to part ids that exist in all four parts libraries, and to
##             swatches the manifest has; unknown values fall back to the default; Surprise me stays in the options
##   legacy    a save from before the creator draws exactly the old player figure (preset patron_06: parts, beard,
##             colours)
##   save      the record round-trips through Needs.to_dict / from_dict; set_avatar writes the name and calls
##             set_personality (the 10 % decay hook in rules.gd); new characters vs saves from before the creator
##   names     2-16 characters, Latin and Thai, cast names refused, the local word filter (with look-alikes)
##   figure    PatronFigure's avatar form keeps only the record's meshes and recolours skin, hair and top
##   start     a new character's first tap opens the creator, "Into the bar" walks in; a save from before the creator
##             gets the one-time card (Keep this look keeps the legacy look; no name -> the You tab); Edit look
##   booth     the photo booth zone in the lounge (layout.json) opens the creator; Done changes the player's look
##   greeter   the personality's regular greets on arrival when in the room (Nam, Tt); none when not placed (Tong)
##   exits     (owner item 26, 2026-11-09, phone) real touches (Input.parse_input_event, touch -> mouse emulation as on
##             the phone) reach Next, × and Done; × leaves from every step, from the start screen and the booth;
##             Done with a refused or empty name stays and says why above the button, the name field first on screen;
##             Done with a good name leaves
##   item 27   at least three of the eight hairs read as long or tied-up hair from the front; one look is a dress
##   godot --headless --path . --script res://tests/test_avatar.gd

const Avatar = preload("res://scripts/avatar.gd")
const Creator = preload("res://scripts/ui/character_creator.gd")

var needs: Node
var fails: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _init() -> void:
	await process_frame
	needs = root.get_node_or_null("Needs")
	needs.autosave = false
	root.size = Vector2i(1080, 1920)
	_data()
	_legacy()
	_save()
	_names()
	await _figure()
	await _start_new()
	await _start_old()
	await _booth_and_greeter()
	await _exits()
	await _phone_name()
	print("TEST AVATAR ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


func _manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/chars/manifest.json"))


func _data() -> void:
	print("data")
	var m := _manifest()
	var d := Avatar.data()
	check(d["bodies"] == ["petite", "regular", "broad", "tall"], "four bodies (Q1)")
	check(d["skins"].size() == 8 and d["hairs"].size() == 8 and d["hair_colours"].size() == 8, "8 skins, 8 hairs x 8 colours (Q2, Q3)")
	check(d["heads"].size() == 4 and d["face_order"].size() == 3, "4 head shapes + 3 face sets (Q4)")
	check(d["look_order"].size() == 3, "3 looks (Q5)")
	var fem := ["long_straight", "pigtails", "double_bun", "ponytail", "chignon"]
	var n_fem := 0
	for h in d["hairs"]:
		n_fem += 1 if fem.has(h) else 0
	check(n_fem >= 3 and d["hairs"].has("long_straight"), "item 27: %d of 8 hairs read long / tied up from the front" % n_fem)
	var skirts := 0
	for l in d["look_order"]:
		skirts += 1 if (d["looks"][l]["bottom"] in ["skirt", "dress"]) else 0
	check(skirts >= 1, "item 27: a starter look with a dress or skirt")
	var old_night: Dictionary = Avatar.resolve({"look": "night_out", "top_colour": "LeatherBlack"})
	check(old_night["ids"].has("top_leather") and not d["look_order"].has("night_out"), "night_out (leather) hidden but kept for saves that chose it")
	var dr: Dictionary = Avatar.resolve({"look": "dress", "top_colour": "Teal"})
	check(dr["colours"]["bottom"] == dr["colours"]["top"], "the dress takes the top colour to the hem")
	var six := true
	for l in d["look_order"]:
		six = six and d["looks"][l]["top_colours"].size() == 6
	check(six, "6 top colours per look (Q5)")
	var missing := []
	for body in d["bodies"]:
		var lib := {}
		for part in m["libraries"][body]["parts"]:
			lib[part["id"]] = true
		check(ResourceLoader.exists(Avatar.library_path(body)), "library %s exists" % body)
		for head in d["heads"]:
			for face in d["face_order"]:
				for hair in d["hairs"]:
					for look in d["look_order"]:
						var rec := {"body": body, "head": head, "face": face, "hair": hair, "look": look,
							"skin": "Skin1", "hair_colour": "HairBlack", "top_colour": d["looks"][look]["top_colours"][0]}
						for id in Avatar.resolve(rec)["ids"]:
							if not lib.has(id) and not missing.has(body + ":" + id):
								missing.append(body + ":" + id)
	check(missing.is_empty(), "every offered combination resolves to parts in every library %s" % [missing])
	var bad_sw := []
	var lists: Array = d["skins"] + d["hair_colours"]
	for l in d["looks"]:
		lists += d["looks"][l]["top_colours"]
		lists += d["looks"][l]["colours"].values()
	for sw in lists:
		if Avatar.hex(sw) == "":
			bad_sw.append(sw)
	check(bad_sw.is_empty(), "every swatch is in the manifest %s" % [bad_sw])
	var n := Avatar.normalize({"body": "giant", "hair": "nope", "look": "toga", "skin": "Blue", "worn": {"hat": "crown"}})
	var dflt := Avatar.default_record()
	check(n["body"] == dflt["body"] and n["hair"] == dflt["hair"] and n["look"] == dflt["look"] and n["skin"] == dflt["skin"] and n["worn"].is_empty(), "unknown values fall back to the default")
	check(Avatar.normalize("garbage") == dflt, "a non-dictionary record is the default")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var in_options := true
	for i in 40:
		var r := Avatar.random_record(rng)
		in_options = in_options and d["bodies"].has(r["body"]) and d["hairs"].has(r["hair"]) and d["looks"][r["look"]]["top_colours"].has(r["top_colour"])
	check(in_options, "Surprise me rolls only offered options")


func _legacy() -> void:
	print("legacy")
	var pre: Dictionary = {}
	for p in _manifest()["presets"]:
		if p["name"] == "patron_06":
			pre = p
	var res := Avatar.resolve(Avatar.legacy_record())
	var want := ["head_" + pre["parts"]["head"], "hair_" + pre["parts"]["hair"], "eyes_" + pre["parts"]["eyes"],
		"brows_" + pre["parts"]["brows"], "mouth_" + pre["parts"]["mouth"], "top_" + pre["parts"]["top"],
		"bottom_" + pre["parts"]["bottom"], "shoes_" + pre["parts"]["shoes"], "beard"]
	var all_in := true
	for id in want:
		all_in = all_in and res["ids"].has(id)
	check(res["body"] == pre["body"] and all_in, "legacy look = patron_06 parts (%s) %s" % [pre["body"], res["ids"]])
	var same := true
	for slot in ["skin", "hair", "top", "bottom", "shoes", "shoes_trim", "beard"]:
		var want_hex: String = pre["colours"][slot]["hex"]
		if str(res["colours"].get(slot, "")).to_upper() != want_hex.to_upper():
			same = false
			print("    ", slot, " ", res["colours"].get(slot, ""), " vs ", want_hex)
	check(same, "legacy colours = patron_06 colours")


func _save() -> void:
	print("save")
	needs.new_game()
	check(not needs.has_avatar() and needs.is_new_character(), "a new game is a new character")
	check(needs.avatar() == Avatar.legacy_record(), "no record: the legacy look")
	var rec := Avatar.default_record()
	rec["body"] = "tall"
	rec["hair"] = "bun"
	needs.set_avatar(rec, "  Mai   Lee ", "easy_sipper")
	check(needs.has_avatar() and needs.avatar()["body"] == "tall" and needs.avatar()["hair"] == "bun", "set_avatar stores the record")
	check(needs.profile["display_name"] == "Mai Lee", "name trimmed, spaces collapsed: '%s'" % needs.profile["display_name"])
	check(needs.personality == "easy_sipper", "set_avatar calls set_personality")
	check(needs.avatar().get("created_at", 0.0) > 0.0 and needs.avatar().get("edited_at", 0.0) > 0.0, "created_at / edited_at stamped")
	var d: Dictionary = JSON.parse_string(JSON.stringify(needs.to_dict()))
	check(d["profile"]["avatar"]["body"] == "tall" and int(d["profile"]["avatar"]["v"]) == Avatar.V, "record in save.json profile.avatar")
	check(int(d["version"]) == 1, "save VERSION unchanged (additive key)")
	needs.new_game()
	needs.from_dict(d)
	check(needs.avatar()["hair"] == "bun" and needs.profile["display_name"] == "Mai Lee" and needs.personality == "easy_sipper", "round trip through from_dict")
	# A save from before the creator: nights out, no avatar
	needs.new_game()
	needs.nights_out = 3
	check(not needs.is_new_character() and not needs.has_avatar(), "an old save is not a new character")
	needs.new_game()


func _names() -> void:
	print("names")
	var cases := {"Mai": "", "ต้น": "", "Jo-Anne O'Neil": "", "A": "short", "  B  ": "short",
		"Abcdefghijklmnopq": "long", "Mai😀": "chars", "x<y": "chars", "Nam": "cast", "nam": "cast", "Lung Nop": "cast",
		"LungNop": "cast", "Prae": "cast", "พลอย": "cast", "fuckboy": "blocked", "F u c k": "blocked", "sh1t": "blocked",
		"เหี้ยมาก": "blocked", "Namwan": "", "Tong Lor": ""}
	for n in cases:
		var got := Avatar.check_name(n)
		check(got == cases[n], "name '%s' -> '%s' (want '%s')" % [n, got, cases[n]])


func _figure() -> void:
	print("figure")
	var f: Node3D = load("res://scenes/venue/patron_figure.tscn").instantiate()
	root.add_child(f)
	var rec := Avatar.default_record()
	rec["skin"] = "Skin7"
	rec["top_colour"] = "Teal"
	f.set_look({"avatar": rec})
	await process_frame
	var res := Avatar.resolve(rec)
	var names := []
	for mi in f.find_children("*", "MeshInstance3D", true, false):
		names.append(String(mi.name))
	names.sort()
	var want: Array = res["ids"].duplicate()
	want.sort()
	check(names == want, "only the record's meshes stay: %s" % [names])
	check(f.is_preset(), "rigged and animated (AnimationPlayer found)")
	var skin_ok := false
	var top_ok := false
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as StandardMaterial3D
			if m == null:
				continue
			if m.resource_name == "skin__custom" and m.albedo_color.r < 0.6:
				skin_ok = true
			if m.resource_name == "top__custom" and m.albedo_color.g > m.albedo_color.r:
				top_ok = true
	check(skin_ok and top_ok, "skin (Skin7) and top (Teal) recoloured")
	f.queue_free()
	await process_frame


func _main(intro: bool) -> Node:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.intro = intro
	root.add_child(m)
	for i in 4:
		await process_frame
	return m


func _creator(ss: Node) -> Control:
	if not is_instance_valid(ss) or not is_instance_valid(ss._modal):
		return null
	for c in ss._modal.get_children():
		if c is Creator:
			return c
	return null


func _start_new() -> void:
	print("start: new character")
	needs.new_game()
	var main := await _main(true)
	var ss: Node = main.start_screen
	check(ss != null and not ss._edit_btn.visible, "start screen up, no Edit look for a new character")
	ss.tap()
	await process_frame
	var c := _creator(ss)
	check(c != null and c.mode == "new" and ss.phase == ss.Phase.TITLE, "first tap opens the creator, the walk waits")
	check(c != null and c.personality == "night_owl", "a vibe is preselected")
	# Taps on the creator must not reach the street
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = Vector2(540, 1500)
	ss._input(ev)
	check(ss.phase == ss.Phase.TITLE, "a tap on the creator does not walk in")
	# Through the tabs with the Next button
	var tabs_seen := []
	for i in 3:
		tabs_seen.append(c.tab)
		c._next.pressed.emit()
		await process_frame
	check(tabs_seen == [0, 1, 2] and c.tab == 3, "Next walks Body -> Hair -> Outfit -> You")
	c.choose("body", "tall")
	c.choose("hair", "pigtails")
	c.choose("name", "Nam")
	c._next.pressed.emit()
	await process_frame
	check(is_instance_valid(c) and c._name_err != null and c._name_err.text != "", "a cast name is refused on the You tab: '%s'" % (c._name_err.text if c and c._name_err else ""))
	c.choose("name", "Mai")
	c.choose("personality", "music_nerd")
	c._next.pressed.emit()
	await process_frame
	await process_frame
	check(needs.has_avatar() and needs.avatar()["body"] == "tall" and needs.profile["display_name"] == "Mai" and needs.personality == "music_nerd", "Into the bar saves look, name, personality")
	check(not is_instance_valid(ss._modal) and ss.phase != ss.Phase.TITLE, "creator closed, the walk-in started")
	var fig: Node = main.player.figure
	check(main.player.look.get("avatar", {}).get("body", "") == "tall" and fig.find_child("hair_pigtails", true, false) != null, "the player wears the new look")
	main.queue_free()
	await process_frame


func _start_old() -> void:
	print("start: save from before the creator")
	needs.new_game()
	needs.nights_out = 4
	needs.profile["display_name"] = ""
	var main := await _main(true)
	var ss: Node = main.start_screen
	check(is_instance_valid(ss._modal) and ss._modal.find_child("OfferCard", true, false) != null, "one-time card shown")
	var fig: Node = main.player.figure
	check(fig.find_child("beard", true, false) != null and fig.find_child("hair_shaggy", true, false) != null, "old save keeps the old look (patron_06, beard)")
	ss._modal.find_child("Keep", true, false).pressed.emit()
	await process_frame
	var c := _creator(ss)
	check(c != null and c.tab == 3, "Keep this look with no name opens the You tab")
	c.choose("name", "Somchai")
	c._next.pressed.emit()
	await process_frame
	check(needs.has_avatar() and needs.avatar()["look"] == "legacy" and needs.profile["display_name"] == "Somchai", "kept look saved as the legacy record with the name")
	check(not is_instance_valid(ss._modal) and ss._edit_btn.visible, "card gone, Edit look shown")
	ss._edit_btn.pressed.emit()
	await process_frame
	c = _creator(ss)
	check(c != null and c.mode == "edit" and c.reached == 3, "Edit look opens every tab")
	c._on_back()
	await process_frame
	check(not is_instance_valid(ss._modal) and ss.phase == ss.Phase.TITLE, "× closes it, still on the street")
	main.queue_free()
	await process_frame
	# The card shows once: a second start with the record saved has no card
	var main2 := await _main(true)
	check(not is_instance_valid(main2.start_screen._modal), "no card once the look is saved")
	main2.queue_free()
	await process_frame


func _booth_and_greeter() -> void:
	print("booth")
	needs.new_game()
	needs.set_avatar(Avatar.default_record(), "Mai", "easy_sipper")
	var main := await _main(false)
	for i in 10:
		await physics_frame
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	var booth: Dictionary = main.zones.by_id("booth")
	check(not booth.is_empty() and booth["kind"] == "booth", "photo booth zone from layout.json")
	var venue: Node = main.get_node("Venue")
	var pb: Node3D = venue.find_child("PhotoBooth", true, false)
	check(pb != null and pb.find_child("Collider", true, false) != null, "photo booth in the venue, solid")
	if not booth.is_empty():
		var a: Vector3 = booth["approach"]
		var nav_map: RID = main.player.get_world_3d().navigation_map
		var near := NavigationServer3D.map_get_closest_point(nav_map, a)
		check(Vector2(near.x, near.z).distance_to(Vector2(a.x, a.z)) < 0.3, "booth front is on the navmesh (%.2f m)" % Vector2(near.x, near.z).distance_to(Vector2(a.x, a.z)))
		check(main.player.rig.area_at(a) == "lounge", "booth front is in the lounge area")
		main.open_sheet(booth)
		await process_frame
		var c: Control = main.creator
		check(is_instance_valid(c) and c.mode == "edit" and not is_instance_valid(main.sheet), "booth opens the creator, not a sheet")
		check(not main.hud.visible and not main.player.input_enabled, "HUD hidden, no walking while it is up")
		c.choose("look", "smart")
		c.choose("top_colour", "Sky")
		c._next.pressed.emit()
		await process_frame
		await process_frame
		check(not is_instance_valid(main.creator) and needs.avatar()["look"] == "smart", "Done saves the new look")
		check(main.player.figure.find_child("top_shirt", true, false) != null, "the player now wears the shirt")
	print("greeter")
	var lines := []
	main.session.action_done.connect(func(card): lines.append(str(card.get("line", ""))))
	needs.set_personality("easy_sipper")
	main.session._greet()
	check(main.session.greeted == "nam" and lines.size() == 1 and "Nam" in lines[0], "Easy Sipper: Nam waves first (%s)" % [lines])
	needs.set_personality("social_butterfly")
	main.session._greet()
	check(main.session.greeted == "tt", "Social Butterfly: Tt (hosts the Long Table)")
	needs.set_personality("music_nerd")
	lines.clear()
	main.session._greet()
	check(main.session.greeted == "" and lines.is_empty(), "Music Nerd: Tong not in the room yet, no line")
	needs.set_personality("")
	main.session._greet()
	check(main.session.greeted == "", "no personality, no greeter")
	main.queue_free()
	await process_frame


## A finger tap on a control, the phone's way: ScreenTouch through Input, which emulates the mouse
## (project.godot pointing/emulate_mouse_from_touch) before the GUI sees it.
func _touch(ctrl: Control) -> void:
	var at := ctrl.get_global_rect().get_center()
	for down in [true, false]:
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.pressed = down
		t.position = at
		Input.parse_input_event(t)
		Input.flush_buffered_events()
		await process_frame
	await process_frame


func _exits() -> void:
	print("exits (item 26)")
	# New character, real touches: Next x3, Into the bar with no name
	needs.new_game()
	var main := await _main(true)
	var ss: Node = main.start_screen
	ss.tap()
	await process_frame
	var c := _creator(ss)
	for i in 3:
		await _touch(c._next)
	check(c.tab == 3, "touch: Next reaches the You tab (tab %d)" % c.tab)
	var first_input: Node = null
	for n in c._content.get_children():
		if n is LineEdit or n is GridContainer:
			first_input = n
			break
	check(first_input is LineEdit, "the name field comes first on the You tab (it is what Done can refuse)")
	c.choose("name", "")
	await _touch(c._next)
	check(is_instance_valid(ss._modal) and c.tab == 3, "Into the bar with no name stays on the You tab")
	check(c._status.visible and c._status.text != "" and c._next.get_global_rect().position.y > c._status.get_global_rect().position.y, "... and says why right above the button: '%s'" % c._status.text)
	c.choose("name", "Nam")
	await _touch(c._next)
	check(c._status.visible and c._status.text != "" and is_instance_valid(ss._modal), "a cast name: stays, reason shown")
	# × leaves from the last step, no save
	var close: Button = c.find_child("Close", true, false)
	await _touch(close)
	check(not is_instance_valid(ss._modal) and ss.phase == ss.Phase.TITLE and not needs.has_avatar(), "touch: × leaves the creator from step 4, nothing saved")
	# ‹ steps back; × from step 2
	ss.tap()
	await process_frame
	c = _creator(ss)
	await _touch(c._next)
	await _touch(c._back)
	check(is_instance_valid(c) and c.tab == 0, "touch: ‹ goes back a step")
	check(c._back.disabled, "no ‹ on the first step (× is the way out)")
	await _touch(c.find_child("Close", true, false))
	check(not is_instance_valid(ss._modal), "touch: × leaves from step 1")
	# Done with a good name leaves and walks in
	ss.tap()
	await process_frame
	c = _creator(ss)
	for i in 3:
		await _touch(c._next)
	c.choose("name", "Mai")
	await _touch(c._next)
	await process_frame
	check(not is_instance_valid(ss._modal) and needs.has_avatar() and needs.profile["display_name"] == "Mai", "touch: Into the bar with a good name leaves and saves")
	main.queue_free()
	await process_frame
	# Edit look (start screen): Done with the saved name leaves at once; × leaves
	main = await _main(true)
	ss = main.start_screen
	ss._edit_btn.pressed.emit()
	await process_frame
	c = _creator(ss)
	c.choose("hair", "double_bun")
	await _touch(c._next)
	await process_frame
	check(not is_instance_valid(ss._modal) and needs.avatar()["hair"] == "double_bun", "touch: Edit look, Done with the saved name leaves and saves")
	ss._edit_btn.pressed.emit()
	await process_frame
	c = _creator(ss)
	await _touch(c.find_child("Close", true, false))
	check(not is_instance_valid(ss._modal) and ss.phase == ss.Phase.TITLE, "touch: Edit look, × leaves")
	main.queue_free()
	await process_frame
	# Booth: Done with an empty saved name says why, then leaves once named; × leaves
	needs.new_game()
	needs.set_avatar(Avatar.default_record(), "Mai", "easy_sipper")
	needs.profile["display_name"] = ""
	main = await _main(false)
	for i in 10:
		await physics_frame
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	main.open_creator()
	await process_frame
	c = main.creator
	await _touch(c._next)
	check(is_instance_valid(main.creator) and c.tab == 3 and c._status.visible, "booth: Done with no name opens the You tab and says why")
	c.choose("name", "Ploy Two")
	await _touch(c._next)
	await process_frame
	check(not is_instance_valid(main.creator) and needs.profile["display_name"] == "Ploy Two", "booth: named, Done leaves")
	main.open_creator()
	await process_frame
	await _touch(main.creator.find_child("Close", true, false))
	await process_frame
	check(not is_instance_valid(main.creator) and main.player.input_enabled, "booth: × leaves, walking again")
	main.queue_free()
	await process_frame


## Phone web build (owner item 26): no on-screen keyboard bridge in the export, so a tap on the name field opens the
## browser's prompt; the typed name fills the field and Into the bar leaves.
func _phone_name() -> void:
	print("phone name (item 26)")
	needs.new_game()
	var main := await _main(true)
	var ss: Node = main.start_screen
	ss.tap()
	await process_frame
	var c := _creator(ss)
	c.use_prompt = true
	var asked := []
	c.prompt_name = func(cur: String) -> Variant:
		asked.append(cur)
		return "  Mai  "
	for i in 3:
		await _touch(c._next)
	await _touch(c._name_edit)
	check(asked.size() == 1 and c._name_edit.text == "Mai" and not c._name_edit.has_focus(), "touch on the name field: the prompt asks once, the name fills the field (%s)" % [asked])
	await _touch(c._next)
	await process_frame
	check(not is_instance_valid(ss._modal) and needs.profile.get("display_name", "") == "Mai", "... and Into the bar leaves with it")
	c = null
	main.queue_free()
	await process_frame
	# Cancelled prompt: the field stays empty, Into the bar says why
	needs.new_game()
	main = await _main(true)
	ss = main.start_screen
	ss.tap()
	await process_frame
	c = _creator(ss)
	c.use_prompt = true
	c.prompt_name = func(_cur: String) -> Variant: return null
	for i in 3:
		await _touch(c._next)
	await _touch(c._name_edit)
	await _touch(c._next)
	check(is_instance_valid(ss._modal) and c._status.visible, "prompt cancelled: stays, says why")
	main.queue_free()
	await process_frame
