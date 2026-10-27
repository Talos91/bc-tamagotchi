@tool
extends SceneTree
## Generates res://scenes/venue/venue.tscn from the voxel kit (res://assets/kit/manifest.json). Run from game/:
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/build_venue.gd
## Re-run after editing or after the kit is re-exported; hand-edits to venue.tscn are overwritten. Units are metres,
## x east, z south, y up. Room height 4 m (DECISIONS 2026-10-27 j).
##
## Layout (direction renders R01-R03, docs/art/direction/):
##   Lounge x 0..10, z 0..10. Facing north: neon sign on the plant wall over a velvet banquette and the long table,
##   stairs up on the west wall, white columns, CRT, arcade cabinet and collectibles shelf in the north-east corner.
##   The red Curtain on the east wall (opening z 4.8..7.2) leads into the main room.
##   Main room x 10..30, z 0..10. Walking in through the curtain (facing east, as in R01): Bar with backlit shelves
##   and stools along the south wall on the right, CommunalTable and Banquette along the north wall on the left,
##   round Tables and drum stools in the middle, raised red-carpet Stage across the east end with the slatted
##   backdrop, curtains, drum kit, amps, guitar, mics, truss; disco ball and track lights overhead.
## Kit objects are instanced from their .glb (never copied). Pieces the kit does not have yet (banquette, floor,
## walls, soffit, truss) are simple boxes; a kit object named "banquette" replaces the box when it appears.
## Furniture gets box colliders so the NavigationRegion3D (baked here) routes tap-to-move around it.
## Ceiling slab, beams and lounge ceiling panels are on render layer 2: the game camera hides them (diorama
## cutaway), eye-level capture cameras show them. Walls carry meta "cut_normal" for camera_rig.gd's cutaway;
## hanging objects in group "occluder" (disco ball) hide while they sit between the camera and the player.

const MANIFEST := "res://assets/kit/manifest.json"
const OUT := "res://scenes/venue/venue.tscn"
const ROOM_H := 4.0
const STAGE_H := 0.5            # platform 0.45 + carpet tile 0.05
const CEILING_LAYER := 2
const BAR_SEAT_H := 0.8       # kit bar_stool seat top; chairs, drum stools and banquettes are 0.45

# Palette (art bible §3, game values)
const CABIN_DARK := Color("1c0d0c")
const BEAM_BLACK := Color("160a0c")
const FLOOR_GREY := Color("3a2c30")
const VELVET_SHADOW := Color("3e0408")
const VELVET_RED := Color("8c0610")
const CARPET_RED := Color("9a0a12")
const PANEL_RED := Color("b80a10")
const NEON_RED := Color("ff2a14")
const LAMP_GOLD := Color("ffdd78")
const TEALIGHT := Color("f7db71")
const SHELF_AMBER := Color("ff8a30")
const SOFFIT_PEACH := Color("e8814a")
const WOOD_MID := Color("6e3522")
const STOOL_BLACK := Color("221110")
const STAGE_BLUE := Color("20a8f0")
const SCREEN_CYAN := Color("18d0fa")

var vroot: Node3D
var kit := {}          # name -> manifest entry
var mats := {}
var light_count := 0
var spots: Node3D      # Patrons/Spots: seats, staff and wander points for scripts/venue_patrons.gd
var shadow_count := 0

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for o in data.objects:
		kit[o.name] = o
	vroot = Node3D.new()
	vroot.name = "Venue"
	vroot.add_to_group("nav_source", true)
	_environment()
	var patrons := _group("Patrons")
	spots = _group("Spots", patrons)
	_lounge()
	_stairs()
	_curtain()
	_main_room()
	_bar()
	_tables()
	_communal_table()
	_banquette()
	_stage()
	_camera_zones()
	await process_frame   # root joins the tree after _init starts; navmesh parsing needs the venue inside it
	_navigation()
	_wander_spots()
	patrons.set_script(load("res://scripts/venue_patrons.gd"))
	vroot.set_script(load("res://scripts/venue.gd"))
	var ps := PackedScene.new()
	ps.pack(vroot)
	var err := ResourceSaver.save(ps, OUT)
	print("venue saved: ", err, " lights=", light_count, " shadowed=", shadow_count)
	vroot.free()
	quit(0 if err == OK else 1)

# --- helpers -----------------------------------------------------------------------------------------------

func _own(n: Node, parent: Node) -> void:
	parent.add_child(n)
	n.owner = vroot

