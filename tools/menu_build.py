"""Black Cabin real menu: derive the game data and the readable page from the transcription of record.

    python tools/menu_build.py

Reads  docs/venue/menu/menu.json   (the transcription; names exactly as printed, errata listed, never fixed)
Writes game/data/menu.json          (what the game needs: id, EN/TH names, category, price, flags, effect)
       docs/venue/menu/menu.md      (readable menu, same content as the transcription)

Game EN names are title-cased from the printed names with the clear misprints in DISPLAY_FIX corrected; unverified
spellings stay as printed. TH names are a machine draft (th_draft: true) for Black Cabin staff to check: food and
generic drinks are translated, wine and spirit brand names stay in Latin script as on Bangkok bar menus. The two
Thai names printed on the menu are used as they are (th_draft: false).
"""
import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs/venue/menu/menu.json"
GAME = ROOT / "game/data/menu.json"
MD = ROOT / "docs/venue/menu/menu.md"

# Section id -> game category, group and pour style. Group "drinks" is the bar list, "kitchen" the food list.
SECTION_GAME = {
    "aperitifs": ("aperitif", "kitchen", ""),
    "sharing": ("sharing", "kitchen", ""),
    "mains": ("main", "kitchen", ""),
    "pasta": ("pasta", "kitchen", ""),
    "beer": ("beer", "drinks", "lager"),
    "other": ("soft", "drinks", ""),
    "champagne_sparkling": ("sparkling", "drinks", "sparkling"),
    "whites": ("white_wine", "drinks", "white"),
    "reds": ("red_wine", "drinks", "red"),
    "single_malt": ("single_malt", "drinks", "dark_spirit"),
    "blended_scotch": ("blended_scotch", "drinks", "dark_spirit"),
    "american_whiskey": ("american_whiskey", "drinks", "dark_spirit"),
    "irish_whiskey": ("irish_whiskey", "drinks", "dark_spirit"),
    "japanese_whisky": ("japanese_whisky", "drinks", "dark_spirit"),
    "tequila_mezcal": ("tequila_mezcal", "drinks", "clear_spirit"),
    "vodka": ("vodka", "drinks", "clear_spirit"),
    "rum": ("rum", "drinks", "dark_spirit"),
    "liqueur": ("liqueur", "drinks", "liqueur"),
    "brandy_cognac": ("brandy_cognac", "drinks", "dark_spirit"),
    "gin": ("gin", "drinks", "clear_spirit"),
}

# Category -> rule effect. Every number lives in game/scripts/rules.gd; the effect names which existing bar row
# the drink behaves like (see EFFECTS below and handoffs/real-menu-2026-11-02.md).
ALCOHOL = {"beer", "sparkling", "white_wine", "red_wine", "single_malt", "blended_scotch", "american_whiskey",
           "irish_whiskey", "japanese_whisky", "tequila_mezcal", "vodka", "rum", "liqueur", "brandy_cognac", "gin",
           "shooter"}
EFFECTS = {
    "alcohol": {"action": "order_drink", "tipsy": 1, "merry_blocked": True,
                "was": "the Order a drink row and the six invented Try something new drinks"},
    "soft": {"action": "order_drink", "tipsy": 0, "merry_blocked": False, "was": "the Thai iced tea (mocktail) row"},
    "water": {"action": "order_drink", "tipsy": -1, "merry_blocked": False, "was": "the A glass of water row"},
    "none": {"action": "", "tipsy": 0, "merry_blocked": False, "was": "nothing yet (Kitchen list)"},
}

# Printed name -> game display name, only for the clear misprints listed in print_errata.
DISPLAY_FIX = {
    "THAI CAVIER (YUM)": "Thai Caviar (Yum)",
    "AUS RIBEYE STEAK W/ FRITTES & TRUFFLE MAYO": "Aus Ribeye Steak w/ Frites & Truffle Mayo",
    "KI RARO BLOCKS, SAUVIGNON BLANC 2023": "Ki Raro Blocks, Sauvignon Blanc 2023",
    "CAPE OF GOOD HOPE RIEBBEKSREVIER CHENIN BLANC 2023": "Cape of Good Hope Riebeeksrivier Chenin Blanc 2023",
    "CASTELLO DEL TREBBIO CHIANTI SUPERIORE DOGC 2022": "Castello del Trebbio Chianti Superiore DOCG 2022",
}
REGION_FIX = {"MALBOUROUGH, NZ": "Marlborough, NZ"}

