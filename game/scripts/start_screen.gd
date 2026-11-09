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
## Character creator (07-character-creator.md §4.3, §5; DECISIONS 2026-11-09): a new character (no look yet, never out)
## opens the creator on the first tap and walks in after "Into the bar"; a save from before the creator gets a
## one-time card ("Make your character" / "Keep this look"); everyone else has an "Edit look" button. The photo booth
## in the lounge is the in-game way back to the creator (main.gd). While the creator or the card is up, taps go to them.

const UI = preload("res://scripts/minigames/mg_ui.gd")
const T = preload("res://scripts/zones/venue_strings.gd")
const VersionInfo = preload("res://scripts/version_info.gd")
const Rules = preload("res://scripts/rules.gd")
const Creator = preload("res://scripts/ui/character_creator.gd")
const Avatar = preload("res://scripts/avatar.gd")
const UIS = preload("res://scripts/ui/ui_strings.gd")

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
var _stake_box: VBoxContainer   ## stage chip, ghost rule, postcard, annoyance chips, lives (06-stakes §10.5)
var _locale := ""
var _modal: CanvasLayer         ## the creator or the one-time card, over everything
var _edit_btn: Button           ## "Edit look" (characters that have a look)
var _walk_after := false        ## the creator was opened by the first tap: walk in once it is done


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
	if not main.needs.has_avatar() and not main.needs.is_new_character():
		_offer_card()


## Tap on the start screen: walk in. Any tap after that: skip to the end.
func tap() -> void:
	match phase:
		Phase.TITLE:
			if main.needs.is_new_character():
				_walk_after = true
				open_creator("new")
				return
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


## Taps reach the creator, the card and the Edit look button, not the street (street_shot.gd takes every tap first).
func _input(event: InputEvent) -> void:
	if is_instance_valid(_modal):
		return
	if phase == Phase.TITLE and is_instance_valid(_edit_btn) and _edit_btn.visible:
		var pos: Variant = event.get("position") if (event is InputEventScreenTouch or event is InputEventMouseButton) else null
		if pos != null and _edit_btn.get_global_rect().grow(UI.dp(6)).has_point(pos):
			return
	super(event)


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
	_stake_box = VBoxContainer.new()
	_stake_box.name = "StakeInfo"
	_stake_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stake_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_stake_box.offset_left = UI.dp(16)
	_stake_box.offset_right = -UI.dp(16)
	_stake_box.offset_top = UI.dp(44)
	_stake_box.add_theme_constant_override("separation", int(UI.dp(6)))
	_screen.add_child(_stake_box)
	_edit_btn = UI.button(UIS.t("ui.avatar.edit"), "ghost")
	_edit_btn.name = "EditLook"
	_edit_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_edit_btn.offset_left = UI.dp(12)
	_edit_btn.offset_top = -UI.dp(58)
	_edit_btn.offset_bottom = -UI.dp(10)
	_edit_btn.offset_right = UI.dp(130)
	_edit_btn.add_theme_font_size_override("font_size", int(UI.dp(13)))
	_edit_btn.visible = main.needs.has_avatar()
	_edit_btn.pressed.connect(func(): open_creator("edit"))
	_screen.add_child(_edit_btn)
	_retitle()


func _retitle() -> void:
	_locale = TranslationServer.get_locale()
	_prompt.text = text_for("venue.start.tap")
	if is_instance_valid(_edit_btn):
		_edit_btn.text = UIS.t("ui.avatar.edit")
	_fill_stake_box()


