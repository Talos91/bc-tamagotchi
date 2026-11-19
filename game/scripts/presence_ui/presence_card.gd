extends Control
## A live patron's card (08-presence §5.1; Daniele 2026-11-19 "reaction interaction with live patrons (what we
## discussed instead of chat)"): their avatar, name, tags (regular, at your table, friend), nights together, and the
## wave-1 verbs: Wave, Cheers, Send a drink (three drinks from the real menu), Say (the phrase wheel: fixed lines only,
## no free text). The other player is not live: a verb is an event they find in their inbox at their next open; the
## sender sees it now (a bubble over both figures, the presence applauds). Limits per pair per night (presence_client.gd
## LIMITS); a used verb shows "Sent". Hide and Report (fixed reasons) take them out of this bar at once (§7.4).
## Simple, on the existing style (mg_ui.gd); the themed reskin comes later. Tap outside or Close to shut it.

signal closed

const UI = preload("res://scripts/minigames/mg_ui.gd")
const UIS = preload("res://scripts/ui/ui_strings.gd")
const PresenceClient = preload("res://scripts/presence_ui/presence_client.gd")
const Badge = preload("res://scripts/presence_ui/presence_badge.gd")
const BarMenu = preload("res://scripts/menu/bar_menu.gd")
const Inbox = preload("res://scripts/presence_ui/presence_inbox.gd")
const Avatar = preload("res://scripts/avatar.gd")
const FIGURE := preload("res://scenes/venue/patron_figure.tscn")

const VERBS := ["wave", "cheers", "drink", "phrase"]
const PHRASES := 12              ## ui.presence.phrase.01 .. 12 (GDD §5.3 asks 24; the rest wait for the owner's lines)
const DRINKS := 3                ## the first three of the menu's try order

var p: Dictionary = {}           ## the presence record
var main: Node
var venue: Node
var buttons := {}                ## verb -> Button
var status: Label
var sub: VBoxContainer           ## drink choices, phrase wheel or report reasons
var panel: PanelContainer
var last_result := {}            ## the last send's answer (tests)


func open(presence: Dictionary, m: Node, v: Node) -> void:
	p = presence
	main = m
	venue = v
	name = "PresenceCard"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(UI.BG_DEEP, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and not e.pressed:
			close())
	add_child(dim)
	panel = PanelContainer.new()
	panel.name = "Card"
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG_BASE, 20, UI.LINE, 2.0))
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(UI.dp(360), 0)
	panel.offset_left = -UI.dp(180)
	panel.offset_right = UI.dp(180)
	panel.offset_bottom = -UI.dp(12)
	add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(UI.dp(14)))
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UI.dp(10)))
	pad.add_child(col)
	col.add_child(_header())
	var row := GridContainer.new()
	row.name = "Verbs"
	row.columns = 2
	row.add_theme_constant_override("h_separation", int(UI.dp(8)))
	row.add_theme_constant_override("v_separation", int(UI.dp(8)))
	col.add_child(row)
	for k in VERBS:
		var b := UI.button(UIS.t("ui.presence." + k))
		b.name = "Verb_" + k
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_verb.bind(k))
		row.add_child(b)
		buttons[k] = b
	sub = VBoxContainer.new()
	sub.name = "Sub"
	sub.add_theme_constant_override("separation", int(UI.dp(6)))
	col.add_child(sub)
	status = UI.wrap(UI.label("", 13, UI.SMOKE))
	status.name = "Status"
	col.add_child(status)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", int(UI.dp(6)))
	col.add_child(foot)
	for k in ["hide", "report", "close"]:
		var b := UI.button(UIS.t("ui.presence." + k), "ghost")
		b.name = "Foot_" + k
		b.custom_minimum_size.y = UI.dp(40)
		b.add_theme_font_size_override("font_size", int(UI.dp(13)))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(b)
		match k:
			"hide": b.pressed.connect(hide_them)
			"report": b.pressed.connect(_show_reasons)
			"close": b.pressed.connect(close)
	_refresh()


func who() -> String:
	return str(p.get("display_name", "?"))


func pid() -> String:
	return str(p.get("player_id", ""))


func _header() -> Control:
	var h := HBoxContainer.new()
	h.name = "Header"
	h.add_theme_constant_override("separation", int(UI.dp(12)))
	h.add_child(_portrait())
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(c)
	var nm := UI.title(who(), 24)
	nm.name = "Name"
	c.add_child(nm)
	var tags: Array[String] = [UIS.t("ui.presence.live")]
	if p.get("tablemate", false):
		tags.append(UIS.t("ui.presence.tablemate"))
	if p.get("friend", false):
		tags.append(UIS.t("ui.presence.friend"))
	if p.get("regular", false):
		tags.append(UIS.t("ui.presence.regular"))
	var tl := UI.label(" · ".join(tags), 13, Badge.LIVE)
	tl.name = "Tags"
	c.add_child(tl)
	var n := int(p.get("nights_together", 0))
	var nl := UI.label(UIS.t("ui.presence.nights_none") if n == 0 else (UIS.t("ui.presence.nights_one") if n == 1 else UIS.t("ui.presence.nights", {"n": n})), 13, UI.SMOKE)
	nl.name = "Nights"
	c.add_child(nl)
	return h


