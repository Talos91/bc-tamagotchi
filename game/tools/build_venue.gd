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
##   Main room x 10..28, z -0.5..14 (docs/art/parity-measurements.md, renders 05/06). Walking in through the
##   curtain (facing east, 05): the raised red-carpet Stage runs along the left (north) wall at the far end with
##   curtains behind, half stacks, drums, mics, wedges, truss and the olive tree; two rows of drum-stool poufs in
##   front of it; round tables in a middle-left column, a bar-side column and a back row before the slatted
##   backdrop on the far (east) wall; the CommunalTable and a side table at the front-left; the Bar with backlit
##   bays and 13 stools along the right (south) wall; disco ball over the centre. Band spots on the stage.
## Kit objects are instanced from their .glb (never copied). Pieces the kit does not have yet (banquette, floor,
## walls, PAR stand-ins) are simple boxes; the velvet banquette falls back to boxes if the kit lacks banquette_straight.
## The kit's floor_tile_a/b are not used: one mesh per 1 m tile would be ~300 draw calls, so the floor stays
## 2 m textured tiles (Compatibility shades at most 8 lights per mesh, so the floor cannot be one mesh either).
## Furniture gets box colliders so the NavigationRegion3D (baked here) routes tap-to-move around it.
## Ceiling slab, beams and lounge ceiling panels are on render layer 2: the game camera hides them (diorama
## cutaway), eye-level capture cameras show them. Walls carry meta "cut_normal" for camera_rig.gd's cutaway;
## hanging objects in group "occluder" (disco ball) hide while they sit between the camera and the player.

const MANIFEST := "res://assets/kit/manifest.json"
const OUT := "res://scenes/venue/venue.tscn"
const ROOM_H := 4.0
const STAGE_H := 0.6            # platform 0.55 + carpet tile 0.05 (parity-measurements.md)
# Main room (docs/art/parity-measurements.md, from renders 05/06): 18 x 14.5 m, wider than the lounge
const MAIN_X1 := 28.0
const MAIN_Z0 := -0.5
const MAIN_Z1 := 14.0
const STAGE_X0 := 16.6          # stage runs x STAGE_X0..STAGE_X1 along the north wall
const STAGE_X1 := 24.6          # photo 07: it stops short of the end wall (drum stools, then the end-wall tables)
const STAGE_Z1 := 3.3           # stage front edge
const BAR_X0 := 11.5            # bar runs x BAR_X0 .. BAR_X0 + BAR_BAYS * 1.5 along the south wall
const BAR_BAYS := 9
const CEILING_LAYER := 2
const BAR_SEAT_H := 0.8       # kit bar_stool seat top; chairs, drum stools and banquettes are 0.45

# Palette (art bible §3, game values)
const CABIN_DARK := Color("1c0d0c")
const BEAM_BLACK := Color("160a0c")
const FLOOR_GREY := Color("57525c")   # iteration 18: darker and cooler (render 05 floor between the pools)       # v3: renders 05/06 floor is a mid cool grey tile, glossy (iteration 11: lighter)
const VELVET_SHADOW := Color("3e0408")
const VELVET_RED := Color("8c0610")
const CARPET_RED := Color("9a0a12")
const PANEL_RED := Color("b80a10")
const NEON_RED := Color("ff2a14")
const LAMP_GOLD := Color("ffb860")        # v3: warm amber pools, renders 05/06
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
var shadow_spots: Array = []   # [centre Vector2 | Rect2, radius, strength] for _contact_shadows()

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
	_lounge_shell()
	lounge_turn = true
	_lounge()
	_stairs()
	lounge_turn = false
	for gname in ["Lounge", "Stairs"]:
		(vroot.get_node(gname) as Node3D).transform = LOUNGE_TURN
	_curtain()
	_main_room()
	_bar()
	_tables()
	_communal_table()
	_stage()
	_camera_zones()
	_contact_shadows()
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

## Glossy tiled floor, world-triplanar so tiles line up across meshes. Iteration 12 (render 05 close-up): 0.2 m tiles
## in running bond (each row shifted half a tile), a wide per-tile value spread and soft dark seams.
func _floor_mat() -> StandardMaterial3D:
	return _bond_mat("floor", FLOOR_GREY, 0.07, 0.34, 0.5)

## Running-bond voxel blocks, 0.2 m, world-triplanar: the floor, and the dark brick of the upper walls (iteration 16).
func _bond_mat(key: String, base: Color, jit: float, rough: float, spec: float) -> StandardMaterial3D:
	if mats.has(key):
		return mats[key]
	var img := Image.create(160, 160, false, Image.FORMAT_RGB8)   # 4 m: 20 x 20 tiles of 8 px
	var rng := RandomNumberGenerator.new()
	rng.seed = 5843
	var vals := []
	for i in 20 * 21:
		vals.append(rng.randf_range(-jit, jit))
	for py in 160:
		var row := py / 8
		var shift := 4 if row % 2 == 1 else 0
		for px in 160:
			var col := ((px + shift) / 8) % 20
			var j: float = vals[row * 21 + col]
			var c := Color(base.r + j, base.g + j * 0.95, base.b + j * 0.9)
			var seam := py % 8 == 0 or (px + shift) % 8 == 0
			img.set_pixel(px, py, c.darkened(0.32) if seam else c)
	var m := StandardMaterial3D.new()
	m.resource_name = key.capitalize()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)   # texture spans 4 m, 20 tiles
	m.roughness = rough     # floor 0.34 (iteration 13): soft warm sheen; 0.18 threw white lamp glints
	m.metallic_specular = spec
	mats[key] = m
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
	_shadow_spot(pos, maxf(fp[0], fp[1]) * 0.5 + 0.06)
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

## Kit piece mounted on a wall: hidden with that wall by the cutaway.
func _cut(n: Node3D, cut_normal: Vector3) -> Node3D:
	n.set_meta("cut_normal", cut_normal)
	n.add_to_group("cutaway", true)
	return n

## Wall the diorama camera can cut away: hidden when its outward normal points at the camera.
func _wall(parent: Node, nm: String, pos: Vector3, size: Vector3, mat: Material, cut_normal: Vector3) -> MeshInstance3D:
	var w := _box(parent, nm, pos, size, mat)
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	_ceiling_group(_nocast(_box(parent, "Ceiling", Vector3(x0, ROOM_H, z0), Vector3(w, 0.2, d), _mat("ceiling", CABIN_DARK, 0.95), false, CEILING_LAYER)))

func _nocast(n: GeometryInstance3D) -> GeometryInstance3D:
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

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
		_omni(parent, nm + "Light", LAMP_GOLD, 2.6, 3.4, top + Vector3(-0.08, 0.42, 0))
	else:
		_omni(parent, nm + "Light", TEALIGHT, 2.0, 3.0, top + Vector3(0.12, 0.25, 0), "tealight")

