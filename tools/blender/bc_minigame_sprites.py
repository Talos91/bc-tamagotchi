"""Black Cabin Tamagotchi - minigame voxel sprites (look B, docs/design/11-minigame-quality.md section 1).

Builds every minigame object as a voxel model in the venue kit's style (bc_kit palette, jitter and seam texture,
emissive neon; characters from bc_chars), renders each one ONCE with an orthographic camera and a transparent
background, and leaves raw frames for the packer, which makes the sprite strips, glow strips, backdrops,
per-game sprites.json, contact sheets and the wiring README:

    blender --background --factory-startup --python tools/blender/bc_minigame_sprites.py
    python tools/blender/bc_minigame_pack.py

Options after `--`: `--game neon_moth,soi_dash` (only those games), `--no-backdrops` (skip the venue renders),
`--no-blend` (skip the review file), `--no-render` (build and save the review file only).
Raw frames go to %TEMP%/bc_mg_raw/<game>/ with manifest.json; the packer writes game/assets/minigames/<game>/.
A full run saves the lit, labelled review scene blender/BlackCabinMinigames.blend (one collection per game,
frame 0 of every sprite on a grid with its name, warm key and red rim lights, a camera over the whole set).

Backdrops: the game's own venue (blender/BlackCabin.blend, from bc_review.py) rendered from a camera in the room
the game is played in (lounge, Buffer tall tables, bar, stage, candle table); Soi Dash's night soi and the pinball
playfield are built here. The packer blurs and darkens them.

Every sprite records its frame size, frame count, anchor pixel (the model point the game positions, e.g. the
bottom centre of a speaker cabinet or the pivot of a flipper) and named points (e.g. the inside of the pour glass)
so the builders can wire them without measuring. Axes as bc_kit: x right, y back (front = -y), z up.
Deterministic: same script, same pixels (EEVEE, fixed samples).
"""
import json
import math
import os
import random
import shutil
import subprocess
import sys
import tempfile

import bpy
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.path.join(os.getcwd(), "tools", "blender")
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import bc_kit as K                                                   # noqa: E402
import bc_chars as B                                                 # noqa: E402

VOX = K.VOX
E = K.E
OUT = os.path.join(K.REPO, "game", "assets", "minigames")
RAW = os.path.join(tempfile.gettempdir(), "bc_mg_raw")
BLEND = os.path.join(K.REPO, "blender", "BlackCabinMinigames.blend")
VENUE_BLEND = os.path.join(K.REPO, "blender", "BlackCabin.blend")
EMIT_CAP = 1.5                 # emission strength cap for sprite renders (glow comes from the _glow sprite)
GAMES = ("neon_moth", "coaster_flip", "soi_dash", "shake_serve", "pour_perfect", "front_row_rhythm",
         "candle_talk", "neon_pinball")

# Swatches the venue kit has no use for (street, animals, drinks, moth). Same tuple as bc_kit: hex, roughness,
# metallic, emission strength (used only through E()).
K.PALETTE.update({
    "MGMothWing":   ("#C8B49A", 0.90, 0.0, 0),
    "MGMothEdge":   ("#6E5440", 0.90, 0.0, 0),
    "MGMothBody":   ("#5A4434", 0.90, 0.0, 0),
    "MGMothFur":    ("#E2D6C2", 0.95, 0.0, 0),
    "MGChar":       ("#2A1610", 0.95, 0.0, 0),
    "MGEmber":      ("#FF7A20", 0.40, 0.0, 4.5),
    "MGCord":       ("#3A2218", 0.80, 0.0, 0),
    "MGCardboard":  ("#B8A684", 0.90, 0.0, 0),
    "MGAsphalt":    ("#2A2428", 0.90, 0.0, 0),
    "MGAsphaltLite": ("#3C3438", 0.90, 0.0, 0),
    "MGPaint":      ("#D8D2C8", 0.70, 0.0, 0),
    "MGKerbWhite":  ("#E0DCD4", 0.80, 0.0, 0),
    "MGLizard":     ("#4E5638", 0.80, 0.0, 0),
    "MGLizardDark": ("#2C3220", 0.80, 0.0, 0),
    "MGLizardPale": ("#9A9668", 0.80, 0.0, 0),
    "MGDog":        ("#C4A07A", 0.95, 0.0, 0),
    "MGDogDark":    ("#8A6A4A", 0.95, 0.0, 0),
    "MGDogPale":    ("#E4D2B4", 0.95, 0.0, 0),
    "MGTukBlue":    ("#1E5AA8", 0.40, 0.0, 0),
    "MGTukYellow":  ("#E8B830", 0.40, 0.0, 0),
    "MGChrome":     ("#C4C0C4", 0.25, 0.3, 0),
    "MGTyre":       ("#141012", 0.90, 0.0, 0),
    "MGBikeRed":    ("#B01818", 0.35, 0.0, 0),
    "MGSteel":      ("#B4B0B4", 0.35, 0.2, 0),
    "MGGlass":      ("#9EB4BC", 0.10, 0.0, 0),
    "MGUmbrella":   ("#C02020", 0.80, 0.0, 0),
    "MGShutter":    ("#5A5A62", 0.50, 0.2, 0),
    "MGWallTeal":   ("#2E5856", 0.85, 0.0, 0),
    "MGWallOchre":  ("#7A5A34", 0.85, 0.0, 0),
    "MGWallGrey":   ("#4A4448", 0.85, 0.0, 0),
    "MGNeonPink":   ("#FF3AA0", 0.40, 0.0, 4.0),
    "MGNeonGreen":  ("#3AFF7A", 0.40, 0.0, 3.5),
    "MGNeonBlue":   ("#3A8CFF", 0.40, 0.0, 3.5),
    "MGSky":        ("#120A18", 0.90, 0.0, 0),
    "MGLime":       ("#6CB43A", 0.70, 0.0, 0),
    "MGLimeDark":   ("#3E7A22", 0.70, 0.0, 0),
    "MGLimePulp":   ("#C8E07A", 0.70, 0.0, 0),
    "MGCola":       ("#2A1008", 0.15, 0.0, 0),
    "MGGinger":     ("#B87A34", 0.40, 0.0, 0),
    "MGSyrup":      ("#E8E0D0", 0.20, 0.0, 0),
    "MGWhisky":     ("#9A5A1C", 0.15, 0.0, 0),
    "MGTequila":    ("#D8B860", 0.15, 0.0, 0),
    "MGGin":        ("#A8C8B4", 0.15, 0.0, 0),
    "MGTonic":      ("#E0E4C8", 0.15, 0.0, 0),
    "MGSodaCap":    ("#2A6AC8", 0.40, 0.0, 0),
    "MGLabelRed":   ("#A8141C", 0.70, 0.0, 0),
    "MGLabelBlack": ("#1A1416", 0.70, 0.0, 0),
    "MGLabelGold":  ("#C89A40", 0.50, 0.3, 0),
    "MGDrink":      ("#E8A23A", 0.15, 0.0, 0),
    "MGIce":        ("#E4EEF0", 0.10, 0.0, 0),
    "MGWax":        ("#EDE4D0", 0.70, 0.0, 0),
    "MGFlame":      ("#FFB040", 0.40, 0.0, 5.0),
    "MGFlameCore":  ("#FFF0B0", 0.40, 0.0, 6.0),
    "MGBumper":     ("#18D0FA", 0.30, 0.0, 1.0),
    "MGBumperHot":  ("#C8F6FF", 0.30, 0.0, 6.0),
    "MGInsertBlue": ("#103A58", 0.40, 0.0, 0),
    "MGPfDark":     ("#0A0E18", 0.60, 0.0, 0),
    "MGInsertRed":  ("#5A0C10", 0.40, 0.0, 0),
    "MGRubber":     ("#A8201C", 0.80, 0.0, 0),
    "MGBall":       ("#E4E4EC", 0.20, 0.0, 0),
    "MGPuckRim":    ("#E8DCC0", 0.50, 0.0, 0),
    "MGPuckDim":    ("#5A5254", 0.70, 0.0, 0),
    "MGSkin":       ("#D2A07A", 0.55, 0.0, 0),
    "MGSkinShade":  ("#B8885E", 0.55, 0.0, 0),
    "MGWindowWarm": ("#FFC870", 0.40, 0.0, 2.0),
})

# ------------------------------------------------------------------ registry

SPRITES = []


def sprite(game, name, frames=1, ppv=4, view=(0, 20), glow=False, anchor=(0, 0, 0), pad=2, note="",
           opaque=False, persp=None, size=None, points=None, frame_names=None, alpha=None):
    """Register a sprite. The builder is fn(ctx, f) for frame f; it puts models with ctx.vox / ctx.part / ctx.rig.
    ppv: pixels per voxel (orthographic). view: (yaw, elevation) degrees, 0/0 = straight at the front (-y).
    anchor: model point in voxels recorded as a pixel. opaque + persp: a backdrop (perspective camera, no alpha)."""
    def deco(fn):
        SPRITES.append(dict(game=game, name=name, frames=frames, ppv=ppv, view=view, glow=glow, anchor=anchor,
                            pad=pad + (24 if glow else 0), note=note, opaque=opaque, persp=persp, size=size,
                            points=points or {}, frame_names=frame_names, alpha=alpha, fn=fn))
        return fn
    return deco


class Ctx:
    """Where a frame's models go: one collection per frame."""

    def __init__(self, coll):
        self.coll = coll
        self.objs = []
        self.n = 0

    def _take(self, ob):
        for c in list(ob.users_collection):
            c.objects.unlink(ob)
        self.coll.objects.link(ob)
        self.objs.append(ob)
        return ob

    def vox(self, v, pivot=(0, 0, 0), loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0):
        """Mesh a bc_kit.Vox with its own voxel coordinates (cell x spans x..x+1), rotated by rot (degrees, XYZ)
        about pivot (voxels) and moved by loc (voxels)."""
        if not v.cells:
            return None
        self.n += 1
        ob, _ = K.build_mesh("mg%03d" % self.n, v, "ceiling")        # "ceiling": keeps the bottom faces
        (x0, y0, z0), (x1, y1, z1) = v.bounds()
        origin = Vector((-(x0 + x1 + 1) / 2.0, -(y0 + y1 + 1) / 2.0, -(z1 + 1)))
        pv = Vector(pivot)
        ob.data.transform(Matrix.Translation((-origin - pv) * VOX))
        ob.location = (pv + Vector(loc)) * VOX
        ob.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
        ob.scale = (scale, scale, scale)
        return self._take(ob)

    def part(self, part, pivot=(0, 0, 0), loc=(0, 0, 0), rot=(0, 0, 0)):
        """Mesh a bc_chars.Part (no rig) the same way."""
        self.n += 1
        ob, _ = B.build_mesh(part, "mgp%03d" % self.n, self.coll)
        pv = Vector(pivot)
        ob.data.transform(Matrix.Translation(-pv * VOX))
        ob.location = (pv + Vector(loc)) * VOX
        ob.rotation_euler = Euler([math.radians(a) for a in rot], "XYZ")
        self.objs.append(ob)
        return ob

    def rig(self, spec, pose_fn=None):
        """A whole rigged character, posed by pose_fn(D) -> bc_chars pose dict."""
        self.n += 1
        arm, objs, _, _, _ = B.build_character(spec, self.coll, "mgc%03d_" % self.n, with_actions=False)
        D = B.dims(spec["body"])
        if pose_fn:
            sol = B.solve(pose_fn(D), D)
            for bn in B.BONES:
                pb = arm.pose.bones[bn]
                q, l = sol[bn]
                pb.rotation_quaternion = q
                pb.location = (l[0] * VOX, l[1] * VOX, l[2] * VOX)
        self.objs.extend(objs)
        return arm, D


