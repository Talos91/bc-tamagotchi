"""Black Cabin merch catalogue: one source for the game data and the server seed.

Writes
  game/data/merch.json            what the game reads (scripts/merch/merch.gd): items, voxel boxes, colours
  supabase/seed/merch_items.sql   the server catalogue rows (public.merch_items), upserted, prices left NULL

Run from the repo root:  python tools/merch_catalog.py

Voxel boxes are [x0, x1, y0, y1, z0, z1, colour] (inclusive cell ranges, Blender-style axes: x to the right as you
look at the character's face (the game mirrors it onto the kit, whose +x is the character's right), y to the back
(front is -y), z up). Coordinates are relative to the anchor bone:
  head   x -4..3, y -3..3 (face plane y = -3, glasses at y = -4), z 0..6 = the 8 x 7 x 7 head box; hats are written
         from z 7 and lifted one row (onto the kit's brim row, z 8)
  spine  the torso: x X0..X1, y Y0..Y1 (front Y0), z 0..C-1 (C = chest rows); a coordinate may be a string such as
         "Y1+1" or "C-2", evaluated per body type (petite, regular, broad, tall) by merch.gd
A colour key ending in "!" glows (emissive), like the venue's neon.
Pixel art: "face" rows (10 wide, x -5..4, top row first) sit on the glasses plane y = -4 from z = face_top down;
"chest" rows (top row first) sit just in front of the chest (a decal), centred, top row at z = C-2.
Prices: none (Daniele 2026-11-20: picked for free now, bought later; money is his call).
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CATEGORIES = [
    {"id": "head", "anchor": "head"},
    {"id": "eyes", "anchor": "head"},
    {"id": "top", "anchor": "spine"},
    {"id": "acc", "anchor": "spine"},
]

FACE_PARTS = ["head_", "hair_", "eyes_", "mouth_", "brows_", "beard", "hat_", "glasses_", "headphones"]


def mirror_boxes(boxes):
    """Boxes plus their left-right mirror (x -> -1 - x)."""
    out = list(boxes)
    for b in boxes:
        out.append([_mx(b[1]), _mx(b[0])] + b[2:])
    return out


def _mx(x):
    """Mirror one x: an int is -1 - x; "X0-3" is "X1+3" (torsos are symmetric: X1 = -1 - X0)."""
    if isinstance(x, int):
        return -1 - x
    s = x.replace("X0", "#").replace("X1", "X0").replace("#", "X1")
    return s.replace("+", "@").replace("-", "+").replace("@", "-")


def ring(x0, x1, y0, y1, z, col):
    """The perimeter of a rectangle at one height."""
    return [[x0, x1, y0, y0, z, z, col], [x0, x1, y1, y1, z, z, col],
            [x0, x0, y0 + 1, y1 - 1, z, z, col], [x1, x1, y0 + 1, y1 - 1, z, z, col]]


HEAD = [
    {"id": "horse_mask", "name": "Horse Mask", "blurb": "Neigh. Full head. Nobody knows it's you.",
     "hides": FACE_PARTS,
     "palette": {"a": "#8A5A34", "b": "#5A3620", "m": "#D9B48A", "k": "#141010", "w": "#F4EDE2"},
     "boxes": [[-4, 3, -3, 3, 0, 7, "a"],                       # the head
               [-3, 2, -9, -4, -2, 3, "a"],                     # the long face, down past the chin
               [-3, 2, -9, -8, -2, 0, "m"],                     # muzzle
               [-2, -2, -10, -10, 0, 1, "k"], [1, 1, -10, -10, 0, 1, "k"],   # nostrils
               [-3, 2, -10, -10, -2, -2, "b"],                  # mouth line
               [-3, 2, -7, -4, 4, 4, "a"],                      # brow ridge
               [-4, -4, -4, -4, 5, 5, "w"], [3, 3, -4, -4, 5, 5, "w"],
               [-5, -5, -3, -3, 5, 5, "k"], [4, 4, -3, -3, 5, 5, "k"],   # side eyes
               [-4, -3, 0, 1, 8, 11, "a"], [2, 3, 0, 1, 8, 11, "a"],     # ears
               [-4, -3, 0, 0, 9, 10, "m"], [2, 3, 0, 0, 9, 10, "m"],
               [-1, 0, -3, 4, 8, 8, "b"], [-1, 0, 4, 4, 0, 7, "b"], [-1, 0, 4, 5, -2, 0, "b"],
               [-1, 0, -4, -4, 6, 8, "b"]]},                    # mane
    {"id": "bc_cap", "name": "Black Cabin Cap", "blurb": "The house cap. Black, red peak, the cabin on the front.",
     "hat": True,
     "palette": {"k": "#151214", "r": "#C8141C", "w": "#F6EBDD", "n": "#FF2A1E!"},
     "boxes": [[-5, 4, -4, 4, 7, 8, "k"], [-4, 3, -3, 3, 9, 9, "k"], [-1, 0, -1, 0, 10, 10, "r"],
               [-4, 3, -8, -5, 7, 7, "r"],                      # peak
               [-3, 2, -5, -5, 8, 9, "w"], [-1, 0, -6, -6, 9, 9, "n"], [-2, 1, -6, -6, 8, 8, "n"]]},
    {"id": "traffic_cone", "name": "Traffic Cone", "blurb": "Found it on Soi 11 at 2 am. It's a hat now.",
     "hat": True,
     "palette": {"o": "#FF6A13", "w": "#F4F1EA"},
     "boxes": [[-5, 4, -4, 4, 7, 7, "o"], [-3, 2, -2, 2, 8, 9, "o"], [-3, 2, -2, 2, 10, 10, "w"],
               [-2, 1, -1, 1, 11, 12, "o"], [-2, 1, -1, 1, 13, 13, "w"], [-1, 0, -1, 0, 14, 15, "o"]]},
    {"id": "viking_helmet", "name": "Viking Helmet", "blurb": "For the night you order the whole tower.",
     "hat": True,
     "palette": {"s": "#8E949C", "d": "#5B6068", "h": "#EFE3C8"},
     "boxes": [[-5, 4, -4, 4, 7, 8, "s"], [-4, 3, -3, 3, 9, 9, "s"], [-2, 1, -2, 1, 10, 10, "d"],
               [-5, 4, -4, -4, 7, 7, "d"], [-1, 0, -5, -5, 3, 7, "d"]]
              + mirror_boxes([[5, 6, -1, 0, 7, 8, "h"], [7, 7, -1, 0, 8, 10, "h"], [6, 6, -1, 0, 11, 11, "h"]])},
    {"id": "party_crown", "name": "Party Crown", "blurb": "Gold, five spikes, glowing gems. King of the soi.",
     "hat": True,
     "palette": {"g": "#E8B43C", "r": "#FF2A1E!", "c": "#18D0FA!"},
     "boxes": ring(-4, 3, -3, 3, 7, "g") + ring(-4, 3, -3, 3, 8, "g")
              + [[-4, -4, -3, -3, 9, 10, "g"], [3, 3, -3, -3, 9, 10, "g"], [-1, 0, -3, -3, 9, 11, "g"],
                 [-4, -4, 3, 3, 9, 10, "g"], [3, 3, 3, 3, 9, 10, "g"],
                 [-1, 0, -4, -4, 8, 8, "r"], [-3, -3, -4, -4, 8, 8, "c"], [2, 2, -4, -4, 8, 8, "c"]]},
    {"id": "beer_helmet", "name": "Beer Helmet", "blurb": "Two cans, two straws, zero hands needed.",
     "hat": True,
     "palette": {"y": "#F2C230", "a": "#D88A1C", "s": "#C8C8CC", "r": "#D0161C"},
     "boxes": [[-5, 4, -4, 4, 7, 8, "y"], [-4, 3, -3, 3, 9, 9, "y"],
               [-8, -6, -1, 1, 7, 11, "a"], [-8, -6, -1, 1, 12, 12, "s"],
               [5, 7, -1, 1, 7, 11, "a"], [5, 7, -1, 1, 12, 12, "s"],
               [-7, -7, 0, 0, 13, 13, "r"], [-6, -6, -1, -1, 4, 13, "r"], [-6, -3, -4, -4, 3, 3, "r"],
               [6, 6, 0, 0, 13, 13, "r"], [5, 5, -1, -1, 4, 13, "r"], [2, 5, -4, -4, 3, 3, "r"]]},
    {"id": "neon_top_hat", "name": "Neon Top Hat", "blurb": "Tall, black, and the band glows red like the sign.",
     "hat": True,
     "palette": {"k": "#141114", "n": "#FF2A1E!"},
     "boxes": [[-6, 5, -5, 5, 7, 7, "k"], [-4, 3, -3, 3, 8, 13, "k"]] + ring(-4, 3, -3, 3, 8, "n")},
    {"id": "devil_horns", "name": "Devil Horns", "blurb": "Little red horns that glow. You know what you did.",
     "palette": {"r": "#E0141C!", "d": "#8C0610"},
     "boxes": mirror_boxes([[-4, -3, -1, 0, 7, 7, "d"], [-4, -4, -1, 0, 8, 9, "r"], [-5, -5, -1, -1, 10, 10, "r"]])},
    {"id": "neon_halo", "name": "Neon Halo", "blurb": "A gold neon ring floating over you. Innocent. Probably.",
     "palette": {"g": "#FFDD78!"},
     "boxes": ring(-4, 3, -3, 3, 11, "g")},
    {"id": "neon_mohawk", "name": "Neon Mohawk", "blurb": "A pink fin, shaved sides. The drummer approves.",
     "hides": ["hair_"],
     "palette": {"p": "#FF3FA4", "q": "#C0227A", "s": "#2A1C1A"},
     "boxes": [[-4, 3, -3, 3, 7, 7, "s"], [-1, 0, -4, 4, 8, 9, "p"], [-1, 0, -3, 3, 10, 10, "p"],
               [-1, 0, -2, 2, 11, 11, "q"], [-1, 0, -4, -4, 10, 10, "q"], [-1, 0, 4, 4, 10, 10, "q"]]},
]

# Glasses: 10-wide pixel rows over the eyes (x -5..4), plus temples back to the ears.
TEMPLES = [[-5, -5, -3, 0, 4, 4, "t"], [4, 4, -3, 0, 4, 4, "t"]]

EYES = [
    {"id": "star_shades", "name": "Star Shades", "blurb": "Pink stars. You are the headliner now.",
     "palette": {"y": "#FF3FA4!", "t": "#C0227A"}, "face_top": 6,
     "face": ["..y....y..", ".yyy..yyy.", "yyyyyyyyyy", ".yy....yy.", ".y.y..y.y."]},
    {"id": "heart_shades", "name": "Heart Shades", "blurb": "For when the band plays your song.",
     "palette": {"r": "#E8142C", "t": "#8C0610"}, "face_top": 5,
     "face": [".r.r..r.r.", "rrrrrrrrrr", ".rrr..rrr.", "..r....r.."]},
    {"id": "neon_visor", "name": "Neon Visor", "blurb": "One cyan strip. The future arrived at Black Cabin.",
     "palette": {"k": "#141114", "c": "#18D0FA!", "t": "#141114"}, "face_top": 5,
     "face": ["kkkkkkkkkk", "cccccccccc", "cccccccccc"]},
    {"id": "glasses_3d", "name": "3D Glasses", "blurb": "Red and blue. The stage looks deeper. It doesn't.",
     "palette": {"w": "#F4F1EA", "r": "#E0141C", "b": "#18A0FA", "t": "#F4F1EA"}, "face_top": 5,
     "face": ["wwwwwwwwww", "wrrrwwbbbw", "wrrrwwbbbw", "wwww..wwww"]},
    {"id": "shutter_shades", "name": "Shutter Shades", "blurb": "Black Cabin red, horizontal slats. Very 2007.",
     "palette": {"r": "#C8141C", "t": "#141114"}, "face_top": 5,
     "face": ["rrrrrrrrrr", "..........", "rrrrrrrrrr", ".rrrrrrrr."]},
    {"id": "monocle", "name": "Gold Monocle", "blurb": "One gold ring and a chain. Rather distinguished.",
     "palette": {"g": "#E8B43C"}, "face_top": 5,
     "face": [".....gggg.", ".....g..g.", ".....g..g.", ".....gggg."],
     "boxes": [[3, 3, -4, -4, -1, 1, "g"]], "no_temples": True},
    {"id": "pixel_shades", "name": "Pixel Shades", "blurb": "Deal with it.",
     "palette": {"k": "#0E0C0E", "w": "#F4F1EA", "t": "#0E0C0E"}, "face_top": 4,
     "face": ["kkkkkkkkkk", ".kwkk.kwkk", "..kk...kk."]},
    {"id": "ski_goggles", "name": "Ski Goggles", "blurb": "Bangkok is 33 degrees. Wear them anyway.",
     "palette": {"p": "#6A2C9A", "o": "#FF8A30!", "t": "#6A2C9A"}, "face_top": 5,
     "face": ["pppppppppp", "poooooooop", "poooooooop", "pppppppppp"],
     "boxes": [[-5, 4, 4, 4, 4, 4, "t"]]},
    {"id": "googly_eyes", "name": "Googly Eyes", "blurb": "They wobble. Well, they look like they would.",
     "palette": {"w": "#F8F6F0", "k": "#0E0C0E"}, "face_top": 6,
     "face": [".ww....ww.", "wwww..wwww", "wwkw..wkkw", "wkkw..wwww"], "no_temples": True},
    {"id": "flame_shades", "name": "Flame Shades", "blurb": "Black lenses, flames on top. Too hot for the soi.",
     "palette": {"o": "#FF6A13!", "y": "#FFD23C!", "k": "#141114", "t": "#141114"}, "face_top": 6,
     "face": [".o.y..y.o.", "oyoo..ooyo", "kkkkkkkkkk", ".kkkkkkkk.", "..kk..kk.."]},
]

TOPS = [
    {"id": "bc_logo_tee", "name": "Black Cabin Logo Tee", "blurb": "Black tee, the BC in neon red. The classic.",
     "top_colour": "#161314", "palette": {"r": "#FF2A1E!"},
     "chest": ["rr...rr", "r.r.r..", "rr..r..", "r.r.r..", "rr...rr"]},
    {"id": "bc_cabin_tee", "name": "Cabin Tee", "blurb": "The little gold cabin from the sign, door lit red.",
     "top_colour": "#161314", "palette": {"y": "#E8B43C", "n": "#FF2A1E!"},
     "chest": ["...y...", "..yyy..", ".yyyyy.", "yyyyyyy", ".yynyy.", ".yynyy."]},
    {"id": "bc_racer_tee", "name": "Black Cabin Racer", "blurb": "Red and white racing stripes across black.",
     "top_colour": "#161314", "palette": {"r": "#C8141C", "w": "#F4F1EA"}, "chest_full": True,
     "chest": ["", "rrrrrrrrrr", "wwwwwwwwww", "rrrrrrrrrr"]},
    {"id": "skull_tee", "name": "Skull Tee", "blurb": "A white skull on black. The drummer has three.",
     "top_colour": "#161314", "palette": {"w": "#F4F1EA"},
     "chest": [".www.", "wwwww", "w.w.w", "wwwww", ".w.w."]},
    {"id": "tiger_tee", "name": "Tiger Stripes", "blurb": "Orange with black stripes. Roar at the bar.",
     "top_colour": "#E07A1F", "palette": {"k": "#141010"}, "chest_full": True,
     "chest": ["k.k..k.k.k", ".k.k...k.k", "k...kk...k", "..k....k.."]},
    {"id": "lightning_tee", "name": "Lightning Tee", "blurb": "Purple, with a yellow bolt that glows.",
     "top_colour": "#5A2A8A", "palette": {"y": "#FFD23C!"},
     "chest": ["...yy", "..yy.", ".yyyy", "..yy.", ".yy..", "yy..."]},
    {"id": "heart_tee", "name": "Heart Tee", "blurb": "White tee, a big red heart. Wear it on your chest.",
     "top_colour": "#F2EEE6", "palette": {"r": "#D0161C"},
     "chest": [".r.r.", "rrrrr", "rrrrr", ".rrr.", "..r.."]},
    {"id": "tux_tee", "name": "Tuxedo Tee", "blurb": "Black tie dress code, solved with a printed tee.",
     "top_colour": "#F2EEE6", "palette": {"k": "#141114", "r": "#C8141C"}, "chest_full": True,
     "chest": ["kkk.rr.kkk", "kkk....kkk", "kkk..k.kkk", "kkk....kkk", "kkk..k.kkk"]},
    {"id": "pint_tee", "name": "Pint Tee", "blurb": "Navy tee, a frothy pint on the front.",
     "top_colour": "#1C2A4A", "palette": {"w": "#F8F4E8", "a": "#F2A72C"},
     "chest": ["wwwww", "aaaaa", "aaaaa", "aaaaa", ".aaa."]},
    {"id": "disco_tee", "name": "Disco Tee", "blurb": "Silver, with a disco ball that sparkles.",
     "top_colour": "#A2A2B0", "palette": {"c": "#18D0FA!", "m": "#FF3FA4!", "w": "#FFFFFF"},
     "chest": [".cmc.", "mwcwm", "cwmwc", ".mcm."]},
]


def diagonal(col, gem):
    """A sash from one shoulder to the other hip, on the front, with shot glasses on it."""
    out = []
    for i in range(9):
        out.append(["X0+%d" % i, "X0+%d" % i, "Y0-1", "Y0-1", "C-%d" % (1 + i), "C-%d" % (1 + i), col])
        if i % 2 == 1:
            out.append(["X0+%d" % i, "X0+%d" % i, "Y0-2", "Y0-2", "C-%d" % (1 + i), "C-%d" % i, gem])
    return out


ACC = [
    {"id": "gold_chain", "name": "Gold Chain", "blurb": "Heavy, gold, with a dollar sign. Very rock and roll.",
     "palette": {"g": "#E8B43C"},
     "boxes": [["X0+1", "X0+1", "Y0-1", "Y0-1", "C-1", "C-1", "g"], ["X1-1", "X1-1", "Y0-1", "Y0-1", "C-1", "C-1", "g"],
               ["X0+2", "X0+2", "Y0-1", "Y0-1", "C-2", "C-2", "g"], ["X1-2", "X1-2", "Y0-1", "Y0-1", "C-2", "C-2", "g"],
               [-2, 1, "Y0-1", "Y0-1", "C-3", "C-3", "g"], [-1, 0, "Y0-2", "Y0-2", "C-5", "C-4", "g"]]},
    {"id": "bow_tie", "name": "Red Bow Tie", "blurb": "Big, red, a little crooked. Classy enough.",
     "palette": {"r": "#C8141C", "d": "#8C0610"},
     "boxes": [[-3, -2, "Y0-1", "Y0-1", "C-2", "C-1", "r"], [-1, 0, "Y0-1", "Y0-1", "C-2", "C-1", "d"],
               [1, 2, "Y0-1", "Y0-1", "C-2", "C-1", "r"]]},
    {"id": "guitar_back", "name": "Guitar on the Back", "blurb": "A red guitar strapped on. You are the band now.",
     "palette": {"r": "#B0141C", "b": "#5A3620", "w": "#F4F1EA", "s": "#141010"},
     "boxes": [[-3, 2, "Y1+1", "Y1+2", 0, 3, "r"], [-2, 1, "Y1+1", "Y1+2", 4, 4, "r"],
               [-1, 0, "Y1+3", "Y1+3", 1, 2, "s"], [-1, 0, "Y1+1", "Y1+1", 5, "C+3", "b"],
               [-2, 1, "Y1+1", "Y1+1", "C+4", "C+5", "w"],
               ["X0", "X0", "Y0-1", "Y0-1", 1, "C-1", "s"]]},
    {"id": "angel_wings", "name": "Angel Wings", "blurb": "White feathered wings. For the good nights.",
     "palette": {"w": "#F8F6F0", "c": "#D8D4CC"},
     "boxes": mirror_boxes([["X0-3", -1, "Y1+1", "Y1+1", "C-4", "C+1", "w"], ["X0-5", "X0-4", "Y1+1", "Y1+1", "C-2", "C+3", "w"],
                            ["X0-6", "X0-6", "Y1+1", "Y1+1", "C", "C+3", "c"], ["X0-3", "X0-2", "Y1+1", "Y1+1", "C-6", "C-5", "c"]])},
    {"id": "bat_wings", "name": "Bat Wings", "blurb": "Black and purple, with spikes. For the other nights.",
     "palette": {"k": "#1C1220", "p": "#6A2C9A"},
     "boxes": mirror_boxes([["X0-3", -1, "Y1+1", "Y1+1", "C-3", "C", "p"], ["X0-6", "X0-4", "Y1+1", "Y1+1", "C-1", "C+2", "p"],
                            ["X0-6", -1, "Y1+1", "Y1+1", "C+1", "C+1", "k"], ["X0-7", "X0-7", "Y1+1", "Y1+1", "C+1", "C+3", "k"],
                            ["X0-4", "X0-4", "Y1+1", "Y1+1", "C-3", "C-2", "k"], ["X0-6", "X0-6", "Y1+1", "Y1+1", "C-2", "C-1", "k"]])},
    {"id": "keg_backpack", "name": "Keg Backpack", "blurb": "A silver mini keg on your back, red tap on top.",
     "palette": {"s": "#B8BCC4", "d": "#6E7480", "r": "#D0161C", "k": "#141010"},
     "boxes": [[-3, 2, "Y1+1", "Y1+4", 1, "C-2", "s"], [-3, 2, "Y1+1", "Y1+4", 2, 2, "d"],
               [-3, 2, "Y1+1", "Y1+4", "C-3", "C-3", "d"], [-1, 0, "Y1+2", "Y1+3", "C-1", "C-1", "r"],
               ["X0", "X0", "Y0-1", "Y0-1", 2, "C-1", "k"], ["X1", "X1", "Y0-1", "Y0-1", 2, "C-1", "k"]]},
    {"id": "feather_boa", "name": "Pink Feather Boa", "blurb": "Fluffy, pink, dramatic. Karaoke night essential.",
     "palette": {"p": "#FF5FB0", "q": "#FF8CCB"},
     "boxes": [["X0-1", "X1+1", "Y0-1", "Y1+1", "C-1", "C-1", "p"], ["X0", "X1", "Y0-1", "Y0-1", "C-2", "C-2", "q"],
               ["X0", "X0+1", "Y0-1", "Y0-1", 0, "C-3", "p"], ["X1-1", "X1", "Y0-1", "Y0-1", 1, "C-3", "q"]]},
    {"id": "shot_bandolier", "name": "Shot Bandolier", "blurb": "A leather sash with shot glasses. Refills at the bar.",
     "palette": {"b": "#5A3620", "g": "#F2A72C"},
     "boxes": diagonal("b", "g")},
    {"id": "devil_tail", "name": "Devil Tail", "blurb": "A red tail with an arrow tip. Pairs with the horns.",
     "palette": {"r": "#D0161C", "n": "#FF2A1E!"},
     "boxes": [[-1, 0, "Y1+1", "Y1+1", 0, 0, "r"], [-1, 0, "Y1+2", "Y1+2", -1, -1, "r"],
               [-1, 0, "Y1+3", "Y1+3", -1, 0, "r"], [-1, 0, "Y1+4", "Y1+4", 1, 2, "r"],
               [-2, 1, "Y1+5", "Y1+5", 3, 3, "n"], [-1, 0, "Y1+5", "Y1+5", 4, 4, "n"]]},
    {"id": "vip_lanyard", "name": "VIP Lanyard", "blurb": "Red cord, gold pass. Access all areas (the lounge).",
     "palette": {"r": "#C8141C", "w": "#F4F1EA", "g": "#E8B43C", "n": "#FF2A1E!"},
     "boxes": [["X0+2", "X0+2", "Y0-1", "Y0-1", "C-3", "C-1", "r"], ["X1-2", "X1-2", "Y0-1", "Y0-1", "C-3", "C-1", "r"],
               ["X0+2", "X1-2", "Y0-1", "Y0-1", "C-4", "C-4", "r"],
               [-2, 1, "Y0-1", "Y0-1", "C-8", "C-5", "g"], [-1, 0, "Y0-2", "Y0-2", "C-6", "C-6", "n"]]},
]


def build():
    items = []
    for cat, lst in (("head", HEAD), ("eyes", EYES), ("top", TOPS), ("acc", ACC)):
        for i, it in enumerate(lst):
            e = dict(it)
            e["cat"] = cat
            e["sort"] = i
            e.setdefault("boxes", [])
            if e.get("hat"):        # hats sit one row up, on the brim row of the kit's hats (bc_chars.py T + 2)
                e["boxes"] = [b[:4] + [b[4] + 1, b[5] + 1] + b[6:] for b in e["boxes"]]
            if cat == "eyes" and not e.get("no_temples"):
                e["boxes"] = e["boxes"] + TEMPLES
            e["price_coins"] = None
            e["price_thb"] = None
            items.append(e)
    return {"_doc": "Generated by tools/merch_catalog.py; edit there. See scripts/merch/merch.gd.",
            "v": 1, "categories": CATEGORIES, "items": items}


def sql_text(s):
    return "'" + s.replace("'", "''") + "'"


def main():
    data = build()
    ids = [it["id"] for it in data["items"]]
    assert len(ids) == len(set(ids)), "duplicate ids"
    with open(os.path.join(ROOT, "game", "data", "merch.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent="\t", ensure_ascii=False)
        f.write("\n")
    rows = []
    for it in data["items"]:
        rows.append("  (%s, %s, %s, %d, true, true)" % (sql_text(it["id"]), sql_text(it["cat"]), sql_text(it["name"]),
                                                     it["sort"]))
    sql = ("-- Generated by tools/merch_catalog.py from the same source as game/data/merch.json. Run after the\n"
           "-- migration 20261120000002_player_profile_merch.sql. Prices stay NULL (money is Daniele's call); a re-run\n"
           "-- updates names, order and categories and never touches prices or inventory.\n"
           "insert into public.merch_items (item_id, category, name, sort, free_pick, active) values\n"
           + ",\n".join(rows) + "\n"
           "on conflict (item_id) do update set category = excluded.category, name = excluded.name,\n"
           "  sort = excluded.sort;\n")
    with open(os.path.join(ROOT, "supabase", "seed", "merch_items.sql"), "w", encoding="utf-8", newline="\n") as f:
        f.write(sql)
    counts = {}
    for it in data["items"]:
        counts[it["cat"]] = counts.get(it["cat"], 0) + 1
    print("merch.json + merch_items.sql:", counts)


if __name__ == "__main__":
    main()
