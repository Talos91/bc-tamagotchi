"""Black Cabin Tamagotchi - voxel venue kit generator.

Builds every kit object from the art bible (docs/art/art-bible.md, section 6) as a voxel grid,
meshes it (exposed faces only, coplanar same-material faces merged into rectangles), and exports one glTF
per object to game/assets/kit/<zone>/<object>.glb plus game/assets/kit/manifest.json.

Run headless from the repo root:
    blender --background --factory-startup --python tools/blender/bc_kit.py
    blender --background --factory-startup --python tools/blender/bc_kit.py -- --only round_table,bar_stool
A full run also saves a review scene to blender/BlackCabinKit.blend (zone collections, labels, lights, camera,
Material Preview); pass `-- --no-blend` to skip it. `--only` runs never write the .blend.
Or inside Blender (Blender MCP bridge or the Text editor):
    exec(open(r"<this file>", encoding="utf-8").read())

Rules (art bible section 2):
  * one voxel = 5 cm, no half voxels, thin parts are one voxel wide
  * per-voxel value jitter of +-2 steps and a thin dark seam on every voxel face, both baked into one
    tiling texture (16 x 16 voxels, 16 px per voxel); UVs are in voxel units on a world-aligned grid, so a
    merged rectangle still shows one jittered, seamed cube per voxel
  * emissive materials are named <Swatch>_emissive so Godot can bloom them (no texture, no jitter)
Axes: Blender X = width, -Y = front, Z = up; glTF/Godot: X = width, +Z = front, Y = up.
Origin: centre of the footprint at the floor (anchor "floor") or at the ceiling mount (anchor "ceiling").
Wall-mounted objects keep anchor "floor" (origin at the bottom centre) and add "mount": "wall" in the manifest,
back face at +Y in Blender (-Z in Godot) against the wall.
Deterministic: the same script always writes the same voxels and the same texture.
"""
import json
import math
import os
import random
import sys
import zlib

import bpy

VOX = 0.05                     # metres per voxel (art bible section 2)
ROOM_H = 80                    # floor to ceiling in voxels, 4 m (DECISIONS 2026-10-27 (j))
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
    # Wood v2: the bible's Game values were sampled off the renders, i.e. already lit red and amber, so under
    # the game's own red light they went orange-red. These are the same woods un-lit: hue moved from 6-19 deg
    # to 16-25 deg (the photos' walnut reads 24-33 deg under amber), saturation down to ~0.55.
    "TableWoodLit": ("#946446", 0.25, 0.0, 0),
    "WoodMid":      ("#5E3E2A", 0.30, 0.0, 0),
    "WoodDark":     ("#36241A", 0.60, 0.0, 0),
    "BarFront":     ("#4E2A1C", 0.45, 0.0, 0),
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
    "MirrorGrey":   ("#8C8892", 0.15, 0.3, 0),     # v2: metallic 0.7 -> 0.3, read black without a reflection probe
    "MirrorLight":  ("#C4C0CA", 0.10, 0.3, 0),
    "MirrorDark":   ("#4C4852", 0.20, 0.3, 0),
    "LampGoldOff":  ("#8A7444", 0.50, 0.0, 0),
    "White":        ("#F2EEE8", 0.40, 0.0, 4.0),   # disco ball lit tiles only
    "PlasticWhite": ("#D6D0CA", 0.50, 0.0, 0),     # AC unit
    "OliveLeaf":    ("#5A5E3C", 0.90, 0.0, 0),     # stage tree (olive, 5843): grey-green, still dark
    "OliveDark":    ("#3A3E26", 0.90, 0.0, 0),
    "BarkGrey":     ("#4A3C34", 0.90, 0.0, 0),
    "FloorPale":    ("#46383A", 0.30, 0.0, 0),     # concrete mottling either side of Floor Grey
    "FloorDeep":    ("#30242A", 0.30, 0.0, 0),
}
SEAM_VALUE = 0.55              # brightness of the seam line relative to the voxel face (sRGB texel value)
BLOCK2 = {"ColumnWhite"}       # white tile: jitter and seams on a 2x2 grid, not per voxel (bible section 5)
TILE = 16                      # jitter texture period in voxels
TEX_PX = 16                    # texture pixels per voxel
JMAX = 1.0 + 2 * JITTER_STEP   # brightest jitter; the texture stores jitter / JMAX, the colour factor x JMAX


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

    def line(self, p0, p1, m, keep=False):
        """1-voxel line from p0 to p1 (inclusive), face-connected so it never reads as loose diagonal cubes.
        keep=True leaves cells that are already set."""
        p, q = [int(round(c)) for c in p0], [int(round(c)) for c in p1]
        n = max(abs(q[i] - p[i]) for i in range(3))
        prev = None
        for s in range(n + 1):
            c = [int(round(p[i] + (q[i] - p[i]) * s / max(n, 1))) for i in range(3)]
            if prev is not None:                                     # fill the corner between diagonal steps
                for i in range(3):
                    if c[i] != prev[i]:
                        prev = prev[:i] + [c[i]] + prev[i + 1:]
                        if not (keep and tuple(prev) in self.cells):
                            self.set(*prev, m)
            if not (keep and tuple(c) in self.cells):
                self.set(*c, m)
            prev = c

    def blob(self, c, r, pick, density, rnd, keep=True):
        """Ellipsoid of radii r around c, each cell set with probability density; pick(cell, t) gives the
        material, t = normalised height inside the blob (0 bottom, 1 top)."""
        out = []
        for x in range(math.floor(c[0] - r[0]), math.ceil(c[0] + r[0]) + 1):
            for y in range(math.floor(c[1] - r[1]), math.ceil(c[1] + r[1]) + 1):
                for z in range(math.floor(c[2] - r[2]), math.ceil(c[2] + r[2]) + 1):
                    d = ((x - c[0]) / r[0]) ** 2 + ((y - c[1]) / r[1]) ** 2 + ((z - c[2]) / r[2]) ** 2
                    if d > 1.0 or rnd.random() > density * (1.25 - 0.5 * d):
                        continue
                    if keep and (x, y, z) in self.cells:
                        continue
                    self.set(x, y, z, pick((x, y, z), (z - c[2] + r[2]) / (2 * r[2])))
                    out.append((x, y, z))
        return out

    def bounds(self):
        xs, ys, zs = zip(*self.cells)
        return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


