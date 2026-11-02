"""Strips and photo sheets for the look test (game/tests/capture_look_test.gd; Daniele 2026-11-02: black walls and red
light, "before implementing lets test").

    python game/tools/look_test_compose.py          (from the repo root, after both capture runs)

Writes to docs/art/screens/look-test/ (JPEG, quality 88):
  strip-<view>.jpg              portrait A | B | C | D side by side, captioned
  strip-landscape-<view>.jpg    landscape, A B over C D
  sheet-photos-bar.jpg          variant D at the bar next to real photos 09 and 16
  sheet-photos-floor.jpg        variant D on the main-room floor (landscape) next to real photos 07 and 11
"""
import os

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIR = os.path.join(REPO, "docs", "art", "screens", "look-test")
PHOTOS = os.path.join(REPO, "docs", "art", "direction")
FONT = os.path.join(REPO, "game", "assets", "fonts", "Lato-Bold.ttf")
VARIANTS = [("A", "A  today"), ("B", "B  black walls, red light"), ("C", "C  burgundy walls, red light"),
            ("D", "D  as in the venue")]
VIEWS = ["floor", "bar", "stage", "lounge", "corridor", "smoking"]
MAIN_VIEWS = ["floor", "bar", "stage"]
SHEETS = [("bar", "D-bar.png", ["09-bar-lights-cashier.jpg", "16-reindeer-over-cashier.jpg"]),
          ("floor", "D-landscape-floor.png", ["07-main-room-photo-from-bar-end.webp",
                                              "11-main-room-east-raised-couch-shelves.jpg"])]
GAP = 12
CAP = 56
BG = (14, 10, 10)
INK = (240, 228, 210)


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def fit_h(im, h):
    return im.resize((round(im.width * h / im.height), h), Image.LANCZOS)


def tile(im, caption, f):
    out = Image.new("RGB", (im.width, im.height + CAP), BG)
    out.paste(im, (0, CAP))
    ImageDraw.Draw(out).text((14, 10), caption, font=f, fill=INK)
    return out


def grid(tiles, cols):
    w = max(t.width for t in tiles)
    h = max(t.height for t in tiles)
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new("RGB", (cols * w + (cols + 1) * GAP, rows * h + (rows + 1) * GAP), BG)
    for i, t in enumerate(tiles):
        out.paste(t, (GAP + (i % cols) * (w + GAP), GAP + (i // cols) * (h + GAP)))
    return out


def save(im, name):
    path = os.path.join(DIR, name)
    im.save(path, quality=88)
    print("saved", os.path.relpath(path, REPO), im.size)


def main():
    f = font(30)
    for view in VIEWS:
        files = [os.path.join(DIR, "%s-%s.png" % (k, view)) for k, _ in VARIANTS]
        if all(os.path.exists(p) for p in files):
            save(grid([tile(fit_h(Image.open(p).convert("RGB"), 960), c, f) for p, (_, c) in zip(files, VARIANTS)], 4),
                 "strip-%s.jpg" % view)
    for view in MAIN_VIEWS:
        files = [os.path.join(DIR, "%s-landscape-%s.png" % (k, view)) for k, _ in VARIANTS]
        if all(os.path.exists(p) for p in files):
            save(grid([tile(fit_h(Image.open(p).convert("RGB"), 540), c, f) for p, (_, c) in zip(files, VARIANTS)], 2),
                 "strip-landscape-%s.jpg" % view)
    for name, shot, photos in SHEETS:
        h = 1100 if name == "bar" else 700
        tiles = [tile(fit_h(Image.open(os.path.join(DIR, shot)).convert("RGB"), h), "D in the game", f)]
        for ph in photos:
            tiles.append(tile(fit_h(Image.open(os.path.join(PHOTOS, ph)).convert("RGB"), h), "photo " + ph[:2], f))
        if name == "bar":
            save(grid(tiles, 3), "sheet-photos-bar.jpg")
        else:   # the landscape shot on top, the two photos under it
            top = tiles[0]
            bottom = grid(tiles[1:], 2)
            out = Image.new("RGB", (max(top.width + 2 * GAP, bottom.width), top.height + bottom.height + GAP), BG)
            out.paste(top, ((out.width - top.width) // 2, GAP))
            out.paste(bottom, ((out.width - bottom.width) // 2, top.height + GAP))
            save(out, "sheet-photos-floor.jpg")


if __name__ == "__main__":
    main()
