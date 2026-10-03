"""Read-only source intake. Run: blender -b --python-exit-code 1 -P this_file."""
import sys, json, hashlib
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / '.deps'))
import bpy, bmesh, numpy as np
from scipy.spatial import cKDTree
from PIL import Image
source = HERE / 'source/Meshy_AI_Shadow_Velocity_1003043122_generate.fbx'
expected = (HERE / 'source/SHA256.txt').read_text().split()[0]
assert hashlib.sha256(source.read_bytes()).hexdigest() == expected
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(source))
report = {'sha256':expected, 'objects':[]}
from io_scene_fbx import parse_fbx
root,version=parse_fbx.parse(str(source))
settings=next(e for e in root.elems if e.id==b'GlobalSettings')
props=next(e for e in settings.elems if e.id==b'Properties70')
report['fbx_global_settings']={p.props[0].decode():p.props[-1] for p in props.elems
    if p.id==b'P' and p.props[0] in [b'UpAxis',b'UpAxisSign',b'FrontAxis',b'FrontAxisSign',b'CoordAxis',b'CoordAxisSign',b'UnitScaleFactor',b'OriginalUnitScaleFactor']}
report['blender_scene_unit_scale']=bpy.context.scene.unit_settings.scale_length
for ob in bpy.context.scene.objects:
    if ob.type != 'MESH': continue
    v = np.array([ob.matrix_world @ x.co for x in ob.data.vertices])
    bm=bmesh.new(); bm.from_mesh(ob.data)
    report['objects'].append(dict(name=ob.name, vertices=len(v), faces=len(ob.data.polygons),
        matrix_world=[list(r) for r in ob.matrix_world], local_scale=list(ob.scale),
        bbox_min=v.min(0).tolist(), bbox_max=v.max(0).tolist(),
        boundary_edges=sum(e.is_boundary for e in bm.edges),
        nonmanifold_edges=sum(not e.is_manifold for e in bm.edges)))
    bm.free()
    np.savez_compressed(HERE/'raw_vertices.npz', vertices=v)
report['source_hash_after']=hashlib.sha256(source.read_bytes()).hexdigest()
(HERE/'source_inspection.json').write_text(json.dumps(report,indent=2))
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'raw_intake.blend'),compress=True)
print('INTAKE',json.dumps(report))