## Spot for scripts/venue_patrons.gd, named by zone so a later cast can be placed without moving the layout.
func _seat(zone: String, nm: String, pos: Vector3, yaw_deg: float, seat_h := 0.45, pose := "sit") -> void:
	var m := Marker3D.new()
	m.name = nm
	m.position = LOUNGE_TURN * pos if lounge_turn else pos
	m.rotation_degrees.y = yaw_deg + (90.0 if lounge_turn else 0.0)
	m.set_meta("zone", zone)
	m.set_meta("pose", pose)
	m.set_meta("seat_h", seat_h)
	_own(m, spots)

func _wander_spots() -> void:
	var pts := {"Wander_Lounge": LOUNGE_TURN * Vector3(5.0, 0, 4.0), "Wander_Arcade": LOUNGE_TURN * Vector3(7.4, 0, 1.6),
		"Wander_Communal": Vector3(12.0, 0, 3.4),
		"Wander_Aisle": Vector3(16.0, 0, 5.6), "Wander_StageFront": Vector3(22.0, 0, 5.4),
		"Wander_BackTables": Vector3(24.8, 0, 8.3), "Wander_BarEnd": Vector3(19.7, 0, 8.3)}
	for k in pts:
		_seat("Wander", k, pts[k], 0.0, 0.0, "wander")

# --- environment ------------------------------------------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b0505")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.44, 0.44)   # iteration 11: lower, so lamps model the room; 18: a little red back
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.2
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.5
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.3)
	env.fog_enabled = true
	env.fog_light_color = Color(0.30, 0.07, 0.06)
	env.fog_light_energy = 1.0
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.18
	# Warm key from high over the backdrop / bar corner (render 05: shadows fall toward the entrance and the stage;
	# 06: toward the stage). Steep, so the back bar's shadow stops short of the counter.
	# Iteration 12: the one shadowed light that gives every chair, stool, table and figure a crisp cast shadow.
	# Ceiling pieces (layer 2) are outside its cull mask so they neither take its light nor block it.
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color("ffcfa8")
	key.light_energy = 0.32
	key.light_specular = 0.3
	key.shadow_enabled = true
	key.shadow_opacity = 0.85
	key.shadow_blur = 1.2
	key.shadow_bias = 0.03
	# Phone budget (iteration 18, parity-measurements.md): the only shadow map in the venue. One orthogonal map,
	# 2048 (project.godot), over 28 m is ~1.4 cm a texel, finer than a 5 cm voxel; 2 PSSM splits doubled the casters.
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 28.0
	key.light_cull_mask = 0xFFFFF & ~(1 << (CEILING_LAYER - 1))
	key.transform = Transform3D(Basis.looking_at(Vector3(-0.35, -1.0, -0.3)), Vector3(20, 8, 6))
	_own(key, vroot)
	light_count += 1
	shadow_count += 1
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_own(we, vroot)

# --- zones ------------------------------------------------------------------------------------------------

## The lounge shell (floor, ceiling, outer walls, street door) stays put; its contents are laid out as in R02 and
## then turned by LOUNGE_TURN (DECISIONS 2026-10-28, Daniele option A): 90 degrees counter-clockwise seen from
## above about the lounge centre, so the neon / plant wall is on the west wall, the stairs on the south wall, the
## street door on the north wall, and the curtain into the main room stays in the shared east wall.
const LOUNGE_TURN := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(5, 0, 5)) * Transform3D(Basis.IDENTITY, Vector3(-5, 0, -5))
var lounge_turn := false   # _seat() turns lounge spots with the contents while this is set

func _lounge_shell() -> void:
	var g := _group("LoungeShell")
	var wall := _mat("lounge_wall", Color("4a0c10"), 0.9)
	_floor(g, 0, 0, 10, 10)
	_ceiling(g, 0, 0, 10, 10)
	_wall(g, "WallNorth", Vector3(0, 0, -0.2), Vector3(10, ROOM_H, 0.2), wall, Vector3.FORWARD)
	_wall(g, "WallWest", Vector3(-0.2, 0, 0), Vector3(0.2, ROOM_H, 10), wall, Vector3.LEFT)
	_wall(g, "WallSouth", Vector3(0, 0, 10), Vector3(10, ROOM_H, 0.2), wall, Vector3.BACK)
	# Street door on the north wall (option A: the street side is north)
	_box(g, "StreetDoor", Vector3(5.2, 0, -0.06), Vector3(1.6, 2.4, 0.08), _mat("door_dark", Color("120808"), 0.6), false)
	_kit(g, "exit_sign", Vector3(6.0, 2.6, 0.05), 0.0, "ExitSignStreet")

func _lounge() -> void:
	var g := _group("Lounge")
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
		_kit(g, "white_column", p, 0.0, "Column%d" % i)
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
	_kit(g, "wall_lamp", Vector3(6.4, 1.7, 0.1), 0.0, "RedDiscLamp")
	_kit(g, "ac_unit", Vector3(7.6, 3.3, 0.15), 0.0, "ACUnit")
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
	# Partition between lounge and main room, opening z 4.8..7.2 (height 3.2). The main room is wider than the
	# lounge (z MAIN_Z0..MAIN_Z1), so the partition runs past the lounge walls on both sides.
	_wall(g, "WallNorth", Vector3(9.9, 0, MAIN_Z0), Vector3(0.2, ROOM_H, 4.8 - MAIN_Z0), wall, Vector3.LEFT)
	_wall(g, "WallSouth", Vector3(9.9, 0, 7.2), Vector3(0.2, ROOM_H, MAIN_Z1 - 7.2), wall, Vector3.LEFT)
	_wall(g, "Lintel", Vector3(9.9, 3.2, 4.8), Vector3(0.2, 0.8, 2.4), wall, Vector3.LEFT)
	# Red velvet panels on the lounge side, the whole wall as in R02, open over the doorway
	for z in [0.5, 1.5, 2.5, 3.5, 4.3, 7.7, 8.5, 9.5]:
		var p := _kit(g, "curtain_panel", Vector3(9.8, 0, z), -90.0, "Panel_%d" % int(z * 10))
		p.set_meta("cut_normal", Vector3.LEFT)
		p.add_to_group("cutaway", true)
	var v := _box(g, "Valance", Vector3(9.7, 3.2, 4.8), Vector3(0.12, 0.8, 2.4), _mat("velvet_red", VELVET_RED, 0.95), false)
	v.set_meta("cut_normal", Vector3.LEFT)
	v.add_to_group("cutaway", true)
	# Main-room side (render 06, far wall): curtains either side of the dark doorway, valance over it
	var zs: Array[float] = []
	var z := MAIN_Z0 + 0.5
	while z < MAIN_Z1:
		if z < 4.8 or z > 7.2:
			zs.append(z)
		z += 1.0
	for zz in zs:
		var p := _kit(g, "curtain_panel", Vector3(10.2, 0, zz), 90.0, "MainPanel_%d" % int(zz * 10))
		p.set_meta("cut_normal", Vector3.LEFT)
		p.add_to_group("cutaway", true)
	var mv := _box(g, "MainValance", Vector3(10.1, 3.2, 4.8), Vector3(0.12, 0.8, 2.4), _mat("velvet_red", VELVET_RED, 0.95), false)
	mv.set_meta("cut_normal", Vector3.LEFT)
	mv.add_to_group("cutaway", true)

