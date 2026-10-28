"""Black Cabin Tamagotchi - voxel character kit generator (v2, renders 05/06 parity).

Builds chibi voxel characters from swappable parts (art bible section 7, cast bible docs/design/03-cast.md),
rigs them to one shared armature with elbows and knees, writes the animations as actions, and exports:
  game/assets/chars/presets/<name>.glb     every named preset (regulars, staff, house band, 24 patrons)
  game/assets/chars/parts/parts_<body>.glb every part for one body type on one armature (runtime assembly)
  game/assets/chars/manifest.json          presets (role, parts, colours, height, animations) and the part list
A full run also saves blender/BlackCabinChars.blend (presets on a labelled grid, every animation on stand-in
furniture, a parts lineup, lights, camera, Material Preview) and renders docs/art/chars-showcase.png.

Run headless from the repo root:
    blender --background --factory-startup --python tools/blender/bc_chars.py -- --no-review
    blender --background --factory-startup --python tools/blender/bc_chars.py -- --only tong,nam --no-blend
`--no-review` skips the combined blender/BlackCabin.blend (bc_review.py), which a full run rebuilds last;
`--no-render` keeps the .blend but skips the PNG; `--review-only` rebuilds just the .blend and the PNG. `--only` runs
never write the manifest, libraries or .blend.

Reuses bc_kit (imported, never edited): the voxel scale, the face tables, per-voxel jitter, the seam texture and
the material builder. Character swatches are registered into bc_kit.PALETTE at run time under slot-prefixed keys
(`top__Mustard`), so every material is named <slot>__<Swatch> and the game can find and recolour it.

MEASUREMENTS (renders 05/06 at their own camera, ~35-40 deg elevation; full table in docs/art/screens/chars/README.md)
  Standing figure ~30 voxels (the render's voxel is ~6 px on a 178 px server, R05).
  Head + hair 29-35 % of the height (R05 server 29 %, R05 front guitarist 33 %, R06 blonde guitarist 34 %);
  torso shoulder-to-crotch 32-36 %; legs 33-36 %. Head + hair as wide as the shoulders (arms included);
  arms ~2.5 voxels thick; hair overhangs the head by 1-2 voxels and rises 2-3 voxels in clumps.
  Faces: dark 1 x 2 eyes, brows in relief, beards and moustaches in relief, mouth rarely visible.
  Seated: thighs level on the seat, shins down, the table top at chest height; forearms flat on the table with a
  glass in hand. Server: vest over a white shirt, tray at chest height on a forward forearm.
So, in voxels (1 voxel = 5 cm in this file; the venue draws figures at FIG_SCALE 0.75, 3.75 cm on screen):
  regular  legs 11 (thigh 6, shin 3, shoe 2) + pelvis 2 + chest 9 + head 7 + hair 1-2 = 30-31 (1.13-1.16 m drawn),
           head + hair 8-9 of 31 = 27-30 % (9- and 8-row heads measured 37-43 % against the 05 server's 27-29 %)
  head 8 W x 7 D x 7 H on an 8 x 5 torso, arms 3 x 3 (upper 4, forearm 4, hand 2; hands hang at the hips)
  petite   legs 10, chest 8;   broad  torso 10 x 6, chest 10.

Rig: root, hips, spine, head, arm_L, forearm_L, arm_R, forearm_R, leg_L, shin_L, leg_R, shin_R. Every bone points
up (+Z) with roll 0, so every bone's rest frame equals the world frame in glTF/Godot. Parts are skinned rigidly:
each voxel belongs to exactly one bone (weight 1.0). Character left = +X; front = -Y in Blender, +Z in Godot.
"""
import json
import math
import os
import sys
import zlib

import bpy
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.path.join(os.getcwd(), "tools", "blender")
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import bc_kit as K                                                   # noqa: E402

VOX = K.VOX
OUT = os.path.join(K.REPO, "game", "assets", "chars")
BLEND = os.path.join(K.REPO, "blender", "BlackCabinChars.blend")
SHOWCASE = os.path.join(K.REPO, "docs", "art", "chars-showcase.png")
FPS = 24
FIG_SCALE = 0.75               # the venue draws every figure at this scale (venue_patrons.gd FIG_SCALE)
SEAT_VOX = 9                   # seated poses put the thigh undersides here: 0.45 m at scale 1, the seat at 0.8
TABLE_VOX = SEAT_VOX + 0.30 / (VOX * FIG_SCALE)    # cafe table (0.75) and bar top (1.1) are 0.30 m above their seats
DECAL_EPS = 0.0015             # eye and mouth pixels float this far in front of the head

# ------------------------------------------------------------------ swatches
SKIN = {
    "Skin1": "#F0D2B6", "Skin2": "#E4BA96", "Skin3": "#D2A07A", "Skin4": "#BC8860",
    "Skin5": "#A06E4A", "Skin6": "#845636", "Skin7": "#6A432C", "Skin8": "#4E3022",
}
HAIR = {
    "HairBlack": "#1E1616", "HairDarkBrown": "#3E2618", "HairBrown": "#6A4228", "HairAuburn": "#8E3A1E",
    "HairBleach": "#E8CF86", "HairGrey": "#8E8890", "HairWhite": "#E4E0DC", "HairRose": "#B05A64",
    "HairGinger": "#C0602A",
}
WARDROBE_BIBLE = ("CabinDark", "StoolBlack", "FloorGrey", "FloorLit", "ColumnWhite", "VelvetRed", "DrumRed",
                  "CymbalGold", "TableWoodLit", "WoodMid", "WoodDark", "PlantGreen")
WARDROBE_ADDED = {
    "Cream": "#D9C9A6", "Sand": "#B49A76", "Stone": "#7C7270", "Charcoal": "#403A3E",
    "Denim": "#3F5878", "DenimLight": "#6C88A8", "Sky": "#86A8C6", "Teal": "#2F6B6A",
    "Olive": "#66703A", "Moss": "#4C5A30", "Mustard": "#C99430", "Rust": "#A04A26",
    "Jacket": "#3A3444", "ShirtWhite": "#ECE6E0", "DressRed": "#B0141C", "Leather": "#5A3020",
}
FACE = {"Ink": "#120808", "Mouth": "#6A2420", "Blush": "#E0786E", "Lens": "#2A1E1A", "Beer": "#E8A23A"}
ROUGH = {"skin": 0.55, "hair": 0.6, "eyes": 0.3, "mouth": 0.5, "blush": 0.6, "lens": 0.1}


def hexof(sw):
    sw = sw[:-len("_emissive")] if sw.endswith("_emissive") else sw
    for table in (SKIN, HAIR, WARDROBE_ADDED, FACE):
        if sw in table:
            return table[sw]
    return K.PALETTE[sw][0]


def mat_key(m):
    return "%s__%s" % m


def material(m):
    """m = (slot, swatch). Registers <slot>__<swatch> in bc_kit.PALETTE and builds it with bc_kit.material.
    A swatch ending in _emissive keeps bc_kit's emission strength (lit beer)."""
    key = mat_key(m)
    slot, sw = m
    emissive = sw.endswith("_emissive")
    base_sw = sw[:-len("_emissive")] if emissive else sw
    base_key = "%s__%s" % (slot, base_sw)
    if base_key not in K.PALETTE:
        if base_sw in K.PALETTE and base_sw not in SKIN:
            _, rough, metal, strength = K.PALETTE[base_sw]
            rough = max(rough, 0.5) if slot in ("top", "bottom", "top_trim", "bottom_trim") else rough
        else:
            rough, metal, strength = ROUGH.get(slot, 0.85), 0.0, 0
        K.PALETTE[base_key] = (hexof(base_sw), rough, metal, strength if emissive else 0)
    return K.material(K.E(base_key) if emissive else base_key)


# ------------------------------------------------------------------ bodies, bones

BODIES = {   # torso width/depth, leg rows (incl. 2 shoe rows), chest rows; pelvis is always 2 rows
    "petite":  dict(tw=8, td=5, leg=10, chest=8),
    "regular": dict(tw=8, td=5, leg=11, chest=9),
    "broad":   dict(tw=10, td=6, leg=11, chest=10),
}
HEAD_W, HEAD_D, HEAD_H = 8, 7, 7
HX0, HX1, HY0, HY1 = -4, 3, -3, 3
BONES = ("root", "hips", "spine", "head", "arm_L", "forearm_L", "arm_R", "forearm_R",
         "leg_L", "shin_L", "leg_R", "shin_R")
PARENT = {"hips": "root", "spine": "hips", "head": "spine", "arm_L": "spine", "arm_R": "spine",
          "forearm_L": "arm_L", "forearm_R": "arm_R", "leg_L": "hips", "leg_R": "hips",
          "shin_L": "leg_L", "shin_R": "leg_R"}