# Words that stay upper case / lower case when title-casing.
UPPER = {"NV", "DOCG", "DOGC", "AOP", "VS", "VSOP", "XO", "H"}
LOWER = {"W/", "E", "DE", "DEL", "OF", "ON", "WITH", "AND", "PCS", "BY"}

TH_FOOD = {
    "ITALIAN SAUSAGE SALAD": "สลัดไส้กรอกอิตาเลียน",
    "SMOKED SALMON CANAPE, HOUSE TARTAR (3 PCS)": "คานาเป้แซลมอนรมควัน ซอสทาร์ทาร์สูตรร้าน (3 ชิ้น)",
    "CHICKEN LIVER PATE": "ปาเต้ตับไก่",
    "RIBEYE BEEF JERKY MALA": "เนื้อริบอายแดดเดียวหมาล่า",
    "CHEESE & COLD CUTS BOARD": "ชีสและโคลด์คัทบอร์ด",
    "SHRIMP TARTARE": "ทาร์ทาร์กุ้ง",
    "BEEF TARTARE W/ BAGUETTE": "ทาร์ทาร์เนื้อกับบาแกตต์",
    "MIXED NUTS": "ถั่วรวม",
    "FRENCH FRIES": "เฟรนช์ฟรายส์",
    "FRIED CHICKEN TENDONS": "เอ็นไก่ทอด",
    "CHICKEN NUGGETS": "นักเก็ตไก่",
    "CHICKEN POPS": "ไก่ป๊อป",
    "PORK WATERFALL": "น้ำตกหมู",
    "AUS RIBEYE BEEF WATERFALL": "น้ำตกเนื้อริบอายออสเตรเลีย",
    "BEEF NACHOS": "นาโชเนื้อ",
    "BLACK CABIN QUESADILLA": "เคซาดิยาแบล็คเคบิน",
    "CRISPY FRIED SHRIMPS": "กุ้งทอดกรอบ",
    "CALAMARI": "คาลามารี (ปลาหมึกทอด)",
    "MORTADELLA SANDWICH (BOURDAIN SANDWICH)": "แซนด์วิชมอร์ตาเดลลา (แซนด์วิชบูร์แดง)",
    "PULLED PORK ON FRIES": "พูลด์พอร์กบนเฟรนช์ฟรายส์",
    "AUS RIBEYE STEAK W/ FRITTES & TRUFFLE MAYO": "สเต๊กริบอายออสเตรเลีย เฟรนช์ฟรายส์ มายองเนสทรัฟเฟิล",
    "PORK/BEEF KRAPAO ON RICE WITH FRIED DUCK EGG": "ข้าวกะเพราหมู/เนื้อ ไข่เป็ดดาว",
    "BLACK CABIN BURGER & FRIES": "เบอร์เกอร์แบล็คเคบินและเฟรนช์ฟรายส์",
    "SPICY CHICKEN POPS ON RICE": "ข้าวไก่ป๊อปรสเผ็ด",
    "PAD WAIWAI (STIR FRIED NOODLES WITH PORK)": "ผัดไวไวหมู",
    "HAM SCRAMBLED EGG ON RICE": "ข้าวไข่คนแฮม",
    "LINGUINE VONGOLE": "ลิงกวีนีวองโกเล",
    "SPAGHETTI BOLOGNESE": "สปาเกตตีโบโลเนส",
    "SPAGHETTI AGLIO E OLIO W/ BACON": "สปาเกตตีอาลีโอ โอลีโอ เบคอน",
    "SPAGHETTI CARBONARA": "สปาเกตตีคาร์โบนารา",
    "SPAGHETTI ITALIAN SAUSAGE": "สปาเกตตีไส้กรอกอิตาเลียน",
    "LINGUINE SHRIMP BISQUE": "ลิงกวีนีบิสก์กุ้ง",
}
TH_DRINK = {
    "HEINEKEN DRAUGHT": "ไฮเนเก้นสด",
    "GUINNESS DRAUGHT": "กินเนสส์สด",
    "HEINEKEN SILVER": "ไฮเนเก้น ซิลเวอร์",
    "CORONA": "โคโรนา",
    "SINGHA SODA": "โซดาสิงห์",
    "WATER": "น้ำเปล่า",
    "ACQUA PANNA MINERAL WATER": "น้ำแร่อควาปันนา",
    "COKE": "โค้ก",
    "COKE ZERO": "โค้กซีโร่",
    "SPRITE": "สไปรท์",
    "TONIC": "โทนิก",
    "RED BULL CAN": "เรดบูลกระป๋อง",
    "FEVER TREE INDIAN": "ฟีเวอร์ทรี อินเดียน",
    "FEVER TREE MEDITERRANEAN": "ฟีเวอร์ทรี เมดิเตอร์เรเนียน",
    "FEVER TREE ELDERFLOWER": "ฟีเวอร์ทรี เอลเดอร์ฟลาวเวอร์",
    "FEVER TREE GINGER ALE": "ฟีเวอร์ทรี จินเจอร์เอล",
    "FEVER TREE GINGER BEER": "ฟีเวอร์ทรี จินเจอร์เบียร์",
}
WATERS = {"WATER", "ACQUA PANNA MINERAL WATER"}
NOT_IN_GAME = {"ICE BUCKET"}  # a service item, not a drink