func _main_room() -> void:
	var g := _group("MainRoom")
	var wall := _mat("main_wall", Color("23150f"), 0.85)   # v3: dark wood / brick, not red (renders 05/06)
	var w := MAIN_X1 - 10.0
	var d := MAIN_Z1 - MAIN_Z0
	_floor(g, 10, MAIN_Z0, w, d)
	_ceiling(g, 10, MAIN_Z0, w, d)
	_wall(g, "WallNorth", Vector3(10, 0, MAIN_Z0 - 0.2), Vector3(w, ROOM_H, 0.2), wall, Vector3.FORWARD)
	_wall(g, "WallSouth", Vector3(10, 0, MAIN_Z1), Vector3(w, ROOM_H, 0.2), wall, Vector3.BACK)
	_wall(g, "WallEast", Vector3(MAIN_X1, 0, MAIN_Z0), Vector3(0.2, ROOM_H, d), wall, Vector3.RIGHT)
	# Left wall by the entrance (05 bottom-left): warm cube sconces, amber cove at the base, a door with an exit sign
	_box(g, "AmberCoveNorth", Vector3(10.2, 0.05, MAIN_Z0 + 0.02), Vector3(STAGE_X0 - 10.4, 0.05, 0.05), _mat("amber_strip", SHELF_AMBER, 0.5, 2.5), false)
	for x in [11.0, 14.2]:
		_kit(g, "wall_lamp", Vector3(x, 1.9, MAIN_Z0 + 0.05), 0.0, "Sconce_%d" % int(x * 10))
	_omni(g, "SconceLight", LAMP_GOLD, 1.2, 3.5, Vector3(12.6, 1.9, MAIN_Z0 + 0.6))
	# Parity 14: pixel paintings on the plain stretches of the north wall (06 shows framed art there)
	_cut(_kit(g, "painting_b", Vector3(13.0, 1.5, MAIN_Z0 + 0.05), 0.0, "PaintingN0"), Vector3.FORWARD)
	_cut(_kit(g, "painting_c", Vector3(26.6, 1.5, MAIN_Z0 + 0.05), 0.0, "PaintingN1"), Vector3.FORWARD)
	_box(g, "SideDoor", Vector3(16.6, 0, MAIN_Z0 - 0.04), Vector3(1.0, 2.2, 0.06), _mat("door_dark", Color("120808"), 0.6), false)
	_kit(g, "exit_sign", Vector3(17.1, 2.5, MAIN_Z0 + 0.05), 0.0, "ExitSignStageDoor")
	# Far (east) wall: door at the bar end with a red-lit glass and an exit sign above (05 top right)
	_box(g, "EastDoor", Vector3(MAIN_X1 - 0.04, 0, 12.2), Vector3(0.06, 2.3, 1.1), _mat("door_dark", Color("120808"), 0.6), false)
	_box(g, "EastDoorGlass", Vector3(MAIN_X1 - 0.06, 1.2, 12.45), Vector3(0.04, 0.8, 0.6), _mat("door_glass", Color("c0181c"), 0.4, 1.4), false)
	_kit(g, "exit_sign", Vector3(MAIN_X1 - 0.05, 2.6, 12.75), -90.0, "ExitSignEast")
	_kit(g, "exit_sign", Vector3(MAIN_X1 - 0.05, 3.1, 10.9), -90.0, "ExitSignEast2")
	_cut(_kit(g, "exit_sign", Vector3(10.25, 3.45, 6.0), 90.0, "ExitSignWest"), Vector3.LEFT)   # 18: hides with its wall
	# Disco ball over the centre of the room (05/06), 1 m, its centre 2.8 m up
	var ball := _kit(g, "disco_ball", Vector3(23.6, ROOM_H, 8.3), 0.0, "DiscoBall")
	ball.set_meta("occluder_center", Vector3(0, -1.2, 0))
	ball.set_meta("occluder_radius", 1.8)
	ball.add_to_group("occluder", true)
	_omni(g, "DiscoGlint", Color("ffe2c0"), 0.6, 3.0, Vector3(23.6, 2.6, 8.3))
	_frame(g)

