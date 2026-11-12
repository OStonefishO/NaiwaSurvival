import bpy
import bmesh
import math
from mathutils import Vector, Euler

# ---------- helpers ----------
def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.curves):
        for d in list(datablocks):
            if d.users == 0:
                datablocks.remove(d)

def material(name, color, roughness=0.55, metallic=0.0):
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        bsdf.inputs['Base Color'].default_value = color
        bsdf.inputs['Roughness'].default_value = roughness
        bsdf.inputs['Metallic'].default_value = metallic
        m.diffuse_color = color
    return m

def uv_sphere(name, loc, scale, mat, segments=32, rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return o

def add_group(obj, bone):
    vg = obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')

def limb(name, start, end, r1, r2, mat, vertices=10):
    start = Vector(start); end = Vector(end)
    direction = end - start
    length = direction.length
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=length, location=(start + end) * 0.5)
    o = bpy.context.object
    o.name = name
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = direction.to_track_quat('Z', 'Y')
    o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return o

def curve_mouth():
    curve = bpy.data.curves.new('MouthCurve', 'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = 8
    curve.bevel_depth = 0.014
    curve.bevel_resolution = 2
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(2)
    pts = [Vector((-0.13, -0.455, 1.28)), Vector((0.0, -0.475, 1.265)), Vector((0.13, -0.455, 1.28))]
    for i, p in enumerate(pts):
        bp = spline.bezier_points[i]
        bp.co = p
        bp.handle_left_type = 'AUTO'
        bp.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new('Mouth', curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material('MouthDark', (0.18, 0.12, 0.06, 1), 0.7))
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target='MESH')
    return obj

# ---------- clean & build ----------
clean()
yellow = material('FrogYellow', (1.0, 0.66, 0.08, 1), 0.52)
cream = material('BellyCream', (1.0, 0.88, 0.68, 1), 0.62)
green = material('EyeGreen', (0.20, 0.52, 0.24, 1), 0.40)
black = material('EyeBlack', (0.008, 0.012, 0.008, 1), 0.22)
dark = material('HandOlive', (0.20, 0.18, 0.10, 1), 0.68)
highlight = material('EyeSpark', (1.0, 0.97, 0.88, 1), 0.25)

# body: a pear-shaped soft mass
body = uv_sphere('Body', (0, 0, 1.02), (0.56, 0.45, 0.84), yellow, 40, 28)
bm = bmesh.new()
bm.from_mesh(body.data)
zs = [v.co.z for v in bm.verts]
zmin, zmax = min(zs), max(zs)
for v in bm.verts:
    zn = (v.co.z - zmin) / max(0.0001, (zmax - zmin))
    # broad lower belly, gentle taper toward the head; no neck
    f = 0.86 + 0.18 * math.sin(math.pi * min(1.0, max(0.0, zn)) ** 0.9)
    v.co.x *= f
    v.co.y *= f
    # tuck the very bottom so short legs can show
    if zn < 0.20:
        v.co.z = zmin + (v.co.z - zmin) * 0.82
bm.to_mesh(body.data)
bm.free()
body.data.update()
add_group(body, 'spine')

# belly patch (in front, local -Y is front)
belly = uv_sphere('Belly', (0, -0.438, 0.82), (0.36, 0.035, 0.38), cream, 36, 24)
add_group(belly, 'spine')

# eyes and pupils
parts = [body, belly]
for side, x in [('L', 0.235), ('R', -0.235)]:
    ring = uv_sphere('Eye' + side, (x, -0.365, 1.49), (0.155, 0.075, 0.175), green, 28, 18)
    add_group(ring, 'head')
    pupil = uv_sphere('Pupil' + side, (x, -0.425, 1.485), (0.078, 0.025, 0.092), black, 24, 16)
    add_group(pupil, 'head')
    spark = uv_sphere('Spark' + side, (x + 0.025, -0.446, 1.515), (0.022, 0.012, 0.026), highlight, 16, 10)
    add_group(spark, 'head')
    parts += [ring, pupil, spark]

