extends SceneTree
## Headless test of consistent players and the merch shop (Daniele 2026-11-20; docs/design/14-merch-shop.md):
##   catalogue  ten pieces in each of the four categories; every piece builds voxels for all four bodies with only
##              its own palette; the server seed lists every id
##   version    a character survives a version bump: a save written by 0.4.0 (save v1, avatar record v1, no merch)
##              and a save from a newer build load with the look, name and personality intact and no creator prompt;
##              the avatar's merch and the owned pieces round-trip through the save file on disk
##   server     (presence mock + merch server mock) sync saves the character and assigns a player code; a free pick is
##              owned at once and lands in the server inventory as free_pick; nothing is sent when nothing changed
##   booth      a picked piece is in the photo booth wardrobe (merch_shop "wardrobe" lists it, unowned ones are not),
##              Wear puts it on the avatar record and the figure draws it on the bone (a mask hides the head)
##   lost save  a wiped save on the same account gets its character and pieces back from the server
##   session    a new anonymous account under a save that knows its code takes the character back by itself
##   restore    another phone types the code: character and pieces move there; wrong codes and the rate limit
##   offline    a pick while offline is kept and claimed when back online; a server without the migration stays local
##   reset      the player's own reset deletes the character (not brought back), keeps the pieces and the code
##   godot --headless --path . --script res://tests/test_merch_profile.gd

const Merch = preload("res://scripts/merch/merch.gd")
const PresenceMock = preload("res://scripts/presence/presence_mock.gd")
const ServerMock = preload("res://scripts/merch/merch_server_mock.gd")
const MerchShop = preload("res://scripts/merch/merch_shop.gd")
const Avatar = preload("res://scripts/avatar.gd")
const Save = preload("res://scripts/save.gd")
const FigureScene = preload("res://scenes/venue/patron_figure.tscn")

var needs: Node
var presence: Node
var prof: Node
var mock: RefCounted
var server: RefCounted
var fails: Array[String] = []
var checks := 0


func check(ok: bool, what: String) -> void:
	checks += 1
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _init() -> void:
	await process_frame
	needs = root.get_node("Needs")
	presence = root.get_node("Presence")
	prof = root.get_node("PlayerProfile")
	needs.autosave = false
	needs.save_path = "user://test_merch_save.json"
	root.size = Vector2i(1080, 1920)
	_catalogue()
	_version()
	await _server()
	await _booth()
	await _booth_in_game()
	await _lost_save()
	await _session()
	await _restore()
	await _offline()
	await _reset()
	print("merch_profile: %d checks, %d failures" % [checks, fails.size()])
	print("TEST MERCH_PROFILE ", "PASS" if fails.is_empty() else "FAIL")
	quit(0 if fails.is_empty() else 1)


func _character(name := "Juno") -> void:
	needs.new_game()
	var rec := Avatar.default_record()
	rec["hair"] = Avatar.data()["hairs"][1]
	needs.set_avatar(rec, name, "")


# ------------------------------------------------------------------ catalogue

func _catalogue() -> void:
	print("catalogue")
	for c in Merch.SLOTS:
		check(Merch.items(c).size() == 10, "%s has 10 pieces (%d)" % [c, Merch.items(c).size()])
	var ids := Merch.all_ids()
	check(ids.size() == 40, "40 pieces")
	var seed := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../supabase/seed/merch_items.sql"))
	var all_built := true
	var palette_ok := true
	var seeded := true
	for id in ids:
		var it := Merch.item(id)
		if not seed.contains("'%s'" % id):
			seeded = false
		for body in Merch.BODIES:
			var m := Merch.mesh_for(id, body)
			if m == null or m.get_surface_count() == 0:
				all_built = false
				print("    empty mesh ", id, " ", body)
			var c := Merch.cells_for(id, body)
			for cell in c["cells"]:
				if not it["palette"].has(c["cells"][cell]):
					palette_ok = false
					print("    colour key not in palette ", id, " ", c["cells"][cell])
			for d in c["decals"]:
				if not it["palette"].has(d[2]):
					palette_ok = false
	check(all_built, "every piece builds voxels for every body")
	check(palette_ok, "every voxel colour comes from the piece's palette")
	check(seeded, "supabase/seed/merch_items.sql lists every piece")
	check(Merch.item("horse_mask").get("hides", []).has("head_"), "the horse mask hides the head")
	check(Merch.items("top")[0]["id"] == "bc_logo_tee" and Merch.items("head")[0]["id"] == "horse_mask",
		"Black Cabin logo tee and horse mask lead their categories")