## Dark wood framing of the main room (renders 05/06): pilasters between the curtain bays and along the plain wall,
## and a ceiling cornice round the walls so the cutaway reads as a room with a dark ceiling, not an open box.
func _frame(g: Node) -> void:
	var wood := _mat("frame_wood", Color("2a1810"), 0.55)
	var ceil := _mat("ceiling_edge", Color("120a0a"), 0.9)
	for x in [10.0, 12.0, 14.0, 16.0, 18.0, 20.5, 23.0, 25.5, MAIN_X1 - 0.25]:
		_cut(_box(g, "PilasterN_%d" % int(x * 10), Vector3(x, 0, MAIN_Z0), Vector3(0.25, ROOM_H, 0.32), wood, false), Vector3.FORWARD)
	for z in [12.0]:   # iteration 11: no pilasters across the backdrop (05: one continuous slatted wall)
		_cut(_box(g, "PilasterE_%d" % int(z * 10), Vector3(MAIN_X1 - 0.32, 0, z - 0.12), Vector3(0.32, ROOM_H, 0.25), wood, false), Vector3.RIGHT)
	_cut(_nocast(_box(g, "CorniceN", Vector3(10, ROOM_H - 0.3, MAIN_Z0), Vector3(MAIN_X1 - 10, 0.3, 0.3), ceil, false)), Vector3.FORWARD)   # shallow: the truss PARs show
	_cut(_nocast(_box(g, "CorniceE", Vector3(MAIN_X1 - 0.9, ROOM_H - 0.3, MAIN_Z0), Vector3(0.9, 0.3, MAIN_Z1 - MAIN_Z0), ceil, false)), Vector3.RIGHT)
	_cut(_nocast(_box(g, "CorniceS", Vector3(10, ROOM_H - 0.3, MAIN_Z1 - 0.9), Vector3(MAIN_X1 - 10, 0.3, 0.9), ceil, false)), Vector3.BACK)
	_cut(_box(g, "BeamN", Vector3(10, ROOM_H - 0.45, MAIN_Z0 + 0.25), Vector3(STAGE_X0 - 10, 0.15, 0.12), wood, false), Vector3.FORWARD)
	_cut(_box(g, "BeamS", Vector3(10, ROOM_H - 0.45, MAIN_Z1 - 0.97), Vector3(MAIN_X1 - 10, 0.15, 0.12), wood, false), Vector3.BACK)
	# Upper walls, 4 m..6 m (iteration 11): the cutaway cameras sit above the ceiling line; renders 05/06 fill the frame
	# top with dark ceiling, beams and soffits, not the void. Each hides with the wall below it.
	var upper := _bond_mat("upper_brick", Color("2e221e"), 0.05, 0.9, 0.3)   # 18: darker, reads as ceiling, not red wall
	var uh := 2.0
	_cut(_nocast(_box(g, "UpperN", Vector3(10, ROOM_H, MAIN_Z0 - 0.2), Vector3(MAIN_X1 - 10, uh, 0.2), upper, false)), Vector3.FORWARD)
	_cut(_nocast(_box(g, "UpperS", Vector3(10, ROOM_H, MAIN_Z1), Vector3(MAIN_X1 - 10, uh, 0.2), upper, false)), Vector3.BACK)
	_cut(_nocast(_box(g, "UpperE", Vector3(MAIN_X1, ROOM_H, MAIN_Z0), Vector3(0.2, uh, MAIN_Z1 - MAIN_Z0), upper, false)), Vector3.RIGHT)
	# The west upper wall sits right in front of the lounge and floor-zone cameras (they look over the curtain wall
	# from just east / west of it), so it is twelve 1.2 m occluder segments the rig hides on its sight line.
	var zw := MAIN_Z0
	var k := 0
	while zw < MAIN_Z1 - 0.01:
		var seg := Node3D.new()
		seg.name = "UpperW%d" % k
		seg.position = Vector3(10.0, ROOM_H + uh * 0.5, zw + 0.6)
		seg.set_meta("occluder_center", Vector3.ZERO)
		seg.set_meta("occluder_radius", 1.3)
		seg.add_to_group("occluder", true)
		_own(seg, g)
		_nocast(_box(seg, "Brick", Vector3(-0.1, -uh * 0.5, -0.6), Vector3(0.2, uh, 1.2), upper, false))
		for i in 4:
			_box(seg, "Joist%d" % i, Vector3(0.1, 0.35 + i * 0.45 - uh * 0.5, -0.6), Vector3(0.06, 0.08, 1.2), wood, false)
		if k == 8:
			_kit(seg, "exit_sign", Vector3(0.15, 0.4 - uh * 0.5, 0.0), 90.0, "ExitSignWestHigh")
		zw += 1.2
		k += 1
	for i in BAR_BAYS:   # 05: peach soffit panels along the top of the bar wall, one per bay
		_cut(_kit(g, "soffit_segment", Vector3(BAR_X0 + 0.75 + i * 1.5, ROOM_H + 1.1, MAIN_Z1 - 0.2), 180.0, "Soffit%d" % i), Vector3.BACK)
	_cut(_kit(g, "exit_sign", Vector3(21.0, ROOM_H + 0.4, MAIN_Z0 + 0.05), 0.0, "ExitSignNorthHigh"), Vector3.FORWARD)
	for i in 4:   # ceiling joists as dark wood bands up the upper walls
		var y := ROOM_H + 0.35 + i * 0.45
		_cut(_box(g, "UpperBeamS%d" % i, Vector3(10, y, MAIN_Z1 - 0.06), Vector3(MAIN_X1 - 10, 0.08, 0.06), wood, false), Vector3.BACK)
		_cut(_box(g, "UpperBeamN%d" % i, Vector3(10, y, MAIN_Z0), Vector3(MAIN_X1 - 10, 0.08, 0.06), wood, false), Vector3.FORWARD)
		_cut(_box(g, "UpperBeamE%d" % i, Vector3(MAIN_X1 - 0.06, y, MAIN_Z0), Vector3(0.06, 0.08, MAIN_Z1 - MAIN_Z0), wood, false), Vector3.RIGHT)
	# No ReflectionProbe: under Compatibility an interior probe darkened the whole room (iteration 6, mean
	# luminance 0.21 -> 0.11); the floor's gloss comes from low roughness and the lamps' specular instead.

func _bar() -> void:
	var g := _group("Bar")
	# Right-hand long wall as you come through the curtain (south), renders 05/06: back-bar bays (1.5 m) against
	# the wall with the painting bay fourth from the entrance, counter 0.8 m deep, 13 stools facing it.
	var bz := MAIN_Z1 - 0.25          # bay origin: back against the wall
	for i in BAR_BAYS:
		var kname := "back_bar_art" if i == 3 else "back_bar_shelf"
		_kit(g, kname, Vector3(BAR_X0 + 0.75 + i * 1.5, 0, bz), 180.0, "Bay%d" % i)
	var bar_len := BAR_BAYS * 1.5
	_collider(g, "BackBarCollider", Vector3(BAR_X0 + bar_len * 0.5, 1.8, MAIN_Z1 - 0.25), Vector3(bar_len, 3.6, 0.5))
	var cz := MAIN_Z1 - 1.75          # counter origin (centre of its 0.8 m footprint)
	for i in int(bar_len):
		_kit(g, "bar_counter", Vector3(BAR_X0 + 0.5 + i, 0, cz), 180.0, "Counter%d" % i)
	_collider(g, "CounterCollider", Vector3(BAR_X0 + bar_len * 0.5, 0.55, cz), Vector3(bar_len, 1.1, 0.7))
	_shadow_rect(Rect2(BAR_X0, cz - 0.42, bar_len, 0.3))
	var sz := cz - 0.75
	for i in 13:
		var x := BAR_X0 + 0.6 + i * 1.0
		_kit_solid(g, "bar_stool", Vector3(x, 0, sz), 0.0, "Stool%d" % i)
		_seat("Bar", "Bar_Stool%d" % i, Vector3(x, 0, sz), 0.0, BAR_SEAT_H)
	_seat("Bar", "Bar_Bartender", Vector3(BAR_X0 + 5.6, 0, MAIN_Z1 - 0.95), 180.0, 0.0, "staff")
	# Backlit cubbies: the brightest surface in the renders
	for i in 4:
		_omni(g, "ShelfLight%d" % i, SHELF_AMBER, 1.4, 3.2, Vector3(BAR_X0 + 1.6 + i * 3.1, 1.9, MAIN_Z1 - 0.9))
	# Counter dressing: a lamp every 2.6 m, lanterns, glasses, napkins, a few bottles (05/06)
	var top := 1.1
	var bottles := ["bottle_amber", "bottle_green", "bottle_clear"]
	for i in 5:
		var x := BAR_X0 + 0.9 + i * 2.6
		_kit(g, "table_lamp_lit", Vector3(x, top, cz + 0.05), 0.0, "CounterLamp%d" % i)
		_omni(g, "CounterLight%d" % i, LAMP_GOLD, 0.8, 2.6, Vector3(x, top + 0.8, cz - 0.3))
		_kit(g, "napkin_cup", Vector3(x + 0.4, top, cz + 0.15), 0.0, "CounterNapkins%d" % i)
		_kit(g, "tealight_lantern", Vector3(x + 1.3, top, cz - 0.1), 0.0, "CounterTealight%d" % i)
	for i in 18:
		_kit(g, bottles[i % 3], Vector3(BAR_X0 + 0.3 + i * 0.71, top, cz + 0.22 + (i % 2) * 0.06), 0.0, "CounterBottle%d" % i)
	for i in 9:
		_kit(g, "beer_glass", Vector3(BAR_X0 + 0.55 + i * 1.43, top, cz - 0.25), 0.0, "CounterGlass%d" % i)
	# Parity 14 dressing: a second row of glasses and a row of bottles on the back-bar cabinet
	for i in 12:
		_kit(g, "beer_glass", Vector3(BAR_X0 + 1.1 + i * 1.07, top, cz - 0.12 + (i % 2) * 0.08), 0.0, "CounterGlassB%d" % i)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 40:
		var bx := BAR_X0 + 0.25 + i * 0.33
		if bx > BAR_X0 + 4.55 and bx < BAR_X0 + 5.95:
			continue   # bartender lane by the painting bay stays clear
		_kit(g, bottles[r.randi() % 3], Vector3(bx, 1.05, MAIN_Z1 - 0.42 - (i % 2) * 0.06), 0.0, "BackBottle%d" % i)

