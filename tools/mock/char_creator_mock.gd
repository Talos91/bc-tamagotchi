extends SceneTree
## Static mock of the character-creator screen (design review only, docs/design/07-character-creator.md).
## Not game code: builds three 1080x1920 portrait frames from the real parts libraries and saves PNGs.
## Needs a GPU window (not --headless). From the repo root:
##   Godot --path game --script "<abs path>/tools/mock/char_creator_mock.gd" -- <out_dir>
## Writes <out_dir>/mock-01-body-skin.png, mock-02-hair.png, mock-03-vibe-name.png.

const W := 1080
const H := 1920
const BG := Color("120708")
const PANEL := Color("1c0d0c")
const CARD := Color("2a1514")
const CARD_ON := Color("4a1a1c")
const NEON := Color("e0303a")
const GOLD := Color("e8a030")
const TEXT := Color("e4dde6")
const DIM := Color("9a8a8c")

const SKINS := ["F0D2B6", "E4BA96", "D2A07A", "BC8860", "A06E4A", "845636", "6A432C", "4E3022"]
const HAIRS := {"HairBlack": "1E1616", "HairDarkBrown": "3E2618", "HairBrown": "6A4228", "HairAuburn": "8E3A1E",
	"HairBleach": "E8CF86", "HairGrey": "8E8890", "HairRose": "B05A64", "HairSilver": "50545F"}

var lato: FontFile
var lato_black: FontFile
var kristi: FontFile
var frames := 0
var shot := 0
var out_dir := ""
var vp: SubViewport
var looks := []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://").path_join("../docs/art/screens/char-creator")
	lato = load("res://assets/fonts/Lato-Bold.ttf")
	lato_black = load("res://assets/fonts/Lato-Black.ttf")
	kristi = load("res://assets/fonts/Kristi-Regular.ttf")
	# Three looks, one per frame (body, head, hair, face, top, bottom, shoes, colours).
	looks = [
		{"body": "regular", "head": "round", "hair": "bob", "face": ["happy", "flat", "smile"], "top": "denim_jacket",
			"bottom": "jeans", "shoes": "sneakers", "acc": [],
			"col": {"skin": "D2A07A", "hair": "1E1616", "top": "3F5878", "top_trim": "D9C9A6", "top_accent": "ECE6E0",
				"bottom": "241E26", "shoes": "ECE6E0", "shoes_trim": "D9C9A6"}},
		{"body": "regular", "head": "soft", "hair": "quiff", "face": ["dot", "arched", "grin"], "top": "leather",
			"bottom": "jeans", "shoes": "boots", "acc": [],
			"col": {"skin": "A06E4A", "hair": "E8CF86", "top": "241E26", "top_trim": "B4B0B8", "top_accent": "ECE6E0",
				"bottom": "4C6EA6", "shoes": "403A3E", "shoes_trim": "403A3E"}},
		{"body": "petite", "head": "heart", "hair": "long", "face": ["lashes", "flat", "smile"], "top": "blouse",
			"bottom": "skirt", "shoes": "loafers", "acc": [],
			"col": {"skin": "E4BA96", "hair": "8E3A1E", "top": "B0141C", "top_trim": "D9C9A6",
				"bottom": "241E26", "shoes": "221110", "shoes_trim": "221110"}},
	]
	_build(0)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 45:
		return false
	var names := ["mock-01-body-skin.png", "mock-02-hair.png", "mock-03-vibe-name.png"]
	var img := vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var p := out_dir.path_join(names[shot])
	print("mock saved: ", p, " err=", img.save_png(p))
	shot += 1
	if shot >= names.size():
		return true
	vp.queue_free()
	_build(shot)
	frames = 0
	return false


# ------------------------------------------------------------------ frame

