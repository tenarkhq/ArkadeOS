"""ArkadeOS wallpaper "Ark műszer" (T069, Roland 2026-11-01): the gauge of the
Ark mark as one instrument for performance and games, AI and crypto, in 3D
on true black for OLED screens. Rendered in Blender (Cycles):
blender -b --factory-startup --python gauge.py -- ark <w> <h> <out.png> [samples]
(art/render-gauge.sh makes every size and encodes JPEG XL)."""
import math
import random
import sys

import bpy
from mathutils import Euler, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
name, W, H, out = argv[0], int(argv[1]), int(argv[2]), argv[3]
samples = int(argv[4]) if len(argv) > 4 else 128
random.seed(7)


def lin(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


GREEN = lin((0.20, 0.90, 0.38))
AMBER = lin((1.00, 0.64, 0.05))
LAVENDER = lin((0.74, 0.74, 1.00))
ROSE = lin((1.00, 0.18, 0.36))
WHITE = lin((0.957, 0.957, 0.965))
PAL = [GREEN, AMBER, LAVENDER, ROSE]

# ---------------------------------------------------------------- scene
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = samples
sc.cycles.use_denoising = True
try:
    sc.cycles.denoiser = "OPENIMAGEDENOISE"
except TypeError:
    pass
sc.cycles.max_bounces = 12
sc.cycles.transmission_bounces = 12
sc.cycles.glossy_bounces = 6
sc.render.resolution_x, sc.render.resolution_y = W, H
sc.render.resolution_percentage = 100
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_depth = "16"
sc.render.filepath = out
try:
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Punchy"
except TypeError:
    pass

world = bpy.data.worlds.new("black")
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
bg.inputs[0].default_value = (0, 0, 0, 1)
bg.inputs[1].default_value = 0
sc.world = world


def mat(nm, color=(0.02, 0.02, 0.025), metal=0.0, rough=0.4, emit=None, strength=0.0,
        trans=0.0, ior=1.45, coat=0.0, alpha=1.0):
    m = bpy.data.materials.new(nm)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    p.inputs["IOR"].default_value = ior
    p.inputs["Transmission Weight"].default_value = trans
    p.inputs["Coat Weight"].default_value = coat
    if emit is not None:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = strength
    return m


def emission(nm, color, strength):
    m = bpy.data.materials.new(nm)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value = (*color, 1)
    e.inputs[1].default_value = strength
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(e.outputs[0], o.inputs[0])
    return m


def glass(nm, tint=(0.9, 0.92, 1.0), rough=0.02, ior=1.5):
    m = bpy.data.materials.new(nm)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    g = nt.nodes.new("ShaderNodeBsdfGlass")
    g.inputs["Color"].default_value = (*tint, 1)
    g.inputs["Roughness"].default_value = rough
    g.inputs["IOR"].default_value = ior
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(g.outputs[0], o.inputs[0])
    return m


def link(obj):
    sc.collection.objects.link(obj)
    return obj


def box(loc, size, m, rot=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    o.data.materials.append(m)
    if bevel:
        mod = o.modifiers.new("b", "BEVEL")
        mod.width = bevel
        mod.segments = 4
        mod.affect = "EDGES"
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(scale=True)
    return o


def curve(points, m, depth, name="c", cyclic=False):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = depth
    cu.bevel_resolution = 3
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for p, xyz in zip(sp.points, points):
        p.co = (*xyz, 1)
    sp.use_cyclic_u = cyclic
    o = bpy.data.objects.new(name, cu)
    o.data.materials.append(m)
    return link(o)


def area(loc, rot, size, color, power):
    ld = bpy.data.lights.new("a", "AREA")
    ld.size = size
    ld.color = color
    ld.energy = power
    o = bpy.data.objects.new("a", ld)
    o.location = loc
    o.rotation_euler = rot
    return link(o)


def camera(loc, target, lens=50, focus=None, fstop=None):
    cd = bpy.data.cameras.new("cam")
    cd.lens = lens
    o = link(bpy.data.objects.new("cam", cd))
    o.location = loc
    d = Vector(target) - Vector(loc)
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    if focus is not None:
        cd.dof.use_dof = True
        cd.dof.focus_distance = (Vector(focus) - Vector(loc)).length
        cd.dof.aperture_fstop = fstop
    sc.camera = o
    return o


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


# ---------------------------------------------------------------- scenes
if name == "ark":
    # Everything in one instrument: the gauge of the Ark mark (performance,
    # games), its face a processor die wired like a neural net (AI), its scale
    # a chain of glass blocks (crypto), the Ark mark on the hub.
    face = mat("face", (0.006, 0.006, 0.009), metal=0.5, rough=0.28, coat=1.0)
    steel = mat("steel", (0.55, 0.56, 0.6), metal=1.0, rough=0.22)
    bpy.ops.mesh.primitive_cylinder_add(vertices=256, radius=1.0, depth=0.06, location=(0, 0, -0.03))
    bpy.context.object.data.materials.append(face)
    bpy.ops.mesh.primitive_torus_add(major_radius=1.04, minor_radius=0.05, major_segments=256, minor_segments=32)
    bpy.context.object.data.materials.append(steel)
    # the die: a square in the middle, wiring running out of it, nodes on it
    die = mat("die", (0.012, 0.012, 0.02), metal=0.8, rough=0.2)
    box((0, 0, 0.004), (0.5, 0.5, 0.008), die, bevel=0.004)
    curve([(-0.25, -0.25, 0.009), (0.25, -0.25, 0.009), (0.25, 0.25, 0.009), (-0.25, 0.25, 0.009)],
          emission("dieedge", LAVENDER, 4), 0.0025, cyclic=True)
    grid = 0.045
    for k in range(190):
        col = random.choice([LAVENDER, LAVENDER, GREEN, GREEN, AMBER])
        hot = random.random() < 0.07
        side = random.choice((-1, 1))
        if random.random() < 0.5:
            x, y = side * 0.25, round(random.uniform(-0.23, 0.23) / grid) * grid
        else:
            x, y = round(random.uniform(-0.23, 0.23) / grid) * grid, side * 0.25
        pts = [(x, y, 0.003)]
        horizontal = abs(x) > abs(y)
        for st in range(random.randint(2, 5)):
            d = grid * random.randint(1, 4)
            if horizontal:
                x += math.copysign(d, x)
            else:
                y += math.copysign(d, y)
            if math.hypot(x, y) > 0.7:
                break
            pts.append((x, y, 0.003))
            horizontal = not horizontal if random.random() < 0.6 else horizontal
        if len(pts) < 2:
            continue
        curve(pts, emission(f"w{k}", col, 7 if hot else random.uniform(0.8, 2.4)), 0.0018)
        ex, ey, _ = pts[-1]
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.006 if not hot else 0.009, location=(ex, ey, 0.006))
        bpy.context.object.data.materials.append(emission(f"n{k}", mix(col, WHITE, 0.6), 14 if hot else 6))
    # the scale: a chain of glass blocks, green to amber to red
    sweep0, sweep1 = math.radians(225), math.radians(-45)
    glassm = glass("blk", rough=0.04)
    nblk = 30
    prev = None
    for i in range(nblk):
        t = i / (nblk - 1)
        a = sweep0 + (sweep1 - sweep0) * t
        col = mix(GREEN, AMBER, min(1, t / 0.6)) if t < 0.6 else mix(AMBER, ROSE, min(1, (t - 0.6) / 0.22))
        p = (math.cos(a) * 0.87, math.sin(a) * 0.87, 0.03)
        rot = (0, 0, a)
        box(p, (0.05, 0.05, 0.05), glassm, rot=rot, bevel=0.006)
        box(p, (0.026, 0.026, 0.026), emission(f"bc{i}", col, (5 + 12 * t) * (2.2 if t > 0.78 else 1)), rot=rot)
        if prev is not None:
            curve([prev, p], emission(f"bl{i}", col, 3 + 6 * t), 0.0028)
        prev = p
    # needle deep in the red
    a = sweep0 + (sweep1 - sweep0) * 0.92
    box((math.cos(a) * 0.40, math.sin(a) * 0.40, 0.05), (0.80, 0.016, 0.008), emission("needle", ROSE, 30), rot=(0, 0, a))
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=0.1, depth=0.06, location=(0, 0, 0.05))
    bpy.context.object.data.materials.append(steel)
    # the Ark mark on the hub
    markm = emission("mark", WHITE, 9)
    z = 0.0815
    curve([(-0.045, -0.005, z), (0.045, -0.005, z), (0.045, 0.04, z), (-0.045, 0.04, z)], markm, 0.0035, cyclic=True)
    curve([(-0.06, -0.025, z), (0.06, -0.025, z)], markm, 0.0035)
    curve([(math.cos(math.pi * i / 10) * 0.016, 0.004 + math.sin(math.pi * i / 10) * 0.016, z) for i in range(11)],
          markm, 0.0025)
    curve([(0, 0.004, z), (0.012, 0.018, z)], emission("markneedle", ROSE, 14), 0.0025)
    # glass over it all
    bpy.ops.mesh.primitive_cylinder_add(vertices=256, radius=1.0, depth=0.004, location=(0, 0, 0.11))
    bpy.context.object.data.materials.append(glass("cover", rough=0.0))
    area((-2.5, 2.2, 2.6), Euler((math.radians(-40), math.radians(-40), 0)), 2.5, LAVENDER, 180)
    area((2.8, -1.0, 1.4), Euler((math.radians(60), math.radians(55), 0)), 1.0, AMBER, 40)
    tip = (math.cos(a) * 0.8, math.sin(a) * 0.8, 0.05)
    camera((-1.7, -2.9, 2.0), (0.3, 0.05, 0), lens=55, focus=(0.2, 0.0, 0), fstop=3.2)

bpy.ops.render.render(write_still=True)
