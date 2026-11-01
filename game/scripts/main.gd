extends Node3D
## Drops the player into the venue and runs the visit: zones from layout.json (VenueZones), what they offer
## (VenueSession), the needs HUD, zone sheets, minigames as overlays, Welcome Back and the walk-out summary.
##
## Keys: WASD / arrows walk, E / Space / Enter opens the nearby zone, Esc closes a sheet.
## Debug (debug builds): F1 needs panel, F2 +1 game day, F3 debug clock x60, F4 a week away (Welcome Back),
## F5 reset the save, F6 skip to the next song / break, F7 swap portrait / landscape window, F8 English / Thai.
## Screenshot mode: godot --path game -- --capture=<png> [--capture-size=1080x1920] [--capture-at=bar] [--capture-frames=120]
## Start screen (BACKLOG B8, scripts/start_screen.gd): the street door at night, tap to walk in; the visit starts
## once inside. Leaving plays the exit shot (scripts/exit_shot.gd) before the walk-out card. Both only when main.tscn
## runs as the game, not in screenshot mode or with `-- --skip-intro`; tests and tools that instance main.tscn start
## straight in the venue and leave straight to the card unless they set `intro` first.
## Nightlife (DECISIONS "Playtest of 33dc5b9"): the drunk overlay (scripts/ui/drunk_overlay.gd) on its own layer; past
## Rules.WASTED_AFTER drinks the WASTED shot (scripts/wasted_shot.gd) instead of the walk-out card; opened during the
## 12 h lockout, the game goes straight to the WASTED screen (F2 / F3 on the debug clock skip the lockout).

const S = preload("res://scripts/minigames/strings.gd")
const T = preload("res://scripts/zones/venue_strings.gd")
const FrameScene = preload("res://scenes/ui/minigame_frame.tscn")
const SheetScene = preload("res://scenes/ui/zone_sheet.tscn")
const WalkOutScene = preload("res://scenes/ui/walk_out.tscn")
const WelcomeScene = preload("res://scenes/ui/welcome_back.tscn")
const StartScreen = preload("res://scripts/start_screen.gd")
const ExitShot = preload("res://scripts/exit_shot.gd")
const MenuList = preload("res://scripts/menu/menu_list.gd")
const Nightlife = preload("res://scripts/zones/nightlife.gd")
const WastedShot = preload("res://scripts/wasted_shot.gd")
const DrunkOverlay = preload("res://scripts/ui/drunk_overlay.gd")

@onready var player: Player = $Player
@onready var zones: VenueZones = $Zones
@onready var session: VenueSession = $Session
@onready var hud: Control = $UI/Hud
@onready var overlay: CanvasLayer = $Overlay
@onready var needs: Node = get_node("/root/Needs")

## HUD zone name for an interaction zone; elsewhere the camera framing's name is used.
const ZONE_TITLES := {"bar": "bar", "stage": "stage", "arcade": "lounge", "exit": "lobby", "memory": "memory"}   # tables: the room they stand in

var sheet: Control
var sheet_zone: Dictionary = {}
var menu_list: Control
var frame: Control
var walk_out: Control
var welcome: Control
const ARRIVE_SLACK := 0.5   ## metres a finished walk may end outside its target zone and still open the sheet
var pending_zone := ""      ## zone id the player is walking to after a tap; its sheet opens on arrival
var _spawn: Transform3D
var _capture := {}
var intro := false          ## force the start screen and exit shot (tests); see the header
var street_shots := false   ## start screen and exit shot on
var start_screen: Node      ## the start screen while it runs
var exit_shot: Node         ## the exit shot while it runs
var wasted_shot: Node       ## the WASTED shot and screen while they run
var drunk: CanvasLayer      ## the drunk overlay
var _wasted_line := -1      ## WASTED during a minigame: the shot waits for the frame to close


