@tool
extends SceneTree
## Generates res://scenes/venue/venue.tscn from the voxel kit (res://assets/kit/manifest.json). Run from game/:
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/build_venue.gd
## Re-run after editing or after the kit is re-exported; hand-edits to venue.tscn are overwritten. Units are metres,
## x east, z south, y up. Room height 4 m (DECISIONS 2026-10-27 j).
##
## Layout v4 (docs/art/plan-v4.md, data in tools/plan_v4.py, from the real floor map direction 08 + answers):
##   x 0 = the lobby's street wall, z 0 = the shared north wall of lounge and main room. 1 map px = 0.0331 m.
##   Lobby (spawn, street door west) -> entrance corridor along the south of the lounge -> Sticker door -> lounge
##   (plant wall, neon, banquette, long table and the pinball on the west wall; stairs SW; game cabinet by the
##   stairs; two columns) -> buffer zone (four tall tables, window north with a tree outside, mirror south,
##   curtains both ends) -> main room 21.7 x 15 m: stage at floor level mid north wall (carpets, backstage behind),
##   tables west of it, tiny two-stool tables below and east of it, a bare tree east, a row of five four-chair
##   tables (Mali at Table2), raised +15 cm strip on the east with couch, shelves, round tables, neon under the
##   edge and mirror ceiling panels; the bar on the south wall (cashier bump, reindeer head, red back bar, walled
##   staff area east); the strip west of the bar runs south to the toilets vestibule (kitchen curtain); the
##   smoking room in the south-east (red door in, emergency exit south, glass to the night street east).
##   Green rooms on the map (backstage, kitchen, toilets, staff area) are closed boxes behind doors: NPC spawns.
## Kit objects are instanced from their .glb (never copied). Objects the 🧱 kit session is still modelling
## (PLACEHOLDERS) are grey boxes of the planned footprint until their name appears in the manifest: the swap is
## automatic. The floor stays 2 m textured tiles (Compatibility shades at most 8 lights per mesh).
## Furniture gets box colliders so the NavigationRegion3D (baked here) routes tap-to-move around it.
## Ceiling pieces are on render layer 2 (the game camera hides them). Walls carry meta "cut_normal" for
## camera_rig.gd's cutaway: the outward normal of the room whose camera looks through them.

const MANIFEST := "res://assets/kit/manifest.json"
const OUT := "res://scenes/venue/venue.tscn"
const ROOM_H := 4.0
const CEILING_LAYER := 2
const BAR_SEAT_H := 0.8       # kit bar_stool seat top; chairs, drum stools and banquettes are 0.45
const TALL_SEAT_H := 0.75
const RAISED_H := 0.15

# Rooms (plan_v4.py ROOMS): x0, z0, x1, z1
const LOBBY := Rect2(0.0, 5.05, 2.15, 9.85)
const CORRIDOR := Rect2(2.15, 13.25, 13.3, 1.65)
const LOUNGE := Rect2(2.35, 0.0, 13.1, 13.05)
const STUB := Rect2(15.45, 10.1, 4.5, 2.3)
const BUFFER := Rect2(15.45, 3.0, 4.65, 4.6)
const MAIN := Rect2(20.1, 0.0, 21.7, 15.0)
const MAIN_X0 := 20.1
const MAIN_X1 := 41.8
const MAIN_Z1 := 15.0
const MAIN_SE_Z := 12.65           # south wall east of the bar (staff area, smoke door)
const BAR_X0 := 21.8
const BAR_X1 := 35.75
const RAISED := Rect2(39.5, 0.0, 2.3, 10.85)
const VESTIBULE := Rect2(20.2, 15.0, 4.15, 1.7)
const SMOKING := Rect2(38.3, 12.85, 3.5, 5.05)
const STAGE := Rect2(27.6, 0.0, 6.3, 4.15)
const BACKSTAGE := Rect2(24.3, -3.2, 3.2, 3.2)
# Stairs (Daniele, playtest of v4): the first flight along the lounge's south wall (the Sticker-door wall), its bottom
# step facing the game machine, rising west to a landing in the SW corner; the second flight turns right and climbs
# north along the west wall into the floor above (closed: the player can climb to it, not into it).
const STAIR_LOWER := Rect2(4.05, 11.45, 4.0, 1.6)     # first flight, foot at its east end
const STAIR_LANDING := Rect2(2.35, 11.35, 1.7, 1.7)
const STAIR_UPPER := Rect2(2.35, 7.75, 1.6, 3.6)      # second flight, foot at its south end (the landing)
const STAIR_H1 := 1.6                                 # landing height
const STAIR_TOP := 4.0                                # the floor above
const STAIR_STOP_Z := 10.05                           # rope across the second flight: as high as the player climbs
const CABINET_X := 10.3                               # game machine, ~1.9 m east of the bottom step
const DOOR_W := 1.2                                   # walk-through doors: kit leaf (1 m) stretched to this opening
const STICKER_DOOR := Vector2(13.05, 14.25)  # x range on the lounge south wall
const STREET_DOOR := Vector2(6.6, 7.8)       # z range on the lobby west wall
const SMOKE_DOOR := Vector2(39.0, 40.2)      # x range on the wall z MAIN_SE_Z
const STAFF_DOOR_BAR := Vector2(37.05, 38.05)
const DOOR_USERS := "door_user"              # groups whose members open a door (player, crowd; staff_door_user)
const STAFF_USERS := "staff_door_user"
const STAFF_PASS := Vector2(36.05, 36.95)   # half wall for orders in the staff room's north wall, beside the staff door
const TINY_ROW_Z := 5.1
const TINY_ROW_X := [27.0, 28.45, 30.05, 31.55, 33.1, 34.6]
const TINY_EAST_X := 35.1
const TINY_EAST_Z := [0.95, 2.3, 3.5]
const ROW5 := [[24.6, 8.4, 45.0], [27.45, 8.4, 45.0], [30.05, 8.4, 0.0], [32.7, 8.4, 45.0], [35.45, 8.4, 0.0]]
const RAISED_TABLES_Z := [1.25, 3.1, 4.9, 7.3, 8.55]
const RAISED_TABLE_X := 40.4
const COUNTER_STOOLS_X := [24.65, 25.9, 27.1, 28.3, 30.95, 31.95, 32.95, 33.95, 34.95]
const COUNTER_STOOL_Z := 12.2
const BUFFER_TALL := [Vector2(16.7, 3.9), Vector2(18.7, 3.9), Vector2(16.7, 6.7), Vector2(18.7, 6.7)]
const OPENING_TALL := [Vector2(20.5, 9.05), Vector2(20.5, 11.5)]
const SMOKE_TABLES := [Vector2(41.2, 14.05), Vector2(38.85, 14.45), Vector2(38.85, 16.55), Vector2(41.2, 16.4)]
const TREE := Vector2(37.6, 0.7)
const TREE_OUTSIDE := Vector2(17.7, 1.0)
const CASHIER_X := 29.65

## Kit names the 🧱 session is modelling (brief 2026-11-01): box size (w, d, h) until the .glb lands.
const PLACEHOLDERS := {
	"tall_table_square": Vector3(0.6, 0.6, 1.05), "tall_table_round": Vector3(0.6, 0.6, 1.05), "tall_stool": Vector3(0.35, 0.35, 0.75),
	"tiny_table": Vector3(0.5, 0.5, 0.5), "couch_long": Vector3(1.0, 0.5, 0.85), "shelf_wall_tile": Vector3(1.0, 0.25, 0.05),
	"raised_edge_neon": Vector3(1.0, 0.04, 0.04), "cashier_counter": Vector3(1.4, 0.4, 1.1), "reindeer_head": Vector3(0.5, 0.45, 0.7),
	"game_cabinet_bc": Vector3(0.7, 0.75, 1.8), "pinball_machine": Vector3(0.7, 1.4, 1.3), "red_door": Vector3(1.2, 0.1, 2.2),
	"emergency_door": Vector3(1.0, 0.1, 2.2), "sticker_door": Vector3(1.7, 0.1, 2.3), "staff_door": Vector3(1.1, 0.1, 2.2),
	"window_wall_panel": Vector3(1.0, 0.1, 4.0), "mirror_wall_panel": Vector3(1.0, 0.05, 2.6), "outdoor_tree_bare": Vector3(1.6, 1.6, 3.2),
	"smoke_table_square": Vector3(0.85, 0.85, 0.75), "smoke_table_round": Vector3(0.7, 0.7, 0.55), "wishbone_chair": Vector3(0.5, 0.5, 0.75),
	"ashtray": Vector3(0.12, 0.12, 0.05), "air_purifier": Vector3(0.35, 0.35, 0.8), "wall_picture_framed": Vector3(0.7, 0.05, 0.5),
	"picture_light": Vector3(0.4, 0.12, 0.08), "vinyl_record_wall": Vector3(0.32, 0.03, 0.32), "lightbox_bc": Vector3(0.9, 0.12, 0.35),
	"wine_fridge": Vector3(0.6, 0.6, 1.8), "par_on_stand": Vector3(0.35, 0.35, 1.6),
}
## Placeholder tints so the boxes read on captures (grey by default)
const PH_TINT := {"red_door": Color("8c0a10"), "emergency_door": Color("1a1618"), "sticker_door": Color("5a4a40"),
	"staff_door": Color("2a2224"), "window_wall_panel": Color("18202c"), "mirror_wall_panel": Color("50565e"),
	"couch_long": Color("3a1a1a"), "outdoor_tree_bare": Color("3a3028"), "raised_edge_neon": Color("ff2a14"),
	"lightbox_bc": Color("f0e6d0"), "wine_fridge": Color("1a1a1e"), "pinball_machine": Color("2a3a5a"), "game_cabinet_bc": Color("202a3a")}

# Palette (art bible §3, game values)
const CABIN_DARK := Color("1c0d0c")
const BEAM_BLACK := Color("160a0c")
const FLOOR_GREY := Color("57525c")
const CONCRETE := Color("6a6a6c")          # corridors, smoking room and vestibule floors (photos 10, 13)
const VELVET_SHADOW := Color("3e0408")
const VELVET_RED := Color("8c0610")
const CARPET_RED := Color("9a0a12")
const PANEL_RED := Color("b80a10")
const NEON_RED := Color("ff2a14")
const LAMP_GOLD := Color("ffb860")
const TEALIGHT := Color("f7db71")
const SHELF_AMBER := Color("ff8a30")
const WOOD_MID := Color("6e3522")
const STOOL_BLACK := Color("221110")
const STAGE_BLUE := Color("20a8f0")
const SCREEN_CYAN := Color("18d0fa")
const BAR_RED := Color("ff2018")           # photo 09/16: the back bar is lit red
const NIGHT_SKY := Color("070810")
const STREETLIGHT := Color("ffd9a0")

var vroot: Node3D
var kit := {}          # name -> manifest entry
var mats := {}
var light_count := 0
var spots: Node3D      # Patrons/Spots: seats, staff, NPC spawns and wander points for scripts/venue_patrons.gd
var shadow_count := 0
var shadow_spots: Array = []   # [centre Vector2 | Rect2, radius, strength] for _contact_shadows()
var placeholders_used := {}    # name -> count, logged at the end

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
	_lobby_and_corridor()
	_lounge()
	_stairs()
	_buffer()
	_main_room()
	_stage()
	_tables()
	_raised()
	_bar()
	_vestibule()
	_smoking()
	_closed_rooms()
	_outside()
	_thresholds()
	_camera_zones()
	_contact_shadows()
	await process_frame   # root joins the tree after _init starts; navmesh parsing needs the venue inside it
	_navigation()
	_wander_spots()
	var looks := Node.new()
	looks.name = "Looks"
	looks.set_script(load("res://scenes/venue/venue_looks.gd"))
	_own(looks, vroot)
	var doors := Node.new()
	doors.name = "Doors"
	doors.set_script(load("res://scenes/venue/venue_doors.gd"))
	_own(doors, vroot)
	patrons.set_script(load("res://scripts/venue_patrons.gd"))
	patrons.set("seated_count", 64)   # more seats than before (118); 64 seated + band + staff + wanderers stays under the draw budget
	vroot.set_script(load("res://scripts/venue.gd"))
	var ps := PackedScene.new()
	ps.pack(vroot)
	var err := ResourceSaver.save(ps, OUT)
	print("venue saved: ", err, " lights=", light_count, " shadowed=", shadow_count)
	for k in placeholders_used:
		print("placeholder box (kit object missing): ", k, " x", placeholders_used[k])
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

func _floor_mat() -> StandardMaterial3D:
	return _bond_mat("floor", FLOOR_GREY, 0.07, 0.34, 0.5)

func _concrete_mat() -> StandardMaterial3D:
	return _bond_mat("concrete", CONCRETE, 0.04, 0.7, 0.2)