# ------------------------------------------------------------------ small helpers

def V():
    return K.Vox()


def font_cells(ch):
    return [(c, 6 - r) for r, bits in enumerate(K.FONT[ch]) for c, b in enumerate(bits) if b == "1"]


def disc(v, cx, cy, z0, z1, d, m, inner=0):
    v.cyl(cx, cy, z0, z1, d, m, axis="z", inner=inner)


def preset(pid):
    return next(p for p in B.PRESETS if p["name"] == pid)


def with_face(spec, **kw):
    s = dict(spec)
    s.update(kw)
    return s


def head_parts(spec, bones=("head",), zmin=None):
    """bc_chars parts of a preset reduced to the given bones (or to every cell at or above zmin)."""
    out = []
    for p in B.assemble(spec):
        if p.pid in B.DRINKS or p.slot in B.DRINKS:
            continue
        q = B.Part(p.pid, p.slot)
        for c, val in p.cells.items():
            if (zmin is None and val[1] in bones) or (zmin is not None and c[2] >= zmin):
                q.cells[c] = val
        for d in p.decals:
            if (zmin is None and d[4] in bones) or (zmin is not None and d[2] >= zmin):
                q.decals.append(d)
        if not q.empty():
            out.append(q)
    return out


REGULARS = ("tt", "tong", "ploy", "jules", "dougie", "lung_nop", "bow", "hiro")
CHEER = dict(eyes="happy", mouth="grin")

# ================================================================== NEON MOTH


def moth_wing(near, singe=None):
    """A flat wing in the x-y plane (z = 0), hinged on the body edge: near wing toward -y, far wing toward +y."""
    v = V()
    sgn = -1 if near else 1
    for j in range(1, 13):
        for x in range(-2, 12):
            fore = ((x - 6.0 + j * 0.25) / 4.2) ** 2 + ((j - 6.5) / 6.2) ** 2 <= 1.0
            hind = ((x - 1.0) / 3.2) ** 2 + ((j - 4.0) / 4.4) ** 2 <= 1.0
            if not (fore or hind):
                continue
            m = "MGMothFur" if fore else "MGMothWing"
            edge_f = fore and ((x + 1 - 6.0 + j * 0.25) / 4.2) ** 2 + ((j - 6.5) / 6.2) ** 2 > 1.0
            if j >= 11 or (fore and (j >= 10 or edge_f)) or (hind and not fore and j >= 7):
                m = "MGMothEdge"
            if fore and 6 <= j <= 7 and 5 <= x <= 6:                 # eye spot
                m = "CymbalGold" if (x, j) != (5, 7) else "BeamBlack"
            if fore and j in (3, 4) and x in (3, 8):
                m = "MGMothEdge"
            v.set(x, sgn * j if near else j, 0, m)
    if singe:
        rnd = random.Random(singe)
        tips = [c for c in v.cells if abs(c[1]) >= 9]
        for c in tips:
            r = rnd.random()
            if r < 0.35:
                v.cells[c] = "MGChar"
            elif r < 0.55:
                v.cells[c] = E("MGEmber")
    return v


def moth(ctx, flap, singe=None):
    v = V()
    for x in range(0, 4):                                            # abdomen, striped
        v.box(x, 0, 0, x, 1, 1, "MGMothBody" if x % 2 else "MGMothEdge")
    v.box(4, -1, -1, 6, 2, 2, "MGMothBody")                          # thorax
    v.box(6, -1, 2, 6, 2, 2, "MGMothFur")                            # fur collar
    v.box(6, -1, -1, 6, -1, 2, "MGMothFur")
    v.box(7, 0, 0, 8, 1, 1, "MGMothBody")                            # head
    v.set(9, -1, 1, "BeamBlack")                                     # eyes
    v.set(9, 2, 1, "BeamBlack")
    v.box(9, 0, 1, 9, 1, 1, "MGMothBody")
    for side, y0 in ((-1, 0), (1, 1)):                               # feathered antennae
        v.line((9, y0, 2), (12, y0 + side * 3, 5), "MGMothEdge")
        v.set(11, y0 + side * 2, 5, "MGMothEdge")
    ctx.vox(v)
    ctx.vox(moth_wing(True, singe), pivot=(0, 0, 0.5), loc=(1, -0, 0), rot=(-flap, 0, 0))
    ctx.vox(moth_wing(False, singe and singe + 7), pivot=(0, 2, 0.5), loc=(1, 0, 0), rot=(flap, 0, 0))


FLAP = (55, 20, -30, 5)


@sprite("neon_moth", "moth", frames=4, ppv=4, view=(-90, 68), anchor=(5.5, 1, 1),
        note="seen from above, head up, wings spread left and right (rotate 90 deg clockwise to face the flight, "
        "tilt with the vertical speed); flap cycle: frame 0 wings up, 2 down; one tap = play 0-1-2-3 once (or loop at 12 fps)")
def s_moth(ctx, f):
    moth(ctx, FLAP[f])


@sprite("neon_moth", "moth_singe", frames=2, ppv=4, view=(-90, 68), anchor=(5.5, 1, 1),
        note="singed wing tips with embers; alternate during the 1.2 s blink")
def s_moth_singe(ctx, f):
    moth(ctx, 20 if f == 0 else -10, singe=11 + f)


@sprite("neon_moth", "wing_icon", frames=2, ppv=3, view=(0, 90), anchor=(5, -6, 0),
        frame_names=["whole", "broken"], note="life pip: one per singe left")
def s_wing_icon(ctx, f):
    v = moth_wing(True)
    if f == 1:
        for c in list(v.cells):
            if c[0] + c[1] * 0.6 > 1.5:                                  # snapped off along a diagonal
                v.cells[c] = "MGChar" if c[0] + c[1] * 0.6 < 3.0 else None
        v.cells = {c: m for c, m in v.cells.items() if m}
    ctx.vox(v)


def bulb(v, cx, z_top, lit):
    """Socket and an Edison bulb hanging from z_top down (4 x 4 x 5 glass)."""
    v.box(cx - 1, -1, z_top - 1, cx, 0, z_top, "StoolBlack")
    v.box(cx - 1, -1, z_top - 2, cx, 0, z_top - 2, "CymbalGold")
    m = E("LampGold") if lit else "LampGoldOff"
    v.box(cx - 2, -2, z_top - 6, cx + 1, 1, z_top - 3, m)
    v.box(cx - 1, -1, z_top - 7, cx, 0, z_top - 7, m)
    for x in (cx - 2, cx + 1):                                       # round the glass
        for y in (-2, 1):
            v.remove(x, y, z_top - 3)
            v.remove(x, y, z_top - 6)


@sprite("neon_moth", "bulb_drop", frames=2, ppv=5, view=(0, 10), glow=True, anchor=(0, 0, 0),
        frame_names=["lit", "off"], note="anchor = top of the cord; hang the drop's top at the batten, tile 'cord' above")
def s_bulb_drop(ctx, f):
    v = V()
    v.box(-1, -1, -12, -1, -1, -1, "MGCord")
    bulb(v, 0, -13, f == 0)
    ctx.vox(v, loc=(0, 0, 0))


@sprite("neon_moth", "cord", ppv=5, view=(0, 10), anchor=(0, 0, 0), pad=0,
        note="tile vertically above a bulb_drop (texture repeat)")
def s_cord(ctx, f):
    v = V()
    v.box(0, 0, 0, 0, 0, 7, "MGCord")
    ctx.vox(v)


@sprite("neon_moth", "batten", ppv=6, view=(0, 10), anchor=(0, 0, 0),
        note="the wooden batten across the top of the gap (GATE_W wide); anchor = its bottom centre")
def s_batten(ctx, f):
    v = V()
    v.box(-10, -1, 0, 9, 1, 2, "WoodMid")
    v.box(-10, -1, 2, 9, 1, 2, "TableWoodLit")
    for x in (-7, 0, 6):
        v.box(x, -2, -1, x, -2, 0, "CymbalGold")
    ctx.vox(v)


def speaker_cab(v, z0, variant):
    W, H = 18, 18
    v.box(0, 0, z0, W - 1, 9, z0 + H - 1, "StoolBlack")
    v.box(1, 0, z0 + 1, W - 2, 0, z0 + H - 2, "BeamBlack")
    if variant == 0:
        v.cyl(8.5, z0 + 8.5, 0, 0, 14, "PrintGrey", axis="y", inner=12)
        v.cyl(8.5, z0 + 8.5, -1, -1, 12, "FloorGrey", axis="y", inner=4)
        v.cyl(8.5, z0 + 8.5, -2, -2, 4, "PrintGrey", axis="y")
    else:
        for cx in (4.5, 12.5):
            v.cyl(cx, z0 + 5.5, 0, 0, 7, "PrintGrey", axis="y", inner=5)
            v.cyl(cx, z0 + 5.5, -1, -1, 5, "FloorGrey", axis="y")
            v.cyl(cx, z0 + 5.5, -2, -2, 2, "PrintGrey", axis="y")
        v.box(4, 0, z0 + 11, 13, 0, z0 + 15, "PrintGrey")              # horn
        v.box(6, -1, z0 + 12, 11, -1, z0 + 14, "BeamBlack")
    v.box(0, -1, z0 + H - 1, W - 1, -1, z0 + H - 1, "ColumnWhite")     # piping
    for x in (0, W - 1):
        for z in (z0, z0 + H - 1):
            v.set(x, -1, z, "FloorGrey")
    v.set(W - 3, -1, z0 + 1, E("NeonRed"))


@sprite("neon_moth", "speaker_cab", frames=2, ppv=6, view=(0, 12), anchor=(9, 0, 0),
        frame_names=["woofer", "horn"], note="stack from the floor up to the gap; anchor = bottom centre of the front; "
        "next cab sits stack_step_px higher")
def s_speaker(ctx, f):
    v = V()
    speaker_cab(v, 0, f)
    ctx.vox(v)


@sprite("neon_moth", "neon_sign", ppv=11, view=(0, 0), glow=True, anchor=(14.5, 1, 0),
        note="the kit's own BLACK CABIN neon (bc_kit.neon_sign); anchor = bottom centre")
def s_moth_sign(ctx, f):
    v = V()
    K.neon_sign(v)
    ctx.vox(v)


# ================================================================== COASTER FLIP

def coaster():
    v = V()
    d = 18
    for (u, w) in v.disc_cells(0, 0, d):
        r = math.hypot(u + 0.5, w + 0.5)
        top = "StoolBlack"
        if 6.6 <= r <= 7.8:
            top = "PanelRed"
        if r > 8.4:
            top = "LabelCream"
        v.set(u, w, 0, "MGCardboard")
        v.set(u, w, 1, top)
    for ci, ch in enumerate("BC"):                                   # BC monogram, 5 x 7, cream
        for (c, r) in font_cells(ch):
            v.set(-6 + ci * 7 + c, -3 + r - 1, 1, "LabelCream")
    return v


