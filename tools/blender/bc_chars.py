"""Black Cabin Tamagotchi - voxel character kit generator.

Builds chibi voxel characters from swappable parts (art bible section 7, cast bible docs/design/03-cast.md),
rigs them to one shared armature, writes the animations as actions, and exports:
  game/assets/chars/presets/<name>.glb     every named preset (regulars, staff, house band, 12 patrons)
  game/assets/chars/parts/parts_<body>.glb every part for one body type on one armature (runtime assembly)
  game/assets/chars/manifest.json          presets (role, parts, colours, height) and the part list
A full run also saves blender/BlackCabinChars.blend (presets on a labelled grid, a parts lineup, lights, camera,
Material Preview) and renders docs/art/chars-showcase.png.

Run headless from the repo root:
    blender --background --factory-startup --python tools/blender/bc_chars.py
    blender --background --factory-startup --python tools/blender/bc_chars.py -- --only tong,nam --no-blend
`--no-review` skips the combined blender/BlackCabin.blend (bc_review.py), which a full run rebuilds last;
`--no-render` keeps the .blend but skips the PNG; `--review-only` rebuilds just the .blend and the PNG. `--only` runs never write the manifest, libraries or .blend.

Reuses bc_kit (imported, never edited): the voxel scale, the face tables, per-voxel jitter, the seam texture and
the material builder. Character swatches are registered into bc_kit.PALETTE at run time under slot-prefixed keys
(`top__Mustard`), so every material is named <slot>__<Swatch> and the game can find and recolour it.

Scale: 1 voxel = 5 cm. Regular body 29 voxels to the top of the head (1.45 m), 30 with the usual hair cap
(art bible: 30). Head 12 x 12 x 11 on an 18-voxel body. Petite 26 (1.30 m), broad 31 (1.55 m) before hair.
Against the kit: chair seat 9 voxels = regular hip height + 1, bar top 22 = shoulder + 4, table top 15 = mid torso.

Rig: root, hips, spine, head, arm_L, arm_R, leg_L, leg_R. Every bone points up (+Z) with roll 0, so every bone's
rest frame equals the world frame in glTF/Godot. Parts are skinned rigidly: each voxel belongs to exactly one bone
(weight 1.0). Character left = +X; front = -Y in Blender, +Z in Godot.
"""
import json
import math
import os
import sys
import zlib

import bpy

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.path.join(os.getcwd(), "tools", "blender")
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import bc_kit as K                                                   # noqa: E402

VOX = K.VOX
OUT = os.path.join(K.REPO, "game", "assets", "chars")
BLEND = os.path.join(K.REPO, "blender", "BlackCabinChars.blend")
SHOWCASE = os.path.join(K.REPO, "docs", "art", "chars-showcase.png")
FPS = 24
SEAT_VOX = 9                   # cafe chair seat height (art bible section 2)
DECAL_EPS = 0.0015             # face pixels float this far in front of the head

# ------------------------------------------------------------------ swatches
# Skin (derived, warm-biased, light -> deep). The bible asks for 8; the first-playable creator shows 1-6
# (GDD section 7.1 wants 12 at launch: add between these).
SKIN = {
    "Skin1": "#F0D2B6", "Skin2": "#E4BA96", "Skin3": "#D2A07A", "Skin4": "#BC8860",
    "Skin5": "#A06E4A", "Skin6": "#845636", "Skin7": "#6A432C", "Skin8": "#4E3022",
}
HAIR = {
    "HairBlack": "#1E1616", "HairDarkBrown": "#3E2618", "HairBrown": "#6A4228", "HairAuburn": "#7E3220",
    "HairBleach": "#E6D49A", "HairGrey": "#8E8890", "HairWhite": "#E4E0DC", "HairRose": "#B05A64",
}
# Wardrobe (art bible section 7: 24 swatches = section 3 values + mid-value neutrals, a few greens and blues).
# The first 12 are bible Game values (taken from bc_kit.PALETTE), the last 12 are added here.
WARDROBE_BIBLE = ("CabinDark", "StoolBlack", "FloorGrey", "FloorLit", "ColumnWhite", "VelvetRed", "DrumRed",
                  "CymbalGold", "TableWoodLit", "WoodMid", "WoodDark", "PlantGreen")
WARDROBE_ADDED = {
    "Cream": "#D9C9A6", "Sand": "#B49A76", "Stone": "#7C7270", "Charcoal": "#403A3E",
    "Denim": "#3F5878", "DenimLight": "#6C88A8", "Sky": "#86A8C6", "Teal": "#2F6B6A",
    "Olive": "#66703A", "Moss": "#4C5A30", "Mustard": "#C99430", "Rust": "#A04A26",
}
FACE = {"Ink": "#160B0A", "Mouth": "#6A2420", "Blush": "#E0786E", "Lens": "#2A1E1A"}
ROUGH = {"skin": 0.55, "hair": 0.6, "eyes": 0.3, "mouth": 0.5, "blush": 0.6, "lens": 0.1}


def hexof(sw):
    for table in (SKIN, HAIR, WARDROBE_ADDED, FACE):
        if sw in table:
            return table[sw]
    return K.PALETTE[sw][0]


def mat_key(m):
    return "%s__%s" % m


def material(m):
    """m = (slot, swatch). Registers <slot>__<swatch> in bc_kit.PALETTE and builds it with bc_kit.material."""
    key = mat_key(m)
    if key not in K.PALETTE:
        slot, sw = m
        if sw in K.PALETTE and sw not in SKIN:
            _, rough, metal, _ = K.PALETTE[sw]
            rough = max(rough, 0.5) if slot in ("top", "bottom", "top_trim", "bottom_trim") else rough
        else:
            rough, metal = ROUGH.get(slot, 0.85), 0.0
        K.PALETTE[key] = (hexof(sw), rough, metal, 0)
    return K.material(key)


# ------------------------------------------------------------------ bodies, bones

BODIES = {   # torso width/depth, leg rows (incl. 2 shoe rows), chest rows; pelvis is always 2 rows
    "petite":  dict(tw=8, td=6, leg=6, chest=7),
    "regular": dict(tw=8, td=6, leg=8, chest=8),
    "broad":   dict(tw=10, td=8, leg=8, chest=10),
}
HEAD_W, HEAD_D, HEAD_H = 12, 12, 11
HX0, HX1, HY0, HY1 = -6, 5, -6, 5
BONES = ("root", "hips", "spine", "head", "arm_L", "arm_R", "leg_L", "leg_R")
PARENT = {"hips": "root", "spine": "hips", "head": "spine", "arm_L": "spine", "arm_R": "spine",
          "leg_L": "hips", "leg_R": "hips"}


def dims(body):
    d = dict(BODIES[body])
    d["body"] = body
    d["h"] = d["leg"] + 2 + d["chest"]                  # head sits on this row
    d["x0"], d["x1"] = -d["tw"] // 2, d["tw"] // 2 - 1
    d["y0"], d["y1"] = -d["td"] // 2, d["td"] // 2 - 1
    d["az0"] = d["h"] - (d["chest"] + 1)                # bottom row of the arms (hands are 2 rows)
    d["arm_L"] = (d["x1"] + 1, d["x1"] + 3)
    d["arm_R"] = (d["x0"] - 3, d["x0"] - 1)
    d["T"] = d["h"] + HEAD_H - 1                        # top row of the head
    return d


def bone_heads(D):
    """Pivot of every bone, in voxels (x, y, z)."""
    h = D["h"]
    return {
        "root": (0, 0, 0), "hips": (0, 0, D["leg"]), "spine": (0, 0, D["leg"] + 2), "head": (0, 0, h),
        "arm_L": (D["x1"] + 2.5, -0.5, h - 1), "arm_R": (D["x0"] - 1.5, -0.5, h - 1),
        "leg_L": (2, 0, D["leg"]), "leg_R": (-2, 0, D["leg"]),
    }


ARMS = ("arm_L", "arm_R")
LEGS = (("leg_L", (0, 3)), ("leg_R", (-4, -1)))


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


# ---- head shapes: all inside the bible's 12 x 12 x 11 box, so every hair, hat and face fits every head
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
                if shape == "heart" and ((z <= 2 and ex) or (z == 0 and x in (HX0 + 1, HX1 - 1))):
                    continue
                p.set(x, y, Z + z, ("skin", C["skin"]), "head")
    return p


