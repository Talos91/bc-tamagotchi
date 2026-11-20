"""Crop act photos from a weekly lineup poster set into game/assets/events/<slug>.jpg (square, <= 512 px).

Usage: python tools/crop_lineup.py <crops.json>
crops.json: {"posters_dir": "docs/venue/events/<week folder>", "crops": [
  {"slug": "aomsin", "poster": "4-wednesday.jpg", "box": [x0, y0, x1, y1], "focus_x": 0.5, "fit": "cover"}]}
box = the photo's rectangle on the poster (pixels). fit "cover" crops a centred square (focus_x moves it left/right,
0..1); fit "contain" keeps the whole photo and pads it to a square with the poster's black. Output 320 px, JPEG q82.
"""
import json, sys, os
from PIL import Image

SIZE = 320
OUT = "game/assets/events"

def main(spec_path):
    spec = json.load(open(spec_path, encoding="utf-8"))
    os.makedirs(OUT, exist_ok=True)
    for c in spec["crops"]:
        im = Image.open(os.path.join(spec["posters_dir"], c["poster"])).convert("RGB")
        x0, y0, x1, y1 = c["box"]
        ph = im.crop((x0, y0, x1, y1))
        w, h = ph.size
        if c.get("fit", "cover") == "contain":
            s = max(w, h)
            sq = Image.new("RGB", (s, s), (10, 10, 10))
            sq.paste(ph, ((s - w) // 2, (s - h) // 2))
        else:
            s = min(w, h)
            fx = float(c.get("focus_x", 0.5))
            left = int(round((w - s) * fx))
            top = (h - s) // 2
            sq = ph.crop((left, top, left + s, top + s))
        sq = sq.resize((SIZE, SIZE), Image.LANCZOS)
        out = os.path.join(OUT, c["slug"] + ".jpg")
        sq.save(out, "JPEG", quality=82, optimize=True, progressive=False)
        print(out, os.path.getsize(out) // 1024, "KB")

if __name__ == "__main__":
    main(sys.argv[1])
