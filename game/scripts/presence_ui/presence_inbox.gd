extends Control
## The received inbox (08-presence §4 N2): waves, cheers, drinks and phrases other players sent while this player was
## away, shown at the next open from the start screen ("Inbox · N", start_screen.gd), like postcards. "Got it" marks
## them read; waves, cheers and phrases give Friends +2 each at the visit (presence_client.gd read_inbox). A received
## drink is only listed for now: the drink inventory does not exist yet (open item in the role note).

signal closed

const UI = preload("res://scripts/minigames/mg_ui.gd")
const UIS = preload("res://scripts/ui/ui_strings.gd")
const PresenceClient = preload("res://scripts/presence_ui/presence_client.gd")
const BarMenu = preload("res://scripts/menu/bar_menu.gd")

var needs: Node
var items: Array = []
var list: VBoxContainer


func open(n: Node) -> void:
	needs = n
	name = "PresenceInbox"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UI.BG_DEEP, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "InboxCard"
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
	col.add_child(UI.title(UIS.t("ui.presence.inbox.title"), 26))
	list = VBoxContainer.new()
	list.name = "Items"
	list.add_theme_constant_override("separation", int(UI.dp(6)))
	col.add_child(list)
	var ok := UI.button(UIS.t("ui.presence.inbox.ok"), "primary")
	ok.name = "GotIt"
	ok.pressed.connect(got_it)
	col.add_child(ok)
	PresenceClient.fetch_inbox(func(got: Array):
		items = got
		if is_inside_tree() or list != null:
			_fill())


func _fill() -> void:
	for c in list.get_children():
		c.queue_free()
	if items.is_empty():
		list.add_child(UI.label(UIS.t("ui.presence.inbox.empty"), 14, UI.SMOKE))
		return
	for it in items:
		var l := UI.wrap(UI.label(line_for(it), 15, UI.CREAM))
		l.name = "Item_" + str(it.get("id", ""))
		var sb := UI.box(UI.BG_RAISED, 12, UI.LINE, 1.0)
		sb.content_margin_left = UI.dp(10)
		sb.content_margin_right = UI.dp(10)
		sb.content_margin_top = UI.dp(6)
		sb.content_margin_bottom = UI.dp(6)
		l.add_theme_stylebox_override("normal", sb)
		list.add_child(l)


static func line_for(it: Dictionary) -> String:
	var from: Variant = it.get("from", {})
	var nm := str(from.get("display_name", "?")) if from is Dictionary else str(it.get("from_name", "?"))
	var pl: Dictionary = it.get("payload", {}) if it.get("payload") is Dictionary else {}
	match str(it.get("kind", "")):
		"wave": return UIS.t("ui.presence.inbox.wave", {"name": nm})
		"cheers": return UIS.t("ui.presence.inbox.cheers", {"name": nm})
		"drink": return UIS.t("ui.presence.inbox.drink", {"name": nm, "drink": BarMenu.name_of(str(pl.get("drink_id", "")))})
		"phrase": return UIS.t("ui.presence.inbox.phrase", {"name": nm, "line": phrase_text(str(pl.get("phrase", "p01")))})
	return UIS.t("ui.presence.inbox.wave", {"name": nm})


## Phrase id (08b: "p01".."p24") -> its line (strings_ui ui.presence.phrase.01..; ids past the written lines show
## the first one until the owner's list lands).
static func phrase_text(id: String) -> String:
	var n := id.trim_prefix("p").to_int()
	var key := "ui.presence.phrase.%02d" % clampi(n, 1, 99)
	var s := UIS.t(key)
	return s if s != key else UIS.t("ui.presence.phrase.01")


func got_it() -> void:
	PresenceClient.read_inbox(needs, items)
	closed.emit()
	queue_free()