## Running-bond voxel blocks, 0.2 m, world-triplanar: the floor, and the dark brick of the upper walls.
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
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	m.roughness = rough
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
func _kit_solid(parent: Node, kname: String, pos: Vector3, rot_deg := 0.0, nm := "", h := -1.0, scl := Vector3.ONE) -> Node3D:
	var inst := _kit(parent, kname, pos, rot_deg, nm, scl)
	if inst == null:
		return null
	var fp: Array = kit[kname].footprint_m
	var height: float = kit[kname].height_m if h < 0.0 else h
	_shadow_spot(pos, maxf(fp[0] * scl.x, fp[1] * scl.z) * 0.5 + 0.06)
	_collider(inst, "Collider", Vector3(0, height * 0.5, 0), Vector3(fp[0], height, fp[1]))
	return inst

## Kit object by name when the kit has it, else a tinted box of the planned footprint (logged). Solid unless told not.
func _ph(parent: Node, kname: String, pos: Vector3, rot_deg := 0.0, nm := "", solid := true, scl := Vector3.ONE) -> Node3D:
	if kit.has(kname):
		return _kit_solid(parent, kname, pos, rot_deg, nm, -1.0, scl) if solid else _kit(parent, kname, pos, rot_deg, nm, scl)
	var s: Vector3 = PLACEHOLDERS.get(kname, Vector3(0.5, 0.5, 0.5))
	placeholders_used[kname] = placeholders_used.get(kname, 0) + 1
	var holder := Node3D.new()
	holder.name = nm if nm != "" else kname
	holder.position = pos
	holder.rotation_degrees.y = rot_deg
	holder.scale = scl
	holder.set_meta("placeholder", kname)
	_own(holder, parent)
	var col: Color = PH_TINT.get(kname, Color("6a6668"))
	var emit := 2.5 if kname == "raised_edge_neon" else (1.6 if kname == "lightbox_bc" else 0.0)
	var mi := _box(holder, "Box", Vector3(-s.x * 0.5, 0, -s.y * 0.5), Vector3(s.x, s.z, s.y), _mat("ph_" + kname, col, 0.8, emit), solid)
	if kname == "window_wall_panel":
		mi.material_override = _glass_mat()
	if solid:
		_shadow_spot(pos, maxf(s.x * scl.x, s.y * scl.z) * 0.5 + 0.06)
	return holder

func _glass_mat() -> StandardMaterial3D:
	if mats.has("glass"):
		return mats["glass"]
	var m := StandardMaterial3D.new()
	m.resource_name = "Glass"
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.5, 0.62, 0.8, 0.18)
	m.roughness = 0.05
	m.metallic_specular = 0.9
	mats["glass"] = m
	return m

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
	if n == null:
		return null
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

## Wall along x at z (thickness 0.2 on the side the normal points to), full height, with openings (x ranges) left out.
func _wall_x(parent: Node, nm: String, z: float, x0: float, x1: float, mat: Material, normal: Vector3, openings := [], lintel_y := 3.2) -> void:
	var zz := z if normal.z > 0 else z - 0.2
	var cuts: Array = openings.duplicate()
	cuts.sort_custom(func(a, b): return a.x < b.x)
	var x := x0
	var i := 0
	for o in cuts:
		if o.x > x:
			_wall(parent, "%s_%d" % [nm, i], Vector3(x, 0, zz), Vector3(o.x - x, ROOM_H, 0.2), mat, normal)
		_wall(parent, "%s_L%d" % [nm, i], Vector3(o.x, lintel_y, zz), Vector3(o.y - o.x, ROOM_H - lintel_y, 0.2), mat, normal)
		x = o.y
		i += 1
	if x < x1:
		_wall(parent, "%s_%d" % [nm, i], Vector3(x, 0, zz), Vector3(x1 - x, ROOM_H, 0.2), mat, normal)

## Wall along z at x, with openings (z ranges) left out.
func _wall_z(parent: Node, nm: String, x: float, z0: float, z1: float, mat: Material, normal: Vector3, openings := [], lintel_y := 3.2) -> void:
	var xx := x if normal.x > 0 else x - 0.2
	var cuts: Array = openings.duplicate()
	cuts.sort_custom(func(a, b): return a.x < b.x)
	var z := z0
	var i := 0
	for o in cuts:
		if o.x > z:
			_wall(parent, "%s_%d" % [nm, i], Vector3(xx, 0, z), Vector3(0.2, ROOM_H, o.x - z), mat, normal)
		_wall(parent, "%s_L%d" % [nm, i], Vector3(xx, lintel_y, o.x), Vector3(0.2, ROOM_H - lintel_y, o.y - o.x), mat, normal)
		z = o.y
		i += 1
	if z < z1:
		_wall(parent, "%s_%d" % [nm, i], Vector3(xx, 0, z), Vector3(0.2, ROOM_H, z1 - z), mat, normal)

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

## Floor of 2 m tiles (separate meshes so each tile only takes the lamps near it) plus one collider for the room.
func _floor(parent: Node, r: Rect2, mat: Material = null, y := 0.0, nm := "Floor") -> void:
	var g := _group(nm, parent)
	var bm := BoxMesh.new()
	bm.size = Vector3(2, 0.2, 2)
	var m: Material = mat if mat else _floor_mat()
	var tiles_x := int(ceil(r.size.x / 2.0))
	var tiles_z := int(ceil(r.size.y / 2.0))
	for ix in tiles_x:
		for iz in tiles_z:
			var mi := MeshInstance3D.new()
			mi.name = "Tile%d_%d" % [ix, iz]
			mi.mesh = bm
			mi.material_override = m
			var w := minf(2.0, r.size.x - ix * 2.0)
			var d := minf(2.0, r.size.y - iz * 2.0)
			mi.scale = Vector3(w / 2.0, 1, d / 2.0)
			mi.position = Vector3(r.position.x + ix * 2.0 + w * 0.5, y - 0.1, r.position.y + iz * 2.0 + d * 0.5)
			_own(mi, g)
	_collider(g, "Collider", Vector3(r.get_center().x, y - 0.1, r.get_center().y), Vector3(r.size.x, 0.2, r.size.y))

func _ceiling(parent: Node, r: Rect2, nm := "Ceiling") -> void:
	_ceiling_group(_nocast(_box(parent, nm, Vector3(r.position.x, ROOM_H, r.position.y), Vector3(r.size.x, 0.2, r.size.y), _mat("ceiling", CABIN_DARK, 0.95), false, CEILING_LAYER)))

func _nocast(n: GeometryInstance3D) -> GeometryInstance3D:
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

func _ceiling_group(n: Node) -> void:
	n.add_to_group("ceiling", true)

## Closed door (kit frame + leaf, front +z = room side) dropped into the gap the wall leaves for it; solid.
func _door(parent: Node, nm: String, kname: String, c: Vector3, rot: float, normal: Vector3, solid := true) -> void:
	_cut(_ph(parent, kname, c, rot, nm, solid), normal)

## Door that swings (Daniele, playtest of v4): the kit piece (frame and leaf are one mesh, room side +z) is the leaf,
## hung from a hinge pivot at the +x jamb of a `w` m opening centred on `c`. scenes/venue/venue_doors.gd swings it
## away from whoever of group `users` comes near and closes it after they pass. No collider on the leaf, so the
## opening stays in the navmesh; a staff-only door gets a blocker in its opening instead (`block`).
func _swing_door(parent: Node, nm: String, kname: String, c: Vector3, rot: float, normal: Vector3, w := DOOR_W,
		users := DOOR_USERS, block := false) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = nm
	pivot.position = c + Basis(Vector3.UP, deg_to_rad(rot)) * Vector3(w * 0.5, 0, 0)
	pivot.rotation_degrees.y = rot
	pivot.set_meta("center", c)
	pivot.set_meta("users", users)
	pivot.add_to_group("swing_door", true)
	_own(pivot, parent)
	var kw: float = kit[kname].footprint_m[0] if kit.has(kname) else 1.0
	_kit(pivot, kname, Vector3(-w * 0.5, 0, 0), 0.0, nm + "Leaf", Vector3(w / kw, 1, 1))
	if block:
		_collider(parent, nm + "Blocker", c + Vector3(0, 1.2, 0), Vector3(w, 2.4, 0.2), Vector3(0, deg_to_rad(rot), 0))
	# Not hidden with its wall (a door left standing in a cut-away wall still reads as the way through); only when
	# it crosses the sight line to the player. `normal` stays for reference.
	pivot.set_meta("wall_normal", normal)
	_cut(pivot, Vector3.ZERO)
	return pivot

## Table dressing: a lit lamp and/or tealights (emissive); the light is shared by the caller.
func _table_dressing(parent: Node, nm: String, top: Vector3, lamp: bool, tealights: int, glasses := 2) -> void:
	if lamp:
		_kit(parent, "table_lamp_lit", top + Vector3(-0.1, 0, -0.05), 0.0, nm + "Lamp")
	for i in tealights:
		_kit(parent, "tealight_lantern", top + Vector3(0.14 + i * 0.1, 0, 0.1 - i * 0.16), 0.0, nm + "Tealight%d" % i)
	for k in glasses:
		var a := k * 2.1 + 0.6
		_kit(parent, "beer_glass", top + Vector3(cos(a) * 0.26, 0, sin(a) * 0.26), 0.0, nm + "Glass%d" % k)
	_kit(parent, "napkin_cup", top + Vector3(0.06, 0, -0.2), 0.0, nm + "Napkins")

## Spot for scripts/venue_patrons.gd, named by zone so a later cast can be placed without moving the layout.
## `table` names the table (kit instance) a seat belongs to, so the player can take a free seat at the table they
## tapped (scripts/zones/venue_session.gd); `couch` marks seats with their backs to a wall (stand up forward).
func _seat(zone: String, nm: String, pos: Vector3, yaw_deg: float, seat_h := 0.45, pose := "sit", table := "", couch := false) -> void:
	var m := Marker3D.new()
	m.name = nm
	m.position = pos
	m.rotation_degrees.y = yaw_deg
	m.set_meta("zone", zone)
	m.set_meta("pose", pose)
	m.set_meta("seat_h", seat_h)
	if pose == "sit":
		m.set_meta("table", table)
		m.set_meta("couch", couch)
		m.add_to_group("seat", true)
	_own(m, spots)

func _wander_spots() -> void:
	var pts := {"Wander_Lobby": Vector3(1.1, 0, 10.0), "Wander_Corridor": Vector3(8.0, 0, 14.1), "Wander_Lounge": Vector3(7.5, 0, 6.5),
		"Wander_Buffer": Vector3(17.7, 0, 5.3), "Wander_Opening": Vector3(21.3, 0, 7.0), "Wander_Aisle": Vector3(30.0, 0, 6.7),
		"Wander_StageFront": Vector3(30.75, 0, 6.3), "Wander_BarEnd": Vector3(23.0, 0, 11.0), "Wander_BarEast": Vector3(36.5, 0, 11.2),
		"Wander_East": Vector3(37.0, 0, 3.5), "Wander_Smoking": Vector3(40.0, 0, 15.2), "Wander_Toilets": Vector3(22.3, 0, 15.8)}
	for k in pts:
		_seat("Wander", k, pts[k], 0.0, 0.0, "wander")
	# NPC spawns inside the closed rooms (map legend): band backstage, staff in the kitchen and the walled bar area
	_seat("Spawn", "Spawn_Backstage", Vector3(25.9, 0, -1.5), 180.0, 0.0, "spawn")
	_seat("Spawn", "Spawn_Kitchen", Vector3(18.5, 0, 16.5), 0.0, 0.0, "spawn")
	_seat("Spawn", "Spawn_StaffArea", Vector3(37.0, 0, 13.8), 0.0, 0.0, "spawn")
	_seat("Staff", "Staff_Hatch", Vector3((STAFF_PASS.x + STAFF_PASS.y) * 0.5, 0, MAIN_SE_Z + 0.55), 180.0, 0.0, "hatch")

# --- environment ------------------------------------------------------------------------------------------

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = NIGHT_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.44, 0.44)
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
	# Warm key from high over the bar corner (iteration 12/18): the one shadow map in the venue (phone budget).
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color("ffcfa8")
	key.light_energy = 0.32
	key.light_specular = 0.3
	key.shadow_enabled = true
	key.shadow_opacity = 0.85
	key.shadow_blur = 1.2
	key.shadow_bias = 0.03
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 30.0
	key.light_cull_mask = 0xFFFFF & ~(1 << (CEILING_LAYER - 1))
	key.transform = Transform3D(Basis.looking_at(Vector3(-0.35, -1.0, -0.3)), Vector3(32, 8, 8))
	_own(key, vroot)
	light_count += 1
	shadow_count += 1
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_own(we, vroot)

# --- rooms ------------------------------------------------------------------------------------------------

