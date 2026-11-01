# 🍸 menu worker → orchestrator: edits needed in venue-owned files (waiting for go-ahead)

My own files are ready (not yet committed): `docs/venue/menu/menu.json` + `menu.md`, `tools/menu_build.py`,
`game/data/menu.json`, `game/i18n/strings_menu.csv`, `game/scripts/menu/bar_menu.gd` (loader + effects),
`game/scripts/menu/menu_list.gd` (Drinks / Kitchen sheet), `game/scripts/minigames/pour_perfect.gd` (takes
`config.drink`; no other session owns minigames), `game/tests/test_menu.gd`.

Rule effects stay exactly as today; ordering a real drink reuses the existing rows' code paths:
alcohol = Order row (`order_drink` +15, +1 tipsy, blocked while Merry); soft = Thai iced tea row (+15, no tipsy);
water = water row (+15, drops a state); kitchen = nothing. Try something new keeps `order_drink` + `try_new_drink`
(+20, +1 tipsy) over six real drinks; Pour Perfect keeps +20-30 and +1 tipsy, now featuring a real drink.

## 1. `game/scripts/zones/venue_session.gd` (venue-notes owns it)

a) After `signal state_changed ...` (line 16) add:
```gdscript
signal menu_requested(tab: String)  ## main.gd opens the real menu list (scripts/menu/menu_list.gd) on this tab
```
b) After `const T = preload("res://scripts/zones/venue_strings.gd")` (line 21) add:
```gdscript
const BarMenu = preload("res://scripts/menu/bar_menu.gd")
```
c) Delete lines 28-29 (the comment and `const MENU := ["lychee_fizz", ... "smoky_old_fashioned"]`). Add one var
next to `var drinks_this_visit := 0`:
```gdscript
var pours_this_visit := 0  ## rotates Pour Perfect through the menu's featured drinks
```
and in `arrive()` next to `drinks_this_visit = 0` (line 82): `pours_this_visit = 0`.

d) Bar rows, lines 118-127 become:
```gdscript
			rows.append(_row("order", "venue.sheet.bar.order",
				T.t("venue.sheet.bar.order_free") if drinks_this_visit == 0 else BarMenu.t("menu.bar.order_sub", {"drink": BarMenu.name_of(HOUSE_DRINK)}), "drinks", false, no_alc))
			rows.append(_row("menu", "menu.bar.menu", BarMenu.t("menu.bar.menu_sub", {"n": BarMenu.items("drinks").size()}), "drinks"))
			rows.append(_row("pour", "venue.sheet.bar.pour", T.t("venue.sheet.bar.pour_sub", {"best": _best("pour_perfect")}), "drinks", true))
			var nxt := next_new_drink()
			if nxt == "":
				rows.append(_row("try", "venue.sheet.bar.try", "", "drinks", false, T.t("venue.sheet.bar.try_done")))
			else:
				rows.append(_row("try", "venue.sheet.bar.try", T.t("venue.sheet.bar.try_sub", {"drink": BarMenu.name_of(nxt)}), "drinks", false, no_alc))
			rows.append(_row("mocktail", "menu.bar.soft", BarMenu.t("menu.bar.soft_sub", {"drink": BarMenu.name_of(SOFT_DRINK)}), "drinks"))
			rows.append(_row("water", "venue.sheet.bar.water", T.t("venue.sheet.bar.water_sub"), "drinks"))
```
and after the stool row (after line 132) add:
```gdscript
			rows.append(_row("kitchen", "menu.bar.kitchen", BarMenu.t("menu.bar.kitchen_sub", {"n": BarMenu.items("kitchen").size()}), ""))
```
with two consts near BARTENDER: `const HOUSE_DRINK := "house_shooter"` and `const SOFT_DRINK := "coke"`.
`_row()` builds the title with `T.t(title_key)`; `T.t` goes through TranslationServer, and BarMenu installs the
menu CSV into it, so `menu.bar.*` title keys resolve as long as `BarMenu.t()` ran once (it does in the sub-line
of the same rows). If you prefer, call `BarMenu.install_strings()` at the top of `rows_for()`.

