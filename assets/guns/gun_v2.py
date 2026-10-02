"""Gun art v2: the four owner-locked v2 sheets (concepts-2026-09-30/*-v2.png) -> Blender meshes -> Roblox data.
Run from assets/guns:  blender -b -P gun_v2.py -- [gun ...]        (default: all four)
Outputs: v2/<id>.blend, v2/<id>-overlay.png (render over the sheet), v2/<id>-q.png, v2/info.json,
         ../../src/shared/GunArt/<id>.luau (first-person mesh data + world primitive LOD + points).
Geometry is authored in SHEET PIXELS of the locked side view (traced landmarks), so the overlay check is exact:
  stud = k * px, origin = grip top (hand web), muzzle tip lands on Config.Guns[i].muzzle Z (length kept).
Blender frame as gun_build.py: muzzle -Y, up +Z, gun LEFT = +X. Roblox = (-x, z, y).
gun_build.py (detail/color passes) is the superseded pre-v2 build, kept for history."""
import bpy, bmesh, math, sys, os, re, json, base64, struct
from mathutils import Vector, Matrix

_A = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = _A or ["dart9", "buzz", "ranger", "needle"]
HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
OUT = os.path.join(HERE, "v2"); os.makedirs(OUT, exist_ok=True)
LUA_OUT = os.path.join(HERE, "..", "..", "src", "shared", "GunArt"); os.makedirs(LUA_OUT, exist_ok=True)
SHEETS = os.path.join(HERE, "concepts-2026-09-30")
CFG = open(os.path.join(HERE, "..", "..", "src", "shared", "Config.luau")).read().split("Config.Guns = {", 1)[1]
MUZ_Z = {g: float(b.split(",")[2]) for g, b in re.findall(r'id = "(\w+)".*?muzzle = Vector3\.new\(([^)]*)\)', CFG, re.S)}

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

# Material zones -> Roblox (Color3 0-255, Enum.Material). Matte family from the locked sheets; no neon/emissive.
ZONES = [  # name, rgb, roblox material, blender roughness, metal
    ("Frame", (40, 41, 44), "SmoothPlastic", .62, 0), ("Black", (24, 24, 26), "SmoothPlastic", .55, 0),
    ("Grip", (30, 30, 32), "Plastic", .9, 0), ("Panel", (148, 142, 134), "SmoothPlastic", .45, .1),
    ("Steel", (176, 178, 182), "Metal", .3, 1), ("Foam", (255, 112, 34), "Sand", .95, 0),
    ("Plate", (112, 114, 118), "Metal", .5, .6), ("Lens", (34, 52, 58), "Glass", .1, 0),
]
ZI = {z[0]: i for i, z in enumerate(ZONES)}
MATS = []
for name, rgb, _, rough, metal in ZONES:
    m = bpy.data.materials.new(name); m.use_nodes = True; b = m.node_tree.nodes["Principled BSDF"]
    lin = tuple((c / 255) ** 2.2 for c in rgb)
    b.inputs["Base Color"].default_value = (*lin, 1); b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*lin, 1); MATS.append(m)

# ---------------------------------------------------------------- per-gun sheet frame
G = {}   # current gun frame: ox, oy (origin px), k (stud/px), s (+1 muzzle right on sheet, -1 left)
def Y(px): return (G["ox"] - px) * G["k"] * G["s"]
def Z(py): return (G["oy"] - py) * G["k"]
def W(px): return px * G["k"]
def P(pts): return [(Y(x), Z(y)) for x, y in pts]

def prof(pts, w, x=0., bev=.008):
    """Side polygon (Blender y, z) extruded +-w/2 along X; cap edges chamfered."""
    bm = bmesh.new()
    a = [bm.verts.new((x - w / 2, y, z)) for y, z in pts]; b = [bm.verts.new((x + w / 2, y, z)) for y, z in pts]
    fa = bm.faces.new(a[::-1]); fb = bm.faces.new(b); n = len(pts)
    for i in range(n):
        j = (i + 1) % n; bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bev:
        es = list(set(fa.edges) | set(fb.edges))
        bmesh.ops.bevel(bm, geom=es, offset=min(bev, w * .3), offset_type="OFFSET", segments=1, profile=.5, affect="EDGES", clamp_overlap=True)
    return bm

def lathe(pr, seg=12, x=0., z=0., axis="Y", smooth=True):
    """Revolve (r, t) rows about an axis through (x, ., z) (axis Y) or (., t, z) (axis X); r=0 rows collapse."""
    bm = bmesh.new(); rings = []
    def at(t, u, v): return (x + u, t, z + v) if axis == "Y" else (t, x + u, z + v)
    for r, t in pr:
        if r <= 1e-6:
            rings.append((t, [bm.verts.new(at(t, 0, 0))])); continue
        rings.append((t, [bm.verts.new(at(t, r * math.cos(2 * math.pi * (k + .5) / seg), r * math.sin(2 * math.pi * (k + .5) / seg))) for k in range(seg)]))
    for (ta, A), (tb, B) in zip(rings, rings[1:]):
        if len(A) == 1 and len(B) == 1: continue
        for k in range(seg):
            k2 = (k + 1) % seg
            if len(A) == 1: f = bm.faces.new((A[0], B[k], B[k2]))
            elif len(B) == 1: f = bm.faces.new((A[k], A[k2], B[0]))
            else: f = bm.faces.new((A[k], A[k2], B[k2], B[k]))
            f.smooth = smooth and len(A) > 1 and len(B) > 1 and abs(ta - tb) > 1e-6
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

