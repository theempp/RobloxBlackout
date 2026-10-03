"""Gate step 5: Meshy T2 gun GLBs -> named, phone-budget pieces. Sources are read-only.
Run: blender -b -P tools/guns_blender.py   (optional: -- P1 S2 to do a subset)
Out per gun: assets/guns/<class>/<ID>.blend, <class>/export/<ID>.{fbx,glb}; <class>/export/manifest.json.
Blender units = studs. Muzzle +Y, up +Z; FBX/GLB defaults map Blender (x,y,z) -> Roblox (x,z,-y)."""
import bpy, bmesh, json, sys
from pathlib import Path
from mathutils import Vector, Matrix

R = Path(__file__).resolve().parents[1]
TRI_BUDGET = 1500  # Config.TriBudget.WorldGun (also under FirstPersonGun 5000)
# class: (overall length studs, grip-origin fraction from rear) — lengths from v2 Dart-9/Ranger/Needlepoint; shotgun placeholder
CLASS = {'pistol': (1.43, .27), 'ar': (2.97, .34), 'sniper': (3.10, .21), 'shotgun': (2.6, .30)}
# Piece boxes in SOURCE coords (Meshy: length on X normalised to 1, muzzle at -X, up +Z).
# (name, xlo, xhi, zlo, zhi); first match by face centroid wins; everything else is Body.
PIECES = {
 'P1': [('Muzzle', -.51, -.065, .03, .14), ('Optic', .25, .41, .095, .2), ('Slide', -.065, .48, .06, .2),
        ('Mag', .27, .52, -.25, -.125), ('Light', -.05, .14, -.075, .005)],
 'P2': [('Muzzle', -.51, -.335, .1, .22), ('Optic', .1, .3, .2, .35), ('Slide', -.335, .47, .12, .26),
        ('Mag', .1, .52, -.36, -.2)],
 'A1': [('Muzzle', -.51, -.41, -.02, .08), ('Optic', -.05, .28, .085, .2), ('Stock', .285, .51, -.15, .1),
        ('Mag', -.03, .1, -.2, -.02), ('Foregrip', -.27, -.16, -.14, -.005)],
 'A2': [('Muzzle', -.51, -.44, 0, .1), ('Optic', -.16, -.03, .115, .2), ('Stock', .295, .51, -.12, .1),
        ('Mag', -.09, .05, -.2, -.02), ('Foregrip', -.32, -.17, -.1, .012)],
 'S1': [('Muzzle', -.51, -.40, -.02, .05), ('Optic', -.18, .26, .045, .2), ('Bipod', -.31, -.09, -.075, -.025),
        ('Barrel', -.40, -.12, -.02, .04), ('Stock', .27, .51, -.14, .05), ('Mag', .02, .13, -.12, -.025)],
 'S2': [('Muzzle', -.51, -.22, -.02, .06), ('Optic', -.08, .22, .055, .2), ('Stock', .22, .51, -.13, .05),
        ('Mag', .04, .15, -.1, -.025)],
 'G1': [('Barrel', -.51, 0, .07, .15), ('Pump', -.36, -.03, -.03, .07), ('Stock', .33, .51, -.17, .04)],
 'G2': [('Barrel', -.51, -.02, .028, .085), ('Pump', -.24, -.05, -.03, .045), ('Stock', .27, .51, -.13, .09)],
}
# No orange anywhere (owner override): only dark greys/black.
MATS = {'Gunmetal': (.05, .05, .055, 1), 'Black': (.015, .015, .015, 1)}
DARK = {'Body': 'Gunmetal', 'Slide': 'Gunmetal'}  # all other pieces Black
GUNS = {'P1': 'pistol', 'P2': 'pistol', 'A1': 'ar', 'A2': 'ar', 'S1': 'sniper', 'S2': 'sniper', 'G1': 'shotgun', 'G2': 'shotgun'}

def tris(me):
    me.calc_loop_triangles(); return len(me.loop_triangles)

