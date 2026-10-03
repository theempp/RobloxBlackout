"""Re-import BOTH deliverables, measuring actual geometry, pivots and materials.
Run: blender -b --python-exit-code 1 -P assets/karts/nightcrawler/verify_export.py
"""
import bpy,bmesh,json,hashlib
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent
manifest=json.loads((HERE/'manifest.json').read_text())
source=HERE/'source/Meshy_AI_Shadow_Velocity_1003043122_generate.fbx'
expected=(HERE/'source/SHA256.txt').read_text().split()[0]
assert hashlib.sha256(source.read_bytes()).hexdigest()==expected
names={p['name'] for p in manifest['pieces']}
hubs={'Wheel_FL':(-1.925,.92,-3.4),'Wheel_FR':(1.925,.92,-3.4),
      'Wheel_RL':(-1.925,.92,3.6),'Wheel_RR':(1.925,.92,3.6)}
def rb(p):return Vector((p.x,p.z,-p.y))
results={}
for ext in ['fbx','glb']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path=HERE/'export'/('blackout_nightcrawler.'+ext)
    if ext=='fbx':bpy.ops.import_scene.fbx(filepath=str(path),axis_forward='-Z',axis_up='Y')
    else:bpy.ops.import_scene.gltf(filepath=str(path))
    meshes={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
    assert set(meshes)==names,(ext,'piece mismatch',set(meshes)^names)
    assert {'Chassis','Steer',*hubs}.issubset(meshes)
    total=0;topology={};errors={}
    for name,ob in meshes.items():
        assert not ob.data.validate(),(ext,name,'invalid mesh')
        ob.data.calc_loop_triangles();total+=len(ob.data.loop_triangles)
        bm=bmesh.new();bm.from_mesh(ob.data)
        # glTF splits identical positions at normal/material seams. Audit the
        # geometric surface after epsilon welding a temporary BMesh only.
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
        topology[name]={'boundary_edges':sum(e.is_boundary for e in bm.edges),
                        'nonmanifold_edges':sum(not e.is_manifold for e in bm.edges)}
        bm.free()
    assert total==manifest['measured_triangles'],(ext,total,manifest['measured_triangles'])
    assert total<=8000,(ext,total)
    for name,target in hubs.items():
        assert topology[name]['nonmanifold_edges']==0,(ext,name,'wheel seam topology')
        ob=meshes[name];error=(rb(ob.matrix_world.translation)-Vector(target)).length
        assert error<=.15,(ext,name,error)
        world=[rb(ob.matrix_world@v.co) for v in ob.data.vertices]
        lo=Vector([min(v[i] for v in world) for i in range(3)]);hi=Vector([max(v[i] for v in world) for i in range(3)])
        assert ((lo+hi)/2-Vector(target)).length<.02,(ext,name,'geometry not centred')
        # Radius is measured radially. A decimated tyre need not have vertices
        # exactly at all four cardinal angles, so its AABB can be slightly smaller.
        assert abs((hi-lo).x-.96)<.0001,(ext,name,'wheel width')
        radius=max(((v.y-target[1])**2+(v.z-target[2])**2)**.5 for v in world)
        assert .919<=radius<=.92001,(ext,name,'tyre radius',radius)
        assert min((hi-lo).y,(hi-lo).z)>1.79,(ext,name,'collapsed tyre envelope')
        errors[name]=error
    for name,target in [('Chassis',(0,1.75,-.05)),('Steer',(0,1.85,-.95))]:
        assert (rb(meshes[name].matrix_world.translation)-Vector(target)).length<.001,(ext,name)
    # Chassis bounds, not just its pivot, establish KartModel.templateFrame.
    ob=meshes['Chassis'];points=[rb(ob.matrix_world@v.co) for v in ob.data.vertices]
    center=Vector([(min(p[i] for p in points)+max(p[i] for p in points))/2 for i in range(3)])
    assert (center-Vector((0,1.75,-.05))).length<.001
    assert sum(n=='TailLamp' for n in meshes)==1
    for mat in bpy.data.materials:
        if not mat.use_nodes:continue
        assert not any(n.type=='TEX_IMAGE' for n in mat.node_tree.nodes),(ext,mat.name,'texture')
        for n in mat.node_tree.nodes:
            if n.type=='BSDF_PRINCIPLED':
                assert n.inputs['Alpha'].default_value==1,(ext,mat.name,'transparent')
                assert n.inputs['Emission Strength'].default_value==0,(ext,mat.name,'emission')
    results[ext]={'pieces':len(meshes),'triangles':total,'hub_errors':errors,'topology':topology,
                  'topology_method':'temporary position weld at 1e-6; exported geometry untouched',
                  'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
assert hashlib.sha256(source.read_bytes()).hexdigest()==expected
results['source_sha256_before_and_after']=expected
results['Studio_import']='PENDING OWNER';results['phone_test']='PENDING OWNER'
(HERE/'verification.json').write_text(json.dumps(results,indent=2))
print('NIGHTCRAWLER_VERIFIED',json.dumps({k:{'pieces':v['pieces'],'triangles':v['triangles'],'max_hub_error':max(v['hub_errors'].values())} for k,v in results.items() if k in ['fbx','glb']}))
