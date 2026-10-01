"""Gun detail build (Phase 3-4: detail + attachment points). Run from this folder:
  blender -b -P gun_build.py -- detail OUTDIR [gun ...]
  blender -b -P gun_build.py -- color OUTDIR [gun ...]  # painted review pass
Blender frame: 1 BU = 1 stud, origin = grip, muzzle = -Y, up = +Z. Export (later) applies Rz(180) like RAZOR,
so Roblox = (-x, z, y): gun LEFT = Blender +X, gun RIGHT = Blender -X.
Muzzle tip (foam front face, bore axis) = Config.Guns[i].muzzle, read from src/shared/Config.luau.
Parts: Receiver, Mag, Mover (only where a mover exists), Plate. Material slots = future atlas zones."""
import bpy, bmesh, math, sys, os, re, json
from mathutils import Vector, Matrix

_A = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PHASE = _A[0] if _A else "detail"
OUT = _A[1] if len(_A) > 1 else "detail"
ONLY = _A[2:] or ["dart9", "buzz", "ranger", "needle"]
os.makedirs(OUT, exist_ok=True)
HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else os.getcwd()
CFG_LUAU = os.path.join(HERE, "..", "..", "src", "shared", "Config.luau")

# ---- Config muzzles (Roblox frame) -> Blender (y = Rz, z = Ry)
MUZ = {}
for gid, body in re.findall(r'id = "(\w+)".*?muzzle = Vector3\.new\(([^)]*)\)', open(CFG_LUAU).read().split("Config.Guns = {", 1)[1], re.S):
    x, y, z = (float(v) for v in body.split(",")); MUZ[gid] = (y, z)   # (bore height, tip y)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

# ---- materials (slot order = atlas zones): 0 black, 1 charcoal, 2 foam, 3 steel, 4 plate grey
def mat(n, c, rough=.6, metal=0.):
    m = bpy.data.materials.new(n); m.use_nodes = True; b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*c, 1); b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
    # Fine molded-plastic grain under a smooth clearcoat; the export atlas is a later step.
    if PHASE == "color" and n in ("charcoal", "black"):
        nodes = m.node_tree.nodes; links = m.node_tree.links
        grain = nodes.new("ShaderNodeTexNoise"); grain.inputs["Scale"].default_value = 240
        grain.inputs["Detail"].default_value = 2
        bump = nodes.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = .035
        bump.inputs["Distance"].default_value = .0015
        links.new(grain.outputs["Fac"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], b.inputs["Normal"])
    return m
MATS = [mat("black", (.030, .030, .033), .62), mat("charcoal", (.085, .085, .092), .7), mat("foam", (.85, .30, .04), .95),
        mat("steel", (.55, .56, .58), .32, 1.), mat("plate", (.26, .26, .28), .85), mat("trim", (.7, .7, .7), .55)]
BLK, CHR, FOAM, STEEL, PLATE, TRIM = range(6)

# Deep lacquered plastic, not illumination. Keep the orange foam tip and neutral plate.
PALETTES = {
    "dart9": ((.005, .022, .12), (.62, .34, .07)),     # midnight cobalt / brass
    "buzz": ((.17, .006, .005), (.72, .30, .025)),   # oxblood / warm gold
    "ranger": ((.003, .055, .04), (.39, .56, .39)),  # deep petrol / sage metal
    "needle": ((.05, .006, .095), (.61, .39, .12)),  # aubergine / champagne
}

def set_palette(g):
    base = MATS[BLK].node_tree.nodes["Principled BSDF"]
    base.inputs["Base Color"].default_value = (.018, .021, .03, 1)
    base.inputs["Roughness"].default_value = .31
    base.inputs["Coat Weight"].default_value = .18
    base.inputs["Coat Roughness"].default_value = .19
    plate = MATS[PLATE].node_tree.nodes["Principled BSDF"]
    plate.inputs["Base Color"].default_value = (.11, .12, .13, 1)
    plate.inputs["Roughness"].default_value = .43
    steel = MATS[STEEL].node_tree.nodes["Principled BSDF"]
    steel.inputs["Base Color"].default_value = (.37, .39, .44, 1)
    steel.inputs["Roughness"].default_value = .23
    for index, rgb in ((CHR, PALETTES[g][0]), (TRIM, PALETTES[g][1])):
        shader = MATS[index].node_tree.nodes["Principled BSDF"]
        shader.inputs["Base Color"].default_value = (*rgb, 1)
        shader.inputs["Roughness"].default_value = .18 if index == CHR else .24
        shader.inputs["Metallic"].default_value = .16 if index == CHR else .68
        shader.inputs["Coat Weight"].default_value = .62 if index == CHR else .25
        shader.inputs["Coat Roughness"].default_value = .09 if index == CHR else .18