def build(gid):
    cls = GUNS[gid]; src = R / f'assets/guns/{cls}/source/{gid}-meshy-t2.glb'
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(src))
    ob = next(o for o in bpy.data.objects if o.type == 'MESH')
    raw = tris(ob.data)
    me = ob.data
    me.transform(ob.matrix_world)  # bake glTF axis fix; then work in source coords
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    boxes = PIECES[gid]
    # Bisect only faces overlapping each box so fused parts (mag in grip, slide on frame) separate cleanly.
    for _, x0, x1, z0, z1 in boxes:
        for co, no in (((x0, 0, 0), (1, 0, 0)), ((x1, 0, 0), (1, 0, 0)), ((0, 0, z0), (0, 0, 1)), ((0, 0, z1), (0, 0, 1))):
            fs = [f for f in bm.faces if any(x0 - 1e-4 <= v.co.x <= x1 + 1e-4 for v in f.verts)
                  and any(z0 - 1e-4 <= v.co.z <= z1 + 1e-4 for v in f.verts)]
            if not fs: continue
            g = list({e for f in fs for e in f.edges}) + list({v for f in fs for v in f.verts}) + fs
            bmesh.ops.bisect_plane(bm, geom=g, plane_co=co, plane_no=no, dist=1e-5)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    groups = {}
    for f in bm.faces:
        c = f.calc_center_median(); name = 'Body'
        for n, x0, x1, z0, z1 in boxes:
            if x0 <= c.x <= x1 and z0 <= c.z <= z1: name = n; break
        groups.setdefault(name, []).append(f.index)
    bm.faces.ensure_lookup_table()
    L, frac = CLASS[cls]
    # Source -> design space: rotate -X(muzzle) to +Y, scale to class length, origin at grip (rear fraction), bore-ish mid height.
    xs = [v.co.x for v in bm.verts]; zs = [v.co.z for v in bm.verts]
    s = L / (max(xs) - min(xs))
    ox = max(xs) - frac * (max(xs) - min(xs)); oz = (max(zs) + min(zs)) / 2
    M = Matrix.Scale(s, 4) @ Matrix.Rotation(-1.5707963, 4, 'Z') @ Matrix.Translation((-ox, 0, -oz))
    bpy.data.objects.remove(ob)
    for n, c in MATS.items():
        m = bpy.data.materials.new(n); m.diffuse_color = c; m.use_nodes = True
        m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = c
        m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .55
    root = bpy.data.objects.new(gid, None); bpy.context.scene.collection.objects.link(root)
    pieces = []
    for name, idx in sorted(groups.items()):
        pb = bm.copy(); pb.faces.ensure_lookup_table(); keep = set(idx)
        bmesh.ops.delete(pb, geom=[f for f in pb.faces if f.index not in keep], context='FACES')
        bmesh.ops.holes_fill(pb, edges=pb.edges, sides=0)  # cap bisect cuts
        bmesh.ops.triangulate(pb, faces=[f for f in pb.faces if len(f.verts) > 4])
        pb.transform(M)
        pme = bpy.data.meshes.new(f'{gid}_{name}'); pb.to_mesh(pme); pb.free()
        po = bpy.data.objects.new(f'{gid}_{name}', pme); bpy.context.scene.collection.objects.link(po)
        po.data.materials.append(bpy.data.materials[DARK.get(name, 'Black')])
        pieces.append(po)
    bm.free()
    total = sum(tris(p.data) for p in pieces)
    if total > TRI_BUDGET:  # decimate in Blender, never Studio; small pieces untouched
        big = [p for p in pieces if tris(p.data) > 60]
        nb = sum(tris(p.data) for p in big)
        ratio = max(.3, 1 - (total - TRI_BUDGET + 10) / nb)
        for p in big:
            bpy.context.view_layer.objects.active = p
            d = p.modifiers.new('PhoneBudget', 'DECIMATE'); d.ratio = ratio
            with bpy.context.temp_override(object=p): bpy.ops.object.modifier_apply(modifier=d.name)
    for p in pieces:  # exporters drop zero-area tris; drop them here so the manifest count is the shipped count
        b = bmesh.new(); b.from_mesh(p.data)
        bmesh.ops.dissolve_degenerate(b, edges=b.edges, dist=1e-5)
        bmesh.ops.triangulate(b, faces=[f for f in b.faces if len(f.verts) > 3])
        seen = set(); dup = []
        for f in b.faces:  # hole-fill can double an existing face; exporters drop the copy
            k = tuple(sorted(v.index for v in f.verts)); dup.append(f) if k in seen else seen.add(k)
        bmesh.ops.delete(b, geom=dup, context='FACES_ONLY'); b.to_mesh(p.data); b.free()
    out = []
    for p in pieces:
        bb = [Vector(v.co) for v in p.data.vertices]
        lo = Vector([min(v[i] for v in bb) for i in range(3)]); hi = Vector([max(v[i] for v in bb) for i in range(3)])
        piv = (lo + hi) / 2
        if p.name.endswith('_Mag'): piv.z = hi.z  # mag pivot at its top (drop/insert)
        p.data.transform(Matrix.Translation(-piv)); p.location = piv; p.parent = root
        out.append({'name': p.name.split('_', 1)[1], 'object': p.name, 'tris': tris(p.data),
                    'pivot_blender': [round(a, 4) for a in piv],
                    'pivot_roblox': [round(piv.x, 4), round(piv.z, 4), round(-piv.y, 4)],
                    'material': p.data.materials[0].name})
    total = sum(o['tris'] for o in out)
    assert total <= TRI_BUDGET, (gid, total)
    d = R / f'assets/guns/{cls}'; (d / 'export').mkdir(exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(d / f'{gid}.blend'))
    bpy.ops.export_scene.fbx(filepath=str(d / f'export/{gid}.fbx'), object_types={'EMPTY', 'MESH'},
                             apply_scale_options='FBX_SCALE_UNITS', bake_space_transform=False, add_leaf_bones=False)
    bpy.ops.export_scene.gltf(filepath=str(d / f'export/{gid}.glb'), export_format='GLB', export_yup=True)
    return cls, {'source': str(src.relative_to(R)), 'source_tris': raw, 'tris': total, 'tri_budget': TRI_BUDGET,
                 'length_studs': L, 'forward': 'Roblox -Z (Blender +Y)', 'piece_count': len(out), 'pieces': out}

ids = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else list(GUNS)
man = {}
for gid in ids:
    cls, m = build(gid); man.setdefault(cls, {})[gid] = m
    print(f'GUN {gid} {m["source_tris"]}->{m["tris"]} tris, {m["piece_count"]} pieces:', ' '.join(f'{p["name"]}={p["tris"]}' for p in m['pieces']))
for cls, ms in man.items():
    p = R / f'assets/guns/{cls}/export/manifest.json'
    old = json.loads(p.read_text()) if p.exists() else {}
    old.update(ms); p.write_text(json.dumps(old, indent=1))
