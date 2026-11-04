extends SceneTree
## Pre-alpha debug panel: the actions (scripts/debug_tools.gd) clear a WASTED lockout, jump the clock by 1 h / 12 h /
## 1 night, make a ghost and revive it with the debug check-in, reset the save; and the panel on main.tscn works by
## touch (a screen touch on the Debug button opens it, a touch on Clear lockout clears the lockout) and is gone when
## Rules.PRE_ALPHA is false.
##   godot --headless --path . --script res://tests/test_debug_tools.gd

const Rules = preload("res://scripts/rules.gd")
const Tools = preload("res://scripts/debug_tools.gd")
const Nightlife = preload("res://scripts/zones/nightlife.gd")

var failed := 0

func check(c: bool, what: String) -> void:
	print(("ok   " if c else "FAIL ") + what)
	if not c:
		failed += 1

func touch_button(b: Button) -> void:
	# A headless viewport does not route GUI input, so do what the viewport does for a phone touch at the button's
	# centre: the topmost visible control under the point (the layer's last in draw order) must be this button (nothing
	# covers it), then the touch presses it.
	var pos := b.get_global_rect().get_center()
	var top: Control = null
	for c: Control in b.get_parent().get_parent().get_parent().find_children("*", "Control", true, false):
		if c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(pos):
			top = c
	if b.get_parent() is CanvasLayer:
		top = b
	check(top == b, "the touch at %s reaches the button %s" % [str(pos), b.text])
	if top == b and not b.disabled:
		b.pressed.emit()

func _init() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.new_game()
	check(Rules.PRE_ALPHA, "PRE_ALPHA is true in the pre-alpha builds")

	# lockout
	var line := Tools.force_wasted(needs)
	check(line >= 0 and Nightlife.locked(needs), "force WASTED locks the player out")
	check(absf(Nightlife.seconds_left(needs) - Rules.WASTED_LOCKOUT_HOURS * 3600.0) < 5.0, "lockout is 12 h")
	Tools.clear_lockout(needs)
	check(not Nightlife.locked(needs), "clear lockout: no longer locked")
	check(Nightlife.state(needs).get("wasted", 0) == 1, "clear lockout keeps the wasted count")

	# clock jumps
	var c0: float = needs.clock
	Tools.jump(needs, 3600.0)
	check(absf(needs.clock - c0 - 3600.0) < 5.0, "+1 hour moves the clock 1 h")
	c0 = needs.clock
	Tools.jump(needs, 12.0 * 3600.0)
	check(absf(needs.clock - c0 - 12.0 * 3600.0) < 5.0, "+12 hours moves the clock 12 h")
	c0 = needs.clock
	var k0: int = needs.night_key(c0)
	Tools.jump_night(needs)
	check(needs.night_key(needs.clock) == k0 + 1 and needs.clock > c0 and needs.clock - c0 <= 86400.0 + 5.0, "+1 night lands in the next bar night")
	Tools.force_wasted(needs)
	Tools.jump(needs, 12.0 * 3600.0 + 60.0)
	check(not Nightlife.locked(needs), "a 12 h jump runs the lockout out")

	# ghost and revival
	Tools.make_ghost(needs)
	check(needs.is_ghost() and needs.stake_stage == "ghost", "make ghost: the character is a ghost")
	Tools.fake_check_in(needs)
	check(not needs.is_ghost() and needs.lives == 2, "fake check-in revives the ghost (lives 2)")
	Tools.make_ghost(needs)
	Tools.fake_check_in(needs)
	check(not needs.is_ghost() and needs.lives == 3, "the debug check-in can revive again (cooldown lifted)")

	# the panel in the game, by touch
	needs.new_game()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var dbg: CanvasLayer = main.get_node_or_null("DebugPanel")
	check(dbg != null and dbg.toggle.visible, "the Debug button is on screen")
	if dbg != null:
		check(not dbg.panel.visible, "the panel starts closed")
		touch_button(dbg.toggle)
		await process_frame
		check(dbg.panel.visible, "a touch on Debug opens the panel")
		Tools.force_wasted(needs)
		dbg._refresh_status()
		var clear: Button = null
		for b: Button in dbg.panel.find_children("*", "Button", true, false):
			if b.text == "Clear lockout":
				clear = b
		check(clear != null, "Clear lockout button exists")
		await process_frame
		if clear != null:
			touch_button(clear)
			await process_frame
			check(not Nightlife.locked(needs), "a touch on Clear lockout clears the lockout")
		check(dbg.reset_btn.text == "Reset save", "reset starts unarmed")
		dbg._reset()
		check(dbg._reset_armed and dbg.reset_btn.text.begins_with("Tap again"), "reset asks for confirmation first")
	main.queue_free()
	print("TEST DEBUG TOOLS ", "PASS" if failed == 0 else "FAIL (%d)" % failed)
	quit(0 if failed == 0 else 1)
