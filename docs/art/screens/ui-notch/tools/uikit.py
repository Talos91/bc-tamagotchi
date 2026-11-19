"""Mock-up toolkit for the ui-notch design job (PIL only, no Godot). Icons in three styles, glow, panels, text."""
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

SCR = r"C:/Users/itisf/AppData/Local/Temp/claude/367d8cda9bb5f12e/76793083-ac6f-4169-b888-79561fb22d63/scratchpad"
FONTS = SCR + "/fonts/"
GAMEF = r"H:/My Drive/PROJECTS/Black Cabin Tamagotchi/game/assets/fonts/"

NEED_COL = {"music": (232, 40, 52), "friends": (255, 221, 120), "drinks": (255, 138, 48), "nightlife": (24, 208, 250)}
NEED_COL_NEW = {"music": (255, 64, 129), "friends": (255, 214, 90), "drinks": (255, 140, 40), "nightlife": (40, 210, 255)}
NEEDS = ["music", "friends", "drinks", "nightlife"]
LABEL = {"music": "Music", "friends": "Friends", "drinks": "Drinks", "nightlife": "Nightlife"}
CREAM = (246, 235, 221)
GOLD = (255, 221, 120)
NEON = (255, 42, 20)
INK = (22, 10, 12)


def font(name, size):
    paths = {"lato": GAMEF + "Lato-Bold.ttf", "lato-r": GAMEF + "Lato-Regular.ttf", "lato-b": GAMEF + "Lato-Black.ttf",
             "kristi": GAMEF + "Kristi-Regular.ttf", "tilt": FONTS + "TiltNeon.ttf", "bebas": FONTS + "BebasNeue.ttf",
             "silk": FONTS + "Silkscreen.ttf", "silk-b": FONTS + "Silkscreen-Bold.ttf", "monoton": FONTS + "Monoton.ttf",
             "oswald": FONTS + "Oswald.ttf", "bungee": FONTS + "Bungee.ttf", "limelight": FONTS + "Limelight.ttf",
             "pixel": FONTS + "PixelifySans.ttf"}
    return ImageFont.truetype(paths[name], int(size))


