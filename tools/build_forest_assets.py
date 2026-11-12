import bpy
import math
import os
from mathutils import Vector

ROOT = r'D:\Godot project\NaiwaForest'
ENV = os.path.join(ROOT, 'assets', 'models', 'environment')
BLD = os.path.join(ROOT, 'assets', 'models', 'buildings')
ENM = os.path.join(ROOT, 'assets', 'models', 'enemies')
for p in (ENV, BLD, ENM):
    os.makedirs(p, exist_ok=True)


def clean():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for ds in (bpy.data.meshes, bpy.data.materials, bpy.data.curves):
        for d in list(ds):
            if d.users == 0:
                ds.remove(d)


def mat(name, color, rough=0.75, metal=0.0, emission=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if emission > 0:
        b.inputs['Emission Color'].default_value = (*color, 1)
        b.inputs['Emission Strength'].default_value = emission
    m.diffuse_color = (*color, 1)
    return m


def root(name):
    e = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(e)
    return e


def parent(o, r):
    o.parent = r
    return o


def ico(r, name, loc, scale, material, subdiv=2, smooth=True):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    if smooth:
        bpy.ops.object.shade_smooth()
    return parent(o, r)


def cyl(r, name, loc, radius, depth, material, vertices=10, rot=(0, 0, 0), smooth=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material)
    if smooth:
        bpy.ops.object.shade_smooth()
    return parent(o, r)


def box(r, name, loc, size, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    return parent(o, r)


def cone(r, name, loc, radius, depth, material, vertices=10, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=0, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return parent(o, r)


def export(r, path):
    bpy.ops.object.select_all(action='DESELECT')
    r.select_set(True)
    for o in r.children_recursive:
        o.select_set(True)
    bpy.context.view_layer.objects.active = r
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_yup=True,
    )
    print('EXPORT', path)


# Materials
clean()
yellow = mat('FrogYellow', (1, 0.66, 0.08), 0.5)
cream = mat('BellyCream', (1, 0.88, 0.68), 0.7)
bark = mat('Bark', (0.30, 0.19, 0.10), 0.9)
bark_dark = mat('BarkDark', (0.18, 0.11, 0.06), 0.95)
leaf = mat('Leaf', (0.22, 0.44, 0.20), 0.9)
leaf_dark = mat('LeafDark', (0.11, 0.28, 0.14), 0.92)
leaf_light = mat('LeafLight', (0.38, 0.62, 0.30), 0.88)
rock = mat('Rock', (0.28, 0.28, 0.24), 0.95)
rock_dark = mat('RockDark', (0.18, 0.18, 0.16), 0.95)
mush = mat('Mushroom', (0.62, 0.22, 0.14), 0.8)
mush_spot = mat('MushroomSpot', (0.92, 0.82, 0.60), 0.8)
berry = mat('Berry', (0.72, 0.12, 0.12), 0.55)
wood = mat('Wood', (0.46, 0.30, 0.16), 0.9)
wood_dark = mat('WoodDark', (0.28, 0.18, 0.09), 0.95)
cloth = mat('Cloth', (0.72, 0.64, 0.45), 0.95)
gold = mat('Gold', (0.82, 0.58, 0.17), 0.35, 0.4)
slime = mat('Slime', (0.32, 0.62, 0.43), 0.35)
bug = mat('BugBody', (0.34, 0.22, 0.12), 0.8)
spike = mat('Spike', (0.56, 0.50, 0.34), 0.9)
dark = mat('Dark', (0.03, 0.04, 0.03), 0.4)
flame = mat('Flame', (1.0, 0.45, 0.08), 0.3, 0.0, 2.5)
glow = mat('HeartGlow', (0.25, 1.0, 0.65), 0.25, 0.0, 4.0)

# ---------------- environment ----------------
r = root('Tree')
cyl(r, 'Trunk', (0, 0, 1.35), 0.22, 2.7, bark, 8)
ico(r, 'CanopyLow', (0, 0, 2.55), (1.45, 1.35, 1.05), leaf_dark, 2)
ico(r, 'CanopyMid', (0.35, -0.15, 3.05), (1.15, 1.05, 0.85), leaf, 2)
ico(r, 'CanopyHigh', (-0.35, 0.15, 2.95), (0.9, 0.85, 0.7), leaf_light, 2)
export(r, os.path.join(ENV, 'tree.glb'))

r = root('MushroomPatch')
for i, (x, z, s) in enumerate([(-0.25, 0, 1.0), (0.28, 0.1, 0.72), (0.0, -0.25, 0.55)]):
    cyl(r, 'Stem%d' % i, (x, z, 0.36 * s), 0.13 * s, 0.72 * s, cream, 8)
    ico(r, 'Cap%d' % i, (x, z, 0.78 * s), (0.42 * s, 0.42 * s, 0.20 * s), mush, 2)
    for k in range(3):
        a = k * 2.1 + i
        ico(r, 'Spot%d_%d' % (i, k), (x + math.cos(a) * 0.22 * s, z + math.sin(a) * 0.18 * s, 0.86 * s), (0.08 * s, 0.08 * s, 0.025 * s), mush_spot, 1)
export(r, os.path.join(ENV, 'mushroom_patch.glb'))

r = root('Rock')
ico(r, 'RockA', (0, 0, 0.32), (0.62, 0.48, 0.42), rock, 2)
ico(r, 'RockB', (0.38, 0.12, 0.18), (0.28, 0.24, 0.20), rock_dark, 1)
ico(r, 'RockC', (-0.28, -0.15, 0.14), (0.24, 0.20, 0.16), rock, 1)
export(r, os.path.join(ENV, 'rock.glb'))

r = root('BranchPile')
for i in range(5):
    a = i * 1.2
    cyl(r, 'Branch%d' % i, (math.cos(a) * 0.12, math.sin(a) * 0.12, 0.11 + i * 0.025), 0.045, 1.0, bark if i % 2 else wood, 6, (1.35, 0, a))
export(r, os.path.join(ENV, 'branch_pile.glb'))

r = root('BerryBush')
ico(r, 'BushA', (0, 0, 0.34), (0.62, 0.52, 0.42), leaf_dark, 2)
ico(r, 'BushB', (0.35, 0.1, 0.28), (0.38, 0.34, 0.30), leaf, 2)
for i in range(8):
    a = i * 2.2
    ico(r, 'Berry%d' % i, (math.cos(a) * 0.42, math.sin(a) * 0.35, 0.42 + math.sin(i) * 0.12), (0.08, 0.08, 0.08), berry, 1)
export(r, os.path.join(ENV, 'berry_bush.glb'))

# ---------------- buildings ----------------
r = root('Campfire')
for i in range(8):
    a = i * math.tau / 8
    ico(r, 'Stone%d' % i, (math.cos(a) * 0.62, math.sin(a) * 0.62, 0.12), (0.18, 0.15, 0.12), rock, 1)
for i in range(3):
    cyl(r, 'Log%d' % i, (0, 0, 0.17 + i * 0.05), 0.09, 1.0, wood_dark, 6, (math.pi * 0.5, 0, i * 1.05))
cone(r, 'Flame', (0, 0, 0.65), 0.24, 0.72, flame, 8)
export(r, os.path.join(BLD, 'campfire.glb'))

r = root('Workbench')
for x in (-0.7, 0.7):
    for y in (-0.35, 0.35):
        box(r, 'Leg', (x, y, 0.43), (0.12, 0.12, 0.86), wood_dark)
box(r, 'Top', (0, 0, 0.9), (1.7, 0.9, 0.14), wood)
box(r, 'Vice', (0.45, 0.1, 0.99), (0.35, 0.18, 0.08), rock)
cyl(r, 'ToolHandle', (-0.35, 0.15, 1.05), 0.04, 0.55, wood_dark, 6, (0, 1.1, 0.3))
export(r, os.path.join(BLD, 'workbench.glb'))

r = root('Chest')
box(r, 'Base', (0, 0, 0.35), (0.95, 0.62, 0.62), wood)
box(r, 'Lid', (0, 0, 0.72), (1.0, 0.66, 0.18), wood_dark)
for x in (-0.3, 0.3):
    box(r, 'Band', (x, 0, 0.45), (0.08, 0.68, 0.76), gold)
box(r, 'Latch', (0, -0.34, 0.52), (0.16, 0.06, 0.22), gold)
export(r, os.path.join(BLD, 'chest.glb'))

r = root('Bed')
box(r, 'Frame', (0, 0, 0.2), (1.35, 2.0, 0.22), wood_dark)
box(r, 'Mattress', (0, 0, 0.38), (1.2, 1.8, 0.22), cloth)
box(r, 'Pillow', (0, -0.65, 0.52), (0.7, 0.32, 0.16), cream)
box(r, 'Blanket', (0, 0.3, 0.50), (1.18, 0.9, 0.08), mat('Blanket', (0.30, 0.45, 0.28), 0.95))
export(r, os.path.join(BLD, 'bed.glb'))

r = root('Floor')
for i in range(4):
    box(r, 'Plank', (0, -0.75 + i * 0.5, 0.06), (2.0, 0.47, 0.10), wood if i % 2 else wood_dark)
export(r, os.path.join(BLD, 'floor.glb'))

r = root('Wall')
for i in range(5):
    box(r, 'Plank', (-0.8 + i * 0.4, 0, 1.0), (0.37, 0.14, 2.0), wood if i % 2 else wood_dark)
box(r, 'Beam', (0, 0, 1.95), (2.0, 0.18, 0.12), wood_dark)
export(r, os.path.join(BLD, 'wall.glb'))

r = root('Door')
box(r, 'FrameL', (-0.85, 0, 1.05), (0.14, 0.18, 2.1), wood_dark)
box(r, 'FrameR', (0.85, 0, 1.05), (0.14, 0.18, 2.1), wood_dark)
box(r, 'Top', (0, 0, 2.05), (1.85, 0.18, 0.16), wood_dark)
box(r, 'Panel', (0, 0, 0.98), (1.55, 0.10, 1.92), wood)
ico(r, 'Knob', (0.55, -0.08, 1.0), (0.06, 0.04, 0.06), gold, 1)
export(r, os.path.join(BLD, 'door.glb'))

r = root('Roof')
for i in range(4):
    box(r, 'PanelL', (-0.55 + i * 0.32, 0, 0.25), (0.34, 2.1, 0.12), wood if i % 2 else wood_dark, (0, math.radians(20), 0))
    box(r, 'PanelR', (0.55 - i * 0.32, 0, 0.25), (0.34, 2.1, 0.12), wood if i % 2 else wood_dark, (0, math.radians(-20), 0))
export(r, os.path.join(BLD, 'roof.glb'))

# ---------------- enemies ----------------
r = root('Slime')
ico(r, 'Body', (0, 0, 0.48), (0.55, 0.48, 0.45), slime, 2)
for x in (-0.18, 0.18):
    ico(r, 'Eye', (x, -0.4, 0.58), (0.09, 0.06, 0.10), dark, 1)
    ico(r, 'EyeSpark', (x + 0.03, -0.45, 0.62), (0.025, 0.02, 0.025), cream, 1)
export(r, os.path.join(ENM, 'slime.glb'))

r = root('MushroomBug')
ico(r, 'Body', (0, 0, 0.35), (0.42, 0.55, 0.30), bug, 2)
ico(r, 'Cap', (0, 0, 0.62), (0.55, 0.5, 0.18), mush, 2)
ico(r, 'Spot', (0.15, -0.1, 0.72), (0.10, 0.08, 0.025), mush_spot, 1)
for i in range(4):
    cyl(r, 'Leg', (-0.35 + i * 0.22, 0.15, 0.2), 0.035, 0.32, bark_dark, 5, (0, math.radians(40 if i % 2 else -40), 0))
export(r, os.path.join(ENM, 'mushroom_bug.glb'))

r = root('SpikyBeast')
ico(r, 'Body', (0, 0, 0.55), (0.68, 0.55, 0.55), bark, 2)
for i in range(7):
    a = i * math.tau / 7
    cone(r, 'Spike%d' % i, (math.cos(a) * 0.48, math.sin(a) * 0.40, 0.85), 0.12, 0.55, spike, 5, (math.radians(20), 0, a))
for x in (-0.22, 0.22):
    ico(r, 'Eye', (x, -0.5, 0.64), (0.08, 0.05, 0.08), gold, 1)
export(r, os.path.join(ENM, 'spiky_beast.glb'))

r = root('AncientGuardian')
cyl(r, 'Trunk', (0, 0, 2.0), 1.0, 4.0, bark_dark, 10)
for i in range(4):
    a = i * math.tau / 4
    ico(r, 'Crown', (math.cos(a) * 1.2, math.sin(a) * 1.1, 4.4), (1.5, 1.2, 0.9), leaf_dark if i % 2 else leaf, 2)
ico(r, 'Heart', (0, -0.92, 2.9), (0.28, 0.12, 0.38), glow, 1)
for x in (-0.4, 0.4):
    ico(r, 'Eye', (x, -0.92, 3.55), (0.10, 0.06, 0.10), glow, 1)
export(r, os.path.join(ENM, 'ancient_guardian.glb'))

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, 'source_blend', 'forest_assets.blend'))
print('ASSET PACK DONE')
