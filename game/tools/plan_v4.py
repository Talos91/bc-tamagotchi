"""Plan v4: the venue in metres, derived from the real floor map docs/art/direction/08-floor-map-real.png.

Measured on the 1500 x 771 px file (segmented by colour, see docs/art/plan-v4.md). One scale for both axes,
anchored on the main room's depth (stage wall to bar wall) = 15 m: 1 px = 0.03311 m. x east = (px - 201) * S,
z south = (py - 188) * S, so x 0 is the lobby's west (street) wall and z 0 the shared north wall of lounge and
main room. North is up (-z) as in plan_view.py. Rooms are (x0, z0, x1, z1); heights are 4 m everywhere.

Read by plan_view.py (rooms, doors, labels, and the planned furniture for `--planned`) and transcribed into
tools/build_venue.gd. Keep the two in step: build_venue.gd is the geometry of record, this file is the plan.
"""
S = 15.0 / 453.0   # metres per map pixel

ROOMS = {  # walkable rooms: name -> (x0, z0, x1, z1, level_y)
    "lobby":     (0.0, 5.05, 2.3, 14.9, 0.0),
    "corridor":  (2.3, 13.25, 15.45, 14.9, 0.0),
    "lounge":    (2.35, 0.0, 15.45, 13.15, 0.0),
    "stub":      (15.45, 10.1, 19.95, 12.4, 0.0),      # old corridor to the old toilets: alcove off the lounge, unused
    "buffer":    (15.45, 3.0, 20.1, 7.6, 0.0),
    "main":      (20.1, 0.0, 41.8, 15.0, 0.0),         # south wall z 15.0 behind the bar, z 12.65 east of x 35.75
    "main_se":   (35.75, 12.65, 41.8, 15.0, None),     # not floor: walled staff area + smoking room's north part
    "raised":    (39.5, 0.0, 41.8, 10.85, 0.15),       # +15 cm strip, couch along its east wall
    "vestibule": (20.2, 15.0, 24.35, 16.7, 0.0),       # toilet doors, kitchen curtain
    "smoking":   (38.3, 12.8, 41.8, 17.9, 0.0),
}
CLOSED = {  # never walkable (green on the map): name -> (x0, z0, x1, z1), built as dark boxes behind doors
    "backstage": (24.3, -3.2, 27.5, 0.0),
    "kitchen":   (6.6, 15.0, 20.1, 18.5),
    "toilet_f":  (24.4, 15.0, 28.9, 17.4),
    "toilet_m":  (20.1, 16.7, 24.35, 18.5),
    "old_toilet_n": (15.45, 7.65, 19.95, 10.1),
    "old_toilet_s": (15.45, 12.4, 19.95, 14.9),
    "staff_area": (35.75, 12.65, 38.25, 15.0),
}
OUTSIDE = {  # night exterior seen through glass
    "buffer_window": (15.45, -4.0, 20.1, 3.0),         # north of the buffer zone, bare tree outside (photo 22)
    "smoking_street": (41.8, 12.8, 46.0, 17.9),        # east of the smoking room (photos 13, 20)
}
BAR = {"counter": (21.8, 12.7, 35.75, 13.35), "back": (21.8, 13.35, 35.75, 15.0), "cashier": (28.95, 12.3, 30.35, 12.7)}
STAGE = (27.6, 0.0, 33.9, 4.15)                        # floor level, carpet tiles
DOORS = {  # name -> (x0, z0, x1, z1, kind)  kind: open | door | curtain | window | exit
    "street_door":   (-0.1, 6.25, 0.1, 8.1, "exit"),           # west wall of the lobby: spawn and leave
    "lobby_threshold": (0.0, 11.25, 2.3, 11.35, "open"),
    "sticker_door":  (12.8, 13.15, 14.5, 13.3, "door"),        # lounge south wall -> entrance corridor
    "lounge_buffer": (15.4, 3.0, 15.5, 7.6, "curtain"),
    "lounge_stub":   (15.4, 10.1, 15.5, 12.4, "open"),
    "old_toilet_door_n": (18.5, 10.05, 19.75, 10.15, "door"),
    "old_toilet_door_s": (18.5, 12.35, 19.75, 12.45, "door"),
    "buffer_main":   (20.0, 3.0, 20.15, 7.6, "curtain"),
    "buffer_window": (15.45, 2.9, 20.1, 3.05, "window"),
    "staff_door_n":  (25.35, -0.1, 26.45, 0.1, "door"),        # backstage
    "staff_door_bar": (37.0, 12.6, 38.1, 12.7, "door"),        # walled staff area
    "smoke_door":    (38.6, 12.6, 39.8, 12.85, "door"),        # red door
    "emergency_exit": (39.5, 17.85, 40.5, 18.0, "exit"),
    "smoking_glass": (41.75, 12.85, 41.9, 17.85, "window"),
    "kitchen_curtain": (20.15, 15.1, 20.25, 16.6, "curtain"),
    "toilet_f_door": (24.3, 15.1, 24.45, 16.2, "door"),
    "toilet_m_door": (22.6, 16.65, 23.7, 16.75, "door"),
}
LOUNGE_COLUMNS = [(8.95, 3.9), (8.95, 9.75)]
STAIRS = {"leg": (2.35, 8.5, 4.15, 11.5), "block": (2.35, 11.5, 8.65, 13.15)}   # leg = flight up along the west wall

