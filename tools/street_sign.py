"""Street sign texture for the start screen (game/scenes/street/street_front.gd), after Daniele's photo
docs/art/direction/23-street-sign-neon.png: BLACK over a smaller centred CABIN in a high-contrast serif, drawn as
outlined neon tubes (the outline of each glyph, so every stroke reads as a double line), pale pink-white, with a deep
red glow round them. The letters are drawn here from rectangles, polygons and ellipses (no font file: nothing to
license), filled into a mask, and the mask's edge becomes the tube.

    python tools/street_sign.py            -> game/assets/street/street_sign.png (2048 x 1024, black = nothing)

The texture is used additively (black adds nothing), so the foliage behind it shows through.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

W, H_IMG = 2048, 1024
OUT = Path(__file__).resolve().parent.parent / "game" / "assets" / "street" / "street_sign.png"

# Proportions of the cap height H
T = 0.16      # thick stroke
t = 0.055     # thin stroke
S = 0.045     # serif slab thickness
O = 0.09      # serif overhang
GAP = 0.07    # letter spacing


def _rect(d, x0, y0, x1, y1, fill=255):
    d.rectangle([min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)], fill=fill)


def letter(d, ch, x, base, H):
    """Draws `ch` with its left edge at x and baseline at `base`, cap height H (pixels). Returns the advance."""
    top = base - H
    h = lambda v: v * H
    if ch == "B":
        sx = x + h(O)
        _rect(d, sx, top, sx + h(T), base)
        _rect(d, x, top, sx + h(T), top + h(S))
        _rect(d, x, base - h(S), sx + h(T), base)
        r = sx + h(0.5)
        d.rounded_rectangle([sx, top, r, top + h(0.5)], radius=h(0.24), fill=255, corners=(False, True, True, False))
        r2 = sx + h(0.56)
        d.rounded_rectangle([sx, top + h(0.45), r2, base], radius=h(0.27), fill=255, corners=(False, True, True, False))
        d.rounded_rectangle([sx + h(T), top + h(t), r - h(0.12), top + h(0.5 - t)], radius=h(0.15), fill=0,
                            corners=(False, True, True, False))
        d.rounded_rectangle([sx + h(T), top + h(0.45 + t), r2 - h(0.14), base - h(t)], radius=h(0.17), fill=0,
                            corners=(False, True, True, False))
        return h(O + 0.56 + 0.02)
    if ch == "L":
        sx = x + h(O)
        _rect(d, sx, top, sx + h(T), base)
        _rect(d, x, top, sx + h(T + O), top + h(S))
        _rect(d, x, base - h(S * 1.3), x + h(0.56), base)
        d.polygon([(x + h(0.56), base), (x + h(0.56), base - h(0.24)), (x + h(0.56 - t), base - h(0.24)),
                   (x + h(0.48), base - h(S * 1.3))], fill=255)
        return h(0.58)
    if ch == "I":
        sx = x + h(O)
        _rect(d, sx, top, sx + h(T), base)
        _rect(d, x, top, sx + h(T + O), top + h(S))
        _rect(d, x, base - h(S), sx + h(T + O), base)
        return h(T + 2 * O)
    if ch == "A":
        ax = x + h(0.34)
        lx, rx = x + h(0.1), x + h(0.6)
        d.polygon([(ax - h(0.05), top), (ax - h(0.05) + h(t), top), (lx + h(t) / 2, base), (lx - h(t) / 2, base)], fill=255)
        d.polygon([(ax - h(0.04), top), (ax + h(0.09), top), (rx + h(T) / 2, base), (rx - h(T) / 2, base)], fill=255)
        _rect(d, x + h(0.18), top + h(0.6), x + h(0.5), top + h(0.6 + t))
        _rect(d, lx - h(0.11), base - h(S), lx + h(0.11), base)
        _rect(d, rx - h(0.15), base - h(S), rx + h(0.14), base)
        return h(0.74)
    if ch == "C":
        w = 0.64
        d.ellipse([x, top, x + h(w), base], fill=255)
        d.ellipse([x + h(T), top + h(t), x + h(w - 0.05), base - h(t)], fill=0)
        _rect(d, x + h(0.4), top + h(0.24), x + h(w) + 2, base - h(0.22), fill=0)
        _rect(d, x + h(0.5), top + h(0.05), x + h(0.5 + t), top + h(0.26))          # beaks at the terminals
        _rect(d, x + h(0.5), base - h(0.23), x + h(0.5 + t), base - h(0.05))
        return h(w + 0.01)
    if ch == "K":
        sx = x + h(O)
        _rect(d, sx, top, sx + h(T), base)
        _rect(d, x, top, sx + h(T + O), top + h(S))
        _rect(d, x, base - h(S), sx + h(T + O), base)
        sr = sx + h(T)
        d.polygon([(sr, top + h(0.58)), (sr, top + h(0.58) + h(t) * 1.6), (x + h(0.62), top + h(S)),
                   (x + h(0.62) - h(t) * 1.4, top + h(S))], fill=255)
        d.polygon([(sr - h(0.02), top + h(0.4)), (sr + h(T) * 0.9, top + h(0.4)), (x + h(0.7), base - h(S)),
                   (x + h(0.7) - h(T), base - h(S))], fill=255)
        _rect(d, x + h(0.47), top, x + h(0.75), top + h(S))
        _rect(d, x + h(0.5), base - h(S), x + h(0.78), base)
        return h(0.78)
    if ch == "N":
        lx = x + h(O)
        rx = x + h(0.7 - O)
        _rect(d, lx, top, lx + h(t), base)
        _rect(d, rx - h(t), top, rx, base - h(0.04))
        d.polygon([(lx, top), (lx + h(T), top), (rx, base), (rx - h(T), base)], fill=255)
        _rect(d, x, top, lx + h(T * 0.7), top + h(S))
        _rect(d, x, base - h(S), lx + h(t + O), base)
        _rect(d, rx - h(t + O), top, rx + h(O), top + h(S))
        return h(0.7)
    raise ValueError(ch)


def word_width(word, H):
    d = ImageDraw.Draw(Image.new("L", (8, 8)))
    return sum(letter(d, c, 0, 4, H) for c in word) + GAP * H * (len(word) - 1)


def draw_word(d, word, cx, base, H):
    x = cx - word_width(word, H) / 2
    for c in word:
        x += letter(d, c, x, base, H) + GAP * H


def main():
    H = 440
    H2 = H * 0.72
    gap = H * 0.3
    total = H + gap + H2
    top = (H_IMG - total) / 2
    mask = Image.new("L", (W, H_IMG), 0)
    d = ImageDraw.Draw(mask)
    draw_word(d, "BLACK", W / 2, top + H, H)
    draw_word(d, "CABIN", W / 2, top + H + gap + H2, H2)
    # The tube: a band along the glyph edge (dilated minus eroded), softened a touch
    band = ImageChops.subtract(mask.filter(ImageFilter.MaxFilter(15)), mask.filter(ImageFilter.MinFilter(9)))
    core = band.filter(ImageFilter.GaussianBlur(1.2))
    halo = band.filter(ImageFilter.GaussianBlur(22))
    halo2 = band.filter(ImageFilter.GaussianBlur(7))
    tube = (255, 222, 228)          # pale pink-white
    red = (255, 14, 22)             # deep red glow
    out = Image.new("RGB", (W, H_IMG), 0)
    px_core, px_halo, px_halo2 = core.load(), halo.load(), halo2.load()
    px = out.load()
    for y in range(H_IMG):
        for x in range(W):
            c = px_core[x, y] / 255.0
            g = min(1.0, px_halo[x, y] / 255.0 * 2.4) * 0.5 + min(1.0, px_halo2[x, y] / 255.0 * 1.4) * 0.4
            if c <= 0.0 and g <= 0.0:
                continue
            px[x, y] = tuple(min(255, int(tube[i] * c + red[i] * g * (1.0 - c))) for i in range(3))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT, optimize=True)
    print("wrote", OUT, out.size)


if __name__ == "__main__":
    main()
