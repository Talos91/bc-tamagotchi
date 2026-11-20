extends Control
## The merch shop (lounge merch stand) and the merch wardrobe (photo booth), one panel in two modes
## (Daniele 2026-11-20; docs/design/14-merch-shop.md):
##   "shop"      every piece by category (Hats & Masks, Eyewear, Tees, Extras); tap one to try it on the preview;
##               "Pick it (free)" makes it yours (PlayerProfile.claim); owned pieces can be worn at once. The player
##               code and "Have a code?" (restore) sit at the bottom.
##   "wardrobe"  only the pieces the player owns: wear / take off.
## Wearing writes the avatar record's `merch` through Needs.set_avatar (PlayerProfile.wear); `worn_changed` tells an
## open character creator to take the new record.

signal closed
signal worn_changed(record: Dictionary)

const UI = preload("res://scripts/minigames/mg_ui.gd")
const MS = preload("res://scripts/merch/merch_strings.gd")
const Merch = preload("res://scripts/merch/merch.gd")
const FigureScene = preload("res://scenes/venue/patron_figure.tscn")
const PhoneGraphics = preload("res://scripts/phone_graphics.gd")
const PREVIEW_BG := Color("1a0b0c")

var mode := "shop"
var profile: Node                  ## PlayerProfile
var needs: Node
var cat := "head"
var selected := ""                 ## the piece being looked at ("" = none)

var _figure: Node3D
var _grid: GridContainer
var _tabs := {}
var _name: Label
var _blurb: Label
var _action: Button
var _toast: Label
var _code: Label
var _dialog: Control
var _turn := 0.35


func open(m: String, p_profile: Node = null, p_needs: Node = null) -> void:
	mode = m
	profile = p_profile if p_profile != null else get_node_or_null("/root/PlayerProfile")
	needs = p_needs if p_needs != null else get_node_or_null("/root/Needs")
	if mode == "wardrobe":
		for c in Merch.SLOTS:
			if not profile.owned_in(c).is_empty():
				cat = c
				break
	_build()
	if profile != null and not profile.changed.is_connected(_refresh):
		profile.changed.connect(_refresh)
	_refresh()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(UI.dp(8)))
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG_BASE, 18.0, UI.RED, 2.0))
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UI.dp(6)))
	panel.add_child(col)
	# title bar
	var bar := HBoxContainer.new()
	var t := UI.title(MS.t("ui.merch.wardrobe" if mode == "wardrobe" else "ui.merch.title"), 24, UI.RED_HI.lightened(0.15))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(UI.dp(56), 0)
	bar.add_child(spacer)
	bar.add_child(t)
	var x := UI.button("×", "ghost")
	x.name = "Close"
	x.custom_minimum_size = Vector2(UI.dp(56), UI.dp(52))
	x.add_theme_font_size_override("font_size", int(UI.dp(30)))
	x.pressed.connect(close)
	bar.add_child(x)
	col.add_child(bar)
	col.add_child(_preview_box())
	# category tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", int(UI.dp(4)))
	for c in Merch.SLOTS:
		var b := UI.button(MS.t("ui.merch.cat." + c), "ghost")
		b.name = "Tab_" + c
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, UI.dp(44))
		b.add_theme_font_size_override("font_size", int(UI.dp(12)))
		b.pressed.connect(func(): _go(c))
		tabs.add_child(b)
		_tabs[c] = b
	col.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, UI.dp(110))
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", int(UI.dp(6)))
	_grid.add_theme_constant_override("v_separation", int(UI.dp(6)))
	scroll.add_child(_grid)
	col.add_child(scroll)
	# the piece in focus
	_name = UI.title("", 18, UI.GOLD)
	col.add_child(_name)
	_blurb = UI.wrap(UI.label("", 13, UI.SMOKE))
	col.add_child(_blurb)
	_action = UI.button("", "primary")
	_action.name = "Action"
	_action.custom_minimum_size = Vector2(0, UI.dp(52))
	_action.pressed.connect(_on_action)
	col.add_child(_action)
	_toast = UI.wrap(UI.label("", 12, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_toast)
	if mode == "shop":
		var foot := HBoxContainer.new()
		var codes := VBoxContainer.new()
		codes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		codes.add_child(UI.label(MS.t("ui.merch.code"), 11, UI.ASH))
		_code = UI.label("", 17, UI.CREAM)
		_code.name = "Code"
		codes.add_child(_code)
		codes.add_child(UI.wrap(UI.label(MS.t("ui.merch.code_hint"), 10, UI.ASH)))
		foot.add_child(codes)
		var rb := UI.button(MS.t("ui.merch.restore"), "secondary")
		rb.name = "Restore"
		rb.custom_minimum_size = Vector2(UI.dp(120), UI.dp(44))
		rb.add_theme_font_size_override("font_size", int(UI.dp(12)))
		rb.pressed.connect(_open_restore)
		foot.add_child(rb)
		col.add_child(foot)


func _preview_box() -> Control:
	var box := SubViewportContainer.new()
	box.name = "Preview"
	box.stretch = true
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(0, UI.dp(170))
	box.gui_input.connect(_on_preview_input)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = PhoneGraphics.preview_msaa()
	vp.use_hdr_2d = true
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	box.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = PREVIEW_BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.36, 0.34)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffd9b0")
	key.light_energy = 1.2
	key.rotation_degrees = Vector3(-35, 30, 0)
	vp.add_child(key)
	var fill := OmniLight3D.new()
	fill.light_color = Color("ff3040")
	fill.light_energy = 1.8
	fill.omni_range = 6.0
	fill.position = Vector3(-2.0, 1.2, 0.6)
	vp.add_child(fill)
	_figure = FigureScene.instantiate()
	_figure.rotation.y = _turn
	vp.add_child(_figure)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.9, 2.5), Vector3(0, 0.62, 0))
	return box