## Entrance lobby (spawn) and the corridor along the south of the lounge: concrete, dim, the street door west.
func _lobby_and_corridor() -> void:
	var g := _group("Lobby")
	var wall := _mat("lobby_wall", Color("2a2426"), 0.9)
	_floor(g, LOBBY, _concrete_mat())
	_floor(g, CORRIDOR, _concrete_mat(), 0.0, "CorridorFloor")
	_ceiling(g, Rect2(LOBBY.position.x, LOBBY.position.y, CORRIDOR.end.x - LOBBY.position.x, LOBBY.size.y))
	# West (street) wall with the door, north wall, the long south wall, the corridor's east end
	_wall_z(g, "WallWest", 0.0, LOBBY.position.y, LOBBY.end.y, wall, Vector3.LEFT, [STREET_DOOR], 2.3)
	_wall_x(g, "WallNorth", LOBBY.position.y, -0.2, LOUNGE.position.x, wall, Vector3.FORWARD)
	_wall_x(g, "WallSouth", CORRIDOR.end.y, -0.2, CORRIDOR.end.x + 0.2, wall, Vector3.BACK)
	_wall_z(g, "WallEast", CORRIDOR.end.x, CORRIDOR.position.y, CORRIDOR.end.y, wall, Vector3.RIGHT)
	# Street door (where you come in and leave): a dark wooden leaf (kit staff_door; no photo of the real one yet)
	# that swings open when someone comes near, exit sign above, front facing east into the lobby
	var sz := (STREET_DOOR.x + STREET_DOOR.y) * 0.5
	_swing_door(g, "StreetDoor", "staff_door", Vector3(-0.1, 0, sz), 90.0, Vector3.LEFT)
	_cut(_kit(g, "exit_sign", Vector3(0.06, 2.6, sz), 90.0, "ExitSignStreet"), Vector3.LEFT)
	# A step of night street outside it, so the open door shows the pavement; invisible kerb walls stop the player
	var pave := _mat("pavement", Color("16171c"), 0.95)
	_floor(g, Rect2(-1.8, sz - 1.6, 1.6, 3.2), pave, 0.0, "StreetStep")
	_box(g, "StreetSill", Vector3(-0.2, -0.2, STREET_DOOR.x), Vector3(0.2, 0.2, STREET_DOOR.y - STREET_DOOR.x), _concrete_mat())
	_collider(g, "StreetKerbW", Vector3(-1.85, 1.2, sz), Vector3(0.1, 2.4, 3.2))
	_collider(g, "StreetKerbN", Vector3(-1.0, 1.2, sz - 1.65), Vector3(1.8, 2.4, 0.1))
	_collider(g, "StreetKerbS", Vector3(-1.0, 1.2, sz + 1.65), Vector3(1.8, 2.4, 0.1))
	_box(g, "StreetFacade", Vector3(-6.0, 0, sz - 4.0), Vector3(0.5, 6.0, 8.0), _mat("building", Color("0c0d12"), 0.95), false)
	_box(g, "StreetWindow", Vector3(-5.52, 2.2, sz - 0.6), Vector3(0.04, 1.0, 1.2), _mat("lit_window", Color("ffd9a0"), 0.6, 1.2), false)
	# Lobby and corridor are one L corridor (Daniele, corrections on plan v4): no door between them. Framed pictures
	# of regular customers on its walls later; wall_picture_framed placeholders for now.
	for i in 2:
		_cut(_ph(g, "wall_picture_framed" if i == 0 else "wall_picture_framed_b", Vector3(0.06, 1.4, 10.0 + i * 2.2), 90.0, "RegularPictureW%d" % i, false), Vector3.LEFT)
	for i in 4:
		_cut(_ph(g, "wall_picture_framed" if i % 2 == 0 else "wall_picture_framed_b", Vector3(3.6 + i * 2.6, 1.4, CORRIDOR.end.y - 0.06), 180.0, "RegularPictureS%d" % i, false), Vector3.BACK)
	# None on the corridor's lounge side: that wall hides on the sight line and its pictures would float
	# Sticker door between the corridor and the lounge: swings open for whoever comes through, stickers on the
	# corridor side (front +z)
	_swing_door(g, "StickerDoor", "sticker_door", Vector3((STICKER_DOOR.x + STICKER_DOOR.y) * 0.5, 0, LOUNGE.end.y + 0.1), 0.0, Vector3.BACK)
	_omni(g, "LobbyLight", Color("ffc890"), 0.9, 5.0, Vector3(1.1, 3.2, 8.0))
	_omni(g, "CorridorLight", Color("ff9a60"), 0.8, 6.0, Vector3(9.0, 3.3, 14.1))
	for x in [4.0, 10.0]:
		_cut(_kit(g, "wall_lamp", Vector3(x, 1.9, CORRIDOR.end.y - 0.05), 0.0, "CorridorLamp%d" % int(x)), Vector3.BACK)
	_kit(g, "track_light", Vector3(13.0, ROOM_H, 14.1), 0.0, "CorridorTrack")
	_seat("Lobby", "Lobby_Stand0", Vector3(1.3, 0, 12.6), 90.0, 0.0, "stand")

func _lounge() -> void:
	var g := _group("Lounge")
	var wall := _mat("lounge_wall", Color("4a0c10"), 0.9)
	_floor(g, LOUNGE)
	_floor(g, STUB, _concrete_mat(), 0.0, "StubFloor")
	_ceiling(g, Rect2(LOUNGE.position.x, LOUNGE.position.y, STUB.end.x - LOUNGE.position.x, LOUNGE.size.y))
	_wall_z(g, "WallWest", LOUNGE.position.x, -0.2, LOUNGE.end.y + 0.2, wall, Vector3.LEFT)
	_wall_x(g, "WallNorth", 0.0, LOUNGE.position.x - 0.2, LOUNGE.end.x + 0.2, wall, Vector3.FORWARD)
	_wall_x(g, "WallSouth", LOUNGE.end.y, LOUNGE.position.x - 0.2, LOUNGE.end.x + 0.2, wall, Vector3.BACK, [STICKER_DOOR], 2.3)
	_wall_z(g, "WallEast", LOUNGE.end.x, -0.2, LOUNGE.end.y + 0.2, wall, Vector3.RIGHT,
		[Vector2(BUFFER.position.y, BUFFER.end.y), Vector2(STUB.position.y, STUB.end.y)], 3.4)
	# Old corridor alcove: closed doors into the old toilets at both ends, its east wall is the main room's
	_wall_x(g, "StubNorth", STUB.position.y, STUB.position.x, STUB.end.x, wall, Vector3.FORWARD, [Vector2(18.6, 19.6)], 2.15)
	_wall_x(g, "StubSouth", STUB.end.y, STUB.position.x, STUB.end.x, wall, Vector3.BACK, [Vector2(18.6, 19.6)], 2.15)
	_door(g, "OldToiletDoorN", "staff_door", Vector3(19.1, 0, STUB.position.y - 0.1), 0.0, Vector3.FORWARD)
	_door(g, "OldToiletDoorS", "staff_door", Vector3(19.1, 0, STUB.end.y + 0.1), 180.0, Vector3.BACK)
	_cut(_kit(g, "wall_lamp", Vector3(17.7, 1.9, STUB.position.y + 0.05), 0.0, "StubLamp"), Vector3.FORWARD)
	# West wall, north part (R02 kept): plant wall framing the neon over the banquette, long table in front
	for c in 4:
		for r in 3:
			_kit(g, "plant_wall_tile", Vector3(LOUNGE.position.x + 0.15, 0.9 + r, 1.6 + c), 90.0, "PlantWall%d_%d" % [c, r])
	_kit(g, "neon_sign", Vector3(LOUNGE.position.x + 0.38, 1.75, 3.1), 90.0, "NeonSign", Vector3(1.55, 1.55, 1.0))
	_omni(g, "NeonLight", NEON_RED, 2.6, 6.5, Vector3(LOUNGE.position.x + 1.3, 2.4, 3.1))
	_banquette(g, "LoungeBanquette", LOUNGE.position.x, 1.1, 5.1)
	_kit_solid(g, "communal_table", Vector3(3.9, 0, 3.6), 90.0, "LongTable")
	for i in 3:
		var z := 2.6 + i * 1.0
		_table_dressing(g, "LongTable%d" % i, Vector3(3.9, 0.75, z), i != 1, 1 if i == 1 else 0, 1)
		_kit_solid(g, "cafe_chair", Vector3(4.75, 0, z), -90.0, "Chair%d" % i)
		_seat("Lounge", "Lounge_Chair%d" % i, Vector3(4.75, 0, z), -90.0, 0.45, "sit", "LongTable")
		_seat("Lounge", "Lounge_Banquette%d" % i, Vector3(LOUNGE.position.x + 0.3, 0, z), 90.0, 0.45, "sit", "LongTable", true)
	_omni(g, "LongTableLightA", LAMP_GOLD, 2.2, 3.4, Vector3(3.9, 1.5, 2.8))
	_omni(g, "LongTableLightB", LAMP_GOLD, 1.8, 3.2, Vector3(3.9, 1.5, 4.6))
	# Pinball on the west wall between the banquette and the stairs (Daniele 2026-11-01); the kit's arcade cabinet
	# stands in for it until pinball_machine lands (Neon Pinball runs on it, DECISIONS (c)).
	if kit.has("pinball_machine"):
		_ph(g, "pinball_machine", Vector3(LOUNGE.position.x + 0.75, 0, 7.2), 90.0, "Pinball")
	else:
		_kit_solid(g, "arcade_cabinet", Vector3(LOUNGE.position.x + 0.45, 0, 7.2), 90.0, "ArcadeCabinet")
	_omni(g, "PinballGlow", SCREEN_CYAN, 0.6, 2.4, Vector3(LOUNGE.position.x + 1.2, 1.4, 7.2))
	# Black Cabin game machine by the stairs, near the Sticker door (flappy-bird style; zone stub "cabinet")
	_ph(g, "game_cabinet_bc", Vector3(CABINET_X, 0, LOUNGE.end.y - 0.4), 180.0, "GameCabinet")
	# Two white columns where the map shows them
	for i in 2:
		var p: Vector3 = [Vector3(8.95, 0, 3.9), Vector3(8.95, 0, 9.75)][i]
		_kit(g, "white_column", p, 0.0, "Column%d" % i)
		_collider(g, "Column%dCollider" % i, p + Vector3(0, ROOM_H * 0.5, 0), Vector3(0.4, ROOM_H, 0.4))
	# North wall, east part: CRT on its cabinet, collectibles shelf with the high counter and two stools (R02)
	_kit_solid(g, "crt_monitor", Vector3(11.2, 0, 0.3), 0.0, "CRT")
	_kit(g, "collectibles_shelf", Vector3(13.6, 0, 0.22), 0.0, "CollectiblesShelf")
	_collider(g, "ShelfCollider", Vector3(13.6, 1.1, 0.22), Vector3(2.0, 2.2, 0.4))
	_box(g, "HighCounter", Vector3(12.65, 0, 1.0), Vector3(1.9, 0.95, 0.5), _mat("wood_mid", WOOD_MID, 0.4))
	for i in 2:
		_kit_solid(g, "bar_stool", Vector3(13.15 + i * 0.9, 0, 1.85), 180.0, "CounterStool%d" % i)
		_seat("Lounge", "Lounge_Stool%d" % i, Vector3(13.15 + i * 0.9, 0, 1.85), 180.0, BAR_SEAT_H, "sit", "HighCounter")
	_cut(_kit(g, "wall_lamp", Vector3(10.2, 1.7, 0.1), 0.0, "RedDiscLamp"), Vector3.FORWARD)
	_cut(_kit(g, "ac_unit", Vector3(7.0, 3.3, 0.15), 0.0, "ACUnit"), Vector3.FORWARD)
	_cut(_kit(g, "painting_a", Vector3(6.0, 1.4, 0.05), 0.0, "LoungePainting"), Vector3.FORWARD)
	# Two round tables with four chairs in the open middle (the real lounge changes often, Daniele)
	for n in 2:
		_round_table(g, "LoungeTable%d" % n, "Lounge", Vector3(11.0, 0, 5.0 + n * 4.0), 0.0, n == 0)
	_omni(g, "LoungeTablesLight", LAMP_GOLD, 2.0, 4.5, Vector3(11.0, 1.9, 7.0))
	# Red cove strip and the ceiling: black beam grid with red emissive panels
	_box(g, "RedCove", Vector3(LOUNGE.position.x + 0.31, 0.9, 1.0), Vector3(0.04, 0.04, 4.4), _mat("red_strip", NEON_RED, 0.5, 3.0), false)
	var ceil := _group("CeilingGrid", g)
	for row in 5:
		for i in 12:
			_kit(ceil, "beam_segment", Vector3(3.0 + i, ROOM_H, 1.0 + row * 2.5), 0.0, "Beam%d_%d" % [row, i])
	for row in 4:
		for i in 8:
			_kit(ceil, "ceiling_panel", Vector3(4.0 + i * 1.3, ROOM_H, 1.75 + row * 2.5 + (i % 2) * 0.5), 0.0, "Panel%d_%d" % [row, i])
	_ceiling_group(ceil)
	_omni(g, "RedPanelLightA", PANEL_RED, 1.6, 7.0, Vector3(6.0, 3.6, 4.0))
	_omni(g, "RedPanelLightB", PANEL_RED, 1.4, 7.0, Vector3(10.0, 3.6, 10.0))
	_kit(g, "track_light", Vector3(6.0, ROOM_H, 7.0), 0.0, "TrackLight0")
	_kit(g, "track_light", Vector3(12.0, ROOM_H, 11.0), 0.0, "TrackLight1")