# ---------------------------------------------------------------- bmesh helpers
def prof(pts, w, x=0., bev=.012):
    """Side polygon (y, z) extruded +-w/2 along X; silhouette (cap-boundary) edges chamfered."""
    bm = bmesh.new()
    a = [bm.verts.new((x - w / 2, y, z)) for y, z in pts]; b = [bm.verts.new((x + w / 2, y, z)) for y, z in pts]
    fa = bm.faces.new(a[::-1]); fb = bm.faces.new(b); n = len(pts)
    for i in range(n):
        j = (i + 1) % n; bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bev:
        es = list(set(fa.edges) | set(fb.edges))
        bmesh.ops.bevel(bm, geom=es, offset=min(bev * 1.4, w * .3), offset_type="OFFSET", segments=2 if bev >= .012 else 1, profile=.5, affect="EDGES", clamp_overlap=True)
    return bm

def box(y0, y1, z0, z1, w, x=0., bev=.01):
    return prof([(y0, z0), (y1, z0), (y1, z1), (y0, z1)], w, x, bev)

def lathe(pr, seg=14, x=0., z=0., axis="Y"):
    """Revolve (r, t) profile about an axis through (x, ., z) (axis Y) or (., t, z) (axis X); r=0 rows collapse."""
    bm = bmesh.new(); rings = []
    for r, t in pr:
        if r <= 1e-6:
            rings.append([bm.verts.new((x, t, z) if axis == "Y" else (t, x, z))]); continue
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg; u, v = r * math.cos(a), r * math.sin(a)
            ring.append(bm.verts.new((x + u, t, z + v) if axis == "Y" else (t, x + u, z + v)))
        rings.append(ring)
    for A, B in zip(rings, rings[1:]):
        if len(A) == 1 and len(B) == 1: continue
        for k in range(seg):
            k2 = (k + 1) % seg
            if len(A) == 1: bm.faces.new((A[0], B[k], B[k2]))
            elif len(B) == 1: bm.faces.new((A[k], A[k2], B[0]))
            else: bm.faces.new((A[k], A[k2], B[k2], B[k])).smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

def cyl(y0, y1, r, z, x=0., seg=12):
    return lathe([(0, y0), (r, y0), (r, y1), (0, y1)], seg, x, z)

def muzzle(ym, zb, r, back, seg=16):
    """Orange foam tip: flared lip, waist groove, recessed bore. Front face at y = ym."""
    return lathe([(0, ym + .045), (.034, ym + .045), (.034, ym), (r - .014, ym), (r, ym + .014), (r, ym + .055), (r - .012, ym + .07),
                  (r - .012, ym + .09), (r - .004, ym + .1), (r - .004, back - .012), (r - .02, back), (0, back)], seg, 0, zb)

def rail(y0, y1, z, w=.11, n=8, h=.035):
    """Picatinny-ish top rail: base + n teeth (one mesh)."""
    bm = box(y0, y1, z, z + h * .55, w, bev=.006); p = (y1 - y0) / n
    for i in range(n):
        t = box(y0 + i * p + p * .2, y0 + i * p + p * .8, z + h * .5, z + h, w * 1.1, bev=0)
        me = bpy.data.meshes.new("t"); t.to_mesh(me); t.free(); bm.from_mesh(me); bpy.data.meshes.remove(me)
    return bm

def cut(bm, cutters):
    """Boolean DIFFERENCE (exact) of cutter bmeshes from bm; returns a new bmesh."""
    me = bpy.data.meshes.new("b"); bm.to_mesh(me); bm.free(); ob = bpy.data.objects.new("b", me); sc.collection.objects.link(ob); tmp = [ob]
    for c in cutters:
        cm = bpy.data.meshes.new("c"); c.to_mesh(cm); c.free(); co = bpy.data.objects.new("c", cm); sc.collection.objects.link(co); tmp.append(co)
        md = ob.modifiers.new("x", "BOOLEAN"); md.operation = "DIFFERENCE"; md.solver = "EXACT"; md.object = co
    ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get()); out = bmesh.new(); out.from_mesh(ev.to_mesh()); ev.to_mesh_clear()
    for o in tmp:
        d = o.data; bpy.data.objects.remove(o); bpy.data.meshes.remove(d)
    return out

