"""Before / after two-ups for the lounge follow-up (tests/capture_lounge_followup.gd). Before = 50a0623 (the lounge
revamp), after = the follow-up.

    python game/tools/lounge_followup_twoup.py [tag]       (from the repo root; tag = portrait | landscape, default portrait)

Writes docs/art/screens/lounge-followup/twoup-<tag>-<shot>.jpg (quality 90): before left, after right, scaled to the
same height, with a caption strip. Before pictures come from docs/art/screens/lounge-revamp/<tag>-<shot>.png (the 50a0623
captures) or, for the shots that run did not take, from lounge-followup/before-<tag>-<shot>.png (the same capture script
run on 50a0623 with --prefix=before-; not committed, the two-ups carry them). Shots without a before picture are skipped.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
AFTER_DIR = os.path.join(REPO, "docs", "art", "screens", "lounge-followup")
REVAMP_DIR = os.path.join(REPO, "docs", "art", "screens", "lounge-revamp")
SHOTS = ["lounge", "stair-foot", "memory", "merch-sheet", "patrons-sheet", "portrait-6-sheet", "raised-east", "raised-top"]
H = {"portrait": 1100, "landscape": 640}
GAP = 16
CAP = 54


def fit(im, h):
    return im.resize((round(im.width * h / im.height), h), Image.LANCZOS)


def before_path(tag, shot):
    own = os.path.join(AFTER_DIR, "before-%s-%s.png" % (tag, shot))
    if os.path.exists(own):
        return own
    return os.path.join(REVAMP_DIR, "%s-%s.png" % (tag, shot if shot != "portrait-6-sheet" else "portrait-6-sheet"))


def main(tag):
    try:
        font = ImageFont.truetype("arialbd.ttf", 30)
    except OSError:
        font = ImageFont.load_default()
    h = H.get(tag, 900)
    for shot in SHOTS:
        before = before_path(tag, shot)
        after = os.path.join(AFTER_DIR, "%s-%s.png" % (tag, shot))
        if not (os.path.exists(before) and os.path.exists(after)):
            print("skipped", shot)
            continue
        a = fit(Image.open(before).convert("RGB"), h)
        b = fit(Image.open(after).convert("RGB"), h)
        out = Image.new("RGB", (a.width + GAP + b.width, h + CAP), (18, 14, 16))
        out.paste(a, (0, CAP))
        out.paste(b, (a.width + GAP, CAP))
        d = ImageDraw.Draw(out)
        d.text((14, 10), "BEFORE (50a0623)", fill=(200, 190, 190), font=font)
        d.text((a.width + GAP + 14, 10), "AFTER (lounge follow-up)", fill=(255, 210, 120), font=font)
        path = os.path.join(AFTER_DIR, "twoup-%s-%s.jpg" % (tag, shot))
        out.save(path, quality=90)
        print("saved", path, out.size)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "portrait")