## The character's stake on the street-door home view (06-stakes §4, §10.5): the stage chip from Restless on, the revival
## rule for a ghost, the postcard, one chip per annoyance, "Lives: N" after a revival. Nothing at Fine with no annoyance.
func _fill_stake_box() -> void:
	for c in _stake_box.get_children():
		c.queue_free()
	var needs: Node = main.needs
	var who := str(needs.profile.get("display_name", ""))
	if who == "":
		who = text_for("venue.stake.name_fallback")
	var stage: String = needs.stake_stage
	var d: int = needs.days_left()
	var chip := ""
	match stage:
		"restless":
			chip = text_for("venue.stake.restless")
		"fading", "last_call":
			chip = text_for("venue.stake." + stage).format({"d": d})
		"ghost":
			chip = text_for("venue.stake.ghost").format({"d": d, "name": who})
	if chip != "":
		var col := UI.RED_HI if stage in ["last_call", "ghost"] else UI.GOLD
		_stake_box.add_child(_start_chip(chip, col))
	if stage == "ghost":
		_stake_box.add_child(UI.wrap(UI.label(text_for("venue.stake.ghost_rule").format({"name": who}), 14, UI.SMOKE)))
	if stage != "fine":
		_stake_box.add_child(UI.wrap(UI.label(text_for("venue.stake.postcard." + stage) if stage != "ghost" else text_for("venue.stake.postcard.ghost"), 14, UI.CREAM)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(UI.dp(4)))
	for id in needs.annoyances():
		var meter: String = Rules.ANNOYANCES[id]
		row.add_child(_start_chip(text_for("venue.annoy." + id), UI.need_color(meter) if meter != "" else UI.SMOKE))
	if int(needs.lives) > 1:
		row.add_child(_start_chip(text_for("venue.stake.lives").format({"n": needs.lives}), UI.GOLD))
	if row.get_child_count() > 0:
		_stake_box.add_child(row)
	else:
		row.queue_free()


func _start_chip(text: String, color: Color) -> Label:
	var l := UI.label(text, 14, color, HORIZONTAL_ALIGNMENT_CENTER)
	var sb := UI.box(Color(UI.BG_DEEP, 0.85), 12, color, 2.0)
	sb.content_margin_left = UI.dp(8)
	sb.content_margin_right = UI.dp(8)
	l.add_theme_stylebox_override("normal", sb)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l


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


# --- Character creator ---------------------------------------------------------------------------

func _modal_layer() -> CanvasLayer:
	_close_modal()
	_modal = CanvasLayer.new()
	_modal.name = "CreatorLayer"
	_modal.layer = 6
	main.add_child(_modal)
	return _modal


func _close_modal() -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null


## mode "new" (first tap of a new character; starts from a random look), "edit", "make" (from the card: the old
## look, every tab open), "name" (Keep this look with no name yet).
func open_creator(mode: String) -> void:
	var needs: Node = main.needs
	var rec: Dictionary = Avatar.random_record() if mode == "new" else needs.avatar()
	var p: String = needs.personality
	if mode == "new" and p == "":
		p = Avatar.data()["personalities"][0]
	var c := Creator.new()
	_modal_layer().add_child(c)
	c.open("new" if mode == "new" else ("name" if mode == "name" else "edit"), rec, str(needs.profile.get("display_name", "")), p)
	c.done.connect(func(r: Dictionary, who: String, pp: String):
		needs.set_avatar(r, who, pp)
		main.player.set_avatar(needs.avatar())
		_close_modal()
		_edit_btn.visible = true
		if _walk_after:
			_walk_after = false
			tap())
	c.cancelled.connect(func():
		_walk_after = false
		_close_modal()
		if mode in ["make", "name"]:
			_offer_card())


## Saves from before the creator: one card, once (either answer writes the look, 07-character-creator.md §4.3).
func _offer_card() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer().add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(UI.BG_DEEP, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "OfferCard"
	panel.custom_minimum_size = Vector2(UI.dp(330), 0)
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG_BASE, 20, UI.LINE, 2.0))
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(UI.dp(18)))
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UI.dp(10)))
	pad.add_child(col)
	col.add_child(UI.title(UIS.t("ui.avatar.offer.title"), 26))
	col.add_child(UI.wrap(UI.label(UIS.t("ui.avatar.offer.body"), 14, UI.SMOKE)))
	var make := UI.button(UIS.t("ui.avatar.offer.make"), "primary")
	make.name = "Make"
	make.pressed.connect(func(): open_creator("make"))
	col.add_child(make)
	var keep := UI.button(UIS.t("ui.avatar.offer.keep"))
	keep.name = "Keep"
	keep.pressed.connect(_keep_look)
	col.add_child(keep)


func _keep_look() -> void:
	var needs: Node = main.needs
	if Avatar.check_name(str(needs.profile.get("display_name", ""))) != "":
		open_creator("name")
		return
	needs.set_avatar(needs.avatar(), str(needs.profile.get("display_name", "")), needs.personality)
	_close_modal()
	_edit_btn.visible = true