## Round table with four chairs (renders 05/06: N, E, S, W), its lamp, lanterns, glasses and a warm light.
func _round_table(g: Node, n: int, c: Vector3) -> void:
	_kit_solid(g, "round_table", c, 0.0, "Table%d" % n)
	var top := c + Vector3(0, 0.75, 0)
	_kit(g, "table_lamp_lit", top + Vector3(-0.1, 0, -0.05), 0.0, "Table%dLamp" % n)
	_kit(g, "tealight_lantern", top + Vector3(0.18, 0, 0.12), 0.0, "Table%dTealight" % n)
	if n % 2 == 0:
		_kit(g, "tealight_lantern", top + Vector3(-0.2, 0, 0.22), 0.0, "Table%dTealightB" % n)
	for k in 4:
		var a := k * PI * 0.5 + 0.4
		_kit(g, "beer_glass", top + Vector3(cos(a) * 0.28, 0, sin(a) * 0.28), 0.0, "Table%dGlass%d" % [n, k])
	_kit(g, "napkin_cup", top + Vector3(0.08, 0, -0.22), 0.0, "Table%dNapkins" % n)
	_kit(g, "menu_card", top + Vector3(-0.24, 0, 0.12), 30.0 + n * 17.0, "Table%dMenu" % n)
	_omni(g, "Table%dLight" % n, LAMP_GOLD, 2.0, 3.4, top + Vector3(-0.1, 1.0, -0.05))
	var offs := [Vector2(0, -0.66), Vector2(0.66, 0), Vector2(0, 0.66), Vector2(-0.66, 0)]
	for k in 4:
		var off: Vector2 = offs[k]
		var face := rad_to_deg(atan2(-off.x, -off.y))   # chair front (+z) turned toward the table
		_kit_solid(g, "cafe_chair", c + Vector3(off.x, 0, off.y), face, "Table%dChair%d" % [n, k])
		_seat("Tables", "Tables_T%d_C%d" % [n, k], c + Vector3(off.x, 0, off.y), face)

func _tables() -> void:
	var g := _group("Tables")
	# 05 + photo 07: bar-side column of five, middle-left column of two beside the poufs. The z ~5.5 aisle from the
	# curtain to the stage steps stays clear. The end wall is its own line of tables (_end_wall_tables).
	var centres := [Vector2(13.2, 9.75), Vector2(15.8, 9.75), Vector2(18.4, 9.75), Vector2(21.0, 9.75), Vector2(23.6, 9.75),
		Vector2(19.8, 6.85), Vector2(22.6, 6.85)]
	for n in centres.size():
		_round_table(g, n, Vector3(centres[n].x, 0, centres[n].y))
	# Drum-stool poufs in two rows in front of the stage, facing it (05, 07; gap at the steps x 20.5..22.5)
	var n := 0
	for x in [17.4, 18.4, 19.4, 23.4]:
		_pouf(g, n, Vector3(x, 0, STAGE_Z1 + 0.75))
		n += 1
	for x in [17.9, 18.9]:
		_pouf(g, n, Vector3(x, 0, STAGE_Z1 + 1.6))
		n += 1
	# Between the stage end and the end-wall tables: drum stools round short low tables (photo 07)
	for i in 2:
		var c := Vector3(STAGE_X1 + 0.75, 0, [0.5, 5.4][i])
		var lt := _kit(g, "round_table", c, 0.0, "LowTable%d" % i, Vector3(0.7, 0.6, 0.7))
		_collider(lt, "Collider", Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.9))
		_shadow_spot(c, 0.42)
		_kit(g, "tealight_lantern", c + Vector3(0.05, 0.45, 0.0), 0.0, "LowTable%dTealight" % i)
		_kit(g, "beer_glass", c + Vector3(-0.12, 0.45, 0.1), 0.0, "LowTable%dGlass" % i)
		for k in 2:
			var p := c + Vector3(0, 0, -0.62 + k * 1.24)
			_pouf(g, n, p)
			n += 1
	_end_wall_tables(g)

## Photo 07: the whole end wall is one line of tables with chairs, in front of the slatted backdrop.
func _end_wall_tables(g: Node) -> void:
	var x := MAIN_X1 - 1.1
	var k := 0
	var z := MAIN_Z0 + 0.75
	while z < 11.9:
		var c := Vector3(x, 0, z)
		_kit_solid(g, "round_table", c, 0.0, "EndTable%d" % k)
		_kit(g, "table_lamp_lit", c + Vector3(0.12, 0.75, -0.08), 0.0, "EndTable%dLamp" % k)
		_kit(g, "tealight_lantern", c + Vector3(-0.15, 0.75, 0.15), 0.0, "EndTable%dTealight" % k)
		for j in 2:
			_kit(g, "beer_glass", c + Vector3(-0.25, 0.75, -0.2 + j * 0.3), 0.0, "EndTable%dGlass%d" % [k, j])
		_kit(g, "napkin_cup", c + Vector3(0.2, 0.75, 0.2), 0.0, "EndTable%dNapkins" % k)
		_kit(g, "menu_card", c + Vector3(-0.05, 0.75, -0.25), 15.0 * k, "EndTable%dMenu" % k)
		if k % 2 == 0:
			_omni(g, "EndLight%d" % k, LAMP_GOLD, 2.2, 3.6, c + Vector3(0, 1.8, 0.8))
		var seats := [[Vector3(-0.66, 0, 0), -90.0], [Vector3(0, 0, -0.66), 0.0]]
		if z > STAGE_Z1 - 2.0 and z < STAGE_Z1 + 1.0:
			seats = [[Vector3(0, 0, -0.66), 0.0], [Vector3(0, 0, 0.66), 180.0]]   # keep the walkway past the stage end clear
		for s in seats:
			var off: Vector3 = s[0]
			var face := rad_to_deg(atan2(-off.x, -off.z))
			_kit_solid(g, "cafe_chair", c + off, face, "EndTable%dChair%d" % [k, seats.find(s)])
			_seat("Tables", "Tables_End%d_C%d" % [k, seats.find(s)], c + off, face)
		z += 1.6
		k += 1

