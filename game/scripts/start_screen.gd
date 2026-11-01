extends Node
## Start screen and entry (BACKLOG B8, Daniele 2026-11-01): the game opens on a still, first-person view from the
## pavement across from the club's street door, the BLACK CABIN neon lit above it (scenes/street/street_front.gd),
## with the title and "Tap to enter". A tap, click, Enter or Space walks the character in: they step out from under
## the camera, the street door swings open for them (venue_doors.gd, as for anyone who comes near), the camera
## follows at eye height just behind their head through the doorway, then pulls back and up into the diorama camera
## of the lobby zone while the door swings shut; main.gd's `start_play()` fades the HUD in and starts the visit as
## it starts without a start screen. About 5 s. Any further tap skips to the end.
##
## While it runs the visit has not begun (Needs.begin_visit waits for start_play), the HUD and joystick are hidden
## and VenueSession (house band, sit minute) does not process; the save has already loaded. The street is hidden,
## lights included, once the camera turns into the lobby, so the venue keeps its own light count.
## main.gd adds this when main.tscn runs as the game; tests set `main.intro = true` (tests/smoke_start.gd).
## Debug builds: Esc on the start screen goes straight in. Command line: `-- --skip-intro` never shows it.

const StreetFront = preload("res://scenes/street/street_front.gd")
const UI = preload("res://scripts/minigames/mg_ui.gd")
const T = preload("res://scripts/zones/venue_strings.gd")

const EYE_H := 1.6          ## on the start screen (standing across the street)
const FOLLOW_H := 1.75       ## while following: just above and behind the head (the character is 1.35 m)
const FOLLOW := 1.3          ## camera this far behind the walker outside ...
const FOLLOW_IN := 0.6       ## ... closing to this once through the door, so it ends inside the lobby
const SHOULDER := 0.3        ## over the right shoulder outside (the doorway shows past the head), centred inside
const WALK_TIME := 3.3       ## street to the lobby spawn
const ACCEL_TIME := 0.4
const DECEL_TIME := 0.6
const PULL_TIME := 1.7       ## eye height inside the door to the lobby's diorama camera
const FADE_TIME := 0.35      ## title fading out after the tap
const CEILING_LAYER_MASK := 1 << 1

enum Phase { TITLE, WALK, PULL, DONE }

var main: Node                 ## main.gd
var street: Node3D
var cam: Camera3D
var phase := Phase.TITLE
var door_max_open := 0.0       ## how far the street door opened during the entry (tests)
var _t := 0.0                  ## seconds since the tap
var _from: Vector3             ## walk start (behind the camera)
var _to: Vector3               ## walk end (main's spawn)
var _cam0: Vector3
var _pull_from: Transform3D
var _pull_look: Vector3        ## what the camera looked at when the pull-back began
var _pull_fov := 0.0
var _layer: CanvasLayer
var _screen: Control
var _title: Label
var _prompt: Label
var _locale := ""
var _tap_guard := 0


func begin(m: Node) -> void:
	main = m
	var p: Player = main.player
	var doors := _doors()
	var center := Vector3(-0.1, 0, 7.2)
	for d in (doors.doors if doors else []):
		if (d.node as Node).name == "StreetDoor":
			center = d.center
	street = StreetFront.new()
	street.name = "Street"
	main.add_child(street)
	street.build(center)
	_cam0 = Vector3(street.far_pave_x, EYE_H, center.z)
	_from = Vector3(_cam0.x - 0.1, 0.0, center.z)
	_to = main._spawn.origin
	_to.y = 0.0
	# The character waits out of sight under the camera; the diorama rig stays put until the pull-back
	p.input_enabled = false
	p.set_physics_process(false)
	p.velocity = Vector3.ZERO
	p.global_transform = Transform3D(Basis.IDENTITY, _from)
	p.get_node("Body").rotation.y = PI * 0.5
	p.figure.move_speed = 0.0
	p.figure.play("idle")
	p.visible = false
	p.rig.set_process(false)
	main.session.process_mode = Node.PROCESS_MODE_DISABLED
	cam = Camera3D.new()
	cam.name = "StartCamera"
	cam.near = 0.05
	cam.far = 80.0
	main.add_child(cam)
	cam.make_current()
	_place_title_camera()
	_build_ui()


# --- Input ---------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if phase == Phase.DONE:
		return
	var go := false
	if event is InputEventScreenTouch and event.pressed:
		go = true
	elif event is InputEventMouseButton and event.pressed:
		go = true   # also arrives as ScreenTouch (emulate_touch_from_mouse); _tap_guard drops the twin
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E:
				go = true
			KEY_ESCAPE:
				if OS.is_debug_build():
					get_viewport().set_input_as_handled()
					skip()
				return
	if go:
		get_viewport().set_input_as_handled()
		if Engine.get_process_frames() != _tap_guard:
			_tap_guard = Engine.get_process_frames()
			tap()


## Tap on the start screen: walk in. Any tap after that: skip to the end.
func tap() -> void:
	match phase:
		Phase.TITLE:
			_start_walk()
		Phase.WALK, Phase.PULL:
			skip()