# ---------------------------------------------------------------- icon geometry (24-unit box)
def _icon_draw(d, need, ox, oy, u, col, bg, mode, w):
    """mode 'fill' draws silhouettes (bg cuts the details); mode 'line' draws tubes of width w."""
    P = lambda x, y: (ox + x * u, oy + y * u)
    E = lambda cx, cy, rx, ry: [ox + (cx - rx) * u, oy + (cy - ry) * u, ox + (cx + rx) * u, oy + (cy + ry) * u]
    if need == "music":  # two beamed eighth notes
        if mode == "fill":
            d.ellipse(E(6.3, 18.2, 3.6, 2.9), fill=col)
            d.ellipse(E(17.0, 16.2, 3.6, 2.9), fill=col)
            d.polygon([P(8.6, 18), P(10.4, 18), P(10.4, 6.6), P(8.6, 7)], fill=col)
            d.polygon([P(19.3, 16), P(21.1, 16), P(21.1, 4.4), P(19.3, 4.8)], fill=col)
            d.polygon([P(8.6, 4.6), P(21.1, 2.0), P(21.1, 5.6), P(8.6, 8.2)], fill=col)
        else:
            d.ellipse(E(6.3, 18.2, 3.2, 2.5), outline=col, width=w)
            d.ellipse(E(17.0, 16.2, 3.2, 2.5), outline=col, width=w)
            d.line([P(9.4, 17.6), P(9.4, 5.6), P(20.2, 3.2), P(20.2, 15.6)], fill=col, width=w, joint="curve")
            d.line([P(9.4, 8.6), P(20.2, 6.2)], fill=col, width=w)
    elif need == "friends":  # two busts, the front one overlapping
        if mode == "fill":
            d.ellipse(E(16.2, 7.6, 3.6, 3.6), fill=col)
            d.pieslice(E(16.2, 21.5, 6.6, 8.0), 180, 360, fill=col)
            d.ellipse(E(8.8, 9.0, 5.2, 5.2), fill=bg)
            d.pieslice(E(8.8, 23.6, 9.0, 10.4), 180, 360, fill=bg)
            d.ellipse(E(8.8, 9.0, 3.9, 3.9), fill=col)
            d.pieslice(E(8.8, 23.6, 7.6, 9.0), 180, 360, fill=col)
        else:
            d.ellipse(E(16.4, 7.4, 3.2, 3.2), outline=col, width=w)
            d.arc(E(16.4, 21.0, 6.0, 7.2), 205, 330, fill=col, width=w)
            d.ellipse(E(8.6, 9.2, 3.6, 3.6), outline=col, width=w)
            d.arc(E(8.6, 23.0, 7.0, 8.4), 180, 360, fill=col, width=w)
    elif need == "drinks":  # cocktail glass with an olive
        if mode == "fill":
            d.polygon([P(2.6, 4.2), P(21.4, 4.2), P(12, 13.6)], fill=col)
            d.rectangle([P(11.0, 12.5), P(13.0, 19.6)], fill=col)
            d.ellipse(E(12, 20.4, 5.4, 1.5), fill=col)
            d.ellipse(E(14.6, 7.0, 1.9, 1.9), fill=bg)
            d.line([P(13.0, 9.2), P(18.8, 1.4)], fill=bg, width=max(1, int(u * 1.1)))
            d.line([P(17.0, 3.6), P(19.8, 0.2)], fill=col, width=max(1, int(u * 1.3)))
        else:
            d.line([P(3.2, 4.6), P(20.8, 4.6), P(12, 13.2), P(3.2, 4.6)], fill=col, width=w, joint="curve")
            d.line([P(12, 13.2), P(12, 19.6)], fill=col, width=w)
            d.line([P(7.2, 20.4), P(16.8, 20.4)], fill=col, width=w)
            d.ellipse(E(14.0, 2.4, 1.6, 1.6), outline=col, width=max(1, w * 2 // 3))
    elif need == "nightlife":  # disco ball with a sparkle
        if mode == "fill":
            d.line([P(11, 0.4), P(11, 5)], fill=col, width=max(1, int(u * 1.0)))
            d.ellipse(E(11, 13.4, 8.6, 8.6), fill=col)
            lw = max(1, int(u * 0.9))
            for yy in (9.6, 13.4, 17.2):
                hw = math.sqrt(max(0, 8.6 ** 2 - (yy - 13.4) ** 2))
                d.line([P(11 - hw, yy), P(11 + hw, yy)], fill=bg, width=lw)
            for xx in (7.0, 11.0, 15.0):
                hh = math.sqrt(max(0, 8.6 ** 2 - (xx - 11) ** 2))
                d.line([P(xx, 13.4 - hh), P(xx, 13.4 + hh)], fill=bg, width=lw)
            _star(d, P(20.6, 4.2), 3.6 * u, col)
        else:
            d.line([P(11, 0.6), P(11, 4.6)], fill=col, width=w)
            d.ellipse(E(11, 13.4, 8.0, 8.0), outline=col, width=w)
            d.line([P(3.6, 13.4), P(18.4, 13.4)], fill=col, width=max(1, w * 2 // 3))
            d.arc(E(11, 13.4, 3.6, 8.0), 0, 360, fill=col, width=max(1, w * 2 // 3))
            _star(d, P(20.6, 4.2), 3.4 * u, col)
    elif need == "door":
        if mode == "fill":
            d.rectangle([P(5, 2), P(17, 22)], fill=col)
            d.rectangle([P(7.5, 4.5), P(14.5, 20)], fill=bg)
            d.polygon([P(7.5, 4.5), P(14.5, 2.8), P(14.5, 21.5), P(7.5, 20)], fill=col)
            d.ellipse(E(12.6, 12, 1.0, 1.0), fill=bg)
            d.polygon([P(17.5, 10), P(21.5, 12), P(17.5, 14)], fill=col)
        else:
            d.rectangle([P(5, 2), P(17, 22)], outline=col, width=w)
            d.line([P(19, 12), P(23, 12)], fill=col, width=w)
    elif need == "ticket":
        if mode == "fill":
            d.rounded_rectangle([P(1.5, 6), P(22.5, 18)], radius=int(1.5 * u), fill=col)
            d.ellipse(E(1.5, 12, 2.2, 2.2), fill=bg)
            d.ellipse(E(22.5, 12, 2.2, 2.2), fill=bg)
            for yy in range(7, 18, 2):
                d.rectangle([P(15.6, yy), P(16.4, yy + 0.9)], fill=bg)
            _star(d, P(9, 12), 4.2 * u, bg)
        else:
            d.rounded_rectangle([P(1.5, 6), P(22.5, 18)], radius=int(1.5 * u), outline=col, width=w)
            _star(d, P(9, 12), 4 * u, col)


def _star(d, c, r, col):
    x, y = c
    pts = []
    for i in range(8):
        a = i * math.pi / 4 - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.3
        pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
    d.polygon(pts, fill=col)


def icon(need, size, col, style="solid", bg=None):
    """Returns an RGBA image size x size. styles: solid (filled), neon (tube + glow), voxel (blocky, shaded)."""
    if style == "solid":
        S = 8
        big = Image.new("RGBA", (size * S, size * S), (0, 0, 0, 0))
        d = ImageDraw.Draw(big)
        _icon_draw(d, need, size * S * 0.04, size * S * 0.04, size * S * 0.92 / 24, col + (255,), (0, 0, 0, 0), "fill", 1)
        return big.resize((size, size), Image.LANCZOS)
    if style == "neon":
        S = 4
        pad = size // 4
        W = size + pad * 2
        big = Image.new("RGBA", (W * S, W * S), (0, 0, 0, 0))
        d = ImageDraw.Draw(big)
        w = max(2, int(size * S * 0.085))
        _icon_draw(d, need, pad * S + size * S * 0.04, pad * S + size * S * 0.04, size * S * 0.92 / 24, (255, 255, 255, 255), None, "line", w)
        m = big.resize((W, W), Image.LANCZOS).split()[3]
        return neon_from_mask(m, col)
    if style == "voxel":
        G = 20
        small = Image.new("L", (G * 4, G * 4), 0)
        d = ImageDraw.Draw(small)
        _icon_draw(d, need, 0, 0, G * 4 / 24, 255, 255 if need == "nightlife" else 0, "fill", 1)
        grid = small.resize((G, G), Image.BOX).point(lambda v: 255 if v > 110 else 0)
        b = size / G
        out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(out)
        if need == "friends":
            grid = _friends_grid(G)
        px = grid.load()
        dark = tuple(int(c * 0.45) for c in col)
        hi = tuple(min(255, int(c + (255 - c) * 0.55)) for c in col)
        for y in range(G):
            for x in range(G):
                if not px[x, y]:
                    continue
                x0, y0 = int(x * b), int(y * b)
                x1, y1 = int((x + 1) * b) - 1, int((y + 1) * b) - 1
                cc = col
                if need == "nightlife" and y >= 6 and ((x // 2 + y // 2) % 2):
                    cc = tuple(int(c * 0.7) for c in col)
                d.rectangle([x0, y0, x1, y1], fill=cc + (255,))
                e = max(1, int(b * 0.22))
                if y == 0 or not px[x, y - 1]:
                    d.rectangle([x0, y0, x1, y0 + e - 1], fill=hi + (255,))
                if y == G - 1 or not px[x, y + 1]:
                    d.rectangle([x0, y1 - e + 1, x1, y1], fill=dark + (255,))
                if x == G - 1 or not px[x + 1, y]:
                    d.rectangle([x1 - e + 1, y0, x1, y1], fill=dark + (255,))
        return out
    raise ValueError(style)


def neon_from_mask(m, col, glow=1.0):
    """Mask (L) -> RGBA neon tube: wide blurred colour glow, tighter glow, near-white core tinted by the colour."""
    W, H = m.size
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    r = max(2, W // 14)
    for rad, a in ((r * 1.6, 0.9 * glow), (r * 0.6, 1.0)):
        g = m.filter(ImageFilter.GaussianBlur(rad)).point(lambda v, a=a: min(255, int(v * 2.2 * a)))
        layer = Image.new("RGBA", (W, H), col + (0,))
        layer.putalpha(g)
        out = Image.alpha_composite(out, layer)
    core_col = tuple(min(255, int(c + (255 - c) * 0.6)) for c in col)
    core = Image.new("RGBA", (W, H), core_col + (0,))
    core.putalpha(m)
    return Image.alpha_composite(out, core)


# ---------------------------------------------------------------- drawing helpers on an RGBA canvas
def paste(canvas, im, xy, center=False):
    x, y = xy
    if center:
        x, y = int(x - im.width / 2), int(y - im.height / 2)
    canvas.alpha_composite(im, (int(x), int(y)))


def glow_rect(canvas, box, radius, col, blur, alpha=200, width=None):
    """Soft glow of a rounded rect (or its outline when width is set)."""
    pad = int(blur * 3)
    x0, y0, x1, y1 = [int(v) for v in box]
    W, H = x1 - x0 + pad * 2, y1 - y0 + pad * 2
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    if width:
        d.rounded_rectangle([pad, pad, W - pad, H - pad], radius=radius, outline=alpha, width=width)
    else:
        d.rounded_rectangle([pad, pad, W - pad, H - pad], radius=radius, fill=alpha)
    m = m.filter(ImageFilter.GaussianBlur(blur))
    layer = Image.new("RGBA", (W, H), col + (0,))
    layer.putalpha(m)
    canvas.alpha_composite(layer, (x0 - pad, y0 - pad))


def rrect(canvas, box, radius, fill=None, outline=None, width=1):
    S = 3
    x0, y0, x1, y1 = [int(v) for v in box]
    W, H = x1 - x0 + 4, y1 - y0 + 4
    big = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.rounded_rectangle([2 * S, 2 * S, (W - 2) * S, (H - 2) * S], radius=radius * S, fill=fill, outline=outline, width=width * S)
    canvas.alpha_composite(big.resize((W, H), Image.LANCZOS), (x0 - 2, y0 - 2))


def neon_rrect(canvas, box, radius, col, tube=6, glow=1.0):
    x0, y0, x1, y1 = [int(v) for v in box]
    pad = 40
    W, H = x1 - x0 + pad * 2, y1 - y0 + pad * 2
    S = 2
    m = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(m).rounded_rectangle([pad * S, pad * S, (W - pad) * S, (H - pad) * S], radius=radius * S, outline=255, width=tube * S)
    m = m.resize((W, H), Image.LANCZOS)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for rad, a in ((16, 0.75 * glow), (5, 1.0)):
        g = m.filter(ImageFilter.GaussianBlur(rad)).point(lambda v, a=a: min(255, int(v * 2.0 * a)))
        layer = Image.new("RGBA", (W, H), col + (0,))
        layer.putalpha(g)
        out = Image.alpha_composite(out, layer)
    core_col = tuple(min(255, int(c + (255 - c) * 0.55)) for c in col)
    core = Image.new("RGBA", (W, H), core_col + (0,))
    core.putalpha(m)
    out = Image.alpha_composite(out, core)
    canvas.alpha_composite(out, (x0 - pad, y0 - pad))


def text(canvas, xy, s, f, col, anchor="la", glow=None, glow_r=10, shadow=False):
    if glow:
        pad = int(glow_r * 4)
        xy = (int(xy[0]), int(xy[1]))
        bb = ImageDraw.Draw(canvas).textbbox(xy, s, font=f, anchor=anchor)
        W, H = bb[2] - bb[0] + pad * 2, bb[3] - bb[1] + pad * 2
        m = Image.new("L", (W, H), 0)
        ImageDraw.Draw(m).text((xy[0] - bb[0] + pad, xy[1] - bb[1] + pad), s, font=f, fill=255, anchor=anchor)
        for rad, a in ((glow_r * 2.2, 0.8), (glow_r * 0.7, 1.0)):
            g = m.filter(ImageFilter.GaussianBlur(rad)).point(lambda v, a=a: min(255, int(v * 1.8 * a)))
            layer = Image.new("RGBA", (W, H), glow + (0,))
            layer.putalpha(g)
            canvas.alpha_composite(layer, (bb[0] - pad, bb[1] - pad))
    if shadow:
        ImageDraw.Draw(canvas).text((xy[0] + 3, xy[1] + 4), s, font=f, fill=(0, 0, 0, 170), anchor=anchor)
    ImageDraw.Draw(canvas).text(xy, s, font=f, fill=col, anchor=anchor)


def vgrad(size, top, bottom):
    W, H = size
    g = Image.new("RGBA", (1, H))
    for y in range(H):
        t = y / max(1, H - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(4)))
    return g.resize((W, H))


def cover(im, size):
    W, H = size
    s = max(W / im.width, H / im.height)
    im = im.resize((int(im.width * s + 0.5), int(im.height * s + 0.5)), Image.LANCZOS)
    x, y = (im.width - W) // 2, (im.height - H) // 2
    return im.crop((x, y, x + W, y + H))


def dim(im, k=0.75):
    return Image.blend(Image.new("RGBA", im.size, (0, 0, 0, 255)), im.convert("RGBA"), k)


def _friends_grid(G=20):
    def body(x, y, x0, x1, y0, y1):
        if not (x0 <= x <= x1 and y0 <= y <= y1):
            return False
        if y == y0 and (x <= x0 + 1 or x >= x1 - 1):
            return False
        if y == y0 + 1 and (x == x0 or x == x1):
            return False
        return True
    front = set()
    back = set()
    for y in range(G):
        for x in range(G):
            if (x - 6.5) ** 2 + (y - 7.0) ** 2 <= 3.0 ** 2 or body(x, y, 1, 12, 11, 18):
                front.add((x, y))
            if (x - 14.0) ** 2 + (y - 4.5) ** 2 <= 2.6 ** 2 or body(x, y, 9, 18, 9, 15):
                back.add((x, y))
    im = Image.new("L", (G, G), 0)
    for (x, y) in front:
        im.putpixel((x, y), 255)
    for (x, y) in back:
        if all((x + dx, y + dy) not in front for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            im.putpixel((x, y), 255)
    return im
