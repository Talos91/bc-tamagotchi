"""Corridor end-wall neon for the venue (game/tools/build_venue.gd, _corridor_end), after Daniele's photo
docs/art/direction/24-corridor-end-neon-now-open.jpg, lettered in Kristi (Daniele 2026-11-02, Questions tab third
batch: Kristi script for the corridor neon and the memory-corner light box). "Black" over a tube line and
"— Cabin —" in pale pink-white tubes with a red glow, then "Now Open" in a green-white arrow outline pointing left
(north, to the Sticker door), as the photo. A script in capitals reads badly, so the words are in title case, as the
Kristi titles in the interface (mg_ui.gd UI.title_case).

Same neon recipe as tools/street_sign.py: a tube mask, a bright softened core, two blurred halos in the glow colour,
drawn on black. The texture is used additively (black adds nothing), so the brick and panel behind show through.
Kristi strokes are already tube-thin, so the glyph itself is the tube (the street sign's serif letters are outlined
instead); the core is the stroke eroded to its centre line, so every stroke has a white centre and a tinted rim.

    python tools/venue_neon.py      -> game/assets/venue/corridor_neon.png (1200 x 1120, black = nothing)

Font: game/assets/fonts/Kristi-Regular.ttf (OFL, bundled with the game).
"""
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / "game" / "assets" / "fonts" / "Kristi-Regular.ttf"
OUT = ROOT / "game" / "assets" / "venue" / "corridor_neon.png"
W, H = 1200, 1120          # 1.2 x 1.12 m on the wall (build_venue.gd CORRIDOR_NEON_SIZE)

PINK_TUBE = (255, 236, 236)  # pale pink-white tube
PINK_GLOW = (255, 30, 60)    # red-pink glow
GREEN_TUBE = (244, 255, 222)  # the NOW OPEN arrow: green-white
GREEN_GLOW = (170, 255, 110)


def text_mask(text, size, cx, cy, stroke=0):
    """L mask with `text` in Kristi at `size` px, its ink box centred on (cx, cy)."""
    f = ImageFont.truetype(str(FONT), size)
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    x0, y0, x1, y1 = d.textbbox((0, 0), text, font=f, stroke_width=stroke)
    d.text((cx - (x0 + x1) / 2, cy - (y0 + y1) / 2), text, font=f, fill=255, stroke_width=stroke, stroke_fill=255)
    return m


def line_mask(segments, width):
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    for a, b in segments:
        d.line([a, b], fill=255, width=width)
        for p in (a, b):   # round tube ends
            d.ellipse([p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2], fill=255)
    return m


def _max(a, b):
    return ImageChops.lighter(a, b)


def neon(out, mask, tube, glow, strength=1.0):
    """Adds one neon colour to `out` (RGB, additive): tinted tube, white-hot centre, two halos."""
    rim = mask.filter(ImageFilter.GaussianBlur(1.0))
    centre = mask.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(1.2))
    halo = mask.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(26))
    halo2 = mask.filter(ImageFilter.GaussianBlur(8))
    layers = []
    for img, col, k in ((halo, glow, 1.3 * strength), (halo2, glow, 0.8 * strength), (rim, tube, 1.0),
                        (centre, (255, 255, 255), 0.6)):
        lit = img.point(lambda v, k=k: min(255, int(v * k)))
        layers.append(Image.merge("RGB", [lit.point(lambda v, c=c: v * c // 255) for c in col]))
    for layer in layers:
        out = ImageChops.add(out, layer)
    return out


def main():
    cx = W / 2
    # BLACK, the tube line under it, — CABIN — (photo 24: the line runs under BLACK, dashes either side of CABIN)
    pink = text_mask("Black", 330, cx, 250, stroke=2)
    pink = _max(pink, line_mask([((cx - 330, 420), (cx + 330, 420))], 12))
    cabin = text_mask("Cabin", 210, cx, 545, stroke=2)
    pink = _max(pink, cabin)
    pink = _max(pink, line_mask([((cx - 430, 555), (cx - 250, 555)), ((cx + 250, 555), (cx + 430, 555))], 12))
    # NOW OPEN inside an arrow outline pointing left
    green = text_mask("Now Open", 156, cx + 50, 905, stroke=5)
    x0, x1, y0, y1, tip = cx - 230, cx + 330, 815, 995, cx - 390
    mid = (y0 + y1) / 2
    arrow = [((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)),
             ((x0, y0), (x0, y0 - 45)), ((x0, y0 - 45), (tip, mid)), ((tip, mid), (x0, y1 + 45)),
             ((x0, y1 + 45), (x0, y1))]
    green = _max(green, line_mask(arrow, 11))
    out = Image.new("RGB", (W, H), 0)
    out = neon(out, pink, PINK_TUBE, PINK_GLOW)
    out = neon(out, green, GREEN_TUBE, GREEN_GLOW, 0.5)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT, optimize=True)
    print("wrote", OUT, out.size)


if __name__ == "__main__":
    main()