# Planned furniture: (object, x, z, rotation_y, name). Footprints come from the kit manifest where the object exists,
# else from PLACEHOLDERS (w, d, h) below. Chairs and stools are listed where they shape the walkways.
TABLE_R = 0.9           # round_table footprint
CHAIR_OFF = 0.66        # chair centre from a round table's centre
TINY_ROW_Z = 5.1
TINY_ROW_X = [27.0, 28.45, 30.05, 31.55, 33.1, 34.6]
TINY_EAST_X = 34.85
TINY_EAST_Z = [0.95, 2.3, 3.5]
ROW5 = [(24.6, 8.4, 45), (27.45, 8.4, 45), (30.05, 8.4, 0), (32.7, 8.4, 45), (35.45, 8.4, 0)]   # Table0..4 (45 = diamond)
MALI_TABLE = 2
RAISED_TABLES_Z = [1.25, 3.1, 4.9, 7.3, 8.55]
RAISED_TABLE_X = 40.4
COUNTER_STOOLS_X = [24.65, 25.9, 27.1, 28.3, 30.95, 31.95, 32.95, 33.95, 34.95]
COUNTER_STOOL_Z = 12.2
BUFFER_TALL = [(16.7, 3.9), (18.7, 3.9), (16.7, 6.7), (18.7, 6.7)]
OPENING_TALL = [(20.5, 9.05), (20.5, 11.5)]
SMOKE_TABLES = [(41.2, 14.05), (38.75, 14.1), (38.75, 16.3), (41.2, 16.4)]
TREE = (37.2, 0.7)
TREE_OUTSIDE = (17.7, 1.0)

PLACEHOLDERS = {  # kit names the 🧱 session is modelling; box size (w, d, h) until the .glb lands
    "tall_table_square": (0.6, 0.6, 1.05), "tall_table_round": (0.6, 0.6, 1.05), "tall_stool": (0.35, 0.35, 0.75),
    "tiny_table": (0.5, 0.5, 0.5), "couch_long": (1.0, 0.5, 0.85), "shelf_wall_tile": (1.0, 0.25, 0.05),
    "raised_edge_neon": (1.0, 0.04, 0.04), "cashier_counter": (1.4, 0.4, 1.1), "reindeer_head": (0.5, 0.45, 0.7),
    "game_cabinet_bc": (0.7, 0.75, 1.8), "pinball_machine": (0.7, 1.4, 1.3), "red_door": (1.2, 0.1, 2.2),
    "emergency_door": (1.0, 0.1, 2.2), "sticker_door": (1.7, 0.1, 2.3), "staff_door": (1.1, 0.1, 2.2),
    "window_wall_panel": (1.0, 0.1, 4.0), "mirror_wall_panel": (1.0, 0.05, 2.6), "outdoor_tree_bare": (1.6, 1.6, 3.2),
    "smoke_table_square": (0.85, 0.85, 0.75), "smoke_table_round": (0.7, 0.7, 0.55), "wishbone_chair": (0.5, 0.5, 0.75),
    "ashtray": (0.12, 0.12, 0.05), "air_purifier": (0.35, 0.35, 0.8), "wall_picture_framed": (0.7, 0.05, 0.5),
    "picture_light": (0.4, 0.12, 0.08), "vinyl_record_wall": (0.32, 0.03, 0.32), "lightbox_bc": (0.9, 0.12, 0.35),
    "wine_fridge": (0.6, 0.6, 1.8), "par_on_stand": (0.35, 0.35, 1.6),
}