e) `next_new_drink()` (line 240): `for d in MENU:` → `for d in BarMenu.try_order():`

f) `do_row()`:
```gdscript
		"order":
			_drink(now, true, BarMenu.t("menu.card.order", {"who": _name(BARTENDER), "drink": BarMenu.name_of(HOUSE_DRINK)}))
		"mocktail":
			_drink(now, false, BarMenu.t("menu.card.soft", {"drink": BarMenu.name_of(SOFT_DRINK)}))
```
in "try": `T.t("venue.card.try", {"drink": T.t("venue.drink." + d)})` → `T.t("venue.card.try", {"drink": BarMenu.name_of(d)})`
"pour" becomes:
```gdscript
		"pour":
			_request("pour_perfect", {"drink": BarMenu.pour_pick(pours_this_visit, tipsy.state() == Tipsiness.MERRY)})
			pours_this_visit += 1
		"menu":
			menu_requested.emit("drinks")
		"kitchen":
			menu_requested.emit("kitchen")
```
g) New public function after `_drink()` (around line 311):
```gdscript
## Orders one item from the real menu (main.gd, menu list). Same effects as the rows: alcohol = Order a drink,
## soft = the soft-drink row, water = the water row; kitchen items do nothing yet. False if refused.
func order_item(id: String) -> bool:
	var now: float = needs.real_now()
	match BarMenu.effect(id):
		"alcohol":
			if tipsy.state() == Tipsiness.MERRY:
				return false
			_drink(now, true, BarMenu.t("menu.card.order", {"who": _name(BARTENDER), "drink": BarMenu.name_of(id)}))
		"soft":
			_drink(now, false, BarMenu.t("menu.card.soft", {"drink": BarMenu.name_of(id)}))
		"water":
			tipsy.water(now)
			_drink(now, false, BarMenu.t("menu.card.water"))
		_:
			return false
	return true
```

## 2. `game/scripts/main.gd` (shared; venue / start-screen edits uncommitted there)

a) consts: `const MenuList = preload("res://scripts/menu/menu_list.gd")`; var: `var menu_list: Control`
b) in `_ready` after `session.minigame_requested.connect(open_minigame)`:
   `session.menu_requested.connect(open_menu)`
c) `_blocked()`: add `or is_instance_valid(menu_list)`
d) new functions after `_on_row()`:
```gdscript
func open_menu(tab: String) -> void:
	if is_instance_valid(menu_list):
		return
	menu_list = MenuList.new()
	overlay.add_child(menu_list)
	menu_list.open(tab, session.tipsy.state() == VenueSession.Tipsiness.MERRY)
	menu_list.item_chosen.connect(func(id):
		close_menu()
		session.order_item(id))
	menu_list.closed.connect(close_menu)
	_sync_block()


func close_menu() -> void:
	if is_instance_valid(menu_list):
		menu_list.queue_free()
	menu_list = null
	_sync_block.call_deferred()
```
e) `_on_visit_finished`: add `close_menu()` next to `close_sheet()`.

## 3. `game/i18n/strings_venue.csv` (venue owns)
Delete the six `venue.drink.*` rows (106-111). Optional, since nothing reads them after 1c/1e:
`venue.sheet.bar.order_sub` ("The house cocktail"), `venue.sheet.bar.mocktail`, `venue.sheet.bar.mocktail_sub`,
`venue.card.mocktail` ("Thai iced tea") are no longer read. `venue.sheet.bar.greet_merry` / `venue.sheet.bar.merry`
say "mocktail": suggest "Water or a soft drink for now" (TH ตอนนี้ขอเป็นน้ำหรือซอฟต์ดริงก์ก่อน).

## Saves
`Needs.ext["drinks_tried"]` keeps the old ids; they no longer match, so every player's Try list starts fresh
with the six real drinks. No migration needed.

## After the edits
`test_menu` turns fully green (today: 2355 of 2362 pass; the 5 integration checks + 2 now fixed). I then run all
nine suites and take the captures (bar sheet + menu list + Pour Perfect with a real drink, portrait and landscape)
into `docs/art/screens/menu/`. I can make the edits myself on your go-ahead, or venue-notes can.