func _pouf(g: Node, n: int, p: Vector3) -> void:
	_kit_solid(g, "drum_stool", p, n * 37.0, "DrumStool%d" % n)
	_seat("Tables", "Tables_DrumStool%d" % n, p, 180.0)

func _communal_table() -> void:
	var g := _group("CommunalTable")
	# Front-left (05): 4 m long along the room, four chairs a side, five lamps, lanterns, two napkin boxes
	var c := Vector3(14.4, 0, 1.75)
	_kit_solid(g, "communal_table", c, 0.0, "Table")
	for k in 4:
		var x := c.x - 1.5 + k
		_kit_solid(g, "cafe_chair", Vector3(x, 0, c.z - 0.75), 0.0, "ChairN%d" % k)
		_kit_solid(g, "cafe_chair", Vector3(x, 0, c.z + 0.75), 180.0, "ChairS%d" % k)
		_seat("CommunalTable", "CommunalTable_N%d" % k, Vector3(x, 0, c.z - 0.75), 0.0)
		_seat("CommunalTable", "CommunalTable_S%d" % k, Vector3(x, 0, c.z + 0.75), 180.0)
		_kit(g, "beer_glass", Vector3(x + 0.1, 0.75, c.z - 0.3), 0.0, "GlassN%d" % k)
		_kit(g, "beer_glass", Vector3(x - 0.1, 0.75, c.z + 0.3), 0.0, "GlassS%d" % k)
	for i in 5:
		var x := c.x - 1.6 + i * 0.8
		_kit(g, "table_lamp_lit" if i % 2 == 0 else "tealight_lantern", Vector3(x, 0.75, c.z + (-0.05 if i % 2 == 0 else 0.1)), 0.0, "Lamp%d" % i)
	for i in 3:
		_omni(g, "Light%d" % i, LAMP_GOLD, 1.8, 3.2, Vector3(c.x - 1.4 + i * 1.4, 1.75, c.z))
	for i in 2:
		_kit(g, "napkin_cup", Vector3(c.x - 0.6 + i * 1.3, 0.75, c.z + 0.12), 0.0, "Napkins%d" % i)
		_kit(g, "menu_card", Vector3(c.x - 1.2 + i * 2.2, 0.75, c.z - 0.15), 90.0, "Menu%d" % i)
	# Side table against the left wall by the entrance (05 bottom-left), two chairs
	var s := Vector3(11.3, 0, 0.75)
	_kit_solid(g, "round_table", s, 0.0, "SideTable")
	_kit(g, "table_lamp_lit", s + Vector3(-0.1, 0.75, 0), 0.0, "SideLamp")
	_kit(g, "tealight_lantern", s + Vector3(0.2, 0.75, 0.1), 0.0, "SideTealight")
	_omni(g, "SideLight", LAMP_GOLD, 2.0, 2.6, s + Vector3(0, 1.2, 0))
	for k in 2:
		var off := Vector3(-0.66 + k * 1.32, 0, 0)
		var face := -90.0 if k == 0 else 90.0
		_kit_solid(g, "cafe_chair", s + off, face, "SideChair%d" % k)
		_seat("CommunalTable", "CommunalTable_Side%d" % k, s + off, face)

