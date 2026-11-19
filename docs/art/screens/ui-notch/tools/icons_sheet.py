import sys
sys.path.insert(0, __file__.rsplit("\\", 1)[0].rsplit("/", 1)[0])
from uikit import *

REPO = r"H:/My Drive/PROJECTS/Black Cabin Tamagotchi/"
OUT = REPO + "docs/art/screens/ui-notch/"


def chip_solid(need, size, col=None):
    col = col or NEED_COL_NEW[need]
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    S = 4
    big = Image.new("RGBA", (size * S, size * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.ellipse([0, 0, size * S - 1, size * S - 1], fill=col + (255,))
    big = big.resize((size, size), Image.LANCZOS)
    im.alpha_composite(big)
    ic = icon(need, int(size * 0.66), INK, "solid")
    paste(im, ic, (size / 2, size / 2 + size * 0.01), center=True)
    return im


def chip_neon(need, size):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ic = icon(need, int(size * 0.62), NEED_COL_NEW[need], "neon")
    paste(im, ic, (size / 2, size / 2), center=True)
    return im


def chip_voxel(need, size):
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    S = 3
    big = Image.new("RGBA", (size * S, size * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    d.rounded_rectangle([0, 0, size * S - 1, size * S - 1], radius=int(size * S * 0.18), fill=(30, 14, 14, 255), outline=NEED_COL_NEW[need] + (255,), width=int(size * S * 0.05))
    im.alpha_composite(big.resize((size, size), Image.LANCZOS))
    ic = icon(need, int(size * 0.66), NEED_COL_NEW[need], "voxel")
    paste(im, ic, (size / 2, size / 2), center=True)
    return im


CHIPS = {"I1": chip_solid, "I2": chip_neon, "I3": chip_voxel}


def main():
    W, H = 1080, 1920
    cv = Image.new("RGBA", (W, H), (16, 8, 9, 255))
    venue = Image.open(REPO + "docs/art/screens/area-camera/portrait-area-bar.png").convert("RGBA").crop((0, 260, 860, 1100))
    today = Image.open(REPO + "docs/art/screens/tonight/0-hud-button-portrait.png").convert("RGBA").crop((262, 80, 820, 210))
    text(cv, (60, 70), "Need icons: today and three options", font("lato-b", 54), CREAM)
    text(cv, (60, 140), "Large, then at phone size on the red room (right)", font("lato-r", 28), (196, 173, 162))
    rows = [("Today", None, "thin line glyphs, 22 dp inside a ring; moon reads as 'sleep'"),
            ("I1  Bold chips", "I1", "filled silhouettes on a colour chip; readable at 24 dp"),
            ("I2  Neon tubes", "I2", "the bar's neon signs; on theme, thinner at small size"),
            ("I3  Voxel", "I3", "blocky like the venue and the minigame sprites")]
    y = 220
    for name, key, note in rows:
        rrect(cv, (40, y, W - 40, y + 380), 28, fill=(34, 16, 16, 255), outline=(74, 42, 36, 255), width=2)
        text(cv, (70, y + 28), name, font("lato-b", 40), GOLD)
        text(cv, (70, y + 82), note, font("lato-r", 26), (196, 173, 162))
        # big row
        if key is None:
            big = today.resize((int(today.width * 1.05), int(today.height * 1.05)), Image.LANCZOS)
            paste(cv, big, (70, y + 150))
            panel = Image.new("RGBA", (300, 230))
            panel.alpha_composite(venue.crop((480, 300, 780, 530)))
            sm = today.resize((int(today.width * 0.5), int(today.height * 0.5)), Image.LANCZOS)
            panel.alpha_composite(sm, (10, 80))
            paste(cv, panel, (W - 40 - 30 - 300, y + 120))
        else:
            for i, n in enumerate(NEEDS):
                c = CHIPS[key](n, 128)
                paste(cv, c, (66 + i * 146, y + 140))
                text(cv, (66 + i * 146 + 64, y + 290), LABEL[n], font("lato", 24), CREAM, anchor="ma")
            panel = Image.new("RGBA", (300, 230))
            panel.alpha_composite(venue.crop((480, 300, 780, 530)))
            panel.alpha_composite(Image.new("RGBA", panel.size, (0, 0, 0, 60)))
            for i, n in enumerate(NEEDS):
                c = CHIPS[key](n, 100 if key != "I2" else 110)
                paste(panel, c, (16 + (i % 2) * 140, 12 + (i // 2) * 110))
            paste(cv, panel, (W - 40 - 30 - 300, y + 120))
        y += 410
    text(cv, (60, H - 60), "Mock-up drawn in PIL, not a game capture. Backdrop: area-camera/portrait-area-bar.png", font("lato-r", 22), (150, 130, 120))
    cv.convert("RGB").save(OUT + "icons-options.png")


if __name__ == "__main__":
    main()
