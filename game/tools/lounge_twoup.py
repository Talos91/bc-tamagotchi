"""Before / after two-ups for the lounge revamp (tests/capture_lounge.gd run on db5e398 with --prefix=before- and on the
revamp itself).

    python game/tools/lounge_twoup.py [tag]          (from the repo root; tag = portrait | landscape, default portrait)

Writes docs/art/screens/lounge-revamp/twoup-<tag>-<shot>.jpg (quality 90): before left, after right, both scaled to the
same height, with a caption strip. Shots without a before picture are skipped. The before-*.png inputs are not
committed (the two-ups carry them).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIR = os.path.join(REPO, "docs", "art", "screens", "lounge-revamp")
SHOTS = ["lounge", "merch", "memory", "patrons", "stair-foot", "corridor-west", "corridor-east", "portrait-wall",
         "curtain-main-west", "curtain-main-strip", "curtain-buffer"]
H = {"portrait": 1100, "landscape": 640}
GAP = 16
CAP = 54


def fit(im, h):
    return im.resize((round(im.width * h / im.height), h), Image.LANCZOS)


def main(tag):
    try:
        font = ImageFont.truetype("arialbd.ttf", 30)
    except OSError:
        font = ImageFont.load_default()
    h = H.get(tag, 900)
    for shot in SHOTS:
        before = os.path.join(DIR, "before-%s-%s.png" % (tag, shot))
        after = os.path.join(DIR, "%s-%s.png" % (tag, shot))
        if not (os.path.exists(before) and os.path.exists(after)):
            continue
        a = fit(Image.open(before).convert("RGB"), h)
        b = fit(Image.open(after).convert("RGB"), h)
        out = Image.new("RGB", (a.width + GAP + b.width, h + CAP), (18, 14, 16))
        out.paste(a, (0, CAP))
        out.paste(b, (a.width + GAP, CAP))
        d = ImageDraw.Draw(out)
        d.text((14, 10), "BEFORE (db5e398)", fill=(200, 190, 190), font=font)
        d.text((a.width + GAP + 14, 10), "AFTER (lounge revamp)", fill=(255, 210, 120), font=font)
        path = os.path.join(DIR, "twoup-%s-%s.jpg" % (tag, shot))
        out.save(path, quality=90)
        print("saved", path, out.size)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "portrait")