# ---- face: pixel decals on the front plane. Offsets are (dx, dz) for the left eye (+X); the right is mirrored.
EYE_X, EYE_Z, BROW_Z, MOUTH_Z, BLUSH_Z = 3, 4, 7, 1, 3
EYES = {
    "dot":    [(0, 0), (0, 1)],
    "wide":   [(0, 0), (1, 0), (0, 1), (1, 1)],
    "sleepy": [(0, 0), (1, 0)],
    "happy":  [(-1, 0), (0, 1), (1, 0)],
    "lashes": [(0, 0), (0, 1), (1, 1)],
}
BROWS = {
    "none":    [],
    "flat":    [(0, 0), (1, 0)],
    "arched":  [(-1, 0), (0, 1), (1, 0)],
    "worried": [(-1, 1), (0, 1), (1, 0)],
    "thick":   [(-1, 0), (0, 0), (1, 0), (-1, 1), (0, 1), (1, 1)],
}
MOUTHS = {     # absolute x (symmetric about the centre line), dz
    "smile": [(-2, 1), (-1, 0), (0, 0), (1, 1)],
    "small": [(-1, 0), (0, 0)],
    "flat":  [(-2, 0), (-1, 0), (0, 0), (1, 0)],
    "open":  [(-1, 0), (0, 0), (-1, 1), (0, 1)],
    "grin":  [(-3, 1), (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 1)],
}


def build_pair(pid, slot, offsets, row, m, D):
    p = Part(pid, slot)
    for dx, dz in offsets:
        x = EYE_X + dx
        p.decal(x, D["h"] + row + dz, m)
        p.decal(mirror(x), D["h"] + row + dz, m)
    return p


def build_eyes(v, D, C):
    return build_pair("eyes_" + v, "eyes", EYES[v], EYE_Z, ("eyes", C["eyes"]), D)


def build_brows(v, D, C):
    return build_pair("brows_" + v, "brows", BROWS[v], BROW_Z, ("hair", C["hair"]), D)   # brows follow the hair colour


def build_blush(D, C):
    return build_pair("blush", "blush", [(0, 0), (1, 0)], BLUSH_Z, ("blush", C["blush"]), D)


def build_mouth(v, D, C):
    p = Part("mouth_" + v, "mouth")
    for x, dz in MOUTHS[v]:
        p.decal(x, D["h"] + MOUTH_Z + dz, ("mouth", C["mouth"]))
    return p


# ---- hair. T = top row of the head; hair adds a 1-voxel cap above it and may rise up to 5 (bible section 7).
HAIRS = ("shaggy", "wavy", "afro", "crop", "buzz", "bob", "bun", "quiff", "ponytail", "side_part", "swept", "long", "spiky", "curly",
         "sideburns", "chignon")


def build_hair(style, D, C):
    p = Part("hair_" + style, "hair")
    m = ("hair", C["hair"])
    Z, T = D["h"], D["T"]

    def b(xr, yr, zr, keep=None):
        p.box(xr, yr, zr, m, "head", keep)

    def cap(over=1):
        b((HX0 - over, HX1 + over), (HY0 - over, HY1 + over), (T + 1, T + 1))

    def sides(zlo, ylo=HY0):
        b((HX0 - 1, HX0 - 1), (ylo, HY1 + 1), (zlo, T))
        b((HX1 + 1, HX1 + 1), (ylo, HY1 + 1), (zlo, T))

    def back(zlo):
        b((HX0, HX1), (HY1 + 1, HY1 + 1), (zlo, T))

    def fringe(zlo, xr=(HX0, HX1)):
        b(xr, (HY0 - 1, HY0 - 1), (zlo, T))

    def lumpy(x0, x1, y0, y1, z, seed, chance=0.55):
        """One irregular layer: each 2 x 2 tuft is set with probability `chance` (renders 05/06 hair reads as
        clumps, not a flat cap)."""
        for x in range(x0, x1 + 1, 2):
            for y in range(y0, y1 + 1, 2):
                if zlib.crc32(("%s%d,%d,%d" % (seed, x, y, z)).encode()) % 100 < chance * 100:
                    b((x, min(x + 1, x1)), (y, min(y + 1, y1)), (z, z))

    if style == "shaggy":
        # renders 05/06, the most common look: a thick messy mop over the ears, jagged fringe, clumps on top
        b((HX0 - 1, HX1 + 1), (HY0 - 1, HY1 + 1), (T + 1, T + 2))
        lumpy(HX0 - 1, HX1 + 1, HY0 - 1, HY1 + 1, T + 3, "shag")
        lumpy(HX0 + 1, HX1 - 1, HY0 + 1, HY1 - 1, T + 4, "shag2", 0.35)
        b((HX0 - 2, HX0 - 1), (HY0, HY1 + 1), (Z + 3, T))
        b((HX1 + 1, HX1 + 2), (HY0, HY1 + 1), (Z + 3, T))
        b((HX0 - 1, HX1 + 1), (HY1 + 1, HY1 + 2), (Z + 1, T))
        fringe(T - 1)
        for x in range(HX0, HX1 + 1, 2):                             # jagged fringe tips
            if zlib.crc32(("fr%d" % x).encode()) % 2:
                b((x, x), (HY0 - 1, HY0 - 1), (T - 3, T - 2))
    elif style == "wavy":
        # long voluminous waves past the shoulders (05: the blonde patrons, the ginger at the bar)
        b((HX0 - 1, HX1 + 1), (HY0 - 1, HY1 + 1), (T + 1, T + 2))
        lumpy(HX0, HX1, HY0, HY1 + 1, T + 3, "wave")
        for side, x0, x1 in ((-1, HX0 - 3, HX0 - 1), (1, HX1 + 1, HX1 + 3)):
            for z in range(Z - 4, T + 1):
                flare = 1 if (z - Z) % 4 in (0, 1) else 0             # the wave: in and out every 2 rows
                xa, xb = (x0 + 1 - flare, x1) if side < 0 else (x0, x1 - 1 + flare)
                b((xa, xb), (HY0 + 1, HY1 + 2), (z, z))
        b((HX0 - 1, HX1 + 1), (HY1 + 1, HY1 + 3), (Z - 4, T))
        fringe(T - 2, (HX0, -1)); fringe(T - 1, (0, HX1))
    elif style == "afro":
        cz = T - 1.0
        head = set((x, y, z) for x in range(HX0, HX1 + 1) for y in range(HY0, HY1 + 1) for z in range(Z, T + 1))

        def keep(x, y, z):
            if (x, y, z) in head:
                return False
            if y < HY0 and z < T - 1:
                return False
            d = ((x + 0.5) / 9.8) ** 2 + ((y + 0.5) / 9.8) ** 2 + ((z + 0.5 - cz) / 7.6) ** 2
            if d > 1.0:
                return False
            return d < 0.86 or zlib.crc32(("afro%d,%d,%d" % (x, y, z)).encode()) % 3 > 0   # tufted edge
        b((HX0 - 4, HX1 + 4), (HY0 - 3, HY1 + 4), (T - 6, T + 7), keep)
    elif style == "crop":
        cap(); sides(T - 3); back(T - 4); fringe(T - 1)
    elif style == "buzz":
        cap(0)
    elif style == "bob":
        cap(); sides(Z + 2); back(Z + 2); fringe(T - 2)
        b((HX0 - 2, HX0 - 2), (HY0, HY1 + 1), (Z + 2, Z + 3))       # flared ends
        b((HX1 + 2, HX1 + 2), (HY0, HY1 + 1), (Z + 2, Z + 3))
    elif style == "bun":
        cap(); sides(T - 2); back(T - 4); fringe(T)
        b((-2, 1), (-1, 2), (T + 2, T + 4))
    elif style == "quiff":
        cap(); sides(T - 2); back(T - 3)
        b((-4, 3), (HY0 - 1, HY0 + 1), (T + 2, T + 4))
        b((-4, 3), (HY0 + 2, HY0 + 4), (T + 2, T + 3))
        b((-4, 3), (HY0 + 5, HY0 + 6), (T + 2, T + 2))
        b((-4, 3), (HY0 - 2, HY0 - 2), (T + 3, T + 4))              # the quiff leans forward
    elif style == "ponytail":
        cap(); sides(T - 4); back(T - 5); fringe(T - 1)
        b((-2, 1), (HY1 - 1, HY1 + 1), (T + 2, T + 3))              # high tie at the crown
        b((-1, 0), (HY1 + 2, HY1 + 3), (Z + 2, T + 3))              # tail down the back
    elif style == "side_part":
        cap(); sides(T - 3); back(T - 4)
        b((-1, HX1 + 1), (HY0 - 1, HY1), (T + 2, T + 2))            # volume on the left of the part
        fringe(T - 2, (0, HX1)); fringe(T, (HX0, -1))               # swept fringe, longer on one side
    elif style == "swept":
        b((HX0, HX1), (HY0 + 2, HY1 + 1), (T + 1, T + 1))           # forehead stays bare
        sides(T - 3, HY0 + 3); back(T - 5)
        b((HX0 + 1, HX1 - 1), (HY1 - 3, HY1), (T + 2, T + 2))
    elif style == "long":
        cap(); sides(Z); back(Z); fringe(T - 1)
        b((-5, 4), (HY1 - 2, HY1 - 1), (Z - 4, Z - 1))              # falls behind the shoulders
    elif style == "spiky":
        cap(); sides(T - 2); back(T - 3); fringe(T)
        for x in range(HX0, HX1 + 1, 3):
            for y in range(HY0, HY1 + 1, 3):
                hgt = 2 + zlib.crc32(("spike%d,%d" % (x, y)).encode()) % 2
                b((x, x + 1), (y, y + 1), (T + 2, T + 1 + hgt))
    elif style == "curly":
        cz = T - 1.5
        head = set((x, y, z) for x in range(HX0, HX1 + 1) for y in range(HY0, HY1 + 1) for z in range(Z, T + 1))

        def keep(x, y, z):
            if (x, y, z) in head:
                return False
            if y < HY0 and z < T - 1:
                return False                                         # keep the face clear
            return ((x + 0.5) / 8.6) ** 2 + ((y + 0.5) / 8.6) ** 2 + ((z + 0.5 - cz) / 6.6) ** 2 <= 1.0
        b((HX0 - 2, HX1 + 2), (HY0 - 2, HY1 + 2), (T - 4, T + 4), keep)
    elif style == "sideburns":
        cap(); sides(T - 2, HY0 + 3); back(T - 4)
        b((HX0 - 1, HX0 - 1), (HY0 + 1, HY0 + 2), (Z + 3, T))
        b((HX1 + 1, HX1 + 1), (HY0 + 1, HY0 + 2), (Z + 3, T))
    elif style == "chignon":
        cap(); sides(T - 5, HY0 + 1); back(Z + 3); fringe(T, (HX0, 1))
        b((-2, 1), (HY1 + 2, HY1 + 4), (Z + 2, Z + 5))              # low bun at the nape
    else:
        raise KeyError(style)
    return p