def cut(bm, cutters):
    me = bpy.data.meshes.new("b"); bm.to_mesh(me); bm.free(); ob = bpy.data.objects.new("b", me); sc.collection.objects.link(ob); tmp = [ob]
    for c in cutters:
        cm = bpy.data.meshes.new("c"); c.to_mesh(cm); c.free(); co = bpy.data.objects.new("c", cm); sc.collection.objects.link(co); tmp.append(co)
        md = ob.modifiers.new("x", "BOOLEAN"); md.operation = "DIFFERENCE"; md.solver = "EXACT"; md.object = co
    ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()); out = bmesh.new(); out.from_mesh(ev.to_mesh()); ev.to_mesh_clear()
    for o in tmp:
        d = o.data; bpy.data.objects.remove(o); bpy.data.meshes.remove(d)
    return out

# ---- pixel-space shorthands. L = extruded side profile; B = box; C = cylinder along the bore axis (px x0..x1, centre y, radius r)
PIECES = []   # (group, zone, bmesh, lod)  lod: None | "block" | "cyl" (world primitive approximation)
def add(grp, zone, bm, lod=None): PIECES.append((grp, zone, bm, lod))
def L(pts, w, zone, grp="Receiver", x=0., bev=.008, lod=None, cuts=None):
    bm = prof(P(pts), W(w), x=W(x), bev=bev)
    if cuts: bm = cut(bm, cuts)
    add(grp, zone, bm, lod); return bm
def Bx(x0, x1, y0, y1, w, zone, grp="Receiver", x=0., bev=.006, lod=None):
    return L([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], w, zone, grp, x, bev, lod)
def C(x0, x1, r, cy, zone, grp="Receiver", seg=12, x=0., lod=None, rows=None):
    """Cylinder (or a lathe of (r_px, x_px) rows) along the bore direction at height cy px."""
    pr = rows or [(0, x0), (r, x0), (r, x1), (0, x1)]
    bm = lathe([(W(rr), Y(xx)) for rr, xx in pr], seg, W(x), Z(cy)); add(grp, zone, bm, lod); return bm
def Xc(cx, cy, r, w, zone, grp="Receiver", seg=8, x=0.):
    """Cylinder across the gun (axis X), e.g. pins, screws, turrets seen end-on in the side view."""
    bm = lathe([(0, W(x - w / 2)), (W(r), W(x - w / 2)), (W(r), W(x + w / 2)), (0, W(x + w / 2))], seg, Y(cx), Z(cy), axis="X")
    add(grp, zone, bm); return bm
def Vc(cx, y_top, y_bot, r, zone, grp="Receiver", seg=12, x=0.):
    """Vertical cylinder (axis Z), e.g. a scope turret."""
    bm = lathe([(0, 0), (W(r), 0), (W(r), W(y_bot - y_top)), (0, W(y_bot - y_top))], seg, 0, 0)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-90), 3, "X"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((W(x), Y(cx), Z(y_bot)))); add(grp, zone, bm); return bm
def LB(pts, w, zone, grp="Receiver"):
    """World-LOD-only block (min-area rectangle of the polygon); not part of the first-person mesh."""
    add(grp, zone, prof(P(pts), W(w), bev=0), "block-only")
def LC(x0, x1, r, cy, zone, grp="Receiver"):
    """World-LOD-only cylinder along the bore direction."""
    add(grp, zone, lathe([(0, Y(x0)), (W(r), Y(x0)), (W(r), Y(x1)), (0, Y(x1))], 8, 0, Z(cy)), "cyl-only")
def cutter(pts, w=400, x=0.): return prof(P(pts), W(w), x=W(x), bev=0)
def side_screws(pts, xs, r=6, zone="Steel", grp="Receiver"):
    for cx, cy in pts:
        for s in (-1, 1): Xc(cx, cy, r, 3, zone, grp, seg=8, x=s * xs)
def foam(x_front, x_back, r_front, r_back, cy, grp="Receiver", bore=.45):
    """Orange foam tip: rounded front lip, recessed bore, taper to r_back."""
    rf, rb = r_front, r_back; d = 1 if x_front > x_back else -1   # px direction toward the muzzle
    rows = [(0, x_front - d * 14), (rf * bore, x_front - d * 14), (rf * bore, x_front), (rf - 5, x_front), (rf, x_front - d * 5),
            (rb, x_back + d * 3), (rb - 3, x_back), (0, x_back)]
    C(0, 0, 0, cy, "Foam", grp, seg=16, rows=rows, lod="cyl")

