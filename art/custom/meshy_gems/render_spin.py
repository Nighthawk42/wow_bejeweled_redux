"""Blender: render a GLB spinning about its vertical axis into N transparent frames.

blender -b -P render_spin.py -- <model.glb> <out_dir> [frames=20] [degrees=180] [size=200] [shadeless=1]
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
model, out_dir = argv[0], argv[1]
frames = int(argv[2]) if len(argv) > 2 else 20
degrees = float(argv[3]) if len(argv) > 3 else 180.0
size = int(argv[4]) if len(argv) > 4 else 200
shadeless = (argv[5] != "0") if len(argv) > 5 else True
os.makedirs(out_dir, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=model)
meshes = [o for o in scene.objects if o.type == "MESH"]

# Parent everything to a pivot at the model's bounding-box center.
corners = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
hi = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
center = (lo + hi) / 2
pivot = bpy.data.objects.new("pivot", None)
scene.collection.objects.link(pivot)
pivot.location = center
for o in scene.objects:
    if o.parent is None and o is not pivot:
        o.parent = pivot
        o.matrix_parent_inverse = pivot.matrix_world.inverted()

# Shadeless: show the painted texture exactly, no scene lighting.
if shadeless:
    for o in meshes:
        for slot in o.material_slots:
            mat = slot.material
            if not mat or not mat.use_nodes:
                continue
            nodes, links = mat.node_tree.nodes, mat.node_tree.links
            bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
            out = next((n for n in nodes if n.type == "OUTPUT_MATERIAL"), None)
            if not bsdf or not out:
                continue
            emission = nodes.new("ShaderNodeEmission")
            color_in = bsdf.inputs["Base Color"]
            if color_in.links:
                links.new(color_in.links[0].from_socket, emission.inputs["Color"])
            else:
                emission.inputs["Color"].default_value = color_in.default_value
            links.new(emission.outputs["Emission"], out.inputs["Surface"])

# Orthographic camera looking along -Y (glTF front faces +Y after import... find widest view).
extent = hi - lo
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
# The model's depth axis is its thinnest; look along it.
axes = sorted(range(3), key=lambda i: extent[i])
depth_axis = axes[0]
direction = Vector((0, 0, 0))
direction[depth_axis] = 1
distance = max(extent) * 4
cam.location = center + direction * distance
cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Z" if depth_axis != 2 else "Y").to_euler()
# Spin axis: the model's vertical (largest of the two remaining axes is treated as up = Z in glTF).
spin_axis = 2 if depth_axis != 2 else 1
cam_data.ortho_scale = max(extent[i] for i in range(3) if i != depth_axis) * 1.04

scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = size
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("world")
scene.world = world

for i in range(frames):
    angle = math.radians(degrees * i / frames)
    rot = [0.0, 0.0, 0.0]
    rot[spin_axis] = angle
    pivot.rotation_euler = rot
    scene.render.filepath = os.path.join(out_dir, f"frame_{i + 1:02d}.png")
    bpy.ops.render.render(write_still=True)
print("rendered", frames, "frames; depth axis", depth_axis, "spin axis", spin_axis, "extent", tuple(round(v, 3) for v in extent))
