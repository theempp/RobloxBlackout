"""RAZOR kart build (Phases 2-6). Run (cwd = this folder; needs Blender + scipy + Pillow in its Python): blender -b -P razor_build.py -- PHASE OUTDIR   (PHASE 2..6 builds cumulatively)
Units: 1 BU = 1 stud. Nose = -Y, up = +Z, ground z=0, mirrored on X. All tunables live in CFG / tables below."""
import bpy, bmesh, math, sys, os, json
import numpy as np
from mathutils import Vector, Matrix, Euler
from scipy.interpolate import PchipInterpolator

_A = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]   # works under `blender -b -P` and plain python
PHASE = int(_A[0]) if len(_A) > 0 else 2
OUT = _A[1] if len(_A) > 1 else "."
os.makedirs(OUT, exist_ok=True)

CFG = dict(wr=.92, ww=.95, x_out=2.4, ax_f=-3.4, ax_r=3.6, clr=.06,      # wheels / arches (P1)
           floor=.28, pod_depth=.17, decal_recess=.07, pocket_z=1.0, pocket_len=(-1.4, 1.05))

def PT(pts):
    a = np.array(sorted(pts), float); f = PchipInterpolator(a[:, 0], a[:, 1], extrapolate=False)
    return lambda y: float(f(min(max(y, a[0, 0]), a[-1, 0])))
def SS(t): t = min(max(t, 0.), 1.); return t * t * (3 - 2 * t)

# ---- measured targets (ref side/top, 105.5 px/stud; Y from side view, widths from top-view mask)
HW = PT([(-5.3, .62), (-5.15, 1.35), (-5.0, 1.72), (-4.8, 2.0), (-4.55, 2.2), (-4.3, 2.32), (-4.05, 2.42), (-3.8, 2.46), (-3.4, 2.48),
         (-2.8, 2.45), (-2.55, 2.4), (-2.3, 2.29), (-2.05, 2.18), (-1.8, 2.11), (-1.3, 2.02), (-.5, 2.0), (.5, 2.06),
         (1.2, 2.09), (1.7, 2.13), (1.95, 2.18), (2.2, 2.28), (2.45, 2.44), (2.7, 2.5), (3.2, 2.56), (3.7, 2.58),
         (4.2, 2.54), (4.45, 2.42), (4.7, 2.3), (4.9, 2.15), (5.0, 1.98)])
ZCR = PT([(-5.3, .95), (-5.15, 1.05), (-4.95, 1.2), (-4.7, 1.38), (-4.4, 1.58), (-4.05, 1.85), (-3.7, 2.02), (-3.4, 2.1), (-2.8, 2.1), (-2.3, 2.05),
          (-1.9, 2.02), (-1.5, 2.02), (-.6, 2.06), (.2, 2.1), (.8, 2.2), (1.3, 2.3), (1.9, 2.3), (2.5, 2.15), (3.0, 2.1),
          (3.6, 2.1), (4.2, 2.06), (4.7, 1.98), (4.9, 1.88), (5.0, 1.78)])
ZCEN = PT([(-5.3, .95), (-5.15, 1.0), (-4.95, 1.1), (-4.7, 1.2), (-4.3, 1.38), (-3.8, 1.5), (-3.2, 1.55), (-2.5, 1.6), (-1.9, 1.68), (-1.5, 1.75),
           (1.15, 2.3), (1.9, 2.36), (2.6, 2.3), (3.4, 2.2), (4.2, 2.06), (4.7, 1.96), (4.9, 1.86), (5.0, 1.78)])
ZF = PT([(-5.3, .62), (-5.0, .45), (-4.4, .30), (-4.0, .28), (4.0, .28), (4.6, .42), (5.0, .6)])
XP = PT([(-1.4, .8), (-.9, 1.0), (.3, 1.05), (1.05, .85)])          # cockpit opening half-width by Y

WR = CFG["wr"]; RA = WR + CFG["clr"]
def arch(y):
    for ya in (CFG["ax_f"], CFG["ax_r"]):
        d = y - ya
        if abs(d) <= RA: return WR + math.sqrt(max(RA * RA - d * d, 0))
    return 0.

def fend(y): return max(SS((1.8 - abs(y - CFG['ax_f'])) / .9), SS((1.8 - abs(y - CFG['ax_r'])) / .9))
def pod(y, t):  # side-pod recess depth at wall param t (0 bottom..1 shoulder); slash slants: top forward
    yf = -1.59 - .17 * (t - .25) / .5 * 1.0; yr = .2 + .6 * t
    m = SS((y - (yf - .13)) / .13) * (1 - SS((y - (yr - .45)) / .45))
    return CFG["pod_depth"] * (1 + .6 * (1 - SS((y - yf) / 1.0))) * m * (1 if .1 < t < .95 else 0)