# ---------------------------------------------------------------- guns (sheet pixel coordinates)
def dart9():
    # muzzle right; right side shown. slide warm grey, frame black, grip textured + grey side panels
    B0 = 140   # bore height px
    L([(55, 160), (72, 146), (205, 47), (912, 44), (926, 56), (926, 190), (745, 194), (560, 201), (300, 199), (100, 188)], 132, "Panel", "Mover", bev=.012, lod="block",
      cuts=[cutter([(212, 60), (330, 60), (318, 82), (222, 82)], 40, x=-62),           # ejection port (right)
            cutter([(744, 47), (756, 47), (756, 192), (744, 192)], 12, x=-66), cutter([(744, 47), (756, 47), (756, 192), (744, 192)], 12, x=66),
            cutter([(205, 47), (520, 47), (520, 70), (330, 70), (300, 100), (170, 100)], 20, x=-70)])   # stepped top flat
    L([(205, 47), (520, 47), (520, 58), (205, 58)], 104, "Panel", "Mover", bev=.004)                  # top facet
    L([(60, 150), (80, 116), (136, 58), (162, 46), (190, 52), (150, 120), (118, 150)], 150, "Black", "Mover", bev=.01)
    for i in range(5):   # rear serrations as raised ribs
        L([(70 + i * 15, 142 - i * 18), (80 + i * 15, 130 - i * 18), (100 + i * 15, 136 - i * 18), (90 + i * 15, 148 - i * 18)], 158, "Black", "Mover", bev=0)
    L([(200, 30), (240, 30), (240, 47), (200, 47)], 70, "Black", "Mover", bev=.004, cuts=[cutter([(214, 26), (226, 26), (226, 35), (214, 35)], 30)])   # rear notch sight
    L([(872, 35), (888, 35), (892, 46), (868, 46)], 34, "Black", "Mover", bev=.003)                    # front post
    Bx(330, 560, 90, 168, 6, "Plate", "Mover", x=-68, bev=.004); Bx(330, 560, 90, 168, 6, "Plate", "Mover", x=68, bev=.004)
    side_screws([(345, 104), (545, 104), (345, 154), (545, 154)], 71, r=7)
    side_screws([(240, 118)], 68, r=10)
    # frame: dust-cover rail, trigger guard (hole), front grey panel
    L([(100, 186), (300, 199), (560, 203), (745, 196), (928, 190), (905, 250), (808, 292), (712, 402), (470, 412), (418, 378), (402, 236), (150, 232)], 112, "Black", bev=.01,
      lod="block", cuts=[cutter([(470, 262), (668, 262), (705, 300), (660, 372), (488, 372), (462, 318)])])
    L([(756, 206), (918, 194), (905, 250), (808, 292), (776, 262)], 126, "Panel", bev=.008)
    side_screws([(842, 218)], 64, r=9)
    L([(505, 242), (526, 244), (532, 292), (553, 368), (541, 380), (516, 330), (496, 280)], 30, "Black", bev=.004)   # trigger
    # grip: frame core, textured wrap, grey side panels
    L([(95, 190), (300, 214), (404, 238), (418, 376), (342, 432), (313, 496), (322, 580), (360, 622), (70, 594), (104, 510), (145, 430), (190, 340), (198, 310), (165, 242)],
      116, "Frame", bev=.012, lod="block")
    L([(118, 214), (250, 240), (300, 300), (270, 420), (150, 560), (78, 586), (106, 505), (146, 426), (188, 338), (196, 310), (165, 248)], 128, "Grip", bev=.008)
    L([(270, 232), (402, 238), (416, 300), (350, 430), (318, 560), (300, 600), (150, 606), (240, 520), (290, 400), (300, 300)], 124, "Panel", bev=.008)
    side_screws([(360, 228), (218, 532)], 62, r=9)
    L([(65, 590), (362, 628), (346, 696), (100, 680)], 132, "Black", "Mag", bev=.012, lod="block")
    Bx(150, 230, 655, 672, 6, "Frame", "Mag", x=-66, bev=.002)
    foam(985, 925, 60, 55, B0)
    C(905, 928, 26, B0, "Black", "Mover", seg=12)   # barrel crown inside the slide nose
    LB([(60, 150), (80, 116), (136, 58), (162, 46), (190, 52), (150, 120), (118, 150)], 150, "Black", "Mover")
    LB([(756, 206), (918, 194), (905, 250), (808, 292), (776, 262)], 126, "Panel")
    LB([(462, 372), (705, 372), (705, 410), (470, 412)], 112, "Black")
    return dict(Sight=(220, 35), FrontSight=(880, 35), Grip=(250, 330), Support=(300, 480), MagWell=(220, 590), Eject=(270, 70),
                Engrave=(445, 129), Holster=(300, 200), Mover=(300, 120), Mag=(220, 600)), B0