def recess(y0, y1, z0, z1, xs, d=.016):
    """Cutters for a shallow side recess at both faces x = +-xs (pass to cut())."""
    return [box(y0, y1, z0, z1, 2 * d, x=s * xs, bev=0) for s in (-1, 1)]

def through(pts, w=2.):
    return prof(pts, w, bev=0)

# ---------------------------------------------------------------- per-gun assembly
PIECES = {}   # group -> [(bm, mat)]
def add(grp, bm, m): PIECES.setdefault(grp, []).append((bm, m))

def trigger_group(gy=0., zt=-.08, w=.10):
    """Guard (with hole) + trigger, guard front at gy-.36."""
    g = prof([(gy - .37, zt - .02), (gy - .33, zt - .17), (gy + .0, zt - .17), (gy + .03, zt)], w, bev=.01)
    g = cut(g, [through([(gy - .30, zt - .01), (gy - .27, zt - .125), (gy - .04, zt - .125), (gy - .03, zt - .01)])])
    add("Receiver", g, CHR)
    add("Receiver", prof([(gy - .19, zt), (gy - .13, zt), (gy - .14, zt - .07), (gy - .18, zt - .115), (gy - .215, zt - .105), (gy - .185, zt - .055)], .04, bev=.006), BLK)

def paint_details(g):
    """Small molded-in color breaks and tactile marks; joined into the existing four parts."""
    if g == "dart9":
        add("Mover", box(-.84, -.35, .265, .285, .15, bev=.006), CHR)
        add("Mover", box(-.17, .12, .267, .287, .15, bev=.006), CHR)
        for side in (-1, 1):
            add("Mover", box(-.87, -.82, .07, .20, .012, x=side * .108, bev=.003), TRIM)
        add("Mag", box(.09, .32, -.649, -.636, .18, bev=.002), TRIM)
    elif g == "buzz":
        for side in (-1, 1):
            add("Receiver", box(-1.10, -.64, .183, .20, .012, x=side * .132, bev=.003), TRIM)
            add("Mag", box(-.58, -.50, -.63, -.25, .010, x=side * .084, bev=.002), TRIM)
        add("Receiver", box(.97, 1.05, -.12, -.10, .205, bev=.003), TRIM)
    elif g == "ranger":
        for side in (-1, 1):
            add("Receiver", box(-1.62, -1.13, .174, .191, .012, x=side * .111, bev=.003), TRIM)
            add("Receiver", box(.77, 1.11, .174, .191, .012, x=side * .102, bev=.003), TRIM)
        add("Mag", box(-.90, -.60, -.859, -.845, .19, bev=.003), TRIM)
    elif g == "needle":
        for side in (-1, 1):
            add("Receiver", box(-.99, -.88, .185, .205, .012, x=side * .106, bev=.003), TRIM)
            add("Receiver", box(-.10, .36, .185, .205, .012, x=side * .106, bev=.003), CHR)
        add("Receiver", cyl(-1.99, -1.96, .067, .12, seg=12), TRIM)
        add("Receiver", cyl(-1.61, -1.58, .067, .12, seg=12), CHR)
        add("Receiver", cyl(-.82, -.80, .104, .38, seg=12), TRIM)
        add("Mag", box(-.63, -.36, -.51, -.498, .17, bev=.003), TRIM)