NEIGH = ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))
AXES = {0: (1, 2), 1: (0, 2), 2: (0, 1)}   # in-plane axes (a, b) of a face whose normal runs along axis k


def jitter(i, j, block):
    """Value multiplier of texture cell (i, j): -2..+2 steps. block=2 shares one value per 2x2 cells."""
    h = zlib.crc32(("bcvox|%d,%d" % (i // block, j // block)).encode())
    return 1.0 + JITTER_STEP * ((h % 5) - 2)


# ------------------------------------------------------------------ Blender side

def srgb_to_linear(c):
    return ((c + 0.055) / 1.055) ** 2.4 if c > 0.04045 else c / 12.92


def linear_to_srgb(c):
    return 1.055 * c ** (1 / 2.4) - 0.055 if c > 0.0031308 else c * 12.92


def hex_linear(h):
    return tuple(srgb_to_linear(int(h[i:i + 2], 16) / 255) for i in (1, 3, 5))


def seam_image(block=1):
    """TILE x TILE voxels, TEX_PX px each: jitter / JMAX per voxel (per 2x2 for block=2) times a 1 px dark seam
    on every voxel edge (only on the 2-voxel grid for block=2). sRGB texels, as glTF base colour expects."""
    name = "bc_seam" if block == 1 else "bc_seam%d" % block
    img = bpy.data.images.get(name)
    if img:
        return img
    n = TILE * TEX_PX
    seam = srgb_to_linear(SEAM_VALUE)
    img = bpy.data.images.new(name, n, n, alpha=False)
    px = []
    for y in range(n):
        j, py = divmod(y, TEX_PX)
        for x in range(n):
            i, pxl = divmod(x, TEX_PX)
            lin = jitter(i, j, block) / JMAX
            edge_x = (pxl == 0 and i % block == 0) or (pxl == TEX_PX - 1 and i % block == block - 1)
            edge_y = (py == 0 and j % block == 0) or (py == TEX_PX - 1 and j % block == block - 1)
            if edge_x or edge_y:
                lin *= seam
            v = round(linear_to_srgb(lin) * 255) / 255
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
        # jitter/seam texture x swatch colour -> glTF baseColorTexture + baseColorFactor
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = seam_image(2 if base in BLOCK2 else 1)
        tex.interpolation = "Linear"
        tex.extension = "REPEAT"
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        a = next(s for s in mix.inputs if s.name == "A" and s.type == "RGBA")
        b = next(s for s in mix.inputs if s.name == "B" and s.type == "RGBA")
        out = next(s for s in mix.outputs if s.type == "RGBA")
        nt.links.new(tex.outputs["Color"], a)
        b.default_value = (*(min(1.0, c * JMAX) for c in col), 1.0)
        nt.links.new(out, bsdf.inputs["Base Color"])
    _MATS[key] = m
    return m


def greedy_faces(cells, skip):
    """Exposed voxel faces, merged per plane into maximal same-material rectangles.
    Returns (rects, faces_before); a rect is (d, w, a0, b0, wa, wb, key)."""
    planes, before = {}, 0
    for cell, key in cells.items():
        for d in NEIGH:
            if (cell[0] + d[0], cell[1] + d[1], cell[2] + d[2]) in cells or skip(cell, d):
                continue
            k = next(i for i in range(3) if d[i])
            a, b = AXES[k]
            planes.setdefault((d, cell[k]), {})[(cell[a], cell[b])] = key
            before += 1
    rects = []
    for (d, w) in sorted(planes):
        grid, done = planes[(d, w)], set()
        for (a, b) in sorted(grid, key=lambda p: (p[1], p[0])):
            if (a, b) in done:
                continue
            key = grid[(a, b)]

            def free(p):
                return p not in done and grid.get(p) == key
            wa = 1
            while free((a + wa, b)):
                wa += 1
            wb = 1
            while all(free((a + i, b + wb)) for i in range(wa)):
                wb += 1
            for i in range(wa):
                for j in range(wb):
                    done.add((a + i, b + j))
            rects.append((d, w, a, b, wa, wb, key))
    return rects, before


def build_mesh(name, vox, anchor):
    """Mesh the exposed faces as merged rectangles. Returns (object, stats)."""
    cells = vox.cells
    (x0, y0, z0), (x1, y1, z1) = vox.bounds()
    origin = (-(x0 + x1 + 1) / 2.0, -(y0 + y1 + 1) / 2.0, -(z1 + 1) if anchor == "ceiling" else -z0)

    def skip(cell, d):                                               # never seen: sits on the floor
        return d == (0, 0, -1) and anchor == "floor" and cell[2] == z0
    rects, before = greedy_faces(cells, skip)
    keys = sorted(set(cells.values()))
    slot = {k: i for i, k in enumerate(keys)}
    verts, faces, mats, uvs = [], [], [], []
    for d, w, a0, b0, wa, wb, key in rects:
        k = next(i for i in range(3) if d[i])
        ax, bx = AXES[k]
        plane = w + (1 if d[k] > 0 else 0)
        step = 2 if swatch(key)[0] in BLOCK2 else 1                  # keep the 2x2 tile grid aligned
        h = zlib.crc32(("%s|%d,%d,%d|%d" % (name, *d, w)).encode())  # each plane starts the texture elsewhere
        ou, ov = (h % (TILE // step)) * step, ((h >> 8) % (TILE // step)) * step
        quad = []
        for ca, cb in ((a0, b0), (a0 + wa, b0), (a0 + wa, b0 + wb), (a0, b0 + wb)):
            p = [0.0, 0.0, 0.0]
            p[k], p[ax], p[bx] = plane, ca, cb
            quad.append(((p[0] + origin[0]) * VOX, (p[1] + origin[1]) * VOX, (p[2] + origin[2]) * VOX,
                         (ca + ou) / TILE, (cb + ov) / TILE))
        e1 = [quad[1][i] - quad[0][i] for i in range(3)]
        e2 = [quad[2][i] - quad[0][i] for i in range(3)]
        normal = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
        if normal[k] * d[k] < 0:
            quad.reverse()                                           # counter-clockwise seen from outside
        base = len(verts)
        for q in quad:
            verts.append(q[:3])
            uvs.append(q[3:])
        faces.append((base, base + 1, base + 2, base + 3))
        mats.append(slot[key])
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    for k in keys:
        me.materials.append(material(k))
    me.polygons.foreach_set("material_index", mats)
    uv = me.uv_layers.new(name="UVMap")
    uv.data.foreach_set("uv", [c for p in uvs for c in p])
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    stats = {
        "size_vox": [x1 - x0 + 1, y1 - y0 + 1, z1 - z0 + 1],
        "voxels": len(cells),
        "tris": len(faces) * 2,
        "tris_unmerged": before * 2,
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

KIT = []      # (name, zone, size_class, anchor, builder, extra manifest fields)


def kit(name, zone, size_class, anchor="floor", **extra):
    """extra goes into the manifest as is: mount ("wall"), mount_height_m (suggested height of the origin),
    variant_of (the object this one swaps with), note."""
    def deco(fn):
        KIT.append((name, zone, size_class, anchor, fn, extra))
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


@kit("soffit_segment", "bar", "L", anchor="ceiling")
def soffit_segment(v):
    """1 m of the light soffit above the bar (R01, R03): a dark wood box hung from the ceiling with a Soffit
    Peach panel facing the room (-y) and a peach strip underneath. Butt segments along x; the end posts
    become 2-voxel dividers between panels."""
    W, D, H = 20, 8, 10
    v.box(0, 0, 0, W - 1, D - 1, H - 1, "WoodDark")
    v.box(1, 0, 2, W - 2, 0, H - 2, E("SoffitPeach"))                # front panel
    v.box(1, 2, 0, W - 2, 4, 0, E("SoffitPeach"))                    # underside strip
    v.box(0, 0, 0, W - 1, 0, 1, "BarFront")                          # bottom rail, one lighter edge


PAINTING_SETS = {
    # canvas, frame, block colours (bible section 6: pixel-art paintings in red frames)
    "painting_a": ("CabinDark", "VelvetRed", ("DrumRed", "CymbalGold", "CarpetRed", "ColumnWhite", "WoodMid")),
    "painting_b": ("CeilingPlum", "CarpetRed", ("ColumnWhite", "StageBlue", "DrumRed", "BeamBlack", "CymbalGold")),
    "painting_c": ("WoodDark", "VelvetRed", ("CymbalGold", "TableWoodLit", "ColumnWhite", "VelvetShadow", "DrumRed")),
}


def painting(v, name, w, h):
    """Wall painting, front -y, back flat against the wall (+y). 1-voxel red frame standing one voxel proud
    of the canvas; abstract palette blocks on the canvas, a few in relief."""
    canvas, frame, colours = PAINTING_SETS[name]
    r = rng(name)
    v.box(0, 1, 0, w - 1, 1, h - 1, frame)                           # frame back / sides
    v.box(0, 0, 0, w - 1, 0, h - 1, frame)
    v.clear_box(1, 0, 1, w - 2, 0, h - 2)                            # open the frame
    v.box(1, 1, 1, w - 2, 1, h - 2, canvas)
    for i in range(r.randint(6, 9)):                                 # overlapping blocks, big ones first
        bw = max(2, int((w - 2) * r.uniform(0.15, 0.6) * (1 - i * 0.06)))
        bh = max(2, int((h - 2) * r.uniform(0.15, 0.6) * (1 - i * 0.06)))
        x0, z0 = r.randint(1, w - 1 - bw), r.randint(1, h - 1 - bh)
        c = colours[i % len(colours)]
        y = 0 if i >= 5 and r.random() < 0.6 else 1                  # late, small blocks stand in relief
        v.box(x0, y, z0, x0 + bw - 1, y, z0 + bh - 1, c)


@kit("painting_a", "bar", "M", mount="wall", mount_height_m=1.4)
def painting_a(v):
    painting(v, "painting_a", 16, 22)                                # portrait 0.8 x 1.1 m


@kit("painting_b", "bar", "M", mount="wall", mount_height_m=1.5)
def painting_b(v):
    painting(v, "painting_b", 24, 16)                                # landscape 1.2 x 0.8 m


@kit("painting_c", "bar", "M", mount="wall", mount_height_m=1.5)
def painting_c(v):
    painting(v, "painting_c", 14, 14)                                # square 0.7 m


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
    """One 20-voxel curtain bay, floor to ceiling: 4 m / 80 voxels (DECISIONS 2026-10-27 (j); v1 was 3.5 m).
    Folds: 1-voxel depth steps on a 2-voxel rhythm."""
    W, H = 20, ROOM_H
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
    """Red shells with gold hoops and lugs, white heads, white kick head with a red ring, gold cymbals with
    bells on tripod stands (R03). Drummer sits at +y. v2: bigger shells, same 31 x 17 x 24 box as v1."""
    chrome = "FloorGrey"

    def tripod(x, y, top):
        v.box(x, y, 0, x, y, top, chrome)
        for dx, dy in ((-2, -1), (2, -1), (0, 2)):                   # feet splayed on the floor
            v.line((x, y, 1), (x + dx, y + dy, 0), chrome)

    def drum(cx, cy, z0, z1, d, lugs=True):
        """Upright shell: white batter head on top, gold hoop at both ends, gold lugs on the side."""
        v.cyl(cx, cy, z0, z1, d, "DrumRed")
        v.cyl(cx, cy, z0, z0, d, "CymbalGold", inner=d - 2)
        v.cyl(cx, cy, z1, z1, d, "CymbalGold", inner=d - 2)
        v.cyl(cx, cy, z1, z1, d - 2, "ColumnWhite")
        if lugs:
            mid = (z0 + z1) // 2
            for u, w in v.disc_cells(cx, cy, d):                     # lugs every other rim cell, one voxel proud
                if (u + w) % 3 == 0 and (u - cx + 0.5) ** 2 + (w - cy + 0.5) ** 2 > (d / 2 - 1.2) ** 2:
                    du = 1 if u + 0.5 > cx + d / 2 - 1 else (-1 if u + 0.5 < cx - d / 2 + 1 else 0)
                    dw = 1 if w + 0.5 > cy + d / 2 - 1 else (-1 if w + 0.5 < cy - d / 2 + 1 else 0)
                    if du or dw:
                        v.set(u + du, w + dw, mid, "CymbalGold")

    def cymbal(cx, cy, z, d):
        v.cyl(cx, cy, z, z, d, "CymbalGold")
        v.cyl(cx, cy, z + 1, z + 1, 3, "CymbalGold")                 # bell

    # bass drum on its side, Ø12, head facing the audience (-y)
    v.cyl(0, 6, -3, 3, 12, "DrumRed", axis="y")
    v.cyl(0, 6, -4, -4, 12, "ColumnWhite", axis="y")                 # kick head
    v.cyl(0, 6, -4, -4, 8, "CarpetRed", axis="y", inner=6)           # red ring logo
    v.cyl(0, 6, -4, -4, 4, "BeamBlack", axis="y")                    # port hole
    v.cyl(0, 6, -3, -3, 12, "CymbalGold", axis="y", inner=10)        # hoops
    v.cyl(0, 6, 3, 3, 12, "CymbalGold", axis="y", inner=10)
    for x in (-7, 6):                                                # side lugs and spurs
        for y in (-2, 0, 2):
            v.set(x, y, 6, "CymbalGold")
        v.line((x, -2, 3), (x, -4, 0), chrome)
    # rack toms on a mount rising out of the bass drum
    v.box(0, 1, 12, 0, 1, 13, chrome)
    v.box(-3, 1, 13, 3, 1, 13, chrome)
    drum(-4, 1.5, 14, 18, 7)
    drum(4, 1.5, 14, 18, 7)
    # snare (audience right is -x here) on its stand
    tripod(-10, 3, 10)
    drum(-10.5, 3.5, 11, 14, 8)
    # floor tom on three legs
    for lx, ly in ((7, 0), (13, 0), (10, 6)):
        v.box(lx, ly, 0, lx, ly, 6, chrome)
    drum(10, 3, 6, 13, 8)
    # cymbals: hi-hat pair, crash, ride (all with bells)
    tripod(-13, 5, 17)
    cymbal(-13, 5.5, 16, 5)
    cymbal(-13, 5.5, 18, 5)
    tripod(-8, 8, 21)
    cymbal(-8, 8.5, 22, 9)
    tripod(11, 8, 19)
    cymbal(10.5, 8.5, 20, 9)
    # throne
    v.box(0, 10, 0, 0, 10, 6, chrome)
    for dx, dy in ((-2, 0), (2, 0), (0, 2)):
        v.line((0, 10, 1), (dx, 10 + dy, 0), chrome)
    v.cyl(0.5, 10.5, 7, 8, 5, "StoolBlack")


@kit("guitar_on_stand", "stage", "S")
def guitar_on_stand(v):
    """Red double-cut electric guitar, face to the audience (-y), on a black A-frame stand (R03).
    v2: body 3 voxels thick with a darker rim, pickguard, 2-deep neck with fret markers, gold bridge, knobs
    and tuners; same 9 x 8 x 23 box as v1."""
    body, edge = "CarpetRed", "VelvetRed"
    rows = {2: (1, 7), 3: (0, 8), 4: (0, 8), 5: (0, 8), 6: (1, 7), 7: (1, 7), 8: (0, 8), 9: (0, 8)}
    for z, (a, b) in rows.items():
        v.box(a, 0, z, b, 2, z, edge)                                # side of the body
        v.box(a + 1, 0, z, b - 1, 0, z, body)                        # front face; the dark rim reads as thickness
    v.box(2, 0, 1, 6, 2, 1, edge)                                    # rounded bottom
    v.box(3, 0, 1, 5, 0, 1, body)
    for x in (0, 8):                                                 # double-cut horns
        v.box(x, 0, 10, x, 2, 11, edge)
        v.set(x, 0, 10, body)
    v.box(2, 0, 3, 3, 0, 7, "ColumnWhite")                           # pickguard
    v.box(4, 0, 2, 4, 0, 2, "CymbalGold")                            # tailpiece
    v.box(3, 0, 4, 5, 0, 4, "CymbalGold")                            # bridge
    v.box(3, 0, 5, 5, 0, 5, "StoolBlack")                            # pickups
    v.box(3, 0, 8, 5, 0, 8, "StoolBlack")
    v.set(6, 0, 3, "CymbalGold")                                     # knobs
    v.set(7, 0, 4, "CymbalGold")
    v.box(4, 0, 10, 4, 1, 19, "WoodMid")                             # neck, fretboard on the front
    v.box(4, 0, 10, 4, 0, 19, "WoodDark")
    for z in (12, 14, 16, 18):
        v.set(4, 0, z, "ColumnWhite")                                # fret markers
    v.box(3, 0, 20, 5, 1, 22, "WoodDark")                            # headstock
    for z in (20, 22):
        v.set(2, 1, z, "CymbalGold")                                 # tuners
        v.set(6, 1, z, "CymbalGold")
    v.box(0, 3, 0, 8, 3, 0, "BeamBlack")                             # stand base
    v.box(4, 3, 0, 4, 7, 0, "BeamBlack")                             # rear leg
    v.box(4, 3, 1, 4, 3, 15, "BeamBlack")                            # upright behind the neck
    v.box(3, 2, 15, 5, 2, 15, "BeamBlack")                           # neck yoke
    for x in (1, 7):
        v.box(x, 0, 0, x, 3, 0, "BeamBlack")                         # cradle arms under the body


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
    # v2 pattern (checked against R03): every tile a separate mirror value (dark / mid / light) so the ball reads
    # as a mosaic even unlit; reflections cluster instead of speckling: red on the stage side (-x) and below,
    # amber on the bar side (+x), a few white glints on top.
    def tile(p):
        h = zlib.crc32(("disco|%d,%d,%d" % p).encode()) % 100
        nx, ny, nz = ((p[i] + 0.5 - 7) / 7 for i in range(3))
        if nx < -0.35 and nz < 0.3 and h < 45:
            return E("SlatRed")
        if nx > 0.4 and ny < 0.2 and h < 30:
            return E("LampGold")
        if nz > 0.45 and h < 14:
            return E("White")
        if h < 4:
            return E("White")
        return ("MirrorDark", "MirrorGrey", "MirrorGrey", "MirrorLight")[h % 4]
    v.sphere((7, 7, 7), 14, tile)
    v.box(6, 6, 14, 7, 7, 23, "BeamBlack")
    v.box(5, 5, 24, 8, 8, 24, "BeamBlack")


@kit("stage_steps", "stage", "M")
def stage_steps(v):
    """1 m wide flight in front of the stage (front -y, rising to +y): two carpeted treads at 0.15 m and
    0.35 m, then the 0.5 m stage (platform 9 + carpet tile 1). Black risers, carpet nosing, amber step lights."""
    W = 20
    for i, (bottom, top) in enumerate(((0, 2), (3, 6))):              # tread top voxel; surfaces at 3 and 7
        y0 = i * 6
        v.box(0, y0, 0, W - 1, 11, top - 1, "BeamBlack")
        v.box(0, y0, top, W - 1, 11, top, "CarpetRed")
        v.box(0, y0, top - 1, W - 1, y0, top - 1, "CarpetRed")       # carpet wraps the nosing
        v.box(0, y0, 0, 0, 11, top - 1, "StoolBlack")                # lighter edge on the open sides
        v.box(W - 1, y0, 0, W - 1, 11, top - 1, "StoolBlack")
        for x in (2, W - 4):
            v.box(x, y0, bottom + 1, x + 1, y0, bottom + 1, E("ShelfAmber"))  # step lights set into the riser


TRUSS_L, TRUSS_S = 40, 6                                             # 2 m long, 0.3 m box section


@kit("truss_segment", "stage", "L", anchor="ceiling",
     note="2 m box truss along x; PAR lights hang under it: place a par_light_* origin at the truss origin minus height_m")
def truss_segment(v):
    """Black box truss (R01): four 1-voxel chords, zigzag lacing on all four faces, an end frame at each end,
    two drop pipes to the ceiling."""
    L, S = TRUSS_L, TRUSS_S
    for y in (0, S - 1):
        for z in (0, S - 1):
            v.box(0, y, z, L - 1, y, z, "BeamBlack")                 # chords
    for x in (0, L - 1):                                             # end frames
        v.box(x, 0, 0, x, S - 1, 0, "BeamBlack")
        v.box(x, 0, S - 1, x, S - 1, S - 1, "BeamBlack")
        v.box(x, 0, 0, x, 0, S - 1, "BeamBlack")
        v.box(x, S - 1, 0, x, S - 1, S - 1, "BeamBlack")
    for i, x in enumerate(range(0, L - 1, S - 1)):                   # lacing: zigzag diagonals between chords
        x1 = min(x + S - 1, L - 1)
        lo, hi = (0, S - 1) if i % 2 == 0 else (S - 1, 0)
        for y in (0, S - 1):
            v.line((x, y, lo), (x1, y, hi), "StoolBlack", keep=True)
        for z in (0, S - 1):
            v.line((x, lo, z), (x1, hi, z), "StoolBlack", keep=True)
    for x in (6, L - 7):
        v.box(x, 2, S, x + 1, 3, S + 3, "BeamBlack")                 # drop pipes to the ceiling


def par_light(v, lens):
    """Cube PAR can (R01, R03) hanging from a clamp: black can, lens facing the audience (-y) with a brighter
    2 x 2 core, U-yoke round the can. Origin at the clamp top."""
    v.box(2, 2, 10, 3, 3, 11, "StoolBlack")                          # clamp
    v.box(0, 2, 9, 5, 3, 9, "BeamBlack")                             # yoke top
    v.box(0, 2, 3, 0, 3, 8, "BeamBlack")                             # yoke arms
    v.box(5, 2, 3, 5, 3, 8, "BeamBlack")
    v.box(1, 0, 2, 4, 5, 8, "StoolBlack")                            # can
    v.box(1, -1, 2, 4, -1, 8, "BeamBlack")                           # lens bezel
    v.box(2, -1, 3, 3, -1, 7, E(lens))
    v.box(1, -1, 4, 4, -1, 6, E(lens))
    v.box(2, 6, 4, 3, 6, 6, "BeamBlack")                             # rear cap


@kit("par_light_red", "stage", "S", anchor="ceiling")
def par_light_red(v):
    par_light(v, "NeonRed")


@kit("par_light_amber", "stage", "S", anchor="ceiling", variant_of="par_light_red")
def par_light_amber(v):
    par_light(v, "ShelfAmber")


@kit("par_light_blue", "stage", "S", anchor="ceiling", variant_of="par_light_red")
def par_light_blue(v):
    par_light(v, "StageBlue")


@kit("stage_tree", "stage", "M")
def stage_tree(v):
    """The olive tree behind the drums (5843; R01): square black planter, grey bark trunk that forks into
    thin branches, an airy crown of small grey-green leaf clusters with gaps."""
    r = rng("stage_tree")
    P = 10                                                           # planter, centred on x, y = 0
    v.box(-5, -5, 0, 4, 4, 7, "StoolBlack")
    v.box(-5, -5, 7, 4, 4, 7, "BeamBlack")                           # rim
    v.box(-4, -4, 7, 3, 3, 7, "WoodDark")                            # soil
    v.box(-1, -1, 7, 0, 0, 24, "BarkGrey")                           # trunk 2 x 2
    v.line((0, 0, 14), (3, 1, 20), "BarkGrey")                       # a low side branch, like the photo
    tips = []
    forks = (((-1, 0, 24), (-8, -2, 36)), ((0, -1, 24), (7, -3, 38)), ((0, 0, 24), (2, 4, 44)),
             ((-1, -1, 24), (-4, 3, 42)), ((3, 1, 20), (10, 2, 30)))
    for a, b in forks:
        v.line(a, b, "BarkGrey")
        tips.append(b)
        mid = tuple((a[i] + b[i]) / 2 for i in range(3))
        twig = (b[0] + r.randint(-4, 4), b[1] + r.randint(-3, 3), b[2] + r.randint(-6, 2))
        v.line(mid, twig, "BarkGrey")
        tips.append(twig)
    for t in tips:                                                   # leaf clusters around every tip
        rad = (r.uniform(3.5, 5.0), r.uniform(3.0, 4.0), r.uniform(2.5, 3.5))

        def pick(cell, h):
            return "OliveLeaf" if h > 0.55 or r.random() < 0.25 else "OliveDark"
        v.blob(t, rad, pick, 0.42, r)
    for x, y, z in list(v.cells):                                    # nothing hangs below the planter rim
        if z < 9 and v.get(x, y, z) in ("OliveLeaf", "OliveDark"):
            v.remove(x, y, z)


@kit("pa_speaker", "stage", "S")
def pa_speaker(v):
    """Black PA cabinet (R01, R03): woofer ring and dust cap, horn above, dotted grille corners, lighter
    top edge, yoke bracket on top for hanging. Face to the audience (-y)."""
    W, D, H = 10, 8, 16
    v.box(0, 0, 0, W - 1, D - 1, H - 1, "StoolBlack")
    v.box(1, 0, 1, W - 2, 0, H - 2, "BeamBlack")                     # front baffle
    v.cyl(4.5, 5.5, 0, 0, 8, "FloorGrey", axis="y", inner=6)         # woofer surround (x, z disc on the front)
    v.cyl(4.5, 5.5, 0, 0, 2, "FloorGrey", axis="y")                  # dust cap
    v.box(3, 0, 11, 6, 0, 13, "FloorGrey")                           # horn mouth
    v.box(4, 0, 12, 5, 0, 12, "BeamBlack")                           # horn throat
    v.box(0, 0, H - 1, W - 1, 0, H - 1, "FloorGrey")                 # lighter top edge
    v.set(8, -1, 1, E("NeonRed"))                                    # power LED
    v.box(1, 3, H, 1, 4, H + 2, "BeamBlack")                         # yoke bracket
    v.box(W - 2, 3, H, W - 2, 4, H + 2, "BeamBlack")
    v.box(1, 3, H + 3, W - 2, 4, H + 3, "BeamBlack")


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
    """20 x 20 tile: leaf clusters on 1-voxel vines over a black backing, in three dark greens (lighter on top
    of each cluster), with gaps where the backing and vines show (R02). Clusters wrap at the tile edges so
    tiles butt up seamlessly. Same 20 x 6 x 20 box as v1 (leaves y -1..3, backing y 4)."""
    r = rng("plant_wall_tile")
    N = 20
    v.box(0, 4, 0, N - 1, 4, N - 1, "BeamBlack")
    for x0, z0, x1, z1 in ((2, 0, 7, 19), (13, 0, 10, 19), (0, 9, 19, 12)):  # vines, wrapping at the edges
        v.line((x0, 3, z0), (x1, 3, z1), "WoodDark")
    centres = []
    for _ in range(400):                                             # dart-throwing: clusters 4.5+ apart (torus)
        c = (r.uniform(0, N), r.uniform(0, N))
        if all(min(abs(c[0] - o[0]), N - abs(c[0] - o[0])) ** 2 + min(abs(c[1] - o[1]), N - abs(c[1] - o[1])) ** 2 > 20
               for o in centres):
            centres.append(c)
        if len(centres) == 12:
            break
    greens = ("PlantDark", "PlantGreen", "PlantMid")
    for i, (cx, cz) in enumerate(centres):
        g = i % 3
        rad = r.uniform(2.2, 3.2)
        bulge = 5 if i == 0 else r.choice((2, 3, 3, 4))              # stand-off from the wall; one at full depth
        for dx in range(-4, 5):
            for dz in range(-4, 5):
                d = (dx * dx + dz * dz) ** 0.5 / rad
                if d > 1.0 or r.random() < 0.18 * d:                  # ragged edge
                    continue
                x, z = int(cx + dx) % N, int(cz + dz) % N
                depth = max(1, round(bulge * (1 - d * d)))
                top = dz > rad * 0.3                                 # top-lit: upper leaves one green lighter
                low = dz < -rad * 0.4
                m = greens[min(2, g + 1)] if top else (greens[max(0, g - 1)] if low else greens[g])
                for k in range(depth):
                    v.set(x, 3 - k, z, m if k == depth - 1 else greens[max(0, g - 1)])


@kit("white_column", "lounge", "Architecture")
def white_column(v):
    """Square white-tile column, 8 x 8, floor to ceiling: 4 m / 80 voxels (v1 was 3.5 m)."""
    v.box(0, 0, 2, 7, 7, ROOM_H - 1, "ColumnWhite")
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


BANQ_D, BANQ_SEAT, BANQ_TOP = 12, 8, 22                              # depth, seat top voxel (0.45 m), back top (1.15 m)


def channels(v, cells_xy, along=0):
    """Channelled back face: velvet tubes 3 voxels wide, 1-voxel grooves recessed one voxel (5849, 5851; R02).
    The 4-voxel rhythm runs on the absolute coordinate, so modules tile without a seam."""
    for x, y in cells_xy:
        if (x, y)[along] % 4 == 3:
            v.clear_box(x, y, BANQ_SEAT + 1, x, y, BANQ_TOP - 1)
        else:
            v.box(x, y, BANQ_SEAT + 1, x, y, BANQ_TOP, "VelvetRed")


@kit("banquette_straight", "lounge", "L")
def banquette_straight(v):
    """Red velvet banquette, 1 m module along x, seat to the front (-y), back against the wall at +y.
    Recessed black plinth, Velvet Red cushion with a shadow seam, channelled back; modules tile along x."""
    W = 20
    v.box(0, 1, 0, W - 1, BANQ_D - 1, 1, "BeamBlack")                # plinth, 1 voxel recessed
    v.box(0, 0, 2, W - 1, 8, BANQ_SEAT, "VelvetRed")                 # seat cushion
    v.box(0, 0, 2, W - 1, 0, 2, "VelvetShadow")                      # seam under the cushion nose
    v.box(0, 9, 2, W - 1, BANQ_D - 1, BANQ_TOP, "VelvetShadow")      # back
    channels(v, [(x, 9) for x in range(W)])


@kit("banquette_corner", "lounge", "L", variant_of="banquette_straight")
def banquette_corner(v):
    """Inside corner, 12 x 12: backs on +y and +x. Joins a straight run on its -x side (backs aligned) and
    a straight run rotated -90 deg about the vertical axis (back to +x) on its -y side."""
    D = BANQ_D
    v.box(0, 0, 0, D - 1, D - 1, 1, "BeamBlack")                     # plinth (no open front: both runs join it)
    v.box(0, 0, 2, 8, 8, BANQ_SEAT, "VelvetRed")
    v.box(0, 9, 2, D - 1, D - 1, BANQ_TOP, "VelvetShadow")           # back along +y
    v.box(9, 0, 2, D - 1, D - 1, BANQ_TOP, "VelvetShadow")           # back along +x
    channels(v, [(x, 9) for x in range(9)])
    channels(v, [(9, y) for y in range(9)], along=1)


@kit("ac_unit", "lounge", "S", mount="wall", mount_height_m=2.9)
def ac_unit(v):
    """Wall split AC (R02): off-white body, dark louvre slot under the front, small cyan status light."""
    W, D, H = 18, 5, 6
    v.box(0, 0, 1, W - 1, D - 1, H - 1, "PlasticWhite")
    v.box(1, 1, 0, W - 2, D - 1, 0, "PlasticWhite")                  # body tapers into the louvre
    v.box(1, 0, 0, W - 2, 0, 1, "BeamBlack")                         # louvre slot
    v.box(2, 0, 1, W - 3, 0, 1, "FloorGrey")                         # louvre blade
    v.box(0, 0, H - 1, W - 1, 0, H - 1, "ColumnWhite")               # lighter top edge
    v.set(W - 3, -1, 3, E("ScreenCyan"))                             # status light


@kit("wall_lamp", "lounge", "S", mount="wall", mount_height_m=1.8)
def wall_lamp(v):
    """Red disc wall lamp (R02; 5843-5845 disc lamps): Ø9 black rim, Neon Red glowing face, warm 3 x 3 bulb
    proud in the centre, short arm to a wall plate. Face to the room (-y)."""
    v.cyl(4.5, 4.5, 0, 1, 9, "BeamBlack", axis="y", inner=7)        # rim (x, z disc)
    v.cyl(4.5, 4.5, 1, 1, 7, E("NeonRed"), axis="y")                 # glowing face
    v.cyl(4.5, 4.5, 0, 0, 3, E("LampGold"), axis="y")                # bulb
    v.box(4, 2, 4, 4, 2, 4, "BeamBlack")                             # arm
    v.box(3, 3, 3, 5, 3, 5, "BeamBlack")                             # wall plate


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


def floor_tile(v, seed):
    """1 m concrete floor tile, one voxel thick: Floor Grey with soft paler and darker patches (value noise on
    a 5-voxel lattice that wraps at 20, so tiles butt up seamlessly), plus a few loose dark flecks."""
    N, C = 20, 5
    r = rng(seed)
    lat = [[r.random() for _ in range(N // C)] for _ in range(N // C)]

    def noise(x, z):
        gx, gz = x / C, z / C
        i, j = int(gx), int(gz)
        fx, fz = gx - i, gz - j
        fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
        a, b = lat[i % 4][j % 4], lat[(i + 1) % 4][j % 4]
        c, d = lat[i % 4][(j + 1) % 4], lat[(i + 1) % 4][(j + 1) % 4]
        return (a * (1 - fx) + b * fx) * (1 - fz) + (c * (1 - fx) + d * fx) * fz
    for x in range(N):
        for z in range(N):
            n = noise(x, z)
            m = "FloorDeep" if n < 0.32 else ("FloorPale" if n > 0.68 else "FloorGrey")
            if r.random() < 0.03:
                m = "FloorDeep"
            v.set(x, z, 0, m)


@kit("floor_tile_a", "circulation", "Architecture")
def floor_tile_a(v):
    floor_tile(v, "floor_tile_a")


@kit("floor_tile_b", "circulation", "Architecture", variant_of="floor_tile_a")
def floor_tile_b(v):
    floor_tile(v, "floor_tile_b")


# ------------------------------------------------------------------ review .blend

BLEND = os.path.join(REPO, "blender", "BlackCabinKit.blend")
ZONE_ORDER = ("tables", "bar", "stage", "lounge", "circulation")   # front row (camera side) first
REVIEW_GAP = 0.5
REVIEW_MAX_W = 9.0


def label_material():
    m = bpy.data.materials.new("Label")
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.8, 0.75, 0.7, 1.0)
    bsdf.inputs["Emission Color"].default_value = (0.8, 0.75, 0.7, 1.0)
    bsdf.inputs["Emission Strength"].default_value = 0.6
    return m


def review_light(coll, name, kind, loc, energy, color, rot=None, size=None):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = color
    if size is not None:
        ld.shadow_soft_size = size
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    if rot:
        lo.rotation_euler = rot
    coll.objects.link(lo)


def build_review(objects, manifest, path=BLEND):
    """Lay the kit out on a labelled grid, one collection per zone, and save a review .blend."""
    from mathutils import Vector
    scene = bpy.context.scene
    scene.name = "Black Cabin Kit"
    lab_mat = label_material()
    by_zone = {}
    for o in manifest:
        by_zone.setdefault(o["zone"], []).append(o)
    y, widest = 0.0, 0.0
    for zone in ZONE_ORDER:
        if zone not in by_zone:
            continue
        coll = bpy.data.collections.new(zone)
        scene.collection.children.link(coll)
        lines, w = [[]], 0.0
        for o in by_zone[zone]:                                      # wrap long zones onto extra lines
            if w and w + o["footprint_m"][0] > REVIEW_MAX_W:
                lines.append([])
                w = 0.0
            lines[-1].append(o)
            w += o["footprint_m"][0] + REVIEW_GAP
        for line in lines:
            depth = max(o["footprint_m"][1] for o in line)
            width = sum(o["footprint_m"][0] for o in line) + REVIEW_GAP * (len(line) - 1)
            widest = max(widest, width)
            y += depth / 2 + 0.35                                    # room for the labels in front
            x = -width / 2
            for o in line:
                ob = objects[o["name"]]
                for c in list(ob.users_collection):
                    c.objects.unlink(ob)
                coll.objects.link(ob)
                x += o["footprint_m"][0] / 2
                ob.location = (x, y, o["height_m"] + 0.3 if o["anchor"] == "ceiling" else 0.0)
                cu = bpy.data.curves.new(o["name"] + "_label", "FONT")
                cu.body = o["name"]
                cu.size = 0.09
                cu.align_x = "CENTER"
                cu.materials.append(lab_mat)
                lab = bpy.data.objects.new(o["name"] + "_label", cu)
                lab.location = (x, y - o["footprint_m"][1] / 2 - 0.15, 0.002)
                coll.objects.link(lab)
                x += o["footprint_m"][0] / 2 + REVIEW_GAP
            y += depth / 2
        y += 0.8
    span = Vector((widest + 3.0, y + 3.0))
    centre = Vector((0.0, y / 2, 0.0))

    setup = bpy.data.collections.new("review_setup")
    scene.collection.children.link(setup)
    me = bpy.data.meshes.new("Floor")
    hx, hy = span.x / 2, span.y / 2
    me.from_pydata([(-hx, -hy, 0), (hx, -hy, 0), (hx, hy, 0), (-hx, hy, 0)], [], [(0, 1, 2, 3)])
    me.materials.append(material("FloorGrey"))
    fl = bpy.data.objects.new("Floor", me)
    fl.location = (centre.x, centre.y, -0.001)
    setup.objects.link(fl)

    world = bpy.data.worlds.new("CabinDark")
    world.use_nodes = True
    dark = hex_linear(PALETTE["CabinDark"][0])
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (*dark, 1.0)
    world.color = dark
    scene.world = world
    review_light(setup, "WarmKey", "SUN", (0, 0, 10), 1.6, (1.0, 0.72, 0.5), rot=(math.radians(45), 0, math.radians(25)))
    review_light(setup, "RedFill", "SUN", (0, 0, 10), 0.4, (1.0, 0.15, 0.1), rot=(math.radians(60), 0, math.radians(200)))
    for i in range(3):                                               # warm pools along the grid
        review_light(setup, "Pool%d" % i, "POINT", ((i - 1) * widest / 3, centre.y, 2.6), 400.0, (1.0, 0.7, 0.4), size=0.5)

    cam = bpy.data.objects.new("ReviewCamera", bpy.data.cameras.new("ReviewCamera"))
    cam.data.lens = 30
    cam.data.clip_end = 500.0
    dist = max(span.x * 0.8, span.y * 1.15)
    aim = Vector((0.0, y * 0.42, 0.5))                               # a little in front of centre: tall rows are at the back
    cam.location = aim + Vector((0.0, -dist * 0.75, dist * 0.7))
    cam.rotation_euler = (aim - cam.location).to_track_quat("-Z", "Y").to_euler()
    setup.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 1920, 1080

    for screen in bpy.data.screens:                                  # headless: no windows, edit the saved screens
        for area in screen.areas:
            for sp in area.spaces:
                if sp.type != "VIEW_3D":
                    continue
                sp.shading.type = "MATERIAL"
                sp.shading.use_scene_world = True
                sp.shading.use_scene_lights = True
                sp.clip_end = 500.0
                if sp.region_3d:
                    sp.region_3d.view_perspective = "CAMERA"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
    print("BC_KIT review blend -> %s (%.1f MB)" % (path, os.path.getsize(path) / 1e6))


# ------------------------------------------------------------------ run

def run(only=None, out=OUT, blend=True):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    manifest = []
    objects = {}
    names = [k[0] for k in KIT]
    assert len(names) == len(set(names)), "duplicate kit names"
    for name, zone, size_class, anchor, fn, extra in KIT:
        if only and name not in only:
            continue
        v = Vox()
        fn(v)
        ob, st = build_mesh(name, v, anchor)
        objects[name] = ob
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
            "tris_unmerged": st["tris_unmerged"],
            **extra,
        })
        print("BC_KIT %-20s %-12s %-12s vox=%-6d tris=%-6d (unmerged %-6d) size=%s"
              % (name, zone, size_class, st["voxels"], st["tris"], st["tris_unmerged"], st["size_vox"]))
    if not only:
        with open(os.path.join(out, "manifest.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump({"voxel_m": VOX, "front": "+Z (Godot) / -Y (Blender)", "objects": manifest}, f, indent=1)
            f.write("\n")
    print("BC_KIT done: %d objects -> %s" % (len(manifest), out))
    if blend and not only:
        build_review(objects, manifest)
    return manifest


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = None
    out = OUT
    if "--out" in argv:                                              # write somewhere else (tests); no .blend
        out = os.path.abspath(argv[argv.index("--out") + 1])
        argv.append("--no-blend")
    if "--only" in argv:
        only = set(argv[argv.index("--only") + 1].split(","))
    run(only, out=out, blend="--no-blend" not in argv)