# ------------------------------------------------------------------ version bump

func _version() -> void:
	print("version")
	# A save written by the live 0.4.0 build: save v1, avatar record v1 (no `top`), no merch, no ext.merch.
	var old := {"version": 1, "saved_at_unix": 1795600000.0, "last_seen_unix": 1795600000.0,
		"profile": {"player_id": "11111111-2222-4333-8444-555555555555", "display_name": "Juno",
			"avatar": {"v": 1, "body": "petite", "head": "round", "face": Avatar.data()["face_order"][0],
				"skin": Avatar.data()["skins"][2], "hair": Avatar.data()["hairs"][2],
				"hair_colour": Avatar.data()["hair_colours"][1], "look": Avatar.data()["look_order"][0],
				"top_colour": Avatar.data()["looks"][Avatar.data()["look_order"][0]]["top_colours"][1], "worn": {},
				"created_at": 1795500000.0, "edited_at": 1795500000.0}},
		"needs": {"personality": "", "meters": {}, "nights_out": 3, "created_at": 1795400000.0}, "visits": [], "ext": {}}
	var path := "user://test_merch_v040.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	var was_version: String = ProjectSettings.get_setting("application/config/version", "")
	ProjectSettings.set_setting("application/config/version", "9.9.9")      # the new build
	needs.new_game()
	needs.from_dict(Save.read(path))
	check(needs.has_avatar(), "0.4.0 save: the character is there after the version bump")
	check(not needs.is_new_character(), "0.4.0 save: no creator prompt (not a new character)")
	check(str(needs.profile["display_name"]) == "Juno", "0.4.0 save: the name survives")
	var a: Dictionary = needs.avatar()
	check(a["body"] == "petite" and a["head"] == "round" and a["hair"] == old["profile"]["avatar"]["hair"],
		"0.4.0 save: body, head and hair survive")
	check(float(a["created_at"]) == 1795500000.0, "0.4.0 save: the character's created-at survives")
	check(str(needs.profile["player_id"]) == "11111111-2222-4333-8444-555555555555", "0.4.0 save: the player id survives")
	# merch on the record and owned pieces round-trip through the file
	prof.state()["owned"]["bc_cap"] = {"at": 1.0, "source": "free_pick", "synced": true}
	needs.profile["avatar"] = Merch.wear(needs.profile["avatar"], "bc_cap")
	check(needs.save_game(), "save written")
	needs.new_game()
	check(not needs.has_avatar(), "(cleared in memory)")
	check(needs._load_from_disk(), "save read back")
	check(Merch.worn(needs.avatar()).get("head", "") == "bc_cap", "worn merch survives the save file")
	check(prof.owns("bc_cap"), "owned pieces survive the save file")
	# a save from a NEWER build (save version 7, unknown keys) still keeps the character
	var newer: Dictionary = needs.to_dict()
	newer["version"] = 7
	newer["future_system"] = {"x": 1}
	needs.new_game()
	needs.from_dict(newer)
	check(needs.has_avatar() and str(needs.profile["display_name"]) == "Juno", "a newer build's save keeps the character")
	check(needs.to_dict().has("future_system"), "unknown keys from a newer build are written back")
	ProjectSettings.set_setting("application/config/version", was_version)
	needs.delete_save()


# ------------------------------------------------------------------ server

func _fresh_server() -> void:
	presence.reset_local("user://test_merch_presence.json")
	mock = presence.use_mock(true)
	server = ServerMock.install(mock)
	prof.server_ok = true


