"""Table QR codes for presence check-in (docs/design/08-presence.md §3, 08b §5).

    python docs/venue/qr/make_qr.py              # redraw everything from codes.json; new seats get new codes
    python docs/venue/qr/make_qr.py --new-all    # new tokens for every code (old printed codes stop working)
    python docs/venue/qr/make_qr.py --rotate Tiny3   # reprint one code (key as in codes.json)

The code set comes from the venue the game ships (game/scenes/venue/venue.tscn, seat markers with metas zone and
table, built by game/tools/build_venue.gd): every table of the Buffer and the Main room (zones Buffer, Tables,
Raised), one code per table (its chairs and stools go with it), plus one code per bar counter stool (all of them
check in to table "Bar", the bar's tablemates). No Lounge and no Smoking codes (Daniele 2026-11-20).

Writes, next to this file: codes.json (the record: one entry per printed code), png/<key>.png (one code each),
table-map.svg (the numbered map), qr-sheet.pdf (A4: cards labelled with number, name and place, then the map page)
and qr-sheet.png (page 1), and supabase/seed/venue_tables.sql (upsert of every code, every other code inactive).
game/tests/test_qr_codes.gd checks that all of these agree with the client's seats.
"""
import json, math, os, re, secrets, string, sys
import qrcode
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
VENUE = os.path.join(ROOT, 'game', 'scenes', 'venue', 'venue.tscn')
BASE = 'https://blackcabin.app/?t='
ZONES = ('Buffer', 'Tables', 'Raised', 'Bar')          # what gets a code; Lounge / Smoking do not
ZONE_NAME = {'Buffer': 'Buffer', 'Tables': 'Main room', 'Raised': 'Main room, raised (east wall)',
             'Bar': 'Main room, bar counter'}
ALPHABET = ''.join(c for c in string.ascii_letters + string.digits if c not in 'O0Il1')
# Rooms for the map (build_venue.gd constants, metres; x east, z south).
ROOMS = [('LOUNGE (no codes)', (2.35, 0.0, 13.1, 13.05), '#1c1414'), ('BUFFER', (15.45, 3.0, 4.65, 4.6), '#3a1f1f'),
         ('MAIN ROOM', (20.1, 0.0, 21.7, 15.0), '#221616'), ('STAGE', (27.6, 0.0, 6.3, 4.15), '#14324a'),
         ('RAISED', (39.5, 0.0, 2.3, 10.85), '#2d2d2d'), ('SMOKING (no codes)', (38.3, 12.85, 3.5, 5.05), '#1c1c1c'),
         ('ENTRANCE CORRIDOR', (2.15, 13.25, 13.3, 1.65), '#333333')]
BAR_COUNTER = (23.9, 12.6, 12.0, 0.8)


def seats():
    """[(name, zone, table, x, z)] for every sit seat in the shipped venue."""
    out = []
    for blk in re.split(r'\n(?=\[node )', open(VENUE, encoding='utf-8').read()):
        m = re.match(r'\[node name="([^"]+)"', blk)
        tb = re.search(r'metadata/table = "([^"]*)"', blk)
        zn = re.search(r'metadata/zone = "([^"]*)"', blk)
        tr = re.search(r'transform = Transform3D\(([^)]*)\)', blk)
        if m and tb and tb.group(1) and zn and tr:
            v = [float(a) for a in tr.group(1).split(',')]
            out.append((m.group(1), zn.group(1), tb.group(1), v[9], v[11]))
    return out


def label(key):
    for a, b in (('BarStool', 'Bar stool '), ('RectTableW', 'Long table W'), ('RectTableE', 'Long table E'),
                 ('EastTable', 'East table'), ('WestTable', 'West table '), ('BufferTall', 'Tall table B'),
                 ('OpeningTall', 'Tall table O'), ('TinyE', 'Small table E'), ('Tiny', 'Small table '),
                 ('Raised', 'Raised table '), ('Table', 'Round table ')):
        if key.startswith(a):
            return (b + key[len(a):]).strip()
    return key