# ---- outfits. Tops own the chest rows and the sleeves (bare forearms in skin); bottoms own the pelvis and legs
# above the shoes; shoes own the 2 floor rows. Hands are their own part.
TOPS = {   # style: sleeve length
    "tee": "short", "hoodie": "full", "shirt": "full", "shirt_tie": "full", "cardigan": "full",
    "bomber": "full", "staff_shirt": "short", "blouse": "three_q", "blazer": "full",
}
BOTTOMS = ("jeans", "trousers", "shorts", "skirt")
SHOES = ("sneakers", "boots", "loafers")


def build_top(style, D, C):
    p = Part("top_" + style, "top")
    mm, tt, aa, sk = ("top", C["top"]), ("top_trim", C["top_trim"]), ("top_accent", C["top_accent"]), ("skin", C["skin"])
    zb, zt = D["leg"] + 2, D["h"] - 1
    yr = (D["y0"] - 1, D["y1"] + 1) if style == "bomber" else (D["y0"], D["y1"])
    xr = (D["x0"], D["x1"])
    fy = yr[0]
    p.box(xr, yr, (zb, zt), mm, "spine")

    def front(x, z, m):
        p.set(x, fy, z, m, "spine")

    hz = D["az0"] + 2
    bottom = {"short": zt - 2, "three_q": max(hz, zt - 5), "full": hz}[TOPS[style]]
    for bone in ARMS:
        ar = D[bone]
        p.box(ar, (-2, 0), (bottom, zt), mm, bone)
        if bottom > hz:
            p.box(ar, (-2, 0), (hz, bottom - 1), sk, bone)
        if style in ("bomber", "staff_shirt", "blouse"):
            p.box(ar, (-2, 0), (bottom, bottom), tt, bone)          # cuffs
    if style == "tee":
        for x in (-1, 0):
            front(x, zt, tt)
    elif style == "hoodie":
        p.box((-3, 2), (D["y1"] + 1, D["y1"] + 1), (zt - 2, zt), mm, "spine")   # hood
        for x in range(-2, 2):
            for z in (zb, zb + 1):
                front(x, z, tt)                                     # pocket
        for z in (zt - 2, zt - 1):
            front(-2, z, tt); front(1, z, tt)                       # drawstrings
    elif style == "shirt":
        for x in range(-2, 2):
            front(x, zt, tt)
        for z in (zt - 3, zt - 2):
            front(1, z, tt); front(2, z, tt)                        # chest pocket
    elif style == "shirt_tie":
        front(-1, zt, sk); front(0, zt, sk)                         # open collar
        front(0, zt - 1, tt); front(1, zt - 1, tt)                  # loosened knot, pulled aside
        for z in range(zt - 6, zt - 1):
            front(0, z, tt)
    elif style == "cardigan":
        for z in range(zb, zt + 1):
            front(-1, z, aa); front(0, z, aa)                       # open front shows the shirt
        for (x, y, z), (m, bone) in list(p.cells.items()):
            if m == mm and zlib.crc32(("chalk%d,%d,%d" % (x, y, z)).encode()) % 11 == 0:
                p.set(x, y, z, ("top_dust", "Cream"), bone)          # Mali's chalk dust
    elif style == "bomber":
        p.box(xr, yr, (zb, zb), tt, "spine")                        # ribbed hem
        for x in range(D["x0"], D["x1"] + 1):
            front(x, zt, tt)                                        # collar
    elif style == "staff_shirt":
        p.box(xr, yr, (zb, zb), tt, "spine")
        for x in range(-2, 2):
            front(x, zt, tt)
    elif style == "blouse":
        for x in range(-2, 2):
            front(x, zt, sk)
        front(-1, zt - 1, sk); front(0, zt - 1, sk)                 # V neck
    elif style == "blazer":
        for z in range(zt - 4, zt + 1):
            front(-2, z, tt); front(1, z, tt)                       # lapels
        for z in range(zt - 3, zt + 1):
            front(-1, z, aa); front(0, z, aa)                       # shirt
        p.box(xr, (D["y1"] + 1, D["y1"] + 1), (D["leg"] - 1, D["leg"] + 1), mm, "hips")   # back tail
    return p


def build_bottom(style, D, C):
    p = Part("bottom_" + style, "bottom")
    mm, tt, sk = ("bottom", C["bottom"]), ("bottom_trim", C["bottom_trim"]), ("skin", C["skin"])
    leg = D["leg"]
    p.box((D["x0"], D["x1"]), (D["y0"], D["y1"]), (leg, leg + 1), mm, "hips")
    if style in ("jeans", "trousers"):
        p.box((D["x0"], D["x1"]), (D["y0"], D["y1"]), (leg + 1, leg + 1), tt, "hips")   # belt
    if style == "skirt":
        for z in range(leg - 3, leg):
            g = 1 if z < leg - 1 else 0
            p.box((D["x0"] - g, D["x1"] + g), (D["y0"] - g, D["y1"] + g), (z, z), tt if z == leg - 3 else mm, "hips")
    for bone, xr in LEGS:
        for z in range(2, leg):
            if style == "skirt" or (style == "shorts" and z < leg - 2):
                m = sk
            elif style == "jeans" and z == 2:
                m = tt                                              # rolled cuff
            else:
                m = mm
            p.box(xr, (-2, 1), (z, z), m, bone)                     # legs overwrite the skirt shell's core
    return p


def build_shoes(style, D, C):
    p = Part("shoes_" + style, "shoes")
    mm, tt = ("shoes", C["shoes"]), ("shoes_trim", C["shoes_trim"])
    for bone, xr in LEGS:
        if style == "loafers":
            p.box(xr, (-2, 1), (0, 1), mm, bone)
            p.box(xr, (-3, -3), (0, 0), mm, bone)                   # low toe
            p.box(xr, (-2, -2), (1, 1), tt, bone)                   # vamp
        else:
            p.box(xr, (-3, 1), (0, 1), mm, bone)
            p.box(xr, (-3, 1), (0, 0), tt, bone)                    # sole
        if style == "boots":
            outer = xr[1] + 1 if bone == "leg_L" else xr[0] - 1
            p.box(xr, (-3, -3), (2, 3), mm, bone)
            p.box(xr, (2, 2), (2, 3), mm, bone)
            p.box((outer, outer), (-2, 1), (2, 3), mm, bone)
    return p


def build_hands(D, C):
    p = Part("hands", "hands")
    for bone in ARMS:
        p.box(D[bone], (-2, 0), (D["az0"], D["az0"] + 1), ("skin", C["skin"]), bone)
    return p


