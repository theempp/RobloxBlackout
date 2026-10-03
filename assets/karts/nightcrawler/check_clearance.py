"""Offline surface-intersection audit; does not replace Studio avatar/phone tests."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(HERE/'blackout_nightcrawler.blend'))
def tree(o,matrix=None):
    m=matrix if matrix is not None else o.matrix_world
    return BVHTree.FromPolygons([m@v.co for v in o.data.vertices],[p.vertices[:] for p in o.data.polygons])
obstacles={n:tree(bpy.data.objects[n]) for n in ['BodyShell','Canopy_L','Canopy_R','CockpitFloor','CockpitTub']}
body=obstacles['BodyShell']
checks=[]
for name in ['Wheel_FL','Wheel_FR','Wheel_RL','Wheel_RR']:
    o=bpy.data.objects[name]
    for steer in ([-32,0,32] if name.startswith('Wheel_F') else [0]):
        for travel in [-.8,0,.35]:
            m=Matrix.Translation(o.location+Vector((0,0,travel)))
            m=m@Matrix.Rotation(math.radians(steer),4,'Z')
            wt=tree(o,m)
            checks.append(dict(piece=name,steer=steer,travel=travel,intersecting_triangle_pairs={n:len(t.overlap(wt)) for n,t in obstacles.items()}))
avatar={o.name:len(body.overlap(tree(o))) for o in bpy.context.scene.objects if o.name.startswith('FIT_PROXY_')}
report={'wheel_sweep':checks,'avatar_body_surface_intersections':avatar,
        'note':'Surface intersections only; no gameplay, animation, or phone test implied.'}
(HERE/'clearance_audit.json').write_text(json.dumps(report,indent=2))
assert not any(any(x['intersecting_triangle_pairs'].values()) for x in checks), 'wheel surface intersections'
assert not any(avatar.values()), 'avatar/body intersections'
print('CLEARANCE_AUDIT_PASS',len(checks),'wheel poses;',len(avatar),'avatar parts')
