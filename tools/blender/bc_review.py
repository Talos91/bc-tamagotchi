"""Black Cabin Tamagotchi - one review file with everything built so far.

Writes blender/BlackCabin.blend: one scene, three areas, each in its own top-level collection so it can be toggled:
  VENUE       the assembled room: kit instances and spawn spots from game/assets/kit/layout.json when it exists
              (otherwise from game/scenes/venue/venue.tscn), greybox boxes and lights always parsed from
              venue.tscn (layout.json does not carry them), with
              character presets placed in it: bartender behind the bar, the House Lights on stage, regulars and
              patrons seated, the player figure walking in the lounge
  KIT         the kit grid, built by bc_kit.build_review (imported, not copied)
  CHARACTERS  the preset rows, animation row and parts lineup, built by bc_chars.review_content
plus a camera per area and one overview (the active camera), and renders docs/art/review-overview.png.

Run from the repo root after any kit or character change (about 2 minutes):
    blender --background --factory-startup --python tools/blender/bc_review.py
    blender --background --factory-startup --python tools/blender/bc_review.py -- --no-render
bc_chars.py runs it at the end of every full run; bc_kit.py does not (its owner can add the call), so after a kit
change run the command above.

Coordinates: Godot (x, y up, z) -> Blender (x, -z, y), the same mapping the glTF exporter uses, so kit meshes built
here sit exactly where their GLBs sit in Godot.
"""
import json
import math
import os
import re
import sys
import tempfile

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.path.join(os.getcwd(), "tools", "blender")
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import bc_kit as K                                                   # noqa: E402
import bc_chars as B                                                 # noqa: E402

BLEND = os.path.join(K.REPO, "blender", "BlackCabin.blend")
STILL = os.path.join(K.REPO, "docs", "art", "review-overview.png")
LAYOUT = os.path.join(K.REPO, "game", "assets", "kit", "layout.json")
VENUE_TSCN = os.path.join(K.REPO, "game", "scenes", "venue", "venue.tscn")
# Venue on top (Blender x 0..30, y -10..0); kit grid and character lineup side by side in front of it. Both grids
# grow toward +Y from their offset.
KIT_OFFSET = Vector((5.0, -31.0, 0.0))
CHARS_OFFSET = Vector((22.0, -33.0, 0.0))
CEILING_OBJECTS = {"beam_segment", "ceiling_panel"}   # go with the ceiling into the hidden cutaway collection
POSE_FRAME = 12
P = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))          # Godot axes -> Blender axes

# Who sits where in the venue: (preset, spot marker or stage anchor, animation)
CAST = [
    ("nam", "Bar_Bartender", "idle"),
    ("hiro", "Bar_Stool3", "sit"), ("dougie", "Bar_Stool7", "sit"), ("patron_06", "Bar_Stool1", "sit"),
    ("ploy", "Tables_T1_C2", "sit"), ("patron_02", "Tables_T0_C0", "sit"), ("patron_09", "Tables_T0_C1", "sit"),
    ("patron_05", "Tables_T3_C2", "sit"), ("patron_11", "Tables_T4_C0", "sit"),
    ("tong", "Tables_DrumStool1", "sit"), ("patron_03", "CommunalTable_T0_N1", "sit"),
    ("patron_08", "CommunalTable_T1_S0", "sit"), ("mali", "CommunalTable_T0_S2", "sit"),
    ("bow", "Wander_StageFront", "dance"), ("jules", "Wander_Arcade", "idle_warm"),
    ("player", "Wander_Lounge", "walk"),
    ("jo", "@Mic1", "idle_warm"), ("pete", "@Mic0", "idle"), ("boy", "@DrumKit", "sit"),
]
PLAYER = B.P("player", "Player", "player", "PLAYER", "regular", "soft", "bob", ("wide", "flat", "smile"),
             "hoodie", "jeans", "sneakers", ["drink_beer"],
             skin="Skin3", hair="HairAuburn", top="Sky", top_trim="Cream", bottom="Denim", shoes="ColumnWhite",
             shoes_trim="Stone")


# ------------------------------------------------------------------ venue.tscn parsing

