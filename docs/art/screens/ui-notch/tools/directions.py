"""Three interface directions for ui-notch: D1 Neon Sign, D2 Back-bar, D3 Gig Poster. Portrait HUD + bar sheet,
portrait result card, landscape HUD + Tonight sheet, and an overview strip. PIL mock-ups, not game captures."""
import sys, random
sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
from uikit import *
from icons_sheet import chip_solid

REPO = r"H:/My Drive/PROJECTS/Black Cabin Tamagotchi/"
SCR_IN = REPO + "docs/art/screens/"
OUT = SCR_IN + "ui-notch/"
VAL = {"music": 0.72, "friends": 0.55, "drinks": 0.22, "nightlife": 0.86}
AREAS = ["Lounge", "Buffer", "Floor", "Stage", "Bar", "Toilets", "Smoking"]
OPTIONS = [("drinks", "Order a drink", "First one's on the house", None), ("drinks", "The menu", "Beer, wine, whisky, gin · 121 drinks", None),
           ("drinks", "Pour it yourself", "Pour Perfect · first try", "GAME"), ("friends", "Chat with Nam", "Ask what's on tonight", None)]
EVENTS = [("WED 21", "The Cabin Jam", "from 23:45 · Oct poster", True), ("TUE 06", "Coldplay & Oasis Night", "from 21:15", False),
          ("WED 07", "Moderndog Concert", "showtime 22:45", False), ("FRI 09", "10 Year Anniversary", "from 21:00", False)]
BRASS = (196, 150, 82)
RED_LED = (255, 30, 40)
POSTER_RED = (232, 50, 42)
PAPER = (238, 228, 210)


def venue_portrait():
    im = Image.open(SCR_IN + "area-camera/portrait-area-bar.png").convert("RGBA").crop((0, 340, 860, 1421))
    return dim(cover(im, (1080, 1920)), 0.85)


def venue_landscape():
    im = Image.open(SCR_IN + "camera-areas/after-landscape-main.png").convert("RGBA").crop((280, 300, 1700, 1080))
    return dim(cover(im, (1920, 1080)), 0.85)


def game_bg():
    im = Image.open(SCR + "/q1/portrait-neon-moth-gate.png").convert("RGBA")
    return dim(im.filter(ImageFilter.GaussianBlur(6)), 0.6)


def scrim(cv, h, top=True):
    g = vgrad((cv.width, h), (0, 0, 0, 190), (0, 0, 0, 0)) if top else vgrad((cv.width, h), (0, 0, 0, 0), (0, 0, 0, 200))
    cv.alpha_composite(g, (0, 0 if top else cv.height - h))


def poly_mask(size, pts, S=3):
    m = Image.new("L", (size[0] * S, size[1] * S), 0)
    ImageDraw.Draw(m).polygon([(x * S, y * S) for x, y in pts], fill=255)
    return m.resize(size, Image.LANCZOS)


