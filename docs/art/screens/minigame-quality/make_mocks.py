# Design mock-ups for docs/design/11-minigame-quality.md. Drawings in PIL, not game captures.
import sys, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops, ImageEnhance

ROOT = r"H:\My Drive\PROJECTS\Black Cabin Tamagotchi"
OUT = os.path.join(ROOT, r"docs\art\screens\minigame-quality")
os.makedirs(OUT, exist_ok=True)
F = os.path.join(ROOT, r"game\assets\fonts")
def font(name, size): return ImageFont.truetype(os.path.join(F, name), size)
LATO_B = lambda s: font("Lato-Bold.ttf", s)
LATO_K = lambda s: font("Lato-Black.ttf", s)
LATO = lambda s: font("Lato-Regular.ttf", s)
KRISTI = lambda s: font("Kristi-Regular.ttf", s)

C = dict(bg="#120607", deep="#160A0C", raised="#2E1614", line="#4A2A24", cream="#F6EBDD", smoke="#C4ADA2",
         ash="#A8907F", red="#8C0610", redhi="#D0161C", neon="#FF2A14", amber="#FF8A30", gold="#FFDD78", cyan="#18D0FA")
def rgb(h, a=255):
    h = h.lstrip("#"); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

W, H = 540, 960
lounge = Image.open(os.path.join(ROOT, r"docs\art\screens\lounge-followup\portrait-lounge.png")).convert("RGB")
sign_crop = lounge.crop((548, 490, 812, 668))  # the real voxel BLACK CABIN neon from the live build

def glow_layer(size):
    return Image.new("RGBA", size, (0, 0, 0, 0))

def add_glow(base, layer, radius, strength=1.0):
    g = layer.filter(ImageFilter.GaussianBlur(radius))
    if strength != 1.0:
        r, gg, b, a = g.split(); a = a.point(lambda v: min(255, int(v * strength))); g = Image.merge("RGBA", (r, gg, b, a))
    base.alpha_composite(g)

def voxel_box(d, x, y, w, h, face, top=None, side=None, edge=None):
    top = top or tuple(min(255, int(c * 1.35)) for c in face[:3]) + (255,)
    side = side or tuple(int(c * 0.6) for c in face[:3]) + (255,)
    d.rectangle([x, y, x + w, y + h], fill=face)
    d.rectangle([x, y, x + w, y + 5], fill=top)
    d.rectangle([x + w - 6, y, x + w, y + h], fill=side)
    if edge: d.rectangle([x, y, x + w, y + h], outline=edge, width=2)

MOTH = [  # 13 x 9 pixel moth, wings up; . empty, c cream, k body, s spot, e eye, a antenna
    "..a.......a..",
    "...a.....a...",
    "cc..a...a..cc",
    "cccc.kek.cccc",
    "ccscckkkccscc",
    ".cccckkkcccc.",
    "..ccc.k.ccc..",
    "...c..k..c...",
    "......k......",
]
PAL = {"c": (232, 214, 188, 255), "k": (120, 92, 76, 255), "s": (140, 6, 16, 255), "e": (255, 42, 20, 255), "a": (246, 235, 221, 255)}

def draw_moth(img, cx, cy, px=5, alpha=255, outline_only=False):
    d = ImageDraw.Draw(img)
    w, h = len(MOTH[0]) * px, len(MOTH) * px
    x0, y0 = cx - w // 2, cy - h // 2
    for j, row in enumerate(MOTH):
        for i, ch in enumerate(row):
            if ch == ".": continue
            col = PAL[ch]
            if outline_only: col = (246, 235, 221, alpha)
            else: col = col[:3] + (alpha,)
            d.rectangle([x0 + i * px, y0 + j * px, x0 + (i + 1) * px - 1, y0 + (j + 1) * px - 1], fill=col)
            if not outline_only and ch in "ck":  # voxel shading: darker bottom edge per block
                d.line([x0 + i * px, y0 + (j + 1) * px - 1, x0 + (i + 1) * px - 1, y0 + (j + 1) * px - 1],
                       fill=tuple(int(c * 0.7) for c in col[:3]) + (alpha,))