def _floats(s):
    if "(" in s:
        s = s[s.index("(") + 1:]                                     # skip the type name: the 3 in Vector3(
    return [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?(?:e-?\d+)?", s)]


def godot_matrix(vals):
    """Transform3D(12 floats, basis row-major then origin) -> 4x4 Blender world matrix."""
    b = Matrix(((vals[0], vals[1], vals[2]), (vals[3], vals[4], vals[5]), (vals[6], vals[7], vals[8])))
    m = (P @ b @ P.transposed()).to_4x4()
    m.translation = P @ Vector(vals[9:12])
    return m


def parse_tscn(path):
    """Minimal .tscn reader: ext/sub resources and nodes with their properties and world matrices."""
    ext, sub, nodes = {}, {}, []
    cur = None
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("[ext_resource"):
                rid = re.search(r'id="([^"]+)"', line).group(1)
                ext[rid] = re.search(r'path="([^"]+)"', line).group(1)
                cur = None
            elif line.startswith("[sub_resource"):
                cur = {"_type": re.search(r'type="([^"]+)"', line).group(1)}
                sub[re.search(r'id="([^"]+)"', line).group(1)] = cur
            elif line.startswith("[node"):
                cur = {"_name": re.search(r'name="([^"]+)"', line).group(1),
                       "_type": (re.search(r'type="([^"]+)"', line) or [None, None])[1],
                       "_parent": (re.search(r'parent="([^"]*)"', line) or [None, None])[1],
                       "_groups": re.search(r'groups=\[([^\]]*)\]', line).group(1) if "groups=" in line else "",
                       "_instance": (re.search(r'instance=ExtResource\("([^"]+)"\)', line) or [None, None])[1]}
                nodes.append(cur)
            elif line.startswith("["):
                cur = None
            elif cur is not None and " = " in line:
                k, v = line.split(" = ", 1)
                cur[k.strip()] = v.strip()
    world = {}
    for n in nodes:
        par = n["_parent"]
        path_ = "" if par is None else (n["_name"] if par == "." else par + "/" + n["_name"])
        n["_path"] = path_
        local = godot_matrix(_floats(n["transform"])) if "transform" in n else Matrix.Identity(4)
        parent_m = Matrix.Identity(4) if par in (None, ".") else world.get(par, Matrix.Identity(4))
        n["_world"] = (parent_m @ local) if par is not None else Matrix.Identity(4)
        world[path_] = n["_world"]
    hidden = set()
    for n in nodes:                                                  # hidden parents hide their subtree
        if n.get("visible") == "false" or (n["_parent"] not in (None, ".") and n["_parent"] in hidden):
            hidden.add(n["_path"])
        n["_visible"] = n["_path"] not in hidden
    return ext, sub, nodes


def _color(s, default=(0.5, 0.5, 0.5)):
    v = _floats(s) if s else []
    return tuple(v[:3]) if len(v) >= 3 else default


_GMATS = {}


def godot_material(sub, rid):
    """A StandardMaterial3D sub-resource -> Blender material (sRGB albedo, emission). FloorTile -> kit FloorGrey."""
    if rid in _GMATS:
        return _GMATS[rid]
    r = sub.get(rid, {})
    name = r.get("resource_name", '"%s"' % rid).strip('"')
    if name == "FloorTile":
        m = K.material("FloorGrey")
    else:
        m = bpy.data.materials.new("venue_" + name)
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        col = tuple(K.srgb_to_linear(c) for c in _color(r.get("albedo_color"), (0.8, 0.8, 0.8)))
        bsdf.inputs["Base Color"].default_value = (*col, 1.0)
        bsdf.inputs["Roughness"].default_value = float(r.get("roughness", 0.8))
        bsdf.inputs["Metallic"].default_value = float(r.get("metallic", 0.0))
        m.diffuse_color = (*col, 1.0)
        if r.get("emission_enabled") == "true":
            ecol = tuple(K.srgb_to_linear(c) for c in _color(r.get("emission"), (1, 1, 1)))
            bsdf.inputs["Emission Color"].default_value = (*ecol, 1.0)
            bsdf.inputs["Emission Strength"].default_value = float(r.get("emission_energy_multiplier", 1.0)) * 2.0
    _GMATS[rid] = m
    return m


def box_mesh(name, size):
    sx, sy, sz = size[0] / 2, size[2] / 2, size[1] / 2                # Godot (x, y, z) size -> Blender (x, z, y)
    v = [(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(v, [], f)
    me.update()
    return me


# ------------------------------------------------------------------ areas

def top_collection(scene, name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c


def label(coll, name, body, loc, size, mat, align="CENTER"):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = align
    cu.materials.append(mat)
    ob = bpy.data.objects.new(name, cu)
    ob.location = loc
    coll.objects.link(ob)
    return ob


def build_kit_objects():
    """Every bc_kit object meshed once (no export); also returns the manifest-shaped dicts build_review wants."""
    objects, manifest = {}, []
    for name, zone, size_class, anchor, fn, *extra in K.KIT:
        v = K.Vox()
        fn(v)
        ob, st = K.build_mesh(name, v, anchor)
        objects[name] = ob
        sx, sy, sz = st["size_vox"]
        manifest.append({"name": name, "zone": zone, "anchor": anchor,
                         "footprint_m": [sx * K.VOX, sy * K.VOX], "height_m": sz * K.VOX})
    return objects, manifest


def kit_area(scene, objects, manifest, parent):
    """bc_kit.build_review lays out the grid (and saves a throwaway copy); keep its zones, floor, pools and camera,
    drop its suns (the combined scene has its own), and move it all to KIT_OFFSET."""
    before = set(bpy.data.collections)
    tmp = os.path.join(tempfile.gettempdir(), "bc_review_kit_tmp.blend")
    K.build_review(objects, manifest, path=tmp)
    for p in (tmp, tmp + "1"):
        if os.path.exists(p):
            os.remove(p)
    cam = None
    for c in [c for c in bpy.data.collections if c not in before]:
        scene.collection.children.unlink(c)
        parent.children.link(c)
        c.name = "kit " + c.name
        for ob in list(c.objects):
            if ob.type == "LIGHT" and ob.data.type == "SUN":
                bpy.data.objects.remove(ob)
                continue
            if ob.parent is None:
                ob.location = ob.location + KIT_OFFSET
            if ob.type == "CAMERA":
                cam = ob
    cam.name = "Cam_KIT"
    return cam


def chars_area(scene, lab, parent):
    before = set(bpy.data.collections)
    depth, widest = B.review_content(scene, lab)
    for c in [c for c in bpy.data.collections if c not in before]:
        if c.name in scene.collection.children:
            scene.collection.children.unlink(c)
            parent.children.link(c)
        for ob in c.objects:
            if ob.parent is None:
                ob.location = ob.location + CHARS_OFFSET
    me = bpy.data.meshes.new("chars_floor")
    hx, hy = widest / 2 + 4.0, depth / 2 + 1.5
    me.from_pydata([(-hx, -hy, 0), (hx, -hy, 0), (hx, hy, 0), (-hx, hy, 0)], [], [(0, 1, 2, 3)])
    me.materials.append(K.material("FloorGrey"))
    fl = bpy.data.objects.new("chars_floor", me)
    fl.location = CHARS_OFFSET + Vector((0, depth / 2 - 0.8, -0.001))
    parent.objects.link(fl)
    aim = CHARS_OFFSET + Vector((0, depth * 0.4, 0.4))
    cam = camera(parent, "Cam_CHARACTERS", aim, max(widest * 0.85, depth * 1.2), 38, 35)
    for i in range(4):
        K.review_light(parent, "chars_pool%d" % i, "POINT", CHARS_OFFSET + Vector(((i - 1.5) * widest / 3.5, 1.6, 3.0)),
                       500.0, (1.0, 0.72, 0.45), size=0.6)
    return cam, depth, widest


def camera(coll, name, aim, dist, elev_deg, lens, yaw_deg=0.0):
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    cam.data.lens = lens
    cam.data.clip_end = 1000.0
    e, y = math.radians(elev_deg), math.radians(yaw_deg)
    cam.location = aim + Vector((dist * math.cos(e) * math.sin(y), -dist * math.cos(e) * math.cos(y), dist * math.sin(e)))
    cam.rotation_euler = (aim - cam.location).to_track_quat("-Z", "Y").to_euler()
    coll.objects.link(cam)
    return cam


def zone_collection(coll, subs, zone):
    if zone not in subs:
        subs[zone] = bpy.data.collections.new("venue " + zone)
        coll.children.link(subs[zone])
    return subs[zone]


def venue_from_layout(objects, coll, subs, cut):
    """Kit instances and spawn spots from layout.json (Godot axes, metres, rotation_y in degrees)."""
    with open(LAYOUT, encoding="utf-8") as f:
        data = json.load(f)
    anchors, spots, n = {}, {}, 0
    for it in data["kit"]:
        sx, sy, sz = it.get("scale", (1, 1, 1))
        turn = Matrix.Rotation(math.radians(it.get("rotation_y", 0.0)), 4, "Z")      # Godot +Y turn = Blender +Z
        m = Matrix.Translation(P @ Vector(it["position"])) @ turn @ Matrix.Diagonal((sx, sz, sy, 1.0))
        anchors[it["name"]] = m
        src = objects.get(it["object"])
        if src is None:
            print("BC_REVIEW layout: unknown kit object", it["object"])
            continue
        ob = bpy.data.objects.new("venue." + it["name"], src.data)
        ob.matrix_world = m
        (cut if it["object"] in CEILING_OBJECTS else zone_collection(coll, subs, it.get("zone", "Venue"))).objects.link(ob)
        n += 1
    for sp in data.get("spawns", []):
        m = Matrix.Translation(P @ Vector(sp["position"])) @ Matrix.Rotation(math.radians(sp.get("rotation_y", 0.0)), 4, "Z")
        spots[sp["spot"]] = (m, float(sp.get("seat_h", 0.0)) or B.SEAT_VOX * B.VOX)
    return n, spots, anchors


def venue_from_tscn(objects, coll, cut, sub_collections, instances=True):
    """Kit instances (linked duplicates of the KIT meshes), greybox boxes, lights, and the Marker3D spots.
    With instances=False only the greybox and the lights (layout.json carries the rest)."""
    ext, sub, nodes = parse_tscn(VENUE_TSCN)
    spots, anchors, counts = {}, {}, {"kit": 0, "box": 0, "light": 0}
    meshes = {}
    for n in nodes:
        if not n["_visible"]:
            continue
        if n["_instance"] and not instances:
            continue
        if n["_instance"]:
            path = ext.get(n["_instance"], "")
            name = os.path.splitext(os.path.basename(path))[0]
            anchors[n["_name"]] = n["_world"]
            src = objects.get(name)
            if src is None:
                continue
            target = cut if name in CEILING_OBJECTS else zone_collection(coll, sub_collections, n["_path"].split("/")[0])
            ob = bpy.data.objects.new("venue." + n["_path"].replace("/", "."), src.data)
            ob.matrix_world = n["_world"]
            target.objects.link(ob)
            counts["kit"] += 1
        elif n["_type"] == "MeshInstance3D" and "mesh" in n:
            rid = re.search(r'SubResource\("([^"]+)"\)', n["mesh"])
            res = sub.get(rid.group(1)) if rid else None
            if not res or res["_type"] != "BoxMesh":
                continue
            size = tuple(_floats(res.get("size", "Vector3(1, 1, 1)")))
            if size not in meshes:
                meshes[size] = box_mesh("venue_box_%gx%gx%g" % size, size)
            mrid = re.search(r'SubResource\("([^"]+)"\)', n.get("material_override", n.get("surface_material_override/0", "")))
            ob = bpy.data.objects.new("venue." + n["_path"].replace("/", "."), meshes[size])
            ob.matrix_world = n["_world"]
            if mrid:
                ob.material_slots and None
                ob.data = ob.data if ob.data.materials else ob.data
                ob.active_material = None
                ob.data = meshes[size]
                slot_mat = godot_material(sub, mrid.group(1))
                if not ob.material_slots:
                    ob.data.materials.append(None) if not ob.data.materials else None
                ob.material_slots[0].link = "OBJECT"
                ob.material_slots[0].material = slot_mat
            groups = n["_groups"]
            cutaway = '"ceiling"' in groups or ('"cutaway"' in groups and _south_facing(n))
            (cut if cutaway else coll).objects.link(ob)
            counts["box"] += 1
        elif n["_type"] in ("OmniLight3D", "SpotLight3D"):
            col = _color(n.get("light_color"), (1, 1, 1))
            energy = float(n.get("light_energy", 1.0))
            rng = float(n.get("omni_range", n.get("spot_range", 5.0)))
            kind = "POINT" if n["_type"] == "OmniLight3D" else "SPOT"
            ld = bpy.data.lights.new("venue." + n["_name"], kind)
            ld.color = col
            ld.energy = energy * rng * rng * (6.0 if kind == "POINT" else 14.0)
            ld.shadow_soft_size = 0.15
            ld.use_shadow = kind == "SPOT"                           # 23 shadowed lamps overflow EEVEE's shadow pool
            if kind == "SPOT":
                ld.spot_size = math.radians(2 * float(n.get("spot_angle", 45.0)))
                ld.spot_blend = 0.4
            lo = bpy.data.objects.new("venue." + n["_name"], ld)
            lo.matrix_world = n["_world"]          # Godot lights shine down -Z local; P maps that to Blender -Z local
            coll.objects.link(lo)
            counts["light"] += 1
        elif n["_type"] == "Marker3D" and n["_parent"] == "Patrons/Spots":
            spots[n["_name"]] = (n["_world"], float(n.get("metadata/seat_h", B.SEAT_VOX * B.VOX)))
    return counts, spots, anchors


def _south_facing(n):
    """Cutaway walls whose outward normal points at the overview/venue cameras (Godot +Z or -X side)."""
    v = _floats(n.get("metadata/cut_normal", "Vector3(0, 0, 0)"))
    return len(v) == 3 and (v[2] > 0.5 or v[0] < -0.5)


def place_cast(coll, spots, anchors):
    """Presets into the room. Seated spots lift the root by seat_h - 0.45 m (as venue_patrons.gd does)."""
    acts, placed = {}, 0
    specs = {p["name"]: p for p in B.PRESETS}
    specs["player"] = PLAYER
    for name, where, anim in CAST:
        spec = specs[name]
        if where.startswith("@"):
            m = anchors.get(where[1:])
            if m is None:
                continue
            fwd = (m.to_3x3() @ Vector((0, -1, 0))).normalized()     # kit front is -Y in Blender
            back = {"@DrumKit": 0.75, "@Mic0": 0.35, "@Mic1": 0.35}[where]
            mw = m.copy()
            mw.translation = m.translation - fwd * back
            if where == "@DrumKit":                                  # Boy sits on a drum stool behind the kit
                st = bpy.data.objects.get("drum_stool")
                if st:
                    s = bpy.data.objects.new("venue.drum_throne", st.data)
                    s.matrix_world = mw
                    coll.objects.link(s)
        else:
            if where not in spots:
                continue
            mw, seat_h = spots[where]
            mw = mw.copy()
            if anim == "sit":
                mw.translation.z += seat_h - B.SEAT_VOX * B.VOX
        arm, _, _, _, _ = B.build_character(spec, coll, prefix="venue_%s." % name, with_actions=False)
        arm.matrix_world = mw
        body = spec["body"]
        if body not in acts:
            acts[body] = B.make_actions(arm, B.dims(body), prefix="venue_%s." % body)
        act = acts[body][anim]
        arm.animation_data_create()
        arm.animation_data.action = act
        try:
            if arm.animation_data.action_slot is None and act.slots:
                arm.animation_data.action_slot = act.slots[0]
        except AttributeError:
            pass
        placed += 1
    return placed


def world_and_lights(scene, setup):
    world = bpy.data.worlds.new("CabinDark")
    world.use_nodes = True
    dark = K.hex_linear(K.PALETTE["CabinDark"][0])
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (*dark, 1.0)
    bg.inputs["Strength"].default_value = 1.0
    world.color = dark
    scene.world = world
    K.review_light(setup, "WarmKey", "SUN", (0, 0, 20), 1.2, (1.0, 0.74, 0.52), rot=(math.radians(50), 0, math.radians(20)))
    K.review_light(setup, "RedWash", "SUN", (0, 0, 20), 0.35, (1.0, 0.12, 0.08), rot=(math.radians(55), 0, math.radians(250)))


def bloom(scene):
    """Soft glow on emissives in the render (compositor glare); skipped if this Blender's API differs."""
    try:
        tree = bpy.data.node_groups.new("BC Bloom", "CompositorNodeTree")
        rl = tree.nodes.new("CompositorNodeRLayers")
        gl = tree.nodes.new("CompositorNodeGlare")
        out = tree.nodes.new("NodeGroupOutput")
        tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        for attr, val in (("glare_type", "BLOOM"), ("quality", "MEDIUM")):
            if hasattr(gl, attr):
                setattr(gl, attr, val)
        for key, val in (("Type", "Bloom"), ("Threshold", 1.0), ("Size", 0.6), ("Strength", 0.5)):
            if key in gl.inputs:
                gl.inputs[key].default_value = val
        tree.links.new(rl.outputs["Image"], gl.inputs["Image"])
        tree.links.new(gl.outputs["Image"], out.inputs[0])
        scene.compositing_node_group = tree
        scene.render.use_compositing = True
        return True
    except Exception as e:                                           # noqa: BLE001 - review nicety only
        print("BC_REVIEW bloom skipped:", e)
        return False


def build(render=True):
    B.reset()
    _GMATS.clear()
    scene = bpy.context.scene
    lab = K.label_material()
    venue = top_collection(scene, "VENUE")
    kit = top_collection(scene, "KIT")
    chars = top_collection(scene, "CHARACTERS")
    setup = top_collection(scene, "REVIEW lights and cameras")

    objects, manifest = build_kit_objects()
    cam_kit = kit_area(scene, objects, manifest, kit)
    scene.name = "Black Cabin"

    cut = bpy.data.collections.new("VENUE ceiling and near walls")
    venue.children.link(cut)
    subs = {}
    if os.path.exists(LAYOUT):
        source = "layout.json + venue.tscn greybox and lights"
        n, spots, anchors = venue_from_layout(objects, venue, subs, cut)
        counts, _, _ = venue_from_tscn(objects, venue, cut, subs, instances=False)
        counts["kit"] = n
    else:
        source = "venue.tscn"
        counts, spots, anchors = venue_from_tscn(objects, venue, cut, subs)
    cast = bpy.data.collections.new("venue cast")
    venue.children.link(cast)
    placed = place_cast(cast, spots, anchors)
    vmin = Vector((0.0, -10.0, 0.0))
    vmax = Vector((30.0, 0.0, 4.0))
    centre = (vmin + vmax) / 2
    cam_venue = camera(setup, "Cam_VENUE", Vector((centre.x, centre.y, 0.5)), 26.0, 42, 30, yaw_deg=-18)

    cam_chars, cdepth, cwidth = chars_area(scene, lab, chars)
    for c, ob in ((setup, cam_kit), (setup, cam_chars)):
        for u in list(ob.users_collection):
            u.objects.unlink(ob)
        c.objects.link(ob)

    for text, loc in (("VENUE", Vector((0.0, -12.0, 0.01))),
                      ("KIT", KIT_OFFSET + Vector((-5.0, -1.8, 0.01))),
                      ("CHARACTERS", CHARS_OFFSET + Vector((-cwidth / 2 - 1.0, -2.2, 0.01)))):
        label(setup, "area_" + text, text, loc, 1.0, lab, align="LEFT")

    world_and_lights(scene, setup)
    overview = camera(setup, "Cam_OVERVIEW", Vector((15.5, -17.0, 0.0)), 52.0, 58, 35, yaw_deg=-8)
    scene.camera = overview
    cut.hide_viewport = False
    vl = bpy.context.view_layer.layer_collection.children["VENUE"].children["VENUE ceiling and near walls"]
    vl.exclude = True                                                # tick it in the outliner to see the closed room
    scene.render.resolution_x, scene.render.resolution_y = 2400, 1500
    scene.render.fps = B.FPS
    scene.frame_set(POSE_FRAME)
    for screen in bpy.data.screens:
        for area in screen.areas:
            for sp in area.spaces:
                if sp.type != "VIEW_3D":
                    continue
                sp.shading.type = "MATERIAL"
                sp.shading.use_scene_world = True
                sp.shading.use_scene_lights = True
                sp.clip_end = 1000.0
                if sp.region_3d:
                    sp.region_3d.view_perspective = "CAMERA"
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    print("BC_REVIEW %s (%.1f MB): venue from %s %s, %d characters placed"
          % (BLEND, os.path.getsize(BLEND) / 1e6, source, counts, placed))
    if render:
        glow = bloom(scene)
        scene.render.engine = "BLENDER_EEVEE"
        scene.render.image_settings.file_format = "PNG"
        scene.render.image_settings.color_mode = "RGB"
        scene.render.image_settings.compression = 100
        scene.view_settings.view_transform = "AgX"
        stills = [(overview, STILL)]
        if "--all-cameras" in sys.argv:
            for c in (cam_venue, cam_kit, cam_chars):
                stills.append((c, os.path.join(tempfile.gettempdir(), "bc_review_%s.png" % c.name)))
        for cam, path in stills:
            scene.camera = cam
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)
            print("BC_REVIEW still -> %s (bloom %s)" % (path, glow))
        scene.camera = overview
    return source


if __name__ == "__main__":
    build(render="--no-render" not in sys.argv)
