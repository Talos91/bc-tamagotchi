extends Control
## The character creator (docs/design/07-character-creator.md §5; answers DECISIONS 2026-11-09). One screen, four tabs
## (Body · Hair · Outfit · You) over a live 3D preview that turns with a drag; "Surprise me" rolls every slot.
## Portrait: preview on top, options in the thumb half. Landscape: preview left, options right.
## Opened by the start screen (new character, Edit look, the one-time card for older saves) and the photo booth in the
## lounge. It never writes the save itself: `done` hands the record, name and personality to the caller, which calls
## Needs.set_avatar(). Only the chosen body's parts library is loaded (one at a time); the hair thumbnails reuse it and
## render once.
##   mode "new"  : steps in order, last button "Into the bar"; ‹ goes back a step
##   mode "edit" : every tab open, "Done"
##   mode "name" : opens on the You tab (a "Keep this look" save with no name yet)
## The × (top right, every mode) always leaves without saving. A refused name never fails silently: the reason shows
## right above the button, the You tab opens with the name field first (owner item 26, 2026-11-09: on the phone the
## field and its reason were below the fold, so Done looked dead).

signal done(record: Dictionary, display_name: String, personality: String)
signal cancelled

const UI = preload("res://scripts/minigames/mg_ui.gd")
const UIS = preload("res://scripts/ui/ui_strings.gd")
const Avatar = preload("res://scripts/avatar.gd")
const Rules = preload("res://scripts/rules.gd")
const Cast = preload("res://scripts/cast.gd")
const FigureScene = preload("res://scenes/venue/patron_figure.tscn")

const TABS := ["body", "hair", "outfit", "you"]
const PREVIEW_BG := Color("2a0e10")

var mode := "new"
var record: Dictionary = {}
var display_name := ""
var personality := ""
var tab := 0
var reached := 0                 ## furthest tab reached (mode "new" opens tabs in order)

var _preview: SubViewport
var _figure: Node3D
var _turn := 0.35
var _main: BoxContainer
var _content: VBoxContainer
var _tabs: Array[Button] = []
var _next: Button
var _back: Button
var _status: Label               ## why Done / Into the bar refused, always on screen above the button
var _scroll: ScrollContainer
var _name_edit: LineEdit
var _name_err: Label
var _step: Label
var _landscape := false
## Phone browsers: the web export has no on-screen keyboard bridge (export preset html/experimental_virtual_keyboard
## is off), so a LineEdit never gets a keyboard there and a new character could never type a name (owner item 26).
## On a touch web build a tap on the name field opens the browser's own prompt instead. Tests set both.
var use_prompt := OS.has_feature("web") and DisplayServer.is_touchscreen_available()
var prompt_name: Callable = _browser_prompt
var _prompting := false


## `rec` the look to start from, `who` and `p` the current name and personality.
func open(m: String, rec: Dictionary, who: String, p: String) -> void:
	UIS.install()
	mode = m
	record = Avatar.normalize(rec)
	display_name = who
	personality = p
	tab = 3 if m == "name" else 0
	reached = 3 if m != "new" else 0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	get_viewport().size_changed.connect(_on_resize)


func _on_resize() -> void:
	if _is_landscape() != _landscape:
		_build()


func _is_landscape() -> bool:
	var s := get_viewport_rect().size
	return s.x > s.y


# --- Layout --------------------------------------------------------------------------------------