func _stage() -> void:
	var g := _group("Stage")
	# Raised platform along the left-hand (north) wall (05/06, photo 07): x STAGE_X0..STAGE_X1, z MAIN_Z0..STAGE_Z1,
	# 0.6 m. It stops short of the end wall: the end-wall tables and the drum stools sit beyond it. Kit risers
	# along the front and the open end, red carpet on top, curtains behind, truss with PARs on the wall.
	var sw := STAGE_X1 - STAGE_X0
	var sd := STAGE_Z1 - MAIN_Z0
	for i in int(sw / 2.0):
		_kit(g, "stage_platform", Vector3(STAGE_X0 + 1.0 + i * 2.0, 0, STAGE_Z1 - 0.5), 0.0, "Riser%d" % i)
	_kit(g, "stage_platform", Vector3(STAGE_X1 - 0.5, 0, STAGE_Z1 - 2.0), -90.0, "RiserEnd")
	_box(g, "EndSkirt", Vector3(STAGE_X1 - 0.2, 0, MAIN_Z0), Vector3(0.2, STAGE_H - 0.05, STAGE_Z1 - 2.0 - 1.0 - MAIN_Z0), _mat("frame_wood", Color("2a1810"), 0.55), false)
	_box(g, "PlatformCore", Vector3(STAGE_X0, 0, MAIN_Z0), Vector3(sw - 1.0, STAGE_H - 0.05, sd - 1.0), _mat("stool_black", STOOL_BLACK, 0.85), false)
	var carpet := _group("Carpet", g)
	for ix in int(sw):
		for iz in int(ceil(sd)):
			var cz := MAIN_Z0 + 0.5 + iz
			if cz + 0.5 > STAGE_Z1 + 0.01:
				cz = STAGE_Z1 - 0.5
			_kit(carpet, "stage_carpet_tile", Vector3(STAGE_X0 + 0.5 + ix, STAGE_H - 0.05, cz), 0.0, "Tile%d_%d" % [ix, iz])
	_collider(g, "PlatformCollider", Vector3(STAGE_X0 + sw * 0.5, STAGE_H * 0.5, MAIN_Z0 + sd * 0.5), Vector3(sw, STAGE_H, sd))
	_shadow_rect(Rect2(STAGE_X0 - 0.1, STAGE_Z1 - 0.05, sw + 0.2, 0.45), 0.92)
	_shadow_rect(Rect2(STAGE_X1 - 0.05, MAIN_Z0, 0.45, sd), 0.92)
	# Front steps (kit) over a hidden ramp, x 20.5..22.5
	for i in 2:
		_kit(g, "stage_steps", Vector3(21.0 + i, 0, STAGE_Z1 + 0.3), 0.0, "Steps%d" % i)
	# 1.4 m run: the navmesh only links cells that climb <= agent_max_climb (0.05) per 0.1 m cell
	var run := 1.4
	_collider(g, "StageRamp", Vector3(21.5, STAGE_H * 0.5 - 0.1, STAGE_Z1 + run * 0.5), Vector3(2.0, 0.2, sqrt(run * run + STAGE_H * STAGE_H)), Vector3(atan2(STAGE_H, run), 0, 0))
	# Curtains along the wall behind the stage; slatted backdrop across the whole end (east) wall with six lanterns
	for i in int(sw):
		_kit(g, "curtain_panel", Vector3(STAGE_X0 + 0.5 + i, 0, MAIN_Z0 + 0.1), 0.0, "CurtainBack%d" % i)
	var z := MAIN_Z0
	var k := 0
	while z < 12.0:
		var edge := z < 2.0 or z > 9.0   # iteration 18: the glow is graded, brightest at the centre of the wall
		_cut(_kit(g, "slatted_backdrop_edge" if edge else "slatted_backdrop", Vector3(MAIN_X1 - 0.1, 0, z + 0.5), -90.0, "Backdrop%d" % k), Vector3.RIGHT)
		z += 1.0
		k += 1
	for i in 6:
		_cut(_kit(g, "backdrop_lantern", Vector3(MAIN_X1 - 0.25, 2.85, MAIN_Z0 + 1.0 + i * 2.0), -90.0, "BackdropLantern%d" % i), Vector3.RIGHT)
	# Backline facing the room (+z), 05/07: half stacks either side of the drums, combo, guitar, three mics,
	# wedges on the front edge, olive tree at the open end of the stage, PAs at the near end
	var top := STAGE_H
	_kit_solid(g, "amp_stack", Vector3(17.7, top, -0.05), 0.0, "AmpStackL")
	_kit_solid(g, "amp", Vector3(19.2, top, 0.2), 0.0, "ComboL")
	_kit_solid(g, "drum_kit", Vector3(20.9, top, 0.75), 0.0, "DrumKit")
	_kit_solid(g, "amp_stack", Vector3(22.7, top, -0.05), 0.0, "AmpStackR")
	_kit_solid(g, "stage_tree", Vector3(24.2, top, 0.3), -90.0, "StageTree")
	_kit_solid(g, "amp", Vector3(23.9, top, 1.7), -20.0, "ComboR")
	_kit_solid(g, "guitar_on_stand", Vector3(17.4, top, 1.3), 20.0, "Guitar")
	_kit(g, "mic_stand", Vector3(18.6, top, 2.5), 0.0, "Mic0")
	_kit(g, "mic_stand", Vector3(21.0, top, 2.6), 0.0, "Mic1")
	_kit(g, "mic_stand", Vector3(23.0, top, 2.5), 0.0, "Mic2")
	for x in [17.6, 19.6, 23.6]:
		_kit_solid(g, "monitor_wedge", Vector3(x, top, STAGE_Z1 - 0.3), 180.0, "Wedge%d" % int(x))
	# Parity 14 dressing (05: the stage floor is busy): pedalboards, cable runs, water bottles
	_kit(g, "pedalboard", Vector3(18.9, top, 2.15), 10.0, "PedalboardGtr")
	_kit(g, "pedalboard", Vector3(22.7, top, 2.2), -12.0, "PedalboardBass")
	var cables := [[Vector3(18.2, top, 0.6), 70.0], [Vector3(18.6, top, 1.6), 95.0], [Vector3(19.7, top, 0.9), 20.0],
		[Vector3(21.6, top, 1.55), 80.0], [Vector3(22.4, top, 0.6), 110.0], [Vector3(23.1, top, 1.3), 75.0],
		[Vector3(20.0, top, 2.55), 0.0], [Vector3(17.9, top, 2.6), 10.0]]
	for i in cables.size():
		_kit(g, "cable_run", cables[i][0], cables[i][1], "Cable%d" % i)
	for x in [18.3, 21.4, 23.3]:
		_kit(g, "bottle_clear", Vector3(x, top, 2.9), 0.0, "StageWater%d" % int(x))
	_kit_solid(g, "pa_speaker", Vector3(STAGE_X0 - 0.3, 0, STAGE_Z1 + 0.35), 0.0, "SpeakerL")
	_kit_solid(g, "pa_speaker", Vector3(STAGE_X0 - 0.3, 0, MAIN_Z0 + 0.3), 0.0, "SpeakerLBack")
	# Band spots: drummer behind the kit, guitarist, singer, bassist (05/06)
	_seat("Band", "Band_Drums", Vector3(20.9, top, 0.25), 0.0, 0.45, "band_drums")
	_seat("Band", "Band_Guitar", Vector3(18.6, top, 1.85), 15.0, 0.0, "band_guitar")
	_seat("Band", "Band_Vocal", Vector3(21.0, top, 1.95), 0.0, 0.0, "band_vocal")
	_seat("Band", "Band_Bass", Vector3(23.0, top, 1.85), -15.0, 0.0, "band_bass")
	# Truss with cube PARs along the top of the wall behind the stage (05: lamps over the curtains), facing the room
	var truss := _group("Truss", g)
	for i in int(sw / 2.0):
		_kit(truss, "truss_segment", Vector3(STAGE_X0 + 1.0 + i * 2.0, ROOM_H, MAIN_Z0 + 0.45), 0.0, "Segment%d" % i)
	# Iteration 11: the carpet is not emissive and nothing floods it; each PAR on the truss throws its own pool
	# (renders 05/06: red pools with dark falloff between them, blue on the drums). The PARs tilt down at the stage.
	var pars := [[17.8, "red"], [19.4, "red"], [21.0, "blue"], [22.6, "red"], [24.2, "amber"]]
	var aims := [Vector3(18.4, top, 1.9), Vector3(19.4, top, 1.4), Vector3(20.9, top + 0.6, 0.6), Vector3(22.6, top, 1.7), Vector3(23.8, top, 1.4)]
	var par_col := {"red": NEON_RED, "blue": STAGE_BLUE, "amber": Color("ff7a30")}
	for i in pars.size():
		var par := _kit(truss, "par_light_" + pars[i][1], Vector3(pars[i][0], ROOM_H - 0.5, MAIN_Z0 + 0.45), 0.0, "Par%d" % i)
		par.rotation_degrees.x = 40.0
		var src := Vector3(pars[i][0], ROOM_H - 0.75, MAIN_Z0 + 0.75)
		var blue: bool = pars[i][1] == "blue"
		_spot(g, "ParSpot%d" % i, par_col[pars[i][1]], 2.4 if blue else 3.4, 7.5, 16.0 if blue else 24.0, src, aims[i])   # no spot shadows: the key light's map is the one shadow (phone budget)
	_omni(g, "BackdropGlowA", Color("e0261c"), 0.7, 4.0, Vector3(MAIN_X1 - 0.8, 1.6, 2.0))
	_omni(g, "BackdropGlowB", Color("e0261c"), 1.4, 4.5, Vector3(MAIN_X1 - 0.8, 1.6, 6.0))
	_omni(g, "BackdropGlowC", Color("e0261c"), 0.7, 4.0, Vector3(MAIN_X1 - 0.8, 1.6, 10.5))

