extends Node
## Tap on a live patron → their card (08-presence §5.1). venue_patrons.gd adds this to the root after the game scene,
## so it hears an unhandled touch before the Player (which would walk to the floor under it). A press within
## TAP_RADIUS of a presence's body on screen is taken (press and release both, so the Player's own tap tracking never
## starts); the release opens the card. Anything else passes through untouched. Off while the player's input is off
## (a sheet, the start screen, a minigame, the card itself).

const Card = preload("res://scripts/presence_ui/presence_card.gd")
const UI = preload("res://scripts/minigames/mg_ui.gd")

const TAP_RADIUS := 34.0     ## dp around the line from a figure's hips to its head
const TAP_MOVE := 24.0       ## dp a press may move and still be a tap

var venue: Node              ## Venue/Patrons (venue_patrons.gd)
var card: Control            ## the open card
var _press := -1
var _press_pos := Vector2.ZERO
var _press_id := ""


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(venue):
		queue_free()
		return
	if not event is InputEventScreenTouch:
		return
	var main := find_main()
	if main == null or not main.player.input_enabled or is_instance_valid(card):
		_press = -1
		return
	if event.pressed and _press == -1:
		var id := pick(event.position)
		if id == "":
			return
		_press = event.index
		_press_pos = event.position
		_press_id = id
		get_viewport().set_input_as_handled()
	elif not event.pressed and event.index == _press:
		_press = -1
		get_viewport().set_input_as_handled()
		if event.position.distance_to(_press_pos) <= UI.dp(TAP_MOVE):
			open_card(_press_id)


## The presence under a screen point ("" = none): the nearest whose hips-to-head segment is within TAP_RADIUS.
func pick(screen_pos: Vector2) -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return ""
	var best := ""
	var best_d := UI.dp(TAP_RADIUS)
	if not get_viewport().get_visible_rect().has_point(screen_pos):
		return ""
	for id in venue.presences:
		var f: Node3D = venue.presences[id]
		if not is_instance_valid(f) or not f.is_visible_in_tree():
			continue
		var lo := f.global_position + Vector3(0, 0.35, 0)
		var hi := f.global_position + Vector3(0, 1.1, 0)
		if cam.is_position_behind(lo) or cam.is_position_behind(hi):
			continue
		var a := cam.unproject_position(lo)
		var b := cam.unproject_position(hi)
		var d := screen_pos.distance_to(Geometry2D.get_closest_point_to_segment(screen_pos, a, b))
		if d < best_d:
			best_d = d
			best = id
	return best


## Opens the card of presence `id` over the venue; the player's input is off until it closes.
func open_card(id: String) -> Control:
	var main := find_main()
	var f: Node3D = venue.presences.get(id)
	if main == null or f == null:
		return null
	var layer := CanvasLayer.new()
	layer.name = "PresenceCardLayer"
	layer.layer = 7
	main.add_child(layer)
	card = Card.new()
	layer.add_child(card)
	card.open(f.get_meta("presence"), main, venue)
	main.player.input_enabled = false
	card.closed.connect(func():
		layer.queue_free()
		card = null
		if is_instance_valid(main):
			main._sync_block())
	return card


func find_main() -> Node:
	var n: Node = venue
	while n != null:
		if n.get("player") is Node and n.get("needs") is Node:
			return n
		n = n.get_parent()
	return null