func _build() -> void:
	for c in get_children():
		c.queue_free()
	_tabs.clear()
	_landscape = _is_landscape()
	var bg := ColorRect.new()
	bg.color = UI.BG_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_main = HBoxContainer.new() if _landscape else VBoxContainer.new()
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.add_theme_constant_override("separation", 0)
	add_child(_main)
	# Left / top: title bar + preview
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0 if _landscape else 1.1
	left.add_theme_constant_override("separation", 0)
	_main.add_child(left)
	left.add_child(_title_bar())
	left.add_child(_preview_box())
	# Right / bottom: tabs, options, next
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	var sb := UI.box(UI.BG_BASE, 0, UI.RED, 0.0)
	sb.border_color = UI.RED_HI
	sb.border_width_top = 0 if _landscape else 3
	sb.border_width_left = 3 if _landscape else 0
	panel.add_theme_stylebox_override("panel", sb)
	_main.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, int(UI.dp(14)))
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(UI.dp(10)))
	pad.add_child(col)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", int(UI.dp(4)))
	col.add_child(tabs)
	for i in TABS.size():
		var b := UI.button(UIS.t("ui.avatar.tab." + TABS[i]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = UI.dp(40)
		b.add_theme_font_size_override("font_size", int(UI.dp(14)))
		b.pressed.connect(_go_tab.bind(i))
		b.name = "Tab_" + TABS[i]
		tabs.add_child(b)
		_tabs.append(b)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", int(UI.dp(8)))
	_scroll.add_child(_content)
	_status = UI.wrap(UI.label("", 14, UI.RED_HI.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER))
	_status.name = "Status"
	_status.visible = false
	col.add_child(_status)
	_next = UI.button("", "primary")
	_next.name = "Next"
	_next.pressed.connect(_on_next)
	col.add_child(_next)
	_show_tab()


func _title_bar() -> Control:
	var bar := VBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	var top := HBoxContainer.new()
	bar.add_child(top)
	# ‹ back a step (new character, step 2 on) on the left; × leave on the right. Both are big thumb targets
	# (64 dp), not just the glyph.
	_back = _corner("‹", "Back")
	_back.pressed.connect(_on_back)
	top.add_child(_back)
	var t := UI.title(UIS.t("ui.avatar.title"), 24, UI.RED_HI.lightened(0.15))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var close := _corner("×", "Close")
	close.pressed.connect(_on_close)
	top.add_child(close)
	_step = UI.label("", 12, UI.ASH, HORIZONTAL_ALIGNMENT_CENTER)
	bar.add_child(_step)
	return bar


func _corner(glyph: String, nm: String) -> Button:
	var b := UI.button(glyph, "ghost")
	b.name = nm
	b.custom_minimum_size = Vector2(UI.dp(64), UI.dp(56))
	b.size_flags_vertical = Control.SIZE_FILL
	b.add_theme_font_size_override("font_size", int(UI.dp(30)))
	return b


func _preview_box() -> Control:
	var box := SubViewportContainer.new()
	box.name = "Preview"
	box.stretch = true
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(UI.dp(160), UI.dp(200))
	box.gui_input.connect(_on_preview_input)
	_preview = SubViewport.new()
	_preview.own_world_3d = true
	_preview.msaa_3d = Viewport.MSAA_2X
	_preview.use_hdr_2d = true
	_preview.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	box.add_child(_preview)
	_stage(_preview, true)
	_figure = FigureScene.instantiate()
	_figure.rotation.y = _turn
	_preview.add_child(_figure)
	_figure.set_look({"avatar": record})
	var cam := Camera3D.new()
	cam.fov = 30.0
	_preview.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.95, 3.3), Vector3(0, 0.58, 0))
	# Pills over the preview: the turn hint and "Surprise me"
	var over := HBoxContainer.new()
	over.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	over.offset_top = -UI.dp(52)
	over.offset_bottom = -UI.dp(8)
	over.offset_left = UI.dp(12)
	over.offset_right = -UI.dp(12)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(over)
	var hint := UI.label(UIS.t("ui.avatar.turn"), 12, UI.ASH)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	over.add_child(hint)
	var dice := UI.button(UIS.t("ui.avatar.surprise"))
	dice.name = "Surprise"
	dice.custom_minimum_size.y = UI.dp(40)
	dice.add_theme_font_size_override("font_size", int(UI.dp(13)))
	dice.pressed.connect(_on_surprise)
	over.add_child(dice)
	return box


## Lights and floor of a preview world (red fill, warm key and rim, as the venue).
func _stage(vp: SubViewport, disc: bool) -> void:
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
	var rim := OmniLight3D.new()
	rim.light_color = Color("ffb070")
	rim.light_energy = 2.0
	rim.omni_range = 5.0
	rim.position = Vector3(1.4, 2.0, -1.6)
	vp.add_child(rim)
	if disc:
		var d := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.5
		cyl.height = 0.04
		d.mesh = cyl
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("3a1a1c")
		d.material_override = m
		d.position.y = -0.02
		vp.add_child(d)


