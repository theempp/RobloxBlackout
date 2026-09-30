# razor_tex.py -- Phase 5: UV layout + PBR atlas. exec'd inside razor_build namespace (after phase4, before stats).
import numpy as np, math, bmesh, bpy, json, os
from mathutils import Vector, Matrix, kdtree, bvhtree
from scipy.ndimage import distance_transform_edt, uniform_filter
from PIL import Image, ImageDraw, ImageFont

# ---- tunables (single Config: CFG["tex"]); numbers are placeholders
TEX = CFG.setdefault("tex", dict(
    atlas=1024, pad=4, sharp=35, dens_max=110, dec_w=512, dec_h=256,
    # class -> (albedo sRGB, metalness, roughness)   0 body 1 aero 2 hoop 3 seat 4 steer 5 rim 6 tire
    cls={0: ((22, 22, 25), .70, .35), 1: ((19, 19, 22), .55, .30), 2: ((20, 20, 23), .75, .40), 3: ((14, 14, 16), .0, .85),
         4: ((16, 16, 18), .20, .65), 5: ((26, 26, 30), .80, .35), 6: ((11, 11, 12), .0, .90)},
    groove_w=.022, groove_d=.025, groove_albedo=.45, ao_rays=12, ao_dist=1.4, ao_amt=.45, ao_step=2,
    cuts_y=(-4.25, -2.55, 1.3, 3.3, 4.35), hood_line_x=.99, hood_y=(-4.3, -2.5), sill_z=.62,
    dec_col=(34, 34, 38), dec_border=(66, 66, 74)))
AT, PAD = TEX["atlas"], TEX["pad"]
G5 = {g: sum(tris(o) for o in obs) for g, obs in GRP.items() if g != "Proxy"}
print("PRE-JOIN", G5)

# ------------------------------------------------------------------ gather final part meshes (bmesh, cls/src face layers)
UVL = {}
CH_GROUPS = ("Body", "Splitter", "Diffuser", "Wing", "Canards", "Hoop", "Seat")
def cls_of(ob):
    g = next(g for g, obs in GRP.items() if ob in obs)
    return {"Body": 0 if ob.name == "tub" else 1, "Splitter": 1, "Diffuser": 1, "Wing": 1, "Canards": 1, "Hoop": 2, "Seat": 3}[g]
def gather(objs, clsf, world=True):
    bm = bmesh.new(); lc = bm.faces.layers.int.new("cls"); lt = bm.faces.layers.int.new("src")
    for k, ob in enumerate(objs):
        s = len(bm.faces); me = ob.data.copy()
        if world: me.transform(ob.matrix_world)
        bm.from_mesh(me); bpy.data.meshes.remove(me); bm.faces.ensure_lookup_table()
        for f in bm.faces[s:]: f[lc] = clsf(ob); f[lt] = k
    UVL[id(bm)] = bm.loops.layers.uv.new("UVMap")
    return bm, lc, lt
ch_objs = [o for g in CH_GROUPS for o in GRP[g]]
st_ob = GRP["Steering"][0]; wh_objs = GRP["Wheels"]; dec_objs = GRP["DecalPlates"]
BM = {}
BM["chassis"] = gather(ch_objs, cls_of)
BM["steer"] = gather([st_ob], lambda o: 4, world=False)
BM["wheel"] = gather([wh_objs[0]], lambda o: 5, world=False)
BM["decals"] = gather(dec_objs, lambda o: 1)
BM["head"] = gather(GRP["Headlight"], lambda o: 1); BM["tail"] = gather(GRP["Taillight"], lambda o: 1); BM["glow"] = gather(GRP["Underglow"], lambda o: 1)

# ------------------------------------------------------------------ islands
ISL = []
def add_island(key, items, atlas=0, order=0.):
    a = [p[0] for _, p in items]; b = [p[1] for _, p in items]
    ISL.append(dict(key=key, items=items, w=max(a) - min(a), h=max(b) - min(b), a0=min(a), b1=max(b), atlas=atlas))
