"""Blender: extract shipped gun GLBs without modifying or decimating them.
blender -b -P tools/export_guns.py; python3 tools/import_guns.py
Geometry stays in build/; manifests and uploaded IDs generate GunAssets.luau.
"""
import hashlib
import json
from pathlib import Path
import bpy

R = Path(__file__).resolve().parents[1]
out = {}
for cls in ('pistol', 'ar', 'sniper', 'shotgun'):
    directory = R / 'assets/guns' / cls / 'export'
    manifest = json.loads((directory / 'manifest.json').read_text())
    for gid, gun in manifest.items():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        path = directory / (gid + '.glb')
        bpy.ops.import_scene.gltf(filepath=str(path))
        pieces = []
        for spec in gun['pieces']:
            ob = bpy.data.objects[spec['object']]
            ob.data.calc_loop_triangles()
            vertices = []
            for v in ob.data.vertices:
                p = ob.matrix_world @ v.co
                vertices.append([round(p.x, 6), round(p.z, 6), round(-p.y, 6)])
            lo = [min(v[i] for v in vertices) for i in range(3)]
            hi = [max(v[i] for v in vertices) for i in range(3)]
            center = [(a + b) / 2 for a, b in zip(lo, hi)]
            local = [[round(v[i] - center[i], 6) for i in range(3)] for v in vertices]
            faces = [[i + 1 for i in t.vertices] for t in ob.data.loop_triangles]
            assert len(faces) == spec['tris'], spec['object']
            color = list(ob.data.materials[0].diffuse_color[:3])
            assert max(color) <= .1, spec['object']
            data = dict(vertices=local, faces=faces)
            sha = hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()
            pieces.append(dict(name=spec['object'], piece=spec['name'], tris=len(faces),
                               pivot=spec['pivot_roblox'], center=center, size=[b-a for a,b in zip(lo,hi)],
                               color=color, material=spec['material'], sha256=sha, **data))
        assert sum(p['tris'] for p in pieces) == gun['tris']
        by = {p['piece']: p for p in pieces}
        front = by.get('Muzzle', by.get('Barrel'))
        muzzle = front['center'].copy()
        muzzle[2] -= front['size'][2] / 2
        assert muzzle[2] < 0
        optic = by.get('Optic', by['Body'])
        sight = [0, optic['center'][1] + optic['size'][1] / 2, optic['center'][2]]
        points = dict(Grip=[0, 0, 0], Sight=sight,
                      FrontSight=[0, sight[1], muzzle[2]], Barrel=muzzle)
        for label, piece in [('Mag','Mag'), ('Mover','Slide' if 'Slide' in by else 'Pump'),
                             ('Optic','Optic'), ('Foregrip','Foregrip')]:
            if piece in by:
                points[label] = by[piece]['pivot']
        out[gid] = dict(tris=gun['tris'], muzzle=muzzle, points=points, pieces=pieces,
                        export_sha256=hashlib.sha256(path.read_bytes()).hexdigest())
(R/'build').mkdir(exist_ok=True)
(R/'build/guns-geometry.json').write_text(json.dumps(out, separators=(',', ':')))
print('BC_GUN_EXPORT', len(out), 'guns', sum(len(g['pieces']) for g in out.values()), 'pieces')

# One import file preserves all 43 names; source exports remain byte-intact.
bpy.ops.wm.read_factory_settings(use_empty=True)
for cls in ('pistol', 'ar', 'sniper', 'shotgun'):
    for path in sorted((R/'assets/guns'/cls/'export').glob('*.glb')):
        bpy.ops.import_scene.gltf(filepath=str(path))
bpy.ops.export_scene.gltf(filepath=str(R/'build/guns-import.glb'), export_format='GLB')