## Stairs in the lounge's south-west (Daniele, playtest of v4; map: grey L): the first flight along the south wall,
## its bottom step facing the game machine, rises west to a landing in the corner; the second flight turns right and
## climbs north along the west wall into the floor above, a dark bulkhead the steps disappear under. A velvet rope
## across the second flight is as far as the player goes (upstairs is closed for now). The flights are kit stair_run
## pieces stretched to fit; solid wedges under them carry the walk surface and the navmesh.
func _stairs() -> void:
	var g := _group("Stairs")
	var dark := _mat("beam_black", BEAM_BLACK, 0.7)
	var kh: float = kit.stair_run.height_m if kit.has("stair_run") else 3.3
	var kl: float = kit.stair_run.footprint_m[1] if kit.has("stair_run") else 3.65
	# First flight: kit rotated 90 (high end west), stretched to the run, squashed to the landing height
	var lo := STAIR_LOWER
	_kit(g, "stair_run", Vector3(lo.get_center().x, 0, lo.get_center().y), 90.0, "StairRunLower", Vector3(1, STAIR_H1 / kh, lo.size.x / kl))
	_wedge(g, "LowerWedge", Vector3(lo.end.x, 0, lo.position.y), Vector3(lo.position.x, STAIR_H1, lo.end.y), Vector3.LEFT)
	# Landing: a solid block in the corner
	var la := STAIR_LANDING
	_box(g, "Landing", Vector3(la.position.x, 0, la.position.y), Vector3(la.size.x, STAIR_H1, la.size.y), dark)
	# Second flight on a plinth the height of the landing, rising north to the floor above
	var up := STAIR_UPPER
	_box(g, "UpperPlinth", Vector3(up.position.x, 0, up.position.y), Vector3(up.size.x, STAIR_H1, up.size.y), dark, false)
	_kit(g, "stair_run", Vector3(up.get_center().x, STAIR_H1, up.get_center().y), 0.0, "StairRunUpper", Vector3(1, (STAIR_TOP - STAIR_H1) / kh, up.size.y / kl))
	_wedge(g, "UpperWedge", Vector3(up.position.x, STAIR_H1, up.end.y), Vector3(up.end.x, STAIR_TOP, up.position.y), Vector3.FORWARD)
	# Side rails on the open sides (the kit's own rail is on one side only): colliders up to above head height
	_collider(g, "RailLower", Vector3(lo.get_center().x, 1.5, lo.position.y - 0.05), Vector3(lo.size.x, 3.0, 0.1))
	_collider(g, "RailUpper", Vector3(up.end.x + 0.05, 2.2, (up.position.y + lo.position.y) * 0.5), Vector3(0.1, 4.4, lo.position.y - up.position.y))
	_rail(g, "RailLowerBar", Vector3(lo.end.x, 0.9, lo.position.y), Vector3(lo.position.x, STAIR_H1 + 0.9, lo.position.y))
	_rail(g, "RailUpperBar", Vector3(up.end.x, STAIR_H1 + 0.9, up.end.y), Vector3(up.end.x, STAIR_TOP + 0.9, up.position.y))
	# The floor above: a dark bulkhead over the top of the second flight (cut away when it hides the player)
	var bz := STAIR_STOP_Z - 0.1
	var bulk := _box(g, "UpperFloor", Vector3(up.position.x, 2.9, up.position.y - 0.4), Vector3(up.size.x + 0.25, ROOM_H - 2.9, bz - up.position.y + 0.4), dark, false)
	_cut(_nocast(bulk), Vector3.ZERO)
	_box(g, "UpperFloorLip", Vector3(up.position.x, 2.75, bz - 0.12), Vector3(up.size.x + 0.25, 0.15, 0.12), _mat("lounge_wall", Color("4a0c10"), 0.9), false)
	# Velvet rope across the second flight where the climb stops; the blocker keeps the player below the bulkhead
	var sy := STAIR_H1 + (up.end.y - STAIR_STOP_Z) / up.size.y * (STAIR_TOP - STAIR_H1)
	var velvet := _mat("velvet_red", VELVET_RED, 0.95)
	for x in [up.position.x + 0.12, up.end.x - 0.12]:
		_box(g, "RopePost_%d" % int(x * 10), Vector3(x - 0.04, sy - 0.1, STAIR_STOP_Z - 0.04), Vector3(0.08, 1.0, 0.08), _mat("cymbal_gold", Color("c8a050"), 0.35), false)
	_box(g, "Rope", Vector3(up.position.x + 0.12, sy + 0.7, STAIR_STOP_Z - 0.03), Vector3(up.size.x - 0.24, 0.06, 0.06), velvet, false)
	_collider(g, "StairStop", Vector3(up.get_center().x, 2.2, STAIR_STOP_Z - 0.05), Vector3(up.size.x, 4.4, 0.1))

## Solid ramp from `lo` (its foot edge corner, floor height lo.y) to `hi` (opposite corner at the top height hi.y);
## `up_dir` is the climbing direction (along x or z). Collider only: a convex wedge, solid down to the floor.
func _wedge(g: Node, nm: String, lo: Vector3, hi: Vector3, up_dir: Vector3) -> void:
	var a := Vector2(minf(lo.x, hi.x), minf(lo.z, hi.z))
	var b := Vector2(maxf(lo.x, hi.x), maxf(lo.z, hi.z))
	var pts := PackedVector3Array()
	for x in [a.x, b.x]:
		for z in [a.y, b.y]:
			pts.append(Vector3(x, 0.0, z))
			# Height at this corner: the top where the corner is at the high end of the climb
			var t := (Vector2(x, z) - Vector2(lo.x, lo.z)).dot(Vector2(up_dir.x, up_dir.z)) / absf((Vector2(hi.x, hi.z) - Vector2(lo.x, lo.z)).dot(Vector2(up_dir.x, up_dir.z)))
			pts.append(Vector3(x, lerpf(lo.y, hi.y, clampf(t, 0.0, 1.0)), z))
	var body := StaticBody3D.new()
	body.name = nm
	_own(body, g)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	cs.shape = shape
	_own(cs, body)

## Hand rail: a thin dark bar from `a` to `b` with posts down to the stair line every metre or so.
func _rail(g: Node, nm: String, a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, a.distance_to(b))
	mi.mesh = bm
	mi.material_override = _mat("beam_black", BEAM_BLACK, 0.7)
	mi.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5)
	_own(mi, g)
	var n := int(ceil(a.distance_to(b) / 1.1))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		_box(g, "%sPost%d" % [nm, i], Vector3(p.x - 0.025, p.y - 0.9, p.z - 0.025), Vector3(0.05, 0.9, 0.05), mi.material_override, false)

## Buffer zone between lounge and main room: curtains both ends (open), window wall north with the night and a
## bare tree outside, mirror wall south, four tall tables with two tall stools each, a PAR on a stand.
func _buffer() -> void:
	var g := _group("Buffer")
	var wall := _mat("main_wall", Color("23150f"), 0.85)
	_floor(g, BUFFER, _concrete_mat())
	_ceiling(g, BUFFER)
	# Window wall: glass panels full height with black mullions (photo 15); the sill wall is low
	for i in 5:
		var x := BUFFER.position.x + 0.5 + i * 0.95
		_cut(_ph(g, "window_wall_panel", Vector3(minf(x, BUFFER.end.x - 0.5), 0, BUFFER.position.y - 0.05), 0.0, "Window%d" % i, false), Vector3.FORWARD)
	_box(g, "WindowSill", Vector3(BUFFER.position.x, 0, BUFFER.position.y - 0.2), Vector3(BUFFER.size.x, 0.9, 0.2), wall)
	_collider(g, "WindowCollider", Vector3(BUFFER.get_center().x, ROOM_H * 0.5, BUFFER.position.y - 0.1), Vector3(BUFFER.size.x, ROOM_H, 0.2))
	# Mirror wall south (photo 14)
	_wall_x(g, "WallSouth", BUFFER.end.y, BUFFER.position.x, BUFFER.end.x, wall, Vector3.BACK)
	for i in 4:
		_cut(_ph(g, "mirror_wall_panel", Vector3(BUFFER.position.x + 0.6 + i * 1.05, 0.0, BUFFER.end.y - 0.06), 180.0, "Mirror%d" % i, false), Vector3.BACK)
	# Curtains on both openings: panels drawn back to the sides (open all night)
	for z in [BUFFER.position.y + 0.4, BUFFER.end.y - 0.4]:
		for x in [BUFFER.position.x + 0.1, BUFFER.end.x - 0.1]:
			var p := _kit(g, "curtain_panel", Vector3(x, 0, z), 90.0, "Curtain_%d_%d" % [int(x * 10), int(z * 10)])
			_cut(p, Vector3.LEFT if x < 18.0 else Vector3.LEFT)
	_box(g, "ValanceW", Vector3(BUFFER.position.x - 0.1, 3.4, BUFFER.position.y), Vector3(0.12, 0.6, BUFFER.size.y), _mat("velvet_red", VELVET_RED, 0.95), false)
	_box(g, "ValanceE", Vector3(BUFFER.end.x - 0.02, 3.4, BUFFER.position.y), Vector3(0.12, 0.6, BUFFER.size.y), _mat("velvet_red", VELVET_RED, 0.95), false)
	for i in BUFFER_TALL.size():
		var c: Vector2 = BUFFER_TALL[i]
		_tall_table(g, "BufferTall%d" % i, "Buffer", Vector3(c.x, 0, c.y), true)
	_ph(g, "par_on_stand", Vector3(15.9, 0, 7.3), 0.0, "BufferPar")
	_spot(g, "BufferParSpot", NEON_RED, 2.2, 7.0, 40.0, Vector3(15.9, 1.6, 7.3), Vector3(18.0, 0.3, 4.5))
	_omni(g, "BufferCandles", TEALIGHT, 1.4, 4.5, Vector3(17.7, 1.6, 5.3), "tealight")

## Tall square table with two tall stools (east/west, or north/south), candles on top.
func _tall_table(g: Node, nm: String, zone: String, c: Vector3, east_west: bool) -> void:
	_ph(g, "tall_table_square", c, 0.0, nm)
	var top := c + Vector3(0, 1.05, 0)
	_kit(g, "tealight_lantern", top + Vector3(0.1, 0, 0.08), 0.0, nm + "Tealight")
	_kit(g, "beer_glass", top + Vector3(-0.15, 0, -0.1), 0.0, nm + "Glass")
	var offs := [Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0)] if east_west else [Vector3(0, 0, -0.5), Vector3(0, 0, 0.5)]
	for k in 2:
		var off: Vector3 = offs[k]
		var face := rad_to_deg(atan2(-off.x, -off.z))
		_ph(g, "tall_stool", c + off, face, nm + "Stool%d" % k)
		_seat(zone, "%s_%s_S%d" % [zone, nm, k], c + off, face, TALL_SEAT_H, "sit", nm)

