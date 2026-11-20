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
##   hair cover (owner list 2026-11-20, item 2: "hairs often clips the head and looks like bald spots") every offered
##             hair on every head shape and body covers the scalp: rays at the top, the back (above the nape) and the
##             upper sides of the head meet hair before skin, read from the parts libraries' own meshes
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
	_hair_cover()
	await _figure()
	await _outfit()
	await _start_new()
	await _start_old()
	await _booth_and_greeter()
	await _exits()
	await _phone_name()
	await _pc_name()
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
		in_options = in_options and d["bodies"].has(r["body"]) and d["hairs"].has(r["hair"]) and d["tops"].has(r["top"]) and d["top_colours"].has(r["top_colour"]) 			and (r["bottom"] == "dress" or d["bottoms"].has(r["bottom"])) and d["shoes"].has(r["shoes"]) and Avatar.normalize(r) == r
	check(in_options, "Surprise me rolls only offered options")


## Scalp cover, from the meshes (voxel 0.05 m, front +z, top +y). The head is the 8 x 7 x 7 box of bc_chars.py; the
## scalp is its top (every column), its back from the third row up (back(Z + 2) in build_hair) and its sides' three top
## rows behind the temples. A ray from outside at each cell centre must hit a hair mesh before the head mesh, or miss
## the head (a round head's missing corners).
func _hair_cover() -> void:
	print("hair cover (item 2)")
	const V := 0.05
	var d := Avatar.data()
	var bad: Array[String] = []
	var n := 0
	for body in d["bodies"]:
		var lib: Node = (load(Avatar.library_path(body)) as PackedScene).instantiate()
		var tm := {}
		var aabb := {}
		for mi: MeshInstance3D in lib.find_children("*", "MeshInstance3D", true, false):
			var nm := String(mi.name)
			if nm.begins_with("head_") or nm.begins_with("hair_"):
				tm[nm] = mi.mesh.generate_triangle_mesh()
				aabb[nm] = mi.mesh.get_aabb()
		lib.free()
		var head_box: AABB = aabb["head_square"]
		var z0 := head_box.position.y               # bottom row of the head (Z)
		var top := z0 + 7 * V
		var rays: Array = []                        # [from, dir, where]
		for i in 8:
			var x := -0.2 + (i + 0.5) * V
			for j in 7:
				var z := 0.2 - (j + 1.5) * V    # head cells y -3..3 -> z 0.15 .. -0.2 (the nose row in front excluded)
				rays.append([Vector3(x, top + 1.0, z), Vector3.DOWN, "top"])
			for k in range(2, 7):
				rays.append([Vector3(x, z0 + (k + 0.5) * V, -1.0), Vector3.BACK, "back"])
		for k in range(4, 7):
			for j in range(2, 7):
				var z := 0.2 - (j + 1.5) * V
				rays.append([Vector3(-1.0, z0 + (k + 0.5) * V, z), Vector3.RIGHT, "side"])
				rays.append([Vector3(1.0, z0 + (k + 0.5) * V, z), Vector3.LEFT, "side"])
		for head in d["heads"]:
			for hair in d["hairs"]:
				n += 1
				var bare := {}
				for r in rays:
					var hh: Dictionary = (tm["head_" + head] as TriangleMesh).intersect_ray(r[0], r[1])
					if hh.is_empty():
						continue
					var hr: Dictionary = (tm["hair_" + hair] as TriangleMesh).intersect_ray(r[0], r[1])
					if hr.is_empty() or (r[0] as Vector3).distance_to(hr["position"]) > (r[0] as Vector3).distance_to(hh["position"]) - 0.001:
						bare[r[2]] = int(bare.get(r[2], 0)) + 1
				if not bare.is_empty():
					bad.append("%s/%s/%s %s" % [body, head, hair, bare])
	check(n == d["bodies"].size() * d["heads"].size() * d["hairs"].size() and bad.is_empty(), "every offered hair covers the scalp on every head and body (%d combinations; bare: %s)" % [n, ", ".join(bad.slice(0, 12)) if not bad.is_empty() else "none"])


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


