extends SceneTree
## Headless tests for Black Cabin's real menu in the game. Exit code 0 = all pass.
##   godot --headless --path . --script res://tests/test_menu.gd
## Data (res://data/menu.json): loads, every item has EN + TH names and a price, ids are unique, categories map to
## the existing rule effects with today's numbers; it matches the transcription docs/venue/menu/menu.json; the printed
## misprints are corrected in the game names and kept as printed in print_errata; Try something new is six real drinks,
## one per family, rotating per bar night; the bundles are listed; the menu strings exist in both languages. UI: the menu list shows every drink, blocks alcohol while Merry, lists the
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
	test_misprints()
	test_try_pool()
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


## Daniele 2026-11-01 (Menu cards): misprints are corrected in the game and listed for Black Cabin; the printed spelling
## stays in print_errata (docs/venue/menu/menu.json) as the record. The clear ones are fixed in the game; the unverified
## ones (Fillippo, Verenes vs Verges, Logann's, the BigMac "sherry cask") stay as printed until the bar confirms them
## (docs/venue/menu/errata-for-black-cabin.md).
func test_misprints() -> void:
	print("[misprints] corrected in the game, kept as printed in print_errata")
	var root_dir := ProjectSettings.globalize_path("res://")
	var f := FileAccess.open(root_dir.path_join("../docs/venue/menu/menu.json"), FileAccess.READ)
	check(f != null, "transcription readable")
	if f == null:
		return
	var text := f.get_as_text()
	var src: Dictionary = JSON.parse_string(text)
	var fixed := {  # id (slug of the printed name, stable) -> corrected game name
		"thai_cavier_yum": "Thai Caviar (Yum)",
		"aus_ribeye_steak_w_frittes_and_truffle_mayo": "Aus Ribeye Steak w/ Frites & Truffle Mayo",
		"cape_of_good_hope_riebbeksrevier_chenin_blanc_2023": "Cape of Good Hope Riebeeksrivier Chenin Blanc 2023",
		"castello_del_trebbio_chianti_superiore_dogc_2022": "Castello del Trebbio Chianti Superiore DOCG 2022",
	}
	for id in fixed:
		check(BarMenu.item(id).get("name_en") == fixed[id], "%s reads %s (game: %s)" % [id, fixed[id], BarMenu.item(id).get("name_en")])
	check(BarMenu.item("ki_raro_blocks_sauvignon_blanc_2023").get("region") == "Marlborough, NZ", "Marlborough spelled right")
	for it in BarMenu.items():
		var shown: String = str(it["name_en"]) + " " + str(it.get("region", ""))
		for bad in ["Cavier", "Frittes", "Riebbeks", "Malbourough", "DOGC"]:
			check(shown.findn(bad) == -1, "%s: no misprint %s in the game text" % [it["id"], bad])
	check(BarMenu.item("thai_cavier_yum").get("name_printed") == "THAI CAVIER (YUM)", "name_printed keeps the printed THAI CAVIER")
	check(BarMenu.sections("drinks").any(func(s): return s["id"] == "blended_scotch" and s["title"] == "Blended Scotch Whisky"),
		"the Blended Scotch heading is spelled right")
	var csv := FileAccess.open(BarMenu.CSV_PATH, FileAccess.READ).get_as_text()
	check(csv.find("BLENDED SCOTH") != -1 and csv.find(",Blended Scotch Whisky,") != -1,
		"strings_menu.csv: heading corrected, the printed form kept in the context column")
	# Unverified: kept as printed in the game until Black Cabin confirms
	check(BarMenu.item("nv_fillippo_sparkling").get("name_en") == "NV Fillippo, Sparkling", "Fillippo kept as printed (unverified)")
	check(str(BarMenu.item("chateau_les_verenes_simplement_sauvignon_blanc_2022").get("name_en", "")).contains("Verenes"),
		"Verenes kept as printed (unverified)")
	check(BarMenu.item("loganns_hollow_shiraz_2019").get("name_en") == "Logann's Hollow, Shiraz 2019", "Logann's kept as printed (unverified)")
	# The record: every misprint is still listed as printed, and the printed text is still in the transcription
	var errata: Array = src["print_errata"]
	check(errata.size() == 10, "print_errata keeps its 10 entries (%d)" % errata.size())
	for e in errata:
		check(str(e["printed"]) != "" and str(e["likely"]) != "" and str(e["page"]) != "", "errata entry %s is complete" % e["printed"])
		check(text.find(str(e["printed"]).split(": ")[-1]) != -1, "printed text '%s' is still in the transcription" % e["printed"])
	var off: Array = src["price_notes"].filter(func(n): return n.has("printed_was"))
	check(off.size() == 3, "the three bundle 'was' prices that do not add up are recorded")
	for n in off:
		check(int(n["printed_was"]) != int(n["list_sum"]), "%s: printed was %d is not the list sum %d" % [n["item"], n["printed_was"], n["list_sum"]])
	var md := FileAccess.open(root_dir.path_join("../docs/venue/menu/errata-for-black-cabin.md"), FileAccess.READ)
	check(md != null, "errata-for-black-cabin.md exists")
	if md:
		var mt := md.get_as_text()
		for e in errata:
			check(mt.find(str(e["printed"]).split(": ")[-1]) != -1, "errata file lists '%s'" % e["printed"])
		for was in ["7,180", "16,980", "20,480"]:
			check(mt.find(was) != -1, "errata file lists the bundle was price " + was)