def face_axis(f):
    n = f.normal; a = max(range(3), key=lambda i: abs(n[i])); return a * 2 + (0 if n[a] > 0 else 1)
# outward-viewed planar maps: 0 X+ 1 X- 2 Y+ 3 Y- 4 Z+ 5 Z-
PROJ = [lambda p: (p.y, p.z), lambda p: (-p.y, p.z), lambda p: (-p.x, p.z), lambda p: (p.x, p.z), lambda p: (-p.x, -p.y), lambda p: (p.x, -p.y)]
def cluster(faces, key):
    fs = set(faces); seen = set(); out = []
    for f in faces:
        if f in seen: continue
        st = [f]; seen.add(f); comp = []
        while st:
            c = st.pop(); comp.append(c)
            for e in c.edges:
                for g in e.link_faces:
                    if g in fs and g not in seen and key(g) == key(c): seen.add(g); st.append(g)
        out.append(comp)
    return out
def planar_islands(tag, faces, key=face_axis):
    for i, comp in enumerate(cluster(faces, key)):
        code = face_axis(comp[0]); add_island(f"{tag}{i}", [(l, PROJ[code](l.vert.co)) for f in comp for l in f.loops])

def uv_chassis():
    bm, lc, lt = BM["chassis"]
    kd = kdtree.KDTree(4 * len(TUBQ)); cu = []; cv = []
    for q in TUBQ:
        for p, u, v in q[1]: kd.insert(p, len(cu)); cu.append(u); cv.append(v)
    kd.balance(); main = []; spec = []; rest = []
    for f in bm.faces:
        if f[lt] != 0: rest.append(f); continue
        ok = abs(f.normal.y) <= .72; its = []
        if ok:
            for l in f.loops:
                _, i, d = kd.find(l.vert.co)
                if d > 2e-4: ok = False; break
                its.append((l, (cu[i], cv[i])))
        if ok: main += its
        else: spec.append(f)
    add_island("tub_main", main)
    planar_islands("tub_sp", spec)
    for k in sorted({f[lt] for f in rest}):
        fs = [f for f in rest if f[lt] == k]
        for i, comp in enumerate(cluster(fs, face_axis)):
            code = face_axis(comp[0]); add_island(f"c{k}_{i}", [(l, PROJ[code](l.vert.co)) for f in comp for l in f.loops])
def uv_steer():
    bm, lc, lt = BM["steer"]; planar_islands("steer", list(bm.faces))
def uv_wheel():
    bm, lc, lt = BM["wheel"]; R = .92; outer = []; inner = []; tread = []; other = []
    for f in bm.faces:
        n = f.normal; c = f.calc_center_median(); r = math.hypot(c.y, c.z); f[lc] = 5 if r < .52 else 6
        if abs(n.x) < .6 and r > .78: tread.append(f)
        elif n.x >= .6: outer.append(f)
        elif n.x <= -.6: inner.append(f)
        else: other.append(f)
    its = []
    for f in tread:
        c = f.calc_center_median(); tc = math.atan2(c.z, c.y)
        for l in f.loops:
            t = math.atan2(l.vert.co.z, l.vert.co.y); t = tc + (t - tc + math.pi) % (2 * math.pi) - math.pi; its.append((l, (t * R, l.vert.co.x)))
    add_island("w_tread", its)
    add_island("w_outer", [(l, (l.vert.co.y, l.vert.co.z)) for f in outer for l in f.loops])
    add_island("w_inner", [(l, (-l.vert.co.y, l.vert.co.z)) for f in inner for l in f.loops])
    planar_islands("w_o", other)
def uv_decals():
    bm, lc, lt = BM["decals"]; solid = []
    for k, ob in enumerate(dec_objs):
        fs = [f for f in bm.faces if f[lt] == k]; top = max(fs, key=lambda f: f.calc_area()); nm = ob.name
        pr = (lambda p: (-p.x, -p.y)) if nm == "decal_hood" else (lambda p: (-p.x, p.z)) if nm == "decal_rear" else (lambda p: (p.y, p.z)) if nm == "decal_num1" else (lambda p: (-p.y, p.z))
        add_island(f"dec_{nm}", [(l, pr(l.vert.co)) for l in top.loops], atlas=1)
        solid += [l for f in fs if f is not top for l in f.loops]
    return solid