# stations: (y, lift, rec, pocket)
def stations():
    S = []
    def add(y, lift=True, rec=0, pk=False): S.append((y, lift, rec, pk))
    for y in (-5.3, -5.15, -4.95, -4.7): add(y)
    for i, y in enumerate((-4.38, -4.38, -4.18, -3.95, -3.68, -3.4, -3.12, -2.85, -2.62, -2.42, -2.42)):
        add(y, lift=(i not in (0, 10)), rec=(1 if 2 <= i <= 8 else 0))
    for y in (-2.1, -1.85, -1.72, -1.59): add(y)
    for y in (-1.4, -.9, -.3, .3, .8, 1.05): add(y, pk=True)
    for y in (1.15, 1.7, 2.2): add(y)
    for i, y in enumerate((2.62, 2.62, 2.8, 3.05, 3.32, 3.6, 3.88, 4.15, 4.4, 4.58, 4.58)):
        add(y, lift=(i not in (0, 10)))
    for y in (4.75, 4.9, 5.0): add(y)
    return S

def section(y, lift, rec, pk):
    hw = HW(y); zcr = ZCR(y); zf = ZF(y); zc = zcr if pk else ZCEN(y)
    xb = hw - .30; zb = max(zf, arch(y)) if lift else zf
    zs = max(zcr - .30, zb + .08); xc = hw - .35 - .25 * fend(y)
    R = [(0., zf), (min(1.3, xb - .2), zf), (xb, zb)]
    for t in (.25, .5, .75): R.append((xb + (hw - xb) * math.sin(t * math.pi / 2) - pod(y, t), zb + (zs - zb) * t))
    R.append((hw, zs))
    for th in (30, 60, 90):
        a = math.radians(th); R.append((xc + (hw - xc) * math.cos(a), zs + (zcr - zs) * math.sin(a)))
    xp = XP(y) if pk else 1.0
    xp = min(xp, max(xc - .12, .25))
    def ztop(x): return zc + (zcr - zc) * SS((x - xp) / max(xc - xp, .05))
    x10 = (xc + xp) / 2; R.append((x10, ztop(x10)))
    z11 = ztop(xp); R.append((xp, z11))
    zb2 = CFG["pocket_z"] if pk else z11 - CFG["decal_recess"] * rec
    R += [(xp - .04, zb2), (xp * .5, zb2), (0., zb2)]
    return R

def ring(R): return [(x, z) for x, z in R] + [(-x, z) for x, z in R[-2:0:-1]]

TUBQ = []   # quad database for UVs: (center Vector, [(corner Vector, u, v)]*4, special)
def row_v(R):
    v = [0.] * len(R)
    for j in range(len(R) - 2, -1, -1):
        v[j] = v[j + 1] + math.hypot(R[j][0] - R[j + 1][0], R[j][1] - R[j + 1][1]) * (1. if j >= 2 else .25)
    return v
def build_tub():
    bm = bmesh.new(); rings = []; RV = []; ys = []
    for y, lift, rec, pk in stations():
        R = section(y, lift, rec, pk); rg = ring(R); rings.append([bm.verts.new((x, y, z)) for x, z in rg]); RV.append((rg, row_v(R), y))
    n = len(rings[0]); rowof = lambda k: k if k <= len(rings[0]) // 2 else n - k
    TUBQ.clear()
    for i in range(len(rings) - 1):
        for k in range(n):
            l = (k + 1) % n; a, b = RV[i], RV[i + 1]
            cs = [(a[0][k], a[1][rowof(k)], a[2]), (a[0][l], a[1][rowof(l)], a[2]), (b[0][l], b[1][rowof(l)], b[2]), (b[0][k], b[1][rowof(k)], b[2])]
            P = [Vector((c[0][0], c[2], c[0][1])) for c in cs]
            nrm = (P[1] - P[0]).cross(P[3] - P[0]) + (P[3] - P[2]).cross(P[1] - P[2])
            nrm = nrm.normalized() if nrm.length > 1e-9 else Vector((0, 0, 1))
            TUBQ.append((sum(P, Vector()) / 4, [(P[q], cs[q][2] + 5.3, cs[q][1]) for q in range(4)], abs(nrm.y) > .72))
    for i in range(len(rings) - 1):
        for k in range(n):
            l = (k + 1) % n; bm.faces.new((rings[i][k], rings[i][l], rings[i + 1][l], rings[i + 1][k]))
    bm.faces.new(rings[0][::-1]); bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