func _group(gname: String, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.name = gname
	_own(g, parent if parent else vroot)
	return g

func _mat(key: String, col: Color, rough := 0.85, emit := 0.0) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = col
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	mats[key] = m
	return m

## Glossy tiled floor: 0.25 m tiles with dark seams and value jitter, world-triplanar so tiles line up across meshes.
func _floor_mat() -> StandardMaterial3D:
	if mats.has("floor"):
		return mats.floor
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5843
	for ty in 16:
		for tx in 16:
			var j := rng.randf_range(-0.035, 0.035)
			var c := Color(FLOOR_GREY.r + j, FLOOR_GREY.g + j, FLOOR_GREY.b + j)
			for py in 8:
				for px in 8:
					var seam := px == 0 or py == 0
					img.set_pixel(tx * 8 + px, ty * 8 + py, c.darkened(0.45) if seam else c)
	var m := StandardMaterial3D.new()
	m.resource_name = "FloorTile"
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)   # texture spans 4 m, 16 tiles
	m.roughness = 0.16
	m.metallic_specular = 0.9
	mats.floor = m
	return m

## Instance a kit .glb with its pivot (floor centre; ceiling objects hang from their pivot) at `pos`.
func _kit(parent: Node, kname: String, pos: Vector3, rot_deg := 0.0, nm := "", scl := Vector3.ONE) -> Node3D:
	if not kit.has(kname):
		push_warning("kit object missing: " + kname)
		return null
	var scene: PackedScene = load(kit[kname].path)
	var inst: Node3D = scene.instantiate()
	inst.name = nm if nm != "" else kname
	inst.position = pos
	inst.rotation_degrees.y = rot_deg
	inst.scale = scl
	_own(inst, parent)
	return inst

## Kit object plus a box collider sized from the manifest footprint (rotated with it).
func _kit_solid(parent: Node, kname: String, pos: Vector3, rot_deg := 0.0, nm := "", h := -1.0) -> Node3D:
	var inst := _kit(parent, kname, pos, rot_deg, nm)
	if inst == null:
		return null
	var fp: Array = kit[kname].footprint_m
	var height: float = kit[kname].height_m if h < 0.0 else h
	_collider(inst, "Collider", Vector3(0, height * 0.5, 0), Vector3(fp[0], height, fp[1]))
	return inst