def dims(body):
    d = dict(BODIES[body])
    d["body"] = body
    d["h"] = d["leg"] + 2 + d["chest"]                  # head sits on this row
    d["x0"], d["x1"] = -d["tw"] // 2, d["tw"] // 2 - 1
    d["y0"] = -(d["td"] // 2)
    d["y1"] = d["y0"] + d["td"] - 1
    d["az0"] = d["h"] - d["chest"] - 1                  # bottom row of the hands (hands are 2 rows, at the hips)
    d["up"] = d["chest"] // 2                           # upper arm rows
    d["elbow"] = d["h"] - d["up"]                       # first row of the upper arm
    d["knee"] = d["leg"] // 2                           # first row of the thigh
    d["arm_L"] = (d["x1"] + 1, d["x1"] + 3)
    d["arm_R"] = (d["x0"] - 3, d["x0"] - 1)
    d["leg_L"] = (1, d["x1"])
    d["leg_R"] = (d["x0"], -2)
    d["T"] = d["h"] + HEAD_H - 1                        # top row of the head
    return d


def bone_heads(D):
    """Pivot of every bone, in voxels (x, y, z), on cell boundaries (cell x spans x..x+1)."""
    h = D["h"]
    aL = (D["arm_L"][0] + D["arm_L"][1] + 1) / 2
    aR = (D["arm_R"][0] + D["arm_R"][1] + 1) / 2
    lL = (D["leg_L"][0] + D["leg_L"][1] + 1) / 2
    lR = (D["leg_R"][0] + D["leg_R"][1] + 1) / 2
    return {
        "root": (0, 0, 0), "hips": (0, 0, D["leg"]), "spine": (0, 0, D["leg"] + 2), "head": (0, 0, h),
        "arm_L": (aL, 0.5, h - 0.5), "arm_R": (aR, 0.5, h - 0.5),
        "forearm_L": (aL, 0.5, D["elbow"]), "forearm_R": (aR, 0.5, D["elbow"]),
        "leg_L": (lL, 0, D["leg"]), "leg_R": (lR, 0, D["leg"]),
        "shin_L": (lL, 0, D["knee"]), "shin_R": (lR, 0, D["knee"]),
    }


ARMS = ("L", "R")
ARM_Y = (-1, 1)
LEG_Y = (-2, 1)


# ------------------------------------------------------------------ parts

class Part:
    """Voxels (x, y, z) -> ((slot, swatch), bone), plus face decals (front-facing quads). Same axes as bc_kit.Vox."""

    def __init__(self, pid, slot):
        self.pid, self.slot = pid, slot
        self.cells = {}
        self.decals = []

    def set(self, x, y, z, m, bone):
        self.cells[(int(x), int(y), int(z))] = (m, bone)

    def box(self, xr, yr, zr, m, bone, keep=None):
        for x in range(min(xr), max(xr) + 1):
            for y in range(min(yr), max(yr) + 1):
                for z in range(min(zr), max(zr) + 1):
                    if keep is None or keep(x, y, z):
                        self.cells[(x, y, z)] = (m, bone)

    def decal(self, x, z, m, bone="head", y=HY0):
        self.decals.append((x, y, z, m, bone))

    def empty(self):
        return not self.cells and not self.decals


def mirror(x):
    return -1 - x


# ---- head shapes: all inside the 8 x 7 x 7 box, so every hair, hat and face fits every head
HEADS = ("square", "round", "soft", "heart")


def build_head(shape, D, C):
    p = Part("head_" + shape, "head")
    Z = D["h"]
    for x in range(HX0, HX1 + 1):
        for y in range(HY0, HY1 + 1):
            for z in range(HEAD_H):
                ex, ey, top = x in (HX0, HX1), y in (HY0, HY1), z == HEAD_H - 1
                if shape == "round" and ((ex and ey) or (top and (ex or ey))):
                    continue
                if shape == "soft" and top and (ex or ey):
                    continue
                if shape == "heart" and ((z <= 1 and ex) or (z == 0 and x in (HX0 + 1, HX1 - 1))):
                    continue
                p.set(x, y, Z + z, ("skin", C["skin"]), "head")
    p.set(-1, HY0 - 1, Z + 2, ("skin", C["skin"]), "head")                 # nose: one voxel of relief
    p.set(0, HY0 - 1, Z + 2, ("skin", C["skin"]), "head")
    return p


# ---- face. Eyes and mouth are pixel decals on the front plane; brows are voxels in relief (they read from the
# high camera as a dark line over the eyes, as in 05/06). Offsets are (dx, dz) for the left eye (+X); mirrored.
EYE_X, EYE_Z, BROW_Z, MOUTH_Z, BLUSH_Z = 1, 3, 5, 1, 2
EYES = {
    "dot":    [(0, 0), (0, 1)],
    "wide":   [(0, 0), (1, 0), (0, 1), (1, 1)],
    "sleepy": [(0, 0), (1, 0)],
    "happy":  [(0, 1), (1, 0)],
    "lashes": [(0, 0), (0, 1), (1, 1)],
}
BROWS = {
    "none":    [],
    "flat":    [(0, 0), (1, 0)],
    "arched":  [(0, 0), (1, 1), (2, 0)],
    "worried": [(0, 1), (1, 0), (2, 0)],
    "thick":   [(0, 0), (1, 0), (2, 0)],
}
MOUTHS = {     # absolute x (symmetric about the centre line), dz
    "smile": [(-2, 1), (-1, 0), (0, 0), (1, 1)],
    "small": [(-1, 0), (0, 0)],
    "flat":  [(-2, 0), (-1, 0), (0, 0), (1, 0)],
    "open":  [(-1, 0), (0, 0), (-1, -1), (0, -1)],
    "grin":  [(-3, 1), (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 1)],
}


def build_eyes(v, D, C):
    p = Part("eyes_" + v, "eyes")
    for dx, dz in EYES[v]:
        x = EYE_X + dx
        p.decal(x, D["h"] + EYE_Z + dz, ("eyes", C["eyes"]))
        p.decal(mirror(x), D["h"] + EYE_Z + dz, ("eyes", C["eyes"]))
    return p


def build_brows(v, D, C):
    p = Part("brows_" + v, "brows")
    for dx, dz in BROWS[v]:
        x = EYE_X + dx
        for xx in (x, mirror(x)):
            p.set(xx, HY0 - 1, D["h"] + BROW_Z + dz, ("hair", C["hair"]), "head")
    return p


def build_blush(D, C):
    p = Part("blush", "blush")
    for dx in (0, 1):
        x = EYE_X + dx
        p.decal(x, D["h"] + BLUSH_Z, ("blush", C["blush"]))
        p.decal(mirror(x), D["h"] + BLUSH_Z, ("blush", C["blush"]))
    return p


def build_mouth(v, D, C):
    p = Part("mouth_" + v, "mouth")
    for x, dz in MOUTHS[v]:
        p.decal(x, D["h"] + MOUTH_Z + dz, ("mouth", C["mouth"]))
    return p


# ---- hair. T = top row of the head; hair adds a cap above it and may rise up to 5. Below the head (z < Z) long
# hair only falls behind the shoulders (y >= 2), so it never cuts through the arms.
HAIRS = ("shaggy", "wavy", "afro", "curly", "long", "bob", "crop", "buzz", "bun", "quiff", "ponytail", "side_part",
         "swept", "spiky", "sideburns", "chignon")


def build_hair(style, D, C):
    p = Part("hair_" + style, "hair")
    m = ("hair", C["hair"])
    Z, T = D["h"], D["T"]

    def b(xr, yr, zr, keep=None):
        def k2(x, y, z):
            if z < Z and y < 2:
                return False
            return keep is None or keep(x, y, z)
        p.box(xr, yr, zr, m, "head", k2)

    def cap(over=1):
        b((HX0 - over, HX1 + over), (HY0 - over, HY1 + over), (T + 1, T + 1))

    def sides(zlo, ylo=HY0):
        b((HX0 - 1, HX0 - 1), (ylo, HY1 + 1), (zlo, T))
        b((HX1 + 1, HX1 + 1), (ylo, HY1 + 1), (zlo, T))

    def back(zlo):
        b((HX0, HX1), (HY1 + 1, HY1 + 1), (zlo, T))

    def fringe(zlo, xr=(HX0, HX1)):
        b(xr, (HY0 - 1, HY0 - 1), (max(zlo, Z + BROW_Z + 1), T))

    def lumpy(x0, x1, y0, y1, z, seed, chance=0.55):
        """One irregular layer of 2 x 2 tufts (renders 05/06 hair reads as clumps, not a flat cap)."""
        for x in range(x0, x1 + 1, 2):
            for y in range(y0, y1 + 1, 2):
                if zlib.crc32(("%s%d,%d,%d" % (seed, x, y, z)).encode()) % 100 < chance * 100:
                    b((x, min(x + 1, x1)), (y, min(y + 1, y1)), (z, z))

    def jagged(zlo, seed):
        for x in range(HX0, HX1 + 1):
            if zlib.crc32(("%s%d" % (seed, x)).encode()) % 3 == 0:
                b((x, x), (HY0 - 1, HY0 - 1), (Z + BROW_Z + 1, zlo))

    if style == "shaggy":
        # 05/06, the most common look: a thick messy mop over the ears, jagged fringe, clumps on top
        b((HX0 - 1, HX1 + 1), (HY0 - 1, HY1 + 1), (T + 1, T + 1))
        lumpy(HX0 - 1, HX1 + 1, HY0 - 1, HY1 + 1, T + 2, "shag", 0.45)
        b((HX0 - 2, HX0 - 1), (HY0, HY1 + 1), (Z + 3, T))
        b((HX1 + 1, HX1 + 2), (HY0, HY1 + 1), (Z + 3, T))
        b((HX0 - 1, HX1 + 1), (HY1 + 1, HY1 + 2), (Z + 1, T))
        fringe(T - 1)
        jagged(T - 2, "fr")
    elif style == "wavy":
        # long voluminous waves past the shoulders (05: the blonde patrons, the ginger at the bar)
        b((HX0 - 1, HX1 + 1), (HY0 - 1, HY1 + 1), (T + 1, T + 1))
        lumpy(HX0, HX1, HY0, HY1 + 1, T + 2, "wave")
        for side, x0, x1 in ((-1, HX0 - 3, HX0 - 1), (1, HX1 + 1, HX1 + 3)):
            for z in range(Z - 4, T + 1):
                flare = 1 if (z - Z) % 4 in (0, 1) else 0             # the wave: in and out every 2 rows
                xa, xb = (x0 + 1 - flare, x1) if side < 0 else (x0, x1 - 1 + flare)
                b((xa, xb), (HY0 + 1, HY1 + 2), (z, z))
        b((HX0 - 1, HX1 + 1), (HY1 + 1, HY1 + 2), (Z - 4, T))
        b((HX0 + 1, HX1 - 1), (2, HY1 + 2), (Z - 5, Z - 1))
        fringe(T - 1, (HX0, -1)); fringe(T, (0, HX1))
        jagged(T - 1, "wv")
    elif style == "afro":
        cz = T - 1.0
        head = set((x, y, z) for x in range(HX0, HX1 + 1) for y in range(HY0, HY1 + 1) for z in range(Z, T + 1))

        def keep(x, y, z):
            if (x, y, z) in head:
                return False
            if y < HY0 and z < T - 1:
                return False
            d = ((x + 0.5) / 6.8) ** 2 + ((y + 0.5) / 6.6) ** 2 + ((z + 0.5 - cz) / 5.0) ** 2
            if d > 1.0:
                return False
            return d < 0.84 or zlib.crc32(("afro%d,%d,%d" % (x, y, z)).encode()) % 3 > 0   # tufted edge
        b((HX0 - 4, HX1 + 4), (HY0 - 3, HY1 + 4), (T - 6, T + 6), keep)
    elif style == "curly":
        cz = T - 1.5
        head = set((x, y, z) for x in range(HX0, HX1 + 1) for y in range(HY0, HY1 + 1) for z in range(Z, T + 1))

        def keep(x, y, z):
            if (x, y, z) in head:
                return False
            if y < HY0 and z < T - 1:
                return False                                         # keep the face clear
            d = ((x + 0.5) / 6.0) ** 2 + ((y + 0.5) / 5.8) ** 2 + ((z + 0.5 - cz) / 4.6) ** 2
            return d <= 1.0 and (d < 0.8 or zlib.crc32(("cu%d,%d,%d" % (x, y, z)).encode()) % 4 > 0)
        b((HX0 - 2, HX1 + 2), (HY0 - 2, HY1 + 2), (T - 5, T + 4), keep)
    elif style == "long":
        cap(); sides(Z - 4); back(Z - 4); fringe(T - 1)
        b((HX0 - 1, HX1 + 1), (HY1, HY1 + 1), (Z - 5, Z - 1))              # falls behind the shoulders
        b((HX0 + 1, HX1 - 1), (HY0, HY1), (T + 2, T + 2))
    elif style == "crop":
        cap(); sides(T - 3); back(Z + 2); fringe(T - 1)
        lumpy(HX0, HX1, HY0, HY1, T + 2, "crop", 0.45)
    elif style == "buzz":
        cap(0)
    elif style == "bob":
        cap(); sides(Z + 1); back(Z + 1); fringe(T - 2)
        b((HX0 - 2, HX0 - 2), (HY0, HY1 + 1), (Z + 1, Z + 2))       # flared ends
        b((HX1 + 2, HX1 + 2), (HY0, HY1 + 1), (Z + 1, Z + 2))
        b((HX0, HX1), (HY0, HY1), (T + 2, T + 2))
    elif style == "bun":
        cap(); sides(T - 2); back(Z + 2); fringe(T)
        b((-2, 1), (-1, 2), (T + 2, T + 4))
    elif style == "quiff":
        cap(); sides(T - 2); back(Z + 2)
        b((-4, 3), (HY0 - 1, HY0 + 1), (T + 2, T + 4))
        b((-4, 3), (HY0 + 2, HY0 + 4), (T + 2, T + 3))
        b((-4, 3), (HY0 + 5, HY0 + 6), (T + 2, T + 2))
        b((-4, 3), (HY0 - 2, HY0 - 2), (T + 3, T + 4))              # the quiff leans forward
    elif style == "ponytail":
        cap(); sides(T - 4); back(Z + 2); fringe(T - 1)
        b((-2, 1), (HY1 - 1, HY1 + 1), (T + 2, T + 3))              # high tie at the crown
        b((-1, 0), (HY1 + 2, HY1 + 3), (Z - 2, T + 3))              # tail down the back
    elif style == "side_part":
        cap(); sides(T - 3); back(Z + 2)
        b((-1, HX1 + 1), (HY0 - 1, HY1), (T + 2, T + 2))            # volume on the left of the part
        fringe(T - 2, (0, HX1)); fringe(T, (HX0, -1))               # swept fringe, longer on one side
    elif style == "swept":
        b((HX0, HX1), (HY0 + 2, HY1 + 1), (T + 1, T + 1))           # forehead stays bare
        sides(T - 3, HY0 + 3); back(Z + 2)
        b((HX0 + 1, HX1 - 1), (HY1 - 3, HY1), (T + 2, T + 2))
    elif style == "spiky":
        cap(); sides(T - 2); back(Z + 2); fringe(T)
        for x in range(HX0, HX1 + 1, 3):
            for y in range(HY0, HY1 + 1, 3):
                hgt = 2 + zlib.crc32(("spike%d,%d" % (x, y)).encode()) % 2
                b((x, x + 1), (y, y + 1), (T + 2, T + 1 + hgt))
    elif style == "sideburns":
        cap(); sides(T - 2, HY0 + 3); back(Z + 2)
        b((HX0 - 1, HX0 - 1), (HY0 + 1, HY0 + 2), (Z + 2, T))
        b((HX1 + 1, HX1 + 1), (HY0 + 1, HY0 + 2), (Z + 2, T))
        b((HX0 + 1, HX1 - 1), (HY0, HY1), (T + 2, T + 2))
    elif style == "chignon":
        cap(); sides(T - 5, HY0 + 1); back(Z + 2); fringe(T, (HX0, 1))
        b((-2, 1), (HY1 + 2, HY1 + 4), (Z + 1, Z + 4))              # low bun at the nape
    else:
        raise KeyError(style)
    if style not in ("buzz", "afro", "curly"):
        tufts(p, m, style, Z)
    return p


def tufts(p, m, seed, Z):
    """Clumps on the back and sides: 2 x 2 tufts on a 2-voxel grid stand one voxel out of about a third of
    the surface, so a head seen from behind or above reads as hair, not as a box (05/06). The face side is left
    alone. Grid-aligned clumps merge into few quads (the kit's size budget)."""
    cells = set(p.cells)
    add = []
    for d, (ia, ib) in (((0, 1, 0), (0, 2)), ((1, 0, 0), (1, 2)), ((-1, 0, 0), (1, 2))):
        for c in sorted(cells):
            if c[ia] % 2 or c[ib] % 2 or c[2] < Z + 2 or (d[0] and c[1] < HY0 + 1):
                continue
            patch = []
            for da in (0, 1):
                for db in (0, 1):
                    q = list(c)
                    q[ia] += da
                    q[ib] += db
                    q = tuple(q)
                    if q in cells and (q[0] + d[0], q[1] + d[1], q[2] + d[2]) not in cells:
                        patch.append((q[0] + d[0], q[1] + d[1], q[2] + d[2]))
            if len(patch) == 4 and zlib.crc32(("tuft%s%d,%d,%d,%d" % (seed, *c, d[0] + 2 * d[2])).encode()) % 3 == 0:
                add += patch
    for c in add:
        p.set(*c, m, "head")


# ---- outfits. Tops own the chest rows and the sleeves (bare forearms in skin); bottoms own the pelvis and legs
# above the shoes; shoes own the 2 floor rows. Hands are their own part. Collars, lapels and hems stand one voxel
# proud of the body so they read as separate layers from the high camera.
TOPS = {   # style: sleeve length
    "tee": "short", "shirt": "full", "shirt_rolled": "rolled", "shirt_tie": "full", "jacket": "full",
    "hoodie": "full", "cardigan": "full", "bomber": "full", "staff_shirt": "short", "blouse": "short",
    "blazer": "full", "dress": "none", "knit": "full",
}
BOTTOMS = ("jeans", "trousers", "shorts", "skirt", "dress")
SHOES = ("sneakers", "boots", "loafers")


def arm_rows(D):
    """(upper arm rows, forearm rows above the hands, hand rows) as (lo, hi) inclusive."""
    return (D["elbow"], D["h"] - 1), (D["az0"] + 2, D["elbow"] - 1), (D["az0"], D["az0"] + 1)


def build_top(style, D, C):
    p = Part("top_" + style, "top")
    mm, tt, aa, sk = ("top", C["top"]), ("top_trim", C["top_trim"]), ("top_accent", C["top_accent"]), ("skin", C["skin"])
    zb, zt = D["leg"] + 2, D["h"] - 1
    x0, x1, y0, y1 = D["x0"], D["x1"], D["y0"], D["y1"]
    p.box((x0, x1), (y0, y1), (zb, zt), mm, "spine")

    def front(x, z, m, out=0):
        p.set(x, y0 - out, z, m, "spine")

    upper, fore, _ = arm_rows(D)
    sleeve = TOPS[style]
    for s in ARMS:
        ar = D["arm_" + s]
        p.box(ar, ARM_Y, upper, sk if sleeve == "none" else mm, "arm_" + s)
        p.box(ar, ARM_Y, fore, mm if sleeve == "full" else sk, "forearm_" + s)
        if sleeve == "short":
            p.box(ar, ARM_Y, (upper[0], upper[0]), tt if style in ("staff_shirt", "blouse") else mm, "arm_" + s)
        elif sleeve == "rolled":                                     # rolled cuff just below the elbow
            p.box(ar, ARM_Y, (fore[1], fore[1]), tt, "forearm_" + s)
            outer = ar[1] + 1 if s == "L" else ar[0] - 1
            p.box((outer, outer), ARM_Y, (fore[1], fore[1]), tt, "forearm_" + s)
        elif sleeve == "full" and style in ("shirt", "shirt_tie", "bomber", "jacket", "blazer", "knit"):
            p.box(ar, ARM_Y, (fore[0], fore[0]), tt if style != "jacket" else aa, "forearm_" + s)   # cuffs
    if style in ("tee", "knit"):
        for x in (-1, 0):
            front(x, zt, sk)
        if style == "knit":
            p.box((x0, x1), (y0, y1), (zb, zb), tt, "spine")
    elif style in ("shirt", "shirt_rolled", "staff_shirt"):
        front(-1, zt, sk); front(0, zt, sk)                         # open neck
        front(-2, zt, tt, 1); front(1, zt, tt, 1)                   # collar points in relief
        front(-3, zt, tt, 1); front(2, zt, tt, 1)
        for z in range(zb + 1, zt - 1, 2):
            front(0, z, aa)                                         # buttons
        if style == "staff_shirt":
            p.box((x0, x1), (y0, y1), (zb, zb), tt, "spine")
        else:
            front(1, zt - 3, aa); front(2, zt - 3, aa)              # pocket
    elif style == "shirt_tie":
        front(-1, zt, sk); front(0, zt, sk)
        front(-2, zt, tt, 1); front(1, zt, tt, 1)
        front(0, zt - 1, aa, 1); front(-1, zt - 1, aa, 1)           # loosened knot
        for z in range(zt - 6, zt - 1):
            front(0, z, aa, 1)
    elif style == "jacket":
        # open dark jacket over a shirt (top_accent), lapels in relief, hem over the belt (05/06: the band, patrons)
        for z in range(zb, zt + 1):
            front(-1, z, aa); front(0, z, aa)
        for z in range(zt - 3, zt + 1):
            front(-2, z, tt, 1); front(1, z, tt, 1)                 # lapels
        front(-1, zt, aa, 1); front(0, zt, aa, 1)                   # shirt collar
        p.box((x0, x1), (y0 - 1, y0 - 1), (zb, zt - 4), mm, "spine",
              keep=lambda x, y, z: x not in (-1, 0))                # jacket fronts stand off the shirt
        p.box((x0, x1), (y0 - 1, y1), (D["leg"] + 1, D["leg"] + 1), mm, "hips",
              keep=lambda x, y, z: not (y == y0 - 1 and x in (-1, 0)))   # hem
    elif style == "hoodie":
        p.box((-3, 2), (y1 + 1, y1 + 1), (zt - 2, zt), mm, "spine")   # hood
        for x in range(-2, 2):
            for z in (zb, zb + 1):
                front(x, z, tt)                                     # pocket
        for z in (zt - 2, zt - 1):
            front(-2, z, aa); front(1, z, aa)                       # drawstrings
    elif style == "cardigan":
        for z in range(zb, zt + 1):
            front(-1, z, aa); front(0, z, aa)                       # open front shows the shirt
        for (x, y, z), (m, bone) in list(p.cells.items()):
            if m == mm and zlib.crc32(("chalk%d,%d,%d" % (x, y, z)).encode()) % 11 == 0:
                p.set(x, y, z, ("top_dust", "Cream"), bone)          # Mali's chalk dust
    elif style == "bomber":
        p.box((x0, x1), (y0 - 1, y1 + 1), (zb, zb), tt, "spine")      # ribbed hem
        p.box((x0, x1), (y0 - 1, y0 - 1), (zb + 1, zt - 1), mm, "spine")
        for x in range(x0, x1 + 1):
            front(x, zt, tt, 1)                                     # collar
        for z in range(zb + 1, zt):
            front(0, z, aa, 1)                                      # zip
    elif style == "blouse":
        for x in range(-2, 2):
            front(x, zt, sk)
        front(-1, zt - 1, sk); front(0, zt - 1, sk)                 # V neck
        for x in range(x0, x1 + 1):
            front(x, zb, tt, 1)                                     # tie hem
    elif style == "blazer":
        for z in range(zt - 4, zt + 1):
            front(-2, z, tt, 1); front(1, z, tt, 1)                 # lapels
        for z in range(zt - 3, zt + 1):
            front(-1, z, aa); front(0, z, aa)                       # shirt
        p.box((x0, x1), (y1 + 1, y1 + 1), (D["leg"] - 1, D["leg"] + 1), mm, "hips")   # back tail
    elif style == "dress":
        # sleeveless (05/06: the red dresses): straps, a scoop neck, bare shoulders
        for x in range(-2, 2):
            front(x, zt, sk); front(x, zt - 1, sk)
        p.box((x0, x1), (y0, y1), (zt, zt), sk, "spine", keep=lambda x, y, z: x not in (x0 + 1, x1 - 1))
    return p


def build_bottom(style, D, C):
    p = Part("bottom_" + style, "bottom")
    mm, tt, sk = ("bottom", C["bottom"]), ("bottom_trim", C["bottom_trim"]), ("skin", C["skin"])
    leg, knee = D["leg"], D["knee"]
    p.box((D["x0"], D["x1"]), (D["y0"], D["y1"]), (leg, leg + 1), mm, "hips")
    if style in ("jeans", "trousers"):
        p.box((D["x0"], D["x1"]), (D["y0"], D["y1"]), (leg + 1, leg + 1), tt, "hips")   # belt
        p.set(-1, D["y0"] - 1, leg + 1, ("bottom_trim", "CymbalGold"), "hips")           # buckle in relief
        p.set(0, D["y0"] - 1, leg + 1, ("bottom_trim", "CymbalGold"), "hips")
    skirt = style in ("skirt", "dress")
    hem = knee + (2 if style == "skirt" else 0)
    for s in ARMS:
        legx = D["leg_" + s]
        xr = (-1, legx[1]) if skirt and s == "L" else legx           # skirts fill the gap between the legs
        for z in range(2, leg):
            bone = ("leg_" if z >= knee else "shin_") + s
            if skirt and z < hem:
                p.box(legx, LEG_Y, (z, z), sk, bone)
                continue
            if skirt:
                m = mm
            elif style == "shorts" and z < knee + 2:
                m = sk
            elif style == "jeans" and z == 2:
                m = tt                                              # rolled cuff
            else:
                m = mm
            p.box(xr, LEG_Y, (z, z), m, bone)
        if skirt:                                                   # flared hem, one voxel out
            outer = xr[1] + 1 if s == "L" else xr[0] - 1
            p.box((outer, outer), (LEG_Y[0] - 1, LEG_Y[1] + 1), (hem, hem + 1), mm, "leg_" + s)
            p.box(xr, (LEG_Y[0] - 1, LEG_Y[0] - 1), (hem, hem), mm, "leg_" + s)
            p.box(xr, (LEG_Y[1] + 1, LEG_Y[1] + 1), (hem, hem), mm, "leg_" + s)
    return p


def build_shoes(style, D, C):
    p = Part("shoes_" + style, "shoes")
    mm, tt = ("shoes", C["shoes"]), ("shoes_trim", C["shoes_trim"])
    for s in ARMS:
        xr, bone = D["leg_" + s], "shin_" + s
        if style == "loafers":
            p.box(xr, LEG_Y, (0, 1), mm, bone)
            p.box(xr, (LEG_Y[0] - 1, LEG_Y[0] - 1), (0, 0), mm, bone)    # low toe
            p.box(xr, (LEG_Y[0], LEG_Y[0]), (1, 1), tt, bone)            # vamp
        else:
            p.box(xr, (LEG_Y[0] - 1, LEG_Y[1]), (0, 1), mm, bone)
            p.box(xr, (LEG_Y[0] - 1, LEG_Y[1]), (0, 0), tt, bone)        # sole
        if style == "boots":
            p.box(xr, LEG_Y, (2, 2), mm, bone)
    return p


def build_hands(D, C):
    p = Part("hands", "hands")
    _, _, hand = arm_rows(D)
    for s in ARMS:
        p.box(D["arm_" + s], ARM_Y, hand, ("skin", C["skin"]), "forearm_" + s)
    return p


# ---- accessories: id -> (slot, default colour 1, default colour 2). Materials are <id>__<Swatch>, <id>_2__<Swatch>.
# Held props are modelled for a forearm held level and pointing forward (the drink and tray poses): in the rest
# pose (forearm hanging) "up" for the prop is -Y. venue_patron_figure.gd hides them outside the poses that use them.
ACC = {
    "hat_bucket":     ("hat", "Olive", "Cream"),
    "hat_flat_cap":   ("hat", "Stone", "Charcoal"),
    "hat_beanie":     ("hat", "Rust", "Cream"),
    "hat_fedora":     ("hat", "StoolBlack", "Charcoal"),
    "glasses_round":  ("glasses", "CymbalGold", "Lens"),
    "glasses_tinted": ("glasses", "CymbalGold", "Lens"),
    "glasses_up":     ("glasses", "StoolBlack", "Lens"),
    "headphones":     ("ears", "StoolBlack", "Charcoal"),
    "beard":          ("face_hair", "HairBlack", "HairBlack"),
    "moustache":      ("face_hair", "HairBlack", "HairBlack"),
    "ribbon":         ("hair_acc", "Rust", "Cream"),
    "pencil":         ("hair_acc", "Mustard", "Charcoal"),
    "gig_bag":        ("back", "StoolBlack", "Charcoal"),
    "apron":          ("outer", "Cream", "CymbalGold"),
    "vest":           ("outer", "StoolBlack", "Charcoal"),
    "bar_towel":      ("arm_acc", "ColumnWhite", "Cream"),
    "gaffer_tape":    ("belt", "Stone", "Charcoal"),
    "guitar":         ("instrument", "WoodMid", "Cream"),
    "guitar_electric": ("instrument", "DressRed", "ColumnWhite"),
    "bass":           ("instrument", "Mustard", "StoolBlack"),
    "drumsticks":     ("held", "Sand", "Sand"),
    "drink_beer":     ("drink", "BeerAmber_emissive", "Foam"),
    "drink_mug":      ("drink", "BeerAmber_emissive", "Foam"),
    "glass_gold":     ("drink", "BottleClear", "CymbalGold"),
    "beer_left":      ("drink", "BeerAmber_emissive", "Foam"),
    "bottle":         ("drink", "BottleGreen", "LabelCream"),
    "shaker":         ("held_R", "MirrorGrey", "CymbalGold"),
    "tray":           ("held_L", "StoolBlack", "BeerAmber_emissive"),
    "notebook":       ("held_R", "Cream", "Charcoal"),
    "torch":          ("held_R", "StoolBlack", "LampGoldOff"),
    "clicker":        ("held_L", "Stone", "Charcoal"),
    "sketchbook":     ("held_L", "WoodMid", "Cream"),
    "vinyl":          ("held_L", "Mustard", "StoolBlack"),
    "wheelie_bag":    ("floor", "Denim", "StoolBlack"),
}
DRINKS = ("drink_beer", "drink_mug", "glass_gold", "beer_left", "bottle")
INSTRUMENTS = ("guitar", "guitar_electric", "bass", "drumsticks")


def build_acc(aid, D, C):
    slot, c1, c2 = ACC[aid]
    p = Part(aid, slot)
    a, b2 = (aid, C.get(aid, c1)), (aid + "_2", C.get(aid + "_2", c2))
    Z, T, h, leg, az = D["h"], D["T"], D["h"], D["leg"], D["az0"]
    L, R = D["arm_L"], D["arm_R"]
    rc, lc = R[0] + 1, L[0] + 1                                     # centre columns of the arms

    def bx(xr, yr, zr, m=a, bone="head", keep=None):
        p.box(xr, yr, zr, m, bone, keep)

    if aid == "hat_bucket":
        bx((HX0 - 2, HX1 + 2), (HY0 - 2, HY1 + 2), (T + 2, T + 2))
        bx((HX0 - 1, HX1 + 1), (HY0 - 1, HY1 + 1), (T + 3, T + 4))
        bx((HX0 - 1, HX1 + 1), (HY0 - 1, HY1 + 1), (T + 3, T + 3), b2)          # band
    elif aid == "hat_flat_cap":
        bx((HX0 - 1, HX1 + 1), (HY0 - 1, HY1 + 1), (T + 2, T + 3))
        bx((HX0, HX1), (HY0 + 1, HY1), (T + 4, T + 4))
        bx((-4, 3), (HY0 - 3, HY0 - 2), (T + 2, T + 2), b2)                    # peak
    elif aid == "hat_beanie":
        bx((HX0 - 1, HX1 + 1), (HY0 - 1, HY1 + 1), (T + 2, T + 2), b2)          # cuff
        bx((HX0 - 1, HX1 + 1), (HY0 - 1, HY1 + 1), (T + 3, T + 4),
           keep=lambda x, y, z: not (z == T + 4 and (x in (HX0 - 1, HX1 + 1) or y in (HY0 - 1, HY1 + 1))))
        bx((-1, 0), (-1, 0), (T + 5, T + 5), b2)                                 # pom
    elif aid == "hat_fedora":
        # 05/06: the bassist's and the bar patron's fedora. Wide brim, band, pinched crown
        bx((HX0 - 2, HX1 + 2), (HY0 - 2, HY1 + 2), (T + 2, T + 2),
           keep=lambda x, y, z: not (x in (HX0 - 2, HX1 + 2) and y in (HY0 - 2, HY1 + 2)))
        bx((HX0, HX1), (HY0 + 1, HY1 - 1), (T + 3, T + 3), b2)                   # band
        bx((HX0, HX1), (HY0 + 1, HY1 - 1), (T + 4, T + 5),
           keep=lambda x, y, z: not (z == T + 5 and -2 <= x <= 1))               # pinched crown
    elif aid in ("glasses_round", "glasses_tinted"):
        ez = Z + EYE_Z
        for ex in (EYE_X, mirror(EYE_X)):
            bx((ex - 1, ex + 1), (HY0 - 1, HY0 - 1), (ez - 1, ez + 2),
               keep=lambda x, y, z, ex=ex: not (x == ex and ez <= z <= ez + 1))
            if aid == "glasses_tinted":
                bx((ex, ex), (HY0 - 1, HY0 - 1), (ez, ez + 1), b2)
        bx((-1, 0), (HY0 - 1, HY0 - 1), (ez + 1, ez + 1))                       # bridge
        bx((HX1 + 1, HX1 + 1), (HY0, HY0 + 3), (ez + 1, ez + 1))                 # temples
        bx((HX0 - 1, HX0 - 1), (HY0, HY0 + 3), (ez + 1, ez + 1))
    elif aid == "glasses_up":
        for ex in (EYE_X, mirror(EYE_X)):
            bx((ex - 1, ex + 1), (HY0, HY0 + 1), (T + 2, T + 2))
            bx((ex, ex), (HY0, HY0), (T + 2, T + 2), b2)
        bx((-1, 0), (HY0 + 1, HY0 + 1), (T + 2, T + 2))
    elif aid == "headphones":
        bx((HX0 - 1, HX1 + 1), (-1, 0), (T + 2, T + 2))                          # band
        for x in (HX0 - 2, HX1 + 2):
            bx((x, x), (-1, 0), (Z + 6, T + 2))
        bx((HX0 - 3, HX0 - 2), (-2, 1), (Z + 2, Z + 5), b2)                       # cups
        bx((HX1 + 2, HX1 + 3), (-2, 1), (Z + 2, Z + 5), b2)
    elif aid == "beard":
        y = HY0 - 1
        bx((-3, 2), (y, y), (Z, Z))                                               # chin row
        bx((-2, 1), (HY0, HY0), (Z - 1, Z - 1))                                   # under the chin
        for x0 in (HX0, HX1):
            bx((x0, x0), (y, y), (Z, Z + 2))                                      # jaw
        bx((HX0 - 1, HX0 - 1), (HY0, HY0 + 2), (Z, Z + 4))                        # sideburn to the jaw
        bx((HX1 + 1, HX1 + 1), (HY0, HY0 + 2), (Z, Z + 4))
        bx((-4, 3), (y, y), (Z + 1, Z + 1), keep=lambda x, yy, z: x in (-4, -3, 2, 3))   # round the mouth
        bx((-3, 2), (y, y), (Z + 2, Z + 2), keep=lambda x, yy, z: x not in (-1, 0))      # moustache, under the nose
    elif aid == "moustache":
        y = HY0 - 1
        bx((-3, 2), (y, y), (Z + 1, Z + 1), keep=lambda x, yy, z: x in (-3, 2))
        bx((-3, 2), (y, y), (Z + 2, Z + 2), keep=lambda x, yy, z: x not in (-1, 0))
    elif aid == "ribbon":
        y = HY1 + 2
        for x0 in (-6, 2):
            bx((x0, x0 + 3), (y, y), (T + 1, T + 4),
               keep=lambda x, yy, z, x0=x0: not ((x in (x0, x0 + 3)) and z in (T + 1, T + 4)))
        bx((-2, 1), (y, y), (T + 2, T + 3), b2)
    elif aid == "pencil":
        bx((-5, 3), (0, 0), (T + 3, T + 3))
        bx((4, 4), (0, 0), (T + 3, T + 3), b2)                                     # graphite tip
    elif aid == "gig_bag":
        y0 = D["y1"] + 1
        bx((-4, 1), (y0, y0 + 2), (leg, h - 1), bone="spine")
        for k in range(6):                                                         # neck pokes over the right shoulder
            x = -5 - k // 2
            bx((x, x + 1), (y0, y0 + 1), (h - 4 + k, h - 4 + k), bone="spine")
        bx((-8, -7), (y0, y0 + 1), (h + 2, h + 3), b2, bone="spine")
        for i in range(D["tw"]):                                                   # strap across the chest
            x = D["x1"] - i
            z = h - 1 - (i * (D["chest"] - 2)) // D["tw"]
            bx((x, x), (D["y0"] - 1, D["y0"] - 1), (z, z), b2, bone="spine")
    elif aid == "apron":
        y = D["y0"] - 1
        bx((D["x0"] + 1, D["x1"] - 1), (y, y), (leg - 3, h - 3), bone="spine")
        bx((D["x0"] + 1, D["x0"] + 1), (y, y), (h - 2, h - 1), bone="spine")      # neck straps
        bx((D["x1"] - 1, D["x1"] - 1), (y, y), (h - 2, h - 1), bone="spine")
        bx((D["x0"] + 1, D["x1"] - 1), (y, y), (leg + 2, leg + 2), b2, bone="spine")   # gold waist tie
    elif aid == "vest":
        # 05/06 server: black waistcoat over the white shirt, open at the front, two gold buttons, back panel
        y0, y1 = D["y0"] - 1, D["y1"] + 1
        for x0, x1 in ((D["x0"], -2), (1, D["x1"])):
            bx((x0, x1), (y0, y0), (leg + 1, h - 1), bone="spine",
               keep=lambda x, y, z: not (z >= h - 3 and x in (-2, 1)))             # V at the neck
        bx((D["x0"], D["x1"]), (y1, y1), (leg + 1, h - 1), bone="spine")
        bx((D["x0"], D["x0"]), (D["y0"], D["y1"]), (leg + 1, h - 3), bone="spine")
        bx((D["x1"], D["x1"]), (D["y0"], D["y1"]), (leg + 1, h - 3), bone="spine")
        bx((1, 1), (y0 - 1, y0 - 1), (leg + 3, leg + 3), b2, "spine")
        bx((1, 1), (y0 - 1, y0 - 1), (leg + 5, leg + 5), b2, "spine")
    elif aid == "bar_towel":                                                       # over the left shoulder
        x0, x1 = L
        bx((x0, x1), (-2, -2), (h - 3, h), bone="arm_L")
        bx((x0, x1), (2, 2), (h - 4, h), bone="arm_L")
        bx((x0, x1), (-2, 2), (h, h), bone="arm_L")
    elif aid == "gaffer_tape":
        bx((D["x1"] - 2, D["x1"] - 1), (D["y0"] - 1, D["y0"] - 1), (leg, leg + 1), bone="hips")
        bx((D["x1"] - 2, D["x1"] - 1), (D["y0"] - 2, D["y0"] - 2), (leg, leg + 1), b2, bone="hips")
    elif aid in ("guitar", "guitar_electric", "bass"):
        # slung on the strap in front of the belly, neck up to the character's left (+X) for a right-hander
        y0 = D["y0"] - 2
        wide = {"guitar": 8, "guitar_electric": 8, "bass": 8}[aid]
        tall = {"guitar": 8, "guitar_electric": 7, "bass": 8}[aid]
        x0 = -7
        zb = leg

        def body_keep(x, y, z):
            corner = (x in (x0, x0 + wide - 1)) and (z in (zb, zb + tall - 1))
            waist = (x in (x0, x0 + wide - 1)) and z == zb + tall // 2 + 1
            horn = aid != "guitar" and x == x0 + wide - 1 and z >= zb + tall - 2
            return not (corner or waist or horn)
        bx((x0, x0 + wide - 1), (y0, y0 + 1), (zb, zb + tall - 1), bone="spine", keep=body_keep)
        if aid == "guitar":
            bx((-3, -2), (y0 - 1, y0 - 1), (zb + 3, zb + 4), ("guitar_hole", "StoolBlack"), "spine")
            bx((x0 + 1, x0 + wide - 2), (y0 - 1, y0 - 1), (zb, zb), b2, "spine")     # binding
        else:
            bx((x0 + 2, x0 + 4), (y0 - 1, y0 - 1), (zb + 1, zb + 3), b2, "spine")    # pickguard
            bx((x0 + 1, x0 + 3), (y0 - 1, y0 - 1), (zb + 4, zb + 4), (aid + "_3", "MirrorGrey"), "spine")
        nl = {"guitar": 5, "guitar_electric": 6, "bass": 7}[aid]
        neck = ("guitar_neck", "WoodDark")                                          # up at 45 deg, under the chin line
        for i in range(nl):
            zz = zb + tall - 2 + i
            bx((x0 + wide + i - 1, x0 + wide + i), (y0, y0), (zz, zz), neck, "spine")
        hx = x0 + wide + nl - 1
        bx((hx, hx + 1), (y0, y0), (zb + tall - 2 + nl, zb + tall - 1 + nl), a, "spine")    # headstock
        bx((D["x0"], D["x1"]), (D["y1"] + 1, D["y1"] + 1), (h - 1, h - 1), ("guitar_strap", "StoolBlack"), "spine")
    elif aid == "drumsticks":
        for s, ar in (("L", L), ("R", R)):
            c = ar[0] + 1
            bx((c, c), (0, 0), (az - 6, az - 1), bone="forearm_" + s)              # continue the forearm line
            bx((c, c), (0, 0), (az - 7, az - 7), b2, "forearm_" + s)
    elif aid in ("drink_beer", "glass_gold", "beer_left"):
        # a pint held at the inner side of the hand; upright when the forearm is level (see note above ACC)
        if aid == "beer_left":
            gx, bone = (L[0] - 2, L[0] - 1), "forearm_L"
        else:
            gx, bone = (R[1] + 1, R[1] + 2), "forearm_R"
        foam = (b2[0], "Foam") if aid != "glass_gold" else b2
        bx(gx, (-2, 1), (az, az + 1), bone=bone)
        bx(gx, (-3, -3), (az, az + 1), foam, bone)
        if aid == "glass_gold":
            bx(gx, (2, 2), (az, az + 1), ("glass_gold_3", "BottleClear"), bone)      # stem
    elif aid == "drink_mug":
        gx, bone = (R[1] + 1, R[1] + 3), "forearm_R"
        bx(gx, (-2, 1), (az - 1, az + 1), bone=bone)
        bx(gx, (-3, -3), (az - 1, az + 1), b2, bone)
        bx((R[1] + 2, R[1] + 2), (-1, 0), (az - 2, az - 2), ("drink_mug_3", "BottleClear"), bone)   # handle
    elif aid == "bottle":
        # held by the neck, the body continues the forearm line: tipped forward it pours (bartender)
        bx((rc, rc), (0, 0), (az - 2, az - 1), ("bottle_3", "BottleGreenCap"), "forearm_R")
        bx((rc - 1, rc), (-1, 0), (az - 7, az - 3), bone="forearm_R")
        bx((rc - 1, rc), (-1, -1), (az - 5, az - 4), b2, "forearm_R")
    elif aid == "shaker":
        gx = (R[1] + 1, R[1] + 2)
        bx(gx, (-4, 1), (az, az + 1), bone="forearm_R")
        bx(gx, (-5, -5), (az, az + 1), b2, "forearm_R")
    elif aid == "tray":
        # 05/06: the server's round tray flat on the left palm with pints on it (level forearm, see ACC note)
        x0t, x1t = lc - 4, lc + 3
        z0t, z1t = az - 4, az + 3
        bx((x0t, x1t), (-2, -2), (z0t, z1t), bone="forearm_L",
           keep=lambda x, y, z: not (x in (x0t, x1t) and z in (z0t, z1t)))
        for gx, gz in ((x0t + 1, z0t + 1), (x0t + 4, z0t + 1), (x0t + 1, z0t + 4), (x0t + 4, z0t + 4)):
            bx((gx, gx + 1), (-6, -3), (gz, gz + 1), b2, "forearm_L")
            bx((gx, gx + 1), (-7, -7), (gz, gz + 1), ("tray_3", "Foam"), "forearm_L")
    elif aid == "notebook":
        bx((R[0] - 1, R[0] - 1), (-2, 1), (az - 1, az + 2), bone="forearm_R")
        bx((R[0] - 1, R[0] - 1), (-2, 1), (az + 2, az + 2), b2, "forearm_R")
    elif aid == "torch":
        bx((rc, rc), (0, 0), (az - 4, az - 1), bone="forearm_R")
        bx((rc, rc), (0, 0), (az - 5, az - 5), b2, "forearm_R")
    elif aid == "clicker":
        bx((lc, lc), (-2, -2), (az, az + 1), bone="forearm_L")
        bx((lc, lc), (-3, -3), (az + 1, az + 1), b2, "forearm_L")
    elif aid == "sketchbook":
        x = L[1] + 1
        bx((x, x), (-3, 1), (az - 1, az + 3), bone="forearm_L")
        bx((x, x), (-3, 1), (az + 3, az + 3), b2, "forearm_L")
    elif aid == "vinyl":
        x = L[1] + 1
        bx((x, x), (-4, 2), (az - 2, az + 4), bone="forearm_L")
        bx((x, x), (-2, 0), (az, az + 2), b2, "forearm_L")                           # label
    elif aid == "wheelie_bag":
        x0 = D["x0"] - 9
        bx((x0, x0 + 4), (0, 3), (1, 8), bone="root")
        bx((x0, x0), (0, 0), (0, 0), b2, "root"); bx((x0 + 4, x0 + 4), (0, 0), (0, 0), b2, "root")
        bx((x0, x0), (3, 3), (0, 0), b2, "root"); bx((x0 + 4, x0 + 4), (3, 3), (0, 0), b2, "root")
        bx((x0 + 1, x0 + 1), (2, 2), (9, 12), ("wheelie_bag_3", "MirrorGrey"), "root")
        bx((x0 + 3, x0 + 3), (2, 2), (9, 12), ("wheelie_bag_3", "MirrorGrey"), "root")
        bx((x0 + 1, x0 + 3), (2, 2), (13, 13), b2, "root")
    else:
        raise KeyError(aid)
    return p


# ------------------------------------------------------------------ presets
# colours: skin, hair, top, top_trim, top_accent, bottom, bottom_trim, shoes, shoes_trim, plus <acc id>(_2).
DEFAULT_COLOURS = dict(skin="Skin3", hair="HairDarkBrown", top="Stone", top_trim="Cream", top_accent="Cream",
                       bottom="Denim", bottom_trim="Leather", shoes="Charcoal", shoes_trim="Cream",
                       eyes="Ink", mouth="Mouth", blush="Blush")
SLOTS = ("head", "hair", "eyes", "brows", "mouth", "top", "bottom", "shoes")


def P(name, display, role, slot_id, body, head_shape, hair_style, face, top_style, bottom_style, shoe_style,
      acc=(), **colours):
    eyes, brows, mouth = face
    return dict(name=name, display=display, role=role, slot_id=slot_id, body=body, head=head_shape, hair=hair_style,
                eyes=eyes, brows=brows, mouth=mouth, top=top_style, bottom=bottom_style, shoes=shoe_style,
                acc=list(acc), colours=dict(DEFAULT_COLOURS, **colours))


STAFF_TOP = dict(top="CabinDark", top_trim="CymbalGold")             # bible section 7: staff wear Cabin Dark + gold
PRESETS = [
    # regulars (cast bible section 3.1): no two share a head silhouette; each keeps a signature item
    P("tong", "Tong", "regular", "REG_TONG", "regular", "square", "crop", ("dot", "flat", "smile"),
      "tee", "jeans", "sneakers", ["hat_bucket", "gig_bag", "drink_beer"],
      skin="Skin4", hair="HairBlack", top="Mustard", top_trim="Cream", shoes="Cream", shoes_trim="ColumnWhite"),
    P("ploy", "Ploy", "regular", "REG_PLOY", "petite", "soft", "bun", ("lashes", "arched", "small"),
      "blouse", "trousers", "loafers", ["pencil", "sketchbook"],
      skin="Skin2", hair="HairBlack", top="Teal", top_trim="Cream", bottom="Charcoal", bottom_trim="StoolBlack",
      shoes="WoodDark", shoes_trim="TableWoodLit"),
    P("jules", "Jules", "regular", "REG_JULES", "regular", "heart", "quiff", ("wide", "flat", "grin"),
      "bomber", "jeans", "boots", ["drink_beer"],
      skin="Skin1", hair="HairBleach", top="Olive", top_trim="Mustard", top_accent="Cream", bottom="Charcoal",
      bottom_trim="Stone", shoes="WoodDark", shoes_trim="StoolBlack"),
    P("mali", "Mali", "regular", "REG_MALI", "broad", "round", "bob", ("dot", "arched", "grin"),
      "cardigan", "skirt", "loafers", ["glasses_up", "drink_mug"],
      skin="Skin5", hair="HairDarkBrown", top="Rust", top_trim="Cream", top_accent="Cream",
      bottom="FloorGrey", bottom_trim="Charcoal", shoes="WoodDark", shoes_trim="Sand"),
    P("dougie", "Dougie", "regular", "REG_DOUGIE", "broad", "square", "sideburns", ("sleepy", "thick", "flat"),
      "shirt", "jeans", "boots", ["hat_flat_cap", "moustache", "drink_beer"],
      skin="Skin1", hair="HairGrey", top="Moss", top_trim="Cream", top_accent="Cream", shoes="WoodDark",
      shoes_trim="StoolBlack", moustache="HairGrey"),
    P("lung_nop", "Lung Nop", "regular", "REG_LUNG_NOP", "regular", "round", "swept", ("dot", "flat", "small"),
      "shirt", "trousers", "loafers", ["glasses_tinted", "vinyl"],
      skin="Skin5", hair="HairWhite", top="Cream", top_trim="Sand", top_accent="WoodMid", bottom="Sand",
      bottom_trim="WoodMid", shoes="WoodDark", shoes_trim="TableWoodLit"),
    P("bow", "Bow", "regular", "REG_BOW", "petite", "square", "ponytail", ("lashes", "arched", "open"),
      "blouse", "skirt", "sneakers", ["ribbon", "wheelie_bag"],
      skin="Skin3", hair="HairDarkBrown", top="Sky", top_trim="Cream", bottom="Denim", bottom_trim="Cream",
      shoes="ColumnWhite", shoes_trim="Stone"),
    P("hiro", "Hiro", "regular", "REG_HIRO", "regular", "soft", "side_part", ("sleepy", "flat", "small"),
      "shirt_tie", "trousers", "loafers", ["notebook"],
      skin="Skin2", hair="HairBlack", top="ShirtWhite", top_trim="Cream", top_accent="DrumRed", bottom="Charcoal",
      bottom_trim="StoolBlack", shoes="StoolBlack", shoes_trim="Charcoal"),
    # staff slots (cast bible section 2)
    P("nam", "Nam", "staff", "BAR_1", "regular", "round", "crop", ("happy", "flat", "smile"),
      "staff_shirt", "trousers", "loafers", ["apron", "bar_towel", "bottle", "beer_left"],
      skin="Skin4", hair="HairBlack", top_accent="CymbalGold", bottom="StoolBlack", bottom_trim="CymbalGold",
      shoes="StoolBlack", shoes_trim="Charcoal", **STAFF_TOP),
    P("fern", "Fern", "staff", "BAR_2", "petite", "heart", "long", ("lashes", "arched", "smile"),
      "staff_shirt", "skirt", "sneakers", ["shaker", "beer_left"],
      skin="Skin3", hair="HairAuburn", top_accent="CymbalGold", bottom="StoolBlack", bottom_trim="CymbalGold",
      shoes="StoolBlack", shoes_trim="CymbalGold", **STAFF_TOP),
    P("big", "Big", "staff", "DOOR", "broad", "square", "buzz", ("dot", "thick", "smile"),
      "staff_shirt", "trousers", "boots", ["torch", "clicker", "beard"],
      skin="Skin6", hair="HairBlack", top_accent="CymbalGold", bottom="StoolBlack", bottom_trim="CymbalGold",
      shoes="StoolBlack", shoes_trim="Charcoal", **STAFF_TOP),
    P("golf", "Golf", "staff", "SOUND", "regular", "soft", "spiky", ("sleepy", "flat", "flat"),
      "staff_shirt", "jeans", "sneakers", ["headphones", "gaffer_tape"],
      skin="Skin4", hair="HairBlack", top_accent="CymbalGold", bottom="Charcoal", bottom_trim="Stone",
      shoes="Charcoal", shoes_trim="ColumnWhite", **STAFF_TOP),
    P("khun_joy", "Khun Joy", "staff", "OWNER", "regular", "heart", "chignon", ("lashes", "arched", "smile"),
      "blazer", "trousers", "loafers", ["glass_gold"],
      skin="Skin3", hair="HairBlack", top="CabinDark", top_trim="CymbalGold", top_accent="Cream",
      bottom="CabinDark", bottom_trim="CymbalGold", shoes="StoolBlack", shoes_trim="CymbalGold"),
    # 05/06: the floor server, white shirt with rolled sleeves, black vest and belt, tray of pints
    P("server", "Server", "staff", "FLOOR", "regular", "square", "shaggy", ("dot", "thick", "smile"),
      "shirt_rolled", "trousers", "boots", ["vest", "tray", "beard"],
      skin="Skin2", hair="HairDarkBrown", top="ShirtWhite", top_trim="ColumnWhite", top_accent="Stone",
      bottom="StoolBlack", bottom_trim="Leather", shoes="WoodDark", shoes_trim="StoolBlack", beard="HairDarkBrown",
      vest="StoolBlack", vest_2="CymbalGold"),
    # house band, The House Lights (cast bible section 4.1), dressed as the band in 05/06
    P("jo", "Jo", "band", "PERF_HOUSE_VOX", "petite", "round", "long", ("wide", "arched", "open"),
      "jacket", "skirt", "boots", ["guitar"],
      skin="Skin4", hair="HairBlack", top="Jacket", top_trim="StoolBlack", top_accent="Mustard",
      bottom="StoolBlack", bottom_trim="Cream", shoes="WoodDark", shoes_trim="StoolBlack"),
    P("pete", "Pete", "band", "PERF_HOUSE_BASS", "regular", "square", "crop", ("dot", "flat", "smile"),
      "shirt", "trousers", "boots", ["bass", "hat_fedora", "beard"],
      skin="Skin6", hair="HairBlack", top="Jacket", top_trim="Charcoal", top_accent="Stone", bottom="StoolBlack",
      bottom_trim="Charcoal", shoes="StoolBlack", shoes_trim="Charcoal", beard="HairBlack"),
    P("boy", "Boy", "band", "PERF_HOUSE_DRUMS", "broad", "soft", "shaggy", ("happy", "flat", "grin"),
      "shirt_rolled", "jeans", "sneakers", ["drumsticks", "moustache"],
      skin="Skin4", hair="HairBlack", top="ShirtWhite", top_trim="ColumnWhite", top_accent="Stone",
      bottom="Charcoal", bottom_trim="StoolBlack", shoes="ColumnWhite", shoes_trim="Stone"),
    # the venue's fourth stage spot (05/06 show a four-piece; the House Lights are a trio): an anonymous guest
    P("band_guitar", "Guest guitarist", "band", "PERF_GUEST", "regular", "square", "shaggy", ("dot", "thick", "small"),
      "jacket", "jeans", "boots", ["guitar_electric", "beard"],
      skin="Skin1", hair="HairBleach", top="Jacket", top_trim="StoolBlack", top_accent="StoolBlack",
      bottom="StoolBlack", bottom_trim="Charcoal", shoes="StoolBlack", shoes_trim="Charcoal", beard="HairBleach"),
]

# 24 anonymous patrons (DECISIONS m), styled after the crowd in 05/06: big hair, beards, white shirts, dark
# jackets, red dresses, denim, a few hats and glasses. Each holds a pint or a mug (shown only when drinking).
#   body, head, hair, (eyes, brows, mouth), top, bottom, shoes, acc, skin, hair colour, top, top accent, bottom
PATRONS = [
    ("regular", "square", "shaggy", ("dot", "thick", "smile"), "shirt", "jeans", "boots", ["beard"], "Skin3", "HairBlack", "ShirtWhite", "Stone", "Denim"),
    ("petite", "soft", "wavy", ("lashes", "arched", "smile"), "dress", "dress", "loafers", [], "Skin1", "HairBleach", "DressRed", "Cream", "DressRed"),
    ("regular", "round", "afro", ("dot", "arched", "grin"), "dress", "dress", "loafers", [], "Skin7", "HairBlack", "DrumRed", "Cream", "DrumRed"),
    ("regular", "square", "shaggy", ("sleepy", "flat", "small"), "jacket", "trousers", "boots", ["hat_fedora", "beard"], "Skin4", "HairBlack", "Jacket", "ShirtWhite", "StoolBlack"),
    ("petite", "heart", "wavy", ("wide", "arched", "open"), "tee", "jeans", "sneakers", [], "Skin2", "HairGinger", "Stone", "Cream", "Denim"),
    ("broad", "square", "shaggy", ("dot", "thick", "flat"), "tee", "jeans", "boots", ["beard"], "Skin5", "HairDarkBrown", "Moss", "Cream", "Charcoal"),
    ("regular", "soft", "wavy", ("lashes", "flat", "smile"), "blouse", "skirt", "loafers", [], "Skin2", "HairBleach", "Denim", "Cream", "StoolBlack"),
    ("regular", "round", "afro", ("dot", "flat", "smile"), "shirt", "trousers", "sneakers", [], "Skin6", "HairBlack", "DenimLight", "Cream", "Charcoal"),
    ("petite", "soft", "curly", ("lashes", "arched", "small"), "dress", "dress", "loafers", [], "Skin8", "HairBlack", "VelvetRed", "Cream", "VelvetRed"),
    ("regular", "square", "shaggy", ("dot", "flat", "grin"), "hoodie", "jeans", "sneakers", [], "Skin3", "HairBrown", "Charcoal", "Cream", "Denim"),
    ("broad", "round", "swept", ("sleepy", "thick", "smile"), "jacket", "trousers", "loafers", ["glasses_round"], "Skin1", "HairWhite", "Charcoal", "Cream", "StoolBlack"),
    ("regular", "heart", "long", ("wide", "arched", "smile"), "tee", "jeans", "sneakers", [], "Skin3", "HairDarkBrown", "DressRed", "Cream", "Denim"),
    ("regular", "square", "crop", ("dot", "thick", "smile"), "shirt_rolled", "jeans", "boots", ["beard"], "Skin2", "HairBrown", "ShirtWhite", "Stone", "Denim"),
    ("petite", "round", "bob", ("lashes", "arched", "smile"), "blouse", "jeans", "loafers", ["glasses_round"], "Skin4", "HairBlack", "Mustard", "Cream", "Denim"),
    ("broad", "soft", "buzz", ("dot", "thick", "flat"), "tee", "jeans", "boots", ["beard"], "Skin6", "HairBlack", "StoolBlack", "Cream", "Denim"),
    ("regular", "soft", "curly", ("dot", "flat", "smile"), "shirt", "trousers", "sneakers", [], "Skin5", "HairDarkBrown", "Olive", "Cream", "Charcoal"),
    ("petite", "heart", "ponytail", ("lashes", "arched", "open"), "tee", "skirt", "sneakers", [], "Skin3", "HairBlack", "Cream", "Cream", "StoolBlack"),
    ("regular", "square", "side_part", ("dot", "flat", "small"), "jacket", "trousers", "loafers", [], "Skin1", "HairBrown", "Denim", "ShirtWhite", "Charcoal"),
    ("regular", "round", "shaggy", ("sleepy", "thick", "grin"), "shirt_rolled", "jeans", "boots", ["hat_flat_cap"], "Skin4", "HairBlack", "Rust", "Cream", "Denim"),
    ("petite", "soft", "long", ("lashes", "arched", "smile"), "dress", "dress", "loafers", [], "Skin2", "HairDarkBrown", "Teal", "Cream", "Teal"),
    ("broad", "square", "sideburns", ("dot", "thick", "flat"), "shirt", "jeans", "boots", ["beard", "glasses_tinted"], "Skin3", "HairGrey", "Charcoal", "Stone", "Denim"),
    ("regular", "heart", "wavy", ("wide", "arched", "smile"), "blouse", "skirt", "loafers", [], "Skin5", "HairAuburn", "ShirtWhite", "Cream", "StoolBlack"),
    ("regular", "round", "spiky", ("dot", "flat", "grin"), "bomber", "jeans", "sneakers", [], "Skin2", "HairBlack", "Olive", "Mustard", "Charcoal"),
    ("petite", "round", "afro", ("dot", "arched", "smile"), "knit", "jeans", "sneakers", [], "Skin7", "HairBlack", "Sky", "Cream", "Denim"),
]
for i, (body, head, hair, face, top, bottom, shoes, acc, sk, hc, tc, ac, bc) in enumerate(PATRONS):
    PRESETS.append(P("patron_%02d" % (i + 1), "Patron %d" % (i + 1), "patron", "PATRON", body, head, hair, face,
                     top, bottom, shoes, acc + ["drink_mug" if i % 3 == 2 else "drink_beer"],
                     skin=sk, hair=hc, top=tc, top_trim="ColumnWhite" if tc in ("ShirtWhite",) else "Cream",
                     top_accent=ac, bottom=bc, bottom_trim="Leather",
                     shoes=("Charcoal", "WoodDark", "StoolBlack")[i % 3], shoes_trim="Stone",
                     beard=hc, moustache=hc))

# Parts drawn later win where they overlap earlier ones (no coplanar faces): a jacket hem over the belt,
# glasses over brows, a hat over the hair it covers.
LAYER = {"head": 0, "bottom": 1, "shoes": 2, "hands": 2, "top": 3, "hair": 4, "brows": 5, "eyes": 5, "mouth": 5}


def assemble(spec):
    """Parts for a preset spec (dict as made by P), with overlaps resolved."""
    D, C = dims(spec["body"]), spec["colours"]
    parts = [build_head(spec["head"], D, C), build_hair(spec["hair"], D, C), build_eyes(spec["eyes"], D, C),
             build_brows(spec["brows"], D, C), build_mouth(spec["mouth"], D, C), build_top(spec["top"], D, C),
             build_bottom(spec["bottom"], D, C), build_shoes(spec["shoes"], D, C), build_hands(D, C)]
    parts += [build_acc(a, D, C) for a in spec["acc"]]
    hats = [p for p in parts if p.slot == "hat"]
    if hats:                                    # hair under a hat stops at the brim
        brim = min(z for p in hats for (_, _, z) in p.cells)
        hair = next(p for p in parts if p.slot == "hair")
        for c in [c for c in hair.cells if c[2] >= brim]:
            del hair.cells[c]
    ordered = sorted(parts, key=lambda p: LAYER.get(p.slot, 6))
    taken = {}
    for p in reversed(ordered):
        for c in list(p.cells):
            if c in taken:
                del p.cells[c]
            else:
                taken[c] = p
    return [p for p in parts if not p.empty()]


def library_parts(body):
    """Every part for one body type, in default colours: the runtime creator's source."""
    D, C = dims(body), dict(DEFAULT_COLOURS)
    parts = [build_head(s, D, C) for s in HEADS] + [build_hair(s, D, C) for s in HAIRS]
    parts += [build_eyes(v, D, C) for v in EYES] + [build_brows(v, D, C) for v in BROWS if BROWS[v]]
    parts += [build_mouth(v, D, C) for v in MOUTHS] + [build_blush(D, C)]
    parts += [build_top(s, D, C) for s in TOPS] + [build_bottom(s, D, C) for s in BOTTOMS]
    parts += [build_shoes(s, D, C) for s in SHOES] + [build_hands(D, C)]
    parts += [build_acc(a, D, C) for a in ACC]
    return parts


# ------------------------------------------------------------------ Blender side

def build_armature(name, D, coll):
    ad = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, ad)
    coll.objects.link(ob)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    heads = bone_heads(D)
    for bn in BONES:
        eb = ad.edit_bones.new(bn)
        x, y, z = heads[bn]
        eb.head = (x * VOX, y * VOX, z * VOX)
        eb.tail = (x * VOX, y * VOX, z * VOX + (0.15 if bn == "root" else 0.08))
        eb.roll = 0.0
    for bn, par in PARENT.items():
        ad.edit_bones[bn].parent = ad.edit_bones[par]
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    ad.display_type = "STICK"
    ob.show_in_front = True
    return ob