# --- Sequence ------------------------------------------------------------------------------------

func _start_walk() -> void:
	phase = Phase.WALK
	_t = 0.0
	main.player.visible = true
	create_tween().tween_property(_screen, "modulate:a", 0.0, FADE_TIME)


func _process(delta: float) -> void:
	if phase == Phase.DONE:
		return
	var portrait := _portrait()
	if phase == Phase.TITLE:
		_place_title_camera()
		if TranslationServer.get_locale() != _locale:
			_retitle()
		return
	_t += delta
	var doors := _doors()
	if doors:
		door_max_open = maxf(door_max_open, doors.openness("StreetDoor"))
	var p: Player = main.player
	if phase == Phase.WALK:
		var s := _walk_s(minf(_t, WALK_TIME))
		var pos := _from.lerp(_to, s)
		p.global_position = pos
		p.figure.move_speed = _walk_speed(_t)
		p.figure.play("walk" if p.figure.move_speed > 0.3 else "idle")
		# Just behind and above the head; looking up at the sign from across the street, level through the door
		var inside := clampf((pos.x - (street.face_x - 0.5)) / 1.5, 0.0, 1.0)
		var cx := maxf(_cam0.x, pos.x - lerpf(FOLLOW, FOLLOW_IN, smoothstep(0.0, 1.0, inside)))
		var k := clampf((cx - _cam0.x) / (street.face_x - 0.8 - _cam0.x), 0.0, 1.0)
		var pitch := lerpf(_title_pitch(portrait), -8.0 if portrait else -11.0, smoothstep(0.0, 1.0, k))
		cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(pitch), -PI * 0.5, 0)),
			Vector3(cx, lerpf(EYE_H, FOLLOW_H, smoothstep(0.0, 0.3, k)), _cam0.z + SHOULDER * smoothstep(0.0, 0.25, k) * (1.0 - inside)))
		_set_fov(portrait, lerpf(_title_fov(portrait), _title_fov(portrait) - 2.0, k))
		cam.cull_mask = 0xFFFFF
		if _t >= WALK_TIME:
			_start_pull()
	elif phase == Phase.PULL:
		var u := minf((_t - WALK_TIME) / PULL_TIME, 1.0)
		var e := smoothstep(0.0, 1.0, u)
		var rc: Camera3D = p.rig.camera
		# Up first, then back: the height eases out, the rest eases in-out; the camera keeps looking at a point
		# that slides from ahead of the character to the diorama camera's own look point (on the character)
		var a := _pull_from.origin
		var b := rc.global_position
		var head := p.global_position + Vector3(0, 1.2, 0)
		var look_end := b - rc.global_basis.z * b.distance_to(head)
		var look := _pull_look.lerp(look_end, smoothstep(0.0, 0.6, u))
		var o := Vector3(lerpf(a.x, b.x, e), lerpf(a.y, b.y, 1.0 - pow(1.0 - u, 2.2)), lerpf(a.z, b.z, smoothstep(0.15, 1.0, u)))
		if u >= 1.0:
			cam.global_transform = rc.global_transform
		else:
			cam.global_transform = Transform3D(Basis.looking_at(look - o, Vector3.UP), o)
		cam.keep_aspect = rc.keep_aspect
		cam.fov = lerpf(_pull_fov, rc.fov, e)
		# The diorama camera never draws the ceiling: drop it once the camera rises to it
		cam.cull_mask = rc.cull_mask if cam.global_position.y > 3.6 else 0xFFFFF
		if e >= 1.0:
			_finish()


## Arrived at the spawn: hand the camera over to the diorama rig with a pull back and up.
func _start_pull() -> void:
	phase = Phase.PULL
	var p: Player = main.player
	_arrive_player()
	p.rig.snap()
	p.rig.set_process(true)
	_pull_from = cam.global_transform
	_pull_look = cam.global_position - cam.global_basis.z * 1.8
	_pull_fov = cam.fov
	# The camera faces into the lobby now, the street behind it: off with it (and its two lights)
	street.set_on(false)


func _arrive_player() -> void:
	var p: Player = main.player
	var sp: Transform3D = main._spawn
	p.global_transform = Transform3D(sp.basis, Vector3(sp.origin.x, _to.y + 0.02, sp.origin.z))
	p.get_node("Body").global_rotation = Vector3(0, PI * 0.5, 0)
	p.figure.move_speed = 0.0
	p.figure.play("idle")
	p.velocity = Vector3.ZERO


## Second tap: everything as at the end of the sequence, now.
func skip() -> void:
	if phase == Phase.DONE:
		return
	main.player.visible = true
	_arrive_player()
	var doors := _doors()
	if doors:
		for d in doors.doors:
			if (d.node as Node).name == "StreetDoor":
				d.hold = 0.0
		doors.pose("StreetDoor", 0.0, Vector3.ZERO)
	street.set_on(false)
	main.player.rig.snap()
	main.player.rig.set_process(true)
	_finish()