func _server() -> void:
	print("server")
	_fresh_server()
	_character("Juno")
	prof.state()["owned"] = {}
	prof.state()["account"] = ""
	prof.state()["pushed"] = ""
	var r: Dictionary = await prof.sync()
	check(r.get("ok", false), "sync ok")
	var uid: String = presence.player_id()
	check(server.profiles.has(uid), "the server has the profile")
	check(server.profiles[uid]["display_name"] == "Juno", "server: name")
	check(server.profiles[uid]["avatar"].get("hair", "") == needs.avatar()["hair"], "server: avatar record")
	check(prof.code().length() == 10, "a 10-character player code (%s)" % prof.code())
	check(str(needs.profile["player_id"]) == uid, "Needs.profile.player_id is the account")
	var n: int = server.profiles.size()
	r = await prof.sync()
	check(r.get("unchanged", false), "nothing changed: no request")
	# free pick
	var c: Dictionary = await prof.claim("horse_mask")
	check(c.get("ok", false) and c.get("new", false) and c.get("synced", false), "claim horse_mask: new, synced")
	check(prof.owns("horse_mask"), "owned locally")
	check(server.inventory[uid].has("horse_mask") and server.inventory[uid]["horse_mask"]["source"] == "free_pick",
		"server inventory: horse_mask, free_pick")
	c = await prof.claim("horse_mask")
	check(c.get("ok", false) and not c.get("new", true), "a second pick is not new")
	c = await prof.claim("no_such_piece")
	check(not c.get("ok", true) and c["reason"] == "unknown_item", "unknown piece refused")
	server.shop_free = false
	c = await prof.claim("neon_halo")
	check(not c.get("ok", true) and c["reason"] == "not_free" and not prof.owns("neon_halo"),
		"free picks switched off on the server: refused, not owned")
	server.shop_free = true
	check(server.profiles.size() == n, "one profile per account")


# ------------------------------------------------------------------ photo booth

func _booth() -> void:
	print("booth")
	await prof.claim("bc_logo_tee")
	var shop: Control = MerchShop.new()
	root.add_child(shop)
	shop.open("wardrobe", prof, needs)
	await process_frame
	check(shop.cat == "head", "the wardrobe opens on the first category with pieces")
	check(shop._grid.get_node_or_null("Item_horse_mask") != null, "wardrobe lists the picked horse mask")
	check(shop._grid.get_node_or_null("Item_bc_cap") == null or prof.owns("bc_cap"), "wardrobe hides pieces not owned")
	var unowned := 0
	for ch in shop._grid.get_children():
		if ch.name.begins_with("Item_") and not prof.owns(String(ch.name).trim_prefix("Item_")):
			unowned += 1
	check(unowned == 0, "wardrobe: only owned pieces")
	shop._select("horse_mask")
	await shop._on_action()
	check(Merch.worn(needs.avatar()).get("head", "") == "horse_mask", "Wear: the avatar record wears the mask")
	shop._go("top")
	check(shop._grid.get_node_or_null("Item_bc_logo_tee") != null, "wardrobe tees: the logo tee")
	shop.queue_free()
	# the shop lists everything
	shop = MerchShop.new()
	root.add_child(shop)
	shop.open("shop", prof, needs)
	await process_frame
	check(shop._grid.get_child_count() == 10, "shop lists the 10 hats and masks")
	shop.queue_free()
	# the figure draws it
	var fig: Node3D = FigureScene.instantiate()
	root.add_child(fig)
	fig.set_look({"avatar": Merch.wear(needs.avatar(), "bc_logo_tee")})
	await process_frame
	var att := fig.find_children("Merch_head", "BoneAttachment3D", true, false)
	check(att.size() == 1 and att[0].get_child_count() == 1, "figure: the mask is on the head bone")
	check(fig.find_children("Merch_top", "BoneAttachment3D", true, false).size() == 1, "figure: the tee print on the spine")
	var head_shown := false
	for mi: MeshInstance3D in fig.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).begins_with("head_") and mi.visible:
			head_shown = true
	check(not head_shown, "figure: the horse mask hides the head")
	var aabb: AABB = att[0].get_child(0).get_aabb() if att.size() == 1 else AABB()
	check(aabb.size.y > 0.3, "figure: the mask has a head-sized mesh (%.2f m)" % aabb.size.y)
	fig.queue_free()
	# on the server the worn merch is part of the avatar after the next sync
	await prof.sync()
	check(server.profiles[presence.player_id()]["avatar"].get("merch", {}).get("head", "") == "horse_mask",
		"server avatar carries the worn merch")