def build_mesh(part, name, coll, arm=None, offset=(0.0, 0.0, 0.0)):
    """Mesh the exposed faces as merged rectangles (bc_kit.greedy_faces), one bone at a time, so faces between
    voxels of different bones stay closed when the limbs move. UVs follow bc_kit v2: voxel units on the jitter/seam
    texture, offset per plane by a hash. Decals are single quads. One vertex group per bone, weight 1.0.
    Returns (object, triangles)."""
    ox, oy, oz = offset
    verts, faces, mats, uvs, groups = [], [], [], [], {}
    lookup = {}
    for m, _ in part.cells.values():
        lookup[mat_key(m)] = m
    for d in part.decals:
        lookup[mat_key(d[3])] = d[3]
    keys = sorted(lookup)
    slot = {k: i for i, k in enumerate(keys)}

    def emit(quad, key, bone):
        base = len(verts)
        for q in quad:
            verts.append(((q[0]) * VOX + ox, (q[1]) * VOX + oy, (q[2]) * VOX + oz))
            uvs.append(q[3:])
        faces.append((base, base + 1, base + 2, base + 3))
        mats.append(slot[key])
        groups.setdefault(bone, []).extend(range(base, base + 4))

    by_bone = {}
    for cell, (m, bone) in part.cells.items():
        by_bone.setdefault(bone, {})[cell] = mat_key(m)
    for bone in sorted(by_bone):
        rects, _ = K.greedy_faces(by_bone[bone], lambda cell, d: False)
        for d, w, a0, b0, wa, wb, key in rects:
            k = next(i for i in range(3) if d[i])
            ax, bx = K.AXES[k]
            plane = w + (1 if d[k] > 0 else 0)
            step = 2 if K.swatch(key)[0] in K.BLOCK2 else 1
            h = zlib.crc32(("%s|%d,%d,%d|%d" % (part.pid, *d, w)).encode())
            ou, ov = (h % (K.TILE // step)) * step, ((h >> 8) % (K.TILE // step)) * step
            quad = []
            for ca, cb in ((a0, b0), (a0 + wa, b0), (a0 + wa, b0 + wb), (a0, b0 + wb)):
                p = [0.0, 0.0, 0.0]
                p[k], p[ax], p[bx] = plane, ca, cb
                quad.append((p[0], p[1], p[2], (ca + ou) / K.TILE, (cb + ov) / K.TILE))
            e1 = [quad[1][i] - quad[0][i] for i in range(3)]
            e2 = [quad[2][i] - quad[0][i] for i in range(3)]
            n = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
            if n[k] * d[k] < 0:
                quad.reverse()                                       # counter-clockwise seen from outside
            emit(quad, key, bone)
    eps = DECAL_EPS / VOX
    for x, y, z, m, bone in part.decals:                             # front-facing (-Y) pixel quads
        u0 = (x % K.TILE) / K.TILE
        v0 = (z % K.TILE) / K.TILE
        du = 1.0 / K.TILE
        emit([(x, y - eps, z, u0, v0), (x + 1, y - eps, z, u0 + du, v0),
              (x + 1, y - eps, z + 1, u0 + du, v0 + du), (x, y - eps, z + 1, u0, v0 + du)], mat_key(m), bone)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    for k in keys:
        me.materials.append(material(lookup[k]))
    me.polygons.foreach_set("material_index", mats)
    uv = me.uv_layers.new(name="UVMap")
    uv.data.foreach_set("uv", [c for p in uvs for c in p])
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    if arm is not None:
        ob.parent = arm
        for bone, idx in groups.items():
            ob.vertex_groups.new(name=bone).add(idx, 1.0, "REPLACE")
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    return ob, len(faces) * 2


# ------------------------------------------------------------------ animation
# Pose functions take the phase t in [0, 1) and the body dims and return {bone: spec}. Model space: +X the
# character's left, -Y forward, +Z up, in voxels. A spec is one of
#   ((pitch, yaw, roll) degrees, (x, up, forward) voxels)   local Euler, as in kit v1:
#       pitch + : the part above the pivot tips forward; a hanging limb swings back
#       yaw   + : turns toward the character's left (+X)
#       roll  + : the top tilts to the character's right; a hanging arm_L lifts outward (arm_R uses roll -)
#   ("dir", (x, y, z))   a limb segment points this way in model space (shoulder->elbow, elbow->hand, hip->knee...)
# and, for a whole arm, "armL" / "armR" -> one of
#   ("dirs", upper, fore)          both segment directions
#   ("reach", z, out, fore)        upper arm swings forward until the elbow is at height z (out = sideways
#                                  voxels), forearm direction `fore`: forearms flat on a table or a bar
#   ("ik", target, pole)           hand centre at `target`, elbow toward `pole`
#   ("mix", A, B, w)               blend two of the above (segment directions, w 0..1)
# A level forward forearm (0, -1, 0) holds drinks and the tray upright (see the ACC note).
# Every loop is periodic in t, so frame 0 == the last frame.
TAU = 2 * math.pi
_B = Matrix.Rotation(math.radians(90), 3, "X")       # bone rest frame (Y along the bone = model up) in model space
_BI = _B.transposed()


def S(t, cycles=1.0, phase=0.0):
    return math.sin(TAU * (cycles * t + phase))


def C_(t, cycles=1.0, phase=0.0):
    return math.cos(TAU * (cycles * t + phase))


def bump(t, a, b):
    """0 outside [a, b], a smooth 0 -> 1 -> 0 hump inside."""
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a)) ** 2


