"""Black Cabin Tamagotchi - entrance round review (Daniele 2026-11-20: "open in my blender how it would look before
pushing live").

Opens blender/BlackCabin.blend (written by bc_review.py from layout.json + venue.tscn), adds one camera per place of
the entrance round (the eagle greeter and its door, the corner view towards the eagle room, the poster booth, the mural
corridor, the Sticker door from both sides, the memory corner, the curtained corner, the merch stand), shows the near
walls BlackCabin.blend leaves out, hides the ceilings so nothing blocks the view, and saves
blender/BlackCabin-entrance-review.blend with the eagle camera active. A review file, not committed.

    blender --background --factory-startup --python tools/blender/bc_review.py -- --no-render
    blender --background --factory-startup --python tools/blender/bc_entrance_review.py
Open it with `-- --view` in a Blender window to start in the eagle camera with Material Preview:
    blender blender/BlackCabin-entrance-review.blend --python tools/blender/bc_entrance_review.py -- --view
"""
import os
import sys

import bpy
from mathutils import Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(REPO, "blender", "BlackCabin.blend")
OUT = os.path.join(REPO, "blender", "BlackCabin-entrance-review.blend")

# name: (eye, look-at) in Godot metres (x east, y up, z south); Blender = (x, -z, y)
CAMS = {
    "1 Street door: the eagle greets you": ((0.3, 1.75, 6.45), (2.1, 1.05, 7.3)),
    "2 Left of the eagle, the door (photo 13)": ((1.5, 1.6, 5.4), (1.15, 1.0, 8.6)),
    "3 Corner to the eagle room": ((1.2, 1.6, 14.5), (1.0, 1.0, 8.4)),
    "4 Poster booth": ((1.6, 1.7, 10.2), (0.3, 1.2, 14.3)),
    "5 Mural corridor": ((2.6, 1.7, 14.5), (13.0, 1.3, 13.3)),
    "6 Sticker door": ((12.6, 1.7, 14.75), (13.65, 1.3, 13.1)),
    "7 Sticker door from the lounge (photo 07)": ((12.6, 1.8, 8.6), (13.6, 1.1, 13.0)),
    "8 Memory corner (photo 09)": ((7.6, 1.7, 4.6), (4.2, 0.8, 0.2)),
    "9 Curtained corner (photo 08)": ((8.6, 1.9, 2.0), (15.4, 1.0, 1.4)),
    "10 Merch stand in the middle": ((14.6, 2.8, 10.2), (11.6, 0.6, 6.6)),
}


def g2b(p):
    return Vector((p[0], -p[2], p[1]))


def build():
    bpy.ops.wm.open_mainfile(filepath=SRC)
    scene = bpy.context.scene
    coll = bpy.data.collections.new("ENTRANCE REVIEW 2026-11-20")
    scene.collection.children.link(coll)
    first = None
    for name, (eye, at) in CAMS.items():
        cam = bpy.data.cameras.new(name)
        cam.lens = 18
        ob = bpy.data.objects.new(name, cam)
        ob.location = g2b(eye)
        ob.rotation_euler = (g2b(at) - g2b(eye)).to_track_quat("-Z", "Y").to_euler()
        coll.objects.link(ob)
        first = first or ob
    scene.camera = first
    # The near walls (west- and south-facing: the street wall, the eagle room's door wall, the portraits wall, the
    # Sticker door wall) are left out of BlackCabin.blend for its overview camera; these cameras stand inside the
    # rooms, so they come back here (Daniele 2026-11-20: "the blender has many invisible walls")
    near = bpy.context.view_layer.layer_collection.children["VENUE"].children.get("VENUE ceiling and near walls")
    if near is not None:
        near.exclude = False
    # The kit lineup (every piece side by side, labelled) stands where the lounge is: out of these views
    lineup = bpy.context.view_layer.layer_collection.children.get("KIT")
    if lineup is not None:
        lineup.exclude = True
    # Dark like the real place (Daniele 2026-11-20: "the end goal is to get the feel of the place which is dark (even if
    # it has light walls)"): the pale walls stay, the exposure comes down
    scene.view_settings.exposure = -1.0
    for ob in scene.objects:                                  # the overview's section labels lie on the floors
        if ob.type == "FONT":
            ob.hide_viewport = True
            ob.hide_render = True
    for ob in scene.objects:                                  # ceilings would block every view
        if "eiling" in ob.name:
            ob.hide_viewport = True
            ob.hide_render = True
    bpy.ops.wm.save_as_mainfile(filepath=OUT, compress=True)
    print("BC_ENTRANCE_REVIEW", OUT)


def view():
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            for sp in area.spaces:
                if sp.type == "VIEW_3D":
                    sp.shading.type = "MATERIAL"
                    sp.region_3d.view_perspective = "CAMERA"
                    sp.overlay.show_overlays = False


if __name__ == "__main__":
    if "--view" in sys.argv:
        bpy.app.timers.register(lambda: view(), first_interval=1.0)
    else:
        build()
