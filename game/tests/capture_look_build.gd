extends SceneTree
## Look build, step 1: the voxel cement floor (Daniele 2026-11-02, on look D: "the floor looks like a texture that
## hasn't loaded, make it match the rest of the map style"). A prototype on top of the look test
## (capture_look_test.gd): it loads main.tscn as built, applies look D at runtime exactly as the test did, and swaps the
## test's smooth noise cement for a voxel cement: flat 0.1 m cells (two kit voxels) in stepped greys, as the kit and
## the old running-bond floor are built. No game file changes.
##   A  as built (today)
##   D  look D as tested (smooth cement)
##   E  look D with the voxel cement (the build's floor)
##   F  E with a 1 px step shade on cell edges where the grey changes
##   G  E with 0.2 m cells
## Variants D..G apply look D on top of the venue as built, so they only make sense on the pre-build venue (54b96c3 and
## before). Since look D is built (build_venue.gd), only A is meaningful: it captures the before|after shots
## (--variants=A --out=<dir>; two-ups by game/tools/look_build_compose.py after). Views: floor, bar, stage, lounge,
## corridor, smoking, toilets (landscape: floor, bar, stage).
## From game/, windowed (headless renders nothing):
##   godot --path . --script res://tests/capture_look_build.gd -- --tag=portrait [--only=floor,bar] [--variants=D,E]
## Writes <variant>-<view>.png to docs/art/screens/look-build/floor-proto/ (--out=DIR).

## Light groups by node name (build_venue.gd): every one of the 42 lights falls in one, or keeps its look.
const LIGHT_CATS := {
	"KeyLight": "key",
	"LongTableLightA": "lamp", "LongTableLightB": "lamp", "LoungeTablesLight": "lamp", "WestTablesLight": "lamp",
	"RectWLight": "lamp", "RowLight0": "lamp", "RowLight1": "lamp", "RowLight2": "lamp", "EastLight": "lamp",
	"RaisedLightA": "lamp", "RaisedLightB": "lamp",
	"BufferCandles": "candle", "TinyLightA": "candle", "TinyLightB": "candle",
	"CounterLightW": "counter", "CounterLightE": "counter", "CashierLight": "counter",
	"NeonLight": "red", "RedPanelLightA": "red", "RedPanelLightB": "red", "BufferParSpot": "red", "ParSpot0": "red",
	"ParSpot2": "red", "TreeLight": "red", "NeonEdgeA": "red", "NeonEdgeB": "red", "BackBarRed0": "red",
	"BackBarRed1": "red", "BackBarRed2": "red",
	"ParSpot3": "par_amber", "ParSpot1": "par_blue",
	"LobbyLight": "house", "CorridorLight": "house", "StaffRoomLight": "house", "LightboxGlow": "house",
	"DiscoGlint": "house",
	"PictureLightOmni": "picture", "StreetSpill": "smoke", "SmokeBulb": "smoke", "Streetlight": "outside",
	"PinballGlow": "screen",
}

const RED := Color("ff2a18")       # the room red: between the kit NeonRed ff2a14 and the back bar ff2018
const RED_KEY := Color("ff6a55")   # the one directional light, red but not pure so faces keep some shape
const KEY_D := Color("ff8a70")     # D: a paler red key, so figures keep their clothes' colours
const CANDLE := Color("ffa050")    # D: table lamps as candle pools (photos 07, 11), warmer and redder than LAMP_GOLD
const AMB := Color(0.45, 0.34, 0.34)   # ambient: only a little red, so figures keep their colours; dark walls stay dark
const CEMENT := Color("4a4848")   # cement floor albedo (times a soft noise 0.7..1.0), dark grey as in photos 07, 09, 14
const NORTH_TOP := Color("8c8a8a")      # D: the north wall's light grey top half
const NORTH_BOTTOM := Color("100c0c")   # D: its blackish bottom half
const NORTH_SPLIT := 1.9                # D: height of the neon line between them (m; rooms are 4 m high)
const NORTH_NEON := Color("ff1a12")

## D: two-tone wall in world height, a thin emissive line at the split (the line glows; it lights nothing)
const NORTH_SHADER := """
shader_type spatial;
uniform vec3 top_col : source_color;
uniform vec3 bottom_col : source_color;
uniform vec3 neon : source_color;
uniform float split_y;
uniform float neon_energy = 3.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float d = wpos.y - split_y;
	ALBEDO = d > 0.0 ? top_col : bottom_col;
	ROUGHNESS = 0.9;
	if (abs(d) < 0.04) { ALBEDO = neon; EMISSION = neon * neon_energy; }
}
"""

## The kit's amber LED soffits and shelves over the bar that venue_looks.gd does not already turn red (photo 09)
const RED_LEDS := {"SoffitPeach_emissive": Color("ff1a12"), "ShelfAmber_emissive": Color("ff1a12"),
	"CubbyGlow_emissive": Color("6a0806")}

