"""Gun blockouts (Phase 1, silhouette only). Run: blender -b -P gun_blockout.py -- OUTDIR
Frame: 1 BU = 1 stud, origin = grip, muzzle = -Y (becomes Roblox -Z at export), up = +Z, right = +X.
All dims are placeholders; lengths/muzzles match Config.Guns. Parts are grouped like the final MeshPart split."""
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "."
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


def mat(n, c, emit=0, rough=.5, metal=.2):
    m = bpy.data.materials.new(n); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*c, 1); b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*c, 1); b.inputs["Emission Strength"].default_value = emit
    return m


M = dict(body=mat("body", (.09, .09, .10), rough=.4, metal=.4), dark=mat("dark", (.04, .04, .045), rough=.6),
         foam=mat("foam", (.9, .42, .08), rough=.9, metal=0), plate=mat("plate", (.30, .30, .33), rough=.8),
         steel=mat("steel", (.16, .16, .18), rough=.35, metal=.7),
         ground=mat("ground", (.62, .62, .64), rough=.9, metal=0))

OBJS = []; GRP = {}


def add(name, grp, bm, m):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.materials.append(m)
    ob = bpy.data.objects.new(name, me); sc.collection.objects.link(ob)
    OBJS.append(ob); GRP.setdefault(grp, []).append(ob); return ob


def P(name, grp, pts, w, m, x=0):
    """Side-profile polygon (y, z) extruded +-w/2 along X."""
    bm = bmesh.new()
    a = [bm.verts.new((x - w / 2, y, z)) for y, z in pts]; b = [bm.verts.new((x + w / 2, y, z)) for y, z in pts]
    n = len(pts)
    bm.faces.new(a[::-1]); bm.faces.new(b)
    for i in range(n):
        j = (i + 1) % n; bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return add(name, grp, bm, m)


def B(name, grp, y0, y1, z0, z1, w, m, x=0):
    return P(name, grp, [(y0, z0), (y1, z0), (y1, z1), (y0, z1)], w, m, x)


def C(name, grp, y0, y1, z, r, m, x=0, seg=10):
    """Cylinder along Y."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=abs(y1 - y0))
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(x, (y0 + y1) / 2, z))
    return add(name, grp, bm, m)


def CX(name, grp, y, z, r, w, m, x=0, seg=14):
    """Cylinder along X (dial/drum)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=w)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(x, y, z))
    return add(name, grp, bm, m)


def plate(g, y0, y1, z0, z1, w):  # engraving zone, left receiver (matte grey)
    B("plate", "Plate", y0, y1, z0, z1, .03, M["plate"], x=-w / 2 - .005)


