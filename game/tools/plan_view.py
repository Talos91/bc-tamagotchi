"""Top-down plan of the venue: rooms, doors and labels from tools/plan_v4.py, furniture from
game/assets/kit/layout.json (written by tools/export_layout.gd) or, with --planned, from plan_v4.planned_objects().

    python game/tools/plan_view.py <out.png> [--planned]          (from the repo root)

North is up (-z), east is right (+x), 30 px per metre, 1 m grid. Every kit instance is drawn as its rotated
manifest footprint (placeholder sizes from plan_v4.PLACEHOLDERS for objects the kit lacks), coloured by kind;
seats and spawn points are dots. Keep plan_v4.py in step with tools/build_venue.gd when the layout changes.
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import plan_v4 as P  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
KIT = os.path.join(REPO, "game", "assets", "kit")
PPM = 30
X0, X1, Z0, Z1 = -1.5, 47.0, -5.0, 19.5           # sheet extent in metres

COLOURS = [  # (substring of the object name, fill)
    ("stage_carpet", (150, 20, 25)), ("stage_platform", (60, 30, 30)), ("curtain", (140, 10, 20)),
    ("backdrop", (210, 40, 30)), ("bar_counter", (110, 70, 40)), ("back_bar", (80, 50, 30)), ("cashier", (130, 90, 50)),
    ("bar_stool", (40, 30, 30)), ("tall_stool", (60, 50, 50)), ("tall_table", (130, 170, 220)), ("tiny_table", (170, 150, 40)),
    ("round_table", (170, 120, 80)), ("communal_table", (190, 140, 90)), ("smoke_table", (160, 110, 60)),
    ("cafe_chair", (120, 60, 40)), ("wishbone", (140, 90, 50)), ("drum_stool", (25, 25, 25)), ("stair", (90, 90, 100)),
    ("plant_wall", (60, 90, 40)), ("neon", (255, 60, 40)), ("white_column", (230, 225, 230)), ("couch", (110, 20, 30)),
    ("banquette", (140, 20, 30)), ("drum_kit", (200, 60, 50)), ("amp", (20, 20, 20)), ("tree", (90, 110, 60)),
    ("pinball", (40, 160, 200)), ("game_cabinet", (40, 120, 200)), ("fridge", (90, 90, 90)), ("purifier", (90, 90, 90)),
    ("door", (20, 20, 20)), ("par", (60, 60, 60)), ("speaker", (30, 30, 30)), ("mic", (50, 50, 50)), ("wedge", (40, 40, 40)),
]
ROOM_FILL = {"lobby": (226, 226, 234), "corridor": (226, 226, 234), "lounge": (232, 222, 214), "stub": (232, 222, 214),
             "buffer": (220, 160, 210), "main": (222, 222, 228), "raised": (246, 230, 170), "vestibule": (222, 222, 228),
             "smoking": (150, 40, 40), "main_se": None}


def px(x, z):
    return ((x - X0) * PPM, (z - Z0) * PPM)


def rect(d, r, fill, outline=(40, 30, 30), width=3):
    d.rectangle([px(r[0], r[1]), px(r[2], r[3])], fill=fill, outline=outline, width=width)


def footprint(d, obj, x, z, rot, w, dep, fill):
    a = math.radians(rot)
    pts = []
    for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        lx, lz = sx * w / 2, sz * dep / 2
        pts.append(px(x + lx * math.cos(a) + lz * math.sin(a), z - lx * math.sin(a) + lz * math.cos(a)))
    d.polygon(pts, fill=fill, outline=(30, 25, 25))


def main(out, planned):
    manifest = {o["name"]: o for o in json.load(open(os.path.join(KIT, "manifest.json")))["objects"]}
    img = Image.new("RGB", (int((X1 - X0) * PPM), int((Z1 - Z0) * PPM)), (245, 240, 232))
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arial.ttf", 13)
        big = ImageFont.truetype("arialbd.ttf", 20)
    except OSError:
        font = big = ImageFont.load_default()
    for x in range(int(X0), int(X1) + 1):                       # 1 m grid
        d.line([px(x, Z0), px(x, Z1)], fill=(225, 220, 212))
    for z in range(int(Z0), int(Z1) + 1):
        d.line([px(X0, z), px(X1, z)], fill=(225, 220, 212))
    for name, r in P.OUTSIDE.items():
        rect(d, r, (200, 205, 215), (120, 120, 130), 2)
    for name, r in P.CLOSED.items():
        rect(d, r, (110, 180, 100), (40, 80, 40), 3)
    for name, r in P.ROOMS.items():
        if ROOM_FILL.get(name):
            rect(d, r, ROOM_FILL[name], (40, 30, 30), 3)
    rect(d, P.BAR["back"], (235, 220, 40))
    rect(d, P.BAR["counter"], (110, 70, 40))
    rect(d, P.BAR["cashier"], (130, 90, 50))
    rect(d, P.STAGE, (225, 60, 50), (120, 20, 20), 2)
    rect(d, P.STAIRS["leg"], (95, 95, 100))
    rect(d, P.STAIRS["block"], (95, 95, 100))
    for name, (x0, z0, x1, z1, kind) in P.DOORS.items():
        col = {"open": (255, 255, 255), "door": (20, 20, 20), "curtain": (190, 20, 40), "window": (120, 190, 240),
               "exit": (20, 160, 90)}[kind]
        d.rectangle([px(x0, z0), px(x1, z1)], fill=col, outline=col, width=2)
    for i, (x, z) in enumerate(P.LOUNGE_COLUMNS):
        rect(d, (x - 0.2, z - 0.2, x + 0.2, z + 0.2), (255, 255, 255), (20, 20, 20), 2)
    if planned:
        items = [{"object": o, "position": [x, 0.0, z], "rotation_y": r, "scale": [1, 1, 1], "name": n}
                 for (o, x, z, r, n) in P.planned_objects()]
        spawns = []
    else:
        layout = json.load(open(os.path.join(KIT, "layout.json")))
        items, spawns = layout["kit"], layout["spawns"]
    for k in items:
        m = manifest.get(k["object"])
        if m:
            if m.get("anchor") == "ceiling" or k["position"][1] > 2.0:
                continue
            w, dep = m["footprint_m"][0] * k["scale"][0], m["footprint_m"][1] * k["scale"][2]
        elif k["object"] in P.PLACEHOLDERS:
            w, dep, _h = P.PLACEHOLDERS[k["object"]]
            w, dep = w * k["scale"][0], dep * k["scale"][2]
        else:
            continue
        if planned and k["object"] == "communal_table":           # the two rectangles are scaled communal tables
            w = {"RectTableW": 2.4, "RectTableE": 1.9}.get(k["name"], w)
        if planned and k["name"].startswith("Raised") and k["object"] == "round_table":
            w = dep = 0.72
        fill = next((c for key, c in COLOURS if key in k["object"]), (150, 150, 150))
        footprint(d, k["object"], k["position"][0], k["position"][2], k["rotation_y"], w, dep, fill)
    for s in spawns:
        x, z = s["position"][0], s["position"][2]
        col = {"sit": (30, 120, 220), "staff": (30, 120, 220), "spawn": (200, 30, 200)}.get(s["pose"], (20, 160, 60))
        d.ellipse([px(x - 0.08, z - 0.08), px(x + 0.08, z + 0.08)], fill=col)

    def label(text, x, z, f=font, col=(10, 10, 10)):
        bx = d.textbbox((0, 0), text, font=f)
        tx, tz = px(x, z)
        tx -= (bx[2] - bx[0]) / 2
        d.rectangle([tx - 3, tz - 2, tx + bx[2] - bx[0] + 3, tz + bx[3] - bx[1] + 4], fill=(255, 255, 255))
        d.text((tx, tz), text, font=f, fill=col)
    label("LOUNGE", 8.9, 6.3, big)
    label("MAIN ROOM", 30.0, 10.5, big)
    label("ENTRANCE (spawn)", 1.15, 9.3)
    label("entrance corridor", 7.0, 13.8)
    label("Sticker door", 13.65, 12.5, col=(180, 10, 20))
    label("stairs", 5.5, 12.2)
    label("pinball (west wall)", 4.2, 7.8)
    label("game cabinet", 9.4, 12.1)
    label("plant wall / neon / banquette", 5.6, 0.6)
    label("old corridor (unused)", 17.7, 11.3)
    label("BUFFER ZONE", 17.8, 5.4, col=(80, 10, 60))
    label("window wall, tree outside", 17.8, 2.4)
    label("mirror wall", 17.8, 7.3)
    label("old toilet", 17.7, 8.9)
    label("old toilet", 17.7, 13.6)
    label("kitchen (staff spawn)", 13.0, 16.8)
    label("STAGE (floor level, carpets)", 30.75, 2.3, col=(120, 10, 10))
    label("backstage (band spawn)", 25.9, -1.6)
    label("staff door", 25.9, 0.4)
    label("tiny tables, 2 stools", 30.8, 6.0)
    label("tree", 37.2, 1.6)
    label("Mali", 30.05, 9.2, col=(160, 100, 0))
    label("RAISED +15 cm, couch, shelves, mirror ceiling", 40.6, 11.3)
    label("neon under edge", 39.5, 5.6, col=(200, 20, 20))
    label("BAR (red back bar)", 28.8, 14.2)
    label("cashier + reindeer head", 29.65, 11.7)
    label("staff area", 37.0, 13.8)
    label("red door", 39.2, 12.2, col=(180, 10, 20))
    label("SMOKING ROOM", 40.05, 15.3, big)
    label("emergency exit", 40.0, 18.4)
    label("night street (glass)", 43.9, 15.3)
    label("toilets corridor", 22.3, 15.8)
    label("Toilet F", 26.6, 16.2)
    label("Toilet M", 22.2, 17.6)
    label("tall tables", 20.5, 10.3)
    label("night outside", 17.8, -2.5)
    W, H = img.size
    for t, (cx, cy) in (("N", (W / 2, 4)), ("S", (W / 2, H - 28)), ("W", (6, H / 2)), ("E", (W - 22, H / 2))):
        d.text((cx, cy), t, font=big, fill=(200, 20, 30))
    src = "planned furniture (tools/plan_v4.py)" if planned else "from game/assets/kit/layout.json"
    d.text((10, H - 24), "1 m grid; %s; blue dots = seats, green = wander, purple = NPC spawns" % src, font=font, fill=(60, 60, 60))
    img.save(out)
    print("plan ->", out, img.size)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    main(args[0] if args else os.path.join(REPO, "docs", "art", "screens", "plan", "plan-v4.png"), "--planned" in sys.argv)
