"""Black Cabin Tamagotchi - voxel venue kit generator.

Builds every kit object from the art bible (docs/art/art-bible.md, section 6) as a voxel grid,
meshes it (exposed faces only, one quad per voxel face), and exports one glTF per object to
game/assets/kit/<zone>/<object>.glb plus game/assets/kit/manifest.json.

Run headless from the repo root:
    blender --background --factory-startup --python tools/blender/bc_kit.py
    blender --background --factory-startup --python tools/blender/bc_kit.py -- --only round_table,bar_stool
Or inside Blender (Blender MCP bridge or the Text editor):
    exec(open(r"<this file>", encoding="utf-8").read())

Rules (art bible section 2):
  * one voxel = 5 cm, no half voxels, thin parts are one voxel wide
  * per-voxel value jitter of +-2 steps (vertex colour COLOR_0, multiplies the material colour)
  * a thin dark seam on every voxel face (16 px seam texture on per-face UVs)
  * emissive materials are named <Swatch>_emissive so Godot can bloom them
Axes: Blender X = width, -Y = front, Z = up; glTF/Godot: X = width, +Z = front, Y = up.
Origin: centre of the footprint at the floor (anchor "floor") or at the ceiling mount (anchor "ceiling").
Deterministic: the same script always writes the same voxels (jitter is hashed from name + cell).
"""
import json
import math
import os
import random
import sys
import zlib

import bpy

VOX = 0.05                     # metres per voxel (art bible section 2)
JITTER_STEP = 0.035            # one value "step"; jitter is -2..+2 steps
HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(REPO, "game", "assets", "kit")

# ------------------------------------------------------------------ palette
# name: (hex, roughness, metallic, emissive strength or 0). Game values from art bible section 3.
# Entries marked "derived" are not in the bible yet; they are the nearest values the bible implies
# (bottle tints, mirror tiles, extra plant greens, unlit lamp glass) and need art sign-off.
PALETTE = {
    # base
    "CabinDark":    ("#1C0D0C", 0.80, 0.0, 0),
    "BeamBlack":    ("#160A0C", 0.70, 0.0, 0),
    "CeilingPlum":  ("#2A0E12", 0.85, 0.0, 0),
    "StoolBlack":   ("#221110", 0.85, 0.0, 0),
    "FloorGrey":    ("#3A2C30", 0.30, 0.0, 0),
    "FloorLit":     ("#7A5248", 0.30, 0.0, 0),
    "ColumnWhite":  ("#E4DDE6", 0.45, 0.0, 0),
    # reds
    "VelvetShadow": ("#3E0408", 0.95, 0.0, 0),
    "VelvetRed":    ("#8C0610", 0.95, 0.0, 0),
    "CarpetRed":    ("#9A0A12", 0.95, 0.0, 0),
    "SlatRed":      ("#D0161C", 0.60, 0.0, 2.5),
    "PanelRed":     ("#B80A10", 0.60, 0.0, 2.0),
    "NeonRed":      ("#FF2A14", 0.40, 0.0, 5.0),
    "DrumRed":      ("#9A2A1A", 0.25, 0.0, 0),
    # warm
    "LampGold":     ("#FFDD78", 0.40, 0.0, 3.5),
    "Tealight":     ("#F7DB71", 0.40, 0.0, 3.5),
    "ShelfAmber":   ("#FF8A30", 0.40, 0.0, 3.0),
    "SoffitPeach":  ("#E8814A", 0.40, 0.0, 2.5),
    "CymbalGold":   ("#E8A030", 0.30, 0.8, 0),
    "TableWoodLit": ("#B5582C", 0.25, 0.0, 0),
    "WoodMid":      ("#6E3522", 0.30, 0.0, 0),
    "WoodDark":     ("#3F1A10", 0.60, 0.0, 0),
    "BarFront":     ("#5E1C10", 0.45, 0.0, 0),
    # cool points
    "ExitCyan":     ("#2AE6F5", 0.40, 0.0, 3.0),
    "ScreenCyan":   ("#18D0FA", 0.30, 0.0, 2.5),
    "StageBlue":    ("#20A8F0", 0.40, 0.0, 3.0),
    "PlantGreen":   ("#2E3A1A", 0.95, 0.0, 0),
    # derived (see note above)
    "PlantDark":    ("#1F2812", 0.95, 0.0, 0),
    "PlantMid":     ("#3C4A22", 0.95, 0.0, 0),
    "BottleAmber":  ("#8A4A1A", 0.15, 0.0, 0),
    "BottleAmberCap": ("#A8642E", 0.30, 0.0, 0),
    "BottleGreen":  ("#2E5A28", 0.15, 0.0, 0),
    "BottleGreenCap": ("#44703A", 0.30, 0.0, 0),
    "BottleClear":  ("#A8A0A0", 0.10, 0.0, 0),
    "BottleClearCap": ("#C4BCBC", 0.30, 0.0, 0),
    "MirrorGrey":   ("#8C8892", 0.15, 0.7, 0),
    "LampGoldOff":  ("#8A7444", 0.50, 0.0, 0),
    "White":        ("#F2EEE8", 0.40, 0.0, 4.0),   # disco ball lit tiles only
}
SEAM_VALUE = 0.55              # brightness of the seam line relative to the voxel face
BLOCK2 = {"ColumnWhite"}       # white tile: jitter per 2x2 tile, not per voxel (bible section 5)