mouth = curve_mouth()
add_group(mouth, 'head')
parts.append(mouth)

# arms
for side, sx, ex in [('L', 0.67, 0.84), ('R', -0.67, -0.84)]:
    arm = limb('Arm' + side, (sx, 0.0, 1.18), (ex, -0.02, 0.64), 0.12, 0.075, yellow)
    add_group(arm, 'arm.' + side)
    hand = uv_sphere('Hand' + side, (ex, -0.035, 0.57), (0.115, 0.10, 0.13), dark, 20, 14)
    add_group(hand, 'arm.' + side)
    parts += [arm, hand]

# legs & feet
for side, x in [('L', 0.34), ('R', -0.34)]:
    leg = limb('Leg' + side, (x, 0.0, 0.46), (x, -0.01, 0.09), 0.145, 0.10, yellow)
    add_group(leg, 'leg.' + side)
    foot = uv_sphere('Foot' + side, (x, -0.15, 0.075), (0.18, 0.28, 0.10), dark, 24, 14)
    add_group(foot, 'leg.' + side)
    parts += [leg, foot]

# join all mesh parts
bpy.ops.object.select_all(action='DESELECT')
for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
frog = bpy.context.object
frog.name = 'NaiFrogMesh'
frog.data.name = 'NaiFrogMesh'
frog.location = (0, 0, 0)

# ---------- armature ----------
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
rig = bpy.context.object
rig.name = 'NaiFrogRig'
rig.data.name = 'NaiFrogRig'
eb = rig.data.edit_bones
for b in list(eb):
    eb.remove(b)

def bone(name, head, tail, parent=None):
    b = eb.new(name)
    b.head = head
    b.tail = tail
    if parent:
        b.parent = eb[parent]
    return b

bone('root', (0, 0, 0), (0, 0, 0.22))
bone('hips', (0, 0, 0.35), (0, 0, 0.75), 'root')
bone('spine', (0, 0, 0.75), (0, 0, 1.28), 'hips')
bone('head', (0, 0, 1.28), (0, 0, 1.78), 'spine')
bone('arm.L', (0.40, 0, 1.22), (0.66, -0.02, 0.60), 'spine')
bone('arm.R', (-0.40, 0, 1.22), (-0.66, -0.02, 0.60), 'spine')
bone('leg.L', (0.21, 0, 0.46), (0.21, -0.01, 0.08), 'hips')
bone('leg.R', (-0.21, 0, 0.46), (-0.21, -0.01, 0.08), 'hips')
bpy.ops.object.mode_set(mode='OBJECT')

# parent mesh to armature with skin
frog.parent = rig
mod = frog.modifiers.new('Armature', 'ARMATURE')
mod.object = rig

# ---------- animation ----------
bpy.context.scene.render.fps = 30
rig.animation_data_create()
for pb in rig.pose.bones:
    pb.rotation_mode = 'XYZ'

def clear_pose():
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)

def key_all(frame):
    for pb in rig.pose.bones:
        pb.keyframe_insert('location', frame=frame)
        pb.keyframe_insert('rotation_euler', frame=frame)
        pb.keyframe_insert('scale', frame=frame)

def make_action(name, frames, poses):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    for frame in frames:
        bpy.context.scene.frame_set(frame)
        clear_pose()
        pose = poses.get(frame, {})
        for bname, vals in pose.items():
            pb = rig.pose.bones[bname]
            if 'loc' in vals: pb.location = vals['loc']
            if 'rot' in vals: pb.rotation_euler = vals['rot']
            if 'scale' in vals: pb.scale = vals['scale']
        key_all(frame)
    act.use_frame_range = True
    act.frame_start = frames[0]
    act.frame_end = frames[-1]
    return act