def header(img, title="Neon Moth"):
    d = ImageDraw.Draw(img)
    d.ellipse([22, 45, 88, 111], fill=rgb(C["deep"]), outline=rgb(C["line"]), width=2)
    d.text((55, 78), "II", font=LATO_B(20), fill=rgb(C["cream"]), anchor="mm")
    d.text((270, 78), title, font=LATO_B(34), fill=rgb(C["redhi"]), anchor="mm")
    d.arc([466, 52, 512, 100], 60, 300, fill=rgb(C["cyan"]), width=9)

def target_play():
    img = Image.new("RGBA", (W, H), rgb(C["bg"]))
    # far layer: the real lounge, blurred and dark (parallax back wall)
    bgl = lounge.crop((0, 420, 1080, 1920)).resize((W, int(W * 1500 / 1080)))
    bgl = bgl.filter(ImageFilter.GaussianBlur(7))
    bgl = ImageEnhance.Brightness(bgl).enhance(0.28)
    bgl = bgl.crop((0, 0, W, 800)).convert("RGBA")
    img.alpha_composite(bgl, (0, 150))
    d = ImageDraw.Draw(img)
    # vignette
    vig = Image.new("L", (W, H), 0); vd = ImageDraw.Draw(vig)
    vd.rectangle([40, 190, W - 40, H - 40], fill=255); vig = vig.filter(ImageFilter.GaussianBlur(60))
    dark = Image.new("RGBA", (W, H), (8, 2, 3, 255)); img = Image.composite(img, dark, vig).convert("RGBA")
    d = ImageDraw.Draw(img)
    glow = glow_layer((W, H)); gd = ImageDraw.Draw(glow)
    # gates: bulb strings + voxel speaker stacks
    def gate(gx, top, bot, passed=False, dim=False):
        for c in range(3):
            x = gx + 15 + c * 30
            d.line([x, 150, x, top - 12], fill=(58, 34, 24, 255), width=3)
            y = top - 14
            while y > 170:
                col = (255, 221, 120, 255)
                d.rectangle([x - 6, y - 6, x + 6, y + 6], fill=col)
                d.rectangle([x - 6, y + 2, x + 6, y + 6], fill=(220, 160, 70, 255))
                gd.ellipse([x - 16, y - 16, x + 16, y + 16], fill=(255, 190, 90, 150))
                y -= 40
        voxel_box(d, gx, top - 12, 90, 10, (74, 42, 36, 255))
        h = 940 - bot; n = max(1, h // 110); bh = h / n
        for b in range(n):
            yy = bot + b * bh
            voxel_box(d, gx, int(yy), 90, int(bh) - 5, (46, 22, 20, 255), edge=(74, 42, 36, 255))
            cx, cy = gx + 42, int(yy + bh / 2)
            for r, col in ((26, (18, 8, 8)), (18, (40, 24, 22)), (8, (18, 8, 8))):
                d.rectangle([cx - r, cy - r, cx + r, cy + r], fill=col + (255,))
            d.rectangle([gx + 74, int(yy) + 10, gx + 79, int(yy) + 15], fill=rgb(C["neon"]))
            gd.ellipse([gx + 66, int(yy) + 2, gx + 87, int(yy) + 23], fill=(255, 42, 20, 120))
        if passed:
            gd.ellipse([gx + 25, (top + bot) // 2 - 20, gx + 65, (top + bot) // 2 + 20], fill=(255, 221, 120, 160))
    gate(62, 380, 640, passed=True)
    gate(330, 300, 560)
    # the real neon sign entering on the right edge
    s = sign_crop.resize((220, 148)).convert("RGBA")
    sg = glow_layer((W, H)); sg.alpha_composite(s, (440, 620)); add_glow(img, sg, 18, 1.6)
    img.alpha_composite(s, (440, 620))
    add_glow(img, glow, 10, 1.2)
    d = ImageDraw.Draw(img)
    # ember trail
    random.seed(4)
    tr = glow_layer((W, H)); td = ImageDraw.Draw(tr)
    for k in range(22):
        t = k / 22
        x = 230 - k * 9 + random.uniform(-4, 4); y = 505 + (k ** 1.6) * 0.9 + random.uniform(-6, 6)
        sz = 6 - int(t * 4); a = int(255 * (1 - t))
        td.rectangle([x, y, x + sz, y + sz], fill=(255, 138, 48, a))
    add_glow(img, tr, 4); img.alpha_composite(tr)
    # ghost of your best run
    gh = glow_layer((W, H)); draw_moth(gh, 300, 470, px=5, alpha=90, outline_only=True); img.alpha_composite(gh)
    d = ImageDraw.Draw(img)
    d.text((300, 430), "your best", font=LATO_B(15), fill=(246, 235, 221, 140), anchor="mm")
    # the moth, with a warm halo
    hal = glow_layer((W, H)); ImageDraw.Draw(hal).ellipse([200, 460, 290, 540], fill=(255, 190, 110, 110)); add_glow(img, hal, 16)
    draw_moth(img, 245, 500, px=5)
    d = ImageDraw.Draw(img)
    # pass pop + combo
    d.text((150, 470), "+1", font=LATO_K(30), fill=rgb(C["gold"]), anchor="mm")
    d.text((270, 610), "CLEAN x6", font=LATO_K(30), fill=rgb(C["gold"]), anchor="mm")
    d.text((270, 642), "no wing touched since gate 3", font=LATO_B(15), fill=rgb(C["smoke"]), anchor="mm")
    # header + HUD
    header(img); d = ImageDraw.Draw(img)
    # 15 gate pips with tonight's best marker
    for i in range(15):
        x = 60 + i * 28
        fill = rgb(C["gold"]) if i < 9 else rgb(C["line"])
        d.rectangle([x, 128, x + 20, 140], fill=fill)
    mx = 60 + 13 * 28 - 4
    d.polygon([(mx, 146), (mx - 7, 158), (mx + 7, 158)], fill=rgb(C["cyan"]))
    d.text((mx, 172), "Tt tonight: 13", font=LATO_B(15), fill=rgb(C["cyan"]), anchor="mm")
    d.text((60, 172), "gate 9 of 15", font=LATO_B(15), fill=rgb(C["smoke"]), anchor="lm")
    for k in range(3):  # wings left as mini moths
        draw_moth(img, 40 + k * 40, 215, px=2, alpha=255 if k < 2 else 70)
    return img

def today(path):
    return Image.open(os.path.join(ROOT, path)).convert("RGBA").resize((W, H))

def callouts(img, pts):
    d = ImageDraw.Draw(img)
    for n, (x, y) in enumerate(pts, 1):
        d.ellipse([x - 13, y - 13, x + 13, y + 13], fill=rgb(C["cyan"]), outline=(0, 0, 0, 255), width=2)
        d.text((x, y), str(n), font=LATO_K(16), fill=(0, 0, 0, 255), anchor="mm")

def two_up(left, right, ltitle, rtitle, legend, name):
    pad, top = 24, 70
    leg_h = 34 + 26 * len(legend)
    out = Image.new("RGBA", (W * 2 + pad * 3, H + top + leg_h + pad), rgb("#0B0405"))
    d = ImageDraw.Draw(out)
    d.text((pad, 24), ltitle, font=LATO_B(24), fill=rgb(C["smoke"]))
    d.text((W + pad * 2, 24), rtitle, font=LATO_B(24), fill=rgb(C["gold"]))
    out.alpha_composite(left, (pad, top)); out.alpha_composite(right, (W + pad * 2, top))
    y = top + H + 20
    for n, line in enumerate(legend, 1):
        d.text((pad, y), f"{n}  {line}", font=LATO(19), fill=rgb(C["cream"])); y += 26
    out.convert("RGB").save(os.path.join(OUT, name), quality=90)
    print("wrote", name, out.size)

def target_result(play):
    img = play.copy()
    img.alpha_composite(Image.new("RGBA", (W, H), (22, 10, 12, 215)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([22, 200, 518, 820], 24, fill=rgb("#1C0D0C"), outline=rgb(C["line"]), width=2)
    d.text((48, 260), "Neon reached", font=KRISTI(64), fill=rgb(C["gold"]), anchor="lm")
    # tier stamp
    st = Image.new("RGBA", (190, 70), (0, 0, 0, 0)); sd = ImageDraw.Draw(st)
    sd.rounded_rectangle([2, 2, 186, 66], 10, outline=rgb(C["neon"]), width=5)
    sd.text((94, 35), "GREAT", font=LATO_K(36), fill=rgb(C["neon"]), anchor="mm")
    st = st.rotate(-8, expand=True, resample=Image.BICUBIC)
    sg = glow_layer((W, H)); sg.alpha_composite(st, (318, 210)); add_glow(img, sg, 8); img.alpha_composite(st, (318, 210))
    d = ImageDraw.Draw(img)
    d.text((48, 345), "84", font=LATO_K(84), fill=rgb(C["cream"]), anchor="lm")
    d.rounded_rectangle([170, 318, 330, 352], 8, fill=rgb(C["gold"]))
    d.text((250, 335), "NEW BEST +12", font=LATO_K(18), fill=(30, 10, 10, 255), anchor="mm")
    d.text((172, 372), "was 72 · 13 gates + the sign", font=LATO_B(16), fill=rgb(C["smoke"]), anchor="lm")
    # gates strip
    for i in range(15):
        x = 48 + i * 29
        d.rectangle([x, 410, x + 22, 424], fill=rgb(C["gold"]) if i < 13 else rgb(C["line"]))
    # tonight's best target
    d.text((48, 460), "Tonight's cabinet board: Tt 92 (same lounge for all)", font=LATO_B(17), fill=rgb(C["cyan"]), anchor="lm")
    d.rounded_rectangle([48, 482, 492, 498], 8, fill=rgb(C["line"]))
    d.rounded_rectangle([48, 482, 48 + int(444 * 0.84), 498], 8, fill=rgb(C["cyan"]))
    tx = 48 + int(444 * 0.92); d.rectangle([tx - 2, 474, tx + 2, 506], fill=rgb(C["gold"]))
    d.text((tx, 520), "Tt 92 · 8 short", font=LATO_B(15), fill=rgb(C["gold"]), anchor="mm")
    # streak + need
    d.text((48, 560), "Night streak: 3", font=LATO_B(20), fill=rgb(C["amber"]), anchor="lm")
    for k in range(7):
        x = 230 + k * 36
        d.rectangle([x, 549, x + 24, 571], fill=rgb(C["amber"]) if k < 3 else rgb(C["line"]))
    d.text((48, 620), "Nightlife", font=LATO_B(18), fill=rgb(C["smoke"]), anchor="lm")
    d.rounded_rectangle([150, 612, 430, 628], 8, fill=rgb(C["line"]))
    d.rounded_rectangle([150, 612, 405, 628], 8, fill=rgb(C["cyan"]))
    d.text((490, 620), "+19", font=LATO_B(20), fill=rgb(C["cyan"]), anchor="rm")
    d.rounded_rectangle([48, 680, 260, 760], 18, fill=rgb(C["raised"]), outline=rgb(C["line"]), width=2)
    d.text((154, 708), "Again", font=LATO_B(24), fill=rgb(C["gold"]), anchor="mm")
    d.text((154, 738), "2 tries left", font=LATO(15), fill=rgb(C["smoke"]), anchor="mm")
    d.rounded_rectangle([280, 680, 492, 760], 18, fill=rgb(C["red"]))
    d.text((386, 720), "Done", font=LATO_B(24), fill=rgb(C["cream"]), anchor="mm")
    return img

def art_options():
    S = 360
    pans = []
    # A polished flat neon (today's draw code + glow, particles, better shapes)
    a = Image.new("RGBA", (S, S), rgb(C["bg"])); ad = ImageDraw.Draw(a); g = glow_layer((S, S)); gd = ImageDraw.Draw(g)
    for c in range(3):
        x = 140 + c * 26; ad.line([x, 0, x, 120], fill=(58, 34, 24, 255), width=3)
        for y in range(20, 120, 34):
            ad.ellipse([x - 6, y - 6, x + 6, y + 6], fill=rgb(C["gold"])); gd.ellipse([x - 14, y - 14, x + 14, y + 14], fill=(255, 200, 100, 140))
    ad.rounded_rectangle([128, 230, 214, 360], 8, fill=(35, 18, 18, 255), outline=rgb(C["line"]), width=3)
    ad.ellipse([146, 270, 196, 320], outline=rgb(C["ash"]), width=3)
    add_glow(a, g, 8); ad = ImageDraw.Draw(a)
    c0 = (80, 180)
    ad.polygon([(80, 178), (52, 152), (56, 196)], fill=(217, 196, 168, 255)); ad.polygon([(84, 178), (108, 150), (112, 194)], fill=(232, 214, 188, 255))
    ad.ellipse([70, 170, 92, 192], fill=(168, 144, 127, 255))
    pans.append((a, "A  Polished flat neon", "today's 2D draw + glow, particles, juice", "S per game"))
    # B voxel sprites pre-rendered from the Blender kit (simulated here with pixel blocks)
    b = Image.new("RGBA", (S, S), rgb(C["bg"])); bd = ImageDraw.Draw(b); g = glow_layer((S, S)); gd = ImageDraw.Draw(g)
    for c in range(3):
        x = 140 + c * 26; bd.line([x, 0, x, 120], fill=(58, 34, 24, 255), width=3)
        for y in range(20, 120, 34):
            bd.rectangle([x - 6, y - 6, x + 6, y + 6], fill=rgb(C["gold"])); bd.rectangle([x - 6, y + 2, x + 6, y + 6], fill=(220, 160, 70, 255))
            gd.ellipse([x - 14, y - 14, x + 14, y + 14], fill=(255, 200, 100, 140))
    voxel_box(bd, 128, 230, 86, 130, (46, 22, 20, 255), edge=(74, 42, 36, 255))
    for r, col in ((24, (18, 8, 8)), (16, (40, 24, 22)), (7, (18, 8, 8))):
        bd.rectangle([167 - r, 295 - r, 167 + r, 295 + r], fill=col + (255,))
    add_glow(b, g, 8); draw_moth(b, 82, 180, px=4)
    pans.append((b, "B  Voxel sprites", "rendered once from Blender, drawn as 2D", "M per game"))
    # C real 3D: the game inside the venue's own 3D scene (crop of the live lounge)
    c = lounge.crop((240, 430, 790, 980)).resize((S, S)).convert("RGBA")
    c = ImageEnhance.Brightness(c).enhance(0.8); draw_moth(c, 120, 230, px=4)
    pans.append((c, "C  Real 3D in the venue", "a 3D minigame scene, venue camera", "L per game, GPU risk"))
    pad = 20
    out = Image.new("RGBA", (S * 3 + pad * 4, S + 150), rgb("#0B0405")); d = ImageDraw.Draw(out)
    for i, (p, t, s1, s2) in enumerate(pans):
        x = pad + i * (S + pad)
        out.alpha_composite(p, (x, pad))
        d.text((x, S + pad + 14), t, font=LATO_B(22), fill=rgb(C["gold"]))
        d.text((x, S + pad + 46), s1, font=LATO(17), fill=rgb(C["cream"]))
        d.text((x, S + pad + 72), s2, font=LATO_B(17), fill=rgb(C["smoke"]))
    d.text((pad, S + pad + 104), "Mock-up drawings, not game captures. C uses a crop of the live lounge capture.", font=LATO(15), fill=rgb(C["ash"]))
    out.convert("RGB").save(os.path.join(OUT, "art-options-a-b-c.jpg"), quality=90); print("wrote art options", out.size)

play = target_play()
play_annot = play.copy()
callouts(play_annot, [(118, 330), (250, 545), (300, 405), (500, 140), (165, 600), (470, 610)])
two_up(today(r"docs\art\screens\minigame-next\build-neon_moth-play.png"), play_annot,
       "TODAY  v0.3.0 capture", "TARGET  mock-up (drawing, not a capture)",
       ["Voxel bulbs and speaker stacks with glow (baked glow sprites), the lounge blurred behind",
        "Ember trail + wing-beat squash: every tap is seen",
        "Ghost of your best run flies beside you",
        "Gate pips with tonight's regular to beat (offline: a seeded cast score; T2: real players)",
        "Combo: CLEAN x6 counts gates since the last singe, +1 pops on each gate",
        "The real BLACK CABIN neon from the venue is the goal, glowing as you near it"],
       "neon-moth-today-vs-target.jpg")
two_up(today(r"docs\art\screens\minigame-next\build-neon_moth-result.png"), target_result(play),
       "TODAY  result card", "TARGET  result moment (mock-up)",
       ["Tier stamp slams in (GREAT / PERFECT), small shake + haptic tick",
        "Score counts up; NEW BEST ribbon with the gain over the old best",
        "Tonight's cabinet board: the regular to beat on tonight's seed (real players after T2)",
        "Night streak: Bangkok nights in a row with a good-or-better round (option, his call)",
        "Again shows the tries left (3 per visit, 06-stakes 7.2 unchanged)"],
       "result-today-vs-target.jpg")
play.convert("RGB").save(os.path.join(OUT, "neon-moth-target-clean.png"))
art_options()