def fill_mask(cv, mask, xy, col):
    layer = Image.new("RGBA", mask.size, col[:3] + (0,))
    a = mask if len(col) == 3 else mask.point(lambda v: v * col[3] // 255)
    layer.putalpha(a)
    cv.alpha_composite(layer, xy)


def neon_poly(cv, pts, col, tube=6, offset=(0, 0)):
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    pad = 40
    x0, y0 = int(min(xs)) - pad, int(min(ys)) - pad
    W, H = int(max(xs)) - x0 + pad, int(max(ys)) - y0 + pad
    S = 2
    m = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(m).line([((x - x0) * S, (y - y0) * S) for x, y in pts + [pts[0]]], fill=255, width=tube * S, joint="curve")
    m = m.resize((W, H), Image.LANCZOS)
    cv.alpha_composite(neon_from_mask(m, col, 0.8), (x0, y0))


def grain(size, seed=1, amt=18):
    random.seed(seed)
    n = Image.effect_noise(size, 40).point(lambda v: 128 + (v - 128) * amt // 40)
    return n


def ticket_mask(w, h, notch=None, perf_x=None, S=3):
    notch = notch or h * 0.14
    m = Image.new("L", (w * S, h * S), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0, 0, w * S - 1, h * S - 1], radius=int(8 * S), fill=255)
    r = notch * S
    for cx in ([perf_x * S] if perf_x else [0, w * S]):
        d.ellipse([cx - r, -r, cx + r, r], fill=0)
        d.ellipse([cx - r, h * S - r, cx + r, h * S + r], fill=0)
    if perf_x:
        for yy in range(int(r * 1.4), int(h * S - r * 1.4), int(14 * S)):
            d.rectangle([perf_x * S - 2 * S, yy, perf_x * S + 2 * S, yy + 6 * S], fill=0)
    return m.resize((w, h), Image.LANCZOS)


def stamp(cv, center, s, f, col, angle=-8, box=True):
    W, H = 900, 400
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    d.text((W / 2, H / 2), s, font=f, fill=255, anchor="mm")
    if box:
        bb = d.textbbox((W / 2, H / 2), s, font=f, anchor="mm")
        d.rounded_rectangle([bb[0] - 30, bb[1] - 26, bb[2] + 30, bb[3] + 26], radius=14, outline=255, width=10)
    n = grain((W, H), 3, 60).point(lambda v: 255 if v > 90 else 0)
    m = ImageChops.multiply(m, n)
    m = m.rotate(angle, resample=Image.BICUBIC)
    fill_mask(cv, m, (int(center[0] - W / 2), int(center[1] - H / 2)), col)


# ======================================================================= D1 NEON SIGN
class Neon:
    key, name = "d1-neon", "D1 Neon Sign"
    panel = (10, 5, 8, 225)

    def button(self, cv, box, label, col=NEON, ic=None, fill=None, fs=36):
        x0, y0, x1, y1 = box
        rrect(cv, box, 26, fill=fill or self.panel)
        neon_rrect(cv, box, 26, col, tube=5)
        cx = (x0 + x1) / 2
        if ic:
            paste(cv, icon(ic, 46, col, "neon"), (cx, y0 + (y1 - y0) * 0.36), center=True)
            text(cv, (cx, y1 - 22), label, font("tilt", 28), CREAM, anchor="ms")
        else:
            text(cv, (cx, (y0 + y1) / 2), label, font("tilt", fs), CREAM, anchor="mm", glow=col, glow_r=6)

    def meter(self, cv, x, y, w, h, n):
        col = NEED_COL_NEW[n]
        rrect(cv, (x, y, x + w, y + h), 22, fill=self.panel)
        neon_rrect(cv, (x, y, x + w, y + h), 22, tuple(int(c * 0.55) for c in col), tube=3, glow=0.4)
        paste(cv, icon(n, 70, col, "neon"), (x + w / 2, y + h * 0.4), center=True)
        bx0, bx1, by = x + 18, x + w - 18, y + h - 22
        rrect(cv, (bx0, by - 5, bx1, by + 5), 5, fill=(60, 30, 30, 255))
        neon_rrect(cv, (bx0, by - 1, bx0 + (bx1 - bx0) * VAL[n], by + 1), 2, col, tube=6)

    def area(self, cv, box, label, lit=False):
        x0, y0, x1, y1 = box
        pts = [(x0, y0), (x1 - 34, y0), (x1, (y0 + y1) / 2), (x1 - 34, y1), (x0, y1)]
        fill_mask(cv, poly_mask((int(x1 - x0) + 1, int(y1 - y0) + 1), [(px - x0, py - y0) for px, py in pts]), (int(x0), int(y0)), self.panel)
        neon_poly(cv, pts, GOLD if lit else NEON, tube=4)
        text(cv, ((x0 + x1 - 30) / 2, (y0 + y1) / 2), label.upper(), font("tilt", 32), CREAM, anchor="mm")

    def zone(self, cv, xy, s, small="LIVE · song 1 of 4"):
        text(cv, xy, s, font("tilt", 92), (255, 220, 214), glow=NEON, glow_r=12)
        text(cv, (xy[0], xy[1] + 120), small, font("tilt", 34), (130, 235, 255), glow=(24, 208, 250), glow_r=5)

    def sheet(self, cv, box, title, sub):
        x0, y0, x1, y1 = box
        rrect(cv, (x0, y0, x1, y1 + 60), 44, fill=(8, 4, 6, 240))
        neon_rrect(cv, (x0 + 30, y0 + 2, x1 - 30, y0 + 4), 2, NEON, tube=5)
        text(cv, (x0 + 56, y0 + 60), title, font("tilt", 64), (255, 236, 190), glow=GOLD, glow_r=8)
        text(cv, (x0 + 56, y0 + 150), sub, font("lato", 36), CREAM)

    def option(self, cv, box, n, t, s, badge):
        x0, y0, x1, y1 = box
        rrect(cv, box, 22, fill=(18, 8, 10, 255), outline=(70, 26, 30, 255), width=2)
        paste(cv, icon(n, 72, NEED_COL_NEW[n], "neon"), (x0 + 70, (y0 + y1) / 2), center=True)
        text(cv, (x0 + 140, y0 + 40), t, font("lato-b", 44), CREAM)
        text(cv, (x0 + 140, y0 + 100), s, font("lato-r", 32), (196, 173, 162))
        if badge:
            neon_rrect(cv, (x1 - 170, y0 + 54, x1 - 34, y0 + 112), 14, (24, 208, 250), tube=4)
            text(cv, (x1 - 102, y0 + 84), badge, font("tilt", 34), (190, 245, 255), anchor="mm")

    def result(self, cv, W, H):
        box = (60, 470, W - 60, 1470)
        rrect(cv, box, 40, fill=(8, 4, 6, 235))
        neon_rrect(cv, box, 40, NEON, tube=6)
        text(cv, (W / 2, 620), "Neon reached", font("tilt", 104), (255, 225, 215), anchor="mm", glow=NEON, glow_r=16)
        text(cv, (W / 2 - 80, 800), "96", font("tilt", 170), CREAM, anchor="mm", glow=(255, 120, 80), glow_r=6)
        neon_rrect(cv, (W / 2 + 60, 760, W / 2 + 360, 850), 18, GOLD, tube=5)
        text(cv, (W / 2 + 210, 805), "NEW BEST", font("tilt", 44), (255, 240, 200), anchor="mm")
        text(cv, (W / 2, 950), "+12 over your best · you beat Ty (92)", font("lato-b", 38), GOLD, anchor="mm")
        paste(cv, icon("nightlife", 78, NEED_COL_NEW["nightlife"], "neon"), (150, 1080), center=True)
        rrect(cv, (220, 1072, 820, 1088), 8, fill=(40, 30, 40, 255))
        neon_rrect(cv, (220, 1078, 680, 1082), 2, NEED_COL_NEW["nightlife"], tube=8)
        text(cv, (930, 1080), "+23", font("tilt", 54), (160, 240, 255), anchor="mm")
        self.button(cv, (120, 1220, 510, 1370), "Again", GOLD, fs=52)
        rrect(cv, (570, 1220, 960, 1370), 26, fill=(140, 6, 16, 255))
        self.button(cv, (570, 1220, 960, 1370), "Done", NEON, fill=(140, 6, 16, 255), fs=52)

    def event(self, cv, box, e):
        x0, y0, x1, y1 = box
        date, name, sub, now = e
        rrect(cv, box, 20, fill=(18, 8, 10, 255))
        if now:
            neon_rrect(cv, box, 20, NEON, tube=4)
        text(cv, (x0 + 30, (y0 + y1) / 2), date, font("tilt", 40), (130, 235, 255) if now else (196, 173, 162), anchor="lm")
        text(cv, (x0 + 210, y0 + 26), name, font("lato-b", 40), CREAM)
        text(cv, (x0 + 210, y0 + 80), sub, font("lato-r", 30), (196, 173, 162))


# ======================================================================= D2 BACK-BAR
class BackBar:
    key, name = "d2-backbar", "D2 Back-bar"

    def wood(self, cv, box, r=24, led=True, brass=True):
        x0, y0, x1, y1 = [int(v) for v in box]
        g = vgrad((x1 - x0, y1 - y0), (52, 24, 18, 240), (24, 11, 10, 245))
        m = Image.new("L", g.size, 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, g.width - 1, g.height - 1], radius=r, fill=255)
        g.putalpha(ImageChops.multiply(g.split()[3], m))
        if led:
            glow_rect(cv, (x0 + 14, y1 - 4, x1 - 14, y1 + 6), 4, RED_LED, 12, 230)
        cv.alpha_composite(g, (x0, y0))
        if brass:
            rrect(cv, (x0 + 5, y0 + 5, x1 - 5, y1 - 5), max(4, r - 5), outline=BRASS + (200,), width=2)
        if led:
            rrect(cv, (x0 + 16, y1 - 4, x1 - 16, y1 - 1), 2, fill=(255, 120, 110, 255))

    def button(self, cv, box, label, col=None, ic=None, primary=False, fs=36):
        x0, y0, x1, y1 = box
        if primary:
            g = vgrad((int(x1 - x0), int(y1 - y0)), (196, 22, 34, 255), (110, 6, 14, 255))
            m = Image.new("L", g.size, 0)
            ImageDraw.Draw(m).rounded_rectangle([0, 0, g.width - 1, g.height - 1], radius=26, fill=255)
            g.putalpha(m)
            glow_rect(cv, box, 26, RED_LED, 18, 140)
            cv.alpha_composite(g, (int(x0), int(y0)))
            rrect(cv, (x0 + 4, y0 + 4, x1 - 4, y1 - 4), 22, outline=GOLD + (230,), width=3)
        else:
            self.wood(cv, box, 26, led=False)
        cx = (x0 + x1) / 2
        if ic:
            paste(cv, icon(ic, 50, GOLD, "solid"), (cx, y0 + (y1 - y0) * 0.38), center=True)
            text(cv, (cx, y1 - 20), label, font("lato-b", 26), CREAM, anchor="ms")
        else:
            text(cv, (cx, (y0 + y1) / 2), label, font("lato-b", fs), CREAM if primary else GOLD, anchor="mm")

    def meter_shelf(self, cv, x, y, w, h):
        self.wood(cv, (x - 10, y - 10, x + w + 10, y + h + 10), 20)
        cw = (w - 3 * 10) / 4
        for i, n in enumerate(NEEDS):
            cx0 = x + i * (cw + 10)
            col = NEED_COL_NEW[n]
            # cubby: dark back, backlit fill rising to the meter level, then the icon chip over it
            rrect(cv, (cx0, y, cx0 + cw, y + h), 12, fill=(14, 6, 6, 255))
            fh = (h - 8) * VAL[n]
            lvl = vgrad((int(cw - 8), int(fh)), col + (230,), tuple(int(c * 0.5) for c in col) + (230,))
            m = Image.new("L", lvl.size, 0)
            ImageDraw.Draw(m).rounded_rectangle([0, 0, lvl.width - 1, lvl.height - 1], radius=9, fill=255)
            lvl.putalpha(ImageChops.multiply(lvl.split()[3], m))
            cv.alpha_composite(lvl, (int(cx0 + 4), int(y + h - 4 - fh)))
            rrect(cv, (cx0 + 4, y + h - 4 - fh, cx0 + cw - 4, y + h - 4 - fh + 3), 2, fill=(255, 255, 255, 150))
            ic = icon(n, 70, CREAM, "solid")
            sh = Image.new("RGBA", ic.size, (0, 0, 0, 0))
            sh.putalpha(ic.split()[3].filter(ImageFilter.GaussianBlur(4)))
            paste(cv, sh, (cx0 + cw / 2 + 2, y + h * 0.44 + 3), center=True)
            paste(cv, sh, (cx0 + cw / 2, y + h * 0.44 + 1), center=True)
            paste(cv, ic, (cx0 + cw / 2, y + h * 0.44), center=True)
            if n == "drinks":  # lowest: a pulsing LED edge
                glow_rect(cv, (cx0, y, cx0 + cw, y + h), 12, col, 10, 255, width=6)

    def area(self, cv, box, label, lit=False):
        x0, y0, x1, y1 = box
        self.wood(cv, box, 18, led=lit)
        text(cv, ((x0 + x1) / 2 - 10, (y0 + y1) / 2), label, font("lato-b", 34), GOLD if not lit else CREAM, anchor="mm")
        text(cv, (x1 - 30, (y0 + y1) / 2), "›", font("lato-b", 40), BRASS, anchor="mm")

    def zone(self, cv, xy, s, small="LIVE · song 1 of 4"):
        text(cv, xy, s, font("tilt", 88), (255, 214, 206), glow=NEON, glow_r=11)
        x, y = xy[0], xy[1] + 122
        rrect(cv, (x, y, x + 360, y + 56), 28, fill=(140, 6, 16, 230))
        cv.alpha_composite(Image.new("RGBA", (16, 16), (0, 0, 0, 0)), (0, 0))
        ImageDraw.Draw(cv).ellipse([x + 22, y + 20, x + 38, y + 36], fill=(255, 220, 200, 255))
        text(cv, (x + 54, y + 28), small, font("lato-b", 30), CREAM, anchor="lm")

    def sheet(self, cv, box, title, sub):
        x0, y0, x1, y1 = box
        self.wood(cv, (x0, y0, x1, y1 + 60), 44, led=False)
        glow_rect(cv, (x0 + 40, y0 - 2, x1 - 40, y0 + 4), 3, RED_LED, 14, 255)
        rrect(cv, (x0 + 40, y0, x1 - 40, y0 + 3), 2, fill=(255, 140, 130, 255))
        text(cv, (x0 + 56, y0 + 56), title, font("tilt", 66), (255, 214, 206), glow=NEON, glow_r=9)
        text(cv, (x1 - 56, y0 + 92), "Nam is pouring", font("lato-b", 32), GOLD, anchor="rm")
        text(cv, (x0 + 56, y0 + 160), sub, font("lato", 36), CREAM)

    def option(self, cv, box, n, t, s, badge):
        x0, y0, x1, y1 = box
        rrect(cv, box, 18, fill=(26, 12, 10, 255))
        # backlit cubby holding the icon
        cub = (x0 + 14, y0 + 14, x0 + 14 + (y1 - y0) - 28, y1 - 14)
        g = vgrad((int(cub[2] - cub[0]), int(cub[3] - cub[1])), (255, 70, 60, 255), (120, 8, 18, 255))
        m = Image.new("L", g.size, 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, g.width - 1, g.height - 1], radius=12, fill=255)
        g.putalpha(m)
        glow_rect(cv, cub, 12, RED_LED, 10, 150)
        cv.alpha_composite(g, (int(cub[0]), int(cub[1])))
        paste(cv, icon(n, 74, CREAM, "solid"), ((cub[0] + cub[2]) / 2, (cub[1] + cub[3]) / 2), center=True)
        text(cv, (cub[2] + 30, y0 + 36), t, font("lato-b", 44), CREAM)
        text(cv, (cub[2] + 30, y0 + 98), s, font("lato-r", 31), (205, 180, 165))
        rrect(cv, (x0 + 10, y1 - 3, x1 - 10, y1), 2, fill=BRASS + (120,))
        if badge:
            rrect(cv, (x1 - 170, y0 + 52, x1 - 30, y0 + 112), 12, fill=(60, 40, 18, 255), outline=GOLD + (255,), width=3)
            text(cv, (x1 - 100, y0 + 83), badge, font("lato-b", 32), GOLD, anchor="mm")

    def result(self, cv, W, H):
        box = (60, 470, W - 60, 1470)
        self.wood(cv, box, 40)
        text(cv, (W / 2, 610), "Neon reached", font("tilt", 100), (255, 220, 210), anchor="mm", glow=NEON, glow_r=14)
        text(cv, (W / 2 - 90, 800), "96", font("lato-b", 170), CREAM, anchor="mm", shadow=True)
        rrect(cv, (W / 2 + 40, 755, W / 2 + 360, 850), 12, fill=(70, 46, 18, 255), outline=GOLD + (255,), width=4)
        text(cv, (W / 2 + 200, 803), "NEW BEST", font("lato-b", 44), GOLD, anchor="mm")
        text(cv, (W / 2, 950), "+12 over your best · you beat Ty (92)", font("lato-b", 38), GOLD, anchor="mm")
        paste(cv, chip_solid("nightlife", 96), (150, 1085), center=True)
        rrect(cv, (220, 1062, 840, 1108), 23, fill=(14, 6, 6, 255), outline=BRASS + (200,), width=2)
        lvl = vgrad((int(600 * 0.62), 38), NEED_COL_NEW["nightlife"] + (255,), (10, 120, 160, 255))
        m = Image.new("L", lvl.size, 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, lvl.width - 1, lvl.height - 1], radius=19, fill=255)
        lvl.putalpha(m)
        cv.alpha_composite(lvl, (224, 1066))
        text(cv, (935, 1085), "+23", font("lato-b", 50), NEED_COL_NEW["nightlife"], anchor="mm")
        self.button(cv, (120, 1220, 510, 1370), "Again", fs=52)
        self.button(cv, (570, 1220, 960, 1370), "Done", primary=True, fs=52)

    def event(self, cv, box, e):
        x0, y0, x1, y1 = box
        date, name, sub, now = e
        self.wood(cv, box, 18, led=now)
        rrect(cv, (x0 + 16, y0 + 16, x0 + 170, y1 - 16), 10, fill=(140, 6, 16, 255) if now else (40, 20, 16, 255))
        d, n = date.split()
        text(cv, (x0 + 93, y0 + 44), d, font("lato-b", 28), GOLD, anchor="mm")
        text(cv, (x0 + 93, y0 + 92), n, font("lato-b", 46), CREAM, anchor="mm")
        text(cv, (x0 + 200, y0 + 28), name, font("lato-b", 40), CREAM)
        text(cv, (x0 + 200, y0 + 82), sub, font("lato-r", 30), (205, 180, 165))