func _main_room() -> void:
	var g := _group("MainRoom")
	var wall := _mat("main_wall", Color("23150f"), 0.85)
	_floor(g, Rect2(MAIN_X0, 0.0, MAIN_X1 - MAIN_X0, MAIN_SE_Z))
	_floor(g, Rect2(MAIN_X0, MAIN_SE_Z, BAR_X1 - MAIN_X0, MAIN_Z1 - MAIN_SE_Z), null, 0.0, "FloorSouth")
	_ceiling(g, MAIN)
	_wall_x(g, "WallNorth", 0.0, MAIN_X0 - 0.2, MAIN_X1 + 0.2, wall, Vector3.FORWARD, [Vector2(25.4, 26.4)], 2.15)
	_wall_z(g, "WallEast", MAIN_X1, -0.2, MAIN_SE_Z, wall, Vector3.RIGHT)
	_wall_z(g, "WallWest", MAIN_X0, -0.2, MAIN_Z1, wall, Vector3.LEFT, [Vector2(BUFFER.position.y, BUFFER.end.y)], 3.4)
	# South: behind the bar (z MAIN_Z1) from the bar's west end to the staff area; east of it the wall at MAIN_SE_Z
	_wall_x(g, "WallSouthBar", MAIN_Z1, BAR_X0, BAR_X1 + 0.2, wall, Vector3.BACK)
	_wall_x(g, "WallSouthEast", MAIN_SE_Z, BAR_X1, MAIN_X1 + 0.2, wall, Vector3.BACK, [STAFF_PASS, STAFF_DOOR_BAR, SMOKE_DOOR], 2.2)
	_staff_room(g, wall)
	# Staff door north wall into the backstage, staff door into the walled bar area (both closed)
	_door(g, "StaffDoorBackstage", "staff_door", Vector3(25.9, 0, -0.1), 0.0, Vector3.FORWARD)
	_cut(_kit(g, "exit_sign", Vector3(25.9, 2.5, 0.05), 0.0, "ExitSignStaff"), Vector3.FORWARD)
	# Staff door into the walled bar area: closed to the player (blocker in the opening), staff swing it open
	_swing_door(g, "StaffDoorBar", "staff_door", Vector3((STAFF_DOOR_BAR.x + STAFF_DOOR_BAR.y) * 0.5, 0, MAIN_SE_Z + 0.1), 180.0, Vector3.BACK,
		STAFF_DOOR_BAR.y - STAFF_DOOR_BAR.x, STAFF_USERS, true)
	# Red door to the smoking room: swings open for whoever comes through (front, the red side, faces the main room)
	_swing_door(g, "RedDoor", "red_door", Vector3((SMOKE_DOOR.x + SMOKE_DOOR.y) * 0.5, 0, MAIN_SE_Z + 0.1), 180.0, Vector3.BACK)
	_cut(_kit(g, "exit_sign", Vector3((SMOKE_DOOR.x + SMOKE_DOOR.y) * 0.5, 2.45, MAIN_SE_Z - 0.05), 0.0, "ExitSignSmoke"), Vector3.BACK)
	# South-east corner at floor level: wine fridge, Black Cabin light box over the door (photo 12)
	_ph(g, "wine_fridge", Vector3(41.4, 0, MAIN_SE_Z - 0.35), 0.0, "WineFridge")
	_ph(g, "lightbox_bc", Vector3(41.4, 1.0, MAIN_SE_Z - 0.35), 0.0, "LightboxBC", false)   # sits on the fridge (kit note)
	_omni(g, "LightboxGlow", Color("ffd0b0"), 0.9, 3.5, Vector3(41.0, 1.6, MAIN_SE_Z - 0.9))
	# Vinyl records and a framed picture on the west wall of the strip to the toilets (photo 10)
	for i in 3:
		_cut(_ph(g, "vinyl_record_wall", Vector3(MAIN_X0 + 0.06, 1.3 + (i % 2) * 0.3, 13.0 + i * 0.6), 90.0, "Vinyl%d" % i, false), Vector3.LEFT)
	# Paintings and sconces on the plain north wall west of the stage
	_cut(_kit(g, "painting_b", Vector3(23.0, 1.5, 0.05), 0.0, "PaintingN0"), Vector3.FORWARD)
	for x in [21.2, 26.9]:
		_cut(_kit(g, "wall_lamp", Vector3(x, 1.9, 0.05), 0.0, "Sconce_%d" % int(x * 10)), Vector3.FORWARD)
	# Disco ball over the centre of the floor
	var ball := _kit(g, "disco_ball", Vector3(30.9, ROOM_H, 7.0), 0.0, "DiscoBall")
	ball.set_meta("occluder_center", Vector3(0, -1.2, 0))
	ball.set_meta("occluder_radius", 1.8)
	ball.add_to_group("occluder", true)
	_omni(g, "DiscoGlint", Color("ffe2c0"), 0.6, 3.0, Vector3(30.9, 2.6, 7.0))
	_frame(g)

## Dark wood framing of the main room (renders 05/06): pilasters, cornices, upper walls 4..6 m that fill the frame
## top above the cutaway, soffits over the bar, high exit signs. Each hides with the wall below it.
func _frame(g: Node) -> void:
	var wood := _mat("frame_wood", Color("2a1810"), 0.55)
	var ceil := _mat("ceiling_edge", Color("120a0a"), 0.9)
	for x in [MAIN_X0, 22.0, 24.5, 27.3, 34.2, 37.0, MAIN_X1 - 0.25]:
		_cut(_box(g, "PilasterN_%d" % int(x * 10), Vector3(x, 0, 0.0), Vector3(0.25, ROOM_H, 0.32), wood, false), Vector3.FORWARD)
	_cut(_nocast(_box(g, "CorniceN", Vector3(MAIN_X0, ROOM_H - 0.3, 0.0), Vector3(MAIN_X1 - MAIN_X0, 0.3, 0.3), ceil, false)), Vector3.FORWARD)
	_cut(_nocast(_box(g, "CorniceE", Vector3(MAIN_X1 - 0.6, ROOM_H - 0.3, 0.0), Vector3(0.6, 0.3, MAIN_SE_Z), ceil, false)), Vector3.RIGHT)
	_cut(_nocast(_box(g, "CorniceS", Vector3(BAR_X0, ROOM_H - 0.3, MAIN_Z1 - 0.9), Vector3(BAR_X1 - BAR_X0, 0.3, 0.9), ceil, false)), Vector3.BACK)
	var upper := _bond_mat("upper_brick", Color("2e221e"), 0.05, 0.9, 0.3)
	var uh := 2.0
	_cut(_nocast(_box(g, "UpperN", Vector3(MAIN_X0, ROOM_H, -0.2), Vector3(MAIN_X1 - MAIN_X0, uh, 0.2), upper, false)), Vector3.FORWARD)
	_cut(_nocast(_box(g, "UpperS", Vector3(BAR_X0, ROOM_H, MAIN_Z1), Vector3(BAR_X1 - BAR_X0, uh, 0.2), upper, false)), Vector3.BACK)
	_cut(_nocast(_box(g, "UpperSE", Vector3(BAR_X1, ROOM_H, MAIN_SE_Z), Vector3(MAIN_X1 - BAR_X1, uh, 0.2), upper, false)), Vector3.BACK)
	_cut(_nocast(_box(g, "UpperE", Vector3(MAIN_X1, ROOM_H, -0.2), Vector3(0.2, uh, MAIN_SE_Z + 0.2), upper, false)), Vector3.RIGHT)
	# The west upper wall sits right in front of the floor-zone camera: 1.2 m occluder segments the rig hides on its sight line
	var zw := 0.0
	var k := 0
	while zw < MAIN_Z1 - 0.01:
		var seg := Node3D.new()
		seg.name = "UpperW%d" % k
		seg.position = Vector3(MAIN_X0, ROOM_H + uh * 0.5, zw + 0.6)
		seg.set_meta("occluder_center", Vector3.ZERO)
		seg.set_meta("occluder_radius", 1.3)
		seg.add_to_group("occluder", true)
		_own(seg, g)
		_nocast(_box(seg, "Brick", Vector3(-0.2, -uh * 0.5, -0.6), Vector3(0.2, uh, 1.2), upper, false))
		for i in 4:
			_box(seg, "Joist%d" % i, Vector3(0.0, 0.35 + i * 0.45 - uh * 0.5, -0.6), Vector3(0.06, 0.08, 1.2), wood, false)
		zw += 1.2
		k += 1
	for i in 9:   # peach soffit panels along the top of the bar wall, one per bay
		_cut(_kit(g, "soffit_segment", Vector3(22.55 + i * 1.5, ROOM_H + 1.1, MAIN_Z1 - 0.2), 180.0, "Soffit%d" % i), Vector3.BACK)
	_cut(_kit(g, "exit_sign", Vector3(30.75, ROOM_H + 0.4, 0.05), 0.0, "ExitSignNorthHigh"), Vector3.FORWARD)
	for i in 4:
		var y := ROOM_H + 0.35 + i * 0.45
		_cut(_box(g, "UpperBeamS%d" % i, Vector3(BAR_X0, y, MAIN_Z1 - 0.06), Vector3(BAR_X1 - BAR_X0, 0.08, 0.06), wood, false), Vector3.BACK)
		_cut(_box(g, "UpperBeamN%d" % i, Vector3(MAIN_X0, y, 0.0), Vector3(MAIN_X1 - MAIN_X0, 0.08, 0.06), wood, false), Vector3.FORWARD)
		_cut(_box(g, "UpperBeamE%d" % i, Vector3(MAIN_X1 - 0.06, y, 0.0), Vector3(0.06, 0.08, MAIN_SE_Z), wood, false), Vector3.RIGHT)

## Stage at floor level, mid north wall, marked by red carpet tiles; backstage behind the staff door. Curtains and
## the slatted backdrop on the wall behind it, truss with PARs over it; band spots on the carpet.
func _stage() -> void:
	var g := _group("Stage")
	var carpet := _group("Carpet", g)
	for ix in int(STAGE.size.x):
		for iz in int(ceil(STAGE.size.y)):
			var cz := STAGE.position.y + 0.5 + iz
			if cz + 0.5 > STAGE.end.y + 0.01:
				cz = STAGE.end.y - 0.5
			_kit(carpet, "stage_carpet_tile", Vector3(STAGE.position.x + 0.5 + ix, 0.0, cz), 0.0, "Tile%d_%d" % [ix, iz])
	_shadow_rect(Rect2(STAGE.position.x - 0.05, STAGE.end.y - 0.05, STAGE.size.x + 0.1, 0.25), 0.5)
	# Wall behind: curtains either side, slatted backdrop (lit) behind the drums, lanterns
	var cx := STAGE.get_center().x
	var x := STAGE.position.x + 0.5
	var k := 0
	while x < STAGE.end.x:
		if absf(x - cx) < 1.6:
			_cut(_kit(g, "slatted_backdrop", Vector3(x, 0, 0.1), 0.0, "Backdrop%d" % k), Vector3.FORWARD)
		else:
			_cut(_kit(g, "curtain_panel", Vector3(x, 0, 0.12), 0.0, "CurtainBack%d" % k), Vector3.FORWARD)
		x += 1.0
		k += 1
	for i in 2:
		_cut(_kit(g, "backdrop_lantern", Vector3(cx - 1.0 + i * 2.0, 2.85, 0.25), 0.0, "BackdropLantern%d" % i), Vector3.FORWARD)
	# Backline facing the room (+z): stacks either side of the drums, combo, guitar, three mics, wedges on the
	# front edge, PAs at the front corners
	_kit_solid(g, "amp_stack", Vector3(28.0, 0, 0.35), 0.0, "AmpStackL")
	_kit_solid(g, "amp", Vector3(29.4, 0, 0.5), 0.0, "ComboL")
	_kit_solid(g, "drum_kit", Vector3(30.75, 0, 0.9), 0.0, "DrumKit")
	_kit_solid(g, "amp_stack", Vector3(33.4, 0, 0.35), 0.0, "AmpStackR")
	_kit_solid(g, "amp", Vector3(32.4, 0, 0.6), -20.0, "ComboR")
	_kit_solid(g, "guitar_on_stand", Vector3(27.9, 0, 1.6), 20.0, "Guitar")
	_kit(g, "mic_stand", Vector3(28.9, 0, 3.0), 0.0, "Mic0")
	_kit(g, "mic_stand", Vector3(30.8, 0, 3.1), 0.0, "Mic1")
	_kit(g, "mic_stand", Vector3(32.6, 0, 3.0), 0.0, "Mic2")
	for mx in [28.3, 30.75, 33.2]:
		_kit_solid(g, "monitor_wedge", Vector3(mx, 0, STAGE.end.y - 0.3), 180.0, "Wedge%d" % int(mx))
	_kit(g, "pedalboard", Vector3(28.9, 0, 2.5), 10.0, "PedalboardGtr")
	_kit(g, "pedalboard", Vector3(32.6, 0, 2.55), -12.0, "PedalboardBass")
	var cables := [[Vector3(28.5, 0, 1.0), 70.0], [Vector3(29.0, 0, 2.0), 95.0], [Vector3(30.0, 0, 1.3), 20.0],
		[Vector3(31.6, 0, 1.9), 80.0], [Vector3(32.4, 0, 1.1), 110.0], [Vector3(30.3, 0, 3.0), 0.0]]
	for i in cables.size():
		_kit(g, "cable_run", cables[i][0], cables[i][1], "Cable%d" % i)
	for bx in [28.4, 31.5]:
		_kit(g, "bottle_clear", Vector3(bx, 0, 3.4), 0.0, "StageWater%d" % int(bx))
	_kit_solid(g, "pa_speaker", Vector3(STAGE.position.x - 0.3, 0, STAGE.end.y - 0.3), 0.0, "SpeakerL")
	_kit_solid(g, "pa_speaker", Vector3(STAGE.end.x + 0.3, 0, STAGE.end.y - 0.3), 0.0, "SpeakerR")
	# Band spots: drummer behind the kit, guitarist, singer, bassist
	_seat("Band", "Band_Drums", Vector3(30.75, 0, 0.5), 0.0, 0.45, "band_drums")
	_seat("Band", "Band_Guitar", Vector3(28.9, 0, 2.2), 15.0, 0.0, "band_guitar")
	_seat("Band", "Band_Vocal", Vector3(30.8, 0, 2.4), 0.0, 0.0, "band_vocal")
	_seat("Band", "Band_Bass", Vector3(32.6, 0, 2.2), -15.0, 0.0, "band_bass")
	# Truss with cube PARs along the top of the wall behind the stage, tilted down at the carpet (four pools)
	var truss := _group("Truss", g)
	for i in 3:
		_kit(truss, "truss_segment", Vector3(STAGE.position.x + 1.15 + i * 2.0, ROOM_H, 0.45), 0.0, "Segment%d" % i)
	var pars := [[28.4, "red"], [30.0, "blue"], [31.6, "red"], [33.2, "amber"]]
	var aims := [Vector3(28.6, 0, 2.0), Vector3(30.75, 0.6, 0.8), Vector3(31.4, 0, 2.2), Vector3(33.0, 0, 1.6)]
	var par_col := {"red": NEON_RED, "blue": STAGE_BLUE, "amber": Color("ff7a30")}
	for i in pars.size():
		var par := _kit(truss, "par_light_" + pars[i][1], Vector3(pars[i][0], ROOM_H - 0.5, 0.45), 0.0, "Par%d" % i)
		par.rotation_degrees.x = 40.0
		var src := Vector3(pars[i][0], ROOM_H - 0.75, 0.75)
		var blue: bool = pars[i][1] == "blue"
		_spot(g, "ParSpot%d" % i, par_col[pars[i][1]], 2.4 if blue else 3.4, 7.5, 16.0 if blue else 26.0, src, aims[i])
	# Bare tree to the right of the stage, between stage and raised strip, by the tiny tables (photo 19)
	_kit_solid(g, "stage_tree", Vector3(TREE.x, 0, TREE.y), -90.0, "TreeRightOfStage")
	_omni(g, "TreeLight", Color("ff5a40"), 1.2, 4.0, Vector3(TREE.x, 2.6, TREE.y + 0.8))

