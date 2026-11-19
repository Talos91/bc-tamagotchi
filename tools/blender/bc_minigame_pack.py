"""Packs the raw frames of bc_minigame_sprites.py into the game's minigame sprites (system Python + Pillow + numpy).

    python tools/blender/bc_minigame_pack.py            (after the Blender run; reads %TEMP%/bc_mg_raw)

Writes, per game, game/assets/minigames/<game>/:
  <sprite>.png        frames side by side (one row), RGBA, transparent background
  <sprite>_glow.png   same layout: the sprite's emissive parts blurred, to draw ADDITIVELY under or over it
  backdrop.png        the game's room, blurred and darkened (RGB), where the game has one
  sprites.json        frame size, count, names, anchor pixel, named points, notes, texture bytes
plus game/assets/minigames/README.md (the wiring notes, regenerated) and one contact sheet per game in
docs/art/screens/minigame-sprites/<game>.png. Texture memory = width x height x 4 bytes per file (Godot imports
these lossless, no mipmaps, so they sit in GPU memory as RGBA8; RGB backdrops are counted as RGBA to be safe).
"""
import json
import os
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
RAW = os.path.join(tempfile.gettempdir(), "bc_mg_raw")
OUT = os.path.join(REPO, "game", "assets", "minigames")
SHEETS = os.path.join(REPO, "docs", "art", "screens", "minigame-sprites")
FONT = os.path.join(REPO, "game", "assets", "fonts", "Lato-Bold.ttf")
FONT_R = os.path.join(REPO, "game", "assets", "fonts", "Lato-Regular.ttf")
MAX_PX = 2000                      # house rule: no committed image over 2000 px
BUDGET_MB = 4.0                    # brief: <= 4 MB of loaded textures per game (plan section 1.3 allows 6)
BG = (20, 10, 12)
GLOW_SCALE = 2                     # glow strips are saved at half size (they are blurry): draw them scaled x2
GAMES = ("neon_moth", "coaster_flip", "soi_dash", "shake_serve", "pour_perfect", "front_row_rhythm",
         "candle_talk", "neon_pinball")
TITLES = {"neon_moth": "Neon Moth", "coaster_flip": "Coaster Flip", "soi_dash": "Soi Dash",
          "shake_serve": "Shake & Serve", "pour_perfect": "Pour Perfect", "front_row_rhythm": "Front Row Rhythm",
          "candle_talk": "Candle Talk", "neon_pinball": "Neon Pinball"}
SCRIPTS = {g: "game/scripts/minigames/%s.gd" % g for g in GAMES}
PER_REGULAR = ("coaster_flip", "candle_talk")   # one regular_<id>.png is loaded per game, not all eight


