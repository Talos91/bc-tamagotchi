extends SceneTree
## Screenshots of main.tscn in a real window (not headless). Run from game/, one size per run:
##   godot --path . --resolution 540x960 --script res://tools/capture_venue.gd -- --tag=portrait
##   godot --path . --resolution 960x540 --script res://tools/capture_venue.gd -- --tag=landscape
## (half of 1080x1920 and 1920x1080; orientation is undecided, so both are captured.)
## Writes <tag>-<shot>.png to docs/art/screens/v4/ (override with --out=DIR): the diorama
## gameplay camera in each zone, then eye-level cameras that show the ceiling, placed like the direction renders.
## The player and the patron crowd (Venue/Patrons) are in every shot.
## Prints the average frame rate per gameplay shot (vsync off).

const SHOTS := [
	{"name": "lobby", "player": Vector3(1.2, 0, 7.2)},
	{"name": "corridor", "player": Vector3(8.0, 0, 14.1)},
	{"name": "lounge", "player": Vector3(7.5, 0, 6.5)},
	{"name": "buffer", "player": Vector3(17.7, 0, 5.3)},
	{"name": "floor", "player": Vector3(30.0, 0, 6.7)},
	{"name": "bar", "player": Vector3(29.6, 0, 11.3)},
	{"name": "stage", "player": Vector3(30.75, 0, 6.3)},
	{"name": "raised", "player": Vector3(40.4, 0.15, 6.1)},
	{"name": "toilets", "player": Vector3(22.3, 0, 15.8)},
	{"name": "smoking", "player": Vector3(40.0, 0, 15.2)},
	{"name": "alcove-walk", "player": Vector3(17.0, 0, 11.25)},
]
## Eye-level views matched to the real photos (docs/art/direction): 09 bar from the west end, 11 the raised east
## side from its south end, 14 the buffer zone's south (mirror) side looking at the window, 20 the smoking room's
## window side looking at the emergency exit.
const EYE := [
	{"name": "eye-P09-bar", "from": Vector3(22.6, 1.5, 11.6), "at": Vector3(33.0, 0.9, 13.6), "fov": 62.0, "player": Vector3(27.0, 0, 10.8)},
	{"name": "eye-P11-raised", "from": Vector3(40.2, 1.5, 10.6), "at": Vector3(38.6, 1.3, 1.0), "fov": 64.0, "player": Vector3(38.0, 0, 7.0)},
	{"name": "eye-P14-buffer", "from": Vector3(17.8, 1.4, 7.4), "at": Vector3(17.8, 1.1, 2.6), "fov": 66.0, "player": Vector3(16.6, 0, 5.4)},
	{"name": "eye-P20-smoking", "from": Vector3(39.4, 1.6, 13.2), "at": Vector3(40.2, 1.0, 18.0), "fov": 66.0, "player": Vector3(39.9, 0, 15.3)},
]

## Close views after the door and seat shots: doors [from, at]; seats [Vector3(turn degrees from the seat's facing,
## height above the chest, distance), unused] around the seated player.
const CLOSE := {
	"door-sticker": [Vector3(11.7, 2.1, 14.7), Vector3(13.65, 1.0, 13.2)],
	"door-red": [Vector3(37.5, 2.1, 10.5), Vector3(39.6, 1.0, 12.9)],
	"sit-table": [Vector3(40.0, 0.9, 2.3), Vector3.ZERO],
	"sit-couch": [Vector3(30.0, 0.9, 2.2), Vector3.ZERO],
	"sit-bar": [Vector3(-100.0, 0.7, 1.9), Vector3.ZERO],
}
## Stair (Daniele's note on v4): straight down on it, at eye level from the lounge with the player on the landing,
## and a low look along the neon edge under the raised strip.
const STAIR := [
	{"name": "stair-top", "from": Vector3(6.2, 13.0, 10.6), "at": Vector3(6.2, 0.0, 10.59), "fov": 50.0, "player": Vector3(3.2, 1.6, 12.2)},
	{"name": "stair-eye", "from": Vector3(8.4, 1.8, 5.6), "at": Vector3(4.6, 1.3, 11.8), "fov": 66.0, "player": Vector3(3.2, 1.6, 12.2)},
	{"name": "neon-edge", "from": Vector3(36.5, 2.2, 11.0), "at": Vector3(39.45, 0.1, 6.5), "fov": 55.0, "player": Vector3(38.2, 0, 3.6)},
]

