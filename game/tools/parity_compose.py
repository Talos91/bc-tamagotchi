"""Two-up parity composite: direction render next to the matching game capture, plus histogram numbers.

    python game/tools/parity_compose.py <n>            (from the repo root)

Reads docs/art/screens/parity/<n>-R05-game.png and <n>-R06-game.png, copies the renders next to them as
R05-render.png / R06-render.png, writes <n>-R05-twoup.png / <n>-R06-twoup.png and prints the luminance stats
that docs/art/parity-measurements.md (Lighting) gives as targets, plus two crispness numbers measured at the
render's size: edge = mean luminance gradient (Sobel, x100), how hard and dense the edges are; lc = local
contrast, the mean standard deviation of luminance in 8 x 8 px blocks (x100); flat = share of those blocks
whose std is under 0.01 (empty surfaces, flat-lit slabs and black voids read as flat).
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PAR = os.path.join(REPO, "docs", "art", "screens", "parity")
RENDERS = {"R05": "05-main-room-iso-from-entrance.webp", "R06": "06-main-room-iso-from-bar.webp"}


def stats(img):
    a = np.asarray(img.convert("RGB")).astype(float) / 255
    lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    m = a.reshape(-1, 3).mean(0)
    p10, p50, p90 = np.percentile(lum, [10, 50, 90])
    edge, lc, flat = crisp(lum)
    return "meanL %.3f  R/G %.2f  p10/50/90 %.2f/%.2f/%.2f  L>0.8 %.1f%%  edge %.2f  lc %.2f  flat %.0f%%" % (
        lum.mean(), m[0] / max(m[1], 1e-4), p10, p50, p90, 100 * (lum > 0.8).mean(), edge, lc, flat)


def crisp(lum):
    """Edge strength (mean Sobel magnitude), local contrast (mean 8 x 8 block std), both x100, and flat %."""
    p = np.pad(lum, 1, mode="edge")
    gx = (p[:-2, 2:] + 2 * p[1:-1, 2:] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[1:-1, :-2] + p[2:, :-2])
    gy = (p[2:, :-2] + 2 * p[2:, 1:-1] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[:-2, 1:-1] + p[:-2, 2:])
    edge = np.hypot(gx, gy).mean() / 4
    h, w = (lum.shape[0] // 8) * 8, (lum.shape[1] // 8) * 8
    blocks = lum[:h, :w].reshape(h // 8, 8, w // 8, 8)
    std = blocks.std(axis=(1, 3))
    return 100 * edge, 100 * std.mean(), 100 * (std < 0.01).mean()


def main(n):
    for shot, fname in RENDERS.items():
        game_p = os.path.join(PAR, "%s-%s-game.png" % (n, shot))
        if not os.path.exists(game_p):
            print("missing", game_p)
            continue
        ref = Image.open(os.path.join(REPO, "docs", "art", "direction", fname)).convert("RGB")
        ref.save(os.path.join(PAR, "%s-render.png" % shot))
        game = Image.open(game_p).convert("RGB").resize(ref.size, Image.LANCZOS)
        w, h = ref.size
        out = Image.new("RGB", (w * 2 + 12, h + 40), (12, 6, 6))
        out.paste(ref, (0, 40))
        out.paste(game, (w + 12, 40))
        d = ImageDraw.Draw(out)
        d.text((10, 12), "%s render   %s" % (shot, stats(ref)), fill=(240, 220, 200))
        d.text((w + 22, 12), "iteration %s game   %s" % (n, stats(game)), fill=(240, 220, 200))
        out.save(os.path.join(PAR, "%s-%s-twoup.png" % (n, shot)))
        print(shot, "render", stats(ref))
        print(shot, "game  ", stats(game))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "0")