def uv_lights():
    for k in ("head", "tail", "glow"):
        bm = BM[k][0]
        for f in bm.faces:
            for l in f.loops: l[UVL[id(bm)]].uv = (.5, .5)
uv_chassis(); uv_steer(); uv_wheel(); dec_solid = uv_decals(); uv_lights()

# ------------------------------------------------------------------ pack (shelf, uniform density)
def shelf(sizes, W, H, pad):
    order = sorted(range(len(sizes)), key=lambda i: -sizes[i][1]); x = y = rowh = 0; pos = {}
    for i in order:
        w, h = sizes[i][0] + 2 * pad, sizes[i][1] + 2 * pad
        if w > W: return None
        if x + w > W: x = 0; y += rowh; rowh = 0
        pos[i] = (x, y); x += w; rowh = max(rowh, h)
    return pos if y + rowh <= H else None
def pack(isls, W, H, pad, smax):
    lo, hi, best = 10., smax, None
    for _ in range(18):
        s = (lo + hi) / 2; pos = shelf([(math.ceil(i["w"] * s), math.ceil(i["h"] * s)) for i in isls], W, H, pad)
        if pos: lo, best = s, (s, pos)
        else: hi = s
    return best
def assign(isls, W, H, pad, s, pos):
    for i, isl in enumerate(isls):
        px, py = pos[i]; uv = isl["uvl"]
        for l, (a, b) in isl["items"]:
            X = px + pad + (a - isl["a0"]) * s; Y = py + pad + (isl["b1"] - b) * s; l[uv].uv = (X / W, 1 - Y / H)
        isl["rect"] = (px + pad, py + pad, math.ceil(isl["w"] * s), math.ceil(isl["h"] * s))
face_owner = {}
for k, (b_, _, _) in BM.items():
    for f in b_.faces: face_owner[f] = k
for i in ISL: i["uvl"] = UVL[id(BM[face_owner[i["items"][0][0].face]][0])]
main_isl = [i for i in ISL if i["atlas"] == 0]; dec_isl = [i for i in ISL if i["atlas"] == 1]
sM, posM = pack(main_isl, AT, AT, PAD, TEX["dens_max"]); assign(main_isl, AT, AT, PAD, sM, posM)
DW, DH = TEX["dec_w"], TEX["dec_h"]
sD, posD = pack(dec_isl, DW, DH - 8, PAD, 400.); assign(dec_isl, DW, DH, PAD, sD, posD)
for l in dec_solid: l[UVL[id(BM["decals"][0])]].uv = (4 / DW, 4 / DH)      # solid block at bottom-left (v-up)
used = sum((i["rect"][2] + 2 * PAD) * (i["rect"][3] + 2 * PAD) for i in main_isl) / AT ** 2
print(f"ATLAS density {sM:.1f} px/stud, islands {len(main_isl)}, packed area {used*100:.0f}%; decals {sD:.0f} px/stud")

# ------------------------------------------------------------------ split hard edges, triangulate, normals
def finish(bm, lc, lt):
    sh = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > math.radians(TEX["sharp"])]
    bmesh.ops.split_edges(bm, edges=sh)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.normal_update(); bm.verts.index_update(); bm.faces.ensure_lookup_table()
for k, (b, lc, lt) in BM.items(): finish(b, lc, lt)

# ------------------------------------------------------------------ raster + bake
def tri_arrays(bm, lc):
    uvl = UVL[id(bm)]; P = []; UV = []; NN = []; CL = []
    for f in bm.faces:
        ls = f.loops; P.append([l.vert.co[:] for l in ls]); UV.append([l[uvl].uv[:] for l in ls]); NN.append([l.vert.normal[:] for l in ls]); CL.append(f[lc])
    return np.array(P, float), np.array(UV, float), np.array(NN, float), np.array(CL)
