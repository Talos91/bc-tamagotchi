"""Two-ups and strips for the look build (look D with a voxel cement floor; Daniele 2026-11-02).

    python game/tools/look_build_compose.py floor      (after capture_look_build.gd: proto run and the floor run)
    python game/tools/look_build_compose.py after      (after the before and after captures of the built venue)

Writes JPEG (quality 88) to docs/art/screens/look-build/:
  floor:  floor-proto-strip.jpg      floor view A | D | E | F | G (the prototype variants)
          floor-twoup-<view>.jpg     D as tested | D with the voxel cement (F, the one built)
  after:  twoup-<view>.jpg           before (54b96c3, main before the build) | after, for every A-<view>.png in before/
                                     and after/ (capture_look_build.gd --variants=A --out=.../before or .../after)
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIR = os.path.join(REPO, "docs", "art", "screens", "look-build")
FONT = os.path.join(REPO, "game", "assets", "fonts", "Lato-Bold.ttf")
GAP = 12
CAP = 56
BG = (14, 10, 10)
INK = (240, 228, 210)


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def tile(im, caption, f):
    out = Image.new("RGB", (im.width, im.height + CAP), BG)
    out.paste(im, (0, CAP))
    ImageDraw.Draw(out).text((14, 10), caption, font=f, fill=INK)
    return out


def row(paths_caps, height):
    f = font(34)
    tiles = []
    for p, cap in paths_caps:
        im = Image.open(p).convert("RGB")
        im = im.resize((round(im.width * height / im.height), height), Image.LANCZOS)
        tiles.append(tile(im, cap, f))
    w = sum(t.width for t in tiles) + GAP * (len(tiles) + 1)
    h = max(t.height for t in tiles) + GAP * 2
    out = Image.new("RGB", (w, h), BG)
    x = GAP
    for t in tiles:
        out.paste(t, (x, GAP))
        x += t.width + GAP
    return out


def save(im, name):
    path = os.path.join(DIR, name)
    im.save(path, quality=88)
    print("wrote", path, im.size)


def floor():
    proto = os.path.join(DIR, "floor-proto")
    caps = [("A", "A  today"), ("D", "D  as tested"), ("E", "E  voxel cement"), ("F", "F  + step shade (built)"),
            ("G", "G  0.2 m cells")]
    have = [(os.path.join(proto, k + "-floor.png"), c) for k, c in caps
            if os.path.exists(os.path.join(proto, k + "-floor.png"))]
    if have:
        save(row(have, 960), "floor-proto-strip.jpg")
    fdir = os.path.join(DIR, "floor")
    for v in ["floor", "bar", "lounge", "corridor"]:
        d, e = os.path.join(fdir, "D-%s.png" % v), os.path.join(fdir, "F-%s.png" % v)
        if os.path.exists(d) and os.path.exists(e):
            save(row([(d, "D as tested: smooth cement"), (e, "D, voxel cement")], 1280), "floor-twoup-%s.jpg" % v)


def after():
    bdir, adir = os.path.join(DIR, "before"), os.path.join(DIR, "after")
    for name in sorted(os.listdir(adir)):
        if not name.endswith(".png") or not os.path.exists(os.path.join(bdir, name)):
            continue
        v = name[:-4].removeprefix("A-")    # capture_look_build.gd names the as-built variant A
        h = 1280 if "landscape" not in v else 720
        save(row([(os.path.join(bdir, name), "before (main)"), (os.path.join(adir, name), "after: look D")], h),
             "twoup-%s.jpg" % v)


if __name__ == "__main__":
    {"floor": floor, "after": after}[sys.argv[1] if len(sys.argv) > 1 else "floor"]()
