"""Two-ups of the real photos against the in-game eye-level captures (tools/capture_venue.gd EYE shots).

    python game/tools/photo_twoup.py [tag]          (from the repo root; tag = portrait | landscape, default portrait)

Writes docs/art/screens/v4/twoup-<tag>-P<nn>.png: photo left, game right, both scaled to the same height (960 px).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIRECTION = os.path.join(REPO, "docs", "art", "direction")
V4 = os.path.join(REPO, "docs", "art", "screens", "v4")
PAIRS = {"09": ("09-bar-lights-cashier.jpg", "eye-P09-bar"), "11": ("11-main-room-east-raised-couch-shelves.jpg", "eye-P11-raised"),
         "14": ("14-buffer-zone-south-mirror.jpg", "eye-P14-buffer"), "20": ("20-smoking-room-window-side.jpg", "eye-P20-smoking")}
H = 960


def fit(im):
    return im.resize((round(im.width * H / im.height), H), Image.LANCZOS)


def main(tag):
    try:
        font = ImageFont.truetype("arialbd.ttf", 26)
    except OSError:
        font = ImageFont.load_default()
    for n, (photo, shot) in PAIRS.items():
        game_path = os.path.join(V4, "%s-%s.png" % (tag, shot))
        if not os.path.exists(game_path):
            print("missing", game_path)
            continue
        a = fit(Image.open(os.path.join(DIRECTION, photo)).convert("RGB"))
        b = fit(Image.open(game_path).convert("RGB"))
        out = Image.new("RGB", (a.width + b.width + 12, H), (12, 8, 8))
        out.paste(a, (0, 0))
        out.paste(b, (a.width + 12, 0))
        d = ImageDraw.Draw(out)
        for x, t in ((10, "photo %s" % n), (a.width + 22, "game v4 (%s)" % tag)):
            d.rectangle([x - 4, 8, x + 12 * len(t) + 30, 44], fill=(0, 0, 0))
            d.text((x, 12), t, font=font, fill=(255, 255, 255))
        p = os.path.join(V4, "twoup-%s-P%s.png" % (tag, n))
        out.save(p)
        print("twoup ->", p)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "portrait")
