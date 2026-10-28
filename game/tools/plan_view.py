"""Top-down plan of the venue from game/assets/kit/layout.json (written by tools/export_layout.gd).

    python game/tools/plan_view.py <out.png>          (from the repo root)

North is up (-z), east is right (+x), 40 px per metre, 1 m grid. Every kit instance is drawn as its rotated
manifest footprint, coloured by kind; seats and spawn points are dots; the walls and labelled landmarks come
from the generator's constants (tools/build_venue.gd), so keep them in step when the layout changes.
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
KIT = os.path.join(REPO, "game", "assets", "kit")
PPM = 40
X0, X1, Z0, Z1 = -1.5, 29.5, -2.0, 15.5           # sheet extent in metres
MAIN_X1, MAIN_Z0, MAIN_Z1 = 28.0, -0.5, 14.0
STAGE = (16.6, -0.5, 24.6, 3.3)

COLOURS = [  # (substring of the object name, fill)
    ("stage_platform", (60, 30, 30)), ("stage_carpet", (150, 20, 25)), ("curtain", (140, 10, 20)),
    ("backdrop", (210, 40, 30)), ("bar_counter", (110, 70, 40)), ("back_bar", (80, 50, 30)),
    ("bar_stool", (40, 30, 30)), ("round_table", (170, 120, 80)), ("communal_table", (190, 140, 90)),
    ("cafe_chair", (120, 60, 40)), ("drum_stool", (25, 25, 25)), ("stair", (90, 90, 100)),
    ("plant_wall", (60, 90, 40)), ("neon", (255, 60, 40)), ("white_column", (230, 225, 230)),
    ("banquette", (140, 20, 30)), ("drum_kit", (200, 60, 50)), ("amp", (20, 20, 20)), ("stage_tree", (90, 110, 60)),
]


def px(x, z):
    return ((x - X0) * PPM, (z - Z0) * PPM)


def main(out):
    manifest = {o["name"]: o for o in json.load(open(os.path.join(KIT, "manifest.json")))["objects"]}
    layout = json.load(open(os.path.join(KIT, "layout.json")))
    img = Image.new("RGB", (int((X1 - X0) * PPM), int((Z1 - Z0) * PPM)), (245, 240, 232))
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arial.ttf", 15)
        big = ImageFont.truetype("arialbd.ttf", 22)
    except OSError:
        font = big = ImageFont.load_default()
    for x in range(int(X0), int(X1) + 1):                       # 1 m grid
        d.line([px(x, Z0), px(x, Z1)], fill=(225, 220, 212))
    for z in range(int(Z0), int(Z1) + 1):
        d.line([px(X0, z), px(X1, z)], fill=(225, 220, 212))
    # rooms
    d.rectangle([px(0, 0), px(10, 10)], fill=(232, 222, 214), outline=(40, 30, 30), width=4)
    d.rectangle([px(10, MAIN_Z0), px(MAIN_X1, MAIN_Z1)], fill=(222, 222, 228), outline=(40, 30, 30), width=4)
    d.line([px(10, 4.8), px(10, 7.2)], fill=(200, 20, 30), width=8)   # curtain opening
    d.rectangle([px(STAGE[0], STAGE[1]), px(STAGE[2], STAGE[3])], fill=(200, 120, 120))
    # kit footprints
    for k in layout["kit"]:
        m = manifest.get(k["object"])
        if not m or m.get("anchor") == "ceiling" or k["position"][1] > 2.0:
            continue
        w, dep = m["footprint_m"][0] * k["scale"][0], m["footprint_m"][1] * k["scale"][2]
        a = math.radians(k["rotation_y"])
        cx, cz = k["position"][0], k["position"][2]
        pts = []
        for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            lx, lz = sx * w / 2, sz * dep / 2
            pts.append(px(cx + lx * math.cos(a) + lz * math.sin(a), cz - lx * math.sin(a) + lz * math.cos(a)))
        fill = next((c for key, c in COLOURS if key in k["object"]), (150, 150, 150))
        d.polygon(pts, fill=fill, outline=(30, 25, 25))
    for s in layout["spawns"]:
        x, z = s["position"][0], s["position"][2]
        col = (30, 120, 220) if s["pose"] in ("sit", "staff") else (20, 160, 60)
        d.ellipse([px(x - 0.08, z - 0.08), px(x + 0.08, z + 0.08)], fill=col)
    # labels
    def label(text, x, z, f=font, col=(10, 10, 10)):
        bx = d.textbbox((0, 0), text, font=f)
        tx, tz = px(x, z)
        tx -= (bx[2] - bx[0]) / 2
        d.rectangle([tx - 4, tz - 2, tx + bx[2] - bx[0] + 4, tz + bx[3] - bx[1] + 6], fill=(255, 255, 255))
        d.text((tx, tz), text, font=f, fill=col)
    label("LOUNGE", 5.0, 8.2, big)
    label("MAIN ROOM", 13.5, 6.0, big)
    label("STAIRS (up, west wall)", 2.6, 3.4)
    label("NEON SIGN / PLANT WALL (north wall)", 4.2, -0.9)
    label("STREET DOOR? not modelled; implied by", 5.0, 10.4)
    label("render 02 viewpoint (south wall)", 5.0, 10.9)
    label("CURTAIN into main room", 10.0, 7.5, col=(180, 10, 20))
    label("STAGE (0.6 m)", 20.6, 1.5)
    label("BAR (back bar on south wall)", 18.2, 14.4)
    label("COMMUNAL TABLE", 14.4, 2.4)
    label("END-WALL TABLE LINE", 26.0, 7.6)
    label("BACKDROP (east wall)", 26.0, -1.4)
    label("arcade / shelf", 8.0, 2.6)
    # compass
    W, H = img.size
    for t, (cx, cy) in (("N", (W / 2, 4)), ("S", (W / 2, H - 30)), ("W", (6, H / 2)), ("E", (W - 24, H / 2))):
        d.text((cx, cy), t, font=big, fill=(200, 20, 30))
    d.text((10, H - 26), "1 m grid; blue dots = seats, green = wander points; from game/assets/kit/layout.json",
           font=font, fill=(60, 60, 60))
    img.save(out)
    print("plan ->", out, img.size)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "docs", "art", "screens", "parity", "plan.png"))