func _ready() -> void:
	S.install()
	T.install()
	_spawn = player.global_transform
	player.joystick = $UI/Joystick
	if needs.meters.is_empty():  # built before the Needs autoload's _ready (tests that skip a frame)
		await get_tree().process_frame
	player.tap_handler = _on_world_tap
	zones.player = player
	session.setup(needs, zones, player)
	hud.setup(session, needs)
	zones.zone_changed.connect(_on_zone_changed)
	hud.prompt_pressed.connect(func(): open_sheet(zones.current))
	hud.leave_pressed.connect(_on_leave)
	hud.area_pressed.connect(walk_to_area)
	session.minigame_requested.connect(open_minigame)
	session.menu_requested.connect(open_menu)
	session.visit_finished.connect(_on_visit_finished)
	session.welcome_back.connect(_on_welcome_back)
	session.wasted.connect(_on_wasted)
	drunk = DrunkOverlay.new()
	drunk.name = "DrunkOverlay"
	add_child(drunk)
	move_child(drunk, $Post.get_index() + 1)
	drunk.setup(session)
	# Needs debug panel: F1 only (its on-screen button would sit on the HUD). Debug builds only.
	var dbg: Control = $UI/NeedsDebug
	if not OS.is_debug_build():
		dbg.queue_free()
	else:
		dbg._toggle.visible = false
	_parse_capture()
	if Nightlife.locked(needs) and _capture.is_empty():
		_show_wasted(-1)
	elif intro or (get_tree().current_scene == self and _capture.is_empty() and not "--skip-intro" in OS.get_cmdline_user_args()):
		street_shots = true
		start_screen = StartScreen.new()
		start_screen.name = "StartScreenRun"
		add_child(start_screen)
		start_screen.begin(self)
		_sync_block()
	else:
		session.arrive()
	if DisplayServer.get_name() == "headless":
		print("main ready: player at ", player.global_position, ", ", zones.zones.size(), " zones")


func _process(_delta: float) -> void:
	hud.set_zone_name(ZONE_TITLES.get(zones.current.get("kind", ""), player.rig.zone))
	hud.set_area(player.rig.zone)
	if player.rig.focus != "" and not player.walking_to:
		player.rig.release_focus()   # an area button's walk is over (arrived, or cancelled by the stick or a tap)
	if pending_zone != "":
		if zones.current.get("id", "") == pending_zone and not _blocked():
			var z := zones.current
			pending_zone = ""
			player.walking_to = false
			open_sheet(z)
		elif not player.walking_to:
			# The walk is over. A table or stool zone is ringed by its furniture's nav hole and the agent stops short of
			# its target, so the feet can end just outside the circle: close enough counts as arrived.
			var z := zones.by_id(pending_zone)
			pending_zone = ""
			if not z.is_empty() and not _blocked() and VenueZones.gap(z, player.global_position) <= ARRIVE_SLACK:
				open_sheet(z)
	if not _capture.is_empty():
		_capture_tick()


func _blocked() -> bool:
	return is_instance_valid(start_screen) or is_instance_valid(exit_shot) or is_instance_valid(wasted_shot) or is_instance_valid(sheet) or is_instance_valid(menu_list) or is_instance_valid(frame) or is_instance_valid(walk_out) or is_instance_valid(welcome)


func _sync_block() -> void:
	var b := _blocked()
	player.input_enabled = not b
	session.busy = b
	hud.prompt.visible = not b
	hud.visible = not (is_instance_valid(frame) or is_instance_valid(walk_out) or is_instance_valid(start_screen) or is_instance_valid(exit_shot) or is_instance_valid(wasted_shot))
	$UI/Joystick.visible = not b


## The start screen has walked the player in: HUD and joystick fade in and the visit starts as it does without one.
func start_play() -> void:
	start_screen = null
	_sync_block()
	session.process_mode = Node.PROCESS_MODE_INHERIT
	for c: CanvasItem in [hud, $UI/Joystick]:
		c.modulate.a = 0.0
		create_tween().tween_property(c, "modulate:a", 1.0, 0.5)
	session.arrive()


# --- Zones ---------------------------------------------------------------------------------------

func _on_zone_changed(z: Dictionary) -> void:
	hud.prompt.show_text(session.prompt_for(z))


## A floor or object tap inside a zone walks there and opens its sheet; elsewhere the player just walks.
func _on_world_tap(pos: Vector3) -> bool:
	var z := zones.zone_at(pos)
	if z.is_empty():
		pending_zone = ""
		return false
	if zones.current.get("id", "") == z["id"]:
		open_sheet(z)
	else:
		player.walk_to(z["approach"])
		pending_zone = z["id"]
	return true


