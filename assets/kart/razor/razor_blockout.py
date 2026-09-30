"""RAZOR kart blockout (Phase 1). Run: python3 razor_blockout.py OUTDIR
Units: 1 BU = 1 stud. Nose = -Y, up = +Z, ground z=0. All dims = placeholders (CFG)."""
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix, Euler

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
CFG = dict(wr=0.92, ww=0.95, x_out=2.4, ax_f=-3.4, ax_r=3.6)
bpy.ops.wm.read_factory_settings(use_empty=True)
col = bpy.data.collections.new("RAZOR"); bpy.context.scene.collection.children.link(col)
GRP = {}

def mat(n, c, emit=0, rough=0.5, metal=0.2):
    m = bpy.data.materials.new(n); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*c, 1); b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*c, 1); b.inputs["Emission Strength"].default_value = emit
    return m

M = dict(body=mat("body", (.10, .10, .11), rough=.35, metal=.5), dark=mat("dark", (.05, .05, .055), rough=.6),
         wing=mat("wing", (.14, .14, .15), rough=.4), wht=mat("wht", (1, 1, 1), emit=6),
         red=mat("red", (1, .03, .02), emit=6), dec=mat("dec", (.30, .30, .33), rough=.8),
         glow=mat("glow", (.1, .6, .7), emit=1), ground=mat("ground", (.62, .62, .64), rough=.9, metal=0))

def add(name, grp, bm, m, mesh=None):
    if mesh is None:
        mesh = bpy.data.meshes.new(name); bm.to_mesh(mesh); bm.free()
        mesh.materials.append(m)
    ob = bpy.data.objects.new(name, mesh); col.objects.link(ob); GRP.setdefault(grp, []).append(ob); return ob

def box(name, grp, c, s, m, rot=(0, 0, 0)):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=s, verts=bm.verts)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler(rot).to_matrix())
    bmesh.ops.translate(bm, verts=bm.verts, vec=c)
    return add(name, grp, bm, m)

def loft(name, grp, secs, m):  # secs: (y, halfw_bottom, halfw_top, z_bottom, z_top)
    bm = bmesh.new(); rings = []
    for y, hb, ht, zb, zt in secs:
        rings.append([bm.verts.new(v) for v in ((-hb, y, zb), (hb, y, zb), (ht, y, zt), (-ht, y, zt))])
    for a, b in zip(rings, rings[1:]):
        for i in range(4):
            j = (i + 1) % 4; bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(rings[0][::-1]); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return add(name, grp, bm, m)

def cyl(r, w, seg, axis_euler):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=w)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler(axis_euler).to_matrix())
    return bm

S = (-1, 1)
WR, WW = CFG["wr"], CFG["ww"]
AX = ((CFG["ax_f"], "F"), (CFG["ax_r"], "R"))
def wheel_x(s): return s * (CFG["x_out"] - WW / 2)

def carve(ob, cutters, m):  # boolean-subtract cutter objects, bake result
    for c in cutters:
        md = ob.modifiers.new("b", "BOOLEAN"); md.operation = "DIFFERENCE"; md.object = c; md.solver = "EXACT"
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    ob.modifiers.clear(); ob.data = me
    if not me.materials: me.materials.append(m)
    for c in cutters: bpy.data.objects.remove(c)

# ---- Body tub (measured from razor-side/top crops; ~107 px/stud)
tub = loft("tub", "Body", [(-5.3, 1.0, 1.2, .45, 1.36), (-5.0, 1.6, 1.9, .42, 1.6), (-4.2, 2.15, 2.45, .35, 1.9),
    (-3.4, 2.2, 2.5, .30, 2.05), (-2.4, 2.0, 2.3, .28, 1.95), (-1.6, 1.8, 2.1, .28, 1.98), (-.4, 1.75, 2.05, .28, 2.0),
    (1.3, 1.8, 2.1, .28, 2.15), (2.2, 2.1, 2.4, .30, 2.4), (3.5, 2.25, 2.55, .40, 2.25), (4.5, 2.1, 2.4, .60, 1.95),
    (4.9, 1.9, 2.2, .70, 1.87)], M["body"])