# Try something new: six real drinks in order (the old list was six invented ones). One per family.
TRY_ORDER = ["guinness_draught", "monkey_shoulder", "roku", "don_julio_blanco", "phraya_rum_8y", "jagermeister"]
# Pour Perfect rotates through these (alcohol, pourable): beer, the house shooters, wine, one spirit per family.
POUR_FEATURED = ["heineken_draught", "house_shooter", "guinness_draught", "petes_pure_sauvignon_blanc_2023",
                 "the_wily_fox_shiraz_2023", "monkey_shoulder", "jameson", "roku", "don_julio_blanco",
                 "phraya_rum_8y", "hennessy_vs", "jagermeister"]
# Pour Perfect layer colours per pour style, bottom to top.
POUR_COLORS = {
    "lager": ["E39A2D", "F2BE4A", "F6EBDD"],
    "stout": ["2A120C", "3A1A10", "EADBC2"],
    "sparkling": ["E8D58A", "F2E3A4", "FBF4DA"],
    "white": ["D9C46A", "E6D58A", "F1E6B4"],
    "red": ["5A0A16", "7A1020", "9C1E2C"],
    "dark_spirit": ["9A4A12", "B8651E", "D68A35"],
    "clear_spirit": ["BFD8DE", "D6E8EC", "EEF6F7"],
    "liqueur": ["3B1A0A", "6A2A0E", "B0451A"],
    "shooter": ["D0161C", "FF8A30", "FFDD78"],
    "soft": ["3A160C", "4A1E10", "D9C2A6"],
}
# While Merry, Nam pours this soft drink in Pour Perfect instead (the minigame still counts as a drink).
POUR_MERRY = "coke"
STYLE_OVERRIDE = {"guinness_draught": "stout", "campari": "shooter", "aperol": "shooter",
                  "finlandia_cranberry": "red"}