## Area button (hud AREAS): walk to that area's zone and open its sheet on arrival, while the camera turns to the area's framing at once and settles on it
## when the player gets there (CameraRig.focus_on). Daniele, Questions tab 2026-11-01.
func walk_to_area(area: String) -> void:
	if _blocked():
		return
	var z := area_zone(area)
	if z.is_empty():
		return
	player.walk_to(z["approach"])
	pending_zone = z["id"]
	player.rig.focus_on(area)


## The zone an area button walks to: the zone named in AREAS, or the first of its kind whose approach is in the area.
func area_zone(area: String) -> Dictionary:
	for a in hud.AREAS:
		if a[0] != area:
			continue
		for z in zones.zones:
			if (z["id"] == a[2] or z["kind"] == a[2]) and player.rig.area_at(z["approach"]) == area:
				return z
	return {}


## Walk to the first zone of that kind (a regular's table for "table") and open its sheet on arrival.
func walk_to_kind(kind: String) -> void:
	if _blocked():
		return
	var z := zones.first_of(kind, kind == "table")
	if z.is_empty():
		return
	player.walk_to(z["approach"])
	pending_zone = z["id"]


func open_sheet(z: Dictionary) -> void:
	if z.is_empty() or _blocked():
		return
	sheet_zone = z
	sheet = SheetScene.instantiate()
	overlay.add_child(sheet)
	sheet.open(session.header_for(z), session.rows_for(z))
	sheet.row_chosen.connect(_on_row)
	sheet.closed.connect(close_sheet)
	_sync_block()


func close_sheet() -> void:
	if is_instance_valid(sheet):
		sheet.queue_free()
	sheet = null
	_sync_block.call_deferred()


func _on_row(row_id: String) -> void:
	var z := sheet_zone
	close_sheet()
	sheet = null
	session.do_row(z, row_id)
	_sync_block()


## The real menu list (bar sheet → The menu / Kitchen). A tapped drink is ordered by VenueSession.order_item().
func open_menu(tab: String) -> void:
	if is_instance_valid(menu_list):
		return
	menu_list = MenuList.new()
	overlay.add_child(menu_list)
	menu_list.open(tab, false)   # Merry no longer stops alcohol (nightlife: drunk to 10, WASTED past 10)
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


func _on_leave() -> void:
	if not _blocked():
		session.leave()


# --- Minigames -----------------------------------------------------------------------------------

func open_minigame(game_id: String, config: Dictionary) -> void:
	if is_instance_valid(frame):
		return
	frame = FrameScene.instantiate()
	frame.needs = needs
	overlay.add_child(frame)
	frame.closed.connect(_on_minigame_closed)
	frame.open(load(VenueSession.GAMES[game_id]), config)
	_sync_block()


func _on_minigame_closed(_result: Dictionary) -> void:
	if is_instance_valid(frame):
		frame.queue_free()
	frame = null
	_sync_block()
	_on_zone_changed(zones.current)
	if _wasted_line >= 0:
		_show_wasted(_wasted_line)


# --- Visit ---------------------------------------------------------------------------------------

func _on_welcome_back(_reason: String) -> void:
	if is_instance_valid(welcome):
		return
	welcome = WelcomeScene.instantiate()
	overlay.add_child(welcome)
	welcome.open(str(needs.profile.get("display_name", "")))
	welcome.dismissed.connect(func():
		welcome.queue_free()
		welcome = null
		_sync_block())
	_sync_block()


func _on_visit_finished(summary: Dictionary) -> void:
	close_sheet()
	close_menu()
	sheet = null
	pending_zone = ""
	if summary.get("reason", "") == "wasted":
		return   # the WASTED shot takes over (_on_wasted)
	if street_shots and summary.get("reason", "") == "left" and not is_instance_valid(exit_shot):
		exit_shot = ExitShot.new()
		exit_shot.name = "ExitShotRun"
		add_child(exit_shot)
		exit_shot.begin(self, summary)
		_sync_block()
		return
	_show_walk_out(summary)