def build(g):
    if PHASE == "color": set_palette(g)
    ZB, YM = MUZ[g]
    P = {}
    if g == "dart9":   # slim toy slide pistol (no ref): boxy slide, serrations, rail, finger-groove grip
        s = prof([(-.93, 0.), (.24, 0.), (.26, .05), (.24, .25), (.18, .27), (-.86, .27), (-.93, .21)], .20, bev=.016)
        cs = [box(.04 + i * .035, .055 + i * .035, .05, .235, .024, x=sx * .1, bev=0) for i in range(5) for sx in (-1, 1)]
        cs += [box(-.26, -.02, .20, .32, .09, x=-.065, bev=0)]                       # ejection port (right/top)
        cs += [box(-.80, -.62, .085, .115, .03, x=sx * .1, bev=0) for sx in (-1, 1)]   # front cocking groove
        add("Mover", cut(s, cs), BLK)
        add("Mover", box(-.82, -.76, .26, .31, .05, bev=.008), BLK)                   # front sight
        for sx in (-1, 1): add("Mover", box(.15, .21, .26, .32, .035, x=sx * .045, bev=.006), BLK)
        f = prof([(-.86, .0), (.18, .0), (.18, -.10), (-.40, -.10), (-.47, -.15), (-.86, -.15)], .18, bev=.012)
        add("Receiver", f, CHR)
        add("Receiver", box(-.82, -.50, -.18, -.15, .12, bev=.006), CHR)
        for i in range(3): add("Receiver", box(-.80 + i * .1, -.75 + i * .1, -.20, -.17, .14, bev=0), CHR)
        trigger_group(0., -.10, .10)
        add("Receiver", prof([(-.04, -.10), (.26, -.04), (.29, -.08), (.22, -.14), (.33, -.56), (.31, -.60), (.10, -.60), (.08, -.56), (.07, -.48),
                              (.04, -.44), (.05, -.36), (.02, -.32), (.03, -.24), (0., -.18), (-.02, -.14)], .18, bev=.016), CHR)
        add("Receiver", prof([(.07, -.20), (.21, -.20), (.29, -.52), (.13, -.52)], .204, bev=.008), BLK)   # grip panels
        add("Receiver", muzzle(YM, ZB, .082, -.90), FOAM)
        add("Mag", prof([(.07, -.14), (.20, -.14), (.29, -.60), (.12, -.60)], .13, bev=0), BLK)
        add("Mag", prof([(.09, -.595), (.32, -.595), (.34, -.65), (.08, -.65)], .20, bev=.012), BLK)
        add("Plate", box(-.62, -.24, .06, .21, .012, x=.105, bev=.004), PLATE)
        P = dict(Sight=(0, .18, .31), Grip=(0, .15, -.30), Support=(0, .20, -.42), MagWell=(0, .13, -.12), Eject=(-.10, -.14, .24),
                 MountOptic=(0, -.30, .27), MountBarrel=(0, -.93, ZB), MountGrip=(0, -.66, -.20), Engrave=(.111, -.43, .135), HolsterHip=(0, -.30, .05))
        PIV = dict(Mover=(0, .24, .0), Mag=(0, .13, -.12))
    elif g == "buzz":  # slim MP5-ish (ref 2): ribbed handguard, cocking tube, hooded front sight, aperture rear, rod stock
        add("Receiver", prof([(-.60, -.06), (.40, -.06), (.40, .20), (.34, .27), (-.52, .27), (-.60, .22)], .22, bev=.016), BLK)
        add("Receiver", rail(-.45, .14, .27, w=.10, n=8), CHR)
        h = prof([(-1.16, -.02), (-.60, -.08), (-.60, .22), (-1.12, .22), (-1.18, .17)], .25, bev=.018)
        cs = [c for i in range(4) for c in recess(-1.06 + i * .11, -.99 + i * .11, .0, .15, .125, .018)]
        add("Receiver", cut(h, cs), CHR)
        add("Receiver", cyl(-1.20, -.60, .042, .245, seg=10), BLK)                     # cocking tube
        add("Receiver", lathe([(0, -1.20), (.06, -1.20), (.06, -1.12), (.05, -1.12), (.05, -1.08), (0, -1.08)], 14, 0, ZB), BLK)   # barrel collar
        fs = prof([(-1.17, .22), (-1.07, .22), (-1.09, .40), (-1.15, .40)], .14, bev=.008)
        add("Receiver", cut(fs, [lathe([(0, -1.3), (.035, -1.3), (.035, -1.0), (0, -1.0)], 10, 0, .345)]), BLK)  # hooded front sight
        rs = prof([(.16, .27), (.32, .27), (.30, .40), (.19, .40)], .13, bev=.008)
        add("Receiver", cut(rs, [lathe([(0, .0), (.028, .0), (.028, .5), (0, .5)], 10, 0, .345)]), BLK)       # aperture rear sight
        add("Receiver", prof([(-.64, -.06), (-.32, -.06), (-.35, -.17), (-.62, -.17)], .19, bev=.01), BLK)     # magwell
        trigger_group(0., -.06, .10)
        add("Receiver", prof([(-.02, -.06), (.22, -.06), (.24, -.14), (.36, -.56), (.34, -.60), (.16, -.60), (.13, -.55), (.10, -.38),
                              (.07, -.33), (.05, -.22), (0., -.15)], .17, bev=.015), CHR)
        add("Receiver", prof([(.08, -.20), (.22, -.20), (.31, -.52), (.17, -.52)], .186, bev=.008), BLK)
        add("Receiver", box(.38, .48, .0, .18, .18, bev=.012), BLK)                    # stock block
        for sx in (-1, 1): add("Receiver", lathe([(0, .44), (.024, .44), (.024, .98), (0, .98)], 8, sx * .06, .10), CHR)
        add("Receiver", prof([(.94, .26), (1.04, .24), (1.06, -.14), (.98, -.12), (.94, -.04)], .20, bev=.02), BLK)
        add("Receiver", muzzle(YM, ZB, .09, -1.10), FOAM)
        m = prof([(-.60, -.06), (-.36, -.06), (-.40, -.40), (-.50, -.74), (-.74, -.74), (-.66, -.40)], .15, bev=.012)
        add("Mag", cut(m, [prof([(-.56, -.20), (-.44, -.20), (-.50, -.62), (-.62, -.62)], .028, x=sx * .075, bev=0) for sx in (-1, 1)]), BLK)   # mag window
        add("Mag", prof([(-.77, -.73), (-.48, -.73), (-.47, -.80), (-.78, -.80)], .18, bev=.012), BLK)
        add("Mover", box(-.98, -.92, .21, .29, .05, x=.075, bev=.008), BLK)
        add("Mover", lathe([(0, .09), (.022, .09), (.022, .15), (.03, .15), (.03, .19), (0, .19)], 8, -.95, .25, axis="X"), BLK)
        add("Plate", box(-.46, .06, .0, .18, .012, x=.115, bev=.004), PLATE)
        P = dict(Sight=(0, .25, .345), Grip=(0, .16, -.30), Support=(0, -.90, -.06), MagWell=(0, -.48, -.06), Eject=(-.11, -.24, .18),
                 MountOptic=(0, -.15, .305), MountBarrel=(0, -1.20, ZB), MountGrip=(0, -.90, -.07), Engrave=(.121, -.20, .09), HolsterHip=(0, -.30, .05))
        PIV = dict(Mover=(.075, -.95, .25), Mag=(0, -.48, -.06))
    elif g == "ranger":  # slim long-tube rifle (ref 7 language): angular split panels, triangle cutouts, flip sights
        add("Receiver", prof([(-.98, -.08), (.46, -.08), (.46, .22), (.40, .28), (-.62, .28), (-.80, .20), (-.98, .20)], .25, bev=.018), BLK)
        for pts in ([(-.74, -.03), (-.22, -.03), (.02, .21), (-.62, .21)], [(-.12, -.03), (.40, -.03), (.40, .21), (.12, .21)]):
            add("Receiver", prof(pts, .274, bev=.008), CHR)                              # split side panels (both sides)
        add("Receiver", rail(-.74, .34, .28, w=.11, n=12), CHR)
        add("Receiver", cyl(-1.70, -.98, .045, ZB, seg=10), BLK)                        # barrel inside handguard
        h = prof([(-1.72, -.02), (-.98, -.06), (-.98, .20), (-1.66, .20), (-1.72, .14)], .21, bev=.016)
        add("Receiver", cut(h, [through([(-1.56, .03), (-1.14, .03), (-1.14, .15)]), through([(-1.60, .06), (-1.60, .15), (-1.22, .15)])]), CHR)
        for y0, y1 in ((-.74, -.62), (.16, .28)):
            s = prof([(y0, .30), (y1, .30), (y1 - .015, .42), (y0 + .015, .42)], .11, bev=.008)
            add("Receiver", cut(s, [lathe([(0, y0 - .2), (.026, y0 - .2), (.026, y1 + .2), (0, y1 + .2)], 10, 0, .375)]), BLK)
        add("Receiver", prof([(-.82, -.08), (-.40, -.08), (-.43, -.19), (-.80, -.19)], .20, bev=.01), BLK)
        trigger_group(0., -.08, .10)
        add("Receiver", prof([(-.02, -.08), (.22, -.08), (.24, -.16), (.36, -.60), (.34, -.64), (.16, -.64), (.13, -.59), (.10, -.40),
                              (.07, -.35), (.05, -.24), (0., -.17)], .17, bev=.015), CHR)
        add("Receiver", prof([(.08, -.22), (.22, -.22), (.32, -.56), (.17, -.56)], .186, bev=.008), BLK)
        st = prof([(.46, .24), (1.25, .20), (1.30, -.30), (1.08, -.28), (.80, -.08), (.46, -.08)], .19, bev=.018)
        add("Receiver", cut(st, [through([(.66, .15), (1.14, .13), (1.14, -.14)])]), CHR)
        add("Receiver", prof([(1.24, .22), (1.32, .21), (1.36, -.33), (1.27, -.33)], .21, bev=.016), BLK)   # butt pad
        add("Receiver", muzzle(YM, ZB, .10, -1.62), FOAM)
        m = prof([(-.78, -.08), (-.44, -.08), (-.48, -.46), (-.62, -.80), (-.88, -.80), (-.80, -.46)], .16, bev=.014)
        add("Mag", cut(m, [c for i in range(3) for c in recess(-.70 - i * .04, -.52 - i * .04, -.30 - i * .14, -.26 - i * .14, .08, .012)]), BLK)
        add("Mag", prof([(-.90, -.79), (-.60, -.79), (-.59, -.86), (-.91, -.86)], .19, bev=.012), BLK)
        add("Mover", box(-.36, -.26, .12, .20, .07, x=-.155, bev=.01), BLK)               # side charging handle (right)
        add("Plate", box(-.66, -.30, .02, .17, .012, x=.143, bev=.004), PLATE)
        P = dict(Sight=(0, .22, .375), Grip=(0, .16, -.32), Support=(0, -1.35, -.06), MagWell=(0, -.62, -.08), Eject=(-.125, -.10, .16),
                 MountOptic=(0, -.20, .315), MountBarrel=(0, -1.66, ZB), MountGrip=(0, -1.35, -.04), Engrave=(.149, -.48, .095), HolsterBack=(0, -.40, .10))
        PIV = dict(Mover=(-.155, -.31, .16), Mag=(0, -.62, -.08))
    elif g == "needle":  # slim marksman (ref 5): long steel barrel, scope, skeleton thumbhole stock, bolt handle
        add("Receiver", prof([(-1.18, -.06), (.50, -.06), (.50, .22), (-1.05, .24), (-1.18, .18)], .20, bev=.016), BLK)
        add("Receiver", rail(-.95, -.05, .23, w=.10, n=10), CHR)
        add("Receiver", lathe([(0, -2.38), (.05, -2.38), (.05, -2.0), (.062, -1.99), (.062, -1.93), (.05, -1.92), (.05, -1.62), (.062, -1.61),
                               (.062, -1.55), (.055, -1.54), (.055, -1.18), (0, -1.18)], 14, 0, ZB), STEEL)   # steel barrel w/ 2 collars
        add("Receiver", cyl(-1.62, -1.15, .028, .0, seg=8), CHR)                         # under tube
        add("Receiver", lathe([(0, -.82), (.095, -.82), (.10, -.80), (.10, -.70), (.065, -.62), (.065, -.24), (.08, -.18), (.085, -.06), (0, -.06)], 16, 0, .38), BLK)
        for y in (-.55, -.32): add("Receiver", box(y - .03, y + .03, .25, .34, .09, bev=.006), CHR)   # scope rings
        add("Receiver", prof([(-.66, -.06), (-.34, -.06), (-.36, -.17), (-.64, -.17)], .18, bev=.01), BLK)
        trigger_group(.06, -.06, .10)
        sk = prof([(-.02, -.08), (.48, -.06), (.48, .22), (1.30, .22), (1.40, .14), (1.42, -.46), (1.26, -.46), (1.18, -.30),
                   (.34, -.60), (.14, -.60), (.11, -.52), (.08, -.40), (.04, -.30), (.03, -.18)], .18, bev=.018)
        add("Receiver", cut(sk, [through([(.24, -.10), (.90, -.10), (1.0, -.16), (.32, -.40)])]), CHR)
        add("Receiver", prof([(.70, .22), (1.15, .22), (1.12, .30), (.76, .30)], .14, bev=.012), BLK)    # cheek riser
        add("Receiver", prof([(1.38, .18), (1.47, .16), (1.49, -.50), (1.40, -.48)], .20, bev=.016), BLK)  # butt hook
        add("Receiver", muzzle(YM, ZB, .088, -2.33), FOAM)
        add("Mag", prof([(-.62, -.06), (-.38, -.06), (-.38, -.46), (-.60, -.46)], .14, bev=.012), BLK)
        add("Mag", prof([(-.63, -.45), (-.36, -.45), (-.36, -.51), (-.64, -.51)], .17, bev=.01), BLK)
        add("Mover", lathe([(0, -.10), (.022, -.10), (.022, -.24), (0, -.24)], 8, .22, .13, axis="X"), BLK)   # bolt arm (right)
        kb = bmesh.new(); bmesh.ops.create_icosphere(kb, subdivisions=1, radius=.042)
        bmesh.ops.translate(kb, verts=kb.verts, vec=(-.27, .22, .13)); add("Mover", kb, BLK)
        add("Plate", box(-.86, -.30, .0, .17, .012, x=.105, bev=.004), PLATE)
        P = dict(Sight=(0, -.06, .38), Grip=(0, .20, -.30), Support=(0, -1.0, -.06), MagWell=(0, -.50, -.06), Eject=(-.10, -.12, .16),
                 MountOptic=(0, -.45, .265), MountBarrel=(0, -2.38, ZB), MountGrip=(0, -1.0, -.06), Engrave=(.111, -.58, .085), HolsterBack=(0, -.60, .10))
        PIV = dict(Mover=(-.10, .22, .13), Mag=(0, -.50, -.06))
    if PHASE == "color": paint_details(g)
    P = dict(Muzzle=(0., YM, ZB), **P)
    return P, PIV