def E(name):
    """Material key for the emissive version of a swatch."""
    return name + "_emissive"


def swatch(key):
    base = key[:-len("_emissive")] if key.endswith("_emissive") else key
    return base, key.endswith("_emissive")


# ------------------------------------------------------------------ voxel grid

class Vox:
    """A sparse voxel grid: (x, y, z) integer cell -> material key. x right, y back (front = -y), z up."""

    def __init__(self):
        self.cells = {}

    def set(self, x, y, z, m):
        self.cells[(int(x), int(y), int(z))] = m

    def remove(self, x, y, z):
        self.cells.pop((int(x), int(y), int(z)), None)

    def get(self, x, y, z):
        return self.cells.get((int(x), int(y), int(z)))

    def box(self, x0, y0, z0, x1, y1, z1, m):
        """Fill the inclusive box x0..x1, y0..y1, z0..z1."""
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                for z in range(min(z0, z1), max(z0, z1) + 1):
                    self.cells[(x, y, z)] = m

    def clear_box(self, x0, y0, z0, x1, y1, z1):
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                for z in range(z0, z1 + 1):
                    self.cells.pop((x, y, z), None)

    def disc_cells(self, cu, cv, d):
        """Cells (u, v) of a stepped pixel circle of diameter d centred on (cu, cv). Below 5 it is a square."""
        r = d / 2.0
        if d < 5:
            return [(u, v) for u in range(int(round(cu - r)), int(round(cu + r)))
                    for v in range(int(round(cv - r)), int(round(cv + r)))]
        out = []
        for u in range(math.floor(cu - r), math.ceil(cu + r)):
            for v in range(math.floor(cv - r), math.ceil(cv + r)):
                if (u + 0.5 - cu) ** 2 + (v + 0.5 - cv) ** 2 <= r * r + 0.3:
                    out.append((u, v))
        return out

    def cyl(self, cu, cv, w0, w1, d, m, axis="z", inner=0):
        """Stepped cylinder along `axis` from w0 to w1 (inclusive). inner > 0 leaves a hollow of that diameter."""
        hole = set(self.disc_cells(cu, cv, inner)) if inner else set()
        for u, v in self.disc_cells(cu, cv, d):
            if (u, v) in hole:
                continue
            for w in range(w0, w1 + 1):
                if axis == "z":
                    self.set(u, v, w, m)
                elif axis == "y":
                    self.set(u, w, v, m)
                else:
                    self.set(w, u, v, m)

    def sphere(self, c, d, m, shell=True):
        r = d / 2.0
        cells = []
        for x in range(math.floor(c[0] - r), math.ceil(c[0] + r)):
            for y in range(math.floor(c[1] - r), math.ceil(c[1] + r)):
                for z in range(math.floor(c[2] - r), math.ceil(c[2] + r)):
                    if (x + 0.5 - c[0]) ** 2 + (y + 0.5 - c[1]) ** 2 + (z + 0.5 - c[2]) ** 2 <= r * r:
                        cells.append((x, y, z))
        full = set(cells)
        for p in cells:
            if shell and all((p[0] + dx, p[1] + dy, p[2] + dz) in full for dx, dy, dz in NEIGH):
                continue
            self.cells[p] = m(p) if callable(m) else m
        return cells

    def bounds(self):
        xs, ys, zs = zip(*self.cells)
        return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


NEIGH = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
# quad corners per face direction, counter-clockwise seen from outside
FACES = {
    (1, 0, 0): ((1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)),
    (-1, 0, 0): ((0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)),
    (0, 1, 0): ((0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)),
    (0, -1, 0): ((0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)),
    (0, 0, 1): ((0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)),
    (0, 0, -1): ((0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)),
}
UVS = ((0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0))


