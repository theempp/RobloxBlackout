"""Deterministic local Blender derivative of the immutable paid FBX; no services.

Run inspect_source.py then measure_fit.py first. All distances are Roblox studs.
"""
import bpy, bmesh, sys, json, hashlib, math
from pathlib import Path
from mathutils import Vector, Matrix
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE/'.deps'))
import numpy as np
from PIL import Image
from scipy.spatial import cKDTree
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
SOURCE=HERE/'source/Meshy_AI_Shadow_Velocity_1003043122_generate.fbx'
HASH=(HERE/'source/SHA256.txt').read_text().split()[0]
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==HASH
fit=json.loads((HERE/'fit_measurements.json').read_text())
assert fit['hub_fit_pass'] and max(w['hub_error'] for w in fit['wheels'])<=.15
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(SOURCE))
raw=next(o for o in bpy.context.scene.objects if o.type=='MESH')
raw.name='SOURCE_UNMODIFIED'
# A working-copy reduction avoids thousands of jagged cut-edge vertices locking
# the later piece budgets. Final decimation remains per named piece.
work=raw.copy();work.data=raw.data.copy();bpy.context.scene.collection.objects.link(work)
bpy.context.view_layer.objects.active=work
mod=work.modifiers.new('Preparation for local wheel cuts','DECIMATE');mod.ratio=24000/len(work.data.polygons)
bpy.ops.object.modifier_apply(modifier=mod.name)
v=np.array([work.matrix_world@p.co for p in work.data.vertices])
faces=np.array([p.vertices[:] for p in work.data.polygons],dtype=np.int32)
bpy.data.objects.remove(work,do_unlink=True)
assert faces.shape[1]==3
centroids=v[faces].mean(axis=1)
rb=v[:,[1,2,0]]*fit['fit_scale_rb']+fit['fit_offset_rb']
def r2b(p): return (p[0],-p[2],p[1])
def material(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;m.use_fake_user=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Roughness'].default_value=.66;bs.inputs['Metallic'].default_value=0
    bs.inputs['Emission Strength'].default_value=0
    return m
mats={k:material(k,c) for k,c in {'StealthBlack':(.022,.023,.027),'TyreBlack':(.012,.013,.015),
    'OpaqueBlackGlass':(.006,.008,.010),'FlatForgedCarbon':(.043,.046,.052),
    'WhiteHeadlamp':(.92,.92,.87),'RedTailLamp':(.56,.012,.018)}.items()}
objects=[]; repairs=[]
def mesh(name,points,polys,mat='StealthBlack',pivot=(0,0,0)):
    me=bpy.data.meshes.new(name);me.from_pydata([r2b(np.array(p)-pivot) for p in points],[],polys);me.update()
    ob=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(ob)
    ob.location=r2b(pivot);me.materials.append(mats[mat]);objects.append(ob)
    return ob
def subset(name,mask,points=rb,mat='StealthBlack',pivot=(0,0,0)):
    fs=faces[mask]; ids,inv=np.unique(fs,return_inverse=True)
    return mesh(name,points[ids],inv.reshape(-1,3).tolist(),mat,pivot)
def activate(ob):
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
def tris(ob): ob.data.calc_loop_triangles();return len(ob.data.loop_triangles)
def reduce(ob,budget):
    activate(ob)
    mod=ob.modifiers.new('Triangulate cut caps','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
    for _ in range(5):
        count=tris(ob)
        if count<=budget: break
        mod=ob.modifiers.new('PhoneBudget','DECIMATE');mod.ratio=(budget-8)/count
        bpy.ops.object.modifier_apply(modifier=mod.name)
    assert tris(ob)<=budget,(ob.name,tris(ob),budget)
def cap(ob):
    bm=bmesh.new();bm.from_mesh(ob.data)
    edges=[e for e in bm.edges if e.is_boundary]
    repairs.append({'piece':ob.name,'cut_boundary_edges':len(edges)})
    if edges:bmesh.ops.holes_fill(bm,edges=edges,sides=0)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.004)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.0001)
    bmesh.ops.dissolve_limit(bm,angle_limit=.08,verts=list(bm.verts),edges=list(bm.edges),use_dissolve_boundaries=True)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
def largest_component(ob):
    edges=np.array([e.vertices[:] for e in ob.data.edges])
    graph=coo_matrix((np.ones(len(edges)),(edges[:,0],edges[:,1])),shape=(len(ob.data.vertices),)*2)
    _,labels=connected_components(graph,directed=False)
    keep=np.argmax(np.bincount(labels))
    bm=bmesh.new();bm.from_mesh(ob.data);bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=[p for p in bm.verts if labels[p.index]!=keep],context='VERTS')
    bm.to_mesh(ob.data);bm.free()