## Round table with four chairs (rotation 45 = diamond on the map), lamp, lanterns, glasses. Chairs become seats of `zone`.
func _round_table(g: Node, nm: String, zone: String, c: Vector3, rot: float, lamp: bool, scl := 1.0) -> void:
	if scl == 1.0:
		_kit_solid(g, "round_table", c, 0.0, nm)
	else:
		var t := _kit(g, "round_table", c, 0.0, nm, Vector3(scl, 1.0, scl))
		_collider(t, "Collider", Vector3(0, 0.375, 0), Vector3(0.9, 0.75, 0.9))
		_shadow_spot(c, 0.45 * scl + 0.06)
	var top := c + Vector3(0, 0.75, 0)
	_table_dressing(g, nm, top, lamp, 1 if lamp else 2, 3)
	_kit(g, "menu_card", top + Vector3(-0.24, 0, 0.12), 30.0 + c.x * 7.0, nm + "Menu")
	for k in 4:
		var a := deg_to_rad(rot + k * 90.0)
		var off := Vector3(sin(a) * 0.66 * (0.9 if scl < 1.0 else 1.0), 0, -cos(a) * 0.66 * (0.9 if scl < 1.0 else 1.0))
		var face := rad_to_deg(atan2(-off.x, -off.z))
		_kit_solid(g, "cafe_chair", c + off, face, "%sChair%d" % [nm, k])
		_seat(zone, "%s_%s_C%d" % [zone, nm, k], c + off, face, 0.45, "sit", nm)

## Rectangular four-chair table (the map's rectangles): a communal_table scaled along its length, two chairs a side.
func _rect_table(g: Node, nm: String, zone: String, c: Vector3, length: float) -> void:
	var t := _kit(g, "communal_table", c, 90.0, nm, Vector3(length / 4.0, 1.0, 1.0))
	_collider(t, "Collider", Vector3(0, 0.375, 0), Vector3(4.0, 0.75, 1.0))
	shadow_spots.append([Rect2(c.x - 0.5, c.z - length * 0.5, 1.0, length), 0.0, 0.6])
	var top := c + Vector3(0, 0.75, 0)
	_kit(g, "table_lamp_lit", top + Vector3(0, 0, -length * 0.25), 0.0, nm + "Lamp")
	_kit(g, "tealight_lantern", top + Vector3(0.1, 0, length * 0.25), 0.0, nm + "Tealight")
	for k in 2:
		var z := c.z - length * 0.25 + k * length * 0.5
		_kit(g, "beer_glass", top + Vector3(-0.25, 0, z - c.z), 0.0, nm + "GlassW%d" % k)
		_kit(g, "beer_glass", top + Vector3(0.25, 0, z - c.z + 0.1), 0.0, nm + "GlassE%d" % k)
		_kit_solid(g, "cafe_chair", Vector3(c.x - 0.75, 0, z), 90.0, nm + "ChairW%d" % k)
		_kit_solid(g, "cafe_chair", Vector3(c.x + 0.75, 0, z), -90.0, nm + "ChairE%d" % k)
		_seat(zone, "%s_%s_W%d" % [zone, nm, k], Vector3(c.x - 0.75, 0, z), 90.0, 0.45, "sit", nm)
		_seat(zone, "%s_%s_E%d" % [zone, nm, k], Vector3(c.x + 0.75, 0, z), -90.0, 0.45, "sit", nm)

## Tiny table with two drum stools (map: gold circles): the stools face the stage.
func _tiny_table(g: Node, nm: String, c: Vector3, stools_south: bool) -> void:
	_ph(g, "tiny_table", c, 0.0, nm)
	_kit(g, "tealight_lantern", c + Vector3(0.05, 0.7, 0.0), 0.0, nm + "Tealight")
	_kit(g, "beer_glass", c + Vector3(-0.12, 0.7, 0.1), 0.0, nm + "Glass")
	for k in 2:
		var off := Vector3(-0.32 + k * 0.64, 0, 0.5) if stools_south else Vector3(0.5, 0, -0.32 + k * 0.64)
		var face := 180.0 if stools_south else -90.0   # toward the table and the stage (yaw 0 faces +z, south)
		_kit_solid(g, "drum_stool", c + off, k * 37.0, nm + "Stool%d" % k)
		_seat("Tables", "Tables_%s_S%d" % [nm, k], c + off, face, 0.45, "sit", nm)

func _tables() -> void:
	var g := _group("Tables")
	# West of the stage: two four-chair tables (map: square + circle) and the vertical rectangle
	_round_table(g, "WestTable0", "Tables", Vector3(21.9, 0, 1.2), 0.0, true)
	_round_table(g, "WestTable1", "Tables", Vector3(24.25, 0, 1.2), 0.0, false)
	_rect_table(g, "RectTableW", "Tables", Vector3(24.4, 0, 4.7), 2.4)
	_omni(g, "WestTablesLight", LAMP_GOLD, 2.2, 4.0, Vector3(23.1, 1.8, 1.4))
	_omni(g, "RectWLight", LAMP_GOLD, 1.8, 3.4, Vector3(24.4, 1.8, 4.7))
	# Six tiny tables below the stage, three to its right
	for i in TINY_ROW_X.size():
		_tiny_table(g, "Tiny%d" % i, Vector3(TINY_ROW_X[i], 0, TINY_ROW_Z), true)
	for i in TINY_EAST_Z.size():
		_tiny_table(g, "TinyE%d" % i, Vector3(TINY_EAST_X, 0, TINY_EAST_Z[i]), false)
	_omni(g, "TinyLightA", TEALIGHT, 1.6, 4.2, Vector3(28.7, 1.3, TINY_ROW_Z), "tealight")
	_omni(g, "TinyLightB", TEALIGHT, 1.6, 4.2, Vector3(33.3, 1.3, TINY_ROW_Z + 0.2), "tealight")
	# Row of five four-chair tables; Mali at Table2 (the circle in the middle)
	for n in ROW5.size():
		var t: Array = ROW5[n]
		_round_table(g, "Table%d" % n, "Tables", Vector3(t[0], 0, t[1]), t[2], n % 2 == 0)
	for i in 3:
		_omni(g, "RowLight%d" % i, LAMP_GOLD, 2.2, 4.2, Vector3(25.9 + i * 4.8, 1.9, 8.4))
	# East: the diamond and the vertical rectangle before the raised strip
	_round_table(g, "EastTable", "Tables", Vector3(38.2, 0, 5.85), 45.0, true)
	_rect_table(g, "RectTableE", "Tables", Vector3(38.2, 0, 8.45), 1.9)
	_omni(g, "EastLight", LAMP_GOLD, 2.0, 4.2, Vector3(38.2, 1.9, 7.2))
	# Two tall tables at the main room's west opening, stools north and south
	for i in OPENING_TALL.size():
		var c: Vector2 = OPENING_TALL[i]
		_tall_table(g, "OpeningTall%d" % i, "Buffer", Vector3(c.x, 0, c.y), false)

## Raised +15 cm strip on the east (photos 11, 18): couch along the wall, shelves above, five round tables with a
## chair on the room side, neon strip under the edge, mirror ceiling panels. The navmesh climbs it on hidden ramps.
func _raised() -> void:
	var g := _group("Raised")
	_floor(g, RAISED, _floor_mat(), RAISED_H)
	# Ramps the agent can climb (max climb 0.05 per cell): 0.6 m run along the west edge and the south end
	var run := 0.6
	var hyp := sqrt(run * run + RAISED_H * RAISED_H)
	_collider(g, "RampW", Vector3(RAISED.position.x - run * 0.5, RAISED_H * 0.5 - 0.1, RAISED.get_center().y), Vector3(hyp, 0.2, RAISED.size.y), Vector3(0, 0, atan2(RAISED_H, run)))
	_collider(g, "RampS", Vector3(RAISED.get_center().x, RAISED_H * 0.5 - 0.1, RAISED.end.y + run * 0.5), Vector3(RAISED.size.x, 0.2, hyp), Vector3(atan2(RAISED_H, run), 0, 0))
	# Riser face with the neon strip under the edge (kit raised_edge_neon, 1 x 0.2 x 0.15, front = room side)
	for i in int(ceil(RAISED.size.y)):
		_ph(g, "raised_edge_neon", Vector3(RAISED.position.x - 0.1, 0.0, minf(RAISED.position.y + 0.5 + i, RAISED.end.y - 0.4)), -90.0, "NeonW%d" % i, false)
	for i in 3:
		_ph(g, "raised_edge_neon", Vector3(minf(RAISED.position.x + 0.4 + i * 1.0, MAIN_X1 - 0.5), 0.0, RAISED.end.y + 0.1), 0.0, "NeonS%d" % i, false)
	_omni(g, "NeonEdgeA", NEON_RED, 1.4, 4.5, Vector3(RAISED.position.x - 0.3, 0.2, 2.8))
	_omni(g, "NeonEdgeB", NEON_RED, 1.4, 4.5, Vector3(RAISED.position.x - 0.3, 0.2, 8.2))
	# Couch along the east wall, shelves above it
	for i in int(RAISED.size.y):
		_cut(_ph(g, "couch_long", Vector3(MAIN_X1 - 0.35, RAISED_H, RAISED.position.y + 0.5 + i), -90.0, "Couch%d" % i), Vector3.RIGHT)
	for i in int(RAISED.size.y):
		for r in 2:
			var sh := _cut(_ph(g, "shelf_wall_tile", Vector3(MAIN_X1 - 0.15, RAISED_H + 1.1 + r * 1.0, RAISED.position.y + 0.5 + i), -90.0, "Shelf%d_%d" % [i, r], false), Vector3.RIGHT)
			sh.add_to_group("look_shelf_dull", true)
	# Pink-red strip along the top of the shelf wall (photo 11), and a few shelf backs lit from behind
	_cut(_box(g, "ShelfNeon", Vector3(MAIN_X1 - 0.32, RAISED_H + 3.12, RAISED.position.y), Vector3(0.04, 0.04, RAISED.size.y), _mat("shelf_neon", Color("ff2a5a"), 0.5, 2.6), false), Vector3.RIGHT)
	for z in [1.6, 4.4, 7.9]:
		_cut(_box(g, "ShelfBacklight_%d" % int(z * 10), Vector3(MAIN_X1 - 0.06, RAISED_H + 2.2, z), Vector3(0.03, 0.7, 0.8), _mat("shelf_backlight", Color("c8284a"), 0.6, 1.4), false), Vector3.RIGHT)
	for i in RAISED_TABLES_Z.size():
		var c := Vector3(RAISED_TABLE_X, RAISED_H, RAISED_TABLES_Z[i])
		var t := _kit(g, "round_table", c, 0.0, "Raised%d" % i, Vector3(0.8, 1.0, 0.8))
		_collider(t, "Collider", Vector3(0, 0.375, 0), Vector3(0.9, 0.75, 0.9))
		_table_dressing(g, "Raised%d" % i, c + Vector3(0, 0.75, 0), i % 2 == 0, 1, 2)
		_kit_solid(g, "cafe_chair", c + Vector3(-0.6, 0, 0), 90.0, "Raised%dChair" % i)   # west of the table, facing east
		_seat("Raised", "Raised_T%d_C" % i, c + Vector3(-0.6, 0, 0), 90.0, 0.45, "sit", "Raised%d" % i)
		for k in 2:
			# On the couch, backs to the wall, facing west across the table (yaw -90; +90 faced the couch back)
			_seat("Raised", "Raised_T%d_S%d" % [i, k], Vector3(MAIN_X1 - 0.45, RAISED_H, c.z - 0.35 + k * 0.7), -90.0, 0.45, "sit", "Raised%d" % i, true)
	_omni(g, "RaisedLightA", LAMP_GOLD, 2.0, 4.0, Vector3(RAISED_TABLE_X, 1.9, 2.2))
	_omni(g, "RaisedLightB", LAMP_GOLD, 2.0, 4.0, Vector3(RAISED_TABLE_X, 1.9, 7.9))
	# Mirror ceiling panels over the strip (photo 11): glossy dark tiles on the ceiling layer
	var mirror := _mat("mirror_ceiling", Color("3a3c44"), 0.05)
	mirror.metallic = 0.9
	mirror.metallic_specular = 1.0
	var cg := _group("MirrorCeiling", g)
	for i in int(RAISED.size.y):
		_nocast(_box(cg, "Mirror%d" % i, Vector3(RAISED.position.x, ROOM_H - 0.03, RAISED.position.y + i), Vector3(RAISED.size.x, 0.03, 0.95), mirror, false, CEILING_LAYER))
	_ceiling_group(cg)