def buzz():
    # muzzle LEFT; left side shown. grey receiver, black shroud + carry handle, rod stock, curved grey mag
    B0 = 222
    foam(16, 118, 66, 51, B0)
    C(0, 0, 0, B0, "Black", seg=16, lod="cyl", rows=[(0, 112), (60, 112), (64, 120), (64, 320), (60, 336), (0, 336)])   # vented shroud
    for i in range(3):
        for j in range(4):   # vent slots: raised dark ribs between them are implied by black slot inlays
            Bx(152 + i * 58, 196 + i * 58, 168 + j * 33, 180 + j * 33, 132, "Frame", bev=.003)
    C(0, 0, 0, B0, "Frame", seg=16, rows=[(0, 330), (66, 330), (66, 346), (0, 346)])
    L([(335, 192), (600, 192), (690, 182), (808, 180), (812, 240), (790, 290), (740, 298), (700, 320), (612, 332), (520, 332), (510, 294), (380, 296), (338, 286)],
      150, "Panel", bev=.012, lod="block", cuts=[cutter([(375, 210), (585, 210), (585, 262), (375, 262)], 10, x=-75), cutter([(375, 210), (585, 210), (585, 262), (375, 262)], 10, x=75)])
    Bx(378, 584, 212, 260, 6, "Plate", x=74, bev=.003); Bx(378, 584, 212, 260, 6, "Plate", x=-74, bev=.003)
    side_screws([(392, 225), (392, 248), (594, 232), (594, 252), (362, 286), (786, 205), (796, 278)], 76, r=7)
    L([(338, 286), (520, 290), (520, 300), (340, 300)], 140, "Black", bev=.004)
    # carry handle with top rail
    L([(215, 168), (276, 80), (300, 70), (690, 76), (712, 96), (706, 186), (676, 190), (676, 118), (650, 100), (330, 98), (310, 108), (262, 180)], 70, "Black",
      bev=.01)
    LB([(290, 66), (705, 66), (705, 100), (290, 100)], 70, "Black"); LB([(676, 96), (712, 96), (706, 190), (676, 190)], 70, "Black")
    LB([(215, 168), (276, 80), (310, 100), (262, 180)], 70, "Black")
    for i in range(14):
        Bx(300 + i * 20, 311 + i * 20, 62, 72, 60, "Frame", bev=0)
    side_screws([(300, 96), (690, 108)], 38, r=11)
    L([(612, 52), (640, 52), (644, 74), (608, 74)], 50, "Black", bev=.004, cuts=[cutter([(618, 50), (634, 50), (634, 62), (618, 62)], 20)])   # rear aperture
    L([(300, 62), (310, 62), (312, 72), (298, 72)], 16, "Black", bev=.002)                                                                    # front post
    # lower: magwell, trigger frame, pistol grip
    L([(360, 296), (512, 296), (520, 346), (382, 346)], 132, "Panel", bev=.008, lod="block")
    L([(512, 290), (790, 290), (700, 330), (660, 392), (530, 392), (520, 300)], 110, "Black", bev=.01,
      cuts=[cutter([(580, 318), (634, 318), (640, 352), (622, 378), (586, 378)])])
    L([(600, 330), (612, 330), (628, 372), (616, 376)], 22, "Black", bev=.003)
    L([(655, 300), (775, 296), (808, 500), (712, 546), (690, 470), (660, 380)], 110, "Grip", bev=.014, lod="block")
    for i in range(6): Bx(684 + i * 3, 692 + i * 3, 400 + i * 22, 410 + i * 22, 116, "Black", bev=.002)
    # stock: two rods + grey hinge plate + rubber pad
    C(808, 980, 15, 204, "Black", seg=10, lod="cyl"); C(808, 980, 11, 262, "Black", seg=10)
    L([(960, 186), (1020, 168), (1030, 400), (1000, 395), (960, 330)], 116, "Panel", bev=.012, lod="block")
    L([(1020, 164), (1074, 168), (1078, 395), (1030, 400)], 120, "Grip", bev=.014, lod="block")
    side_screws([(1005, 205), (1005, 285)], 60, r=8)
    # curved magazine: grey body, ribs, black base
    L([(405, 346), (518, 346), (473, 556), (440, 600), (316, 566), (345, 470)], 92, "Panel", "Mag", bev=.012, lod="block")
    for dx in (0, 34):
        L([(445 + dx, 356), (452 + dx, 356), (414 + dx, 548), (407 + dx, 548)], 98, "Frame", "Mag", bev=0)
    L([(312, 540), (440, 576), (430, 632), (305, 600)], 100, "Black", "Mag", bev=.012, lod="block")
    return dict(Sight=(626, 62), FrontSight=(305, 62), Grip=(730, 420), Support=(330, 300), MagWell=(460, 340), Eject=(500, 210),
                Engrave=(480, 236), Holster=(700, 300), Mag=(460, 340)), B0