func _build(i: int) -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.use_hdr_2d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var ui := Control.new()
	ui.size = Vector2(W, H)
	vp.add_child(ui)
	_rect(ui, Rect2(0, 0, W, H), BG)
	# preview area with the character
	var look: Dictionary = looks[i]
	_figure_view(ui, Rect2(0, 160, W, 850), look, 4.6, 0.74, 28.0, true)
	_top_bar(ui, i)
	_preview_overlays(ui)
	# bottom panel
	_rect(ui, Rect2(0, 1010, W, H - 1010), PANEL)
	_rect(ui, Rect2(0, 1010, W, 3), NEON.darkened(0.3))
	_tabs(ui, i)
	match i:
		0: _step_body_skin(ui, look)
		1: _step_hair(ui, look)
		2: _step_vibe_name(ui)
	_next_button(ui, i)


func _top_bar(ui: Control, i: int) -> void:
	_label(ui, "‹", Vector2(40, 22), 72, TEXT, lato)
	_label(ui, "Who are you tonight?", Vector2(0, 26), 76, NEON.lightened(0.15), kristi, W, HORIZONTAL_ALIGNMENT_CENTER)
	var steps := ["Step 1 of 4", "Step 2 of 4", "Step 4 of 4"]
	_label(ui, steps[i], Vector2(0, 124), 28, DIM, lato, W, HORIZONTAL_ALIGNMENT_CENTER)


func _preview_overlays(ui: Control) -> void:
	# rotate hint and dice (randomise)
	_pill(ui, Rect2(40, 930, 250, 64), "⟲  drag to turn", 26, DIM)
	_pill(ui, Rect2(W - 290, 930, 250, 64), "⚄  Surprise me", 26, GOLD)