def build(g):
    bd, dk, fm, st = M["body"], M["dark"], M["foam"], M["steel"]
    if g == "dart9":  # slim toy slide pistol
        B("slide", "Mover", -1.0, .25, 0.0, .26, .22, bd)
        B("frame", "Receiver", -.85, .2, -.10, 0.0, .19, dk)
        P("grip", "Receiver", [(-.0, -.10), (.22, -.10), (.30, -.58), (.08, -.58)], .19, dk)
        P("guard", "Receiver", [(-.42, -.10), (-.05, -.10), (-.05, -.24), (-.16, -.24), (-.42, -.10)], .10, dk)
        C("muzzle", "Receiver", -1.16, -.98, .12, .09, fm)
        plate(g, -.55, -.12, .04, .20, .22)
    elif g == "buzz":  # slim MP5-ish
        B("receiver", "Receiver", -.55, .38, -.08, .24, .23, bd)
        B("handguard", "Receiver", -1.15, -.55, -.07, .21, .26, dk)
        P("grip", "Receiver", [(-.0, -.08), (.20, -.08), (.34, -.58), (.15, -.58)], .17, dk)
        P("mag", "Mag", [(-.60, -.08), (-.34, -.08), (-.40, -.46), (-.54, -.78), (-.72, -.78), (-.66, -.46)], .15, dk)
        B("stock_bar", "Receiver", .38, 1.0, .04, .15, .10, dk)
        P("stock_pad", "Receiver", [(.95, .22), (1.06, .22), (1.06, -.12), (.95, -.09)], .19, dk)
        C("muzzle", "Receiver", -1.36, -1.14, .09, .10, fm)
        B("sight", "Receiver", -.05, .16, .24, .31, .09, dk)
        plate(g, -.45, .1, .0, .18, .23)
    elif g == "ranger":  # slim long-tube rifle
        B("receiver", "Receiver", -.95, .45, -.08, .26, .25, bd)
        B("handguard", "Receiver", -1.7, -.95, -.03, .20, .21, dk)
        C("tube", "Receiver", -2.08, -1.68, .09, .10, fm)
        P("grip", "Receiver", [(-.0, -.08), (.20, -.08), (.34, -.62), (.15, -.62)], .17, dk)
        P("mag", "Mag", [(-.76, -.08), (-.42, -.08), (-.46, -.46), (-.62, -.84), (-.86, -.84), (-.78, -.46)], .16, dk)
        P("stock", "Receiver", [(.45, .24), (1.25, .20), (1.30, -.30), (1.08, -.28), (.80, -.08), (.45, -.08)], .19, dk)
        B("sight", "Receiver", -.30, .0, .26, .35, .10, dk)
        plate(g, -.8, -.1, -.02, .20, .25)
    elif g == "needle":  # slim marksman, long tube, optic, hooked thumbhole stock
        B("receiver", "Receiver", -1.15, .5, -.08, .22, .22, bd)
        C("barrel", "Receiver", -2.5, -1.15, .09, .07, st)
        C("muzzle", "Receiver", -2.62, -2.48, .09, .10, fm)
        C("optic", "Receiver", -.75, -.05, .36, .09, dk)
        B("optic_mount", "Receiver", -.5, -.2, .22, .31, .08, dk)
        P("grip", "Receiver", [(-.0, -.08), (.18, -.08), (.28, -.56), (.10, -.56)], .17, dk)
        P("mag", "Mag", [(-.62, -.08), (-.38, -.08), (-.38, -.48), (-.58, -.48)], .14, dk)
        B("stock_top", "Receiver", .5, 1.35, .08, .22, .19, dk)
        P("stock_hook", "Receiver", [(1.22, .08), (1.42, .08), (1.42, -.42), (1.30, -.42), (1.22, -.18)], .19, dk)
        P("thumbhole_post", "Receiver", [(.62, .08), (.78, .08), (.78, -.24), (.66, -.24)], .16, dk)
        plate(g, -.8, -.1, -.03, .18, .22)


def tris():
    t = 0
    for o in OBJS:
        o.data.calc_loop_triangles(); t += len(o.data.loop_triangles)
    return t


# ---- scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 16
try: sc.cycles.use_denoising = True
except Exception: pass
sc.render.resolution_x, sc.render.resolution_y = 1000, 600
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (.58, .58, .60, 1)
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=30)
gm = bpy.data.meshes.new("ground"); bm.to_mesh(gm); bm.free(); gm.materials.append(M["ground"])
gr = bpy.data.objects.new("ground", gm); sc.collection.objects.link(gr); gr.location.z = -1.1
ld = bpy.data.lights.new("sun", "SUN"); ld.energy = 3.0
lo = bpy.data.objects.new("sun", ld); sc.collection.objects.link(lo)
lo.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
cd = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam


def view(kind):
    c = Vector((0, -.6, .0))
    if kind == "side":  # left side looking +X so muzzle points left in the image
        cd.type = "ORTHO"; cd.ortho_scale = 4.8
        loc = c + Vector((30, 0, 0)); cam.location = loc
        cam.rotation_euler = (c - loc).to_track_quat("-Z", "Z").to_euler()
        cam.matrix_world = Matrix.Translation(loc) @ Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    else:
        cd.type = "PERSP"; cd.lens = 55
        loc = Vector((-4.2, -4.6, 2.6)); cam.location = loc
        cam.rotation_euler = (c - loc).to_track_quat("-Z", "Y").to_euler()


stats = []
for g in ("dart9", "buzz", "ranger", "needle"):
    OBJS.clear(); GRP.clear(); build(g)
    bpy.context.view_layer.update()
    vs = [o.matrix_world @ Vector(c) for o in OBJS for c in o.bound_box]
    L = max(v.y for v in vs) - min(v.y for v in vs); H = max(v.z for v in vs) - min(v.z for v in vs)
    Wd = max(v.x for v in vs) - min(v.x for v in vs)
    mz = min(v.y for v in vs)
    stats.append(f"{g:8s} tris {tris():5d}  L {L:.2f} H {H:.2f} W {Wd:.2f}  muzzle y {mz:.2f}  parts {sorted(GRP)}")
    for k in ("side", "q"):
        view(k); sc.render.filepath = os.path.join(OUT, f"{g}-{k}.png"); bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"{g}_blockout.blend"))
    for o in OBJS: bpy.data.objects.remove(o)
open(os.path.join(OUT, "blockout_stats.txt"), "w").write("\n".join(stats)); print("\n".join(stats))