## The bar on the south wall (photos 09, 16): counter with the cashier bump, two stool groups, red-lit back bar bays,
## reindeer head over the cashier, bartender spot, walled staff area east (closed, staff spawn).
func _bar() -> void:
	var g := _group("Bar")
	var bay_z := MAIN_Z1 - 0.25
	for i in 9:
		var kname := "back_bar_art" if i == 4 else "back_bar_shelf"
		_kit(g, kname, Vector3(22.55 + i * 1.5, 0, bay_z), 180.0, "Bay%d" % i).add_to_group("look_red_bar", true)
	_collider(g, "BackBarCollider", Vector3((BAR_X0 + BAR_X1) * 0.5, 1.8, MAIN_Z1 - 0.25), Vector3(BAR_X1 - BAR_X0, 3.6, 0.5))
	var cz := 13.0   # counter centre line (0.65 deep)
	for i in 14:
		_kit(g, "bar_counter", Vector3(BAR_X0 + 0.5 + i, 0, cz), 180.0, "Counter%d" % i)
	_collider(g, "CounterCollider", Vector3((BAR_X0 + BAR_X1) * 0.5, 0.55, cz + 0.05), Vector3(BAR_X1 - BAR_X0, 1.1, 0.7))
	_collider(g, "BarFloorBlock", Vector3((BAR_X0 + BAR_X1) * 0.5, 0.55, 14.2), Vector3(BAR_X1 - BAR_X0, 1.1, 1.6))   # staff side closed to the player
	_shadow_rect(Rect2(BAR_X0, cz - 0.45, BAR_X1 - BAR_X0, 0.3))
	# Cashier bump north out of the counter, reindeer head on the back wall above it
	_ph(g, "cashier_counter", Vector3(CASHIER_X, 0, 12.35), 180.0, "Cashier")   # its back (-z) joins the counter
	_cut(_ph(g, "reindeer_head", Vector3(CASHIER_X, 1.7, MAIN_Z1 - 0.35), 0.0, "ReindeerHead", false), Vector3.BACK)
	_omni(g, "CashierLight", Color("ffd0a0"), 1.2, 3.2, Vector3(CASHIER_X, 2.0, 13.3))
	for i in COUNTER_STOOLS_X.size():
		var x: float = COUNTER_STOOLS_X[i]
		_kit_solid(g, "bar_stool", Vector3(x, 0, COUNTER_STOOL_Z), 0.0, "Stool%d" % i)
		_seat("Bar", "Bar_Stool%d" % i, Vector3(x, 0, COUNTER_STOOL_Z), 0.0, BAR_SEAT_H, "sit", "Bar")
	_seat("Bar", "Bar_Bartender", Vector3(CASHIER_X, 0, 13.9), 180.0, 0.0, "staff")
	# Red-lit back bar (photos 09, 16): red LED strips under the soffit and along the top of the cabinets (emissive
	# boxes, no lights), the cubbies and bottles recoloured red at load (scenes/venue/venue_looks.gd), dark joinery
	var led := _mat("bar_led_strip", BAR_RED, 0.5, 3.2)
	for y in [2.35, 3.55]:
		_cut(_box(g, "RedLED_%d" % int(y * 100), Vector3(BAR_X0, y, MAIN_Z1 - 0.52), Vector3(BAR_X1 - BAR_X0, 0.04, 0.04), led, false), Vector3.BACK)
	# Three red omnis behind the counter
	for i in 3:
		_omni(g, "BackBarRed%d" % i, BAR_RED, 1.6, 4.5, Vector3(24.5 + i * 5.2, 2.0, MAIN_Z1 - 0.8))
	# Counter dressing: lamps, lanterns, glasses, napkins, bottles
	var top := 1.1
	var bottles := ["bottle_amber", "bottle_green", "bottle_clear"]
	for i in 4:
		var x := BAR_X0 + 1.5 + i * 3.4
		_kit(g, "table_lamp_lit", Vector3(x, top, cz + 0.08), 0.0, "CounterLamp%d" % i)
		_kit(g, "napkin_cup", Vector3(x + 0.4, top, cz + 0.15), 0.0, "CounterNapkins%d" % i)
		_kit(g, "tealight_lantern", Vector3(x + 1.5, top, cz - 0.1), 0.0, "CounterTealight%d" % i)
	_omni(g, "CounterLightW", LAMP_GOLD, 1.0, 4.0, Vector3(25.5, 1.9, cz - 0.4))
	_omni(g, "CounterLightE", LAMP_GOLD, 1.0, 4.0, Vector3(33.0, 1.9, cz - 0.4))
	for i in 18:
		_kit(g, bottles[i % 3], Vector3(BAR_X0 + 0.3 + i * 0.77, top, cz + 0.22 + (i % 2) * 0.06), 0.0, "CounterBottle%d" % i)
	for i in 10:
		_kit(g, "beer_glass", Vector3(BAR_X0 + 0.55 + i * 1.38, top, cz - 0.22), 0.0, "CounterGlass%d" % i)
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 40:
		var bx := BAR_X0 + 0.25 + i * 0.34
		if absf(bx - CASHIER_X) < 0.8:
			continue   # bartender lane behind the cashier stays clear
		_kit(g, bottles[r.randi() % 3], Vector3(bx, 1.05, MAIN_Z1 - 0.42 - (i % 2) * 0.06), 0.0, "BackBottle%d" % i)

## Vestibule south of the main room's west strip: kitchen curtain west (closed behind), toilet doors east and south,
## a picture light over a framed picture (photo 10). Concrete floor.
func _vestibule() -> void:
	var g := _group("Vestibule")
	var wall := _mat("main_wall", Color("23150f"), 0.85)
	_floor(g, VESTIBULE, _concrete_mat())
	_ceiling(g, VESTIBULE)
	_wall_z(g, "WallWest", VESTIBULE.position.x, VESTIBULE.position.y, VESTIBULE.end.y, wall, Vector3.LEFT, [Vector2(15.1, 16.6)], 2.6)
	_wall_z(g, "WallEast", VESTIBULE.end.x, VESTIBULE.position.y, VESTIBULE.end.y, wall, Vector3.RIGHT, [Vector2(15.15, 16.15)], 2.15)
	_wall_x(g, "WallSouth", VESTIBULE.end.y, VESTIBULE.position.x - 0.2, VESTIBULE.end.x + 0.2, wall, Vector3.BACK, [Vector2(22.65, 23.65)], 2.15)
	# Kitchen curtain (closed to the player: collider), dark kitchen behind
	for z in [15.4, 16.3]:
		_cut(_kit(g, "curtain_panel", Vector3(VESTIBULE.position.x + 0.1, 0, z), 90.0, "KitchenCurtain%d" % int(z * 10)), Vector3.LEFT)
	_collider(g, "KitchenCurtainCollider", Vector3(VESTIBULE.position.x, ROOM_H * 0.5, 15.85), Vector3(0.3, ROOM_H, 1.6))
	_door(g, "ToiletDoorF", "staff_door", Vector3(VESTIBULE.end.x + 0.1, 0, 15.65), -90.0, Vector3.RIGHT)
	_door(g, "ToiletDoorM", "staff_door", Vector3(23.15, 0, VESTIBULE.end.y + 0.1), 180.0, Vector3.BACK)
	_cut(_ph(g, "wall_picture_framed", Vector3(21.6, 1.4, VESTIBULE.end.y - 0.06), 180.0, "CorridorPicture", false), Vector3.BACK)
	_cut(_ph(g, "picture_light", Vector3(21.6, 2.0, VESTIBULE.end.y - 0.12), 180.0, "PictureLight", false), Vector3.BACK)
	_omni(g, "PictureLightOmni", Color("ffd8a8"), 1.1, 3.4, Vector3(21.9, 1.9, VESTIBULE.end.y - 0.45))
	_cut(_kit(g, "exit_sign", Vector3(22.3, 2.6, VESTIBULE.position.y + 0.05), 0.0, "ExitSignToilets"), Vector3.FORWARD)
	_seat("Lobby", "Toilets_Stand0", Vector3(21.2, 0, 15.9), -90.0, 0.0, "stand")

## Smoking room (photos 13, 20, 21): red door in from the main room's SE corner, emergency exit south, glass wall
## east to the night street, dark west wall with pictures, four square tables with wishbone chairs, ashtrays.
func _smoking() -> void:
	var g := _group("Smoking")
	var wall := _mat("smoke_wall", Color("1e1c20"), 0.9)
	var plaster := _mat("smoke_plaster", Color("6e6e6a"), 0.95)   # pale concrete plaster, not beige (photos 20/21)
	_floor(g, SMOKING, _concrete_mat())
	_ceiling(g, SMOKING)
	_wall_z(g, "WallWest", SMOKING.position.x, SMOKING.position.y, SMOKING.end.y, wall, Vector3.LEFT)
	_wall_x(g, "WallSouth", SMOKING.end.y, SMOKING.position.x - 0.2, SMOKING.end.x + 0.2, plaster, Vector3.BACK, [Vector2(39.1, 40.9)], 2.4)
	# Glass wall east: panels over a low sill (photo 20), mullions
	_box(g, "GlassSill", Vector3(SMOKING.end.x, 0, SMOKING.position.y), Vector3(0.2, 0.9, SMOKING.size.y), plaster)
	_collider(g, "GlassCollider", Vector3(SMOKING.end.x + 0.1, ROOM_H * 0.5, SMOKING.get_center().y), Vector3(0.2, ROOM_H, SMOKING.size.y))
	for i in 5:
		_cut(_ph(g, "window_wall_panel", Vector3(SMOKING.end.x + 0.05, 0, minf(SMOKING.position.y + 0.5 + i * 1.0, SMOKING.end.y - 0.5)), -90.0, "SmokeWindow%d" % i, false), Vector3.RIGHT)
	_door(g, "EmergencyExit", "emergency_door", Vector3(40.0, 0, SMOKING.end.y + 0.1), 180.0, Vector3.BACK)
	for i in 3:
		_cut(_ph(g, "wall_picture_framed" if i != 1 else "wall_picture_framed_b", Vector3(SMOKING.position.x + 0.06, 1.4, 13.6 + i * 1.3), 90.0, "SmokePicture%d" % i, false), Vector3.LEFT)
	_cut(_ph(g, "picture_light", Vector3(SMOKING.position.x + 0.12, 2.0, 14.9), 90.0, "SmokePictureLight", false), Vector3.LEFT)
	for i in SMOKE_TABLES.size():
		var c: Vector2 = SMOKE_TABLES[i]
		var p := Vector3(c.x, 0, c.y)
		_ph(g, "smoke_table_square", p, 0.0, "Smoke%d" % i)
		_ph(g, "ashtray", p + Vector3(0.1, 0.75, 0.05), 0.0, "Smoke%dAshtray" % i, false)
		_kit(g, "tealight_lantern", p + Vector3(-0.2, 0.75, -0.15), 0.0, "Smoke%dTealight" % i)
		for k in 2:
			var off := Vector3(0, 0, -0.7 + k * 1.4)
			var face := 0.0 if k == 0 else 180.0   # north chair faces south (+z) to the table, south chair faces north
			_ph(g, "wishbone_chair", p + off, face, "Smoke%dChair%d" % [i, k])
			_seat("Smoking", "Smoking_T%d_C%d" % [i, k], p + off, face, 0.45, "sit", "Smoke%d" % i)
	_ph(g, "air_purifier", Vector3(41.45, 0, 13.1), 0.0, "AirPurifier")
	# Cool blue-white spill from the street through the glass, one small warm bulb by the pictures (photos 20/21)
	_omni(g, "StreetSpill", Color("a8c4e8"), 1.2, 5.0, Vector3(SMOKING.end.x + 0.6, 2.2, 15.4))
	_omni(g, "SmokeBulb", Color("ffc890"), 0.7, 3.0, Vector3(SMOKING.position.x + 0.5, 2.0, 14.9))
	_seat("Smoking", "Smoking_Stand0", Vector3(40.0, 0, 15.3), -90.0, 0.0, "stand")