## Try something new (Daniele 2026-11-01: "six real drinks, one per family"): the pool is six drinks from six different
## families; the offer rotates per bar night like Pour Perfect and skips any drink already tried. Bundles are in the data.
func test_try_pool() -> void:
	print("[try something new] six real drinks, one per family, rotating per bar night; bundles in the data")
	var pool := BarMenu.try_order()
	check(pool.size() == 6, "six drinks in the pool")
	var fams := {}
	for id in pool:
		check(BarMenu.has(id) and BarMenu.effect(id) == "alcohol", "%s is a real alcoholic drink" % id)
		var fam := BarMenu.family_of(id)
		check(fam != "" and not fams.has(fam), "%s is the only pool drink of family %s" % [id, fam])
		fams[fam] = true
	check(fams.size() == 6, "six different families")
	for night in [0, 1, 5, 6, 20398]:
		check(BarMenu.try_pick({}, night) == pool[night % 6], "night %d opens on pool[%d]" % [night, night % 6])
		check(BarMenu.try_pick({}, night) == BarMenu.try_pick({}, night), "night %d is deterministic" % night)
		check(BarMenu.try_pick({}, night + 1) == pool[(night + 1) % 6], "night %d: tomorrow opens on the next drink" % night)
	# Skips what is tried; six tried = nothing left
	var tried := {}
	var offered := {}
	for i in 6:
		var d := BarMenu.try_pick(tried, 3)
		check(d != "" and not tried.has(d) and not offered.has(d), "night 3, pick %d: %s is new" % [i, d])
		offered[d] = true
		tried[d] = true
	check(offered.size() == 6, "six picks cover the six drinks")
	check(BarMenu.try_pick(tried, 3) == "", "all six tried: nothing to offer")
	check(BarMenu.try_pick({pool[0]: true}, 0) == pool[1], "a tried drink is skipped")
	var bundles := BarMenu.bundles()
	check(bundles.size() == 6, "six bundles (Seppuku + five)")
	var by := {}
	for b in bundles:
		by[b["id"]] = b
		check(str(b["name"]) != "" and str(b["bottles"]).contains(" + "), "%s lists its bottles" % b["id"])
		check(int(b["price"]) > 0, "%s has a price (%d)" % [b["id"], b["price"]])
	check(by.has("seppuku") and int(by["seppuku"]["price"]) == 34990, "Seppuku 34,990")
	check(by.has("bigmac") and int(by["bigmac"]["price"]) == 16990 and by["bigmac"]["name"] == "BigMac", "BigMac 16,990")
	check(by.has("rockstar_breakfast") and int(by["rockstar_breakfast"]["price"]) == 6590, "Rockstar Breakfast 6,590")


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
			"menu.bar.soft_sub", "menu.card.order", "menu.card.soft", "menu.card.water", "menu.pour.pouring", "menu.tab.bundles",
			"menu.bundles.note"]:
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
	# Bundles tab: their own section, every bundle with its bottles and its THB price dimmed like the rest
	ml.show_tab("bundles")
	await process_frame
	await process_frame
	check(ml.tab == "bundles" and ml.tab_buttons.has("bundles") and ml.tab_buttons["bundles"].button_pressed, "Bundles tab opens")
	check(ml.bundle_rows.size() == BarMenu.bundles().size() and ml.buttons.is_empty(),
		"the Bundles tab lists the %d bundles, no drink rows" % BarMenu.bundles().size())
	for bd in BarMenu.bundles():
		var row: Control = ml.bundle_rows.get(bd["id"])
		var price: Label = row.find_child("Price", true, false) if row else null
		var bottles: Label = row.find_child("Bottles", true, false) if row else null
		check(price != null and price.text == BarMenu.bundle_price_text(bd["price"]) and price.get_theme_color("font_color") == MenuList.PRICE_COLOR,
			"%s shows %s in the dimmed price colour" % [bd["id"], BarMenu.bundle_price_text(bd["price"])])
		check(bottles != null and bottles.text == bd["bottles"], "%s shows its bottles" % bd["id"])
		check(row != null and not (row is Button), "%s is not orderable (no coin price yet)" % bd["id"])
	var texts := []
	for l in ml.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	# Daniele 2026-11-02: price only (no struck-through 'was' price), list-only (no ordering)
	for bd in BarMenu.bundles():
		check(not bd.has("was"), "%s carries no 'was' price" % bd["id"])
	var src_b: Array = BarMenu.data()["bundles"]
	for sb in src_b:
		check(not texts.has(BarMenu.bundle_price_text(int(sb["was"]))) or int(sb["was"]) == int(sb["now"]), "no label shows the 'was' price %d" % int(sb["was"]))
	var any_btn := false
	for bd in BarMenu.bundles():
		any_btn = any_btn or ml.bundle_rows[bd["id"]].find_children("*", "Button", true, false).size() > 0
	check(not any_btn, "bundle rows hold no button: list-only, nothing to order")
	check(texts.has(BarMenu.t("menu.bundles.note")), "the daily-limit note shows on the Bundles tab")
	ml.show_tab("drinks")
	await process_frame
	check(ml.bundle_rows.is_empty() and ml.buttons.size() == drinks.size(), "back on Drinks: drink rows only")
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
	check(BarMenu.try_order().has(s.next_new_drink()) and text.find(BarMenu.name_of(s.next_new_drink())) != -1,
		"Try something new names a real drink from the six")
	# Soft row: Coke (Daniele 2026-11-01)
	check(VenueSession.SOFT_DRINK == "coke", "the soft-drink row is Coke")
	var soft := {}
	for r in rows:
		if r["id"] == "mocktail":
			soft = r
	check(str(soft.get("sub", "")).contains("Coke"), "the soft-drink row's sub-line names Coke (%s)" % soft.get("sub", ""))
	check(ids.has("menu") and ids.has("kitchen"), "bar sheet has The menu and Kitchen rows")
	for id in ["order", "pour", "try", "mocktail", "water", "stool"]:
		check(ids.has(id), "row %s kept" % id)
	check(s.has_method("order_item"), "VenueSession.order_item exists")
	if not s.has_method("order_item"):
		main.queue_free()
		return

	# Ordering from the menu marks the drink as tried (it did not before); the gains stay the plain order's
	needs.ext.erase("drinks_tried")
	check(s.tried_count() == 0, "nothing tried yet")
	var offer0: String = s.next_new_drink()
	var d_menu: float = needs.meters["drinks"]
	check(s.order_item(offer0), "order tonight's Try something new drink from the menu: " + offer0)
	check(needs.ext.get("drinks_tried", {}).has(offer0) and s.tried_count() == 1, "the menu order marked %s as tried" % offer0)
	check(s.next_new_drink() != offer0 and BarMenu.try_order().has(s.next_new_drink()), "Try something new moves on after the menu order")
	check(needs.meters["drinks"] > d_menu, "the menu order refilled Drinks (%.1f -> %.1f), no Try bonus" % [d_menu, needs.meters["drinks"]])
	s.order_item("jameson")
	s.order_item("coke")
	check(s.tried_count() == 3 and needs.ext["drinks_tried"].has("jameson") and needs.ext["drinks_tried"].has("coke"),
		"any menu drink counts: alcohol and soft")
	s.order_item("jameson")
	check(s.tried_count() == 3, "a repeat order does not count twice")
	check(not s.order_item("black_cabin_burger_and_fries") and s.tried_count() == 3, "kitchen items are not drinks, not marked")
	# The bar rows mark theirs too
	needs.ext.erase("drinks_tried")
	s.tipsy.reset(needs.clock)
	s.do_row(z, "order")
	s.do_row(z, "mocktail")
	check(needs.ext["drinks_tried"].has("house_shooter") and needs.ext["drinks_tried"].has("coke"), "the Order and soft-drink rows mark theirs")
	# Pour Perfect marks the poured drink as tried once it is served (orchestrator 2026-11-02)
	needs.ext.erase("drinks_tried")
	s.do_row(z, "pour")
	var poured: String = s._pour_drink
	check(poured != "" and not needs.ext.get("drinks_tried", {}).has(poured), "a pour that is only requested is not tried yet")
	needs.apply_action("pour_perfect", 1.0)
	check(needs.ext["drinks_tried"].has(poured), "Pour Perfect marks the poured drink (%s) as tried" % poured)
	# Try something new never offers what was already tried and still marks its own drink
	needs.ext.erase("drinks_tried")
	for id in BarMenu.try_order().slice(0, 5):
		s.order_item(id)
	check(s.next_new_drink() == BarMenu.try_order()[5], "five of six tried through the menu: Try something new offers the last (%s)" % s.next_new_drink())
	s.do_row(z, "try")
	check(s.next_new_drink() == "" and s.tried_count() >= 6, "the Try row marked the sixth; nothing left to try")
	needs.ext.erase("drinks_tried")
	s.tipsy.reset(needs.clock)
	for m in needs.meters:
		needs.meters[m] = 20.0
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