def plateau(t, a, b, ramp=0.08):
    """0 -> 1 over [a, a + ramp], 1 until b - ramp, back to 0 at b (a sip, a pour)."""
    if t <= a or t >= b:
        return 0.0
    u = min((t - a) / ramp, (b - t) / ramp, 1.0)
    return math.sin(0.5 * math.pi * u) ** 2


def mx(v):
    """Mirror a model-space vector to the other side."""
    return (-v[0], v[1], v[2])


def pose(**bones):
    out = {}
    for bn, v in bones.items():
        if bn in ("armL", "armR") or (isinstance(v, tuple) and v and v[0] == "dir"):
            out[bn] = v
            continue
        r = tuple(v[0]) if v and len(v) > 0 else (0, 0, 0)
        l = tuple(v[1]) if v and len(v) > 1 else (0, 0, 0)
        out[bn] = (r, l)
    return out


def _arm_dirs(spec, S0, D, side):
    """Resolve an armL / armR spec to (upper, fore) model-space directions, given the posed shoulder S0."""
    heads = bone_heads(D)
    a = heads["arm_" + side][2] - heads["forearm_" + side][2]
    b = heads["forearm_" + side][2] - (D["az0"] + 1)
    kind = spec[0]
    if kind == "dirs":
        return Vector(spec[1]).normalized(), Vector(spec[2]).normalized()
    if kind == "reach":
        dz = max(-a, min(a, spec[1] - S0.z))
        out = spec[2] * (1 if side == "L" else -1)
        fwd = math.sqrt(max(a * a - dz * dz - out * out, 0.01))
        return Vector((out, -fwd, dz)).normalized(), Vector(spec[3]).normalized()
    if kind == "ik":
        T, pole = Vector(spec[1]), Vector(spec[2])
        d = T - S0
        dist = max(abs(a - b) + 1e-3, min(a + b - 1e-3, d.length))
        dn = d.normalized()
        x = (a * a - b * b + dist * dist) / (2 * dist)
        hh = math.sqrt(max(a * a - x * x, 0.0))
        pp = pole - dn * pole.dot(dn)
        pp = pp.normalized() if pp.length > 1e-6 else Vector((0, 0, -1))
        E = S0 + dn * x + pp * hh
        return (E - S0).normalized(), (S0 + dn * dist - E).normalized()
    if kind == "mix":
        u1, f1 = _arm_dirs(spec[1], S0, D, side)
        u2, f2 = _arm_dirs(spec[2], S0, D, side)
        w = spec[3]
        return (u1 * (1 - w) + u2 * w).normalized(), (f1 * (1 - w) + f2 * w).normalized()
    raise KeyError(kind)