func _collider(parent: Node, nm: String, center: Vector3, size: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = nm
	body.position = center
	body.rotation = rot
	_own(body, parent)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	_own(cs, body)
	return body

## Box from min corner `pos`, size `size`. Optional collider, render layer and cutaway normal.
func _box(parent: Node, nm: String, pos: Vector3, size: Vector3, mat: Material, collide := true, layer := 1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos + size * 0.5
	mi.layers = 1 << (layer - 1)
	_own(mi, parent)
	if collide:
		_collider(mi, "Collider", Vector3.ZERO, size)
	return mi

## Wall the diorama camera can cut away: hidden when its outward normal points at the camera.
func _wall(parent: Node, nm: String, pos: Vector3, size: Vector3, mat: Material, cut_normal: Vector3) -> MeshInstance3D:
	var w := _box(parent, nm, pos, size, mat)
	w.set_meta("cut_normal", cut_normal)
	w.add_to_group("cutaway", true)
	return w

func _omni(parent: Node, nm: String, col: Color, energy: float, rng: float, pos: Vector3, group := "") -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = nm
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.position = pos
	l.light_specular = 0.8
	l.distance_fade_enabled = true
	l.distance_fade_begin = 22.0
	l.distance_fade_length = 4.0
	if group != "":
		l.add_to_group(group, true)
	_own(l, parent)
	light_count += 1
	return l

func _spot(parent: Node, nm: String, col: Color, energy: float, rng: float, angle: float, pos: Vector3, aim: Vector3, shadow := false) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.name = nm
	l.light_color = col
	l.light_energy = energy
	l.spot_range = rng
	l.spot_angle = angle
	l.spot_angle_attenuation = 0.8
	l.shadow_enabled = shadow
	l.transform = Transform3D(Basis.looking_at(aim - pos, Vector3.UP), pos)
	_own(l, parent)
	light_count += 1
	if shadow:
		shadow_count += 1
	return l

## Floor of 2 m tiles (separate meshes so each tile only takes the lamps near it: Compatibility caps lights per
## mesh at 8) plus one collider for the whole room.
func _floor(parent: Node, x0: float, z0: float, w: float, d: float) -> void:
	var g := _group("Floor", parent)
	var bm := BoxMesh.new()
	bm.size = Vector3(2, 0.2, 2)
	var tiles_x := int(ceil(w / 2.0))
	var tiles_z := int(ceil(d / 2.0))
	for ix in tiles_x:
		for iz in tiles_z:
			var mi := MeshInstance3D.new()
			mi.name = "Tile%d_%d" % [ix, iz]
			mi.mesh = bm
			mi.material_override = _floor_mat()
			mi.position = Vector3(x0 + ix * 2.0 + 1.0, -0.1, z0 + iz * 2.0 + 1.0)
			_own(mi, g)
	_collider(g, "Collider", Vector3(x0 + w * 0.5, -0.1, z0 + d * 0.5), Vector3(w, 0.2, d))

func _ceiling(parent: Node, x0: float, z0: float, w: float, d: float) -> void:
	_ceiling_group(_box(parent, "Ceiling", Vector3(x0, ROOM_H, z0), Vector3(w, 0.2, d), _mat("ceiling", CABIN_DARK, 0.95), false, CEILING_LAYER))

## Ceiling pieces: venue.gd moves everything under these nodes to render layer 2 at load (layers set on the children
## of an instanced .glb would not be saved).
func _ceiling_group(n: Node) -> void:
	n.add_to_group("ceiling", true)

## Table dressing: a lit lamp and/or tealights, and one warm point light pooling on the top.
func _table_lights(parent: Node, nm: String, top: Vector3, lamp: bool, tealights: int) -> void:
	if lamp:
		_kit(parent, "table_lamp_lit", top + Vector3(-0.08, 0, 0), 0.0, nm + "Lamp")
	for i in tealights:
		_kit(parent, "tealight_lantern", top + Vector3(0.12 + i * 0.12, 0, 0.06 - i * 0.12), 0.0, nm + "Tealight%d" % i)
	_kit(parent, "napkin_cup", top + Vector3(0.05, 0, -0.14), 0.0, nm + "Napkins")
	if lamp:
		_omni(parent, nm + "Light", LAMP_GOLD, 1.8, 2.8, top + Vector3(-0.08, 0.42, 0))
	else:
		_omni(parent, nm + "Light", TEALIGHT, 1.3, 2.4, top + Vector3(0.12, 0.25, 0), "tealight")

## Spot for scripts/venue_patrons.gd, named by zone so a later cast can be placed without moving the layout.
func _seat(zone: String, nm: String, pos: Vector3, yaw_deg: float, seat_h := 0.45, pose := "sit") -> void:
	var m := Marker3D.new()
	m.name = nm
	m.position = pos
	m.rotation_degrees.y = yaw_deg
	m.set_meta("zone", zone)
	m.set_meta("pose", pose)
	m.set_meta("seat_h", seat_h)
	_own(m, spots)

func _wander_spots() -> void:
	var pts := {"Wander_Lounge": Vector3(5.0, 0, 4.0), "Wander_Arcade": Vector3(7.4, 0, 1.6),
		"Wander_Curtain": Vector3(11.2, 0, 6.0), "Wander_Communal": Vector3(11.0, 0, 3.0),
		"Wander_Aisle": Vector3(15.5, 0, 5.4), "Wander_StageFront": Vector3(21.0, 0, 5.6),
		"Wander_BarEnd": Vector3(22.0, 0, 7.6)}
	for k in pts:
		_seat("Wander", k, pts[k], 0.0, 0.0, "wander")

# --- environment ------------------------------------------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b0505")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.36, 0.3)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.3)
	env.fog_enabled = true
	env.fog_light_color = Color(0.32, 0.07, 0.06)
	env.fog_light_energy = 1.0
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_own(we, vroot)

# --- zones ------------------------------------------------------------------------------------------------

func _lounge() -> void:
	var g := _group("Lounge")
	var wall := _mat("lounge_wall", Color("4a0c10"), 0.9)
	_floor(g, 0, 0, 10, 10)
	_ceiling(g, 0, 0, 10, 10)
	_wall(g, "WallNorth", Vector3(0, 0, -0.2), Vector3(10, ROOM_H, 0.2), wall, Vector3.FORWARD)
	_wall(g, "WallWest", Vector3(-0.2, 0, 0), Vector3(0.2, ROOM_H, 10), wall, Vector3.LEFT)
	_wall(g, "WallSouth", Vector3(0, 0, 10), Vector3(10, ROOM_H, 0.2), wall, Vector3.BACK)
	# Plant wall framing the neon sign, velvet banquette under it, long table with lamps in front (R02)
	for c in 4:
		for r in 3:
			_kit(g, "plant_wall_tile", Vector3(2.3 + c, 0.9 + r, 0.15), 0.0, "PlantWall%d_%d" % [c, r])
	_kit(g, "neon_sign", Vector3(3.8, 1.75, 0.38), 0.0, "NeonSign", Vector3(1.55, 1.55, 1.0))
	_omni(g, "NeonLight", NEON_RED, 2.6, 6.5, Vector3(3.8, 2.4, 1.3))
	_banquette_box(g, "LoungeBanquette", 1.9, 5.9, 0.3, false)
	_kit_solid(g, "communal_table", Vector3(3.9, 0, 1.55), 0.0, "LongTable")
	for i in 3:
		_table_lights(g, "LongTable%d" % i, Vector3(2.9 + i * 1.0, 0.75, 1.55), true, 1 if i != 1 else 0)
		_kit_solid(g, "cafe_chair", Vector3(2.9 + i * 1.0, 0, 2.25), 180.0, "Chair%d" % i)
		_seat("Lounge", "Lounge_Chair%d" % i, Vector3(2.9 + i * 1.0, 0, 2.25), 180.0)
		_seat("Lounge", "Lounge_Banquette%d" % i, Vector3(2.9 + i * 1.0, 0, 0.6), 0.0)
	# White columns, stretched to the 4 m ceiling
	for i in 2:
		var p: Vector3 = [Vector3(2.6, 0, 5.0), Vector3(7.0, 0, 3.2)][i]
		_kit(g, "white_column", p, 0.0, "Column%d" % i, Vector3(1, ROOM_H / 3.5, 1))
		_collider(g, "Column%dCollider" % i, p + Vector3(0, ROOM_H * 0.5, 0), Vector3(0.4, ROOM_H, 0.4))
	# North-east corner: CRT on its cabinet, arcade cabinet, collectibles shelf with a high counter and stools
	_kit_solid(g, "crt_monitor", Vector3(6.55, 0, 0.3), 0.0, "CRT")
	_kit_solid(g, "arcade_cabinet", Vector3(7.5, 0, 0.42), 0.0, "ArcadeCabinet")
	_omni(g, "ArcadeGlow", SCREEN_CYAN, 0.6, 2.2, Vector3(7.5, 1.4, 1.0))
	_kit(g, "collectibles_shelf", Vector3(8.95, 0, 0.22), 0.0, "CollectiblesShelf")
	_collider(g, "ShelfCollider", Vector3(8.95, 1.1, 0.22), Vector3(2.0, 2.2, 0.4))
	_box(g, "HighCounter", Vector3(8.0, 0, 1.0), Vector3(1.9, 0.95, 0.5), _mat("wood_mid", WOOD_MID, 0.4))
	for i in 2:
		_kit_solid(g, "bar_stool", Vector3(8.5 + i * 0.9, 0, 1.85), 180.0, "CounterStool%d" % i)
		_seat("Lounge", "Lounge_Stool%d" % i, Vector3(8.5 + i * 0.9, 0, 1.85), 180.0, BAR_SEAT_H)
	_omni(g, "ShelfGlow", SHELF_AMBER, 0.8, 2.6, Vector3(8.95, 1.6, 1.0))
	# Red cove strip along the walls (R02) and the ceiling: black beam grid with red emissive panels
	_box(g, "RedCove", Vector3(1.8, 0.9, 0.31), Vector3(4.2, 0.04, 0.04), _mat("red_strip", NEON_RED, 0.5, 3.0), false)
	var ceil := _group("CeilingGrid", g)
	for row in 4:
		for i in 9:
			_kit(ceil, "beam_segment", Vector3(1.5 + i, ROOM_H, 1.0 + row * 2.5), 0.0, "Beam%d_%d" % [row, i])
	for row in 3:
		for i in 6:
			_kit(ceil, "ceiling_panel", Vector3(3.0 + i, ROOM_H, 1.75 + row * 2.5 + (i % 2) * 0.5), 0.0, "Panel%d_%d" % [row, i])
	_ceiling_group(ceil)
	_omni(g, "RedPanelLightA", PANEL_RED, 1.6, 6.0, Vector3(4.0, 3.6, 3.0))
	_omni(g, "RedPanelLightB", PANEL_RED, 1.4, 6.0, Vector3(5.5, 3.6, 7.5))
	_kit(g, "track_light", Vector3(4.0, ROOM_H, 4.0), 0.0, "TrackLight0")
	_kit(g, "track_light", Vector3(6.0, ROOM_H, 7.0), 0.0, "TrackLight1")

func _stairs() -> void:
	var g := _group("Stairs")
	# Along the west wall, rising north: foot at z 4.8 (floor), top at z 1.2 onto a landing at y 2.4
	_kit(g, "stair_run", Vector3(0.85, 0, 3.0), 0.0, "StairRun")
	_box(g, "Landing", Vector3(0.05, 2.2, 0.0), Vector3(1.6, 0.2, 1.2), _mat("beam_black", BEAM_BLACK, 0.7))
	_collider(g, "LandingFill", Vector3(0.85, 1.1, 0.6), Vector3(1.6, 2.2, 1.2))
	var run := 3.6
	var rise := 2.4
	_collider(g, "StairRamp", Vector3(0.85, rise * 0.5 - 0.1, 3.0), Vector3(1.5, 0.2, sqrt(run * run + rise * rise)), Vector3(atan2(rise, run), 0, 0))
	# Side wall of the stairwell so the player cannot walk under the flight
	_collider(g, "StairSide", Vector3(1.7, 1.2, 3.0), Vector3(0.1, 2.4, 3.6))

func _curtain() -> void:
	var g := _group("Curtain")
	var wall := _mat("lounge_wall", Color("4a0c10"), 0.9)
	# Partition between lounge and main room, opening z 4.8..7.2 (height 3.2)
	_wall(g, "WallNorth", Vector3(9.9, 0, 0), Vector3(0.2, ROOM_H, 4.8), wall, Vector3.LEFT)
	_wall(g, "WallSouth", Vector3(9.9, 0, 7.2), Vector3(0.2, ROOM_H, 2.8), wall, Vector3.LEFT)
	_wall(g, "Lintel", Vector3(9.9, 3.2, 4.8), Vector3(0.2, 0.8, 2.4), wall, Vector3.LEFT)
	# Red velvet panels on the lounge side, the whole wall as in R02, open over the doorway
	for z in [0.5, 1.5, 2.5, 3.5, 4.3, 7.7, 8.5, 9.5]:
		var p := _kit(g, "curtain_panel", Vector3(9.8, 0, z), -90.0, "Panel_%d" % int(z * 10))
		p.set_meta("cut_normal", Vector3.LEFT)
		p.add_to_group("cutaway", true)
	var v := _box(g, "Valance", Vector3(9.7, 3.2, 4.8), Vector3(0.12, 0.8, 2.4), _mat("velvet_red", VELVET_RED, 0.95), false)
	v.set_meta("cut_normal", Vector3.LEFT)
	v.add_to_group("cutaway", true)
	_kit(g, "exit_sign", Vector3(10.12, 3.35, 6.0), 90.0, "ExitSign")

func _main_room() -> void:
	var g := _group("MainRoom")
	var wall := _mat("main_wall", CABIN_DARK, 0.9)
	_floor(g, 10, 0, 20, 10)
	_ceiling(g, 10, 0, 20, 10)
	_wall(g, "WallNorth", Vector3(10, 0, -0.2), Vector3(20, ROOM_H, 0.2), wall, Vector3.FORWARD)
	_wall(g, "WallSouth", Vector3(10, 0, 10), Vector3(20, ROOM_H, 0.2), wall, Vector3.BACK)
	_wall(g, "WallEast", Vector3(30, 0, 0), Vector3(0.2, ROOM_H, 10), wall, Vector3.RIGHT)
	# Amber cove strip along the north wall base (R03)
	_box(g, "AmberCove", Vector3(10.2, 0.05, 0.02), Vector3(13.6, 0.05, 0.05), _mat("amber_strip", SHELF_AMBER, 0.5, 2.5), false)
	# Track lights over the bar and the floor, disco ball over the dance aisle (R01, R03)
	for i in 5:
		_ceiling_group(_kit(g, "track_light", Vector3(12.5 + i * 2.2, ROOM_H, 7.4), 0.0, "TrackBar%d" % i))
		_kit(g, "track_light", Vector3(12.5 + i * 2.2, ROOM_H, 3.0), 0.0, "TrackFloor%d" % i)
	var ball := _kit(g, "disco_ball", Vector3(19.0, ROOM_H, 5.5), 0.0, "DiscoBall")
	ball.set_meta("occluder_center", Vector3(0, -0.9, 0))
	ball.set_meta("occluder_radius", 0.9)
	ball.add_to_group("occluder", true)
	_kit(g, "exit_sign", Vector3(23.0, 2.9, 0.06), 0.0, "ExitSignNorth")
	_kit(g, "exit_sign", Vector3(10.12, 2.9, 2.0), 90.0, "ExitSignWest")

func _bar() -> void:
	var g := _group("Bar")
	# South wall, front facing the room (-z). Back bar against the wall, counter 0.7 m in front, stools facing it.
	for i in 10:
		_kit(g, "back_bar_shelf", Vector3(12.0 + i, 0, 9.85), 180.0, "BackBar%d" % i)
		_kit(g, "bar_counter", Vector3(12.0 + i, 0, 8.65), 180.0, "Counter%d" % i)
	_collider(g, "BackBarCollider", Vector3(16.5, 1.25, 9.85), Vector3(10, 2.5, 0.3))
	_collider(g, "CounterCollider", Vector3(16.5, 0.55, 8.65), Vector3(10, 1.1, 0.65))
	for i in 8:
		_kit_solid(g, "bar_stool", Vector3(12.0 + i * 1.25, 0, 7.95), 0.0, "Stool%d" % i)
		_seat("Bar", "Bar_Stool%d" % i, Vector3(12.0 + i * 1.25, 0, 7.95), 0.0, BAR_SEAT_H)
	_seat("Bar", "Bar_Bartender", Vector3(16.5, 0, 9.35), 180.0, 0.0, "staff")
	for i in 4:
		_omni(g, "ShelfLight%d" % i, SHELF_AMBER, 2.4, 4.0, Vector3(12.8 + i * 2.6, 1.9, 9.25))
	# Soffit light panels above the bar (R01), fascia behind them
	_ceiling_group(_box(g, "SoffitFascia", Vector3(11.5, 3.45, 8.3), Vector3(10, 0.55, 1.7), _mat("beam_black", BEAM_BLACK, 0.7), false))
	for i in 5:
		_ceiling_group(_box(g, "Soffit%d" % i, Vector3(11.6 + i * 2.0, 3.38, 8.4), Vector3(1.8, 0.07, 1.5), _mat("soffit", SOFFIT_PEACH, 0.5, 0.9), false))
	_box(g, "BarWall", Vector3(11.5, 2.5, 9.95), Vector3(10, 0.95, 0.05), _mat("bar_front", Color("5e1c10"), 0.6), false)

func _tables() -> void:
	var g := _group("Tables")
	# Two staggered rows of round tables with café chairs; the z 5.5 aisle stays clear from curtain to stage
	var rows := [
		{"z": 3.4, "xs": [13.8, 16.6, 19.4], "chairs": [Vector2(-0.6, 0), Vector2(0.6, 0), Vector2(0, 0.6)]},
		{"z": 6.6, "xs": [12.6, 15.4, 18.2], "chairs": [Vector2(-0.6, 0), Vector2(0.6, 0), Vector2(0, 0.6)]},
	]
	var n := 0
	for row in rows:
		for x in row.xs:
			var c := Vector3(x, 0, row.z)
			_kit_solid(g, "round_table", c, 0.0, "Table%d" % n)
			_table_lights(g, "Table%d" % n, c + Vector3(0, 0.75, 0), n % 2 == 0, 2 if n % 2 == 1 else 1)
			for k in row.chairs.size():
				var off: Vector2 = row.chairs[k]
				var face := rad_to_deg(atan2(-off.x, -off.y))   # chair front (+z) turned toward the table
				_kit_solid(g, "cafe_chair", c + Vector3(off.x, 0, off.y), face, "Table%dChair%d" % [n, k])
				_seat("Tables", "Tables_T%d_C%d" % [n, k], c + Vector3(off.x, 0, off.y), face)
			n += 1
	# Drum stools between the tables and the stage (R01, R03)
	var stools := [Vector2(21.7, 2.6), Vector2(22.7, 3.4), Vector2(21.8, 4.3), Vector2(22.6, 6.7), Vector2(21.7, 7.4), Vector2(23.0, 2.0)]
	for i in stools.size():
		_kit_solid(g, "drum_stool", Vector3(stools[i].x, 0, stools[i].y), i * 37.0, "DrumStool%d" % i)
		_seat("Tables", "Tables_DrumStool%d" % i, Vector3(stools[i].x, 0, stools[i].y), 90.0)

func _communal_table() -> void:
	var g := _group("CommunalTable")
	# Along the north wall, chairs both sides (R01 left)
	for u in 2:
		var x := 13.0 + u * 3.0
		_kit_solid(g, "communal_table", Vector3(x, 0, 1.35), 0.0, "Table%d" % u)
		for k in 3:
			_kit_solid(g, "cafe_chair", Vector3(x - 1.0 + k, 0, 0.7), 0.0, "Chair%d_N%d" % [u, k])
			_kit_solid(g, "cafe_chair", Vector3(x - 1.0 + k, 0, 2.0), 180.0, "Chair%d_S%d" % [u, k])
			_seat("CommunalTable", "CommunalTable_T%d_N%d" % [u, k], Vector3(x - 1.0 + k, 0, 0.7), 0.0)
			_seat("CommunalTable", "CommunalTable_T%d_S%d" % [u, k], Vector3(x - 1.0 + k, 0, 2.0), 180.0)
		_table_lights(g, "Lamp%d" % u, Vector3(x - 0.4 + u * 0.8, 0.75, 1.35), true, 2)

## Velvet banquette from x0 to x1 against a north wall at z0 (seat 0.6 deep). Boxes until the kit has one.
func _banquette_box(parent: Node, nm: String, x0: float, x1: float, z0: float, solid := true) -> void:
	if kit.has("banquette"):
		var w: float = kit.banquette.footprint_m[0]
		var count := int(round((x1 - x0) / w))
		for i in count:
			_kit(parent, "banquette", Vector3(x0 + w * (i + 0.5), 0, z0 + kit.banquette.footprint_m[1] * 0.5), 0.0, "%s%d" % [nm, i])
	else:
		var b := _group(nm, parent)
		_box(b, "Seat", Vector3(x0, 0, z0), Vector3(x1 - x0, 0.45, 0.6), _mat("velvet_red", VELVET_RED, 0.95), false)
		_box(b, "Back", Vector3(x0, 0.45, z0), Vector3(x1 - x0, 0.5, 0.18), _mat("velvet_shadow", VELVET_SHADOW, 0.95), false)
		var channels := int((x1 - x0) / 0.2)
		for i in channels:
			if i % 2 == 0:
				_box(b, "Channel%d" % i, Vector3(x0 + i * 0.2 + 0.05, 0.47, z0 + 0.17), Vector3(0.1, 0.46, 0.04), _mat("velvet_red", VELVET_RED, 0.95), false)
	if solid:
		_collider(parent, nm + "Collider", Vector3((x0 + x1) * 0.5, 0.45, z0 + 0.3), Vector3(x1 - x0, 0.9, 0.6))

func _banquette() -> void:
	var g := _group("Banquette")
	# Main room, north wall east of the communal table (DECISIONS i), two small tables in front
	_banquette_box(g, "Seat", 18.2, 22.2, 0.0)
	for i in 4:
		_seat("Banquette", "Banquette_Seat%d" % i, Vector3(18.7 + i, 0, 0.3), 0.0)
	for i in 2:
		var c := Vector3(19.2 + i * 2.0, 0, 1.05)
		_kit_solid(g, "round_table", c, 0.0, "Table%d" % i)
		_table_lights(g, "Table%d" % i, c + Vector3(0, 0.75, 0), false, 2)

func _stage() -> void:
	var g := _group("Stage")
	# Raised platform x 24..30, z 1..9: kit risers along the front edge, red carpet tiles on top (R01, R03)
	for i in 4:
		_kit(g, "stage_platform", Vector3(24.5, 0, 2.0 + i * 2.0), -90.0, "Riser%d" % i)
	_box(g, "PlatformCore", Vector3(25.0, 0, 1.0), Vector3(5.0, 0.45, 8.0), _mat("stool_black", STOOL_BLACK, 0.85), false)
	var carpet := _group("Carpet", g)
	for ix in 6:
		for iz in 8:
			_kit(carpet, "stage_carpet_tile", Vector3(24.5 + ix, 0.45, 1.5 + iz), 0.0, "Tile%d_%d" % [ix, iz])
	_collider(g, "PlatformCollider", Vector3(27.0, STAGE_H * 0.5, 5.0), Vector3(6.0, STAGE_H, 8.0))
	# Front steps (visual) over a hidden ramp, centred on the aisle
	_box(g, "Step0", Vector3(23.0, 0, 4.5), Vector3(0.5, 0.17, 2.0), _mat("carpet", CARPET_RED, 0.95), false)
	_box(g, "Step1", Vector3(23.5, 0, 4.5), Vector3(0.5, 0.34, 2.0), _mat("carpet", CARPET_RED, 0.95), false)
	_collider(g, "StageRamp", Vector3(23.5, STAGE_H * 0.5 - 0.1, 5.5), Vector3(sqrt(1.0 + STAGE_H * STAGE_H), 0.2, 2.0), Vector3(0, 0, atan2(STAGE_H, 1.0)))
	# Slatted backdrop on the east wall, curtains flanking it and along the side walls
	for i in 6:
		_kit(g, "slatted_backdrop", Vector3(29.85, STAGE_H, 2.5 + i), -90.0, "Backdrop%d" % i)
	for z in [1.5, 8.5]:
		_kit(g, "curtain_panel", Vector3(29.85, STAGE_H, z), -90.0, "CurtainEast_%d" % int(z))
	for i in 4:
		_kit(g, "curtain_panel", Vector3(25.5 + i * 1.3, 0, 0.1), 0.0, "CurtainNorth%d" % i).scale.y = ROOM_H / 3.5
		_kit(g, "curtain_panel", Vector3(25.5 + i * 1.3, 0, 9.9), 180.0, "CurtainSouth%d" % i).scale.y = ROOM_H / 3.5
	# Backline (facing the room, -x)
	_kit_solid(g, "drum_kit", Vector3(28.2, STAGE_H, 5.0), -90.0, "DrumKit")
	_kit_solid(g, "amp", Vector3(29.2, STAGE_H, 2.7), -90.0, "AmpL")
	_kit_solid(g, "amp", Vector3(29.2, STAGE_H, 7.3), -90.0, "AmpR")
	_kit_solid(g, "guitar_on_stand", Vector3(27.2, STAGE_H, 7.7), -90.0, "Guitar")
	_kit(g, "mic_stand", Vector3(25.7, STAGE_H, 3.9), -90.0, "Mic0")
	_kit(g, "mic_stand", Vector3(25.7, STAGE_H, 6.1), -90.0, "Mic1")
	_kit(g, "mic_stand", Vector3(26.8, STAGE_H, 2.6), -90.0, "Mic2")
	_kit_solid(g, "monitor_wedge", Vector3(24.8, STAGE_H, 3.4), 90.0, "Wedge0")
	_kit_solid(g, "monitor_wedge", Vector3(24.8, STAGE_H, 6.6), 90.0, "Wedge1")
	# Truss with cube PARs over the stage front
	var truss := _group("Truss", g)
	_box(truss, "Bar", Vector3(24.6, 3.55, 1.0), Vector3(0.15, 0.15, 8.0), _mat("beam_black", BEAM_BLACK, 0.7), false)
	var pars := [[2.0, NEON_RED], [3.6, NEON_RED], [5.0, STAGE_BLUE], [6.4, NEON_RED], [8.0, NEON_RED]]
	for i in pars.size():
		_box(truss, "Par%d" % i, Vector3(24.55, 3.25, pars[i][0] - 0.13), Vector3(0.26, 0.26, 0.26), _mat("par_%d" % i, pars[i][1], 0.5, 4.0), false)
	_spot(g, "RedWashL", NEON_RED, 5.0, 9.0, 38.0, Vector3(24.7, 3.3, 3.0), Vector3(27.6, 0.5, 4.0), true)
	_spot(g, "RedWashR", NEON_RED, 5.0, 9.0, 38.0, Vector3(24.7, 3.3, 7.0), Vector3(27.6, 0.5, 6.0), true)
	_spot(g, "BluePar", STAGE_BLUE, 2.5, 7.0, 18.0, Vector3(24.7, 3.3, 5.0), Vector3(28.2, 1.0, 5.0))
	_omni(g, "BackdropGlow", Color("d0161c"), 2.0, 5.5, Vector3(28.8, 2.4, 5.0))
	# Haze: soft additive sheets, thickest over the stage (Compatibility has no volumetric fog)
	var haze_mat := StandardMaterial3D.new()
	haze_mat.resource_name = "Haze"
	haze_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	haze_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	haze_mat.albedo_color = Color(0.55, 0.06, 0.05, 0.16)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	haze_mat.albedo_texture = gt
	var qm := QuadMesh.new()
	qm.size = Vector2(5.0, 3.0)
	for i in 3:
		var h := MeshInstance3D.new()
		h.name = "Haze%d" % i
		h.mesh = qm
		h.material_override = haze_mat
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.position = Vector3(27.4 + i * 0.6, 2.2, 3.0 + i * 2.0)
		_own(h, g)

## Camera framings, one per zone, read by camera_rig.gd. rect = membership (x, z, w, d); clamp = where the look
## target may go inside the zone; yaw 0 looks north (-z), -90 looks east.
func _camera_zones() -> void:
	var g := _group("CameraZones")
	var zones := [
		{"name": "lounge", "rect": Rect2(0, 0, 10, 10), "clamp": Rect2(3.0, 3.4, 4.2, 2.2), "yaw": 0.0, "pitch": -34.0, "dist": 7.5, "look_y": 1.3},
		{"name": "bar", "rect": Rect2(10, 6.9, 13.3, 3.1), "clamp": Rect2(12.5, 7.2, 8.0, 0.6), "yaw": 180.0, "pitch": -32.0, "dist": 7.0, "look_y": 1.0},
		{"name": "stage", "rect": Rect2(23.3, 0, 6.7, 10), "clamp": Rect2(25.6, 3.8, 0.8, 2.4), "yaw": -90.0, "pitch": -22.0, "dist": 6.5, "look_y": 1.4},
		{"name": "floor", "rect": Rect2(10, 0, 13.3, 6.9), "clamp": Rect2(14.0, 3.5, 5.0, 3.0), "yaw": -90.0, "pitch": -30.0, "dist": 8.0, "look_y": 0.9},
	]
	for z in zones:
		var m := Marker3D.new()
		m.name = z.name.capitalize()
		var r: Rect2 = z.rect
		m.position = Vector3(r.position.x + r.size.x * 0.5, 0, r.position.y + r.size.y * 0.5)
		for k in z:
			if k != "name":
				m.set_meta(k, z[k])
		m.add_to_group("camera_zone", true)
		_own(m, g)

func _navigation() -> void:
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "nav_source"
	nm.cell_size = 0.1
	nm.cell_height = 0.05
	nm.agent_radius = 0.4
	nm.agent_height = 1.7
	nm.agent_max_climb = 0.25
	nm.agent_max_slope = 45.0
	region.navigation_mesh = nm
	_own(region, vroot)
	# Bake here so the shipped scene carries the navmesh; venue.gd re-bakes only if it is empty.
	root.add_child(vroot)
	region.bake_navigation_mesh(false)
	root.remove_child(vroot)
	print("navmesh polygons: ", nm.get_polygon_count())