## Owner list 2026-11-20 items 1 and 3: the per-piece Outfit tab, and taps that restyle instead of rebuilding.
func _outfit() -> void:
	print("outfit (items 1, 3)")
	var d := Avatar.data()
	# v1 records (a look and a top colour) draw their look's pieces and colours in v2
	for look in d["look_order"]:
		var lk: Dictionary = d["looks"][look]
		var res := Avatar.resolve({"look": look, "top_colour": lk["top_colours"][1]})
		check(res["ids"].has("top_" + lk["top"]) and res["ids"].has("bottom_" + lk["bottom"]) and res["ids"].has("shoes_" + lk["shoes"])
			and res["colours"]["top"] == Avatar.hex(lk["top_colours"][1]), "v1 look %s draws its own pieces and top colour in v2" % look)
	# Surprise me: hats and glasses sometimes, never always
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hats := 0
	var glasses := 0
	for i in 200:
		var r := Avatar.random_record(rng)
		hats += 1 if r["worn"].has("hat") else 0
		glasses += 1 if r["worn"].has("glasses") else 0
	check(hats > 20 and hats < 120 and glasses > 15 and glasses < 120, "Surprise me puts on a hat sometimes (%d/200) and glasses sometimes (%d/200)" % [hats, glasses])
	# a hat swaps the hair for the one cut at the brim
	var rec := Avatar.default_record()
	rec["worn"] = {"hat": "hat_cap"}
	var ids: Array = Avatar.resolve(rec)["ids"]
	check(ids.has("hair_%s_hat" % rec["hair"]) and not ids.has("hair_" + rec["hair"]) and ids.has("hat_cap"), "a hat swaps the hair id (%s)" % [ids])

	# The creator's Outfit tab, one row per piece
	var c: Control = Creator.new()
	root.add_child(c)
	c.open("edit", Avatar.default_record(), "Ty", "night_owl")
	await process_frame
	c._go_tab(2)
	await process_frame
	await process_frame
	var tops: Array = d["tops"].filter(func(t): return c._content.find_child("top_" + t, true, false) != null)
	check(tops.size() == d["tops"].size(), "every top on the Outfit tab (%d of %d)" % [tops.size(), d["tops"].size()])
	for row in ["shoes_boots", "hat_none", "hat_hat_fedora", "glasses_none", "glasses_glasses_round", "bottom_skirt_long", "bottom_colour_Olive"]:
		check(c._content.find_child(row, true, false) != null, "Outfit tab has %s" % row)
	check(c._content.find_child("print_colour_Mint", true, false) == null, "no pattern row for a plain tee")
	var fig_model: Node = c._figure._model
	var swatch: Node = c._content.find_child("top_colour_Coral", true, false)
	c.choose("top_colour", "Coral")
	await process_frame
	check(is_instance_valid(swatch) and not swatch.is_queued_for_deletion() and c._figure._model == fig_model, "a colour tap restyles in place: the tab and the figure are not rebuilt (item 1)")
	check(c.record["top_colour"] == "Coral" and swatch.get_theme_stylebox("normal").border_width_top >= 3, "the tapped swatch shows as chosen")
	c.choose("top", "shirt_aloha")
	await process_frame
	check(c.record["look"] == "smart" and c._content.find_child("print_colour_Mint", true, false) != null, "a printed top adds the pattern row; record.look follows the top")
	c.choose("top", "dress")
	await process_frame
	check(c.record["bottom"] == "dress" and c._content.find_child("bottom_jeans", true, false) == null and c.record["look"] == "dress", "the dress hides the bottom rows")
	c.choose("top", "tee")
	await process_frame
	check(c.record["bottom"] == "skirt" and c._content.find_child("bottom_jeans", true, false) != null, "leaving the dress puts on a skirt")
	c.choose("hat", "hat_beanie")
	await process_frame
	var hair_hat := c._figure.find_child("hair_%s_hat" % c.record["hair"], true, false) as MeshInstance3D
	var beanie := c._figure.find_child("hat_beanie", true, false) as MeshInstance3D
	check(c.record["worn"].get("hat") == "hat_beanie" and beanie != null and beanie.visible and hair_hat != null and hair_hat.visible, "a hat chip puts it on, the hair cut at the brim")
	c.choose("hat", "")
	c.choose("glasses", "glasses_tinted")
	await process_frame
	check(not c.record["worn"].has("hat") and c.record["worn"].get("glasses") == "glasses_tinted" and not beanie.visible, "None takes the hat off; glasses go on")
	var body_model: Node = c._figure._model
	c.choose("body", "tall")
	await process_frame
	check(c._figure._model != body_model and c._figure.look.get("library", "").ends_with("parts_tall.glb"), "a body change loads that body's library")
	c.queue_free()
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
	# The entrance message is the falcon's chat bubble now (Daniele 2026-11-20), never a popup card
	var lines := []
	var cards := []
	main.session.door_greeting.connect(func(line): lines.append(str(line)))
	main.session.action_done.connect(func(card): cards.append(card))
	needs.set_personality("easy_sipper")
	main.session._greet()
	check(main.session.greeted == "nam" and lines.size() == 1 and "Nam" in lines[0] and "Black Cabin" in lines[0], "Easy Sipper: the eagle welcomes, Nam waves first (%s)" % [lines])
	check(cards.is_empty(), "no popup card for the entrance message")
	var bird := main.get_tree().get_first_node_in_group("entrance_greeter") as Node3D
	check(bird != null and bird.global_position.distance_to(Vector3(1.86, 0.95, 7.28)) < 0.05, "the eagle stands on the entrance table, east wall (build_venue EAGLE_AT)")
	main.greet_at_door()
	await process_frame
	var bub: Control = main.eagle_bubble
	check(is_instance_valid(bub) and "Black Cabin" in bub.text_label.text, "greet_at_door shows the eagle's bubble")
	check(is_instance_valid(bub) and bub.mouse_filter == Control.MOUSE_FILTER_IGNORE and main.player.input_enabled, "the bubble never blocks walking")
	if is_instance_valid(bub):
		var cam := main.get_viewport().get_camera_3d()
		var tip := cam.unproject_position(bird.global_position + Vector3(0, 0.9, 0))
		var r := Rect2(bub.panel.position, bub.panel.size)
		var near := r.grow(80.0).has_point(tip) or (absf(r.get_center().x - tip.x) < r.size.x and r.end.y <= tip.y + 2.0)
		check(not bub.panel.visible or near, "the bubble sits over or beside the eagle's head (%s, tip %s)" % [r, tip])
		var pr: Rect2 = main.hud.prompt.pill.get_global_rect()
		check(not main.hud.prompt.pill.is_visible_in_tree() or not pr.intersects(r), "the bubble keeps clear of the prompt pill (%s vs %s)" % [r, pr])
		bub.dismiss()
	needs.set_personality("social_butterfly")
	main.session._greet()
	check(main.session.greeted == "tt", "Social Butterfly: Tt (hosts the Long Table)")
	needs.set_personality("music_nerd")
	lines.clear()
	main.session._greet()
	check(main.session.greeted == "" and lines.size() == 1 and not "waves" in lines[0], "Music Nerd: Tong not in the room yet, the welcome alone")
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