## The real photo booth: the creator opens with a "Merch" button; the wardrobe it opens lists the owned pieces,
## and wearing one reaches the creator's record (Done keeps it) and its preview figure.
func _booth_in_game() -> void:
	print("booth in game")
	needs.profile["avatar"] = Merch.wear(needs.avatar(), "", "head")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.intro = false
	root.add_child(main)
	for i in 10:
		await process_frame
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	main.open_sheet(main.zones.by_id("booth"))
	await process_frame
	var c: Control = main.creator
	var b: Button = c.find_child("BoothMerch", true, false) if is_instance_valid(c) else null
	check(b != null, "the photo booth creator has a Merch button")
	if b != null:
		b.pressed.emit()
		await process_frame
	var w: Control = main.merch_shop
	check(is_instance_valid(w) and w.mode == "wardrobe", "Merch opens My Merch over the creator")
	if is_instance_valid(w):
		check(w._grid.get_node_or_null("Item_horse_mask") != null, "My Merch lists the horse mask")
		w._select("horse_mask")
		await w._on_action()
		check(Merch.worn(c.record).get("head", "") == "horse_mask", "the creator's record now wears the mask")
		await process_frame
		var fig: Node3D = c.get("_figure")
		check(fig != null and fig.find_children("Merch_head", "BoneAttachment3D", true, false).size() == 1,
			"the creator's preview shows the mask")
		w.close()
		await process_frame
	check(not is_instance_valid(main.merch_shop) and is_instance_valid(main.creator), "closing My Merch returns to the creator")
	c._next.pressed.emit()
	await process_frame
	await process_frame
	check(not is_instance_valid(main.creator) and Merch.worn(needs.avatar()).get("head", "") == "horse_mask",
		"Done keeps the mask")
	var pl_has: bool = main.player.find_children("Merch_head", "BoneAttachment3D", true, false).size() == 1
	check(pl_has, "the player in the venue wears it")
	main.queue_free()
	await process_frame


# ------------------------------------------------------------------ lost save, lost session, restore

func _lost_save() -> void:
	print("lost save")
	var uid: String = presence.player_id()
	needs.new_game()                    # storage wiped, but the anonymous session survived
	check(not needs.has_avatar() and prof.owned().is_empty(), "(local save gone)")
	await prof.sync()
	check(presence.player_id() == uid, "same account")
	check(needs.has_avatar() and str(needs.profile["display_name"]) == "Juno", "the character came back from the server")
	check(prof.owns("horse_mask") and prof.owns("bc_logo_tee"), "the pieces came back")
	check(Merch.worn(needs.avatar()).get("head", "") == "horse_mask", "still wearing the mask")


func _session() -> void:
	print("session")
	var old_uid: String = presence.player_id()
	var code: String = prof.code()
	presence.reset_local("user://test_merch_presence2.json")    # anonymous session lost; the save keeps the code
	presence.use_mock(true, mock)
	await prof.sync()
	var uid: String = presence.player_id()
	check(uid != old_uid, "a new anonymous account")
	check(server.profiles[uid]["display_name"] == "Juno", "the new account has the character")
	check(server.inventory.get(uid, {}).has("horse_mask"), "the pieces moved to the new account")
	check(not server.inventory.has(old_uid), "the old account holds nothing")
	check(prof.code() == code, "the player code stays the same")
	check(str(server.profiles[old_uid]["restore_code"]) == "<null>" or server.profiles[old_uid]["restore_code"] == null,
		"the old account lost the code")


