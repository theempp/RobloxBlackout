"""Cloud/Claude check requiring only Python stdlib, not Blender.

Checks immutable source and export hashes, independently counts GLB triangles,
and checks GLB node names/pivots. Blender-specific evidence is verification.json.
"""
import hashlib,json,math,struct
from pathlib import Path
HERE=Path(__file__).resolve().parent
manifest=json.loads((HERE/'manifest.json').read_text())
verified=json.loads((HERE/'verification.json').read_text())
source=HERE/'source/Meshy_AI_Shadow_Velocity_1003043122_generate.fbx'
expected=(HERE/'source/SHA256.txt').read_text().split()[0]
assert hashlib.sha256(source.read_bytes()).hexdigest()==expected==manifest['source_sha256']
for ext in ['fbx','glb']:
    data=(HERE/'export'/('blackout_nightcrawler.'+ext)).read_bytes()
    assert hashlib.sha256(data).hexdigest()==verified[ext]['sha256'],ext+' stale verification'
data=(HERE/'export/blackout_nightcrawler.glb').read_bytes()
magic,version,length=struct.unpack_from('<III',data)
assert magic==0x46546c67 and version==2 and length==len(data)
size,kind=struct.unpack_from('<II',data,12);assert kind==0x4e4f534a
gltf=json.loads(data[20:20+size])
nodes={n['name']:n for n in gltf['nodes'] if 'mesh' in n}
assert set(nodes)=={p['name'] for p in manifest['pieces']}
tris=0
for mesh in gltf['meshes']:
    for p in mesh['primitives']:
        assert p.get('mode',4)==4
        tris+=gltf['accessors'][p['indices']]['count']//3
assert tris==manifest['measured_triangles']<=8000
for p in manifest['pieces']:
    assert math.dist(nodes[p['name']].get('translation',[0,0,0]),p['pivot_rb'])<.00001,p['name']
assert not gltf.get('textures') and not gltf.get('images')
audit=json.loads((HERE/'clearance_audit.json').read_text())
assert not any(any(x['intersecting_triangle_pairs'].values()) for x in audit['wheel_sweep'])
assert not any(audit['avatar_body_surface_intersections'].values())
print(f'NIGHTCRAWLER_CLOUD_REVIEW_PASS: {len(nodes)} pieces, {tris}/8000 triangles; source/export hashes and GLB pivots match.')
print('Pending: owner visual approval, actual avatar/Studio import, hinge integration and iPhone test.')
