"""Two-up parity composite: direction render next to the matching game capture, plus histogram numbers.

    python game/tools/parity_compose.py <n>            (from the repo root)

Reads docs/art/screens/parity/<n>-R05-game.png and <n>-R06-game.png, copies the renders next to them as
R05-render.png / R06-render.png, writes <n>-R05-twoup.png / <n>-R06-twoup.png and prints the luminance stats
that docs/art/parity-measurements.md (Lighting) gives as targets.
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
    return "meanL %.3f  R/G %.2f  p10/50/90 %.2f/%.2f/%.2f  L>0.8 %.1f%%" % (
        lum.mean(), m[0] / max(m[1], 1e-4), p10, p50, p90, 100 * (lum > 0.8).mean())


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
