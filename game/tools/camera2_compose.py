"""Before / after pictures for camera feel 2 (tests/capture_camera2.gd run on 14cda24 with --prefix=before- and on
the pass itself).

    python game/tools/camera2_compose.py SHOTS_DIR      (from the repo root)

SHOTS_DIR holds before-<tag>-<shot>.png and <tag>-<shot>.png. Writes to docs/art/screens/camera-feel-2/:
  twoup-<tag>-<shot>.jpg   before left, after right, same height, caption strip (areas, occlusions)
  walk-strip.jpg           the walk across the main room, before row over after row (0.25 / 0.7 / 1.3 / 2.2 s, stopped)
  areas-sheet.jpg          every area after the pass, portrait, one sheet
The before-*.png inputs are not committed (the two-ups carry them).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(REPO, "docs", "art", "screens", "camera-feel-2")
AREAS = ["floor", "bar", "stage", "toilets", "smoking", "buffer", "lounge", "merch", "memory", "patrons", "alcove", "corridor", "lobby"]
OCCL = ["raised-tree", "toilets-backbar", "buffer-valance"]
H = {"portrait": 1100, "landscape": 640}
GAP = 16
CAP = 54


def fit(im, h):
    return im.resize((round(im.width * h / im.height), h), Image.LANCZOS)


def font(size):
    try:
        return ImageFont.truetype("arialbd.ttf", size)
    except OSError:
        return ImageFont.load_default()


def twoup(src, tag, shot, f):
    before = os.path.join(src, "before-%s-%s.png" % (tag, shot))
    after = os.path.join(src, "%s-%s.png" % (tag, shot))
    if not (os.path.exists(before) and os.path.exists(after)):
        return
    h = H[tag]
    a = fit(Image.open(before).convert("RGB"), h)
    b = fit(Image.open(after).convert("RGB"), h)
    out = Image.new("RGB", (a.width + GAP + b.width, h + CAP), (18, 14, 16))
    out.paste(a, (0, CAP))
    out.paste(b, (a.width + GAP, CAP))
    d = ImageDraw.Draw(out)
    d.text((14, 10), "BEFORE (14cda24)", fill=(200, 190, 190), font=f)
    d.text((a.width + GAP + 14, 10), "AFTER (camera feel 2)", fill=(255, 210, 120), font=f)
    path = os.path.join(OUT, "twoup-%s-%s.jpg" % (tag, shot))
    out.save(path, quality=88)
    print("saved", path, out.size)


def walk_strip(src, f):
    h = 700
    rows = []
    for pre, label in [("before-", "BEFORE"), ("", "AFTER")]:
        ims = [fit(Image.open(os.path.join(src, "%sportrait-walk-%d.png" % (pre, k))).convert("RGB"), h) for k in range(1, 6)]
        rows.append((label, ims))
    w = sum(im.width for im in rows[0][1]) + GAP * 4
    out = Image.new("RGB", (w, (h + CAP) * 2 + GAP), (18, 14, 16))
    d = ImageDraw.Draw(out)
    times = ["0.25 s", "0.7 s", "1.3 s", "2.2 s", "stopped"]
    for r, (label, ims) in enumerate(rows):
        y = r * (h + CAP + GAP)
        x = 0
        for k, im in enumerate(ims):
            out.paste(im, (x, y + CAP))
            d.text((x + 10, y + 12), "%s  %s" % (label, times[k]), fill=(255, 210, 120) if r else (200, 190, 190), font=f)
            x += im.width + GAP
    path = os.path.join(OUT, "walk-strip.jpg")
    out.save(path, quality=85)
    print("saved", path, out.size)


def areas_sheet(src, f):
    h = 640
    ims = [(a, fit(Image.open(os.path.join(src, "portrait-area-%s.png" % a)).convert("RGB"), h)) for a in AREAS]
    per = 7
    w = ims[0][1].width
    out = Image.new("RGB", (per * (w + GAP), 2 * (h + CAP)), (18, 14, 16))
    d = ImageDraw.Draw(out)
    for i, (a, im) in enumerate(ims):
        x, y = (i % per) * (w + GAP), (i // per) * (h + CAP)
        out.paste(im, (x, y + CAP))
        d.text((x + 10, y + 12), a, fill=(255, 210, 120), font=f)
    path = os.path.join(OUT, "areas-sheet.jpg")
    out.save(path, quality=85)
    print("saved", path, out.size)


def main(src):
    os.makedirs(OUT, exist_ok=True)
    f = font(30)
    for shot in ["area-" + a for a in AREAS] + ["occl-" + o for o in OCCL]:
        twoup(src, "portrait", shot, f)
    for a in ["floor", "bar", "stage", "lounge"]:
        twoup(src, "landscape", "area-" + a, f)
    walk_strip(src, f)
    areas_sheet(src, f)


if __name__ == "__main__":
    main(sys.argv[1])