def _limb_frame(d):
    """Rotation that hangs a forearm along d with its front (rest -Y, the palm side of the props) turned up,
    so a level forearm holds glasses and the tray upright whatever the upper arm did. A forearm hanging nearly
    straight down keeps its front forward."""
    up, fwd = Vector((0, 0, 1)), Vector((0, -1, 0))
    h = up - d * up.dot(d)
    if h.length < 0.35:
        h = fwd - d * fwd.dot(d)
    h.normalize()
    a0, f0 = Vector((0, 0, -1)), Vector((0, -1, 0))
    rest = Matrix((a0, f0, a0.cross(f0))).transposed()
    goal = Matrix((d, h, d.cross(h))).transposed()
    return goal @ rest.transposed()


def solve(p, D):
    """Pose spec -> {bone: (local quaternion, local location in voxels)} by forward kinematics in model space."""
    heads = {k: Vector(v) for k, v in bone_heads(D).items()}
    W = {}
    out = {}
    arm = {}
    down = Vector((0, 0, -1))
    for bn in BONES:
        par = PARENT.get(bn)
        if par:
            ppos, prot = W[par]
            pos = ppos + prot @ (heads[bn] - heads[par])
        else:
            ppos, prot, pos = Vector((0, 0, 0)), Matrix.Identity(3), heads[bn].copy()
        loc = Vector((0, 0, 0))
        side = bn[-1]
        want = None
        if bn in ("arm_L", "arm_R") and ("arm" + side) in p:
            arm[side] = _arm_dirs(p["arm" + side], pos, D, side)
            want = arm[side][0]
        elif bn in ("forearm_L", "forearm_R") and side in arm:
            want = arm[side][1]
        elif isinstance(p.get(bn), tuple) and p[bn] and p[bn][0] == "dir":
            want = Vector(p[bn][1]).normalized()
        if want is not None and bn.startswith("forearm"):
            Rw = _limb_frame(want)
        elif want is not None:
            cur = prot @ down
            Rw = cur.rotation_difference(want).to_matrix() @ prot
        else:
            e, l = p.get(bn, ((0, 0, 0), (0, 0, 0)))
            local = _B @ Euler([math.radians(a) for a in e], "ZYX").to_matrix() @ _BI
            Rw = prot @ local
            loc = Vector(l)
            pos = pos + prot @ (_B @ loc)
        q = (_BI @ (prot.transposed() @ Rw) @ _B).to_quaternion()
        out[bn] = (q, loc)
        W[bn] = (pos, Rw)
    return out


