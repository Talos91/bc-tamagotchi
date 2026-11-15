extends SceneTree
## Headless tests for Shake & Serve (docs/design/10-minigame-next.md §B): orders per night, real bottles from the menu,
## scoring, scripted bartenders, the shared bar tries, the Friends bonus, strings and the venue registry.
##   godot --headless --path . --script res://tests/test_shake_serve.gd
## Exit code 0 = all pass.

const Rules = preload("res://scripts/rules.gd")
const NeedsScript = preload("res://scripts/needs.gd")
const Base = preload("res://scripts/minigames/minigame_base.gd")
const S = preload("res://scripts/minigames/strings.gd")
const BarMenu = preload("res://scripts/menu/bar_menu.gd")
const CardScript = preload("res://scripts/minigames/result_card.gd")
const Game = preload("res://scripts/minigames/shake_serve.gd")
const Session = preload("res://scripts/zones/venue_session.gd")

const T0 := 1_800_000_000.0
const STEP := 1.0 / 120.0

var failures := 0
var checks := 0
var _result: Dictionary = {}


func _initialize() -> void:
	test_orders_and_bottles()
	test_scores()
	test_perfect_bartender()
	test_sloppy_bartender()
	test_tries_and_bonus()
	test_strings_registry()
	print("")
	print("%d checks, %d failed" % [checks, failures])
	print("SHAKE SERVE TESTS ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("  FAIL: ", msg)


func spawn(config := {"night": 100}) -> Control:
	var g: Control = Game.new()
	g.size = Vector2(1080, 1400)
	g.config = config
	root.add_child(g)
	_result = {}
	g.finished.connect(func(r: Dictionary) -> void: _result = r)
	g.start()
	return g


func adv(g: Control, secs: float) -> void:
	var t := 0.0
	while t < secs and not g.done:
		g.advance(STEP)
		t += STEP


func test_orders_and_bottles() -> void:
	print("[orders] three different mixes a round, same per night; real bottles for the spirits")
	var o := Game.pick_orders(100)
	check(o.size() == Game.ORDERS, "three orders")
	check(o[0] != o[1] and o[1] != o[2] and o[0] != o[2], "three different mixes")
	check(str(Game.pick_orders(100)) == str(o), "same night, same orders")
	check(str(Game.pick_orders(100, 1)) != str(o), "the next round of the visit brings others")
	for r in Game.RECIPES:
		check(str(r[1]) in Game.SPIRITS, "recipe %s starts with a spirit" % r[0])
		check(str(r[2]) in Game.MIXERS and str(r[3]) in Game.MIXERS, "recipe %s uses shelf mixers" % r[0])
	for fam in Game.SPIRITS:
		var b := Game.bottle_of(fam)
		check(b != "" and BarMenu.has(b), "a real menu bottle for %s (%s)" % [fam, b])


func test_scores() -> void:
	print("[score] recipe and shake parts")
	check(is_equal_approx(Game.order_score(0, [1.0, 1.0, 1.0, 1.0]), 1.0), "clean order = 1.0")
	check(is_equal_approx(Game.order_score(1, [1.0, 1.0, 1.0, 1.0]), 0.8), "one wrong bottle = 0.8")
	check(is_equal_approx(Game.order_score(5, [0.0, 0.0, 0.0, 0.0]), 0.0), "never below 0")
	check(Game.beat_accuracy(0.0) == 1.0 and Game.beat_accuracy(Game.BEAT_WINDOW) == 0.0, "beat window")
	check(Base.tier_for(Game.round_score([0.2, 0.2, 0.2])) == Base.TIER_MISS, "a sloppy round is a miss")


func play(g: Control, wrong_first: bool, on_beat: bool) -> void:
	var guard := 0
	while not g.done and guard < 20000:
		guard += 1
		match g.state:
			Game.State.PICK:
				if wrong_first and g.step == 0 and g.wrongs == 0:
					for id in Game.shelf():
						if id != g.wanted():
							g.pick(id)
							break
				g.pick(g.wanted())
			Game.State.SHAKE:
				var i: int = g.taps.size()
				if i < Game.BEATS and on_beat and g._state_t >= Game.nod_time(i):
					g.shake_tap()
		g.advance(STEP)


func test_perfect_bartender() -> void:
	print("[play] the right bottles and every nod")
	var g := spawn()
	play(g, false, true)
	check(g.done, "the round ends")
	check(g.order_scores.size() == Game.ORDERS, "three orders served")
	check(int(_result.get("tier", -9)) == 2, "perfect (%s)" % str(_result.get("score")))
	check(_result.get("action_id", "") == "pour_perfect", "feeds the bar's Drinks action")
	check(_result.get("game_id", "") == "shake_serve", "its own game id (best score)")
	check(_result.get("extra", {}).get("bonus_action", "") == "shake_serve_friends", "a great round earns the Friends bonus")
	g.queue_free()


func test_sloppy_bartender() -> void:
	print("[play] one wrong bottle each order and no shaking; idle times out")
	var g := spawn()
	play(g, true, false)
	check(g.done, "the round ends")
	var s := float(_result.get("score", 0.0))
	check(is_equal_approx(s, 0.4), "0.4 = recipe minus one bottle, no shake (%s)" % str(s))
	check(not _result.get("extra", {}).has("bonus_action"), "no bonus below great")
	g.queue_free()
	var h := spawn()
	adv(h, 90.0)
	check(h.done and bool(_result.get("miss", false)), "doing nothing times out to a miss")
	h.queue_free()


func test_tries_and_bonus() -> void:
	print("[needs] the bar's 3 tries are shared; the bonus lands on the card")
	check(Rules.MINIGAME_TRY_POOL.get("shake_serve", "") == "pour_perfect", "try pool: shake_serve uses pour_perfect's tries")
	var def: Dictionary = Rules.ACTIONS.get("shake_serve_friends", {})
	check(def.get("gains", {}).get("friends", 0.0) == 5.0, "bonus = Friends +5")
	var n: Node = NeedsScript.new()
	n.autosave = false
	n.time_override = T0
	n.save_path = "user://test_shake_serve_save.json"
	n.new_game()
	root.add_child(n)
	for m in n.meters:
		n.meters[m] = 20.0
	n.note_minigame_round("pour_perfect")
	n.note_minigame_round("shake_serve")
	check(n.minigame_tries_left("pour_perfect") == 1 and n.minigame_tries_left("shake_serve") == 1, "two rounds at the bar leave one try for both")
	var card: Control = CardScript.new()
	card.needs = n
	root.add_child(card)
	var before := float(n.meters["friends"])
	var out: Dictionary = card.apply({"game_id": "shake_serve", "action_id": "pour_perfect", "need_id": "drinks", "key": "",
		"title_key": "mg.shake_serve.title", "score": 0.9, "points": 90, "tier": 2, "miss": false,
		"extra": {"bonus_action": "shake_serve_friends"}})
	check(out.get("ok", false), "the card applies the round")
	check(float(n.meters["friends"]) > before, "the Friends bonus is applied with it")
	check(n.minigame_tries_left("pour_perfect") == 0, "the third bar round used the last shared try")
	card.queue_free()
	n.queue_free()


func test_strings_registry() -> void:
	print("[strings + registry]")
	var keys := {}
	for r in S.rows():
		keys[r["key"]] = r
	var need: Array[String] = []
	for suffix in ["title", "subtitle", "how_to", "tier_1", "tier_2", "tier_3", "status", "nam", "hint_memo", "hint_pick", "hint_shake", "served", "row", "row_sub"]:
		need.append("mg.shake_serve." + suffix)
	for r in Game.RECIPES:
		need.append("mg.shake_serve.order." + str(r[0]))
	for id in Game.SPIRITS + Game.MIXERS:
		need.append("mg.shake_serve.bottle." + str(id))
	for k in need:
		check(keys.has(k) and keys[k]["en"] != "" and keys[k]["th"] != "", "string " + k)
	check(Session.GAMES.has("shake_serve") and ResourceLoader.exists(Session.GAMES["shake_serve"]), "venue registry has the scene")
	check(Session.ROW_GAMES.get("shake", "") == "shake_serve", "the bar row counts its tries")