func _on_preview_input(e: InputEvent) -> void:
	if e is InputEventScreenDrag or (e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_turn += e.relative.x * 0.01
		_figure.rotation.y = _turn


# ------------------------------------------------------------------ state

func _record() -> Dictionary:
	return needs.avatar() if needs != null else {}


## The record the preview shows: the player's, trying on the selected piece.
func preview_record() -> Dictionary:
	var r := _record()
	if selected != "":
		r = Merch.wear(r, selected)
	return r


func _list() -> Array:
	var out := []
	for it in Merch.items(cat):
		if mode == "shop" or profile.owns(str(it["id"])):
			out.append(str(it["id"]))
	return out


func _go(c: String) -> void:
	cat = c
	selected = ""
	_toast.text = ""
	_refresh()


func _select(id: String) -> void:
	selected = id
	_toast.text = ""
	_refresh()


func _refresh() -> void:
	if _grid == null:
		return
	for c in _tabs:
		var on: bool = c == cat
		_tabs[c].modulate = Color.WHITE if on else Color(1, 1, 1, 0.55)
	for ch in _grid.get_children():
		_grid.remove_child(ch)
		ch.queue_free()
	var worn := Merch.worn(_record())
	var ids := _list()
	if ids.is_empty() and mode == "wardrobe":
		var l := UI.wrap(UI.label(MS.t("ui.merch.empty"), 13, UI.ASH))
		l.custom_minimum_size = Vector2(UI.dp(300), 0)
		_grid.add_child(l)
	for id in ids:
		_grid.add_child(_card(id, worn.get(cat, "") == id))
	if selected == "" and not ids.is_empty():
		selected = worn.get(cat, ids[0])
	var it := Merch.item(selected)
	_name.text = str(it.get("name", ""))
	_blurb.text = str(it.get("blurb", ""))
	_action.visible = selected != ""
	if selected != "":
		if not profile.owns(selected):
			_action.text = MS.t("ui.merch.pick")
		elif worn.get(cat, "") == selected:
			_action.text = MS.t("ui.merch.take_off")
		else:
			_action.text = MS.t("ui.merch.wear")
	if _code != null:
		_code.text = _pretty(profile.code()) if profile.code() != "" else MS.t("ui.merch.code_none")
	_figure.set_look({"avatar": preview_record()})


func _card(id: String, wearing: bool) -> Button:
	var it := Merch.item(id)
	var b := Button.new()
	b.name = "Item_" + id
	b.toggle_mode = true
	b.button_pressed = id == selected
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, UI.dp(64))
	var lit: bool = id == selected
	b.add_theme_stylebox_override("normal", UI.box(UI.BG_RAISED, 12.0, UI.LINE, 1.0))
	b.add_theme_stylebox_override("hover", UI.box(UI.BG_RAISED, 12.0, UI.LINE, 1.0))
	b.add_theme_stylebox_override("pressed", UI.box(UI.BG_PLUM, 12.0, UI.RED_HI, 2.0))
	b.add_theme_stylebox_override("hover_pressed", UI.box(UI.BG_PLUM, 12.0, UI.RED_HI, 2.0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): _select(id))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = UI.dp(10)
	v.offset_right = -UI.dp(8)
	v.offset_top = UI.dp(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var sw := HBoxContainer.new()
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sw.add_theme_constant_override("separation", int(UI.dp(3)))
	var n := 0
	for k in it.get("palette", {}):
		var cr := ColorRect.new()
		cr.color = Color(str(it["palette"][k]).trim_suffix("!"))
		cr.custom_minimum_size = Vector2(UI.dp(14), UI.dp(8))
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sw.add_child(cr)
		n += 1
		if n >= 4:
			break
	var tag := UI.label(MS.t("ui.merch.wearing") if wearing else (MS.t("ui.merch.owned") if profile.owns(id)
		else MS.t("ui.merch.free")), 10, UI.GOLD if profile.owns(id) else UI.ASH, HORIZONTAL_ALIGNMENT_RIGHT)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sw.add_child(tag)
	v.add_child(sw)
	var nm := UI.label(str(it.get("name", id)), 13, UI.CREAM if not lit else UI.GOLD)
	nm.clip_text = true
	v.add_child(nm)
	return b


func _pretty(c: String) -> String:
	return c.substr(0, 4) + "-" + c.substr(4, 3) + "-" + c.substr(7) if c.length() == 10 else c


# ------------------------------------------------------------------ actions

func _on_action() -> void:
	if selected == "":
		return
	var id := selected
	if not profile.owns(id):
		var r: Dictionary = await profile.claim(id)
		if not is_inside_tree():
			return
		if r.get("ok", false):
			profile.wear(id)
			_toast.text = MS.t("ui.merch.picked")
	elif Merch.worn(_record()).get(cat, "") == id:
		profile.wear("", cat)
	else:
		profile.wear(id)
	worn_changed.emit(_record())
	_refresh()


func _open_restore() -> void:
	if is_instance_valid(_dialog):
		return
	_dialog = ColorRect.new()                     # dims the shop; the card sits in the middle
	_dialog.name = "RestoreDialog"
	_dialog.color = Color(0, 0, 0, 0.55)
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dialog)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(UI.BG_DEEP, 16.0, UI.GOLD, 2.0))
	card.custom_minimum_size = Vector2(UI.dp(320), 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(UI.dp(8)))
	card.add_child(v)
	v.add_child(UI.title(MS.t("ui.merch.restore_title"), 20, UI.GOLD))
	v.add_child(UI.wrap(UI.label(MS.t("ui.merch.restore_warn"), 12, UI.SMOKE)))
	var edit := LineEdit.new()
	edit.name = "CodeEdit"
	edit.placeholder_text = "ABCD-EFG-HJK"
	edit.max_length = 14
	edit.custom_minimum_size = Vector2(0, UI.dp(48))
	edit.add_theme_font_size_override("font_size", int(UI.dp(18)))
	v.add_child(edit)
	var msg := UI.wrap(UI.label("", 12, UI.GOLD))
	v.add_child(msg)
	var row := HBoxContainer.new()
	var cancel := UI.button("×", "ghost")
	cancel.custom_minimum_size = Vector2(UI.dp(56), UI.dp(48))
	cancel.pressed.connect(func(): _dialog.queue_free())
	row.add_child(cancel)
	var go := UI.button(MS.t("ui.merch.restore_go"), "primary")
	go.name = "RestoreGo"
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func():
		var r: Dictionary = await profile.restore(edit.text)
		if not is_instance_valid(msg):
			return
		var reason := str(r.get("reason", ""))
		msg.text = MS.t("ui.merch.restore_ok") if r.get("ok", false) else MS.t({"bad_code": "ui.merch.restore_bad",
			"rate_limited": "ui.merch.restore_wait"}.get(reason, "ui.merch.restore_off"))
		if r.get("ok", false):
			worn_changed.emit(_record())
			_refresh())
	row.add_child(go)
	v.add_child(row)


func close() -> void:
	closed.emit()
	queue_free()