def raster(UVpx, W, H, order):
    owner = -np.ones((H, W), np.int32); bary = np.zeros((H, W, 3), np.float32)
    for t in order:
        p = UVpx[t]; d = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
        if abs(d) < 1e-9: continue
        x0 = int(max(math.floor(p[:, 0].min()), 0)); x1 = int(min(math.ceil(p[:, 0].max()), W - 1)); y0 = int(max(math.floor(p[:, 1].min()), 0)); y1 = int(min(math.ceil(p[:, 1].max()), H - 1))
        X, Y = np.meshgrid(np.arange(x0, x1 + 1) + .5, np.arange(y0, y1 + 1) + .5)
        l0 = ((p[1, 1] - p[2, 1]) * (X - p[2, 0]) + (p[2, 0] - p[1, 0]) * (Y - p[2, 1])) / d
        l1 = ((p[2, 1] - p[0, 1]) * (X - p[2, 0]) + (p[0, 0] - p[2, 0]) * (Y - p[2, 1])) / d
        l2 = 1 - l0 - l1; m = (l0 >= -1e-4) & (l1 >= -1e-4) & (l2 >= -1e-4)
        if not m.any(): continue
        ow = owner[y0:y1 + 1, x0:x1 + 1]; bw = bary[y0:y1 + 1, x0:x1 + 1]; ow[m] = t
        bw[m] = np.stack([l0[m], l1[m], l2[m]], -1)
    return owner, bary
def nrm(v): return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-9)

# ---- height fields (studs, +out): panel lines / dimples in object-local (chassis = world) coords
def SSn(t): t = np.clip(t, 0, 1); return t * t * (3 - 2 * t)
def gro(d, w=None, dep=None): w = w or TEX["groove_w"]; dep = dep or TEX["groove_d"]; return -dep * np.exp(-(d / w) ** 2)
def H_body(Q):
    x, y, z = Q[:, 0], Q[:, 1], Q[:, 2]; h = np.zeros(len(Q)); hy0, hy1 = TEX["hood_y"]
    for y0 in TEX["cuts_y"]: h += gro(y - y0) * SSn((z - .8) / .1)
    my = SSn((y - hy0) / .1) * SSn((hy1 - y) / .1); mz = SSn((z - 1.1) / .1)
    h += gro(abs(x) - TEX["hood_line_x"]) * my * mz
    for y0 in np.linspace(hy0 + .25, hy1 - .25, 4): h += gro(np.hypot(abs(x) - 1.12, y - y0), .035, .02) * mz
    h += gro(z - TEX["sill_z"]) * SSn((abs(x) - 1.7) / .2) * SSn((y + 2.0) / .2) * SSn((2.4 - y) / .2)
    return h
def H_wheel(Q):
    x, y, z = Q[:, 0], Q[:, 1], Q[:, 2]; r = np.hypot(y, z); h = np.zeros(len(Q)); ang = np.arctan2(z, y)
    for x0 in (-.16, 0., .16): h += gro(x - x0, .02, .02) * SSn((r - .85) / .04)
    h += gro(r - .62, .02, .018) * SSn((x - .3) / .05)
    for k in range(5):
        a = math.radians(90 + 36 + k * 72); h += gro(np.hypot(y - .1 * math.cos(a), z - .1 * math.sin(a)), .03, .02) * SSn((x - .33) / .02)
    return h
def H_seat(Q):
    x, z = Q[:, 0], Q[:, 2]; h = np.zeros(len(Q))
    for zk in (1.65, 1.95, 2.25): h += gro(z - zk, .02, .018) * SSn((.55 - abs(x)) / .05)
    return h
HF = {"chassis": {0: H_body, 3: H_seat}, "wheel": {5: H_wheel, 6: H_wheel}, "steer": {}}
def Hfun(Q, cl, kind):
    h = np.zeros(len(Q))
    for c, fn in HF[kind].items():
        m = cl == c
        if m.any(): h[m] = fn(Q[m])
    return h