@sprite("coaster_flip", "coaster", frames=8, ppv=9, view=(0, 16), anchor=(0, 0, 1),
        note="spin: frame = round(spin_turns * 8) % 8; frame 0 flat top up, 2 edge on (vertical), 4 flat bottom up. "
        "Stack on the table: frame 0 repeated, stack_step 10 px as today")
def s_coaster(ctx, f):
    ctx.vox(coaster(), pivot=(0, 0, 1), rot=(0, f * 45, 0))


@sprite("coaster_flip", "ring", frames=2, ppv=9, view=(0, 0), glow=True, anchor=(0, 0, 0),
        frame_names=["lit", "dim"], note="catch ring; lit when flat enough (alignment() >= flat_needed)")
def s_ring(ctx, f):
    v = V()
    m = E("LampGold") if f == 0 else "LampGoldOff"
    for (u, w) in v.disc_cells(0, 0, 30):
        if math.hypot(u + 0.5, w + 0.5) >= 12.6:
            v.set(u, 0, w, m)
    ctx.vox(v)


@sprite("coaster_flip", "table_top", ppv=9, view=(0, 16), anchor=(0, -4, 3),
        note="tall table top + edge, 0.88 x the play width; anchor = front top edge centre (the table line)")
def s_table_top(ctx, f):
    v = V()
    v.box(-38, -4, 0, 37, 4, 1, "WoodMid")
    v.box(-38, -4, 2, 37, 4, 2, "TableWoodLit")
    v.box(-38, -5, 0, 37, -5, 0, "WoodDark")
    v.box(28, 0, 3, 30, 2, 3, "CymbalGold")                           # tealight lantern at the far end
    v.box(28, 0, 4, 30, 2, 5, E("LanternAmber"))
    ctx.vox(v)


@sprite("coaster_flip", "table_leg", ppv=9, view=(0, 16), anchor=(0, 0, 8), pad=0,
        note="the table post; tile downward from the table edge")
def s_table_leg(ctx, f):
    v = V()
    v.box(-3, -3, 0, 2, 2, 7, "WoodDark")
    v.box(-1, -4, 0, 0, -4, 7, "ChairWoodDark")
    ctx.vox(v)


def regular_head(ctx, pid, f, nod=0.0):
    spec = preset(pid)
    if f == 1:
        spec = with_face(spec, **CHEER)
    D = B.dims(spec["body"])
    for p in head_parts(spec):
        ctx.part(p, pivot=(0, 0, D["h"]), rot=(nod, 0, 0))
    return D


for _rid in REGULARS:
    def _mk(rid):
        @sprite("coaster_flip", "regular_" + rid, frames=2, ppv=8, view=(-15, 8), anchor=(0, 0, 0),
                frame_names=["calm", "cheer"],
                note="the table's regular (config.regular); load only this one; anchor = neck")
        def s_reg_head(ctx, f):
            D = regular_head(ctx, rid, f)
            ctx.anchor_z = D["h"]
        return s_reg_head
    _mk(_rid)


# ================================================================== SOI DASH

RUNNER = B.P("runner", "Runner", "player", "PLAYER", "regular", "soft", "shaggy", ("dot", "flat", "smile"),
             "tee", "jeans", "sneakers", [], top="VelvetRed", top_trim="CabinDark", hair="HairDarkBrown")


def run_pose(t):
    return lambda D: B.walk(t, D, legs=50, arms=55, bob=1.4, lean=12, arms_wide=6)


def hop_pose(f):
    if f == 0:
        return lambda D: B.pose(leg_L=((-75, 0, 4),), leg_R=((-55, 0, -4),), shin_L=((95, 0, 0),),
                                shin_R=((80, 0, 0),), spine=((10, 0, 0),), hips=((0, 0, 0), (0, 2.0, 0)),
                                arm_L=((-70, 0, 30),), arm_R=((-70, 0, -30),), forearm_L=((-30, 0, 0),),
                                forearm_R=((-30, 0, 0),))
    return lambda D: B.pose(leg_L=((-25, 0, 6),), leg_R=((30, 0, -6),), shin_L=((40, 0, 0),), shin_R=((25, 0, 0),),
                            spine=((4, 0, 0),), hips=((0, 0, 0), (0, 2.0, 0)),
                            arm_L=((-150, 0, 25),), arm_R=((-150, 0, -25),))


@sprite("soi_dash", "runner", frames=6, ppv=6, view=(155, 14), anchor=(0, 0, 0),
        frame_names=["run0", "run1", "run2", "run3", "hop_tuck", "hop_reach"],
        note="seen from behind; frames 0-3 run (advance by distance), 4-5 hop (tuck on the way up, reach at the top). "
        "Default avatar: the player's own avatar needs a runtime render (builder's call)")
def s_runner(ctx, f):
    ctx.rig(RUNNER, run_pose(f / 4.0) if f < 4 else hop_pose(f - 4))