# --- Tabs ----------------------------------------------------------------------------------------

func _go_tab(i: int) -> void:
	if i > reached:
		return
	if tab == 3 and i != 3 and is_instance_valid(_name_edit):
		display_name = _name_edit.text
	tab = i
	_show_tab()


func _show_tab() -> void:
	for c in _content.get_children():
		c.queue_free()
	_name_edit = null
	_name_err = null
	_say("")
	if is_instance_valid(_back):
		_back.modulate.a = 1.0 if (mode == "new" and tab > 0) else 0.0
		_back.disabled = not (mode == "new" and tab > 0)
	for i in _tabs.size():
		var b := _tabs[i]
		var on := i == tab
		b.disabled = i > reached
		var mark := "✓ " if i < reached and not on and mode == "new" else ""
		b.text = mark + UIS.t("ui.avatar.tab." + TABS[i])
		b.add_theme_stylebox_override("normal", UI.box(UI.BG_PLUM if on else UI.BG_RAISED, 10, UI.RED_HI if on else UI.LINE, 2.0))
		b.add_theme_color_override("font_color", UI.CREAM if on else (UI.GOLD if i < reached else UI.ASH))
	_step.text = UIS.t("ui.avatar.step", {"n": tab + 1})
	match TABS[tab]:
		"body":
			_row(UIS.t("ui.avatar.row.build"))
			_chips("body", Avatar.data()["bodies"], "ui.avatar.body.", 4)
			_row(UIS.t("ui.avatar.row.skin"))
			_swatches("skin", Avatar.data()["skins"])
			_row(UIS.t("ui.avatar.row.head"))
			_chips("head", Avatar.data()["heads"], "ui.avatar.head.", 4)
			_row(UIS.t("ui.avatar.row.face"))
			_chips("face", Avatar.data()["face_order"], "ui.avatar.face.", 3)
		"hair":
			_row(UIS.t("ui.avatar.row.style"))
			_hair_cards()
			_row(UIS.t("ui.avatar.row.hair_colour"))
			_swatches("hair_colour", Avatar.data()["hair_colours"])
		"outfit":
			_row(UIS.t("ui.avatar.row.look"))
			_chips("look", Avatar.data()["look_order"], "ui.avatar.look.", 3)
			_row(UIS.t("ui.avatar.row.top_colour"))
			var look: Dictionary = Avatar.data()["looks"].get(record["look"], {})
			_swatches("top_colour", look.get("top_colours", []))
		"you":
			_row(UIS.t("ui.avatar.row.name"))         # the name first: it is the one thing Done can refuse
			_name_row()
			_row(UIS.t("ui.avatar.row.vibe"))
			_vibes()
	if tab < 3:
		_next.text = UIS.t("ui.avatar.next", {"tab": UIS.t("ui.avatar.tab." + TABS[tab + 1])}) if mode == "new" else UIS.t("ui.avatar.done")
	else:
		_next.text = UIS.t("ui.avatar.enter") if mode == "new" else UIS.t("ui.avatar.done")


func _row(text: String) -> void:
	var l := UI.label(text, 15, UI.CREAM)
	_content.add_child(l)


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", int(UI.dp(6)))
	g.add_theme_constant_override("v_separation", int(UI.dp(6)))
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(g)
	return g


func _choice(text: String, on: bool) -> Button:
	var b := UI.button(text)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = UI.dp(44)
	b.add_theme_font_size_override("font_size", int(UI.dp(14)))
	b.add_theme_stylebox_override("normal", UI.box(UI.BG_PLUM if on else UI.BG_RAISED, 12, UI.RED_HI if on else UI.LINE, 3.0 if on else 1.0))
	b.add_theme_stylebox_override("hover", b.get_theme_stylebox("normal"))
	b.add_theme_color_override("font_color", UI.CREAM if on else UI.SMOKE)
	return b


func _chips(key: String, ids: Array, prefix: String, cols: int) -> void:
	var g := _grid(cols)
	for id in ids:
		var b := _choice(UIS.t(prefix + str(id)), record.get(key) == id)
		b.name = "%s_%s" % [key, id]
		b.pressed.connect(_pick.bind(key, id))
		g.add_child(b)