def slug(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    s = s.lower().replace("&", "and").replace("'", "").replace("’", "")
    s = re.sub(r"[^a-z0-9]+", "_", s)
    return s.strip("_")


def title(printed: str) -> str:
    if printed in DISPLAY_FIX:
        return DISPLAY_FIX[printed]
    out = []
    words = printed.split(" ")
    for i, w in enumerate(words):
        core = w.strip("(),")
        if re.fullmatch(r"\d+ML\.?", core):
            nw = w.replace("ML.", "ml").replace("ML", "ml")
        elif core in UPPER or re.fullmatch(r"\d+Y", core) or re.fullmatch(r"[A-Z]?\d[\dA-Z.]*", core):
            nw = w
        elif i > 0 and (core in LOWER or (core == "THE" and words[i - 1] == "OF")):
            nw = w.lower()
        elif core.startswith("NO."):
            nw = w.replace("NO.", "No.")
        else:
            nw = re.sub(r"[A-ZÀ-Þ]+", lambda m: m.group(0)[0] + m.group(0)[1:].lower(), w)
            nw = re.sub(r"(['’])S\b", r"\1s", nw)
        out.append(nw)
    s = " ".join(out)
    s = s.replace("Pcs", "pcs").replace("W/ ", "w/ ")
    return s


def region_title(r: str) -> str:
    if r in REGION_FIX:
        return REGION_FIX[r]
    out = ", ".join(" / ".join(title(p.strip()) for p in part.split("/")) for part in r.split(", "))
    return re.sub(r"\b(Aus|Nz)\b", lambda m: m.group(0).upper(), out)


def build():
    src = json.loads(SRC.read_text(encoding="utf-8"))
    items = []
    for sec in src["sections"]:
        cat, group, style = SECTION_GAME[sec["id"]]
        for it in sec["items"]:
            printed = it["name"]
            if printed in NOT_IN_GAME:
                continue
            variants = it.get("variants") or [None]
            for v in variants:
                if v is None:
                    nm_print, price = printed, it.get("price", it.get("price_glass", it.get("price_bottle")))
                    en = title(printed)
                else:  # PORK / AUS RIBEYE BEEF WATERFALL -> two dishes
                    nm_print = v["name"] + " WATERFALL"
                    price = v["price"]
                    en = title(nm_print)
                iid = slug(nm_print)
                if printed in WATERS:
                    effect = "water"
                elif cat == "soft":
                    effect = "soft"
                elif cat in ALCOHOL:
                    effect = "alcohol"
                else:
                    effect = "none"
                if it.get("name_th_printed"):
                    th, th_draft = it["name_th_printed"], False
                elif nm_print in TH_FOOD:
                    th, th_draft = TH_FOOD[nm_print], True
                elif nm_print in TH_DRINK:
                    th, th_draft = TH_DRINK[nm_print], True
                else:
                    th, th_draft = en, True  # wine and spirit brands stay in Latin script
                d = {"id": iid, "name_en": en, "name_th": th, "th_draft": th_draft, "category": cat,
                     "section": sec["id"], "group": group, "effect": effect, "price": price,
                     "price_unit": "glass" if "price_glass" in it else ("bottle" if "price_bottle" in it else "serve")}
                if "price_bottle" in it and "price_glass" in it:
                    d["price_bottle"] = it["price_bottle"]
                d["name_printed"] = printed
                if v is not None:
                    d["variant"] = v["name"]
                for k in ("star", "chilli"):
                    if it.get(k):
                        d[k] = True
                if "abv" in it:
                    d["abv"] = it["abv"]
                if "region" in it:
                    d["region"] = region_title(it["region"])
                if it.get("notes"):
                    d["notes"] = it["notes"]
                d["pourable"] = effect == "alcohol"
                if d["pourable"]:
                    d["pour_style"] = STYLE_OVERRIDE.get(iid, style)
                items.append(d)
    # The house shooters deal is a pourable drink of its own; the menu prints only the 5 + 1 price.
    shooter = {"id": "house_shooter", "name_en": "House Shooter", "name_th": "ช็อตประจำร้าน", "th_draft": True,
               "category": "shooter", "section": "house_shooters", "group": "drinks", "effect": "alcohol",
               "price": 590, "price_unit": "deal_5_free_1", "name_printed": src["deals"][0]["printed"],
               "pourable": True, "pour_style": "shooter"}
    beer_i = next(i for i, d in enumerate(items) if d["category"] == "beer")
    items.insert(beer_i, shooter)

    ids = [d["id"] for d in items]
    assert len(ids) == len(set(ids)), "duplicate ids"
    for i in TRY_ORDER + POUR_FEATURED:
        assert i in ids, i

    sections = []
    for sec in [{"id": "house_shooters", "title": "HOUSE SHOOTERS"}] + src["sections"]:
        if sec["id"] == "house_shooters":
            cat, group = "shooter", "drinks"
        else:
            cat, group, _ = SECTION_GAME[sec["id"]]
        sections.append({"id": sec["id"], "group": group, "title_key": "menu.section." + sec["id"]})
    # Kitchen sections first in the transcription; the bar list shows drinks first.
    sections.sort(key=lambda s: 0 if s["group"] == "drinks" else 1)

    game = {
        "_source": "Generated by tools/menu_build.py from docs/venue/menu/menu.json; do not edit by hand.",
        "currency": "THB",
        "price_note": src["price_footer"],
        "effects": EFFECTS,
        "try_order": TRY_ORDER,
        "pour_featured": POUR_FEATURED,
        "pour_merry": POUR_MERRY,
        "pour_colors": POUR_COLORS,
        "sections": sections,
        "items": items,
        "bundles": [{"id": slug(b["name"]), "name_en": title(b["name"]), "bottles": b["bottles"],
                     "was": b["was"], "now": b["now"]} for b in src["bundles"]],
    }
    GAME.parent.mkdir(parents=True, exist_ok=True)
    GAME.write_text(json.dumps(game, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")
    MD.write_text(markdown(src), encoding="utf-8", newline="\n")
    print(f"{len(items)} game items ({sum(d['group'] == 'drinks' for d in items)} drinks, "
          f"{sum(d['group'] == 'kitchen' for d in items)} kitchen), {len(sections)} sections")


def money(n):
    return f"{n:,}"


def markdown(src) -> str:
    L = ["# Black Cabin menu", "",
         "Transcribed 2026-11-02 from the 11 pages in this folder (Daniele, with Black Cabin's authorization). Machine copy:",
         "`menu.json`; game copy: `game/data/menu.json` (`python tools/menu_build.py`). Names are exactly as printed;",
         "misprints are listed at the end, not fixed. Prices in THB; " + src["price_footer"].lower() + ".", "",
         "★ recommended · 🌶 spicy · spirits are bottle / glass.", ""]
    deal = src["deals"][0]
    L += ["## House shooters", "", f"{deal['printed']} (buy {deal['buy']}, {deal['free']} free, {deal['price']} THB). "
          + deal["note"], ""]
    for sec in src["sections"]:
        L += [f"## {sec['title']}", f"_{sec['page']}_", ""]
        wine = sec["id"] in ("champagne_sparkling", "whites", "reds")
        if wine:
            L += ["| Wine | ABV | Region | Bottle | Notes |", "|---|---|---|---:|---|"]
        elif sec.get("price_columns") == "bottle / glass":
            L += ["| Item | Bottle | Glass |", "|---|---:|---:|"]
        else:
            L += ["| Item | Price |", "|---|---:|"]
        for it in sec["items"]:
            mark = ("★ " if it.get("star") else "") + ("🌶 " if it.get("chilli") else "")
            nm = mark + it["name"] + (" " + it["name_th_printed"] if it.get("name_th_printed") else "")
            if wine:
                L.append(f"| {nm} | {it['abv']}% | {it['region']} | {money(it['price_bottle'])} | {it.get('notes') or ''} |")
            elif sec.get("price_columns") == "bottle / glass":
                b = money(it["price_bottle"]) if "price_bottle" in it else ""
                L.append(f"| {nm} | {b} | {money(it['price_glass'])} |")
            elif "variants" in it:
                L.append(f"| {nm} | {' / '.join(money(v['price']) for v in it['variants'])} |")
            else:
                L.append(f"| {nm} | {money(it['price'])} |")
        L.append("")
    L += ["## Bundles", "", "| Bundle | Bottles | Was | Now |", "|---|---|---:|---:|"]
    for b in src["bundles"]:
        L.append(f"| {b['name']} | {' + '.join(b['bottles'])} | ~~{money(b['was'])}~~ | {money(b['now'])} |")
    L += ["", src["bundles_note"], "", "## Print errata (copied as printed above)", "",
          "| Page | Printed | Likely | Note |", "|---|---|---|---|"]
    for e in src["print_errata"]:
        L.append(f"| {e['page']} | {e['printed']} | {e['likely']} | {e['note']} |")
    L += ["", "## Price notes", ""]
    for p in src["price_notes"]:
        L.append(f"- **{p['item']}** ({p['page']}): {p['note']}")
    L += ["", "No cocktail page is in this set.", ""]
    return "\n".join(L)


if __name__ == "__main__":
    build()