def assemble(g, PIV):
    obs = {}
    for grp, items in PIECES.items():
        out = bmesh.new()
        for bm, m in items:
            for f in bm.faces: f.material_index = m
            me = bpy.data.meshes.new("t"); bm.to_mesh(me); bm.free(); out.from_mesh(me); bpy.data.meshes.remove(me)
        bmesh.ops.remove_doubles(out, verts=out.verts, dist=1e-5)
        piv = Vector(PIV.get(grp, (0, 0, 0))); bmesh.ops.translate(out, verts=out.verts, vec=-piv)   # mesh origin at joint
        me = bpy.data.meshes.new(grp); out.to_mesh(me); out.free()
        for m in MATS: me.materials.append(m)
        ob = bpy.data.objects.new(grp, me); ob.location = piv; sc.collection.objects.link(ob); obs[grp] = ob
    PIECES.clear(); return obs

def tri_count(ob):
    ob.data.calc_loop_triangles(); return len(ob.data.loop_triangles)

def rb(p): return [round(-p[0], 3), round(p[2], 3), round(p[1], 3)]   # Blender -> Roblox (after Rz flip)

# ---------------------------------------------------------------- render
def scene_setup():
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = ((.075, .082, .10, 1) if PHASE == "color" else (.62, .63, .66, 1))
    sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 48
    try: sc.cycles.use_denoising = True
    except Exception: pass
    sc.view_settings.view_transform = "Standard"
    lights = (("key", .8, (55, 0, -40)), ("fill", .3, (60, 0, 140)), ("rim", .95, (100, 0, 190))) if PHASE == "color" else (("key", 2.4, (55, 0, -40)), ("fill", 1.2, (60, 0, 140)), ("rim", 2.0, (100, 0, 190)))
    for n, e, rot in lights:
        ld = bpy.data.lights.new(n, "SUN"); ld.energy = e; ld.angle = math.radians(8); lo = bpy.data.objects.new(n, ld); sc.collection.objects.link(lo)
        lo.rotation_euler = tuple(math.radians(a) for a in rot)
    if PHASE == "color":
        for name, loc, power, width, height in (("long-softbox", (3.0, .4, 2.2), 550, 1.8, 4.5), ("side-softbox", (3.0, 2.6, -.8), 15, .65, 3.4), ("edge-softbox", (-2.2, .4, 2.6), 340, 1.0, 4.0)):
            ld = bpy.data.lights.new(name, "AREA"); ld.energy = power; ld.shape = "RECTANGLE"; ld.size = width; ld.size_y = height
            ob = bpy.data.objects.new(name, ld); sc.collection.objects.link(ob); ob.location = loc
            ob.rotation_euler = (-ob.location).to_track_quat("-Z", "Y").to_euler()
    cd = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cd); sc.collection.objects.link(cam); sc.camera = cam
    return cam, cd