# ---------------------------------------------------------------- scene / helpers
bpy.ops.wm.read_factory_settings(use_empty=True)
col = bpy.data.collections.new("RAZOR"); bpy.context.scene.collection.children.link(col)
GRP = {}
def mat(n, c, emit=0, rough=.5, metal=.2):
    m = bpy.data.materials.new(n); m.use_nodes = True; b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*c, 1); b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
    if emit: b.inputs["Emission Color"].default_value = (*c, 1); b.inputs["Emission Strength"].default_value = emit
    return m
M = dict(clay=mat("clay", (.22, .22, .24), rough=.45, metal=.3), dark=mat("dark", (.05, .05, .055), rough=.6),
         wht=mat("wht", (1, 1, 1), emit=6), red=mat("red", (1, .03, .02), emit=6), dec=mat("dec", (.30, .30, .33), rough=.8),
         glow=mat("glow", (.1, .6, .7), emit=1), ground=mat("ground", (.62, .62, .64), rough=.9, metal=0))
def add(name, grp, bm, m):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.materials.append(m)
    ob = bpy.data.objects.new(name, me); col.objects.link(ob); GRP.setdefault(grp, []).append(ob); return ob
def tris(ob):
    ob.data.calc_loop_triangles(); return len(ob.data.loop_triangles)
def tri_bm(bm): bmesh.ops.triangulate(bm, faces=bm.faces[:])

# ================================================================= PHASE 2: body cage
def phase2():
    bm = build_tub()
    tub = add("tub", "Body", bm, M["clay"])
    # rear plate recess (boolean into flat tail cap)
    cut = bmesh.new(); bmesh.ops.create_cube(cut, size=1); bmesh.ops.scale(cut, vec=(1.6, .24, .5), verts=cut.verts)
    bmesh.ops.translate(cut, verts=cut.verts, vec=(0, 5.0, 1.1))
    co = add("cut_rear", "cut", cut, M["dark"])
    md = tub.modifiers.new("b", "BOOLEAN"); md.operation = "DIFFERENCE"; md.object = co; md.solver = "EXACT"
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(tub.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    tub.modifiers.clear(); tub.data = me; me.materials.append(M["clay"]); bpy.data.objects.remove(co); GRP.pop("cut")
    # airbox (rides behind hoop)
    bm = bmesh.new(); rings = []
    for y, hw, z0, z1 in ((1.5, .48, 2.2, 3.0), (2.0, .55, 2.2, 3.16), (2.6, .5, 2.2, 3.02), (3.1, .4, 2.2, 2.62), (3.6, .28, 2.2, 2.3)):
        rings.append([bm.verts.new(v) for v in ((-hw, y, z0), (hw, y, z0), (hw * 1.0, y, z0 + (z1 - z0) * .55), (hw * .62, y, z1),
                                                  (-hw * .62, y, z1), (-hw * 1.0, y, z0 + (z1 - z0) * .55))])
    for a, b in zip(rings, rings[1:]):
        for i in range(6): j = (i + 1) % 6; bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(rings[0][::-1]); bm.faces.new(rings[-1]); bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    add("airbox", "Body", bm, M["clay"])
    # wheel proxies (context only for arch check; replaced in phase 4)
    if PHASE < 4:
        for s in (-1, 1):
            for ay in (CFG["ax_f"], CFG["ax_r"]):
                bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=WR, radius2=WR, depth=CFG["ww"])
                bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Euler((0, math.pi / 2, 0)).to_matrix())
                bmesh.ops.translate(bm, verts=bm.verts, vec=(s * (CFG["x_out"] - CFG["ww"] / 2), ay, WR))
                add("wheelproxy", "Proxy", bm, M["dark"])