func _init() -> void:
	var tag := "shot"
	var out := "res://../docs/art/screens/v4"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var needs := root.get_node_or_null("Needs")
	if needs:
		needs.autosave = false
	var p: Player = main.get_node("Player")
	main.get_node("UI").visible = false
	for s in SHOTS:
		p.global_position = s.player
		p.velocity = Vector3.ZERO
		p.rig.snap()
		for i in 30:
			await process_frame
		var t0 := Time.get_ticks_usec()
		var frames := 0
		var gpu := 0.0
		var cpu := 0.0
		while Time.get_ticks_usec() - t0 < 2000000:
			await process_frame
			frames += 1
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		var fps := frames / ((Time.get_ticks_usec() - t0) / 1e6)
		await _save(out, tag, s.name)
		print("%s %s zone=%s fps=%.0f gpu=%.2fms render_cpu=%.2fms draw_calls=%d" % [tag, s.name, p.rig.zone, fps, gpu / frames, cpu / frames,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	# HUD check: joystick and needs debug HUD over the floor view
	main.get_node("UI").visible = true
	p.global_position = Vector3(30.0, 0, 6.7)
	p.rig.snap()
	for i in 30:
		await process_frame
	await _save(out, tag, "hud")
	main.get_node("UI").visible = false
	var cam := Camera3D.new()
	main.add_child(cam)
	for e in EYE:
		cam.fov = e.fov
		cam.keep_aspect = Camera3D.KEEP_HEIGHT if root.get_visible_rect().size.aspect() >= 1.0 else Camera3D.KEEP_WIDTH
		cam.look_at_from_position(e.from, e.at)
		cam.make_current()
		p.global_position = e.player
		p.velocity = Vector3.ZERO
		for i in 20:
			await process_frame
		await _save(out, tag, e.name)
	# Playtest notes on v4 (doors, sitting, stairs): gameplay camera shots set up through the game's own code,
	# then a top-down and an eye-level view of the stair and a low view of the neon edge under the raised strip
	cam.clear_current()
	var doors: Node = main.get_node("Venue/Doors")
	var s: VenueSession = main.session
	for n in ["door-sticker", "door-red", "sit-table", "sit-couch", "sit-bar", "alcove"]:
		p.stand_up()
		doors.set_process(true)
		match n:
			"door-sticker":
				p.global_position = Vector3(13.65, 0, 13.85)
				p.get_node("Body").rotation.y = PI
			"door-red":
				p.global_position = Vector3(39.6, 0, 12.15)
				p.get_node("Body").rotation.y = 0.0
			"sit-table", "sit-bar":
				var z: Dictionary = main.zones.first_of("table" if n == "sit-table" else "bar", true if n == "sit-table" else false)
				p.global_position = z["approach"] + Vector3(0, 0.1, 0)
				for i in 10:
					await process_frame
				s.do_row(z, "sit" if n == "sit-table" else "stool")
			"sit-couch":
				for seat in get_nodes_in_group("seat"):
					if seat.get_meta("table", "") == "Raised1" and seat.get_meta("couch", false):
						p.global_position = Vector3(40.7, 0.25, seat.global_position.z)
						p.sit_at({"node": seat, "pos": seat.global_position, "yaw": seat.global_rotation.y, "h": float(seat.get_meta("seat_h")),
							"couch": true, "table": "Raised1", "pose": "sit_hold"})
						break
			"alcove":
				p.global_position = Vector3(17.7, 0, 11.25)
		p.velocity = Vector3.ZERO
		p.rig.snap()
		for i in 240:
			await process_frame
			if not n.begins_with("sit") or p.seated:
				break
		for i in 30:
			await process_frame
		if n.begins_with("door"):   # mid-swing, away from the player
			doors.set_process(false)
			var dn := "StickerDoor" if n == "door-sticker" else "RedDoor"
			var c: Vector3 = doors.doors.filter(func(d): return d.node.name == dn)[0].center
			doors.pose(dn, 0.55, c * 2.0 - p.global_position)
			await process_frame
		await _save(out, tag, n)
		print("%s %s zone=%s seated=%s" % [tag, n, p.rig.zone, p.seated])
		if CLOSE.has(n):   # the same moment up close, at eye level
			var c: Array = CLOSE[n]
			var from: Vector3 = c[0]
			var at: Vector3 = c[1]
			if n.begins_with("sit"):   # around the seated player: in front of them, turned c[0].x degrees
				var yaw: float = p.get_node("Body").rotation.y + deg_to_rad(c[0].x)
				at = p.global_position + Vector3(0, 0.75, 0)
				from = at + Basis(Vector3.UP, yaw) * Vector3(0, 0, c[0].z) + Vector3(0, c[0].y, 0)
			cam.fov = 60.0
			cam.keep_aspect = Camera3D.KEEP_HEIGHT if root.get_visible_rect().size.aspect() >= 1.0 else Camera3D.KEEP_WIDTH
			cam.look_at_from_position(from, at)
			cam.make_current()
			for i in 5:
				await process_frame
			await _save(out, tag, n + "-close")
			cam.clear_current()
	doors.set_process(true)
	p.stand_up()
	cam.cull_mask &= ~(1 << 1)   # no ceiling over the stair views
	for e in STAIR:
		cam.fov = e.fov
		cam.keep_aspect = Camera3D.KEEP_HEIGHT if root.get_visible_rect().size.aspect() >= 1.0 else Camera3D.KEEP_WIDTH
		cam.look_at_from_position(e.from, e.at, Vector3.FORWARD if e.from.y > 10.0 else Vector3.UP)
		cam.make_current()
		p.global_position = e.player
		p.velocity = Vector3.ZERO
		for i in 20:
			await process_frame
		await _save(out, tag, e.name)
	print("CAPTURE DONE ", out)
	quit()

func _save(out: String, tag: String, nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out.path_join("%s-%s.png" % [tag, nm]))