# ---- accessories: id -> (slot, default colour 1, default colour 2). Materials are <id>__<Swatch>, <id>_2__<Swatch>.
ACC = {
    "hat_bucket":     ("hat", "Olive", "Cream"),
    "hat_flat_cap":   ("hat", "Stone", "Charcoal"),
    "hat_beanie":     ("hat", "Rust", "Cream"),
    "glasses_round":  ("glasses", "CymbalGold", "Lens"),
    "glasses_tinted": ("glasses", "CymbalGold", "Lens"),
    "glasses_up":     ("glasses", "StoolBlack", "Lens"),
    "headphones":     ("ears", "StoolBlack", "Charcoal"),
    "ribbon":         ("hair_acc", "Rust", "Cream"),
    "pencil":         ("hair_acc", "Mustard", "Charcoal"),
    "gig_bag":        ("back", "StoolBlack", "Charcoal"),
    "apron":          ("outer", "Cream", "CymbalGold"),
    "bar_towel":      ("arm_acc", "ColumnWhite", "Cream"),
    "gaffer_tape":    ("belt", "Stone", "Charcoal"),
    "guitar":         ("instrument", "WoodMid", "Cream"),
    "bass":           ("instrument", "CymbalGold", "StoolBlack"),
    "drumsticks":     ("held", "Sand", "Sand"),
    "mic":            ("held_R", "StoolBlack", "MirrorGrey"),
    "drink_beer":     ("held_R", "BottleAmber", "Cream"),
    "glass_gold":     ("held_R", "BottleClear", "CymbalGold"),
    "shaker":         ("held_R", "MirrorGrey", "CymbalGold"),
    "notebook":       ("held_R", "Cream", "Charcoal"),
    "torch":          ("held_R", "StoolBlack", "LampGoldOff"),
    "clicker":        ("held_L", "Stone", "Charcoal"),
    "sketchbook":     ("held_L", "WoodMid", "Cream"),
    "vinyl":          ("held_L", "Mustard", "StoolBlack"),
    "wheelie_bag":    ("floor", "Denim", "StoolBlack"),
    "beard":          ("face_hair", "HairBlack", "HairBlack"),
    "hat_fedora":     ("hat", "StoolBlack", "Charcoal"),
    "vest":           ("outer", "StoolBlack", "Charcoal"),
    "tray":           ("held_L", "StoolBlack", "BottleAmber"),
    "beer_left":      ("held_L", "BottleAmber", "Cream"),
}


