extends SceneTree
## Headless tests for Black Cabin's real menu in the game. Exit code 0 = all pass.
##   godot --headless --path . --script res://tests/test_menu.gd
## Data (res://data/menu.json): loads, every item has EN + TH names and a price, ids are unique, categories map to
## the existing rule effects with today's numbers; it matches the transcription docs/venue/menu/menu.json; the menu
## strings exist in both languages. UI: the menu list shows every drink, blocks alcohol while Merry, lists the
## kitchen without making it orderable; Pour Perfect pours a real drink. Integration (main.tscn): the bar sheet
## names real drinks, no invented drink is left, and ordering by category gives exactly the old effects.

const BarMenu = preload("res://scripts/menu/bar_menu.gd")
const MenuList = preload("res://scripts/menu/menu_list.gd")
const UI = preload("res://scripts/minigames/mg_ui.gd")
const Rules = preload("res://scripts/rules.gd")
const Tipsiness = preload("res://scripts/zones/tipsiness.gd")
const PourScene := "res://scenes/minigames/pour_perfect/pour_perfect.tscn"
const TRANSCRIPTION := "res://../docs/venue/menu/menu.json"
const INVENTED := ["lychee_fizz", "thai_tea_sour", "mekhong_mule", "butterfly_gin", "pandan_colada", "smoky_old_fashioned"]
const INVENTED_NAMES := ["Lychee Fizz", "Thai Tea Sour", "Mekhong Mule", "Butterfly Pea Gin", "Pandan Colada",
	"Smoky Old Fashioned", "Thai iced tea", "house cocktail"]
const CATEGORY_EFFECT := {
	"aperitif": "none", "sharing": "none", "main": "none", "pasta": "none", "soft": "",  # soft or water
	"beer": "alcohol", "shooter": "alcohol", "sparkling": "alcohol", "white_wine": "alcohol", "red_wine": "alcohol",
	"single_malt": "alcohol", "blended_scotch": "alcohol", "american_whiskey": "alcohol", "irish_whiskey": "alcohol",
	"japanese_whisky": "alcohol", "tequila_mezcal": "alcohol", "vodka": "alcohol", "rum": "alcohol",
	"liqueur": "alcohol", "brandy_cognac": "alcohol", "gin": "alcohol",
}

var failures := 0
var checks := 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("  FAIL " + msg)