## Blackish walls and ceilings (B, D). For the textured Upper Brick the colour multiplies its texture.
const BLACKISH := {"main_wall": Color("0e0b0b"), "lounge_wall": Color("0e0b0b"), "lobby_wall": Color("0e0b0c"),
	"smoke_wall": Color("0e0c0e"), "frame_wood": Color("120c0a"), "closed_room": Color("070606"),
	"Upper Brick": Color(0.42, 0.40, 0.42), "ceiling": Color("080606"), "ceiling_edge": Color("070505"),
	"beam_black": Color("0a0708"), "CabinDark": Color("0c0909"), "CeilingPlum": Color("0c0809")}
const DARK_ENV := {"ambient_light_color": AMB, "ambient_light_energy": 1.5, "glow_intensity": 0.3,
	"adjustment_contrast": 1.06, "tonemap_exposure": 1.3}

const D_LIGHTS := {"key": [KEY_D, 0.9], "lamp": [CANDLE, 0.75], "counter": [CANDLE, 0.9], "red": [null, 1.3],
	"par_amber": [RED, 1.0], "house": [RED, 0.9]}

## Variant values. walls: albedo per material (absolute; for textured materials a multiplier of the texture).
## emit: emissive materials, albedo and emission. lights: category -> [colour or null to keep, energy factor].
## env: Environment properties set as given. cement: "smooth" (the test's noise) or a voxel cement spec
## {cell: px of 2.5 cm, edge: step shade}. north: D's north wall.
const VARIANTS := {
	"A": {"label": "A  today", "walls": {}, "emit": {}, "lights": {}, "env": {}},
	"D": {"label": "D  as tested", "walls": BLACKISH, "cement": "smooth", "north": true, "emit": RED_LEDS,
		"lights": D_LIGHTS, "env": DARK_ENV},
	"E": {"label": "E  D, voxel cement", "walls": BLACKISH, "cement": {"cell": 4, "edge": false}, "north": true,
		"emit": RED_LEDS, "lights": D_LIGHTS, "env": DARK_ENV},
	"F": {"label": "F  E, step shade", "walls": BLACKISH, "cement": {"cell": 4, "edge": true}, "north": true,
		"emit": RED_LEDS, "lights": D_LIGHTS, "env": DARK_ENV},
	"G": {"label": "G  E, 0.2 m cells", "walls": BLACKISH, "cement": {"cell": 8, "edge": false}, "north": true,
		"emit": RED_LEDS, "lights": D_LIGHTS, "env": DARK_ENV},
}

## Views: the player's spot and facing; `area` presses that area button first (its view, as in the game).
const VIEWS := [
	{"name": "floor", "player": Vector3(30.0, 0.1, 7.0), "yaw": PI * 0.5, "main": true},
	{"name": "bar", "area": "bar", "main": true},
	{"name": "stage", "area": "stage", "main": true},
	{"name": "lounge", "player": Vector3(8.0, 0.1, 6.5), "yaw": PI * 0.5},
	{"name": "corridor", "player": Vector3(4.2, 0.1, 14.0), "yaw": -PI * 0.5},
	{"name": "smoking", "player": Vector3(40.0, 0.1, 15.2), "yaw": PI},
	{"name": "toilets", "area": "toilets"},
]

var out := "res://../docs/art/screens/look-build/floor-proto"
var tag := "portrait"
var only: PackedStringArray = []
var variants: PackedStringArray = ["A", "D", "E", "F", "G"]

var _names := {}         # material names any variant sets
var _mats := {}          # resource_name -> Array[StandardMaterial3D]
var _mat_orig := {}      # StandardMaterial3D -> [albedo_color, emission, albedo_texture, filter, uv1_scale, rough, spec]
var _floors := []        # the Floor and Concrete materials
var _north := {}         # MeshInstance3D of the main room's north wall -> its material_override
var _north_mat: ShaderMaterial
var _cement_tex: ImageTexture
var _voxel_tex := {}     # "cell/edge" -> ImageTexture
var _lights := []        # [Light3D, category, colour, energy]
var _env: Environment
var _env_orig := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
		elif a.begins_with("--variants="):
			variants = a.substr(11).split(",")
	out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	var full := Vector2i(1080, 1920) if tag == "portrait" else Vector2i(1920, 1080)
	root.size = full / 2
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = full
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout


func _run() -> void:
	await process_frame
	var needs: Node = root.get_node("Needs")
	needs.autosave = false
	needs.save_path = "user://capture_look_test_save.json"
	needs.new_game()
	for m in needs.meters:
		needs.meters[m] = 60.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	if is_instance_valid(main.welcome):
		main.welcome.ok_button.pressed.emit()
	for k in VARIANTS:
		for nm in VARIANTS[k].walls.keys() + VARIANTS[k].emit.keys():
			_names[nm] = true
	_names["Floor"] = true
	_names["Concrete"] = true
	_collect(main)
	_floors = _mats.get("Floor", []) + _mats.get("Concrete", [])
	_cement_tex = _cement()
	_north_mat = ShaderMaterial.new()
	_north_mat.shader = Shader.new()
	_north_mat.shader.code = NORTH_SHADER
	_north_mat.set_shader_parameter("top_col", NORTH_TOP)
	_north_mat.set_shader_parameter("bottom_col", NORTH_BOTTOM)
	_north_mat.set_shader_parameter("neon", NORTH_NEON)
	_north_mat.set_shader_parameter("split_y", NORTH_SPLIT)
	print("look test: %d lights, %d materials, %d floor materials, %d north wall pieces" % [_lights.size(),
		_mats.size(), _floors.size(), _north.size()])
	var p: Player = main.player
	var body: Node3D = p.get_node("Body")
	for v in VIEWS:
		if not only.is_empty() and not only.has(v.name):
			continue
		if tag != "portrait" and not v.get("main", false):
			continue
		if v.has("area"):
			_place(p, body, Vector3(30.0, 0.1, 7.0), PI * 0.5)
			await _wait(0.8)
			main.walk_to_area(v.area)
			for i in 1500:
				await process_frame
				if not p.walking_to and main.pending_zone == "":
					break
			await _wait(0.2)
			if is_instance_valid(main.sheet):
				main.close_sheet()
			await _wait(1.6)
		else:
			_place(p, body, v.player, v.yaw)
			await _wait(1.8)
		paused = true
		for k in variants:
			_apply(VARIANTS[k])
			await _wait(0.15)
			var nm: String = ("%s-%s" if tag == "portrait" else "%s-landscape-%s") % [k, v.name]
			await _shot(nm, p)
		_apply(VARIANTS["A"])
		paused = false
	quit()


func _shot(nm: String, p: Player) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := out.path_join(nm + ".png")
	img.save_png(path)
	# Readability: mean luma of the whole frame and of a box around the player's figure (it includes floor around them)
	var cam := root.get_viewport().get_camera_3d()
	var s := img.get_size()
	var scale := float(s.y) / float(root.get_visible_rect().size.y) if root.get_visible_rect().size.y > 0 else 1.0
	var c := cam.unproject_position(p.global_position + Vector3(0, 0.8, 0)) * scale
	var r := int(s.y * 0.045)
	print("saved %s %s  frame luma %.3f  player luma %.3f" % [path, s, _luma(img, Rect2i(0, 0, s.x, s.y)),
		_luma(img, Rect2i(int(c.x) - r, int(c.y) - r * 2, r * 2, r * 4))])


static func _luma(img: Image, r: Rect2i) -> float:
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x <= 0 or r.size.y <= 0:
		return -1.0
	var sum := 0.0
	var n := 0
	for y in range(r.position.y, r.end.y, 4):
		for x in range(r.position.x, r.end.x, 4):
			var col := img.get_pixel(x, y)
			sum += 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b
			n += 1
	return sum / maxf(n, 1)