# ---- standing and walking (kit v1 timings, now with elbows and knees)

def a_idle(t, D):
    br = S(t)
    return pose(spine=((1.5 * br, 0, 0),), head=((-1.0 * S(t, 1, 0.15), 4 * S(t, 1, 0.3), 0),),
                hips=((0, 0, 0), (0, 0.15 * (1 + br) / 2, 0)),
                arm_L=((1.5 * br, 0, 3 + br),), arm_R=((1.5 * br, 0, -3 - br),),
                forearm_L=((-10, 0, 0),), forearm_R=((-10, 0, 0),))


def a_idle_warm(t, D):            # 1 Warm: sways to the music (two sways per loop)
    s = S(t, 2)
    bob = 0.35 * (1 - C_(t, 4)) / 2
    return pose(hips=((0, 0, -2 * s), (0.3 * s, bob, 0)), spine=((1, 0, 4 * s),),
                head=((-2, 0, 5 * S(t, 2, 0.12)),),
                arm_L=((6 * S(t, 2, 0.25), 0, 5 + 2 * s),), arm_R=((-6 * S(t, 2, 0.25), 0, -5 + 2 * s),),
                forearm_L=((-20, 0, 0),), forearm_R=((-20, 0, 0),))


def a_idle_tipsy(t, D):           # 2 Tipsy: leans, laughs at nothing, taps a foot
    laugh = bump(t, 0.25, 0.5)
    shake = S(t, 14) * laugh
    tap = max(0.0, S(t, 4)) ** 2
    return pose(hips=((0, 0, -3), (0.5, 0, 0)), spine=((2 - 5 * laugh, 0, 7 + 2 * S(t)),),
                head=((-10 * laugh + 3 * shake, 0, 6 + 3 * S(t, 1, 0.2)),),
                arm_L=((-15 * laugh, 0, 14 + 3 * S(t)),), arm_R=((-25 * laugh, 0, -4 - 2 * laugh),),
                forearm_R=((-30 * laugh, 0, 0),),
                leg_R=((-14 * tap, 0, 0),), shin_R=((10 * tap, 0, 0),))


def a_idle_merry(t, D):           # 3 Merry: slow big sway, chin up, sings along with one arm up
    s = S(t)
    return pose(hips=((0, 0, -3 * s), (0.7 * s, 0, 0)), spine=((-2, 0, 7 * s),),
                head=((-8, 0, 9 * S(t, 1, 0.12)),),
                arm_R=((-140 + 10 * S(t, 2), 0, -35),), forearm_R=((-20, 0, 0),), arm_L=((4 * s, 0, 6 + 3 * s),))


def a_idle_sad(t, D):             # low Vibe (GDD 2.2 Meh / Homebody): slumped, head down, a slow sigh
    sigh = bump(t, 0.45, 0.8)
    return pose(spine=((13 + 4 * sigh, 0, 0),), head=((18 + 3 * S(t) - 6 * sigh, 0, 2 * S(t, 1, 0.3)),),
                hips=((0, 0, 0), (0, 0.2 * sigh, 0)),
                arm_L=((-7, 0, 1),), arm_R=((-7, 0, -1),))


def walk(t, D, legs=28, arms=24, bob=0.6, lean=4, weave=0.0, roll=0.0, hum=0.0, arms_wide=2, arm_R=True):
    s = S(t)
    up = bob * (1 + C_(t, 2)) / 2
    kneeL = 30 * max(0.0, S(t, 1, 0.3))                    # the swinging leg folds at the knee
    kneeR = 30 * max(0.0, S(t, 1, 0.8))
    p = pose(
        hips=((0, 6 * weave * S(t, 1, 0.25), roll * S(t)), (weave * S(t, 1, 0.25), up, 0)),
        spine=((lean, 4 * s, -roll * 0.7 * S(t, 1, 0.1)),),
        head=((-2 + hum * S(t, 4), -3 * s, roll * 0.5 * S(t, 1, 0.3) + hum * 0.6 * S(t, 2)),),
        leg_L=((-legs * s, 0, 0),), leg_R=((legs * s, 0, 0),), shin_L=((kneeL, 0, 0),), shin_R=((kneeR, 0, 0),),
        arm_L=((arms * s, 0, arms_wide),), forearm_L=((-12 - 8 * max(0.0, -s), 0, 0),))
    if arm_R:
        p.update(pose(arm_R=((-arms * s, 0, -arms_wide),), forearm_R=((-12 - 8 * max(0.0, s), 0, 0),)))
    return p


def a_walk(t, D):
    return walk(t, D)


def a_walk_warm(t, D):            # small bounce in the step
    return walk(t, D, legs=30, arms=30, bob=1.2, roll=3)


def a_walk_tipsy(t, D):           # loose half-step weave, never a stumble
    return walk(t, D, legs=24, arms=26, bob=0.7, lean=2, weave=0.8, roll=5, arms_wide=8)


def a_walk_merry(t, D):           # slower, humming, arms swinging wide; never past 8 degrees of lean
    return walk(t, D, legs=20, arms=45, bob=0.6, lean=0, weave=0.5, roll=7, hum=3, arms_wide=12)


def a_dance(t, D):                # four beats: hop, alternating arm pumps, twist
    hop = 0.8 * (1 - C_(t, 4)) / 2
    s = S(t)
    return pose(hips=((0, 12 * s, 0), (0, hop, 0)), spine=((0, 8 * s, 5 * S(t, 2)),),
                head=((-3, -6 * s, 8 * S(t, 2, 0.15)),),
                arm_L=((-110 + 60 * s, 0, 25 + 20 * (1 - s) / 2),), arm_R=((-110 - 60 * s, 0, -25 - 20 * (1 + s) / 2),),
                forearm_L=((-40, 0, 0),), forearm_R=((-40, 0, 0),),
                leg_L=((-12 * S(t, 2), 0, 0),), leg_R=((12 * S(t, 2), 0, 0),),
                shin_L=((14 * max(0.0, S(t, 2)), 0, 0),), shin_R=((14 * max(0.0, -S(t, 2)), 0, 0),))


def mouth_point(D, rise=0.0):
    return Vector((-0.5, HY0 - 2.5, D["h"] + MOUTH_Z + 1 + rise))


def chest_hold(D, side="R"):
    """Glass held in front of the chest: elbow at the side, forearm level and pointing forward."""
    v = ("dirs", (-0.15, -0.3, -1), (0.35, -1, 0.02))
    return v if side == "R" else ("dirs", mx(v[1]), mx(v[2]))


def sip(D, rise=0.0):
    """Glass at the lips, tipped toward the face."""
    return ("ik", tuple(mouth_point(D, rise) + Vector((-1.5, -2.5, -1.5))), (-1, 0.6, -0.6))


def a_stand_drink(t, D):          # 05/06: standing with a glass, weight on one leg, a sip every loop
    s = bump(t, 0.55, 0.85)
    br = S(t)
    return pose(hips=((0, 4, -2), (0.4, 0.1 * (1 + br), 0)), spine=((1 + br, -3, 2),), head=((-3 - 6 * s, -4, 0),),
                armR=("mix", chest_hold(D), sip(D), s),
                armL=("dirs", (0.55, 0.25, -1), (-0.75, -0.2, -0.45)),                 # hand on the hip
                leg_R=((0, 0, -3),), shin_R=((4, 0, 0),))