def code_set():
    """The printed codes in map order: [{key, table_id, zone, x, z}], numbered 1..n."""
    tables, stools = {}, []
    for nm, zone, table, x, z in seats():
        if zone not in ZONES:
            continue
        if table == 'Bar':
            stools.append((x, z))
        else:
            tables.setdefault(table, (zone, []))[1].append((x, z))
    rows = []
    for t, (zone, pts) in tables.items():
        rows.append({'key': t, 'table_id': t, 'zone': zone,
                     'x': round(sum(p[0] for p in pts) / len(pts), 2), 'z': round(sum(p[1] for p in pts) / len(pts), 2)})
    # West to east, north to south inside each area; bar stools last, west to east (Bar stool 1 = westmost).
    order = {'Buffer': 0, 'Tables': 1, 'Raised': 2}
    rows.sort(key=lambda r: (order[r['zone']], round(r['x'] / 2.5), r['z']))
    for i, (x, z) in enumerate(sorted(stools)):
        rows.append({'key': 'BarStool%d' % (i + 1), 'table_id': 'Bar', 'zone': 'Bar', 'x': round(x, 2), 'z': round(z, 2)})
    for i, r in enumerate(rows):
        r['n'] = i + 1
        r['label'] = label(r['key'])
    return rows


def new_code(taken):
    while True:
        c = ''.join(secrets.choice(ALPHABET) for _ in range(10))
        if c not in taken:
            return c


def font(size, bold=True):
    names = ('segoeuib.ttf', 'arialbd.ttf', 'DejaVuSans-Bold.ttf') if bold else ('segoeui.ttf', 'arial.ttf', 'DejaVuSans.ttf')
    for f in names:
        for p in ('C:/Windows/Fonts/' + f, f):
            try:
                return ImageFont.truetype(p, size)
            except OSError:
                pass
    return ImageFont.load_default()


def qr_img(url, px):
    q = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=1, border=2)
    q.add_data(url)
    q.make(fit=True)
    img = q.make_image(fill_color='black', back_color='white').convert('RGB')
    k = max(1, px // img.width)                       # whole pixels per module: crisp print
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


# ---------------------------------------------------------------- map (SVG + raster share the geometry)
def map_shapes(rows, s, ox, oy):
    """Drawing list for the map at s px per metre: ('rect'|'text'|'dot', ...)."""
    X = lambda x: ox + x * s
    Y = lambda z: oy + z * s
    sh = []
    for name, (x, z, w, h), fill in ROOMS:
        sh.append(('rect', X(x), Y(z), w * s, h * s, fill, '#c33'))
        sh.append(('text', X(x) + 6, Y(z) + 16, name, '#e88', 13, 'start'))
    x, z, w, h = BAR_COUNTER
    sh.append(('rect', X(x), Y(z), w * s, h * s, '#6b3b1f', '#fc6'))
    sh.append(('text', X(x + w / 2), Y(z + h) + 16, 'BAR COUNTER (stools 1-9, west to east)', '#fc6', 12, 'middle'))
    for r in rows:
        sh.append(('dot', X(r['x']), Y(r['z']), r['n'], '#fc6' if r['zone'] == 'Bar' else '#ffd25a'))
    return sh


def write_svg(rows, path):
    s, ox, oy = 26, 20, 60
    W, H = int(ox * 2 + 42.5 * s), int(oy + 18.5 * s)
    o = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" font-family="Arial,sans-serif">' % (W, H),
         '<rect width="100%" height="100%" fill="#0d0a0a"/>',
         '<text x="20" y="30" fill="#fff" font-size="20" font-weight="bold">Black Cabin: QR check-in codes '
         '(top = north; the number is on each printed card)</text>']
    for e in map_shapes(rows, s, ox, oy):
        if e[0] == 'rect':
            o.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" stroke="%s" stroke-width="2"/>' % e[1:])
        elif e[0] == 'text':
            o.append('<text x="%.1f" y="%.1f" fill="%s" font-size="%d" font-weight="bold" text-anchor="%s">%s</text>'
                     % (e[1], e[2], e[4], e[5], e[6], e[3]))
        else:
            o.append('<circle cx="%.1f" cy="%.1f" r="10" fill="%s"/>' % (e[1], e[2], e[4]))
            o.append('<text x="%.1f" y="%.1f" fill="#000" font-size="11" font-weight="bold" text-anchor="middle">%d</text>'
                     % (e[1], e[2] + 4, e[3]))
    y = oy + 15.6 * s
    o.append('<text x="20" y="%.1f" fill="#fff" font-size="12">%s</text>' % (y, ' · '.join(
        '%d %s' % (r['n'], r['label']) for r in rows if r['zone'] != 'Bar')[:400]))
    o.append('<text x="20" y="%.1f" fill="#aaa" font-size="12">Keys (codes.json): %s</text>' % (y + 22, ' '.join(
        '%d=%s' % (r['n'], r['key']) for r in rows)))
    o.append('</svg>')
    open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(o) + '\n')