def render_views(g, obs, cam, cd):
    vs = [o.matrix_world @ Vector(c) for o in obs.values() for c in o.bound_box]
    lo = Vector([min(v[i] for v in vs) for i in range(3)]); hi = Vector([max(v[i] for v in vs) for i in range(3)]); c = (lo + hi) / 2
    L = hi.y - lo.y; H = hi.z - lo.z; files = []; S = max(L, H * 1100 / 640) * 1.25
    sc.render.resolution_x, sc.render.resolution_y = 1100, 640
    def ortho(right, up, back, scale):
        cd.type = "ORTHO"; cd.ortho_scale = scale; loc = c + Vector(back) * 20
        R, U, B = Vector(right), Vector(up), Vector(back)
        cam.matrix_world = Matrix.Translation(loc) @ Matrix(((R.x, U.x, B.x, 0), (R.y, U.y, B.y, 0), (R.z, U.z, B.z, 0), (0, 0, 0, 1)))
    def persp(d, lens=50):
        cd.type = "PERSP"; cd.lens = lens; cd.clip_end = 200
        loc = c + Vector(d).normalized() * max(L, H * 1.8) * 2.3; cam.location = loc; cam.rotation_euler = (c - loc).to_track_quat("-Z", "Y").to_euler()
    views = (("left", lambda: ortho((0, 1, 0), (0, 0, 1), (1, 0, 0), S)),
             ("q-left", lambda: persp((1.0, -1.15, .55))),
             ("q-right", lambda: persp((-1.0, 1.0, .6))),
             ("top", lambda: ortho((0, 1, 0), (-1, 0, 0), (0, 0, 1), S)))
    for n, f in views:
        f(); p = os.path.abspath(os.path.join(OUT, f"{g}-{n}.png")); sc.render.filepath = p; bpy.ops.render.render(write_still=True); files.append(p)
    return files