func _restore() -> void:
	print("restore")
	var code: String = prof.code()
	var src: String = presence.player_id()
	# hotfix 4 (Daniele 11-21 "My friend send some i got none"): tonight sits on the old account
	mock.ignore_hours = true
	await presence.set_mode("everyone")
	var ci: Dictionary = await presence.checkin(PresenceMock.code_for("WestTable0"))
	check(ci.get("ok", false), "the old account checks in at WestTable0")
	var fr: Dictionary = mock.signup()
	mock.rpc("bc_set_profile", {"p_display_name": "Jack", "p_avatar": {}, "p_mode": "everyone"}, fr["access_token"], 1.0)
	mock.rpc("bc_check_in", {"p_code": PresenceMock.code_for("WestTable0"), "p_display_name": "Jack", "p_avatar": {},
		"p_mode": "everyone"}, fr["access_token"], 1.0)
	var sent: Dictionary = mock.edge("verb", {"to": src, "kind": "wave", "payload": {}}, fr["access_token"], 1.0)
	check(sent.get("ok", false), "a friend waves at the old account (%s)" % sent)
	# another phone: fresh install, its own account and a different new character
	presence.reset_local("user://test_merch_presence3.json")
	presence.use_mock(true, mock)
	_character("Other")
	prof.state()["owned"] = {}
	prof.state()["account"] = ""
	prof.state()["code"] = ""
	prof.state()["pushed"] = ""
	var r: Dictionary = await prof.restore("zzzz-zzz-zzz")
	check(not r.get("ok", true) and r["reason"] == "bad_code", "a wrong code is refused")
	r = await prof.restore(code.substr(0, 4).to_lower() + "-" + code.substr(4, 3) + " " + code.substr(7))
	check(r.get("ok", false), "the code (typed in lower case with dashes) works")
	check(str(needs.profile["display_name"]) == "Juno", "restored: the character")
	check(prof.owns("horse_mask") and prof.owns("bc_logo_tee"), "restored: the pieces")
	check(not server.inventory.has(src), "restored: the pieces left the old phone's account")
	var tn: Dictionary = await presence.tonight(true)
	check(tn.get("me_checked_in", false) and tn.get("my_table", "") == "WestTable0",
		"restored: tonight's check-in came along (%s)" % tn.get("my_table", ""))
	var box: Dictionary = await presence.inbox()
	check(box.get("events", []).size() == 1 and box["events"][0]["from"]["display_name"] == "Jack",
		"restored: the friend's wave is in the new account's inbox")
	var rows: Array = tn.get("presences", [])
	check(rows.filter(func(x): return x["player_id"] == src).is_empty(), "the old account is not in tonight's list")
	for i in 12:
		r = await prof.restore("WRONG%d" % i)
	check(not r.get("ok", true) and r["reason"] == "rate_limited", "11+ tries in an hour are rate limited")


func _offline() -> void:
	print("offline")
	mock.online = false
	var c: Dictionary = await prof.claim("star_shades")
	check(c.get("ok", false) and not c.get("synced", true), "offline pick: owned, not synced")
	check(prof.owns("star_shades"), "offline pick is kept")
	mock.online = true
	await prof.sync()
	check(server.inventory[presence.player_id()].has("star_shades"), "back online: the pick reached the server")
	check(prof.state()["owned"]["star_shades"]["synced"], "back online: marked synced")
	ServerMock.uninstall(mock)          # a server without the migration
	prof.state()["pushed"] = ""
	var r: Dictionary = await prof.sync()
	check(not r.get("ok", true), "server without the migration: sync fails quietly")
	check(not prof.server_ok, "...and the client stops asking")
	c = await prof.claim("gold_chain")
	check(c.get("ok", false) and prof.owns("gold_chain"), "...picks still work locally")
	server = ServerMock.install(mock)
	prof.server_ok = true


func _reset() -> void:
	print("reset")
	await prof.sync(true)
	var code: String = prof.code()
	needs.complete_deletion()           # the player's own reset (farewell card / Retire)
	check(not needs.has_avatar(), "reset: the character is gone")
	check(needs.is_new_character(), "reset: the creator opens next")
	check(prof.owns("horse_mask") and prof.code() == code, "reset: pieces and code stay")
	await prof.sync(true)
	check(not needs.has_avatar(), "reset: the server does not bring the deleted character back")