## Their avatar, small: one figure in its own world, lit, idle (the only SubViewport, while the card is open).
func _portrait() -> Control:
	var box := SubViewportContainer.new()
	box.name = "Portrait"
	box.stretch = true
	box.custom_minimum_size = Vector2(UI.dp(84), UI.dp(96))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(int(UI.dp(84)), int(UI.dp(96)))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(vp)
	var f: PatronFigure = FIGURE.instantiate()
	f.look = {"avatar": Avatar.normalize(p.get("avatar", {}))}
	vp.add_child(f)
	f.play("idle")
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.95, 2.4), Vector3(0, 0.62, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.75, 0.7)
	env.environment.ambient_light_energy = 0.6
	vp.add_child(env)
	return box


## Buttons show what is left tonight: a verb used up says "Sent" and is off.
func _refresh() -> void:
	var needs: Node = main.needs if main else null
	for k in buttons:
		var left := PresenceClient.verbs_left(needs, pid(), k)
		var b: Button = buttons[k]
		b.disabled = left <= 0
		b.text = UIS.t("ui.presence." + k) if left > 0 else UIS.t("ui.presence.sent") + " · " + UIS.t("ui.presence." + k)


func _on_verb(kind: String) -> void:
	match kind:
		"drink": _show_drinks()
		"phrase": _show_phrases()
		_: send(kind, {})


func _clear_sub() -> void:
	for c in sub.get_children():
		sub.remove_child(c)
		c.queue_free()


func _show_drinks() -> void:
	_clear_sub()
	var ids: Array = BarMenu.try_order().slice(0, DRINKS)
	for id in ids:
		var b := UI.button(BarMenu.name_of(id))
		b.name = "Drink_" + str(id)
		b.custom_minimum_size.y = UI.dp(42)
		b.pressed.connect(func(): send("drink", {"drink_id": id, "band": 0}))   # band: coins do not exist yet (P10, role note)
		sub.add_child(b)


func _show_phrases() -> void:
	_clear_sub()
	var g := GridContainer.new()
	g.name = "Phrases"
	g.columns = 2
	g.add_theme_constant_override("h_separation", int(UI.dp(6)))
	g.add_theme_constant_override("v_separation", int(UI.dp(6)))
	sub.add_child(g)
	for i in PHRASES:
		var key := "ui.presence.phrase.%02d" % (i + 1)
		var b := UI.button(UIS.t(key))
		b.name = "Phrase_%02d" % (i + 1)
		b.custom_minimum_size.y = UI.dp(40)
		b.add_theme_font_size_override("font_size", int(UI.dp(13)))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): send("phrase", {"phrase": "p%02d" % (i + 1)}))
		g.add_child(b)


func _show_reasons() -> void:
	_clear_sub()
	sub.add_child(UI.label(UIS.t("ui.presence.report.title", {"name": who()}), 14, UI.CREAM))
	for r in PresenceClient.REPORT_REASONS:
		var b := UI.button(UIS.t("ui.presence.report." + r))
		b.name = "Reason_" + r
		b.custom_minimum_size.y = UI.dp(40)
		b.pressed.connect(func(): report_them(r))
		sub.add_child(b)


## Sends a verb. kind: wave | cheers | drink ({drink: id}) | phrase ({line: "01"..}). The answer lands in last_result.
func send(kind: String, payload: Dictionary) -> void:
	var needs: Node = main.needs if main else null
	PresenceClient.send_verb(needs, pid(), kind, payload, func(r: Dictionary):
		last_result = r
		if not is_inside_tree():
			return
		if not r.get("ok", false) and not r.get("queued", false):
			var why := str(r.get("reason", ""))
			status.text = UIS.t("ui.presence.err.limit") if why == "limit" else (UIS.t("ui.presence.err.offline") if why in ["offline", "off"] else UIS.t("ui.presence.err.blocked"))
			status.add_theme_color_override("font_color", UI.RED_HI)
			return
		_sent_fx(kind, payload, needs)
		_clear_sub()
		_refresh())


func _sent_fx(kind: String, payload: Dictionary, needs: Node) -> void:
	var line := ""
	var bubble := ""
	match kind:
		"wave":
			line = UIS.t("ui.presence.done.wave", {"name": who()})
			bubble = UIS.t("ui.presence.bubble.wave")
		"cheers":
			line = UIS.t("ui.presence.done.cheers", {"name": who()})
			bubble = UIS.t("ui.presence.bubble.cheers")
		"drink":
			var dn := BarMenu.name_of(str(payload.get("drink_id", "")))
			line = UIS.t("ui.presence.done.drink", {"name": who(), "drink": dn})
			bubble = dn
		"phrase":
			bubble = Inbox.phrase_text(str(payload.get("phrase", "p01")))
			line = UIS.t("ui.presence.done.phrase", {"name": who(), "line": bubble})
	# §5.1: a wave gives the sender Friends +2, cheers +2 to both (the "social_verb" row, capped per visit)
	if kind in ["wave", "cheers"] and needs != null and needs.visit_active:
		needs.apply_action("social_verb")
	status.text = line + "\n" + UIS.t("ui.presence.note", {"name": who()})
	status.add_theme_color_override("font_color", UI.GOLD)
	if main != null and main.get("player") != null and main.player.get("figure") != null:
		Badge.bubble(main.player.figure, bubble)
	if venue != null and venue.has_method("react"):
		venue.react(pid(), bubble)


func hide_them() -> void:
	PresenceClient.hide(pid())
	if venue != null:
		venue.remove_presence(pid())
	close()


func report_them(reason: String) -> void:
	PresenceClient.report(pid(), reason)
	if venue != null:
		venue.remove_presence(pid())
	close()


func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()
