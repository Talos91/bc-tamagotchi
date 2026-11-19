extends Control
## Table QR check-in (08-presence §3.1, Daniele 2026-11-19 "have my friend scan a qr code and pop in into my bar"):
## the game was opened from the table's code (presence_client.gd pending_code). The first time, one card asks how the
## player shows up (P1: Everyone / Only people here tonight / Nobody, nothing preselected; "Check in" stays off until
## one is chosen); then the server check-in; then a short result ("You're checked in tonight", the table, who is at it,
## a revival) and "Into the bar", which walks in (start_screen.gd). A failure says why (no signal: nothing is queued;
## closed; bad code) and "Not now" walks in without a check-in. New characters make their character first (§3.1).

signal finished(result: Dictionary)

const UI = preload("res://scripts/minigames/mg_ui.gd")
const UIS = preload("res://scripts/ui/ui_strings.gd")
const PresenceClient = preload("res://scripts/presence_ui/presence_client.gd")

const MODES := ["everyone", "here", "nobody"]   ## 08b §3.5

var needs: Node
var code := ""
var mode := ""
var result := {}
var col: VBoxContainer
var go: Button
var mode_buttons := {}


func open(n: Node, table_code: String) -> void:
	needs = n
	code = table_code
	name = "CheckInFlow"
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
	panel.name = "CheckInCard"
	panel.custom_minimum_size = Vector2(UI.dp(340), 0)
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG_BASE, 20, UI.LINE, 2.0))
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(UI.dp(18)))
	panel.add_child(pad)
	col = VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UI.dp(10)))
	pad.add_child(col)
	mode = PresenceClient.mode(needs)
	if mode in MODES:
		run()
	else:
		_consent()


func _clear() -> void:
	for c in col.get_children():
		col.remove_child(c)
		c.queue_free()
	mode_buttons.clear()


## P1, once: nothing preselected.
func _consent() -> void:
	_clear()
	col.add_child(UI.title(UIS.t("ui.presence.consent.title"), 24))
	col.add_child(UI.wrap(UI.label(UIS.t("ui.presence.consent.body"), 14, UI.SMOKE)))
	for m in MODES:
		var b := UI.button(UIS.t("ui.presence.consent." + m))
		b.name = "Mode_" + m
		b.toggle_mode = true
		b.pressed.connect(func(): choose(m))
		col.add_child(b)
		mode_buttons[m] = b
		var s := UI.wrap(UI.label(UIS.t("ui.presence.consent.%s_sub" % m), 12, UI.ASH))
		col.add_child(s)
	go = UI.button(UIS.t("ui.presence.checkin.go"), "primary")
	go.name = "CheckIn"
	go.disabled = true
	go.pressed.connect(func():
		PresenceClient.set_mode(needs, mode)
		run())
	col.add_child(go)
	_skip_button()


func choose(m: String) -> void:
	mode = m
	for k in mode_buttons:
		var b: Button = mode_buttons[k]
		b.set_pressed_no_signal(k == m)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, UI.box(UI.BG_PLUM if k == m else UI.BG_RAISED, 14, UI.GOLD if k == m else UI.LINE, 4.0 if k == m else 2.0))
		for fc in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(fc, UI.CREAM if k == m else UI.GOLD)
	if go:
		go.disabled = false


## The server check-in (mode already in the profile).
func run() -> void:
	_clear()
	col.add_child(UI.title(UIS.t("ui.presence.checkin.wait"), 24))
	PresenceClient.check_in(needs, code, _on_result)


func _on_result(r: Dictionary) -> void:
	result = r
	if not is_inside_tree() and col == null:
		return
	_clear()
	if r.get("ok", false):
		col.add_child(UI.title(UIS.t("ui.presence.checkin.ok"), 24))
		var t := str(r.get("label", str(r.get("table_id", "")).capitalize()))
		if t != "":
			col.add_child(UI.label(UIS.t("ui.presence.checkin.table", {"table": t}), 15, UI.CREAM))
		var mates: Array = []
		for m in r.get("tablemates", []):
			if m is Dictionary and not m.get("me", false):
				mates.append(str(m.get("display_name", "")))
		if not mates.is_empty():
			var ml := UI.wrap(UI.label(UIS.t("ui.presence.checkin.mates", {"names": ", ".join(PackedStringArray(mates))}), 15, UI.GOLD))
			ml.name = "Tablemates"
			col.add_child(ml)
		if r.get("needs", {}).get("revived", false):
			col.add_child(UI.wrap(UI.label(UIS.t("ui.presence.checkin.revived"), 15, UI.GOLD)))
		var enter := UI.button(UIS.t("ui.presence.checkin.enter"), "primary")
		enter.name = "Enter"
		enter.pressed.connect(done)
		col.add_child(enter)
		return
	var err := str(r.get("reason", "other"))
	if err == "need_mode":   # the mode was lost (another device, a reset): ask again
		_consent()
		return
	if not err in ["offline", "closed", "bad_code"]:
		err = "other"
	col.add_child(UI.title(UIS.t("ui.presence.checkin.fail"), 24))
	var el := UI.wrap(UI.label(UIS.t("ui.presence.checkin.err." + err), 15, UI.SMOKE))
	el.name = "Error"
	col.add_child(el)
	_skip_button()


func _skip_button() -> void:
	var b := UI.button(UIS.t("ui.presence.checkin.skip"), "ghost")
	b.name = "Skip"
	b.pressed.connect(func():
		PresenceClient.clear_code()
		done())
	col.add_child(b)


func done() -> void:
	finished.emit(result)
	queue_free()