# Idle
make_action('Idle', [1, 20, 40], {
    1: {'spine': {'scale': (1, 1, 1)}, 'head': {'rot': (0, 0, 0)}, 'arm.L': {'rot': (0, 0, 0.12)}, 'arm.R': {'rot': (0, 0, -0.12)}},
    20: {'spine': {'scale': (1.015, 1.015, 0.99), 'loc': (0, 0.012, 0)}, 'head': {'rot': (0.03, 0, 0)}, 'arm.L': {'rot': (0.04, 0, 0.16)}, 'arm.R': {'rot': (-0.03, 0, -0.15)}},
    40: {'spine': {'scale': (1, 1, 1)}, 'head': {'rot': (0, 0, 0)}, 'arm.L': {'rot': (0, 0, 0.12)}, 'arm.R': {'rot': (0, 0, -0.12)}},
})
# Walk
make_action('Walk', [1, 8, 15, 22, 30], {
    1: {'arm.L': {'rot': (0.6, 0, 0.1)}, 'arm.R': {'rot': (-0.6, 0, -0.1)}, 'leg.L': {'rot': (-0.55, 0, 0)}, 'leg.R': {'rot': (0.55, 0, 0)}, 'spine': {'loc': (0, 0, 0.01)}},
    8: {'arm.L': {'rot': (0, 0, 0.1)}, 'arm.R': {'rot': (0, 0, -0.1)}, 'leg.L': {'rot': (0, 0, 0)}, 'leg.R': {'rot': (0, 0, 0)}, 'spine': {'loc': (0, 0, 0.045)}},
    15: {'arm.L': {'rot': (-0.6, 0, 0.1)}, 'arm.R': {'rot': (0.6, 0, -0.1)}, 'leg.L': {'rot': (0.55, 0, 0)}, 'leg.R': {'rot': (-0.55, 0, 0)}, 'spine': {'loc': (0, 0, 0.01)}},
    22: {'arm.L': {'rot': (0, 0, 0.1)}, 'arm.R': {'rot': (0, 0, -0.1)}, 'leg.L': {'rot': (0, 0, 0)}, 'leg.R': {'rot': (0, 0, 0)}, 'spine': {'loc': (0, 0, 0.045)}},
    30: {'arm.L': {'rot': (0.6, 0, 0.1)}, 'arm.R': {'rot': (-0.6, 0, -0.1)}, 'leg.L': {'rot': (-0.55, 0, 0)}, 'leg.R': {'rot': (0.55, 0, 0)}, 'spine': {'loc': (0, 0, 0.01)}},
})
# Run
make_action('Run', [1, 7, 13, 20], {
    1: {'arm.L': {'rot': (0.95, 0, 0.1)}, 'arm.R': {'rot': (-0.95, 0, -0.1)}, 'leg.L': {'rot': (-0.8, 0, 0)}, 'leg.R': {'rot': (0.8, 0, 0)}, 'spine': {'rot': (0.18, 0, 0), 'loc': (0, 0, 0.02)}},
    7: {'arm.L': {'rot': (0, 0, 0.1)}, 'arm.R': {'rot': (0, 0, -0.1)}, 'leg.L': {'rot': (0, 0, 0)}, 'leg.R': {'rot': (0, 0, 0)}, 'spine': {'rot': (0.22, 0, 0), 'loc': (0, 0, 0.09)}},
    13: {'arm.L': {'rot': (-0.95, 0, 0.1)}, 'arm.R': {'rot': (0.95, 0, -0.1)}, 'leg.L': {'rot': (0.8, 0, 0)}, 'leg.R': {'rot': (-0.8, 0, 0)}, 'spine': {'rot': (0.18, 0, 0), 'loc': (0, 0, 0.02)}},
    20: {'arm.L': {'rot': (0.95, 0, 0.1)}, 'arm.R': {'rot': (-0.95, 0, -0.1)}, 'leg.L': {'rot': (-0.8, 0, 0)}, 'leg.R': {'rot': (0.8, 0, 0)}, 'spine': {'rot': (0.18, 0, 0), 'loc': (0, 0, 0.02)}},
})
# Attack
make_action('Attack', [1, 5, 10, 18], {
    1: {'arm.R': {'rot': (0, 0, 0)}, 'spine': {'rot': (0, 0, 0)}},
    5: {'arm.R': {'rot': (-1.5, 0, -0.3)}, 'spine': {'rot': (0.1, 0, -0.12)}},
    10: {'arm.R': {'rot': (0.5, 0, 0.2)}, 'spine': {'rot': (0.05, 0, 0.1)}},
    18: {'arm.R': {'rot': (0, 0, 0)}, 'spine': {'rot': (0, 0, 0)}},
})
# Hit
make_action('Hit', [1, 4, 10], {
    1: {'spine': {'scale': (1, 1, 1)}},
    4: {'spine': {'scale': (1.08, 0.92, 1.04), 'rot': (-0.12, 0, 0)}, 'head': {'rot': (0.15, 0, 0)}},
    10: {'spine': {'scale': (1, 1, 1)}},
})
# Dodge
make_action('Dodge', [1, 4, 9], {
    1: {'spine': {'scale': (1, 1, 1)}},
    4: {'spine': {'scale': (0.82, 1.18, 0.82), 'rot': (0.3, 0, 0), 'loc': (0, 0.08, 0)}},
    9: {'spine': {'scale': (1, 1, 1)}},
})
# Death
make_action('Death', [1, 18, 36], {
    1: {'hips': {'rot': (0, 0, 0)}, 'spine': {'rot': (0, 0, 0)}},
    18: {'hips': {'rot': (-1.1, 0, 0), 'loc': (0, 0, -0.25)}, 'spine': {'rot': (-0.4, 0, 0)}, 'head': {'rot': (0.3, 0, 0)}},
    36: {'hips': {'rot': (-1.35, 0, 0), 'loc': (0, 0, -0.35)}, 'spine': {'scale': (1.05, 0.9, 1.0)}},
})
rig.animation_data.action = bpy.data.actions['Idle']
bpy.context.scene.frame_set(1)

