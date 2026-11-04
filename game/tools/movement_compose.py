"""Compose the movement-polish captures (game/tests/capture_movement.gd) into review images.

    python game/tools/movement_compose.py <shots dir> [<out dir>]

For every variant (camera = before, north = after, main_room = the alternative axis) and orientation it writes the
three shots at 1080x1920 / 1920x1080 (the window renders at half size: 540x960 / 960x540, scaled 2x) with two
arrows drawn on: yellow = the finger's drag, cyan = where the figure walks on screen. Then a strip per variant and
one sheet per orientation (rows: before, after, alternative) for the hub cards.
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

VARIANTS = [("camera", "BEFORE: stick follows the camera"), ("north", "AFTER: fixed axis, venue north (= first camera)"),
            ("main_room", "OPTION: fixed axis, main-room east")]
SHOTS = [("1-lounge", "1  lounge view, drag held"), ("2-buffer-held", "2  camera swings, same drag held"),
         ("3-same-drag-again", "3  lift, same drag again")]
SCALE = 2
YELLOW = (255, 214, 64)
CYAN = (64, 224, 255)


def font(size):
    for f in ("C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/arialbd.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def arrow(d, start, vec, length, col, width):
    n = math.hypot(*vec)
    if n < 1e-3:
        d.ellipse([start[0] - 14, start[1] - 14, start[0] + 14, start[1] + 14], outline=col, width=width)
        return
    ux, uy = vec[0] / n, vec[1] / n
    end = (start[0] + ux * length, start[1] + uy * length)
    d.line([start, end], fill=(0, 0, 0), width=width + 8)
    d.line([start, end], fill=col, width=width)
    head = 46
    for s in (-1, 1):
        a = math.atan2(uy, ux) + math.pi + s * 0.45
        p = (end[0] + math.cos(a) * head, end[1] + math.sin(a) * head)
        d.line([end, p], fill=(0, 0, 0), width=width + 8)
        d.line([end, p], fill=col, width=width)


def annotate(img, m, title):
    img = img.resize((img.width * SCALE, img.height * SCALE), Image.LANCZOS)
    d = ImageDraw.Draw(img)
    f = [v * SCALE for v in m["finger"]]
    d.ellipse([f[0] - 30, f[1] - 30, f[0] + 30, f[1] + 30], outline=YELLOW, width=8)
    arrow(d, f, m["drag"], 230, YELLOW, 14)
    k = img.width / m["size"][0]   # the figure's point is in canvas units (the stretched 1080x1920 / 1920x1080)
    g = [v * k for v in m["fig"]]
    arrow(d, g, m["fig_move"], 230, CYAN, 14)
    fs = font(44)
    d.rectangle([0, 0, img.width, 140], fill=(0, 0, 0))
    d.text((30, 18), title, fill=(255, 255, 255), font=fs)
    d.text((30, 78), "yellow = finger drag   cyan = figure walks", fill=(200, 200, 200), font=font(34))
    return img


def main():
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..", "..", "docs", "art", "screens", "movement-polish")
    os.makedirs(out, exist_ok=True)
    for tag in ("portrait", "landscape"):
        rows = []
        for key, label in VARIANTS:
            meta_path = os.path.join(src, f"{key}-{tag}.json")
            if not os.path.exists(meta_path):
                continue
            meta = json.load(open(meta_path, encoding="utf-8"))
            tiles = []
            for shot, shot_label in SHOTS:
                img = Image.open(os.path.join(src, f"{key}-{shot}-{tag}.png")).convert("RGB")
                full = annotate(img, meta[shot], f"{label.split(':')[0]}  {shot_label}")
                name = {"camera": "before", "north": "after", "main_room": "option-main-room"}[key]
                full.save(os.path.join(out, f"{name}-{shot}-{tag}.jpg"), quality=88)
                tiles.append(full)
            w = tiles[0].width // 3 if tag == "portrait" else tiles[0].width // 4
            h = tiles[0].height * w // tiles[0].width
            strip = Image.new("RGB", (w * 3, h + 90), (16, 10, 10))
            ImageDraw.Draw(strip).text((20, 22), label, fill=(255, 255, 255), font=font(46 if tag == "portrait" else 40))
            for i, t in enumerate(tiles):
                strip.paste(t.resize((w, h), Image.LANCZOS), (i * w, 90))
            strip.save(os.path.join(out, f"strip-{key}-{tag}.jpg"), quality=86)
            rows.append(strip)
        if rows:
            sheet = Image.new("RGB", (rows[0].width, sum(r.height for r in rows) + 12 * (len(rows) - 1)), (40, 40, 40))
            y = 0
            for r in rows:
                sheet.paste(r, (0, y))
                y += r.height + 12
            sheet.save(os.path.join(out, f"sheet-{tag}.jpg"), quality=86)
            print("sheet", tag, sheet.size)


if __name__ == "__main__":
    main()