def bvh_from(lists):
    V = []; F = []
    for verts, faces in lists: F += [[i + len(V) for i in f] for f in faces]; V += [tuple(v) for v in verts]
    return bvhtree.BVHTree.FromPolygons(V, F)
def bm_world(bm, M=None):
    v = [(M @ x.co if M else x.co)[:] for x in bm.verts]; return v, [[x.index for x in f.verts] for f in bm.faces]
wmats = [o.matrix_world.copy() for o in wh_objs]; stM = st_ob.matrix_world.copy()
lst = [bm_world(BM["chassis"][0]), bm_world(BM["decals"][0]), bm_world(BM["steer"][0], stM)] + [bm_world(BM["wheel"][0], M_) for M_ in wmats]
BVH_ALL = bvh_from(lst); BVH_WHEEL = bvh_from([bm_world(BM["wheel"][0])])
DIRS = []
for k in range(TEX["ao_rays"]):
    u1 = (k + .5) / TEX["ao_rays"]; u2 = (k * .6180339887) % 1; r = math.sqrt(u1); ph = 2 * math.pi * u2; DIRS.append((r * math.cos(ph), r * math.sin(ph), math.sqrt(1 - u1)))
DIRS = np.array(DIRS)
def ao_at(P, N, T, B, bvh, M=None):
    if M is not None: R3 = np.array(M.to_3x3()); P = P @ R3.T + np.array(M.translation); N = N @ R3.T; T = T @ R3.T; B = B @ R3.T
    D = DIRS[None, :, 0:1] * T[:, None] + DIRS[None, :, 1:2] * B[:, None] + DIRS[None, :, 2:3] * N[:, None]; O = P + N * .02
    maxd = TEX["ao_dist"]; occ = np.zeros(len(P)); K = len(DIRS)
    for i in range(len(P)):
        o = Vector(O[i]); s = 0.
        for k in range(K):
            h = bvh.ray_cast(o, Vector(D[i, k]), maxd)
            if h[0] is not None: s += 1 - h[3] / maxd
        occ[i] = s / K
    return 1 - occ