# lights / camera / world for preview
bpy.ops.object.light_add(type='AREA', location=(2.5, -3.5, 4.0))
key = bpy.context.object; key.name = 'Key'; key.data.energy = 350; key.data.size = 4
key.rotation_euler = (0.8, 0.15, -0.6)
bpy.ops.object.light_add(type='SUN', location=(-3, 2, 5))
sun = bpy.context.object; sun.name = 'Sun'; sun.data.energy = 2.0
bpy.ops.object.camera_add(location=(3.1, -4.3, 2.3))
cam = bpy.context.object; cam.name = 'PreviewCam'; cam.data.lens = 62
direction = Vector((0, 0, 0.95)) - cam.location
cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
bpy.context.scene.camera = cam
world = bpy.data.worlds.get('World') or bpy.data.worlds.new('World')
bpy.context.scene.world = world
world.use_nodes = True
bg = next((n for n in world.node_tree.nodes if n.type == 'BACKGROUND'), None)
if bg:
    bg.inputs[0].default_value = (0.035, 0.055, 0.045, 1)
    bg.inputs[1].default_value = 0.45
bpy.context.scene.render.resolution_x = 1200
bpy.context.scene.render.resolution_y = 900

# save + export
bpy.ops.wm.save_as_mainfile(filepath=r'D:\Godot project\NaiwaForest\source_blend\naifrog_rig.blend')
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
frog.select_set(True)
bpy.context.view_layer.objects.active = rig

export_path = r'D:\Godot project\NaiwaForest\assets\models\frog\naifrog.glb'
try:
    bpy.ops.export_scene.gltf(
        filepath=export_path, export_format='GLB', use_selection=True,
        export_apply=False, export_animations=True,
        export_animation_mode='ACTIONS', export_bake_animation=True,
        export_yup=True, export_skins=True, export_morph=False
    )
except TypeError as e:
    print('EXPORT_OPTION_ERROR', e)
    bpy.ops.export_scene.gltf(filepath=export_path, export_format='GLB', use_selection=True, export_apply=False, export_animations=True)
print('DONE', export_path, 'objects', len(bpy.data.objects), 'actions', [a.name for a in bpy.data.actions])
