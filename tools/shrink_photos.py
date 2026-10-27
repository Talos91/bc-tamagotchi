import sys, os
from PIL import Image, ImageOps
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
for n in sorted(os.listdir(src)):
    if not n.lower().endswith(('.jpg','.jpeg')): continue
    im = ImageOps.exif_transpose(Image.open(os.path.join(src, n)))
    im.thumbnail((2000, 2000))
    out = os.path.join(dst, n)
    im.convert("RGB").save(out, "JPEG", quality=85, optimize=True)
    print(n, im.size, os.path.getsize(out)//1024, "KB")