def ranger():
    # muzzle right; right side shown. AR layout: grey M-LOK handguard, black receivers, grey stock
    B0 = 246
    foam(1179, 1110, 34, 34, B0)
    C(1080, 1112, 18, B0, "Black", seg=12)
    hg = L([(654, 214), (1086, 214), (1086, 283), (654, 283)], 74, "Panel", bev=.01, lod="block",
           cuts=[cutter([(710 + i * 40, 236 + j * 26), (740 + i * 40, 236 + j * 26), (740 + i * 40, 244 + j * 26), (710 + i * 40, 244 + j * 26)], 200) for i in range(9) for j in range(2)])
    C(654, 1086, 12, B0, "Black", seg=8)   # barrel visible through slots
    L([(456, 201), (1083, 201), (1083, 214), (456, 214)], 50, "Black", bev=.004, lod="block")
    for i in range(31): Bx(462 + i * 20, 472 + i * 20, 194, 202, 50, "Frame", bev=0)
    # flip sights (aperture rear, post front) on the rail
    L([(396, 202), (462, 202), (452, 176), (444, 150), (414, 150), (404, 176)], 30, "Black", bev=.005,
      cuts=[lathe([(0, -1), (W(8), -1), (W(8), 1), (0, 1)], 10, Y(429), Z(165), axis="X")])
    LB([(396, 202), (462, 202), (452, 160), (406, 160)], 30, "Black"); LB([(1022, 202), (1068, 202), (1050, 168), (1036, 168)], 26, "Black")
    L([(1014, 202), (1074, 202), (1064, 184), (1050, 175), (1046, 165), (1040, 165), (1036, 175), (1022, 184)], 26, "Black", bev=.004)
    # upper receiver + forward assist block, lower receiver w/ magwell and guard
    L([(354, 205), (654, 205), (654, 295), (380, 295), (354, 270)], 84, "Black", bev=.012, lod="block")
    L([(372, 214), (500, 222), (520, 238), (440, 250), (372, 246)], 92, "Panel", bev=.006)
    Bx(519, 636, 253, 292, 6, "Plate", x=44, bev=.003); Bx(519, 636, 253, 292, 6, "Plate", x=-44, bev=.003)
    side_screws([(529, 260), (626, 260), (529, 284), (626, 284)], 46, r=5)
    side_screws([(676, 260)], 40, r=8)
    L([(354, 292), (642, 292), (642, 345), (630, 365), (540, 368), (520, 376), (470, 378), (450, 340), (380, 330), (354, 300)], 80, "Black", bev=.01, lod="block",
      cuts=[cutter([(478, 318), (522, 318), (530, 356), (486, 366), (470, 340)])])
    L([(498, 318), (508, 318), (518, 352), (510, 354)], 14, "Black", bev=.002)
    L([(384, 328), (456, 346), (414, 492), (396, 494), (330, 462)], 70, "Grip", bev=.012, lod="block")
    side_screws([(398, 300), (444, 286)], 42, r=7)
    # stock: buffer tube + grey skeleton stock + rubber pad
    C(243, 356, 28, 250, "Black", seg=14, lod="cyl")
    L([(60, 221), (232, 221), (246, 236), (246, 272), (232, 286), (90, 290), (92, 300), (228, 292), (240, 304), (90, 398), (60, 400)], 76, "Panel", bev=.012, lod="block",
      cuts=[cutter([(110, 240), (170, 240), (170, 248), (110, 248)], 200)])
    L([(24, 216), (64, 214), (64, 404), (24, 404)], 82, "Grip", bev=.014, lod="block")
    # magazine
    L([(540, 345), (630, 340), (657, 524), (560, 556)], 64, "Black", "Mag", bev=.01, lod="block")
    for dx in (0, 26): L([(572 + dx, 352), (578 + dx, 352), (596 + dx, 540), (590 + dx, 542)], 68, "Frame", "Mag", bev=0)
    L([(555, 540), (657, 512), (664, 528), (560, 560)], 70, "Black", "Mag", bev=.006)
    return dict(Sight=(429, 165), FrontSight=(1043, 165), Grip=(380, 400), Support=(800, 290), MagWell=(590, 345), Eject=(560, 236),
                Engrave=(577, 272), Holster=(420, 250), Mag=(590, 345)), B0