cut = []
for s in S:
    for ay, tag in AX:
        bm = cyl(WR + .03, 1.4, 16, (0, math.pi / 2, 0)); bmesh.ops.translate(bm, verts=bm.verts, vec=(s * 2.1, ay, WR))
        cut.append(add(f"cut{tag}{s}", "cut", bm, M["dark"]))
bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1); bmesh.ops.scale(bm, vec=(2.3, 2.9, 2.0), verts=bm.verts)
bmesh.ops.translate(bm, verts=bm.verts, vec=(0, -.15, 2.0)); cut.append(add("cutcockpit", "cut", bm, M["dark"]))
carve(tub, cut, M["body"]); GRP.pop("cut")
loft("airbox", "Body", [(1.45, .5, .5, 2.1, 3.1), (3.9, .4, .3, 2.0, 2.3)], M["body"])
# ---- Aero
box("splitter", "Splitter", (0, -4.95, .3), (4.4, 1.2, .16), M["wing"])
box("diffuser", "Diffuser", (0, 4.45, .42), (2.8, 1.0, .6), M["wing"])
for s in S:
    box(f"diff_fin{s}", "Diffuser", (s * .6, 4.45, .5), (.1, 1.0, .8), M["wing"])
    box(f"wing_end{s}", "Wing", (s * 2.34, 4.95, 2.9), (.08, 1.4, 1.0), M["wing"])
    box(f"wing_strut{s}", "Wing", (s * .75, 4.35, 2.3), (.14, .4, 1.0), M["wing"], (.3, 0, 0))
    box(f"canard_a{s}", "Canards", (s * 2.2, -4.9, .55), (.6, .5, .05), M["wing"], (0, 0, s * .25))
    box(f"canard_b{s}", "Canards", (s * 2.25, -4.7, .75), (.55, .45, .05), M["wing"], (0, 0, s * .25))
box("wing_main", "Wing", (0, 4.9, 2.7), (4.6, 1.0, .1), M["wing"])
box("wing_upper", "Wing", (0, 5.05, 3.05), (4.2, .65, .08), M["wing"])
# ---- Cockpit
for s in S:
    box(f"hoop_post{s}", "Hoop", (s * .7, 1.3, 2.65), (.18, .18, 1.3), M["dark"])
box("hoop_top", "Hoop", (0, 1.3, 3.2), (1.58, .18, .18), M["dark"])
box("seat_base", "Seat", (0, .0, 1.175), (1.3, 1.2, .35), M["dark"])
box("seat_back", "Seat", (0, .85, 1.7), (1.3, .25, 1.4), M["dark"], (.15, 0, 0))
sw = cyl(.35, .08, 12, (-math.radians(60), 0, 0)); bmesh.ops.translate(sw, verts=sw.verts, vec=(0, -.95, 1.85))
add("steer", "Steering", sw, M["dark"])
# ---- Wheels: one mesh, 4 instances
wm = bpy.data.meshes.new("wheel"); b = cyl(WR, WW, 16, (0, math.pi / 2, 0)); b.to_mesh(wm); b.free()
wm.materials.append(M["dark"])
for s in S:
    for ay, tag in AX:
        ob = add(f"wheel_{tag}{'L' if s < 0 else 'R'}", "Wheels", None, None, mesh=wm)
        ob.location = (wheel_x(s), ay, WR)
# ---- Lights, decals, underglow
for s in S:
    box(f"head{s}", "Headlight", (s * 1.8, -4.85, 1.0), (.5, .06, .08), M["wht"], (0, 0, s * .5))
    box(f"tail{s}", "Taillight", (s * .9, 4.92, 1.55), (.9, .06, .07), M["red"])