def wheel(v, cx, cz, d, y0, y1, hub="MGChrome"):
    for y in range(y0, y1 + 1):
        v.cyl(cx, cz, y, y, d, "MGTyre", axis="y")
    v.cyl(cx, cz, y0 - 1, y0 - 1, max(2, d // 2), hub, axis="y")


@sprite("soi_dash", "motorbike", ppv=6, view=(-25, 22), anchor=(0, 0, 0),
        note="parked scooter across the lane; anchor = ground centre")
def s_bike(ctx, f):
    v = V()
    wheel(v, -10.5, 3.5, 8, -1, 1)
    wheel(v, 9.5, 3.5, 8, -1, 1)
    v.box(-9, -2, 5, 3, 2, 9, "MGBikeRed")                              # body and floorboard
    v.box(-12, -2, 7, -4, 2, 12, "MGBikeRed")                           # rear body under the seat
    v.box(-12, -2, 13, -4, 2, 14, "StoolBlack")                         # seat
    v.box(4, -2, 5, 7, 2, 16, "MGBikeRed")                              # leg shield
    v.line((8, 0, 4), (10, 0, 17), "MGChrome")                          # fork
    v.box(8, -5, 18, 11, 5, 18, "MGChrome")                             # handlebar
    v.box(10, -2, 15, 12, 2, 17, "MGBikeRed")                           # headlamp housing
    v.box(12, -1, 16, 12, 1, 16, E("LampGold"))
    v.box(-13, -1, 10, -13, 1, 10, E("NeonRed"))                        # tail light
    v.box(-8, 2, 4, 2, 2, 4, "MGChrome")                                # exhaust
    v.box(6, -6, 18, 6, -6, 20, "MGChrome")                             # mirror
    v.box(6, -6, 21, 7, -6, 21, "MGChrome")
    ctx.vox(v)


@sprite("soi_dash", "tuk_tuk", ppv=6, view=(-25, 22), anchor=(0, 0, 0),
        note="parked tuk-tuk, blocks a lane; anchor = ground centre")
def s_tuktuk(ctx, f):
    ctx.vox(tuk_model())


def tuk_model():
    v = V()
    wheel(v, -11.5, 3, 6, -7, -6)
    wheel(v, -11.5, 3, 6, 6, 7)
    wheel(v, 13.5, 3, 6, -1, 0)
    v.box(-17, -6, 4, 8, 6, 12, "MGTukBlue")                            # passenger tub
    v.box(-16, -5, 10, -5, 5, 13, "StoolBlack")                         # bench
    v.box(9, -3, 4, 16, 3, 9, "MGTukBlue")                              # nose
    v.box(10, -3, 10, 12, 3, 10, "StoolBlack")                          # driver seat
    v.line((15, 0, 9), (16, 0, 16), "MGChrome")
    v.box(14, -5, 16, 16, 5, 16, "MGChrome")
    v.box(16, -1, 10, 16, 1, 11, E("LampGold"))
    for x in (-17, -6, 8):                                              # roof posts
        for y in (-6, 6):
            v.box(x, y, 13, x, y, 25, "MGChrome")
    v.box(-18, -7, 26, 9, 7, 27, "MGTukYellow")                         # roof
    v.box(-18, -7, 25, 9, -7, 25, "MGTukBlue")
    for x in range(-17, 9, 3):                                          # fringe lights under the roof
        v.set(x, -7, 24, E("MGNeonPink") if x % 2 else E("MGNeonGreen"))
    v.box(-17, -7, 8, 8, -7, 8, "MGChrome")                             # trim
    return v


@sprite("soi_dash", "tuk_tuk_front", ppv=5, view=(70, 12), glow=True, anchor=(0, 0, 0),
        note="the same tuk-tuk driving at the runner (Q6): nose and headlight toward the camera; glow = headlight "
        "and fringe lights; anchor = ground centre")
def s_tuktuk_front(ctx, f):
    v = tuk_model()
    v.box(17, -2, 9, 17, 2, 12, E("LampGold"))                          # headlight, lit
    ctx.vox(v)


@sprite("soi_dash", "food_cart", ppv=6, view=(-25, 22), anchor=(0, 0, 0),
        note="noodle cart with umbrella, blocks a lane; anchor = ground centre")
def s_cart(ctx, f):
    v = V()
    wheel(v, -9.5, 3, 6, -6, -5)
    wheel(v, -9.5, 3, 6, 5, 6)
    v.box(-14, -5, 4, 13, 5, 16, "MGSteel")                             # body
    v.box(-13, -6, 6, 12, -6, 14, "MGWallOchre")                        # front panel
    v.box(-11, -7, 8, 9, -7, 12, "PanelRed")                            # painted sign band (no text)
    for x in range(-10, 10, 4):
        v.box(x, -8, 9, x + 1, -8, 11, "LabelCream")
    v.box(-14, -5, 17, 13, 5, 17, "MGSteel")
    v.box(-12, -4, 18, 3, 3, 23, "MGGlass")                             # glass case
    v.box(-11, -3, 18, 2, 2, 19, "MGLabelGold")                         # noodles inside
    v.box(5, -3, 18, 11, 3, 21, "MGSteel")                              # pot
    v.box(6, -2, 22, 10, 2, 22, "FloorGrey")
    v.box(-11, -3, 24, -9, -1, 24, E("LampGold"))                       # bare bulb
    v.box(-2, 0, 18, -2, 0, 33, "StoolBlack")                           # umbrella pole
    for (u, w) in v.disc_cells(-2, 0, 30):
        r = math.hypot(u + 2.5, w - 0.5 + 0.5)
        z = 34 - int(r // 4)
        ang = math.atan2(w + 0.5, u + 2.5)
        v.set(u, w, z, "MGUmbrella" if int((ang + math.pi) / (math.pi / 4)) % 2 else "MGKerbWhite")
    ctx.vox(v)


@sprite("soi_dash", "soi_dog", frames=2, ppv=6, view=(-25, 22), anchor=(0, 0, 0),
        frame_names=["asleep", "ear_up"], note="sleeping soi dog across the lane, hop it; anchor = ground centre")
def s_dog(ctx, f):
    v = V()
    v.box(-9, -4, 0, 7, 3, 5, "MGDog")                                  # body lying down
    v.box(-8, -4, 0, 6, -4, 1, "MGDogPale")                             # belly
    v.box(-4, -2, 6, 3, 2, 6, "MGDogDark")                              # back patch
    v.box(7, -4, 0, 13, 1, 5, "MGDog")                                  # head on the paws
    v.box(13, -3, 0, 15, 0, 2, "MGDogPale")                             # snout
    v.set(16, -2, 1, "BeamBlack")                                       # nose
    v.box(10, -5, 3, 11, -5, 3, "BeamBlack")                            # closed eye
    v.box(8, -4, 6, 9, -2, 7 + f * 2, "MGDogDark")                      # ear (perks up on frame 1)
    v.box(8, 0, 6, 9, 1, 7, "MGDogDark")
    v.box(8, -6, 0, 15, -5, 1, "MGDog")                                 # front paws
    v.line((-9, 0, 2), (-15, -3, 1), "MGDog")                           # tail
    v.line((-15, -3, 1), (-16, -6, 1), "MGDogPale")
    ctx.vox(v)


@sprite("soi_dash", "soi_dog_trot", frames=2, ppv=6, view=(-25, 22), anchor=(0, 0, 0),
        frame_names=["stride", "gather"],
        note="stray soi dog trotting across the soi (Q6), head toward +x (screen right); mirror to trot left; "
        "alternate the frames at ~8 fps while it moves; anchor = ground centre")
def s_dog_trot(ctx, f):
    v = V()
    v.box(-8, -3, 6, 7, 2, 11, "MGDog")                                 # body, standing
    v.box(-6, -2, 6, 5, 1, 6, "MGDogPale")                              # belly
    v.box(-4, -2, 11, 2, 1, 11, "MGDogDark")                            # back patch
    v.box(6, -2, 10, 9, 1, 14, "MGDog")                                 # neck
    v.box(8, -2, 13, 13, 1, 17, "MGDog")                                # head
    v.box(13, -1, 13, 16, 0, 15, "MGDogPale")                           # snout
    v.set(16, -1, 15, "BeamBlack")                                      # nose
    v.set(12, -3, 16, "BeamBlack")                                      # eyes
    v.set(12, 2, 16, "BeamBlack")
    v.box(9, -2, 18, 10, -1, 19, "MGDogDark")                           # ears up
    v.box(9, 0, 18, 10, 1, 19, "MGDogDark")
    swing = (3, -3) if f == 0 else (1, -1)                              # stride: legs apart; gather: under the body
    for (lx, ly, k) in ((6, -3, 0), (6, 1, 1), (-7, -3, 1), (-7, 1, 0)):
        o = swing[k]
        for y in (ly, ly + 1):
            v.line((lx, y, 6), (lx + o, y, 0), "MGDog")
        v.set(lx + o, ly, 0, "MGDogPale")                               # paw
    v.line((-8, 0, 10), (-12, 0, 13 + f), "MGDog")                      # tail up, wagging
    v.line((-12, 0, 13 + f), (-13, 0, 15 + f), "MGDogPale")
    ctx.vox(v)


@sprite("soi_dash", "monitor_lizard", frames=2, ppv=6, view=(-25, 22), anchor=(0, 0, 0),
        frame_names=["still", "tongue"], note="water monitor crossing the soi, hop it; anchor = ground centre")
def s_lizard(ctx, f):
    v = V()
    for x in range(-12, 8):                                             # body, thick in the middle
        w = 3 if -8 <= x <= 3 else 2
        h = 4 if -8 <= x <= 3 else 3
        v.box(x, -w, 1, x, w - 1, h, "MGLizard")
        if x % 3 == 0:
            v.box(x, -w, h, x, w - 1, h, "MGLizardPale")                # banded back
    v.box(-10, -3, 1, -10, 2, 2, "MGLizardDark")
    for x in range(8, 14):                                              # neck and head
        v.box(x, -2, 2, x, 1, 4 if x < 12 else 3, "MGLizard")
    v.box(14, -1, 2, 16, 0, 3, "MGLizard")
    v.set(12, -2, 4, "BeamBlack")
    v.set(12, 1, 4, "BeamBlack")
    if f == 1:
        v.line((17, -1, 2), (20, -2, 2), "MGRubber")
        v.set(20, -3, 2, "MGRubber")
        v.set(20, -1, 2, "MGRubber")
    tail = [(-13 - i, int(round(2 * math.sin(i * 0.45))), 1 if i < 10 else 0) for i in range(18)]
    for i, (x, y, z) in enumerate(tail):
        v.box(x, y - (1 if i < 8 else 0), max(0, z), x, y, 2 if i < 6 else 1, "MGLizard" if i % 4 else "MGLizardPale")
    for (lx, ly) in ((-8, -4), (-8, 3), (4, -4), (4, 3)):               # splayed legs
        v.box(lx - 1, ly, 0, lx + 1, ly, 1, "MGLizardDark")
        v.box(lx - 1 + (2 if lx > 0 else -2), ly + (-1 if ly < 0 else 1), 0,
              lx + 1 + (2 if lx > 0 else -2), ly + (-1 if ly < 0 else 1), 0, "MGLizardDark")
    ctx.vox(v)


@sprite("soi_dash", "kerb", ppv=6, view=(-25, 22), anchor=(0, 0, 0),
        note="black and white kerb block, hop it; anchor = ground centre")
def s_kerb(ctx, f):
    v = V()
    for x in range(-14, 14):
        m = "MGKerbWhite" if (x // 4) % 2 else "StoneDark"
        v.box(x, -2, 0, x, 2, 3, m)
    ctx.vox(v)


@sprite("soi_dash", "note", ppv=5, view=(-15, 10), glow=True, anchor=(0, 0, 0),
        note="music note to collect; anchor = centre of the note head")
def s_note(ctx, f):
    v = V()
    for (u, w) in v.disc_cells(0, 0, 6):
        v.set(u, 0, w, E("LampGold"))
    v.box(2, 0, 0, 2, 0, 12, E("LampGold"))
    v.line((2, 0, 12), (6, 0, 8), E("LampGold"))
    v.line((2, 0, 10), (5, 0, 7), E("LampGold"))
    ctx.vox(v, loc=(0, 0, 0))


def facade(v, x0, variant, lit=True):
    """A two-storey Bangkok shophouse front, 30 wide, 50 tall, face at y = 0."""
    rnd = random.Random(variant * 31 + 5)
    wall = ("MGWallTeal", "MGWallOchre", "MGWallGrey")[variant % 3]
    v.box(x0, 0, 0, x0 + 29, 3, 49, wall)
    v.box(x0 + 2, -1, 0, x0 + 27, -1, 18, "MGShutter")                  # roller shutter, half up
    for z in range(1, 19, 2):
        v.box(x0 + 2, -1, z, x0 + 27, -1, z, "FloorGrey")
    if lit:
        v.box(x0 + 2, 0, 0, x0 + 27, 0, 9, E("CubbyGlow"))             # open shop below the shutter
        v.clear_box(x0 + 2, -1, 0, x0 + 27, -1, 9)
        for z in (3, 6):
            v.box(x0 + 3, -1, z, x0 + 26, -1, z, "StoolBlack")        # shelves inside
        v.box(x0 + 4, -2, 0, x0 + 8, -3, 4, "WoodMid")                  # crates
    v.box(x0, -3, 19, x0 + 29, -1, 20, "StoneDark")                     # awning
    sign = (E("MGNeonPink"), E("MGNeonGreen"), E("MGNeonBlue"), E("NeonRed"))[variant % 4]
    sx = x0 + 6
    v.box(sx - 1, -2, 22, sx + 18, -2, 30, "BeamBlack")                 # sign board, abstract neon shapes
    if variant % 3 == 0:                                                # a bowl
        for (u, w) in v.disc_cells(sx + 8.5, 26.5, 7):
            if w <= 26:
                v.set(u, -3, w, sign)
        v.line((sx + 12, -3, 27), (sx + 15, -3, 29), sign)
    elif variant % 3 == 1:                                              # a beer mug
        v.box(sx + 5, -3, 23, sx + 5, -3, 29, sign)
        v.box(sx + 11, -3, 23, sx + 11, -3, 29, sign)
        v.box(sx + 5, -3, 23, sx + 11, -3, 23, sign)
        v.box(sx + 5, -3, 29, sx + 11, -3, 29, sign)
        v.box(sx + 12, -3, 25, sx + 13, -3, 27, sign)
    else:                                                               # a star
        v.line((sx + 8, -3, 29), (sx + 11, -3, 23), sign)
        v.line((sx + 11, -3, 23), (sx + 5, -3, 27), sign)
        v.line((sx + 5, -3, 27), (sx + 12, -3, 27), sign)
        v.line((sx + 12, -3, 27), (sx + 6, -3, 23), sign)
        v.line((sx + 6, -3, 23), (sx + 8, -3, 29), sign)
    for i, wx in enumerate((x0 + 3, x0 + 12, x0 + 21)):                 # upper windows
        on = lit and rnd.random() < 0.6
        v.box(wx, -1, 34, wx + 5, -1, 42, E("MGWindowWarm") if on else "GlassNight")
        v.box(wx - 1, -2, 33, wx + 6, -2, 33, "FloorGrey")
        for z in (36, 39):
            v.box(wx, -2, z, wx + 5, -2, z, "StoolBlack")               # window grille
    v.box(x0 + 22, -4, 44, x0 + 27, -1, 47, "PlasticWhite")             # AC unit
    v.box(x0, -1, 48, x0 + 29, -1, 49, "StoneDark")


@sprite("soi_dash", "shopfront", frames=3, ppv=4, view=(0, 0), glow=True, anchor=(15, 0, 0),
        note="shophouse fronts for both sides of the soi, scrolling; anchor = bottom centre; mirror for the right side")
def s_shopfront(ctx, f):
    v = V()
    facade(v, 0, f)
    ctx.vox(v)


@sprite("soi_dash", "road_tile", ppv=4, view=(0, 90), anchor=(0, 0, 0), pad=0,
        note="top-down asphalt, tiles seamlessly (32 x 32 voxels); map onto the road polygon")
def s_road(ctx, f):
    v = V()
    rnd = random.Random(7)
    for x in range(32):
        for y in range(32):
            r = rnd.random()
            v.set(x, y, 0, "MGAsphaltLite" if r < 0.12 else ("FloorDeep" if r < 0.2 else "MGAsphalt"))
    ctx.vox(v)


@sprite("soi_dash", "lane_dash", ppv=4, view=(0, 90), anchor=(0, 0, 0), pad=0,
        note="painted lane dash, top-down")
def s_dash(ctx, f):
    v = V()
    v.box(0, 0, 0, 1, 11, 0, "MGPaint")
    ctx.vox(v)


def front_door(v, open_):
    """The Black Cabin street front: dark brick, the red door, the BLACK CABIN neon above it."""
    for x in range(-22, 23):
        for z in range(0, 50):
            v.set(x, 2, z, "BeamBlack" if (x + (z // 2) * 3) % 6 else "CabinDark")
    v.box(-8, 1, 0, 7, 1, 23, "StoolBlack")                             # frame
    if open_:
        v.box(-7, 1, 0, 6, 1, 22, E("CubbyGlow"))
        v.box(-7, 1, 14, 6, 1, 22, E("ShelfAmber"))
    else:
        v.box(-7, 0, 0, -1, 0, 22, "DoorRed")
        v.box(0, 0, 0, 6, 0, 22, "DoorRed")
        v.box(-2, -1, 10, -2, -1, 12, "CymbalGold")
        v.box(1, -1, 10, 1, -1, 12, "CymbalGold")
    v.box(-10, 0, 23, 9, 0, 24, "StoneDark")
    sign = V()
    K.neon_sign(sign)
    for (x, y, z), m in sign.cells.items():
        v.set(x - 14, y - 1, z + 28, m)
    v.box(-9, -1, 24, -9, -1, 24, E("LampGold"))                        # door lamps
    v.box(8, -1, 24, 8, -1, 24, E("LampGold"))


@sprite("soi_dash", "door_front", frames=2, ppv=5, view=(0, 0), glow=True, anchor=(0, 0, 0),
        frame_names=["closed", "open"], note="Black Cabin at the end of the soi; open when the runner arrives; anchor = ground centre")
def s_door_front(ctx, f):
    v = V()
    front_door(v, f == 1)
    ctx.vox(v)


def soi_scene(ctx):
    """The night soi in voxels for the backdrop: road, shophouses both sides, wires, the front at the end."""
    road = V()
    for x in range(-24, 24):
        for y in range(-40, 400):
            road.set(x, y, -1, "MGAsphalt" if (x * 7 + y * 3) % 11 else "MGAsphaltLite")
    for y in range(-40, 400, 16):
        road.box(-1, y, -1, 0, y + 7, -1, "MGPaint")
    ctx.vox(road)
    for i in range(12):
        yy = i * 32 - 20
        for side in (-1, 1):
            v = V()
            facade(v, 0, i * 2 + (side > 0))
            ctx.vox(v, pivot=(15, 0, 0), loc=(side * 26 - 15, yy, 0), rot=(0, 0, -90 * side))
    end = V()
    front_door(end, False)
    ctx.vox(end, loc=(0, 380, 0))
    wires = V()
    for y in range(10, 380, 40):
        wires.line((-25, y, 46), (25, y + 6, 44), "StoolBlack")
        wires.line((-25, y + 3, 42), (25, y + 1, 47), "StoolBlack")
    ctx.vox(wires)


@sprite("soi_dash", "backdrop", ppv=1, opaque=True, size=(270, 480),
        persp=dict(loc=(0, -60, 22), look=(0, 300, 18), lens=24),
        note="night soi far layer (blurred); draw behind the road, scroll slowly")
def s_soi_bg(ctx, f):
    soi_scene(ctx)


# ================================================================== SHAKE & SERVE

def bottle_shape(v, body, h, w, neck_h, cap, label=None, label_m="LabelCream", square=False, shoulder=2):
    """A bottle centred on x = 0, y = 0: body w wide, h tall, a neck, a cap; optional label band."""
    r = w // 2
    for z in range(0, h):
        if square:
            v.box(-r, -r, z, r - (1 - w % 2), r - (1 - w % 2), z, body)
        else:
            for (u, ww) in v.disc_cells(0, 0, w):
                v.set(u, ww, z, body)
    for s in range(shoulder):                                           # shoulder steps
        d = max(2, w - 2 * (s + 1))
        for (u, ww) in v.disc_cells(0, 0, d):
            v.set(u, ww, h + s, body)
    v.box(-1, -1, h + shoulder, 0, 0, h + shoulder + neck_h - 1, body)
    v.box(-1, -1, h + shoulder + neck_h, 0, 0, h + shoulder + neck_h + 1, cap)
    if label:
        z0, z1 = label
        front = {}
        for (x, y, z) in v.cells:
            front[z] = min(front.get(z, y), y)
        for (x, y, z) in list(v.cells):
            if z0 <= z <= z1 and y == front[z]:
                v.set(x, y - 1, z, label_m)


BOTTLES = {   # shelf id: builder
    "gin": lambda v: bottle_shape(v, "MGGin", 10, 6, 3, "MGLabelRed", (3, 7), "LabelCream", square=True),
    "vodka": lambda v: bottle_shape(v, "BottleClear", 12, 5, 4, "MGSteel", (4, 8), "PaperWhite"),
    "rum": lambda v: bottle_shape(v, "BottleAmber", 8, 7, 3, "MGLabelBlack", (2, 6), "MGLabelGold"),
    "tequila": lambda v: bottle_shape(v, "MGTequila", 9, 7, 2, "WoodMid", (2, 6), "MGLabelBlack", shoulder=1),
    "whisky": lambda v: bottle_shape(v, "MGWhisky", 9, 6, 3, "MGLabelBlack", (2, 6), "MGLabelBlack", square=True),
    "sugar": lambda v: bottle_shape(v, "MGSyrup", 8, 5, 4, "MGSteel", (3, 5), "MGLabelGold"),
    "soda": lambda v: bottle_shape(v, "MGGlass", 8, 4, 3, "MGSodaCap", (3, 5), "MGSodaCap"),
    "tonic": lambda v: bottle_shape(v, "MGTonic", 8, 4, 3, "MGLabelGold", (3, 5), "MGLabelGold"),
    "ginger": lambda v: bottle_shape(v, "MGGinger", 8, 5, 2, "LabelCream", (2, 6), "LabelCream", shoulder=1),
    "bitters": lambda v: bottle_shape(v, "BottleAmber", 6, 4, 2, "MGTukYellow", (1, 5), "LabelCream", shoulder=1),
    "cola": lambda v: bottle_shape(v, "MGCola", 9, 4, 4, "MGLabelRed", None),
}


def limes(v):
    v.box(-4, -3, 0, 3, 2, 1, "StoneDark")                              # small dish
    for (cx, cy, cz) in ((-2, -1, 2), (1, -1, 2), (-1, 1, 3)):
        v.box(cx - 1, cy - 1, cz, cx + 1, cy + 1, cz + 2, "MGLime")
        v.set(cx - 1, cy - 1, cz + 2, "MGLimeDark")
    v.box(1, -3, 2, 3, -3, 4, "MGLimePulp")                             # a cut wedge, pulp to the front
    v.box(1, -2, 2, 3, -2, 4, "MGLime")


@sprite("shake_serve", "bottles", frames=12, ppv=7, view=(-15, 12), anchor=(0, 0, 0),
        frame_names=["gin", "vodka", "rum", "tequila", "whisky", "lime", "sugar", "soda", "tonic", "ginger",
                     "bitters", "cola"],
        note="one frame per shelf id (SPIRITS then MIXERS order); anchor = bottom centre; lift it on a tap")
def s_bottles(ctx, f):
    sid = ["gin", "vodka", "rum", "tequila", "whisky", "lime", "sugar", "soda", "tonic", "ginger", "bitters", "cola"][f]
    v = V()
    if sid == "lime":
        limes(v)
    else:
        BOTTLES[sid](v)
    ctx.vox(v)


def shaker():
    """Cobbler shaker: steel tin, darker shoulder ring, strainer cone, cap; a highlight stripe down the front."""
    v = V()
    for z in range(0, 12):
        for (u, w) in v.disc_cells(0, 0, 8):
            v.set(u, w, z, "MGSteel")
    for (u, w) in v.disc_cells(0, 0, 9):
        v.set(u, w, 12, "MirrorDark")
    for z, d in ((13, 7), (14, 7), (15, 5), (16, 5)):
        for (u, w) in v.disc_cells(0, 0, d):
            v.set(u, w, z, "MirrorLight")
    for (u, w) in v.disc_cells(0, 0, 3):
        v.set(u, w, 17, "MGSteel")
        v.set(u, w, 18, "MGSteel")
    front = {}
    for (x, y, z) in v.cells:
        if z < 12:
            front[x] = min(front.get(x, y), y)
    for z in range(1, 11):
        v.set(-2, front[-2], z, "MirrorLight")
        v.set(-1, front[-1], z, "PaperWhite")
    return v


@sprite("shake_serve", "shaker", frames=4, ppv=12, view=(-15, 10), anchor=(0, 0, 0),
        note="shake cycle (tilt -18, -6, +6, +18 degrees): ping-pong 0-1-2-3-2-1 on the nods; anchor = bottom centre")
def s_shaker(ctx, f):
    ctx.vox(shaker(), pivot=(0, 0, 8), loc=(0, 0, 0), rot=(0, (-18, -6, 6, 18)[f], 0))


def glass(v, kind, full):
    if kind == "highball":
        d, h = 6, 14
        for z in range(0, h):
            for (u, w) in v.disc_cells(0, 0, d):
                inner = math.hypot(u + 0.5, w + 0.5) < d / 2 - 1.2
                if z == 0 or not inner:
                    v.set(u, w, z, "MGDrink" if full and 0 < z < h - 5 else "MGGlass")
                elif full and z < h - 2:
                    v.set(u, w, z, "MGDrink" if z < h - 5 or (u + w) % 3 else "MGIce")
        if full:
            v.box(1, -3, h - 3, 2, -3, h + 1, "MGLime")                 # lime wheel on the rim
    elif kind == "rocks":
        d, h = 8, 7
        for z in range(0, h):
            for (u, w) in v.disc_cells(0, 0, d):
                inner = math.hypot(u + 0.5, w + 0.5) < d / 2 - 1.2
                if z <= 1 or not inner:
                    wall = "MGGlass"
                    if full and 1 < z < 4:
                        wall = "MGWhisky"
                    elif full and z < h - 1 and (u + z) % 3 == 0:
                        wall = "MGIce"
                    v.set(u, w, z, wall)
                elif full and z < h - 1:
                    v.set(u, w, z, "MGWhisky" if z < 4 else "MGIce")
    else:                                                               # coupe
        for (u, w) in v.disc_cells(0, 0, 6):
            v.set(u, w, 0, "MGGlass")
        v.box(0, 0, 1, 0, 0, 6, "MGGlass")
        for z, d in ((7, 4), (8, 8), (9, 10), (10, 10)):
            for (u, w) in v.disc_cells(0.5, 0.5, d):
                inner = math.hypot(u, w) < d / 2 - 1.2
                if z == 7 or not inner:
                    v.set(u, w, z, "MGTequila" if full and z in (8, 9) else "MGGlass")
                elif full:
                    v.set(u, w, z, "MGTequila")


for _gk in ("highball", "rocks", "coupe"):
    def _mkg(kind):
        @sprite("shake_serve", "glass_" + kind, frames=2, ppv=8, view=(-15, 14), anchor=(0, 0, 0),
                frame_names=["empty", "full"], note="serve glass; slides across the bar top; anchor = bottom centre")
        def s_glass(ctx, f):
            v = V()
            glass(v, kind, f == 1)
            ctx.vox(v)
        return s_glass
    _mkg(_gk)


@sprite("shake_serve", "nam", frames=2, ppv=8, view=(-15, 8), anchor=(0, 0, 0), frame_names=["up", "nod"],
        note="Nam's head; frame 1 on each nod; anchor = neck")
def s_nam(ctx, f):
    spec = preset("nam")
    D = B.dims(spec["body"])
    for p in head_parts(spec):
        ctx.part(p, pivot=(0, 0, D["h"]), rot=(16 if f else 0, 0, 0))
    ctx.anchor_z = D["h"]


@sprite("shake_serve", "bar_top", ppv=10, view=(0, 18), anchor=(0, -5, 4),
        note="the bar top the glass slides on (dark stone, bar front, gold rail); anchor = front top edge centre")
def s_bar_top(ctx, f):
    v = V()
    v.box(-36, -4, 0, 35, 4, 3, "ChairWood")
    v.box(-36, -5, 4, 35, 5, 5, "MirrorGrey")
    v.box(-36, -6, 5, 35, -6, 5, "PrintGrey")
    v.box(-36, -6, 1, 35, -6, 1, "CymbalGold")
    for x in range(-34, 35, 6):
        v.box(x, -5, 0, x, -5, 3, "ChairWoodDark")
    ctx.vox(v)


# ================================================================== POUR PERFECT

PINT_W, PINT_H = 26, 56


def pint(v, part):
    """A ribbed pint glass, 26 wide, 56 tall, made in two layers around the fill the game draws:
    'back' = the back wall and base, 'front' = side walls, rim, base front, ribs and a highlight."""
    R = PINT_W // 2
    for z in range(0, PINT_H):
        rz = R - (1 if z < 8 else 0)
        if part == "back":
            v.box(-rz, 3, z, rz - 1, 3, z, "MirrorGrey" if z % 9 != 4 else "MirrorLight")
        else:
            v.box(-rz, -3, z, -rz, 3, z, "MGGlass")
            v.box(rz - 1, -3, z, rz - 1, 3, z, "MGGlass")
            if z < 3:
                v.box(-rz, -3, z, rz - 1, 3, z, "MGGlass")
            if z in (PINT_H - 1,):
                v.box(-rz, -3, z, rz - 1, -3, z, "MGGlass")
            if z % 9 == 4 and z > 6:
                v.box(-rz + 1, -4, z, -rz + 2, -4, z, "MirrorLight")
                v.box(rz - 3, -4, z, rz - 2, -4, z, "MirrorLight")
            if 10 <= z <= PINT_H - 8:
                v.set(-rz + 3, -4, z, "MGIce")                          # highlight streak


@sprite("pour_perfect", "pint", frames=2, ppv=12, view=(0, 4), anchor=(0, 0, 0),
        frame_names=["back", "front"], alpha=[0.28, 1.0],
        points={"inner_bottom_left": (-11, -3, 3), "inner_top_right": (11, -3, PINT_H - 1)},
        note="frame 0 (back wall) first, then the fill inside the inner box, then frame 1 (walls, rim, ribs) over it; "
        "anchor = bottom centre")
def s_pint(ctx, f):
    v = V()
    pint(v, ("back", "front")[f])
    ctx.vox(v)


@sprite("pour_perfect", "tap", ppv=10, view=(-12, 8), anchor=(0, 0, 0), points={"spout": (8, -3, 13)},
        note="beer tap over the glass; anchor = bottom centre of the tower; point spout = where the stream starts")
def s_tap(ctx, f):
    v = V()
    v.box(-3, -2, 0, 2, 2, 22, "MGChrome")                              # tower
    v.box(-4, -3, 22, 3, 3, 23, "MGChrome")
    v.box(2, -2, 15, 8, 1, 16, "MGChrome")                              # arm
    v.box(7, -2, 12, 8, 1, 14, "MGChrome")                              # spout
    v.box(-1, -3, 17, 0, -3, 30, "PanelRed")                            # Black Cabin red handle
    v.box(-2, -4, 26, 1, -4, 30, "StoolBlack")
    v.box(-1, -5, 27, 0, -5, 29, "CymbalGold")
    v.box(-5, -4, -1, 4, 4, -1, "StoneDark")                            # drip tray foot
    ctx.vox(v)


@sprite("pour_perfect", "stream", ppv=8, view=(0, 0), anchor=(0, 0, 0), pad=0,
        note="white pour stream, tile vertically and tint (modulate) with the layer colour")
def s_stream(ctx, f):
    v = V()
    rnd = random.Random(3)
    for z in range(16):
        v.box(0, 0, z, 1, 0, z, "Foam")
        if rnd.random() < 0.3:
            v.set(2 if z % 2 else -1, 0, z, "MGIce")
    ctx.vox(v)


@sprite("pour_perfect", "foam", frames=3, ppv=8, view=(0, 20), anchor=(0, 0, 0),
        note="foam head blobs (white, tint if needed); anchor = blob bottom centre; frames are three shapes")
def s_foam(ctx, f):
    v = V()
    rnd = random.Random(40 + f)
    v.blob((0, 0, 3), (6 + f * 2, 4, 3.2), lambda c, t: "Foam" if t > 0.3 or rnd.random() < 0.7 else "MGIce", 1.2, rnd, keep=False)
    ctx.vox(v)


# ================================================================== FRONT ROW RHYTHM

def hand(v, x0, mirror):
    """A hand, palm facing the other hand: 3 thick (x), 6 deep (y), 9 tall (z)."""
    s = -1 if mirror else 1
    for z in range(0, 6):
        v.box(x0, -2, z, x0 + s * 2, 3, z, "MGSkin")
    for i, y in enumerate((-2, 0, 2)):                                  # fingers
        top = 9 if i == 1 else 8
        v.box(x0, y, 6, x0 + s * 1, y + 1, top, "MGSkin")
    v.box(x0 + s * 2, -3, 2, x0 + s * 3, -3, 4, "MGSkinShade")          # thumb
    v.box(x0 + s * 2, -2, -3, x0, 3, -1, "VelvetRed")                   # sleeve cuff


@sprite("front_row_rhythm", "clap", frames=3, ppv=10, view=(-40, 12), anchor=(0, 0, 0),
        frame_names=["open", "closing", "clap"], note="tap = play 0-1-2 fast; anchor = between the palms")
def s_clap(ctx, f):
    v = V()
    gap = (7, 3, 0)[f]
    hand(v, -gap - 3, False)
    hand(v, gap + 2, True)
    ctx.vox(v, pivot=(0, 0, 0))
    if f == 2:
        sp = V()
        for (x, z) in ((-4, 11), (3, 11), (-6, 8), (5, 8), (0, 12)):
            sp.set(x, -3, z, E("LampGold"))
        ctx.vox(sp, loc=(0, 0, 0))


@sprite("front_row_rhythm", "puck", frames=3, ppv=8, view=(0, 55), glow=True, anchor=(0, 0, 0),
        frame_names=["incoming", "perfect", "missed"], note="beat puck scrolling down a lane; anchor = centre")
def s_puck(ctx, f):
    v = V()
    rim = ("MGPuckRim", E("LampGold"), "MGPuckDim")[f]
    for (u, w) in v.disc_cells(0, 0, 14):
        r = math.hypot(u + 0.5, w + 0.5)
        v.set(u, w, 0, "StoolBlack")
        v.set(u, w, 1, rim if r > 4.6 else ("PanelRed" if f != 2 else "MGPuckDim"))
        if r > 5.6:
            v.set(u, w, 2, rim)
    ctx.vox(v, pivot=(0, 0, 1))


@sprite("front_row_rhythm", "target", frames=2, ppv=8, view=(0, 55), glow=True, anchor=(0, 0, 0),
        frame_names=["lit", "dim"], note="hit pad on the hit line, one per lane; anchor = centre")
def s_target(ctx, f):
    v = V()
    m = E("LampGold") if f == 0 else "LampGoldOff"
    for (u, w) in v.disc_cells(0, 0, 19):
        r = math.hypot(u + 0.5, w + 0.5)
        if r >= 8.0:
            v.set(u, w, 0, m)
        elif r < 7:
            v.set(u, w, -1, "CabinDark")
    ctx.vox(v)


for _bid, _fn in (("jo", "a_sing"), ("pete", "a_play_bass")):
    def _mkb(bid, fn):
        @sprite("front_row_rhythm", "band_" + bid, frames=2, ppv=5, view=(-10, 6), anchor=(0, 0, 0),
                note="band member on the stage strip, frame 1 on the beat; anchor = feet centre")
        def s_band(ctx, f):
            pf = getattr(B, fn)
            ctx.rig(preset(bid), lambda D: pf(0.0 if f == 0 else 0.125, D))
        return s_band
    _mkb(_bid, _fn)


# ================================================================== CANDLE TALK

@sprite("candle_talk", "candle", ppv=10, view=(-12, 14), anchor=(0, 0, 0), points={"wick_top": (0, 0, 17)},
        note="pillar candle; draw 'flame' at point wick_top; anchor = bottom centre")
def s_candle(ctx, f):
    v = V()
    for z in range(0, 15):
        for (u, w) in v.disc_cells(0, 0, 8):
            v.set(u, w, z, "MGWax")
    for (u, w) in v.disc_cells(0, 0, 8):
        v.set(u, w, 14, "LabelCream")
    for (u, w) in v.disc_cells(0, 0, 4):
        v.remove(u, w, 14)
    v.box(-4, -4, 10, -4, -4, 13, "MGWax")                              # wax drips
    v.box(3, -4, 8, 3, -4, 13, "MGWax")
    v.box(-1, -1, 14, 0, 0, 16, "MGChar")                               # wick
    v.box(-6, -6, -1, 5, 5, -1, "CymbalGold")                           # gold dish
    ctx.vox(v)


@sprite("candle_talk", "flame", frames=6, ppv=10, view=(-12, 14), glow=True, anchor=(0, 0, 0),
        frame_names=["full0", "full1", "full2", "full3", "gutter0", "gutter1"],
        note="flame: 0-3 flicker loop (8 fps), 4-5 guttering (a miss); scale by the candle light; anchor = wick top")
def s_flame(ctx, f):
    v = V()
    rnd = random.Random(90 + f)
    tall = 9 if f < 4 else 4
    for z in range(tall):
        w = [2, 3, 3, 3, 2, 2, 1, 1, 1][min(z, 8)] if f < 4 else [2, 2, 1, 1][z]
        sway = int(round(math.sin(f * 1.7 + z * 0.5) * (z / 4.0))) if f < 4 else 0
        for x in range(-w, w):
            for y in range(-1, 1):
                core = abs(x + 0.5) < w - 1 and z < tall - 2
                v.set(x + sway, y, z, E("MGFlameCore") if core else E("MGFlame"))
    if f < 4 and rnd.random() < 0.6:
        v.set(rnd.choice((-1, 0)), 0, tall, E("MGFlame"))
    ctx.vox(v)


for _rid in REGULARS:
    def _mkr(rid):
        @sprite("candle_talk", "regular_" + rid, frames=2, ppv=14, view=(-12, 6), anchor=(0, 0, 0),
                frame_names=["listen", "smile"],
                note="the regular across the candle, chest up; load only this one; smile on the best card; anchor = chest cut centre")
        def s_bust(ctx, f):
            spec = preset(rid)
            if f == 1:
                spec = with_face(spec, **CHEER)
            D = B.dims(spec["body"])
            zcut = D["h"] - D["chest"]
            for p in head_parts(spec, zmin=zcut):
                ctx.part(p, pivot=(0, 0, zcut))
            ctx.anchor_z = zcut
        return s_bust
    _mkr(_rid)


@sprite("candle_talk", "card", frames=2, ppv=10, view=(0, 12), anchor=(0, 0, 0),
        frame_names=["normal", "picked"], note="topic card blank (text drawn by the game); picked = gold edge; anchor = centre")
def s_card(ctx, f):
    v = V()
    edge = E("LampGold") if f else "MGLabelRed"
    v.box(-10, 0, -6, 9, 0, 5, "PaperWhite")
    for x in range(-10, 10):
        v.set(x, -1, -6, edge)
        v.set(x, -1, 5, edge)
    for z in range(-6, 6):
        v.set(-10, -1, z, edge)
        v.set(9, -1, z, edge)
    v.box(-9, 1, -5, 8, 1, 4, "MGCardboard")
    ctx.vox(v)


# ================================================================== NEON PINBALL

@sprite("neon_pinball", "bumper", frames=2, ppv=8, view=(0, 70), glow=True, anchor=(0, 0, 0),
        frame_names=["idle", "hit"], note="pop bumper, radius 38 field units = 6 voxels; flash frame 1 for bumper_flash; anchor = centre")
def s_bumper(ctx, f):
    v = V()
    ring = E("MGBumperHot") if f else E("MGBumper")
    for (u, w) in v.disc_cells(0, 0, 12):
        r = math.hypot(u + 0.5, w + 0.5)
        v.set(u, w, 0, "StoolBlack")
        v.set(u, w, 1, ring if r > 4.2 else "ColumnWhite")
        if r <= 4.2:
            v.set(u, w, 2, "PanelRed" if not f else E("NeonRed"))
    for (u, w) in v.disc_cells(0, 0, 4):
        v.set(u, w, 3, "ColumnWhite")
    ctx.vox(v, pivot=(0, 0, 1))


@sprite("neon_pinball", "flipper", ppv=8, view=(0, 90), anchor=(0, 0, 0),
        note="left flipper at rest pointing right (+x); anchor = pivot; rotate by the flipper angle; mirror for the right")
def s_flipper(ctx, f):
    v = V()
    for (u, w) in v.disc_cells(0, 0, 5):
        v.box(u, w, 0, u, w, 1, "MGRubber")
    for x in range(0, 15):
        half = 2 if x < 6 else 1
        for y in range(-half, half):
            v.box(x, y, 0, x, y, 1, "MGRubber" if y in (-half, half - 1) else "ColumnWhite")
    v.box(-1, -1, 2, 0, 0, 2, "MGChrome")
    ctx.vox(v)


@sprite("neon_pinball", "ball", ppv=4, view=(0, 60), anchor=(0, 0, 0),
        note="steel ball, BALL_R 13 field units; anchor = centre")
def s_ball(ctx, f):
    v = V()
    v.sphere((0, 0, 0), 8, "MGBall", shell=False)
    v.set(-2, -3, 2, "MGIce")
    v.set(-1, -3, 2, "MGIce")
    ctx.vox(v)


for _ch in "BLACKIN":
    def _mkl(ch):
        @sprite("neon_pinball", "letter_" + ch, frames=2, ppv=5, view=(0, 0), glow=True, anchor=(2.5, 0, 3.5),
                frame_names=["off", "lit"], note="BLACK CABIN rollover letter; anchor = centre")
        def s_letter(ctx, f):
            v = V()
            m = E("NeonRed") if f else "MGInsertRed"
            for (c, r) in font_cells(ch):
                v.set(c, -1, r, m)
            v.box(-1, 0, -1, 5, 0, 7, "StoolBlack")
            ctx.vox(v)
        return s_letter
    _mkl(_ch)


@sprite("neon_pinball", "playfield", ppv=3, view=(0, 90), opaque=True, anchor=(0, 0, 0), pad=0,
        note="playfield art, field 600 x 1000 units (5 per voxel); draw under the walls; launch lane at the right")
def s_playfield(ctx, f):
    v = V()

    def cell(fx, fy):                                                   # field (x right, y down) -> voxel
        return int(fx // 5), int((1000 - fy) // 5)
    for x in range(120):
        for y in range(200):
            m = "MGPfDark"
            if x >= 108:
                m = "StoneDark"
            v.set(x, y, 0, m)
    for (bx, by, br) in ((170, 340, 38), (370, 340, 38), (270, 470, 38)):   # inserts under the bumpers
        cx, cy = cell(bx, by)
        for (u, w) in v.disc_cells(cx + 0.5, cy + 0.5, int(br * 2 / 5) + 6):
            ring = math.hypot(u - cx, w - cy) >= br / 5 + 1
            v.set(u, w, 0, "ScreenCyan" if ring else "MGInsertBlue")
    for i in range(10):                                                 # letter inserts in an arc
        a = math.radians(200 + i * 14)
        cx, cy = cell(270 + math.cos(a) * 200, 300 + math.sin(a) * 200 * 0.8)
        v.box(cx - 1, cy - 1, 0, cx + 1, cy + 1, 0, "MGInsertRed")
    for k in range(3):                                                  # arrows toward the flippers
        for side in (-1, 1):
            cx, cy = cell(270 + side * 150, 700 + k * 40)
            for d in range(4):
                v.set(cx - side * d, cy + d, 0, "CymbalGold")
                v.set(cx - side * d, cy - d, 0, "CymbalGold")
    # big faint BC monogram
    for ci, ch in enumerate("BC"):
        for (c, r) in font_cells(ch):
            for dx in range(3):
                for dy in range(3):
                    v.set(36 + ci * 21 + c * 3 + dx, 56 + r * 3 + dy, 0, "MGInsertRed")
    for y in range(10, 190, 6):                                         # launch lane chevrons
        v.box(112, y, 0, 116, y, 0, "MGInsertRed")
    ctx.vox(v)


# ================================================================== backdrops from the venue

# Cameras in blender/BlackCabin.blend's own coordinates (Blender metres), aimed at named venue objects: that file is
# bc_review.py's last run, which can lag game/assets/kit/layout.json (on 2026-11-18 it still had the older room, the
# bar at x 12-24 and no Buffer tall tables). Rerun bc_review.py first to refresh the room, then this script.
VENUE_SHOTS = {
    "neon_moth": dict(target="venue.NeonSign", cam=(4.6, 0.0, -0.15), look=(0, 0, -0.05), lens=22,
                      note="the lounge toward the BLACK CABIN neon"),
    "coaster_flip": dict(target="venue.Table3Tealight", cam=(-6.5, 3.4, 1.0), look=(-1.0, 0.4, 0.2), lens=22,
                         note="the main-room tables"),
    "shake_serve": dict(target="venue.Bay4", cam=(0.0, 2.9, 1.95), look=(0, 0, 1.35), lens=22,
                        note="the backlit bar shelf over the counter"),
    "pour_perfect": dict(target="venue.Counter5", cam=(0.0, 1.5, 1.45), look=(0, -0.6, 1.1), lens=20,
                         note="the bar top close up"),
    "front_row_rhythm": dict(target="venue.DrumKit", cam=(0.0, -6.8, 0.9), look=(0, 0.2, 1.0), lens=24,
                             note="the stage from the front row"),
    "candle_talk": dict(target="venue.Table2Tealight", cam=(0.0, 0.95, 0.8), look=(0, -0.1, 0.0), lens=24,
                        note="a candle table close up"),
}


def render_venue_backdrops(games):
    if not os.path.exists(VENUE_BLEND):
        print("BC_MG no venue blend, backdrops skipped")
        return {}
    bpy.ops.wm.open_mainfile(filepath=VENUE_BLEND)
    scene = bpy.context.scene
    def walk(lc):
        yield lc
        for c in lc.children:
            yield from walk(c)
    for lc in walk(bpy.context.view_layer.layer_collection):
        if lc.name.startswith("VENUE ceiling"):
            lc.exclude = False                                          # eye-level shots want the room closed
        if lc.name in ("KIT", "CHARACTERS"):
            lc.exclude = True                                           # the review grids sit beside the room
    cam = bpy.data.objects.new("Cam_MG", bpy.data.cameras.new("Cam_MG"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    r = scene.render
    r.resolution_x, r.resolution_y, r.resolution_percentage = 360, 640, 100
    r.film_transparent = False
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGB"
    try:
        scene.eevee.taa_render_samples = 32
    except AttributeError:
        pass
    out = {}
    os.makedirs(os.path.join(RAW, "backdrops"), exist_ok=True)
    for game, shot in VENUE_SHOTS.items():
        if game not in games:
            continue
        tob = bpy.data.objects.get(shot["target"])
        if tob is None:
            print("BC_MG backdrop %s: no %s in the venue blend, skipped" % (game, shot["target"]))
            continue
        base = tob.matrix_world.translation
        c, t = base + Vector(shot["cam"]), base + Vector(shot["look"])
        cam.location = c
        cam.rotation_euler = (t - c).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = shot["lens"]
        cam.data.sensor_fit = "VERTICAL"
        cam.data.clip_start = 0.05
        path = os.path.join(RAW, "backdrops", game + ".png")
        r.filepath = path
        bpy.ops.render.render(write_still=True)
        out[game] = dict(path=path, note=shot["note"])
        print("BC_MG backdrop %s -> %s" % (game, path))
    return out


# ------------------------------------------------------------------ sprite rendering

def setup_scene():
    scene = bpy.context.scene
    r = scene.render
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            r.engine = engine
            break
        except TypeError:
            continue
    try:
        scene.eevee.taa_render_samples = 16
    except AttributeError:
        pass
    r.film_transparent = True
    r.filter_size = 0.75
    r.resolution_percentage = 100
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    r.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"                    # palette as authored; AgX turns neon orange
    world = bpy.data.worlds.new("MG world")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.035, 0.022, 0.02, 1)
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world
    rig = bpy.data.objects.new("MG_rig", None)
    scene.collection.objects.link(rig)
    cam = bpy.data.objects.new("MG_cam", bpy.data.cameras.new("MG_cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    lights = []
    for name, energy, col, rot in (("MG_key", 4.4, (1.0, 0.86, 0.68), (50, 0, -35)),
                                   ("MG_rim", 4.0, (1.0, 0.22, 0.12), (-60, 0, 35)),
                                   ("MG_fill", 0.7, (0.62, 0.72, 1.0), (60, 0, 50))):
        ld = bpy.data.lights.new(name, "SUN")
        ld.energy = energy
        ld.color = col
        ld.angle = math.radians(8)
        lo = bpy.data.objects.new(name, ld)
        lo.rotation_euler = [math.radians(a) for a in rot]
        lo.parent = rig
        scene.collection.objects.link(lo)
        lights.append(lo)
    return cam, rig, lights, world


def cam_space_bounds(objs, cam_inv):
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9, 1e9))
    hi = Vector((-1e9, -1e9))
    for ob in objs:
        if ob.type != "MESH":
            continue
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        M = cam_inv @ ev.matrix_world
        for vt in me.vertices:
            p = M @ vt.co
            lo.x, lo.y = min(lo.x, p.x), min(lo.y, p.y)
            hi.x, hi.y = max(hi.x, p.x), max(hi.y, p.y)
        ev.to_mesh_clear()
    return lo, hi


def aim(cam, rig, view):
    yaw, elev = view
    R = Euler((math.radians(90 - elev), 0, math.radians(yaw)), "XYZ")
    cam.rotation_euler = R
    cam.location = R.to_matrix() @ Vector((0, 0, 40))
    rig.rotation_euler = (0, 0, math.radians(yaw))
    bpy.context.view_layer.update()


def render_sprites(selected, render=True):
    scene = bpy.context.scene
    cam, rig, lights, world = setup_scene()
    review = bpy.data.collections.new("REVIEW")
    scene.collection.children.link(review)
    review_lc = bpy.context.view_layer.layer_collection.children["REVIEW"]
    review_lc.exclude = True
    work = bpy.data.collections.new("WORK")
    scene.collection.children.link(work)
    manifest = []
    for sp in selected:
        frames = []
        for f in range(sp["frames"]):
            coll = bpy.data.collections.new("%s.%s.%d" % (sp["game"], sp["name"], f))
            work.children.link(coll)
            ctx = Ctx(coll)
            ctx.anchor_z = None
            sp["fn"](ctx, f)
            frames.append((coll, ctx))
        anchor = Vector(sp["anchor"])
        if frames[0][1].anchor_z is not None:
            anchor.z = frames[0][1].anchor_z
        entry = dict(game=sp["game"], name=sp["name"], frames=sp["frames"], ppv=sp["ppv"], view=list(sp["view"]),
                     glow=sp["glow"], note=sp["note"], opaque=sp["opaque"], frame_names=sp["frame_names"],
                     alpha=sp["alpha"])
        if sp["persp"]:
            W, H = sp["size"]
            pr = sp["persp"]
            cam.data.type = "PERSP"
            cam.data.lens = pr["lens"]
            cam.data.sensor_fit = "VERTICAL"
            cam.data.shift_x = cam.data.shift_y = 0
            c, t = Vector(pr["loc"]) * VOX, Vector(pr["look"]) * VOX
            cam.location = c
            cam.rotation_euler = (t - c).to_track_quat("-Z", "Y").to_euler()
            rig.rotation_euler = (0, 0, 0)
            cam.data.clip_end = 200
            entry.update(w=W, h=H, anchor_px=[0, 0], points={})
        else:
            aim(cam, rig, sp["view"])
            cam.data.type = "ORTHO"
            cam.data.clip_start, cam.data.clip_end = 0.01, 100
            inv = cam.matrix_world.inverted()
            lo, hi = Vector((1e9, 1e9)), Vector((-1e9, -1e9))
            for coll, ctx in frames:
                a, b = cam_space_bounds(ctx.objs, inv)
                lo.x, lo.y, hi.x, hi.y = min(lo.x, a.x), min(lo.y, a.y), max(hi.x, b.x), max(hi.y, b.y)
            ppm = sp["ppv"] / VOX
            pad = sp["pad"]
            W = int(math.ceil((hi.x - lo.x) * ppm - 1e-3)) + 2 * pad
            H = int(math.ceil((hi.y - lo.y) * ppm - 1e-3)) + 2 * pad
            W += W % 2
            H += H % 2
            scale = max(W, H) / ppm
            cx, cy = (lo.x + hi.x) / 2, (lo.y + hi.y) / 2
            cam.data.ortho_scale = scale
            cam.data.sensor_fit = "HORIZONTAL" if W >= H else "VERTICAL"
            cam.data.shift_x, cam.data.shift_y = cx / scale, cy / scale
            left, top = cx - W / (2 * ppm), cy + H / (2 * ppm)

            def px(p_vox):
                q = inv @ (Vector(p_vox) * VOX)
                return [round((q.x - left) * ppm, 1), round((top - q.y) * ppm, 1)]
            entry.update(w=W, h=H, anchor_px=px(anchor), points={k: px(p) for k, p in sp["points"].items()})
            if os.environ.get("BC_MG_DEBUG"):
                print("BC_MG_DEBUG", sp["name"], tuple(lo), tuple(hi), W, H, scale, cx, cy, [o.name for c, x in frames for o in x.objs])
            if sp["game"] == "neon_moth" and sp["name"] == "speaker_cab":
                entry["stack_step_px"] = round(18 * sp["ppv"] * math.cos(math.radians(sp["view"][1])), 1)
        scene.render.resolution_x, scene.render.resolution_y = W, H
        scene.render.film_transparent = not sp["opaque"]
        scene.render.image_settings.color_mode = "RGB" if sp["opaque"] else "RGBA"
        d = os.path.join(RAW, sp["game"])
        os.makedirs(d, exist_ok=True)
        for m in bpy.data.materials:                                    # sprites: neon keeps its hue (no clipping)
            if m.node_tree and not m.get("mg_capped"):
                for n in m.node_tree.nodes:
                    if n.type == "BSDF_PRINCIPLED":
                        st = n.inputs["Emission Strength"]
                        st.default_value = min(st.default_value, EMIT_CAP)
                m["mg_capped"] = True
        if render:
            for f, (coll, ctx) in enumerate(frames):
                for g, (c2, _) in enumerate(frames):
                    c2.hide_render = g != f
                scene.render.filepath = os.path.join(d, "%s_%d.png" % (sp["name"], f))
                bpy.ops.render.render(write_still=True)
                if sp["glow"]:                                          # emission only: no lights, no world
                    for lo_ in lights:
                        lo_.hide_render = True
                    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.0
                    scene.render.filepath = os.path.join(d, "%s_%d_emit.png" % (sp["name"], f))
                    bpy.ops.render.render(write_still=True)
                    for lo_ in lights:
                        lo_.hide_render = False
                    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
        manifest.append(entry)
        print("BC_MG %-16s %-18s %d x %4d x %4d" % (sp["game"], sp["name"], sp["frames"], W, H))
        # keep frame 0 for the review scene, drop the rest
        keep, _ = frames[0]
        for coll, ctx in frames[1:]:
            for ob in list(coll.objects):
                bpy.data.objects.remove(ob, do_unlink=True)
            bpy.data.collections.remove(coll)
        work.children.unlink(keep)
        review.children.link(keep)
        keep.hide_render = True                                         # back on in build_review
    cam.data.type = "ORTHO"
    return manifest, review, work, cam, rig, lights


def label(coll, text, loc, size=0.12):
    cu = bpy.data.curves.new("lbl", "FONT")
    cu.body = text
    cu.size = size
    cu.align_x = "CENTER"
    ob = bpy.data.objects.new("label " + text, cu)
    ob.location = loc
    ob.rotation_euler = (math.radians(90), 0, 0)
    mat = bpy.data.materials.get("MG label") or bpy.data.materials.new("MG label")
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Emission Color"].default_value = (1.0, 0.85, 0.6, 1)
    bsdf.inputs["Emission Strength"].default_value = 1.5
    cu.materials.append(mat)
    coll.objects.link(ob)
    return ob


def build_review(review, work, cam, rig, lights, skip_backdrop=True):
    """Lay frame 0 of every sprite out on a grid, one row per game, one collection per game, with labels."""
    scene = bpy.context.scene
    bpy.context.view_layer.layer_collection.children["REVIEW"].exclude = False
    bpy.data.collections.remove(work)
    games = {}
    for coll in list(review.children):
        game = coll.name.split(".")[0]
        games.setdefault(game, []).append(coll)
    y_row = 0.0
    z_row = 0.0
    max_x = 1.0
    for gi, game in enumerate(GAMES):
        if game not in games:
            continue
        gcoll = bpy.data.collections.new(game)
        review.children.link(gcoll)
        x = 0.0
        row_h = 0.0
        for coll in games[game]:
            review.children.unlink(coll)
            gcoll.children.link(coll)
            name = coll.name.split(".")[1]
            coll.hide_render = False
            obs = [o for o in coll.objects if o.parent is None]
            if name == "backdrop" or name == "playfield":
                for o in list(coll.objects):
                    o.hide_viewport = True
                    o.hide_render = True
                coll.hide_viewport = True
                coll.hide_render = True
                continue
            lo = Vector((1e9, 1e9, 1e9))
            hi = Vector((-1e9, -1e9, -1e9))
            bpy.context.view_layer.update()
            for o in coll.objects:
                if o.type != "MESH":
                    continue
                for c in o.bound_box:
                    w = o.matrix_world @ Vector(c)
                    lo = Vector(map(min, lo, w))
                    hi = Vector(map(max, hi, w))
            if lo.x > hi.x:
                continue
            width = hi.x - lo.x
            shift = Vector((x - lo.x, -(lo.y + hi.y) / 2 + y_row, z_row - lo.z))
            for o in obs:
                o.location = o.location + shift
            label(gcoll, name, (x + width / 2, y_row - 0.6, z_row - 0.2))
            x += width + 0.35
            max_x = max(max_x, x)
            row_h = max(row_h, hi.z - lo.z)
        label(gcoll, game.upper().replace("_", " "), (-1.2, y_row - 0.6, z_row + 0.3), 0.22)
        z_row += row_h + 0.9
    # lights for the review scene (world-fixed), camera framing everything
    for lo_ in lights:
        lo_.parent = None
    cam.data.type = "ORTHO"
    cam.data.shift_x = cam.data.shift_y = 0
    cam.data.sensor_fit = "AUTO"
    cam.rotation_euler = (math.radians(90), 0, 0)
    cam.location = ((max_x - 1.8) / 2, -30, (z_row - 1.2) / 2)
    cam.data.ortho_scale = max(max_x + 3.0, (z_row + 1.0) * 1.6)
    scene.render.resolution_x, scene.render.resolution_y = 1600, 1000
    scene.render.film_transparent = False
    for scr in bpy.data.screens:                                        # Material Preview in the saved layout
        for area in scr.areas:
            if area.type == "VIEW_3D":
                for spc in area.spaces:
                    if spc.type == "VIEW_3D":
                        spc.shading.type = "MATERIAL"
                        spc.shading.use_scene_lights = True
                        spc.shading.use_scene_world = True


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    games = set(GAMES)
    if "--game" in argv:
        games = set(argv[argv.index("--game") + 1].split(","))
    render = "--no-render" not in argv
    if os.path.isdir(RAW) and games == set(GAMES) and render:
        shutil.rmtree(RAW)
    os.makedirs(RAW, exist_ok=True)
    backdrops = {}
    if render and "--no-backdrops" not in argv:
        backdrops = render_venue_backdrops(games)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    K._MATS.clear()
    selected = [s for s in SPRITES if s["game"] in games]
    names = [(s["game"], s["name"]) for s in SPRITES]
    assert len(names) == len(set(names)), "duplicate sprite names"
    manifest, review, work, cam, rig, lights = render_sprites(selected, render)
    mpath = os.path.join(RAW, "manifest.json")
    old = []
    if os.path.exists(mpath) and games != set(GAMES):
        with open(mpath, encoding="utf-8") as fh:
            old = json.load(fh)["sprites"]
        old = [e for e in old if e["game"] not in games]
    with open(mpath, "w", encoding="utf-8") as fh:
        json.dump({"sprites": old + manifest, "backdrops": backdrops, "voxel_m": VOX}, fh, indent=1)
    print("BC_MG manifest -> %s (%d sprites)" % (mpath, len(manifest)))
    if "--no-blend" not in argv:
        build_review(review, work, cam, rig, lights)
        os.makedirs(os.path.dirname(BLEND), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
        print("BC_MG review -> %s" % BLEND)


if __name__ == "__main__":
    main()