def jitter(name, cell, key):
    base, emissive = swatch(key)
    if base in BLOCK2:
        cell = (cell[0] // 2, cell[1] // 2, cell[2] // 2)
    h = zlib.crc32(("%s|%d,%d,%d" % (name, *cell)).encode())
    if emissive:
        return 1.0 + 0.5 * JITTER_STEP * ((h % 3) - 1)
    return 1.0 + JITTER_STEP * ((h % 5) - 2)


# ------------------------------------------------------------------ Blender side

def srgb_to_linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


def hex_linear(h):
    return tuple(srgb_to_linear(int(h[i:i + 2], 16) / 255) for i in (1, 3, 5))


def seam_image():
    img = bpy.data.images.get("bc_seam")
    if img:
        return img
    n = 16
    img = bpy.data.images.new("bc_seam", n, n, alpha=False)
    px = []
    for y in range(n):
        for x in range(n):
            v = SEAM_VALUE if x in (0, n - 1) or y in (0, n - 1) else 1.0
            px += [v, v, v, 1.0]
    img.pixels = px
    img.pack()
    return img


_MATS = {}


def material(key):
    if key in _MATS:
        return _MATS[key]
    base, emissive = swatch(key)
    hexv, rough, metal, strength = PALETTE[base]
    col = hex_linear(hexv)
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*col, 1.0)
    m.use_backface_culling = True                                    # closed voxel shells: glTF doubleSided false
    if emissive:
        bsdf.inputs["Base Color"].default_value = (*col, 1.0)
        bsdf.inputs["Emission Color"].default_value = (*col, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength or 2.0
    else:
        # seam texture x swatch colour -> glTF baseColorTexture + baseColorFactor
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = seam_image()
        tex.interpolation = "Linear"
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        a = next(s for s in mix.inputs if s.name == "A" and s.type == "RGBA")
        b = next(s for s in mix.inputs if s.name == "B" and s.type == "RGBA")
        out = next(s for s in mix.outputs if s.type == "RGBA")
        nt.links.new(tex.outputs["Color"], a)
        b.default_value = (*col, 1.0)
        nt.links.new(out, bsdf.inputs["Base Color"])
    _MATS[key] = m
    return m


def build_mesh(name, vox, anchor):
    """Mesh the exposed faces. Returns (object, stats)."""
    cells = vox.cells
    (x0, y0, z0), (x1, y1, z1) = vox.bounds()
    ox = -(x0 + x1 + 1) / 2.0
    oy = -(y0 + y1 + 1) / 2.0
    oz = -(z1 + 1) if anchor == "ceiling" else -z0
    keys = sorted(set(cells.values()))
    slot = {k: i for i, k in enumerate(keys)}
    verts, faces, mats, cols, uvs = [], [], [], [], []
    for cell in sorted(cells):
        key = cells[cell]
        j = jitter(name, cell, key)
        for d, corners in FACES.items():
            n = (cell[0] + d[0], cell[1] + d[1], cell[2] + d[2])
            if n in cells:
                continue
            if d == (0, 0, -1) and anchor == "floor" and cell[2] == z0:
                continue                                     # never seen: sits on the floor
            base = len(verts)
            for c in corners:
                verts.append(((cell[0] + c[0] + ox) * VOX, (cell[1] + c[1] + oy) * VOX, (cell[2] + c[2] + oz) * VOX))
            faces.append((base, base + 1, base + 2, base + 3))
            mats.append(slot[key])
            cols.append(j)
            uvs.extend(UVS)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    for k in keys:
        me.materials.append(material(k))
    me.polygons.foreach_set("material_index", mats)
    uv = me.uv_layers.new(name="UVMap")
    uv.data.foreach_set("uv", [c for p in uvs for c in p])
    ca = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    flat = []
    for j in cols:
        flat += [j, j, j, 1.0] * 4
    ca.data.foreach_set("color", flat)
    me.color_attributes.active_color = ca
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    stats = {
        "size_vox": [x1 - x0 + 1, y1 - y0 + 1, z1 - z0 + 1],
        "voxels": len(cells),
        "tris": len(faces) * 2,
        "materials": keys,
    }
    return ob, stats


def export_glb(ob, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    want = dict(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
                export_texcoords=True, export_normals=True, export_materials="EXPORT",
                export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_image_format="AUTO",
                export_extras=False, export_cameras=False, export_lights=False, export_animations=False)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    bpy.ops.export_scene.gltf(**{k: v for k, v in want.items() if k in props})


# ------------------------------------------------------------------ registry

KIT = []      # (name, zone, size_class, anchor, builder)


def kit(name, zone, size_class, anchor="floor"):
    def deco(fn):
        KIT.append((name, zone, size_class, anchor, fn))
        return fn
    return deco


def rng(name):
    return random.Random(zlib.crc32(name.encode()))


# ================================================================== BAR (main room)

@kit("bar_counter", "bar", "L")
def bar_counter(v):
    """20-voxel (1 m) counter segment, customers at the front (-y). Tiles side by side along x."""
    W, D = 20, 12
    v.box(0, 2, 0, W - 1, D - 1, 1, "StoolBlack")                    # recessed kick
    v.box(0, 1, 2, W - 1, D - 1, 19, "BarFront")                     # body
    for x in range(0, W, 5):                                         # vertical panel seams on the front
        v.box(x, 1, 2, x, 1, 19, "WoodDark")
    v.box(0, 1, 2, W - 1, 1, 2, "WoodDark")                          # bottom rail
    v.box(0, D - 1, 2, W - 1, D - 1, 19, "WoodDark")                 # bartender side
    v.box(0, 0, 19, W - 1, 0, 19, E("ShelfAmber"))                   # amber strip under the lip
    v.box(0, -1, 20, W - 1, D - 1, 20, "WoodDark")                   # lip
    v.box(0, -1, 21, W - 1, D - 1, 21, "TableWoodLit")               # glossy top


@kit("back_bar_shelf", "bar", "L")
def back_bar_shelf(v):
    """Back-bar module: low cabinet, then 2 x 3 backlit cubbies with bottles silhouetted in front."""
    W, D = 20, 6
    r = rng("back_bar_shelf")
    v.box(0, 0, 0, W - 1, D - 1, 20, "WoodDark")                     # cabinet
    for x in (1, 10):
        v.box(x, 0, 2, x + 8, 0, 18, "BarFront")                     # doors
    v.box(0, 0, 21, W - 1, D - 1, 21, "WoodDark")                    # counter
    tints = (("BottleAmber", "BottleAmberCap"), ("BottleGreen", "BottleGreenCap"), ("BottleClear", "BottleClearCap"))
    for zb in (22, 31, 40):                                          # shelf boards at the base of each row
        v.box(0, 0, zb, W - 1, D - 1, zb, "WoodDark")
        for x0 in (1, 10):                                           # two cubbies per row, 8 wide, 8 high
            v.box(x0, D - 1, zb + 1, x0 + 8, D - 1, zb + 8, E("ShelfAmber"))
            for x in range(x0, x0 + 9, 2):
                body, cap = tints[r.randrange(3)]
                h = r.choice((3, 3, 4, 4, 5))
                y = r.choice((2, 3))
                v.box(x, y, zb + 1, x, y, zb + h - 1, body)
                v.set(x, y, zb + h, cap)
    v.box(0, 0, 49, W - 1, D - 1, 49, "WoodDark")                    # top
    for x in (0, 9, W - 1):                                          # uprights
        v.box(x, 0, 22, x, D - 1, 49, "WoodDark")


def bottle(v, body, cap, h):
    v.box(0, 0, 0, 0, 0, h - 2, body)
    v.set(0, 0, h - 1, cap)


@kit("bottle_amber", "bar", "XS")
def bottle_amber(v):
    bottle(v, "BottleAmber", "BottleAmberCap", 4)


@kit("bottle_green", "bar", "XS")
def bottle_green(v):
    bottle(v, "BottleGreen", "BottleGreenCap", 4)


@kit("bottle_clear", "bar", "XS")
def bottle_clear(v):
    bottle(v, "BottleClear", "BottleClearCap", 3)


@kit("bar_stool", "bar", "S")
def bar_stool(v):
    """8 x 8, seat H16, back H24 (bible section 2). Back at +y."""
    for x in (0, 7):
        for y in (0, 7):
            v.box(x, y, 0, x, y, 14, "WoodDark")
    for x in range(8):                                               # footrest ring
        v.set(x, 0, 5, "WoodDark")
        v.set(x, 7, 5, "WoodDark")
    for y in range(8):
        v.set(0, y, 5, "WoodDark")
        v.set(7, y, 5, "WoodDark")
    v.box(0, 0, 15, 7, 7, 15, "StoolBlack")                          # seat
    for x in (0, 7):
        v.box(x, 7, 16, x, 7, 18, "WoodDark")                        # back posts
    v.box(0, 7, 19, 7, 7, 23, "StoolBlack")                          # backrest


# ================================================================== TABLES ZONE (main room)

@kit("round_table", "tables", "M")
def round_table(v):
    """Stepped octagon top, diameter 14, H15, 1-voxel lip, 4 square legs."""
    v.cyl(7, 7, 13, 13, 14, "WoodMid", inner=12)                     # lip / apron
    v.cyl(7, 7, 14, 14, 14, "TableWoodLit")                          # glossy top
    for x, y in ((4, 4), (9, 4), (4, 9), (9, 9)):
        v.box(x, y, 0, x, y, 12, "WoodDark")
    for x in range(4, 10):                                           # low stretchers
        v.set(x, 4, 3, "WoodDark")
        v.set(x, 9, 3, "WoodDark")


@kit("communal_table", "tables", "L")
def communal_table(v):
    """Long communal table 60 x 14, H15. Long axis along x."""
    L, W = 60, 14
    v.box(0, 0, 14, L - 1, W - 1, 14, "WoodMid")
    v.box(0, 0, 13, L - 1, 0, 13, "WoodDark")
    v.box(0, W - 1, 13, L - 1, W - 1, 13, "WoodDark")
    v.box(0, 0, 13, 0, W - 1, 13, "WoodDark")
    v.box(L - 1, 0, 13, L - 1, W - 1, 13, "WoodDark")
    for x in (1, 29, 57):
        for y in (1, 11):
            v.box(x, y, 0, x + 1, y + 1, 12, "WoodDark")


@kit("cafe_chair", "tables", "S")
def cafe_chair(v):
    """8 x 8, seat H9, back H18. Back at +y."""
    for x in (0, 7):
        for y in (0, 7):
            v.box(x, y, 0, x, y, 7, "WoodDark")
    v.box(0, 0, 8, 7, 7, 8, "WoodMid")                               # seat
    for x in (0, 7):
        v.box(x, 7, 9, x, 7, 17, "WoodDark")                         # back posts
    v.box(1, 7, 15, 6, 7, 17, "WoodDark")                            # top rail
    v.box(1, 7, 12, 6, 7, 12, "WoodDark")                            # middle slat


@kit("drum_stool", "tables", "S")
def drum_stool(v):
    """Black cylindrical audience pouffe, diameter 9, H9, recessed 1-voxel ring on top."""
    v.cyl(4.5, 4.5, 0, 7, 9, "StoolBlack")
    v.cyl(4.5, 4.5, 8, 8, 9, "StoolBlack", inner=7)                  # outer rim
    v.cyl(4.5, 4.5, 8, 8, 5, "StoolBlack")                           # centre cushion; ring between is recessed
    v.cyl(4.5, 4.5, 0, 0, 9, "BeamBlack")                            # darker foot band


def table_lamp(v, shade):
    """Base 3x3x1, stem 1x1x5, stepped shade (5x5 x2, 3x3, 1x1), H10. Odd sizes so it centres on the stem."""
    v.box(0, 0, 0, 2, 2, 0, "CymbalGold")
    v.box(1, 1, 1, 1, 1, 5, "CymbalGold")
    v.box(-1, -1, 6, 3, 3, 7, shade)
    v.box(0, 0, 8, 2, 2, 8, shade)
    v.set(1, 1, 9, shade)


@kit("table_lamp_lit", "tables", "S")
def table_lamp_lit(v):
    table_lamp(v, E("LampGold"))


@kit("table_lamp_unlit", "tables", "S")
def table_lamp_unlit(v):
    table_lamp(v, "LampGoldOff")


@kit("tealight_lantern", "tables", "XS")
def tealight_lantern(v):
    v.box(0, 0, 0, 1, 1, 2, E("Tealight"))


@kit("napkin_cup", "tables", "XS")
def napkin_cup(v):
    v.box(0, 0, 0, 1, 1, 2, "ColumnWhite")


# ================================================================== STAGE

@kit("stage_platform", "stage", "L")
def stage_platform(v):
    """2 m x 1 m riser module, H9; a carpet tile on top makes the 0.5 m greybox stage height."""
    W, D, H = 40, 20, 9
    v.box(0, 0, 0, W - 1, D - 1, H - 1, "BeamBlack")
    v.box(0, 0, H - 1, W - 1, 0, H - 1, "StoolBlack")                # lighter front edge highlight
    for x in range(0, W, 10):                                        # riser panel joints
        v.box(x, 0, 0, x, 0, H - 2, "StoolBlack")


@kit("stage_carpet_tile", "stage", "Architecture")
def stage_carpet_tile(v):
    v.box(0, 0, 0, 19, 19, 0, "CarpetRed")


@kit("slatted_backdrop", "stage", "L")
def slatted_backdrop(v):
    """1-voxel slats with 1-voxel gaps in front of a Slat Red emissive panel; amber windows in the upper third."""
    W, H = 20, 60
    v.box(0, 2, 2, W - 1, 2, H - 3, E("SlatRed"))
    for z in (42, 47):                                               # two rows of window lights
        for x in (3, 7, 11, 15):
            v.box(x, 2, z, x, 2, z + 1, E("ShelfAmber"))
    for x in range(0, W, 2):
        v.box(x, 0, 2, x, 0, H - 3, "VelvetRed")
    v.box(0, 0, 0, W - 1, 2, 1, "BeamBlack")                         # bottom rail
    v.box(0, 0, H - 2, W - 1, 2, H - 1, "BeamBlack")                 # top rail


@kit("curtain_panel", "stage", "Architecture")
def curtain_panel(v):
    """One 20-voxel curtain bay, 3.5 m (greybox wall height). Folds: 1-voxel depth steps on a 2-voxel rhythm."""
    W, H = 20, 70
    for x in range(W):
        crest = (x // 2) % 2 == 0
        v.box(x, 2, 0, x, 2, H - 2, "VelvetShadow")
        if crest:
            v.box(x, 0, 0, x, 1, H - 2, "VelvetRed")
        else:
            v.box(x, 1, 0, x, 1, H - 2, "VelvetShadow")
    v.box(0, 0, H - 1, W - 1, 2, H - 1, "BeamBlack")                 # rod / header


@kit("drum_kit", "stage", "M")
def drum_kit(v):
    """Red shells with gold rings, white kick head, gold cymbals on 1-voxel stands. Drummer sits at +y."""
    chrome = "FloorGrey"
    # bass drum on its side, head facing the audience (-y)
    v.cyl(0, 5, -3, 3, 10, "DrumRed", axis="y")
    v.cyl(0, 5, -4, -4, 10, "ColumnWhite", axis="y")                 # kick head
    v.cyl(0, 5, -4, -4, 4, "CarpetRed", axis="y")                    # logo disc on the head
    v.cyl(0, 5, -3, -3, 10, "CymbalGold", axis="y", inner=8)         # hardware rings
    v.cyl(0, 5, 3, 3, 10, "CymbalGold", axis="y", inner=8)
    # rack toms on the bass drum
    v.box(0, 0, 10, 0, 0, 11, chrome)
    for cx in (-3, 3):
        v.cyl(cx, 0.5, 12, 15, 5, "DrumRed")
        v.cyl(cx, 0.5, 12, 12, 5, "CymbalGold", inner=3)
        v.cyl(cx, 0.5, 15, 15, 5, "ColumnWhite")
    # snare (drummer's left, audience right is -x here)
    v.box(-9, 2, 0, -9, 2, 10, chrome)
    v.cyl(-9, 2.5, 11, 13, 6, "DrumRed")
    v.cyl(-9, 2.5, 13, 13, 6, "ColumnWhite")
    v.cyl(-9, 2.5, 11, 11, 6, "CymbalGold", inner=4)
    # floor tom on three legs
    for lx, ly in ((7, 0), (11, 0), (9, 4)):
        v.box(lx, ly, 0, lx, ly, 5, chrome)
    v.cyl(9.5, 2.5, 6, 11, 7, "DrumRed")
    v.cyl(9.5, 2.5, 11, 11, 7, "ColumnWhite")
    v.cyl(9.5, 2.5, 6, 6, 7, "CymbalGold", inner=5)
    # cymbals: hi-hat, crash, ride
    v.box(-13, 4, 0, -13, 4, 17, chrome)
    v.cyl(-13, 4.5, 16, 16, 5, "CymbalGold")
    v.cyl(-13, 4.5, 18, 18, 5, "CymbalGold")
    v.box(-8, 8, 0, -8, 8, 22, chrome)
    v.cyl(-8, 8.5, 23, 23, 7, "CymbalGold")
    v.box(11, 8, 0, 11, 8, 19, chrome)
    v.cyl(11, 8.5, 20, 20, 7, "CymbalGold")
    # throne
    v.box(0, 10, 0, 0, 10, 6, chrome)
    v.cyl(0.5, 10.5, 7, 8, 5, "StoolBlack")


@kit("guitar_on_stand", "stage", "S")
def guitar_on_stand(v):
    """Red electric guitar, face to the audience (-y), on a black A-frame stand."""
    body = "CarpetRed"
    rows = {2: (1, 7), 3: (0, 8), 4: (0, 8), 5: (1, 7), 6: (2, 6), 7: (1, 7), 8: (0, 8)}
    for z, (a, b) in rows.items():
        v.box(a, 1, z, b, 2, z, body)
    for x in (0, 1, 7, 8):                                           # double-cut horns
        v.box(x, 1, 9, x, 2, 9, body)
    v.box(0, 1, 10, 0, 2, 10, body)
    v.box(8, 1, 10, 8, 2, 10, body)
    v.box(2, 0, 3, 3, 0, 6, "ColumnWhite")                           # pickguard, proud of the body
    v.box(3, 0, 5, 5, 0, 5, "StoolBlack")                            # pickups
    v.box(3, 0, 8, 5, 0, 8, "StoolBlack")
    v.set(6, 0, 3, "CymbalGold")                                     # knob
    v.box(4, 1, 9, 4, 1, 19, "WoodMid")                              # neck
    v.box(4, 1, 20, 5, 1, 22, "WoodDark")                            # headstock
    v.box(0, 3, 0, 8, 3, 0, "BeamBlack")                             # stand base
    v.box(4, 3, 0, 4, 7, 0, "BeamBlack")                             # rear leg
    v.box(4, 3, 1, 4, 3, 15, "BeamBlack")                            # upright behind the neck
    v.box(3, 2, 15, 5, 2, 15, "BeamBlack")                           # neck yoke
    for x in (1, 7):
        v.box(x, 0, 1, x, 3, 1, "BeamBlack")                         # cradle arms


@kit("amp", "stage", "S")
def amp(v):
    """Guitar combo amp: black tolex, dotted grille, gold knobs, red pilot light."""
    W, D, H = 12, 7, 12
    v.box(0, 0, 0, W - 1, D - 1, H - 1, "StoolBlack")
    v.box(1, 0, 1, W - 2, 0, 7, "BeamBlack")
    for x in range(2, W - 2, 2):
        for z in range(2, 7, 2):
            v.set(x, 0, z, "FloorGrey")
    v.box(1, 0, 9, W - 2, 0, 10, "BeamBlack")                        # control panel
    for x in (2, 4, 6, 8):
        v.set(x, -1, 10, "CymbalGold")
    v.set(10, -1, 10, E("NeonRed"))
    v.box(4, 3, H, 7, 3, H, "BeamBlack")                             # handle


@kit("mic_stand", "stage", "S")
def mic_stand(v):
    v.cyl(2.5, 2.5, 0, 0, 5, "BeamBlack")
    v.box(2, 2, 1, 2, 2, 25, "FloorGrey")
    v.set(2, 2, 26, "BeamBlack")
    v.box(2, 2, 27, 2, 2, 28, "CarpetRed")                           # red mic head


@kit("monitor_wedge", "stage", "S")
def monitor_wedge(v):
    """Floor wedge, low edge at the front (-y), speaker on the slope."""
    W, D = 12, 9
    for y in range(D):
        h = 2 + round(y * 5 / (D - 1))
        v.box(0, y, 0, W - 1, y, h - 1, "StoolBlack")
        for x in range(1, W - 1):
            top = "FloorGrey" if (x % 2 == 0 and y % 2 == 1) else "BeamBlack"
            v.set(x, y, h - 1, top)


@kit("disco_ball", "stage", "S", anchor="ceiling")
def disco_ball(v):
    """Diameter 14 stepped sphere of mirror tiles on a 2 x 2 drop rod. Some tiles lit white, amber, red."""
    def tile(p):
        h = zlib.crc32(("disco|%d,%d,%d" % p).encode()) % 100
        if h < 6:
            return E("White")
        if h < 12:
            return E("LampGold")
        if h < 18:
            return E("SlatRed")
        return "MirrorGrey"
    v.sphere((7, 7, 7), 14, tile)
    v.box(6, 6, 14, 7, 7, 23, "BeamBlack")
    v.box(5, 5, 24, 8, 8, 24, "BeamBlack")


# ================================================================== ENTRANCE LOUNGE

FONT = {
    "B": ("1111.", "1...1", "1...1", "1111.", "1...1", "1...1", "1111."),
    "L": ("1....", "1....", "1....", "1....", "1....", "1....", "11111"),
    "A": (".111.", "1...1", "1...1", "11111", "1...1", "1...1", "1...1"),
    "C": (".1111", "1....", "1....", "1....", "1....", "1....", ".1111"),
    "K": ("1...1", "1..1.", "1.1..", "11...", "1.1..", "1..1.", "1...1"),
    "I": (".111.", "..1..", "..1..", "..1..", "..1..", "..1..", ".111."),
    "N": ("1...1", "11..1", "1.1.1", "1..11", "1...1", "1...1", "1...1"),
}


@kit("neon_sign", "lounge", "M")
def neon_sign(v):
    """BLACK over CABIN, 1-voxel Neon Red tubes in a 5 x 7 pixel font, on a dark backing plate."""
    lines = ("BLACK", "CABIN")
    width = 5 * 5 + 4
    for li, word in enumerate(lines):
        top = 16 - li * 9                                            # rows z 16..10 and 7..1
        for ci, ch in enumerate(word):
            for row, bits in enumerate(FONT[ch]):
                for col, bit in enumerate(bits):
                    if bit == "1":
                        v.set(ci * 6 + col, 0, top - row, E("NeonRed"))
    v.box(-2, 1, -1, width + 1, 1, 18, "VelvetShadow")               # backing plate


@kit("plant_wall_tile", "lounge", "L")
def plant_wall_tile(v):
    """20 x 20 tile of clustered 1-voxel leaves in three dark greens on a black backing, 1-4 voxels deep."""
    r = rng("plant_wall_tile")
    greens = ("PlantDark", "PlantGreen", "PlantMid")
    v.box(0, 4, 0, 19, 4, 19, "BeamBlack")
    for x in range(20):
        for z in range(20):
            clump = zlib.crc32(("pw|%d,%d" % (x // 3, z // 3)).encode()) % 4
            depth = max(1, min(4, clump + r.choice((-1, 0, 0, 1))))
            for k in range(depth):
                y = 3 - k
                v.set(x, y, z, greens[(clump + k + r.randrange(2)) % 3])
            if r.random() < 0.04:
                v.set(x, 3 - depth, z, "WoodDark")                   # branch tips poking out


@kit("white_column", "lounge", "Architecture")
def white_column(v):
    """Square white-tile column, 8 x 8, floor to greybox ceiling (3.5 m)."""
    v.box(0, 0, 2, 7, 7, 69, "ColumnWhite")
    v.box(0, 0, 0, 7, 7, 1, "BeamBlack")                             # plinth


@kit("beam_segment", "lounge", "Architecture", anchor="ceiling")
def beam_segment(v):
    v.box(0, 0, 0, 19, 3, 4, "BeamBlack")
    v.box(0, 0, 0, 19, 0, 0, "StoolBlack")                           # one lighter edge


@kit("ceiling_panel", "lounge", "Architecture", anchor="ceiling")
def ceiling_panel(v):
    """Red emissive panel that fills one 20 x 20 bay of the beam grid (R02)."""
    v.box(0, 0, 0, 19, 19, 0, E("PanelRed"))


@kit("arcade_cabinet", "lounge", "M")
def arcade_cabinet(v):
    """Upright arcade / vending cabinet with a recessed blue screen, red marquee and lit buttons."""
    W, D, H = 14, 12, 36
    v.box(0, 0, 0, W - 1, D - 1, H - 1, "StoolBlack")
    v.box(0, 0, 0, 0, D - 1, H - 1, "BeamBlack")
    v.box(W - 1, 0, 0, W - 1, D - 1, H - 1, "BeamBlack")
    v.clear_box(2, 0, 20, W - 3, 0, 29)
    v.box(2, 1, 20, W - 3, 1, 29, E("ScreenCyan"))
    v.box(1, 0, 31, W - 2, 0, 34, E("PanelRed"))                     # marquee
    v.box(1, -3, 16, W - 2, -1, 17, "BeamBlack")                     # control deck
    for x, c in ((3, "NeonRed"), (5, "LampGold"), (8, "NeonRed"), (10, "LampGold")):
        v.set(x, -2, 18, E(c))
    v.box(5, -1, 5, 8, -1, 10, "CymbalGold")                         # coin door


@kit("collectibles_shelf", "lounge", "L")
def collectibles_shelf(v):
    """Open shelf: figurines, busts, glass globe, mini disco ball, boxes, small plants; amber strips under shelves."""
    W, D, H = 40, 8, 44
    v.box(0, D - 1, 0, W - 1, D - 1, H - 1, "CeilingPlum")           # back panel
    for x in (0, 13, 26, W - 1):
        v.box(x, 0, 0, x, D - 1, H - 1, "WoodDark")
    for z in (0, 14, 28, H - 1):
        v.box(0, 0, z, W - 1, D - 1, z, "WoodDark")
        if z:
            v.box(1, 1, z - 1, W - 2, 1, z - 1, E("ShelfAmber"))
    v.box(0, 0, 1, W - 1, D - 1, 1, "WoodDark")
    r = rng("collectibles_shelf")

    def figurine(x, z):
        c = r.choice(("DrumRed", "ColumnWhite", "CymbalGold", "StageBlue", "VelvetRed"))
        v.box(x, 3, z, x + 1, 4, z + 2, c)
        v.box(x, 3, z + 3, x + 1, 4, z + 4, "ColumnWhite")

    def bust(x, z):
        v.box(x, 2, z, x + 2, 4, z, "BeamBlack")
        v.box(x, 2, z + 1, x + 2, 4, z + 4, "ColumnWhite")

    def globe(x, z):
        v.box(x + 1, 3, z, x + 3, 4, z, "CymbalGold")
        v.sphere((x + 2.5, 4, z + 4), 6, "BottleClear")

    def mini_disco(x, z):
        v.box(x, 2, z, x + 2, 4, z + 2, "MirrorGrey")
        v.set(x + 1, 2, z + 1, E("White"))

    def boxes(x, z):
        v.box(x, 2, z, x + 3, 5, z + 2, r.choice(("BarFront", "DrumRed", "WoodMid")))
        v.box(x + 1, 3, z + 3, x + 2, 4, z + 4, "ColumnWhite")

    def plant(x, z):
        v.box(x, 3, z, x + 2, 5, z + 1, "WoodDark")
        for k in range(10):
            v.set(x + r.randrange(-1, 4), 3 + r.randrange(3), z + 2 + r.randrange(3), r.choice(("PlantGreen", "PlantMid")))

    items = [figurine, bust, globe, mini_disco, boxes, plant]
    for z in (2, 15, 29):
        for bay in range(3):
            x0 = bay * 13 + 2
            picks = [items[(bay + z + k) % len(items)] for k in range(2)]
            picks[0](x0, z)
            picks[1](x0 + 6, z)


@kit("crt_monitor", "lounge", "S")
def crt_monitor(v):
    """Small blue-screen CRT on a low cabinet (R02)."""
    v.box(0, 0, 0, 13, 9, 11, "WoodDark")
    v.box(1, 0, 1, 6, 0, 10, "BarFront")
    v.box(7, 0, 1, 12, 0, 10, "BarFront")
    v.box(2, 1, 12, 10, 6, 19, "FloorGrey")                          # casing
    v.box(4, 7, 13, 8, 8, 18, "FloorGrey")                           # tube back
    v.box(3, 0, 13, 9, 0, 18, E("ScreenCyan"))
    v.box(2, 0, 12, 10, 0, 12, "StoolBlack")
    v.box(2, 0, 19, 10, 0, 19, "StoolBlack")
    v.box(2, 0, 13, 2, 0, 18, "StoolBlack")
    v.box(10, 0, 13, 10, 0, 18, "StoolBlack")


# ================================================================== STAIRS AND CIRCULATION

@kit("stair_run", "circulation", "L")
def stair_run(v):
    """Greybox flight: 12 steps, rise 0.2 m, run 0.3 m, 1.6 m wide, rising to +y. Steel stringers,
    rail on the +x side, amber step lights at both ends of every riser."""
    STEPS, RISE, RUN, WIDTH = 12, 4, 6, 32
    for i in range(STEPS):
        y0, top = i * RUN, (i + 1) * RISE - 1
        v.box(1, y0, 0, WIDTH - 2, y0 + RUN - 1, top - 1, "BeamBlack")
        v.box(1, y0, top, WIDTH - 2, y0 + RUN - 1, top, "WoodDark")   # tread
        for x in (2, WIDTH - 4):                                     # lights proud of the riser face
            v.box(x, y0 - 1, i * RISE + 1, x + 1, y0 - 1, i * RISE + 1, E("ShelfAmber"))
    for y in range(STEPS * RUN):                                     # stringers follow the slope
        tz = (y // RUN + 1) * RISE - 1
        for x in (0, WIDTH - 1):
            v.box(x, y, 0, x, y, tz + 2, "BeamBlack")
    for y in range(STEPS * RUN):                                     # handrail + posts every 2 steps
        tz = (y // RUN + 1) * RISE - 1
        v.set(WIDTH - 1, y, tz + 18, "StoolBlack")
        if y % (RUN * 2) == 2:
            v.box(WIDTH - 1, y, tz + 3, WIDTH - 1, y, tz + 17, "BeamBlack")


@kit("exit_sign", "circulation", "XS")
def exit_sign(v):
    v.box(0, 1, 0, 5, 1, 3, "BeamBlack")
    v.box(0, 0, 0, 5, 0, 3, "BeamBlack")
    v.box(1, 0, 1, 4, 0, 2, E("ExitCyan"))


@kit("track_light", "circulation", "Architecture", anchor="ceiling")
def track_light(v):
    """1 m rail with three spot heads pointing down, warm lens at the bottom."""
    v.box(0, 0, 7, 19, 0, 7, "BeamBlack")
    for x in (3, 9, 15):
        v.set(x, 0, 6, "BeamBlack")
        v.box(x, 0, 3, x + 1, 1, 5, "StoolBlack")
        v.box(x, 0, 2, x + 1, 1, 2, E("LampGold"))


# ------------------------------------------------------------------ run

def run(only=None, out=OUT):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    manifest = []
    names = [k[0] for k in KIT]
    assert len(names) == len(set(names)), "duplicate kit names"
    for name, zone, size_class, anchor, fn in KIT:
        if only and name not in only:
            continue
        v = Vox()
        fn(v)
        ob, st = build_mesh(name, v, anchor)
        rel = "%s/%s.glb" % (zone, name)
        export_glb(ob, os.path.join(out, zone, name + ".glb"))
        sx, sy, sz = st["size_vox"]
        manifest.append({
            "name": name,
            "zone": zone,
            "size_class": size_class,
            "anchor": anchor,
            "path": "res://assets/kit/" + rel,
            "footprint_m": [round(sx * VOX, 3), round(sy * VOX, 3)],
            "height_m": round(sz * VOX, 3),
            "size_vox": st["size_vox"],
            "emissive": any(m.endswith("_emissive") for m in st["materials"]),
            "materials": st["materials"],
            "voxels": st["voxels"],
            "tris": st["tris"],
        })
        print("BC_KIT %-20s %-12s %-12s vox=%-6d tris=%-6d size=%s" % (name, zone, size_class, st["voxels"], st["tris"], st["size_vox"]))
    if not only:
        with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump({"voxel_m": VOX, "front": "+Z (Godot) / -Y (Blender)", "objects": manifest}, f, indent=1)
            f.write("\n")
    print("BC_KIT done: %d objects -> %s" % (len(manifest), out))
    return manifest


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = None
    if "--only" in argv:
        only = set(argv[argv.index("--only") + 1].split(","))
    run(only)