def glow_of(emit, ppv):
    """Emission-only render -> soft additive glow (RGBA, premultiplied look kept in rgb)."""
    a = np.asarray(emit.convert("RGBA"), dtype=np.float32) / 255.0
    rgb = a[..., :3] * a[..., 3:4]
    lum = rgb.max(axis=2)
    rgb[lum < 0.12] = 0.0
    im = Image.fromarray((rgb * 255).astype(np.uint8), "RGB")
    b1 = np.asarray(im.filter(ImageFilter.GaussianBlur(4)), dtype=np.float32) / 255.0
    b2 = np.asarray(im.filter(ImageFilter.GaussianBlur(9)), dtype=np.float32) / 255.0
    g = np.clip(b1 * 1.1 + b2 * 1.0, 0, None)
    alpha = np.clip(g.max(axis=2) * 1.3, 0, 0.85)
    col = np.where(alpha[..., None] > 1e-4, g / np.maximum(g.max(axis=2, keepdims=True), 1e-4), 0)
    out = np.dstack([np.clip(col, 0, 1), alpha])
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def backdrop_of(path, blur=3.2, dark=0.62):
    im = Image.open(path).convert("RGB")
    im = im.filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(im, dtype=np.float32)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w]
    v = 1.0 - 0.45 * (((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) / 2
    a = a * dark * np.clip(v, 0.4, 1)[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")


def mb(n):
    return n / (1024 * 1024)


def strip(images):
    w, h = images[0].size
    out = Image.new(images[0].mode, (w * len(images), h), (0, 0, 0, 0) if images[0].mode == "RGBA" else BG)
    for i, im in enumerate(images):
        out.paste(im, (i * w, 0))
    return out


def pack():
    with open(os.path.join(RAW, "manifest.json"), encoding="utf-8") as fh:
        man = json.load(fh)
    report = {}
    for game in GAMES:
        sprites = [s for s in man["sprites"] if s["game"] == game]
        if not sprites:
            continue
        gdir = os.path.join(OUT, game)
        os.makedirs(gdir, exist_ok=True)
        keep = set()
        meta = {"game": game, "sprites": {}}
        files = []
        for s in sprites:
            name = s["name"]
            frames = [Image.open(os.path.join(RAW, game, "%s_%d.png" % (name, f))) for f in range(s["frames"])]
            if s.get("alpha"):                                         # see-through frames (glass back wall)
                frames = [im if a >= 1 else Image.fromarray(
                    (np.asarray(im.convert("RGBA"), dtype=np.float32) * [1, 1, 1, a]).astype(np.uint8), "RGBA")
                    for im, a in zip(frames, s["alpha"])]
            if s["opaque"]:
                frames = [im.convert("RGB") for im in frames]
                if name == "backdrop":
                    frames = [backdrop_of(os.path.join(RAW, game, "%s_0.png" % name), blur=1.6, dark=0.75)]
            sheet = strip(frames)
            assert max(sheet.size) <= MAX_PX, (game, name, sheet.size)
            fn = name + ".png"
            sheet.save(os.path.join(gdir, fn), optimize=True)
            keep.add(fn)
            entry = {"file": fn, "frames": s["frames"], "frame_w": s["w"], "frame_h": s["h"],
                     "frame_names": s["frame_names"], "anchor_px": s["anchor_px"], "points": s["points"],
                     "ppv": s["ppv"], "view_yaw_elev": s["view"], "note": s["note"],
                     "bytes": sheet.size[0] * sheet.size[1] * 4}
            if "stack_step_px" in s:
                entry["stack_step_px"] = s["stack_step_px"]
            files.append((fn, entry["bytes"], name))
            if s["glow"]:
                gl = strip([glow_of(Image.open(os.path.join(RAW, game, "%s_%d_emit.png" % (name, f))), s["ppv"])
                            for f in range(s["frames"])])
                gfn = name + "_glow.png"
                gl = gl.resize((gl.size[0] // GLOW_SCALE, gl.size[1] // GLOW_SCALE), Image.LANCZOS)
                gl.save(os.path.join(gdir, gfn), optimize=True)
                keep.add(gfn)
                entry["glow_file"] = gfn
                entry["glow_scale"] = GLOW_SCALE
                entry["glow_bytes"] = gl.size[0] * gl.size[1] * 4
                files.append((gfn, entry["glow_bytes"], name))
            meta["sprites"][name] = entry
        bd = man.get("backdrops", {}).get(game)
        if bd and os.path.exists(bd["path"]):
            im = backdrop_of(bd["path"])
            im.save(os.path.join(gdir, "backdrop.png"), optimize=True)
            keep.add("backdrop.png")
            meta["sprites"]["backdrop"] = {"file": "backdrop.png", "frames": 1, "frame_w": im.size[0],
                                           "frame_h": im.size[1], "frame_names": None, "anchor_px": [0, 0],
                                           "points": {}, "note": "the game's room from the venue (" + bd["note"]
                                           + "), blurred and darkened; stretch to cover the play area",
                                           "bytes": im.size[0] * im.size[1] * 4}
            files.append(("backdrop.png", im.size[0] * im.size[1] * 4, "backdrop"))
        for f in os.listdir(gdir):                                     # stale sprites from an older run
            if f.endswith(".png") and f not in keep:
                os.remove(os.path.join(gdir, f))
                if os.path.exists(os.path.join(gdir, f + ".import")):
                    os.remove(os.path.join(gdir, f + ".import"))
        total = sum(b for _, b, _ in files)
        loaded = total
        if game in PER_REGULAR:
            regs = [b for fn, b, n in files if n.startswith("regular_")]
            loaded = total - sum(regs) + (max(regs) if regs else 0)
        meta["texture_bytes_all_files"] = total
        meta["texture_bytes_loaded"] = loaded
        meta["texture_mb_loaded"] = round(mb(loaded), 2)
        with open(os.path.join(gdir, "sprites.json"), "w", encoding="utf-8", newline="\n") as fh:
            json.dump(meta, fh, indent=1)
            fh.write("\n")
        report[game] = dict(meta=meta, files=files, total=total, loaded=loaded)
        print("BC_MG_PACK %-17s %2d files  all %.2f MB  loaded %.2f MB%s" % (
            game, len(files), mb(total), mb(loaded), "" if mb(loaded) <= BUDGET_MB else "  OVER BUDGET"))
        contact_sheet(game, meta)
    write_readme(report)
    return report


def font(size, bold=True):
    try:
        return ImageFont.truetype(FONT if bold else FONT_R, size)
    except OSError:
        return ImageFont.load_default()


def contact_sheet(game, meta):
    os.makedirs(SHEETS, exist_ok=True)
    W = 1600
    items = []
    gdir = os.path.join(OUT, game)
    for name, e in meta["sprites"].items():
        im = Image.open(os.path.join(gdir, e["file"])).convert("RGBA")
        if e.get("glow_file"):                                         # show it as the game would: glow added
            g = Image.open(os.path.join(gdir, e["glow_file"])).convert("RGBA").resize(im.size, Image.BILINEAR)
            g = np.asarray(g, dtype=np.float32)
            s = np.asarray(im, dtype=np.float32)
            base = np.zeros_like(s)
            base[..., :3] = BG
            base[..., 3] = 255
            ga = g[..., 3:4] / 255.0
            sa = s[..., 3:4] / 255.0
            col = base[..., :3] * (1 - sa) + s[..., :3] * sa
            col = col + g[..., :3] * ga * 0.9                          # additive, over the sprite
            im = Image.fromarray(np.dstack([np.clip(col, 0, 255), np.full(col.shape[:2], 255)]).astype(np.uint8), "RGBA")
        items.append((name, e, im))
    pad, lab = 18, 40
    rows, row, x, rh = [], [], pad, 0
    for name, e, im in items:
        scale = min(1.0, (W - 2 * pad) / im.size[0], 520 / im.size[1])
        sw, sh = max(1, int(im.size[0] * scale)), max(1, int(im.size[1] * scale))
        if x + sw > W - pad and row:
            rows.append((row, rh))
            row, x, rh = [], pad, 0
        row.append((name, e, im, sw, sh, x))
        x += max(sw, 150) + pad
        rh = max(rh, sh)
    if row:
        rows.append((row, rh))
    H = 90 + sum(rh + lab + pad for _, rh in rows) + pad
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    d.text((pad, 18), "%s  -  voxel sprites (look B), rendered from the Blender kit" % TITLES[game], font=font(30),
           fill=(242, 214, 140))
    d.text((pad, 56), "%d files, %.2f MB loaded as textures (budget 4 MB). Shown at 1:1 unless marked; glow added "
           "where the game would draw it." % (len(meta["sprites"]) + sum(1 for e in meta["sprites"].values()
                                                                          if e.get("glow_file")),
                                              meta["texture_mb_loaded"]), font=font(18, False), fill=(200, 190, 180))
    y = 90
    checker = None
    for row, rh in rows:
        for name, e, im, sw, sh, x0 in row:
            if (sw, sh) != im.size:
                im = im.resize((sw, sh), Image.LANCZOS)
            sheet.paste(im, (x0, y + rh - sh), im)
            if e["frames"] > 1:
                fw = sw / e["frames"]
                for k in range(1, e["frames"]):
                    d.line([(x0 + k * fw, y + rh - sh), (x0 + k * fw, y + rh)], fill=(60, 40, 44))
            tag = "%s  %dx%d x%d" % (name, e["frame_w"], e["frame_h"], e["frames"])
            if sw < im.size[0] or (sw, sh) != (e["frame_w"] * e["frames"], e["frame_h"]):
                tag += "  (scaled)"
            d.text((x0, y + rh + 6), tag, font=font(16), fill=(236, 226, 210))
        y += rh + lab + pad
    out = os.path.join(SHEETS, game + ".png")
    assert max(sheet.size) <= MAX_PX, sheet.size
    sheet.save(out, optimize=True)
    print("BC_MG_PACK contact sheet -> %s (%dx%d)" % (out, W, H))


README_HEAD = """# Minigame sprites (look B) — wiring notes for the builders

Generated by `tools/blender/bc_minigame_pack.py` from the renders of `tools/blender/bc_minigame_sprites.py`
(Blender kit style: `bc_kit` palette, jitter and seam texture, emissive neon; characters from `bc_chars`).
**Do not hand-edit the PNGs or this file: change the generator and rerun** (Blender ~2 min, then the packer):

```
"C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" --background --factory-startup --python tools/blender/bc_minigame_sprites.py
python tools/blender/bc_minigame_pack.py
```

then `godot --headless --path game --import` for the `.import` files. Review scene: `blender/BlackCabinMinigames.blend`
(one collection per game, frame 0 of every sprite, labelled). Contact sheets: `docs/art/screens/minigame-sprites/`.
Plan and budget: `docs/design/11-minigame-quality.md` §1 (look B accepted 2026-11-18; the look itself awaits
Daniele's OK on hub card `minigame-sprites-review`).

## How to draw them (all games)

- **Sheets are one row of equal frames.** Frame `i` is the region `Rect2(i * frame_w, 0, frame_w, frame_h)`
  (`AtlasTexture`, or `draw_texture_rect_region`). Frame counts, names and sizes are in each game's `sprites.json`
  and the tables below.
- **Anchor**: `anchor_px` is the pixel inside a frame that sits on the model point the game positions (bottom
  centre, a pivot, a neck...). Draw at `pos - anchor_px * scale`.
- **Scale**: frames are rendered at roughly the size they appear on a 780 px wide play area (the phone width at
  the pixel-ratio cap 2). Scale with the play area's fit scale like the current draw code; never above ~1.5× or
  the voxels go soft. Filter: linear is fine; `TEXTURE_FILTER_NEAREST` keeps the voxel edges crisp at 1×–2×.
- **Glow**: `<name>_glow.png` has the same frame layout at HALF size (`glow_scale` 2: draw it scaled ×2, so a
  glow frame is `Rect2(i * frame_w / 2, 0, frame_w / 2, frame_h / 2)`). Draw it with an additive `CanvasItemMaterial`
  (`blend_mode = BLEND_MODE_ADD`), at the same position, after the sprite (neon halos sit over the backing
  plate); fade or pulse it with `modulate.a`.
  No post-process shaders (plan §1.3).
- **Backdrops** (`backdrop.png`, RGB): the game's own room in the venue, blurred and darkened; stretch to cover
  the play area (keep aspect, crop). Pinball uses `playfield.png` instead.
- **Memory**: load a game's textures when it opens, free them when it closes. Numbers below are GPU bytes as
  imported (lossless, no mipmaps, RGBA8). Coaster Flip and Candle Talk ship one file per regular: load only
  the one for `config.regular`.
- Tests: nothing here is loaded by the game yet; the suites do not change.
"""


def _report_from_disk(game):
    """A game not in this run (`--game` subset): its section comes from the sprites.json already on disk, so a
    partial run rewrites only its own games and the README keeps every other game (Q6, 2026-11-19)."""
    path = os.path.join(OUT, game, "sprites.json")
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as fh:
        meta = json.load(fh)
    files = []
    for name, e in meta["sprites"].items():
        files.append((e["file"], e["bytes"], name))
        if e.get("glow_file"):
            files.append((e["glow_file"], e["glow_bytes"], name))
    return dict(meta=meta, files=files, total=meta["texture_bytes_all_files"], loaded=meta["texture_bytes_loaded"])


def write_readme(report):
    for g in GAMES:
        if g not in report:
            d = _report_from_disk(g)
            if d:
                report[g] = d
    lines = [README_HEAD]
    lines.append("## Texture memory per game\n")
    lines.append("| Game | Files | All files | Loaded with the game open | Budget |")
    lines.append("|---|---|---|---|---|")
    for g in GAMES:
        if g not in report:
            continue
        r = report[g]
        lines.append("| %s | %d | %.2f MB | **%.2f MB**%s | 4 MB |" % (
            TITLES[g], len(r["files"]), mb(r["total"]), mb(r["loaded"]),
            " (one regular)" if g in PER_REGULAR else ""))
    lines.append("")
    for g in GAMES:
        if g not in report:
            continue
        meta = report[g]["meta"]
        lines.append("## %s (`%s`) — `game/assets/minigames/%s/`\n" % (TITLES[g], SCRIPTS[g], g))
        lines.append("| Sprite | Frames | Frame px | Anchor px | Glow | Notes |")
        lines.append("|---|---|---|---|---|---|")
        for name, e in meta["sprites"].items():
            fr = str(e["frames"])
            if e.get("frame_names"):
                fr += ": " + ", ".join("%d %s" % (i, n) for i, n in enumerate(e["frame_names"]))
            note = e["note"]
            if e.get("points"):
                note += "; points " + ", ".join("%s %s" % (k, v) for k, v in e["points"].items())
            if "stack_step_px" in e:
                note += "; stack_step_px %s" % e["stack_step_px"]
            lines.append("| `%s` | %s | %d × %d | %s | %s | %s |" % (
                e["file"], fr, e["frame_w"], e["frame_h"], e["anchor_px"], "yes" if e.get("glow_file") else "",
                note))
        lines.append("\nLoaded: **%.2f MB**. Contact sheet: `docs/art/screens/minigame-sprites/%s.png`.\n"
                     % (meta["texture_mb_loaded"], g))
    with open(os.path.join(OUT, "README.md"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))
    print("BC_MG_PACK README -> %s" % os.path.join(OUT, "README.md"))


if __name__ == "__main__":
    pack()
    sys.exit(0)