## The exit shot is over (or skipped): the walk-out card.
func end_exit_shot(summary: Dictionary) -> void:
	exit_shot = null
	_show_walk_out(summary)


func _show_walk_out(summary: Dictionary) -> void:
	if is_instance_valid(walk_out):
		walk_out.queue_free()
	walk_out = WalkOutScene.instantiate()
	overlay.add_child(walk_out)
	walk_out.open(summary)
	walk_out.go_out.connect(_go_out)
	_sync_block()


# --- Nightlife: WASTED ---------------------------------------------------------------------------

## Past Rules.WASTED_AFTER drinks (the rules are applied already): the shot, once a running minigame has closed.
func _on_wasted(line: int) -> void:
	close_sheet()
	close_menu()
	if is_instance_valid(welcome):
		welcome.queue_free()
		welcome = null
	if is_instance_valid(frame):
		_wasted_line = line
		return
	_show_wasted(line)


## line -1: the game opened during a lockout, straight to the screen.
func _show_wasted(line: int) -> void:
	_wasted_line = -1
	if is_instance_valid(wasted_shot):
		return
	pending_zone = ""
	wasted_shot = WastedShot.new()
	wasted_shot.name = "WastedRun"
	add_child(wasted_shot)
	if line < 0:
		wasted_shot.begin_locked(self)
	else:
		wasted_shot.begin(self, line)
	_sync_block()


## Try again, the lockout over: from the street door as a fresh start when this is the game, else back in at the spawn.
func end_wasted() -> void:
	wasted_shot = null
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()
		return
	_go_out()


## GO OUT on the Flat stand-in: back in through the street door, a new visit.
func _go_out() -> void:
	if is_instance_valid(walk_out):
		walk_out.queue_free()
	walk_out = null
	player.global_transform = _spawn
	player.velocity = Vector3.ZERO
	player.walking_to = false
	player.rig.snap()
	_sync_block()
	session.arrive()


# --- Keys ----------------------------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_E, KEY_SPACE, KEY_ENTER:
			if not _blocked() and not zones.current.is_empty():
				open_sheet(zones.current)
		KEY_F8:
			TranslationServer.set_locale("th" if TranslationServer.get_locale().begins_with("en") else "en")
			_on_zone_changed(zones.current)
			hud.retitle()
	if not OS.is_debug_build():
		return
	match event.keycode:
		KEY_F2:
			needs.debug_advance(86400.0)
		KEY_F3:
			needs.toggle_debug_clock()
		KEY_F4:
			if not is_instance_valid(walk_out):
				session.debug_week_away()
		KEY_F5:
			needs.delete_save()
			needs.new_game()
			get_tree().reload_current_scene()
		KEY_F6:
			session.band.skip()
		KEY_F7:
			var s := DisplayServer.window_get_size()
			DisplayServer.window_set_size(Vector2i(s.y, s.x))


# --- Screenshot mode -----------------------------------------------------------------------------

func _parse_capture() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			_capture["path"] = a.get_slice("=", 1)
		elif a.begins_with("--capture-at="):
			_capture["at"] = a.get_slice("=", 1)
		elif a.begins_with("--capture-frames="):
			_capture["frames"] = int(a.get_slice("=", 1))
		elif a == "--capture-sheet":
			_capture["sheet"] = true
		elif a.begins_with("--capture-size="):  # e.g. 1080x1920; borderless so it may exceed the screen
			var wh := a.get_slice("=", 1).split("x")
			get_window().borderless = true
			get_window().position = Vector2i.ZERO
			get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	if _capture.has("path"):
		_capture["frames"] = _capture.get("frames", 120)
		var z := zones.first_of(_capture.get("at", ""), _capture.get("at", "") == "table")
		if not z.is_empty():
			player.global_position = z["approach"] + Vector3(0, 0.1, 0)
			player.rig.snap()
	else:
		_capture.clear()


func _capture_tick() -> void:
	_capture["frames"] -= 1
	if _capture.get("sheet", false) and _capture["frames"] == 40:
		open_sheet(zones.current)
	if _capture["frames"] > 0:
		return
	var path: String = _capture["path"]
	_capture.clear()
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	print("capture ", path, " ", img.get_size(), " -> ", img.save_png(path))
	get_tree().quit()