# ======================================================================= D3 GIG POSTER
class Poster:
    key, name = "d3-poster", "D3 Gig Poster"

    def paper(self, cv, box, col=(24, 21, 21), mask=None, alpha=245, seed=1):
        x0, y0, x1, y1 = [int(v) for v in box]
        W, H = x1 - x0, y1 - y0
        base = Image.new("RGBA", (W, H), col + (alpha,))
        n = grain((W, H), seed, 14).convert("L")
        tex = Image.merge("RGBA", [ImageChops.add(base.split()[i], n.point(lambda v: max(0, v - 128)) ) for i in range(3)] + [base.split()[3]])
        if mask is None:
            mask = Image.new("L", (W, H), 0)
            ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], radius=6, fill=255)
        tex.putalpha(ImageChops.multiply(tex.split()[3], mask))
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        sh.putalpha(mask.filter(ImageFilter.GaussianBlur(10)).point(lambda v: v * 150 // 255))
        cv.alpha_composite(sh, (x0 + 6, y0 + 10))
        cv.alpha_composite(tex, (x0, y0))

    def button(self, cv, box, label, ic=None, primary=False, fs=44):
        x0, y0, x1, y1 = [int(v) for v in box]
        col = POSTER_RED if primary else PAPER
        self.paper(cv, box, col, ticket_mask(x1 - x0, y1 - y0), seed=x0 + y0)
        ink = PAPER if primary else (24, 21, 21)
        cx = (x0 + x1) / 2
        if ic:
            paste(cv, icon(ic, 50, ink, "solid"), (cx, y0 + (y1 - y0) * 0.38), center=True)
            text(cv, (cx, y1 - 16), label.upper(), font("bebas", 34), ink, anchor="ms")
        else:
            text(cv, (cx, (y0 + y1) / 2 + 4), label.upper(), font("bebas", fs), ink, anchor="mm")

    def meter(self, cv, x, y, w, h, n):
        col = NEED_COL_NEW[n]
        self.paper(cv, (x, y, x + w, y + h), PAPER, ticket_mask(int(w), int(h), notch=10), seed=int(x))
        paste(cv, icon(n, 66, (24, 21, 21), "solid"), (x + w / 2, y + h * 0.40), center=True)
        bx0, bx1, by = x + 16, x + w - 16, y + h - 26
        ImageDraw.Draw(cv).rectangle([bx0, by - 7, bx1, by + 7], fill=(24, 21, 21, 255))
        ImageDraw.Draw(cv).rectangle([bx0 + 3, by - 4, bx0 + 3 + (bx1 - bx0 - 6) * VAL[n], by + 4], fill=col + (255,))

    def area(self, cv, box, label, lit=False, idx=0):
        x0, y0, x1, y1 = box
        if idx == 0:
            pass
        num = "%02d" % (idx + 1)
        if lit:
            ImageDraw.Draw(cv).rectangle([x0, y0 + 8, x1, y1 - 8], fill=POSTER_RED + (255,))
        text(cv, (x0 + 18, (y0 + y1) / 2 + 3), num, font("bebas", 34), (24, 21, 21) if lit else POSTER_RED, anchor="lm")
        text(cv, (x0 + 70, (y0 + y1) / 2 + 3), label.upper(), font("bebas", 46), PAPER if lit else (24, 21, 21), anchor="lm")

    def setlist(self, cv, x0, y0, x1, n=7, step=86, lit=4):
        self.paper(cv, (x0, y0, x1, y0 + 90 + n * step), PAPER, seed=7)
        text(cv, ((x0 + x1) / 2, y0 + 50), "SET LIST", font("bebas", 44), POSTER_RED, anchor="mm")
        ImageDraw.Draw(cv).line([x0 + 16, y0 + 82, x1 - 16, y0 + 82], fill=(24, 21, 21, 255), width=3)
        for i, a in enumerate(AREAS[:n]):
            self.area(cv, (x0 + 4, y0 + 90 + i * step, x1 - 4, y0 + 90 + (i + 1) * step), a, lit=(i == lit), idx=i)

    def zone(self, cv, xy, s, small="LIVE · song 1 of 4"):
        x, y = xy
        text(cv, (x + 6, y + 6), s.upper(), font("bebas", 130), POSTER_RED)
        text(cv, (x, y), s.upper(), font("bebas", 130), PAPER)
        stamp(cv, (x + 190, y + 190), small.upper(), font("bebas", 44), PAPER, angle=-4)

    def sheet(self, cv, box, title, sub):
        x0, y0, x1, y1 = box
        self.paper(cv, (x0, y0, x1, y1 + 60), (24, 21, 21), seed=11)
        text(cv, (x0 + 56, y0 + 40), title.upper(), font("bebas", 110), PAPER)
        text(cv, (x0 + 56 + 330, y0 + 70), "TONIGHT ON THE TAPS: NAM", font("bebas", 40), POSTER_RED)
        text(cv, (x0 + 56, y0 + 168), sub, font("lato", 36), PAPER)

    def option(self, cv, box, n, t, s, badge, idx=0):
        x0, y0, x1, y1 = box
        d = ImageDraw.Draw(cv)
        for xx in range(int(x0), int(x1), 18):
            d.rectangle([xx, y1 - 3, xx + 8, y1], fill=(110, 100, 95, 255))
        paste(cv, chip_solid(n, 104, NEED_COL_NEW[n]), (x0 + 60, (y0 + y1) / 2), center=True)
        text(cv, (x0 + 140, y0 + 30), t.upper(), font("bebas", 64), PAPER)
        text(cv, (x0 + 140, y0 + 106), s, font("lato-r", 31), (200, 190, 180))
        if badge:
            stamp(cv, (x1 - 110, y0 + 80), badge, font("bebas", 50), POSTER_RED, angle=8)

    def result(self, cv, W, H):
        t = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.paper(t, (90, 520, W - 90, 1420), PAPER, ticket_mask(W - 180, 900, notch=46), seed=5)
        text(t, (W / 2, 640), "NEON MOTH · CABINET", font("bebas", 48), (24, 21, 21), anchor="mm")
        ImageDraw.Draw(t).line([160, 680, W - 160, 680], fill=(24, 21, 21, 255), width=3)
        text(t, (W / 2 - 60, 830), "96", font("bebas", 260), (24, 21, 21), anchor="mm")
        text(t, (W / 2, 1000), "+12 over your best · you beat Ty (92)", font("lato-b", 36), (24, 21, 21), anchor="mm")
        paste(t, icon("nightlife", 70, (24, 21, 21), "solid"), (190, 1090), center=True)
        d = ImageDraw.Draw(t)
        d.rectangle([250, 1076, 830, 1104], fill=(24, 21, 21, 255))
        d.rectangle([254, 1080, 254 + 572 * 0.62, 1100], fill=NEED_COL_NEW["nightlife"] + (255,))
        text(t, (900, 1092), "+23", font("bebas", 64), (24, 21, 21), anchor="mm")
        for xx in range(150, W - 150, 26):
            d.rectangle([xx, 1170, xx + 12, 1176], fill=(24, 21, 21, 120))
        t = t.rotate(-2.5, resample=Image.BICUBIC, center=(W / 2, 970))
        cv.alpha_composite(t)
        stamp(cv, (W / 2 + 230, 760), "NEW BEST", font("bebas", 80), POSTER_RED, angle=-12)
        stamp(cv, (W / 2, 560), "NEON REACHED", font("bebas", 96), POSTER_RED, angle=-3, box=False)
        self.button(cv, (130, 1270, 510, 1410), "Again", fs=60)
        self.button(cv, (570, 1270, 950, 1410), "Done", primary=True, fs=60)

    def event(self, cv, box, e):
        x0, y0, x1, y1 = box
        date, name, sub, now = e
        d = ImageDraw.Draw(cv)
        text(cv, (x0 + 10, (y0 + y1) / 2 + 4), date, font("bebas", 54), POSTER_RED if now else PAPER, anchor="lm")
        text(cv, (x0 + 190, y0 + 14), name.upper(), font("bebas", 60), PAPER)
        text(cv, (x0 + 190, y0 + 78), sub, font("lato-r", 28), (200, 190, 180))
        for xx in range(int(x0), int(x1), 18):
            d.rectangle([xx, y1 - 3, xx + 8, y1], fill=(110, 100, 95, 255))
        if now:
            stamp(cv, (x1 - 120, (y0 + y1) / 2), "TONIGHT", font("bebas", 44), POSTER_RED, angle=-6)


# ======================================================================= screens
def top_hud(cv, D, W, land=False):
    scrim(cv, 420 if not land else 260)
    y, h = (60, 150) if not land else (36, 140)
    if isinstance(D, Neon):
        D.button(cv, (36, y, 186, y + h), "Leave", NEON, ic="door")
        x = 214 if not land else 230
        for i, n in enumerate(NEEDS):
            D.meter(cv, x + i * 160, y, 146, h, n)
        D.button(cv, (W - 186, y, W - 36, y + h), "Tonight", GOLD, ic="ticket")
    elif isinstance(D, BackBar):
        D.button(cv, (36, y, 186, y + h), "Leave", ic="door")
        x = 226 if not land else 240
        D.meter_shelf(cv, x, y + 6, 4 * 140 + 30, h - 12)
        D.button(cv, (W - 186, y, W - 36, y + h), "Tonight", ic="ticket")
    else:
        D.button(cv, (36, y, 186, y + h), "Leave", ic="door")
        x = 214 if not land else 230
        for i, n in enumerate(NEEDS):
            D.meter(cv, x + i * 160, y, 146, h, n)
        D.button(cv, (W - 186, y, W - 36, y + h), "Tonight", ic="ticket")


def portrait_hud(D):
    W, H = 1080, 1920
    cv = venue_portrait()
    top_hud(cv, D, W)
    D.zone(cv, (40, 250), "The Bar")
    if isinstance(D, Poster):
        D.setlist(cv, 816, 470, 1050, n=6, step=78, lit=4)
    else:
        for i, a in enumerate(AREAS[:5]):
            D.area(cv, (800, 520 + i * 112, 1046, 610 + i * 112), a, lit=(a == "Bar"))
    D.sheet(cv, (0, 1060, W, H), "The Bar", "Evening! What are we having?")
    for i, (n, t, s, b) in enumerate(OPTIONS[:3]):
        D.option(cv, (40, 1290 + i * 200, W - 40, 1470 + i * 200), n, t, s, b)
    label(cv, D, W, H)
    cv.convert("RGB").save(OUT + f"{D.key}-portrait-hud.png")
    return cv


def portrait_result(D):
    W, H = 1080, 1920
    cv = game_bg()
    D.result(cv, W, H)
    label(cv, D, W, H)
    cv.convert("RGB").save(OUT + f"{D.key}-portrait-result.png")


def landscape(D):
    W, H = 1920, 1080
    cv = venue_landscape()
    top_hud(cv, D, 1180, land=True)
    D.zone(cv, (40, 210), "Candle Floor")
    # Tonight sheet as a right-side panel
    x0 = 1180
    if isinstance(D, Neon):
        rrect(cv, (x0, 12, W - 8, H - 8), 36, fill=(8, 4, 6, 240))
        neon_rrect(cv, (x0, 12, W - 8, H - 8), 36, GOLD, tube=4, glow=0.6)
        text(cv, (x0 + 50, 60), "Tonight", font("tilt", 86), (255, 236, 190), glow=GOLD, glow_r=10)
    elif isinstance(D, BackBar):
        D.wood(cv, (x0, 12, W - 8, H - 8), 36)
        text(cv, (x0 + 50, 56), "Tonight", font("tilt", 86), (255, 214, 206), glow=NEON, glow_r=10)
    else:
        D.paper(cv, (x0, 12, W - 8, H - 8), (24, 21, 21), seed=21)
        text(cv, (x0 + 50, 40), "TONIGHT AT", font("bebas", 60), POSTER_RED)
        text(cv, (x0 + 50, 96), "BLACK CABIN", font("bebas", 120), PAPER)
    yy = 250 if not isinstance(D, Poster) else 260
    for i, e in enumerate(EVENTS):
        D.event(cv, (x0 + 40, yy + i * 190, W - 60, yy + i * 190 + 160), e)
    label(cv, D, W, H)
    cv.convert("RGB").save(OUT + f"{D.key}-landscape.png")


def label(cv, D, W, H):
    s = f"{D.name} · mock-up, not a game capture"
    f = font("lato-b", 24)
    bb = ImageDraw.Draw(cv).textbbox((0, 0), s, font=f)
    rrect(cv, (W - bb[2] - 40, H - 52, W - 12, H - 12), 12, fill=(0, 0, 0, 200))
    text(cv, (W - 26, H - 32), s, f, (230, 220, 210), anchor="rm")


def overview(huds):
    W, H = 3 * 720 + 4 * 30, 1280 + 170
    cv = Image.new("RGBA", (W, H), (16, 8, 9, 255))
    for i, (D, im) in enumerate(huds):
        sm = im.convert("RGB").resize((720, 1280), Image.LANCZOS).convert("RGBA")
        x = 30 + i * 750
        cv.alpha_composite(sm, (x, 140))
        text(cv, (x, 40), D.name + (" (rec)" if isinstance(D, BackBar) else ""), font("lato-b", 56), GOLD)
    cv.convert("RGB").save(OUT + "directions-overview.png")


if __name__ == "__main__":
    huds = []
    for D in (Neon(), BackBar(), Poster()):
        huds.append((D, portrait_hud(D)))
        portrait_result(D)
        landscape(D)
    overview(huds)
    print("ok")