def a_cheers(t, D):               # one-shot: raise the glass, clink, back down
    up = bump(t, 0.0, 1.0) ** 0.6
    clink = bump(t, 0.35, 0.5)
    raised = ("dirs", (0.15, -0.75, 0.6 + 0.15 * clink), (0.25, -1, 0.05))
    return pose(armR=("mix", chest_hold(D), raised, up), spine=((-3 * up, 6 * up, 0),),
                head=((-8 * up, 4 * up, 0),), arm_L=((0, 0, 3),), forearm_L=((-10, 0, 0),))


def a_applaud(t, D):              # two claps per loop, hands meet in front of the chest
    c = (1 + C_(t, 2)) / 2
    z = D["h"] - 4
    return pose(armL=("ik", (0.6 + 2.2 * c, -6.0, z), (1, 0.3, -0.5)),
                armR=("ik", (-0.6 - 2.2 * c, -6.0, z), (-1, 0.3, -0.5)),
                head=((-4 + 2 * c, 0, 0),), spine=((-1, 0, 0),), hips=((0, 0, 0), (0, 0.2 * c, 0)))


# ---- seated. Thigh undersides on the seat (SEAT_VOX), knees bent, shins down; the venue lowers the root so
# SEAT_VOX lands on the real seat (0.45 m chairs and drum stools, 0.8 m bar stools).

def sit_rise(D):
    return SEAT_VOX + 2 - D["leg"]


def seated(D, lean=2.0, yaw=0.0, legs=1.0, t=0.0, **extra):
    r = sit_rise(D)
    sw = 4 * S(t, 1) * legs
    p = pose(hips=((0, yaw, 0), (0, r, 0)), spine=((lean, 0, 0),),
             leg_L=((-86, 0, 3),), leg_R=((-86, 0, -3),), shin_L=((92 + sw, 0, 0),), shin_R=((92 - sw, 0, 0),))
    p.update(pose(**extra))
    return p


def table_arm(D, side, inward=0.4, z_off=0.0):
    """Forearm flat on a table or bar top (TABLE_VOX), pointing forward and a little inward."""
    f = (-inward, -1, 0) if side == "L" else (inward, -1, 0)
    return ("reach", TABLE_VOX + 1.6 + z_off, 0.4, f)


def a_sit(t, D):                  # relaxed on a chair, hands on the thighs
    br = S(t)
    return seated(D, 2 + 1.5 * br, t=t, head=((-2, 5 * S(t, 1, 0.3), 0),),
                  armL=("dirs", (0.1, -0.45, -1), (-0.1, -1, -0.55)),
                  armR=("dirs", (-0.1, -0.45, -1), (0.1, -1, -0.55)))


def a_sit_drink(t, D):            # 05/06: at a table, forearms on the top, glass in the right hand, a sip per loop
    s = plateau(t, 0.42, 0.72)
    br = S(t)
    return seated(D, 9 + br, t=t, legs=0.3, head=((-6 - 6 * s, 6 * S(t, 1, 0.2) * (1 - s), 0),),
                  armL=table_arm(D, "L"),
                  armR=("mix", table_arm(D, "R", 0.2), sip(D, sit_rise(D)), s))


def a_sit_talk(t, D):             # leaning in, chatting: the free hand talks, head nods, glass stays on the table
    g = plateau(t, 0.15, 0.55, 0.1)
    nod = S(t, 4) * 3
    wave = ("dirs", (0.35, -0.7, -0.6), (0.1, -0.6, 0.8 + 0.1 * S(t, 6)))
    return seated(D, 12 + 2 * S(t, 2), yaw=8 * S(t, 1, 0.1), t=t, legs=0.5,
                  head=((-8 + nod, 10 * S(t, 1, 0.35), 2 * S(t, 2)),),
                  armL=("mix", table_arm(D, "L", 0.6), wave, g),
                  armR=table_arm(D, "R", 0.2))


def a_sit_hold(t, D):             # on a drum stool or a lounge chair: glass held at the chest, left hand on the knee
    s = plateau(t, 0.5, 0.78)
    r = sit_rise(D)
    return seated(D, 3 + S(t), t=t, head=((-6 - 4 * s, 5 * S(t, 1, 0.2) * (1 - s), 0),),
                  armR=("mix", chest_hold(D), sip(D, r), s),
                  armL=("dirs", (0.1, -0.5, -1), (-0.1, -1, -0.5)))


def a_sit_applaud(t, D):          # front row, facing the stage
    c = (1 + C_(t, 2)) / 2
    z = D["h"] - 3 + sit_rise(D)
    return seated(D, 1, t=t, head=((-10, 0, 0),),
                  armL=("ik", (0.6 + 2.2 * c, -6.0, z), (1, 0.3, -0.5)),
                  armR=("ik", (-0.6 - 2.2 * c, -6.0, z), (-1, 0.3, -0.5)))


# ---- staff

TRAY = ("dirs", (0.75, -0.15, -0.65), (0.45, -0.9, 0.0))          # elbow out, left forearm level: tray beside the head


def a_idle_tray(t, D):            # 05/06 server waiting with the tray up
    br = S(t)
    return pose(spine=((1 + br, 0, 0),), head=((-3, 6 * S(t, 1, 0.3), 0),), hips=((0, 0, 0), (0, 0.15 * (1 + br) / 2, 0)),
                armL=TRAY, arm_R=((2 * br, 0, -4),), forearm_R=((-15, 0, 0),))


def a_walk_tray(t, D):            # carrying the tray: the tray arm stays level, the other swings
    p = walk(t, D, legs=26, arms=22, bob=0.5, lean=3)
    p.update(pose(armL=TRAY))
    return p


def a_pour(t, D):                 # bartender: glass in the left hand, tips the bottle over it, sets it level
    tip = plateau(t, 0.2, 0.7, 0.12)
    up = ("dirs", (-0.25, -0.6, -0.75), (0.45, -0.8, -0.25))
    pour = ("dirs", (-0.15, -0.75, -0.6), (0.6, -0.55, -0.6))
    return pose(spine=((8, 4, 0),), head=((10 + 4 * tip, 6, 0),),
                armL=("dirs", (0.25, -0.45, -1), (-0.4, -1, 0.0)),
                armR=("mix", up, pour, tip))


# ---- band. Instruments hang on the spine; hands go to the strings and the neck. Neck positions follow
# build_acc's guitar (body x -5.., neck rising to +X).

def strum(t, D, inst="guitar", rate=4, sing=False):
    leg = D["leg"]
    y = D["y0"] - 3.0                                   # just in front of the strings
    st = S(t, rate)
    fret = S(t, 1, 0.1)
    neck = {"guitar": (3.0, 18.0), "guitar_electric": (3.0, 18.0), "bass": (3.0, 18.5)}[inst]
    sway = S(t, 2)
    return pose(hips=((0, 6, 0), (0, 0.25 * (1 - C_(t, 4)) / 2, 0)), spine=((9 + sway, -6, 2 * sway),),
                head=((-14 if sing else 2, 10 if not sing else -6, 3 * S(t, 2, 0.2)),),
                armR=("ik", (-3.0, y, leg + 3.5 + 1.0 * st), (-1, 0.6, -0.2)),
                armL=("ik", (neck[0] + fret, y, neck[1] + fret), (0.6, 0.3, -1)),
                leg_R=((0, 0, -4),), leg_L=((0, 0, 4),), shin_L=((3 * (1 - C_(t, 4)) / 2, 0, 0),))


def a_play_guitar(t, D):
    return strum(t, D, "guitar_electric", 4)


def a_play_bass(t, D):
    return strum(t, D, "bass", 2)


def a_sing(t, D):                 # Jo: acoustic guitar at the mic stand, chin up to the mic
    return strum(t, D, "guitar", 2, sing=True)


def a_play_drums(t, D):           # seated at the kit, sticks alternate on the snare, a cymbal crash per loop
    hitL = max(0.0, S(t, 4)) ** 2
    hitR = max(0.0, S(t, 4, 0.5)) ** 2
    crash = bump(t, 0.7, 0.95)
    return seated(D, 8, t=0, legs=0, head=((-2 + 5 * hitL, 8 * S(t, 1), 0),),
                  armL=("dirs", (0.3, -0.35, -0.9), (-0.25, -1, 0.35 - 0.7 * hitL)),
                  armR=("mix", ("dirs", (-0.3, -0.35, -0.9), (0.25, -1, 0.35 - 0.7 * hitR)),
                        ("dirs", (-0.7, -0.5, -0.3), (-0.2, -1, 0.5 - 0.9 * crash)), crash),
                  shin_R=((92 - 18 * hitR, 0, 0),))


# name, frames, pose fn, loops. Tipsiness names follow the cast bible (5.1): clear = the base idle/walk.
ANIMS = [
    ("idle", 48, a_idle, True), ("walk", 16, a_walk, True), ("sit", 48, a_sit, True),
    ("sit_drink", 96, a_sit_drink, True), ("sit_talk", 96, a_sit_talk, True), ("sit_hold", 96, a_sit_hold, True),
    ("sit_applaud", 24, a_sit_applaud, True), ("stand_drink", 96, a_stand_drink, True),
    ("cheers", 36, a_cheers, False), ("applaud", 24, a_applaud, True), ("dance", 48, a_dance, True),
    ("idle_warm", 48, a_idle_warm, True), ("idle_tipsy", 72, a_idle_tipsy, True), ("idle_merry", 96, a_idle_merry, True),
    ("walk_warm", 16, a_walk_warm, True), ("walk_tipsy", 24, a_walk_tipsy, True), ("walk_merry", 32, a_walk_merry, True),
    ("idle_sad", 72, a_idle_sad, True),
    ("idle_tray", 48, a_idle_tray, True), ("walk_tray", 16, a_walk_tray, True), ("pour", 72, a_pour, True),
    ("play_guitar", 48, a_play_guitar, True), ("play_bass", 48, a_play_bass, True), ("sing", 48, a_sing, True),
    ("play_drums", 48, a_play_drums, True),
]
STAFF_ANIMS = ("idle_tray", "walk_tray", "pour")
BAND_ANIMS = ("play_guitar", "play_bass", "sing", "play_drums")
WALK_SPEED = {"walk": 1.1, "walk_warm": 1.1, "walk_tipsy": 0.85, "walk_merry": 0.7, "walk_tray": 1.0}   # m/s


def anims_for(spec):
    """Every preset gets the shared set; staff add the tray and pour, the band their instruments."""
    extra = set()
    if spec["role"] == "staff":
        extra |= set(STAFF_ANIMS)
    if any(a in INSTRUMENTS for a in spec["acc"]):
        extra |= set(BAND_ANIMS)
    return [a[0] for a in ANIMS if a[0] not in STAFF_ANIMS + BAND_ANIMS or a[0] in extra]


