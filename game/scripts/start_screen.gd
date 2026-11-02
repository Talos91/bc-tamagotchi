extends "res://scripts/street_shot.gd"
## Start screen and entry (BACKLOG B8; Daniele 2026-11-01 and 2026-11-02, docs/design/DECISIONS.md): the game opens
## on a still view from the opposite pavement of the club's street door under the BLACK CABIN neon
## (scenes/street/street_front.gd), with only "Tap to enter" on screen. Then, in Daniele's words: "start first (when
## you see the door) tapping and camera ease to over the shoulder, character open the door enters and while the door
## is closing camera ease to game view, interface appear and its playable":
##   tap     the character steps out from under the camera towards the door while the camera eases (EASE_IN) to
##           over their right shoulder
##   door    they stop in front of it while it swings open (venue_doors.gd, as for anyone who comes near), then walk
##           through to main's lobby spawn, the camera following and centring behind them
##   close   when the door starts to swing shut, the camera eases (PULL_TIME) up and back into the diorama camera of
##           the lobby; the street goes dark once the door is shut
##   play    main.gd `start_play()`: HUD and joystick fade in, the visit starts as it does without a start screen
## About 5.5 s from the tap. Any further tap skips to the end.
##
## While it runs the visit has not begun (Needs.begin_visit waits for start_play), the HUD and joystick are hidden
## and VenueSession (house band, sit minute) does not process; the save has already loaded. The street's two lights
## are off once inside, so the venue keeps its own light count. main.gd adds this when main.tscn runs as the game;
## tests set `main.intro = true` (tests/smoke_start.gd). Debug builds: Esc on the start screen goes straight in.
## Command line: `-- --skip-intro` never shows it.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const T = preload("res://scripts/zones/venue_strings.gd")
const VersionInfo = preload("res://scripts/version_info.gd")

const FOLLOW_H := 1.75       ## camera height behind the character (1.35 m tall)
const FOLLOW := 1.3          ## camera this far behind the character outside ...
const FOLLOW_IN := 0.6       ## ... closing to this once through the door, so it ends inside the lobby
const SHOULDER := 0.3        ## over the right shoulder outside (the doorway shows past the head), centred inside
const EASE_IN := 1.2         ## still view to over the shoulder
const LEG_A := 1.9           ## from under the camera to the door
const DOOR_WAIT := 0.3       ## standing at the door while it swings open
const LEG_B := 1.2           ## through the door to the lobby spawn
const DOOR_STOP := 0.75      ## stop this far in front of the facade (inside the door's reach, venue_doors.gd 1.2 m)
const PULL_TIME := 1.6       ## over the shoulder to the lobby's diorama camera, while the door closes
const FADE_TIME := 0.35      ## prompt fading out after the tap
const CEILING_Y := 3.6       ## above this the camera stops drawing the ceiling, as the diorama camera does

enum Phase { TITLE, WALK, PULL, DONE }

var phase := Phase.TITLE
var _t := 0.0                  ## seconds since the tap
var _p0: Vector3               ## walk start (under the camera)
var _p1: Vector3               ## in front of the door
var _p2: Vector3               ## main's spawn
var _view: Transform3D         ## the still camera
var _cam_x := 0.0              ## follow position along the walk (damped)
var _door_was_open := false
var _pull_t0 := 0.0
var _pull_from: Transform3D
var _pull_look: Vector3        ## what the camera looked at when the pull-back began
var _pull_fov := 0.0
var _layer: CanvasLayer
var _screen: Control
var _prompt: Label
var _locale := ""


func begin(m: Node) -> void:
	main = m
	street = _street()
	street.set_on(true)
	var cz: float = street.door_center.z
	_make_camera("StartCamera")
	_place_view_camera()
	_view = cam.global_transform
	_p0 = Vector3(_view.origin.x - 0.1, 0.0, cz)
	_p1 = Vector3(street.face_x - DOOR_STOP, 0.0, cz)
	_p2 = Vector3(main._spawn.origin.x, 0.0, main._spawn.origin.z)
	_cam_x = _view.origin.x
	# The character waits out of sight under the camera; the diorama rig stays put until the pull-back
	_take_player()
	_drive(_p0, PI * 0.5, 0.0)
	main.player.visible = false
	main.session.process_mode = Node.PROCESS_MODE_DISABLED
	_build_ui()


## Tap on the start screen: walk in. Any tap after that: skip to the end.
func tap() -> void:
	match phase:
		Phase.TITLE:
			phase = Phase.WALK
			_t = 0.0
			main.player.visible = true
			create_tween().tween_property(_screen, "modulate:a", 0.0, FADE_TIME)
		Phase.WALK, Phase.PULL:
			skip()


## Everything as at the end of the sequence, now.
func skip() -> void:
	if phase == Phase.DONE:
		return
	_shut_door()
	street.set_on(false)
	_finish()