box("decal_hood", "DecalPlates", (0, -3.1, 2.02), (1.8, 2.0, .06), M["dec"])
box("decal_rear", "DecalPlates", (0, 4.91, 1.1), (1.6, .04, .5), M["dec"])
box("underglow", "Underglow", (0, .2, .23), (3.0, 5.0, .04), M["glow"])

# ---- stats
def tris(ob):
    ob.data.calc_loop_triangles(); return len(ob.data.loop_triangles)
bpy.context.view_layer.update()
tot = 0; lines = []
for g, obs in GRP.items():
    t = sum(tris(o) for o in obs); tot += t; lines.append(f"{g:12s}{t:6d}")
allv = [o.matrix_world @ Vector(c) for g in GRP.values() for o in g for c in o.bound_box]
mn = Vector((min(v.x for v in allv), min(v.y for v in allv), min(v.z for v in allv)))
mx = Vector((max(v.x for v in allv), max(v.y for v in allv), max(v.z for v in allv)))
for g,obs in GRP.items():
    zs=[(o.matrix_world@Vector(c)).z for o in obs for c in o.bound_box]; lines.append(f"  z[{g}] {min(zs):.2f}..{max(zs):.2f}")
lines.append(f"TOTAL       {tot:6d}")
lines.append("bbox L/W/H  %.2f / %.2f / %.2f  y[%.2f,%.2f]" % (mx.y - mn.y, mx.x - mn.x, mx.z - mn.z, mn.y, mx.y))
open(os.path.join(OUT, "blockout_stats.txt"), "w").write("\n".join(lines)); print("\n".join(lines))

# ---- render
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 24
try: sc.cycles.use_denoising = True
except Exception: pass
sc.render.resolution_x, sc.render.resolution_y = 1000, 560
sc.render.image_settings.file_format = "PNG"
w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (.55, .55, .57, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=30)
gm = bpy.data.meshes.new("ground"); bm.to_mesh(gm); bm.free(); gm.materials.append(M["ground"])
g = bpy.data.objects.new("ground", gm); sc.collection.objects.link(g)
for n, loc, e in (("sun", (0, 0, 0), 3.0),):
    ld = bpy.data.lights.new(n, "SUN"); ld.energy = e
    lo = bpy.data.objects.new(n, ld); sc.collection.objects.link(lo)
    lo.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
cd = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam

def persp(loc, tgt, lens=32):
    cd.type = "PERSP"; cd.lens = lens; cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()

def ortho(loc, right, up, scale):
    back = Vector(right).cross(Vector(up)); cd.type = "ORTHO"; cd.ortho_scale = scale; cam.location = loc
    cam.matrix_world = Matrix.Translation(loc) @ Matrix(((right[0], up[0], back.x, 0), (right[1], up[1], back.y, 0),
                                                          (right[2], up[2], back.z, 0), (0, 0, 0, 1)))

views = {"front34": lambda: persp((-9.5, -10.5, 4.2), (0, 0, 1.3)),
         "side": lambda: ortho((30, 0, 1.6), (0, 1, 0), (0, 0, 1), 13.5),
         "rear34": lambda: persp((-9.5, 10.5, 4.2), (0, 0, 1.3)),
         "top": lambda: ortho((0, 0, 30), (0, 1, 0), (-1, 0, 0), 13.5)}
for n, f in views.items():
    f(); sc.render.filepath = os.path.join(OUT, f"blockout-{n}.png"); bpy.ops.render.render(write_still=True)
from PIL import Image
ims = [Image.open(os.path.join(OUT, f"blockout-{n}.png")) for n in ("front34", "side", "rear34", "top")]
sh = Image.new("RGB", (2000, 1120))
for i, im in enumerate(ims): sh.paste(im, ((i % 2) * 1000, (i // 2) * 560))
sh.save(os.path.join(OUT, "blockout-sheet.png"))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "razor_blockout.blend"))