def planned_objects():
    """Furniture of the plan as (object, x, z, rot_deg, name); the plan render draws these before the build."""
    out = []
    add = lambda o, x, z, r=0.0, n="": out.append((o, x, z, r, n or o))
    # lounge: plant wall / neon / banquette / long table on the west wall, pinball on the west wall, cabinet by the stairs
    for i in range(4):
        add("plant_wall_tile", 2.5, 1.6 + i, 90, "PlantWall%d" % i)
    for i in range(4):
        add("banquette_straight", 2.65, 1.6 + i, 90, "Banquette%d" % i)
    add("communal_table", 3.9, 3.6, 90, "LongTable")
    for i in range(3):
        add("cafe_chair", 4.75, 2.6 + i, -90, "LongChair%d" % i)
    add("pinball_machine", 2.75, 7.2, 90, "Pinball")
    add("game_cabinet_bc", 9.4, 12.7, 0, "GameCabinet")
    for i, (x, z) in enumerate(LOUNGE_COLUMNS):
        add("white_column", x, z, 0, "Column%d" % i)
    add("crt_monitor", 11.2, 0.3, 0, "CRT")
    add("collectibles_shelf", 13.6, 0.22, 0, "Shelf")
    for i in range(2):
        add("bar_stool", 13.2 + i * 0.9, 1.5, 180, "LoungeStool%d" % i)
    for n, (x, z) in enumerate([(11.0, 5.0), (11.0, 9.0)]):
        add("round_table", x, z, 0, "LoungeTable%d" % n)
        for k, (dx, dz) in enumerate([(0, -CHAIR_OFF), (CHAIR_OFF, 0), (0, CHAIR_OFF), (-CHAIR_OFF, 0)]):
            add("cafe_chair", x + dx, z + dz, 0, "LoungeTable%dChair%d" % (n, k))
    add("stair_run", 3.25, 10.1, 0, "StairRun")
    # buffer zone
    for i, (x, z) in enumerate(BUFFER_TALL):
        add("tall_table_square", x, z, 0, "BufferTall%d" % i)
        add("tall_stool", x - 0.5, z, 0, "BufferTall%dStoolW" % i)
        add("tall_stool", x + 0.5, z, 0, "BufferTall%dStoolE" % i)
    add("par_on_stand", 15.9, 7.3, 0, "BufferPar")
    add("outdoor_tree_bare", TREE_OUTSIDE[0], TREE_OUTSIDE[1], 0, "TreeOutside")
    # main room, west opening
    for i, (x, z) in enumerate(OPENING_TALL):
        add("tall_table_square", x, z, 0, "OpeningTall%d" % i)
        add("tall_stool", x, z - 0.5, 0, "OpeningTall%dStoolN" % i)
        add("tall_stool", x, z + 0.5, 0, "OpeningTall%dStoolS" % i)
    # west of the stage: two four-chair tables and the rectangle
    for n, (x, z) in enumerate([(21.75, 1.2), (24.25, 1.2)]):
        add("round_table", x, z, 0, "WestTable%d" % n)
        for k, (dx, dz) in enumerate([(0, -CHAIR_OFF), (CHAIR_OFF, 0), (0, CHAIR_OFF), (-CHAIR_OFF, 0)]):
            add("cafe_chair", x + dx, z + dz, 0, "WestTable%dChair%d" % (n, k))
    add("communal_table", 24.65, 4.7, 90, "RectTableW")   # scaled 0.6 along its length: 2.4 x 1.0 m
    for k in range(2):
        add("cafe_chair", 24.65 - 0.75, 4.1 + k * 1.2, 90, "RectTableWChairW%d" % k)
        add("cafe_chair", 24.65 + 0.75, 4.1 + k * 1.2, -90, "RectTableWChairE%d" % k)
    # stage
    add("drum_kit", 30.75, 0.9, 0, "DrumKit")
    add("amp_stack", 28.0, 0.35, 0, "AmpStackL")
    add("amp_stack", 33.4, 0.35, 0, "AmpStackR")
    add("guitar_on_stand", 27.9, 1.6, 20, "Guitar")
    add("mic_stand", 28.9, 3.0, 0, "Mic0")
    add("mic_stand", 30.8, 3.1, 0, "Mic1")
    add("mic_stand", 32.6, 3.0, 0, "Mic2")
    for x in [28.3, 30.75, 33.2]:
        add("monitor_wedge", x, 3.85, 180, "Wedge%d" % int(x))
    add("pa_speaker", 27.3, 3.9, 0, "SpeakerL")
    add("pa_speaker", 34.2, 3.9, 0, "SpeakerR")
    # tiny tables
    for i, x in enumerate(TINY_ROW_X):
        add("tiny_table", x, TINY_ROW_Z, 0, "Tiny%d" % i)
        add("drum_stool", x - 0.32, TINY_ROW_Z + 0.5, 0, "Tiny%dStoolA" % i)
        add("drum_stool", x + 0.32, TINY_ROW_Z + 0.5, 0, "Tiny%dStoolB" % i)
    for i, z in enumerate(TINY_EAST_Z):
        add("tiny_table", TINY_EAST_X, z, 0, "TinyE%d" % i)
        add("drum_stool", TINY_EAST_X + 0.5, z - 0.32, 0, "TinyE%dStoolA" % i)
        add("drum_stool", TINY_EAST_X + 0.5, z + 0.32, 0, "TinyE%dStoolB" % i)
    add("stage_tree", TREE[0], TREE[1], -90, "TreeRightOfStage")
    # row of five four-chair tables (Mali at Table2)
    for n, (x, z, rot) in enumerate(ROW5):
        add("round_table", x, z, 0, "Table%d" % n)
        for k in range(4):
            import math
            a = math.radians(rot + k * 90)
            add("cafe_chair", x + math.sin(a) * CHAIR_OFF, z - math.cos(a) * CHAIR_OFF, 0, "Table%dChair%d" % (n, k))
    # east tables
    add("round_table", 38.2, 5.85, 0, "EastTable")
    for k in range(4):
        import math
        a = math.radians(45 + k * 90)
        add("cafe_chair", 38.2 + math.sin(a) * CHAIR_OFF, 5.85 - math.cos(a) * CHAIR_OFF, 0, "EastTableChair%d" % k)
    add("communal_table", 38.2, 8.45, 90, "RectTableE")   # scaled 0.475: 1.9 x 1.0 m
    for k in range(2):
        add("cafe_chair", 38.2 - 0.75, 8.0 + k * 0.9, 90, "RectTableEChairW%d" % k)
        add("cafe_chair", 38.2 + 0.75, 8.0 + k * 0.9, -90, "RectTableEChairE%d" % k)
    # raised strip
    for i, z in enumerate(RAISED_TABLES_Z):
        add("round_table", RAISED_TABLE_X, z, 0, "Raised%d" % i)       # scale 0.8
        add("cafe_chair", RAISED_TABLE_X - 0.6, z, -90, "Raised%dChair" % i)
    for i in range(10):
        add("couch_long", 41.55, 0.5 + i * 1.0, -90, "Couch%d" % i)
    # bar
    for i in range(14):
        add("bar_counter", 22.3 + i, 13.0, 180, "Counter%d" % i)
    for i in range(9):
        add("back_bar_art" if i == 4 else "back_bar_shelf", 22.55 + i * 1.5, 14.75, 180, "Bay%d" % i)
    add("cashier_counter", 29.65, 12.5, 0, "Cashier")
    for i, x in enumerate(COUNTER_STOOLS_X):
        add("bar_stool", x, COUNTER_STOOL_Z, 0, "Stool%d" % i)
    add("wine_fridge", 41.3, 12.3, 0, "WineFridge")
    # vestibule / toilet corridor
    add("vinyl_record_wall", 20.15, 13.6, 90, "Vinyl")
    add("wall_picture_framed", 22.3, 16.65, 0, "CorridorPicture")
    # smoking room
    for i, (x, z) in enumerate(SMOKE_TABLES):
        add("smoke_table_square", x, z, 0, "Smoke%d" % i)
        add("wishbone_chair", x, z - 0.7, 180, "Smoke%dChairN" % i)
        add("wishbone_chair", x, z + 0.7, 0, "Smoke%dChairS" % i)
    add("air_purifier", 40.3, 13.05, 0, "AirPurifier")
    return out