func _process(delta: float) -> void:
	if phase == Phase.DONE:
		return
	if phase == Phase.TITLE:
		_place_view_camera()
		_view = cam.global_transform
		if TranslationServer.get_locale() != _locale:
			_retitle()
		return
	_t += delta
	var portrait := _portrait()
	if phase == Phase.WALK:
		_walk(delta, portrait)
	else:
		_pull()


func _walk(delta: float, portrait: bool) -> void:
	# The character: to the door, a beat while it opens, through to the spawn
	var pos: Vector3
	var speed := 0.0
	var tb := _t - LEG_A - DOOR_WAIT
	if _t < LEG_A:
		pos = _p0.lerp(_p1, leg(_t, LEG_A, 0.4, 0.5))
		speed = leg_speed(_t, LEG_A, 0.4, 0.5, _p0.distance_to(_p1))
	elif tb < 0.0:
		pos = _p1
	else:
		pos = _p1.lerp(_p2, leg(tb, LEG_B, 0.3, 0.45))
		speed = leg_speed(tb, LEG_B, 0.3, 0.45, _p1.distance_to(_p2))
	_drive(pos, PI * 0.5, speed)
	# The camera: from the still view to over the shoulder, then following through the doorway
	var e := smoothstep(0.0, EASE_IN, _t)
	var inside := clampf((pos.x - (street.face_x - 0.5)) / 1.5, 0.0, 1.0)
	var behind := lerpf(FOLLOW, FOLLOW_IN, smoothstep(0.0, 1.0, inside))
	_cam_x = lerpf(_cam_x, maxf(_view.origin.x, pos.x - behind), 1.0 - exp(-6.0 * delta))
	var pitch := lerpf(street.view_pitch(portrait), -8.0 if portrait else -11.0, e)
	var origin := Vector3(_cam_x, lerpf(_view.origin.y, FOLLOW_H, e), pos.z + SHOULDER * e * (1.0 - inside))
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(pitch), -PI * 0.5, 0)), origin)
	_set_fov(portrait, street.view_fov(portrait) - 2.0 * e)
	cam.cull_mask = 0xFFFFF
	# The pull-back starts as the door starts to swing shut behind them (fallback: a moment after arriving)
	var open := door_open()
	if open > 0.99:
		_door_was_open = true
	if tb > 0.0 and ((_door_was_open and open < 0.97) or tb > LEG_B + 1.5):
		_start_pull()


## Arrived at the spawn, the door closing: hand the camera over to the diorama rig, up first, then back.
func _start_pull() -> void:
	phase = Phase.PULL
	_pull_t0 = _t
	_drive(_p2, PI * 0.5, 0.0)
	var p: Player = main.player
	var sp: Transform3D = main._spawn
	p.global_transform = Transform3D(sp.basis, Vector3(sp.origin.x, 0.02, sp.origin.z))
	p.get_node("Body").global_rotation = Vector3(0, PI * 0.5, 0)
	p.rig.set_process(true)   # first: snap() does nothing while the rig is off, and the pull-back would aim at (0, 0, 0) for a frame
	p.rig.snap()
	_pull_from = cam.global_transform
	_pull_look = cam.global_position - cam.global_basis.z * 1.8
	_pull_fov = cam.fov


func _pull() -> void:
	var p: Player = main.player
	var u := minf((_t - _pull_t0) / PULL_TIME, 1.0)
	var e := smoothstep(0.0, 1.0, u)
	var rc: Camera3D = p.rig.camera
	# The height eases out, the rest in and out; the camera keeps looking at a point that slides from ahead of the
	# character to the diorama camera's own look point (on the character)
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
	cam.cull_mask = rc.cull_mask if cam.global_position.y > CEILING_Y else 0xFFFFF
	# Out of sight and dark once the door is shut
	if street.visible and door_open() < 0.001:
		street.set_on(false)
	if u >= 1.0:
		street.set_on(false)
		_finish()


func _finish() -> void:
	phase = Phase.DONE
	_give_back_player()
	if is_instance_valid(_layer):
		_layer.queue_free()
	queue_free()
	main.start_play()


# --- Prompt --------------------------------------------------------------------------------------

## Nothing on screen but "Tap to enter" over a soft dark band (the neon carries the name; Daniele 2026-11-02).
func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "StartScreen"
	_layer.layer = 5
	main.add_child(_layer)
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_screen)
	var g := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(UI.BG_DEEP, 0.85))
	grad.set_color(1, Color(UI.BG_DEEP, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 1.0)
	gt.fill_to = Vector2(0.5, 0.0)
	g.texture = gt
	g.stretch_mode = TextureRect.STRETCH_SCALE
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.anchor_right = 1.0
	g.anchor_top = 0.74
	g.anchor_bottom = 1.0
	_screen.add_child(g)
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
	_screen.add_child(VersionInfo.label())  # bottom right, fades out with the prompt
	_retitle()


func _retitle() -> void:
	_locale = TranslationServer.get_locale()
	_prompt.text = text_for("venue.start.tap")


## Start-screen string in the current language. Reads the CSV when the imported translation predates the key (the
## game run from the command line does not re-import a changed CSV).
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