def needle():
    # muzzle right; right side shown. steel barrel, black action, grey chassis, skeleton stock, scope, folded bipod
    B0 = 238
    foam(1327, 1230, 49, 46, B0)
    C(0, 0, 0, B0, "Steel", seg=14, lod="cyl", rows=[(0, 1236), (16, 1236), (17, 900), (20, 591), (0, 591)])
    # action: receiver + bolt shroud; bolt (mover) = shroud cylinder, arm, knob
    L([(300, 231), (591, 231), (591, 322), (412, 322), (300, 300)], 72, "Black", bev=.01, lod="block")
    C(289, 356, 15, 256, "Black", "Mover", seg=12, lod="cyl")
    LB([(108, 402), (244, 452), (244, 466), (108, 430)], 46, "Frame")
    for cx in (406, 554): LB([(cx - 24, 231), (cx + 24, 231), (cx + 20, 157), (cx - 20, 157)], 66, "Black")
    LB([(665, 343), (930, 343), (930, 361), (665, 361)], 46, "Black")
    C(330, 345, 19, 256, "Steel", "Mover", seg=12)
    # bolt arm: from shroud (349,256) down-right to knob (319,315), on the right side (Blender -X)
    a0, a1 = Vector((-W(30), Y(349), Z(256))), Vector((-W(52), Y(322), Z(310)))
    v = a1 - a0; L_ = v.length
    bm = lathe([(0, 0), (W(6), 0), (W(6), L_), (0, L_)], 8, 0, 0); q = Vector((0, 1, 0)).rotation_difference(v.normalized())
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=q.to_matrix()); bmesh.ops.translate(bm, verts=bm.verts, vec=a0); add("Mover", "Steel", bm)
    kb = bmesh.new(); bmesh.ops.create_uvsphere(kb, u_segments=10, v_segments=6, radius=W(17))
    for f in kb.faces: f.smooth = True
    bmesh.ops.translate(kb, verts=kb.verts, vec=Vector((-W(56), Y(319), Z(315)))); add("Mover", "Steel", kb)
    Bx(380, 517, 261, 308, 6, "Plate", x=38, bev=.003); Bx(380, 517, 261, 308, 6, "Plate", x=-38, bev=.003)
    # chassis forend (grey) with screws, rail base, scope rings, scope
    L([(517, 258), (900, 258), (900, 322), (560, 325), (517, 300)], 76, "Panel", bev=.012, lod="block")
    L([(560, 300), (900, 300), (900, 322), (560, 325)], 80, "Frame", bev=.004)
    side_screws([(545, 307), (865, 270)], 40, r=8)
    L([(376, 224), (598, 224), (598, 245), (376, 245)], 52, "Black", bev=.006)
    for cx in (406, 554): L([(cx - 24, 231), (cx + 24, 231), (cx + 20, 157), (cx - 20, 157)], 66, "Black", bev=.006)
    LC(266, 650, 22, 182, "Black"); LC(650, 778, 46, 182, "Black")
    C(0, 0, 0, 182, "Black", seg=16, rows=[(0, 266), (26, 266), (30, 278), (30, 330), (22, 352), (18, 380), (18, 600), (34, 650), (48, 700), (48, 776), (40, 780), (0, 780)])
    C(770, 778, 40, 182, "Lens", seg=16)
    C(262, 268, 22, 182, "Lens", seg=14)
    Vc(484, 120, 156, 20, "Black")                       # elevation turret (top)
    lathe_t = lathe([(0, 0), (W(18), 0), (W(18), W(34)), (0, W(34))], 12, 0, 0)   # windage turret (right side)
    bmesh.ops.rotate(lathe_t, verts=lathe_t.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Z"))
    bmesh.ops.translate(lathe_t, verts=lathe_t.verts, vec=Vector((-W(30), Y(484), Z(182)))); add("Receiver", "Black", lathe_t)
    # trigger group, grip, magazine
    L([(316, 322), (412, 322), (403, 360), (380, 376), (330, 372)], 50, "Black", bev=.006, cuts=[cutter([(336, 330), (392, 330), (380, 362), (342, 362)])])
    L([(350, 328), (358, 328), (366, 356), (360, 358)], 12, "Black", bev=.002)
    L([(246, 298), (306, 302), (302, 336), (276, 466), (234, 466), (222, 382), (240, 330)], 66, "Grip", bev=.012, lod="block")
    L([(410, 322), (524, 322), (524, 392), (410, 392)], 54, "Black", "Mag", bev=.008, lod="block")
    Bx(414, 520, 380, 392, 58, "Frame", "Mag", bev=.003)
    # skeleton stock: top beam, cheek riser, butt column, struts, rubber pad + hook
    L([(108, 278), (300, 288), (300, 305), (108, 305)], 52, "Panel", bev=.008, lod="block")
    L([(71, 245), (215, 245), (225, 260), (215, 281), (71, 281)], 58, "Panel", bev=.012, lod="block")
    L([(60, 275), (108, 275), (108, 436), (60, 436)], 56, "Panel", bev=.01, lod="block")
    L([(108, 402), (200, 440), (244, 450), (244, 466), (108, 430)], 46, "Frame", bev=.006)
    L([(108, 330), (118, 322), (236, 396), (230, 410)], 40, "Frame", bev=.004)
    L([(10, 265), (60, 265), (60, 436), (14, 436)], 64, "Grip", bev=.014, lod="block")
    L([(60, 436), (91, 436), (91, 476), (78, 476), (74, 450), (60, 450)], 30, "Black", bev=.004)
    side_screws([(84, 300), (90, 410), (128, 268)], 30, r=7)
    # folded bipod (rest pose: folded under the forend, legs forward)
    L([(845, 325), (880, 325), (880, 342), (845, 342)], 50, "Black", bev=.004)
    for s in (-1, 1): C(665, 930, 9, 352, "Black", seg=8, x=s * 14)
    return dict(Sight=(266, 182), FrontSight=(778, 182), Grip=(255, 400), Support=(760, 300), MagWell=(467, 322), Eject=(470, 250),
                Engrave=(448, 284), Holster=(280, 270), Mover=(349, 256), Mag=(467, 330)), B0

# frame per gun: (fn, sheet, origin px, muzzle tip px x, side shown: s=+1 muzzle right)
FRAMES = {"dart9": (dart9, "dart9-v2.png", (300, 205), 985, 1), "buzz": (buzz, "buzzline-v2.png", (715, 300), 16, -1),
          "ranger": (ranger, "ranger-v2.png", (420, 330), 1179, 1), "needle": (needle, "needlepoint-v2.png", (285, 325), 1327, 1)}
GROUPS = ("Receiver", "Mover", "Mag")
SHOWN = {1: "right", -1: "left"}

def rb(p): return [round(-p[0], 4), round(p[2], 4), round(p[1], 4)]

# ---------------------------------------------------------------- export helpers
def mesh_data(bms):
    """Merge bmeshes, triangulate; one vertex per (position, flat-or-smooth normal) so Roblox's automatic normals
    reproduce hard edges. Returns Roblox-frame positions, triangles."""
    verts, tris, key = [], [], {}
    for bm in bms:
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bm.normal_update()
        for f in bm.faces:
            idx = []
            for v in f.verts:
                n = v.normal if f.smooth else f.normal
                p = rb(v.co); nn = (round(n.x, 2), round(n.y, 2), round(n.z, 2)) if not f.smooth else ("s",)
                kk = (tuple(round(c, 4) for c in p), nn if not f.smooth else ("s", id(bm)))
                if kk not in key: key[kk] = len(verts); verts.append(p)
                idx.append(key[kk])
            if len(set(idx)) == 3: tris.append(idx)
    return verts, tris

def encode(verts, tris):
    lo = [min(v[i] for v in verts) for i in range(3)]; hi = [max(v[i] for v in verts) for i in range(3)]
    ext = [max(hi[i] - lo[i], 1e-4) for i in range(3)]
    raw = b"".join(struct.pack("<HHH", *[int(round((v[i] - lo[i]) / ext[i] * 65535)) for i in range(3)]) for v in verts)
    raw += b"".join(struct.pack("<HHH", *t) for t in tris)
    return base64.b64encode(raw).decode(), lo, ext

def min_rect(pts2):
    """Min-area rectangle of a 2D (y, z) point set: centre, size (along, across), angle (radians about X)."""
    best = None
    for i in range(len(pts2)):
        (y0, z0), (y1, z1) = pts2[i], pts2[(i + 1) % len(pts2)]
        a = math.atan2(z1 - z0, y1 - y0); c, s = math.cos(a), math.sin(a)
        us = [p[0] * c + p[1] * s for p in pts2]; vs = [-p[0] * s + p[1] * c for p in pts2]
        area = (max(us) - min(us)) * (max(vs) - min(vs))
        if best is None or area < best[0]:
            cu, cv = (max(us) + min(us)) / 2, (max(vs) + min(vs)) / 2
            best = (area, (cu * c - cv * s, cu * s + cv * c), (max(us) - min(us), max(vs) - min(vs)), a)
    return best[1:]

def hull(pts):
    pts = sorted(set(pts))
    if len(pts) < 3: return pts
    def cross(o, a, b): return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0: lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0: up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]

