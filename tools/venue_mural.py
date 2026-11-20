"""Draws the entrance corridor's mural (Daniele 2026-11-20, photos 03, 04, 05 in
docs/venue/photos/2026-11-20-entrance-round/): the spray-painted "REAL" in big hollow black letters, "MAX  SOLO
EXHIBITION" in hand capitals under it and the little cartoon painter with a spray can, on a patch of pale worn
plaster (the corridor walls there are pale concrete; the game's wall is near black, so the mural carries its own
plaster). Output game/assets/venue/corridor_mural.png, 2048 x 640 px for a 6.0 x 1.875 m quad (1 px ~ 3 mm).
The lettering is a stylised copy for the game; the real work is by the artist MAX (credit: Daniele to confirm).

    python tools/venue_mural.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
OUT = os.path.join(REPO, "game", "assets", "venue", "corridor_mural.png")
FONT_BIG = os.path.join(REPO, "game", "assets", "fonts", "Lato-Black.ttf")
FONT_SMALL = os.path.join(REPO, "game", "assets", "fonts", "Lato-Bold.ttf")
W, H = 2048, 640
INK = (18, 14, 14, 255)


def plaster(rnd):
    """Pale plaster patch with worn, ragged edges (alpha) and damp stains toward the floor."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for y in range(H):
        for x in range(W):
            edge = min(x, W - 1 - x, y, H - 1 - y)
            n = (math.sin(x * 0.013 + y * 0.007) + math.sin(x * 0.041 - y * 0.023) * 0.5) * 18
            if edge + n < 12:
                continue
            v = 196 + int(n * 0.6) + rnd.randint(-6, 6)
            damp = max(0.0, (y - H * 0.7) / (H * 0.3)) * (0.5 + 0.5 * math.sin(x * 0.02))
            v = int(v * (1.0 - 0.35 * damp))
            px[x, y] = (v, int(v * 0.95), int(v * 0.92), 255)
    return img


def hollow_text(img, text, font, xy, wobble, rnd):
    """Big letters as the photo shows them: a black outline stroke with a dark fill and light streaks left inside,
    each letter a little tilted."""
    d = ImageDraw.Draw(img)
    x, y = xy
    for ch in text:
        bbox = font.getbbox(ch)
        cw = bbox[2] - bbox[0]
        layer = Image.new("RGBA", (cw + 80, font.size + 80), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        ld.text((40 - bbox[0], 40 - bbox[1]), ch, font=font, fill=(40, 30, 28, 235), stroke_width=10, stroke_fill=INK)
        for k in range(5):                                       # spray streaks in the fill
            sx = 40 + rnd.randint(int(cw * 0.15), int(cw * 0.85))
            ld.line([(sx, 60), (sx + rnd.randint(-6, 6), font.size)], fill=(120, 110, 104, 120), width=3)
        layer = layer.rotate(rnd.uniform(-wobble, wobble), resample=Image.BICUBIC, expand=False)
        img.alpha_composite(layer, (int(x) - 40, int(y) - 40 + rnd.randint(-12, 12)))
        x += cw + 26
    return x


def painter(d, cx, cy, s):
    """The little cartoon figure (03, 05): round face, bowl haircut, big round eyes, pursed mouth, an arm holding a
    spray can out to the left."""
    d.ellipse([cx - 60 * s, cy - 60 * s, cx + 60 * s, cy + 70 * s], fill=(214, 204, 196, 255), outline=INK, width=int(7 * s))
    d.chord([cx - 66 * s, cy - 78 * s, cx + 66 * s, cy + 28 * s], 180, 360, fill=INK)          # bowl hair
    d.rectangle([cx - 66 * s, cy - 26 * s, cx - 44 * s, cy + 20 * s], fill=INK)
    for ex in (-22, 18):
        d.ellipse([cx + (ex - 13) * s, cy - 4 * s, cx + (ex + 13) * s, cy + 24 * s], outline=INK, width=int(5 * s))
        d.ellipse([cx + (ex - 4) * s, cy + 6 * s, cx + (ex + 4) * s, cy + 14 * s], fill=INK)
    d.ellipse([cx - 8 * s, cy + 38 * s, cx + 8 * s, cy + 52 * s], outline=INK, width=int(4 * s))   # mouth
    d.line([cx - 50 * s, cy + 70 * s, cx - 120 * s, cy + 40 * s], fill=INK, width=int(22 * s))     # arm, striped
    for k in range(3):
        t = 0.25 + k * 0.25
        px, py = cx - 50 * s - 70 * s * t, cy + 70 * s - 30 * s * t
        d.line([px, py - 12 * s, px + 6 * s, py + 12 * s], fill=(214, 204, 196, 255), width=int(4 * s))
    d.rounded_rectangle([cx - 160 * s, cy + 16 * s, cx - 118 * s, cy + 64 * s], 6, fill=(214, 204, 196, 255), outline=INK, width=int(5 * s))
    d.rectangle([cx - 150 * s, cy + 4 * s, cx - 136 * s, cy + 16 * s], fill=INK)                    # nozzle
    d.line([cx - 54 * s, cy + 66 * s, cx - 54 * s, cy + 150 * s], fill=INK, width=int(7 * s))       # body
    d.line([cx + 54 * s, cy + 50 * s, cx + 60 * s, cy + 150 * s], fill=INK, width=int(7 * s))


def main():
    rnd = random.Random(1120)
    img = plaster(rnd)
    big = ImageFont.truetype(FONT_BIG, 360)
    small = ImageFont.truetype(FONT_SMALL, 74)
    end = hollow_text(img, "REAL", big, (110, 70), 5, rnd)
    d = ImageDraw.Draw(img)
    x = 150
    for ch in "MAX   SOLO EXHIBITION":                                # hand capitals, uneven baseline
        if ch != " ":
            d.text((x, 470 + rnd.randint(-10, 10) - (x - 150) * 0.06), ch, font=small, fill=INK)
        x += small.getbbox(ch)[2] + 10 if ch != " " else 22
    painter(d, max(end, x) + 330, 330, 1.35)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(OUT)
    print("mural ->", OUT, img.size)


if __name__ == "__main__":
    main()