A_COL = np.zeros((AT, AT, 3), np.float32); A_COLN = np.zeros((AT, AT, 3), np.float32); A_NRM = np.zeros((AT, AT, 3), np.float32)
A_MET = np.zeros((AT, AT), np.float32); A_ROU = np.zeros((AT, AT), np.float32); A_AO = np.ones((AT, AT), np.float32); COV = np.zeros((AT, AT), bool)
OVERLAP = {}
def bake(kind, M=None, bvh=None):
    bm, lc, lt = BM[kind]; P, UV, NN, CL = tri_arrays(bm, lc); T_ = len(P)
    UVpx = UV.copy(); UVpx[..., 0] *= AT; UVpx[..., 1] = (1 - UVpx[..., 1]) * AT
    order = np.argsort(P[:, :, 0].mean(1)) if kind == "wheel" else np.arange(T_)
    owner, bary = raster(UVpx, AT, AT, order); ys, xs = np.nonzero(owner >= 0); t = owner[ys, xs]; b = bary[ys, xs].astype(float)
    # per-triangle tangent frame from UV
    e1 = P[:, 1] - P[:, 0]; e2 = P[:, 2] - P[:, 0]; du1 = UV[:, 1, 0] - UV[:, 0, 0]; dv1 = UV[:, 1, 1] - UV[:, 0, 1]; du2 = UV[:, 2, 0] - UV[:, 0, 0]; dv2 = UV[:, 2, 1] - UV[:, 0, 1]
    r = du1 * dv2 - du2 * dv1; r = np.where(np.abs(r) < 1e-14, 1e-14, r)[:, None]
    Tt = nrm((e1 * dv2[:, None] - e2 * dv1[:, None]) / r); Bt = nrm((e2 * du1[:, None] - e1 * du2[:, None]) / r)
    Pp = np.einsum("sk,skj->sj", b, P[t]); N = nrm(np.einsum("sk,skj->sj", b, NN[t])); cl = CL[t]
    T = nrm(Tt[t] - (Tt[t] * N).sum(1, keepdims=True) * N); B = Bt[t] - (Bt[t] * N).sum(1, keepdims=True) * N - (Bt[t] * T).sum(1, keepdims=True) * T; B = nrm(B)
    # normal from height field: n' = N - grad_t(H)
    eps = .004; g = np.zeros_like(Pp)
    if HF[kind]:
        for a in range(3):
            d = np.zeros(3); d[a] = eps; g[:, a] = (Hfun(Pp + d, cl, kind) - Hfun(Pp - d, cl, kind)) / (2 * eps)
        g -= (g * N).sum(1, keepdims=True) * N
    n2 = nrm(N - g); ts = np.stack([(n2 * T).sum(1), (n2 * B).sum(1), (n2 * N).sum(1)], 1); h0 = Hfun(Pp, cl, kind) if HF[kind] else np.zeros(len(Pp))
    gm = np.clip(-h0 / TEX["groove_d"], 0, 1)
    # AO on a regular subset, normalized-convolution fill
    st_ = TEX["ao_step"]; sub = ((xs % st_) == 0) & ((ys % st_) == 0); idx = np.nonzero(sub)[0]
    ao = ao_at(Pp[idx], N[idx], T[idx], B[idx], bvh, M)
    grid = np.zeros((AT, AT)); wgt = np.zeros((AT, AT)); grid[ys[idx], xs[idx]] = ao; wgt[ys[idx], xs[idx]] = 1
    F1 = uniform_filter(grid, 5) / np.maximum(uniform_filter(wgt, 5), 1e-6); F2 = uniform_filter(grid, 15) / np.maximum(uniform_filter(wgt, 15), 1e-6)
    aof = np.where(uniform_filter(wgt, 5) > 1e-3, F1, np.where(uniform_filter(wgt, 15) > 1e-4, F2, 1.))[ys, xs]
    # maps
    alb = np.array([TEX["cls"][c][0] for c in cl], float); met = np.array([TEX["cls"][c][1] for c in cl]); rou = np.array([TEX["cls"][c][2] for c in cl])
    nz = np.sin(Pp[:, 0] * 7.1 + Pp[:, 1] * 3.3) * np.sin(Pp[:, 2] * 5.7 + Pp[:, 1] * 1.7)
    alb = alb * (1 + .06 * nz[:, None]) * (1 - TEX["groove_albedo"] * gm)[:, None]; rou = np.clip(rou + .03 * nz + .25 * gm, 0, 1); met = np.clip(met * (1 - .5 * gm), 0, 1)
    aomul = (1 - TEX["ao_amt"]) + TEX["ao_amt"] * np.clip(aof, 0, 1)
    A_COLN[ys, xs] = alb; A_COL[ys, xs] = alb * aomul[:, None]; A_NRM[ys, xs] = (ts * .5 + .5) * 255; A_MET[ys, xs] = met; A_ROU[ys, xs] = rou; A_AO[ys, xs] = aof; COV[ys, xs] = True
    print(f"bake {kind}: tris {T_} texels {len(ys)} ao-samples {len(idx)}")
bake("chassis", None, BVH_ALL); bake("steer", stM, BVH_ALL); bake("wheel", None, BVH_WHEEL)

# overlap check between different islands (raster owner of each island separately would be costly; use island-id painting)
def overlap_check():
    cnt = np.zeros((AT, AT), np.int16); bad = 0
    for isl in main_isl:
        x0, y0, w, h = isl["rect"]; m = np.zeros((AT, AT), bool)
        # approx: island rectangle overlap (rects are disjoint by packer; report only if packer broken)
        cnt[y0:y0 + h, x0:x0 + w] += 1
    return int((cnt > 1).sum())
OV = overlap_check()