def lua_v(v): return "Vector3.new(%s)" % ", ".join(f"{c:.4f}".rstrip("0").rstrip(".") if abs(c) > 1e-9 else "0" for c in v)

# ---------------------------------------------------------------- render (overlay on the sheet + 3/4 view)
def setup_render():
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (.5, .5, .52, 1)
    sc.render.engine = "BLENDER_WORKBENCH"; sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_cavity = True; sc.display.shading.cavity_type = "WORLD"
    sc.render.film_transparent = True; sc.view_settings.view_transform = "Standard"
    cd = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
    return cam, cd

def overlay(g, sheet, s, cam, cd):
    im = bpy.data.images.load(os.path.join(SHEETS, sheet)); Wpx, Hpx = im.size; bpy.data.images.remove(im)
    sc.render.resolution_x, sc.render.resolution_y = Wpx, Hpx; cd.type = "ORTHO"; cd.ortho_scale = Wpx * G["k"]; cd.clip_end = 100
    cx, cy = Y(Wpx / 2), Z(Hpx / 2)
    if s == 1:   # right side shown: camera on -X looking +X
        cam.matrix_world = Matrix(((0, 0, -1, -20), (-1, 0, 0, cx), (0, 1, 0, cy), (0, 0, 0, 1)))
    else:        # left side: camera on +X looking -X
        cam.matrix_world = Matrix(((0, 0, 1, 20), (1, 0, 0, cx), (0, 1, 0, cy), (0, 0, 0, 1)))
    p = os.path.join(OUT, f"{g}-side.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True); return p

def quarter(g, obs, cam, cd):
    vs = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
    lo = Vector([min(v[i] for v in vs) for i in range(3)]); hi = Vector([max(v[i] for v in vs) for i in range(3)]); c = (lo + hi) / 2
    sc.render.resolution_x, sc.render.resolution_y = 1100, 640; cd.type = "PERSP"; cd.lens = 50; cd.clip_start = .01
    out = []
    for n, d in (("q-left", (1.0, -1.1, .5)), ("fp", (.55, 1.0, .32))):
        loc = c + Vector(d).normalized() * (hi.y - lo.y) * (1.9 if n == "q-left" else 1.25)
        cam.location = loc; cam.rotation_euler = (c - loc).to_track_quat("-Z", "Y").to_euler()
        p = os.path.join(OUT, f"{g}-{n}.png"); sc.render.filepath = p; bpy.ops.render.render(write_still=True); out.append(p)
    return out

# ---------------------------------------------------------------- main
cam, cd = setup_render()
INFO = json.load(open(os.path.join(OUT, "info.json"))) if os.path.exists(os.path.join(OUT, "info.json")) else {}
for g in ONLY:
    fn, sheet, (ox, oy), tip, s = FRAMES[g]
    G.update(ox=ox, oy=oy, s=s, k=abs(MUZ_Z[g]) / abs(tip - ox))
    pts, B0 = fn()
    piv = {k: (Y(v[0]), Z(v[1])) for k, v in pts.items()}
    # Blender objects (one per group, zones as material slots) for renders / .blend
    obs, parts = [], []
    for grp in GROUPS:
        items = [(z, bm, lod) for (gg, z, bm, lod) in PIECES if gg == grp and not (lod or "").endswith("-only")]
        if not items: continue
        out = bmesh.new()
        for z, bm, _ in items:
            for f in bm.faces: f.material_index = ZI[z]
            me = bpy.data.meshes.new("t"); bm.to_mesh(me); out.from_mesh(me); bpy.data.meshes.remove(me)
        me = bpy.data.meshes.new(grp); out.to_mesh(me); out.free()
        for m in MATS: me.materials.append(m)
        ob = bpy.data.objects.new(grp, me); sc.collection.objects.link(ob); obs.append(ob)
    bpy.context.view_layer.update()
    side = overlay(g, sheet, s, cam, cd); quarter(g, obs, cam, cd)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"{g}.blend"))
    # Roblox data: one mesh per (group, zone); world LOD primitives from flagged pieces
    tri_total, lua_parts, world, wtris = 0, [], [], 0
    for grp in GROUPS:
        for zname, _, rmat, _, _ in ZONES:
            bms = [bm.copy() for (gg, z, bm, lod) in PIECES if gg == grp and z == zname and not (lod or "").endswith("-only")]
            if not bms: continue
            verts, tris = mesh_data(bms)
            for b in bms: b.free()
            b64, lo, ext = encode(verts, tris); tri_total += len(tris)
            lua_parts.append(f'\t\t{{ group = "{grp}", zone = "{zname}", verts = {len(verts)}, tris = {len(tris)}, min = {lua_v(lo)}, ext = {lua_v(ext)},\n\t\t\tdata = "{b64}" }},')
    for (grp, z, bm, lod) in PIECES:
        if not lod: continue
        co = [v.co for v in bm.verts]
        if lod.startswith("cyl"):
            ys = [c.y for c in co]; r = max(math.hypot(c.x, c.z - (sum(cc.z for cc in co) / len(co))) for c in co)
            zc = sum(c.z for c in co) / len(co); xc = sum(c.x for c in co) / len(co)
            world.append(dict(kind="Cylinder", group=grp, zone=z, cf=rb((xc, (max(ys) + min(ys)) / 2, zc)), angle=0,
                              size=[round(2 * r, 4), round(2 * r, 4), round(max(ys) - min(ys), 4)])); wtris += 96
        else:
            (cy_, cz_), (lu, lv), a = min_rect(hull([(round(c.y, 4), round(c.z, 4)) for c in co]))
            xs = [c.x for c in co]
            world.append(dict(kind="Block", group=grp, zone=z, cf=rb(((max(xs) + min(xs)) / 2, cy_, cz_)), angle=round(a, 4),
                              size=[round(max(xs) - min(xs), 4), round(lv, 4), round(lu, 4)])); wtris += 12
    # engraving zone = the gun-LEFT plate (Blender +X): centre + size in the Roblox frame
    pl_pts = [v.co for (gg, z, bm, _) in PIECES if z == "Plate" and gg == "Receiver" for v in bm.verts]
    eg = "Receiver" if pl_pts else "Mover"
    pl_pts = pl_pts or [v.co for (gg, z, bm, _) in PIECES if z == "Plate" for v in bm.verts]
    left = [c for c in pl_pts if c.x > 0]
    elo = [min(c[i] for c in left) for i in range(3)]; ehi = [max(c[i] for c in left) for i in range(3)]
    eng = f"engrave = {{ group = \"{eg}\", pos = {lua_v(rb((ehi[0] + .002, (elo[1] + ehi[1]) / 2, (elo[2] + ehi[2]) / 2)))}, size = Vector2.new({ehi[1] - elo[1]:.4f}, {ehi[2] - elo[2]:.4f}) }},"
    zl = ", ".join(f'{n} = {{ color = Color3.fromRGB({r}, {gg_}, {b}), material = Enum.Material.{m} }}' for n, (r, gg_, b), m, _, _ in ZONES)
    pl = ", ".join(f"{k} = {lua_v(rb((0., v[0], v[1])))}" for k, v in sorted(piv.items()))
    wl = "\n".join(f'\t\t{{ kind = "{w["kind"]}", group = "{w["group"]}", zone = "{w["zone"]}", pos = {lua_v(w["cf"])}, pitch = {-w["angle"] if w["kind"] == "Block" else 0}, size = {lua_v(w["size"])} }},' for w in world)
    src = (f"-- GENERATED by assets/guns/gun_v2.py from the locked {sheet} (do not hand-edit; rerun the script).\n"
           f"-- First-person: {tri_total} triangles in {len(lua_parts)} meshes (built at runtime via EditableMesh). World LOD: {len(world)} primitives.\n"
           f"-- Frame: studs, origin = grip top, muzzle along -Z, +X = gun right. data = base64(uint16 xyz quantised over min..min+ext, then uint16 triangles).\n"
           "return {\n"
           f'\tid = "{g}", tris = {tri_total},\n'
           f"\tzones = {{ {zl} }},\n"
           f"\tpoints = {{ {pl} }},\n"
           f"\t{eng}\n"
           "\tmeshes = {\n" + "\n".join(lua_parts) + "\n\t},\n"
           "\tworld = {\n" + wl + "\n\t},\n}\n")
    open(os.path.join(LUA_OUT, f"{g}.luau"), "w").write(src)
    INFO[g] = dict(fp_tris=tri_total, world_prims=len(world), world_tris_est=wtris, k=round(G["k"], 6), muzzle=rb((0., Y(tip), Z(B0))),
                   points={k: rb((0., v[0], v[1])) for k, v in piv.items()})
    print("GUN", g, "fp tris", tri_total, "world prims", len(world), "~tris", wtris, "muzzle", INFO[g]["muzzle"])
    for (_, _, bm, _) in PIECES: bm.free()
    PIECES.clear()
    for o in obs:
        d = o.data; bpy.data.objects.remove(o); bpy.data.meshes.remove(d)
json.dump(INFO, open(os.path.join(OUT, "info.json"), "w"), indent=1)
