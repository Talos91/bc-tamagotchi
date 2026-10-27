extends SceneTree
## Headless smoke test: main.tscn boots with the Needs autoload and the debug HUD, the HUD opens and an action runs.
##   godot --headless --path . --script res://tests/smoke_hud.gd

func _init() -> void:
	await process_frame  # autoloads finish _ready after _init
	var needs: Node = root.get_node_or_null("Needs")
	if needs == null:
		print("SMOKE HUD FAIL: Needs autoload missing")
		quit(1)
		return
	needs.autosave = false
	needs.new_game()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var hud: Control = main.get_node_or_null("UI/NeedsDebug")
	var ok := hud != null
	if ok:
		hud._toggle.pressed.emit()
		ok = hud._panel.visible
		var before: float = needs.meters["drinks"]
		needs.meters["drinks"] = 20.0
		hud._do_action("order_drink")
		await process_frame
		ok = ok and needs.meters["drinks"] > 20.0 and hud._bars["drinks"].value > 20.0
		hud._clock_btn.pressed.emit()
		ok = ok and needs.multiplier == 60.0
		print("hud drinks bar: ", hud._bars["drinks"].value, " (was ", before, "), multiplier ", needs.multiplier)
	print("SMOKE HUD ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