def _fcurves(act):
    """F-curves of an action, for both the legacy and the layered (Blender 4.4+) action layouts."""
    if hasattr(act, "layers") and act.layers:
        return [fc for layer in act.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
    return list(getattr(act, "fcurves", []))


def make_actions(arm, D, prefix="", names=None):
    """One action per ANIMS entry (or the named subset), keyed every 3 frames from its pose function.
    Returns {name: action}."""
    arm.animation_data_create()
    acts = {}
    for name, length, fn, _loop in ANIMS:
        if names is not None and name not in names:
            continue
        act = bpy.data.actions.new(prefix + name)
        act.use_fake_user = True
        arm.animation_data.action = act
        prev = {}
        for f in sorted(set(list(range(0, length, 3)) + [length])):
            sol = solve(fn((f % length) / length, D), D)
            for bn in BONES:
                pb = arm.pose.bones[bn]
                q, l = sol[bn]
                if bn in prev and prev[bn].dot(q) < 0:
                    q = -q                                           # keep quaternions on one hemisphere
                prev[bn] = q
                pb.rotation_quaternion = q
                pb.location = (l[0] * VOX, l[1] * VOX, l[2] * VOX)
                pb.keyframe_insert("rotation_quaternion", frame=f, group=bn)
                if bn in ("hips", "root"):
                    pb.keyframe_insert("location", frame=f, group=bn)
        for fc in _fcurves(act):
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
        act.use_frame_range = True
        act.frame_start, act.frame_end = 0, length
        act.use_cyclic = _loop
        # keys are dense (every 3 frames) and linear, so the exporter writes them as authored: rotation for every
        # bone, translation for root and hips only, no scale channels (sampling wrote all three for all 12 bones)
        acts[name] = act
    arm.animation_data.action = acts.get("idle") or next(iter(acts.values()))
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    return acts


def export_glb(objs, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    want = dict(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
                export_texcoords=True, export_normals=True, export_materials="EXPORT",
                export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_image_format="AUTO",
                export_skins=True, export_animations=True, export_animation_mode="ACTIONS",
                export_frame_range=False, export_force_sampling=False,
                export_anim_slide_to_zero=True,
                export_def_bones=False, export_rest_position_armature=True, export_reset_pose_bones=True,
                export_optimize_animation_size=True, export_extras=False, export_cameras=False,
                export_lights=False)
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    bpy.ops.export_scene.gltf(**{k: v for k, v in want.items() if k in props})


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    K._MATS.clear()
    bpy.context.scene.render.fps = FPS



def build_character(spec, coll, prefix="", with_actions=True):
    D = dims(spec["body"])
    arm = build_armature(prefix + "rig", D, coll)
    objs, tris, top = [arm], 0, 0
    for part in assemble(spec):
        ob, t = build_mesh(part, prefix + (part.slot if part.slot in SLOTS or part.slot == "hands" else part.pid), coll, arm)
        objs.append(ob)
        tris += t
        top = max([top] + [c[2] + 1 for c in part.cells])
    acts = make_actions(arm, D, names=anims_for(spec)) if with_actions else None
    return arm, objs, tris, top, acts


def colours_used(spec, parts):
    used = {}
    for p in parts:
        for m, _ in p.cells.values():
            used[m[0]] = m[1]
        for d in p.decals:
            used[d[3][0]] = d[3][1]
    return {k: {"swatch": v, "hex": hexof(v)} for k, v in sorted(used.items())}


def export_presets(only=None):
    out = []
    for spec in PRESETS:
        if only and spec["name"] not in only:
            continue
        reset()
        coll = bpy.context.scene.collection
        arm, objs, tris, top, _ = build_character(spec, coll)
        rel = "presets/%s.glb" % spec["name"]
        export_glb(objs, os.path.join(OUT, rel))
        parts = assemble(spec)
        out.append({
            "name": spec["name"], "display": spec["display"], "role": spec["role"], "slot": spec["slot_id"],
            "path": "res://assets/chars/" + rel, "body": spec["body"],
            "parts": {k: spec[k] for k in SLOTS} | {"accessories": spec["acc"]},
            "colours": colours_used(spec, parts),
            "height_m": round(top * VOX, 3), "height_vox": top,
            "head_top_vox": dims(spec["body"])["T"] + 1, "tris": tris,
            "animations": anims_for(spec),
            "bytes": os.path.getsize(os.path.join(OUT, rel)),
        })
        print("BC_CHARS %-12s %-8s %-8s h=%2d vox tris=%5d %4d KB" % (spec["name"], spec["role"], spec["body"], top,
                                                                       tris, out[-1]["bytes"] // 1024))
    return out


def export_libraries():
    libs = {}
    for body in BODIES:
        reset()
        coll = bpy.context.scene.collection
        D = dims(body)
        arm = build_armature("rig", D, coll)
        objs, entries = [arm], []
        for part in library_parts(body):
            ob, t = build_mesh(part, part.pid, coll, arm)
            objs.append(ob)
            bones = sorted(set(b for _, b in part.cells.values()) | set(d[4] for d in part.decals))
            mats = sorted(set(mat_key(m) for m, _ in part.cells.values()) | set(mat_key(d[3]) for d in part.decals))
            entries.append({"id": part.pid, "slot": part.slot, "bones": bones, "materials": mats, "tris": t})
        make_actions(arm, D)
        rel = "parts/parts_%s.glb" % body
        export_glb(objs, os.path.join(OUT, rel))
        libs[body] = {"path": "res://assets/chars/" + rel, "height_vox": D["T"] + 1, "parts": entries}
        print("BC_CHARS library %-8s %d parts" % (body, len(entries)))
    return libs


def write_manifest(presets, libs):
    data = {
        "voxel_m": VOX, "fps": FPS, "front": "+Z (Godot) / -Y (Blender)", "left": "+X",
        "seat_vox": SEAT_VOX, "fig_scale": FIG_SCALE,
        "bones": {b: PARENT.get(b) for b in BONES},
        "bodies": {b: {k: v for k, v in dims(b).items() if k in ("tw", "td", "leg", "chest", "h", "T", "elbow", "knee")}
                   for b in BODIES},
        "animations": [{"name": n, "frames": f, "seconds": round(f / FPS, 3), "loop": lp,
                        "root_speed_mps": WALK_SPEED.get(n, 0.0)} for n, f, _, lp in ANIMS],
        "drinks": list(DRINKS),
        "swatches": {"skin": SKIN, "hair": HAIR,
                     "wardrobe": {**{k: K.PALETTE[k][0] for k in WARDROBE_BIBLE}, **WARDROBE_ADDED}, "face": FACE},
        "parts": {"heads": list(HEADS), "hair": list(HAIRS), "eyes": list(EYES), "brows": [b for b in BROWS if BROWS[b]],
                  "mouths": list(MOUTHS), "tops": list(TOPS), "bottoms": list(BOTTOMS), "shoes": list(SHOES),
                  "accessories": {a: {"slot": v[0], "colours": [v[1], v[2]]} for a, v in ACC.items()}},
        "libraries": libs,
        "presets": presets,
    }
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=1)
        f.write("\n")


# ------------------------------------------------------------------ review .blend + showcase render

ROWS = [("Regulars", "regular"), ("Staff and band", ("staff", "band")), ("Anonymous patrons", "patron")]
SPACING = 0.9
ROW_GAP = 2.0
POSE_FRAME = 12                # the still shows every armature at this frame
ANIM_ROW = "patron_01"        # the preset that demonstrates the shared animations
ANIM_DEMO = {"idle_tray": "server", "walk_tray": "server", "pour": "nam", "play_guitar": "band_guitar",
             "play_bass": "pete", "sing": "jo", "play_drums": "boy", "sit_talk": "patron_02",
             "sit_hold": "patron_04", "stand_drink": "patron_03", "cheers": "patron_03"}
SEATED = {"sit": 9, "sit_drink": 9, "sit_talk": 9, "sit_hold": 9, "sit_applaud": 9, "play_drums": 9}


def text(coll, name, body, loc, size, mat, rot=(0, 0, 0)):
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = body
    cu.size = size
    cu.align_x = "CENTER"
    cu.materials.append(mat)
    ob = bpy.data.objects.new(name, cu)
    ob.location = loc
    ob.rotation_euler = rot
    coll.objects.link(ob)
    return ob


def stand_in(coll, name, size, loc, sw):
    """A box of furniture (chair seat, table top) so the seated poses read in the review still."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    ob.data.materials.append(K.material(sw))
    for c in ob.users_collection:
        c.objects.unlink(ob)
    coll.objects.link(ob)
    return ob


def set_action(arm, act):
    arm.animation_data_create()
    arm.animation_data.action = act
    try:
        if arm.animation_data.action_slot is None and act.slots:
            arm.animation_data.action_slot = act.slots[0]
    except AttributeError:
        pass


def hide_props(objs, anim):
    show = anim in ("sit_drink", "sit_talk", "sit_hold", "stand_drink", "cheers", "pour")
    for o in objs:
        base = o.name.split(".")[-1]
        if base in DRINKS:
            o.hide_render = o.hide_viewport = not show
            if base == "bottle" and anim != "pour":
                o.hide_render = o.hide_viewport = True


def review_content(scene, lab):
    """The preset rows, the animation row and the parts lineup, one collection each, starting at y = 0 and
    growing toward +Y. Returns (depth, widest row width) in metres. Shared by build_review and bc_review.py.
    Characters are drawn at FIG_SCALE, as in the venue."""
    y = 0.0
    acts = {}
    widest = 0.0
    specs = {p["name"]: p for p in PRESETS}

    def actions_for(spec, arm):
        key = spec["name"]
        if key not in acts:
            acts[key] = make_actions(arm, dims(spec["body"]), prefix=key + ".", names=anims_for(spec))
        return acts[key]

    for title, roles in ROWS:
        roles = (roles,) if isinstance(roles, str) else roles
        group = [p for p in PRESETS if p["role"] in roles]
        coll = bpy.data.collections.new(title)
        scene.collection.children.link(coll)
        width = SPACING * (len(group) - 1)
        widest = max(widest, width)
        text(coll, title + "_title", title, (-width / 2 - 1.0, y, 0.002), 0.16, lab).data.align_x = "RIGHT"
        for i, spec in enumerate(group):
            x = -width / 2 + i * SPACING
            arm, objs, _, _, _ = build_character(spec, coll, prefix=spec["name"] + ".", with_actions=False)
            arm.location = (x, y, 0)
            arm.scale = (FIG_SCALE,) * 3
            set_action(arm, actions_for(spec, arm)["idle"])
            hide_props(objs, "idle")
            text(coll, spec["name"] + "_label", spec["display"], (x, y - 0.45, 0.002), 0.07, lab)
        y += ROW_GAP
    # one character per animation, on stand-in chairs and tables for the seated ones
    coll = bpy.data.collections.new("Animations")
    scene.collection.children.link(coll)
    sp = SPACING * 0.95
    width = sp * (len(ANIMS) - 1)
    widest = max(widest, width)
    text(coll, "anim_title", "Animations (frame %d)" % POSE_FRAME, (-width / 2 - 1.0, y, 0.002), 0.16, lab).data.align_x = "RIGHT"
    for i, (name, _, _, _) in enumerate(ANIMS):
        x = -width / 2 + i * sp
        spec = specs[ANIM_DEMO.get(name, ANIM_ROW)]
        arm, objs, _, _, _ = build_character(spec, coll, prefix="anim_%s." % name, with_actions=False)
        arm.scale = (FIG_SCALE,) * 3
        seat = SEATED.get(name)
        if seat is not None:
            arm.location = (x, y, 0.45 - SEAT_VOX * VOX * FIG_SCALE)
            stand_in(coll, "anim_%s.seat" % name, (0.45, 0.45, 0.05), (x, y + 0.05, 0.425), "ChairWood")
            if name in ("sit_drink", "sit_talk"):
                stand_in(coll, "anim_%s.table" % name, (0.7, 0.5, 0.04), (x, y - 0.55, 0.73), "TableWoodLit")
        else:
            arm.location = (x, y, 0)
        set_action(arm, actions_for(spec, arm)[name])
        hide_props(objs, name)
        text(coll, "anim_%s_label" % name, name, (x, y - 0.6, 0.002), 0.06, lab)
    y += ROW_GAP
    # parts lineup: one bust per head shape and hair style, then outfits on mannequins, then props
    lineup = bpy.data.collections.new("Parts lineup")
    scene.collection.children.link(lineup)
    D = dims("regular")
    C = dict(DEFAULT_COLOURS)
    busts = [("head:" + s, [build_head(s, D, C)]) for s in HEADS]
    busts += [("hair:" + s, [build_head("square", D, C), build_hair(s, D, C), build_eyes("dot", D, C),
                             build_brows("flat", D, C)]) for s in HAIRS]
    for i, (e, b, m) in enumerate(zip(EYES, list(BROWS)[1:] + ["flat"], MOUTHS)):
        busts.append(("face %d" % (i + 1), [build_head("soft", D, C), build_eyes(e, D, C), build_brows(b, D, C),
                                              build_mouth(m, D, C), build_hair("buzz", D, C)]))
    for a in ("hat_bucket", "hat_flat_cap", "hat_beanie", "hat_fedora", "glasses_round", "glasses_tinted",
              "glasses_up", "headphones", "beard", "moustache", "ribbon", "pencil"):
        spec = P("b", a, "bust", "", "regular", "square", "ponytail" if a == "ribbon" else "bun" if a == "pencil" else "crop",
                 ("dot", "flat", "small"), "tee", "jeans", "sneakers", [a])
        parts = [p for p in assemble(spec) if p.slot not in ("top", "bottom", "shoes", "hands")]
        busts.append((a, parts))
    mannequin = dict(DEFAULT_COLOURS, top="Stone", bottom="Charcoal")
    bodies = []
    for s in TOPS:
        bodies.append(("top:" + s, "regular", dict(top=s)))
    for s in BOTTOMS:
        bodies.append(("bottom:" + s, "regular", dict(bottom=s)))
    for s in SHOES:
        bodies.append(("shoes:" + s, "regular", dict(shoes=s)))
    for b in BODIES:
        bodies.append(("body:" + b, b, {}))
    for a in ("gig_bag", "apron", "vest", "bar_towel", "gaffer_tape", "guitar", "guitar_electric", "bass", "drumsticks",
              "drink_beer", "drink_mug", "glass_gold", "bottle", "tray", "shaker", "notebook", "torch", "clicker",
              "sketchbook", "vinyl", "wheelie_bag"):
        bodies.append((a, "regular", dict(acc=[a])))
    half = (len(busts) + 1) // 2
    hb = (len(bodies) + 1) // 2
    rows = [(busts[:half], 0.8, True), (busts[half:], 0.8, True), (bodies[:hb], 0.85, False), (bodies[hb:], 0.85, False)]
    y += 0.4
    text(lineup, "lineup_title", "Parts", (-widest / 2 - 1.0, y, 0.002), 0.16, lab).data.align_x = "RIGHT"
    for items, spc, is_bust in rows:
        n = len(items)
        width = spc * (n - 1)
        for i, it in enumerate(items):
            x = -width / 2 + i * spc
            if is_bust:
                label, parts = it
                for part in parts:
                    build_mesh(part, "lineup." + label + "." + part.pid, lineup, offset=(x, y, -D["h"] * VOX))
            else:
                label, body, over = it
                spec = P("m", label, "mannequin", "", body, "square", "buzz", ("dot", "flat", "small"),
                         over.get("top", "tee"), over.get("bottom", "trousers"), over.get("shoes", "sneakers"),
                         over.get("acc", []), **{k: v for k, v in mannequin.items() if k not in ("eyes", "mouth", "blush")})
                for part in assemble(spec):
                    build_mesh(part, "lineup." + label + "." + part.pid, lineup, offset=(x, y, 0))
            text(lineup, "lineup." + label + "_label", label, (x, y - 0.5, 0.002), 0.06, lab)
        y += 1.2 if is_bust else 1.9
    return y, widest


def build_review(render=True):
    reset()
    scene = bpy.context.scene
    scene.name = "Black Cabin Chars"
    lab = K.label_material()
    y, widest = review_content(scene, lab)
    # floor, world, lights, camera
    setup = bpy.data.collections.new("review_setup")
    scene.collection.children.link(setup)
    span_x, span_y = widest + 8.0, y + 3.0
    me = bpy.data.meshes.new("Floor")
    hx, hy = span_x / 2, span_y / 2
    me.from_pydata([(-hx, -hy, 0), (hx, -hy, 0), (hx, hy, 0), (-hx, hy, 0)], [], [(0, 1, 2, 3)])
    me.materials.append(K.material("FloorGrey"))
    fl = bpy.data.objects.new("Floor", me)
    fl.location = (0, y / 2 - 0.5, -0.001)
    setup.objects.link(fl)
    world = bpy.data.worlds.new("CabinDark")
    world.use_nodes = True
    dark = K.hex_linear(K.PALETTE["CabinDark"][0])
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (*dark, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    world.color = dark
    scene.world = world
    K.review_light(setup, "WarmKey", "SUN", (0, 0, 10), 2.4, (1.0, 0.76, 0.56), rot=(math.radians(50), 0, math.radians(20)))
    K.review_light(setup, "RedFill", "SUN", (0, 0, 10), 0.6, (1.0, 0.15, 0.1), rot=(math.radians(60), 0, math.radians(200)))
    K.review_light(setup, "WarmRim", "SUN", (0, 0, 10), 1.2, (1.0, 0.6, 0.3), rot=(math.radians(-60), 0, math.radians(-20)))
    for i in range(4):
        K.review_light(setup, "Pool%d" % i, "POINT", ((i - 1.5) * widest / 3.5, 1.6, 3.0), 500.0, (1.0, 0.72, 0.45), size=0.6)
    cam = bpy.data.objects.new("ReviewCamera", bpy.data.cameras.new("ReviewCamera"))
    cam.data.lens = 35
    cam.data.clip_end = 500.0
    aim = Vector((0.0, y * 0.40, 0.4))
    dist = max(span_x * 0.82, y * 1.15)
    elev = math.radians(38)
    cam.location = aim + Vector((0.0, -dist * math.cos(elev), dist * math.sin(elev)))
    cam.rotation_euler = (aim - cam.location).to_track_quat("-Z", "Y").to_euler()
    setup.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 2400, 1500
    scene.frame_set(POSE_FRAME)
    for screen in bpy.data.screens:
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
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
    print("BC_CHARS review blend -> %s (%.1f MB)" % (BLEND, os.path.getsize(BLEND) / 1e6))
    if render:
        for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
            try:
                scene.render.engine = engine
                break
            except TypeError:
                continue
        scene.render.image_settings.file_format = "PNG"
        scene.render.image_settings.color_mode = "RGB"
        scene.render.image_settings.compression = 100
        scene.render.filepath = SHOWCASE
        scene.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in scene.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
        bpy.ops.render.render(write_still=True)
        print("BC_CHARS showcase -> %s (%s)" % (SHOWCASE, scene.render.engine))


# ------------------------------------------------------------------ run

def run(only=None, blend=True, render=True, review=True):
    names = [p["name"] for p in PRESETS]
    assert len(names) == len(set(names)), "duplicate preset names"
    presets = export_presets(only)
    if only:
        return presets
    libs = export_libraries()
    write_manifest(presets, libs)
    print("BC_CHARS done: %d presets, %d libraries -> %s" % (len(presets), len(libs), OUT))
    if blend:
        build_review(render)
    if review:                                    # the combined review file is always regenerated last
        import bc_review
        bc_review.build(render)
    return presets


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = set(argv[argv.index("--only") + 1].split(",")) if "--only" in argv else None
    if "--review-only" in argv:
        build_review("--no-render" not in argv)
    else:
        run(only, blend="--no-blend" not in argv, render="--no-render" not in argv, review="--no-review" not in argv)
