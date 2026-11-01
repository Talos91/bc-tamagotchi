"""Black Cabin Tamagotchi - contact sheet of the v4 kit additions.

Builds only the objects registered through bc_kit.kit4 (the baseline-map additions), lays them out on the kit's
labelled review grid with its lights and camera, and renders one still:
    blender --background --factory-startup --python tools/blender/bc_kit_sheet.py
    blender --background --factory-startup --python tools/blender/bc_kit_sheet.py -- --out <png> --names a,b,c
Default output: docs/art/screens/kit/kit-v4-additions.png (2400 x 1350, EEVEE). Nothing is exported; the GLBs,
manifest and blender/BlackCabinKit.blend come from bc_kit.py.
"""
import os
import sys
import tempfile

import bpy

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.path.join(os.getcwd(), "tools", "blender")
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import bc_kit as K                                                   # noqa: E402

OUT = os.path.join(K.REPO, "docs", "art", "screens", "kit", "kit-v4-additions.png")


def glow(scene):
    """Soft bloom on the emissives (same node-group compositor as bc_review.bloom)."""
    tree = bpy.data.node_groups.new("BC Bloom", "CompositorNodeTree")
    rl = tree.nodes.new("CompositorNodeRLayers")
    gl = tree.nodes.new("CompositorNodeGlare")
    out = tree.nodes.new("NodeGroupOutput")
    tree.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    for attr, val in (("glare_type", "BLOOM"), ("quality", "MEDIUM")):
        if hasattr(gl, attr):
            setattr(gl, attr, val)
    for key, val in (("Type", "Bloom"), ("Threshold", 1.0), ("Size", 0.6), ("Strength", 0.5)):
        if key in gl.inputs:
            gl.inputs[key].default_value = val
    tree.links.new(rl.outputs["Image"], gl.inputs["Image"])
    tree.links.new(gl.outputs["Image"], out.inputs[0])
    scene.compositing_node_group = tree
    scene.render.use_compositing = True


def main(names, out):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    K._MATS.clear()
    objects, manifest = {}, []
    for name, zone, size_class, anchor, fn, *extra in K.KIT:
        if name not in names:
            continue
        v = K.Vox()
        fn(v)
        ob, st = K.build_mesh(name, v, anchor)
        objects[name] = ob
        sx, sy, sz = st["size_vox"]
        manifest.append({"name": name, "zone": zone, "anchor": anchor,
                         "footprint_m": [sx * K.VOX, sy * K.VOX], "height_m": sz * K.VOX})
    missing = [n for n in names if n not in objects]
    assert not missing, "not in the kit: %s" % missing
    tmp = os.path.join(tempfile.gettempdir(), "bc_kit_sheet_tmp.blend")
    K.REVIEW_MAX_W = 12.0                                            # wider rows than the review file: fewer lines
    K.build_review(objects, manifest, path=tmp)                      # grid, labels, floor, lights, camera
    for p in (tmp, tmp + "1"):
        if os.path.exists(p):
            os.remove(p)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 2400, 1350
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.view_settings.view_transform = "Filmic" if "Filmic" in [
        i.name for i in type(scene.view_settings).bl_rna.properties["view_transform"].enum_items] else "Standard"
    scene.view_settings.look = "None"
    for ob in scene.objects:                                         # brighter than the review file: this is a still
        if ob.type == "LIGHT":
            ob.data.energy *= 1.8 if ob.data.type == "SUN" else 1.4
    cam = scene.camera                                               # closer than the review framing
    from mathutils import Vector
    aim = Vector((0.0, max(o.location.y for o in objects.values()) * 0.48, 0.4))
    cam.location = aim + (cam.location - aim) * 0.74
    cam.rotation_euler = (aim - cam.location).to_track_quat("-Z", "Y").to_euler()
    try:
        glow(scene)
    except Exception as exc:                                         # noqa: BLE001 - the sheet is still useful without bloom
        print("BC_SHEET glow skipped:", exc)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("BC_SHEET %d objects -> %s" % (len(objects), out))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = os.path.abspath(argv[argv.index("--out") + 1]) if "--out" in argv else OUT
    names = set(argv[argv.index("--names") + 1].split(",")) if "--names" in argv else set(K.V4_NAMES)
    main(names, out)