def repair_wheel_seam(ob):
    for _ in range(4):
        ob.data.validate()
        bm=bmesh.new();bm.from_mesh(ob.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.015)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.003)
        remove=set()
        for e in bm.edges:
            if len(e.link_faces)>2:
                remove.update(sorted(e.link_faces,key=lambda f:f.calc_area())[:len(e.link_faces)-2])
        if remove:bmesh.ops.delete(bm,geom=list(remove),context='FACES')
        edges=[e for e in bm.edges if e.is_boundary]
        if edges:bmesh.ops.holes_fill(bm,edges=edges,sides=0)
        loose=[e for e in bm.edges if not e.link_faces]
        if loose:bmesh.ops.delete(bm,geom=loose,context='EDGES')
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        count=sum(not e.is_manifold for e in bm.edges)
        bm.to_mesh(ob.data);bm.free()
        if count==0:break
    if count:
        bm=bmesh.new();bm.from_mesh(ob.data)
        badverts={v for e in bm.edges if not e.is_manifold for v in e.verts}
        patch={f for v in badverts for f in v.link_faces}
        bmesh.ops.delete(bm,geom=list(patch),context='FACES')
        edges=[e for e in bm.edges if e.is_boundary]
        if edges:bmesh.ops.holes_fill(bm,edges=edges,sides=0)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        count=sum(not e.is_manifold for e in bm.edges)
        bm.to_mesh(ob.data);bm.free()
    print('WHEEL_SEAM',ob.name,count,flush=True)
    assert count==0,(ob.name,'unrepaired seam',count)
def box(name,center,size,mat='StealthBlack',hidden=False):
    bpy.ops.mesh.primitive_cube_add(size=1,location=r2b(center));ob=bpy.context.object;ob.name=name
    ob.dimensions=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    ob.data.materials.append(mats[mat]);objects.append(ob)
    if hidden:ob.hide_render=True;ob.display_type='WIRE';ob['RobloxTransparency']=1
    return ob
used=np.zeros(len(faces),dtype=bool)
for w,target in zip(fit['wheels'],[(-1.925,.92,-3.4),(1.925,.92,-3.4),(-1.925,.92,3.6),(1.925,.92,3.6)]):
    c=np.array(w['raw_center']);sign=np.sign(c[1]);radius=w['raw_radius']
    distance=np.linalg.norm(centroids[:,[0,2]]-c[[0,2]],axis=1)
    mask=(distance<radius*1.035)&(centroids[:,1]*sign>abs(c[1])-w['raw_width']/2-.008)
    mask &= ~used;used|=mask
    ob=subset(w['name'],mask,mat='TyreBlack',pivot=target)
    largest_component(ob);cap(ob);reduce(ob,500)
    ob.data.validate();cap(ob);ob.data.validate()
    repair_wheel_seam(ob)
    # Normalize measured tyre envelope to the existing radius/width, then centre it.
    coords=np.array([p.co[:] for p in ob.data.vertices]);lo=coords.min(0);hi=coords.max(0)
    ctr=(lo+hi)/2;dims=hi-lo
    coords=(coords-ctr)*np.array([.96,1.84,1.84])/dims
    radial=np.linalg.norm(coords[:,1:],axis=1)
    coords[:,1:]*=np.minimum(1,.92/np.maximum(radial,1e-9))[:,None]
    for p,co in zip(ob.data.vertices,coords):p.co=co
    ob['hub_rb']=target;ob['source_natural_hub_error']=w['hub_error']
    for p in ob.data.polygons:p.use_smooth=True
body=subset('BodyShell',~used);reduce(body,6000)
for p in body.data.polygons:p.use_smooth=True
raw.hide_render=True;raw.hide_set(True)
source_collection=bpy.data.collections.new('Source_reference_NOT_EXPORTED');bpy.context.scene.collection.children.link(source_collection)
for col in list(raw.users_collection):col.objects.unlink(raw)
source_collection.objects.link(raw);source_collection.hide_render=True;source_collection.hide_viewport=True
# Checkpoint allows wheel/body inspection without downstream cockpit edits.
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'wheel_stage.blend'),compress=True)
(HERE/'wheel_stage.json').write_text(json.dumps({'triangles':sum(tris(o) for o in objects),'repairs':repairs},indent=2))
print('WHEEL_STAGE',sum(tris(o) for o in objects),flush=True)