func _swatches(key: String, names: Array) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", int(UI.dp(10)))
	flow.add_theme_constant_override("v_separation", int(UI.dp(10)))
	_content.add_child(flow)
	for sw in names:
		var on: bool = record.get(key) == sw
		var b := Button.new()
		b.name = "%s_%s" % [key, sw]
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = str(sw)
		b.custom_minimum_size = Vector2(UI.dp(40), UI.dp(40))
		var st := UI.box(Color(Avatar.hex(sw)), 20, UI.RED_HI if on else UI.LINE, 4.0 if on else 1.0)
		for s in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(s, st)
		b.pressed.connect(_pick.bind(key, sw))
		flow.add_child(b)


## Hair styles as small renders of the current character with that style (rendered once, the same library).
func _hair_cards() -> void:
	var g := _grid(4)
	for id in Avatar.data()["hairs"]:
		var on: bool = record.get("hair") == id
		var card := PanelContainer.new()
		card.name = "hair_" + str(id)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UI.box(UI.BG_PLUM if on else UI.BG_RAISED, 12, UI.RED_HI if on else UI.LINE, 3.0 if on else 1.0))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(e: InputEvent):
			if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
				_pick("hair", id))
		g.add_child(card)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(v)
		var box := SubViewportContainer.new()
		box.stretch = true
		box.custom_minimum_size = Vector2(UI.dp(60), UI.dp(60))
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(box)
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		box.add_child(vp)
		_stage(vp, false)
		var r := record.duplicate(true)
		r["hair"] = id
		var f: Node3D = FigureScene.instantiate()
		f.rotation.y = 0.3
		vp.add_child(f)
		f.set_look({"avatar": r})
		var cam := Camera3D.new()
		cam.fov = 26.0
		vp.add_child(cam)
		var head_y := 1.0 if record["body"] != "tall" else 1.1
		cam.look_at_from_position(Vector3(0, head_y + 0.1, 1.5), Vector3(0, head_y - 0.02, 0))
		var l := UI.label(UIS.t("ui.avatar.hair." + str(id)), 12, UI.CREAM if on else UI.SMOKE, HORIZONTAL_ALIGNMENT_CENTER)
		v.add_child(l)


func _vibes() -> void:
	var g := _grid(2)
	for p in Avatar.data()["personalities"]:
		var on: bool = personality == p
		var b := _choice("", on)
		b.name = "vibe_" + p
		b.custom_minimum_size.y = UI.dp(84)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(UI.dp(10)))
		b.add_child(v)
		v.add_child(UI.label(UIS.t("ui.avatar.vibe." + p), 15, UI.CREAM))
		var need: String = Rules.PERSONALITIES[p]
		v.add_child(UI.label(UIS.t("ui.avatar.vibe.effect", {"need": tr("need.%s.name" % need)}), 11, UI.GOLD if on else UI.ASH))
		v.add_child(UI.label(UIS.t("ui.avatar.vibe.greeter", {"name": Cast.name_of(Avatar.greeter(p))}), 11, UI.ASH))
		b.pressed.connect(func():
			if is_instance_valid(_name_edit):
				display_name = _name_edit.text
			personality = p
			_show_tab())
		g.add_child(b)


func _name_row() -> void:
	_name_edit = LineEdit.new()
	_name_edit.name = "NameEdit"
	_name_edit.text = display_name
	_name_edit.placeholder_text = UIS.t("ui.avatar.name.placeholder")
	_name_edit.max_length = int(Avatar.data()["name"]["max"]) + 4
	_name_edit.custom_minimum_size.y = UI.dp(48)
	_name_edit.add_theme_font_size_override("font_size", int(UI.dp(18)))
	_name_edit.add_theme_stylebox_override("normal", UI.box(Color("0c0505"), 10, UI.GOLD, 2.0))
	_name_edit.add_theme_stylebox_override("focus", UI.box(Color("0c0505"), 10, UI.GOLD, 3.0))
	_name_edit.text_changed.connect(func(s: String):
		display_name = s
		if is_instance_valid(_name_err):
			_name_err.text = ""
		_say(""))
	_name_edit.text_submitted.connect(func(_s): _on_next())
	_name_edit.focus_entered.connect(_on_name_focus)
	_content.add_child(_name_edit)
	_name_err = UI.wrap(UI.label("", 12, UI.RED_HI))
	_name_err.name = "NameError"
	_content.add_child(_name_err)
	_content.add_child(UI.wrap(UI.label(UIS.t("ui.avatar.name.hint"), 12, UI.ASH)))