## Floor under door openings whose rooms' floors stop at the wall faces (Sticker door, smoke-room door): without it
## the 0.2 m gap, eroded by the agent radius, splits the navmesh even though the player can step over it.
func _thresholds() -> void:
	var g := _group("Thresholds")
	for r in [Rect2(STICKER_DOOR.x, LOUNGE.end.y - 0.05, STICKER_DOOR.y - STICKER_DOOR.x, 0.3),
			Rect2(SMOKE_DOOR.x, MAIN_SE_Z - 0.05, SMOKE_DOOR.y - SMOKE_DOOR.x, 0.3)]:
		_box(g, "Sill_%d" % int(r.position.x * 10), Vector3(r.position.x, -0.2, r.position.y), Vector3(r.size.x, 0.2, r.size.y), _concrete_mat())

## Walled bar staff room east of the bar (Daniele, corrections on plan v4): closed, non-walkable (no floor collider, so
## no navmesh), staff spawn inside. Its north wall has the staff door and, right beside it, the half wall for orders:
## a pass-through counter at bar height where waiters return glasses and collect orders; staff show behind it.
func _staff_room(g: Node, wall: Material) -> void:
	var r := Rect2(BAR_X1, MAIN_SE_Z, 38.25 - BAR_X1, MAIN_Z1 - MAIN_SE_Z)
	var fl := _box(g, "StaffRoomFloor", Vector3(r.position.x, -0.2, r.position.y), Vector3(r.size.x, 0.2, r.size.y), _concrete_mat(), false)
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ceiling(g, r, "StaffRoomCeiling")
	_wall_z(g, "StaffRoomWest", BAR_X1, MAIN_SE_Z, MAIN_Z1, wall, Vector3.RIGHT)
	_wall_x(g, "StaffRoomSouth", MAIN_Z1, BAR_X1, r.end.x + 0.05, wall, Vector3.BACK)
	# The east wall is the smoking room's west wall (x 38.3)
	var top := _mat("wood_mid", WOOD_MID, 0.4)
	_box(g, "PassSill", Vector3(STAFF_PASS.x, 0, MAIN_SE_Z), Vector3(STAFF_PASS.y - STAFF_PASS.x, 1.05, 0.2), wall)
	_box(g, "PassTop", Vector3(STAFF_PASS.x - 0.05, 1.05, MAIN_SE_Z - 0.2), Vector3(STAFF_PASS.y - STAFF_PASS.x + 0.1, 0.06, 0.6), top, false)
	for i in 3:
		_kit(g, "beer_glass", Vector3(STAFF_PASS.x + 0.2 + i * 0.25, 1.11, MAIN_SE_Z - 0.05), 0.0, "PassGlass%d" % i)
	_kit(g, "napkin_cup", Vector3(STAFF_PASS.y - 0.15, 1.11, MAIN_SE_Z + 0.05), 0.0, "PassNapkins")
	_box(g, "StaffShelf", Vector3(r.position.x + 0.1, 0, r.end.y - 0.45), Vector3(r.size.x - 0.2, 1.8, 0.4), _mat("stool_black", STOOL_BLACK, 0.85), false)
	_omni(g, "StaffRoomLight", Color("ffd8b0"), 0.9, 3.2, Vector3(r.get_center().x, 2.6, r.get_center().y))

## Closed rooms (green on the map): dark boxes behind their doors so a door never opens onto the void.
func _closed_rooms() -> void:
	var g := _group("ClosedRooms")
	var dark := _mat("closed_room", Color("0e0a0a"), 0.95)
	var rooms := {"Backstage": BACKSTAGE, "Kitchen": Rect2(6.6, 15.0, 13.5, 3.5), "ToiletF": Rect2(24.4, 15.0, 4.5, 2.4),
		"ToiletM": Rect2(20.1, 16.7, 4.25, 1.8), "OldToiletN": Rect2(15.45, 7.65, 4.5, 2.45), "OldToiletS": Rect2(15.45, 12.4, 4.5, 2.5),
	}
	for nm in rooms:
		var r: Rect2 = rooms[nm]
		var mi := _box(g, nm, Vector3(r.position.x, 0, r.position.y), Vector3(r.size.x, ROOM_H, r.size.y), dark, true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cut(mi, Vector3.ZERO)   # never cut by direction; hidden only when it blocks the sight line to the player

## Night outside the windows (Daniele: night only for now): dark pavement, a bare tree north of the buffer zone,
## a faint streetlight, lit windows of the buildings across the street east of the smoking room.
func _outside() -> void:
	var g := _group("Outside")
	var pave := _mat("pavement", Color("16171c"), 0.95)
	var bldg := _mat("building", Color("0c0d12"), 0.95)
	var win := _mat("lit_window", Color("ffd9a0"), 0.6, 1.2)
	# North of the buffer zone
	_box(g, "PaveN", Vector3(15.0, -0.2, -4.5), Vector3(5.6, 0.2, 7.3), pave, false)
	_ph(g, "outdoor_tree_bare", Vector3(TREE_OUTSIDE.x, 0, TREE_OUTSIDE.y), 0.0, "TreeOutside", false)
	_box(g, "BuildingN", Vector3(14.5, 0, -5.0), Vector3(6.5, 7.0, 0.5), bldg, false)
	for i in 3:
		_box(g, "WindowN%d" % i, Vector3(15.5 + i * 1.8, 3.2, -4.52), Vector3(0.8, 1.0, 0.04), win, false)
	_box(g, "LampPost", Vector3(16.1, 0, -2.0), Vector3(0.1, 3.4, 0.1), _mat("beam_black", BEAM_BLACK, 0.7), false)
	_box(g, "LampHead", Vector3(15.95, 3.4, -2.15), Vector3(0.4, 0.15, 0.4), win, false)
	_omni(g, "Streetlight", STREETLIGHT, 1.0, 6.0, Vector3(16.1, 3.2, -2.0))
	# East of the smoking room
	_box(g, "PaveE", Vector3(MAIN_X1 + 0.2, -0.2, 12.0), Vector3(4.5, 0.2, 7.0), pave, false)
	_box(g, "BuildingE", Vector3(MAIN_X1 + 4.5, 0, 11.5), Vector3(0.5, 8.0, 8.0), bldg, false)
	for i in 4:
		_box(g, "WindowE%d" % i, Vector3(MAIN_X1 + 4.48, 1.8 + (i % 2) * 2.2, 12.6 + i * 1.5), Vector3(0.04, 1.0, 0.8), win, false)
	_box(g, "Shrubs", Vector3(MAIN_X1 + 0.6, 0, 13.0), Vector3(1.0, 1.1, 4.0), _mat("shrub", Color("142012"), 0.95), false)

## Contact shadows under the main-room furniture: one alpha texture on one floor quad (Compatibility has no SSAO).
func _shadow_spot(p: Vector3, r: float, strength := 0.75) -> void:
	if p.y < 0.2 and p.x > MAIN_X0 and p.x < MAIN_X1 and p.z > 0.0 and p.z < MAIN_Z1:
		shadow_spots.append([Vector2(p.x, p.z), r, strength])

func _shadow_rect(r: Rect2, strength := 0.7) -> void:
	shadow_spots.append([r, 0.0, strength])

func _contact_shadows() -> void:
	const PPM := 16.0
	var w := int((MAIN_X1 - MAIN_X0) * PPM)
	var h := int(MAIN_Z1 * PPM)
	var alpha := PackedFloat32Array()
	alpha.resize(w * h)
	for s in shadow_spots:
		if s[0] is Rect2:
			var r: Rect2 = s[0]
			for py in range(int(r.position.y * PPM), int(r.end.y * PPM)):
				for px in range(int((r.position.x - MAIN_X0) * PPM), int((r.end.x - MAIN_X0) * PPM)):
					if px >= 0 and py >= 0 and px < w and py < h:
						alpha[py * w + px] = maxf(alpha[py * w + px], s[2])
			continue
		var c: Vector2 = s[0]
		var rad: float = s[1] * 1.25
		var cx := (c.x - MAIN_X0) * PPM
		var cy := c.y * PPM
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
	qm.size = Vector2(MAIN_X1 - MAIN_X0, MAIN_Z1)
	qm.orientation = PlaneMesh.FACE_Y
	var mi := MeshInstance3D.new()
	mi.name = "ContactShadows"
	mi.mesh = qm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3((MAIN_X0 + MAIN_X1) * 0.5, 0.006, MAIN_Z1 * 0.5)
	_own(mi, vroot.get_node("MainRoom"))

## Camera framings, one per zone, read by camera_rig.gd. rect = membership (x, z, w, d); clamp = where the look
## target may go; yaw 0 looks north (-z), -90 looks east, 90 west, 180 south. "fallback" covers the main room.
## The lobby reaches out over the step of street beyond the street door. The old-corridor alcove off the lounge has its
## own framing, looking south into it over the old toilets' closed box (hidden on the sight line).
func _camera_zones() -> void:
	var g := _group("CameraZones")
	var zones := [
		{"name": "lobby", "rect": Rect2(-2.0, 5.05, 4.15, 8.2), "clamp": Rect2(1.1, 7.0, 0.1, 5.0), "yaw": 0.0, "pitch": -36.0, "dist": 6.5, "look_y": 1.2},
		{"name": "corridor", "rect": Rect2(-0.2, 13.25, 15.65, 1.65), "clamp": Rect2(3.5, 13.6, 9.5, 0.1), "yaw": 0.0, "pitch": -42.0, "dist": 7.0, "look_y": 1.0},
		{"name": "buffer", "rect": Rect2(BUFFER.position.x, BUFFER.position.y, BUFFER.size.x, BUFFER.size.y), "clamp": Rect2(17.7, 4.6, 0.3, 1.5), "yaw": 0.0, "pitch": -32.0, "dist": 7.0, "look_y": 1.3},
		{"name": "alcove", "rect": Rect2(STUB.position.x, STUB.position.y, STUB.size.x, STUB.size.y), "clamp": Rect2(16.4, 11.3, 2.2, 0.1), "yaw": 180.0, "pitch": -48.0, "dist": 5.5, "look_y": 1.0},
		{"name": "lounge", "rect": Rect2(LOUNGE.position.x, LOUNGE.position.y, LOUNGE.size.x, LOUNGE.size.y), "clamp": Rect2(5.0, 2.8, 5.0, 7.5), "yaw": 90.0, "pitch": -34.0, "dist": 8.0, "look_y": 1.3},
		{"name": "bar", "rect": Rect2(BAR_X0, 9.6, BAR_X1 - BAR_X0, MAIN_Z1 - 9.6), "clamp": Rect2(23.5, 10.6, 10.5, 0.6), "yaw": 180.0, "pitch": -32.0, "dist": 7.0, "look_y": 1.0},
		{"name": "stage", "rect": Rect2(26.4, 0.0, 9.6, 6.6), "clamp": Rect2(29.0, 1.6, 3.5, 0.6), "yaw": 0.0, "pitch": -26.0, "dist": 7.5, "look_y": 1.4},
		{"name": "toilets", "rect": Rect2(MAIN_X0, 12.0, BAR_X0 - MAIN_X0 + 2.6, 4.7), "clamp": Rect2(21.0, 13.5, 0.6, 2.0), "yaw": 180.0, "pitch": -34.0, "dist": 6.0, "look_y": 1.2},
		{"name": "smoking", "rect": Rect2(SMOKING.position.x, MAIN_SE_Z, SMOKING.size.x, SMOKING.end.y - MAIN_SE_Z), "clamp": Rect2(40.0, 14.2, 0.1, 2.0), "yaw": 180.0, "pitch": -34.0, "dist": 6.0, "look_y": 1.2},
		{"name": "floor", "rect": Rect2(MAIN_X0, 0.0, MAIN_X1 - MAIN_X0, MAIN_Z1), "clamp": Rect2(23.5, 4.0, 15.0, 5.0), "yaw": -90.0, "pitch": -30.0, "dist": 8.5, "look_y": 0.9, "fallback": true},
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

## Velvet banquette along a west wall at x0 from z0 to z1 (seat 0.6 deep, facing east).
func _banquette(parent: Node, nm: String, x0: float, z0: float, z1: float) -> void:
	if kit.has("banquette_straight"):
		var w: float = kit.banquette_straight.footprint_m[0]
		var count := int(round((z1 - z0) / w))
		for i in count:
			_kit(parent, "banquette_straight", Vector3(x0 + kit.banquette_straight.footprint_m[1] * 0.5, 0, z0 + w * (i + 0.5)), 90.0, "%s%d" % [nm, i])
	else:
		var b := _group(nm, parent)
		_box(b, "Seat", Vector3(x0, 0, z0), Vector3(0.6, 0.45, z1 - z0), _mat("velvet_red", VELVET_RED, 0.95), false)
		_box(b, "Back", Vector3(x0, 0.45, z0), Vector3(0.18, 0.5, z1 - z0), _mat("velvet_shadow", VELVET_SHADOW, 0.95), false)
	_collider(parent, nm + "Collider", Vector3(x0 + 0.3, 0.45, (z0 + z1) * 0.5), Vector3(0.6, 0.9, z1 - z0))

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
	root.add_child(vroot)
	region.bake_navigation_mesh(false)
	root.remove_child(vroot)
	print("navmesh polygons: ", nm.get_polygon_count())