def build_acc(aid, D, C):
    slot, c1, c2 = ACC[aid]
    p = Part(aid, slot)
    a, b2 = (aid, C.get(aid, c1)), (aid + "_2", C.get(aid + "_2", c2))
    Z, T, h, leg, az = D["h"], D["T"], D["h"], D["leg"], D["az0"]
    L, R = D["arm_L"], D["arm_R"]
    rc = R[0] + 1                                                     # centre column of the right arm
    lc = L[0] + 1

    def bx(xr, yr, zr, m=a, bone="head", keep=None):
        p.box(xr, yr, zr, m, bone, keep)

    if aid == "hat_bucket":
        bx((HX0 - 3, HX1 + 3), (HY0 - 3, HY1 + 3), (T + 2, T + 2))
        bx((HX0 - 1, HX1 + 1), (HY0 - 1, HY1 + 1), (T + 3, T + 5))
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
    elif aid in ("glasses_round", "glasses_tinted"):
        ez = Z + EYE_Z
        for x0 in (2, mirror(5)):
            bx((x0, x0 + 3), (HY0 - 1, HY0 - 1), (ez - 1, ez + 2),
               keep=lambda x, y, z, x0=x0: not (x0 < x < x0 + 3 and ez <= z <= ez + 1))
            if aid == "glasses_tinted":
                bx((x0 + 1, x0 + 2), (HY0 - 1, HY0 - 1), (ez, ez + 1), b2)
        bx((-2, 1), (HY0 - 1, HY0 - 1), (ez + 1, ez + 1))                       # bridge
        bx((HX1 + 1, HX1 + 1), (HY0, HY0 + 3), (ez + 1, ez + 1))                 # temples
        bx((HX0 - 1, HX0 - 1), (HY0, HY0 + 3), (ez + 1, ez + 1))
    elif aid == "glasses_up":
        for x0 in (2, mirror(5)):
            bx((x0, x0 + 3), (HY0, HY0 + 1), (T + 2, T + 2))
            bx((x0 + 1, x0 + 2), (HY0, HY0), (T + 2, T + 2), b2)
        bx((-2, 1), (HY0 + 1, HY0 + 1), (T + 2, T + 2))
    elif aid == "headphones":
        bx((HX0 - 1, HX1 + 1), (-1, 0), (T + 2, T + 2))                          # band
        for x in (HX0 - 2, HX1 + 2):
            bx((x, x), (-1, 0), (Z + 7, T + 2))
        bx((HX0 - 3, HX0 - 2), (-2, 1), (Z + 3, Z + 6), b2)                       # cups
        bx((HX1 + 2, HX1 + 3), (-2, 1), (Z + 3, Z + 6), b2)
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
        bx((D["x0"] + 1, D["x1"] - 1), (y, y), (leg, h - 3), bone="spine")
        bx((D["x0"] + 1, D["x0"] + 1), (y, y), (h - 2, h - 1), bone="spine")      # neck straps
        bx((D["x1"] - 1, D["x1"] - 1), (y, y), (h - 2, h - 1), bone="spine")
        bx((D["x0"] + 1, D["x1"] - 1), (y, y), (leg + 2, leg + 2), b2, bone="spine")   # gold waist tie
    elif aid == "bar_towel":
        x0, x1 = L
        bx((x0, x1), (-3, -3), (az + 2, az + 4), bone="arm_L")
        bx((x0, x1), (1, 1), (az + 2, az + 4), bone="arm_L")
        bx((x1 + 1, x1 + 1), (-3, 1), (az + 1, az + 4), bone="arm_L")
    elif aid == "gaffer_tape":
        bx((D["x1"] - 2, D["x1"] - 1), (D["y0"] - 1, D["y0"] - 1), (leg, leg + 1), bone="hips")
        bx((D["x1"] - 2, D["x1"] - 1), (D["y0"] - 2, D["y0"] - 2), (leg, leg + 1), b2, bone="hips")
    elif aid in ("guitar", "bass"):
        y0 = D["y0"] - 3
        wide = 7 if aid == "guitar" else 6
        x0 = -4
        zb = leg - 2
        tall = 8 if aid == "guitar" else 7

        def body_keep(x, y, z):
            corner = (x in (x0, x0 + wide - 1)) and (z in (zb, zb + tall - 1))
            waist = (x in (x0, x0 + wide - 1)) and z == zb + tall // 2 + 1
            return not (corner or waist)
        bx((x0, x0 + wide - 1), (y0, y0 + 1), (zb, zb + tall - 1), bone="spine", keep=body_keep)
        if aid == "guitar":
            bx((-2, -1), (y0, y0), (zb + 3, zb + 4), ("guitar_hole", "StoolBlack"), "spine")
            bx((x0 + 1, x0 + wide - 2), (y0, y0), (zb, zb), b2, "spine")           # binding
        else:
            bx((x0 + 1, x0 + 2), (y0, y0), (zb + 1, zb + tall - 3), b2, "spine")   # pickguard
        nl = 6 if aid == "guitar" else 8
        for i in range(nl):
            bx((x0 + wide + i // 2, x0 + wide + i // 2), (y0, y0), (zb + tall - 2 + i, zb + tall - 2 + i), b2, "spine")
        hx = x0 + wide + (nl - 1) // 2
        bx((hx, hx + 1), (y0, y0), (zb + tall - 2 + nl, zb + tall + nl), a, "spine")   # headstock
    elif aid == "drumsticks":
        for bone, ar in (("arm_L", L), ("arm_R", R)):
            c = ar[0] + 1
            bx((c, c), (-8, -3), (az, az), bone=bone)
    elif aid == "mic":
        bx((rc, rc), (-3, -3), (az, az + 1), bone="arm_R")
        bx((rc - 1, rc), (-4, -3), (az + 2, az + 3), b2, "arm_R")
    elif aid == "drink_beer":
        bx((rc - 1, rc), (-4, -3), (az, az + 2), bone="arm_R")
        bx((rc - 1, rc), (-4, -3), (az + 3, az + 3), b2, "arm_R")                 # foam
    elif aid == "glass_gold":
        bx((rc - 1, rc), (-4, -3), (az, az + 2), bone="arm_R")
        bx((rc - 1, rc), (-4, -3), (az + 3, az + 3), b2, "arm_R")                 # the only gold rim in the room
    elif aid == "shaker":
        bx((rc - 1, rc), (-4, -3), (az, az + 3), bone="arm_R")
        bx((rc - 1, rc), (-4, -3), (az + 4, az + 4), b2, "arm_R")
    elif aid == "notebook":
        bx((rc - 1, rc), (-3, -3), (az, az + 2), bone="arm_R")
        bx((rc - 1, rc), (-3, -3), (az + 2, az + 2), b2, "arm_R")
    elif aid == "torch":
        bx((rc, rc), (-5, -3), (az, az), bone="arm_R")
        bx((rc, rc), (-6, -6), (az, az), b2, "arm_R")
    elif aid == "clicker":
        bx((lc, lc), (-3, -3), (az, az + 1), bone="arm_L")
        bx((lc, lc), (-4, -4), (az + 1, az + 1), b2, "arm_L")
    elif aid == "sketchbook":
        x = L[1] + 1
        bx((x, x), (-4, 0), (az - 1, az + 3), bone="arm_L")
        bx((x, x), (-4, 0), (az + 3, az + 3), b2, "arm_L")
    elif aid == "vinyl":
        x = L[1] + 1
        bx((x, x), (-5, 1), (az - 2, az + 4), bone="arm_L")
        bx((x, x), (-3, -1), (az, az + 2), b2, "arm_L")                            # label
    elif aid == "beard":
        y = HY0 - 1
        bx((-4, 3), (y, y), (Z, Z))                                               # chin row
        bx((-3, 2), (y, y), (Z - 1, Z - 1))                                       # under the chin
        for x0 in (HX0, HX1 - 1):
            bx((x0, x0 + 1), (y, y), (Z, Z + 3))                                  # jaw
        bx((HX0 - 1, HX0 - 1), (HY0, HY0 + 3), (Z, Z + 4))                        # sideburn to the jaw
        bx((HX1 + 1, HX1 + 1), (HY0, HY0 + 3), (Z, Z + 4))
        bx((-3, 2), (y, y), (Z + 3, Z + 3), keep=lambda x, yy, z: x not in (-1, 0))   # moustache
    elif aid == "hat_fedora":
        bx((HX0 - 2, HX1 + 2), (HY0 - 2, HY1 + 2), (T + 2, T + 2),
           keep=lambda x, y, z: not (x in (HX0 - 2, HX1 + 2) and y in (HY0 - 2, HY1 + 2)))
        bx((HX0, HX1), (HY0 + 1, HY1), (T + 3, T + 3), b2)                       # band
        bx((HX0, HX1), (HY0 + 1, HY1), (T + 4, T + 6),
           keep=lambda x, y, z: not (z == T + 6 and -2 <= x <= 1))               # pinched crown
    elif aid == "vest":
        y0, y1 = D["y0"] - 1, D["y1"] + 1
        for x0, x1 in ((D["x0"], D["x0"] + 2), (D["x1"] - 2, D["x1"])):
            bx((x0, x1), (y0, y0), (leg + 1, h - 1), bone="spine")
        bx((D["x0"], D["x1"]), (y1, y1), (leg + 1, h - 1), bone="spine")
        bx((D["x1"] - 2, D["x1"] - 2), (y0 - 1, y0 - 1), (leg + 4, leg + 4), b2, "spine")   # button
        bx((D["x0"] + 2, D["x0"] + 2), (y0 - 1, y0 - 1), (leg + 4, leg + 4), b2, "spine")
    elif aid == "tray":
        # 06/05: the server's round tray held flat at the left hand with four pints on it
        zt = az + 1
        bx((lc - 3, lc + 3), (-9, -2), (zt, zt), bone="arm_L",
           keep=lambda x, y, z: not (x in (lc - 3, lc + 3) and y in (-9, -2)))
        for gx, gy in ((lc - 2, -8), (lc + 1, -8), (lc - 2, -5), (lc + 1, -5)):
            bx((gx, gx + 1), (gy, gy + 1), (zt + 1, zt + 3), b2, "arm_L")
            bx((gx, gx + 1), (gy, gy + 1), (zt + 4, zt + 4), ("tray_3", "Cream"), "arm_L")
    elif aid == "beer_left":
        bx((lc - 1, lc), (-4, -3), (az, az + 2), bone="arm_L")
        bx((lc - 1, lc), (-4, -3), (az + 3, az + 3), b2, "arm_L")
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
                       bottom="Denim", bottom_trim="DenimLight", shoes="Charcoal", shoes_trim="Cream",
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
    # regulars (cast bible section 3.1): no two share a head silhouette
    P("tong", "Tong", "regular", "REG_TONG", "regular", "square", "crop", ("dot", "flat", "smile"),
      "tee", "jeans", "sneakers", ["hat_bucket", "gig_bag", "drink_beer"],
      skin="Skin4", hair="HairBlack", top="Mustard", top_trim="Cream", shoes="Cream", shoes_trim="ColumnWhite"),
    P("ploy", "Ploy", "regular", "REG_PLOY", "petite", "soft", "bun", ("lashes", "arched", "small"),
      "blouse", "trousers", "loafers", ["pencil", "sketchbook"],
      skin="Skin2", hair="HairBlack", top="Teal", top_trim="Cream", bottom="Charcoal", bottom_trim="StoolBlack",
      shoes="WoodDark", shoes_trim="TableWoodLit"),
    P("jules", "Jules", "regular", "REG_JULES", "regular", "heart", "quiff", ("wide", "flat", "grin"),
      "bomber", "jeans", "boots", [],
      skin="Skin1", hair="HairBleach", top="Olive", top_trim="Mustard", bottom="Charcoal", bottom_trim="Stone",
      shoes="WoodDark", shoes_trim="StoolBlack"),
    P("mali", "Mali", "regular", "REG_MALI", "broad", "round", "bob", ("dot", "arched", "grin"),
      "cardigan", "skirt", "loafers", ["glasses_up"],
      skin="Skin5", hair="HairDarkBrown", top="Rust", top_trim="Cream", top_accent="Cream",
      bottom="FloorGrey", bottom_trim="Charcoal", shoes="WoodDark", shoes_trim="Sand"),
    P("dougie", "Dougie", "regular", "REG_DOUGIE", "broad", "square", "sideburns", ("sleepy", "thick", "flat"),
      "shirt", "jeans", "boots", ["hat_flat_cap", "drink_beer"],
      skin="Skin1", hair="HairGrey", top="Moss", top_trim="Cream", shoes="WoodDark", shoes_trim="StoolBlack"),
    P("lung_nop", "Lung Nop", "regular", "REG_LUNG_NOP", "regular", "round", "swept", ("dot", "flat", "small"),
      "shirt", "trousers", "loafers", ["glasses_tinted", "vinyl"],
      skin="Skin5", hair="HairWhite", top="Cream", top_trim="Sand", bottom="Sand", bottom_trim="WoodMid",
      shoes="WoodDark", shoes_trim="TableWoodLit"),
    P("bow", "Bow", "regular", "REG_BOW", "petite", "square", "ponytail", ("lashes", "arched", "open"),
      "blouse", "skirt", "sneakers", ["ribbon", "wheelie_bag"],
      skin="Skin3", hair="HairDarkBrown", top="Sky", top_trim="Cream", bottom="Denim", bottom_trim="Cream",
      shoes="ColumnWhite", shoes_trim="Stone"),
    P("hiro", "Hiro", "regular", "REG_HIRO", "regular", "soft", "side_part", ("sleepy", "flat", "small"),
      "shirt_tie", "trousers", "loafers", ["notebook"],
      skin="Skin2", hair="HairBlack", top="Cream", top_trim="DrumRed", bottom="Charcoal", bottom_trim="StoolBlack",
      shoes="StoolBlack", shoes_trim="Charcoal"),
    # staff slots (cast bible section 2)
    P("nam", "Nam", "staff", "BAR_1", "regular", "round", "crop", ("happy", "flat", "smile"),
      "staff_shirt", "trousers", "loafers", ["apron", "bar_towel"],
      skin="Skin4", hair="HairBlack", bottom="StoolBlack", bottom_trim="CymbalGold", shoes="StoolBlack",
      shoes_trim="Charcoal", **STAFF_TOP),
    P("fern", "Fern", "staff", "BAR_2", "petite", "heart", "long", ("lashes", "arched", "smile"),
      "staff_shirt", "skirt", "sneakers", ["shaker"],
      skin="Skin3", hair="HairAuburn", bottom="StoolBlack", bottom_trim="CymbalGold", shoes="StoolBlack",
      shoes_trim="CymbalGold", **STAFF_TOP),
    P("big", "Big", "staff", "DOOR", "broad", "square", "buzz", ("dot", "thick", "smile"),
      "staff_shirt", "trousers", "boots", ["torch", "clicker"],
      skin="Skin6", hair="HairBlack", bottom="StoolBlack", bottom_trim="CymbalGold", shoes="StoolBlack",
      shoes_trim="Charcoal", **STAFF_TOP),
    P("golf", "Golf", "staff", "SOUND", "regular", "soft", "spiky", ("sleepy", "flat", "flat"),
      "staff_shirt", "jeans", "sneakers", ["headphones", "gaffer_tape"],
      skin="Skin4", hair="HairBlack", bottom="Charcoal", bottom_trim="Stone", shoes="Charcoal",
      shoes_trim="ColumnWhite", **STAFF_TOP),
    P("khun_joy", "Khun Joy", "staff", "OWNER", "regular", "heart", "chignon", ("lashes", "arched", "smile"),
      "blazer", "trousers", "loafers", ["glass_gold"],
      skin="Skin3", hair="HairBlack", top="CabinDark", top_trim="CymbalGold", top_accent="Cream",
      bottom="CabinDark", bottom_trim="CymbalGold", shoes="StoolBlack", shoes_trim="CymbalGold"),
    # house band, The House Lights (cast bible section 4.1)
    P("jo", "Jo", "band", "PERF_HOUSE_VOX", "petite", "round", "long", ("wide", "arched", "open"),
      "blouse", "skirt", "boots", ["guitar"],
      skin="Skin4", hair="HairBlack", top="Mustard", top_trim="Cream", bottom="Charcoal", bottom_trim="Cream",
      shoes="WoodDark", shoes_trim="StoolBlack"),
    P("pete", "Pete", "band", "PERF_HOUSE_BASS", "regular", "square", "curly", ("dot", "flat", "smile"),
      "tee", "jeans", "sneakers", ["bass"],
      skin="Skin5", hair="HairBlack", top="Teal", top_trim="Cream", shoes="Charcoal", shoes_trim="ColumnWhite"),
    P("boy", "Boy", "band", "PERF_HOUSE_DRUMS", "broad", "soft", "spiky", ("happy", "flat", "grin"),
      "tee", "shorts", "sneakers", ["hat_beanie", "drumsticks"],
      skin="Skin4", hair="HairBlack", top="Charcoal", top_trim="CymbalGold", bottom="Olive", bottom_trim="Moss",
      shoes="ColumnWhite", shoes_trim="Stone", hat_beanie="Rust", hat_beanie_2="Cream"),
]

# 12 anonymous patrons (DECISIONS m): 3 bodies x 4 heads, palette swaps, generic outfits, no signature items
PATRON_HEADS = [("square", "crop", ("dot", "flat", "smile")), ("round", "long", ("lashes", "arched", "small")),
                ("soft", "buzz", ("sleepy", "flat", "flat")), ("heart", "curly", ("dot", "none", "open"))]
PATRON_OUTFITS = [("tee", "jeans", "sneakers"), ("hoodie", "trousers", "sneakers"), ("blouse", "skirt", "loafers"),
                  ("shirt", "trousers", "boots"), ("tee", "shorts", "sneakers"), ("cardigan", "jeans", "loafers")]
PATRON_TOPS = ["Stone", "Denim", "Sand", "Olive", "Teal", "Charcoal", "DenimLight", "Moss", "Cream", "Rust", "Sky", "FloorLit"]
PATRON_BOTTOMS = ["Denim", "Charcoal", "Sand", "StoolBlack", "Stone", "Moss"]
PATRON_SKIN = ["Skin2", "Skin4", "Skin6", "Skin3", "Skin5", "Skin1", "Skin7", "Skin8", "Skin3", "Skin2", "Skin5", "Skin6"]
PATRON_HAIR = ["HairBlack", "HairDarkBrown", "HairBrown", "HairBlack", "HairAuburn", "HairBlack", "HairDarkBrown",
               "HairGrey", "HairBlack", "HairRose", "HairBrown", "HairBlack"]
for i in range(12):
    body = ("petite", "regular", "broad")[i // 4]
    head, hair, face = PATRON_HEADS[i % 4]
    top, bottom, shoes = PATRON_OUTFITS[(i * 5) % len(PATRON_OUTFITS)]
    PRESETS.append(P("patron_%02d" % (i + 1), "Patron %d" % (i + 1), "patron", "PATRON", body, head, hair, face,
                     top, bottom, shoes, ["drink_beer"] if i % 3 == 1 else [],
                     skin=PATRON_SKIN[i], hair=PATRON_HAIR[i], top=PATRON_TOPS[i], top_trim="Cream",
                     bottom=PATRON_BOTTOMS[i % len(PATRON_BOTTOMS)], bottom_trim="Stone",
                     shoes=("Charcoal", "WoodDark", "ColumnWhite")[i % 3], shoes_trim="Stone"))


# Server and render patrons (renders 05/06): white shirt + black vest + tray; big hair, beards, fedoras, red tops
PRESETS.append(P("server", "Server", "staff", "FLOOR", "regular", "square", "shaggy", ("dot", "thick", "smile"),
                 "shirt", "trousers", "boots", ["vest", "tray", "beard"],
                 skin="Skin2", hair="HairDarkBrown", top="ColumnWhite", top_trim="Cream", bottom="StoolBlack",
                 bottom_trim="Charcoal", shoes="WoodDark", shoes_trim="StoolBlack", beard="HairDarkBrown"))
RENDER_PATRONS = [
    # (body, head, hair, face, top, bottom, shoes, acc, skin, hair colour, top colour, bottom colour)
    ("regular", "square", "shaggy", ("dot", "thick", "smile"), "shirt", "jeans", "boots", ["beard", "drink_beer"],
     "Skin3", "HairBlack", "ColumnWhite", "Denim"),
    ("petite", "soft", "wavy", ("lashes", "arched", "smile"), "blouse", "jeans", "loafers", ["drink_beer"],
     "Skin1", "HairBleach", "Charcoal", "Denim"),
    ("regular", "round", "afro", ("dot", "arched", "grin"), "blouse", "skirt", "loafers", ["drink_beer"],
     "Skin7", "HairBlack", "VelvetRed", "StoolBlack"),
    ("regular", "square", "shaggy", ("sleepy", "flat", "small"), "shirt", "trousers", "boots", ["hat_fedora", "beard"],
     "Skin4", "HairBlack", "ColumnWhite", "StoolBlack"),
    ("petite", "heart", "wavy", ("wide", "arched", "open"), "tee", "jeans", "sneakers", ["drink_beer"],
     "Skin2", "HairAuburn", "Stone", "Denim"),
    ("broad", "square", "shaggy", ("dot", "thick", "flat"), "tee", "jeans", "boots", ["beard", "drink_beer"],
     "Skin5", "HairDarkBrown", "Moss", "Charcoal"),
    ("regular", "soft", "wavy", ("lashes", "flat", "smile"), "blouse", "skirt", "loafers", ["drink_beer"],
     "Skin2", "HairBleach", "Denim", "StoolBlack"),
    ("regular", "round", "afro", ("dot", "flat", "smile"), "shirt", "trousers", "sneakers", ["drink_beer"],
     "Skin6", "HairBlack", "DenimLight", "Charcoal"),
    ("petite", "soft", "afro", ("lashes", "arched", "small"), "blouse", "skirt", "loafers", ["drink_beer"],
     "Skin8", "HairBlack", "VelvetRed", "StoolBlack"),
    ("regular", "square", "shaggy", ("dot", "flat", "grin"), "hoodie", "jeans", "sneakers", ["drink_beer"],
     "Skin3", "HairBrown", "Charcoal", "Denim"),
    ("broad", "round", "swept", ("sleepy", "thick", "smile"), "shirt", "trousers", "loafers", ["drink_beer"],
     "Skin1", "HairWhite", "Charcoal", "StoolBlack"),
    ("regular", "heart", "wavy", ("wide", "arched", "smile"), "tee", "jeans", "sneakers", ["drink_beer"],
     "Skin3", "HairDarkBrown", "VelvetRed", "Denim"),
]
for i, (body, head, hair, face, top, bottom, shoes, acc, sk, hc, tc, bc) in enumerate(RENDER_PATRONS):
    PRESETS.append(P("patron_%02d" % (13 + i), "Patron %d" % (13 + i), "patron", "PATRON", body, head, hair, face,
                     top, bottom, shoes, acc, skin=sk, hair=hc, top=tc, top_trim="Cream", bottom=bc,
                     bottom_trim="Stone", shoes=("Charcoal", "WoodDark", "StoolBlack")[i % 3], shoes_trim="Stone",
                     beard=hc))


def assemble(spec):
    """Parts for a preset spec (dict as made by P)."""
    D, C = dims(spec["body"]), spec["colours"]
    parts = [build_head(spec["head"], D, C), build_hair(spec["hair"], D, C), build_eyes(spec["eyes"], D, C),
             build_brows(spec["brows"], D, C), build_mouth(spec["mouth"], D, C), build_top(spec["top"], D, C),
             build_bottom(spec["bottom"], D, C), build_shoes(spec["shoes"], D, C), build_hands(D, C)]
    parts += [build_acc(a, D, C) for a in spec["acc"]]
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
        pb.rotation_mode = "ZYX"          # roll first, then yaw, then pitch: see the animation notes
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
# Pose functions take the phase t in [0, 1) and the body dims, and return {bone: ((pitch, yaw, roll) degrees,
# (x, up, forward) voxels)}. In every bone's local frame (all bones point up, roll 0):
#   pitch + : the part above the pivot tips forward; a hanging limb swings back
#   yaw   + : turns toward the character's left (+X)
#   roll  + : the top tilts to the character's right; a hanging arm_L lifts outward (arm_R uses roll -)
# Euler order ZYX: roll is applied first, so an arm's roll stays an outward splay at any pitch (with XYZ a raised
# arm's outward roll turns inward and the arm disappears behind the 12-voxel head).
# Every loop is periodic in t, so frame 0 == the last frame.
TAU = 2 * math.pi


def S(t, cycles=1.0, phase=0.0):
    return math.sin(TAU * (cycles * t + phase))


def C_(t, cycles=1.0, phase=0.0):
    return math.cos(TAU * (cycles * t + phase))


def bump(t, a, b):
    """0 outside [a, b], a smooth 0 -> 1 -> 0 hump inside."""
    if t <= a or t >= b:
        return 0.0
    return math.sin(math.pi * (t - a) / (b - a)) ** 2


def arms_out(base):
    """Arms hang slightly away from the body (the voxel arm touches the torso otherwise)."""
    return {"arm_L": ((0, 0, base), (0, 0, 0)), "arm_R": ((0, 0, -base), (0, 0, 0))}


def pose(**bones):
    out = {}
    for bn, v in bones.items():
        r = tuple(v[0]) if v and len(v) > 0 else (0, 0, 0)
        l = tuple(v[1]) if v and len(v) > 1 else (0, 0, 0)
        out[bn] = (r, l)
    return out


def a_idle(t, D):
    br = S(t)
    return pose(spine=((1.5 * br, 0, 0),), head=((-1.0 * S(t, 1, 0.15), 4 * S(t, 1, 0.3), 0),),
                hips=((0, 0, 0), (0, 0.15 * (1 + br) / 2, 0)),
                arm_L=((1.5 * br, 0, 2 + br),), arm_R=((1.5 * br, 0, -2 - br),))


def a_idle_warm(t, D):            # 1 Warm: sways to the music (two sways per loop)
    s = S(t, 2)
    bob = 0.35 * (1 - C_(t, 4)) / 2
    return pose(hips=((0, 0, -2 * s), (0.3 * s, bob, 0)), spine=((1, 0, 4 * s),),
                head=((-2, 0, 5 * S(t, 2, 0.12)),),
                arm_L=((6 * S(t, 2, 0.25), 0, 4 + 2 * s),), arm_R=((-6 * S(t, 2, 0.25), 0, -4 + 2 * s),))


def a_idle_tipsy(t, D):           # 2 Tipsy: leans, laughs at nothing, taps a foot
    laugh = bump(t, 0.25, 0.5)
    shake = S(t, 14) * laugh
    tap = max(0.0, S(t, 4)) ** 2
    return pose(hips=((0, 0, -3), (0.5, 0, 0)), spine=((2 - 5 * laugh, 0, 7 + 2 * S(t)),),
                head=((-10 * laugh + 3 * shake, 0, 6 + 3 * S(t, 1, 0.2)),),
                arm_L=((-15 * laugh, 0, 14 + 3 * S(t)),), arm_R=((-25 * laugh, 0, -4 - 2 * laugh),),
                leg_R=((-14 * tap, 0, 0),))


def a_idle_merry(t, D):           # 3 Merry: slow big sway, chin up, sings along with one arm up
    s = S(t)
    return pose(hips=((0, 0, -3 * s), (0.7 * s, 0, 0)), spine=((-2, 0, 7 * s),),
                head=((-8, 0, 9 * S(t, 1, 0.12)),),
                arm_R=((-115 + 10 * S(t, 2), 0, -32),), arm_L=((4 * s, 0, 6 + 3 * s),))


def a_idle_sad(t, D):             # low Vibe (GDD 2.2 Meh / Homebody): slumped, head down, a slow sigh
    sigh = bump(t, 0.45, 0.8)
    return pose(spine=((13 + 4 * sigh, 0, 0),), head=((18 + 3 * S(t) - 6 * sigh, 0, 2 * S(t, 1, 0.3)),),
                hips=((0, 0, 0), (0, 0.2 * sigh, 0)),
                arm_L=((-7, 0, 1),), arm_R=((-7, 0, -1),))


def walk(t, D, legs=28, arms=24, bob=0.6, lean=4, weave=0.0, roll=0.0, hum=0.0, arms_wide=2):
    s = S(t)
    up = bob * (1 + C_(t, 2)) / 2
    return pose(
        hips=((0, 6 * weave * S(t, 1, 0.25), roll * S(t)), (weave * S(t, 1, 0.25), up, 0)),
        spine=((lean, 4 * s, -roll * 0.7 * S(t, 1, 0.1)),),
        head=((-2 + hum * S(t, 4), -3 * s, roll * 0.5 * S(t, 1, 0.3) + hum * 0.6 * S(t, 2)),),
        leg_L=((-legs * s, 0, 0),), leg_R=((legs * s, 0, 0),),
        arm_L=((arms * s, 0, arms_wide),), arm_R=((-arms * s, 0, -arms_wide),))


def a_walk(t, D):
    return walk(t, D)


def a_walk_warm(t, D):            # small bounce in the step
    return walk(t, D, legs=30, arms=30, bob=1.2, roll=3)


def a_walk_tipsy(t, D):           # loose half-step weave, never a stumble
    return walk(t, D, legs=24, arms=26, bob=0.7, lean=2, weave=0.8, roll=5, arms_wide=8)


def a_walk_merry(t, D):           # slower, humming, arms swinging wide; never past 8 degrees of lean
    return walk(t, D, legs=20, arms=45, bob=0.6, lean=0, weave=0.5, roll=7, hum=3, arms_wide=12)


def a_sit(t, D):                  # on a cafe chair: hips at the seat (9 voxels), legs forward, feet swinging
    rise = SEAT_VOX - D["leg"]
    br = S(t)
    return pose(hips=((0, 0, 0), (0, rise, 0)), spine=((2 + 1.5 * br, 0, 0),),
                head=((-1, 5 * S(t, 1, 0.3), 0),),
                leg_L=((-90 + 5 * S(t, 1), 0, 0), (0, 2, 1)), leg_R=((-90 - 5 * S(t, 1), 0, 0), (0, 2, 1)),
                arm_L=((-28, 0, 3),), arm_R=((-28, 0, -3),))


def a_cheers(t, D):               # one-shot: raise the glass, clink, back down
    up = bump(t, 0.0, 1.0) ** 0.6
    clink = bump(t, 0.35, 0.5)
    return pose(arm_R=((-80 * up - 15 * clink, 0, -2 - 10 * up),), spine=((-3 * up, 6 * up, 0),),
                head=((-5 * up, 4 * up, 0),), arm_L=((0, 0, 3),))


def a_applaud(t, D):              # two claps per loop, arms forward, hands meet in the middle
    c = C_(t, 2)
    return pose(arm_L=((-55, 0, -18 - 10 * c),), arm_R=((-55, 0, 18 + 10 * c),),
                head=((-3 + 2 * c, 0, 0),), spine=((-1, 0, 0),), hips=((0, 0, 0), (0, 0.2 * (1 + c) / 2, 0)))


def a_dance(t, D):                # four beats: hop, alternating arm pumps, twist. A raised arm rolls outward
    # with its height, or the 12-voxel head hides it
    hop = 0.8 * (1 - C_(t, 4)) / 2
    s = S(t)
    return pose(hips=((0, 12 * s, 0), (0, hop, 0)), spine=((0, 8 * s, 5 * S(t, 2)),),
                head=((-3, -6 * s, 8 * S(t, 2, 0.15)),),
                arm_L=((-100 + 70 * s, 0, 12 + 30 * (1 - s) / 2),), arm_R=((-100 - 70 * s, 0, -12 - 30 * (1 + s) / 2),),
                leg_L=((-12 * S(t, 2), 0, 0),), leg_R=((12 * S(t, 2), 0, 0),))


# name, frames, pose fn, loops. Tipsiness names follow the cast bible (5.1): clear = the base idle/walk.
ANIMS = [
    ("idle", 48, a_idle, True), ("walk", 16, a_walk, True), ("sit", 48, a_sit, True),
    ("cheers", 36, a_cheers, False), ("applaud", 24, a_applaud, True), ("dance", 48, a_dance, True),
    ("idle_warm", 48, a_idle_warm, True), ("idle_tipsy", 72, a_idle_tipsy, True), ("idle_merry", 96, a_idle_merry, True),
    ("walk_warm", 16, a_walk_warm, True), ("walk_tipsy", 24, a_walk_tipsy, True), ("walk_merry", 32, a_walk_merry, True),
    ("idle_sad", 72, a_idle_sad, True),
]
WALK_SPEED = {"walk": 1.1, "walk_warm": 1.1, "walk_tipsy": 0.85, "walk_merry": 0.7}   # m/s the root should move


def make_actions(arm, D, prefix=""):
    """One action per ANIMS entry, keyed every 2 frames from its pose function. Returns {name: action}."""
    arm.animation_data_create()
    acts = {}
    for name, length, fn, _loop in ANIMS:
        act = bpy.data.actions.new(prefix + name)
        act.use_fake_user = True
        arm.animation_data.action = act
        for f in range(0, length + 1, 2):
            p = fn(f / length, D)
            for bn in BONES:
                pb = arm.pose.bones[bn]
                r, l = p.get(bn, ((0, 0, 0), (0, 0, 0)))
                pb.rotation_euler = [math.radians(a) for a in r]
                pb.location = (l[0] * VOX, l[1] * VOX, l[2] * VOX)
                pb.keyframe_insert("rotation_euler", frame=f, group=bn)
                pb.keyframe_insert("location", frame=f, group=bn)
        act.use_frame_range = True
        act.frame_start, act.frame_end = 0, length
        act.use_cyclic = _loop
        acts[name] = act
    arm.animation_data.action = acts["idle"]
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)
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
                export_frame_range=False, export_force_sampling=True, export_anim_slide_to_zero=True,
                export_def_bones=False, export_rest_position_armature=True, export_reset_pose_bones=True,
                export_optimize_animation_size=False, export_extras=False, export_cameras=False,
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
    acts = make_actions(arm, D) if with_actions else None
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
        })
        print("BC_CHARS %-10s %-8s %-8s h=%2d vox tris=%d" % (spec["name"], spec["role"], spec["body"], top, tris))
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
        "seat_vox": SEAT_VOX,
        "bones": {b: PARENT.get(b) for b in BONES},
        "bodies": {b: {k: v for k, v in dims(b).items() if k in ("tw", "td", "leg", "chest", "h", "T")} for b in BODIES},
        "animations": [{"name": n, "frames": f, "seconds": round(f / FPS, 3), "loop": lp,
                        "root_speed_mps": WALK_SPEED.get(n, 0.0)} for n, f, _, lp in ANIMS],
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