func _init() -> void:
	await process_frame
	test_data()
	test_effects()
	test_transcription()
	test_strings()
	await test_menu_list()
	await test_pour()
	await test_bar_sheet()
	print("")
	print("%d checks, %d failed" % [checks, failures])
	print("MENU TESTS ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func test_data() -> void:
	print("[data] menu.json loads; every item has id, EN + TH, category and a price")
	var d := BarMenu.data()
	check(not d.is_empty(), "res://data/menu.json loads")
	var all := BarMenu.items()
	check(all.size() == 155, "155 game items (%d)" % all.size())
	check(BarMenu.items("drinks").size() == 121, "121 drinks")
	check(BarMenu.items("kitchen").size() == 34, "34 kitchen dishes")
	var seen := {}
	for it in all:
		var id: String = it.get("id", "")
		check(id != "" and not seen.has(id), "unique id " + id)
		seen[id] = true
		check(str(it.get("name_en", "")) != "", id + " has an EN name")
		check(str(it.get("name_th", "")) != "", id + " has a TH name")
		check(typeof(it.get("th_draft")) == TYPE_BOOL, id + " marks th_draft")
		check(it.get("price") != null and int(it["price"]) > 0, id + " has a price")
		check(CATEGORY_EFFECT.has(it.get("category", "")), id + " has a known category")
		check(it.get("group") in ["drinks", "kitchen"], id + " is in a group")
		check(BarMenu.price_text(id) != "", id + " price shows")
	check(BarMenu.item("house_shooter").get("price_unit") == "deal_5_free_1", "house shooters keep the 5 + 1 deal")
	check(BarMenu.item("ardbeg_10y").get("price") == 520 and BarMenu.item("ardbeg_10y").get("price_bottle") == 6990,
		"spirits price per glass, bottle kept")
	check(BarMenu.price_text("clase_azul_reposado").begins_with("2,290"), "thousands separator")
	check(BarMenu.item("thai_cavier_yum").get("name_th") == "ยำไข่มดแดง" and not BarMenu.item("thai_cavier_yum")["th_draft"],
		"printed Thai name kept and not a draft")
	check(BarMenu.item("ribeye_beef_jerky_mala").get("star", false) and BarMenu.item("ribeye_beef_jerky_mala").get("chilli", false),
		"star and chilli flags")
	for id in INVENTED:
		check(not BarMenu.has(id), "invented drink %s is gone" % id)


func test_effects() -> void:
	print("[effects] categories map to the existing rule effects with today's numbers")
	var fx: Dictionary = BarMenu.data()["effects"]
	for e in ["alcohol", "soft", "water", "none"]:
		check(fx.has(e), "effect %s defined" % e)
	check(fx["alcohol"]["action"] == "order_drink" and int(fx["alcohol"]["tipsy"]) == 1 and not fx["alcohol"]["merry_blocked"],
		"alcohol = order_drink, +1 tipsy, served while Merry (nightlife: drunk to 10, WASTED past 10)")
	check(fx["soft"]["action"] == "order_drink" and int(fx["soft"]["tipsy"]) == 0, "soft = order_drink, no tipsy")
	check(fx["water"]["action"] == "order_drink" and int(fx["water"]["tipsy"]) == -1, "water = order_drink, drops a state")
	check(fx["none"]["action"] == "", "kitchen does nothing yet")
	# The numbers themselves stay in rules.gd, unchanged.
	check(float(Rules.ACTIONS["order_drink"]["gains"]["drinks"]) == 15.0, "order_drink still +15 Drinks")
	check(float(Rules.ACTIONS["try_new_drink"]["gains"]["drinks"]) == 5.0, "try_new_drink still +5 Drinks")
	check(Rules.ACTIONS["pour_perfect"]["gains"]["drinks"] == [20.0, 30.0], "pour_perfect still +20-30 Drinks")
	for it in BarMenu.items():
		var want: String = CATEGORY_EFFECT[it["category"]]
		if want == "":
			check(it["effect"] in ["soft", "water"], "%s is soft or water" % it["id"])
		else:
			check(it["effect"] == want, "%s (%s) -> %s" % [it["id"], it["category"], want])
		check((it["group"] == "kitchen") == (it["effect"] == "none"), "%s: kitchen iff no effect" % it["id"])
		check(it.get("pourable", false) == (it["effect"] == "alcohol"), "%s: pourable iff alcohol" % it["id"])
	check(BarMenu.effect("water") == "water" and BarMenu.effect("acqua_panna_mineral_water") == "water", "both waters are water")
	check(BarMenu.effect("coke") == "soft", "Coke is soft")
	check(BarMenu.try_order().size() == 6, "Try something new keeps six drinks")
	for id in BarMenu.try_order():
		check(BarMenu.effect(id) == "alcohol", "try drink %s is alcoholic like the old six" % id)
	for id in BarMenu.pour_featured():
		check(BarMenu.item(id).get("pourable", false), "featured pour %s is pourable" % id)
		check(BarMenu.pour_colors(id).size() == 3, "featured pour %s has three layer colours" % id)
	check(BarMenu.pour_pick(0) == BarMenu.pour_featured()[0], "pour pick rotates from the first")
	check(BarMenu.pour_pick(BarMenu.pour_featured().size()) == BarMenu.pour_featured()[0], "pour pick wraps")
	_check_pour_families()


## Pour Perfect: a rotation of 12 drinks, one per drink family (Daniele 2026-11-02, Questions tab third batch).
func _check_pour_families() -> void:
	var fams := BarMenu.pour_families()
	check(fams.size() == 12, "Pour Perfect has 12 drink families (got %d)" % fams.size())
	check(BarMenu.pour_featured().size() == 12, "Pour Perfect features 12 drinks")
	var fam_ids := {}
	var cat_family := {}
	for i in fams.size():
		var f: Dictionary = fams[i]
		check(not fam_ids.has(f["id"]), "family %s listed once" % f["id"])
		fam_ids[f["id"]] = true
		for c in f["categories"]:
			check(not cat_family.has(c), "category %s in one family only" % c)
			cat_family[c] = f["id"]
		check(BarMenu.has(f["drink"]), "family %s drink %s is on the menu" % [f["id"], f["drink"]])
		check(BarMenu.family_of(f["drink"]) == f["id"], "family %s features its own drink (%s)" % [f["id"], f["drink"]])
		check(BarMenu.pour_featured()[i] == f["drink"], "featured pour %d is family %s's drink" % [i, f["id"]])
	# Every pourable drink belongs to exactly one family; nothing else does
	for it in BarMenu.items("drinks"):
		var fam := BarMenu.family_of(it["id"])
		if it.get("pourable", false):
			check(fam != "", "pourable %s (%s) has a family" % [it["id"], it["category"]])
		else:
			check(fam == "", "%s (not pourable) has no family" % it["id"])
	# One drink per family in any 12 pours in a row, from any night; each night opens on the next family
	for night in [0, 1, 7, 11, 12, 20398]:
		var seen := {}
		for n in 12:
			seen[BarMenu.family_of(BarMenu.pour_pick(n, false, night))] = true
		check(seen.size() == 12, "night %d: 12 pours cover all 12 families" % night)
		check(BarMenu.pour_pick(0, false, night + 1) == BarMenu.pour_pick(1, false, night), "night %d: tomorrow opens on the next family" % night)
	# Bar nights turn over at 06:00 Bangkok (UTC+7) = 23:00 UTC: 02:00 and 05:59 belong to the night before
	var evening := 1793707200.0  # 2026-11-03 19:00 Bangkok (12:00 UTC)
	check(BarMenu.night_of(evening) == BarMenu.night_of(evening + 7 * 3600.0), "02:00 is still the same night")
	check(BarMenu.night_of(evening) == BarMenu.night_of(evening + 10 * 3600.0 + 3599.0), "05:59 is still the same night")
	check(BarMenu.night_of(evening + 11 * 3600.0) == BarMenu.night_of(evening) + 1, "06:00 starts the next night")
	check(BarMenu.effect(BarMenu.pour_pick(3, true)) == "soft", "Merry pours a soft drink")
	check(BarMenu.pour_colors(BarMenu.pour_pick(0, true)).size() == 3, "the Merry soft drink has colours")


func test_transcription() -> void:
	print("[transcription] game data matches docs/venue/menu/menu.json")
	var path := ProjectSettings.globalize_path("res://").path_join("../docs/venue/menu/menu.json")
	var f := FileAccess.open(path, FileAccess.READ)
	check(f != null, "transcription readable at " + path)
	if f == null:
		return
	var src: Dictionary = JSON.parse_string(f.get_as_text())
	var counts := {"aperitifs": 8, "sharing": 13, "mains": 6, "pasta": 6, "beer": 4, "other": 14,
		"champagne_sparkling": 5, "whites": 6, "reds": 6, "single_malt": 10, "blended_scotch": 10,
		"american_whiskey": 8, "irish_whiskey": 2, "japanese_whisky": 5, "tequila_mezcal": 14, "vodka": 5, "rum": 6,
		"liqueur": 5, "brandy_cognac": 7, "gin": 14}
	var by_printed := {}
	for it in BarMenu.items():
		by_printed[it["name_printed"] + ("|" + it["variant"] if it.has("variant") else "")] = it
	for s in src["sections"]:
		check(s["items"].size() == counts.get(s["id"], -1), "%s has %d items as printed" % [s["id"], counts.get(s["id"], -1)])
		for p in s["items"]:
			if p["name"] == "ICE BUCKET":
				continue
			if p.has("variants"):
				for v in p["variants"]:
					var g: Dictionary = by_printed.get(p["name"] + "|" + v["name"], {})
					check(not g.is_empty() and int(g["price"]) == int(v["price"]), "%s %s price" % [p["name"], v["name"]])
				continue
			var gi: Dictionary = by_printed.get(p["name"], {})
			check(not gi.is_empty(), "%s is in the game" % p["name"])
			if gi.is_empty():
				continue
			var want := int(p.get("price_glass", p.get("price", p.get("price_bottle", 0))))
			check(int(gi["price"]) == want, "%s price %d (game %d)" % [p["name"], want, int(gi["price"])])
			check(gi.get("star", false) == p.get("star", false) and gi.get("chilli", false) == p.get("chilli", false),
				"%s flags" % p["name"])
	check(src["bundles"].size() == 6, "five bundles plus Seppuku")
	check(src["deals"][0]["price"] == 590, "house shooters 5 free 1 at 590")
	check(src["print_errata"].size() >= 5, "print errata recorded")


func test_strings() -> void:
	print("[strings] strings_menu.csv has EN and TH for every key")
	var f := FileAccess.open(BarMenu.CSV_PATH, FileAccess.READ)
	check(f != null, "strings_menu.csv opens")
	if f == null:
		return
	var keys := {}
	f.get_csv_line()
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() < 3 or r[0] == "":
			continue
		keys[r[0]] = true
		check(r[1] != "" and r[2] != "", r[0] + " has EN and TH")
	for s in BarMenu.data()["sections"]:
		check(keys.has(s["title_key"]), s["title_key"] + " in the CSV")
	for k in ["menu.head", "menu.tab.drinks", "menu.tab.kitchen", "menu.kitchen_soon", "menu.merry", "menu.bar.menu",
			"menu.bar.menu_sub", "menu.bar.kitchen", "menu.bar.kitchen_sub", "menu.bar.order_sub", "menu.bar.soft",
			"menu.bar.soft_sub", "menu.card.order", "menu.card.soft", "menu.card.water", "menu.pour.pouring"]:
		check(keys.has(k), k + " in the CSV")
	TranslationServer.set_locale("th")
	check(BarMenu.t("menu.tab.kitchen") == "ครัว", "Thai string resolves")
	check(BarMenu.name_of("water") == "น้ำเปล่า", "Thai item name in Thai locale")
	TranslationServer.set_locale("en")
	check(BarMenu.name_of("water") == "Water", "EN item name in English locale")


## Every row shows its THB price as printed, dimmed: the secondary colour, not the name's cream (Daniele 2026-11-02).
## Rows also fit their content: a long name wraps and its row grows, no row draws over the next.
func _check_prices(ml: Control, tab: String) -> void:
	for i in 3:
		await process_frame
	var dimmed := 0
	var short := []
	for it in BarMenu.items(tab):
		var row: Control = ml.buttons.get(it["id"])
		var price: Label = row.find_child("Price", true, false) if row else null
		check(price != null and price.text == BarMenu.price_text(it["id"]) and price.text != "",
			"%s row shows its price %s" % [it["id"], BarMenu.price_text(it["id"])])
		if price and price.get_theme_color("font_color") == MenuList.PRICE_COLOR:
			dimmed += 1
		if row and row.size.y + 0.5 < row.get_child(0).get_combined_minimum_size().y:
			short.append(it["id"])
	check(short.is_empty(), "%s: every row fits its text (too short: %s)" % [tab, ", ".join(short)])
	check(dimmed == BarMenu.items(tab).size(), "%s: every price in the secondary colour (%d)" % [tab, dimmed])
	check(MenuList.PRICE_COLOR.get_luminance() < UI.CREAM.get_luminance(), "prices dimmer than item names")


func test_menu_list() -> void:
	print("[menu list] every drink tappable; Merry blocks alcohol; kitchen listed, not orderable")
	var ml: Control = MenuList.new()
	root.add_child(ml)
	ml.open("drinks", false)
	await process_frame
	var drinks := BarMenu.items("drinks")
	check(ml.buttons.size() == drinks.size(), "drinks tab lists all %d drinks (%d)" % [drinks.size(), ml.buttons.size()])
	var chosen := []
	ml.item_chosen.connect(func(id): chosen.append(id))
	var b: Button = ml.buttons.get("guinness_draught")
	check(b != null and not b.disabled, "Guinness row enabled")
	if b:
		b.pressed.emit()
	check(chosen == ["guinness_draught"], "tapping a drink emits its id")
	await _check_prices(ml, "drinks")
	ml.show_tab("kitchen")
	await process_frame
	await _check_prices(ml, "kitchen")
	ml.open("drinks", true)
	await process_frame
	check(ml.buttons["guinness_draught"].disabled, "Merry: alcohol disabled")
	check(not ml.buttons["coke"].disabled and not ml.buttons["water"].disabled, "Merry: soft drinks and water open")
	ml.show_tab("kitchen")
	await process_frame
	check(ml.buttons.size() == BarMenu.items("kitchen").size(), "kitchen tab lists all dishes")
	var any_button := false
	for id in ml.buttons:
		any_button = any_button or ml.buttons[id] is Button
	check(not any_button, "kitchen rows are not buttons (do nothing yet)")
	ml.queue_free()
	await process_frame


func test_pour() -> void:
	print("[pour perfect] pours a real drink")
	var game: Control = load(PourScene).instantiate()
	game.config = {"drink": "guinness_draught"}
	root.add_child(game)
	game.start()
	await process_frame
	check(game.drink_id == "guinness_draught", "drink taken from config")
	check(game.layer_colors == BarMenu.pour_colors("guinness_draught"), "stout colours on the layers")
	game.queue_free()
	var plain: Control = load(PourScene).instantiate()
	root.add_child(plain)
	plain.start()
	await process_frame
	check(plain.drink_id == "" and plain.layer_colors == plain.LAYER_COLORS, "no drink: the lab's plain pour")
	plain.queue_free()
	await process_frame


func test_bar_sheet() -> void:
	print("[bar sheet] real items on the bar sheet; effects by category unchanged (main.tscn)")
	var needs: Node = root.get_node_or_null("Needs")
	check(needs != null, "Needs autoload")
	if needs == null:
		return
	needs.autosave = false
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 20.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 5:
		await physics_frame
	var s: VenueSession = main.session
	var z: Dictionary = main.zones.first_of("bar")
	var rows: Array = s.rows_for(z)
	var text := ""
	var ids := []
	for r in rows:
		ids.append(r["id"])
		text += "%s | %s | %s\n" % [r["title"], r["sub"], r["reason"]]
	print(text)
	for n in INVENTED_NAMES:
		check(text.findn(n) == -1, "no invented drink on the bar sheet: " + n)
	check(text.find(BarMenu.name_of(BarMenu.try_order()[0])) != -1, "Try something new names a real drink")
	check(ids.has("menu") and ids.has("kitchen"), "bar sheet has The menu and Kitchen rows")
	for id in ["order", "pour", "try", "mocktail", "water", "stool"]:
		check(ids.has(id), "row %s kept" % id)
	check(s.has_method("order_item"), "VenueSession.order_item exists")
	if not s.has_method("order_item"):
		main.queue_free()
		return

	# Alcohol: exactly the old Order row (+15 Drinks, +1 tipsiness).
	var d0: float = needs.meters["drinks"]
	var t0: int = s.tipsy.drinks
	check(s.order_item("guinness_draught"), "order Guinness from the menu")
	check(needs.meters["drinks"] > d0, "Guinness refills Drinks (%.1f -> %.1f)" % [d0, needs.meters["drinks"]])
	check(s.tipsy.drinks == t0 + 1, "Guinness adds one to tipsiness")
	# Soft: the old Thai iced tea row (+Drinks, no tipsiness).
	var d1: float = needs.meters["drinks"]
	check(s.order_item("coke"), "order a Coke")
	check(needs.meters["drinks"] > d1 and s.tipsy.drinks == t0 + 1, "Coke refills Drinks, no tipsiness")
	# Water: the old water row (drops a state).
	s.order_item("jameson")
	s.order_item("roku")
	var st: int = s.tipsy.state()
	check(s.order_item("water"), "order water")
	check(s.tipsy.state() == st - 1, "water drops a tipsiness state")
	# Kitchen: nothing yet.
	var d2: float = needs.meters["drinks"]
	check(not s.order_item("black_cabin_burger_and_fries"), "kitchen item is not orderable yet")
	check(needs.meters["drinks"] == d2, "kitchen item changes nothing")
	# Merry no longer stops alcohol (DECISIONS playtest of 33dc5b9: drunk to 10, WASTED past 10; tests/test_nightlife.gd)
	while s.tipsy.state() != Tipsiness.MERRY:
		s.order_item("house_shooter")
	check(s.order_item("guinness_draught"), "Merry: alcohol still served")
	check(s.order_item("coke"), "Merry: soft drink still served")
	main.queue_free()
	await process_frame
