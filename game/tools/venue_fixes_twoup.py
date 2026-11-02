"""Before | after two-ups of the venue fixes (owner feedback 2026-11-02 items 4 5 6 7 8 11, and 15), one per item, portrait pair
over landscape pair, from docs/art/screens/venue-fixes/{before,after}/ (game/tests/capture_venue_fixes.gd).
Run from the repo root: python game/tools/venue_fixes_twoup.py"""
from PIL import Image, ImageDraw

D = "docs/art/screens/venue-fixes/"
ITEMS = {"4-bar-door": "bar-side", "5-bar-height": "bar", "6-buffer-curtain": "buffer", "7-toilet-door": "toilets",
         "8-buffer-east-curtains": "buffer-east-in", "11-alcove-rope": "alcove-top"}
LAND = {"8-buffer-east-curtains": "buffer-east"}


def pair(view, h, dirs=("before", "after")):
    ims = [Image.open(f"{D}{s}/{view}.png").convert("RGB") for s in dirs]
    ims = [i.resize((int(i.width * h / i.height), h)) for i in ims]
    out = Image.new("RGB", (ims[0].width * 2 + 12, h + 40), "white")
    dr = ImageDraw.Draw(out)
    for k, (im, lab) in enumerate(zip(ims, ("before", "after"))):
        out.paste(im, (k * (im.width + 12), 40))
        dr.text((k * (im.width + 12) + 8, 12), f"{lab}  {view}", fill="black")
    return out


for item, view in ITEMS.items():
    top = pair(view, 960)
    bot = pair("landscape-" + LAND.get(item, view), 540)
    sheet = Image.new("RGB", (max(top.width, bot.width), top.height + bot.height + 10), "white")
    sheet.paste(top, (0, 0))
    sheet.paste(bot, (0, top.height + 10))
    sheet.save(f"{D}twoup-{item}.png")
    print("saved", f"{D}twoup-{item}.png", sheet.size)

# Item 15 (follow-up, 2026-11-03): the walled bar area stays solid; before = e4d7e76's venue, in before-15/ and after-15/
top = pair("staff-from-smoking", 960, ("before-15", "after-15"))
bot = pair("landscape-staff-from-smoking", 540, ("before-15", "after-15"))
sheet = Image.new("RGB", (max(top.width, bot.width), top.height + bot.height + 10), "white")
sheet.paste(top, (0, 0))
sheet.paste(bot, (0, top.height + 10))
sheet.save(f"{D}twoup-15-walled-area-solid.png")
print("saved", f"{D}twoup-15-walled-area-solid.png", sheet.size)
