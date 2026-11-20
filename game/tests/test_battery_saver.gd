extends SceneTree
## Headless test of the iPhone round (perf-iphone 2026-11-20): the battery saver's frame pacing (scripts/frame_pacer.gd,
## autoload FramePacer: 30 / 15 a second, off off the web), the full-screen button (scenes/ui/fullscreen_button.gd:
## hidden off the web, its strings in both languages) and the static merge (venue_batch.gd merge_static: chunks made,
## each paired with at most 8 lights, so no pixel loses a light).
##   godot --headless --path . --script res://tests/test_battery_saver.gd

const Pacer = preload("res://scripts/frame_pacer.gd")
const VenueBatch = preload("res://scripts/venue_batch.gd")
const U = preload("res://scripts/ui/ui_strings.gd")

var fails: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails.append(what)


func _draws(fps: float, hz: float, n: int) -> int:
	var acc := 0.0
	var d := 0
	for i in n:
		var r := Pacer.pace(acc, 1.0 / hz, fps)
		acc = r.x
		d += int(r.y)
	return d


func _init() -> void:
	await process_frame
	print("frame pacing")
	var fp: Node = root.get_node_or_null("FramePacer")
	check(fp != null, "autoload FramePacer is registered")
	if fp != null:
		check(not fp.saver and fp.target_fps() == 0.0, "off outside the web build (desktop, tests)")
		fp.set_saver(true)
		check(fp.target_fps() == 0.0, "never caps off the web, even when switched on")
		fp.set_saver(false)
		check(RenderingServer.render_loop_enabled, "switching it off leaves drawing on")
		check(fp.describe() == "battery saver off", "describe() for the perf report")
	check(_draws(30.0, 60.0, 600) == 300, "60 Hz screen, 30 fps: every second refresh draws (%d of 600)" % _draws(30.0, 60.0, 600))
	check(_draws(15.0, 60.0, 600) == 150, "60 Hz screen, 15 fps idle: every fourth (%d of 600)" % _draws(15.0, 60.0, 600))
	var d120 := _draws(30.0, 120.0, 1200)
	check(d120 >= 295 and d120 <= 305, "120 Hz screen, 30 fps: ~300 of 1200 (%d)" % d120)

	print("full-screen button")
	var fb: Button = load("res://scenes/ui/fullscreen_button.gd").new()
	root.add_child(fb)
	await process_frame
	check(not fb.visible, "hidden off the web")
	check(fb.name == "FullscreenButton", "named for the HUD")
	for k in ["ui.fullscreen.button", "ui.fullscreen.ios_hint"]:
		check(U.t(k) != k and U.t(k) != "", "string %s exists" % k)
	check(U.t("ui.fullscreen.ios_hint").contains("Home Screen"), "iPhone hint says Add to Home Screen")
	fb.queue_free()

	print("static merge")
	check(VenueBatch.MERGE_STATIC, "merge_static is on")
	var venue: Node3D = load("res://scenes/venue/venue.tscn").instantiate()
	root.add_child(venue)
	for i in 150:   # the merge is sliced over frames
		await process_frame
	var lights: Array[AABB] = []
	for l in venue.find_children("*", "Light3D", true, false):
		if not l is DirectionalLight3D:
			lights.append((l as Light3D).global_transform * (l as Light3D).get_aabb())
	var chunks := venue.find_children("Merged_*", "MeshInstance3D", true, false)
	check(chunks.size() > 100, "venue merged into chunks (%d)" % chunks.size())
	var over := 0
	for c: MeshInstance3D in chunks:
		if VenueBatch._lights_of(c.global_transform * c.get_aabb(), lights).size() > VenueBatch.MAX_LIGHTS:
			over += 1
	check(over == 0, "every chunk pairs with at most %d lights (%d over)" % [VenueBatch.MAX_LIGHTS, over])
	var still := 0
	for mi: MeshInstance3D in venue.find_children("*", "MeshInstance3D", true, false):
		if mi.layers == 0 and mi.mesh != null and mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			still += 1
	check(still == 0, "a retired original never casts from layer 0 (shadow-only instead) (%d)" % still)
	venue.queue_free()
	await process_frame

	print("%d failed" % fails.size())
	print("BATTERY SAVER TESTS " + ("PASS" if fails.is_empty() else "FAIL"))
	quit(0 if fails.is_empty() else 1)