# pad (edge dilation) + write
d, ix = distance_transform_edt(~COV, return_indices=True); fm = (~COV) & (d <= PAD + 1)
def fill(a, neutral):
    a[fm] = a[ix[0][fm], ix[1][fm]]; far = (~COV) & ~fm; a[far] = neutral; return a
A_COL = fill(A_COL, (22, 22, 25)); A_COLN = fill(A_COLN, (22, 22, 25)); A_NRM = fill(A_NRM, (128, 128, 255)); A_MET = fill(A_MET, .7); A_ROU = fill(A_ROU, .35); A_AO = fill(A_AO, 1.)
def save(a, name, mode):
    im = Image.fromarray(np.clip(a + .5, 0, 255).astype(np.uint8), mode); im.save(os.path.join(OUT, name)); return im
save(A_COL, "razor_color.png", "RGB"); save(A_COLN, "razor_color_noao.png", "RGB"); save(A_NRM, "razor_normal.png", "RGB")
save(A_MET * 255, "razor_metalness.png", "L"); save(A_ROU * 255, "razor_roughness.png", "L"); save(A_AO * 255, "razor_ao.png", "L")

# decals texture (blank placeholder + labelled orientation test)
def decal_tex(labelled):
    im = Image.new("RGB", (DW, DH), (16, 16, 18)); dr = ImageDraw.Draw(im)
    try: fnt = ImageFont.load_default(size=26)
    except Exception: fnt = None
    for isl in dec_isl:
        x0, y0, w, h = isl["rect"]; dr.rectangle([x0, y0, x0 + w - 1, y0 + h - 1], fill=TEX["dec_col"]); dr.rectangle([x0 + 4, y0 + 4, x0 + w - 5, y0 + h - 5], outline=TEX["dec_border"], width=2)
        if labelled:
            nm = isl["key"][4:]; lab = {"decal_hood": "HOOD  ^ NOSE", "decal_rear": "REAR  ^ UP", "decal_num1": "#7 ^UP", "decal_num-1": "#7 ^UP"}[nm]
            dr.text((x0 + w // 2, y0 + h // 2), lab, fill=(230, 230, 60), font=fnt, anchor="mm"); dr.line([x0 + w // 2, y0 + 8, x0 + w // 2, y0 + 30], fill=(255, 60, 60), width=3)
    return im
decal_tex(False).save(os.path.join(OUT, "razor_decals_color.png")); decal_tex(True).save(os.path.join(OUT, "razor_decals_orient.png"))

# ------------------------------------------------------------------ final objects
def make_obj(name, kind, mesh=None, matrix=None):
    bm, lc, lt = BM[kind]; bm.faces.layers.int.remove(lc); bm.faces.layers.int.remove(lt)
    me = mesh or bpy.data.meshes.new(name); bm.to_mesh(me); me.polygons.foreach_set("use_smooth", [True] * len(me.polygons)); me.update()
    ob = bpy.data.objects.new(name, me); col.objects.link(ob)
    if matrix is not None: ob.matrix_world = matrix
    return ob
def pbr_mat(name, files, dec=False):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    def img(p, nc):
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = bpy.data.images.load(os.path.join(OUT, p), check_existing=True); n.image.colorspace_settings.name = "Non-Color" if nc else "sRGB"; n.interpolation = "Linear"; return n
    nt.links.new(img(files[0], 0).outputs["Color"], b.inputs["Base Color"])
    if dec: b.inputs["Roughness"].default_value = .8; return m
    nt.links.new(img(files[2], 1).outputs["Color"], b.inputs["Metallic"]); nt.links.new(img(files[3], 1).outputs["Color"], b.inputs["Roughness"])
    nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(img(files[1], 1).outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], b.inputs["Normal"]); return m
MAT_ATLAS = pbr_mat("razor_atlas", ("razor_color.png", "razor_normal.png", "razor_metalness.png", "razor_roughness.png"))
MAT_DEC = pbr_mat("razor_decals", ("razor_decals_orient.png",), dec=True)
old = [o for obs in GRP.values() for o in obs]
chassis = make_obj("Chassis", "chassis"); steer = make_obj("Steer", "steer", matrix=stM)
wmesh = wh_objs[0].data; make_wheel_mesh = BM["wheel"][0]; bm_, lc_, lt_ = BM["wheel"]; bm_.faces.layers.int.remove(lc_); bm_.faces.layers.int.remove(lt_)
bm_.to_mesh(wmesh); wmesh.polygons.foreach_set("use_smooth", [True] * len(wmesh.polygons)); wmesh.update(); del BM["wheel"]
decp = make_obj("DecalPlates", "decals"); head = make_obj("HeadlightStrips", "head"); tail = make_obj("TailStrips", "tail"); glow = make_obj("Underglow", "glow")
for o, m in ((chassis, MAT_ATLAS), (steer, MAT_ATLAS), (decp, MAT_DEC), (head, M["wht"]), (tail, M["red"]), (glow, M["glow"])): o.data.materials.clear(); o.data.materials.append(m)
wmesh.materials.clear(); wmesh.materials.append(MAT_ATLAS)
for o in old:
    if o.name not in {w.name for w in wh_objs}: bpy.data.objects.remove(o)
GRP.clear(); GRP.update({"Chassis": [chassis], "Steer": [steer], "Wheels": list(wh_objs), "DecalPlates": [decp], "HeadlightStrips": [head], "TailStrips": [tail], "Underglow": [glow]})
for o in GRP["Chassis"] + GRP["Steer"] + GRP["DecalPlates"] + GRP["HeadlightStrips"] + GRP["TailStrips"] + GRP["Underglow"]: o.data.update()

# ------------------------------------------------------------------ verification sheets
def uv_layout():
    im = Image.new("RGB", (AT, AT), (12, 12, 14)); dr = ImageDraw.Draw(im); cols = {"Chassis": (90, 200, 255), "Steer": (255, 200, 60), "Wheels": (120, 255, 120)}
    for g in ("Chassis", "Steer", "Wheels"):
        me = GRP[g][0].data; uvl = me.uv_layers["UVMap"].data
        for p in me.polygons:
            pts = [(uvl[l].uv[0] * AT, (1 - uvl[l].uv[1]) * AT) for l in p.loop_indices]; dr.polygon(pts, outline=cols[g])
    im.save(os.path.join(OUT, "razor_uv_layout.png")); return im
uvim = uv_layout()
def atlas_sheet():
    tiles = [Image.open(os.path.join(OUT, "razor_color.png")).point(lambda v: min(255, v * 6)), Image.open(os.path.join(OUT, "razor_normal.png")), Image.open(os.path.join(OUT, "razor_metalness.png")).convert("RGB"),
             Image.open(os.path.join(OUT, "razor_roughness.png")).convert("RGB"), Image.open(os.path.join(OUT, "razor_ao.png")).convert("RGB"), uvim]
    sh = Image.new("RGB", (1536, 1024)); dr = ImageDraw.Draw(sh)
    for i, t in enumerate(tiles): sh.paste(t.resize((512, 512)), ((i % 3) * 512, (i // 3) * 512))
    for i, n in enumerate(("color x6 bright", "normal", "metalness", "roughness", "AO", "UV layout")): dr.text(((i % 3) * 512 + 6, (i // 3) * 512 + 4), n, fill=(255, 255, 0))
    sh.save(os.path.join(OUT, "phase5-atlas.png"))
atlas_sheet()
info = dict(tris=sum(tris(o) for g in GRP for o in GRP[g] if g != "Wheels") + tris(GRP["Wheels"][0]) * 4, density_px_per_stud=round(sM, 1), islands=len(main_isl), packed_pct=round(used * 100, 1), decal_density=round(sD, 1),
            verts={g: len(obs[0].data.vertices) for g, obs in GRP.items()}, pregroup=G5)
json.dump(info, open(os.path.join(OUT, "phase5_info.json"), "w")); print("PHASE5", info)