ROWS = [("Regulars", "regular"), ("Staff and house band", ("staff", "band")), ("Anonymous patrons", "patron")]
SPACING = 1.0
ROW_GAP = 2.0
POSE_FRAME = 12                # the still shows every armature at this frame
ANIM_ROW = "patron_05"        # the preset that demonstrates every animation


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


def review_content(scene, lab):
    """The preset rows, the animation row and the parts lineup, one collection each, starting at y = 0 and
    growing toward +Y. Returns (depth, widest row width) in metres. Shared by build_review and bc_review.py."""
    y = 0.0
    acts_by_body = {}
    widest = 0.0
    for title, roles in ROWS:
        roles = (roles,) if isinstance(roles, str) else roles
        group = [p for p in PRESETS if p["role"] in roles]
        coll = bpy.data.collections.new(title)
        scene.collection.children.link(coll)
        width = SPACING * (len(group) - 1)
        widest = max(widest, width)
        text(coll, title + "_title", title, (-width / 2 - 1.2, y, 0.002), 0.16, lab).data.align_x = "RIGHT"
        for i, spec in enumerate(group):
            x = -width / 2 + i * SPACING
            arm, objs, _, _, _ = build_character(spec, coll, prefix=spec["name"] + ".", with_actions=False)
            arm.location = (x, y, 0)
            body = spec["body"]
            if body not in acts_by_body:
                acts_by_body[body] = make_actions(arm, dims(body), prefix=body + ".")
            arm.animation_data_create()
            arm.animation_data.action = acts_by_body[body]["idle"]
            try:
                if arm.animation_data.action_slot is None and acts_by_body[body]["idle"].slots:
                    arm.animation_data.action_slot = acts_by_body[body]["idle"].slots[0]
            except AttributeError:
                pass
            text(coll, spec["name"] + "_label", spec["display"], (x, y - 0.55, 0.002), 0.085, lab)
        y += ROW_GAP
    # one character per animation, so the poses can be checked in the still
    coll = bpy.data.collections.new("Animations")
    scene.collection.children.link(coll)
    spec = next(p for p in PRESETS if p["name"] == ANIM_ROW)
    width = SPACING * 1.15 * (len(ANIMS) - 1)
    text(coll, "anim_title", "Animations (frame %d)" % POSE_FRAME, (-widest / 2 - 1.2, y, 0.002), 0.16, lab).data.align_x = "RIGHT"
    for i, (name, _, _, _) in enumerate(ANIMS):
        x = -width / 2 + i * SPACING * 1.15
        arm, _, _, _, _ = build_character(spec, coll, prefix="anim_%s." % name, with_actions=False)
        arm.location = (x, y, 0)
        arm.animation_data_create()
        act = acts_by_body[spec["body"]][name] if spec["body"] in acts_by_body else None
        if act is None:
            acts_by_body[spec["body"]] = make_actions(arm, dims(spec["body"]), prefix=spec["body"] + ".")
            act = acts_by_body[spec["body"]][name]
        arm.animation_data.action = act
        try:
            if arm.animation_data.action_slot is None and act.slots:
                arm.animation_data.action_slot = act.slots[0]
        except AttributeError:
            pass
        text(coll, "anim_%s_label" % name, name, (x, y - 0.55, 0.002), 0.075, lab)
    y += ROW_GAP
    # parts lineup: one bust per head shape and hair style, then outfits on mannequins, then props
    lineup = bpy.data.collections.new("Parts lineup")
    scene.collection.children.link(lineup)
    D = dims("regular")
    C = dict(DEFAULT_COLOURS)
    busts = [("head:" + s, [build_head(s, D, C)]) for s in HEADS]
    busts += [("hair:" + s, [build_head("square", D, C), build_hair(s, D, C)]) for s in HAIRS]
    for i, (e, b, m) in enumerate(zip(EYES, list(BROWS)[1:] + ["flat"], MOUTHS)):
        busts.append(("face %d" % (i + 1), [build_head("soft", D, C), build_eyes(e, D, C), build_brows(b, D, C),
                                              build_mouth(m, D, C), build_hair("buzz", D, C)]))
    for a in ("hat_bucket", "hat_flat_cap", "hat_beanie", "glasses_round", "glasses_tinted", "glasses_up",
              "headphones", "ribbon", "pencil"):
        busts.append((a, [build_head("square", D, C), build_hair("ponytail" if a == "ribbon" else "bun" if a == "pencil" else "crop", D, C),
                          build_eyes("dot", D, C), build_acc(a, D, C)]))
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
    for a in ("gig_bag", "apron", "bar_towel", "gaffer_tape", "guitar", "bass", "drumsticks", "mic", "drink_beer",
              "glass_gold", "shaker", "notebook", "torch", "clicker", "sketchbook", "vinyl", "wheelie_bag"):
        bodies.append((a, "regular", dict(acc=[a])))
    half = (len(busts) + 1) // 2
    rows = [(busts[:half], 0.85, True), (busts[half:], 0.85, True), (bodies[:16], 0.9, False), (bodies[16:], 0.9, False)]
    y += 0.4
    text(lineup, "lineup_title", "Parts", (-widest / 2 - 1.2, y, 0.002), 0.16, lab).data.align_x = "RIGHT"
    for items, sp, is_bust in rows:
        n = len(items)
        width = sp * (n - 1)
        for i, it in enumerate(items):
            x = -width / 2 + i * sp
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
        y += 1.2 if is_bust else 1.8
    return y, widest