func _tabs(ui: Control, i: int) -> void:
	var names := ["Body", "Hair", "Outfit", "You"]
	var on: int = [0, 1, 3][i]
	var w := (W - 80) / 4.0
	for k in names.size():
		var r := Rect2(40 + k * w, 1040, w - 12, 76)
		_rect(ui, r, CARD_ON if k == on else CARD)
		if k == on:
			_rect(ui, Rect2(r.position.x, r.end.y - 6, r.size.x, 6), NEON)
		var done: bool = k < on
		_label(ui, ("✓ " if done else "") + names[k], r.position + Vector2(0, 18), 32,
			TEXT if k == on else (GOLD if done else DIM), lato, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _next_button(ui: Control, i: int) -> void:
	var r := Rect2(40, 1790, W - 80, 100)
	_rect(ui, r, NEON)
	var t: String = ["Next: Hair", "Next: Outfit", "Into the bar"][i]
	_label(ui, t, r.position + Vector2(0, 24), 44, Color.WHITE, lato_black, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


# ------------------------------------------------------------------ steps

func _step_body_skin(ui: Control, look: Dictionary) -> void:
	_label(ui, "Build", Vector2(40, 1140), 34, TEXT, lato)
	var bodies := ["petite", "regular", "broad"]
	var cw := (W - 80 - 2 * 20) / 3.0
	for k in bodies.size():
		var r := Rect2(40 + k * (cw + 20), 1190, cw, 330)
		_rect(ui, r, CARD_ON if bodies[k] == look["body"] else CARD)
		var l := look.duplicate(true)
		l["body"] = bodies[k]
		_figure_view(ui, Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, 260)), l, 3.4, 0.78, 26.0, false)
		_label(ui, bodies[k].capitalize(), Vector2(r.position.x, r.end.y - 58), 30,
			TEXT if bodies[k] == look["body"] else DIM, lato, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if bodies[k] == look["body"]:
			_frame(ui, r, NEON, 4)
	_label(ui, "Skin", Vector2(40, 1550), 34, TEXT, lato)
	for k in 6:
		var c := Vector2(40 + 50 + k * 168, 1680)
		_swatch(ui, c, 56, Color(SKINS[k]), SKINS[k] == look["col"]["skin"])


func _step_hair(ui: Control, look: Dictionary) -> void:
	_label(ui, "Style", Vector2(40, 1140), 34, TEXT, lato)
	var styles := ["crop", "quiff", "bob", "long"]
	var cw := (W - 80 - 3 * 16) / 4.0
	for k in styles.size():
		var r := Rect2(40 + k * (cw + 16), 1190, cw, 300)
		var on: bool = styles[k] == look["hair"]
		_rect(ui, r, CARD_ON if on else CARD)
		var l := look.duplicate(true)
		l["hair"] = styles[k]
		_figure_view(ui, Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, 236)), l, 2.3, 1.30, 24.0, false, 18.0)
		_label(ui, styles[k].capitalize(), Vector2(r.position.x, r.end.y - 56), 30, TEXT if on else DIM, lato,
			r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if on:
			_frame(ui, r, NEON, 4)
	_label(ui, "Colour", Vector2(40, 1520), 34, TEXT, lato)
	var keys := HAIRS.keys()
	for k in keys.size():
		var c := Vector2(40 + 125 + (k % 4) * 250, 1615 + (k / 4) * 110)
		_swatch(ui, c, 44, Color(HAIRS[keys[k]]), HAIRS[keys[k]] == look["col"]["hair"])


func _step_vibe_name(ui: Control) -> void:
	_label(ui, "Your vibe", Vector2(40, 1135), 34, TEXT, lato)
	var vibes := [
		["Night Owl", "Nightlife fades 10% slower", "Jules waves first"],
		["Music Nerd", "Music fades 10% slower", "Tong waves first"],
		["Social Butterfly", "Friends fades 10% slower", "Tt waves first"],
		["Easy Sipper", "Drinks fades 10% slower", "Nam waves first"],
	]
	var cw := (W - 80 - 20) / 2.0
	for k in vibes.size():
		var r := Rect2(40 + (k % 2) * (cw + 20), 1180 + (k / 2) * 170, cw, 154)
		var on: bool = k == 0
		_rect(ui, r, CARD_ON if on else CARD)
		_label(ui, vibes[k][0], r.position + Vector2(24, 16), 36, TEXT if on else TEXT.darkened(0.15), lato_black)
		_label(ui, vibes[k][1], r.position + Vector2(24, 66), 25, GOLD if on else DIM, lato)
		_label(ui, vibes[k][2], r.position + Vector2(24, 104), 25, DIM, lato)
		if on:
			_frame(ui, r, NEON, 4)
	_label(ui, "Your name", Vector2(40, 1530), 34, TEXT, lato)
	var f := Rect2(40, 1580, W - 80, 96)
	_rect(ui, f, Color("0c0505"))
	_frame(ui, f, GOLD, 3)
	_label(ui, "Mai|", f.position + Vector2(28, 22), 42, TEXT, lato)
	_label(ui, "3 / 16", f.position + Vector2(f.size.x - 140, 30), 28, DIM, lato)
	_label(ui, "Shown to staff and regulars. Change it any time, free.", Vector2(40, 1696), 25, DIM, lato)


# ------------------------------------------------------------------ 3D

func _figure_view(ui: Control, r: Rect2, look: Dictionary, dist: float, aim_y: float, fov: float, big: bool,
		yaw_deg: float = 22.0) -> void:
	var box := SubViewportContainer.new()
	box.position = r.position
	box.size = r.size
	box.stretch = true
	ui.add_child(box)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = false
	sv.msaa_3d = Viewport.MSAA_4X
	sv.use_hdr_2d = true
	sv.size = Vector2i(r.size)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a0e10") if big else Color("1e0b0c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.36, 0.34)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var cam := Camera3D.new()
	cam.fov = fov
	sv.add_child(cam)
	cam.look_at_from_position(Vector3(0, aim_y + dist * 0.12, dist), Vector3(0, aim_y, 0))
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffd9b0")
	key.light_energy = 1.25
	key.rotation_degrees = Vector3(-35, 30, 0)
	sv.add_child(key)
	var fill := OmniLight3D.new()
	fill.light_color = Color("ff3040")
	fill.light_energy = 2.2
	fill.omni_range = 6.0
	fill.position = Vector3(-2.0, 1.2, 0.6)
	sv.add_child(fill)
	var rim := OmniLight3D.new()
	rim.light_color = Color("ffb070")
	rim.light_energy = 2.5
	rim.omni_range = 5.0
	rim.position = Vector3(1.4, 2.0, -1.6)
	sv.add_child(rim)
	if big:
		var disc := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.6
		cyl.bottom_radius = 0.6
		cyl.height = 0.04
		disc.mesh = cyl
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("3a1a1c")
		m.roughness = 0.4
		disc.material_override = m
		disc.position = Vector3(0, -0.02, 0)
		sv.add_child(disc)
		var spot := SpotLight3D.new()
		spot.light_color = Color("ff5a4a")
		spot.light_energy = 3.0
		spot.spot_range = 5.0
		spot.spot_angle = 28.0
		spot.position = Vector3(0, 3.2, 0.4)
		spot.rotation_degrees = Vector3(-90, 0, 0)
		sv.add_child(spot)
	var fig := _figure(look)
	fig.rotation_degrees.y = yaw_deg
	sv.add_child(fig)