# ---------------------------------------------------------------- main
cam, cd = scene_setup()
ALL = {}
for g in ONLY:
    pts, piv = build(g); obs = assemble(g, piv); bpy.context.view_layer.update()
    vs = [o.matrix_world @ Vector(c) for o in obs.values() for c in o.bound_box]
    tri = {k: tri_count(o) for k, o in obs.items()}
    bb = dict(L=round(max(v.y for v in vs) - min(v.y for v in vs), 3), H=round(max(v.z for v in vs) - min(v.z for v in vs), 3),
              W=round(max(v.x for v in vs) - min(v.x for v in vs), 3), tip_y=round(min(v.y for v in vs), 3))
    bad = 0
    for o in obs.values():
        b = bmesh.new(); b.from_mesh(o.data); bad += sum(1 for e in b.edges if not e.is_manifold); b.free()
    ALL[g] = dict(tris=tri, tris_total=sum(tri.values()), bbox=bb, nonmanifold_edges=bad,
                  points={k: rb(v) for k, v in pts.items()}, pivots={k: rb(v) for k, v in piv.items()},
                  muzzle_cfg=rb((0, MUZ[g][1], MUZ[g][0])))
    print(g, ALL[g]["tris_total"], tri, bb, "nonmanifold", bad)
    if PHASE in ("detail", "color"):
        render_views(g, obs, cam, cd)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(os.path.join(OUT, f"{g}_detail.blend")))
    for o in obs.values():
        d = o.data; bpy.data.objects.remove(o); bpy.data.meshes.remove(d)
json.dump(ALL, open(os.path.join(OUT, "detail_info.json"), "w"), indent=1)
json.dump({g: dict(points=v["points"], pivots=v["pivots"]) for g, v in ALL.items()}, open(os.path.join(OUT, "gun_points.json"), "w"), indent=1)