def build_review(render=True):
    from mathutils import Vector
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
    K.review_light(setup, "WarmKey", "SUN", (0, 0, 10), 2.2, (1.0, 0.76, 0.56), rot=(math.radians(50), 0, math.radians(20)))
    K.review_light(setup, "RedFill", "SUN", (0, 0, 10), 0.5, (1.0, 0.15, 0.1), rot=(math.radians(60), 0, math.radians(200)))
    K.review_light(setup, "WarmRim", "SUN", (0, 0, 10), 1.2, (1.0, 0.6, 0.3), rot=(math.radians(-60), 0, math.radians(-20)))
    for i in range(4):
        K.review_light(setup, "Pool%d" % i, "POINT", ((i - 1.5) * widest / 3.5, 1.6, 3.0), 500.0, (1.0, 0.72, 0.45), size=0.6)
    cam = bpy.data.objects.new("ReviewCamera", bpy.data.cameras.new("ReviewCamera"))
    cam.data.lens = 35
    cam.data.clip_end = 500.0
    aim = Vector((0.0, y * 0.40, 0.4))
    dist = max(span_x * 0.80, y * 1.15)
    elev = math.radians(38)
    cam.location = aim + Vector((0.0, -dist * math.cos(elev), dist * math.sin(elev)))
    cam.rotation_euler = (aim - cam.location).to_track_quat("-Z", "Y").to_euler()
    setup.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = 2100, 1400
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