func _finish() -> void:
	phase = Phase.DONE
	var p: Player = main.player
	p.rig.camera.make_current()
	p.set_physics_process(true)
	if is_instance_valid(cam):
		cam.queue_free()
	if is_instance_valid(_layer):
		_layer.queue_free()
	queue_free()
	main.start_play()


# --- Camera --------------------------------------------------------------------------------------

func _portrait() -> bool:
	return get_viewport().get_visible_rect().size.aspect() < 1.0


## Portrait frames width (a tall view up the facade to the sky); landscape frames height (door and sign).
func _title_fov(portrait: bool) -> float:
	return 62.0 if portrait else 54.0


func _title_pitch(portrait: bool) -> float:
	return 13.0 if portrait else 9.0


func _set_fov(portrait: bool, fov: float) -> void:
	cam.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	cam.fov = fov


func _place_title_camera() -> void:
	var portrait := _portrait()
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(_title_pitch(portrait)), -PI * 0.5, 0)), _cam0)
	_set_fov(portrait, _title_fov(portrait))


func _doors() -> Node:
	return main.get_node_or_null("Venue/Doors")


# --- Title UI ------------------------------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "StartScreen"
	_layer.layer = 5
	main.add_child(_layer)
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_screen)
	# Soft dark bands top and bottom so the type reads over the sky and the pavement
	for top in [true, false]:
		var g := TextureRect.new()
		var grad := Gradient.new()
		grad.set_color(0, Color(UI.BG_DEEP, 0.75 if top else 0.85))
		grad.set_color(1, Color(UI.BG_DEEP, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = grad
		gt.fill_from = Vector2(0.5, 0.0 if top else 1.0)
		gt.fill_to = Vector2(0.5, 1.0 if top else 0.0)
		g.texture = gt
		g.stretch_mode = TextureRect.STRETCH_SCALE
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.anchor_right = 1.0
		g.anchor_top = 0.0 if top else 0.72
		g.anchor_bottom = 0.26 if top else 1.0
		_screen.add_child(g)
	_title = UI.label("", 44.0, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_title.theme_type_variation = &"LabelDisplayXL"
	_title.add_theme_font_size_override("font_size", int(UI.dp(44.0)))
	_title.add_theme_color_override("font_shadow_color", Color(UI.NEON, 0.55))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 0)
	_title.add_theme_constant_override("shadow_outline_size", int(UI.dp(10.0)))
	_title.anchor_right = 1.0
	_title.anchor_top = 0.07
	_title.anchor_bottom = 0.07
	_title.grow_vertical = Control.GROW_DIRECTION_BOTH
	_screen.add_child(_title)
	_prompt = UI.label("", 19.0, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.theme_type_variation = &"LabelDisplayL"
	_prompt.add_theme_font_size_override("font_size", int(UI.dp(19.0)))
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.9
	_prompt.anchor_bottom = 0.9
	_prompt.grow_vertical = Control.GROW_DIRECTION_BOTH
	_screen.add_child(_prompt)
	var tw := _prompt.create_tween().set_loops()
	tw.tween_property(_prompt, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_prompt, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	_retitle()


func _retitle() -> void:
	_locale = TranslationServer.get_locale()
	_title.text = text_for("venue.start.title")
	_prompt.text = text_for("venue.start.tap")


## Title-screen string in the current language. Reads the CSV when the imported translation predates these keys
## (the game run from the command line does not re-import a changed CSV).
static func text_for(key: String) -> String:
	var s := T.t(key)
	if s != key:
		return s
	var f := FileAccess.open(T.CSV_PATH, FileAccess.READ)
	if f == null:
		return key
	var col := 2 if TranslationServer.get_locale().begins_with("th") else 1
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() > col and r[0] == key:
			return r[col]
	return key


# --- Walk profile --------------------------------------------------------------------------------

## Fraction of the walk done at time t: speeds up over ACCEL_TIME, steady, slows down over DECEL_TIME.
func _walk_s(t: float) -> float:
	var v := 1.0 / (WALK_TIME - (ACCEL_TIME + DECEL_TIME) * 0.5)
	if t < ACCEL_TIME:
		return 0.5 * v / ACCEL_TIME * t * t
	var s := 0.5 * v * ACCEL_TIME
	if t < WALK_TIME - DECEL_TIME:
		return s + v * (t - ACCEL_TIME)
	s += v * (WALK_TIME - DECEL_TIME - ACCEL_TIME)
	var u := t - (WALK_TIME - DECEL_TIME)
	return minf(1.0, s + v * u - 0.5 * v / DECEL_TIME * u * u)


func _walk_speed(t: float) -> float:
	if t >= WALK_TIME:
		return 0.0
	var v := _from.distance_to(_to) / (WALK_TIME - (ACCEL_TIME + DECEL_TIME) * 0.5)
	if t < ACCEL_TIME:
		return v * t / ACCEL_TIME
	if t > WALK_TIME - DECEL_TIME:
		return v * (WALK_TIME - t) / DECEL_TIME
	return v