## Contact shadows (Daniele: the renders have dark shadow under every piece of furniture). Every solid kit piece on the
## main-room floor adds a soft dark disc; _contact_shadows() paints them all into one texture on one floor quad
## (one draw call; Compatibility has no SSAO).
func _shadow_spot(p: Vector3, r: float, strength := 0.75) -> void:
	if p.y < 0.05 and p.x > 10.0 and p.x < MAIN_X1 and p.z > MAIN_Z0 and p.z < MAIN_Z1:
		shadow_spots.append([Vector2(p.x, p.z), r, strength])

func _shadow_rect(r: Rect2, strength := 0.7) -> void:
	shadow_spots.append([r, 0.0, strength])

func _contact_shadows() -> void:
	const PPM := 16.0
	var w := int((MAIN_X1 - 10.0) * PPM)
	var h := int((MAIN_Z1 - MAIN_Z0) * PPM)
	var alpha := PackedFloat32Array()
	alpha.resize(w * h)
	for s in shadow_spots:
		if s[0] is Rect2:
			var r: Rect2 = s[0]
			for py in range(int((r.position.y - MAIN_Z0) * PPM), int((r.end.y - MAIN_Z0) * PPM)):
				for px in range(int((r.position.x - 10.0) * PPM), int((r.end.x - 10.0) * PPM)):
					if px >= 0 and py >= 0 and px < w and py < h:
						alpha[py * w + px] = maxf(alpha[py * w + px], s[2])
			continue
		var c: Vector2 = s[0]
		var rad: float = s[1] * 1.25
		var cx := (c.x - 10.0) * PPM
		var cy := (c.y - MAIN_Z0) * PPM
		var rp := rad * PPM
		for py in range(maxi(0, int(cy - rp)), mini(h, int(cy + rp) + 1)):
			for px in range(maxi(0, int(cx - rp)), mini(w, int(cx + rp) + 1)):
				var d := Vector2(px + 0.5 - cx, py + 0.5 - cy).length() / rp
				if d < 1.0:
					var a: float = s[2] * clampf((1.0 - d) / 0.45, 0.0, 1.0)
					alpha[py * w + px] = maxf(alpha[py * w + px], a)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for py in h:
		for px in w:
			img.set_pixel(px, py, Color(0.02, 0.0, 0.0, alpha[py * w + px]))
	var m := StandardMaterial3D.new()
	m.resource_name = "ContactShadows"
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var qm := QuadMesh.new()
	qm.size = Vector2(MAIN_X1 - 10.0, MAIN_Z1 - MAIN_Z0)
	qm.orientation = PlaneMesh.FACE_Y
	var mi := MeshInstance3D.new()
	mi.name = "ContactShadows"
	mi.mesh = qm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3((10.0 + MAIN_X1) * 0.5, 0.006, (MAIN_Z0 + MAIN_Z1) * 0.5)
	_own(mi, vroot.get_node("MainRoom"))

## Camera framings, one per zone, read by camera_rig.gd. rect = membership (x, z, w, d); clamp = where the look
## target may go inside the zone; yaw 0 looks north (-z), -90 looks east. A "fallback" zone (floor) covers the
## whole main room and applies only where no other zone does.
func _camera_zones() -> void:
	var g := _group("CameraZones")
	var zones := [
		{"name": "lounge", "rect": Rect2(0, 0, 10, 10), "clamp": Rect2(3.4, 2.8, 2.2, 4.2), "yaw": 90.0, "pitch": -34.0, "dist": 7.5, "look_y": 1.3},
		{"name": "bar", "rect": Rect2(BAR_X0, 7.4, 13.0, MAIN_Z1 - 7.4), "clamp": Rect2(13.0, 10.0, 10.0, 0.8), "yaw": 180.0, "pitch": -32.0, "dist": 7.0, "look_y": 1.0},
		{"name": "stage", "rect": Rect2(STAGE_X0, MAIN_Z0, MAIN_X1 - STAGE_X0, STAGE_Z1 - MAIN_Z0 + 0.2), "clamp": Rect2(20.5, 1.2, 5.0, 0.4), "yaw": 0.0, "pitch": -24.0, "dist": 7.0, "look_y": 1.4},
		{"name": "floor", "rect": Rect2(10, MAIN_Z0, MAIN_X1 - 10, MAIN_Z1 - MAIN_Z0), "clamp": Rect2(13.0, 4.0, 10.0, 4.0), "yaw": -90.0, "pitch": -30.0, "dist": 8.5, "look_y": 0.9, "fallback": true},
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

## Velvet banquette from x0 to x1 against a north wall at z0 (seat 0.6 deep, 0.45 high).
func _banquette_box(parent: Node, nm: String, x0: float, x1: float, z0: float, solid := true) -> void:
	if kit.has("banquette_straight"):
		var w: float = kit.banquette_straight.footprint_m[0]
		var count := int(round((x1 - x0) / w))
		for i in count:
			_kit(parent, "banquette_straight", Vector3(x0 + w * (i + 0.5), 0, z0 + kit.banquette_straight.footprint_m[1] * 0.5), 0.0, "%s%d" % [nm, i])
	else:
		var b := _group(nm, parent)
		_box(b, "Seat", Vector3(x0, 0, z0), Vector3(x1 - x0, 0.45, 0.6), _mat("velvet_red", VELVET_RED, 0.95), false)
		_box(b, "Back", Vector3(x0, 0.45, z0), Vector3(x1 - x0, 0.5, 0.18), _mat("velvet_shadow", VELVET_SHADOW, 0.95), false)
	if solid:
		_collider(parent, nm + "Collider", Vector3((x0 + x1) * 0.5, 0.45, z0 + 0.3), Vector3(x1 - x0, 0.9, 0.6))

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
	nm.agent_max_climb = 0.05   # ramps only from their foot: the player cannot step onto a ramp side edge
	nm.agent_max_slope = 45.0
	region.navigation_mesh = nm
	_own(region, vroot)
	# Bake here so the shipped scene carries the navmesh; venue.gd re-bakes only if it is empty.
	root.add_child(vroot)
	region.bake_navigation_mesh(false)
	root.remove_child(vroot)
	print("navmesh polygons: ", nm.get_polygon_count())