func _collect(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		for i in n.mesh.get_surface_count():
			var m := n.get_active_material(i) as StandardMaterial3D
			if m and _names.has(m.resource_name) and not _mat_orig.has(m):
				_mat_orig[m] = [m.albedo_color, m.emission, m.albedo_texture, m.texture_filter, m.uv1_scale,
					m.roughness, m.metallic_specular]
				if not _mats.has(m.resource_name):
					_mats[m.resource_name] = []
				_mats[m.resource_name].append(m)
		# The main room's north wall (build_venue.gd WallNorth_* in MainRoom, the camera rig's stubs beside them); the
		# filler wall over it (UpperN, 4..6 m) stays blackish: grey there reads as a banner across the top of the frame
		var nm := String(n.name)
		if nm.begins_with("WallNorth") and n.get_parent().name == "MainRoom":
			_north[n] = n.material_override
	elif n is Light3D:
		_lights.append([n, LIGHT_CATS.get(String(n.name), "other"), n.light_color, n.light_energy])
	elif n is WorldEnvironment and _env == null:
		_env = n.environment
	for c in n.get_children():
		_collect(c)


func _apply(v: Dictionary) -> void:
	for m in _mat_orig:
		m.albedo_color = _mat_orig[m][0]
		m.emission = _mat_orig[m][1]
		m.albedo_texture = _mat_orig[m][2]
		m.texture_filter = _mat_orig[m][3]
		m.uv1_scale = _mat_orig[m][4]
		m.roughness = _mat_orig[m][5]
		m.metallic_specular = _mat_orig[m][6]
	var cem = v.get("cement", null)
	if cem is String:
		for m in _floors:
			m.albedo_texture = _cement_tex
			m.albedo_color = CEMENT
	elif cem is Dictionary:
		var key := "%d/%s" % [cem.cell, cem.edge]
		if not _voxel_tex.has(key):
			var img := cement_image(CEMENT, 4417, cem.cell, cem.edge)
			img.generate_mipmaps()
			_voxel_tex[key] = ImageTexture.create_from_image(img)
		for m in _floors:
			m.albedo_texture = _voxel_tex[key]
			m.albedo_color = Color.WHITE
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			m.uv1_scale = Vector3.ONE / CEMENT_REPEAT
			m.roughness = CEMENT_ROUGH
			m.metallic_specular = CEMENT_SPEC
	for nm in v.walls:
		for m in _mats.get(nm, []):
			m.albedo_color = v.walls[nm]
	for nm in v.emit:
		for m in _mats.get(nm, []):
			m.albedo_color = v.emit[nm]
			m.emission = v.emit[nm]
	for w in _north:
		w.material_override = _north_mat if v.get("north", false) else _north[w]
	for l in _lights:
		var light: Light3D = l[0]
		var rule: Array = v.lights.get(l[1], [null, 1.0])
		light.light_color = rule[0] if rule[0] != null else l[2]
		light.light_energy = l[3] * rule[1]
	if _env:
		for k in _env_orig:
			_env.set(k, _env_orig[k])
		for k in v.env:
			if not _env_orig.has(k):
				_env_orig[k] = _env.get(k)
			_env.set(k, v.env[k])


## Voxel cement (Daniele 2026-11-02: the floor "in the game's voxel style"). Flat square cells (0.1 m: two kit
## voxels), each one of five stepped greys around `base`: the field is value noise sampled once per cell and snapped
## to a step, so patches follow the cell grid, with single-cell aggregate flecks a step up or down. No grout: cement
## is poured, not tiled. One image covers CEMENT_REPEAT metres (1 px = 2.5 cm), seamless, read world-triplanar and
## nearest-filtered like the kit's bond floor. `edge`: a 1 px shade on a cell's north and west edges where the grey
## steps (darker where the neighbour is lighter), as if the cells were voxels of slightly different height.
const CEMENT_REPEAT := 8.0
const CEMENT_STEP := 0.022       # one grey step (albedo)
const CEMENT_ROUGH := 0.85       # matte: the old tile floor was 0.34 (glossy)
const CEMENT_SPEC := 0.25
static func cement_image(base: Color, seed: int, cell := 4, edge := false) -> Image:
	var px := int(CEMENT_REPEAT * 40.0)
	var n := px / cell
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	noise.frequency = 0.1 * cell / 4.0     # in cells: patches of roughly 0.5 to 1.5 m
	noise.fractal_octaves = 2
	var field := noise.get_seamless_image(n, n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lv := PackedInt32Array()
	lv.resize(n * n)
	for cy in n:
		for cx in n:
			var l := clampi(int(field.get_pixel(cx, cy).r * 4.0), 0, 3) - 2   # -2..1
			var r := rng.randf()
			if r < 0.05:
				l -= 1
			elif r < 0.09:
				l += 1
			lv[cy * n + cx] = l
	var img := Image.create(px, px, false, Image.FORMAT_RGB8)
	for py in px:
		var cy := py / cell
		for qx in px:
			var cx := qx / cell
			var l := lv[cy * n + cx]
			var j := l * CEMENT_STEP
			if edge:
				var up := lv[((cy + n - 1) % n) * n + cx]
				var left := lv[cy * n + (cx + n - 1) % n]
				if (py % cell == 0 and up > l) or (qx % cell == 0 and left > l):
					j -= CEMENT_STEP * 0.8
				elif (py % cell == 0 and up < l) or (qx % cell == 0 and left < l):
					j += CEMENT_STEP * 0.5
			img.set_pixel(qx, py, Color(base.r + j, base.g + j * 0.95, base.b + j * 0.9))
	return img


## Soft cement: low-contrast cloudy noise, seamless, read world-triplanar by the floor materials (uv1 scale 0.25:
## one tile is 4 m)
static func _cement() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 5
	var img := noise.get_seamless_image(256, 256)
	img.convert(Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var g := 0.7 + 0.3 * img.get_pixel(x, y).r
			img.set_pixel(x, y, Color(g, g, g * 0.99))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _place(p: Player, body: Node3D, at: Vector3, yaw: float) -> void:
	p.stand_up()
	p.walking_to = false
	p.global_position = at
	p.velocity = Vector3.ZERO
	body.global_rotation = Vector3(0, yaw, 0)
	p.rig.snap()