## Phone web build: the browser's prompt types the name (see use_prompt).
func _on_name_focus() -> void:
	if use_prompt and not _prompting:
		_prompting = true
		_ask_name.call_deferred()              # not inside the LineEdit's own focus handling (it re-grabs focus)


func _ask_name() -> void:
	if not is_instance_valid(_name_edit):
		_prompting = false
		return
	_name_edit.release_focus()
	var v: Variant = prompt_name.call(_name_edit.text)
	if v is String:
		var s := String(v).strip_edges().left(int(Avatar.data()["name"]["max"]) + 4)
		_name_edit.text = s
		display_name = s
		if is_instance_valid(_name_err):
			_name_err.text = ""
		_say("")
	_prompting = false


func _browser_prompt(current: String) -> Variant:
	var js := "(function(){var r = window.prompt(%s, %s); return r === null ? null : String(r);})()" % [
		JSON.stringify(UIS.t("ui.avatar.name.placeholder")), JSON.stringify(current)]
	return JavaScriptBridge.eval(js, true)


# --- Choices -------------------------------------------------------------------------------------

func _pick(key: String, value: Variant) -> void:
	record[key] = value
	if key == "look":
		var tc: Array = Avatar.data()["looks"][value]["top_colours"]
		if not tc.has(record.get("top_colour")):
			record["top_colour"] = tc[0]
	_refresh_figure()
	_show_tab()


func _refresh_figure() -> void:
	if is_instance_valid(_figure):
		_figure.set_look({"avatar": record})


func _on_surprise() -> void:
	var r := Avatar.random_record()
	r["worn"] = record.get("worn", {})
	record = r
	_refresh_figure()
	_show_tab()


func _on_preview_input(e: InputEvent) -> void:
	var dx := 0.0
	if e is InputEventScreenDrag:
		dx = e.relative.x
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		dx = e.relative.x
	if dx != 0.0 and is_instance_valid(_figure):
		_turn += dx * 0.012
		_figure.rotation.y = _turn


func _on_back() -> void:
	if mode == "new" and tab > 0:
		_go_tab(tab - 1)
		return
	_on_close()


## × : leave without saving, from any step and any mode.
func _on_close() -> void:
	_drop_keyboard()
	cancelled.emit()


## The status line above the button (empty hides it).
func _say(text: String) -> void:
	if is_instance_valid(_status):
		_status.text = text
		_status.visible = text != ""


## Take the name field's focus away so the phone keyboard closes and the next tap reaches the buttons.
func _drop_keyboard() -> void:
	if is_instance_valid(_name_edit):
		display_name = _name_edit.text
		_name_edit.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()


func _on_next() -> void:
	_drop_keyboard()
	if tab < 3 and mode == "new":
		reached = maxi(reached, tab + 1)
		_go_tab(tab + 1)
		return
	if tab < 3:
		_finish()
		return
	_finish()


## The name is checked here (Avatar.check_name); a bad one keeps the player on the You tab with the reason.
func _finish() -> void:
	if is_instance_valid(_name_edit):
		display_name = _name_edit.text
	var why := Avatar.check_name(display_name)
	if why != "":
		if tab != 3:
			reached = 3
			tab = 3
			_show_tab()
		var msg := UIS.t("ui.avatar.name.err." + why)
		if is_instance_valid(_name_err):
			_name_err.text = msg
		_say(msg)
		if is_instance_valid(_scroll):
			_scroll.scroll_vertical = 0               # the name field is the first row of the You tab
		return
	done.emit(record.duplicate(true), Avatar.clean_name(display_name), personality)


## Tests: choose without tapping.
func choose(key: String, value: Variant) -> void:
	if key == "personality":
		personality = value
		_show_tab()
	elif key == "name":
		display_name = value
		if is_instance_valid(_name_edit):
			_name_edit.text = value
	else:
		_pick(key, value)