func _figure(look: Dictionary) -> Node3D:
	var node: Node3D = load("res://assets/chars/parts/parts_%s.glb" % look["body"]).instantiate()
	var ap := BCChars.setup_animations(node)
	var face: Array = look["face"]
	var ids := ["head_" + look["head"], "hair_" + look["hair"], "eyes_" + face[0], "mouth_" + face[2],
		"top_" + look["top"], "bottom_" + look["bottom"], "shoes_" + look["shoes"], "hands"]
	if face[1] != "none":
		ids.append("brows_" + face[1])
	ids.append_array(look["acc"])
	BCChars.show_parts(node, ids)
	for slot in look["col"]:
		BCChars.recolour(node, slot, Color(look["col"][slot]))
	if ap:
		ap.play("idle")
		ap.seek(0.6, true)
		ap.pause()
	return node


# ------------------------------------------------------------------ 2D helpers

func _rect(p: Control, r: Rect2, c: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.position = r.position
	cr.size = r.size
	cr.color = c
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(cr)
	return cr


func _frame(p: Control, r: Rect2, c: Color, t: float) -> void:
	_rect(p, Rect2(r.position, Vector2(r.size.x, t)), c)
	_rect(p, Rect2(r.position + Vector2(0, r.size.y - t), Vector2(r.size.x, t)), c)
	_rect(p, Rect2(r.position, Vector2(t, r.size.y)), c)
	_rect(p, Rect2(r.position + Vector2(r.size.x - t, 0), Vector2(t, r.size.y)), c)


func _label(p: Control, t: String, pos: Vector2, sz: int, c: Color, f: Font, width: float = 0.0,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	if width > 0.0:
		l.size = Vector2(width, sz * 1.4)
	l.horizontal_alignment = align
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	p.add_child(l)
	return l


func _pill(p: Control, r: Rect2, t: String, sz: int, c: Color) -> void:
	_rect(p, r, Color(0, 0, 0, 0.45))
	_frame(p, r, c.darkened(0.2), 2)
	_label(p, t, r.position + Vector2(0, (r.size.y - sz * 1.3) / 2.0), sz, c, lato, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _swatch(p: Control, centre: Vector2, radius: float, c: Color, on: bool) -> void:
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(radius))
	if on:
		sb.border_color = NEON
		sb.set_border_width_all(6)
		sb.expand_margin_left = 6
		sb.expand_margin_right = 6
		sb.expand_margin_top = 6
		sb.expand_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = centre - Vector2(radius, radius)
	panel.size = Vector2(radius * 2, radius * 2)
	p.add_child(panel)