def map_page(rows, W, H, dpi_scale):
    """Landscape A4 map page for the PDF."""
    img = Image.new('RGB', (W, H), 'white')
    d = ImageDraw.Draw(img)
    m = int(40 * dpi_scale)
    d.text((m, m), 'Black Cabin - where each QR code goes (top = north)', fill='black', font=font(int(30 * dpi_scale)))
    s = (W - 2 * m) / 42.5
    oy = m + int(60 * dpi_scale)
    for e in map_shapes(rows, s, m, oy):
        if e[0] == 'rect':
            fill = {'#1c1414': '#eeeeee', '#1c1c1c': '#eeeeee', '#333333': '#e4e4e4', '#6b3b1f': '#c8a27a'}.get(e[5], '#f6efe6')
            d.rectangle([e[1], e[2], e[1] + e[3], e[2] + e[4]], fill=fill, outline='#a33', width=max(1, int(2 * dpi_scale)))
        elif e[0] == 'text':
            d.text((e[1], e[2] - 12 * dpi_scale), e[3], fill='#a33' if e[4] != '#fc6' else '#6b3b1f',
                   font=font(int(e[5] * 1.1 * dpi_scale)), anchor='la' if e[6] == 'start' else 'ma')
        else:
            r = int(13 * dpi_scale)
            d.ellipse([e[1] - r, e[2] - r, e[1] + r, e[2] + r], fill='black')
            d.text((e[1], e[2]), str(e[3]), fill='white', font=font(int(14 * dpi_scale)), anchor='mm')
    # Legend in columns under the map.
    y0 = oy + int(15.4 * s)
    f = font(int(15 * dpi_scale), False)
    cols = 4
    per = math.ceil(len(rows) / cols)
    cw = (W - 2 * m) // cols
    for i, r in enumerate(rows):
        x = m + (i // per) * cw
        y = y0 + (i % per) * int(21 * dpi_scale)
        d.text((x, y), '%2d  %s' % (r['n'], r['label']), fill='black', font=f)
    return img


# ---------------------------------------------------------------- sheet
def cards_pages(rows, codes, W, H, dpi_scale):
    cols, rws, m = 4, 5, int(40 * dpi_scale)
    top = int(60 * dpi_scale)
    cw, ch = (W - 2 * m) // cols, (H - 2 * m - top) // rws
    per = cols * rws
    pages = []
    n_pages = math.ceil(len(rows) / per)
    for p in range(n_pages):
        sheet = Image.new('RGB', (W, H), 'white')
        d = ImageDraw.Draw(sheet)
        d.text((m, int(18 * dpi_scale)), 'Black Cabin - scan to check in   (page %d of %d; map on the last page)' % (p + 1, n_pages),
               fill='black', font=font(int(26 * dpi_scale)))
        f_n, f_lab, f_sub = font(int(30 * dpi_scale)), font(int(21 * dpi_scale)), font(int(12 * dpi_scale), False)
        for i, r in enumerate(rows[p * per:(p + 1) * per]):
            x, y = m + (i % cols) * cw, m + top + (i // cols) * ch
            d.rectangle([x + 4, y + 4, x + cw - 4, y + ch - 4], outline='#999999', width=2)
            q = qr_img(BASE + codes[r['key']], min(cw, ch) - int(95 * dpi_scale))
            sheet.paste(q, (x + (cw - q.width) // 2, y + int(10 * dpi_scale)))
            d.text((x + int(12 * dpi_scale), y + int(8 * dpi_scale)), str(r['n']), fill='black', font=f_n)
            d.text((x + cw // 2, y + ch - int(62 * dpi_scale)), r['label'], fill='black', font=f_lab, anchor='mm')
            d.text((x + cw // 2, y + ch - int(38 * dpi_scale)), ZONE_NAME[r['zone']], fill='#333333', font=f_sub, anchor='mm')
            d.text((x + cw // 2, y + ch - int(20 * dpi_scale)), '#%d  %s  %s' % (r['n'], r['key'], codes[r['key']]),
                   fill='#666666', font=f_sub, anchor='mm')
        pages.append(sheet)
    return pages


def seed_sql(rows, codes):
    q = lambda s: "'" + s.replace("'", "''") + "'"
    vals = ',\n'.join('  (%s, %s, %s, %s, true)' % (q(codes[r['key']]), q(r['table_id']),
                                                    q(r['label']), q(r['zone']))
                      for r in rows)
    keep = ', '.join(q(codes[r['key']]) for r in rows)
    zones = ',\n'.join('  (%s, %s)' % (q(t), q(z)) for t, z in sorted({(r['table_id'], r['zone']) for r in rows}))
    return '\n'.join([
        '-- Generated by docs/venue/qr/make_qr.py: one active code per printed QR (Buffer + Main room tables, bar',
        '-- stools; no Lounge). %d codes, %d tables. Every other code goes inactive (old prints stop checking in).' %
        (len(rows), len({r['table_id'] for r in rows})),
        'begin;',
        'insert into public.venue_tables (code, table_id, label, zone, active) values',
        vals,
        'on conflict (code) do update set table_id = excluded.table_id, label = excluded.label,',
        '  zone = excluded.zone, active = true;',
        'update public.venue_tables set active = false where code not in (%s);' % keep,
        '-- Old rows of the same table carry the new zone too (bc_presences reads zone by table_id).',
        'update public.venue_tables v set zone = n.zone from (values',
        zones,
        ') as n (table_id, zone) where v.table_id = n.table_id and v.zone <> n.zone;',
        'commit;',
        '-- Check: select count(*) filter (where active), count(*) from public.venue_tables;  -- expect %d active' % len(rows),
        ''])


def main():
    path = os.path.join(HERE, 'codes.json')
    old = json.load(open(path, encoding='utf-8')) if os.path.exists(path) else []
    if isinstance(old, dict):                       # the 2026-11-19 format: {table: code}
        old = [{'key': k, 'code': v} for k, v in old.items()]
    known = {e['key']: e['code'] for e in old}
    retired = {e['code'] for e in old}   # never reuse a printed code
    if '--new-all' in sys.argv:
        known = {}
    if '--rotate' in sys.argv:
        known.pop(sys.argv[sys.argv.index('--rotate') + 1], None)
    rows = code_set()
    codes = {}
    for r in rows:
        codes[r['key']] = known.get(r['key']) or new_code(retired | set(codes.values()))
    rec = [{'n': r['n'], 'key': r['key'], 'code': codes[r['key']], 'table_id': r['table_id'], 'label': r['label'],
            'zone': r['zone']} for r in rows]
    json.dump(rec, open(path, 'w', encoding='utf-8', newline='\n'), indent=1)

    png = os.path.join(HERE, 'png')
    os.makedirs(png, exist_ok=True)
    for f in os.listdir(png):
        if f.endswith('.png'):
            os.remove(os.path.join(png, f))
    for r in rows:
        qr_img(BASE + codes[r['key']], 1200).save(os.path.join(png, '%02d-%s.png' % (r['n'], r['key'])))

    write_svg(rows, os.path.join(HERE, 'table-map.svg'))
    k = 2.0                                          # 300 dpi A4
    W, H = int(1240 * k), int(1754 * k)
    pages = cards_pages(rows, codes, W, H, k) + [map_page(rows, H, W, k)]
    pages[0].save(os.path.join(HERE, 'qr-sheet.png'))
    pages[0].save(os.path.join(HERE, 'qr-sheet.pdf'), resolution=300.0, save_all=True, append_images=pages[1:])

    seed = os.path.join(ROOT, 'supabase', 'seed', 'venue_tables.sql')
    open(seed, 'w', encoding='utf-8', newline='\n').write(seed_sql(rows, codes))
    by = {}
    for r in rows:
        by[r['zone']] = by.get(r['zone'], 0) + 1
    print('codes:', len(rows), by, 'tables:', len({r['table_id'] for r in rows}), '-> codes.json, png/, table-map.svg,',
          'qr-sheet.pdf (%d pages), supabase/seed/venue_tables.sql' % len(pages))


if __name__ == '__main__':
    main()