## PC web build (owner item 36): a mouse click on the name field keeps the focus and typing lands at once. The web
## build sends every click twice (ScreenTouch from pointing/emulate_touch_from_mouse, then the mouse button), and
## is_touchscreen_available() is true there, which used to send PCs down the phone prompt path and drop the focus.
func _pc_name() -> void:
	print("pc name (item 36)")
	check(not Creator.finger_pointer(), "off a phone browser there is no finger pointer")
	needs.new_game()
	var main := await _main(true)
	var ss: Node = main.start_screen
	ss.tap()
	await process_frame
	var c := _creator(ss)
	check(c != null and not c.use_prompt, "a PC build types in the field, no prompt")
	var asked := []
	c.prompt_name = func(_cur: String) -> Variant:
		asked.append(1)
		return null
	for i in 3:
		c._next.pressed.emit()
		await process_frame
	await process_frame
	var at: Vector2 = c._name_edit.get_global_rect().get_center()
	for down in [true, false]:
		var t := InputEventScreenTouch.new()
		t.pressed = down
		t.position = at
		root.push_input(t, true)
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.pressed = down
		m.position = at
		m.global_position = at
		root.push_input(m, true)
		await process_frame
	for i in 3:
		await process_frame
	check(c._name_edit.has_focus() and asked.is_empty(), "one click: the field keeps the focus, no prompt")
	for ch in "Mai":
		for down in [true, false]:
			var k := InputEventKey.new()
			k.keycode = OS.find_keycode_from_string(ch)
			k.unicode = ch.unicode_at(0) if down else 0
			k.pressed = down
			root.push_input(k)
		await process_frame
	check(c._name_edit.text == "Mai" and c.display_name == "Mai", "typing lands at once ('%s')" % c._name_edit.text)
	main.queue_free()
	await process_frame