# ================================================================= PHASE 3: aero
def prism(name, grp, poly, f, t, m):
    bm = bmesh.new(); n = len(poly)
    A = [bm.verts.new(f(a, b, -t / 2)) for a, b in poly]; B = [bm.verts.new(f(a, b, t / 2)) for a, b in poly]
    bm.faces.new(A[::-1]); bm.faces.new(B)
    for i in range(n): j = (i + 1) % n; bm.faces.new((A[i], A[j], B[j], B[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces); return add(name, grp, bm, m)
def mir(half): return half + [(-x, y) for x, y in half[::-1]]
def airfoil(y0, chord, z0, pitch):
    tp = math.tan(math.radians(pitch)); P = [(0, -.03), (.5, -.06), (1, -.01), (1, .14), (.5, .16), (0, .12)]
    return [(y0 + u * chord, z0 + v + (u - .5) * chord * tp) for u, v in P]
WING = dict(hw=2.2, ex=2.25, et=.16, main=(4.15, 1.15, 2.38, 5), upper=(4.6, .75, 2.83, 6), sx=.85)
EPOLY = [(4.05, 2.38), (4.15, 2.25), (5.55, 2.25), (5.65, 2.38), (5.65, 3.19), (5.55, 3.29), (4.2, 2.93), (4.05, 2.78)]
def strut_path(x):
    P = [(4.2, 1.95), (4.28, 2.2), (4.5, 2.4), (4.85, 2.5)]; W = [.6, .55, .48, .42]
    bm = bmesh.new(); rings = []; n = len(P)
    for i, (y, z) in enumerate(P):
        d = Vector((P[min(i + 1, n - 1)][0] - P[max(i - 1, 0)][0], P[min(i + 1, n - 1)][1] - P[max(i - 1, 0)][1])).normalized(); nv = Vector((-d.y, d.x))
        w = W[i] / 2; hx = .14
        rings.append([bm.verts.new((x + sx * hx, y + nv.x * w * sz, z + nv.y * w * sz)) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    for a, b in zip(rings, rings[1:]):
        for i in range(4): j = (i + 1) % 4; bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(rings[0][::-1]); bm.faces.new(rings[-1]); bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm
def phase3():
    W_ = WING; Mw = M["clay"]
    for s in (-1, 1):
        prism(f"wing_end{s}", "Wing", EPOLY, lambda a, b, c, s=s: (s * W_["ex"] + c, a, b), W_["et"], Mw)
        add(f"wing_strut{s}", "Wing", strut_path(s * W_["sx"]), Mw)
    for nm, (y0, ch, z0, pt) in (("wing_main", W_["main"]), ("wing_upper", W_["upper"])):
        prism(nm, "Wing", airfoil(y0, ch, z0, pt), lambda a, b, c: (c, a, b), 2 * W_["hw"], Mw)
    # splitter: slab + end fins + 2 nose fins
    half = [(0, -5.55), (1.0, -5.53), (1.7, -5.38), (2.1, -5.0), (2.28, -4.6), (2.28, -4.3), (1.4, -4.22), (0, -4.22)]
    poly = [(x, y) for x, y in half] + [(-x, y) for x, y in half[::-1]][1:-1]
    prism("splitter", "Splitter", poly, lambda a, b, c: (a, b, .31 + c), .18, Mw)
    for s in (-1, 1):
        prism(f"split_end{s}", "Splitter", [(-5.0, .22), (-4.25, .22), (-4.25, .74), (-4.6, .74)], lambda a, b, c, s=s: (s * 2.2 + c, a, b), .16, Mw)
        prism(f"nose_fin{s}", "Splitter", [(-5.25, .36), (-4.6, .36), (-4.5, .64), (-5.25, .64)], lambda a, b, c, s=s: (s * 1.0 + c, a, b), .16, Mw)
    # diffuser wedge + strakes + lip
    prism("diff_wedge", "Diffuser", [(3.9, .27), (5.15, .46), (5.15, .70), (4.95, .70), (3.9, .40)], lambda a, b, c: (c, a, b), 2.8, Mw)
    for x in (-1.4, -.72, 0, .72, 1.4):
        prism(f"diff_fin{x}", "Diffuser", [(4.3, .18), (5.2, .2), (5.2, .8), (5.0, .85), (4.6, .6)], lambda a, b, c, x=x: (x + c, a, b), .16, Mw)
    # canards (chunky, swept, two levels)
    for s in (-1, 1):
        for k, (yy, zz) in enumerate(((-5.08, .56), (-4.9, .84))):
            pl = [(0, 0), (.62, .06), (.7, .34), (0, .4)]; th = .2; ca, sa = math.cos(th), math.sin(th)
            prism(f"canard{k}{s}", "Canards", pl, lambda a, b, c, s=s, yy=yy, zz=zz, ca=ca, sa=sa: (s * (1.5 + a * ca - b * sa), yy + a * sa + b * ca, zz + c), .16, Mw)
    decals()
def decals():
    def plate(name, cs, th):  # top quad cs + bottom offset by -th; 5 faces (bottom open); faces oriented away from centroid
        bm = bmesh.new(); T = [bm.verts.new(c) for c in cs]; B = [bm.verts.new((c[0] - th[0], c[1] - th[1], c[2] - th[2])) for c in cs]
        fs = [bm.faces.new(T)] + [bm.faces.new((T[i], T[(i + 1) % 4], B[(i + 1) % 4], B[i])) for i in range(4)]
        cen = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
        for f in fs:
            if f.normal.dot(f.calc_center_median() - cen) < 0: bmesh.ops.reverse_faces(bm, faces=[f])
        return add(name, "DecalPlates", bm, M["dec"])
    zt = lambda y: ZCEN(y) - .012
    plate("decal_hood", [(-.94, -4.18, zt(-4.18)), (.94, -4.18, zt(-4.18)), (.94, -2.62, zt(-2.62)), (-.94, -2.62, zt(-2.62))], (0, 0, .05))
    plate("decal_rear", [(-.78, 4.995, .87), (.78, 4.995, .87), (.78, 4.995, 1.33), (-.78, 4.995, 1.33)], (0, .11, 0))
    for s in (-1, 1):
        x = s * (WING["ex"] + WING["et"] / 2 + .002)
        plate(f"decal_num{s}", [(x, 4.5, 2.43), (x, 5.45, 2.43), (x, 5.45, 3.03), (x, 4.5, 3.03)], (s * .03, 0, 0))

# ================================================================= PHASE 4: wheels, cockpit, lights
NW = 20
def wheel_bm():
    P = [(.40, .14), (.43, .42), (.50, .44), (.82, .48), (.92, .32), (.92, -.32), (.82, -.48), (.50, -.44)]
    bm = bmesh.new(); ctr = bm.verts.new((.14, 0, 0)); rows = []
    for r, x in P: rows.append([bm.verts.new((x, r * math.cos(2 * math.pi * i / NW), r * math.sin(2 * math.pi * i / NW))) for i in range(NW)])
    for i in range(NW): bm.faces.new((ctr, rows[0][(i + 1) % NW], rows[0][i]))
    for a, b in zip(rows, rows[1:]):
        for i in range(NW): j = (i + 1) % NW; bm.faces.new((a[i], a[j], b[j], b[i]))
    back = bm.verts.new((-.44, 0, 0))
    for i in range(NW): bm.faces.new((back, rows[-1][i], rows[-1][(i + 1) % NW]))
    for k in range(5):
        ph = math.radians(90 + k * 72); c, s_ = math.cos(ph), math.sin(ph)
        pl = [(.10, -.075), (.10, .075), (.42, .11), (.42, -.11)]
        A = [bm.verts.new((.14, a * c - b * s_, a * s_ + b * c)) for a, b in pl]; B = [bm.verts.new((.30, a * c - b * s_, a * s_ + b * c)) for a, b in pl]
        bm.faces.new(B)
        for i in range(4): j = (i + 1) % 4; bm.faces.new((A[i], A[j], B[j], B[i]))
    hub = [(.17 * math.cos(2 * math.pi * i / 10), .17 * math.sin(2 * math.pi * i / 10)) for i in range(10)]
    A = [bm.verts.new((.10, a, b)) for a, b in hub]; B = [bm.verts.new((.36, a, b)) for a, b in hub]; bm.faces.new(B)
    for i in range(10): j = (i + 1) % 10; bm.faces.new((A[i], A[j], B[j], B[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm
def ring_solid(nseg, prof, axis_y=True):  # revolve closed profile (r, h) about Y axis
    bm = bmesh.new(); rows = []
    for i in range(nseg):
        ph = 2 * math.pi * i / nseg; rows.append([bm.verts.new((r * math.cos(ph), h, r * math.sin(ph))) for r, h in prof])
    n = len(prof)
    for i in range(nseg):
        a, b = rows[i], rows[(i + 1) % nseg]
        for k in range(n): l = (k + 1) % n; bm.faces.new((a[k], a[l], b[l], b[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces); return bm
def strip(name, grp, target, nrm, z, L, H, m, T=.1, proud=.035):
    n = Vector((nrm[0], nrm[1], 0)).normalized(); tub = GRP["Body"][0]
    hit, loc, fn, _ = tub.ray_cast(Vector((target[0], target[1], z)) + n * 3, -n)
    if not hit: print("strip miss", name); loc, fn = Vector((target[0], target[1], z)), n
    fn = Vector((fn.x, fn.y, 0)).normalized(); t = Vector((-fn.y, fn.x, 0)); c = loc + fn * proud
    def P(u, v, w): return c + t * u + fn * v + Vector((0, 0, w))   # u along strip, v along normal, w up
    top = [P(-L / 2, 0, -H / 2), P(L / 2, 0, -H / 2), P(L / 2, 0, H / 2), P(-L / 2, 0, H / 2)]
    bm = bmesh.new(); T_ = [bm.verts.new(v) for v in top]; B_ = [bm.verts.new(v - fn * T) for v in top]
    fs = [bm.faces.new(T_)] + [bm.faces.new((T_[i], T_[(i + 1) % 4], B_[(i + 1) % 4], B_[i])) for i in range(4)]
    cen = sum((v.co for v in bm.verts), Vector()) / 8
    for f in fs:
        if f.normal.dot(f.calc_center_median() - cen) < 0: bmesh.ops.reverse_faces(bm, faces=[f])
    return add(name, grp, bm, m)
def phase4():
    Md = M["dark"]
    # wheels: ONE mesh, 4 instances, origin = hub centre, right side as modelled (outer face +X), left rotated 180 about Z
    b = wheel_bm(); wm = bpy.data.meshes.new("wheel"); b.to_mesh(wm); b.free(); wm.materials.append(Md)
    for s in (-1, 1):
        for ay, tag in ((CFG["ax_f"], "F"), (CFG["ax_r"], "R")):
            ob = bpy.data.objects.new(f"wheel_{tag}{'L' if s < 0 else 'R'}", wm); col.objects.link(ob); GRP.setdefault("Wheels", []).append(ob)
            ob.location = (s * (CFG["x_out"] - CFG["ww"] / 2), ay, WR); ob.rotation_euler = (0, 0, 0 if s > 0 else math.pi)
    # hoop: two tapered posts + top bar (chunky)
    HP = [(1.05, 2.2), (1.75, 2.2), (1.46, 3.26), (1.32, 3.32), (1.1, 3.32), (1.02, 3.2)]
    for s in (-1, 1): prism(f"hoop_post{s}", "Hoop", HP, lambda a, b, c, s=s: (s * .72 + c, a, b), .22, Md)
    prism("hoop_top", "Hoop", [(1.08, 3.1), (1.44, 3.1), (1.46, 3.26), (1.32, 3.32), (1.1, 3.32), (1.02, 3.2)], lambda a, b, c: (c, a, b), 1.5, Md)
    # seat: pan, back, side bolsters, headrest, steering column
    pan = [(-.62, -.5), (-.5, -.62), (.5, -.62), (.62, -.5), (.62, .5), (.5, .62), (-.5, .62), (-.62, .5)]
    prism("seat_pan", "Seat", pan, lambda a, b, c: (a, b, 1.18 + c), .36, Md)
    prism("seat_back", "Seat", [(-.62, 1.3), (.62, 1.3), (.62, 2.15), (.5, 2.42), (-.5, 2.42), (-.62, 2.15)], lambda a, b, c: (a, .8 + c + (b - 1.3) * .17, b), .26, Md)
    for s in (-1, 1):
        prism(f"seat_bolster{s}", "Seat", [(.55, 1.3), (1.0, 1.3), (1.05, 2.0), (.75, 2.1)], lambda a, b, c, s=s: (s * .7 + c, .8 + a * .0 + (a - .55) * .0 + (b - 1.3) * .17 - .0, b), .18, Md) if False else None
    prism("seat_head", "Seat", [(-.35, 2.2), (.35, 2.2), (.35, 2.62), (-.35, 2.62)], lambda a, b, c: (a, .8 + c + (b - 1.3) * .17 + .03, b), .22, Md)
    prism("column", "Seat", [(-.09, -.1), (.09, -.1), (.09, .1), (-.09, .1)], lambda a, b, c: (a, -1.15 + c * 0 + b * 0 - .0, 1.5 + b * 0), .001, Md) if False else None
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1); bmesh.ops.scale(bm, vec=(.2, .5, .2), verts=bm.verts); bmesh.ops.translate(bm, verts=bm.verts, vec=(0, -1.12, 1.55)); add("column", "Seat", bm, Md)
    # steering wheel: separate mesh, origin = hub centre, axis local +Y, tilted 30 deg
    bm = ring_solid(12, [(.27, -.075), (.36, -.075), (.36, .075), (.27, .075)])
    for s in (-1, 1):
        bmesh.ops.create_cube(bm, size=1)
    bm.clear(); bm = ring_solid(12, [(.27, -.075), (.36, -.075), (.36, .075), (.27, .075)])
    def box_into(bm, c, sc):
        t = bmesh.new(); bmesh.ops.create_cube(t, size=1); bmesh.ops.scale(t, vec=sc, verts=t.verts); bmesh.ops.translate(t, verts=t.verts, vec=c)
        me = bpy.data.meshes.new("t"); t.to_mesh(me); t.free(); bm.from_mesh(me); bpy.data.meshes.remove(me)
    box_into(bm, (-.17, 0, 0), (.22, .15, .1)); box_into(bm, (.17, 0, 0), (.22, .15, .1))
    hub = [(.1 * math.cos(2 * math.pi * i / 6), .1 * math.sin(2 * math.pi * i / 6)) for i in range(6)]
    A = [bm.verts.new((a, -.09, b)) for a, b in hub]; B = [bm.verts.new((a, .09, b)) for a, b in hub]; bm.faces.new(B[::-1]); bm.faces.new(A)
    for i in range(6): j = (i + 1) % 6; bm.faces.new((A[j], A[i], B[i], B[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    st = add("steer", "Steering", bm, Md); st.location = (0, -.95, 1.85); st.rotation_euler = (math.radians(30), 0, 0)
    # lights: white headlight strips (2/side), red tail strips, squad underglow plate
    for s in (-1, 1):
        for k, z in enumerate((.9, 1.08)):
            strip(f"head{k}{s}", "Headlight", (s * 1.72, -4.98), (s * .7, -.7), z, .5, .07, M["wht"])
        strip(f"tail{s}", "Taillight", (s * .95, 5.0), (0, 1), 1.55, 1.2, .16, M["red"])
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1); bmesh.ops.scale(bm, vec=(3.0, 5.0, .15), verts=bm.verts)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, .2, .205)); add("underglow", "Underglow", bm, M["glow"])

phase2()
if PHASE >= 3: phase3()
else: decals()
if PHASE >= 4: phase4()
if PHASE >= 5: exec(compile(open('razor_tex.py').read(), 'razor_tex.py', 'exec'), globals())

# ================================================================= stats / render / checks
K = 105.5
REF = os.environ.get("RAZOR_REF", os.path.join(os.getcwd(), "..", "..", "..", "refs", "kart", "razor")) + "/"   # cwd = this folder
def stats(tag):
    L = []; tot = 0
    for g, obs in GRP.items():
        if g == "Proxy": continue
        t = sum(tris(o) for o in obs); tot += t; L.append(f"{g:12s}{t:6d}" + (f"   ({tris(obs[0])}/wheel x{len(obs)})" if g == 'Wheels' else ''))
    for g, obs in GRP.items():
        if g == "Proxy": continue
        vs = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
        L.append(f"  {g:11s} x[{min(v.x for v in vs):.2f},{max(v.x for v in vs):.2f}] y[{min(v.y for v in vs):.2f},{max(v.y for v in vs):.2f}] z[{min(v.z for v in vs):.2f},{max(v.z for v in vs):.2f}]")
    bad = 0
    for o in (o for g, obs in GRP.items() if g != "Proxy" for o in obs):
        b = bmesh.new(); b.from_mesh(o.data); bad += sum(1 for e in b.edges if len(e.link_faces) != 2); b.free()
    L.append(f"TOTAL {tot}   open/non-manifold edges: {bad}")
    open(os.path.join(OUT, f"{tag}_stats.txt"), "w").write("\n".join(L)); print("\n".join(L)); return tot

sc = bpy.context.scene
def setup_render(engine="CYCLES", w=1000, h=560, samples=24):
    sc.render.engine = engine; sc.render.resolution_x, sc.render.resolution_y = w, h; sc.render.image_settings.file_format = "PNG"
    if engine == "CYCLES":
        sc.cycles.device = "CPU"; sc.cycles.samples = samples
        try: sc.cycles.use_denoising = True
        except Exception: pass
cd = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
def persp(loc, tgt, lens=32):
    cd.type = "PERSP"; cd.lens = lens; cam.location = loc; cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
def ortho(loc, right, up, scale):
    back = Vector(right).cross(Vector(up)); cd.type = "ORTHO"; cd.ortho_scale = scale; cam.location = loc
    cam.matrix_world = Matrix.Translation(loc) @ Matrix(((right[0], up[0], back.x, 0), (right[1], up[1], back.y, 0), (right[2], up[2], back.z, 0), (0, 0, 0, 1)))
def scene_lights():
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (.55, .55, .57, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=30)
    gm = bpy.data.meshes.new("ground"); bm.to_mesh(gm); bm.free(); gm.materials.append(M["ground"])
    g = bpy.data.objects.new("ground", gm); sc.collection.objects.link(g)
    ld = bpy.data.lights.new("sun", "SUN"); ld.energy = 3.0; lo = bpy.data.objects.new("sun", ld); sc.collection.objects.link(lo)
    lo.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35)); return g
from PIL import Image, ImageDraw, ImageFilter
VIEWS = {"front34": lambda: persp((-9.6, -12.2, 3.0), (.2, -.2, 1.15), 32), "side": lambda: ortho((30, .0948, 1.5545), (0, 1, 0), (0, 0, 1), 1376 / K),
         "rear34": lambda: persp((-9.4, 12.4, 3.1), (0, .6, 1.3), 32), "top": lambda: ortho((0, 0, 30), (0, 1, 0), (-1, 0, 0), 13.5)}
def smooth_all(angle=35):
    for g, obs in GRP.items():
        for o in obs:
            o.data.polygons.foreach_set('use_smooth', [True] * len(o.data.polygons)); o.data.update()
            if not any(m.type == 'EDGE_SPLIT' for m in o.modifiers):
                m = o.modifiers.new('es', 'EDGE_SPLIT'); m.split_angle = math.radians(angle); m.use_edge_angle = True; m.use_edge_sharp = False
def beauty(tag):
    smooth_all(); ground = scene_lights(); ims = {}
    for n, f in VIEWS.items():
        f(); w, h = (1376, 768) if n == "side" else (1000, 560); setup_render("CYCLES", w, h, 24)
        sc.render.filepath = os.path.join(OUT, f"_{tag}_{n}.png"); bpy.ops.render.render(write_still=True); ims[n] = Image.open(sc.render.filepath).convert("RGB")
    sh = Image.new("RGB", (2000, 1120))
    for i, n in enumerate(("front34", "side", "rear34", "top")): sh.paste(ims[n].resize((1000, 560)), ((i % 2) * 1000, (i // 2) * 560))
    sh.save(os.path.join(OUT, f"{tag}-sheet.png"))
    refn = {"front34": "front-34", "side": "side", "rear34": "rear-34", "top": "top"}
    cmp = Image.new("RGB", (1400, 1568))
    for i, n in enumerate(("front34", "side", "rear34", "top")):
        cmp.paste(Image.open(REF + f"razor-{refn[n]}.png").convert("RGB").resize((700, 392)), (0, i * 392)); cmp.paste(ims[n].resize((700, 392)), (700, i * 392))
    cmp.save(os.path.join(OUT, f"{tag}-compare.png")); g = ground; bpy.data.objects.remove(g)
    return ims

def mask_render(loc_fn, w, h, path):
    sc.render.engine = "BLENDER_WORKBENCH"; sc.render.film_transparent = True
    sc.display.shading.light = "FLAT"; sc.display.shading.color_type = "SINGLE"; sc.display.shading.single_color = (1, 1, 1)
    sc.render.resolution_x, sc.render.resolution_y = w, h; loc_fn(); sc.render.filepath = path
    hide = [o for o in bpy.data.objects if o.name.startswith(("ground", "sun"))]
    bpy.ops.render.render(write_still=True); sc.render.film_transparent = False
    return np.asarray(Image.open(path))[:, :, 3] > 127

def silhouettes(tag, skip_groups=("Proxy",)):
    for g in skip_groups:
        for o in GRP.get(g, []): o.hide_render = True
    ms = mask_render(lambda: ortho((30, .0948, 1.5545), (0, 1, 0), (0, 0, 1), 1376 / K), 1376, 768, os.path.join(OUT, "_ms.png"))
    ref_s = np.asarray(Image.open(os.path.join(os.path.dirname(__file__) if "__file__" in globals() else ".", "mask_side.png"))) > 0 if os.path.exists("mask_side.png") else None
    mt = mask_render(lambda: ortho((0, 0, 30), (0, 1, 0), (-1, 0, 0), 1600 / K), 1600, 900, os.path.join(OUT, "_mt.png"))
    # top: warp my mask into ref pixel space with landmark mapping
    xs = np.arange(1376); Yv = np.interp(xs, [140, 365, 1025, 1265], [-5.3, -3.4, 3.6, 5.6])
    Yv = np.where(xs < 140, -5.3 + (xs - 140) / 118., Yv); Yv = np.where(xs > 1265, 5.6 + (xs - 1265) / 118., Yv)
    u = np.clip((800 + Yv * K).astype(int), 0, 1599); ys = np.arange(768); v = np.clip((450 + (ys - 386) / K * K).astype(int), 0, 899)
    mt_ref = mt[np.ix_(v, u)]
    ref_t = np.asarray(Image.open("mask_top.png")) > 0 if os.path.exists("mask_top.png") else None   # QA-only silhouette mask (not shipped); IoU skipped if absent
    body_cols = (xs > 200) & (xs < 1140)          # exclude splitter/wing zones for IoU
    res = {}
    if ref_t is not None:
        a = mt_ref[:, body_cols]; b = ref_t[:, body_cols]
        res["iou_top_body"] = round(float((a & b).sum() / max((a | b).sum(), 1)), 3)
    for nm, mk, ref in (("side", ms, None), ("top", mt_ref, ref_t)):
        base = Image.open(REF + f"razor-{nm}.png").convert("RGB"); arr = np.asarray(base).copy()
        e = mk ^ np.asarray(Image.fromarray((mk * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5))) .astype(bool)
        arr[e] = (255, 40, 40); Image.fromarray(arr).save(os.path.join(OUT, f"{tag}-sil-{nm}.png"))
    for g in skip_groups:
        for o in GRP.get(g, []): o.hide_render = False
    return res

if __name__ == "__main__" or True:
    tot = stats(f"phase{PHASE}")
    if os.environ.get("QUICK"):
        for o in GRP.get("Proxy", []): pass
        r = silhouettes(f"phase{PHASE}"); print(r)
    else:
        beauty(f"phase{PHASE}"); r = silhouettes(f"phase{PHASE}"); print(r)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "razor_build.blend"))
        if PHASE >= 6: exec(compile(open('razor_export.py').read(), 'razor_export.py', 'exec'), globals())
