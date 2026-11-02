extends SceneTree
## Look-D follow-ups (Daniele 2026-11-02, DECISIONS "Questions tab, answered 07:35-08:19"): before|after captures of
## the areas the six follow-ups touch, the game's own views with the HUD on, as capture_look_build.gd takes them.
## Views: floor, stage, bar, dark and dark-aisle (the darkest floor patches of the main room, found by --sweep), corridor-west,
## lobby, board (the lounge's Top patrons board), north-west (the sconces on the neon line). Landscape: floor, stage,
## bar, board, cashier, library, band-door. Each shot prints the frame luma and the luma of a box around the player (as capture_look_build.gd).
## --sweep instead walks the player over the main room's walkable floor (1.5 m grid, every spot snapped to the navmesh)
## and prints the player luma per spot, darkest first: that is how DARK_SPOT was chosen.
## From game/, windowed (headless renders nothing):
##   godot --path . --script res://tests/capture_look_followups.gd -- --tag=portrait --out=<dir> [--only=floor,dark]
## Writes <view>.png (landscape-<view>.png) to docs/art/screens/look-followups/after/ by default.

## --sweep on 82ef3e6 (before the follow-ups): the darkest walkable patch (beside the stage, by the backstage door; player
## luma 0.029) and the darkest open floor between the candle pools (the west opening, 0.057)
const DARK_SPOT := Vector3(26.8, 0.1, 0.8)
const DARK_AISLE := Vector3(20.92, 0.1, 8.09)

const VIEWS := [
	{"name": "floor", "player": Vector3(30.0, 0.1, 7.0), "yaw": PI * 0.5, "main": true},
	{"name": "stage", "area": "stage", "main": true},
	{"name": "bar", "area": "bar", "main": true},
	{"name": "dark", "player": DARK_SPOT, "yaw": PI * 0.5},
	{"name": "dark-aisle", "player": DARK_AISLE, "yaw": PI * 0.5},
	{"name": "corridor-west", "player": Vector3(3.4, 0.1, 14.05), "yaw": -PI * 0.5},
	{"name": "lobby", "player": Vector3(1.1, 0.1, 12.0), "yaw": PI},
	{"name": "board", "player": Vector3(6.2, 0.1, 9.2), "yaw": -PI * 0.5, "main": true},
	{"name": "north-west", "player": Vector3(24.0, 0.1, 3.2), "yaw": 0.0},
	# Owner feedback 2026-11-02 (handoffs/owner-feedback-2026-11-02.md): 3 the bay beside the reindeer, 9 the library
	# behind the couch, 10 the band door
	{"name": "cashier", "player": Vector3(29.65, 0.1, 11.4), "yaw": PI, "main": true},
	{"name": "library", "player": Vector3(40.4, 0.25, 5.9), "yaw": PI * 0.5, "main": true},
	{"name": "band-door", "player": Vector3(25.9, 0.1, 1.0), "yaw": 0.0, "main": true},
]

var out := "res://../docs/art/screens/look-followups/after"
var tag := "portrait"
var only: PackedStringArray = []
var sweep := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
		elif a == "--sweep":
			sweep = true
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	var full := Vector2i(1080, 1920) if tag == "portrait" else Vector2i(1920, 1080)
	root.size = full / 2
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = full
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_look_followups_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	var p: Player = main.player
	var body: Node3D = p.get_node("Body")
	if sweep:
		await _sweep(p, body)
		quit()
		return
	for v in VIEWS:
		if not only.is_empty() and not only.has(v.name):
			continue
		if tag != "portrait" and not v.get("main", false):
			continue
		if v.has("area"):
			_place(p, body, Vector3(30.0, 0.1, 7.0), PI * 0.5)
			await _wait(0.8)
			main.walk_to_area(v.area)
			for i in 1500:
				await process_frame
				if not p.walking_to and main.pending_zone == "":
					break
			await _wait(0.2)
			if is_instance_valid(main.sheet):
				main.close_sheet()
			await _wait(1.6)
		else:
			_place(p, body, v.player, v.yaw)
			await _wait(1.8)
		paused = true
		await _wait(0.15)
		var img := await _grab()
		var nm: String = v.name if tag == "portrait" else "landscape-" + v.name
		var path := out.path_join(nm + ".png")
		img.save_png(path)
		var lum := _lumas(img, p)
		print("saved %s %s  frame luma %.3f  player luma %.3f" % [path, img.get_size(), lum.x, lum.y])
		paused = false
	quit()


## Every walkable spot of the main room on a 1.5 m grid (snapped to the navmesh, spots off it skipped): player luma.
func _sweep(p: Player, body: Node3D) -> void:
	var map := p.get_world_3d().navigation_map
	var res := []
	var x := 20.8
	while x < 41.5:
		var z := 0.8
		while z < 12.4:
			var q := NavigationServer3D.map_get_closest_point(map, Vector3(x, 0.1, z))
			if Vector2(q.x - x, q.z - z).length() < 0.3:
				_place(p, body, Vector3(q.x, 0.1, q.z), PI * 0.5)
				await _wait(0.9)
				var img := await _grab()
				res.append([_lumas(img, p).y, Vector3(q.x, 0.1, q.z)])
			z += 1.5
		x += 1.5
	res.sort_custom(func(a, b): return a[0] < b[0])
	for r in res.slice(0, 12):
		print("sweep player luma %.3f at %s" % [r[0], r[1]])


func _grab() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()


## x: mean luma of the frame; y: of a box around the player's figure (it includes the floor around them)
func _lumas(img: Image, p: Player) -> Vector2:
	var cam := root.get_viewport().get_camera_3d()
	var s := img.get_size()
	var scale := float(s.y) / float(root.get_visible_rect().size.y) if root.get_visible_rect().size.y > 0 else 1.0
	var c := cam.unproject_position(p.global_position + Vector3(0, 0.8, 0)) * scale
	var r := int(s.y * 0.045)
	return Vector2(_luma(img, Rect2i(0, 0, s.x, s.y)), _luma(img, Rect2i(int(c.x) - r, int(c.y) - r * 2, r * 2, r * 4)))


static func _luma(img: Image, r: Rect2i) -> float:
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x <= 0 or r.size.y <= 0:
		return -1.0
	var sum := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y, 4):
		for x in range(r.position.x, r.end.x, 4):
			var col := img.get_pixel(x, y)
			sum += 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b
			n += 1
	return sum / maxf(n, 1)


func _place(p: Player, body: Node3D, at: Vector3, yaw: float) -> void:
	p.stand_up()
	p.walking_to = false
	p.global_position = at
	p.velocity = Vector3.ZERO
	body.global_rotation = Vector3(0, yaw, 0)
	p.rig.snap()
